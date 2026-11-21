// Writes port/src/rom/segment2_symbols.luau: the segmented address (0x02xxxxxx) of every named symbol of bin/segment2.c (the display
// lists, vertex lists and lookup tables of the common 2D graphics: text, HUD, menus) and the text tables of text/define_text.inc.c,
// decision segment2-symbols.
//
// Segment 2 of the US ROM is laid out in four parts, each located in the ROM by its content:
//   * the textures: the offset is in the file name (`textures/segment2/segment2.00200.rgba16.inc.c`) and the same in every version;
//   * the lookup tables (`main_hud_lut`, `main_font_lut`, `main_credits_font_lut`, `main_hud_camera_lut`): their words are
//     the addresses of the textures the C names, so each table is found by searching its expected words in the ROM (the comment
//     addresses are those of another version);
//   * the text (dialogs, course and act names): the tables are the runs of segment 2 pointers after the debug text;
//   * the display lists and vertex lists after the text: the comment above a definition (`// 0x0200EC60 - 0x0200EC98`) holds the
//     address of another version, every one of them shifted by the same amount in the US ROM. The shift is the only one for
//     which every display list ends with G_ENDDL (found by search), so a wrong layout is an error.
//
// Usage: node native/tools/gen_segment2_symbols.mjs <project root>
import fs from "node:fs";
import path from "node:path";
import { ActiveText, Mio0Block } from "./c_source.mjs";

const Root = process.argv[2];
const Output = path.join(Root, "port/src/rom/segment2_symbols.luau");
const Segment2RomStart = 0x108a40;
const EndDisplayList = 0xb8000000;
const FirstListAddress = 0x0200ec60;
const ShiftLimit = 0x8000;
const DialogCount = 170;
const CourseNameCount = 26;
const ActNameCount = 97;
const Failures = [];
const Symbols = new Map();

function Fail(Message) {
	Failures.push(Message);
	console.log(`error: ${Message}`);
}

const Segment = Mio0Block(fs.readFileSync(path.join(Root, "rom/baserom.us.z64")), Segment2RomStart);
const Source = ActiveText(fs.readFileSync(path.join(Root, "reference/bin/segment2.c"), "utf8")).split(/\r?\n/);
const AddressComment = /^\/\/ .*?0x(02[0-9A-F]{6})(?:\s*-\s*0x(02[0-9A-F]{6}))?\s*$/;
const BlockAddressComment = /^\/\* 0x(02[0-9A-F]{6}): (\w+)$/;
const Definition = /^(?:ALIGNED8 )?(?:static )?const (\w+)(?: \*const)? \*?(\w+)\[\]/;
const TextureFile = /segment2\.([0-9A-F]{5})\./;

function Word(Offset) {
	return Segment.readUInt32BE(Offset);
}

// The definitions of the US build, in source order: name, type, the comment before it (address, end) and the lines of the initializer
const Definitions = [];

for (let Line = 0; Line < Source.length; Line++) {
	const Match = Definition.exec(Source[Line]);

	if (Match === null) {
		continue;
	}

	let Last = Line;

	while (Last < Source.length && !/^\};/.test(Source[Last])) {
		Last++;
	}

	const Comment = Line > 0 ? AddressComment.exec(Source[Line - 1]) : null;
	const Texture = TextureFile.exec(Source[Line + 1] ?? "");
	// A table described by a block comment (`/* 0x02015444: seg2_painting_mesh_neighbor_tris`) has its address in the first line of it
	const Described = Comment === null ? Source.slice(Math.max(0, Line - 12), Line).map((Text) => BlockAddressComment.exec(Text)).find((Found) => Found !== null && Found[2] === Match[2]) : undefined;

	Definitions.push({
		Name: Match[2],
		Type: Match[1],
		Pointers: /\*const\b/.test(Source[Line]),
		Address: Comment !== null ? parseInt(Comment[1], 16) : Described === undefined ? null : parseInt(Described[1], 16),
		End: Comment === null || Comment[2] === undefined ? null : parseInt(Comment[2], 16),
		Texture: Texture === null ? null : 0x02000000 + parseInt(Texture[1], 16),
		Body: Source.slice(Line + 1, Last),
	});
}

// The lookup tables: the items of the initializer are the textures it names (0x0 for a gap). The ROM table has a pointer to segment 2
// where the C names a texture and a zero word where it has a gap (the file names of the textures are not the US offsets: the
// textures that exist only in other versions are missing in the US layout); a table that this pattern does not find once is where
// the table before it ends
function Matches(At, Items) {
	for (let Index = 0; Index < Items.length; Index++) {
		const Value = Word(At + Index * 4);

		if ((Items[Index] === "0x0") !== (Value === 0) || (Value !== 0 && (Value >>> 24 !== 2 || (Value & 0xffffff) >= Segment.length))) {
			return false;
		}
	}

	return true;
}

let PreviousEnd = null;

