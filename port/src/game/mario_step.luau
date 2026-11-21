--!strict
--!optimize 2

--[[
	Port of src/game/mario_step.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")

const MarioStepH = require("./mario_step_h")
const GameInit = require("./game_init")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Mario = require("./mario")
const Audio = require("../rom/audio_recorder")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/mario_step.c:data
const mario_step = {
	-- from src/game/mario_step.c:sMovingSandSpeeds L12-12
	sMovingSandSpeeds = { 12, 8, 4, 0 },
	-- from src/game/mario_step.c:gWaterSurfacePseudoFloor L14-17
	gWaterSurfacePseudoFloor = {
		type_ = IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY,
		force = 0,
		flags = 0,
		room = 0,
		lowerY = 0,
		upperY = 0,
		vertex1 = { 0, 0, 0 },
		vertex2 = { 0, 0, 0 },
		vertex3 = { 0, 0, 0 },
		normal = { x = 0.0, y = 1.0, z = 0.0 },
		originOffset = 0.0,
		object = nil,
	} :: GroupsTypesHPlus3Types.Surface,
}

const Floor: { GroupsTypesHPlus3Types.Surface? } = {}
const Ceil: { GroupsTypesHPlus3Types.Surface? } = {}
const LedgeFloor: { GroupsTypesHPlus3Types.Surface? } = {}
const NextPos = { 0, 0, 0 }
const IntendedPos = { 0, 0, 0 }
const LedgePos = { 0, 0, 0 }

Registry.Register("src__game__mario_step", mario_step)

-- from src/game/mario_step.c:get_additive_y_vel_for_jumps L29-31
function mario_step.get_additive_y_vel_for_jumps(): number
	return 0.0
end

-- from src/game/mario_step.c:stub_mario_step_1 L42-43
function mario_step.stub_mario_step_1(x: GroupsTypesHPlus3Types.MarioState)
	-- Empty in the C source.
end

-- from src/game/mario_step.c:stub_mario_step_2 L52-53
function mario_step.stub_mario_step_2()
	-- Empty in the C source.
end

-- from src/game/mario_step.c:transfer_bully_speed L55-72
function mario_step.transfer_bully_speed(obj1: MarioStepH.BullyCollisionData, obj2: MarioStepH.BullyCollisionData)
	const rx = F32(obj2.posX - obj1.posX)
	const rz = F32(obj2.posZ - obj1.posZ)

	--! Bully NaN crash
	const projectedV1 = F32(F32(F32(rx * obj1.velX) + F32(rz * obj1.velZ)) / F32(F32(rx * rx) + F32(rz * rz)))
	const projectedV2 = F32(F32(F32(-rx * obj2.velX) - F32(rz * obj2.velZ)) / F32(F32(rx * rx) + F32(rz * rz)))

	-- Kill speed along r. Convert one object's speed along r and transfer it to
	-- the other object.
	obj2.velX = F32(obj2.velX + F32(F32(F32(obj2.conversionRatio * projectedV1) * rx) - F32(projectedV2 * -rx)))
	obj2.velZ = F32(obj2.velZ + F32(F32(F32(obj2.conversionRatio * projectedV1) * rz) - F32(projectedV2 * -rz)))

	obj1.velX = F32(obj1.velX + F32(F32(-projectedV1 * rx) + F32(F32(obj1.conversionRatio * projectedV2) * -rx)))
	obj1.velZ = F32(obj1.velZ + F32(F32(-projectedV1 * rz) + F32(F32(obj1.conversionRatio * projectedV2) * -rz)))

	--! Bully battery
end

-- from src/game/mario_step.c:init_bully_collision_data L74-87
function mario_step.init_bully_collision_data(data: MarioStepH.BullyCollisionData, posX: number, posZ: number, forwardVel: number, yaw: number, conversionRatio: number, radius: number)
	posX = F32(posX)
	posZ = F32(posZ)
	forwardVel = F32(forwardVel)
	conversionRatio = F32(conversionRatio)
	radius = F32(radius)
	if forwardVel < 0.0 then
		forwardVel = F32(forwardVel * -1.0)
		yaw = S16(yaw + 0x8000)
	end

	data.radius = radius
	data.conversionRatio = conversionRatio
	data.posX = posX
	data.posZ = posZ
	data.velX = F32(forwardVel * SrcEngineMathUtilH.sins(yaw))
	data.velZ = F32(forwardVel * SrcEngineMathUtilH.coss(yaw))
end

-- from src/game/mario_step.c:mario_bonk_reflection L89-105
function mario_step.mario_bonk_reflection(m: GroupsTypesHPlus3Types.MarioState, negateSpeed: number)
	if m.wall ~= nil then
		const wallAngle = S16(SrcEngineMathUtil.atan2s(m.wall.normal.z, m.wall.normal.x))

		m.faceAngle[2] = S16(wallAngle - S16(m.faceAngle[2] - wallAngle))
		Audio.play_sound(if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_BONK else IncludeSoundsH.SOUND_ACTION_BONK, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	else
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HIT, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end

	if negateSpeed ~= 0 then
		Mario.mario_set_forward_vel(m, -m.forwardVel)
	else
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
	end
end

-- from src/game/mario_step.c:mario_update_quicksand L107-156
function mario_step.mario_update_quicksand(m: GroupsTypesHPlus3Types.MarioState, sinkingSpeed: number): number
	sinkingSpeed = F32(sinkingSpeed)
	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) then
		m.quicksandDepth = 0.0
	else
		if m.quicksandDepth < F32(1.1) then
			m.quicksandDepth = F32(1.1)
		end

		const floorType = (m.floor :: GroupsTypesHPlus3Types.Surface).type_

		if floorType == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_QUICKSAND then
			m.quicksandDepth = F32(m.quicksandDepth + sinkingSpeed)
			if m.quicksandDepth >= 10.0 then
				m.quicksandDepth = 10.0
			end
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_MOVING_QUICKSAND then
			m.quicksandDepth = F32(m.quicksandDepth + sinkingSpeed)
			if m.quicksandDepth >= 25.0 then
				m.quicksandDepth = 25.0
			end
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_MOVING_QUICKSAND then
			m.quicksandDepth = F32(m.quicksandDepth + sinkingSpeed)
			if m.quicksandDepth >= 60.0 then
				m.quicksandDepth = 60.0
			end
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_DEEP_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_DEEP_MOVING_QUICKSAND then
			m.quicksandDepth = F32(m.quicksandDepth + sinkingSpeed)
			if m.quicksandDepth >= 160.0 then
				Mario.update_mario_sound_and_camera(m)
				return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_QUICKSAND_DEATH, 0)
			end
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_MOVING_QUICKSAND then
			Mario.update_mario_sound_and_camera(m)
			return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_QUICKSAND_DEATH, 0)
		else
			m.quicksandDepth = 0.0
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_step.c:mario_push_off_steep_floor L158-170
function mario_step.mario_push_off_steep_floor(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	const floorDYaw = S16(m.floorAngle - m.faceAngle[2])

	if floorDYaw > -0x4000 and floorDYaw < 0x4000 then
		m.forwardVel = 16.0
		m.faceAngle[2] = m.floorAngle
	else
		m.forwardVel = -16.0
		m.faceAngle[2] = S16(m.floorAngle + 0x8000)
	end

	return Mario.set_mario_action(m, action, actionArg)
end

-- from src/game/mario_step.c:mario_update_moving_sand L172-188
function mario_step.mario_update_moving_sand(m: GroupsTypesHPlus3Types.MarioState): number
	const floor = m.floor :: GroupsTypesHPlus3Types.Surface
	const floorType = floor.type_

	if floorType == IncludeSurfaceTerrainsH.SURFACE_DEEP_MOVING_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_MOVING_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_MOVING_QUICKSAND or floorType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_MOVING_QUICKSAND then
		const pushAngle = S16(bit32.lshift(floor.force, 8))
		const pushSpeed = mario_step.sMovingSandSpeeds[floor.force // 256 + 1]

		m.vel[1] = F32(m.vel[1] + F32(pushSpeed * SrcEngineMathUtilH.sins(pushAngle)))
		m.vel[3] = F32(m.vel[3] + F32(pushSpeed * SrcEngineMathUtilH.coss(pushAngle)))

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_step.c:mario_update_windy_ground L190-221
function mario_step.mario_update_windy_ground(m: GroupsTypesHPlus3Types.MarioState): number
	const floor = m.floor :: GroupsTypesHPlus3Types.Surface

	if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_HORIZONTAL_WIND then
		local pushSpeed: number
		const pushAngle = S16(bit32.lshift(floor.force, 8))

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_MOVING) then
			const pushDYaw = S16(m.faceAngle[2] - pushAngle)

			pushSpeed = if m.forwardVel > 0.0 then F32(-m.forwardVel * 0.5) else -8.0

			if pushDYaw > -0x4000 and pushDYaw < 0x4000 then
				pushSpeed = -pushSpeed
			end

			pushSpeed = F32(pushSpeed * SrcEngineMathUtilH.coss(pushDYaw))
		else
			pushSpeed = F32(F32(3.2) + (GameInit.gGlobalTimer % 4))
		end

		m.vel[1] = F32(m.vel[1] + F32(pushSpeed * SrcEngineMathUtilH.sins(pushAngle)))
		m.vel[3] = F32(m.vel[3] + F32(pushSpeed * SrcEngineMathUtilH.coss(pushAngle)))

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_step.c:stop_and_set_height_to_floor L223-234
function mario_step.stop_and_set_height_to_floor(m: GroupsTypesHPlus3Types.MarioState)
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	Mario.mario_set_forward_vel(m, 0.0)
	m.vel[2] = 0.0

	--! This is responsible for some downwarps.
	m.pos[2] = m.floorHeight

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)
end

