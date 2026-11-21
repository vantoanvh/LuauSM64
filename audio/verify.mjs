// Checks the rendered files against the manifest: every file exists, decodes, is not silent, has
// the manifest duration, loop markers are consistent and seamless; prints statistics and spot
// checks. Exit code 1 when a check fails.
//   node audio/verify.mjs
import fs from "node:fs";
import path from "node:path";

import { OUT, SAMPLE_RATE } from "./lib/paths.mjs";
import { CONCURRENCY, pool } from "./lib/build.mjs";
import { decodeToPcm } from "./lib/encode.mjs";
import { decayMs, dominantFrequency, peak, rms, toMono } from "./lib/pcm.mjs";

const MIN_RMS = 20; // of 32767; the quietest real effect is far above this
const DURATION_SHORT_MS = 5; // decoded vs manifest: Vorbis may drop up to 4 ms at the end,
const DURATION_LONG_MS = 100; // and carries padding (ours 32 ms, plus the block rounding)
const SEAM_WIDTH = 512; // inside the baked crossfades

const failures = [];
const fail = (message) => failures.push(message);
const toSamples = (ms) => Math.round((ms * SAMPLE_RATE) / 1000);

// Root mean square of the difference of the audio before the loop end and before the loop start,
// relative to the signal rms: 0 means the loop wraps without any change.
function seamMismatch(mono, loopStartMs, loopEndMs) {
    const start = Math.round((loopStartMs * SAMPLE_RATE) / 1000);
    const end = Math.min(toSamples(loopEndMs), mono.length);
    if (start < SEAM_WIDTH) {
        return null;
    }
    let sum = 0;
    for (let j = 1; j <= SEAM_WIDTH; j++) {
        sum += (mono[end - j] - mono[start - j]) ** 2;
    }
    const level = rms(mono.subarray(start, end)) || 1;
    return Math.sqrt(sum / SEAM_WIDTH) / level;
}

async function inspect(kind, key, entry, channels) {
    const file = path.join(OUT, entry.file);
    if (!fs.existsSync(file)) {
        fail(`${kind} ${key}: ${entry.file} missing`);
        return null;
    }
    const pcm = await decodeToPcm(file, channels);
    const mono = channels === 1 ? pcm : toMono(pcm);
    const durationMs = (mono.length * 1000) / SAMPLE_RATE;
    const level = rms(mono);
    if (level < MIN_RMS) {
        fail(`${kind} ${key} (${entry.name}): silent (rms ${level.toFixed(1)})`);
    }
    if (durationMs < entry.durationMs - DURATION_SHORT_MS || durationMs > entry.durationMs + DURATION_LONG_MS) {
        fail(`${kind} ${key}: decoded ${durationMs.toFixed(0)} ms, manifest ${entry.durationMs} ms`);
    }
    const looping = entry.loop === true || entry.loopStartMs !== undefined;
    if (looping && !(entry.loopStartMs < entry.loopEndMs && entry.loopEndMs <= entry.durationMs)) {
        fail(`${kind} ${key}: bad loop markers ${entry.loopStartMs}..${entry.loopEndMs} of ${entry.durationMs}`);
    }
    const seam = looping ? seamMismatch(mono, entry.loopStartMs, entry.loopEndMs) : null;
    return { mono, rms: level, peak: peak(pcm), durationMs, seam, clipped: pcm.filter((v) => Math.abs(v) >= 32767).length / pcm.length };
}

const percentile = (values, p) => values.slice().sort((a, b) => a - b)[Math.floor((values.length - 1) * p)];

async function main() {
    const manifest = JSON.parse(fs.readFileSync(path.join(OUT, "manifest.json"), "utf8"));
    const sfxEntries = Object.entries(manifest.sfx);
    const musicEntries = Object.entries(manifest.music);

    const sfx = await pool(sfxEntries, CONCURRENCY, ([key, entry]) => inspect("sfx", key, entry, 1));
    const music = await pool(musicEntries, CONCURRENCY, ([key, entry]) => inspect("music", key, entry, 2));

    const files = (prefix) => fs.readdirSync(OUT).filter((f) => f.startsWith(prefix) && f.endsWith(".ogg"));
    console.log(`files: ${files("sfx_").length} sfx, ${files("music_").length} music`);
    console.log(`manifest: ${sfxEntries.length} sfx (${sfxEntries.filter(([, e]) => e.loop).length} looping), ${musicEntries.length} music (${musicEntries.filter(([, e]) => e.loopStartMs !== undefined).length} looping)`);
    console.log(`silent effects, not rendered: ${manifest.silentSfx.join(", ") || "none"}`);

    const sfxMs = sfx.filter(Boolean).map((r) => r.durationMs);
    console.log(`sfx duration ms: min ${percentile(sfxMs, 0).toFixed(0)}, median ${percentile(sfxMs, 0.5).toFixed(0)}, max ${percentile(sfxMs, 1).toFixed(0)}`);
    console.log(`sfx rms: min ${Math.min(...sfx.filter(Boolean).map((r) => r.rms)).toFixed(0)}; clipped samples: ${sfx.filter((r) => r && r.clipped > 0.001).length} files over 0.1%`);
    const music1 = music.filter(Boolean);
    console.log(`music duration s: min ${(Math.min(...music1.map((r) => r.durationMs)) / 1000).toFixed(1)}, max ${(Math.max(...music1.map((r) => r.durationMs)) / 1000).toFixed(1)}; rms min ${Math.min(...music1.map((r) => r.rms)).toFixed(0)}`);
    console.log(`music clipped samples above 0.1%: ${musicEntries.filter((_, i) => music[i] && music[i].clipped > 0.001).map(([k]) => k).join(", ") || "none"}`);

    const seams = [...sfx.map((r, i) => [`sfx ${sfxEntries[i][0]}`, r?.seam]), ...music.map((r, i) => [`music ${musicEntries[i][0]}`, r?.seam])].filter(([, s]) => s !== null && s !== undefined);
    const worst = seams.sort((a, b) => b[1] - a[1]).slice(0, 5).map(([k, s]) => `${k} ${s.toFixed(2)}`);
    console.log(`loop seam mismatch (0 = identical, vs rms): median ${percentile(seams.map(([, s]) => s), 0.5).toFixed(3)}; worst ${worst.join(", ")}`);

    const spot = (key) => {
        const result = sfx[sfxEntries.findIndex(([k]) => k === key)];
        const entry = manifest.sfx[key];
        return result && `${key} ${entry.name}: ${entry.durationMs.toFixed(0)} ms (-26 dB until ${decayMs(result.mono, 0.05)} ms, -40 dB until ${decayMs(result.mono, 0.01)} ms), rms ${result.rms.toFixed(0)}, peak ${result.peak}, dominant ${dominantFrequency(result.mono).toFixed(0)} Hz`;
    };
    console.log("spot checks:");
    for (const key of ["3_17", "3_18", "2_0", "2_3", "2_4", "0_0", "7_0"]) {
        console.log(`  ${spot(key)}`);
    }

    if (failures.length > 0) {
        console.log(`FAILED (${failures.length}):`);
        for (const message of failures) {
            console.log(`  ${message}`);
        }
        process.exit(1);
    }
    console.log("all checks passed");
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