for (const Definition of Definitions.filter((Candidate) => Candidate.Pointers)) {
	const Items = Definition.Body.join(" ")
		.split(",")
		.map((Item) => Item.trim())
		.filter((Item) => Item !== "");
	const Found = [];

	for (let At = 0; At + Items.length * 4 <= Segment.length; At += 4) {
		if (Matches(At, Items)) {
			Found.push(At);
		}
	}

	let At = -1;

	if (Found.length === 1) {
		At = Found[0];
	} else if (PreviousEnd !== null && Matches(PreviousEnd, Items)) {
		At = PreviousEnd;
	}

	if (At < 0) {
		Fail(`${Definition.Name}: its ${Items.length} words are not found in segment 2`);
		PreviousEnd = null;
	} else {
		Symbols.set(Definition.Name, 0x02000000 + At);
		PreviousEnd = At + Items.length * 4;
	}
}

// The text tables: runs of segment 2 pointers after the debug text
const HudLut = Symbols.get("main_hud_lut");
const Runs = [];

if (HudLut !== undefined) {
	let Cursor = (Symbols.get("main_hud_camera_lut") & 0xffffff) + 6 * 4;

	while (Cursor + 4 <= Segment.length) {
		const Start = Cursor;

		while (Cursor + 4 <= Segment.length && Word(Cursor) >>> 24 === 2 && (Word(Cursor) & 0xffffff) < Segment.length) {
			Cursor += 4;
		}

		const Count = (Cursor - Start) / 4 - (Cursor + 4 <= Segment.length && Word(Cursor) === 0 ? 0 : 0);

		if (Count >= 20) {
			Runs.push([Start, Count]);
		}

		Cursor += 4;
	}
}

if (Runs.length < 3 || Runs[0][1] < DialogCount || Runs[1][1] !== CourseNameCount || Runs[2][1] !== ActNameCount) {
	Fail(`the pointer runs of the text are not ${DialogCount} dialogs, ${CourseNameCount} course names and ${ActNameCount} act names: ${JSON.stringify(Runs.slice(0, 5))}`);
} else {
	Symbols.set("seg2_dialog_table", 0x02000000 + Runs[0][0] + (Runs[0][1] - DialogCount) * 4);
	Symbols.set("seg2_course_name_table", 0x02000000 + Runs[1][0]);
	Symbols.set("seg2_act_name_table", 0x02000000 + Runs[2][0]);
}

// The display lists and vertex lists after the text: one shift for all
const Listed = Definitions.filter((Candidate) => Candidate.Address !== null && Candidate.Address >= FirstListAddress);
const Displays = Listed.filter((Candidate) => Candidate.Type === "Gfx" && Candidate.End !== null);
let Shift = null;

for (let Candidate = -ShiftLimit; Candidate <= ShiftLimit && Shift === null; Candidate += 8) {
	if (Displays.every((Item) => (Item.End & 0xffffff) + Candidate - 8 >= 0 && Word((Item.End & 0xffffff) + Candidate - 8) === EndDisplayList)) {
		Shift = Candidate;
	}
}

if (Shift === null) {
	Fail("no shift of the comment addresses puts the end of every display list on a G_ENDDL");
} else {
	for (const Item of Listed) {
		Symbols.set(Item.Name, Item.Address + Shift);
	}

	console.log(`display lists shifted by 0x${Shift.toString(16)}`);

	// A display list of the US branch of a version conditional (dl_ia_text_begin) has no address comment: it starts where the
	// definition before it ends, and a display list ends after its first G_ENDDL
	const ListEnd = (Start) => {
		let At = Start;

		while (Word(At) !== EndDisplayList) {
			At += 8;
		}

		return At + 8;
	};
	let Cursor = null;

	for (const Item of Definitions) {
		if (Item.Address !== null) {
			if (Item.Address < FirstListAddress) {
				Cursor = null;
			} else if (Item.End !== null) {
				Cursor = (Item.End & 0xffffff) + Shift;
			} else {
				Cursor = Item.Type === "Gfx" ? ListEnd((Item.Address & 0xffffff) + Shift) : null;
			}
		} else if (Cursor !== null && Item.Type === "Gfx") {
			Symbols.set(Item.Name, 0x02000000 + Cursor);
			Cursor = ListEnd(Cursor);
		} else {
			Cursor = null;
		}
	}
}

const Lines = [
	"--!strict",
	"--!optimize 2",
	"",
	"--[[",
	"\tSegmented address of the named symbols of segment 2 (bin/segment2.c and text/define_text.inc.c, US ROM layout): the display lists,",
	"\tlookup tables and text tables of the common 2D graphics. segmented_to_virtual(Segment2Symbols.dl_hud_img_begin) is the Memory address.",
	"\tGenerated by native/tools/gen_segment2_symbols.mjs; do not edit.",
	"]]",
	"",
	"-- from bin/segment2.c:addresses",
	"return {",
];

for (const [Name, Value] of [...Symbols].sort((A, B) => A[0].localeCompare(B[0]))) {
	Lines.push(`\t${Name} = 0x${Value.toString(16).toUpperCase().padStart(8, "0")},`);
}

Lines.push("}", "");
console.log(`${Symbols.size} symbols, ${Failures.length} failure(s)`);

if (Failures.length === 0) {
	fs.writeFileSync(Output, Lines.join("\n"));
}

process.exit(Failures.length === 0 ? 0 : 1);
