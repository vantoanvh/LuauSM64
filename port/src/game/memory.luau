--!strict
--!optimize 2

--[[
	Port of src/game/memory.c.
]]

const MemoryH = require("./memory_h")
const Rom = require("../rom/rom")
const DecompressMio0 = require("../rom/mio0")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Symbols = require("../rom/symbols")

const MainPoolBlockPrev = 0
const MainPoolBlockNext = 8
const MainPoolStateSize = 32
const MainPoolStateFreeSpace = 0
const MainPoolStateListHeadL = 8
const MainPoolStateListHeadR = 16
const MainPoolStatePrev = 24

-- sizeof(struct AllocOnlyPool), 64-bit layout
const AllocOnlyPoolSize = 24
-- sizeof(struct MemoryPool) and sizeof(struct MemoryBlock) (64-bit layout); a MemoryPool header lives in Rom.Memory
const MemoryPoolSize = 32
const MemoryBlockSize = 16
const MemoryPoolTotalSpace = 0
const MemoryPoolFirstBlock = 8
const MemoryPoolFreeListNext = 16
const MemoryBlockNext = 0
const MemoryBlockSizeField = 8

-- A pool pointer is a Rom.Memory offset; a pool header pointer slot is 8 bytes (a 32-bit offset, 0 is NULL, as in the 64-bit layout).
const function ReadPointer(Address: number): number?
	const Value = buffer.readu32(Rom.Memory, Address)

	if Value == 0 then
		return nil
	end

	return Value
end

const function WritePointer(Address: number, Value: number?)
	buffer.writeu32(Rom.Memory, Address, Value or 0)
	buffer.writeu32(Rom.Memory, Address + 4, 0)
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/memory.c:data
const memory = {
	-- from src/game/memory.c:gEffectsMemoryPool L57-57
	gEffectsMemoryPool = nil :: number?,
	-- from src/game/memory.c:sPoolFreeSpace L60-60
	sPoolFreeSpace = 0,
	-- from src/game/memory.c:sPoolStart L61-61
	sPoolStart = 0,
	-- from src/game/memory.c:sPoolEnd L62-62
	sPoolEnd = 0,
	-- from src/game/memory.c:sPoolListHeadL L63-63
	sPoolListHeadL = 0,
	-- from src/game/memory.c:sPoolListHeadR L64-64
	sPoolListHeadR = 0,
	-- from src/game/memory.c:gMainPoolState L66-66
	gMainPoolState = nil :: number?,
}

-- from src/game/memory.c:ALIGN4 L17-17
function memory.ALIGN4(val: number): number
	return bit32.band(val + 0x3, bit32.bnot(0x3))
end

-- from src/game/memory.c:ALIGN8 L18-18
function memory.ALIGN8(val: number): number
	return bit32.band(val + 0x7, bit32.bnot(0x7))
end

-- from src/game/memory.c:ALIGN16 L19-19
function memory.ALIGN16(val: number): number
	return bit32.band(val + 0xF, bit32.bnot(0xF))
end

-- from src/game/memory.c:set_segment_base_addr L68-71
function memory.set_segment_base_addr(segment: number, addr: number): number
	return Rom.SetSegmentBaseAddr(segment, bit32.band(addr, 0x1FFFFFFF))
end

-- from src/game/memory.c:get_segment_base_addr L73-75
function memory.get_segment_base_addr(segment: number): number
	return Rom.SegmentedToVirtual(bit32.lshift(segment, 24))
end

-- from src/game/memory.c:segmented_to_virtual L78-83
function memory.segmented_to_virtual(addr: number): number
	return Rom.SegmentedToVirtual(addr)
end

-- from src/game/memory.c:virtual_to_segmented L85-89
function memory.virtual_to_segmented(segment: number, addr: number): number
	return bit32.lshift(segment, 24) + bit32.band(addr, 0x1FFFFFFF) - memory.get_segment_base_addr(segment)
end

-- from src/game/memory.c:move_segment_table_to_dmem L91-97
function memory.move_segment_table_to_dmem()
	-- gSPSegment writes display list output only (gfx-display-lists)
end

