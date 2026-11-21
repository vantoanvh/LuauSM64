// Runs the trace suite (traces/suite/, written by gen_traces.mjs) through the native harness and the Luau harness and
// compares the per-frame hashes. Writes harness/out/suite.txt (summary table, rate per level, first differing fields) and
// the full diffs to harness/out/suite/<trace>.diff.txt.
//
// Usage (from the project root):
//   node native/tools/run_suite.mjs [--only a,b] [--menu] [--jobs <n>] [--no-diff] [--coverage]
//   --only   keep the traces whose name contains one of the words
//   --menu   run the menu_* traces too (START presses; they need groups/ingame_menu_plus1) instead of skipping them
//   --jobs   parallel traces (default 12)
//   --no-diff  skip the dump rerun that names the differing field of a mismatch
//   --coverage  function coverage instead of the comparison: runs the Luau side only, on the coverage copy of the port (harness/
//               coverage.luau), writes harness/out/coverage/hits/<trace>.hits and merges all hit files into harness/out/coverage.txt
//               (native/tools/merge_coverage.mjs); a trace that stops early still counts what it ran; a full run clears the hit
//               files first, --only adds to them
//
// A trace is one of: match, mismatch (first differing frame, rerun with dumps up to it for harness/diff.luau), stopped (the
// Luau run ended early: error text or "stale function X", prefix compared), hang (Luau timed out), native failure.
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const Root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const SuiteDirectory = path.join(Root, "traces/suite");
const OutDirectory = path.join(Root, "harness/out/suite");
const NativeExe = path.join(Root, "native/build/us/sm64_native.exe");

const Arguments = process.argv.slice(2);
const Flag = (name) => Arguments.includes(`--${name}`);
const Value = (name, fallback) => {
	const index = Arguments.indexOf(`--${name}`);

	return index < 0 ? fallback : Arguments[index + 1];
};
const Only = Value("only", "").split(",").filter(Boolean);
const Jobs = Number(Value("jobs", 12));
const SummaryFile = path.join(Root, Only.length ? "harness/out/suite.only.txt" : "harness/out/suite.txt");

function Run(command, args, options = {}) {
	return new Promise((resolve) => {
		const child = spawn(command, args, { cwd: Root, windowsHide: true, ...options });
		let output = "";
		let timedOut = false;
		const timer = options.timeout
			? setTimeout(() => {
					timedOut = true;
					child.kill();
				}, options.timeout)
			: null;

		child.stdout.on("data", (data) => (output += data));
		child.stderr.on("data", (data) => (output += data));
		child.on("close", (code) => {
			clearTimeout(timer);
			resolve({ code, output, timedOut });
		});
	});
}

const Native = (trace, hash, dump, dumpFrom) =>
	Run(NativeExe, [trace, hash, ...(dump ? [dump, String(dumpFrom)] : [])], { cwd: path.join(Root, "native"), timeout: 120000 });
const Luau = (trace, hash, frames, dump, dumpFrom, extra = []) =>
	Run("lute", ["run", "harness/run.luau", ...extra, trace, hash, ...(dump ? [dump, String(dumpFrom)] : [])], { timeout: 90000 + frames * 60 });

function ReadHashes(file) {
	if (!fs.existsSync(file)) {
		return [];
	}

	return fs
		.readFileSync(file, "utf8")
		.split(/\r?\n/)
		.filter(Boolean)
		.map((line) => line.split(" ")[1]);
}

// frames and the label of each frame, from the trace
function ReadTrace(file) {
	const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
	const labels = [];
	let frames = 0;

	for (const line of lines) {
		if (line.startsWith("# ")) {
			labels.push({ frame: frames, text: line.slice(2) });
		} else if (line && !line.startsWith("#") && !line.startsWith("boot") && !line.startsWith("do ")) {
			frames++;
		}
	}

	return { lines, frames, labels };
}

function SegmentAt(labels, frame) {
	let found = "";

	for (const label of labels) {
		if (label.frame > frame) {
			break;
		}
		if (!label.text.startsWith("phase ") && !label.text.startsWith("boot ")) {
			found = label.text;
		}
	}

	return found;
}

