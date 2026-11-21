// Renders every sound effect and music sequence of the game to Ogg Vorbis files plus a manifest.
//   node audio/render.mjs [--sfx] [--music] [--filter key,key,...] [--clean]
// See audio/README.md.
import fs from "node:fs";
import path from "node:path";

import { AUDIO, BUILD, OUT, SAMPLE_RATE } from "./lib/paths.mjs";
import { CONCURRENCY, DATA_DIR, RENDERER, buildAll, pool, run } from "./lib/build.mjs";
import { encodeOgg } from "./lib/encode.mjs";
import { parsePresets, parseSequences, parseSounds, sequencePlayer } from "./lib/gamedata.mjs";
import {
    audibleRange, bakeLoopCrossfade, dominantFrequency, findSteadyLoop, peak, readPcm, refineLoopEnd, rms, toMono,
} from "./lib/pcm.mjs";

const SFX_CAP_SECONDS = 10;
const MUSIC_CAP_SECONDS = 200; // a loop of 90 s with a second period must fit
const MUSIC_PRIORITY = 4;
const TRIM_THRESHOLD = 16; // peak amplitude (of 32767) below which the start and end are cut
const LEAD_MARGIN = 64; // samples kept before the first audible one
const SFX_LOOP_CROSSFADE = 1280; // 40 ms
const MUSIC_LOOP_CROSSFADE = 960; // 30 ms
const LOOP_END_SEARCH = 300; // samples: sequence ticks happen at update granularity (133 samples)
const SILENT_RMS = 8;

// Times are exact: 32 samples per ms, so a sample position is a multiple of 1/32 ms.
const exactMs = (samples) => samples * 1000 / SAMPLE_RATE;

async function renderPcm(args, pcmPath) {
    const { stdout } = await run(RENDERER, [DATA_DIR, ...args, pcmPath]);
    return JSON.parse(stdout.trim().split("\n").pop());
}

async function renderSfx(sound) {
    const pcmPath = path.join(BUILD, "pcm", `sfx_${sound.key}.pcm`);
    fs.mkdirSync(path.dirname(pcmPath), { recursive: true });
    const info = await renderPcm(["sfx", sound.bits.toString(16), sound.continuous ? "1" : "0", String(SFX_CAP_SECONDS)], pcmPath);
    const mono = toMono(readPcm(pcmPath));
    fs.rmSync(pcmPath);

    const [first, last] = audibleRange(mono, 1, TRIM_THRESHOLD);
    if (last - first < SAMPLE_RATE / 100) {
        return { sound, silent: true, report: { end: info.end } };
    }
    const lead = Math.max(0, first - LEAD_MARGIN);
    let samples = mono.subarray(lead, last);
    const entry = { file: `sfx_${sound.key}.ogg`, durationMs: 0, loop: false, name: sound.name };
    const report = { end: info.end, peak: peak(samples), rms: Math.round(rms(samples)) };
    let loopStart;

    if (info.end === "cap") {
        // Still sounding when the render stopped: a loop (sustained note, looping script).
        const loop = findSteadyLoop(samples);
        samples = bakeLoopCrossfade(samples, 1, loop.start, loop.end, SFX_LOOP_CROSSFADE);
        entry.loop = true;
        loopStart = loop.start;
        entry.loopStartMs = exactMs(loop.start);
        entry.loopEndMs = exactMs(loop.end);
        report.loopCorrelation = Number(loop.correlation.toFixed(3));
    }
    entry.durationMs = exactMs(samples.length);
    if (sound.aliases.length > 0) {
        entry.aliases = sound.aliases;
    }
    report.peakFrequencyHz = Math.round(dominantFrequency(samples));
    await encodeOgg(samples, 1, path.join(OUT, entry.file), loopStart);
    return { sound, entry, report };
}

