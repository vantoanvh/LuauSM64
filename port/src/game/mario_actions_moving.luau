--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_moving.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeSm64H = require("../../include/sm64_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Mario = require("./mario")
const MarioStep = require("./mario_step")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSoundsH = require("../../include/sounds_h")
const InteractionH = require("./interaction_h")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const Interaction = require("./interaction")
const MarioActionsObject = require("./mario_actions_object")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")
const Memory = require("./memory")

-- from src/game/mario_actions_moving.c:LandingAction
export type LandingAction = {
	numFrames: number,
	unk02: number,
	verySteepAction: number,
	endAction: number,
	aPressedAction: number,
	offFloorAction: number,
	slideAction: number,
}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/mario_actions_moving.c:data
const mario_actions_moving = {
	-- from src/game/mario_actions_moving.c:sJumpLandAction L26-28
	sJumpLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_JUMP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_DOUBLE_JUMP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sFreefallLandAction L30-32
	sFreefallLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_FREEFALL_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_DOUBLE_JUMP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sSideFlipLandAction L34-36
	sSideFlipLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_SIDE_FLIP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_DOUBLE_JUMP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sHoldJumpLandAction L38-40
	sHoldJumpLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_HOLD_FREEFALL,
		endAction = IncludeSm64H.ACT_HOLD_JUMP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_HOLD_JUMP,
		offFloorAction = IncludeSm64H.ACT_HOLD_FREEFALL,
		slideAction = IncludeSm64H.ACT_HOLD_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sHoldFreefallLandAction L42-44
	sHoldFreefallLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_HOLD_FREEFALL,
		endAction = IncludeSm64H.ACT_HOLD_FREEFALL_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_HOLD_JUMP,
		offFloorAction = IncludeSm64H.ACT_HOLD_FREEFALL,
		slideAction = IncludeSm64H.ACT_HOLD_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sLongJumpLandAction L46-48
	sLongJumpLandAction = {
		numFrames = 6,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_LONG_JUMP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_LONG_JUMP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sDoubleJumpLandAction L50-52
	sDoubleJumpLandAction = {
		numFrames = 4,
		unk02 = 5,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_DOUBLE_JUMP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_JUMP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sTripleJumpLandAction L54-56
	sTripleJumpLandAction = {
		numFrames = 4,
		unk02 = 0,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_TRIPLE_JUMP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_UNINITIALIZED,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sBackflipLandAction L58-60
	sBackflipLandAction = {
		numFrames = 4,
		unk02 = 0,
		verySteepAction = IncludeSm64H.ACT_FREEFALL,
		endAction = IncludeSm64H.ACT_BACKFLIP_LAND_STOP,
		aPressedAction = IncludeSm64H.ACT_BACKFLIP,
		offFloorAction = IncludeSm64H.ACT_FREEFALL,
		slideAction = IncludeSm64H.ACT_BEGIN_SLIDING,
	},
	-- from src/game/mario_actions_moving.c:sFloorAlignMatrix L62-62
	sFloorAlignMatrix = {
		{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
	},
}

Registry.Register("src__game__mario_actions_moving", mario_actions_moving)

-- C stack temporaries passed by address (WallCollisionData, Surface out pointer, Vec3f) are module level scratch
-- from src/game/mario_actions_moving.c:check_ledge_climb_down:wallCols L100-135
const CollisionData = {
	x = 0,
	y = 0,
	z = 0,
	offsetY = 0,
	radius = 0,
	filler = buffer.create(2),
	numWalls = 0,
	walls = {},
} :: SrcEngineSurfaceCollisionH.WallCollisionData
const FloorSurface: { GroupsTypesHPlus3.Surface? } = {}
const StartPos = { 0, 0, 0 }

-- from src/game/mario_actions_moving.c:LandingAction (zero-filled constructor)
function mario_actions_moving.new_LandingAction(): LandingAction
	return {
		numFrames = 0,
		unk02 = 0,
		verySteepAction = 0,
		endAction = 0,
		aPressedAction = 0,
		offFloorAction = 0,
		slideAction = 0,
	} :: LandingAction
end

-- from src/game/mario_actions_moving.c:tilt_body_running L64-68
function mario_actions_moving.tilt_body_running(m: GroupsTypesHPlus3.MarioState): number
	local pitch = Mario.find_floor_slope(m, 0)
	pitch = S16(TruncS32(F32(F32(pitch * m.forwardVel) / 40)))

	return S16(-pitch)
end

-- from src/game/mario_actions_moving.c:play_step_sound L70-86
function mario_actions_moving.play_step_sound(m: GroupsTypesHPlus3.MarioState, frame1: number, frame2: number)
	frame1 = S16(TruncS32(frame1))
	frame2 = S16(TruncS32(frame2))
	if Mario.is_anim_past_frame(m, frame1) ~= 0 or Mario.is_anim_past_frame(m, frame2) ~= 0 then
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
			if marioObj.header.gfx.animInfo.animID == IncludeMarioAnimationIdsH.MARIO_ANIM_TIPTOE then
				Mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_METAL_STEP_TIPTOE, 0)
			else
				Mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_METAL_STEP, 0)
			end
		elseif m.quicksandDepth > 50 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_QUICKSAND_STEP, marioObj.header.gfx.cameraToObject)
		elseif marioObj.header.gfx.animInfo.animID == IncludeMarioAnimationIdsH.MARIO_ANIM_TIPTOE then
			Mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_STEP_TIPTOE, 0)
		else
			Mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_STEP, 0)
		end
	end
end

-- from src/game/mario_actions_moving.c:align_with_floor L88-92
function mario_actions_moving.align_with_floor(m: GroupsTypesHPlus3.MarioState)
	m.pos[2] = m.floorHeight
	SrcEngineMathUtil.mtxf_align_terrain_triangle(mario_actions_moving.sFloorAlignMatrix[m.unk00 + 1], m.pos, m.faceAngle[2], 40)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	marioObj.header.gfx.throwMatrix = { mario_actions_moving.sFloorAlignMatrix[m.unk00 + 1] }
end

-- from src/game/mario_actions_moving.c:begin_walking_action L94-98
function mario_actions_moving.begin_walking_action(m: GroupsTypesHPlus3.MarioState, forwardVel: number, action: number, actionArg: number): number
	forwardVel = F32(forwardVel)
	m.faceAngle[2] = m.intendedYaw
	Mario.mario_set_forward_vel(m, forwardVel)

	return Mario.set_mario_action(m, action, actionArg)
end

-- from src/game/mario_actions_moving.c:check_ledge_climb_down L100-135
function mario_actions_moving.check_ledge_climb_down(m: GroupsTypesHPlus3.MarioState)
	if m.forwardVel < 10 then
		CollisionData.x = m.pos[1]
		CollisionData.y = m.pos[2]
		CollisionData.z = m.pos[3]
		CollisionData.radius = 10
		CollisionData.offsetY = -10

		if SrcEngineSurfaceCollision.find_wall_collisions(CollisionData) ~= 0 then
			const floorHeight = SrcEngineSurfaceCollision.find_floor(CollisionData.x, CollisionData.y, CollisionData.z, FloorSurface)
			if FloorSurface[1] ~= nil and F32(CollisionData.y - floorHeight) > 160 then
				const wall = CollisionData.walls[CollisionData.numWalls] :: GroupsTypesHPlus3.Surface
				const wallAngle = SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x)
				const wallDYaw = S16(wallAngle - m.faceAngle[2])

				if wallDYaw > -0x4000 and wallDYaw < 0x4000 then
					m.pos[1] = F32(CollisionData.x - F32(20 * wall.normal.x))
					m.pos[3] = F32(CollisionData.z - F32(20 * wall.normal.z))

					m.faceAngle[1] = 0
					m.faceAngle[2] = S16(wallAngle + 0x8000)

					Mario.set_mario_action(m, IncludeSm64H.ACT_LEDGE_CLIMB_DOWN, 0)
					Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CLIMB_DOWN_LEDGE)
				end
			end
		end
	end
end

-- from src/game/mario_actions_moving.c:slide_bonk L137-145
function mario_actions_moving.slide_bonk(m: GroupsTypesHPlus3.MarioState, fastAction: number, slowAction: number)
	if m.forwardVel > 16 then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
		Mario.drop_and_set_mario_action(m, fastAction, 0)
	else
		Mario.mario_set_forward_vel(m, 0)
		Mario.set_mario_action(m, slowAction, 0)
	end