// The trace cut after frame `last` (boot lines and comments kept)
function Truncate(lines, last) {
	const kept = [];
	let frames = 0;

	for (const line of lines) {
		const isFrame = line && !line.startsWith("#") && !line.startsWith("boot") && !line.startsWith("do ");

		if (isFrame && frames > last) {
			// the directives that precede the cut frame belong to it
			while (kept.length > 0 && kept[kept.length - 1].startsWith("do ")) {
				kept.pop();
			}
			break;
		}
		kept.push(line);
		frames += isFrame ? 1 : 0;
	}

	return `${kept.join("\n")}\n`;
}

const StopPattern = /stopped at (.*)/;

const CoverageDirectory = path.join(Root, "harness/out/coverage");

// Luau side only, on the coverage copy; the hash file is a scratch
async function ExecuteCoverage(name) {
	const trace = path.join(SuiteDirectory, `${name}.trace`);
	const info = ReadTrace(trace);
	const hits = path.join(CoverageDirectory, "hits", `${name}.hits`);
	const started = Date.now();
	const luau = await Luau(trace, path.join(CoverageDirectory, "hash", `${name}.hash`), info.frames, null, 0, ["--coverage", hits]);
	const stop = StopPattern.exec(luau.output);

	return {
		name,
		frames: info.frames,
		matched: 0,
		status: luau.timedOut ? "hang" : luau.code === 0 ? "covered" : "stopped",
		stop: stop ? luau.output.slice(stop.index).split("\n")[0] : "",
		seconds: (Date.now() - started) / 1000,
	};
}

async function Execute(name) {
	const trace = path.join(SuiteDirectory, `${name}.trace`);
	const nativeHash = path.join(OutDirectory, `${name}.native.hash`);
	const luauHash = path.join(OutDirectory, `${name}.luau.hash`);
	const info = ReadTrace(trace);
	const result = { name, frames: info.frames, matched: 0, mismatch: null, segment: "", stop: "", status: "match", field: "" };
	const started = Date.now();
	const [native, luau] = await Promise.all([Native(trace, nativeHash), Luau(trace, luauHash, info.frames)]);

	result.seconds = (Date.now() - started) / 1000;

	const nativeHashes = ReadHashes(nativeHash);
	const luauHashes = ReadHashes(luauHash);

	if (native.code !== 0 || nativeHashes.length !== info.frames) {
		result.status = "native failure";
		result.stop = native.output.trim().split("\n").pop();

		return result;
	}
	for (let frame = 0; frame < luauHashes.length; frame++) {
		if (luauHashes[frame] === nativeHashes[frame]) {
			result.matched++;
		} else if (result.mismatch === null) {
			result.mismatch = frame;
		}
	}
	if (luau.timedOut) {
		result.status = "hang";
		result.stop = `timeout after frame ${luauHashes.length - 1}`;
	} else if (luau.code !== 0 || luauHashes.length < info.frames) {
		result.status = "stopped";
		const stop = StopPattern.exec(luau.output);

		result.stop = stop ? luau.output.slice(stop.index).split("\n").slice(0, 3).join(" | ") : luau.output.trim().split("\n").slice(-3).join(" | ");
		result.stop = result.stop.replace(/^stopped at /, "");
	}
	if (result.mismatch !== null) {
		result.status = result.status === "match" ? "mismatch" : `${result.status}+mismatch`;
		result.segment = SegmentAt(info.labels, result.mismatch);
		if (!Flag("no-diff")) {
			result.field = await Localize(name, info, result.mismatch);
		}
	} else if (result.status !== "match") {
		result.segment = SegmentAt(info.labels, luauHashes.length);
	}

	return result;
}

// Reruns both sides up to the first mismatching frame, dumping that frame, and asks harness/diff.luau which fields differ
async function Localize(name, info, frame) {
	const cut = path.join(OutDirectory, `${name}.cut.trace`);
	const files = ["native.hash", "luau.hash", "native.dump", "luau.dump"].map((suffix) => path.join(OutDirectory, `${name}.cut.${suffix}`));

	fs.writeFileSync(cut, Truncate(info.lines, frame));
	await Promise.all([Native(cut, files[0], files[2], frame), Luau(cut, files[1], frame + 1, files[3], frame)]);

	const diff = await Run("lute", ["run", "harness/diff.luau", ...files], { timeout: 300000 });

	fs.writeFileSync(path.join(OutDirectory, `${name}.diff.txt`), diff.output);
	for (const file of [cut, ...files]) {
		fs.rmSync(file, { force: true });
	}

	return diff.output
		.split("\n")
		.filter((line) => /^(first differing field|fields stop|dumps have)/.test(line))
		.join(" | ");
}

