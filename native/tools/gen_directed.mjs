// Writes directed traces into traces/suite/: Mario walks to objects of the level and attacks or jumps on them, which the
// fuzz seldom does (coins, enemies, poles, doors, pipes, switches, platforms: every behavior module that has an object
// in the level at the start).
//
// Usage (from the project root): node native/tools/gen_directed.mjs [--missing] [scenario ...]   (all scenarios without
// arguments; --missing skips the tours whose trace exists, to resume an interrupted run)
// Scenarios: a level (level select, act 6): <level>_tour1..4.trace (the 12 nearest object types, then the next 12 and so
// on, each visited in order of distance; a type is its behavior); a level with an act, <level>_act<k> for the 15 courses
// and the acts 1 to 5: <level>_act<k>_tour1..2.trace (the objects of that act); a place of a new game, boot_grounds,
// boot_castle, boot_courtyard: boot_<place>_tour1..4.trace (the game as a player runs it: the intro cutscene first).
//
// How: the trace is built in chunks of 16 frames. Before each chunk the native harness replays the trace so far and dumps
// the last frame (native/run.sh <dump-from-frame>); the position of Mario and of the target object and the camera yaw
// (intendedYaw of the last stick) give the stick of the next chunk. The native run is deterministic, so a replay of the
// finished trace is the run that was planned. Near the target: a combo (punches, jump kick, ground pound, dive), then the
// next object. Stuck (little progress): a jump with a sideways stick.
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { BootTrace, Button, Levels, Random, Root, Trace } from "./trace_lib.mjs";

const NativeExe = path.join(Root, "native/build/us/sm64_native.exe");
const WorkDirectory = path.join(Root, "harness/out/directed");
const OutDirectory = path.join(Root, "traces/suite");
const Chunk = 16;
const TargetsPerTour = 12;
const MaxFramesPerTarget = 450;
const Near = 130;
const Jobs = 6;

const CourseLevels = ["bob", "wf", "jrb", "ccm", "bbh", "hmc", "lll", "ssl", "ddd", "sl", "wdw", "ttm", "thi", "ttc", "rr"];

// The places of a new game: the file A start and the warp to the place (level, area, node) once the intro cutscene is over
const BootPlaces = { grounds: null, castle: [6, 1, 1], courtyard: [26, 1, 1] };

// scenarios: name, the tours it has and how the trace starts
const Scenarios = [
	...Object.keys(Levels).map((level) => ({
		name: level,
		tours: 4,
		start: () => {
			const trace = new Trace(level);

			trace.prefix();

			return trace;
		},
	})),
	...CourseLevels.flatMap((level) =>
		[1, 2, 3, 4, 5].map((act) => ({
			name: `${level}_act${act}`,
			tours: 2,
			start: () => {
				const trace = new Trace(level);

				trace.prefix(act);

				return trace;
			},
		})),
	),
	...Object.entries(BootPlaces).map(([place, warp]) => ({
		name: `boot_${place}`,
		tours: 4,
		start: () => {
			const trace = new BootTrace();

			trace.newGame("fileA");
			if (warp !== null) {
				trace.directive("warp", ...warp);
				trace.hold(200);
			}

			return trace;
		},
	})),
];

const BehaviorNames = new Map();

for (const Match of fs.readFileSync(path.join(Root, "port/src/rom/behavior_ids.luau"), "utf8").matchAll(/(bhv\w+) = 0x13([0-9A-Fa-f]{6})/g)) {
	BehaviorNames.set(parseInt(Match[2], 16), Match[1]);
}

function RunNative(traceFile, dumpFile, dumpFrom) {
	return new Promise((resolve) => {
		const child = spawn(NativeExe, [traceFile, `${traceFile}.hash`, dumpFile, String(dumpFrom)], { cwd: path.join(Root, "native"), windowsHide: true });

		child.on("close", resolve);
	});
}

// The Mario fields and the objects of the last frame of the trace
async function QueryState(directory, lines, frames) {
	const traceFile = path.join(directory, "q.trace");
	const dumpFile = path.join(directory, "q.dump");

	fs.writeFileSync(traceFile, `${lines.join("\n")}\n`);
	await RunNative(traceFile, dumpFile, frames - 1);

	const state = { pos: [0, 0, 0], intendedYaw: 0, action: 0, objects: [] };
	let object = null;

	for (const Line of fs.readFileSync(dumpFile, "utf8").split(/\r?\n/)) {
		const Pair = /^([\w.[\]]+)=(.*)$/.exec(Line);

		if (Pair === null) {
			continue;
		}

		const Value = Pair[2].includes("(") ? parseFloat(/\((.*)\)/.exec(Pair[2])[1]) : parseInt(Pair[2], 10);

		switch (Pair[1]) {
			case "mario.pos[0]": state.pos[0] = Value; break;
			case "mario.pos[1]": state.pos[1] = Value; break;
			case "mario.pos[2]": state.pos[2] = Value; break;
			case "mario.intendedYaw": state.intendedYaw = Value; break;
			case "mario.action": state.action = Value; break;
			case "object.slot": object = { slot: Value, pos: [0, 0, 0], behavior: -1 }; state.objects.push(object); break;
			case "object.behavior": object.behavior = Value; break;
			case "object.posX": object.pos[0] = Value; break;
			case "object.posY": object.pos[1] = Value; break;
			case "object.posZ": object.pos[2] = Value; break;
		}
	}

	return state;
}

