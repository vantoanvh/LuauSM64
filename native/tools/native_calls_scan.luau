--!strict
--!optimize 2

--[[
	Finds the native slots of the ROM script data: compiles the script data sources for a 32-bit target, reads the
	relocations of the objects and places every object in the ROM.

	Used by gen_native_calls.luau and native/verify/verify_native_calls.luau; run from the repository root after native/build.sh
	(the generated headers in native/build/us) with the ROM in rom/baserom.us.z64.

	Blocks
		A block is the data the game loads into one segment with LOAD_RAW (sm64.ld): the behavior scripts (segment 0x13), the level
		scripts, the level geo layouts of a level (script.c then geo.c, segment 0x0E, 0x14 for intro and menu), the main level
		scripts and the actor geo layouts of a group. A block is named by its ROM start, the `from` of its LOAD_RAW, and a slot by
		its byte offset inside the block (the offset of the segmented address).

	Design Notes
		The compile follows the N64 build (TARGET_N64 turns `const` off and makes uintptr_t 32 bits) for gcc -m32; the alignment flags
		give the objects the packing of the N64 linker (u64 and double 8 aligned, arrays packed), zero data stays in .data.
		A relocation is a function slot when its symbol has the function type (gcc declares referenced functions with `.type 32`),
		the word at a slot is 0 in the object. A relocation of another symbol is a data slot when the ROM holds a RAM address
		there (the address of a C global such as a WaterDropletParams, not a segmented address of script data) and its name is
		not a linker symbol (`_goddardSegmentStart`). Every other word is compared with the ROM (big endian) at the object's
		position (found by its first word that is not a relocation, unique in the ROM), so a flag or define that changes the data
		is an error.
]]

const Fs = require("@std/fs")
const Process = require("@std/process")

const Rom = require("../../port/src/rom/rom")

const ObjectDirectory = "native/build/native_calls"
const LevelDefinesPath = "reference/levels/level_defines.h"
const LinkerScriptPath = "reference/sm64.ld"
const CoffDirectAddress = 6
const CoffFunctionType = 0x20
const RamStart = 0x80000000
const RamEnd = 0x80400000
const MaxBlockGap = 16

const CompileFlags = {
	"-m32",
	"-std=gnu90",
	"-O0",
	"-w",
	"-fsigned-char",
	"-fno-strict-aliasing",
	"-fwrapv",
	"-fno-toplevel-reorder",
	"-fno-zero-initialized-in-bss",
	"-malign-data=abi",
	"-malign-double",
	"-DVERSION_US=1",
	"-DNON_MATCHING=1",
	"-DAVOID_UB=1",
	"-DF3D_OLD=1",
	"-D_FINALROM=1",
	"-D_LANGUAGE_C",
	"-DTARGET_N64",
	"-Ireference/include",
	"-Inative/build/us",
	"-Inative/build/us/include",
	"-Ireference/src",
	"-Ireference",
}

export type Slot = { Offset: number, Name: string }

export type Block = {
	Name: string,
	RomStart: number,
	Size: number,
	Slots: { Slot },
}

type ObjectFile = {
	Source: string,
	Data: buffer,
	Masked: buffer,
	Slots: { Slot },
	DataSlots: { Slot },
}

type BlockSources = { Name: string, Sources: { string } }

const function ReadCString(Bytes: buffer, Offset: number): string
	local End = Offset

	while buffer.readu8(Bytes, End) ~= 0 do
		End += 1
	end

	return buffer.readstring(Bytes, Offset, End - Offset)
end

