// The page: choose the ROM, then make the ModuleScript of it (without its sound data) or the sound files.

import { read, withoutSound } from "./sm64-rom.js";
import { compress } from "./zstd.js";
import { romModule } from "./rbxmx.js";
import { createPool } from "./sound/pool.js";
import { generate, soundData } from "./sound/generate.js";

const IDLE_STATUS = "Choose your Super Mario 64 (US) ROM. Everything runs in this page: the ROM is not uploaded anywhere.";

const element = (id) => document.getElementById(id);
const fileInput = element("fileInput");
const fileName = element("fileName");
const fileSize = element("fileSize");
const statusText = element("statusText");
const romButton = element("romBtn");
const soundButton = element("soundBtn");
const zstdToggle = element("zstdToggle");
const oneLineToggle = element("oneLineToggle");
const progress = element("progress");
const progressText = element("progressText");
const progressBar = element("progressBar");

// The ROM that is loaded (big endian, whole), or null
let rom = null;

const megabytes = (bytes) => `${(bytes / 1048576).toFixed(1)} MB`;

function setBusy(busy) {
  fileInput.disabled = busy;
  zstdToggle.disabled = busy;
  oneLineToggle.disabled = busy;
  romButton.disabled = busy || rom === null;
  soundButton.disabled = busy || rom === null;
}

function showProgress(text, fraction) {
  progress.hidden = text === null;
  progressText.textContent = text ?? "";

  if (fraction === null) {
    progressBar.removeAttribute("value");
  } else {
    progressBar.value = fraction ?? 0;
  }
}

function download(blob, name) {
  const link = document.createElement("a");

  link.href = URL.createObjectURL(blob);
  link.download = name;
  link.click();
  URL.revokeObjectURL(link.href);
}

// Runs a task with the page busy: its error is shown, not thrown away
async function busy(task) {
  setBusy(true);

  try {
    await task();
  } catch (error) {
    statusText.textContent = error instanceof Error ? error.message : String(error);
  } finally {
    showProgress(null);
    setBusy(false);
  }
}

fileInput.addEventListener("change", () => {
  const file = fileInput.files?.[0];

  if (file === undefined) {
    return;
  }

  busy(async () => {
    rom = null;
    fileName.textContent = "Nothing loaded";

    try {
      rom = read(new Uint8Array(await file.arrayBuffer()));
    } finally {
      fileInput.value = "";
    }

    fileName.textContent = file.name;
    fileSize.textContent = "original US version";
    statusText.textContent = "ROM ready. Make the script of the ROM for Studio, and the sound files.";
  });
});

romButton.addEventListener("click", () =>
  busy(async () => {
    const stripped = withoutSound(rom);
    let compressed = null;

    if (zstdToggle.checked) {
      showProgress("Compressing with Zstd (tens of seconds)", null);
      compressed = await compress(stripped);
    }

    const blob = romModule(stripped, compressed, oneLineToggle.checked);

    download(blob, "SM64Rom.rbxmx");
    statusText.textContent = `SM64Rom.rbxmx, ${megabytes(blob.size)}: import it into ReplicatedStorage (right-click, Insert from File).`;
  }),
);

soundButton.addEventListener("click", () =>
  busy(async () => {
    const pool = createPool(soundData(rom));

    try {
      const { zip, manifest } = await generate(pool.run, (phase, done, total) => showProgress(`${phase}: ${done} of ${total}`, done / total));

      download(zip, "SM64Sound.zip");
      statusText.textContent =
        `SM64Sound.zip, ${megabytes(zip.size)}: ${Object.keys(manifest.sfx).length} sound effects in ${manifest.atlases.length} atlases and ` +
        `${Object.keys(manifest.music).length} music tracks, listed in sfx-atlas.json. Unzip it and select every file in Studio with roblox/tools/ImportAudio.luau.`;
    } finally {
      pool.close();
    }
  }),
);

statusText.textContent = IDLE_STATUS;
