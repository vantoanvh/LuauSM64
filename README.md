# rom-tool

Turns your Super Mario 64 (US) ROM into the ModuleScript `SM64Rom` for Roblox Studio. Open `index.html` in a browser (no server, nothing
is uploaded: the ROM is read and converted on your computer), choose the ROM, press Export, and import the `SM64Rom.rbxmx` into
`ReplicatedStorage` (right-click it, Insert from File).

* Only the original US ROM is accepted (`.z64`, `.v64` or `.n64`; checked by size, name, region and checksums). It is exported as `.z64`.
* The sound data of the ROM (banks, samples and music sequences, about 2.3 MB) is removed: the port plays rendered files (`audio/`) and never
  reads it. Removing it keeps it out of the script and makes Zstd much more effective.
* The options are those of FileToLuau: Base64 (smaller script) and Buffer (the module returns a buffer; the game needs it) stay on; Zstd
  makes the script smaller still; No split lines is for loading speed.

A version of [FileToLuau](https://github.com/vantoanvh/FileToLuau) made for this project. `oneidentity-zstd.js` is
[`@oneidentity/zstd-js`](https://github.com/OneIdentity/zstd-js) 1.0.3 (MIT license, bundled by jsDelivr).