async function Pool(names) {
	const results = [];
	let next = 0;
	const worker = async () => {
		while (next < names.length) {
			const name = names[next++];
			const result = await (Flag("coverage") ? ExecuteCoverage(name) : Execute(name));

			results.push(result);
			console.log(`${result.status.padEnd(16)} ${name} (${Flag("coverage") ? result.frames : `${result.matched}/${result.frames}`}, ${result.seconds.toFixed(1)} s)`);
		}
	};

	await Promise.all(Array.from({ length: Jobs }, worker));

	return results.sort((a, b) => (a.name < b.name ? -1 : 1));
}

function Summarize(results) {
	const lines = [];
	const levels = new Map();

	lines.push(["trace", "frames", "matched", "first mismatch", "segment", "luau stop / first field"].join("\t"));
	for (const result of results) {
		const level = result.name.replace(/^menu_/, "").split("_")[0];
		const entry = levels.get(level) ?? { traces: 0, passed: 0, frames: 0, matched: 0 };

		entry.traces++;
		entry.passed += result.status === "match" ? 1 : 0;
		entry.frames += result.frames;
		entry.matched += result.matched;
		levels.set(level, entry);
		lines.push(
			[
				result.name,
				result.frames,
				result.matched,
				result.mismatch ?? "-",
				result.segment || "-",
				[result.status === "match" ? "" : result.status, result.stop, result.field].filter(Boolean).join(": "),
			].join("\t"),
		);
	}

	const passed = results.filter((result) => result.status === "match").length;
	const matchedFrames = results.reduce((sum, result) => sum + result.matched, 0);
	const totalFrames = results.reduce((sum, result) => sum + result.frames, 0);

	lines.push("");
	lines.push(`traces ${results.length}, matching ${passed} (${((100 * passed) / results.length).toFixed(1)}%), frames ${totalFrames}, matched frames ${matchedFrames} (${((100 * matchedFrames) / totalFrames).toFixed(1)}%)`);
	lines.push("");
	lines.push("level\ttraces passed\tframes matched");
	for (const [level, entry] of levels) {
		lines.push(`${level}\t${entry.passed}/${entry.traces}\t${entry.matched}/${entry.frames}`);
	}

	return lines.join("\n");
}

const names = fs
	.readdirSync(SuiteDirectory)
	.filter((file) => file.endsWith(".trace"))
	.map((file) => file.replace(/\.trace$/, ""))
	.filter((name) => Flag("menu") || !name.startsWith("menu_"))
	.filter((name) => Only.length === 0 || Only.some((word) => name.includes(word)))
	.sort();

fs.mkdirSync(OutDirectory, { recursive: true });

if (Flag("coverage")) {
	if (Only.length === 0) {
		fs.rmSync(path.join(CoverageDirectory, "hits"), { recursive: true, force: true });
	}
	fs.mkdirSync(path.join(CoverageDirectory, "hits"), { recursive: true });
	fs.mkdirSync(path.join(CoverageDirectory, "hash"), { recursive: true });

	const prepared = await Run("lute", ["run", "harness/prepare_coverage.luau"]);

	console.log(prepared.output.trim());

	const covered = await Pool(names);
	const stopped = covered.filter((result) => result.status !== "covered");

	for (const result of stopped) {
		console.log(`${result.status}: ${result.name}: ${result.stop}`);
	}

	const merged = await Run("node", ["native/tools/merge_coverage.mjs"]);

	console.log(merged.output.trim());
	process.exit(0);
}

const results = await Pool(names);
const summary = Summarize(results);

fs.writeFileSync(SummaryFile, `${summary}\n`);
console.log(`\n${summary.split("\n").slice(-60).join("\n")}\nwritten to ${path.relative(Root, SummaryFile)}`);