-- from src/game/memory.c:main_pool_init L116-131
function memory.main_pool_init(start: number, end_: number)
	memory.sPoolStart = memory.ALIGN16(start) + 16
	memory.sPoolEnd = memory.ALIGN16(end_ - 15) - 16
	memory.sPoolFreeSpace = memory.sPoolEnd - memory.sPoolStart

	memory.sPoolListHeadL = memory.sPoolStart - 16
	memory.sPoolListHeadR = memory.sPoolEnd
	WritePointer(memory.sPoolListHeadL + MainPoolBlockPrev, nil)
	WritePointer(memory.sPoolListHeadL + MainPoolBlockNext, nil)
	WritePointer(memory.sPoolListHeadR + MainPoolBlockPrev, nil)
	WritePointer(memory.sPoolListHeadR + MainPoolBlockNext, nil)
end

-- from src/game/memory.c:main_pool_alloc L138-162
function memory.main_pool_alloc(size: number, side: number): number?
	local addr: number? = nil

	size = memory.ALIGN16(size) + 16
	if size ~= 0 and memory.sPoolFreeSpace >= size then
		memory.sPoolFreeSpace -= size
		if side == MemoryH.MEMORY_POOL_LEFT then
			const newListHead = memory.sPoolListHeadL + size

			WritePointer(memory.sPoolListHeadL + MainPoolBlockNext, newListHead)
			WritePointer(newListHead + MainPoolBlockPrev, memory.sPoolListHeadL)
			WritePointer(newListHead + MainPoolBlockNext, nil)
			addr = memory.sPoolListHeadL + 16
			memory.sPoolListHeadL = newListHead
		else
			const newListHead = memory.sPoolListHeadR - size

			WritePointer(memory.sPoolListHeadR + MainPoolBlockPrev, newListHead)
			WritePointer(newListHead + MainPoolBlockNext, memory.sPoolListHeadR)
			WritePointer(newListHead + MainPoolBlockPrev, nil)
			memory.sPoolListHeadR = newListHead
			addr = memory.sPoolListHeadR + 16
		end
	end

	return addr
end

-- from src/game/memory.c:main_pool_free L170-190
function memory.main_pool_free(addr: number): number
	const block = addr - 16
	local oldListHead = addr - 16

	if oldListHead < memory.sPoolListHeadL then
		while ReadPointer(oldListHead + MainPoolBlockNext) ~= nil do
			oldListHead = ReadPointer(oldListHead + MainPoolBlockNext) :: number
		end

		memory.sPoolListHeadL = block
		WritePointer(memory.sPoolListHeadL + MainPoolBlockNext, nil)
		memory.sPoolFreeSpace += oldListHead - memory.sPoolListHeadL
	else
		while ReadPointer(oldListHead + MainPoolBlockPrev) ~= nil do
			oldListHead = ReadPointer(oldListHead + MainPoolBlockPrev) :: number
		end

		memory.sPoolListHeadR = ReadPointer(block + MainPoolBlockNext) :: number
		WritePointer(memory.sPoolListHeadR + MainPoolBlockPrev, nil)
		memory.sPoolFreeSpace += memory.sPoolListHeadR - oldListHead
	end

	return memory.sPoolFreeSpace
end

-- from src/game/memory.c:main_pool_realloc L198-207
function memory.main_pool_realloc(addr: number, size: number): number?
	local newAddr: number? = nil
	const block = addr - 16

	if ReadPointer(block + MainPoolBlockNext) == memory.sPoolListHeadL then
		memory.main_pool_free(addr)
		newAddr = memory.main_pool_alloc(size, MemoryH.MEMORY_POOL_LEFT)
	end

	return newAddr
end

-- from src/game/memory.c:main_pool_available L213-215
function memory.main_pool_available(): number
	return U32(memory.sPoolFreeSpace - 16)
end

-- from src/game/memory.c:main_pool_push_state L221-233
function memory.main_pool_push_state(): number
	const prevState = memory.gMainPoolState
	const freeSpace = memory.sPoolFreeSpace
	const lhead = memory.sPoolListHeadL
	const rhead = memory.sPoolListHeadR

	memory.gMainPoolState = memory.main_pool_alloc(MainPoolStateSize, MemoryH.MEMORY_POOL_LEFT)
	const state = memory.gMainPoolState :: number

	buffer.writeu32(Rom.Memory, state + MainPoolStateFreeSpace, freeSpace)
	WritePointer(state + MainPoolStateListHeadL, lhead)
	WritePointer(state + MainPoolStateListHeadR, rhead)
	WritePointer(state + MainPoolStatePrev, prevState)

	return memory.sPoolFreeSpace
end

