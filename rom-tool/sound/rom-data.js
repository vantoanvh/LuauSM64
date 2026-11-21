// The sound data of the ROM in the layout the audio engine reads when it runs as WebAssembly: 32-bit pointers and little endian, which is
// the ROM's own layout (what the decomp's tools assemble for the N64) with every field swapped (what the decomp's PC build assembles with
// --endian little --bitwidth 32, see assemble_sound.py).
//
// The data is four files: the sound banks (ctl), their samples (tbl), the music sequences and the bank sets. Only the fields that are
// numbers (offsets, lengths, counts, tunings, the ADPCM books and loops) are swapped. What is bytes stays: the samples, the sequence scripts
// (read byte by byte) and the envelopes (the engine swaps their entries itself).

import { SOUND } from "../sm64-rom.js";

// A file with the fields of a copy swapped from big endian to little endian
class Swapper {
  constructor(bytes) {
    this.source = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    this.copy = bytes.slice();
    this.target = new DataView(this.copy.buffer);
    // The structures swapped already (one is pointed to by several): swapping twice would undo it
    this.done = new Set();
  }

  u16(at) {
    this.target.setUint16(at, this.source.getUint16(at, false), true);
  }

  u32(at) {
    this.target.setUint32(at, this.source.getUint32(at, false), true);
  }

  // Swaps the structure at `at` once: its fields are 16 or 32 bits at the offsets of `fields` ({ 16: [offsets], 32: [offsets] })
  once(at, fields) {
    if (this.done.has(at)) {
      return false;
    }

    this.done.add(at);

    for (const offset of fields[16] ?? []) {
      this.u16(at + offset);
    }

    for (const offset of fields[32] ?? []) {
      this.u32(at + offset);
    }

    return true;
  }

  read32(at) {
    return this.source.getUint32(at, false);
  }
}

// The header of a ctl, tbl or sequence file: a magic and a count (16 bits each) and the (offset, length) of each entry; returns them
function swapFileHeader(swapper) {
  const count = swapper.source.getUint16(2, false);
  const entries = [];

  swapper.u16(0);
  swapper.u16(2);

  for (let index = 0; index < count; index++) {
    const at = 4 + index * 8;

    swapper.u32(at);
    swapper.u32(at + 4);
    entries.push({ offset: swapper.read32(at), length: swapper.read32(at + 4) });
  }

  return entries;
}

// A sound (a sample and its tuning) at `at` of the bank: the sample is swapped with its book and its loop
function swapSound(swapper, body, at) {
  swapper.u32(at);
  swapper.u32(at + 4);

  const sample = swapper.read32(at);

  if (sample !== 0) {
    swapSample(swapper, body, body + sample);
  }
}

// A sample: 20 bytes (a flags word, the offset of its data in the tbl, its loop, its book, its size) and the book and loop it points to
function swapSample(swapper, body, at) {
  if (!swapper.once(at, { 32: [0, 4, 8, 12, 16] })) {
    return;
  }

  const loop = body + swapper.read32(at + 8);
  const book = body + swapper.read32(at + 12);

  // the book: the order and the number of predictors, then 8 * order * predictors tables of 16 bits
  swapper.once(book, { 32: [0, 4] });

  const tableCount = 8 * swapper.read32(book) * swapper.read32(book + 4);

  for (let index = 0; index < tableCount; index++) {
    swapper.u16(book + 8 + index * 2);
  }

  // the loop: start, end, count and a pad, then 16 states of 16 bits when it loops
  swapper.once(loop, { 32: [0, 4, 8, 12] });

  if (swapper.read32(loop + 8) !== 0) {
    for (let index = 0; index < 16; index++) {
      swapper.u16(loop + 16 + index * 2);
    }
  }
}

// A bank: 16 bytes (the numbers of instruments and drums, a flag, the date) and the body whose pointers are offsets from its start: the
// pointer of the drums, the pointers of the instruments, then the instruments, drums and everything they point to
function swapBank(swapper, at) {
  swapper.once(at, { 32: [0, 4, 8, 12] });

  const instruments = swapper.read32(at);
  const drums = swapper.read32(at + 4);
  const body = at + 16;

  swapper.u32(body);

  const drumTable = swapper.read32(body);

  for (let index = 0; index < instruments; index++) {
    const pointer = body + 4 + index * 4;

    swapper.u32(pointer);

    const offset = swapper.read32(pointer);

    // an instrument: its flags (4 bytes), its envelope, and the sounds of the low, normal and high notes
    if (offset !== 0 && swapper.once(body + offset, { 32: [4] })) {
      for (const sound of [8, 16, 24]) {
        swapSound(swapper, body, body + offset + sound);
      }
    }
  }

  if (drums > 0 && drumTable !== 0) {
    for (let index = 0; index < drums; index++) {
      const pointer = body + drumTable + index * 4;

      swapper.u32(pointer);

      const offset = swapper.read32(pointer);

      // a drum: its flags (4 bytes), its sound and its envelope
      if (offset !== 0 && swapper.once(body + offset, { 32: [12] })) {
        swapSound(swapper, body, body + offset + 4);
      }
    }
  }
}

// The sound banks (ctl)
function ctl(rom) {
  const swapper = new Swapper(rom.subarray(SOUND.CTL, SOUND.TBL));

  for (const { offset } of swapFileHeader(swapper)) {
    swapBank(swapper, offset);
  }

  return swapper.copy;
}

// The samples (tbl): only the header is numbers
function tbl(rom) {
  const swapper = new Swapper(rom.subarray(SOUND.TBL, SOUND.SEQUENCES));

  swapFileHeader(swapper);

  return swapper.copy;
}

// The sequences: only the header is numbers
function sequences(rom) {
  const swapper = new Swapper(rom.subarray(SOUND.SEQUENCES, SOUND.BANK_SETS));

  swapFileHeader(swapper);

  return swapper.copy;
}

// The bank sets: an offset of 16 bits for each sequence, then the banks each sequence uses (bytes)
function bankSets(rom, sequenceCount) {
  const swapper = new Swapper(rom.subarray(SOUND.BANK_SETS, SOUND.END));

  for (let index = 0; index < sequenceCount; index++) {
    swapper.u16(index * 2);
  }

  return swapper.copy;
}

// The four files of the ROM's sound data, for the engine
export function soundData(rom) {
  const sequenceCount = new DataView(rom.buffer, rom.byteOffset).getUint16(SOUND.SEQUENCES + 2, false);

  return { ctl: ctl(rom), tbl: tbl(rom), sequences: sequences(rom), bankSets: bankSets(rom, sequenceCount) };
}