-- from src/game/mario_step.c:stationary_ground_step L236-256
function mario_step.stationary_ground_step(m: GroupsTypesHPlus3Types.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object
	local stepResult = IncludeSm64H.GROUND_STEP_NONE

	Mario.mario_set_forward_vel(m, 0.0)

	local takeStep = mario_step.mario_update_moving_sand(m)
	takeStep = bit32.bor(takeStep, mario_step.mario_update_windy_ground(m))

	if takeStep ~= 0 then
		stepResult = mario_step.perform_ground_step(m)
	else
		--! This is responsible for several stationary downwarps.
		m.pos[2] = m.floorHeight

		SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
		SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)
	end

	return stepResult
end

-- from src/game/mario_step.c:perform_ground_quarter_step L258-320
function mario_step.perform_ground_quarter_step(m: GroupsTypesHPlus3Types.MarioState, nextPos: { number }): number
	Mario.resolve_and_return_wall_collisions(nextPos, 30.0, 24.0)
	const upperWall = Mario.resolve_and_return_wall_collisions(nextPos, 60.0, 50.0)

	local floorHeight = SrcEngineSurfaceCollision.find_floor(nextPos[1], nextPos[2], nextPos[3], Floor)
	local floor = Floor[1]
	const ceilHeight = Mario.vec3f_find_ceil(nextPos, floorHeight, Ceil)

	const waterLevel = SrcEngineSurfaceCollision.find_water_level(nextPos[1], nextPos[3])

	m.wall = upperWall

	if floor == nil then
		return IncludeSm64H.GROUND_STEP_HIT_WALL_STOP_QSTEPS
	end

	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) and floorHeight < waterLevel then
		floorHeight = waterLevel
		floor = mario_step.gWaterSurfacePseudoFloor
		--! Wrong origin offset (no effect)
		floor.originOffset = floorHeight
	end

	if nextPos[2] > F32(floorHeight + 100.0) then
		if F32(nextPos[2] + 160.0) >= ceilHeight then
			return IncludeSm64H.GROUND_STEP_HIT_WALL_STOP_QSTEPS
		end

		SrcEngineMathUtil.vec3f_copy(m.pos, nextPos)
		m.floor = floor
		m.floorHeight = floorHeight
		return IncludeSm64H.GROUND_STEP_LEFT_GROUND
	end

	if F32(floorHeight + 160.0) >= ceilHeight then
		return IncludeSm64H.GROUND_STEP_HIT_WALL_STOP_QSTEPS
	end

	SrcEngineMathUtil.vec3f_set(m.pos, nextPos[1], floorHeight, nextPos[3])
	m.floor = floor
	m.floorHeight = floorHeight

	if upperWall ~= nil then
		const wallDYaw = S16(SrcEngineMathUtil.atan2s(upperWall.normal.z, upperWall.normal.x) - m.faceAngle[2])

		if wallDYaw >= 0x2AAA and wallDYaw <= 0x5555 then
			return IncludeSm64H.GROUND_STEP_NONE
		end

		if wallDYaw <= -0x2AAA and wallDYaw >= -0x5555 then
			return IncludeSm64H.GROUND_STEP_NONE
		end

		return IncludeSm64H.GROUND_STEP_HIT_WALL_CONTINUE_QSTEPS
	end

	return IncludeSm64H.GROUND_STEP_NONE
