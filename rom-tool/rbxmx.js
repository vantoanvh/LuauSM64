// The ROM as the ModuleScript SM64Rom in an .rbxmx file, which Studio imports (right-click ReplicatedStorage, Insert from File). The module
// returns the ROM as a buffer: Roblox's EncodingService decodes the Base64 text that holds it, and the Zstd compression of it if there is one.

const MODULE_NAME = "SM64Rom";
const BASE64 = new TextEncoder().encode("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
const PAD = 0x3D;
// the text is split in lines of this many characters (\z of a Lua string skips the line break), as Studio's editor copes badly with a very
// long line
const CHARS_PER_LINE = 128;

const XML_HEADER = `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n`;
const ITEM_START = `\t<Item class="ModuleScript">\n\t\t<Properties>\n\t\t\t<Content name="LinkedSource"><null></null></Content>\n\t\t\t<ProtectedString name="Source"><![CDATA[`;
const ITEM_END = `]]></ProtectedString>\n\t\t\t<string name="Name">${MODULE_NAME}</string>\n\t\t</Properties>\n\t</Item>\n</roblox>`;

// The Base64 text of the bytes, as bytes
function base64(bytes) {
  const text = new Uint8Array(Math.ceil(bytes.length / 3) * 4);
  let output = 0;

  for (let input = 0; input < bytes.length; input += 3) {
    const rest = bytes.length - input;
    const value = (bytes[input] << 16) | ((bytes[input + 1] ?? 0) << 8) | (bytes[input + 2] ?? 0);

    text[output++] = BASE64[(value >> 18) & 0x3F];
    text[output++] = BASE64[(value >> 12) & 0x3F];
    text[output++] = rest > 1 ? BASE64[(value >> 6) & 0x3F] : PAD;
    text[output++] = rest > 2 ? BASE64[value & 0x3F] : PAD;
  }

  return text;
}

// The pieces of a Lua string with the text in it, split in lines or not
function literal(text, oneLine) {
  const encoder = new TextEncoder();
  const lineBreak = encoder.encode("\\z\n");
  const pieces = [encoder.encode('"')];
  const step = oneLine ? text.length : CHARS_PER_LINE;

  for (let at = 0; at < text.length; at += step) {
    if (at > 0) {
      pieces.push(lineBreak);
    }

    pieces.push(text.subarray(at, at + step));
  }

  pieces.push(encoder.encode('"'));

  return pieces;
}

// The .rbxmx of the ROM (a Blob); `compressed` is the Zstd compression of it, or null when it is not compressed
export function romModule(rom, compressed, oneLine) {
  const payload = literal(base64(compressed ?? rom), oneLine);
  const decode = compressed === null ? ["EncodingService:Base64Decode(buffer.fromstring(", ")"] : ["EncodingService:DecompressBuffer(EncodingService:Base64Decode(buffer.fromstring(", "), Enum.CompressionAlgorithm.Zstd)"];
  const source = ['local EncodingService = game:GetService("EncodingService")\nreturn ', decode[0], ...payload, `)${decode[1]}`];

  return new Blob([XML_HEADER, ITEM_START, ...source, ITEM_END], { type: "application/xml;charset=utf-8" });
}