-- from src/game/memory.c:main_pool_pop_state L239-245
function memory.main_pool_pop_state(): number
	const state = memory.gMainPoolState :: number

	memory.sPoolFreeSpace = buffer.readu32(Rom.Memory, state + MainPoolStateFreeSpace)
	memory.sPoolListHeadL = ReadPointer(state + MainPoolStateListHeadL) :: number
	memory.sPoolListHeadR = ReadPointer(state + MainPoolStateListHeadR) :: number
	memory.gMainPoolState = ReadPointer(state + MainPoolStatePrev)

	return memory.sPoolFreeSpace
end

-- from src/game/memory.c:dma_read L251-266
function memory.dma_read(dest: number, srcStart: number, srcEnd: number)
	-- osInvalDCache and osRecvMesg are no-ops (replaced.txt); osPiStartDma copies the ROM range into Memory
	local size = memory.ALIGN16(srcEnd - srcStart)

	Rom.RecordBlock(dest, size, srcStart)

	while size ~= 0 do
		const copySize = if size >= 0x1000 then 0x1000 else size

		buffer.copy(Rom.Memory, dest, Rom.Image, srcStart, copySize)
		dest += copySize
		srcStart += copySize
		size -= copySize
	end
end

-- from src/game/memory.c:dynamic_dma_read L272-281
function memory.dynamic_dma_read(srcStart: number, srcEnd: number, side: number): number?
	const size = memory.ALIGN16(srcEnd - srcStart)
	const dest = memory.main_pool_alloc(size, side)

	if dest ~= nil then
		memory.dma_read(dest, srcStart, srcEnd)
	end

	return dest
end

-- from src/game/memory.c:load_segment L288-295
function memory.load_segment(segment: number, srcStart: number, srcEnd: number, side: number): number?
	const addr = memory.dynamic_dma_read(srcStart, srcEnd, side)

	if addr ~= nil then
		memory.set_segment_base_addr(segment, addr)
	end

	return addr
end

-- from src/game/memory.c:load_to_fixed_pool_addr L303-320
function memory.load_to_fixed_pool_addr(destAddr: number, srcStart: number, srcEnd: number): number?
	const srcSize = memory.ALIGN16(srcEnd - srcStart)
	const destSize = memory.ALIGN16(memory.sPoolListHeadR - destAddr)
	local dest: number? = nil

	if srcSize <= destSize then
		dest = memory.main_pool_alloc(destSize, MemoryH.MEMORY_POOL_RIGHT)

		if dest ~= nil then
			buffer.fill(Rom.Memory, dest, 0, destSize)
			memory.dma_read(dest, srcStart, srcEnd)
		end
	end

	return dest
end

-- from src/game/memory.c:load_segment_decompress L327-351
function memory.load_segment_decompress(segment: number, srcStart: number, srcEnd: number): number?
	const compSize = memory.ALIGN16(srcEnd - srcStart)
	const compressed = memory.main_pool_alloc(compSize, MemoryH.MEMORY_POOL_RIGHT)
	local dest: number? = nil

	if compressed ~= nil then
		memory.dma_read(compressed, srcStart, srcEnd)
		dest = memory.main_pool_alloc(Rom.ReadU32(compressed + 4), MemoryH.MEMORY_POOL_LEFT)

		if dest ~= nil then
			DecompressMio0(Rom.Memory, compressed, Rom.Memory, dest)
			Rom.RecordBlock(dest, Rom.ReadU32(compressed + 4), srcStart)
			memory.set_segment_base_addr(segment, dest)
			memory.main_pool_free(compressed)
		end
	end

	return dest
end

-- from src/game/memory.c:load_segment_decompress_heap L353-367
function memory.load_segment_decompress_heap(segment: number, srcStart: number, srcEnd: number): number?
	const compSize = memory.ALIGN16(srcEnd - srcStart)
	const compressed = memory.main_pool_alloc(compSize, MemoryH.MEMORY_POOL_RIGHT)

	if compressed ~= nil then
		memory.dma_read(compressed, srcStart, srcEnd)
		DecompressMio0(Rom.Memory, compressed, Rom.Memory, Symbols.DecompressionHeap)
		Rom.RecordBlock(Symbols.DecompressionHeap, Rom.ReadU32(compressed + 4), srcStart)
		memory.set_segment_base_addr(segment, Symbols.DecompressionHeap)
		memory.main_pool_free(compressed)
	end

	return Symbols.DecompressionHeap
end

-- from src/game/memory.c:load_engine_code_segment L369-379
function memory.load_engine_code_segment()
	error("stale")
