// Writes the trace suite into traces/suite/ (deterministic: same arguments, same files).
//
// Usage (from the project root): node native/tools/gen_traces.mjs [--seeds <n>]   (fuzz seeds per level, default 16, 2500 to 6000 frames)
//
// Every trace boots with the debug level select and picks its level the way traces/bob_walk.trace does (see Prefix).
// Per level: <level>_ground and <level>_moves (scripted, level independent: every move is tried wherever Mario spawns),
// <level>_fuzz<seed> (seeded random stick and buttons, no START). menu_<level>_fuzz<seed> adds START presses (pause,
// dialogs); run_suite.mjs skips menu_* unless asked. Segments of the scripted traces are named by "# label" lines, which
// run_suite.mjs uses to say where a mismatch is.
import fs from "node:fs";
import path from "node:path";
import { Button, FuzzTrace, Levels, Root, Trace } from "./trace_lib.mjs";

const OutDirectory = path.join(Root, "traces/suite");
const MenuLevels = Object.keys(Levels);

const Arguments = process.argv.slice(2);
const Option = (name, fallback) => {
	const index = Arguments.indexOf(`--${name}`);

	return index < 0 ? fallback : Number(Arguments[index + 1]);
};
const SeedCount = Option("seeds", 16);
// frames of the fuzz trace of seed 1, 2, ...
const FuzzLengths = [3000, 4500, 6000, 2500, 3500, 5000, 4000, 5500];
const MenuFuzzFrames = 3000;

const Run = 70;

// ---- scripted segments

function Circle(trace, magnitude, frames, turns) {
	for (let frame = 0; frame < frames; frame++) {
		const angle = (2 * Math.PI * turns * frame) / frames;

		trace.frame(0, magnitude * Math.cos(angle), magnitude * Math.sin(angle));
	}
}

function GroundTrace(trace) {
	trace.label("stand 300");
	trace.hold(300);
	trace.label("circle slow");
	Circle(trace, 20, 160, 1);
	trace.label("circle walk");
	Circle(trace, 45, 160, 2);
	trace.label("circle run");
	Circle(trace, Run, 240, 3);
	trace.label("circle edge");
	Circle(trace, 127, 120, 2);
	trace.label("stick sweep");
	for (const magnitude of [6, 7, 8, 9, 12, 24, 48, 80]) {
		for (let angle = 0; angle < 360; angle += 30) {
			const radians = (angle * Math.PI) / 180;

			trace.hold(6, 0, magnitude * Math.cos(radians), magnitude * Math.sin(radians));
		}
	}
	trace.label("stop and go");
	for (const direction of [1, -1, 1]) {
		trace.hold(40, 0, 0, direction * Run);
		trace.hold(25);
		trace.hold(20, 0, direction * Run, 0);
		trace.hold(25);
	}
	trace.label("turn around");
	for (let flips = 0; flips < 6; flips++) {
		trace.hold(25, 0, 0, Run);
		trace.hold(4 + flips, 0, 0, -Run);
	}
	trace.hold(30);
	trace.label("camera buttons");
	for (const button of [Button.CUp, Button.CDown, Button.CLeft, Button.CRight, Button.R, Button.L]) {
		trace.hold(30, button, 0, Run);
		trace.hold(15);
		trace.hold(2, button);
		trace.hold(20);
	}
	trace.label("camera while turning");
	for (const button of [Button.CLeft, Button.CRight, Button.CUp, Button.CDown]) {
		trace.hold(40, button, 50, 50);
	}
}

// the jump chain with a spacing sweep: the double jump window, the triple jump (3rd jump of a run), the long jump
function JumpChain(trace, spacing, count, stickY) {
	for (let jump = 0; jump < count; jump++) {
		trace.tap(Button.A, 0, stickY, 3);
		trace.hold(spacing, 0, 0, stickY);
	}
	trace.hold(40);
}

