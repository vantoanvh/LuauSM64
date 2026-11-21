--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_automatic.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const Area = require("./area")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Mario = require("./mario")
const Memory = require("./memory")
const SrcEngineGraphNode = require("../engine/graph_node")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const IncludeSoundsH = require("../../include/sounds_h")
const MarioStep = require("./mario_step")
const InteractionH = require("./interaction_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/mario_actions_automatic.c:data
const mario_actions_automatic = {
	POLE_NONE = 0,
	POLE_TOUCHED_FLOOR = 1,
	POLE_FELL_OFF = 2,
	HANG_NONE = 0,
	HANG_HIT_CEIL_OR_OOB = 1,
	HANG_LEFT_CEIL = 2,
}

Registry.Register("src__game__mario_actions_automatic", mario_actions_automatic)

const Floor: { GroupsTypesHPlus3.Surface? } = {}
const Ceil: { GroupsTypesHPlus3.Surface? } = {}
const WallX = { 0 }
const WallY = { 0 }
const WallZ = { 0 }
const NextPos = { 0, 0, 0 }

-- from src/game/mario_actions_automatic.c:add_tree_leaf_particles L28-42
function mario_actions_automatic.add_tree_leaf_particles(m: GroupsTypesHPlus3.MarioState)
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object

	if usedObj.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvTree) then
		-- make leaf effect spawn higher on the Shifting Sand Land palm tree
		const leafHeight = if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SSL then 250 else 100

		if F32(m.pos[2] - m.floorHeight) > leafHeight then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_LEAF)
		end
	end
end

-- from src/game/mario_actions_automatic.c:play_climbing_sounds L44-56
function mario_actions_automatic.play_climbing_sounds(m: GroupsTypesHPlus3.MarioState, b: number)
	const isOnTree = (m.usedObj :: GroupsTypesHPlus3.Object).behavior == Memory.segmented_to_virtual(BehaviorIds.bhvTree)
	const cameraToObject = (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject

	if b == 1 then
		if Mario.is_anim_past_frame(m, 1) ~= 0 then
			Audio.play_sound(if isOnTree then IncludeSoundsH.SOUND_ACTION_CLIMB_UP_TREE else IncludeSoundsH.SOUND_ACTION_CLIMB_UP_POLE, cameraToObject)
		end
	else
		Audio.play_sound(if isOnTree then IncludeSoundsH.SOUND_MOVING_SLIDE_DOWN_TREE else IncludeSoundsH.SOUND_MOVING_SLIDE_DOWN_POLE, cameraToObject)
	end
end

-- from src/game/mario_actions_automatic.c:set_pole_position L58-111
function mario_actions_automatic.set_pole_position(m: GroupsTypesHPlus3.MarioState, offsetY: number): number
	offsetY = F32(offsetY)
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const poleTop = F32(usedObj.hitboxHeight - 100)
	local result = mario_actions_automatic.POLE_NONE

	if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos) > poleTop then
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos, poleTop)
	end

	m.pos[1] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX)
	m.pos[3] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ)
	m.pos[2] = F32(F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos)) + offsetY)

	WallX[1] = m.pos[1]
	WallY[1] = m.pos[2]
	WallZ[1] = m.pos[3]

	local collided = SrcEngineSurfaceCollision.f32_find_wall_collision(WallX, WallY, WallZ, 60, 50)

	collided = bit32.bor(collided, SrcEngineSurfaceCollision.f32_find_wall_collision(WallX, WallY, WallZ, 30, 24))

	m.pos[1] = WallX[1]
	m.pos[2] = WallY[1]
	m.pos[3] = WallZ[1]

	const ceilHeight = Mario.vec3f_find_ceil(m.pos, m.pos[2], Ceil)

	if m.pos[2] > F32(ceilHeight - 160) then
		m.pos[2] = F32(ceilHeight - 160)
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos, m.pos[2] - buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY))
	end

	const floorHeight = SrcEngineSurfaceCollision.find_floor(m.pos[1], m.pos[2], m.pos[3], Floor)

	if m.pos[2] < floorHeight then
		m.pos[2] = floorHeight
		Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
		result = mario_actions_automatic.POLE_TOUCHED_FLOOR
	elseif buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos) < -usedObj.hitboxDownOffset then
		m.pos[2] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY) - usedObj.hitboxDownOffset)
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
		result = mario_actions_automatic.POLE_FELL_OFF
	elseif collided ~= 0 then
		if m.pos[2] > F32(floorHeight + 20) then
			m.forwardVel = -2
			Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
			result = mario_actions_automatic.POLE_FELL_OFF
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
			result = mario_actions_automatic.POLE_TOUCHED_FLOOR
		end
	end

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAnglePitch), m.faceAngle[2], buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleRoll))

	return result