end

-- from src/game/mario_step.c:perform_ground_step L322-346
function mario_step.perform_ground_step(m: GroupsTypesHPlus3Types.MarioState): number
	local stepResult: number

	for i = 1, 4 do
		const floor = m.floor :: GroupsTypesHPlus3Types.Surface

		IntendedPos[1] = F32(m.pos[1] + F32(floor.normal.y * F32(m.vel[1] / 4.0)))
		IntendedPos[3] = F32(m.pos[3] + F32(floor.normal.y * F32(m.vel[3] / 4.0)))
		IntendedPos[2] = m.pos[2]

		stepResult = mario_step.perform_ground_quarter_step(m, IntendedPos)
		if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND or stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL_STOP_QSTEPS then
			break
		end
	end

	m.terrainSoundAddend = Mario.mario_get_terrain_sound_addend(m)

	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	if stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL_CONTINUE_QSTEPS then
		stepResult = IncludeSm64H.GROUND_STEP_HIT_WALL
	end

	return stepResult
end

-- from src/game/mario_step.c:check_ledge_grab L348-386
function mario_step.check_ledge_grab(m: GroupsTypesHPlus3Types.MarioState, wall: GroupsTypesHPlus3Types.Surface, intendedPos: { number }, nextPos: { number }): number
	if m.vel[2] > 0 then
		return IncludePRUltratypesH.FALSE
	end

	const displacementX = F32(nextPos[1] - intendedPos[1])
	const displacementZ = F32(nextPos[3] - intendedPos[3])

	-- Only ledge grab if the wall displaced Mario in the opposite direction of
	-- his velocity.
	if F32(F32(displacementX * m.vel[1]) + F32(displacementZ * m.vel[3])) > 0.0 then
		return IncludePRUltratypesH.FALSE
	end

	--! Since the search for floors starts at y + 160, we will sometimes grab
	-- a higher ledge than expected (glitchy ledge grab)
	LedgePos[1] = F32(nextPos[1] - F32(wall.normal.x * 60.0))
	LedgePos[3] = F32(nextPos[3] - F32(wall.normal.z * 60.0))
	LedgePos[2] = SrcEngineSurfaceCollision.find_floor(LedgePos[1], F32(nextPos[2] + 160.0), LedgePos[3], LedgeFloor)

	if F32(LedgePos[2] - nextPos[2]) <= 100.0 then
		return IncludePRUltratypesH.FALSE
	end

	const ledgeFloor = LedgeFloor[1] :: GroupsTypesHPlus3Types.Surface

	SrcEngineMathUtil.vec3f_copy(m.pos, LedgePos)
	m.floor = ledgeFloor
	m.floorHeight = LedgePos[2]

	m.floorAngle = SrcEngineMathUtil.atan2s(ledgeFloor.normal.z, ledgeFloor.normal.x)

	m.faceAngle[1] = 0
	m.faceAngle[2] = S16(SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x) + 0x8000)
	return IncludePRUltratypesH.TRUE