function MovesTrace(trace) {
	trace.label("single jump");
	trace.hold(20, 0, 0, Run);
	trace.tap(Button.A, 0, Run, 12);
	trace.hold(40);
	trace.label("jump standing");
	trace.tap(Button.A, 0, 0, 20);
	trace.hold(40);
	for (const spacing of [14, 18, 20, 22, 24, 26, 28, 32, 40]) {
		trace.label(`double and triple jump spacing ${spacing}`);
		trace.hold(25, 0, 0, Run);
		JumpChain(trace, spacing, 4, Run);
	}
	for (const delay of [0, 2, 5, 9, 14]) {
		trace.label(`long jump delay ${delay}`);
		trace.hold(30, Button.Z, 0, Run);
		trace.hold(delay, Button.Z, 0, Run);
		trace.hold(30, Button.Z | Button.A, 0, Run);
		trace.hold(40);
	}
	trace.label("backflip");
	trace.hold(30, Button.Z);
	trace.tap(Button.Z | Button.A, 0, 0, 3);
	trace.hold(50);
	trace.label("backflip, crouch release");
	trace.hold(10, Button.Z);
	trace.tap(Button.A);
	trace.hold(50);
	trace.label("side flip");
	for (const delay of [1, 3, 6]) {
		trace.hold(30, 0, 0, Run);
		trace.hold(delay, 0, 0, -Run);
		trace.tap(Button.A, 0, -Run, 3);
		trace.hold(50);
	}
	trace.label("ground pound");
	for (const delay of [4, 10, 18, 30]) {
		trace.tap(Button.A, 0, 0, 3);
		trace.hold(delay);
		trace.hold(2, Button.Z);
		trace.hold(60);
	}
	trace.label("ground pound running");
	trace.hold(20, 0, 0, Run);
	trace.tap(Button.A, 0, Run, 3);
	trace.hold(10, 0, 0, Run);
	trace.hold(2, Button.Z, 0, Run);
	trace.hold(60);
	trace.label("dive");
	for (const delay of [0, 4, 12]) {
		trace.hold(30, 0, 0, Run);
		trace.tap(Button.A, 0, Run, 3);
		trace.hold(delay, 0, 0, Run);
		trace.tap(Button.B, 0, Run, 2);
		trace.hold(60);
	}
	trace.label("dive and rollout");
	trace.hold(30, 0, 0, Run);
	trace.tap(Button.B, 0, Run, 2);
	trace.hold(10, 0, 0, Run);
	trace.tap(Button.A, 0, Run, 2);
	trace.hold(60);
	trace.label("slide kick");
	trace.hold(30, 0, 0, Run);
	trace.hold(4, Button.Z, 0, Run);
	trace.tap(Button.B, 0, Run, 2);
	trace.hold(60);
	trace.label("crouch slide jump");
	trace.hold(30, 0, 0, Run);
	trace.hold(6, Button.Z, 0, Run);
	trace.tap(Button.A, 0, Run, 2);
	trace.hold(60);
	trace.label("punch and kick");
	for (const gap of [1, 3, 6, 9, 12]) {
		trace.tap(Button.B);
		trace.hold(gap);
		trace.tap(Button.B);
		trace.hold(gap);
		trace.tap(Button.B);
		trace.hold(30);
	}
	trace.label("crouch and crawl");
	trace.hold(40, Button.Z);
	trace.hold(60, Button.Z, 0, 50);
	trace.hold(30, Button.Z, 50, 0);
	trace.hold(30);
	trace.label("jump kick and air kick");
	for (const delay of [2, 8, 16]) {
		trace.tap(Button.A, 0, Run, 3);
		trace.hold(delay, 0, 0, Run);
		trace.tap(Button.B, 0, Run, 2);
		trace.hold(50);
	}
	trace.label("air steering");
	trace.tap(Button.A, 0, 0, 3);
	for (let frame = 0; frame < 40; frame++) {
		trace.frame(0, 70 * Math.sin(frame / 4), 70 * Math.cos(frame / 4));
	}
	trace.hold(40);
	trace.label("swim strokes");
	for (let stroke = 0; stroke < 16; stroke++) {
		trace.tap(Button.A, 30 * Math.sin(stroke / 3), 60, 2);
		trace.hold(6, 0, 30 * Math.sin(stroke / 3), 60);
	}
	trace.hold(20, Button.Z, 0, 60);
	trace.hold(20, Button.B, 0, 60);
	trace.hold(30);
}

// ---- main

// The other generators write their traces into the same directory (gen_directed.mjs, gen_boot.mjs): only these are replaced
fs.mkdirSync(OutDirectory, { recursive: true });
for (const file of fs.readdirSync(OutDirectory)) {
	if (/^(menu_)?[a-z0-9]+_(ground|moves|fuzz\d+)\.trace$/.test(file)) {
		fs.rmSync(path.join(OutDirectory, file));
	}
}

let count = 0;

function Write(name, build) {
	const level = name.replace(/^menu_/, "").split("_")[0];
	const trace = new Trace(level);

	trace.prefix();
	build(trace);
	fs.writeFileSync(path.join(OutDirectory, `${name}.trace`), trace.text());
	count++;
}

for (const level of Object.keys(Levels)) {
	Write(`${level}_ground`, GroundTrace);
	Write(`${level}_moves`, MovesTrace);
	for (let seed = 1; seed <= SeedCount; seed++) {
		Write(`${level}_fuzz${seed}`, (trace) => FuzzTrace(trace, seed * 1000 + Levels[level], FuzzLengths[(seed - 1) % FuzzLengths.length], false));
	}
}
for (const level of MenuLevels) {
	for (let seed = 1; seed <= 2; seed++) {
		Write(`menu_${level}_fuzz${seed}`, (trace) => FuzzTrace(trace, seed * 7000 + Levels[level], MenuFuzzFrames, true));
	}
}
console.log(`${count} traces in ${path.relative(Root, OutDirectory)}`);