end

-- from src/game/mario_actions_moving.c:set_triple_jump_action L147-157
function mario_actions_moving.set_triple_jump_action(m: GroupsTypesHPlus3.MarioState, action: number, actionArg: number): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_WING_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FLYING_TRIPLE_JUMP, 0)
	elseif m.forwardVel > 20 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_TRIPLE_JUMP, 0)
	else
		return Mario.set_mario_action(m, IncludeSm64H.ACT_JUMP, 0)
	end
end

-- from src/game/mario_actions_moving.c:update_sliding_angle L159-217
function mario_actions_moving.update_sliding_angle(m: GroupsTypesHPlus3.MarioState, accel: number, lossFactor: number)
	accel = F32(accel)
	lossFactor = F32(lossFactor)
	const floor = m.floor :: GroupsTypesHPlus3.Surface
	const slopeAngle = SrcEngineMathUtil.atan2s(floor.normal.z, floor.normal.x)
	const steepness = F32(math.sqrt(F32(F32(floor.normal.x * floor.normal.x) + F32(floor.normal.z * floor.normal.z))))

	m.slideVelX = F32(m.slideVelX + F32(F32(accel * steepness) * SrcEngineMathUtilH.sins(slopeAngle)))
	m.slideVelZ = F32(m.slideVelZ + F32(F32(accel * steepness) * SrcEngineMathUtilH.coss(slopeAngle)))

	m.slideVelX = F32(m.slideVelX * lossFactor)
	m.slideVelZ = F32(m.slideVelZ * lossFactor)

	m.slideYaw = SrcEngineMathUtil.atan2s(m.slideVelZ, m.slideVelX)

	const facingDYaw = S16(m.faceAngle[2] - m.slideYaw)
	local newFacingDYaw = facingDYaw

	-- -0x4000 not handled - can slide down a slope while facing perpendicular to it
	if newFacingDYaw > 0 and newFacingDYaw <= 0x4000 then
		newFacingDYaw -= 0x200
		if newFacingDYaw < 0 then
			newFacingDYaw = 0
		end
	elseif newFacingDYaw > -0x4000 and newFacingDYaw < 0 then
		newFacingDYaw += 0x200
		if newFacingDYaw > 0 then
			newFacingDYaw = 0
		end
	elseif newFacingDYaw > 0x4000 and newFacingDYaw < 0x8000 then
		newFacingDYaw += 0x200
		if newFacingDYaw > 0x8000 then
			newFacingDYaw = 0x8000
		end
	elseif newFacingDYaw > -0x8000 and newFacingDYaw < -0x4000 then
		newFacingDYaw -= 0x200
		if newFacingDYaw < -0x8000 then
			newFacingDYaw = -0x8000
		end
	end

	m.faceAngle[2] = S16(m.slideYaw + newFacingDYaw)

	m.vel[1] = m.slideVelX
	m.vel[2] = 0
	m.vel[3] = m.slideVelZ

	MarioStep.mario_update_moving_sand(m)
	MarioStep.mario_update_windy_ground(m)

	-- Speed is capped a frame late (butt slide HSG)
	m.forwardVel = F32(math.sqrt(F32(F32(m.slideVelX * m.slideVelX) + F32(m.slideVelZ * m.slideVelZ))))
	if m.forwardVel > 100 then
		m.slideVelX = F32(F32(m.slideVelX * 100) / m.forwardVel)
		m.slideVelZ = F32(F32(m.slideVelZ * 100) / m.forwardVel)
	end

	if newFacingDYaw < -0x4000 or newFacingDYaw > 0x4000 then
		m.forwardVel *= -1
	end
end

-- from src/game/mario_actions_moving.c:update_sliding L219-281
function mario_actions_moving.update_sliding(m: GroupsTypesHPlus3.MarioState, stopSpeed: number): number
	stopSpeed = F32(stopSpeed)
	local stopped = IncludePRUltratypesH.FALSE

	const intendedDYaw = S16(m.intendedYaw - m.slideYaw)
	local forward = SrcEngineMathUtilH.coss(intendedDYaw)
	const sideward = SrcEngineMathUtilH.sins(intendedDYaw)

	-- 10k glitch
	if forward < 0 and m.forwardVel >= 0 then
		forward = F32(forward * F32(0.5 + F32(0.5 * m.forwardVel / 100)))
	end

	local accel = 0
	local lossFactor = 0
	const slopeClass = Mario.mario_get_floor_class(m)

	if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
		accel = 10
		lossFactor = F32(F32(F32(m.intendedMag / 32 * forward) * F32(0.02)) + F32(0.98))
	elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_SLIPPERY then
		accel = 8
		lossFactor = F32(F32(F32(m.intendedMag / 32 * forward) * F32(0.02)) + F32(0.96))
	elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_NOT_SLIPPERY then
		accel = 5
		lossFactor = F32(F32(F32(m.intendedMag / 32 * forward) * F32(0.02)) + F32(0.92))
	else
		accel = 7
		lossFactor = F32(F32(F32(m.intendedMag / 32 * forward) * F32(0.02)) + F32(0.92))
	end

	const oldSpeed = F32(math.sqrt(F32(F32(m.slideVelX * m.slideVelX) + F32(m.slideVelZ * m.slideVelZ))))

	-- This is attempting to use trig derivatives to rotate Mario's speed.
	-- It is slightly off/asymmetric since it uses the new X speed, but the old
	-- Z speed.
	m.slideVelX = F32(m.slideVelX + F32(F32(F32(m.slideVelZ * (m.intendedMag / 32)) * sideward) * F32(0.05)))
	m.slideVelZ = F32(m.slideVelZ - F32(F32(F32(m.slideVelX * (m.intendedMag / 32)) * sideward) * F32(0.05)))

	const newSpeed = F32(math.sqrt(F32(F32(m.slideVelX * m.slideVelX) + F32(m.slideVelZ * m.slideVelZ))))

	if oldSpeed > 0 and newSpeed > 0 then
		m.slideVelX = F32(F32(m.slideVelX * oldSpeed) / newSpeed)
		m.slideVelZ = F32(F32(m.slideVelZ * oldSpeed) / newSpeed)
	end

	mario_actions_moving.update_sliding_angle(m, accel, lossFactor)

	if Mario.mario_floor_is_slope(m) == 0 and F32(m.forwardVel * m.forwardVel) < F32(stopSpeed * stopSpeed) then
		Mario.mario_set_forward_vel(m, 0)
		stopped = IncludePRUltratypesH.TRUE
	end

	return stopped
end

-- from src/game/mario_actions_moving.c:apply_slope_accel L283-332
function mario_actions_moving.apply_slope_accel(m: GroupsTypesHPlus3.MarioState)
	const floor = m.floor :: GroupsTypesHPlus3.Surface
	const steepness = F32(math.sqrt(F32(F32(floor.normal.x * floor.normal.x) + F32(floor.normal.z * floor.normal.z))))
	const floorDYaw = S16(m.floorAngle - m.faceAngle[2])

	if Mario.mario_floor_is_slope(m) ~= 0 then
		local slopeClass = 0

		if m.action ~= IncludeSm64H.ACT_SOFT_BACKWARD_GROUND_KB and m.action ~= IncludeSm64H.ACT_SOFT_FORWARD_GROUND_KB then
			slopeClass = S16(Mario.mario_get_floor_class(m))
		end

		local slopeAccel = 0

		if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
			slopeAccel = F32(5.3)
		elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_SLIPPERY then
			slopeAccel = F32(2.7)
		elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_NOT_SLIPPERY then
			slopeAccel = 0
		else
			slopeAccel = F32(1.7)
		end

		if floorDYaw > -0x4000 and floorDYaw < 0x4000 then
			m.forwardVel = F32(m.forwardVel + F32(slopeAccel * steepness))
		else
			m.forwardVel = F32(m.forwardVel - F32(slopeAccel * steepness))
		end
	end

	m.slideYaw = m.faceAngle[2]

	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))

	m.vel[1] = m.slideVelX
	m.vel[2] = 0
	m.vel[3] = m.slideVelZ

	MarioStep.mario_update_moving_sand(m)
	MarioStep.mario_update_windy_ground(m)
end

