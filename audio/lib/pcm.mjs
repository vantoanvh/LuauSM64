// Analysis of rendered PCM: silence trimming, loop search, spectrum.
import fs from "node:fs";

import { SAMPLE_RATE } from "./paths.mjs";

export function readPcm(file) {
    const bytes = fs.readFileSync(file);
    return new Int16Array(bytes.buffer, bytes.byteOffset, bytes.length >> 1).slice();
}

// Interleaved stereo -> mono (average).
export function toMono(stereo) {
    const mono = new Int16Array(stereo.length >> 1);
    for (let i = 0; i < mono.length; i++) {
        mono[i] = (stereo[2 * i] + stereo[2 * i + 1]) >> 1;
    }
    return mono;
}

export function peak(samples) {
    let max = 0;
    for (let i = 0; i < samples.length; i++) {
        max = Math.max(max, Math.abs(samples[i]));
    }
    return max;
}

export function rms(samples) {
    if (samples.length === 0) {
        return 0;
    }
    let sum = 0;
    for (let i = 0; i < samples.length; i++) {
        sum += samples[i] * samples[i];
    }
    return Math.sqrt(sum / samples.length);
}

// First and one-past-last frame (of `channels` interleaved) whose amplitude exceeds `threshold`.
export function audibleRange(samples, channels, threshold) {
    const frames = samples.length / channels;
    const loud = (frame) => {
        for (let c = 0; c < channels; c++) {
            if (Math.abs(samples[frame * channels + c]) > threshold) {
                return true;
            }
        }
        return false;
    };
    let first = 0;
    while (first < frames && !loud(first)) {
        first++;
    }
    let last = frames;
    while (last > first && !loud(last - 1)) {
        last--;
    }
    return [first, last];
}

// ---- spectrum ----------------------------------------------------------------------------

// In-place radix-2 complex FFT.
export function fft(re, im, inverse = false) {
    const n = re.length;
    for (let i = 1, j = 0; i < n; i++) {
        let bit = n >> 1;
        for (; j & bit; bit >>= 1) {
            j ^= bit;
        }
        j ^= bit;
        if (i < j) {
            [re[i], re[j]] = [re[j], re[i]];
            [im[i], im[j]] = [im[j], im[i]];
        }
    }
    for (let length = 2; length <= n; length <<= 1) {
        const angle = ((inverse ? 2 : -2) * Math.PI) / length;
        const wr = Math.cos(angle);
        const wi = Math.sin(angle);
        for (let start = 0; start < n; start += length) {
            let cr = 1;
            let ci = 0;
            for (let k = 0; k < length / 2; k++) {
                const a = start + k;
                const b = a + length / 2;
                const tr = re[b] * cr - im[b] * ci;
                const ti = re[b] * ci + im[b] * cr;
                re[b] = re[a] - tr;
                im[b] = im[a] - ti;
                re[a] += tr;
                im[a] += ti;
                const next = cr * wr - ci * wi;
                ci = cr * wi + ci * wr;
                cr = next;
            }
        }
    }
    if (inverse) {
        for (let i = 0; i < n; i++) {
            re[i] /= n;
            im[i] /= n;
        }
    }
}

// Frequency (Hz) of the strongest spectral peak of mono[start, start + size), size a power of two.
export function dominantFrequency(mono, size = 4096) {
    // Analyze the loudest window.
    let start = 0;
    let loudest = -1;
    for (let at = 0; at + size <= mono.length; at += size / 2) {
        const energy = rms(mono.subarray(at, at + size));
        if (energy > loudest) {
            loudest = energy;
            start = at;
        }
    }
    const re = new Float64Array(size);
    const im = new Float64Array(size);
    for (let i = 0; i < size; i++) {
        const window = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / size);
        re[i] = (mono[start + i] ?? 0) * window;
    }
    fft(re, im);
    let best = 1;
    for (let k = 2; k < size / 2; k++) {
        if (re[k] ** 2 + im[k] ** 2 > re[best] ** 2 + im[best] ** 2) {
            best = k;
        }
    }
    return (best * SAMPLE_RATE) / size;
}

// ---- loops -------------------------------------------------------------------------------

// Sum of squared differences of the `width` samples before a and before b.
function seamError(x, a, b, width) {
    let sum = 0;
    for (let j = 1; j <= width; j++) {
        const d = x[a - j] - x[b - j];
        sum += d * d;
    }
    return sum;
}

