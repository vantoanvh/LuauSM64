// Writes port/src/rom/segment_symbols.luau: the segmented address of every named level and actor data symbol that carries no address in
// its name (bob_seg7_trajectory_koopa, wf_seg7_collision_tumbling_bridge, ttc_movtex_tris_*), decisions segment-symbol-addresses and
// rom-layout-named-addresses.
//
// Source of the addresses: the decomp states them in the comment above each definition of levels/**/*.inc.c and actors/**/*.inc.c
// (`// 0x070116A0` or `// 0x070102D8 - 0x07011C36`): the symbol defined next is at that segmented address of the layout the comment
// was taken from. That layout is not the US ROM everywhere (rr: -0x1E8 and -0x1BC, lll: -0x90 from some point on), so the comment
// is corrected with the ROM:
//   * a collision or trajectory symbol (`COL_INIT()`, `TRAJECTORY_POS(..)`, named with or without its address) is searched in every
//     MIO0 block of the ROM by its leading s16 words; the match nearest to the comment is its real address (an anchor);
//   * the layout shifts only where a symbol changed size, so a symbol between two anchors of the same level and segment that agree
//     takes their shift; a symbol before the first or after the last anchor takes the shift of the nearest; a symbol in a group
//     without any anchor keeps its comment (counted); a symbol between two anchors that disagree is an error (searched by hand).
// A moving texture array or quad collection without an address comment (hmc_movtex_dorrie_pool_water) is placed after the
// definition before it in its file, whose size is counted from its macros (MOV_TEX_* words, 8 bytes an entry of a collection).
// Cross-check: a symbol whose name ends in its own address must agree with its comment (the script fails otherwise).
//
// Usage: node native/tools/gen_segment_symbols.mjs <project root>
import fs from "node:fs";
import path from "node:path";
import { ActiveText, Mio0Blocks } from "./c_source.mjs";

const Root = process.argv[2];
const Roots = ["levels", "actors"].map((Name) => path.join(Root, "reference", Name));
const Output = path.join(Root, "port/src/rom/segment_symbols.luau");
// a comment of the decomp may drop the leading zero of the segmented address (`// 0x7011E08`)
const Comment = /^\/\/ 0x([0-9A-F]{7,8})(?: - 0x([0-9A-F]{8}))?\s*$/;
// the s16 words of the macros of include/moving_texture_macros.h (any other has one)
const MovtexMacroWords = { INIT_LOAD: 2, "4_BOX_TRIS": 2, TRIS: 5, ROT_TRIS: 8, LIGHT_TRIS: 8, ROT_END: 2 };
const MovtexDefinition = /^(?:static |const )*([A-Za-z_][\w ]*?)\s+(\w+)\s*\[[^\]]*\]\s*=/;
const CollisionWords = {
	COL_INIT: 1,
	COL_VERTEX_INIT: 1,
	COL_VERTEX: 3,
	COL_TRI_INIT: 2,
	COL_TRI: 3,
	COL_TRI_SPECIAL: 4,
	COL_TRI_STOP: 1,
	COL_END: 1,
	COL_SPECIAL_INIT: 2,
	COL_WATER_BOX_INIT: 2,
	COL_WATER_BOX: 6,
	SPECIAL_OBJECT: 4,
	SPECIAL_OBJECT_WITH_YAW: 5,
	SPECIAL_OBJECT_WITH_YAW_AND_PARAM: 6,
};
const Anchor = /_([0-9A-F]{8})$/;
const AnchorWords = 16;
const MinWords = 8;
const MaxShift = 0x2000;

function* Files(Directory) {
	for (const Entry of fs.readdirSync(Directory, { withFileTypes: true })) {
		const Full = path.join(Directory, Entry.name);

		if (Entry.isDirectory()) {
			yield* Files(Full);
		} else if (Entry.name.endsWith(".inc.c")) {
			yield Full;
		}
	}
}