-- from src/game/mario_actions_moving.c:apply_landing_accel L334-348
function mario_actions_moving.apply_landing_accel(m: GroupsTypesHPlus3.MarioState, frictionFactor: number): number
	frictionFactor = F32(frictionFactor)
	local stopped = IncludePRUltratypesH.FALSE

	mario_actions_moving.apply_slope_accel(m)

	if Mario.mario_floor_is_slope(m) == 0 then
		m.forwardVel = F32(m.forwardVel * frictionFactor)
		if F32(m.forwardVel * m.forwardVel) < 1 then
			Mario.mario_set_forward_vel(m, 0)
			stopped = IncludePRUltratypesH.TRUE
		end
	end

	return stopped
end

-- from src/game/mario_actions_moving.c:update_shell_speed L350-391
function mario_actions_moving.update_shell_speed(m: GroupsTypesHPlus3.MarioState)
	if m.floorHeight < m.waterLevel then
		m.floorHeight = m.waterLevel
		m.floor = MarioStep.gWaterSurfacePseudoFloor
		const floor = m.floor :: GroupsTypesHPlus3.Surface
		floor.originOffset = m.waterLevel -- Negative origin offset
	end

	local maxTargetSpeed = 0

	if m.floor ~= nil and m.floor.type_ == IncludeSurfaceTerrainsH.SURFACE_SLOW then
		maxTargetSpeed = 48
	else
		maxTargetSpeed = 64
	end

	local targetSpeed = m.intendedMag * 2
	if targetSpeed > maxTargetSpeed then
		targetSpeed = maxTargetSpeed
	end
	if targetSpeed < 24 then
		targetSpeed = 24
	end

	if m.forwardVel <= 0 then
		m.forwardVel = F32(m.forwardVel + F32(1.1))
	elseif m.forwardVel <= targetSpeed then
		m.forwardVel = F32(m.forwardVel + F32(F32(1.1) - F32(m.forwardVel / 58)))
	elseif (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.95) then
		m.forwardVel = F32(m.forwardVel - 1)
	end

	-- No backward speed cap (shell hyperspeed)
	if m.forwardVel > 64 then
		m.forwardVel = 64
	end

	m.faceAngle[2] = S16(m.intendedYaw - SrcEngineMathUtil.approach_s32(S16(m.intendedYaw - m.faceAngle[2]), 0, 0x800, 0x800))

	mario_actions_moving.apply_slope_accel(m)
end

-- from src/game/mario_actions_moving.c:apply_slope_decel L393-418
function mario_actions_moving.apply_slope_decel(m: GroupsTypesHPlus3.MarioState, decelCoef: number): number
	decelCoef = F32(decelCoef)
	local stopped = IncludePRUltratypesH.FALSE
	const slopeClass = Mario.mario_get_floor_class(m)
	local decel = 0

	if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
		decel = F32(decelCoef * F32(0.2))
	elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_SLIPPERY then
		decel = F32(decelCoef * F32(0.7))
	elseif slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_NOT_SLIPPERY then
		decel = F32(decelCoef * 3)
	else
		decel = decelCoef * 2
	end

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0, decel, decel)
	if m.forwardVel == 0 then
		stopped = IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.apply_slope_accel(m)

	return stopped
end

-- from src/game/mario_actions_moving.c:update_decelerating_speed L420-432
function mario_actions_moving.update_decelerating_speed(m: GroupsTypesHPlus3.MarioState): number
	local stopped = IncludePRUltratypesH.FALSE

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0, 1, 1)
	if m.forwardVel == 0 then
		stopped = IncludePRUltratypesH.TRUE
	end

	Mario.mario_set_forward_vel(m, m.forwardVel)
	MarioStep.mario_update_moving_sand(m)
	MarioStep.mario_update_windy_ground(m)

	return stopped
end

-- from src/game/mario_actions_moving.c:update_walking_speed L434-465
function mario_actions_moving.update_walking_speed(m: GroupsTypesHPlus3.MarioState)
	local maxTargetSpeed = 0

	if m.floor ~= nil and m.floor.type_ == IncludeSurfaceTerrainsH.SURFACE_SLOW then
		maxTargetSpeed = 24
	else
		maxTargetSpeed = 32
	end

	local targetSpeed = if m.intendedMag < maxTargetSpeed then m.intendedMag else maxTargetSpeed

	if m.quicksandDepth > 10 then
		targetSpeed = F32(targetSpeed * (6.25 / m.quicksandDepth))
	end

	if m.forwardVel <= 0 then
		m.forwardVel = F32(m.forwardVel + F32(1.1))
	elseif m.forwardVel <= targetSpeed then
		m.forwardVel = F32(m.forwardVel + F32(F32(1.1) - F32(m.forwardVel / 43)))
	elseif (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.95) then
		m.forwardVel = F32(m.forwardVel - 1)
	end

	if m.forwardVel > 48 then
		m.forwardVel = 48
	end

	m.faceAngle[2] = S16(m.intendedYaw - SrcEngineMathUtil.approach_s32(S16(m.intendedYaw - m.faceAngle[2]), 0, 0x800, 0x800))
	mario_actions_moving.apply_slope_accel(m)
end

-- from src/game/mario_actions_moving.c:should_begin_sliding L467-478
function mario_actions_moving.should_begin_sliding(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		const slideLevel = bit32.band((m.area :: GroupsTypesHPlus3.Area).terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SLIDE
		const movingBackward = m.forwardVel <= -1

		if slideLevel or movingBackward or Mario.mario_facing_downhill(m, IncludePRUltratypesH.FALSE) ~= 0 then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:analog_stick_held_back L480-483
function mario_actions_moving.analog_stick_held_back(m: GroupsTypesHPlus3.MarioState): number
	const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])

	return if intendedDYaw < -0x471C or intendedDYaw > 0x471C then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:check_ground_dive_or_punch L485-499
function mario_actions_moving.check_ground_dive_or_punch(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		if m.forwardVel >= 29 and (m.controller :: GroupsTypesHPlus3.Controller).stickMag > 48 then
			m.vel[2] = 20
			return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 1)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_MOVE_PUNCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:begin_braking_action L501-514
function mario_actions_moving.begin_braking_action(m: GroupsTypesHPlus3.MarioState): number
	Interaction.mario_drop_held_object(m)

	if m.actionState == 1 then
		m.faceAngle[2] = S16(m.actionArg)
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STANDING_AGAINST_WALL, 0)
	end

	if m.forwardVel >= 16 and (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.17364818) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BRAKING, 0)
	end

	return Mario.set_mario_action(m, IncludeSm64H.ACT_DECELERATING, 0)
end

-- from src/game/mario_actions_moving.c:anim_and_audio_for_walk L516-605
function mario_actions_moving.anim_and_audio_for_walk(m: GroupsTypesHPlus3.MarioState)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	local val14 = 0
	local val0C = IncludePRUltratypesH.TRUE
	local targetPitch = 0
	local val04 = if m.intendedMag > m.forwardVel then m.intendedMag else m.forwardVel

	if val04 < 4 then
		val04 = 4
	end

	if m.quicksandDepth > 50 then
		val14 = TruncS32(val04 / 4 * 0x10000)
		Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_MOVE_IN_QUICKSAND, val14)
		mario_actions_moving.play_step_sound(m, 19, 93)
		m.actionTimer = 0
	else
		while val0C ~= 0 do
			if m.actionTimer == 0 then
				if val04 > 8 then
					m.actionTimer = 2
				else
					-- (Speed Crash) If Mario's speed is more than 2^17.
					val14 = TruncS32(val04 / 4 * 0x10000)
					if val14 < 0x1000 then
						val14 = 0x1000
					end
					Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_TIPTOE, val14)
					mario_actions_moving.play_step_sound(m, 7, 22)
					if Mario.is_anim_past_frame(m, 23) ~= 0 then
						m.actionTimer = 2
					end

					val0C = IncludePRUltratypesH.FALSE
				end
			elseif m.actionTimer == 1 then
				if val04 > 8 then
					m.actionTimer = 2
				else
					-- (Speed Crash) If Mario's speed is more than 2^17.
					val14 = TruncS32(val04 * 0x10000)
					if val14 < 0x1000 then
						val14 = 0x1000
					end
					Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TIPTOE, val14)
					mario_actions_moving.play_step_sound(m, 14, 72)

					val0C = IncludePRUltratypesH.FALSE
				end
			elseif m.actionTimer == 2 then
				if val04 < 5 then
					m.actionTimer = 1
				elseif val04 > 22 then
					m.actionTimer = 3
				else
					-- (Speed Crash) If Mario's speed is more than 2^17.
					val14 = TruncS32(val04 / 4 * 0x10000)
					Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING, val14)
					mario_actions_moving.play_step_sound(m, 10, 49)

					val0C = IncludePRUltratypesH.FALSE
				end
			elseif m.actionTimer == 3 then
				if val04 < 18 then
					m.actionTimer = 2
				else
					-- (Speed Crash) If Mario's speed is more than 2^17.
					val14 = TruncS32(val04 / 4 * 0x10000)
					Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RUNNING, val14)
					mario_actions_moving.play_step_sound(m, 9, 45)
					targetPitch = mario_actions_moving.tilt_body_running(m)

					val0C = IncludePRUltratypesH.FALSE
				end
			end
		end
	end

	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioWalkingPitch, S16(SrcEngineMathUtil.approach_s32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioWalkingPitch), targetPitch, 0x800, 0x800)))
	marioObj.header.gfx.angle[1] = S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioWalkingPitch))
