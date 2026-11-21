// Checks the segmented address literals the draft took from symbol names (`0x0702A6B4 --[[ rr_seg7_collision_0702A6B4 ]]`).
// The decomp names a data symbol by its address in the ROM it was extracted from; in the US ROM the layout of rr and lll
// differs (rr: -0x1E8, lll: -0x90 from some point on). A table of game code that holds such a pointer is in the ROM with the
// real address, so an address that is not a word of the ROM is wrong. Tables that carry the real address keep the name's
// address in the comment: `0x0702A4CC --[[ rr_seg7_collision_0702A6B4 (ROM layout) ]]`.
//
// Usage (from the project root): node native/tools/check_named_addresses.mjs
import fs from "node:fs";
import path from "node:path";

const Rom = fs.readFileSync("rom/baserom.us.z64");
const Words = new Set();

for (let Offset = 0; Offset + 4 <= Rom.length; Offset += 4) {
	Words.add(Rom.readUInt32BE(Offset));
}

function* Files(Directory) {
	for (const Entry of fs.readdirSync(Directory, { withFileTypes: true })) {
		const Full = path.join(Directory, Entry.name);

		if (Entry.isDirectory()) {
			yield* Files(Full);
		} else if (Entry.name.endsWith(".luau")) {
			yield Full;
		}
	}
}

let Checked = 0;
let Missing = 0;

for (const File of Files("port/src")) {
	for (const Match of fs.readFileSync(File, "utf8").matchAll(/(0x0[0-9A-Fa-f]{7}) --\[\[ ([A-Za-z0-9_]+)/g)) {
		Checked++;
		if (!Words.has(parseInt(Match[1], 16))) {
			Missing++;
			console.log(`not in the ROM: ${Match[1]} ${Match[2]} (${File})`);
		}
	}
}
console.log(`${Checked} named addresses, ${Missing} not in the ROM`);
process.exit(Missing === 0 ? 0 : 1);
