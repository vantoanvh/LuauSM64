// Writes the traces of the paths the level-select suite does not take into traces/suite/ (deterministic):
//   boot_demos, boot_title_*          title screen, the demos, START presses
//   boot_file_*                       file select: score, copy, erase and sound buttons
//   boot_new<file>_fuzz<seed>         a new game: file select, the intro cutscene, then fuzz in the castle grounds
//   boot_game<n>                      a game: course after course (warp to the course, star select, act, a star, star dance,
//                                     course complete, back in the castle), the stars saved in between
//   boot_credits                      the end: credits start warp, the end cutscene, the credits scenes, the waving, back to the title
//   boot_gameover, boot_death         Mario dies with no life left (the game over screen), with lives left (the course exit)
//   <level>_act<k>_fuzz1              level select with the act of the level set (objects and script branches of the acts)
//   <level>_caps                      the metal, wing and vanish caps in turn, with fuzz
//   <level>_grandstar, <level>_action_<behavior>   the grand star taken (the jumbo star cutscene), a boss or enemy put in each of its actions
//   camera_<level>, doors_castle_*   Mario at the center of each camera trigger box, at each key door and star door of the castle
//   warp_<level>_a<area>_n<node>      every destination of a WARP_NODE of the level scripts, entered with the warp directive
//
// Usage (from the project root): node native/tools/gen_boot.mjs
//
// The boot traces start with `boot debug_level_select 0`: START on the title opens the file select, the game runs its
// normal warps (star exit, death, course select) instead of the debug level select. The file select cursor starts over
// file A and moves by rawStick / 8 per frame (file_select.c handle_controller_cursor_input), so every stick of
// these traces is a multiple of 8 and the generator knows where the cursor is.
import fs from "node:fs";
import path from "node:path";
import { BootTrace, Button, FuzzTrace, Levels, Root, Trace } from "./trace_lib.mjs";

const OutDirectory = path.join(Root, "traces/suite");
const ReferenceLevels = path.join(Root, "reference/levels");

const Written = [];

// level_update.h: the warp ops the trace triggers
const WarpOp = { Death: 18, CreditsStart: 23 };

// mario.h: the cap flags
const Cap = { Vanish: 2, Metal: 4, Wing: 8 };

function Save(name, trace) {
	fs.writeFileSync(path.join(OutDirectory, `${name}.trace`), trace.text());
	Written.push(name);
}

function BootTraces() {
	let trace = new BootTrace();

	trace.label("demos");
	trace.hold(14000);
	Save("boot_demos", trace);

	trace = new BootTrace();
	trace.label("START during the splash screen and the logo, then the demo timer reset by the stick");
	trace.hold(20);
	trace.tap(Button.Start);
	trace.hold(60);
	trace.tap(Button.Start);
	trace.hold(100);
	trace.tap(Button.Start, 0, 0, 2);
	trace.hold(500);
	trace.hold(100, 0, 60, 0);
	trace.hold(900);
	Save("boot_title_early", trace);

	trace = new BootTrace();
	trace.label("START during a demo");
	trace.hold(960);
	trace.tap(Button.Start);
	trace.hold(200);
	trace.hold(300, 0, 0, 0);
	trace.tap(Button.Start);
	trace.hold(100);
	Save("boot_title_demo_start", trace);

	for (const [index, name] of ["score", "copy", "erase", "sound"].entries()) {
		trace = new BootTrace();
		trace.title();
		trace.clickMain(name);
		trace.hold(60);
		trace.sweep(Button.A);
		trace.sweep(Button.B);
		trace.hold(60);
		trace.sweep(Button.Start);
		trace.clickMain(["fileB", "fileC", "fileD", "fileA"][index]);
		trace.hold(300);
		Save(`boot_file_${name}`, trace);
	}
}

function NewGameTraces() {
	let seed = 0;

	for (const file of ["fileA", "fileB", "fileC", "fileD"]) {
		for (let index = 1; index <= 2; index++) {
			const trace = new BootTrace();

			seed++;
			trace.newGame(file);
			FuzzTrace(trace, 50000 + seed, 3500, index === 2);
			Save(`boot_new${file.slice(-1)}_fuzz${index}`, trace);
		}
	}
}