end

-- from src/game/mario_actions_moving.c:anim_and_audio_for_hold_walk L607-662
function mario_actions_moving.anim_and_audio_for_hold_walk(m: GroupsTypesHPlus3.MarioState)
	local val08 = IncludePRUltratypesH.TRUE
	local val0C = 0
	local val04 = if m.intendedMag > m.forwardVel then m.intendedMag else m.forwardVel

	if val04 < 2 then
		val04 = 2
	end

	while val08 ~= 0 do
		if m.actionTimer == 0 then
			if val04 > 6 then
				m.actionTimer = 1
			else
				-- (Speed Crash) Crashes if Mario's speed exceeds or equals 2^15.
				val0C = TruncS32(val04 * 0x10000)
				Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLOW_WALK_WITH_LIGHT_OBJ, val0C)
				mario_actions_moving.play_step_sound(m, 12, 62)

				val08 = IncludePRUltratypesH.FALSE
			end
		elseif m.actionTimer == 1 then
			if val04 < 3 then
				m.actionTimer = 0
			elseif val04 > 11 then
				m.actionTimer = 2
			else
				-- (Speed Crash) Crashes if Mario's speed exceeds or equals 2^15.
				val0C = TruncS32(val04 * 0x10000)
				Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALK_WITH_LIGHT_OBJ, val0C)
				mario_actions_moving.play_step_sound(m, 12, 62)

				val08 = IncludePRUltratypesH.FALSE
			end
		elseif m.actionTimer == 2 then
			if val04 < 8 then
				m.actionTimer = 1
			else
				-- (Speed Crash) Crashes if Mario's speed exceeds or equals 2^16.
				val0C = TruncS32(val04 / 2 * 0x10000)
				Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RUN_WITH_LIGHT_OBJ, val0C)
				mario_actions_moving.play_step_sound(m, 10, 49)

				val08 = IncludePRUltratypesH.FALSE
			end
		end
	end
end

-- from src/game/mario_actions_moving.c:anim_and_audio_for_heavy_walk L664-668
function mario_actions_moving.anim_and_audio_for_heavy_walk(m: GroupsTypesHPlus3.MarioState)
	const val04 = TruncS32(m.intendedMag * 0x10000)
	Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALK_WITH_HEAVY_OBJ, val04)
	mario_actions_moving.play_step_sound(m, 26, 79)
end

-- from src/game/mario_actions_moving.c:push_or_sidle_wall L670-709
function mario_actions_moving.push_or_sidle_wall(m: GroupsTypesHPlus3.MarioState, startPos: { number })
	const dx = F32(m.pos[1] - startPos[1])
	const dz = F32(m.pos[3] - startPos[3])
	const movedDistance = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))
	-- (Speed Crash) If a wall is after moving 16384 distance, this crashes.
	const val04 = TruncS32(movedDistance * 2 * 0x10000)

	if m.forwardVel > 6 then
		Mario.mario_set_forward_vel(m, 6)
	end

	local wallAngle = 0
	local dWallAngle = 0

	if m.wall ~= nil then
		const wall = m.wall :: GroupsTypesHPlus3.Surface
		wallAngle = SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x)
		dWallAngle = S16(wallAngle - m.faceAngle[2])
	end

	if m.wall == nil or dWallAngle <= -0x71C8 or dWallAngle >= 0x71C8 then
		m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_UNKNOWN_31)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PUSHING)
		mario_actions_moving.play_step_sound(m, 6, 18)
	else
		if dWallAngle < 0 then
			Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SIDESTEP_RIGHT, val04)
		else
			Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SIDESTEP_LEFT, val04)
		end

		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
		if marioObj.header.gfx.animInfo.animFrame < 20 then
			Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, marioObj.header.gfx.cameraToObject)
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
		end

		m.actionState = 1
		m.actionArg = wallAngle + 0x8000
		marioObj.header.gfx.angle[2] = S16(wallAngle + 0x8000)
		marioObj.header.gfx.angle[3] = Mario.find_floor_slope(m, 0x4000)
	end
end

-- from src/game/mario_actions_moving.c:tilt_body_walking L711-743
function mario_actions_moving.tilt_body_walking(m: GroupsTypesHPlus3.MarioState, startYaw: number)
	startYaw = S16(TruncS32(startYaw))
	const val0C = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const animID = marioObj.header.gfx.animInfo.animID

	if animID == IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING or animID == IncludeMarioAnimationIdsH.MARIO_ANIM_RUNNING then
		const dYaw = S16(m.faceAngle[2] - startYaw)

		-- (Speed Crash) These casts can cause a crash if (dYaw * forwardVel / 12) or
		-- (forwardVel * 170) exceed or equal 2^31.
		local val02 = S16(-S16(TruncS32(F32(F32(dYaw * m.forwardVel) / 12))))
		local val00 = S16(TruncS32(F32(m.forwardVel * 170)))

		if val02 > 0x1555 then
			val02 = 0x1555
		end
		if val02 < -0x1555 then
			val02 = -0x1555
		end

		if val00 > 0x1555 then
			val00 = 0x1555
		end
		if val00 < 0 then
			val00 = 0
		end

		val0C.torsoAngle[3] = S16(SrcEngineMathUtil.approach_s32(val0C.torsoAngle[3], val02, 0x400, 0x400))
		val0C.torsoAngle[1] = S16(SrcEngineMathUtil.approach_s32(val0C.torsoAngle[1], val00, 0x400, 0x400))
	else
		val0C.torsoAngle[3] = 0
		val0C.torsoAngle[1] = 0
	end
end

-- from src/game/mario_actions_moving.c:tilt_body_ground_shell L745-775
function mario_actions_moving.tilt_body_ground_shell(m: GroupsTypesHPlus3.MarioState, startYaw: number)
	startYaw = S16(TruncS32(startYaw))
	const val0C = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const dYaw = S16(m.faceAngle[2] - startYaw)

	-- (Speed Crash) These casts can cause a crash if (dYaw * forwardVel / 12) or
	-- (forwardVel * 170) exceed or equal 2^31. Harder (if not impossible to do)
	-- while on a Koopa Shell making this less of an issue.
	local val04 = S16(-S16(TruncS32(F32(F32(dYaw * m.forwardVel) / 12))))
	local val02 = S16(TruncS32(F32(m.forwardVel * 170)))

	if val04 > 0x1800 then
		val04 = 0x1800
	end
	if val04 < -0x1800 then
		val04 = -0x1800
	end

	if val02 > 0x1000 then
		val02 = 0x1000
	end
	if val02 < 0 then
		val02 = 0
	end

	val0C.torsoAngle[3] = S16(SrcEngineMathUtil.approach_s32(val0C.torsoAngle[3], val04, 0x200, 0x200))
	val0C.torsoAngle[1] = S16(SrcEngineMathUtil.approach_s32(val0C.torsoAngle[1], val02, 0x200, 0x200))
	val0C.headAngle[3] = S16(-val0C.torsoAngle[3])

	marioObj.header.gfx.angle[3] = val0C.torsoAngle[3]
	marioObj.header.gfx.pos[2] = F32(marioObj.header.gfx.pos[2] + 45)
end

