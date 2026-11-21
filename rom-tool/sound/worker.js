// A worker of the sound generator: the first message is the sound data of the ROM, then every message is a job (jobs.js); each is answered by
// { id, result } or { id, error }.

import { run, setData } from "./jobs.js";

self.onmessage = async ({ data: message }) => {
  if (message.type === "data") {
    setData(message.data);

    return;
  }

  try {
    const result = await run(message.job);

    // the big arrays of the result move to the page, they are not copied
    const transfer = [result.samples?.buffer, result.ogg?.buffer].filter(Boolean);

    self.postMessage({ id: message.id, result }, transfer);
  } catch (error) {
    self.postMessage({ id: message.id, error: error instanceof Error ? error.message : String(error) });
  }
};
