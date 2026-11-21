--!strict
--!optimize 2

--[[
	Checks port/src/rom/native_calls.luau (the function or C global behind each RAM address in the ROM scripts) against the ROM and
	a fresh compile of the script data (native/tools/native_calls_scan.luau, which stops where the compiled bytes differ from the ROM):
		the table holds exactly the slots of the compile, block by block, with the same names;
		every slot is a word the ROM holds as a RAM address (0x80000000 to 0x803FFFFF);
		a name is always the same ROM address and an address always the same name (so the position decides, not a guess);
		the word before every behavior slot is the CALL_NATIVE or the SPAWN_WATER_DROPLET command;
		the ROM start of every block except entry is the `from` of a LOAD_RAW, EXECUTE or EXIT_AND_EXECUTE command the ROM scripts hold (so the key
		is the one the game loads the segment with);
		NameAt agrees with the table and has no slot between the slots;
		every name resolves through the Registry (FunctionAt/DataAt) except the ones the draft leaves out and the ones of a module that
		cannot load yet.

	Run from the repository root after native/build.sh: lute run native/verify/verify_native_calls.luau

	Design Notes
		FunctionAt and DataAt only find modules that have loaded. The draft makes every module that defines a name of register.txt
		(generated with the table by gen_native_calls.luau) register itself and groups/loader lists every module that registers, so
		the check requires each module of that list first, one at a time (groups/loader itself stops at the first one that fails). A
		harness or game that uses slots requires them all before its first slot lookup.
		A module that errors while loading is a failure unless it is in PendingModules: an unwritten module whose data calls a macro
		stub. Its names may stay unresolved, and a pending module that loads fine is a failure too (remove it from the list).
]]

const Fs = require("@std/fs")

const ScanBlocks = require("../tools/native_calls_scan")
const NativeCalls = require("../../port/src/rom/native_calls")
const Rom = require("../../port/src/rom/rom")

const RomPath = "rom/baserom.us.z64"
const RamStart = 0x80000000
const RamEnd = 0x80400000
const CallNativeCommand = 0x0C000000
const SpawnWaterDropletCommand = 0x37000000
const LoadRawCommand = 0x170C0000
const ExecuteCommand = 0x00100000
const ExitAndExecuteCommand = 0x01100000
const CommandMask = 0xFFFF0000

-- Functions of the slots that no module of the draft defines (none now: the callbacks of the files the draft excludes live in the hand
-- written src/game/excluded_callbacks and src/game/moving_texture).
const NotDrafted: { string } = {}

-- Modules that cannot load yet (module path under port/ without .luau); none now.
const PendingModules: { string } = {}

local Failures = 0

const function Check(Condition: boolean, Message: string)
	if not Condition then
		Failures += 1
		print(`FAIL {Message}`)
	end
end

const function ReadRomWord(Position: number): number
	return bit32.byteswap(buffer.readu32(Rom.Image, Position))
end

-- The source of every pending module that failed to load, to tell its names from a name that is simply missing
const PendingSources: { string } = {}

for LoaderLine in string.gmatch(Fs.readFileToString("port/groups/loader.luau"), "require%(\"%.%.?/([^\"]+)\"%)") do
	-- the loader lists its own group modules as ./name and the others as ../path
	const Path = if Fs.exists(`port/{LoaderLine}.luau`) then LoaderLine else `groups/{LoaderLine}`
	const Loaded, Message = pcall(require, `../../port/{Path}`)

	if table.find(PendingModules, Path) then
		Check(not Loaded, `{Path}: loads, remove it from PendingModules`)

		if not Loaded then
			const Source = Fs.readFileToString(`port/{Path}.luau`)

			table.insert(PendingSources, Source)
		end
	else
		Check(Loaded, `{Path}: {Message}`)
	end
end

const function IsPending(Name: string): boolean
	for _, Source in PendingSources do
		if string.find(Source, `.{Name}(`, 1, true) then
			return true
		end
	end

	return false
