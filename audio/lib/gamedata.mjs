// Names and ids from the decomp headers: sounds (include/sounds.h), sequences
// (include/seq_ids.h) and the audio settings preset each level plays its music with.
import fs from "node:fs";
import path from "node:path";

import { REF } from "./paths.mjs";

const SOUND_STATUS_WAITING = 1;
const SOUND_DISCRETE = 0x80;
const SEQ_VARIATION = 0x80;
const TERRAIN_NAMES = ["DEFAULT", "GRASS", "WATER", "STONE", "SPOOKY", "SNOW", "ICE", "SAND"];

function readHeader(relative) {
    return fs.readFileSync(path.join(REF, relative), "utf8");
}

function parseNumber(token, constants) {
    const text = token.trim();
    if (/^(0x[0-9a-f]+|\d+)$/i.test(text)) {
        return Number(text);
    }
    if (!(text in constants)) {
        throw new Error(`unknown constant ${text}`);
    }
    return constants[text];
}

function evaluateOr(expression, constants) {
    return expression
        .split("|")
        .map((part) => parseNumber(part, constants))
        .reduce((a, b) => (a | b) >>> 0, 0);
}

// One entry per distinct (bank, id): the first define in sounds.h names it, later defines of the
// same id (suffix _2 and priority variants) are its aliases. The terrain dependent sounds get the
// seven following ids too (the game adds the terrain type to the id).
export function parseSounds() {
    const source = readHeader("include/sounds.h");
    const constants = {};
    for (const [, name, value] of source.matchAll(/^#define (SOUND_[A-Z0-9_]+)\s+(0x[0-9a-fA-F]+|\d+)\b/gm)) {
        constants[name] = Number(value);
    }
    const sounds = new Map();
    const pattern =
        /^#define (SOUND_[A-Z0-9_]+)\s+(?:\/\*.*?\*\/\s*)?SOUND_ARG_LOAD\((SOUND_BANK_[A-Z0-9_]+),\s*(\w+),\s*(\w+),\s*([^)]*)\)/gm;
    for (const [, name, bankName, idText, priorityText, flagsText] of source.matchAll(pattern)) {
        const bank = parseNumber(bankName, constants);
        const id = parseNumber(idText, constants);
        const priority = parseNumber(priorityText, constants);
        const flags = evaluateOr(flagsText, constants);
        const terrain = /^SOUND_(ACTION|MOVING)_TERRAIN_/.test(name);
        const variants = terrain ? TERRAIN_NAMES.map((t, i) => ({ id: id + i, name: i === 0 ? name : `${name}_${t}` })) : [{ id, name }];
        for (const variant of variants) {
            const key = `${bank}_${variant.id}`;
            const bits = ((bank << 28) | (variant.id << 16) | (priority << 8) | flags | SOUND_STATUS_WAITING) >>> 0;
            const known = sounds.get(key);
            if (known) {
                known.aliases.push(variant.name);
            } else {
                sounds.set(key, { key, name: variant.name, bank, id: variant.id, bits, continuous: (flags & SOUND_DISCRETE) === 0, aliases: [] });
            }
        }
    }
    return [...sounds.values()];
}

// Sequence ids of seq_ids.h, plus the title screen variation the game plays as game over. (The
// power-up sequence, played with the variation bit as shell music, renders identically in the US
// version, so it has no entry of its own.)
export function parseSequences() {
    const source = readHeader("include/seq_ids.h");
    const body = source.match(/enum SeqId \{([\s\S]*?)\};/)[1];
    const sequences = [];
    for (const [, name, hex] of body.matchAll(/^\s*(SEQ_[A-Z0-9_]+),\s*\/\/ 0x([0-9A-Fa-f]+)/gm)) {
        sequences.push({ id: parseInt(hex, 16), name });
    }
    const byName = Object.fromEntries(sequences.map((s) => [s.name, s]));
    const variations = [
        { id: byName.SEQ_MENU_TITLE_SCREEN.id | SEQ_VARIATION, name: "SEQ_MENU_GAME_OVER" },
    ];
    return [...sequences.filter((s) => s.id !== 0), ...variations];
}

// The game starts these on SEQ_PLAYER_ENV (jingles and secondary music: play_course_clear,
// play_puzzle_jingle, play_secondary_music, ...); all other sequences on SEQ_PLAYER_LEVEL.
const ENV_SEQUENCES = [
    "SEQ_EVENT_CUTSCENE_COLLECT_STAR",
    "SEQ_EVENT_PIRANHA_PLANT",
    "SEQ_EVENT_HIGH_SCORE",
    "SEQ_EVENT_MERRY_GO_ROUND",
    "SEQ_EVENT_RACE",
    "SEQ_EVENT_CUTSCENE_STAR_SPAWN",
    "SEQ_EVENT_CUTSCENE_COLLECT_KEY",
    "SEQ_EVENT_ENDLESS_STAIRS",
    "SEQ_EVENT_SOLVE_PUZZLE",
    "SEQ_EVENT_TOAD_MESSAGE",
    "SEQ_EVENT_PEACH_MESSAGE",
];

export function sequencePlayer(sequence) {
    return ENV_SEQUENCES.includes(sequence.name) ? 1 : 0;
}

// Most frequent settingsPreset of SET_BACKGROUND_MUSIC in the level scripts, by sequence id.
export function parsePresets(sequences) {
    const byName = Object.fromEntries(sequences.map((s) => [s.name, s.id]));
    const counts = new Map();
    const levels = path.join(REF, "levels");
    for (const level of fs.readdirSync(levels, { withFileTypes: true })) {
        const script = path.join(levels, level.name, "script.c");
        if (!level.isDirectory() || !fs.existsSync(script)) {
            continue;
        }
        const text = fs.readFileSync(script, "utf8");
        for (const [, preset, seqExpression] of text.matchAll(/SET_BACKGROUND_MUSIC\(\s*\/\*settingsPreset\*\/\s*(0x[0-9a-fA-F]+),\s*\/\*seq\*\/\s*([^)]*\)?)\)/g)) {
            const names = seqExpression.replace(/[()]/g, "").split("|").map((n) => n.trim());
            const id = names.reduce((acc, n) => acc | (n === "SEQ_VARIATION" ? SEQ_VARIATION : byName[n] ?? 0), 0);
            const key = `${id}:${Number(preset)}`;
            counts.set(key, (counts.get(key) ?? 0) + 1);
        }
    }
    const best = new Map();
    for (const [key, count] of counts) {
        const [id, preset] = key.split(":").map(Number);
        if (!best.has(id) || best.get(id).count < count) {
            best.set(id, { preset, count });
        }
    }
    return (id) => best.get(id)?.preset ?? 0;
}
