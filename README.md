# SM64 on Roblox (Luau)

Super Mario 64 (US) running in Roblox Studio as a pure Luau program: the game logic is a Luau port of the
[n64decomp](https://github.com/n64decomp/sm64) decompilation, drawn on the client as MeshParts, with
the sound played from files you render yourself.

**This repository contains no game assets and no ROM.** You need your own legally obtained copy of the
US version of Super Mario 64 (`.z64`, 8 MB). Nothing is hosted or distributed: you build the place on your own computer.

This is an unofficial fan project, not affiliated with or endorsed by Nintendo or Roblox. Super Mario 64 is a
trademark and copyright of Nintendo.

## Run it

You need Roblox Studio.

> NOTE: In published places, please make sure to enable `Allow Image / Mesh APIs`!
1. **Open the place.** Download [`SM64.rbxl`](https://github.com/vantoanvh/LuauSM64/releases/latest) and open it in Roblox Studio.
2. **Import your ROM.** Go to https://vantoanvh.github.io/LuauSM64/, select your US ROM, and click **ROM script**. Right-click `ReplicatedStorage` in Studio and select **Insert from File** to import `SM64Rom.rbxmx`.
3. **Import sounds (optional).** Click **Sounds** on the same page, extract `SM64Sound.zip`, then run `roblox/tools/ImportAudio.luau` in Studio's command bar. Select all extracted files, including `.json`. You'll need to repeat this each Studio session.
4. **Press Play.** The first launch takes around 2 minutes to build the meshes. The game then starts at the logo.

## Credits

- The [n64decomp/sm64](https://github.com/n64decomp/sm64) project and everyone who took part in decompiling Super Mario 64: this port exists because of their work.
- The sm64-port and sm64ex projects, whose audio mixer the offline audio renderer follows.
- Nintendo, for Super Mario 64.

## License

Mixed, see `NOTICE.md`. The folders `roblox/`, `render/`, `audio/` and `native/` carry the MIT license of their own `LICENSE`
file; `port/` has no license and is not covered by it.
