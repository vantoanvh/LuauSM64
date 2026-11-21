// The jobs of the sound generator, each a function of its description to its result. They run in a worker of the page (worker.js), one worker
// per core, so that the 500 or so sounds render in parallel; every job is independent.

import { makeMusic, makeSfx } from "./clips.js";
import { encode } from "./vorbis.js";

// -q:a 5 of ffmpeg's libvorbis for the music, 8 for the atlases of sound effects
const MUSIC_QUALITY = 0.5;
const ATLAS_QUALITY = 0.8;

// The sound data of the ROM (sound/rom-data.js), set by the first message to a worker
let data = null;

export function setData(soundData) {
  data = soundData;
}

// { type: "sfx", sound } -> makeSfx; { type: "music", sequence } -> { id, entry, ogg }; { type: "atlas", samples } -> { ogg }
export async function run(job) {
  switch (job.type) {
    case "sfx":
      return makeSfx(data, job.sound);
    case "music": {
      const { id, samples, entry } = await makeMusic(data, job.sequence);

      return { id, entry, ogg: await encode(samples, 2, MUSIC_QUALITY) };
    }
    case "atlas":
      return { ogg: await encode(job.samples, 1, ATLAS_QUALITY) };
    default:
      throw new Error(`Unknown sound job ${job.type}.`);
  }
}
