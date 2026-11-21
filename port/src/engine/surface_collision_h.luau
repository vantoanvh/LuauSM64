--!strict
--!optimize 2

--[[
	Port of src/engine/surface_collision.h.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

-- from src/engine/surface_collision.h:WallCollisionData
export type WallCollisionData = {
	x: number,
	y: number,
	z: number,
	offsetY: number,
	radius: number,
	filler: buffer, -- [2]
	numWalls: number,
	walls: { GroupsTypesHPlus3.Surface? }, -- [4]
}

-- from src/engine/surface_collision.h:FloorGeometry
export type FloorGeometry = {
	filler: buffer, -- [16]
	normalX: number,
	normalY: number,
	normalZ: number,
	originOffset: number,
}

-- from src/engine/surface_collision.h:data
const surface_collision_h = {
	LEVEL_BOUNDARY_MAX = 0x2000,
	CELL_SIZE = 1024,
	CELL_HEIGHT_LIMIT = 20000,
	FLOOR_LOWER_LIMIT = -11000,
	FLOOR_LOWER_LIMIT_MISC = -10000, -- (FLOOR_LOWER_LIMIT + 1000)
	FLOOR_LOWER_LIMIT_SHADOW = -11000 + 1000.0, -- (FLOOR_LOWER_LIMIT + 1000.0)
}

Registry.Register("src__engine__surface_collision_h", surface_collision_h)

-- from src/engine/surface_collision.h:WallCollisionData (zero-filled constructor)
function surface_collision_h.new_WallCollisionData(): WallCollisionData
	return {
		x = 0,
		y = 0,
		z = 0,
		offsetY = 0,
		radius = 0,
		filler = buffer.create(2),
		numWalls = 0,
		walls = { nil, nil, nil, nil },
	} :: WallCollisionData
end

-- from src/engine/surface_collision.h:FloorGeometry (zero-filled constructor)
function surface_collision_h.new_FloorGeometry(): FloorGeometry
	return { filler = buffer.create(16), normalX = 0, normalY = 0, normalZ = 0, originOffset = 0 } :: FloorGeometry
end

return surface_collision_h
