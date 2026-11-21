# SM64 on Roblox (Luau)

Super Mario 64 (US) running in Roblox Studio as a pure Luau program: the game logic is a Luau port of the
[n64decomp/sm64](https://github.com/n64decomp/sm64) decompilation, drawn on the client as MeshParts, with
the sound played from files you render yourself.

**This repository contains no game assets and no ROM.** You need your own legally obtained copy of the
US version of Super Mario 64 (`.z64`, 8 MB). Nothing is hosted or distributed: you build the place on your own computer.

This is an unofficial fan project, not affiliated with or endorsed by Nintendo or Roblox. Super Mario 64 is a
trademark and copyright of Nintendo.

## What is in here

| Folder | What |
|---|---|
| `port/` | the game logic, translated from the decompilation function by function (see `NOTICE.md`: no license is granted for it) |
| `render/` | a software renderer for the N64 display lists (used for the 2D screens and the Mario head) |
| `roblox/` | the Roblox side: the presenter that turns the game's draws into MeshParts, sky, overlay, touch controls, audio player, ROM loader and Studio tools |
| `audio/` | tools that render every sound and music sequence to Ogg files from your own ROM, with the game's own audio code |
| `rom-tool/` | the page that turns your ROM into the `SM64Rom` ModuleScript for Studio |
| `native/` | the native reference build and tools used to check the Luau port against the original code |

## Run it

You need Roblox Studio.

1. **Open the place.** Download `SM64.rbxl` from this repository and open it in Studio. It holds the game: the code of this repository as
   scripts (the game sets its own lighting when it runs).
2. **Put your ROM in the place.** Open https://vantoanvh.github.io/LuauSM64/, choose your ROM, press **ROM script**, and import the
   `SM64Rom.rbxmx` into the place (right-click `ReplicatedStorage`, Insert from File). The module `SM64Rom` returns the ROM as a buffer (the page
   accepts only the original US ROM, runs on your computer and leaves out the sound data, which the game does not read; see `rom-tool/README.md`).
3. **Sound (optional).** Without it the game runs silently and prints one warning. Roblox cannot synthesize audio, so the sounds are rendered once
   from your ROM: press **Sounds** on the same page (about 20 seconds), unzip `SM64Sound.zip`, run `roblox/tools/ImportAudio.luau` (paste it into the command
   bar) and select every file. Temporary asset ids last for the Studio session, so repeat the import each session (see `audio/README.md`).
4. **Press Play.** The first start builds the meshes of the menus and the courses behind a black screen (about two minutes). Then the game starts at the logo.

Controls are the keyboard, a gamepad or, on a touch device, on-screen buttons and a fixed stick (`roblox/src/Controls.luau`, `TouchControls.luau`). The touch layout is new and untested on real phones; the game may also be too heavy for one.

## Credits

- The [n64decomp/sm64](https://github.com/n64decomp/sm64) project and everyone who took part in decompiling Super Mario 64: this port exists because of their work.
- The sm64-port and sm64ex projects, whose audio mixer the offline audio renderer follows.
- Nintendo, for Super Mario 64.

## License

Mixed, see `NOTICE.md`. The folders `roblox/`, `render/`, `audio/` and `native/` carry the MIT license of their own `LICENSE`
file; `port/` has no license and is not covered by it.
