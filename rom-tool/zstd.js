// Zstd compression of bytes, in a worker (it takes tens of seconds for the ROM).

export function compress(bytes) {
  const worker = new Worker(new URL("./zstd-worker.js", import.meta.url));

  return new Promise((resolve, reject) => {
    worker.onmessage = ({ data }) => {
      worker.terminate();

      if (data.error !== undefined) {
        reject(new Error(data.error));
      } else {
        resolve(data.bytes);
      }
    };

    worker.onerror = (event) => {
      worker.terminate();
      reject(new Error(event.message || "Could not start the Zstd worker."));
    };

    worker.postMessage({ bytes });
  });
}
