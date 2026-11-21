// A sound effect or a music sequence of the game as the clip the game plays: rendered by the engine, cut where it is audible, with the loop
// of a sound that repeats found and its seam smoothed. The numbers are those of the loop detection of the engine (host.c) and of the
// listening tests of the first version of this tool.

import { renderMusic, renderSfx } from "./renderer.js";
import { SAMPLE_RATE, audibleRange, bakeLoopCrossfade, findSteadyLoop, refineLoopEnd, rms, toMono } from "./analysis.js";

const SFX_CAP_SECONDS = 10;
// a loop of 90 s with a second period must fit
const MUSIC_CAP_SECONDS = 200;
const MUSIC_PRIORITY = 4;
// peak amplitude (of 32767) below which the start and end are cut
const TRIM_THRESHOLD = 16;
// samples kept before the first audible one
const LEAD_MARGIN = 64;
// 40 ms and 30 ms
const SFX_LOOP_CROSSFADE = 1280;
const MUSIC_LOOP_CROSSFADE = 960;
// samples: sequence ticks happen at update granularity (133 samples)
const LOOP_END_SEARCH = 300;
const SILENT_RMS = 8;

// Times are exact: 32 samples per ms, so a sample position is a multiple of 1/32 ms
const exactMs = (samples) => (samples * 1000) / SAMPLE_RATE;

// A sound effect: { key, silent: true } for one that makes no sound, else { key, samples (mono), entry } where the entry is
// { name, loop, durationMs, loopStartMs?, loopEndMs? }
export async function makeSfx(data, sound) {
  const render = await renderSfx(data, sound.bits, sound.continuous, SFX_CAP_SECONDS);
  const mono = toMono(render.pcm);
  const [first, last] = audibleRange(mono, 1, TRIM_THRESHOLD);

  if (last - first < SAMPLE_RATE / 100) {
    return { key: sound.key, silent: true };
  }

  let samples = mono.subarray(Math.max(0, first - LEAD_MARGIN), last);
  const entry = { name: sound.name, loop: false };

  // still sounding when the render stopped: a loop (a sustained note, a looping script)
  if (render.end === "cap") {
    const loop = findSteadyLoop(samples);

    samples = bakeLoopCrossfade(samples, 1, loop.start, loop.end, SFX_LOOP_CROSSFADE);
    entry.loop = true;
    entry.loopStartMs = exactMs(loop.start);
    entry.loopEndMs = exactMs(loop.end);
  }

  entry.durationMs = exactMs(samples.length);

  return { key: sound.key, samples, entry };
}

// A music sequence: { id, samples (stereo), entry } where the entry is { name, durationMs, loopStartMs?, loopEndMs? } and loopStart the
// sample the music loops back to (in the samples), if it loops
export async function makeMusic(data, sequence) {
  const render = await renderMusic(data, sequence.player, (MUSIC_PRIORITY << 8) | sequence.id, sequence.preset, MUSIC_CAP_SECONDS);
  const stereo = render.pcm;
  const mono = toMono(stereo);

  // Loop markers from the sequence scripts: the first state that repeats (loopStart..loopEnd is one period); a second period (loopEnd2)
  // gives a steady state loop: the audio of period two already contains everything that rings over from period one.
  let loop = null;

  if (render.loopFound >= 1) {
    const start = render.loopFound === 2 ? render.loopEnd : render.loopStart;
    const rough = render.loopFound === 2 ? render.loopEnd2 : render.loopEnd;
    const end = refineLoopEnd(mono, start, rough, LOOP_END_SEARCH);

    if (rms(mono.subarray(start, end)) > SILENT_RMS) {
      loop = { start, end, steady: render.loopFound === 2 };
    }
  }

  const [first, lastAudible] = audibleRange(mono, 1, TRIM_THRESHOLD);
  const lead = Math.max(0, first - LEAD_MARGIN);
  const end = loop ? loop.end : lastAudible;
  let samples = stereo.slice(lead * 2, end * 2);

  if (loop?.steady && loop.start - lead >= MUSIC_LOOP_CROSSFADE) {
    // The audio before the loop start is the end of the previous period: blend the end of the file into it so that the wrap around has no
    // discontinuity.
    samples = bakeLoopCrossfade(samples, 2, loop.start - lead, loop.end - lead, MUSIC_LOOP_CROSSFADE);
  }

  const entry = { name: sequence.name, durationMs: exactMs(end - lead) };

  if (loop) {
    entry.loopStartMs = exactMs(loop.start - lead);
    entry.loopEndMs = exactMs(loop.end - lead);
  }

  return { id: sequence.id, samples, entry };
}