end

-- from src/game/mario_actions_automatic.c:act_holding_pole L113-186
function mario_actions_automatic.act_holding_pole(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const controller = m.controller :: GroupsTypesHPlus3.Controller

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) or m.health < 0x100 then
		mario_actions_automatic.add_tree_leaf_particles(m)
		m.forwardVel = -2
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		mario_actions_automatic.add_tree_leaf_particles(m)
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALL_KICK_AIR, 0)
	end

	if controller.stickY > 16 then
		const poleTop = F32(usedObj.hitboxHeight - 100)
		const poleBehavior = Memory.virtual_to_segmented(0x13, usedObj.behavior :: number)

		if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos) < F32(poleTop - F32(0.4)) then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_CLIMBING_POLE, 0)
		end

		if poleBehavior ~= BehaviorIds.bhvGiantPole and controller.stickY > 50 then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_TOP_OF_POLE_TRANSITION, 0)
		end
	end

	if controller.stickY < -16 then
		local poleYawVel = S32(TruncS32(F32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel) - controller.stickY * 2)))

		if poleYawVel > 0x1000 then
			poleYawVel = 0x1000
		end

		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, poleYawVel)
		m.faceAngle[2] = S16(m.faceAngle[2] + poleYawVel)
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos, buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos) - TruncS32(poleYawVel / 0x100))

		if usedObj.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvTree) then
			-- The Shifting Sand Land palm tree check is done climbing up in
			-- add_tree_leaf_particles, but not here, when climbing down.
			if F32(m.pos[2] - m.floorHeight) > 100 then
				m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_LEAF)
			end
		end

		mario_actions_automatic.play_climbing_sounds(m, 2)
		Audio.set_sound_moving_speed(IncludeSoundsH.SOUND_BANK_MOVING, TruncS32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel) / 0x100) * 2)
	else
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, 0)
		m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] - controller.stickX * 16)))
	end

	if mario_actions_automatic.set_pole_position(m, 0) == mario_actions_automatic.POLE_NONE then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_ON_POLE)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_climbing_pole L188-223
function mario_actions_automatic.act_climbing_pole(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const controller = m.controller :: GroupsTypesHPlus3.Controller
	const cameraAngle = ((m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera).yaw

	if m.health < 0x100 then
		mario_actions_automatic.add_tree_leaf_particles(m)
		m.forwardVel = -2
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		mario_actions_automatic.add_tree_leaf_particles(m)
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALL_KICK_AIR, 0)
	end

	if controller.stickY < 8 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLDING_POLE, 0)
	end

	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos, buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos) + controller.stickY / 8)
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, 0)
	m.faceAngle[2] = S16(cameraAngle - SrcEngineMathUtil.approach_s32(S16(cameraAngle - m.faceAngle[2]), 0, 0x400, 0x400))

	if mario_actions_automatic.set_pole_position(m, 0) == mario_actions_automatic.POLE_NONE then
		const sp24 = S32(TruncS32(F32(controller.stickY / 4) * 0x10000))

		Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CLIMB_UP_POLE, sp24)
		mario_actions_automatic.add_tree_leaf_particles(m)
		mario_actions_automatic.play_climbing_sounds(m, 1)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_grab_pole_slow L225-237