// The destination of each course entrance of the castle: [level, area, node]
const Courses = [
	["bob", 1, 10], ["wf", 1, 10], ["jrb", 1, 10], ["ccm", 1, 10], ["bbh", 1, 10], ["hmc", 1, 10], ["lll", 1, 10],
	["ssl", 1, 10], ["ddd", 1, 10], ["sl", 1, 10], ["wdw", 1, 10], ["ttm", 1, 10], ["thi", 2, 10], ["ttc", 1, 10], ["rr", 1, 10],
];
const SecretCourses = [
	["pss", 1, 10], ["cotmc", 1, 10], ["totwc", 1, 10], ["vcutm", 1, 10], ["sa", 1, 10], ["wmotr", 1, 10], ["bitdw", 1, 10],
	["bitfs", 1, 10], ["bits", 1, 10], ["bowser1", 1, 10], ["bowser2", 1, 10], ["bowser3", 1, 10],
];

function GameTraces() {
	// each chain visits the courses in turn, the first star of a course in its first visit, the second in the second
	const chains = [
		[...Courses.slice(0, 5), ...Courses.slice(0, 3)],
		[...Courses.slice(5, 10), ...Courses.slice(5, 8)],
		[...Courses.slice(10, 15), ...Courses.slice(10, 13)],
		SecretCourses.slice(0, 6),
		SecretCourses.slice(6, 12),
	];

	for (const [index, chain] of chains.entries()) {
		const trace = new BootTrace();
		const visits = new Map();

		trace.newGame("fileA");
		for (const [level, area, node] of chain) {
			const visit = visits.get(level) ?? 0;

			visits.set(level, visit + 1);
			trace.enterCourse(level, area, node, visit);
			trace.collectStar(level);
		}
		Save(`boot_game${index + 1}`, trace);
	}
}

function EndingTraces() {
	let trace = new BootTrace();

	trace.newGame("fileA");
	trace.label("credits");
	trace.directive("trigger", WarpOp.CreditsStart);
	for (let press = 0; press < 450; press++) {
		trace.hold(29);
		trace.tap(Button.A);
	}
	Save("boot_credits", trace);

	trace = new BootTrace();
	trace.newGame("fileA");
	trace.label("game over");
	trace.directive("lives", 0);
	trace.directive("trigger", WarpOp.Death);
	trace.hold(400);
	trace.tap(Button.Start);
	trace.hold(200);
	trace.tap(Button.Start);
	trace.hold(100);
	trace.tap(Button.A);
	trace.hold(600);
	Save("boot_gameover", trace);

	trace = new BootTrace();
	trace.newGame("fileA");
	trace.enterCourse("bob", 1, 10, 0);
	trace.label("death");
	trace.directive("trigger", WarpOp.Death);
	trace.hold(600);
	trace.enterCourse("jrb", 1, 10, 0);
	trace.directive("trigger", WarpOp.Death);
	trace.hold(600);
	Save("boot_death", trace);
}

// The metal, wing and vanish caps in turn, each with fuzz
function CapTraces() {
	for (const level of Object.keys(Levels)) {
		const trace = new Trace(level);

		trace.prefix();
		for (const [index, [name, flag, timer]] of [["metal", Cap.Metal, 700], ["wing", Cap.Wing, 900], ["vanish", Cap.Vanish, 800]].entries()) {
			trace.label(`${name} cap`);
			trace.directive("cap", flag, timer);
			FuzzTrace(trace, 90000 + Levels[level] * 10 + index, 1000, false);
		}
		Save(`${level}_caps`, trace);

		// Mario loses his cap (it flies off, Mario may pick it up again), twice
		const blown = new Trace(level);

		blown.prefix();
		for (const [index, speed] of [30, 60].entries()) {
			blown.label(`blow off the cap at ${speed}`);
			blown.directive("blowcap", speed);
			FuzzTrace(blown, 91000 + Levels[level] * 10 + index, 700, false);
		}
		Save(`${level}_blowcap`, blown);
	}
}

