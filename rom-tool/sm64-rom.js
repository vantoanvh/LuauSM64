// The Super Mario 64 (US) ROM: the only file the tool takes, and what it keeps of it.
//
// read accepts the unmodified US ROM in any of the three byte orders of N64 dumps (.z64, .v64, .n64) and gives it back as .z64 (big endian).
// The sound data of the ROM (banks, samples, music sequences) is what the tool turns into sound files (sound/rom-data.js); the port never
// reads it, because the game's sounds are played from those files, so withoutSound zeroes it for the exported ROM script. That keeps it out of
// the script and lets Zstd make it much smaller.

const ROM_SIZE = 8 * 1024 * 1024;
// The header: the two checksums of the US version (0x10, 0x14), the game's name (0x20) and its region letter (0x3E)
const CHECKSUM_1 = 0x635A2BFF;
const CHECKSUM_2 = 0x8B022326;
const GAME_NAME = "SUPER MARIO 64";
const REGION_US = 0x45;

// The sound data, one block of four parts: the sound banks (ctl), their samples (tbl), the music sequences and the bank sets
export const SOUND = { CTL: 0x57B720, TBL: 0x593560, SEQUENCES: 0x7B0860, BANK_SETS: 0x7CC620, END: 0x7CC6C0 };

// The first word of a ROM says how it is stored: 0x80371240 as z64; v64 swaps each pair of bytes, n64 reverses each word
const WORD_Z64 = 0x80371240;
const WORD_V64 = 0x37804012;
const WORD_N64 = 0x40123780;

function swapPairs(bytes) {
  for (let i = 0; i < bytes.length; i += 2) {
    const first = bytes[i];
    bytes[i] = bytes[i + 1];
    bytes[i + 1] = first;
  }
}

function swapWords(bytes) {
  for (let i = 0; i < bytes.length; i += 4) {
    const a = bytes[i];
    const b = bytes[i + 1];
    bytes[i] = bytes[i + 3];
    bytes[i + 1] = bytes[i + 2];
    bytes[i + 2] = b;
    bytes[i + 3] = a;
  }
}

// The ROM in the byte order of .z64, a copy
function toBigEndian(bytes) {
  const rom = bytes.slice();
  const word = new DataView(rom.buffer).getUint32(0, false);

  if (word === WORD_V64) {
    swapPairs(rom);
  } else if (word === WORD_N64) {
    swapWords(rom);
  } else if (word !== WORD_Z64) {
    throw new Error("This is not an N64 ROM.");
  }

  return rom;
}

// The ROM as a big endian .z64 copy, when it is the original US version of Super Mario 64
export function read(bytes) {
  if (bytes.length !== ROM_SIZE) {
    throw new Error(`The ROM of Super Mario 64 is 8 MB, this file is ${bytes.length.toLocaleString()} bytes.`);
  }

  const rom = toBigEndian(bytes);
  const view = new DataView(rom.buffer);
  const name = new TextDecoder().decode(rom.subarray(0x20, 0x20 + GAME_NAME.length));

  if (name !== GAME_NAME || rom[0x3E] !== REGION_US) {
    throw new Error("This is not the US version of Super Mario 64.");
  }

  if (view.getUint32(0x10, false) !== CHECKSUM_1 || view.getUint32(0x14, false) !== CHECKSUM_2) {
    throw new Error("This ROM is not the original US Super Mario 64 (its checksums are different: a hack or a bad dump).");
  }

  return rom;
}

// A copy of the ROM without its sound data
export function withoutSound(rom) {
  const copy = rom.slice();

  copy.fill(0, SOUND.CTL, SOUND.END);

  return copy;
}
