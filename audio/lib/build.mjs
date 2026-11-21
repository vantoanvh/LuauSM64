// Builds everything the renderer needs under audio/build: the ADPCM tools, the sound data in the
// host layout (little endian, 64-bit pointers: what the decomp's own PC build assembles) and the
// native renderer (the real decomp audio engine plus a host, see audio/native).
import { execFile } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

import { BUILD, NATIVE, REF, ROM } from "./paths.mjs";

const execFileAsync = promisify(execFile);

export const RENDERER = path.join(BUILD, "audio_render.exe");
export const DATA_DIR = BUILD;

const MINGW_BIN = "C:/Tools/WinLibs/mingw64/bin";

export async function run(command, args, options = {}) {
    try {
        return await execFileAsync(command, args, { maxBuffer: 1 << 28, windowsHide: true, ...options });
    } catch (error) {
        throw new Error(`${command} ${args.join(" ")} failed:\n${error.stderr || error.stdout || error.message}`);
    }
}

// Runs fn over items with at most `limit` in flight.
export async function pool(items, limit, fn) {
    const results = new Array(items.length);
    let next = 0;
    const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
        while (next < items.length) {
            const index = next++;
            results[index] = await fn(items[index], index);
        }
    });
    await Promise.all(workers);
    return results;
}

export const CONCURRENCY = Math.max(1, Math.min(8, os.cpus().length));

function newerThan(target, sources) {
    if (!fs.existsSync(target)) {
        return false;
    }
    const time = fs.statSync(target).mtimeMs;
    return sources.every((source) => fs.statSync(source).mtimeMs <= time);
}

function compiler() {
    if (process.env.CC) {
        return process.env.CC;
    }
    const local = path.join(MINGW_BIN, "gcc.exe");
    return fs.existsSync(local) ? local : "gcc";
}

function python() {
    return process.env.PYTHON || "python";
}

async function buildTools() {
    const tools = path.join(BUILD, "tools");
    fs.mkdirSync(tools, { recursive: true });
    const cc = compiler();
    const toolsDir = path.join(REF, "tools");
    const codebook = path.join(tools, "aiff_extract_codebook.exe");
    const encoder = path.join(tools, "vadpcm_enc.exe");
    if (!fs.existsSync(codebook)) {
        await run(cc, ["-O2", "-w", "-I", toolsDir, path.join(toolsDir, "aiff_extract_codebook.c"), "-o", codebook, "-lm"]);
    }
    if (!fs.existsSync(encoder)) {
        const adpcm = path.join(toolsDir, "sdk-tools", "adpcm");
        const sources = ["vadpcm_enc.c", "vpredictor.c", "quant.c", "util.c", "vencode.c"].map((f) => path.join(adpcm, f));
        await run(cc, ["-O2", "-w", "-I", toolsDir, ...sources, "-o", encoder, "-lm"]);
    }
    return { codebook, encoder };
}

// sound/samples/<bank>/<name>.aiff -> build/sound/samples/<bank>/<name>.aifc (VADPCM, as the
// decomp Makefile does).
async function buildSampleAifcs() {
    const { codebook, encoder } = await buildTools();
    const samplesDir = path.join(REF, "sound", "samples");
    if (!fs.existsSync(samplesDir)) {
        throw new Error("reference/sound/samples is missing: run extract_assets.py us in reference/ first");
    }
    const jobs = [];
    for (const bank of fs.readdirSync(samplesDir)) {
        for (const file of fs.readdirSync(path.join(samplesDir, bank))) {
            if (file.endsWith(".aiff")) {
                jobs.push({ bank, name: file.slice(0, -5) });
            }
        }
    }
    await pool(jobs, CONCURRENCY, async ({ bank, name }) => {
        const aiff = path.join(samplesDir, bank, `${name}.aiff`);
        const outDir = path.join(BUILD, "sound", "samples", bank);
        const table = path.join(outDir, `${name}.table`);
        const aifc = path.join(outDir, `${name}.aifc`);
        if (newerThan(aifc, [aiff])) {
            return;
        }
        fs.mkdirSync(outDir, { recursive: true });
        const { stdout } = await run(codebook, [aiff], { encoding: "buffer" });
        fs.writeFileSync(table, stdout);
        await run(encoder, ["-c", table, aiff, aifc]);
    });
}

