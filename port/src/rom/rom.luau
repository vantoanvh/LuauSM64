--!strict
--!optimize 2

--[[
	ROM-resident game data: the ROM image, the address space the game keeps loaded data in, and the segment table over it.

	Address Space
		Memory is one buffer standing in for the RAM the game loads segments into. A pointer to loaded data is a byte offset into
		Memory (a number), so C `*p` of an s16 is ReadS16(p) and `p + n` of an s16 is `p + 2 * n`. NULL is nil.
		A segmented address is (segment << 24) | offset; SegmentedToVirtual turns it into a Memory offset through the segment table.

	Owned State
		Image (the ROM, set by Load), Memory, the segment table and the allocation cursor of Memory.

	Design Notes
		Allocation only grows; Load rewinds it. The game's pool (main_pool_alloc and friends) frees in a stack order a caller of
		LoadSegment/LoadMio0 can reproduce when it needs to; nothing needs it yet.
		Allocate, WriteU8, WriteS16 and WriteU32 are for data the game builds in RAM that is read back through pointers.
		RecordBlock notes where the bytes of a ROM block went in Memory (a DMA or a decompression): BlockOf turns the address of a
		script slot back into the ROM start of its block and its offset in it, the key of NativeCalls. A later block replaces the
		ones it overlaps (the game frees and reuses pool space), so the newest block that holds an address is the one it came from.
		The last StackSize bytes of Memory are the C stack: PushStack/PopStack give a function the arrays of its frame that are read
		back through pointers (the transformed vertices of an object's collision model), a call must pop what it pushed.
		All data in the ROM is big endian.
]]

const DecompressMio0 = require("./mio0")

const MemorySize = 0x800000
const StackSize = 0x10000
const StackBase = MemorySize - StackSize
const Scratch = buffer.create(4)
const Memory = buffer.create(MemorySize)
const SegmentTable = table.create(32, 0)

type Block = { Address: number, Size: number, RomStart: number }

const Blocks: { Block } = {}
const Statics: { [string]: number } = {}

local Allocated = 0
local StackTop = StackBase

const Rom = {
	Image = buffer.create(0),
	Memory = Memory,
}

-- Reserves Size bytes of Memory (16 byte aligned, as the pool blocks are); returns the address
function Rom.Allocate(Size: number): number
	const Address = Allocated

	Allocated += bit32.band(Size + 15, 0xFFFFFFF0)

	if Allocated > StackBase then
		error("out of memory")
	end

	return Address
end

-- Reserves Size bytes of the stack (16 byte aligned); returns the address
function Rom.PushStack(Size: number): number
	const Address = StackTop

	StackTop += bit32.band(Size + 15, 0xFFFFFFF0)

	if StackTop > MemorySize then
		error("out of stack")
	end

	return Address
end

-- Releases the last PushStack of the same Size
function Rom.PopStack(Size: number)
	StackTop -= bit32.band(Size + 15, 0xFFFFFFF0)
end

-- Makes Image (the ROM bytes) the ROM and empties Memory and the segment table (the segment table is 1-based: segment S is [S + 1])
function Rom.Load(Image: buffer)
	Rom.Image = Image
	Allocated = 0
	StackTop = StackBase
	buffer.fill(Memory, 0, 0)
	table.clear(Blocks)
	table.clear(Statics)

	for Index = 1, 32 do
		SegmentTable[Index] = 0
	end
end

function Rom.SetSegmentBaseAddr(Segment: number, Address: number): number
	SegmentTable[Segment + 1] = Address

	return Address
end

-- Notes that Size bytes at Address in Memory are the block at RomStart of the ROM (copied or decompressed)
function Rom.RecordBlock(Address: number, Size: number, RomStart: number)
	for Index = #Blocks, 1, -1 do
		const Block = Blocks[Index]

		if Block.Address < Address + Size and Address < Block.Address + Block.Size then
			table.remove(Blocks, Index)
		end
	end

	table.insert(Blocks, { Address = Address, Size = Size, RomStart = RomStart })
end

-- The ROM start of the block that holds Address and the offset of Address in the block
function Rom.BlockOf(Address: number): (number, number)
	for _, Block in Blocks do
		if Address >= Block.Address and Address < Block.Address + Block.Size then
			return Block.RomStart, Address - Block.Address
		end
	end

	error(`address {Address} is not in a block loaded from the ROM`)
end

function Rom.SegmentedToVirtual(Address: number): number
	return SegmentTable[bit32.rshift(Address, 24) + 1] + bit32.band(Address, 0xFFFFFF)
end

-- Copies the ROM range into Memory and makes it the segment; returns its address
function Rom.LoadSegment(Segment: number, RomStart: number, RomEnd: number): number
	const Size = RomEnd - RomStart
	const Address = Rom.Allocate(Size)

	buffer.copy(Memory, Address, Rom.Image, RomStart, Size)
	Rom.SetSegmentBaseAddr(Segment, Address)
	Rom.RecordBlock(Address, Size, RomStart)

	return Address
end

-- Decompresses the MIO0 block at RomStart into Memory and makes it the segment; returns its address
function Rom.LoadMio0(Segment: number, RomStart: number): number
	const Size = bit32.byteswap(buffer.readu32(Rom.Image, RomStart + 4))
	const Address = Rom.Allocate(Size)

	DecompressMio0(Rom.Image, RomStart, Memory, Address)
	Rom.SetSegmentBaseAddr(Segment, Address)
	Rom.RecordBlock(Address, Size, RomStart)

	return Address
end

function Rom.ReadU8(Address: number): number
	return buffer.readu8(Memory, Address)
end

function Rom.ReadS8(Address: number): number
	return buffer.readi8(Memory, Address)
end

function Rom.ReadU16(Address: number): number
	return bit32.rshift(bit32.byteswap(buffer.readu16(Memory, Address)), 16)
end

function Rom.ReadS16(Address: number): number
	const Value = bit32.rshift(bit32.byteswap(buffer.readu16(Memory, Address)), 16)

	return if Value >= 0x8000 then Value - 0x10000 else Value
end

function Rom.ReadU32(Address: number): number
	return bit32.byteswap(buffer.readu32(Memory, Address))
end

function Rom.ReadS32(Address: number): number
	const Value = bit32.byteswap(buffer.readu32(Memory, Address))

	return if Value >= 0x80000000 then Value - 0x100000000 else Value
end

function Rom.ReadF32(Address: number): number
	buffer.writeu32(Scratch, 0, bit32.byteswap(buffer.readu32(Memory, Address)))

	return buffer.readf32(Scratch, 0)
end

-- Writes wrap to 8 bits, as a C store into a u8
function Rom.WriteU8(Address: number, Value: number)
	buffer.writeu8(Memory, Address, Value)
end

-- Writes wrap to 16 bits, as a C store into an s16
function Rom.WriteS16(Address: number, Value: number)
	buffer.writeu16(Memory, Address, bit32.rshift(bit32.byteswap(bit32.band(Value, 0xFFFF)), 16))
end

-- Writes wrap to 32 bits, as a C store into a u32 or a pointer
function Rom.WriteU32(Address: number, Value: number)
	buffer.writeu32(Memory, Address, bit32.byteswap(bit32.band(Value, 0xFFFFFFFF)))
end

-- The Memory address of a static s16 array of the game's code (sCageUkikiPath), written there the first time it is asked for
function Rom.StaticS16Array(Key: string, Values: { number }): number
	const Existing = Statics[Key]

	if Existing ~= nil then
		return Existing
	end

	const Address = Rom.Allocate(#Values * 2)

	for Index, Value in Values do
		Rom.WriteS16(Address + (Index - 1) * 2, Value)
	end

	Statics[Key] = Address

	return Address
end

return Rom