-- from src/game/mario_actions_moving.c:act_walking L777-838
function mario_actions_moving.act_walking(m: GroupsTypesHPlus3.MarioState): number
	const startYaw = m.faceAngle[2]

	Interaction.mario_drop_held_object(m)

	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return mario_actions_moving.begin_braking_action(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jump_from_landing(m)
	end

	if mario_actions_moving.check_ground_dive_or_punch(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return mario_actions_moving.begin_braking_action(m)
	end

	if mario_actions_moving.analog_stick_held_back(m) ~= 0 and m.forwardVel >= 16 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_TURNING_AROUND, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_CROUCH_SLIDE, 0)
	end

	m.actionState = 0

	SrcEngineMathUtil.vec3f_copy(StartPos, m.pos)
	mario_actions_moving.update_walking_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		mario_actions_moving.anim_and_audio_for_walk(m)
		if F32(m.intendedMag - m.forwardVel) > 16 then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
		end
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		mario_actions_moving.push_or_sidle_wall(m, StartPos)
		m.actionTimer = 0
	end

	mario_actions_moving.check_ledge_climb_down(m)
	mario_actions_moving.tilt_body_walking(m, startYaw)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_move_punching L840-873
function mario_actions_moving.act_move_punching(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if m.actionState == 0 and bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_JUMP_KICK, 0)
	end

	m.actionState = 1

	MarioActionsObject.mario_update_punch_sequence(m)

	if m.forwardVel >= 0 then
		mario_actions_moving.apply_slope_decel(m, 0.5)
	else
		m.forwardVel = F32(m.forwardVel + 8)
		if m.forwardVel >= 0 then
			m.forwardVel = 0
		end
		mario_actions_moving.apply_slope_accel(m)
	end

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hold_walking L875-927
function mario_actions_moving.act_hold_walking(m: GroupsTypesHPlus3.MarioState): number
	if Memory.segmented_to_virtual(BehaviorIds.bhvJumpingBox) == (m.heldObj :: GroupsTypesHPlus3.Object).behavior then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_CRAZY_BOX_BOUNCE, 0)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_HOLD_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_DECELERATING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_CROUCH_SLIDE, 0)
	end

	m.intendedMag = F32(m.intendedMag * F32(0.4))

	mario_actions_moving.update_walking_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if m.forwardVel > 16 then
			Mario.mario_set_forward_vel(m, 16)
		end
	end

	mario_actions_moving.anim_and_audio_for_hold_walk(m)

	if F32(F32(F32(0.4) * m.intendedMag) - m.forwardVel) > 10 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hold_heavy_walking L929-960
function mario_actions_moving.act_hold_heavy_walking(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HEAVY_THROW, 0)
	end

	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_HEAVY_IDLE, 0)
	end

	m.intendedMag = F32(m.intendedMag * F32(0.1))

	mario_actions_moving.update_walking_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if m.forwardVel > 10 then
			Mario.mario_set_forward_vel(m, 10)
		end
	end

	mario_actions_moving.anim_and_audio_for_heavy_walk(m)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_turning_around L962-1011
function mario_actions_moving.act_turning_around(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_SIDE_FLIP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BRAKING, 0)
	end

	if mario_actions_moving.analog_stick_held_back(m) == 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if mario_actions_moving.apply_slope_decel(m, 2) ~= 0 then
		return mario_actions_moving.begin_walking_action(m, 8, IncludeSm64H.ACT_FINISH_TURNING_AROUND, 0)
	end

	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

	Mario.adjust_sound_for_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	if m.forwardVel >= 18 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TURNING_PART1)
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TURNING_PART2)
		if Mario.is_anim_at_end(m) ~= 0 then
			if m.forwardVel > 0 then
				mario_actions_moving.begin_walking_action(m, -m.forwardVel, IncludeSm64H.ACT_WALKING, 0)
			else
				mario_actions_moving.begin_walking_action(m, 8, IncludeSm64H.ACT_WALKING, 0)
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_finish_turning_around L1013-1035
function mario_actions_moving.act_finish_turning_around(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_SIDE_FLIP, 0)
	end

	mario_actions_moving.update_walking_speed(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TURNING_PART2)

	if MarioStep.perform_ground_step(m) == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_braking L1037-1070
function mario_actions_moving.act_braking(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) and bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	if mario_actions_moving.apply_slope_decel(m, 2) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BRAKING_STOP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_MOVE_PUNCHING, 0)
	end

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		mario_actions_moving.slide_bonk(m, IncludeSm64H.ACT_BACKWARD_GROUND_KB, IncludeSm64H.ACT_BRAKING_STOP)
	end

	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	Mario.adjust_sound_for_speed(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SKID_ON_GROUND)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_decelerating L1072-1132
function mario_actions_moving.act_decelerating(m: GroupsTypesHPlus3.MarioState): number
	const slopeClass = S16(Mario.mario_get_floor_class(m))

	if not bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		if mario_actions_moving.should_begin_sliding(m) ~= 0 then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			return Mario.set_jump_from_landing(m)
		end

		if mario_actions_moving.check_ground_dive_or_punch(m) ~= 0 then
			return IncludePRUltratypesH.TRUE
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_CROUCH_SLIDE, 0)
		end
	end

	if mario_actions_moving.update_decelerating_speed(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
			MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
		else
			Mario.mario_set_forward_vel(m, 0)
		end
	end

	if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAD_LEFT)
		Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Mario.adjust_sound_for_speed(m)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	else
		-- (Speed Crash) Crashes if speed exceeds 2^17.
		local val0C = TruncS32(m.forwardVel / 4 * 0x10000)
		if val0C < 0x1000 then
			val0C = 0x1000
		end

		Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING, val0C)
		mario_actions_moving.play_step_sound(m, 10, 49)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hold_decelerating L1134-1198
function mario_actions_moving.act_hold_decelerating(m: GroupsTypesHPlus3.MarioState): number
	const slopeClass = S16(Mario.mario_get_floor_class(m))
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_HOLD_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_CROUCH_SLIDE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WALKING, 0)
	end

	if mario_actions_moving.update_decelerating_speed(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_IDLE, 0)
	end

	m.intendedMag = F32(m.intendedMag * F32(0.4))

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
			MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
		else
			Mario.mario_set_forward_vel(m, 0)
		end
	end

	if slopeClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
		Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Mario.adjust_sound_for_speed(m)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	else
		-- (Speed Crash) This crashes if Mario has more speed than 2^15 speed.
		local val0C = TruncS32(m.forwardVel * 0x10000)
		if val0C < 0x1000 then
			val0C = 0x1000
		end

		Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALK_WITH_LIGHT_OBJ, val0C)
		mario_actions_moving.play_step_sound(m, 12, 62)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_riding_shell_ground L1200-1245
