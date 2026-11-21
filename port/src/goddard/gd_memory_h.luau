--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_memory.h.
]]

-- from src/goddard/gd_memory.h:GMemBlock
export type GMemBlock = {
	ptr: number?,
	size: number,
	blockType: number,
	permFlag: number,
	next: GMemBlock?,
	prev: GMemBlock?,
}

-- from src/goddard/gd_memory.h:data
const gd_memory_h = {
	G_MEM_BLOCK_FREE = 1,
	G_MEM_BLOCK_USED = 2,
	PERM_G_MEM_BLOCK = 0xF0,
	TEMP_G_MEM_BLOCK = 0x0F,
}

-- from src/goddard/gd_memory.h:GMemBlock (zero-filled constructor)
function gd_memory_h.new_GMemBlock(): GMemBlock
	return { ptr = nil, size = 0, blockType = 0, permFlag = 0, next = nil, prev = nil } :: GMemBlock
end

return gd_memory_h
