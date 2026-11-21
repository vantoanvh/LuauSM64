// Writes the Goddard oracle traces (native/goddard/traces/*.trace). Deterministic: rerun to regenerate.
// Usage: node tools/gen_traces.mjs   (from native/goddard)
// Line format: <buttons> <stickX> <stickY> per frame (docs/state-hash.md, Trace). The cursor of Goddard starts at the
// screen center (160, 120) and moves stick * 0.1 pixels per frame outside the dead zone of 6.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const A = 0x8000, B = 0x4000, Z = 0x2000, START = 0x1000;
const DUP = 0x0800, DDOWN = 0x0400, DLEFT = 0x0200, DRIGHT = 0x0100;
const L = 0x0020, R = 0x0010;
const CUP = 0x0008, CDOWN = 0x0004, CLEFT = 0x0002, CRIGHT = 0x0001;

const clampStick = (v) => Math.max(-80, Math.min(80, Math.round(v)));

// Cursor of Goddard (renderer.c parse_p1_controller): csr += stick * 0.1 truncated to an integer outside the dead zone
// of 6 (y is inverted), clamped to [16, 272] x [16, 208].
const clampCursor = (v, low, high) => Math.max(low, Math.min(high, v));

class Trace {
  constructor(header) {
    this.header = header;
    this.frames = [];
    this.cursor = { x: 160, y: 120 };
  }

  push(buttons, x, y) {
    const stickX = clampStick(x);
    const stickY = clampStick(y);
    this.frames.push([buttons, stickX, stickY]);
    if (Math.abs(stickX) >= 6) {
      this.cursor.x = Math.trunc(this.cursor.x + stickX * 0.1);
    }
    if (Math.abs(stickY) >= 6) {
      this.cursor.y = Math.trunc(this.cursor.y - stickY * 0.1);
    }
    this.cursor.x = clampCursor(this.cursor.x, 16, 272);
    this.cursor.y = clampCursor(this.cursor.y, 16, 208);
  }

  // Appends `count` frames; stick is a function of the frame index inside the segment, or a [x, y] pair.
  hold(count, buttons = 0, stick = [0, 0]) {
    for (let i = 0; i < count; i++) {
      const [x, y] = typeof stick === "function" ? stick(i) : stick;
      this.push(buttons, x, y);
    }
    return this;
  }

  // Moves the cursor to within 4 pixels of (x, y) with `buttons` held.
  moveTo(x, y, buttons = 0) {
    while (Math.abs(this.cursor.x - x) > 4 || Math.abs(this.cursor.y - y) > 4) {
      const dx = x - this.cursor.x;
      const dy = this.cursor.y - y;
      this.push(buttons, Math.abs(dx) > 4 ? dx * 12 : 0, Math.abs(dy) > 4 ? dy * 12 : 0);
    }
    return this;
  }

  circle(count, radius, period, buttons = 0) {
    return this.hold(count, buttons, (i) => [
      radius * Math.cos((2 * Math.PI * i) / period),
      radius * Math.sin((2 * Math.PI * i) / period),
    ]);
  }

  // One tap: `buttons` for `frames` frames.
  tap(buttons, frames = 3) {
    return this.hold(frames, buttons);
  }

  text() {
    const lines = this.header.map((line) => `# ${line}`);
    for (const [buttons, x, y] of this.frames) {
      lines.push(`0x${buttons.toString(16).padStart(4, "0")} ${x} ${y}`);
    }
    return lines.join("\n") + "\n";
  }
}

const traces = {};

traces.idle = new Trace(["Goddard regular head (id 2): no input for 600 frames (opening animation)."]).hold(600);

traces.idle_long = new Trace(["Goddard regular head (id 2): no input for 2400 frames (nodding, dozing, falling asleep)."]).hold(2400);

traces.stick_circles = new Trace([
  "Goddard regular head (id 2): stick only (the cursor and the eyes move, no button).",
  "60 idle, 3 circles of radius 70, idle, corner pushes at full deflection, slow spiral.",
])
  .hold(60)
  .circle(240, 70, 80)
  .hold(40)
  .hold(30, 0, [80, 80])
  .hold(30, 0, [-80, 80])
  .hold(30, 0, [-80, -80])
  .hold(30, 0, [80, -80])
  .hold(30, 0, [80, 0])
  .hold(30, 0, [0, -80])
  .hold(30, 0, [-80, 0])
  .hold(30, 0, [0, 80])
  .hold(20)
  .hold(80, 0, (i) => [(10 + i) * Math.cos(i / 6), (10 + i) * Math.sin(i / 6)]);

