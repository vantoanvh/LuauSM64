// The game's audio engine (wasm/engine.js, built from audio/native by audio/build.mjs) as a function: one sound effect or one music sequence in,
// its PCM and a description of the render out. Every render runs on a fresh instance: the engine's state is not reset.

import SoundEngine from "./wasm/engine.js";

// The doubles of audio_info (the InfoField enum of audio/native/host.c)
const INFO_END = 0;
const INFO_FRAMES = 1;
const INFO_LOOP_FOUND = 2;
const INFO_LOOP_START = 3;
const INFO_LOOP_END = 4;
const INFO_LOOP_END2 = 5;
const INFO_PERIOD_TICKS = 6;

// How a render ended (the RenderEnd enum): at the time cap, in silence, without ever being audible, at the second loop of a sequence, or
// at its end
const ENDS = ["cap", "silence", "never-audible", "loop", "ended"];

// The buffers of audio_buffer, in order
const BUFFERS = ["ctl", "tbl", "sequences", "bankSets"];

async function start(data) {
  const engine = await SoundEngine();

  BUFFERS.forEach((name, which) => {
    engine.HEAPU8.set(data[name], engine._audio_buffer(which));
  });
  engine._audio_start();

  return engine;
}

// The interleaved stereo PCM of the render and what it reports
function result(engine) {
  const info = new Float64Array(engine.HEAPU8.buffer, engine._audio_info(), 8);
  const frames = info[INFO_FRAMES];
  const pcm = new Int16Array(engine.HEAPU8.buffer, engine._audio_pcm(), frames * 2).slice();

  return {
    pcm,
    end: ENDS[info[INFO_END]],
    loopFound: info[INFO_LOOP_FOUND],
    loopStart: info[INFO_LOOP_START],
    loopEnd: info[INFO_LOOP_END],
    loopEnd2: info[INFO_LOOP_END2],
    periodTicks: info[INFO_PERIOD_TICKS],
  };
}

// Plays a sound effect on its own (soundBits as the game builds them); hold requests it every frame, as the game does for a continuous one
export async function renderSfx(data, soundBits, hold, maxSeconds) {
  const engine = await start(data);

  engine._audio_render_sfx(soundBits, hold ? 1 : 0, maxSeconds);

  return result(engine);
}

// Plays a sequence on its own, on a sequence player, with the audio settings preset of its level
export async function renderMusic(data, player, sequenceArguments, preset, maxSeconds) {
  const engine = await start(data);

  engine._audio_render_music(player, sequenceArguments, preset, maxSeconds);

  return result(engine);
}