// ---- level select scenarios

function ActTraces() {
	for (const [level] of Courses) {
		for (let act = 1; act <= 5; act++) {
			const trace = new Trace(level);

			trace.prefix(act);
			FuzzTrace(trace, 70000 + Levels[level] * 10 + act, 2500, false);
			Save(`${level}_act${act}_fuzz1`, trace);
		}
	}
}

// ---- warps

const LevelNames = Object.fromEntries(
	Object.entries({
		LEVEL_BBH: "bbh", LEVEL_CCM: "ccm", LEVEL_CASTLE: "castle", LEVEL_HMC: "hmc", LEVEL_SSL: "ssl", LEVEL_BOB: "bob",
		LEVEL_SL: "sl", LEVEL_WDW: "wdw", LEVEL_JRB: "jrb", LEVEL_THI: "thi", LEVEL_TTC: "ttc", LEVEL_RR: "rr",
		LEVEL_CASTLE_GROUNDS: "grounds", LEVEL_BITDW: "bitdw", LEVEL_VCUTM: "vcutm", LEVEL_BITFS: "bitfs", LEVEL_SA: "sa",
		LEVEL_BITS: "bits", LEVEL_LLL: "lll", LEVEL_DDD: "ddd", LEVEL_WF: "wf", LEVEL_ENDING: "ending",
		LEVEL_CASTLE_COURTYARD: "courtyard", LEVEL_PSS: "pss", LEVEL_COTMC: "cotmc", LEVEL_TOTWC: "totwc",
		LEVEL_BOWSER_1: "bowser1", LEVEL_WMOTR: "wmotr", LEVEL_BOWSER_2: "bowser2", LEVEL_BOWSER_3: "bowser3",
		LEVEL_TTM: "ttm",
	}),
);

const LevelDirectories = { castle: "castle_inside", grounds: "castle_grounds", courtyard: "castle_courtyard", bowser1: "bowser_1", bowser2: "bowser_2", bowser3: "bowser_3" };

// The nodes of a level script that are the spawn of a star collect: arriving there without the star leaves the course
// complete screen without a course (the native build reads a name through a pointer of -1)
function StarCollectNodes(level) {
	const script = fs.readFileSync(path.join(ReferenceLevels, LevelDirectories[level] ?? level, "script.c"), "utf8");
	const nodes = new Set();

	for (const match of script.matchAll(/^\s*OBJECT\(.*BPARAM2\(WARP_NODE_([0-9A-F]{2})\).*bhv(\w*StarCollectWarp)\)/gm)) {
		nodes.add(parseInt(match[1], 16));
	}

	return nodes;
}

