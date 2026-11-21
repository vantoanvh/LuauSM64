// Packs the rendered sound effects and music for Studio's local audio importer.
import fs from "node:fs/promises";
import path from "node:path";

import { CONCURRENCY, pool } from "./lib/build.mjs";
import { decodeToPcm, encodeOggPcm } from "./lib/encode.mjs";
import { OUT, SAMPLE_RATE } from "./lib/paths.mjs";

const output = path.join(OUT, "atlases");
const gapMs = 2000;
const gapFrames = (gapMs * SAMPLE_RATE) / 1000;
const durationLimit = 7 * 60 * SAMPLE_RATE;
const sizeLimit = 20_000_000;
const toFrames = (ms) => Math.round((ms * SAMPLE_RATE) / 1000);
const toMs = (frames) => (frames * 1000) / SAMPLE_RATE;

function soundOrder([first], [second]) {
    const [firstBank, firstId] = first.split("_").map(Number);
    const [secondBank, secondId] = second.split("_").map(Number);

    return firstBank - secondBank || firstId - secondId;
}

async function writeAtlas(bank, index) {
    const file = `sfx_atlas_${String(index.atlases.length + 1).padStart(2, "0")}.ogg`;
    const filename = path.join(output, file);
    const samples = new Int16Array(bank.frames);

    for (const { key, entry, pcm, start } of bank.clips) {
        samples.set(pcm, start);

        const clip = { file, name: entry.name, startMs: toMs(start), endMs: toMs(start + pcm.length) };

        if (entry.loop) {
            clip.loopStartMs = toMs(start + toFrames(entry.loopStartMs));
            clip.loopEndMs = toMs(start + toFrames(entry.loopEndMs));
        }

        index.sfx[key] = clip;
    }

    await encodeOggPcm(samples, 1, filename, 8);

    const decoded = await decodeToPcm(filename, 1);
    const { size } = await fs.stat(filename);

    if (Math.abs(decoded.length - samples.length) > 128 || decoded.length >= durationLimit || size >= sizeLimit) {
        throw new Error(`${file} has ${decoded.length} samples and ${size} bytes, expected ${samples.length} samples within the limits`);
    }

    index.atlases.push({ file, durationMs: toMs(decoded.length), bytes: size, clips: bank.clips.length });
    console.log(`${file}: ${bank.clips.length} clips, ${(decoded.length / SAMPLE_RATE).toFixed(3)} s, ${size} bytes`);
}

const manifest = JSON.parse(await fs.readFile(path.join(OUT, "manifest.json"), "utf8"));
const entries = Object.entries(manifest.sfx).sort(soundOrder);

if (entries.length === 0) throw new Error("The source manifest contains no sound effects");

const clips = await pool(entries, CONCURRENCY, async ([key, entry]) => {
    const pcm = await decodeToPcm(path.join(OUT, entry.file), 1);
    const length = toFrames(entry.durationMs);

    if (!Number.isSafeInteger(length) || length <= 0 || length > pcm.length || length + gapFrames >= durationLimit) {
        throw new Error(`Invalid duration for ${entry.file}`);
    }

    if (entry.loop && !(0 <= entry.loopStartMs && entry.loopStartMs < entry.loopEndMs && entry.loopEndMs <= entry.durationMs)) {
        throw new Error(`Invalid loop points for ${entry.file}`);
    }

    return { key, entry, pcm: pcm.subarray(0, length) };
});

await fs.mkdir(output, { recursive: true });

const index = { sampleRate: SAMPLE_RATE, gapMs, atlases: [], sfx: {}, silentSfx: manifest.silentSfx, music: manifest.music };
let bank = { frames: 0, clips: [] };

for (const clip of clips) {
    const required = clip.pcm.length + gapFrames;

    if (bank.frames + required >= durationLimit) {
        await writeAtlas(bank, index);
        bank = { frames: 0, clips: [] };
    }

    bank.clips.push({ ...clip, start: bank.frames });
    bank.frames += required;
}

await writeAtlas(bank, index);
await Promise.all(Object.values(manifest.music).map(({ file }) => fs.copyFile(path.join(OUT, file), path.join(output, file))));
await fs.writeFile(path.join(output, "sfx-atlas.json"), `${JSON.stringify(index, null, 2)}\n`);