// The sound player sequence is assembly in the repository (needs a MIPS assembler); it is in the
// ROM, in the sequence archive at 0x7B0860: s16 revision, s16 count, then (offset, length) pairs.
function extractSoundPlayerSequence(target) {
    const SEQUENCE_ARCHIVE = 0x7b0860;
    if (!fs.existsSync(ROM)) {
        throw new Error(`${ROM} is missing`);
    }
    const rom = fs.readFileSync(ROM);
    if (rom.readUInt16BE(SEQUENCE_ARCHIVE) !== 3 || rom.readUInt16BE(SEQUENCE_ARCHIVE + 2) !== 35) {
        throw new Error("rom/baserom.us.z64 is not the US ROM (sequence archive header mismatch)");
    }
    const offset = rom.readUInt32BE(SEQUENCE_ARCHIVE + 4);
    const length = rom.readUInt32BE(SEQUENCE_ARCHIVE + 8);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, rom.subarray(SEQUENCE_ARCHIVE + offset, SEQUENCE_ARCHIVE + offset + length));
}

async function buildSoundData() {
    const outputs = ["sound_data.ctl", "sound_data.tbl", "sequences.bin", "bank_sets"].map((f) => path.join(BUILD, f));
    const sources = fs.readdirSync(path.join(REF, "sound", "sound_banks")).map((f) => path.join(REF, "sound", "sound_banks", f));
    sources.push(path.join(REF, "sound", "sequences.json"), path.join(REF, "tools", "assemble_sound.py"), ROM);
    if (outputs.every((output) => newerThan(output, sources))) {
        return;
    }
    await buildSampleAifcs();
    const assemble = path.join(REF, "tools", "assemble_sound.py");
    const layout = ["-DVERSION_US=1", "--endian", "little", "--bitwidth", "64"];
    await run(python(), [
        "-W", "ignore", assemble, path.join(BUILD, "sound", "samples") + "/", path.join(REF, "sound", "sound_banks") + "/",
        path.join(BUILD, "sound_data.ctl"), path.join(BUILD, "ctl_header"), path.join(BUILD, "sound_data.tbl"),
        path.join(BUILD, "tbl_header"), ...layout,
    ]);

    const soundPlayer = path.join(BUILD, "seq", "00_sound_player.m64");
    extractSoundPlayerSequence(soundPlayer);
    const sequencesDir = path.join(REF, "sound", "sequences", "us");
    const sequences = fs.readdirSync(sequencesDir).filter((f) => f.endsWith(".m64")).sort().map((f) => path.join(sequencesDir, f));
    await run(python(), [
        "-W", "ignore", assemble, "--sequences", path.join(BUILD, "sequences.bin"), path.join(BUILD, "sequences_header"),
        path.join(BUILD, "bank_sets"), path.join(REF, "sound", "sound_banks") + "/", path.join(REF, "sound", "sequences.json"),
        soundPlayer, ...sequences, ...layout,
    ]);
}

// The decomp audio engine, unmodified, plus the host (host.c), the microcode commands (mixer.c)
// and synthesis.c compiled through synthesis_hle.c. -D_OS_H_ drops PR/os.h, whose prototypes
// clash with the ones of ultra64.h on a non N64 build.
async function buildRenderer() {
    const cc = compiler();
    const hostSources = ["host.c", "mixer.c", "synthesis_hle.c", "host.h", "mixer.h"].map((f) => path.join(NATIVE, f));
    if (newerThan(RENDERER, hostSources)) {
        return;
    }
    const objDir = path.join(BUILD, "obj");
    fs.mkdirSync(objDir, { recursive: true });
    const flags = [
        "-std=gnu90", "-O2", "-fsigned-char", "-fno-strict-aliasing", "-fwrapv", "-ffp-contract=off", "-fcommon", "-w",
        "-D_OS_H_", "-DVERSION_US=1", "-DNON_MATCHING=1", "-DAVOID_UB=1", "-D_FINALROM=1", "-D_LANGUAGE_C",
        "-DNO_SEGMENTED_MEMORY", `-I${REF}/include`, `-I${REF}/src`, `-I${REF}`, `-I${NATIVE}`,
        `-I${REF}/lib`, `-I${REF}/lib/include`,
    ];
    const units = [
        ...["data", "effects", "external", "heap", "load", "playback", "seqplayer"].map((n) => path.join(REF, "src", "audio", `${n}.c`)),
        path.join(REF, "lib", "src", "alBnkfNew.c"),
        ...["host", "mixer", "synthesis_hle"].map((n) => path.join(NATIVE, `${n}.c`)),
    ];
    const objects = units.map((unit) => path.join(objDir, `${path.basename(unit, ".c")}.o`));
    await pool(units, CONCURRENCY, (unit, i) => run(cc, ["-c", ...flags, "-o", objects[i], unit]));
    await run(cc, ["-o", RENDERER, ...objects, "-lm"]);
}

export async function buildAll() {
    await buildSoundData();
    await buildRenderer();
}
