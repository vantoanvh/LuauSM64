// Makes the sound files of the game from its ROM: every sound effect and music sequence rendered by the game's own audio engine, the sound
// effects packed in atlases, as a ZIP of the files ready for Studio's importer (roblox/tools/ImportAudio.luau): the atlases, the music and
// sfx-atlas.json, the list of every sound with where it is in the files and where it loops.

import { SEQUENCES, SOUNDS } from "./tables.js";
import { index, pack } from "./atlas.js";
import { soundData } from "./rom-data.js";
import { zip } from "./zip.js";

// Runs the jobs and gives their results in order; progress is told of each one that finishes
async function runAll(run, jobs, progress) {
  let done = 0;

  return Promise.all(
    jobs.map(async (job) => {
      const result = await run(job);

      progress(++done, jobs.length);

      return result;
    }),
  );
}

// The sound data of a ROM (rom-data.js), for the workers
export { soundData };

// The sound files: { zip, manifest } where zip is the ZIP (a Blob) and manifest the content of its sfx-atlas.json. run(job) does a job of
// jobs.js somewhere (the pool of workers of the page); progress(phase, done, total) says how far it is.
export async function generate(run, progress) {
  const effects = await runAll(run, SOUNDS.map((sound) => ({ type: "sfx", sound })), (done, total) => progress("Sound effects", done, total));
  const music = await runAll(run, SEQUENCES.map((sequence) => ({ type: "music", sequence })), (done, total) => progress("Music", done, total));
  const clips = effects.filter((effect) => !effect.silent);
  const silent = effects.filter((effect) => effect.silent).map((effect) => effect.key);

  const atlases = pack(clips);
  const encoded = await runAll(run, atlases.map(({ samples }) => ({ type: "atlas", samples })), (done, total) => progress("Atlases", done, total));
  const atlasFiles = atlases.map(({ file }, number) => ({ name: file, bytes: encoded[number].ogg }));
  const musicFiles = music.map(({ id, ogg }) => ({ name: `music_${id}.ogg`, bytes: ogg }));
  const manifest = index(atlases, atlasFiles, silent, music.map(({ id, entry }) => ({ id, entry, file: `music_${id}.ogg` })));

  const manifestFile = { name: "sfx-atlas.json", bytes: new TextEncoder().encode(`${JSON.stringify(manifest, null, 2)}\n`) };

  return { zip: zip([...atlasFiles, ...musicFiles, manifestFile]), manifest };
}
