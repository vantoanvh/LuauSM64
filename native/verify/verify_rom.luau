--!nonstrict
--!optimize 2

--[[
	Checks the ROM reader (port/src/rom) against the reference tools and extracted files:
		every MIO0 block of the ROM (16 byte aligned "MIO0" with a plausible header) decompressed by DecompressMio0 equals the
		output of the reference mio0 tool (reference/tools/sm64tools/mio0.exe -d);
		raw blocks (the extracted reference/assets/demos/*.bin, at the US offsets of reference/assets.json) loaded with
		LoadSegment equal the extracted files, and every Read* width agrees with string.unpack on those bytes;
		the segment table (SetSegmentBaseAddr, SegmentedToVirtual) and LoadMio0.

	Run from the repository root after the reference assets are extracted: lute run native/verify/verify_rom.luau
]]

const Fs = require("@std/fs")
const Process = require("@std/process")

const DecompressMio0 = require("../../port/src/rom/mio0")
const Rom = require("../../port/src/rom/rom")
const Symbols = require("../../port/src/rom/symbols")

const RomPath = "rom/baserom.us.z64"
const Mio0Tool = "reference/tools/sm64tools/mio0.exe"
const ScratchPath = `{Process.cwd()}/native/build/verify/mio0.out`

-- name -> US ROM offset, from reference/assets.json
const Demos = {
	{ Name = "bbh", Offset = 5741664 },
	{ Name = "ccm", Offset = 5742652 },
	{ Name = "hmc", Offset = 5743972 },
	{ Name = "jrb", Offset = 5744952 },
	{ Name = "pss", Offset = 5746244 },
	{ Name = "unused", Offset = 5746992 },
	{ Name = "wf", Offset = 5745572 },
	{ Name = "bitdw", Offset = 5747100 },
}

local Failures = 0

const function Check(Condition: boolean, Message: string)
	if not Condition then
		Failures += 1
		print(`FAIL {Message}`)
	end
end

Rom.Load(buffer.fromstring(Fs.readFileToString(RomPath)))

const Image = Rom.Image
local Blocks = 0
local Bytes = 0

for Offset = 0, buffer.len(Image) - 16, 16 do
	if buffer.readstring(Image, Offset, 4) ~= "MIO0" then
		continue
	end

	const Size = bit32.byteswap(buffer.readu32(Image, Offset + 4))
	const PairsAt = bit32.byteswap(buffer.readu32(Image, Offset + 8))
	const RawAt = bit32.byteswap(buffer.readu32(Image, Offset + 12))

	if Size == 0 or Size > 0x400000 or PairsAt < 16 or RawAt < PairsAt then
		continue
	end

	const Result = Process.run({ Mio0Tool, "-d", "-o", tostring(Offset), RomPath, ScratchPath })

	Check(Result.ok, `reference tool failed at {string.format("%X", Offset)}`)

	const Output = buffer.create(Size)

	Check(DecompressMio0(Image, Offset, Output, 0) == Size, `size at {string.format("%X", Offset)}`)
	Check(buffer.tostring(Output) == Fs.readFileToString(ScratchPath), `MIO0 block {string.format("%X", Offset)} differs`)

	Blocks += 1
	Bytes += Size
end

print(`mio0 blocks {Blocks}, {Bytes} bytes`)

-- Raw blocks and typed reads
for _, Demo in Demos do
	const Name = Demo.Name
	const Expected = Fs.readFileToString(`reference/assets/demos/{Name}.bin`)
	const Size = #Expected
	const Address = Rom.LoadSegment(7, Demo.Offset, Demo.Offset + Size)

	Check(Rom.SegmentedToVirtual(0x07000000) == Address, `{Name}: segment base`)
	Check(buffer.readstring(Rom.Memory, Address, Size) == Expected, `{Name}: raw block differs`)

	for Index = 0, Size - 4, 2 do
		Check(Rom.ReadU8(Address + Index) == string.unpack(">I1", Expected, Index + 1), `{Name}: u8 at {Index}`)
		Check(Rom.ReadS8(Address + Index) == string.unpack(">i1", Expected, Index + 1), `{Name}: s8 at {Index}`)
		Check(Rom.ReadU16(Address + Index) == string.unpack(">I2", Expected, Index + 1), `{Name}: u16 at {Index}`)
		Check(Rom.ReadS16(Address + Index) == string.unpack(">i2", Expected, Index + 1), `{Name}: s16 at {Index}`)
		Check(Rom.ReadU32(Address + Index) == string.unpack(">I4", Expected, Index + 1), `{Name}: u32 at {Index}`)
		Check(Rom.ReadS32(Address + Index) == string.unpack(">i4", Expected, Index + 1), `{Name}: s32 at {Index}`)

		const Float = string.unpack(">f", Expected, Index + 1)

		Check(Rom.ReadF32(Address + Index) == Float or (Float ~= Float and Rom.ReadF32(Address + Index) ~= Rom.ReadF32(Address + Index)), `{Name}: f32 at {Index}`)
	end
end

print("raw blocks checked")

-- Linker symbols of setup_game_memory: the level script entry, the MIO0 header of segment 2 and the two DMA tables
Rom.Load(buffer.fromstring(Fs.readFileToString(RomPath)))

const Entry = Rom.LoadSegment(0x10, Symbols.EntrySegmentRomStart, Symbols.EntrySegmentRomEnd)

Check(Rom.ReadU8(Entry) == 0x1B and Rom.ReadU8(Entry + 1) == 4, "entry segment starts with INIT_LEVEL")
Check(Symbols.EntrySegmentRomEnd == Symbols.Segment2Mio0SegmentRomStart, "segment 2 follows the entry segment")
Check(buffer.readstring(Rom.Image, Symbols.Segment2Mio0SegmentRomStart, 4) == "MIO0", "segment 2 MIO0 magic")
Check(buffer.readstring(Rom.Image, Symbols.Segment2Mio0SegmentRomEnd, 4) == "MIO0", "the segment after segment 2 starts at its end")
Check(bit32.byteswap(buffer.readu32(Rom.Image, Symbols.MarioAnims)) == 209, "Mario animation table count")
Check(bit32.byteswap(buffer.readu32(Rom.Image, Symbols.DemoInputs)) == 7, "demo table count")
Check(Symbols.DemoInputs + 8 + 7 * 8 == Demos[1].Offset, "the first demo follows the demo table")

-- seg2_dialog_table: 170 pointers to the 16 byte DialogEntry structs, then NULL; DIALOG_000 is `1, 6, 30, 200`
Rom.LoadMio0(2, Symbols.Segment2Mio0SegmentRomStart)

const DialogTable = Rom.SegmentedToVirtual(Symbols.Seg2DialogTable)
const Dialog0 = Rom.SegmentedToVirtual(Rom.ReadU32(DialogTable))

Check(Rom.ReadU32(DialogTable) == 0x0200FFC8, "seg2_dialog_table first entry")
Check(Rom.ReadU32(DialogTable + 4 * 169) == 0x0200FFC8 + 169 * 16, "seg2_dialog_table last entry")
Check(Rom.ReadU32(DialogTable + 4 * 170) == 0, "seg2_dialog_table is NULL terminated")
Check(Rom.ReadU32(Dialog0) == 1 and Rom.ReadS8(Dialog0 + 4) == 6, "DialogEntry unused and linesPerBox")
Check(Rom.ReadS16(Dialog0 + 6) == 30 and Rom.ReadS16(Dialog0 + 8) == 200, "DialogEntry leftOffset and width")
Check(bit32.rshift(Rom.ReadU32(Dialog0 + 12), 24) == 2, "DialogEntry str is a segment 2 address")

-- Segment table over a decompressed block: bob segment 7, ROM 0x3FC2B0, holds the bob collision at 0x0700E958
Rom.Load(buffer.fromstring(Fs.readFileToString(RomPath)))

const Base = Rom.LoadMio0(7, 0x3FC2B0)

Check(Base == 0, "first allocation at 0")
Check(Rom.SegmentedToVirtual(0x0700E958) == Base + 0xE958, "SegmentedToVirtual")
Check(Rom.ReadS16(Rom.SegmentedToVirtual(0x0700E958)) == 0x40, "bob collision starts with TERRAIN_LOAD_VERTICES")
Check(Rom.ReadS16(Rom.SegmentedToVirtual(0x0700E958) + 2) == 0x23A, "bob vertex count")
Check(Rom.SetSegmentBaseAddr(9, 0x100) == 0x100 and Rom.SegmentedToVirtual(0x09000010) == 0x110, "SetSegmentBaseAddr")

-- Blocks: an address maps back to the ROM start and offset of the load that holds it; a later load replaces an overlapped one
local RomStart, Offset = Rom.BlockOf(Base + 0xE958)

Check(RomStart == 0x3FC2B0 and Offset == 0xE958, "BlockOf of a decompressed block")

Rom.RecordBlock(Base, 0x20, 0x1234)
RomStart, Offset = Rom.BlockOf(Base + 0x10)
Check(RomStart == 0x1234 and Offset == 0x10, "a later block replaces the one it overlaps")
Check(not pcall(Rom.BlockOf, Base + 0xE958), "an address in no block errors")
Check(Rom.WriteU32(Base + 0x40, 0x89ABCDEF) == nil and Rom.ReadU32(Base + 0x40) == 0x89ABCDEF and buffer.readu8(Rom.Memory, Base + 0x40) == 0x89, "WriteU32")

print(Failures == 0 and "ROM reader OK" or `ROM reader: {Failures} failures`)
