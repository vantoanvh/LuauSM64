// Compresses bytes with Zstd (a classic worker: the library, oneidentity-zstd.js, is a script, not a module). Takes { bytes } and answers
// { bytes } or { error }.

self.window = self;
importScripts("oneidentity-zstd.js");

const LEVEL = 19;

self.onmessage = async ({ data }) => {
  try {
    const zstd = await self.ZstdInit();
    const compressed = zstd.ZstdSimple.compress(data.bytes, LEVEL);

    if (!(compressed instanceof Uint8Array)) {
      throw new Error("Zstd compression failed.");
    }

    self.postMessage({ bytes: compressed }, [compressed.buffer]);
  } catch (error) {
    self.postMessage({ error: error instanceof Error ? error.message : String(error) });
  }
};