end

const Blocks = ScanBlocks(RomPath)
const NameOfAddress: { [number]: string } = {}
const AddressOfName: { [string]: number } = {}
const LoadedFrom: { [number]: boolean } = {}
const ResolvedNames: { [string]: boolean } = {}
local Total = 0
local TableBlocks = 0

for RomStart in NativeCalls.Blocks do
	TableBlocks += 1
end

for _, Block in Blocks do
	const Slots = NativeCalls.Blocks[Block.RomStart]
	local Count = 0

	for Position = Block.RomStart, Block.RomStart + Block.Size - 12, 4 do
		const Command = bit32.band(ReadRomWord(Position), CommandMask)

		if Command == LoadRawCommand or Command == ExecuteCommand or Command == ExitAndExecuteCommand then
			LoadedFrom[ReadRomWord(Position + 4)] = true
		end
	end

	if Slots ~= nil then
		for _ in Slots do
			Count += 1
		end

		TableBlocks -= 1
	end

	Check(Count == #Block.Slots, `{Block.Name}: table has {Count} slots, the compile {#Block.Slots}`)
	print(`{Block.Name}: {#Block.Slots} slots`)

	for _, Slot in Block.Slots do
		const Position = Block.RomStart + Slot.Offset
		const Address = ReadRomWord(Position)

		Check(NativeCalls.NameAt(Block.RomStart, Slot.Offset) == Slot.Name, `{Block.Name}+{Slot.Offset}: table does not have {Slot.Name}`)
		Check(NativeCalls.NameAt(Block.RomStart, Slot.Offset + 2) == nil, `{Block.Name}+{Slot.Offset}: NameAt between slots`)
		Check(Address >= RamStart and Address < RamEnd, `{Block.Name}+{Slot.Offset}: {Slot.Name} holds {string.format("0x%08X", Address)} in the ROM`)
		Check(AddressOfName[Slot.Name] == nil or AddressOfName[Slot.Name] == Address, `{Slot.Name}: two ROM addresses`)
		Check(NameOfAddress[Address] == nil or NameOfAddress[Address] == Slot.Name, `{string.format("0x%08X", Address)}: two names`)

		if Block.Name == "behavior" then
			const Command = ReadRomWord(Position - 4)

			Check(Command == CallNativeCommand or Command == SpawnWaterDropletCommand, `behavior+{Slot.Offset}: {Slot.Name} is not the operand of CALL_NATIVE or SPAWN_WATER_DROPLET`)
		end

		AddressOfName[Slot.Name] = Address
		NameOfAddress[Address] = Slot.Name
		Total += 1

		if ResolvedNames[Slot.Name] == nil then
			const Resolved, Message = pcall(NativeCalls.DataAt, Block.RomStart, Slot.Offset)

			ResolvedNames[Slot.Name] = Resolved

			if Resolved then
				Check(not table.find(NotDrafted, Slot.Name), `{Slot.Name}: resolves but is listed as not drafted`)
			else
				Check(table.find(NotDrafted, Slot.Name) ~= nil or IsPending(Slot.Name), `{Slot.Name}: {Message}`)
			end
		end
	end
end

Check(TableBlocks == 0, `the table has {TableBlocks} blocks the compile does not`)

for _, Block in Blocks do
	Check(Block.Name == "entry" or LoadedFrom[Block.RomStart] == true, `{Block.Name}: no LOAD_RAW, EXECUTE or EXIT_AND_EXECUTE of the ROM scripts loads ROM {string.format("0x%X", Block.RomStart)}`)
end

local Names = 0
local Resolved = 0

for _ in AddressOfName do
	Names += 1
end

for _, IsResolved in ResolvedNames do
	if IsResolved then
		Resolved += 1
	end
end

print(`{Total} slots, {Names} functions, {Resolved} resolve through the Registry`)
print(if Failures == 0 then "native calls OK" else `native calls: {Failures} failures`)