// US size minus the size of the comment's layout, or null when it cannot be told: 0 for a symbol without conditionals, the word
// count of a Collision (the COL_* macros are expanded), unknown for any other symbol that has conditionals
function SizeChange(Header, Body, CommentSize) {
	if (ActiveText(Body) === Body) {
		return 0;
	}

	if (!/\bCollision\b/.test(Header) || CommentSize === null) {
		return null;
	}

	const Text = ActiveText(Body).replace(/\/\*.*?\*\//g, "").replace(/\/\/.*$/gm, "");
	let Words = 0;

	for (const Match of Text.matchAll(/\b([A-Z_]+)\s*\(/g)) {
		Words += CollisionWords[Match[1]] ?? 0;
	}

	return Math.ceil((Words * 2) / 4) * 4 - CommentSize;
}

// The leading 16 bit words of a symbol whose initializer is plain numbers (a s16 or u16 array, a Collision or a Trajectory: the
// COL_* and TRAJECTORY_POS macros are expanded), or null for any other symbol or when it is too short to identify
function LeadingWords(Header, Body) {
	if (!/\b(s16|u16|Collision|Trajectory)\b/.test(Header)) {
		return null;
	}

	const Text = ActiveText(Body).replace(/\/\*.*?\*\//g, "").replace(/\/\/.*$/gm, "");
	const Words = [];
	const Item = /(COL_INIT|COL_VERTEX_INIT|COL_VERTEX|TRAJECTORY_POS)\s*\(([^)]*)\)|([^,{}\s][^,{}]*)/g;
	let Match;

	Item.lastIndex = Text.indexOf("{") + 1;

	while ((Match = Item.exec(Text)) !== null && Words.length < AnchorWords) {
		if (Match[1] === "COL_INIT") {
			Words.push(0x40);
			continue;
		}

		for (const Token of (Match[2] ?? Match[3]).split(",")) {
			if (!/^-?(0x[0-9a-f]+|\d+)$/i.test(Token.trim())) {
				return Words.length >= MinWords ? Words : null;
			}

			Words.push(Number(Token.trim()));
		}
	}

	return Words.length >= MinWords ? Words : null;
}

// The shift of the ROM address from the comment address: the words must be found once within MaxShift of it
function FindAnchor(Blocks, Words, Address) {
	const Pattern = Buffer.alloc(Words.length * 2);
	const Wanted = Address & 0xffffff;
	const Shifts = new Set();

	Words.forEach((Word, I) => Pattern.writeUInt16BE(Word & 0xffff, I * 2));

	for (const Block of Blocks) {
		for (let At = Block.indexOf(Pattern); At >= 0; At = Block.indexOf(Pattern, At + 1)) {
			if (Math.abs(At - Wanted) <= MaxShift) {
				Shifts.add(At - Wanted);
			}
		}
	}

	return Shifts.size === 1 ? [...Shifts][0] : null;
}

// The size in bytes of a Movtex array (the words of its macros, up to a multiple of 4) or of a MovtexQuadCollection (8 bytes an entry,
// with the terminator), null for any other type
function MovtexSize(Type, Body) {
	const Text = ActiveText(Body).replace(/\/\*.*?\*\//g, "").replace(/\/\/.*$/gm, "");

	if (Type === "Movtex") {
		let Words = 0;

		for (const Match of Text.matchAll(/\bMOV_TEX_(\w+)\s*\(/g)) {
			Words += MovtexMacroWords[Match[1]] ?? 1;
		}

		return Math.ceil((Words * 2) / 4) * 4;
	}

	if (Type === "struct MovtexQuadCollection") {
		return [...Text.slice(Text.indexOf("{") + 1).matchAll(/\{[^{}]*\}/g)].length * 8;
	}

	return null;
}

const Symbols = [];
let Failures = 0;

for (const File of Roots.flatMap((Directory) => [...Files(Directory)])) {
	const Lines = fs.readFileSync(File, "utf8").split(/\r?\n/);
	const Placed = new Map();

	for (let I = 0; I + 1 < Lines.length; I++) {
		const Address = Comment.exec(Lines[I]);

		if (Address === null) {
			continue;
		}

		// the definition is on the next lines (a comment or attribute line may sit between)
		let Name = null;
		let Start = I;

		for (let J = I + 1; J < Math.min(I + 3, Lines.length) && Name === null; J++) {
			const Match = /\b([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*=/.exec(Lines[J]);

			Name = Match === null ? null : Match[1];
			Start = J;
		}

		if (Name === null) {
			continue;
		}

		const Digits = Address[1].padStart(8, "0");
		const Value = parseInt(Digits, 16);
		const CommentEnd = Address[2] === undefined ? null : parseInt(Address[2], 16);
		const Suffix = Anchor.exec(Name);

		if (Suffix !== null && parseInt(Suffix[1], 16) !== Value) {
			// the actors' comments hold two typos of the decomp (whomp, breakable_box); the level data is the one that is relied on
			const InLevels = File.startsWith(Roots[0]);

			console.log(`${InLevels ? "error" : "warning"}: ${path.relative(Root, File)}: ${Name} is commented 0x${Address[1]}`);
			Failures += InLevels ? 1 : 0;
			continue;
		}

		// the symbols that share a layout: a level (or actor) directory and a segment
		const Unit = path.relative(path.join(Root, "reference"), File).split(path.sep).slice(0, 2).join("/");
		let End = Start;

		while (End < Lines.length && !/^\};/.test(Lines[End])) {
			End++;
		}

		const Symbol = {
			Name,
			Value,
			Named: Suffix !== null,
			Group: `${Unit}:${Digits.slice(0, 2)}`,
			End: CommentEnd,
			SizeChange: SizeChange(Lines[Start], Lines.slice(Start, End).join("\n"), CommentEnd === null ? null : CommentEnd - Value),
			Words: LeadingWords(Lines[Start], Lines.slice(Start, End).join("\n")),
			Shift: null,
		};

		Symbols.push(Symbol);
		Placed.set(Name, Symbol);
	}

	// A moving texture array or quad collection without an address comment (the collection after its data, the waterfall after
	// the water quads) follows the definition before it, which ends at the end of its comment or at its address plus its size
	let Cursor = null;
	let Group = null;

	for (let I = 0; I < Lines.length; I++) {
		const Definition = MovtexDefinition.exec(Lines[I]);

		if (Definition === null) {
			continue;
		}

		const Name = Definition[2];
		const Known = Placed.get(Name);
		let End = I;

		while (End < Lines.length && !/^\};/.test(Lines[End])) {
			End++;
		}

		const Size = MovtexSize(Definition[1], Lines.slice(I, End).join("\n"));

		if (Known !== undefined) {
			Cursor = Size === null ? Known.End : Known.Value + Size;
			Group = Known.Group;
		} else if (Size !== null) {
			if (Cursor === null) {
				console.log(`error: ${path.relative(Root, File)}: ${Name} has no address comment and no definition before it that ends at a known address`);
				Failures += 1;
			} else {
				Symbols.push({ Name, Value: Cursor, Named: false, Group, End: Cursor + Size, SizeChange: 0, Words: null, Shift: null });
				Cursor += Size;
			}
		} else {
			Cursor = null;
		}

		I = End;
	}
}

const Blocks = Mio0Blocks(fs.readFileSync(path.join(Root, "rom/baserom.us.z64")));

console.log(`${Blocks.length} MIO0 blocks, ${Symbols.length} symbols`);

const Groups = new Map();

for (const Symbol of Symbols) {
	if (Symbol.Words !== null) {
		Symbol.Shift = FindAnchor(Blocks, Symbol.Words, Symbol.Value);

		if (Symbol.Shift === null) {
			console.log(`not an anchor: ${Symbol.Name} (0x${Symbol.Value.toString(16)}) is not found once near its comment`);
			Symbol.Words = null;
		}
	}

	if (!Groups.has(Symbol.Group)) {
		Groups.set(Symbol.Group, []);
	}

	Groups.get(Symbol.Group).push(Symbol);
}

let Unanchored = 0;

for (const Members of Groups.values()) {
	Members.sort((A, B) => A.Value - B.Value);

	const Anchors = Members.filter((Symbol) => Symbol.Words !== null && Symbol.Shift !== null);

	for (const Symbol of Members) {
		if (Symbol.Words !== null) {
			continue;
		}

		if (Anchors.length === 0) {
			Symbol.Shift = 0;
			Unanchored += 1;
			continue;
		}

		const Before = Anchors.filter((Candidate) => Candidate.Value <= Symbol.Value).pop();
		const After = Anchors.find((Candidate) => Candidate.Value > Symbol.Value);

		if (Before === undefined) {
			Symbol.Shift = After.Shift;
		} else if (After === undefined || Before.Shift === After.Shift) {
			Symbol.Shift = Before.Shift;
		} else {
			// the symbol that ends where this one starts, and the size it changed by, give the shift directly
			const Previous = Members[Members.indexOf(Symbol) - 1];

			if (Previous !== undefined && Previous.Shift !== null && Previous.End === Symbol.Value && Previous.SizeChange !== null) {
				Symbol.Shift = Previous.Shift + Previous.SizeChange;

				if (Symbol.Shift !== Before.Shift && Symbol.Shift !== After.Shift) {
					console.log(`error: ${Symbol.Name} (0x${Symbol.Value.toString(16)}) follows ${Previous.Name}: shift ${Symbol.Shift} is not ${Before.Shift} or ${After.Shift}`);
					Failures += 1;
				}
			} else if (!Symbol.Named) {
				console.log(`error: ${Symbol.Name} (0x${Symbol.Value.toString(16)}) lies between anchors that shift by ${Before.Shift} and ${After.Shift}`);
				Failures += 1;
			}
		}
	}
}

const Found = new Map();

for (const Symbol of Symbols) {
	if (Symbol.Named || Symbol.Shift === null) {
		continue;
	}

	const Value = Symbol.Value + Symbol.Shift;

	if (Found.has(Symbol.Name) && Found.get(Symbol.Name) !== Value) {
		console.log(`${Symbol.Name} has two addresses`);
		Failures += 1;
	}

	Found.set(Symbol.Name, Value);
}

for (const Symbol of Symbols) {
	if (Symbol.Words !== null && Symbol.Shift !== 0 && !Symbol.Named) {
		console.log(`anchor ${Symbol.Group} ${Symbol.Name} shifts by ${Symbol.Shift}`);
	}
}

const Shifted = Symbols.filter((Symbol) => Symbol.Shift !== null && Symbol.Shift !== 0 && !Symbol.Named).length;

console.log(`${Found.size} symbols, ${Shifted} shifted from their comment, ${Unanchored} in a group without an anchor, ${Failures} failure(s)`);

const Lines = [
	"--!strict",
	"--!optimize 2",
	"",
	"--[[",
	"\tSegmented address of the named level and actor data symbols that carry no address in their name (US ROM layout).",
	"\tsegmented_to_virtual(SegmentSymbols.bob_seg7_trajectory_koopa) is the Memory address of the data.",
	"\tGenerated by native/tools/gen_segment_symbols.mjs; do not edit.",
	"]]",
	"",
	"-- from levels/*/*.inc.c:addresses",
	"return {",
];

for (const [Name, Value] of [...Found].sort((A, B) => A[0].localeCompare(B[0]))) {
	Lines.push(`\t${Name} = 0x${Value.toString(16).toUpperCase().padStart(8, "0")},`);
}

Lines.push("}", "");

if (Failures === 0) {
	fs.writeFileSync(Output, Lines.join("\n"));
}

process.exit(Failures === 0 ? 0 : 1);