// Every [level, area, node] a WARP_NODE of the level scripts leads to, but the star collect spawns
function WarpDestinations() {
	const destinations = new Map();

	for (const directory of fs.readdirSync(ReferenceLevels)) {
		const script = path.join(ReferenceLevels, directory, "script.c");

		if (!fs.existsSync(script)) {
			continue;
		}
		for (const match of fs.readFileSync(script, "utf8").matchAll(/^\s*(?:PAINTING_)?WARP_NODE\(.*?destLevel\*\/ (\w+),.*?destArea\*\/ (\d+),.*?destNode\*\/ WARP_NODE_([0-9A-F]{2}),/gm)) {
			const level = LevelNames[match[1]];

			if (level !== undefined && !StarCollectNodes(level).has(parseInt(match[3], 16))) {
				destinations.set(`${level}_a${match[2]}_n${match[3].toLowerCase()}`, [level, Number(match[2]), parseInt(match[3], 16)]);
			}
		}
	}

	return destinations;
}

// A destination the state hash cannot compare: Mario arrives by a door spawn, which takes no step, so m->wall still points
// to a surface of the level that was unloaded and the native build hashes the freed pool memory (docs/bugs.md)
const DanglingWall = new Set(["courtyard_a1_n01"]);

function WarpTraces() {
	let seed = 0;

	for (const [name, [level, area, node]] of WarpDestinations()) {
		if (DanglingWall.has(name)) {
			continue;
		}

		// from a level other than the destination, so that it is a change of level
		const trace = new Trace(level === "sa" ? "pss" : "sa");

		seed++;
		trace.prefix();
		trace.hold(60);
		trace.label(`warp to ${name}`);
		trace.directive("warp", Levels[level], area, node);
		trace.hold(200);
		FuzzTrace(trace, 80000 + seed, 1500, false);
		Save(`warp_${name}`, trace);
	}
}

// ---- camera triggers

// The boxes of the camera triggers of each level and area: [level, area, event, centerX, centerY, centerZ]
function CameraTriggers() {
	const camera = fs.readFileSync(path.join(Root, "reference/src/game/camera.c"), "utf8");
	const defines = fs.readFileSync(path.join(ReferenceLevels, "level_defines.h"), "utf8");
	const tables = new Map();

	for (const table of camera.matchAll(/^struct CameraTrigger (sCam\w+)\[\] = \{(.*?)NULL_TRIGGER/gms)) {
		tables.set(table[1], [...table[2].matchAll(/\{\s*(-?\d+),\s*(\w+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),/g)].map((entry) => entry.slice(1)));
	}

	const triggers = [];

	for (const define of defines.matchAll(/DEFINE_LEVEL\([^,]*,\s*(\w+),[^\n]*,\s*(sCam\w+)\)/g)) {
		const level = LevelNames[define[1]];

		for (const [area, event, x, y, z] of tables.get(define[2]) ?? []) {
			if (Number(area) > 0 && level !== undefined) {
				triggers.push([level, Number(area), event, Number(x), Number(y), Number(z)]);
			}
		}
	}

	return triggers;
}

// Mario is put at the center of each box, in a fresh area (a warp to a spawn of the area, so that a fall into the void
// cannot leave the level for the rest of the trace)
function CameraTraces() {
	const spawns = new Map();

	for (const [, [level, area, node]] of WarpDestinations()) {
		if (!(spawns.get(`${level}_${area}`) <= node)) {
			spawns.set(`${level}_${area}`, node);
		}
	}

	const byLevel = new Map();

	for (const trigger of CameraTriggers()) {
		byLevel.set(trigger[0], [...(byLevel.get(trigger[0]) ?? []), trigger]);
	}
	for (const [level, triggers] of byLevel) {
		const hub = level === "pss" ? "sa" : "pss";
		const trace = new Trace(hub);

		trace.prefix();
		trace.hold(60);
		let inHub = true;

		for (const [, area, event, x, y, z] of triggers) {
			const node = spawns.get(`${level}_${area}`);

			if (node === undefined) {
				continue;
			}
			trace.label(`camera trigger ${event}`);
			// through the hub: a warp inside the area it is in is not a change of level
			if (!inHub) {
				trace.directive("warp", Levels[hub], 1, 10);
				trace.hold(80);
			}
			trace.directive("warp", Levels[level], area, node);
			inHub = false;
			trace.hold(160);
			trace.directive("pos", x, y, z);
			trace.hold(120);
			// a step in each direction
			for (const [stickX, stickY] of [[0, 70], [70, 0], [0, -70], [-70, 0]]) {
				trace.hold(15, 0, stickX, stickY);
			}
			trace.hold(30);
		}
		Save(`camera_${level}`, trace);
	}
}

fs.mkdirSync(OutDirectory, { recursive: true });

// ---- doors

// The key doors and star doors of the castle: [area, x, y, z, yaw in degrees]
function CastleDoors() {
	const doors = [];
	let area = 0;

	for (const line of fs.readFileSync(path.join(ReferenceLevels, "castle_inside/script.c"), "utf8").split("\n")) {
		// the objects of the area N are in script_func_local_N
		const areaStart = /^static const LevelScript script_func_local_(\d+)\[\]/.exec(line);
		const door = /^\s*OBJECT\(.*?pos\*\/\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*\/\*angle\*\/\s*-?\d+,\s*(-?\d+),.*bhv(?:DoorWarp|StarDoor)\)/.exec(line);

		if (areaStart !== null) {
			area = Number(areaStart[1]);
		}
		if (door !== null) {
			doors.push([area, Number(door[1]), Number(door[2]), Number(door[3]), Number(door[4])]);
		}
	}

	return doors;
}

// Mario next to each door, in front and behind, pushing in every direction (the camera decides which way is the door): the
// locked doors with no star and no key, and the same with the stars and the keys of the file (the unlocking cutscenes)
function DoorTraces() {
	const spawns = new Map();

	for (const [, [level, area, node]] of WarpDestinations()) {
		if (level === "castle" && !(spawns.get(area) <= node)) {
			spawns.set(area, node);
		}
	}
	for (const [name, stars, keys] of [["locked", 0, 0], ["open", 120, 0x30]]) {
		const trace = new Trace("pss");

		trace.prefix();
		trace.hold(60);
		if (stars > 0) {
			trace.directive("stars", stars);
			trace.directive("key", keys);
		}
		for (const [area, x, y, z, yaw] of CastleDoors()) {
			trace.label(`door at ${x} ${y} ${z}`);
			trace.directive("warp", Levels.castle, area, spawns.get(area));
			trace.hold(100);
			// the text box of the arrival (an automatic dialog) is closed by A
			for (let press = 0; press < 8; press++) {
				trace.tap(Button.A);
				trace.hold(14);
			}
			for (const side of [1, -1]) {
				for (let direction = 0; direction < 8; direction++) {
					const radians = (yaw * Math.PI) / 180;

					trace.directive("pos", Math.round(x + side * 140 * Math.sin(radians)), y + 10, Math.round(z + side * 140 * Math.cos(radians)));
					trace.hold(10);
					trace.hold(30, 0, 70 * Math.sin((direction * Math.PI) / 4), 70 * Math.cos((direction * Math.PI) / 4));
				}
			}
			// back to a neutral place of the castle for the next warp
			trace.directive("warp", Levels.pss, 1, 10);
			trace.hold(60);
		}
		Save(`doors_castle_${name}`, trace);
	}
}

// The grand star: it arcs to the origin of Bowser's arena, where Mario starts; A presses close the dialog and jump to it
function GrandStarTrace() {
	const trace = new Trace("bowser3");

	trace.prefix();
	trace.hold(60);
	trace.label("grand star");
	trace.directive("grandstar");
	trace.hold(150);
	for (let press = 0; press < 40; press++) {
		trace.hold(8);
		trace.tap(Button.A);
		trace.hold(12);
	}
	trace.hold(2500);
	Save("bowser3_grandstar", trace);
}

// ---- boss actions

// [behavior, the highest action to put it in]: the objects whose actions are states of a fight or a routine that is long to reach
const ActionBehaviors = [
	["bhvKingBobomb", 8], ["bhvBowser", 19], ["bhvEyerokBoss", 5], ["bhvEyerokHand", 13], ["bhvSmallWhomp", 8], ["bhvWhompKingBoss", 8],
	["bhvBoo", 5], ["bhvBooWithCage", 3], ["bhvGhostHuntBoo", 5], ["bhvGhostHuntBigBoo", 3], ["bhvMerryGoRoundBigBoo", 5], ["bhvMerryGoRoundBoo", 5],
	["bhvBalconyBigBoo", 5], ["bhvChuckya", 4], ["bhvSmallPenguin", 6], ["bhvUkiki", 7], ["bhvWigglerHead", 4],
	["bhvYoshi", 6], ["bhvKoopa", 6], ["bhvHoot", 3], ["bhvMontyMole", 4], ["bhvMips", 4], ["bhvKlepto", 6], ["bhvBigBully", 4],
	["bhvBigBullyWithMinions", 4], ["bhvSmallBully", 4], ["bhvChainChomp", 4], ["bhvBulletBill", 4], ["bhvWaterBomb", 3], ["bhvDorrie", 3],
	["bhvPyramidTop", 3], ["bhvSnowmansBottom", 3], ["bhvCannon", 6], ["bhvFlyingBookend", 4], ["bhvHomingAmp", 3], ["bhvCirclingAmp", 3],
	["bhvBobombBuddy", 5], ["bhvBobombBuddyOpensCannon", 5], ["bhvBobomb", 5], ["bhvGoomba", 5], ["bhvKoopaFlag", 3], ["bhvTreasureChestBottom", 4],
	["bhvThwomp", 4], ["bhvTweester", 2], ["bhvSpindrift", 3], ["bhvPenguinRaceShortcutCheck", 3], ["bhvRacingPenguin", 6], ["bhvLllRotatingHexFlame", 3],
	["bhvCastleFloorTrap", 3], ["bhvFallingPillar", 3], ["bhvBowserPuzzlePiece", 3], ["bhvTumblingBridge", 3], ["bhvPlatformOnTrack", 4],
];

// The level and the first act of each behavior an OBJECT of a level script places, with the behavior offsets of segment 0x13
function PlacedBehaviors() {
	const offsets = new Map();
	const placed = new Map();
	const directoryLevels = Object.fromEntries(Object.entries(LevelDirectories).map(([level, directory]) => [directory, level]));

	for (const match of fs.readFileSync(path.join(Root, "port/src/rom/behavior_ids.luau"), "utf8").matchAll(/(bhv\w+) = 0x13([0-9A-Fa-f]{6})/g)) {
		offsets.set(match[1], parseInt(match[2], 16));
	}
	for (const directory of fs.readdirSync(ReferenceLevels)) {
		const script = path.join(ReferenceLevels, directory, "script.c");
		const level = directoryLevels[directory] ?? directory;

		if (fs.existsSync(script) && Levels[level] !== undefined) {
			for (const match of fs.readFileSync(script, "utf8").matchAll(/^\s*OBJECT(_WITH_ACTS)?\(.*\/\*bhv\*\/ (bhv\w+)\s*(?:,\s*\/\*acts\*\/ ([^)]*))?\)/gm)) {
				const acts = match[1] ? [...match[3].matchAll(/ACT_(\d)/g)].map((act) => Number(act[1])) : [];
				const act = match[3]?.includes("ALL_ACTS") || acts.length === 0 ? 1 : Math.min(...acts);

				if (!placed.has(match[2])) {
					placed.set(match[2], [level, act]);
				}
			}
		}
	}

	return { offsets, placed };
}

// Each behavior in turn in every action it has, in the level and act that places it (the dialog at the start closed by A)
function ActionTraces() {
	const { offsets, placed } = PlacedBehaviors();

	for (const [name, last] of ActionBehaviors) {
		if (!offsets.has(name) || !placed.has(name)) {
			continue;
		}

		const [level, act] = placed.get(name);
		const trace = new Trace(level);

		trace.prefix(act);
		for (let press = 0; press < 8; press++) {
			trace.hold(14);
			trace.tap(Button.A);
		}
		for (let action = 0; action <= last; action++) {
			trace.label(`${name} action ${action}`);
			trace.directive("objact", offsets.get(name), action);
			trace.hold(70);
		}
		Save(`${level}_action_${name.slice(3).toLowerCase()}`, trace);
	}
}

for (const file of fs.readdirSync(OutDirectory)) {
	if (!file.includes("_tour") && /^(boot_|warp_|camera_|doors_)|_(act\d_fuzz1|caps|blowcap|grandstar|action_\w+)\.trace$/.test(file)) {
		fs.rmSync(path.join(OutDirectory, file));
	}
}
BootTraces();
NewGameTraces();
GameTraces();
EndingTraces();
ActTraces();
CapTraces();
GrandStarTrace();
WarpTraces();
CameraTraces();
DoorTraces();
ActionTraces();
console.log(`${Written.length} traces in ${path.relative(Root, OutDirectory)}`);
