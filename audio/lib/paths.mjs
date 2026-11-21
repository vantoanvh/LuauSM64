import path from "node:path";
import { fileURLToPath } from "node:url";

export const AUDIO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const ROOT = path.resolve(AUDIO, "..");
export const REF = path.join(ROOT, "reference");
export const ROM = path.join(ROOT, "rom", "baserom.us.z64");
export const NATIVE = path.join(AUDIO, "native");
export const BUILD = path.join(AUDIO, "build");
export const OUT = path.join(AUDIO, "out");

export const SAMPLE_RATE = 32000;
