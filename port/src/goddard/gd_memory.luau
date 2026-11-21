--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_memory.c.
]]

const Registry = require("../../groups/registry")

const GdMemoryH = require("./gd_memory_h")

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/goddard/gd_memory.c:data
const gd_memory = {
	-- from src/goddard/gd_memory.c:sFreeBlockListHead L18-18
	sFreeBlockListHead = nil :: GdMemoryH.GMemBlock?,
	-- from src/goddard/gd_memory.c:sUsedBlockListHead L19-19
	sUsedBlockListHead = nil :: GdMemoryH.GMemBlock?,
	-- from src/goddard/gd_memory.c:sEmptyBlockListHead L20-20
	sEmptyBlockListHead = nil :: GdMemoryH.GMemBlock?,
}

Registry.Register("src__goddard__gd_memory", gd_memory)

-- from src/goddard/gd_memory.c:empty_mem_block L34-65
function gd_memory.empty_mem_block(block: GdMemoryH.GMemBlock)
	if block.next ~= nil then
		block.next.prev = block.prev
	end

	if block.prev ~= nil then
		block.prev.next = block.next
	end

	if block.blockType == GdMemoryH.G_MEM_BLOCK_FREE then
		if block.prev == nil then
			gd_memory.sFreeBlockListHead = block.next
		end
	elseif block.blockType == GdMemoryH.G_MEM_BLOCK_USED then
		if block.prev == nil then
			gd_memory.sUsedBlockListHead = block.next
		end
	end

	block.next = gd_memory.sEmptyBlockListHead

	if block.next ~= nil then
		(gd_memory.sEmptyBlockListHead :: GdMemoryH.GMemBlock).prev = block
	end

	gd_memory.sEmptyBlockListHead = block
	block.prev = nil
	block.ptr = nil
	block.size = 0
end

-- from src/goddard/gd_memory.c:into_free_memblock L72-89
function gd_memory.into_free_memblock(block: GdMemoryH.GMemBlock): GdMemoryH.GMemBlock
	const ptr = block.ptr
	const space = block.size
	const permanence = block.permFlag

	gd_memory.empty_mem_block(block)

	const freeBlock = gd_memory.make_mem_block(GdMemoryH.G_MEM_BLOCK_FREE, permanence)

	freeBlock.ptr = ptr
	freeBlock.size = space
	freeBlock.permFlag = permanence

	return freeBlock
end

-- from src/goddard/gd_memory.c:make_mem_block L101-143
function gd_memory.make_mem_block(blockType: number, permFlag: number): GdMemoryH.GMemBlock
	permFlag = U8(TruncS32(permFlag))

	if gd_memory.sEmptyBlockListHead == nil then
		const emptyBlock = GdMemoryH.new_GMemBlock()

		emptyBlock.next = nil
		emptyBlock.prev = nil
		gd_memory.sEmptyBlockListHead = emptyBlock
	end

	const newMemBlock = gd_memory.sEmptyBlockListHead :: GdMemoryH.GMemBlock

	gd_memory.sEmptyBlockListHead = newMemBlock.next

	if newMemBlock.next ~= nil then
		newMemBlock.next.prev = nil
	end

	if blockType == GdMemoryH.G_MEM_BLOCK_FREE then
		newMemBlock.next = gd_memory.sFreeBlockListHead

		if newMemBlock.next ~= nil then
			(gd_memory.sFreeBlockListHead :: GdMemoryH.GMemBlock).prev = newMemBlock
		end

		gd_memory.sFreeBlockListHead = newMemBlock
	elseif blockType == GdMemoryH.G_MEM_BLOCK_USED then
		newMemBlock.next = gd_memory.sUsedBlockListHead

		if newMemBlock.next ~= nil then
			(gd_memory.sUsedBlockListHead :: GdMemoryH.GMemBlock).prev = newMemBlock
		end

		gd_memory.sUsedBlockListHead = newMemBlock
	else
		error("unkown memblock type")
	end

	newMemBlock.prev = nil
	newMemBlock.blockType = U8(blockType)
	newMemBlock.permFlag = permFlag

	return newMemBlock
end

-- from src/goddard/gd_memory.c:gd_free_mem L152-167
function gd_memory.gd_free_mem(ptr: unknown): number
	const targetBlock = ptr
	local curBlock = gd_memory.sUsedBlockListHead

	while curBlock ~= nil do
		if targetBlock == curBlock.ptr then
			const bytesFreed = curBlock.size

			gd_memory.into_free_memblock(curBlock)

			return bytesFreed
		end

		curBlock = curBlock.next
	end

	error("Free() Not a valid memory block")
end

-- from src/goddard/gd_memory.c:gd_request_mem L176-221
function gd_memory.gd_request_mem(size: number, permanence: number): unknown
	permanence = U8(TruncS32(permanence))

	local foundBlock: GdMemoryH.GMemBlock? = nil
	const newBlock = gd_memory.make_mem_block(GdMemoryH.G_MEM_BLOCK_USED, permanence)
	local curBlock = gd_memory.sFreeBlockListHead

	while curBlock ~= nil do
		if bit32.btest(curBlock.permFlag, permanence) then
			if curBlock.size == size then
				foundBlock = curBlock

				break
			else
				if curBlock.size > size then
					if foundBlock ~= nil then
						if curBlock.size < foundBlock.size then
							foundBlock = curBlock
						end
					else
						foundBlock = curBlock
					end
				end
			end
		end

		curBlock = curBlock.next
	end

	if foundBlock == nil then
		return nil
	end

	if foundBlock.size > size then
		newBlock.ptr = foundBlock.ptr
		newBlock.size = size
		foundBlock.size = U32(foundBlock.size - size)
		foundBlock.ptr = (foundBlock.ptr :: number) + size
	elseif foundBlock.size == size then
		newBlock.ptr = foundBlock.ptr
		newBlock.size = size
		gd_memory.empty_mem_block(foundBlock)
	end

	return newBlock.ptr
end

-- from src/goddard/gd_memory.c:gd_add_mem_to_heap L228-239
function gd_memory.gd_add_mem_to_heap(size: number, addr: unknown, permanence: number): GdMemoryH.GMemBlock
	permanence = U8(TruncS32(permanence))
	size = bit32.band(size - 8, bit32.bnot(7))
	addr = bit32.band((addr :: number) + 8, bit32.bnot(7))

	const newBlock = gd_memory.make_mem_block(GdMemoryH.G_MEM_BLOCK_FREE, permanence)

	newBlock.ptr = addr
	newBlock.size = size

	return newBlock
end

-- from src/goddard/gd_memory.c:init_mem_block_lists L244-248
function gd_memory.init_mem_block_lists()
	gd_memory.sFreeBlockListHead = nil
	gd_memory.sUsedBlockListHead = nil
	gd_memory.sEmptyBlockListHead = nil
end

-- from src/goddard/gd_memory.c:print_list_stats L260-282
function gd_memory.print_list_stats(block: GdMemoryH.GMemBlock?, printBlockInfo: number, permanence: number): number
	error("stale")
end

-- from src/goddard/gd_memory.c:mem_stats L288-314
function gd_memory.mem_stats()
	error("stale")

	return
end

return gd_memory
