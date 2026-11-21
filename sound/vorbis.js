// Ogg Vorbis files from PCM, by libvorbis (wasm/vorbis.js is built from audio/native/vorbis.c by audio/build.mjs).

import VorbisEncoder from "./wasm/vorbis.js";

const SAMPLE_RATE = 32000;

let instance = null;

// Interleaved s16 PCM at 32 kHz as an Ogg Vorbis file; quality from 0 to 1 (0.5 and 0.8 are the -q:a 5 and 8 of ffmpeg's libvorbis)
export async function encode(samples, channels, quality) {
  instance ??= await VorbisEncoder();

  const frames = samples.length / channels;
  const input = instance._vorbis_input(frames, channels);

  // the heap is read through a fresh view: the input call may have grown it
  new Int16Array(instance.HEAPU8.buffer, input, samples.length).set(samples);

  const size = instance._vorbis_encode(frames, channels, SAMPLE_RATE, quality);

  if (size === 0) {
    throw new Error("The Vorbis encoder could not start.");
  }

  return instance.HEAPU8.slice(instance._vorbis_output(), instance._vorbis_output() + size);
}
