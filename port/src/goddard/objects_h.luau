--!strict
--!optimize 2

--[[
	Port of src/goddard/objects.h.
]]

-- from src/goddard/objects.h:DebugCounters
export type DebugCounters = {
	ctr0: number,
	ctr1: number,
}

const objects_h = {}

-- from src/goddard/objects.h:DebugCounters (zero-filled constructor)
function objects_h.new_DebugCounters(): DebugCounters
	return { ctr0 = 0, ctr1 = 0 } :: DebugCounters
end

return objects_h
