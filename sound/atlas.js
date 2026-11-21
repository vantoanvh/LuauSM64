// The sound effects as the atlases the game plays: every sound effect one after the other in a few long mono Ogg files, 2 seconds of silence
// after each, and the index (sfx-atlas.json) that says where each one is. A long file is one asset to upload, not 475.

import { SAMPLE_RATE } from "./analysis.js";

export const GAP_MS = 2000;
// an atlas is at most 7 minutes
const DURATION_LIMIT = 7 * 60 * SAMPLE_RATE;
const GAP_FRAMES = (GAP_MS * SAMPLE_RATE) / 1000;
const toFrames = (ms) => Math.round((ms * SAMPLE_RATE) / 1000);
const toMs = (frames) => (frames * 1000) / SAMPLE_RATE;

// "<bank>_<id>" keys in the order of the game's sound banks
function byKey([first], [second]) {
  const [firstBank, firstId] = first.split("_").map(Number);
  const [secondBank, secondId] = second.split("_").map(Number);

  return firstBank - secondBank || firstId - secondId;
}

// The clips ({ key, samples, entry }) laid out in atlases, in the order of their keys: [{ file, samples, clips: [{ key, entry, start }] }]
export function pack(clips) {
  const atlases = [];
  let current = { frames: 0, clips: [] };

  const close = () => {
    const samples = new Int16Array(current.frames);

    for (const { clip, start } of current.clips) {
      samples.set(clip.samples, start);
    }

    atlases.push({ file: `sfx_atlas_${String(atlases.length + 1).padStart(2, "0")}.ogg`, samples, clips: current.clips });
    current = { frames: 0, clips: [] };
  };

  for (const clip of [...clips].sort((first, second) => byKey([first.key], [second.key]))) {
    const required = clip.samples.length + GAP_FRAMES;

    if (current.frames + required >= DURATION_LIMIT) {
      close();
    }

    current.clips.push({ clip, start: current.frames });
    current.frames += required;
  }

  close();

  return atlases.map(({ file, samples, clips: placed }) => ({
    file,
    samples,
    clips: placed.map(({ clip, start }) => ({ key: clip.key, entry: clip.entry, start })),
  }));
}

// The index of the atlases (atlasFiles are their Ogg files, in order: { bytes }), the sound effects that make no sound and the music ({ id, entry, file })
export function index(atlases, atlasFiles, silent, music) {
  const sfx = {};

  atlases.forEach(({ file, clips }) => {
    for (const { key, entry, start } of clips) {
      const clip = { file, name: entry.name, startMs: toMs(start), endMs: toMs(start + toFrames(entry.durationMs)) };

      if (entry.loop) {
        clip.loopStartMs = toMs(start + toFrames(entry.loopStartMs));
        clip.loopEndMs = toMs(start + toFrames(entry.loopEndMs));
      }

      sfx[key] = clip;
    }
  });

  const tracks = {};

  for (const { id, entry, file } of [...music].sort((a, b) => a.id - b.id)) {
    tracks[id] = { file, ...entry };
  }

  return {
    sampleRate: SAMPLE_RATE,
    gapMs: GAP_MS,
    atlases: atlases.map(({ file, samples, clips }, number) => ({ file, durationMs: toMs(samples.length), bytes: atlasFiles[number].bytes.length, clips: clips.length })),
    sfx: Object.fromEntries(Object.entries(sfx).sort(byKey)),
    silentSfx: [...silent].sort((a, b) => byKey([a], [b])),
    music: tracks,
  };
}
