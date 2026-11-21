--!strict
--!optimize 2

--[[
	Port of include/segment_symbols.h.
]]

const segment_symbols_h = {}

-- from include/segment_symbols.h:DECLARE_SEGMENT L5-7
function segment_symbols_h.DECLARE_SEGMENT(name: unknown)
	error("stale")
	return
end

-- from include/segment_symbols.h:DECLARE_ACTOR_SEGMENT L9-11
function segment_symbols_h.DECLARE_ACTOR_SEGMENT(name: unknown): number
	error("stale")
end

-- from include/segment_symbols.h:DECLARE_LEVEL_SEGMENT L13-15
function segment_symbols_h.DECLARE_LEVEL_SEGMENT(name: unknown): number
	error("stale")
end

return segment_symbols_h
