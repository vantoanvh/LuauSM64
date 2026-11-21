# Audio

Roblox cannot synthesize audio at runtime, so the sound of the game is rendered once from your own ROM and imported into Studio as files.
The rendering runs in the page of `rom-tool/` (nothing to install, nothing uploaded): it renders every sound effect and every music
sequence with **the game's own audio engine**, compiled to WebAssembly, and gives a ZIP of Ogg Vorbis files and the list of them.

This folder holds what the page is built from; the page itself, and the JavaScript that drives the engine, are in `rom-tool/sound/`.

## What is here

* `native/`: the host of the engine (`host.c`: libultra, game state and audio interface stubs; runs frames the way `thread4_sound` and the
  game loop do, including the audio interface feedback that sizes each frame's buffer), `mixer.c` (the microcode commands: VADPCM decode,
  resampler, envelope mixer, mixer; from the sm64-port / sm64ex mixer, scalar variant), `synthesis_hle.c` (the game's `synthesis.c` with the
  `aXxx` command macros redirected to `mixer.c`, so commands run at once instead of being queued for the RSP) and `vorbis.c` (the Ogg Vorbis
  encoder, libvorbis).
* `build.mjs`: builds `rom-tool/sound/wasm/engine.js` (the decomp's `src/audio` unmodified plus `native/`) and `rom-tool/sound/wasm/vorbis.js`.
  Needs the Emscripten SDK (`emcc` on `PATH`, or `EMCC`) and the decompilation checked out in `reference/`. The two modules are committed: only
  a change of `native/` needs this.
* `tables.mjs`: writes `rom-tool/sound/tables.js`, the names, ids and settings of the sounds that are not in the ROM's sound data (from
  `include/sounds.h`, `include/seq_ids.h` and the level scripts of `reference/`). Committed too.

## How a sound is made

1. **The data.** The sound data of the ROM (banks, samples, sequences, bank sets: `rom-tool/sm64-rom.js` says where) is the data the game itself
   loads. `sound/rom-data.js` swaps its numbers to little endian (what the decomp's PC build assembles with `--endian little --bitwidth 32`; the
   result is byte for byte what `tools/assemble_sound.py` makes from the sources).
2. **The engine.** A fresh instance of the engine per sound (its state is not reset): `sound_reset`, then for a sound effect
   `play_sound(bits, gGlobalSoundSource)` like the game, every frame pair being one game frame (`audio_signal_game_loop_tick`). The listener is
   at the sound position, so volume is full and pan centered; the level has no reverb preset, so the sound carries only the reverb its own script
   asks for. Rendering stops after 1.5 s of silence or at 10 s. A continuous sound (no `SOUND_DISCRETE` flag) is requested every game frame, as
   the game does, while the engine reports it playing. A sound still playing at 10 s is a loop (a sustained note or a script that repeats).
   Music: `sound_reset(preset)` with the preset the level scripts use for that sequence (`SET_BACKGROUND_MUSIC`), then `play_music` on
   `SEQ_PLAYER_LEVEL`, or `SEQ_PLAYER_ENV` for the jingles and secondary music the game starts there. Rendering ends when the sequence ends (and
   is silent), at its second loop, or at 200 s.
3. **Loops of sequences** are detected from the scripts: after every tick of the sequence player's tempo clock the host hashes the state of the
   player, all channels and all layers (program counters, stacks, delays, instrument, volume, pan...). The first state that repeats is the loop
   start; the repeat is one period later. The second period is rendered too when it fits in 200 s: the audio of the second period already
   contains what rings over from the first, so the loop is steady state.
4. **The clip** (`sound/clips.js`): cut where it is audible (start at the first sample above 16 of 32767, end at the last), the loop of a sound
   effect that never ends found by autocorrelation and refined to the sample where the seam is quietest, and a baked linear crossfade of 40 ms
   (effects) or 30 ms (music) at the end of the loop, so that wrapping at the loop end has no discontinuity.
5. **The files** (`sound/atlas.js`, `sound/generate.js`): the sound effects one after the other, 2 s of silence after each, in mono atlases of at
   most 7 minutes (a few long files are a few assets to upload, not 475); the music one file per sequence, in stereo. All at 32 kHz, Vorbis
   quality 8 for the atlases and 5 for the music.

The page checks nothing against a native build. The first version of this tool did (a native build of the same engine with the same data in 64
bits): the 477 sound effects and 35 sequences came out sample for sample the same, so the WebAssembly build of the engine and the data of
`rom-data.js` are exact.

## Output

`SM64Sound.zip`, about 50 MB: `sfx_atlas_01.ogg` ... (4 atlases), `music_<seqId>.ogg` (35: the sequence ids of `seq_ids.h`, plus `130`, the title
screen sequence with the variation bit: game over; the power-up sequence with the variation bit renders identically to `14` in the US version and
has no file), and `sfx-atlas.json`, the list of every sound:

```json
{
  "sampleRate": 32000, "gapMs": 2000,
  "atlases": [{ "file": "sfx_atlas_01.ogg", "durationMs": 419278.5, "bytes": 1639333, "clips": 154 }],
  "sfx": { "3_17": { "file": "sfx_atlas_02.ogg", "name": "SOUND_GENERAL_COIN", "startMs": 129818.15625, "endMs": 130807.78125 },
           "4_0":  { "file": "sfx_atlas_02.ogg", "name": "SOUND_ENV_WATERFALL1", "startMs": 386035.34375, "endMs": 387475.0625,
                     "loopStartMs": 386580.46875, "loopEndMs": 387475.0625 } },
  "silentSfx": ["5_95", "7_16"],
  "music": { "3": { "file": "music_3.ogg", "durationMs": 140183.3125, "name": "SEQ_LEVEL_GRASS", "loopStartMs": 72215.5625, "loopEndMs": 140183.3125 } }
}
```

The key of a sound effect is `<bank>_<id>`, `bank = soundBits >> 28`, `id = (soundBits >> 16) & 0xFF` (decimal). All times are exact (32 samples
per ms). `loopStartMs` and `loopEndMs` mark the region to repeat; a sound without them is a one-shot (music: a stinger, or a sequence still
running at the cap, `26` credits). The terrain dependent sounds (`SOUND_ACTION_TERRAIN_*`, `SOUND_MOVING_TERRAIN_*`) have one entry per
terrain, `<name>_GRASS` etc. (id + terrain type). `silentSfx` are effects that produce no sound in the engine (unused ids).

Unzip it and run `roblox/tools/ImportAudio.luau` in Studio's command bar, selecting every file.

## Gaps

* Effects flagged continuous loop at their script period when the engine keeps them alive; the loop region of noisy effects (wind, water) has a
  low autocorrelation and relies on the crossfade.
* Effects whose sound depends on game state at play time (distance, speed of `SOUND_BANK_MOVING` sounds, level reverb) are rendered at the
  listener, full volume, no level reverb.
* Fidelity to hardware is that of the HLE mixer (a few least significant bits of the microcode may differ); the sequence, note, envelope and
  reverb logic is the original code.