end

-- from src/game/mario_step.c:perform_air_quarter_step L388-501
function mario_step.perform_air_quarter_step(m: GroupsTypesHPlus3Types.MarioState, intendedPos: { number }, stepArg: number): number
	SrcEngineMathUtil.vec3f_copy(NextPos, intendedPos)

	const upperWall = Mario.resolve_and_return_wall_collisions(NextPos, 150.0, 50.0)
	const lowerWall = Mario.resolve_and_return_wall_collisions(NextPos, 30.0, 50.0)

	local floorHeight = SrcEngineSurfaceCollision.find_floor(NextPos[1], NextPos[2], NextPos[3], Floor)
	local floor = Floor[1]
	const ceilHeight = Mario.vec3f_find_ceil(NextPos, floorHeight, Ceil)

	const waterLevel = SrcEngineSurfaceCollision.find_water_level(NextPos[1], NextPos[3])

	m.wall = nil

	--! The water pseudo floor is not referenced when your intended qstep is
	-- out of bounds, so it won't detect you as landing.
	if floor == nil then
		if NextPos[2] <= m.floorHeight then
			m.pos[2] = m.floorHeight
			return IncludeSm64H.AIR_STEP_LANDED
		end

		m.pos[2] = NextPos[2]
		return IncludeSm64H.AIR_STEP_HIT_WALL
	end

	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) and floorHeight < waterLevel then
		floorHeight = waterLevel
		floor = mario_step.gWaterSurfacePseudoFloor
		--! Incorrect origin offset (no effect)
		floor.originOffset = floorHeight
	end

	--! This check uses f32, but findFloor uses short (overflow jumps)
	if NextPos[2] <= floorHeight then
		if F32(ceilHeight - floorHeight) > 160.0 then
			m.pos[1] = NextPos[1]
			m.pos[3] = NextPos[3]
			m.floor = floor
			m.floorHeight = floorHeight
		end

		--! When ceilHeight - floorHeight <= 160, the step result says that
		-- Mario landed, but his movement is cancelled and his referenced floor
		-- isn't updated (pedro spots)
		m.pos[2] = floorHeight
		return IncludeSm64H.AIR_STEP_LANDED
	end

	if F32(NextPos[2] + 160.0) > ceilHeight then
		if m.vel[2] >= 0.0 then
			m.vel[2] = 0.0

			--! Uses referenced ceiling instead of ceil (ceiling hang upwarp)
			if bit32.btest(stepArg, IncludeSm64H.AIR_STEP_CHECK_HANG) and m.ceil ~= nil and m.ceil.type_ == IncludeSurfaceTerrainsH.SURFACE_HANGABLE then
				return IncludeSm64H.AIR_STEP_GRABBED_CEILING
			end

			return IncludeSm64H.AIR_STEP_NONE
		end

		--! Potential subframe downwarp->upwarp?
		if NextPos[2] <= m.floorHeight then
			m.pos[2] = m.floorHeight
			return IncludeSm64H.AIR_STEP_LANDED
		end

		m.pos[2] = NextPos[2]
		return IncludeSm64H.AIR_STEP_HIT_WALL
	end

	--! When the wall is not completely vertical or there is a slight wall
	-- misalignment, you can activate these conditions in unexpected situations
	if bit32.btest(stepArg, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB) and upperWall == nil and lowerWall ~= nil then
		if mario_step.check_ledge_grab(m, lowerWall, intendedPos, NextPos) ~= 0 then
			return IncludeSm64H.AIR_STEP_GRABBED_LEDGE
		end

		SrcEngineMathUtil.vec3f_copy(m.pos, NextPos)
		m.floor = floor
		m.floorHeight = floorHeight
		return IncludeSm64H.AIR_STEP_NONE
	end

	SrcEngineMathUtil.vec3f_copy(m.pos, NextPos)
	m.floor = floor
	m.floorHeight = floorHeight

	if upperWall ~= nil or lowerWall ~= nil then
		m.wall = if upperWall ~= nil then upperWall else lowerWall
		const wall = m.wall :: GroupsTypesHPlus3Types.Surface
		const wallDYaw = S16(SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x) - m.faceAngle[2])

		if wall.type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
			return IncludeSm64H.AIR_STEP_HIT_LAVA_WALL
		end

		if wallDYaw < -0x6000 or wallDYaw > 0x6000 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_UNKNOWN_30)
			return IncludeSm64H.AIR_STEP_HIT_WALL
		end
	end

	return IncludeSm64H.AIR_STEP_NONE
