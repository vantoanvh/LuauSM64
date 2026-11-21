--!strict
--!optimize 2

--[[
	Port of src/goddard/debug_utils.h.
]]

-- from src/goddard/debug_utils.h:MemTracker
export type MemTracker = {
	name: string?,
	begin: number,
	end_: number,
	total: number,
}

-- from src/goddard/debug_utils.h:GdTimer
export type GdTimer = {
	start: number,
	end_: number,
	total: number,
	unused: number,
	scaledTotal: number,
	prevScaledTotal: number,
	name: string?,
	gadgetColourNum: number,
	resetCount: number,
}

-- from src/goddard/debug_utils.h:PrintVal
-- union: the fields are views of the same storage in C; decide how they alias
export type PrintVal = {
	f: number,
	i: number,
	pad: number,
}

-- from src/goddard/debug_utils.h:GdFile
export type GdFile = {
	filler1: buffer, -- [4]
	pos: number,
	stream: buffer?,
	flags: number,
	filler2: buffer, -- [64]
	size: number,
}

-- from src/goddard/debug_utils.h:data
const debug_utils_h = {
	GD_NUM_MEM_TRACKERS = 32,
	GD_NUM_TIMERS = 32,
}

-- from src/goddard/debug_utils.h:MemTracker (zero-filled constructor)
function debug_utils_h.new_MemTracker(): MemTracker
	return { name = nil, begin = 0, end_ = 0, total = 0 } :: MemTracker
end

-- from src/goddard/debug_utils.h:GdTimer (zero-filled constructor)
function debug_utils_h.new_GdTimer(): GdTimer
	return {
		start = 0,
		end_ = 0,
		total = 0,
		unused = 0,
		scaledTotal = 0,
		prevScaledTotal = 0,
		name = nil,
		gadgetColourNum = 0,
		resetCount = 0,
	} :: GdTimer
end

-- from src/goddard/debug_utils.h:GdFile (zero-filled constructor)
function debug_utils_h.new_GdFile(): GdFile
	return {
		filler1 = buffer.create(4),
		pos = 0,
		stream = nil,
		flags = 0,
		filler2 = buffer.create(64),
		size = 0,
	} :: GdFile
end

return debug_utils_h
