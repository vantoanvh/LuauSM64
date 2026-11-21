// The workers that render the sounds (sound/worker.js), one per core: run(job) gives the result of a job (sound/jobs.js) from the first
// worker that is free. Every worker gets the sound data of the ROM first.

const MAXIMUM_WORKERS = 8;

export function createPool(data) {
  const count = Math.max(1, Math.min(MAXIMUM_WORKERS, (navigator.hardwareConcurrency ?? 4) - 1));
  const idle = [];
  const waiting = [];
  const pending = new Map();
  let nextId = 0;

  const workers = Array.from({ length: count }, () => {
    const worker = new Worker(new URL("./worker.js", import.meta.url), { type: "module" });

    worker.onmessage = ({ data: message }) => {
      const { resolve, reject } = pending.get(message.id);

      pending.delete(message.id);
      idle.push(worker);
      waiting.shift()?.();

      if (message.error === undefined) {
        resolve(message.result);
      } else {
        reject(new Error(message.error));
      }
    };

    worker.onerror = (event) => {
      throw new Error(`A sound worker failed: ${event.message}`);
    };

    worker.postMessage({ type: "data", data });
    idle.push(worker);

    return worker;
  });

  function run(job) {
    return new Promise((resolve, reject) => {
      const start = () => {
        const worker = idle.pop();
        const id = nextId++;

        pending.set(id, { resolve, reject });
        worker.postMessage({ id, job });
      };

      if (idle.length > 0) {
        start();
      } else {
        waiting.push(start);
      }
    });
  }

  return { run, close: () => workers.forEach((worker) => worker.terminate()) };
}
