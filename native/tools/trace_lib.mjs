// Shared by gen_traces.mjs and gen_directed.mjs: the levels of the debug level select, the buttons, a seeded random
// generator and the trace writer (every trace picks its level the way traces/bob_walk.trace does, see Trace.prefix).
import path from "node:path";
import { fileURLToPath } from "node:url";

export const Root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

// level number of the debug level select (levels/level_defines.h, enum LevelNum), only levels with a script
export const Levels = {
	bbh: 4, ccm: 5, castle: 6, hmc: 7, ssl: 8, bob: 9, sl: 10, wdw: 11, jrb: 12, thi: 13, ttc: 14, rr: 15,
	grounds: 16, bitdw: 17, vcutm: 18, bitfs: 19, sa: 20, bits: 21, lll: 22, ddd: 23, wf: 24, ending: 25,
	courtyard: 26, pss: 27, cotmc: 28, totwc: 29, bowser1: 30, wmotr: 31, bowser2: 33, bowser3: 34, ttm: 36,
};
export const LevelMax = 38;

export const Button = {
	A: 0x8000, B: 0x4000, Z: 0x2000, Start: 0x1000, L: 0x0020, R: 0x0010,
	CUp: 0x0008, CDown: 0x0004, CLeft: 0x0002, CRight: 0x0001,
};

