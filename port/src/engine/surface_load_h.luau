--!strict
--!optimize 2

--[[
	Port of src/engine/surface_load.h.
]]

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

-- from src/engine/surface_load.h:SurfaceNode
export type SurfaceNode = {
	next: SurfaceNode?,
	surface: GroupsTypesHPlus3.Surface?,
}

-- from src/engine/surface_load.h:data
const surface_load_h = {
	NUM_CELLS = 16, -- (2 * LEVEL_BOUNDARY_MAX / CELL_SIZE)
	NUM_CELLS_INDEX = 15, -- (NUM_CELLS - 1)
	SPATIAL_PARTITION_FLOORS = 0,
	SPATIAL_PARTITION_CEILS = 1,
	SPATIAL_PARTITION_WALLS = 2,
}

-- from src/engine/surface_load.h:SurfaceNode (zero-filled constructor)
function surface_load_h.new_SurfaceNode(): SurfaceNode
	return { next = nil, surface = nil } :: SurfaceNode
end

return surface_load_h
