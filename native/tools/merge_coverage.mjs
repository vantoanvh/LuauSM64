// Sums the per-trace hit files of `run_suite.mjs --coverage` (harness/out/coverage/hits/*.hits) over the function list of
// harness/coverage.luau (harness/out/coverage/functions.txt; a hit file line is "<module> <function> <C source> <calls>") and writes
// harness/out/coverage.txt: per module the written
// functions, how many ran and the names that never ran, then the never executed functions ranked by review status.
//
// Usage (from the project root): node native/tools/merge_coverage.mjs
//
// Status of a function: replaced (port/replaced.txt, by `file:name` or by name), matched (its `-- from` key is in
// port/review.json), else in-review.
import fs from "node:fs";
import path from "node:path";
import { Root } from "./trace_lib.mjs";

const CoverageDirectory = path.join(Root, "harness/out/coverage");
const HitsDirectory = path.join(CoverageDirectory, "hits");

const Functions = fs
	.readFileSync(path.join(CoverageDirectory, "functions.txt"), "utf8")
	.split("\n")
	.filter(Boolean)
	.map((line) => {
		const [module, name, source] = line.split(" ");

		return { module, name, source, calls: 0, traces: 0 };
	});
const ByKey = new Map(Functions.map((entry) => [`${entry.module} ${entry.name}`, entry]));

const Matched = new Set(Object.keys(JSON.parse(fs.readFileSync(path.join(Root, "port/review.json"), "utf8"))));
const Replaced = new Set(
	fs
		.readFileSync(path.join(Root, "port/replaced.txt"), "utf8")
		.split("\n")
		.map((line) => line.replace(/#.*/, "").trim())
		.filter(Boolean),
);

function StatusOf(entry) {
	if (Replaced.has(entry.source) || Replaced.has(entry.source.split(":")[1]) || Replaced.has(entry.name)) {
		return "replaced";
	}

	return Matched.has(entry.source) ? "matched" : "in-review";
}

const HitFiles = fs.readdirSync(HitsDirectory).filter((file) => file.endsWith(".hits"));

for (const file of HitFiles) {
	for (const line of fs.readFileSync(path.join(HitsDirectory, file), "utf8").split("\n")) {
		if (line) {
			const [module, name, , count] = line.split(" ");
			const entry = ByKey.get(`${module} ${name}`);

			// a function of an older copy of the port that is no longer written
			if (entry !== undefined) {
				entry.calls += Number(count);
				entry.traces++;
			}
		}
	}
}

const Modules = new Map();

for (const entry of Functions) {
	entry.status = StatusOf(entry);

	const module = Modules.get(entry.module) ?? { name: entry.module, functions: 0, executed: 0, never: [] };

	module.functions++;
	if (entry.calls > 0) {
		module.executed++;
	} else {
		module.never.push(entry);
	}
	Modules.set(entry.module, module);
}

const Lines = [];
const Never = Functions.filter((entry) => entry.calls === 0);
const Rare = Functions.filter((entry) => entry.calls > 0 && entry.traces <= 2);

Lines.push(`hit files ${HitFiles.length}, written functions ${Functions.length}, executed ${Functions.length - Never.length} (${((100 * (Functions.length - Never.length)) / Functions.length).toFixed(1)}%), never executed ${Never.length}, executed by 1 or 2 traces only ${Rare.length}`);
Lines.push("");
Lines.push("module\tfunctions\texecuted\tnever\tnever executed (names)");
for (const module of [...Modules.values()].sort((a, b) => b.never.length - a.never.length || (a.name < b.name ? -1 : 1))) {
	Lines.push([module.name, module.functions, module.executed, module.never.length, module.never.map((entry) => entry.name).join(" ")].join("\t"));
}

const Order = { "in-review": 0, matched: 1, replaced: 2 };

Lines.push("");
Lines.push("never executed, ranked by status (status, module, function)");
for (const entry of Never.sort((a, b) => Order[a.status] - Order[b.status] || a.module.localeCompare(b.module) || a.name.localeCompare(b.name))) {
	Lines.push(`${entry.status}\t${entry.module}\t${entry.name}`);
}

Lines.push("");
Lines.push("executed by 1 or 2 traces only (traces, calls, status, module, function)");
for (const entry of Rare.sort((a, b) => a.calls - b.calls)) {
	Lines.push(`${entry.traces}\t${entry.calls}\t${entry.status}\t${entry.module}\t${entry.name}`);
}

fs.writeFileSync(path.join(Root, "harness/out/coverage.txt"), `${Lines.join("\n")}\n`);
console.log(Lines.slice(0, 1).join("\n"));