const Distance = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);

// atan2s(-y, x) of the adjusted stick (adjust_analog_stick: dead zone 8)
function StickYaw(x, y) {
	const ax = x > 8 ? x - 8 : x < -8 ? x + 8 : 0;
	const ay = y > 8 ? y - 8 : y < -8 ? y + 8 : 0;

	return (Math.atan2(ax, -ay) * 32768) / Math.PI;
}

const Combos = [
	(trace) => { for (let punch = 0; punch < 3; punch++) { trace.tap(Button.B); trace.hold(5); } trace.hold(20); },
	(trace) => { trace.tap(Button.A, 0, 0, 3); trace.hold(12); trace.tap(Button.B, 0, 0, 2); trace.hold(30); },
	(trace) => { trace.tap(Button.A, 0, 0, 3); trace.hold(8); trace.hold(2, Button.Z); trace.hold(40); },
	(trace) => { trace.hold(20, 0, 0, 70); trace.tap(Button.B, 0, 70, 2); trace.hold(40); },
	(trace) => { trace.hold(6, Button.Z); trace.tap(Button.Z | Button.A, 0, 0, 2); trace.hold(40); },
];

async function Tour(scenarioIndex, tourIndex) {
	const scenario = Scenarios[scenarioIndex];
	const name = `${scenario.name}_tour${tourIndex}`;

	if (Missing && fs.existsSync(path.join(OutDirectory, `${name}.trace`))) {
		return;
	}

	// the level scenarios keep the seeds of the first tours
	const random = Random((Levels[scenario.name] ?? 1000 + scenarioIndex) * 77 + tourIndex);
	const directory = path.join(WorkDirectory, name);

	fs.mkdirSync(directory, { recursive: true });

	const trace = scenario.start();

	const start = await QueryState(directory, trace.lines, trace.frameCount);
	const types = new Map();

	for (const object of start.objects) {
		const name = BehaviorNames.get(object.behavior);

		if (name !== undefined && name !== "bhvMario" && Distance(object.pos, start.pos) > 100 && !types.has(name)) {
			types.set(name, object);
		}
	}

	const targets = [...types.entries()]
		.sort((a, b) => Distance(a[1].pos, start.pos) - Distance(b[1].pos, start.pos))
		.slice((tourIndex - 1) * TargetsPerTour, tourIndex * TargetsPerTour);
	let cameraYaw = null;
	let lastStick = [0, 70];
	let previous = start;

	for (const [name, first] of targets) {
		trace.label(`go to ${name} (slot ${first.slot})`);

		let stuck = 0;

		for (let spent = 0; spent < MaxFramesPerTarget; spent += Chunk) {
			const state = await QueryState(directory, trace.lines, trace.frameCount);
			const target = state.objects.find((object) => object.slot === first.slot && BehaviorNames.get(object.behavior) === name);

			if (target === undefined) {
				break;
			}
			if (cameraYaw === null || Math.hypot(...lastStick) > 12) {
				cameraYaw = state.intendedYaw - StickYaw(...lastStick);
			}
			if (Distance(state.pos, target.pos) < Near) {
				trace.label(`combo at ${name}`);
				Combos[Math.floor(random() * Combos.length)](trace);
				break;
			}

			stuck = Distance(state.pos, previous.pos) < 24 ? stuck + 1 : 0;
			previous = state;

			const wanted = (Math.atan2(target.pos[0] - state.pos[0], target.pos[2] - state.pos[2]) * 32768) / Math.PI;
			let beta = ((wanted - cameraYaw) * Math.PI) / 32768;
			let buttons = 0;

			if (stuck >= 2) {
				beta += (random() < 0.5 ? -1 : 1) * (Math.PI / 3);
				buttons = Button.A;
			}
			lastStick = [70 * Math.sin(beta), -70 * Math.cos(beta)];
			trace.hold(Chunk, 0, ...lastStick);
			if (buttons !== 0) {
				trace.tap(buttons, ...lastStick, 6);
			}
		}
	}

	trace.label("end");
	trace.hold(30);
	fs.writeFileSync(path.join(OutDirectory, `${name}.trace`), trace.text());
	console.log(`${name}: ${targets.length} targets, ${trace.frameCount} frames`);
}

const Missing = process.argv.includes("--missing");
const Selected = process.argv.slice(2).filter((argument) => argument !== "--missing");
const Queue = Scenarios.flatMap((scenario, scenarioIndex) =>
	Selected.length === 0 || Selected.includes(scenario.name)
		? Array.from({ length: scenario.tours }, (_, index) => Tour.bind(null, scenarioIndex, index + 1))
		: [],
);

fs.mkdirSync(OutDirectory, { recursive: true });
await Promise.all(Array.from({ length: Jobs }, async () => {
	while (Queue.length > 0) {
		await Queue.shift()();
	}
}));
