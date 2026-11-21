# Notice

## What is covered by a license

The original code of this repository (the folders `roblox/`, `render/`, `audio/`, `native/` and `rom-tool/`, except as noted below) is licensed under
the MIT license, see the `LICENSE` file in each of those folders.

## What is not

- `port/` is a Luau translation of the game logic of Super Mario 64 made from the
  [n64decomp/sm64](https://github.com/n64decomp/sm64) decompilation, which reconstructs Nintendo's code. It, the data tables drafted from that
  code, and everything else in this repository that is derived from Super Mario 64 or its decompilation, is **not licensed here**: the authors
  claim no rights in it, and no permission to use it is granted by this repository. It is published for study and for personal,
  non-commercial use with your own copy of the game, nothing more.
- `audio/native/mixer.c` follows the audio mixer of the sm64-port and sm64ex projects.
- `rom-tool/sound/wasm/engine.js` is the audio engine of the Super Mario 64 decompilation (`src/audio` of n64decomp/sm64) compiled to
  WebAssembly, with the host of `audio/native/`. It is derived from Nintendo's code like `port/` and is **not licensed here** either.
  `rom-tool/sound/wasm/vorbis.js` contains libogg and libvorbis of Xiph.Org (BSD-3-Clause license).
- `rom-tool/oneidentity-zstd.js` is [`@oneidentity/zstd-js`](https://github.com/OneIdentity/zstd-js) 1.0.3, a third-party library under its own MIT license (it is not covered by the license file of `rom-tool/`).
- Super Mario 64 and everything in it belongs to Nintendo. No ROM, texture, model, sound, music or other game asset is included, and none is
  to be added: the ROM is read at run time from the place you build, and the audio files are rendered on your computer from your own ROM.

## Take-down

If you are a rights holder and want something removed, open an issue and it will be removed.
