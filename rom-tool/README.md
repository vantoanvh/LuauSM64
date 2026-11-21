# rom-tool

A web page for your Super Mario 64 (US) ROM. Open it at https://vantoanvh.github.io/LuauSM64/ (or serve this folder: it uses ES modules and
workers, which a browser does not allow from a `file://` address). Everything runs in the page: **the ROM is not uploaded anywhere**.

Choose the ROM (the original US version, `.z64`, `.v64` or `.n64`: checked by size, name, region and checksums), then:

* **ROM script**: `SM64Rom.rbxmx`, the ModuleScript that returns the ROM as a buffer. Import it into `ReplicatedStorage` (right-click it, Insert
  from File). The sound data of the ROM (banks, samples and music sequences, about 2.3 MB) is left out: the game plays the sound files below and
  never reads it. The script is Base64 text decoded by Roblox's EncodingService. Options: Zstd compresses it (half the size, tens of seconds),
  No split lines keeps the text on one line (faster to load, risky to open in Studio's editor).
* **Sounds**: `SM64Sound.zip`, every sound effect and every music sequence of the game rendered by the game's own audio engine (WebAssembly),
  as Ogg Vorbis atlases and music files, and `sfx-atlas.json`, the list of them (where each sound is and where it loops). Takes about 20 seconds.
  Unzip it and select every file with `roblox/tools/ImportAudio.luau` in Studio. See `audio/README.md` for how it is made.

## Files

| File | What |
|---|---|
| `index.html`, `style.css`, `main.js` | the page |
| `sm64-rom.js` | what the page accepts and what it leaves out of the ROM |
| `rbxmx.js`, `zstd.js`, `zstd-worker.js` | the ROM script |
| `sound/` | the sound generator: the data of the ROM for the engine (`rom-data.js`), the engine and the Vorbis encoder as WebAssembly (`wasm/`, built by `audio/build.mjs`), the sounds as clips, atlases and a ZIP, and the workers that run them in parallel |

The `gh-pages` branch of the repository is a copy of this folder (the page is served from it): copy the changed files there when this folder changes.

## Credits

Made from [FileToLuau](https://github.com/vantoanvh/FileToLuau). `oneidentity-zstd.js` is [`@oneidentity/zstd-js`](https://github.com/OneIdentity/zstd-js)
1.0.3 (MIT license, bundled by jsDelivr). `sound/wasm/vorbis.js` contains libogg and libvorbis of Xiph.Org (BSD-3-Clause license) and
`sound/wasm/engine.js` the audio engine of the Super Mario 64 decompilation, see `NOTICE.md` of the repository.