function mario_actions_automatic.act_grab_pole_slow(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WHOA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	if mario_actions_automatic.set_pole_position(m, 0) == mario_actions_automatic.POLE_NONE then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GRAB_POLE_SHORT)

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_HOLDING_POLE, 0)
		end

		mario_actions_automatic.add_tree_leaf_particles(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_grab_pole_fast L239-260
function mario_actions_automatic.act_grab_pole_fast(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WHOA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	m.faceAngle[2] = S16(m.faceAngle[2] + buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel))
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, TruncS32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel) * 8 / 10))

	if mario_actions_automatic.set_pole_position(m, 0) == mario_actions_automatic.POLE_NONE then
		if buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel) > 0x800 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GRAB_POLE_SWING_PART1)
		else
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GRAB_POLE_SWING_PART2)

			if Mario.is_anim_at_end(m) ~= 0 then
				buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, 0)
				Mario.set_mario_action(m, IncludeSm64H.ACT_HOLDING_POLE, 0)
			end
		end

		mario_actions_automatic.add_tree_leaf_particles(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_top_of_pole_transition L262-280
function mario_actions_automatic.act_top_of_pole_transition(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, 0)

	if m.actionArg == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_HANDSTAND)

		if Mario.is_anim_at_end(m) ~= 0 then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_TOP_OF_POLE, 0)
		end
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RETURN_FROM_HANDSTAND)

		if marioObj.header.gfx.animInfo.animFrame == 0 then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLDING_POLE, 0)
		end
	end

	mario_actions_automatic.set_pole_position(m, Mario.return_mario_anim_y_translation(m))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_top_of_pole L282-297
function mario_actions_automatic.act_top_of_pole(m: GroupsTypesHPlus3.MarioState): number
	const controller = m.controller :: GroupsTypesHPlus3.Controller

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_TOP_OF_POLE_JUMP, 0)
	end

	if controller.stickY < -16 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_TOP_OF_POLE_TRANSITION, 1)
	end

	m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] - controller.stickX * 16)))

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANDSTAND_IDLE)
	mario_actions_automatic.set_pole_position(m, Mario.return_mario_anim_y_translation(m))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:perform_hanging_step L299-341
function mario_actions_automatic.perform_hanging_step(m: GroupsTypesHPlus3.MarioState, nextPos: { number }): number
	m.wall = Mario.resolve_and_return_wall_collisions(nextPos, 50, 50)

	const floorHeight = SrcEngineSurfaceCollision.find_floor(nextPos[1], nextPos[2], nextPos[3], Floor)
	const ceilHeight = Mario.vec3f_find_ceil(nextPos, floorHeight, Ceil)
	const floor = Floor[1]

	if floor == nil then
		return mario_actions_automatic.HANG_HIT_CEIL_OR_OOB
	end

	const ceil = Ceil[1]

	if ceil == nil then
		return mario_actions_automatic.HANG_LEFT_CEIL
	end

	if F32(ceilHeight - floorHeight) <= 160 then
		return mario_actions_automatic.HANG_HIT_CEIL_OR_OOB
	end

	if ceil.type_ ~= IncludeSurfaceTerrainsH.SURFACE_HANGABLE then
		return mario_actions_automatic.HANG_LEFT_CEIL
	end

	const ceilOffset = F32(ceilHeight - F32(nextPos[2] + 160))

	if ceilOffset < -30 then
		return mario_actions_automatic.HANG_HIT_CEIL_OR_OOB
	end

	if ceilOffset > 30 then
		return mario_actions_automatic.HANG_LEFT_CEIL
	end

	nextPos[2] = F32(m.ceilHeight - 160)
	SrcEngineMathUtil.vec3f_copy(m.pos, nextPos)

	m.floor = floor
	m.floorHeight = floorHeight
	m.ceil = ceil
	m.ceilHeight = ceilHeight

	return mario_actions_automatic.HANG_NONE
end

-- from src/game/mario_actions_automatic.c:update_hang_moving L343-373
function mario_actions_automatic.update_hang_moving(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const ceil = m.ceil :: GroupsTypesHPlus3.Surface

	m.forwardVel = F32(m.forwardVel + 1)

	const maxSpeed = 4

	if m.forwardVel > maxSpeed then
		m.forwardVel = maxSpeed
	end

	m.faceAngle[2] = S16(m.intendedYaw - SrcEngineMathUtil.approach_s32(S16(m.intendedYaw - m.faceAngle[2]), 0, 0x800, 0x800))

	m.slideYaw = m.faceAngle[2]
	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))

	m.vel[1] = m.slideVelX
	m.vel[2] = 0
	m.vel[3] = m.slideVelZ

	NextPos[1] = F32(m.pos[1] - F32(ceil.normal.y * m.vel[1]))
	NextPos[3] = F32(m.pos[3] - F32(ceil.normal.y * m.vel[3]))
	NextPos[2] = m.pos[2]

	const stepResult = mario_actions_automatic.perform_hanging_step(m, NextPos)

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	return stepResult
end

