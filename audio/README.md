# Audio renderer

Offline tool that renders every sound effect and every music sequence of Super Mario 64 (US) to Ogg
Vorbis files for a Roblox client to play (Roblox cannot synthesize audio at runtime). The sound is
produced by the game's own audio engine (`reference/src/audio/{data,effects,external,heap,load,playback,seqplayer}.c`
and `synthesis.c`, unmodified), compiled natively and driven by a small host.

## Run

```sh
node audio/render.mjs        # builds, renders everything, writes audio/out/
node audio/verify.mjs        # decodes every file and checks it against the manifest
```

`node audio/render.mjs --sfx` or `--music` renders one section; `--filter 3_17,2_0` (sfx keys) or
`--filter 3,130` (sequence ids) re-renders only those and updates the manifest; `--clean` deletes
`audio/build/` and `audio/out/` first. A full clean run takes about 35 s on 8 cores (data build 25 s,
renderer 5 s, 477 effects 20 s, 35 sequences 10 s); a repeat run skips the build.

Needs: Node 18+, `ffmpeg` with libvorbis on `PATH`, gcc (`CC` env var, default
`C:/Tools/WinLibs/mingw64/bin/gcc.exe`, else `gcc` on `PATH`), Python 3 (`PYTHON` env var, default
`python`), `reference/` with the extracted assets (`sound/samples/*/*.aiff`,
`sound/sequences/us/*.m64`: `python extract_assets.py us` there) and `rom/baserom.us.z64`
(only for the sound player sequence, see below).

## How it works

* `lib/build.mjs` builds into `audio/build/` (git-ignored): the ADPCM tools of the decomp, the sample
  `.aifc` files, then `tools/assemble_sound.py --endian little --bitwidth 64` assembles the sound data
  in the host layout (what the decomp's PC build uses), and the renderer `audio_render.exe`. The
  assembled ADPCM data is byte identical to the ROM's. Sequence 0 (sound player) is assembly in the
  repository (needs a MIPS assembler), so it is cut out of the ROM's sequence archive at 0x7B0860.
* `native/`: the host (`host.c`: libultra, game state and audio interface stubs; loads the data; runs
  frames the way `thread4_sound` and the game loop do, including the audio interface feedback that
  sizes each frame's buffer), `mixer.c` (the microcode commands: VADPCM decode, resampler, envelope
  mixer, mixer; from the sm64-port / sm64ex mixer, scalar variant) and `synthesis_hle.c` (the game's
  `synthesis.c` with the `aXxx` command macros redirected to `mixer.c`, so commands run at once instead
  of being queued for the RSP).
* Sound effects: the host calls `sound_reset(0)` (a level load), then `play_sound(bits, gGlobalSoundSource)`
  like the game; every frame pair is one game frame (`audio_signal_game_loop_tick`). The listener is at
  the sound position, so volume is full and pan centered; the level has no reverb preset, so the sound
  carries only the reverb its own script asks for. Rendering stops after 1.5 s of silence or at 10 s.
  A continuous sound (no `SOUND_DISCRETE` flag) is requested every game frame, as the game does, while
  the engine reports it playing. A sound still playing at 10 s is a loop (sustained note or a script
  that repeats).
* Music: `sound_reset(preset)` with the preset the level scripts use for that sequence
  (`SET_BACKGROUND_MUSIC`), then `play_music` on `SEQ_PLAYER_LEVEL`, or `SEQ_PLAYER_ENV` for the
  jingles and secondary music the game starts there. Rendering ends when the sequence ends (and is
  silent), at its second loop, or at 200 s.
* Sequence loops are detected from the scripts: after every tick of the sequence player's tempo clock
  the host hashes the state of the player, all channels and all layers (program counters, stacks,
  delays, instrument, volume, pan...). The first state that repeats is the loop start; the repeat is one
  period later. The second period is rendered too when it fits in 200 s: the audio of the second
  period already contains what rings over from the first, so the loop is steady state.

## Output

`audio/out/` (git-ignored, 51 MB, 475 + 35 files):

* `sfx_<bank>_<id>.ogg`: mono, 32 kHz, `bank = soundBits >> 28`, `id = (soundBits >> 16) & 0xFF`
  (decimal). Starts at the first audible sample, ends at the last one above -66 dB (one-shots).
* `music_<seqId>.ogg`: stereo, 32 kHz, decimal sequence id of `seq_ids.h`, plus `130`
  (`SEQ_MENU_TITLE_SCREEN | SEQ_VARIATION`, game over). The power-up sequence with the variation bit
  (shell music) renders identically to `14` in the US version and has no file.
* `manifest.json`:

```json
{
  "sfx": { "3_17": { "file": "sfx_3_17.ogg", "durationMs": 989.625, "loop": false, "name": "SOUND_GENERAL_COIN" },
           "4_0":  { "file": "sfx_4_0.ogg", "durationMs": 1439.71875, "loop": true,
                     "loopStartMs": 545.125, "loopEndMs": 1439.71875, "name": "SOUND_ENV_WATERFALL1" } },
  "music": { "3": { "file": "music_3.ogg", "durationMs": 140183.3125, "loopStartMs": 72215.5625,
                    "loopEndMs": 140183.3125, "name": "SEQ_LEVEL_GRASS" } },
  "silentSfx": ["5_95", "7_16"]
}
```

  All times are exact (32 samples per ms). `loopStartMs`/`loopEndMs` mark the region to repeat; the file
  holds the lead-in up to `loopStartMs`, then the region, and ends at `loopEndMs` (plus a few ms of
  encoder padding, which a client never plays when it wraps at `loopEndMs`). A sound without loop
  markers is a one-shot (music: a stinger, or a sequence still running at the cap, `26` credits).
  `aliases` lists further `sounds.h` names of the same id. The terrain dependent sounds
  (`SOUND_ACTION_TERRAIN_*`, `SOUND_MOVING_TERRAIN_*`) have one entry per terrain, `<name>_GRASS` etc.
  (id + terrain type). `silentSfx` are effects that produce no sound in the engine (unused ids).
* A baked 40 ms (sfx) / 30 ms (music) linear crossfade at the end of a loop region makes the wrap
  continuous: the last samples already blend into the audio before `loopStartMs`. Music loops with a
  second period are steady state; the few that only fit once (`loopStartMs` is then the first state
  that repeats) have a slightly different lead-in than the end.
* `audio/report.json` (beside out/, not in it): diagnostics per file (render end reason, peak, rms, dominant frequency, loop
  correlation, sequence player, settings preset, tick period).

## Gaps

* Effects flagged continuous loop at their script period when the engine keeps them alive; the loop
  region of noisy effects (wind, water) has a low autocorrelation and relies on the crossfade.
* Effects whose sound depends on game state at play time (distance, speed of `SOUND_BANK_MOVING`
  sounds, level reverb) are rendered at the listener, full volume, no level reverb.
* Fidelity to hardware is that of the HLE mixer (a few least significant bits of the microcode may
  differ); the sequence, note, envelope and reverb logic is the original code.