// The cursor starts at the center, on the face: A grabs the nose, a pull deforms the face, release lets it spring back.
traces.grab_drag = new Trace([
  "Goddard regular head (id 2): A grabs the face, stick drags it; B, Z, Start, L, R, C and D-pad presses.",
])
  .hold(40)
  .hold(80, A) // grab at the center (nose)
  .hold(30, A, [60, 0])
  .hold(30, A, [-60, 0])
  .hold(30, A, [0, -60])
  .hold(30, A, [0, 60])
  .circle(60, 60, 60, A)
  .hold(40) // release: springs back
  .tap(B)
  .hold(20)
  .tap(Z)
  .hold(20)
  .tap(START)
  .hold(20)
  .tap(START)
  .hold(20)
  .tap(L)
  .tap(R)
  .tap(CUP)
  .tap(CDOWN)
  .tap(CLEFT)
  .tap(CRIGHT)
  .tap(DUP)
  .tap(DDOWN)
  .tap(DLEFT)
  .tap(DRIGHT)
  .hold(20)
  .hold(20, 0, [-80, -80]) // cursor to the upper left (an ear), then grab and pull
  .hold(60, A, [0, 0])
  .hold(40, A, [40, 40])
  .hold(40, A, [-40, 0])
  .hold(40)
  .hold(20, 0, [80, 80]) // cursor to the lower right
  .hold(50, A, [0, 0])
  .hold(40, A, [-70, -70])
  .hold(40, A | B, [70, 70])
  .hold(30);

// B cycles the camera zoom level (0 -> 1 -> 2 -> back to 0), C buttons turn and move the camera, R freezes released
// joints, Start toggles the freezing of the nets.
traces.camera_controls = new Trace([
  "Goddard regular head (id 2): B zoom cycle, held C buttons, R freeze while a grabbed ear is released, Start toggle.",
])
  .hold(40)
  .tap(B)
  .hold(30)
  .tap(B)
  .hold(30)
  .tap(B)
  .hold(30)
  .tap(B)
  .hold(30)
  .hold(30, CLEFT)
  .hold(30, CRIGHT)
  .hold(30, CUP)
  .hold(30, CDOWN)
  .hold(20, CLEFT | CUP)
  .hold(20, CRIGHT | CDOWN)
  .hold(20, L)
  .hold(20, DUP | DLEFT)
  .hold(8, 0, [-80, 0]) // cursor to the left ear, grab, pull, release while R is held
  .hold(40, A, [0, 0])
  .hold(30, A, [-60, 0])
  .hold(30, R, [0, 0])
  .hold(30, R | A, [0, 0])
  .hold(30, R)
  .hold(40) // R released: the joints spring back
  .hold(10, START) // Start on: the nets stop moving
  .hold(30)
  .hold(40, A, [60, 60])
  .hold(30, START) // Start off
  .hold(40)
  .hold(30, A | B, [30, -30])
  .hold(60);

// The grabbers of the face (ears, cap, nose, jaw, cheeks) sit at fixed screen positions once the head has flown in
// (about frame 560). A press within 20 pixels of one picks it, so press A on a grid with a 24 pixel step.
traces.grab_sweep = (() => {
  const trace = new Trace([
    "Goddard regular head (id 2): idle until the head is close, then A presses on a grid (a serpentine sweep) so every",
    "grabber of the face is picked at least once; the stick drags each pick a little.",
  ]).hold(560);
  let leftToRight = true;
  for (let y = 40; y <= 208; y += 24) {
    for (let column = 0; column <= 10; column++) {
      const x = leftToRight ? 40 + 24 * column : 280 - 24 * column;
      trace.moveTo(Math.min(x, 272), y);
      trace.hold(4, A, [leftToRight ? 30 : -30, 20]);
      trace.hold(2);
    }
    leftToRight = !leftToRight;
  }
  return trace;
})();

traces.gameover = new Trace([
  "Goddard dizzy head (id 3, game over): idle through the dizzy animation, then stick and A presses.",
])
  .hold(200)
  .circle(100, 70, 50)
  .hold(20)
  .hold(60, A)
  .hold(30, A, [70, 0])
  .hold(30, A, [0, 70])
  .hold(30, A, [-70, -70])
  .hold(30)
  .tap(START)
  .tap(Z)
  .tap(B)
  .hold(20)
  .hold(40, 0, [-80, 80])
  .hold(50, A)
  .hold(30, A, [80, -80]);

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "traces");
mkdirSync(outDir, { recursive: true });
for (const [name, trace] of Object.entries(traces)) {
  writeFileSync(join(outDir, `${name}.trace`), trace.text());
  console.log(`${name}.trace: ${trace.frames.length} frames`);
}
