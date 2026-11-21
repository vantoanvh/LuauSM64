--!strict
--!optimize 2

--[[
	Port of src/game/memory.h.
]]

-- from src/game/memory.h:AllocOnlyPool
export type AllocOnlyPool = {
	totalSpace: number,
	usedSpace: number,
	startPtr: number?,
	freePtr: number?,
}

-- from src/game/memory.h:OffsetSizePair
export type OffsetSizePair = {
	offset: number,
	size: number,
}

-- from src/game/memory.h:DmaTable
export type DmaTable = {
	count: number,
	srcAddr: number?,
	anim: { OffsetSizePair }, -- [1]
}

-- from src/game/memory.h:DmaHandlerList
export type DmaHandlerList = {
	dmaTable: number?,
	currentAddr: number?,
	bufTarget: number?,
}

-- from src/game/memory.h:data
const memory_h = {
	MEMORY_POOL_LEFT = 0,
	MEMORY_POOL_RIGHT = 1,
}

-- from src/game/memory.h:AllocOnlyPool (zero-filled constructor)
function memory_h.new_AllocOnlyPool(): AllocOnlyPool
	return { totalSpace = 0, usedSpace = 0, startPtr = nil, freePtr = nil } :: AllocOnlyPool
end

-- from src/game/memory.h:OffsetSizePair (zero-filled constructor)
function memory_h.new_OffsetSizePair(): OffsetSizePair
	return { offset = 0, size = 0 } :: OffsetSizePair
end

-- from src/game/memory.h:DmaTable (zero-filled constructor)
function memory_h.new_DmaTable(): DmaTable
	return { count = 0, srcAddr = nil, anim = { { offset = 0, size = 0 } } } :: DmaTable
end

-- from src/game/memory.h:DmaHandlerList (zero-filled constructor)
function memory_h.new_DmaHandlerList(): DmaHandlerList
	return { dmaTable = nil, currentAddr = nil, bufTarget = nil } :: DmaHandlerList
end

return memory_h
