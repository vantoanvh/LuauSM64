import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

import { SAMPLE_RATE } from "./paths.mjs";

// ffmpeg's libvorbis drops up to a block (128 samples) at the end of a stream, so the samples are
// followed by this much padding: what comes after the loop end (the loop start again) for a looping
// sound, silence otherwise.
const END_PADDING = 1024;

function padded(samples, channels, loopStart) {
    const out = new Int16Array(samples.length + END_PADDING * channels);
    out.set(samples);
    if (loopStart !== undefined) {
        const from = loopStart * channels;
        out.set(samples.subarray(from, from + END_PADDING * channels), samples.length);
    }
    return out;
}

// Encodes interleaved s16 PCM to Ogg Vorbis (libvorbis, quality 5). loopStart: frame the sound
// loops back to at its end, if it loops.
export function encodeOgg(samples, channels, file, loopStart) {
    return encodeOggPcm(padded(samples, channels, loopStart), channels, file);
}

export function encodeOggPcm(samples, channels, file, quality = 5) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const args = [
        "-v", "error", "-y", "-f", "s16le", "-ar", String(SAMPLE_RATE), "-ac", String(channels), "-i", "pipe:0",
        "-c:a", "libvorbis", "-q:a", String(quality), file,
    ];
    return new Promise((resolve, reject) => {
        const ffmpeg = spawn("ffmpeg", args, { stdio: ["pipe", "ignore", "pipe"], windowsHide: true });
        let errors = "";
        ffmpeg.stderr.on("data", (chunk) => (errors += chunk));
        ffmpeg.on("error", reject);
        ffmpeg.on("close", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg failed for ${file}: ${errors}`))));
        ffmpeg.stdin.on("error", () => {});
        ffmpeg.stdin.end(Buffer.from(samples.buffer, samples.byteOffset, samples.byteLength));
    });
}

// Decodes an audio file to interleaved s16 PCM at the sample rate.
export function decodeToPcm(file, channels) {
    return new Promise((resolve, reject) => {
        const args = ["-v", "error", "-i", file, "-f", "s16le", "-ar", String(SAMPLE_RATE), "-ac", String(channels), "pipe:1"];
        const ffmpeg = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
        const chunks = [];
        let errors = "";
        ffmpeg.stdout.on("data", (chunk) => chunks.push(chunk));
        ffmpeg.stderr.on("data", (chunk) => (errors += chunk));
        ffmpeg.on("error", reject);
        ffmpeg.on("close", (code) => {
            if (code !== 0) {
                reject(new Error(`ffmpeg failed for ${file}: ${errors}`));
                return;
            }
            const bytes = Buffer.concat(chunks);
            resolve(new Int16Array(bytes.buffer, bytes.byteOffset, bytes.length >> 1).slice());
        });
    });
}