function mario_actions_moving.act_riding_shell_ground(m: GroupsTypesHPlus3.MarioState): number
	const startYaw = m.faceAngle[2]

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_RIDING_SHELL_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		Interaction.mario_stop_riding_object(m)
		if m.forwardVel < 24 then
			Mario.mario_set_forward_vel(m, 24)
		end
		return Mario.set_mario_action(m, IncludeSm64H.ACT_CROUCH_SLIDE, 0)
	end

	mario_actions_moving.update_shell_speed(m)
	Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_START_RIDING_SHELL else IncludeMarioAnimationIdsH.MARIO_ANIM_RIDING_SHELL)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_RIDING_SHELL_FALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		Interaction.mario_stop_riding_object(m)
		Audio.play_sound(if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_BONK else IncludeSoundsH.SOUND_ACTION_BONK, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_GROUND_KB, 0)
	end

	mario_actions_moving.tilt_body_ground_shell(m, startYaw)

	if (m.floor :: GroupsTypesHPlus3.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
		Audio.play_sound(IncludeSoundsH.SOUND_MOVING_RIDING_SHELL_LAVA, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	else
		Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_RIDING_SHELL + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	Mario.adjust_sound_for_speed(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_crawling L1247-1298
function mario_actions_moving.act_crawling(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CRAWLING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_JUMP, 0)
	end

	if mario_actions_moving.check_ground_dive_or_punch(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CRAWLING, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CRAWLING, 0)
	end

	m.intendedMag = F32(m.intendedMag * F32(0.1))

	mario_actions_moving.update_walking_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if m.forwardVel > 10 then
			Mario.mario_set_forward_vel(m, 10)
		end
		-- C has no break here: falls through into GROUND_STEP_NONE
		mario_actions_moving.align_with_floor(m)
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		mario_actions_moving.align_with_floor(m)
	end

	const val04 = TruncS32(m.intendedMag * 2 * 0x10000)
	Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CRAWLING, val04)
	mario_actions_moving.play_step_sound(m, 26, 79)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_burning_ground L1300-1351
function mario_actions_moving.act_burning_ground(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BURNING_JUMP, 0)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer, S32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer) + 2))
	if buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer) > 160 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if F32(m.waterLevel - m.floorHeight) > 50 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_FLAME_OUT, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if m.forwardVel < 8 then
		m.forwardVel = 8
	end
	if m.forwardVel > 48 then
		m.forwardVel = 48
	end

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 32, 4, 1)

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.faceAngle[2] = S16(m.intendedYaw - SrcEngineMathUtil.approach_s32(S16(m.intendedYaw - m.faceAngle[2]), 0, 0x600, 0x600))
	end

	mario_actions_moving.apply_slope_accel(m)

	if MarioStep.perform_ground_step(m) == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_BURNING_FALL, 0)
	end

	Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RUNNING, TruncS32(m.forwardVel / 2 * 0x10000))
	mario_actions_moving.play_step_sound(m, 9, 45)

	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_FIRE)
	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_LAVA_BURN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

	m.health = S16(m.health - 10)
	if m.health < 0x100 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_STANDING_DEATH, 0)
	end

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_DEAD

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:tilt_body_butt_slide L1353-1357
function mario_actions_moving.tilt_body_butt_slide(m: GroupsTypesHPlus3.MarioState)
	const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	marioBodyState.torsoAngle[1] = S16(TruncS32(F32(F32(F32(5461.3335) * m.intendedMag) / 32 * SrcEngineMathUtilH.coss(intendedDYaw))))
	marioBodyState.torsoAngle[3] = S16(TruncS32(-F32(F32(F32(5461.3335) * m.intendedMag) / 32 * SrcEngineMathUtilH.sins(intendedDYaw))))
end

-- from src/game/mario_actions_moving.c:common_slide_action L1359-1412
function mario_actions_moving.common_slide_action(m: GroupsTypesHPlus3.MarioState, endAction: number, airAction: number, animation: number)
	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	Mario.adjust_sound_for_speed(m)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, airAction, 0)
		if m.forwardVel < -50 or 50 < m.forwardVel then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HOOHOO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	elseif stepResult == IncludeSm64H.GROUND_STEP_NONE then
		Mario.set_mario_animation(m, animation)
		mario_actions_moving.align_with_floor(m)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		if Mario.mario_floor_is_slippery(m) == 0 then
			if m.forwardVel > 16 then
				m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
			end

			mario_actions_moving.slide_bonk(m, IncludeSm64H.ACT_GROUND_BONK, endAction)
		elseif m.wall ~= nil then
			const wall = m.wall :: GroupsTypesHPlus3.Surface
			const wallAngle = SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x)
			local slideSpeed = F32(math.sqrt(F32(F32(m.slideVelX * m.slideVelX) + F32(m.slideVelZ * m.slideVelZ))))

			slideSpeed = F32(slideSpeed * 0.9)
			if slideSpeed < 4 then
				slideSpeed = 4
			end

			m.slideYaw = S16(wallAngle - S16(m.slideYaw - wallAngle) + 0x8000)

			m.slideVelX = F32(slideSpeed * SrcEngineMathUtilH.sins(m.slideYaw))
			m.vel[1] = m.slideVelX
			m.slideVelZ = F32(slideSpeed * SrcEngineMathUtilH.coss(m.slideYaw))
			m.vel[3] = m.slideVelZ
		end

		mario_actions_moving.align_with_floor(m)
	end
end

-- from src/game/mario_actions_moving.c:common_slide_action_with_jump L1414-1430
function mario_actions_moving.common_slide_action_with_jump(m: GroupsTypesHPlus3.MarioState, stopAction: number, jumpAction: number, airAction: number, animation: number): number
	if m.actionTimer == 5 then
		if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			return Mario.set_jumping_action(m, jumpAction, 0)
		end
	else
		m.actionTimer = U16(m.actionTimer + 1)
	end

	if mario_actions_moving.update_sliding(m, 4) ~= 0 then
		return Mario.set_mario_action(m, stopAction, 0)
	end

	mario_actions_moving.common_slide_action(m, stopAction, airAction, animation)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_butt_slide L1432-1437
function mario_actions_moving.act_butt_slide(m: GroupsTypesHPlus3.MarioState): number
	const cancel = mario_actions_moving.common_slide_action_with_jump(m, IncludeSm64H.ACT_BUTT_SLIDE_STOP, IncludeSm64H.ACT_JUMP, IncludeSm64H.ACT_BUTT_SLIDE_AIR, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE)
	mario_actions_moving.tilt_body_butt_slide(m)

	return cancel
end

-- from src/game/mario_actions_moving.c:act_hold_butt_slide L1439-1450
function mario_actions_moving.act_hold_butt_slide(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_BUTT_SLIDE, 0)
	end

	const cancel = mario_actions_moving.common_slide_action_with_jump(m, IncludeSm64H.ACT_HOLD_BUTT_SLIDE_STOP, IncludeSm64H.ACT_HOLD_JUMP, IncludeSm64H.ACT_HOLD_BUTT_SLIDE_AIR, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDING_ON_BOTTOM_WITH_LIGHT_OBJ)
	mario_actions_moving.tilt_body_butt_slide(m)

	return cancel
end

-- from src/game/mario_actions_moving.c:act_crouch_slide L1452-1487
function mario_actions_moving.act_crouch_slide(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BUTT_SLIDE, 0)
	end

	if m.actionTimer < 30 then
		m.actionTimer = U16(m.actionTimer + 1)
		if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			if m.forwardVel > 10 then
				return Mario.set_jumping_action(m, IncludeSm64H.ACT_LONG_JUMP, 0)
			end
		end
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		if m.forwardVel >= 10 then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_SLIDE_KICK, 0)
		else
			return Mario.set_mario_action(m, IncludeSm64H.ACT_MOVE_PUNCHING, 0x0009)
		end
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BRAKING, 0)
	end

	const cancel = mario_actions_moving.common_slide_action_with_jump(m, IncludeSm64H.ACT_CROUCHING, IncludeSm64H.ACT_JUMP, IncludeSm64H.ACT_FREEFALL, IncludeMarioAnimationIdsH.MARIO_ANIM_START_CROUCHING)
	return cancel
end

-- from src/game/mario_actions_moving.c:act_slide_kick_slide L1489-1518
function mario_actions_moving.act_slide_kick_slide(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_FORWARD_ROLLOUT, 0)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE_KICK)
	if Mario.is_anim_at_end(m) ~= 0 and m.forwardVel < 1 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SLIDE_KICK_SLIDE_STOP, 0)
	end

	mario_actions_moving.update_sliding(m, 1)

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 2)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_GROUND_KB, 0)
	end

	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:stomach_slide_action L1520-1539
function mario_actions_moving.stomach_slide_action(m: GroupsTypesHPlus3.MarioState, stopAction: number, airAction: number, animation: number): number
	if m.actionTimer == 5 then
		if not bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) and bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_B_PRESSED)) then
			return Mario.drop_and_set_mario_action(m, if m.forwardVel >= 0 then IncludeSm64H.ACT_FORWARD_ROLLOUT else IncludeSm64H.ACT_BACKWARD_ROLLOUT, 0)
		end
	else
		m.actionTimer = U16(m.actionTimer + 1)
	end

	if mario_actions_moving.update_sliding(m, 4) ~= 0 then
		return Mario.set_mario_action(m, stopAction, 0)
	end

	mario_actions_moving.common_slide_action(m, stopAction, airAction, animation)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_stomach_slide L1541-1544
function mario_actions_moving.act_stomach_slide(m: GroupsTypesHPlus3.MarioState): number
	const cancel = mario_actions_moving.stomach_slide_action(m, IncludeSm64H.ACT_STOMACH_SLIDE_STOP, IncludeSm64H.ACT_FREEFALL, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE_DIVE)
	return cancel
end

