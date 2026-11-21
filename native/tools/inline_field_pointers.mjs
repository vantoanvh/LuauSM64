// Rewrites the copy-in / call / copy-out of an Object field passed to a (Buffer, Offset) callee
// (approach_f32_ptr, clamp_f32) into the direct call (decision object-field-pointer-helpers).
//   Scratch.X[1] = buffer.readf32(B, OFF)
//   ... ObjBehaviors2.approach_f32_ptr(Scratch.X, ...)
//   buffer.writef32(B, OFF, Scratch.X[1])
// becomes ... ObjBehaviors2.approach_f32_ptr(B, OFF, ...); the Scratch field is removed when unused.
// Usage: node inline_field_pointers.mjs <behaviors dir> [--write]
import fs from "node:fs";
import path from "node:path";

const Dir = process.argv[2];
const Write = process.argv.includes("--write");
const CopyIn = /^(\s*)Scratch\.(\w+)\[1\] = buffer\.readf32\((.+), (IncludeObjectFieldsH\.\w+)\)$/;
const Callee = /ObjBehaviors2\.(approach_f32_ptr|clamp_f32)\(Scratch\.(\w+), /;

let Total = 0;

for (const Name of fs.readdirSync(Dir).filter((F) => F.endsWith(".luau"))) {
	const File = path.join(Dir, Name);
	const Lines = fs.readFileSync(File, "utf8").split("\n");
	const Removed = new Set();
	let Count = 0;

	for (let I = 0; I < Lines.length; I++) {
		const Match = CopyIn.exec(Lines[I].replace(/\r$/, ""));

		if (!Match) {
			continue;
		}

		const [, , Scratch, Buffer, Offset] = Match;
		const WriteBack = `buffer.writef32(${Buffer}, ${Offset}, Scratch.${Scratch}[1])`;
		let Call = -1;
		let Back = -1;

		for (let J = I + 1; J <= I + 3 && J < Lines.length; J++) {
			const CallMatch = Callee.exec(Lines[J]);

			if (CallMatch && CallMatch[2] === Scratch) {
				Call = J;
				break;
			}
		}

		if (Call < 0) {
			continue;
		}

		for (let K = Call + 1; K <= Call + 2 && K < Lines.length; K++) {
			if (Lines[K].replace(/\r$/, "").trim() === WriteBack) {
				Back = K;
				break;
			}
		}

		if (Back < 0) {
			continue;
		}

		Lines[Call] = Lines[Call].replace(`(Scratch.${Scratch}, `, `(${Buffer}, ${Offset}, `);
		Removed.add(I);
		Removed.add(Back);
		Count += 1;
	}

	if (Count === 0) {
		continue;
	}

	let Kept = Lines.filter((_, Index) => !Removed.has(Index));
	const Text = Kept.join("\n");

	Kept = Kept.filter((Line) => {
		const Declaration = /^\t(\w+) = \{ 0 \},\r?$/.exec(Line);

		if (!Declaration) {
			return true;
		}

		const Uses = Text.split(`Scratch.${Declaration[1]}`).length - 1;

		return Uses > 0;
	});

	console.log(`${Name}: ${Count} site(s)`);
	Total += Count;

	if (Write) {
		fs.writeFileSync(File, Kept.join("\n"));
	}
}

console.log(`total ${Total}`);
