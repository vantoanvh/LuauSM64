// Shared by the generators that read the decomp sources and the ROM: MIO0 blocks of the ROM and the lines of a C text that the US build compiles.

// The MIO0 block at Offset of the ROM, decompressed; null when the header is not one
export function Mio0Block(Rom, Offset) {
	if (Rom.toString("latin1", Offset, Offset + 4) !== "MIO0") {
		return null;
	}

	const Size = Rom.readUInt32BE(Offset + 4);
	const PairsAt = Rom.readUInt32BE(Offset + 8);
	const RawAt = Rom.readUInt32BE(Offset + 12);

	if (Size === 0 || Size > 0x400000 || PairsAt < 16 || RawAt < PairsAt || Offset + RawAt >= Rom.length) {
		return null;
	}

	const Out = Buffer.alloc(Size);
	let Written = 0;
	let BitAt = 16;
	let Pairs = PairsAt;
	let Raw = RawAt;
	let Bits = 0;
	let Mask = 0;

	while (Written < Size) {
		if (Mask === 0) {
			Bits = Rom.readUInt32BE(Offset + BitAt);
			BitAt += 4;
			Mask = 0x80000000;
		}

		if ((Bits & Mask) !== 0) {
			Out[Written++] = Rom[Offset + Raw++];
		} else {
			const Pair = Rom.readUInt16BE(Offset + Pairs);
			const Length = (Pair >> 12) + 3;
			const Distance = (Pair & 0xfff) + 1;

			Pairs += 2;

			for (let I = 0; I < Length && Written < Size; I++, Written++) {
				Out[Written] = Out[Written - Distance];
			}
		}

		Mask >>>= 1;
	}

	return Out;
}

// Every MIO0 block of the ROM, decompressed
export function Mio0Blocks(Rom) {
	const Blocks = [];

	for (let Offset = 0; Offset + 16 <= Rom.length; Offset += 16) {
		const Block = Mio0Block(Rom, Offset);

		if (Block !== null) {
			Blocks.push(Block);
		}
	}

	return Blocks;
}
// The macros of the US build (draft.sh); the others, VERSION_JP among them, are 0
const Defined = new Set(["VERSION_US", "TARGET_N64", "AVOID_UB", "NON_MATCHING", "F3D_OLD", "_LANGUAGE_C"]);

function Condition(Text) {
	const Expression = Text
		.replace(/\/\/.*$/, "")
		.replace(/\/\*.*?\*\//g, "")
		.replace(/defined\s*\(\s*(\w+)\s*\)|defined\s+(\w+)/g, (Match, A, B) => (Defined.has(A ?? B) ? "1" : "0"))
		.replace(/[A-Za-z_]\w*/g, (Name) => (Defined.has(Name) ? "1" : "0"));

	if (!/^[\d\s()!&|]+$/.test(Expression)) {
		throw new Error(`cannot evaluate #if ${Text}`);
	}

	return Function(`return (${Expression})`)() ? true : false;
}

// The lines the US build compiles (`#ifdef`, `#ifndef`, `#if`, `#elif`, `#else`, `#endif`)
export function ActiveText(Body) {
	const Kept = [];
	const Stack = [];

	for (const Line of Body.split(/\r?\n/)) {
		const Directive = /^\s*#\s*(ifdef|ifndef|if|elif|else|endif)\b\s*(.*)$/.exec(Line);

		if (Directive === null) {
			if (Stack.every((Frame) => Frame.Active)) {
				Kept.push(Line);
			}

			continue;
		}

		const [, Name, Rest] = Directive;

		if (Name === "ifdef" || Name === "ifndef" || Name === "if") {
			const Value = Name === "if" ? Condition(Rest) : Defined.has(Rest.replace(/\/\/.*$/, "").trim()) === (Name === "ifdef");

			Stack.push({ Active: Value, Taken: Value });
		} else if (Name === "elif") {
			const Frame = Stack[Stack.length - 1];
			const Value = !Frame.Taken && Stack.slice(0, -1).every((Outer) => Outer.Active) && Condition(Rest);

			Frame.Active = Value;
			Frame.Taken ||= Value;
		} else if (Name === "else") {
			const Frame = Stack[Stack.length - 1];

			Frame.Active = !Frame.Taken;
			Frame.Taken = true;
		} else {
			Stack.pop();
		}
	}

	return Kept.join("\n");
}