end

-- from src/game/memory.c:alloc_only_pool_init L387-401
function memory.alloc_only_pool_init(size: number, side: number): MemoryH.AllocOnlyPool?
	size = memory.ALIGN4(size)

	const addr = memory.main_pool_alloc(size + AllocOnlyPoolSize, side)
	local subPool: MemoryH.AllocOnlyPool? = nil

	if addr ~= nil then
		subPool = MemoryH.new_AllocOnlyPool()
		subPool.totalSpace = size
		subPool.usedSpace = 0
		subPool.startPtr = addr + AllocOnlyPoolSize
		subPool.freePtr = addr + AllocOnlyPoolSize
	end

	return subPool
end

-- from src/game/memory.c:alloc_only_pool_alloc L407-417
function memory.alloc_only_pool_alloc(pool: MemoryH.AllocOnlyPool, size: number): number?
	size = memory.ALIGN4(size)

	local addr: number? = nil

	if size > 0 and pool.usedSpace + size <= pool.totalSpace then
		addr = pool.freePtr
		pool.freePtr = (pool.freePtr :: number) + size
		pool.usedSpace += size
	end

	return addr
end

-- from src/game/memory.c:alloc_only_pool_resize L425-434
function memory.alloc_only_pool_resize(pool: MemoryH.AllocOnlyPool, size: number): MemoryH.AllocOnlyPool?
	size = memory.ALIGN4(size)

	const poolAddr = (pool.startPtr :: number) - AllocOnlyPoolSize
	const newPool = memory.main_pool_realloc(poolAddr, size + AllocOnlyPoolSize)

	if newPool ~= nil then
		pool.totalSpace = size
		return pool
	end

	return nil
end

-- from src/game/memory.c:mem_pool_init L441-460
function memory.mem_pool_init(size: number, side: number): number?
	size = memory.ALIGN4(size)

	const addr = memory.main_pool_alloc(size + MemoryPoolSize, side)
	local pool: number? = nil

	if addr ~= nil then
		pool = addr
		buffer.writeu32(Rom.Memory, pool + MemoryPoolTotalSpace, size)
		WritePointer(pool + MemoryPoolFirstBlock, pool + MemoryPoolSize)
		WritePointer(pool + MemoryPoolFreeListNext, pool + MemoryPoolSize)

		const block = pool + MemoryPoolSize
		WritePointer(block + MemoryBlockNext, nil)
		buffer.writeu32(Rom.Memory, block + MemoryBlockSizeField, size)
	end

	return pool
end

-- from src/game/memory.c:mem_pool_alloc L465-487
function memory.mem_pool_alloc(pool: number, size: number): number?
	local freeBlock = pool + MemoryPoolFreeListNext
	local addr: number? = nil

	size = memory.ALIGN4(size) + MemoryBlockSize

	while ReadPointer(freeBlock + MemoryBlockNext) ~= nil do
		const nextBlock = ReadPointer(freeBlock + MemoryBlockNext) :: number

		if buffer.readu32(Rom.Memory, nextBlock + MemoryBlockSizeField) >= size then
			addr = nextBlock + MemoryBlockSize

			if buffer.readu32(Rom.Memory, nextBlock + MemoryBlockSizeField) - size <= MemoryBlockSize then
				WritePointer(freeBlock + MemoryBlockNext, ReadPointer(nextBlock + MemoryBlockNext))
			else
				const newBlock = nextBlock + size

				buffer.writeu32(Rom.Memory, newBlock + MemoryBlockSizeField, buffer.readu32(Rom.Memory, nextBlock + MemoryBlockSizeField) - size)
				WritePointer(newBlock + MemoryBlockNext, ReadPointer(nextBlock + MemoryBlockNext))
				buffer.writeu32(Rom.Memory, nextBlock + MemoryBlockSizeField, size)
				WritePointer(freeBlock + MemoryBlockNext, newBlock)
			end

			break
		end

		freeBlock = ReadPointer(freeBlock + MemoryBlockNext) :: number
	end

	return addr
end

