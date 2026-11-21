--!strict
--!optimize 2

--[[
	The ROM image: the ModuleScript ReplicatedStorage.SM64Rom returns the whole ROM as a buffer (the .z64 file of Super Mario 64, US,
	converted to a ModuleScript by rom-tool/ with Buffer on, named SM64Rom; the tool leaves out the sound data, which the port never reads).
	The ROM is never part of this project: it is in the place the player made.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The big endian word at the start of a z64 ROM, the game's name at 0x20 and the region letter of the US version at 0x3E
const MagicNumber = 0x80371240
const GameName = "SUPER MARIO 64"
const UsRegion = string.byte("E")
const MinimumSize = 8 * 1024 * 1024

const function Load(): buffer
	const Module = ReplicatedStorage:WaitForChild("SM64Rom", 10)

	assert(Module ~= nil and Module:IsA("ModuleScript"), "ReplicatedStorage.SM64Rom is missing: convert your Super Mario 64 (US) ROM to a ModuleScript that returns a buffer and name it SM64Rom (README)")

	const Image = require(Module) :: unknown

	assert(typeof(Image) == "buffer", "SM64Rom must return a buffer: export the ROM with rom-tool, Buffer on")

	const Rom = Image :: buffer

	assert(buffer.len(Rom) >= MinimumSize, `SM64Rom is {buffer.len(Rom)} bytes: the ROM of Super Mario 64 is 8 MB`)
	assert(
		buffer.readu32(Rom, 0) == bit32.byteswap(MagicNumber),
		"SM64Rom is not a big endian .z64 ROM (a .v64 or .n64 file is byte swapped: convert it to .z64 first)"
	)
	assert(buffer.readstring(Rom, 0x20, #GameName) == GameName and buffer.readu8(Rom, 0x3E) == UsRegion, "SM64Rom is not the US version of Super Mario 64")

	return Rom
end

return Load
