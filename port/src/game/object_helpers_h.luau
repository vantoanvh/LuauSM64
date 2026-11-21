--!strict
--!optimize 2

--[[
	Port of src/game/object_helpers.h.
]]

-- from src/game/object_helpers.h:ChainSegment
export type ChainSegment = {
	posX: number,
	posY: number,
	posZ: number,
	pitch: number,
	yaw: number,
	roll: number,
}

-- from src/game/object_helpers.h:WaterDropletParams
export type WaterDropletParams = {
	flags: number,
	model: number,
	behavior: number,
	moveAngleRange: number,
	moveRange: number,
	randForwardVelOffset: number,
	randForwardVelScale: number,
	randYVelOffset: number,
	randYVelScale: number,
	randSizeOffset: number,
	randSizeScale: number,
}

-- from src/game/object_helpers.h:struct802A1230
export type struct802A1230 = {
	unk00: number,
	unk02: number,
}

-- from src/game/object_helpers.h:Struct802A272C
export type Struct802A272C = {
	vecF: { number },
	vecS: { number },
}

-- from src/game/object_helpers.h:SpawnParticlesInfo
export type SpawnParticlesInfo = {
	bhvParam: number,
	count: number,
	model: number,
	offsetY: number,
	forwardVelBase: number,
	forwardVelRange: number,
	velYBase: number,
	velYRange: number,
	gravity: number,
	dragStrength: number,
	sizeBase: number,
	sizeRange: number,
}

-- from src/game/object_helpers.h:data
const object_helpers_h = {
	WATER_DROPLET_FLAG_RAND_ANGLE = 0x02,
	WATER_DROPLET_FLAG_RAND_OFFSET_XZ = 0x04,
	WATER_DROPLET_FLAG_RAND_OFFSET_XYZ = 0x08,
	WATER_DROPLET_FLAG_SET_Y_TO_WATER_LEVEL = 0x20,
	WATER_DROPLET_FLAG_RAND_ANGLE_INCR_PLUS_8000 = 0x40,
	WATER_DROPLET_FLAG_RAND_ANGLE_INCR = 0x80,
	WAYPOINT_FLAGS_END = -1,
	WAYPOINT_FLAGS_INITIALIZED = 0x8000,
	WAYPOINT_MASK_00FF = 0x00FF,
	WAYPOINT_FLAGS_PLATFORM_ON_TRACK_PAUSE = 3,
	PATH_NONE = 0,
	PATH_REACHED_END = -1,
	PATH_REACHED_WAYPOINT = 1,
}

-- from src/game/object_helpers.h:ChainSegment (zero-filled constructor)
function object_helpers_h.new_ChainSegment(): ChainSegment
	return { posX = 0, posY = 0, posZ = 0, pitch = 0, yaw = 0, roll = 0 } :: ChainSegment
end

-- from src/game/object_helpers.h:WaterDropletParams (zero-filled constructor)
function object_helpers_h.new_WaterDropletParams(): WaterDropletParams
	return {
		flags = 0,
		model = 0,
		behavior = 0,
		moveAngleRange = 0,
		moveRange = 0,
		randForwardVelOffset = 0,
		randForwardVelScale = 0,
		randYVelOffset = 0,
		randYVelScale = 0,
		randSizeOffset = 0,
		randSizeScale = 0,
	} :: WaterDropletParams
end

-- from src/game/object_helpers.h:struct802A1230 (zero-filled constructor)
function object_helpers_h.new_struct802A1230(): struct802A1230
	return { unk00 = 0, unk02 = 0 } :: struct802A1230
end

-- from src/game/object_helpers.h:Struct802A272C (zero-filled constructor)
function object_helpers_h.new_Struct802A272C(): Struct802A272C
	return { vecF = table.create(3, 0), vecS = table.create(3, 0) } :: Struct802A272C
end

-- from src/game/object_helpers.h:SpawnParticlesInfo (zero-filled constructor)
function object_helpers_h.new_SpawnParticlesInfo(): SpawnParticlesInfo
	return {
		bhvParam = 0,
		count = 0,
		model = 0,
		offsetY = 0,
		forwardVelBase = 0,
		forwardVelRange = 0,
		velYBase = 0,
		velYRange = 0,
		gravity = 0,
		dragStrength = 0,
		sizeBase = 0,
		sizeRange = 0,
	} :: SpawnParticlesInfo
end

return object_helpers_h