-- from src/game/memory.c:mem_pool_free L492-533
function memory.mem_pool_free(pool: number, addr: number)
	local block = addr - MemoryBlockSize
	const freeListNext = ReadPointer(pool + MemoryPoolFreeListNext)

	if freeListNext == nil then
		WritePointer(pool + MemoryPoolFreeListNext, block)
		WritePointer(block + MemoryBlockNext, nil)
	else
		if block < freeListNext then
			if freeListNext == block + buffer.readu32(Rom.Memory, block + MemoryBlockSizeField) then
				buffer.writeu32(Rom.Memory, block + MemoryBlockSizeField, buffer.readu32(Rom.Memory, block + MemoryBlockSizeField) + buffer.readu32(Rom.Memory, freeListNext + MemoryBlockSizeField))
				WritePointer(block + MemoryBlockNext, ReadPointer(freeListNext + MemoryBlockNext))
				WritePointer(pool + MemoryPoolFreeListNext, block)
			else
				WritePointer(block + MemoryBlockNext, freeListNext)
				WritePointer(pool + MemoryPoolFreeListNext, block)
			end
		else
			local freeList = freeListNext

			while ReadPointer(freeList + MemoryBlockNext) ~= nil do
				if freeList < block and block < (ReadPointer(freeList + MemoryBlockNext) :: number) then
					break
				end

				freeList = ReadPointer(freeList + MemoryBlockNext) :: number
			end

			if block == freeList + buffer.readu32(Rom.Memory, freeList + MemoryBlockSizeField) then
				buffer.writeu32(Rom.Memory, freeList + MemoryBlockSizeField, buffer.readu32(Rom.Memory, freeList + MemoryBlockSizeField) + buffer.readu32(Rom.Memory, block + MemoryBlockSizeField))
				block = freeList
			else
				WritePointer(block + MemoryBlockNext, ReadPointer(freeList + MemoryBlockNext))
				WritePointer(freeList + MemoryBlockNext, block)
			end

			const nextBlock = ReadPointer(block + MemoryBlockNext)

			if nextBlock ~= nil and nextBlock == block + buffer.readu32(Rom.Memory, block + MemoryBlockSizeField) then
				buffer.writeu32(Rom.Memory, block + MemoryBlockSizeField, buffer.readu32(Rom.Memory, block + MemoryBlockSizeField) + buffer.readu32(Rom.Memory, nextBlock + MemoryBlockSizeField))
				WritePointer(block + MemoryBlockNext, ReadPointer(nextBlock + MemoryBlockNext))
			end
		end
	end
end

-- from src/game/memory.c:alloc_display_list L535-545
function memory.alloc_display_list(size: number): unknown
	-- The display list pool is renderer output (gfx-display-lists). Only a Mat4 pointer is ever read back (the throw matrix of
	-- obj_orient_graph, then by the geo traversal), so every allocation is a fresh one element table of a zero Mat4 (matrix-pointer-indexing).
	return { { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) } }
end

-- from src/game/memory.c:load_dma_table_address L547-557
function memory.load_dma_table_address(srcAddr: number): number
	-- The DmaTable header (count, srcAddr) is 8 bytes; an OffsetSizePair is 8 bytes
	const headerBlock = memory.dynamic_dma_read(srcAddr, srcAddr + 4, MemoryH.MEMORY_POOL_LEFT) :: number
	const size = Rom.ReadU32(headerBlock) * 8 + 8

	memory.main_pool_free(headerBlock)

	const dmaTable = memory.dynamic_dma_read(srcAddr, srcAddr + size, MemoryH.MEMORY_POOL_LEFT) :: number
	Rom.WriteU32(dmaTable + 4, srcAddr)

	return dmaTable
end

-- from src/game/memory.c:setup_dma_table_list L559-565
function memory.setup_dma_table_list(list: MemoryH.DmaHandlerList, srcAddr: number?, buffer: number)
	if srcAddr ~= nil then
		list.dmaTable = memory.load_dma_table_address(srcAddr)
	end

	list.currentAddr = nil
	list.bufTarget = buffer
end

-- from src/game/memory.c:load_patchable_table L567-582
function memory.load_patchable_table(list: MemoryH.DmaHandlerList, index: number): number
	local ret = IncludePRUltratypesH.FALSE
	const dmaTable = list.dmaTable :: number

	if U32(index) < Rom.ReadU32(dmaTable) then
		const addr = Rom.ReadU32(dmaTable + 4) + Rom.ReadU32(dmaTable + 8 + 8 * index)
		const size = Rom.ReadS32(dmaTable + 12 + 8 * index)

		if addr ~= list.currentAddr then
			memory.dma_read(list.bufTarget :: number, addr, addr + size)
			list.currentAddr = addr
			ret = IncludePRUltratypesH.TRUE
		end
	end

	return ret
end

return memory