-- from src/game/mario_actions_moving.c:act_hold_stomach_slide L1546-1555
function mario_actions_moving.act_hold_stomach_slide(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_STOMACH_SLIDE, 0)
	end

	const cancel = mario_actions_moving.stomach_slide_action(m, IncludeSm64H.ACT_DIVE_PICKING_UP, IncludeSm64H.ACT_HOLD_FREEFALL, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE_DIVE)
	return cancel
end

-- from src/game/mario_actions_moving.c:act_dive_slide L1557-1586
function mario_actions_moving.act_dive_slide(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) and bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_B_PRESSED)) then
		return Mario.set_mario_action(m, if m.forwardVel > 0 then IncludeSm64H.ACT_FORWARD_ROLLOUT else IncludeSm64H.ACT_BACKWARD_ROLLOUT, 0)
	end

	Mario.play_mario_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)

	-- Mario is not in the dive slide action for mario_check_object_grab when the slide ends on the pickup frame (C comment kept as behavior)
	if mario_actions_moving.update_sliding(m, 8) ~= 0 and Mario.is_anim_at_end(m) ~= 0 then
		Mario.mario_set_forward_vel(m, 0)
		Mario.set_mario_action(m, IncludeSm64H.ACT_STOMACH_SLIDE_STOP, 0)
	end

	if Interaction.mario_check_object_grab(m) ~= 0 then
		Interaction.mario_grab_used_object(m)
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
		marioBodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_LIGHT_OBJ
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_slide_action(m, IncludeSm64H.ACT_STOMACH_SLIDE_STOP, IncludeSm64H.ACT_FREEFALL, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:common_ground_knockback_action L1588-1639
function mario_actions_moving.common_ground_knockback_action(m: GroupsTypesHPlus3.MarioState, animation: number, arg2: number, arg3: number, arg4: number): number
	if arg3 ~= 0 then
		Mario.play_mario_heavy_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	if arg4 > 0 then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_ATTACKED, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	else
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_OOOF2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	if m.forwardVel > 32 then
		m.forwardVel = 32
	end
	if m.forwardVel < -32 then
		m.forwardVel = -32
	end

	const animFrame = Mario.set_mario_animation(m, animation)
	if animFrame < arg2 then
		mario_actions_moving.apply_landing_accel(m, F32(0.9))
	elseif m.forwardVel >= 0 then
		Mario.mario_set_forward_vel(m, F32(0.1))
	else
		Mario.mario_set_forward_vel(m, -F32(0.1))
	end

	if MarioStep.perform_ground_step(m) == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		if m.forwardVel >= 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_FORWARD_AIR_KB, arg4)
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, arg4)
		end
	elseif Mario.is_anim_at_end(m) ~= 0 then
		if m.health < 0x100 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_STANDING_DEATH, 0)
		else
			if arg4 > 0 then
				m.invincTimer = 30
			end
			Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
		end
	end

	return animFrame
end

-- from src/game/mario_actions_moving.c:act_hard_backward_ground_kb L1641-1659
function mario_actions_moving.act_hard_backward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	const animFrame = mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_OVER_BACKWARDS, 43, IncludePRUltratypesH.TRUE, m.actionArg)
	if animFrame == 43 and m.health < 0x100 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DEATH_ON_BACK, 0)
	end

	if animFrame == 54 and m.prevAction == IncludeSm64H.ACT_SPECIAL_DEATH_EXIT then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_MAMA_MIA, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if animFrame == 69 then
		Mario.play_mario_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hard_forward_ground_kb L1661-1669
function mario_actions_moving.act_hard_forward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	const animFrame = mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_ON_STOMACH, 21, IncludePRUltratypesH.TRUE, m.actionArg)
	if animFrame == 23 and m.health < 0x100 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DEATH_ON_STOMACH, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_backward_ground_kb L1671-1674
function mario_actions_moving.act_backward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARD_KB, 22, IncludePRUltratypesH.TRUE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_forward_ground_kb L1676-1679
function mario_actions_moving.act_forward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_KB, 20, IncludePRUltratypesH.TRUE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_soft_backward_ground_kb L1681-1684
function mario_actions_moving.act_soft_backward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SOFT_BACK_KB, 100, IncludePRUltratypesH.FALSE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_soft_forward_ground_kb L1686-1689
function mario_actions_moving.act_soft_forward_ground_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SOFT_FRONT_KB, 100, IncludePRUltratypesH.FALSE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_ground_bonk L1691-1698
function mario_actions_moving.act_ground_bonk(m: GroupsTypesHPlus3.MarioState): number
	const animFrame = mario_actions_moving.common_ground_knockback_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GROUND_BONK, 32, IncludePRUltratypesH.TRUE, m.actionArg)
	if animFrame == 32 then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_death_exit_land L1700-1720
function mario_actions_moving.act_death_exit_land(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_moving.apply_landing_accel(m, F32(0.9))
	Mario.play_mario_heavy_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)

	const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_OVER_BACKWARDS)

	if animFrame == 54 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_MAMA_MIA, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end
	if animFrame == 68 then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:common_landing_action L1722-1756
function mario_actions_moving.common_landing_action(m: GroupsTypesHPlus3.MarioState, animation: number, airAction: number): number
	animation = S16(TruncS32(animation))
	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		mario_actions_moving.apply_landing_accel(m, F32(0.98))
	elseif m.forwardVel >= 16 then
		mario_actions_moving.apply_slope_decel(m, 2)
	else
		m.vel[2] = 0
	end

	const stepResult = MarioStep.perform_ground_step(m)
	if stepResult == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, airAction, 0)
	elseif stepResult == IncludeSm64H.GROUND_STEP_HIT_WALL then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PUSHING)
	end

	if m.forwardVel > 16 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	Mario.set_mario_animation(m, animation)
	Mario.play_mario_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)

	const floor = m.floor :: GroupsTypesHPlus3.Surface
	if floor.type_ >= IncludeSurfaceTerrainsH.SURFACE_SHALLOW_QUICKSAND and floor.type_ <= IncludeSurfaceTerrainsH.SURFACE_MOVING_QUICKSAND then
		m.quicksandDepth = F32(m.quicksandDepth + F32(F32((4 - m.actionTimer) * 3.5) - 0.5))
	end

	return stepResult
end