-- from src/game/mario_actions_automatic.c:update_hang_stationary L375-383
function mario_actions_automatic.update_hang_stationary(m: GroupsTypesHPlus3.MarioState)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	m.forwardVel = 0
	m.slideVelX = 0
	m.slideVelZ = 0

	m.pos[2] = F32(m.ceilHeight - 160)
	SrcEngineMathUtil.vec3f_copy(m.vel, SrcEngineGraphNode.gVec3fZero)
	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
end

-- from src/game/mario_actions_automatic.c:act_start_hanging L385-420
function mario_actions_automatic.act_start_hanging(m: GroupsTypesHPlus3.MarioState): number
	m.actionTimer = U16(m.actionTimer + 1)

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) and m.actionTimer >= 31 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HANGING, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	const ceil = m.ceil :: GroupsTypesHPlus3.Surface

	if ceil.type_ ~= IncludeSurfaceTerrainsH.SURFACE_HANGABLE then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANG_ON_CEILING)
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_HANGING_STEP, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	mario_actions_automatic.update_hang_stationary(m)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HANGING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_hanging L422-448
function mario_actions_automatic.act_hanging(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HANG_MOVING, m.actionArg)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	const ceil = m.ceil :: GroupsTypesHPlus3.Surface

	if ceil.type_ ~= IncludeSurfaceTerrainsH.SURFACE_HANGABLE then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.actionArg, 1) then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANDSTAND_LEFT)
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANDSTAND_RIGHT)
	end

	mario_actions_automatic.update_hang_stationary(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_hang_moving L450-488
function mario_actions_automatic.act_hang_moving(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	const ceil = m.ceil :: GroupsTypesHPlus3.Surface

	if ceil.type_ ~= IncludeSurfaceTerrainsH.SURFACE_HANGABLE then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.actionArg, 1) then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_MOVE_ON_WIRE_NET_RIGHT)
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_MOVE_ON_WIRE_NET_LEFT)
	end

	if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 12 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HANGING_STEP, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if Mario.is_anim_past_end(m) ~= 0 then
		m.actionArg = bit32.bxor(m.actionArg, 1)

		if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_HANGING, m.actionArg)
		end
	end

	if mario_actions_automatic.update_hang_moving(m) == mario_actions_automatic.HANG_LEFT_CEIL then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:let_go_of_ledge L490-507
function mario_actions_automatic.let_go_of_ledge(m: GroupsTypesHPlus3.MarioState): number
	m.vel[2] = 0
	m.forwardVel = -8

	m.pos[1] = F32(m.pos[1] - F32(60 * SrcEngineMathUtilH.sins(m.faceAngle[2])))
	m.pos[3] = F32(m.pos[3] - F32(60 * SrcEngineMathUtilH.coss(m.faceAngle[2])))

	const floorHeight = SrcEngineSurfaceCollision.find_floor(m.pos[1], m.pos[2], m.pos[3], Floor)

	if floorHeight < F32(m.pos[2] - 100) then
		m.pos[2] = F32(m.pos[2] - 100)
	else
		m.pos[2] = floorHeight
	end

	return Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
end

-- from src/game/mario_actions_automatic.c:climb_up_ledge L509-514
function mario_actions_automatic.climb_up_ledge(m: GroupsTypesHPlus3.MarioState)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAD_LEFT)
	m.pos[1] = F32(m.pos[1] + F32(14 * SrcEngineMathUtilH.sins(m.faceAngle[2])))
	m.pos[3] = F32(m.pos[3] + F32(14 * SrcEngineMathUtilH.coss(m.faceAngle[2])))
	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
end

-- from src/game/mario_actions_automatic.c:update_ledge_climb_camera L516-529
function mario_actions_automatic.update_ledge_climb_camera(m: GroupsTypesHPlus3.MarioState)
	const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState
	const sp4 = if m.actionTimer < 14 then m.actionTimer else 14

	statusForCamera.pos[1] = F32(m.pos[1] + F32(sp4 * SrcEngineMathUtilH.sins(m.faceAngle[2])))
	statusForCamera.pos[3] = F32(m.pos[3] + F32(sp4 * SrcEngineMathUtilH.coss(m.faceAngle[2])))
	statusForCamera.pos[2] = m.pos[2]

	m.actionTimer = U16(m.actionTimer + 1)
	m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_UNKNOWN_25)