// mulberry32
export function Random(seed) {
	let state = seed >>> 0;

	return () => {
		state = (state + 0x6d2b79f5) >>> 0;
		let t = state;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);

		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

export class Trace {
	constructor(level, debugLevelSelect = 1) {
		this.lines = [`boot debug_level_select ${debugLevelSelect}`];
		this.frameCount = 0;
		this.level = level;
	}

	label(text) {
		this.lines.push(`# ${text}`);
	}

	// A stimulus applied before the next frame (docs/state-hash.md, `do`): warp <level> <area> <node>, act <n>, star and
	// starnoexit <dx> <dy> <dz>, grandstar, cap <flags> <timer>, lives <n>, trigger <warp op>, pos <x> <y> <z>, stars <n>, key <flags>, objact <behavior offset> <action>, blowcap <speed>
	directive(name, ...args) {
		this.lines.push(`do ${name} ${args.join(" ")}`.trimEnd());
	}

	frame(buttons = 0, x = 0, y = 0) {
		x = Math.max(-128, Math.min(127, Math.round(x)));
		y = Math.max(-128, Math.min(127, Math.round(y)));
		this.lines.push(`0x${buttons.toString(16).padStart(4, "0")} ${x} ${y}`);
		this.frameCount++;
	}

	hold(count, buttons = 0, x = 0, y = 0) {
		for (let index = 0; index < count; index++) {
			this.frame(buttons, x, y);
		}
	}

	// A press of one frame (or more) with the stick held
	tap(buttons, x = 0, y = 0, length = 1) {
		this.hold(length, buttons, x, y);
	}

	// The title screen waits for START, the level select counts the A (up) and B (down) presses from level 1, START again;
	// act: the act the level loads with instead of 6 (the level select sets 6 until its START)
	prefix(act = null) {
		const number = Levels[this.level];
		const up = number - 1;
		const down = LevelMax + 1 - number;

		this.label(`boot ${this.level} (level ${number})`);
		this.hold(130);
		this.tap(Button.Start);
		this.hold(44);
		for (let press = 0; press < Math.min(up, down); press++) {
			this.tap(up <= down ? Button.A : Button.B);
			this.hold(1);
		}
		this.hold(10);
		this.tap(Button.Start);
		if (act !== null) {
			this.directive("act", act);
		}
		this.hold(120);
	}

	text() {
		return `${this.lines.join("\n")}\n`;
	}
}

// ---- fuzz

// per phase multipliers of the per frame chance of starting a press
const Phases = [
	{ A: 1, B: 1, Z: 1, R: 1, C: 1, L: 1 },
	{ A: 3, B: 1, Z: 0.5, R: 0, C: 0, L: 0 },
	{ A: 0.5, B: 3, Z: 1, R: 0, C: 0, L: 0 },
	{ A: 1, B: 1, Z: 3, R: 0, C: 0, L: 0 },
	{ A: 0, B: 0, Z: 0, R: 4, C: 6, L: 1 },
	{ A: 2, B: 2, Z: 2, R: 1, C: 1, L: 0 },
];
const BaseChance = { A: 0.035, B: 0.025, Z: 0.012, R: 0.004, C: 0.006, L: 0.002 };
const HoldLengths = [1, 1, 1, 2, 3, 3, 5, 8, 12, 20, 40];
const StickMagnitudes = [20, 40, 60, 70, 75, 80, 80, 80];
const StickTricks = [0, 7, 8, 9, 1, 127, -128];
const Cardinals = [0, 45, 90, 135, 180, 225, 270, 315];

export function Pick(random, list) {
	return list[Math.floor(random() * list.length)];
}

export function Between(random, low, high) {
	return low + Math.floor(random() * (high - low + 1));
}

// One stick segment: a function of the frame in it
function StickSegment(random) {
	const kind = random();

	if (kind < 0.12) {
		return { length: Between(random, 5, 60), at: () => [0, 0] };
	}
	if (kind < 0.55) {
		const angle = random() < 0.6 ? Pick(random, Cardinals) : random() * 360;
		const magnitude = random() < 0.05 ? Pick(random, StickTricks) : Pick(random, StickMagnitudes);
		const length = random() < 0.2 ? Between(random, 100, 300) : random() < 0.1 ? Between(random, 300, 600) : random() < 0.2 ? Between(random, 1, 3) : Between(random, 5, 100);
		const radians = (angle * Math.PI) / 180;

		return { length, at: () => [magnitude * Math.cos(radians), magnitude * Math.sin(radians)] };
	}
	if (kind < 0.8) {
		const start = random() * 360;
		const turn = (random() - 0.5) * 720;
		const magnitude = Pick(random, StickMagnitudes);
		const length = Between(random, 20, 150);

		return {
			length,
			at: (frame) => {
				const radians = ((start + (turn * frame) / length) * Math.PI) / 180;

				return [magnitude * Math.cos(radians), magnitude * Math.sin(radians)];
			},
		};
	}
	if (kind < 0.9) {
		return { length: Between(random, 8, 30), at: () => [Between(random, -80, 80), Between(random, -80, 80)] };
	}
	const x = Pick(random, [-80, 0, 80, 127, -128]);
	const y = Pick(random, [-80, 0, 80, 127, -128]);

	return { length: Between(random, 5, 40), at: () => [x, y] };
}

export function FuzzTrace(trace, seed, frames, withStart) {
	const random = Random(seed);
	const remaining = {};
	const buttonOf = {
		A: () => Button.A,
		B: () => Button.B,
		Z: () => Button.Z,
		R: () => Button.R,
		L: () => Button.L,
		C: () => Pick(random, [Button.CUp, Button.CDown, Button.CLeft, Button.CRight]),
	};
	const held = {};
	let phase = Phases[0];
	let phaseLeft = 0;
	let segment = { length: 0, at: () => [0, 0] };
	let segmentFrame = 0;
	let startLeft = 0;

	trace.label(`fuzz seed ${seed}`);
	for (let frame = 0; frame < frames; frame++) {
		if (phaseLeft-- <= 0) {
			phase = Pick(random, Phases);
			phaseLeft = Between(random, 60, 300);
			trace.label(`phase ${JSON.stringify(phase)}`);
		}
		if (segmentFrame >= segment.length) {
			segment = StickSegment(random);
			segmentFrame = 0;
		}

		let buttons = 0;

		for (const name of Object.keys(BaseChance)) {
			if (!(remaining[name] > 0) && random() < BaseChance[name] * phase[name]) {
				remaining[name] = Pick(random, HoldLengths);
				held[name] = buttonOf[name]();
			}
			if (remaining[name] > 0) {
				buttons |= held[name];
				remaining[name]--;
			}
		}
		if (withStart) {
			if (startLeft > 0) {
				buttons |= Button.Start;
				startLeft--;
			} else if (random() < 0.004) {
				startLeft = Pick(random, [1, 1, 2, 4]);
			}
		}

		const [x, y] = segment.at(segmentFrame);

		trace.frame(buttons, x, y);
		segmentFrame++;
	}
}


// ---- file select

// Centers of the buttons of the file select (check_clicked_button: the object position of bhv_menu_button_manager_init
// scaled to the screen by 160 / (52.4213 * 200) and 120 / (52.4213 * 3 / 4 * 200))
const ScaleX = 160 / (52.4213 * 200);
const ScaleY = 120 / (52.4213 * 0.75 * 200);
const MainButtons = {
	fileA: [-6400, 2800], fileB: [1500, 2800], fileC: [-6400, 0], fileD: [1500, 0],
	score: [-6400, -3500], copy: [-2134, -3500], erase: [2134, -3500], sound: [6400, -3500],
};

export class BootTrace extends Trace {
	constructor() {
		super(null, 0);
		// lvl_init_menu_values_and_cursor_pos: over file A
		this.cursor = [-94, 46];
	}

	// The title screen: the splash screen and the logo take about 115 frames before START is read
	title() {
		this.label("title");
		this.hold(130);
		this.tap(Button.Start);
		this.hold(80);
	}

	// Moves the cursor to a screen position, 15 steps of 8 per frame at most (the cursor clamps at 132 and 90)
	moveTo(x, y) {
		const target = [Math.max(-132, Math.min(132, Math.round(x))), Math.max(-90, Math.min(90, Math.round(y)))];

		while (this.cursor[0] !== target[0] || this.cursor[1] !== target[1]) {
			const step = [0, 1].map((axis) => Math.max(-15, Math.min(15, target[axis] - this.cursor[axis])));

			this.frame(0, step[0] * 8, step[1] * 8);
			this.cursor[0] += step[0];
			this.cursor[1] += step[1];
		}
	}

	click(button = Button.A, wait = 10) {
		this.tap(button);
		this.hold(wait);
	}

	clickMain(name) {
		const [x, y] = MainButtons[name];

		this.label(`click ${name}`);
		this.moveTo(x * ScaleX, y * ScaleY);
		this.click();
	}

	// A press at each point of a grid, with the button of the click
	sweep(button) {
		this.label(`sweep ${button === Button.A ? "A" : "B"}`);
		for (const y of [75, 25, -25, -75]) {
			for (const x of [-110, -55, 0, 55, 110]) {
				this.moveTo(x, y);
				this.click(button, 12);
			}
		}
	}

	// The intro cutscene of a new file: it waits for A presses
	introCutscene() {
		this.label("intro cutscene");
		for (let press = 0; press < 56; press++) {
			this.hold(29);
			this.tap(Button.A);
		}
		this.hold(60);
	}

	newGame(file) {
		this.title();
		this.clickMain(file);
		this.hold(40);
		this.introCutscene();
	}

	// The course select: the warp of the pause menu's exit, the star select (right presses to the act), A
	enterCourse(level, area, node, actIndex) {
		this.label(`course ${level} area ${area}`);
		this.directive("warp", Levels[level], area, node);
		this.hold(150);
		for (let press = 0; press < actIndex; press++) {
			this.hold(6, 0, 80, 0);
			this.hold(10);
		}
		this.click(Button.A, 10);
		this.click(Button.A, 10);
		this.hold(120);
	}

	// A star at Mario (it flies from him to the offset and waits there), the star dance, the course complete screen and the
	// save menu (A presses), the exit to the castle; a level without a star exit warp node gets a star that does not exit
	collectStar(level) {
		this.label("star");
		this.directive(StarExitLevels.has(level) ? "star" : "starnoexit", 0, 100, 0);
		for (let press = 0; press < 60; press++) {
			this.hold(14);
			this.tap(Button.A);
		}
		this.hold(120);
	}
}


// The levels whose script has the warp node of a star exit (WARP_NODE_F0)
export const StarExitLevels = new Set(
	["bbh", "bob", "bowser1", "bowser2", "ccm", "cotmc", "ddd", "hmc", "jrb", "lll", "pss", "rr", "sa", "sl", "ssl", "thi", "totwc", "ttc", "ttm", "vcutm", "wdw", "wf", "wmotr"],
);

