// The Super Mario 64 (US) ROM: the only file the converter takes, and what it keeps of it.
//
// Prepare accepts the unmodified US ROM in any of the three byte orders of N64 dumps (.z64, .v64, .n64), and gives it back as .z64 (big endian)
// without the sound data. The port never reads that data: the game's sounds are played from files rendered offline (audio/), so the banks,
// the samples and the music sequences of the ROM are zeroed, which keeps them out of the exported script (and lets Zstd make it much smaller).

const Sm64Rom = (() => {
  const ROM_SIZE = 8 * 1024 * 1024;
  // The header: the two checksums of the US version (0x10, 0x14), the game's name (0x20) and its region letter (0x3E)
  const CHECKSUM_1 = 0x635A2BFF;
  const CHECKSUM_2 = 0x8B022326;
  const GAME_NAME = "SUPER MARIO 64";
  const REGION_US = 0x45;
  // The sound data, one block: the sound banks (ctl), their samples (tbl), the music sequences and the bank sets
  const SOUND_START = 0x57B720;
  const SOUND_END = 0x7CC6B8;

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

  // The ROM as the game reads it: the US version of Super Mario 64, big endian, with no sound data
  function prepare(bytes) {
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

    rom.fill(0, SOUND_START, SOUND_END);

    return rom;
  }

  return { prepare, SOUND_BYTES: SOUND_END - SOUND_START };
})();