end

-- from src/game/mario_actions_automatic.c:update_ledge_climb L531-541
function mario_actions_automatic.update_ledge_climb(m: GroupsTypesHPlus3.MarioState, animation: number, endAction: number)
	MarioStep.stop_and_set_height_to_floor(m)

	Mario.set_mario_animation(m, animation)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, endAction, 0)

		if endAction == IncludeSm64H.ACT_IDLE then
			mario_actions_automatic.climb_up_ledge(m)
		end
	end
end

-- from src/game/mario_actions_automatic.c:act_ledge_grab L543-598
function mario_actions_automatic.act_ledge_grab(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
	const hasSpaceForMario = F32(m.ceilHeight - m.floorHeight) >= 160

	if m.actionTimer < 10 then
		m.actionTimer = U16(m.actionTimer + 1)
	end

	if (m.floor :: GroupsTypesHPlus3.Surface).normal.y < F32(0.9063078) then
		return mario_actions_automatic.let_go_of_ledge(m)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_Z_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR)) then
		return mario_actions_automatic.let_go_of_ledge(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) and hasSpaceForMario then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_LEDGE_CLIMB_FAST, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_KNOCKBACK_DMG) then
			m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 12 else 18))
		end

		return mario_actions_automatic.let_go_of_ledge(m)
	end

	if m.actionTimer == 10 and bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		if intendedDYaw >= -0x4000 and intendedDYaw <= 0x4000 then
			if hasSpaceForMario then
				return Mario.set_mario_action(m, IncludeSm64H.ACT_LEDGE_CLIMB_SLOW_1, 0)
			end
		else
			return mario_actions_automatic.let_go_of_ledge(m)
		end
	end

	const heightAboveFloor = F32(m.pos[2] - Mario.find_floor_height_relative_polar(m, -0x8000, 30))

	if hasSpaceForMario and heightAboveFloor < 100 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_LEDGE_CLIMB_FAST, 0)
	end

	if m.actionArg == 0 then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WHOA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_ON_LEDGE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_ledge_climb_slow L600-624