async function renderMusic(sequence, presetFor) {
    const pcmPath = path.join(BUILD, "pcm", `music_${sequence.id}.pcm`);
    fs.mkdirSync(path.dirname(pcmPath), { recursive: true });
    const player = sequencePlayer(sequence);
    const seqArgs = ((MUSIC_PRIORITY << 8) | sequence.id).toString(16);
    const info = await renderPcm(["music", String(player), seqArgs, String(presetFor(sequence.id)), String(MUSIC_CAP_SECONDS)], pcmPath);
    const stereo = readPcm(pcmPath);
    fs.rmSync(pcmPath);
    const mono = toMono(stereo);

    // Loop markers from the sequence scripts: the first state that repeats (loopStart..loopEnd is one
    // period); a second period (loopEnd2) gives a steady state loop: the audio of period two already
    // contains everything that rings over from period one.
    let loop = null;
    if (info.loopFound >= 1) {
        const start = info.loopFound === 2 ? info.loopEnd : info.loopStart;
        const rough = info.loopFound === 2 ? info.loopEnd2 : info.loopEnd;
        const end = refineLoopEnd(mono, start, rough, LOOP_END_SEARCH);
        if (rms(mono.subarray(start, end)) > SILENT_RMS) {
            loop = { start, end, steady: info.loopFound === 2 };
        }
    }
    const [first, lastAudible] = audibleRange(mono, 1, TRIM_THRESHOLD);
    const lead = Math.max(0, first - LEAD_MARGIN);
    const end = loop ? loop.end : lastAudible;
    let samples = stereo.slice(lead * 2, end * 2);
    if (loop?.steady && loop.start - lead >= MUSIC_LOOP_CROSSFADE) {
        // The audio before the loop start is the end of the previous period: blend the end of the
        // file into it so that the wrap around has no discontinuity.
        samples = bakeLoopCrossfade(samples, 2, loop.start - lead, loop.end - lead, MUSIC_LOOP_CROSSFADE);
    }
    const entry = { file: `music_${sequence.id}.ogg`, durationMs: exactMs(end - lead), name: sequence.name };
    if (loop) {
        entry.loopStartMs = exactMs(loop.start - lead);
        entry.loopEndMs = exactMs(loop.end - lead);
    }
    const report = {
        player, end: info.end, loopFound: info.loopFound, periodTicks: info.periodTicks, peak: peak(samples),
        rms: Math.round(rms(samples)), preset: presetFor(sequence.id),
    };
    await encodeOgg(samples, 2, path.join(OUT, entry.file), loop ? loop.start - lead : undefined);
    return { sequence, entry, report };
}

// Deletes the files of a section (every file of audio/out is in the one folder, named by its section)
function removeFiles(prefix) {
    for (const name of fs.existsSync(OUT) ? fs.readdirSync(OUT) : []) {
        if (name.startsWith(prefix) && name.endsWith(".ogg")) {
            fs.rmSync(path.join(OUT, name));
        }
    }
}

function loadJson(file, fallback) {
    return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : fallback;
}

async function main() {
    const argv = process.argv.slice(2);
    const flag = (name) => argv.includes(name);
    const filter = argv.includes("--filter") ? new Set(argv[argv.indexOf("--filter") + 1].split(",")) : null;
    const doSfx = flag("--sfx") || !flag("--music");
    const doMusic = flag("--music") || !flag("--sfx");
    if (flag("--clean")) {
        fs.rmSync(BUILD, { recursive: true, force: true });
        fs.rmSync(OUT, { recursive: true, force: true });
    }

    console.log("building sound data and renderer");
    await buildAll();

    const manifestPath = path.join(OUT, "manifest.json");
    const reportPath = path.join(AUDIO, "report.json");
    // A partial run (one section, or a filter) updates the files of the earlier runs.
    const manifest = loadJson(manifestPath, {});
    const report = loadJson(reportPath, {});
    manifest.sfx ??= {};
    manifest.music ??= {};
    manifest.silentSfx = new Set(manifest.silentSfx ?? []);
    report.sfx ??= {};
    report.music ??= {};
    if (doSfx && !filter) {
        removeFiles("sfx_");
        manifest.sfx = {};
        manifest.silentSfx.clear();
        report.sfx = {};
    }
    if (doMusic && !filter) {
        removeFiles("music_");
        manifest.music = {};
        report.music = {};
    }

    if (doSfx) {
        const sounds = parseSounds().filter((s) => !filter || filter.has(s.key));
        console.log(`rendering ${sounds.length} sound effects`);
        const results = await pool(sounds, CONCURRENCY, renderSfx);
        for (const { sound, entry, report: sfxReport, silent } of results) {
            report.sfx[sound.key] = sfxReport;
            if (silent) {
                manifest.silentSfx.add(sound.key);
                delete manifest.sfx[sound.key];
            } else {
                manifest.silentSfx.delete(sound.key);
                manifest.sfx[sound.key] = entry;
            }
        }
    }
    if (doMusic) {
        const sequences = parseSequences();
        const presetFor = parsePresets(sequences);
        const selected = sequences.filter((s) => !filter || filter.has(String(s.id)));
        console.log(`rendering ${selected.length} sequences`);
        const results = await pool(selected, CONCURRENCY, (sequence) => renderMusic(sequence, presetFor));
        for (const { sequence, entry, report: musicReport } of results) {
            manifest.music[sequence.id] = entry;
            report.music[sequence.id] = musicReport;
        }
    }

    const sortKeys = (object, compare) => Object.fromEntries(Object.entries(object).sort(([a], [b]) => compare(a, b)));
    const bySoundKey = (a, b) => {
        const [ab, ai] = a.split("_").map(Number);
        const [bb, bi] = b.split("_").map(Number);
        return ab - bb || ai - bi;
    };
    manifest.sfx = sortKeys(manifest.sfx, bySoundKey);
    manifest.music = sortKeys(manifest.music, (a, b) => Number(a) - Number(b));
    manifest.silentSfx = [...manifest.silentSfx].sort(bySoundKey);
    report.sfx = sortKeys(report.sfx, bySoundKey);
    report.music = sortKeys(report.music, (a, b) => Number(a) - Number(b));
    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`manifest: ${Object.keys(manifest.sfx).length} sfx, ${manifest.silentSfx.length} silent, ${Object.keys(manifest.music).length} music`);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