// Normalized autocorrelation of x[start, start + length) for lags in [minLag, maxLag].
function autocorrelation(x, start, length, minLag, maxLag) {
    let size = 1;
    while (size < length * 2) {
        size <<= 1;
    }
    const re = new Float64Array(size);
    const im = new Float64Array(size);
    for (let i = 0; i < length; i++) {
        re[i] = x[start + i];
    }
    fft(re, im);
    for (let i = 0; i < size; i++) {
        re[i] = re[i] ** 2 + im[i] ** 2;
        im[i] = 0;
    }
    fft(re, im, true);
    const energy = new Float64Array(length + 1);
    for (let i = 0; i < length; i++) {
        energy[i + 1] = energy[i] + x[start + i] ** 2;
    }
    const result = new Float64Array(maxLag + 1);
    for (let lag = minLag; lag <= maxLag; lag++) {
        const head = energy[length - lag];
        const tail = energy[length] - energy[lag];
        result[lag] = re[lag] / (Math.sqrt(head * tail) || 1);
    }
    return result;
}

// Loop of a sound that is still playing when the render stops: a region [start, end) of the
// steady part, with the length chosen where the signal repeats best and the seam refined to the
// sample where the audio before `end` matches the audio before `start`.
export function findSteadyLoop(x) {
    const start0 = Math.round(0.5 * SAMPLE_RATE);
    const length = Math.min(x.length - start0, 8 * SAMPLE_RATE);
    const minLag = Math.round(0.25 * SAMPLE_RATE);
    const maxLag = Math.min(Math.round(4 * SAMPLE_RATE), length >> 1);
    const correlation = autocorrelation(x, start0, length, minLag, maxLag);
    let best = minLag;
    for (let lag = minLag; lag <= maxLag; lag++) {
        if (correlation[lag] > correlation[best]) {
            best = lag;
        }
    }
    // The shortest local maximum close to the best one (a loop of two periods is no better).
    let lag = best;
    for (let l = minLag + 1; l < best; l++) {
        if (correlation[l] >= correlation[best] * 0.95 && correlation[l] >= correlation[l - 1] && correlation[l] >= correlation[l + 1]) {
            lag = l;
            break;
        }
    }
    const width = 256;
    let choice = { error: Infinity, start: start0, end: start0 + lag };
    for (let start = start0; start < start0 + 2048; start++) {
        for (let d = -64; d <= 64; d++) {
            const end = start + lag + d;
            const error = seamError(x, end, start, width);
            if (error < choice.error) {
                choice = { error, start, end };
            }
        }
    }
    return { start: choice.start, end: choice.end, correlation: correlation[lag] };
}

// Moves `end` (within +-maxShift) to where the audio before it best continues into `start`.
export function refineLoopEnd(x, start, end, maxShift = 256, width = 4096) {
    let best = { error: Infinity, end };
    for (let candidate = end - maxShift; candidate <= end + maxShift; candidate++) {
        if (candidate > x.length || candidate - width < 0) {
            continue;
        }
        const error = seamError(x, candidate, start, width);
        if (error < best.error) {
            best = { error, end: candidate };
        }
    }
    return best.end;
}

// Replaces the last `fade` samples before `end` with a crossfade towards the samples before
// `start`, so playing [start, end) in a loop has no discontinuity. Works on a copy. The fade is
// linear: the two signals are (nearly) the same one, so their gains must add up to 1.
export function bakeLoopCrossfade(samples, channels, start, end, fade) {
    const out = samples.slice(0, end * channels);
    for (let j = 0; j < fade; j++) {
        const blend = (j + 0.5) / fade;
        const keep = 1 - blend;
        for (let c = 0; c < channels; c++) {
            const at = (end - fade + j) * channels + c;
            const from = (start - fade + j) * channels + c;
            out[at] = Math.round(out[at] * keep + samples[from] * blend);
        }
    }
    return out;
}

// Time (ms) after which no 10 ms window of mono is louder than `fraction` of the peak rms window.
export function decayMs(mono, fraction) {
    const window = SAMPLE_RATE / 100;
    const levels = [];
    for (let at = 0; at + window <= mono.length; at += window) {
        levels.push(rms(mono.subarray(at, at + window)));
    }
    const limit = Math.max(...levels) * fraction;
    const last = levels.map((level) => level > limit).lastIndexOf(true);
    return (last + 1) * 10;
}