-- from src/game/mario_actions_moving.c:common_landing_cancels L1758-1790
function mario_actions_moving.common_landing_cancels(m: GroupsTypesHPlus3.MarioState, landingAction: LandingAction, setAPressAction: (GroupsTypesHPlus3.MarioState, number, number) -> number): number
	if (m.floor :: GroupsTypesHPlus3.Surface).normal.y < F32(0.2923717) then
		return MarioStep.mario_push_off_steep_floor(m, landingAction.verySteepAction, 0)
	end

	m.doubleJumpTimer = U8(landingAction.unk02)

	if mario_actions_moving.should_begin_sliding(m) ~= 0 then
		return Mario.set_mario_action(m, landingAction.slideAction, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, landingAction.endAction, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)
	if m.actionTimer >= landingAction.numFrames then
		return Mario.set_mario_action(m, landingAction.endAction, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return setAPressAction(m, landingAction.aPressedAction, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, landingAction.offFloorAction, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_jump_land L1792-1799
function mario_actions_moving.act_jump_land(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sJumpLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_freefall_land L1801-1808
function mario_actions_moving.act_freefall_land(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sFreefallLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_side_flip_land L1810-1819
function mario_actions_moving.act_side_flip_land(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sSideFlipLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDEFLIP_LAND, IncludeSm64H.ACT_FREEFALL) ~= IncludeSm64H.GROUND_STEP_HIT_WALL then
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
		marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hold_jump_land L1821-1832
function mario_actions_moving.act_hold_jump_land(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_JUMP_LAND_STOP, 0)
	end

	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sHoldJumpLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_LAND_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_hold_freefall_land L1834-1845
function mario_actions_moving.act_hold_freefall_land(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL_LAND_STOP, 0)
	end

	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sHoldFreefallLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_LAND_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_long_jump_land L1847-1872
function mario_actions_moving.act_long_jump_land(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		m.input = U16(bit32.band(m.input, bit32.bnot(IncludeSm64H.INPUT_A_PRESSED)))
	end

	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sLongJumpLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_UH2_2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	mario_actions_moving.common_landing_action(m, if buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioLongJumpIsSlow) == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCH_FROM_FAST_LONGJUMP else IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCH_FROM_SLOW_LONGJUMP, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_double_jump_land L1874-1880
function mario_actions_moving.act_double_jump_land(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sDoubleJumpLandAction, mario_actions_moving.set_triple_jump_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_DOUBLE_JUMP, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_triple_jump_land L1882-1895
function mario_actions_moving.act_triple_jump_land(m: GroupsTypesHPlus3.MarioState): number
	m.input = U16(bit32.band(m.input, bit32.bnot(IncludeSm64H.INPUT_A_PRESSED)))

	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sTripleJumpLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_HAHA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_LAND, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_backflip_land L1897-1912
function mario_actions_moving.act_backflip_land(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		m.input = U16(bit32.band(m.input, bit32.bnot(IncludeSm64H.INPUT_A_PRESSED)))
	end

	if mario_actions_moving.common_landing_cancels(m, mario_actions_moving.sBackflipLandAction, Mario.set_jumping_action) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_HAHA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	mario_actions_moving.common_landing_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_LAND, IncludeSm64H.ACT_FREEFALL)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:quicksand_jump_land_action L1914-1938
function mario_actions_moving.quicksand_jump_land_action(m: GroupsTypesHPlus3.MarioState, animation1: number, animation2: number, endAction: number, airAction: number): number
	const actionTimerBefore = m.actionTimer
	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimerBefore < 6 then
		m.quicksandDepth = F32(m.quicksandDepth - F32((7 - m.actionTimer) * F32(0.8)))
		if m.quicksandDepth < 1 then
			m.quicksandDepth = F32(1.1)
		end

		Mario.play_mario_jump_sound(m)
		Mario.set_mario_animation(m, animation1)
	else
		if m.actionTimer >= 13 then
			return Mario.set_mario_action(m, endAction, 0)
		end

		Mario.set_mario_animation(m, animation2)
	end

	mario_actions_moving.apply_landing_accel(m, F32(0.95))
	if MarioStep.perform_ground_step(m) == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, airAction, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:act_quicksand_jump_land L1940-1944
function mario_actions_moving.act_quicksand_jump_land(m: GroupsTypesHPlus3.MarioState): number
	const cancel = mario_actions_moving.quicksand_jump_land_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP, IncludeSm64H.ACT_JUMP_LAND_STOP, IncludeSm64H.ACT_FREEFALL)
	return cancel
end

-- from src/game/mario_actions_moving.c:act_hold_quicksand_jump_land L1946-1951
function mario_actions_moving.act_hold_quicksand_jump_land(m: GroupsTypesHPlus3.MarioState): number
	const cancel = mario_actions_moving.quicksand_jump_land_action(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_WITH_LIGHT_OBJ, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_LAND_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_JUMP_LAND_STOP, IncludeSm64H.ACT_HOLD_FREEFALL)
	return cancel
end

-- from src/game/mario_actions_moving.c:check_common_moving_cancels L1953-1973
function mario_actions_moving.check_common_moving_cancels(m: GroupsTypesHPlus3.MarioState): number
	if m.pos[2] < F32(m.waterLevel - 100) then
		return Mario.set_water_plunge_action(m)
	end

	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INVULNERABLE) and bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_SQUISHED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SQUISHED, 0)
	end

	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INVULNERABLE) then
		if m.health < 0x100 then
			return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_STANDING_DEATH, 0)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_moving.c:mario_execute_moving_action L1975-2035
function mario_actions_moving.mario_execute_moving_action(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_moving.check_common_moving_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if MarioStep.mario_update_quicksand(m, 0.25) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	local cancel = IncludePRUltratypesH.FALSE

	if m.action == IncludeSm64H.ACT_WALKING then
		cancel = mario_actions_moving.act_walking(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_WALKING then
		cancel = mario_actions_moving.act_hold_walking(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_HEAVY_WALKING then
		cancel = mario_actions_moving.act_hold_heavy_walking(m)
	elseif m.action == IncludeSm64H.ACT_TURNING_AROUND then
		cancel = mario_actions_moving.act_turning_around(m)
	elseif m.action == IncludeSm64H.ACT_FINISH_TURNING_AROUND then
		cancel = mario_actions_moving.act_finish_turning_around(m)
	elseif m.action == IncludeSm64H.ACT_BRAKING then
		cancel = mario_actions_moving.act_braking(m)
	elseif m.action == IncludeSm64H.ACT_RIDING_SHELL_GROUND then
		cancel = mario_actions_moving.act_riding_shell_ground(m)
	elseif m.action == IncludeSm64H.ACT_CRAWLING then
		cancel = mario_actions_moving.act_crawling(m)
	elseif m.action == IncludeSm64H.ACT_BURNING_GROUND then
		cancel = mario_actions_moving.act_burning_ground(m)
	elseif m.action == IncludeSm64H.ACT_DECELERATING then
		cancel = mario_actions_moving.act_decelerating(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_DECELERATING then
		cancel = mario_actions_moving.act_hold_decelerating(m)
	elseif m.action == IncludeSm64H.ACT_BUTT_SLIDE then
		cancel = mario_actions_moving.act_butt_slide(m)
	elseif m.action == IncludeSm64H.ACT_STOMACH_SLIDE then
		cancel = mario_actions_moving.act_stomach_slide(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_BUTT_SLIDE then
		cancel = mario_actions_moving.act_hold_butt_slide(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_STOMACH_SLIDE then
		cancel = mario_actions_moving.act_hold_stomach_slide(m)
	elseif m.action == IncludeSm64H.ACT_DIVE_SLIDE then
		cancel = mario_actions_moving.act_dive_slide(m)
	elseif m.action == IncludeSm64H.ACT_MOVE_PUNCHING then
		cancel = mario_actions_moving.act_move_punching(m)
	elseif m.action == IncludeSm64H.ACT_CROUCH_SLIDE then
		cancel = mario_actions_moving.act_crouch_slide(m)
	elseif m.action == IncludeSm64H.ACT_SLIDE_KICK_SLIDE then
		cancel = mario_actions_moving.act_slide_kick_slide(m)
	elseif m.action == IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB then
		cancel = mario_actions_moving.act_hard_backward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB then
		cancel = mario_actions_moving.act_hard_forward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_BACKWARD_GROUND_KB then
		cancel = mario_actions_moving.act_backward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_FORWARD_GROUND_KB then
		cancel = mario_actions_moving.act_forward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_SOFT_BACKWARD_GROUND_KB then
		cancel = mario_actions_moving.act_soft_backward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_SOFT_FORWARD_GROUND_KB then
		cancel = mario_actions_moving.act_soft_forward_ground_kb(m)
	elseif m.action == IncludeSm64H.ACT_GROUND_BONK then
		cancel = mario_actions_moving.act_ground_bonk(m)
	elseif m.action == IncludeSm64H.ACT_DEATH_EXIT_LAND then
		cancel = mario_actions_moving.act_death_exit_land(m)
	elseif m.action == IncludeSm64H.ACT_JUMP_LAND then
		cancel = mario_actions_moving.act_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_FREEFALL_LAND then
		cancel = mario_actions_moving.act_freefall_land(m)
	elseif m.action == IncludeSm64H.ACT_DOUBLE_JUMP_LAND then
		cancel = mario_actions_moving.act_double_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_SIDE_FLIP_LAND then
		cancel = mario_actions_moving.act_side_flip_land(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_JUMP_LAND then
		cancel = mario_actions_moving.act_hold_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_FREEFALL_LAND then
		cancel = mario_actions_moving.act_hold_freefall_land(m)
	elseif m.action == IncludeSm64H.ACT_TRIPLE_JUMP_LAND then
		cancel = mario_actions_moving.act_triple_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_BACKFLIP_LAND then
		cancel = mario_actions_moving.act_backflip_land(m)
	elseif m.action == IncludeSm64H.ACT_QUICKSAND_JUMP_LAND then
		cancel = mario_actions_moving.act_quicksand_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_QUICKSAND_JUMP_LAND then
		cancel = mario_actions_moving.act_hold_quicksand_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_LONG_JUMP_LAND then
		cancel = mario_actions_moving.act_long_jump_land(m)
	end

	if cancel == 0 and bit32.btest(m.input, IncludeSm64H.INPUT_IN_WATER) then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_WAVE_TRAIL)
		m.particleFlags = bit32.band(m.particleFlags, bit32.bnot(IncludeSm64H.PARTICLE_DUST))
	end

	return cancel
end

return mario_actions_moving