end

-- from src/game/mario_step.c:apply_twirl_gravity L503-517
function mario_step.apply_twirl_gravity(m: GroupsTypesHPlus3Types.MarioState)
	local heaviness = 1.0

	if m.angleVel[2] > 1024 then
		heaviness = F32(1024.0 / m.angleVel[2])
	end

	const terminalVelocity = F32(-75.0 * heaviness)

	m.vel[2] = F32(m.vel[2] - F32(4.0 * heaviness))
	if m.vel[2] < terminalVelocity then
		m.vel[2] = terminalVelocity
	end
end

-- from src/game/mario_step.c:should_strengthen_gravity_for_jump_ascent L519-533
function mario_step.should_strengthen_gravity_for_jump_ascent(m: GroupsTypesHPlus3Types.MarioState): number
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_UNKNOWN_08) then
		return IncludePRUltratypesH.FALSE
	end

	if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_INTANGIBLE, IncludeSm64H.ACT_FLAG_INVULNERABLE)) then
		return IncludePRUltratypesH.FALSE
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) and m.vel[2] > 20.0 then
		return if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_CONTROL_JUMP_HEIGHT) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_step.c:apply_gravity L535-581
function mario_step.apply_gravity(m: GroupsTypesHPlus3Types.MarioState)
	if m.action == IncludeSm64H.ACT_TWIRLING and m.vel[2] < 0.0 then
		mario_step.apply_twirl_gravity(m)
	elseif m.action == IncludeSm64H.ACT_SHOT_FROM_CANNON then
		m.vel[2] = F32(m.vel[2] - 1.0)
		if m.vel[2] < -75.0 then
			m.vel[2] = -75.0
		end
	elseif m.action == IncludeSm64H.ACT_LONG_JUMP or m.action == IncludeSm64H.ACT_SLIDE_KICK or m.action == IncludeSm64H.ACT_BBH_ENTER_SPIN then
		m.vel[2] = F32(m.vel[2] - 2.0)
		if m.vel[2] < -75.0 then
			m.vel[2] = -75.0
		end
	elseif m.action == IncludeSm64H.ACT_LAVA_BOOST or m.action == IncludeSm64H.ACT_FALL_AFTER_STAR_GRAB then
		m.vel[2] = F32(m.vel[2] - F32(3.2))
		if m.vel[2] < -65.0 then
			m.vel[2] = -65.0
		end
	elseif m.action == IncludeSm64H.ACT_GETTING_BLOWN then
		m.vel[2] = F32(m.vel[2] - m.gettingBlownGravity)
		if m.vel[2] < -75.0 then
			m.vel[2] = -75.0
		end
	elseif mario_step.should_strengthen_gravity_for_jump_ascent(m) ~= 0 then
		m.vel[2] = F32(m.vel[2] / 4.0)
	elseif bit32.btest(m.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
		m.vel[2] = F32(m.vel[2] - F32(1.6))
		if m.vel[2] < -16.0 then
			m.vel[2] = -16.0
		end
	elseif bit32.btest(m.flags, IncludeSm64H.MARIO_WING_CAP) and m.vel[2] < 0.0 and bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState
		marioBodyState.wingFlutter = IncludePRUltratypesH.TRUE

		m.vel[2] = F32(m.vel[2] - 2.0)
		if m.vel[2] < -37.5 then
			m.vel[2] = F32(m.vel[2] + 4.0)
			if m.vel[2] > -37.5 then
				m.vel[2] = -37.5
			end
		end
	else
		m.vel[2] = F32(m.vel[2] - 4.0)
		if m.vel[2] < -75.0 then
			m.vel[2] = -75.0
		end
	end
end

-- from src/game/mario_step.c:apply_vertical_wind L583-608
function mario_step.apply_vertical_wind(m: GroupsTypesHPlus3Types.MarioState)
	if m.action ~= IncludeSm64H.ACT_GROUND_POUND then
		const offsetY = F32(m.pos[2] - -1500.0)

		if (m.floor :: GroupsTypesHPlus3Types.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_VERTICAL_WIND and -3000.0 < offsetY and offsetY < 2000.0 then
			local maxVelY: number

			if offsetY >= 0.0 then
				maxVelY = F32(10000.0 / F32(offsetY + 200.0))
			else
				maxVelY = 50.0
			end

			if m.vel[2] < maxVelY then
				m.vel[2] = F32(m.vel[2] + F32(maxVelY / 8.0))
				if m.vel[2] > maxVelY then
					m.vel[2] = maxVelY
				end
			end
		end
	end
end

-- from src/game/mario_step.c:perform_air_step L610-655
function mario_step.perform_air_step(m: GroupsTypesHPlus3Types.MarioState, stepArg: number): number
	m.wall = nil

	local stepResult = IncludeSm64H.AIR_STEP_NONE

	for i = 1, 4 do
		IntendedPos[1] = F32(m.pos[1] + F32(m.vel[1] / 4.0))
		IntendedPos[2] = F32(m.pos[2] + F32(m.vel[2] / 4.0))
		IntendedPos[3] = F32(m.pos[3] + F32(m.vel[3] / 4.0))

		const quarterStepResult = mario_step.perform_air_quarter_step(m, IntendedPos, stepArg)

		--! On one qf, hit OOB/ceil/wall to store the 2 return value, and continue
		-- getting 0s until your last qf. Graze a wall on your last qf, and it will
		-- return the stored 2 with a sharply angled reference wall. (some gwks)
		if quarterStepResult ~= IncludeSm64H.AIR_STEP_NONE then
			stepResult = quarterStepResult
		end

		if quarterStepResult == IncludeSm64H.AIR_STEP_LANDED or quarterStepResult == IncludeSm64H.AIR_STEP_GRABBED_LEDGE or quarterStepResult == IncludeSm64H.AIR_STEP_GRABBED_CEILING or quarterStepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
			break
		end
	end

	if m.vel[2] >= 0.0 then
		m.peakHeight = m.pos[2]
	end

	m.terrainSoundAddend = Mario.mario_get_terrain_sound_addend(m)

	if m.action ~= IncludeSm64H.ACT_FLYING then
		mario_step.apply_gravity(m)
	end

	mario_step.apply_vertical_wind(m)

	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	return stepResult
end

-- from src/game/mario_step.c:set_vel_from_pitch_and_yaw L659-663
function mario_step.set_vel_from_pitch_and_yaw(m: GroupsTypesHPlus3Types.MarioState)
	m.vel[1] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[2] = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[1]))
	m.vel[3] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.coss(m.faceAngle[2]))
end

-- from src/game/mario_step.c:set_vel_from_yaw L665-669
function mario_step.set_vel_from_yaw(m: GroupsTypesHPlus3Types.MarioState)
	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[1] = m.slideVelX
	m.vel[2] = 0.0
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))
	m.vel[3] = m.slideVelZ
end

return mario_step