const function RunGcc(Source: string, Arguments: { string })
	const Command = { "gcc" }

	table.move(CompileFlags, 1, #CompileFlags, 2, Command)
	table.move(Arguments, 1, #Arguments, #Command + 1, Command)

	const Result = Process.run(Command)

	if not Result.ok then
		error(`gcc failed on {Source}: {Result.stderr}`)
	end
end

-- Compiles Source to an object file; returns its path
const function CompileSource(Source: string): string
	const BasePath = `{ObjectDirectory}/{(string.gsub(Source, "[/.]", "_"))}`

	RunGcc(Source, { "-E", "-o", `{BasePath}.i`, `reference/{Source}` })

	-- gcc places a variable where it is first declared, the N64 linker where it is defined: a forward declared static array
	-- becomes an extern declaration and its definition loses `static`
	local Text = Fs.readFileToString(`{BasePath}.i`)

	for _, Name in string.gmatch(Text, "\nstatic ([%w_ ]-)([%w_]+) ?%[[^%]=]*%];") do
		Text = string.gsub(Text, `\nstatic ([%w_ ]-){Name} ?%[[^%]=]*%];`, `\nextern %1{Name}[];`)
		Text = string.gsub(Text, `\nstatic ([%w_ ]-){Name} ?%[%] ?=`, `\n%1{Name}[] =`)
	end

	Fs.writeStringToFile(`{BasePath}.i`, Text)
	RunGcc(Source, { "-x", "cpp-output", "-c", "-o", `{BasePath}.o`, `{BasePath}.i` })

	return `{BasePath}.o`
end

-- Reads the .data section of an object (the only one with contents besides the compiler's .rdata$zzz ident), its relocated
-- words and its function slots
const function ReadObject(Source: string, ObjectPath: string): ObjectFile
	const Bytes = buffer.fromstring(Fs.readFileToString(ObjectPath))
	const SectionCount = buffer.readu16(Bytes, 2)
	const SymbolTable = buffer.readu32(Bytes, 8)
	const SymbolCount = buffer.readu32(Bytes, 12)
	const SectionTable = 20 + buffer.readu16(Bytes, 16)
	const StringTable = SymbolTable + 18 * SymbolCount
	const File = { Source = Source, Data = buffer.create(0), Masked = buffer.create(0), Slots = {} :: { Slot }, DataSlots = {} :: { Slot } }
	local HasData = false

	for Index = 0, SectionCount - 1 do
		const Header = SectionTable + 40 * Index
		local SectionName = buffer.readstring(Bytes, Header, 8)

		if string.sub(SectionName, 1, 1) == "/" then
			SectionName = ReadCString(Bytes, StringTable + tonumber(string.match(SectionName, "%d+")) :: number)
		else
			SectionName = string.match(SectionName, "^%C*") :: string
		end

		const Size = buffer.readu32(Bytes, Header + 16)

		if SectionName ~= ".data" then
			if Size ~= 0 and SectionName ~= ".rdata$zzz" then
				error(`{Source}: unexpected section {SectionName} of {Size} bytes`)
			end

			continue
		end

		if Size % 4 ~= 0 then
			error(`{Source}: .data size {Size} is not a whole number of words`)
		end

		HasData = true
		File.Data = buffer.create(Size)
		File.Masked = buffer.create(Size // 4)
		buffer.copy(File.Data, 0, Bytes, buffer.readu32(Bytes, Header + 20), Size)

		const Relocations = buffer.readu32(Bytes, Header + 24)

		for Relocation = 0, buffer.readu16(Bytes, Header + 32) - 1 do
			const Entry = Relocations + 10 * Relocation
			const Offset = buffer.readu32(Bytes, Entry)
			const Symbol = SymbolTable + 18 * buffer.readu32(Bytes, Entry + 4)

			if buffer.readu16(Bytes, Entry + 8) ~= CoffDirectAddress or Offset % 4 ~= 0 then
				error(`{Source}: relocation at {Offset} is not a word address`)
			end

				buffer.writeu8(File.Masked, Offset // 4, 1)

				const SymbolName = if buffer.readu32(Bytes, Symbol) == 0 then ReadCString(Bytes, StringTable + buffer.readu32(Bytes, Symbol + 4)) else string.match(buffer.readstring(Bytes, Symbol, 8), "^%C*") :: string

				if buffer.readu16(Bytes, Symbol + 14) == CoffFunctionType then
					if buffer.readu32(File.Data, Offset) ~= 0 then
						error(`{Source}: function slot {SymbolName} at {Offset} has an addend`)
					end

					table.insert(File.Slots, { Offset = Offset, Name = string.sub(SymbolName, 2) })
				else
					-- kept only where the ROM holds a RAM address (Run)
					table.insert(File.DataSlots, { Offset = Offset, Name = string.sub(SymbolName, 2) })
				end
		end
	end

	if not HasData then
		error(`{Source}: no .data section`)
	end

	return File
end

-- The ROM start of every object: where its words, except the relocated ones, equal the ROM (unique)
const function Locate(Files: { ObjectFile }): { number }
	const Image = Rom.Image
	const Anchors: { number } = {}
	const Targets: { [number]: { number } } = {}
	const Starts: { number } = {}

	for Index, File in Files do
		local Word = 0

		while Word < buffer.len(File.Masked) and buffer.readu8(File.Masked, Word) == 1 do
			Word += 1
		end

		if Word == buffer.len(File.Masked) then
			error(`{File.Source}: every word is a relocation`)
		end

		Anchors[Index] = Word * 4

		const Value = buffer.readu32(File.Data, Word * 4)

		Targets[Value] = Targets[Value] or {}
		table.insert(Targets[Value], Index)
	end

	for Position = 0, buffer.len(Image) - 4, 4 do
		const Candidates = Targets[bit32.byteswap(buffer.readu32(Image, Position))]

		if Candidates == nil then
			continue
		end

		for _, Index in Candidates do
			const File = Files[Index]
			const Start = Position - Anchors[Index]
			local Equal = Start >= 0 and Start + buffer.len(File.Data) <= buffer.len(Image)

			if Equal then
				for Word = 0, buffer.len(File.Masked) - 1 do
					if buffer.readu8(File.Masked, Word) == 0 and bit32.byteswap(buffer.readu32(Image, Start + Word * 4)) ~= buffer.readu32(File.Data, Word * 4) then
						Equal = false

						break
					end
				end
			end

			if Equal then
				if Starts[Index] ~= nil then
					error(`{File.Source}: found in the ROM at {Starts[Index]} and {Start}`)
				end

				Starts[Index] = Start
			end
		end
	end

	const Missing: { string } = {}

	for Index, File in Files do
		if Starts[Index] == nil then
			table.insert(Missing, File.Source)
		end
	end

	if #Missing > 0 then
		error(`compiled words do not match the ROM: {table.concat(Missing, ", ")}`)
	end

	return Starts
end

-- The blocks and their sources in ROM order of sm64.ld; levels from level_defines.h, actor groups from sm64.ld
const function BlockList(): { BlockSources }
	const Blocks = {
		{ Name = "behavior", Sources = { "data/behavior_data.c" } },
		{ Name = "entry", Sources = { "levels/entry.c" } },
		{ Name = "scripts", Sources = { "levels/scripts.c" } },
		{ Name = "intro", Sources = { "levels/intro/script.c", "levels/intro/geo.c" } },
		{ Name = "menu", Sources = { "levels/menu/script.c", "levels/menu/geo.c" } },
	} :: { BlockSources }

	for Group in string.gmatch(Fs.readFileToString(LinkerScriptPath), "\n%s+STANDARD_OBJECTS%((%w+),") do
		table.insert(Blocks, { Name = `{Group}_geo`, Sources = { `actors/{Group}_geo.c` } })
	end

	for Folder in string.gmatch(Fs.readFileToString(LevelDefinesPath), '\nDEFINE_LEVEL%("[^"]*",%s*[%w_]+,%s*[%w_]+,%s*([%w_]+),') do
		table.insert(Blocks, { Name = Folder, Sources = { `levels/{Folder}/script.c`, `levels/{Folder}/geo.c` } })
	end

	return Blocks
end

-- Compiles and places every block; stops with an error where a block does not equal the ROM
const function Run(RomPath: string): { Block }
	Rom.Load(buffer.fromstring(Fs.readFileToString(RomPath)))

	if not Fs.exists(ObjectDirectory) then
		Fs.createDirectory(ObjectDirectory)
	end

	const Sources = BlockList()
	const Files: { ObjectFile } = {}
	const FileBlocks: { number } = {}
	const Blocks: { Block } = {}

	for BlockIndex, Source in Sources do
		for _, Path in Source.Sources do
				table.insert(Files, ReadObject(Path, CompileSource(Path)))
			table.insert(FileBlocks, BlockIndex)
		end
	end

	const Starts = Locate(Files)
	const RomStarts: { [number]: string } = {}
	local FileIndex = 1

	for BlockIndex, Source in Sources do
		const RomStart = Starts[FileIndex]
		const Block = { Name = Source.Name, RomStart = RomStart, Size = 0, Slots = {} :: { Slot } }
		local End = RomStart

		if RomStarts[RomStart] ~= nil then
			error(`blocks {RomStarts[RomStart]} and {Source.Name} start at the same ROM address`)
		end

		RomStarts[RomStart] = Source.Name

		while FileBlocks[FileIndex] == BlockIndex do
			const File = Files[FileIndex]
			const Start = Starts[FileIndex]

			if Start < End or Start - End >= MaxBlockGap then
				error(`{File.Source}: starts {Start - End} bytes after the previous file of its block`)
			end

			for Gap = End, Start - 1 do
				if buffer.readu8(Rom.Image, Gap) ~= 0 then
					error(`{File.Source}: the padding before it is not zero`)
				end
			end

			for _, Slot in File.Slots do
				table.insert(Block.Slots, { Offset = Start - RomStart + Slot.Offset, Name = Slot.Name })
			end

			for _, Slot in File.DataSlots do
				const Address = bit32.byteswap(buffer.readu32(Rom.Image, Start + Slot.Offset))

				if Address >= RamStart and Address < RamEnd and string.sub(Slot.Name, 1, 1) ~= "_" then
					table.insert(Block.Slots, { Offset = Start - RomStart + Slot.Offset, Name = Slot.Name })
				end
			end

			End = Start + buffer.len(File.Data)
			FileIndex += 1
		end

		Block.Size = End - RomStart
		table.insert(Blocks, Block)
	end

	return Blocks
end

return Run