function mario_actions_automatic.act_ledge_climb_slow(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return mario_actions_automatic.let_go_of_ledge(m)
	end

	if m.actionTimer >= 28 and bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		mario_actions_automatic.climb_up_ledge(m)
		return Mario.check_common_action_exits(m)
	end

	if m.actionTimer == 10 then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_EEUH, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end

	mario_actions_automatic.update_ledge_climb(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLOW_LEDGE_GRAB, IncludeSm64H.ACT_IDLE)

	mario_actions_automatic.update_ledge_climb_camera(m)

	if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 17 then
		m.action = IncludeSm64H.ACT_LEDGE_CLIMB_SLOW_2
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_ledge_climb_down L626-637
function mario_actions_automatic.act_ledge_climb_down(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return mario_actions_automatic.let_go_of_ledge(m)
	end

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WHOA, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	mario_actions_automatic.update_ledge_climb(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CLIMB_DOWN_LEDGE, IncludeSm64H.ACT_LEDGE_GRAB)
	m.actionArg = 1

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_ledge_climb_fast L639-654
function mario_actions_automatic.act_ledge_climb_fast(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return mario_actions_automatic.let_go_of_ledge(m)
	end

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_UH2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	mario_actions_automatic.update_ledge_climb(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FAST_LEDGE_GRAB, IncludeSm64H.ACT_IDLE)

	if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 8 then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	mario_actions_automatic.update_ledge_climb_camera(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_grabbed L656-672
function mario_actions_automatic.act_grabbed(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK2) then
		const thrown = if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK6) then IncludePRUltratypesH.FALSE else IncludePRUltratypesH.TRUE
		const usedObj = m.usedObj :: GroupsTypesHPlus3.Object

		m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		SrcEngineMathUtil.vec3f_copy(m.pos, marioObj.header.gfx.pos)

		return Mario.set_mario_action(m, if m.forwardVel >= 0 then IncludeSm64H.ACT_THROWN_FORWARD else IncludeSm64H.ACT_THROWN_BACKWARD, thrown)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BEING_GRABBED)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_in_cannon L674-762
function mario_actions_automatic.act_in_cannon(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const startFacePitch = m.faceAngle[1]
	const startFaceYaw = m.faceAngle[2]
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const controller = m.controller :: GroupsTypesHPlus3.Controller

	if m.actionState == 0 then
		marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
		buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)

		const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

		statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_CANNON
		statusForCamera.usedObj = m.usedObj

		SrcEngineMathUtil.vec3f_set(m.vel, 0, 0, 0)

		m.pos[1] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX)
		m.pos[2] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY) + 350)
		m.pos[3] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ)

		m.forwardVel = 0
		m.actionState = 1
	elseif m.actionState == 1 then
		if buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oAction) == 1 then
			m.faceAngle[1] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
			m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioCannonObjectYaw, buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioCannonInputYaw, 0)

			m.actionState = 2
		end
	elseif m.actionState == 2 then
		m.faceAngle[1] = S16(m.faceAngle[1] - S16(TruncS32(F32(controller.stickY * 10))))

		local inputYaw = S32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioCannonInputYaw) - S16(TruncS32(F32(controller.stickX * 10))))

		if m.faceAngle[1] > 0x38E3 then
			m.faceAngle[1] = 0x38E3
		end
		if m.faceAngle[1] < 0 then
			m.faceAngle[1] = 0
		end

		if inputYaw > 0x4000 then
			inputYaw = 0x4000
		end
		if inputYaw < -0x4000 then
			inputYaw = -0x4000
		end
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioCannonInputYaw, inputYaw)

		m.faceAngle[2] = S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioCannonObjectYaw) + inputYaw)

		if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			m.forwardVel = F32(100 * SrcEngineMathUtilH.coss(m.faceAngle[1]))
			m.vel[2] = F32(100 * SrcEngineMathUtilH.sins(m.faceAngle[1]))

			m.pos[1] = F32(m.pos[1] + F32(F32(120 * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.sins(m.faceAngle[2])))
			m.pos[2] = F32(m.pos[2] + F32(120 * SrcEngineMathUtilH.sins(m.faceAngle[1])))
			m.pos[3] = F32(m.pos[3] + F32(F32(120 * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.coss(m.faceAngle[2])))

			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_FLYING_FAST, marioObj.header.gfx.cameraToObject)
			Audio.play_sound(IncludeSoundsH.SOUND_OBJ_POUNDING_CANNON, marioObj.header.gfx.cameraToObject)

			marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))

			Mario.set_mario_action(m, IncludeSm64H.ACT_SHOT_FROM_CANNON, 0)

			buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oAction, 2)

			return IncludePRUltratypesH.FALSE
		elseif m.faceAngle[1] ~= startFacePitch or m.faceAngle[2] ~= startFaceYaw then
			Audio.play_sound(IncludeSoundsH.SOUND_MOVING_AIM_CANNON, marioObj.header.gfx.cameraToObject)
		end
	end

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:act_tornado_twirling L764-843
function mario_actions_automatic.act_tornado_twirling(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const prevTwirlYaw = m.twirlYaw

	const dx = F32(F32(m.pos[1] - buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX)) * F32(0.95))
	const dz = F32(F32(m.pos[3] - buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ)) * F32(0.95))

	if m.vel[2] < 60 then
		m.vel[2] = F32(m.vel[2] + 1)
	end

	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY, F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY) + m.vel[2]))

	if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY) < 0 then
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY, 0)
	end

	if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY) > usedObj.hitboxHeight then
		if m.vel[2] < 20 then
			m.vel[2] = 20
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_TWIRLING, 1)
	end

	if m.angleVel[2] < 0x3000 then
		m.angleVel[2] = S16(m.angleVel[2] + 0x100)
	end

	if buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel) < 0x1000 then
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel) + 0x100)
	end

	m.twirlYaw = S16(m.twirlYaw + m.angleVel[2])

	const sinAngleVel = SrcEngineMathUtilH.sins(S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel)))
	const cosAngleVel = SrcEngineMathUtilH.coss(S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel)))

	NextPos[1] = F32(F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX) + F32(dx * cosAngleVel)) + F32(dz * sinAngleVel))
	NextPos[3] = F32(F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ) - F32(dx * sinAngleVel)) + F32(dz * cosAngleVel))
	NextPos[2] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY))

	WallX[1] = NextPos[1]
	WallY[1] = NextPos[2]
	WallZ[1] = NextPos[3]
	SrcEngineSurfaceCollision.f32_find_wall_collision(WallX, WallY, WallZ, 60, 50)
	NextPos[1] = WallX[1]
	NextPos[2] = WallY[1]
	NextPos[3] = WallZ[1]

	const floorHeight = SrcEngineSurfaceCollision.find_floor(NextPos[1], NextPos[2], NextPos[3], Floor)

	if Floor[1] ~= nil then
		m.floor = Floor[1]
		m.floorHeight = floorHeight
		SrcEngineMathUtil.vec3f_copy(m.pos, NextPos)
	else
		if NextPos[2] >= m.floorHeight then
			m.pos[2] = NextPos[2]
		else
			m.pos[2] = m.floorHeight
		end
	end

	m.actionTimer = U16(m.actionTimer + 1)

	Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_START_TWIRL else IncludeMarioAnimationIdsH.MARIO_ANIM_TWIRL)

	if Mario.is_anim_past_end(m) ~= 0 then
		m.actionArg = 1
	end

	-- Play sound on angle overflow
	if prevTwirlYaw > m.twirlYaw then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_TWIRL, marioObj.header.gfx.cameraToObject)
	end

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, S16(m.faceAngle[2] + m.twirlYaw), 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:check_common_automatic_cancels L845-851
function mario_actions_automatic.check_common_automatic_cancels(m: GroupsTypesHPlus3.MarioState): number
	if m.pos[2] < F32(m.waterLevel - 100) then
		return Mario.set_water_plunge_action(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_automatic.c:mario_execute_automatic_action L853-885
function mario_actions_automatic.mario_execute_automatic_action(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_automatic.check_common_automatic_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	m.quicksandDepth = 0

	local cancel = 0

	if m.action == IncludeSm64H.ACT_HOLDING_POLE then
		cancel = mario_actions_automatic.act_holding_pole(m)
	elseif m.action == IncludeSm64H.ACT_GRAB_POLE_SLOW then
		cancel = mario_actions_automatic.act_grab_pole_slow(m)
	elseif m.action == IncludeSm64H.ACT_GRAB_POLE_FAST then
		cancel = mario_actions_automatic.act_grab_pole_fast(m)
	elseif m.action == IncludeSm64H.ACT_CLIMBING_POLE then
		cancel = mario_actions_automatic.act_climbing_pole(m)
	elseif m.action == IncludeSm64H.ACT_TOP_OF_POLE_TRANSITION then
		cancel = mario_actions_automatic.act_top_of_pole_transition(m)
	elseif m.action == IncludeSm64H.ACT_TOP_OF_POLE then
		cancel = mario_actions_automatic.act_top_of_pole(m)
	elseif m.action == IncludeSm64H.ACT_START_HANGING then
		cancel = mario_actions_automatic.act_start_hanging(m)
	elseif m.action == IncludeSm64H.ACT_HANGING then
		cancel = mario_actions_automatic.act_hanging(m)
	elseif m.action == IncludeSm64H.ACT_HANG_MOVING then
		cancel = mario_actions_automatic.act_hang_moving(m)
	elseif m.action == IncludeSm64H.ACT_LEDGE_GRAB then
		cancel = mario_actions_automatic.act_ledge_grab(m)
	elseif m.action == IncludeSm64H.ACT_LEDGE_CLIMB_SLOW_1 then
		cancel = mario_actions_automatic.act_ledge_climb_slow(m)
	elseif m.action == IncludeSm64H.ACT_LEDGE_CLIMB_SLOW_2 then
		cancel = mario_actions_automatic.act_ledge_climb_slow(m)
	elseif m.action == IncludeSm64H.ACT_LEDGE_CLIMB_DOWN then
		cancel = mario_actions_automatic.act_ledge_climb_down(m)
	elseif m.action == IncludeSm64H.ACT_LEDGE_CLIMB_FAST then
		cancel = mario_actions_automatic.act_ledge_climb_fast(m)
	elseif m.action == IncludeSm64H.ACT_GRABBED then
		cancel = mario_actions_automatic.act_grabbed(m)
	elseif m.action == IncludeSm64H.ACT_IN_CANNON then
		cancel = mario_actions_automatic.act_in_cannon(m)
	elseif m.action == IncludeSm64H.ACT_TORNADO_TWIRLING then
		cancel = mario_actions_automatic.act_tornado_twirling(m)
	end

	return cancel
end

return mario_actions_automatic
