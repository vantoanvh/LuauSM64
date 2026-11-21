// A ZIP file of files stored as they are (the Ogg files do not compress).

const CRC_TABLE = Array.from({ length: 256 }, (_, index) => {
  let value = index;

  for (let bit = 0; bit < 8; bit++) {
    value = value & 1 ? 0xEDB88320 ^ (value >>> 1) : value >>> 1;
  }

  return value >>> 0;
});

function crc32(bytes) {
  let crc = 0xFFFFFFFF;

  for (const byte of bytes) {
    crc = CRC_TABLE[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }

  return (crc ^ 0xFFFFFFFF) >>> 0;
}

// The fields of a header, little endian: [byte size, value] pairs
function fields(...pairs) {
  const bytes = new Uint8Array(pairs.reduce((size, [width]) => size + width, 0));
  const view = new DataView(bytes.buffer);
  let at = 0;

  for (const [width, value] of pairs) {
    if (width === 2) {
      view.setUint16(at, value, true);
    } else {
      view.setUint32(at, value, true);
    }

    at += width;
  }

  return bytes;
}

// 1980-01-01 00:00, the time of every file
const DOS_TIME = 0;
const DOS_DATE = 0x21;
// the file names are UTF-8
const UTF8_FLAG = 0x0800;

// The ZIP file, as a Blob, of files ({ name, bytes })
export function zip(files) {
  const encoder = new TextEncoder();
  const parts = [];
  const directory = [];
  let offset = 0;

  for (const { name, bytes } of files) {
    const nameBytes = encoder.encode(name);
    const crc = crc32(bytes);
    const common = [[2, 20], [2, UTF8_FLAG], [2, 0], [2, DOS_TIME], [2, DOS_DATE], [4, crc], [4, bytes.length], [4, bytes.length], [2, nameBytes.length], [2, 0]];
    const header = fields([4, 0x04034B50], ...common);

    // the central directory repeats the header with its own fields, and says where the file is
    directory.push(fields([4, 0x02014B50], [2, 20], ...common, [2, 0], [2, 0], [2, 0], [4, 0], [4, offset]), nameBytes);
    parts.push(header, nameBytes, bytes);
    offset += header.length + nameBytes.length + bytes.length;
  }

  const size = directory.reduce((total, part) => total + part.length, 0);

  return new Blob([...parts, ...directory, fields([4, 0x06054B50], [2, 0], [2, 0], [2, files.length], [2, files.length], [4, size], [4, offset], [2, 0])]);
}
