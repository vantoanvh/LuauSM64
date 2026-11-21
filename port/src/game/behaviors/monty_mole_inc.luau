--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/monty_mole.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const IncludeModelIdsH = require("../../../include/model_ids_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const Memory = require("../memory")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const ObjBehaviors2 = require("../obj_behaviors_2")
const SrcEngineMathUtil = require("../../engine/math_util")
const Audio = require("../../rom/audio_recorder")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/monty_mole_inc.luau:scratch
const Scratch = {
}

-- from src/game/behaviors/monty_mole.inc.c:data
const monty_mole_inc = {
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleHoleList L12-12
	sMontyMoleHoleList = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleKillStreak L17-17
	sMontyMoleKillStreak = 0,
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleLastKilledPosX L23-23
	sMontyMoleLastKilledPosX = 0,
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleLastKilledPosY L24-24
	sMontyMoleLastKilledPosY = 0,
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleLastKilledPosZ L25-25
	sMontyMoleLastKilledPosZ = 0,
	-- from src/game/behaviors/monty_mole.inc.c:montyMoleRiseFromGroundParticles L110-123
	montyMoleRiseFromGroundParticles = {
		bhvParam = 0,
		count = 3,
		model = IncludeModelIdsH.MODEL_SAND_DUST,
		offsetY = 0,
		forwardVelBase = 4,
		forwardVelRange = 4,
		velYBase = 10,
		velYRange = 15,
		gravity = -4,
		dragStrength = 0,
		sizeBase = 10.0,
		sizeRange = 7.0,
	},
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleHitbox L314-324
	sMontyMoleHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = -1,
		numLootCoins = 0,
		radius = 70,
		height = 50,
		hurtboxRadius = 30,
		hurtboxHeight = 40,
	},
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleRockHitbox L432-442
	sMontyMoleRockHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 15,
		damageOrCoinValue = 1,
		health = 99,
		numLootCoins = 0,
		radius = 30,
		height = 15,
		hurtboxRadius = 30,
		hurtboxHeight = 15,
	},
	-- from src/game/behaviors/monty_mole.inc.c:sMontyMoleRockBreakParticles L447-460
	sMontyMoleRockBreakParticles = {
		bhvParam = 0,
		count = 2,
		model = IncludeModelIdsH.MODEL_PEBBLE,
		offsetY = 10,
		forwardVelBase = 4,
		forwardVelRange = 4,
		velYBase = 10,
		velYRange = 15,
		gravity = -4,
		dragStrength = 0,
		sizeBase = 8.0,
		sizeRange = 4.0,
	},
}

Registry.Register("src__game__behaviors__monty_mole_inc", monty_mole_inc)

-- from src/game/behaviors/monty_mole.inc.c:link_objects_with_behavior L32-49
function monty_mole_inc.link_objects_with_behavior(behavior: number): GroupsTypesHPlus3.Object?
	const behaviorAddr = Memory.segmented_to_virtual(behavior)
	const listHead = ObjectListProcessor.gObjectLists[ObjectHelpers.get_object_list_from_behavior(behaviorAddr) + 1]
	local lastObject: GroupsTypesHPlus3.Object? = nil
	local obj = listHead.ObjectNode_next :: GroupsTypesHPlus3.Object

	while obj ~= listHead do
		if obj.behavior == behaviorAddr and obj.activeFlags ~= IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
			obj.parentObj = lastObject
			lastObject = obj
		end

		obj = obj.header.ObjectNode_next :: GroupsTypesHPlus3.Object
	end

	return lastObject
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_select_available_hole L55-91
function monty_mole_inc.monty_mole_select_available_hole(minDistToMario: number): GroupsTypesHPlus3.Object?
	minDistToMario = F32(minDistToMario)
	local hole = monty_mole_inc.sMontyMoleHoleList
	local numAvailableHoles = 0

	while hole ~= nil do
		if buffer.readi32(hole.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown) == 0 then
			if buffer.readf32(hole.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 and buffer.readf32(hole.rawData, IncludeObjectFieldsH.oDistanceToMario) > minDistToMario then
				numAvailableHoles += 1
			end
		end

		hole = hole.parentObj
	end

	if numAvailableHoles ~= 0 then
		const selectedHole = TruncS32(F32(SrcEngineBehaviorScript.random_float() * numAvailableHoles))

		hole = monty_mole_inc.sMontyMoleHoleList
		numAvailableHoles = 0

		while hole ~= nil do
			if buffer.readi32(hole.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown) == 0 then
				if buffer.readf32(hole.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 and buffer.readf32(hole.rawData, IncludeObjectFieldsH.oDistanceToMario) > minDistToMario then
					if numAvailableHoles == selectedHole then
						return hole
					end

					numAvailableHoles += 1
				end
			end

			hole = hole.parentObj
		end
	end

	return nil
end

-- from src/game/behaviors/monty_mole.inc.c:bhv_monty_mole_hole_update L96-104
function monty_mole_inc.bhv_monty_mole_hole_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.parentObj == o then
		monty_mole_inc.sMontyMoleHoleList = monty_mole_inc.link_objects_with_behavior(BehaviorIds.bhvMontyMoleHole)
		monty_mole_inc.sMontyMoleKillStreak = 0
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown) - 1)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_spawn_dirt_particles L109-129
function monty_mole_inc.monty_mole_spawn_dirt_particles(offsetY: number, velYBase: number)
	offsetY = S8(TruncS32(offsetY))
	velYBase = S8(TruncS32(velYBase))
	monty_mole_inc.montyMoleRiseFromGroundParticles.offsetY = offsetY
	monty_mole_inc.montyMoleRiseFromGroundParticles.velYBase = velYBase

	ObjectHelpers.cur_obj_spawn_particles(monty_mole_inc.montyMoleRiseFromGroundParticles)
end

-- from src/game/behaviors/monty_mole.inc.c:bhv_monty_mole_init L134-136
function monty_mole_inc.bhv_monty_mole_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.ptrData[IncludeObjectFieldsH.oMontyMoleCurrentHole + 1] = nil
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_select_hole L142-183
function monty_mole_inc.monty_mole_act_select_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local minDistToMario: number

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.MONTY_MOLE_BP_NO_ROCK then
		minDistToMario = 200.0
	elseif LevelUpdate.gMarioStates[1].forwardVel < 8.0 then
		minDistToMario = 100.0
	else
		minDistToMario = 500.0
	end

	const hole = monty_mole_inc.monty_mole_select_available_hole(minDistToMario)
	o.ptrData[IncludeObjectFieldsH.oMontyMoleCurrentHole + 1] = hole

	if hole ~= nil then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_MONTY_MOLE_APPEAR)

		buffer.writei32(hole.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown, -1)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(hole.rawData, IncludeObjectFieldsH.oPosX))
		const holePosY = buffer.readf32(hole.rawData, IncludeObjectFieldsH.oPosY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, holePosY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, holePosY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(hole.rawData, IncludeObjectFieldsH.oPosZ))

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(hole.rawData, IncludeObjectFieldsH.oAngleToMario))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 500.0 or minDistToMario > 100.0 or SrcEngineBehaviorScript.random_sign() < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_RISE_FROM_HOLE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 3.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
			monty_mole_inc.monty_mole_spawn_dirt_particles(0, 10)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_JUMP_OUT_OF_HOLE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
			monty_mole_inc.monty_mole_spawn_dirt_particles(0, 20)
		end

		ObjectHelpers.cur_obj_unhide()
		ObjectHelpers.cur_obj_become_tangible()
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_rise_from_hole L188-199
function monty_mole_inc.monty_mole_act_rise_from_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMontyMoleHeightRelativeToFloor) >= 49.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) + 50.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_SPAWN_ROCK)
		end
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_spawn_rock L205-218
function monty_mole_inc.monty_mole_act_spawn_rock()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(2) ~= 0 then
		local rock: GroupsTypesHPlus3.Object? = nil

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.MONTY_MOLE_BP_NO_ROCK and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x4000 then
			rock = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PEBBLE, BehaviorIds.bhvMontyMoleRock)
		end

		if rock ~= nil then
			o.prevObj = rock
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_THROW_ROCK)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_BEGIN_JUMP_INTO_HOLE)
		end
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_begin_jump_into_hole L224-230
function monty_mole_inc.monty_mole_act_begin_jump_into_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(3) ~= 0 or ObjBehaviors2.obj_is_near_to_and_facing_mario(1000.0, 0x4000) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_JUMP_INTO_HOLE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -6.0)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_throw_rock L235-244
function monty_mole_inc.monty_mole_act_throw_rock()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_check_frame(8, 10) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MONTY_MOLE_ATTACK)
		o.prevObj = nil
	end

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_BEGIN_JUMP_INTO_HOLE)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_jump_into_hole L249-259
function monty_mole_inc.monty_mole_act_jump_into_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.cur_obj_init_anim_extend(0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, -SrcEngineMathUtil.atan2s(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY), -4.0))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oMontyMoleHeightRelativeToFloor) < 120.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_HIDE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
		monty_mole_inc.monty_mole_spawn_dirt_particles(-80, 15)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_hide_in_hole L264-277
function monty_mole_inc.monty_mole_hide_in_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const hole = o.ptrData[IncludeObjectFieldsH.oMontyMoleCurrentHole + 1] :: GroupsTypesHPlus3.Object

	buffer.writei32(hole.rawData, IncludeObjectFieldsH.oMontyMoleHoleCooldown, 30)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_SELECT_HOLE)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

	ObjectHelpers.cur_obj_become_intangible()
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_hide L282-291
function monty_mole_inc.monty_mole_act_hide()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(1)
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		ObjectHelpers.cur_obj_hide()
		monty_mole_inc.monty_mole_hide_in_hole()
	else
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oVelY, -4.0, 0.5)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_act_jump_out_of_hole L297-309
function monty_mole_inc.monty_mole_act_jump_out_of_hole()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 0.0 then
		ObjectHelpers.cur_obj_init_animation_with_sound(9)
	else
		ObjBehaviors2.cur_obj_init_anim_extend(4)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMontyMoleHeightRelativeToFloor) < 50.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) + 50.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ACT_BEGIN_JUMP_INTO_HOLE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		end
	end
end

-- from src/game/behaviors/monty_mole.inc.c:bhv_monty_mole_update L329-400
function monty_mole_inc.bhv_monty_mole_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_DYING_ENEMY1)
	ObjectHelpers.cur_obj_update_floor_and_walls()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oMontyMoleHeightRelativeToFloor, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MONTY_MOLE_ACT_SELECT_HOLE then
		monty_mole_inc.monty_mole_act_select_hole()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_RISE_FROM_HOLE then
		monty_mole_inc.monty_mole_act_rise_from_hole()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_SPAWN_ROCK then
		monty_mole_inc.monty_mole_act_spawn_rock()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_BEGIN_JUMP_INTO_HOLE then
		monty_mole_inc.monty_mole_act_begin_jump_into_hole()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_THROW_ROCK then
		monty_mole_inc.monty_mole_act_throw_rock()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_JUMP_INTO_HOLE then
		monty_mole_inc.monty_mole_act_jump_into_hole()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_HIDE then
		monty_mole_inc.monty_mole_act_hide()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ACT_JUMP_OUT_OF_HOLE then
		monty_mole_inc.monty_mole_act_jump_out_of_hole()
	end

	-- Spawn a 1-up if you kill 8 monty moles
	if ObjBehaviors2.obj_check_attacks(monty_mole_inc.sMontyMoleHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)) ~= 0 then
		if monty_mole_inc.sMontyMoleKillStreak ~= 0 then
			const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - monty_mole_inc.sMontyMoleLastKilledPosX)
			const dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - monty_mole_inc.sMontyMoleLastKilledPosY)
			const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - monty_mole_inc.sMontyMoleLastKilledPosZ)
			const distToLastKill = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

			if distToLastKill < 1500.0 then
				if monty_mole_inc.sMontyMoleKillStreak == 7 then
					Audio.play_puzzle_jingle()
					ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_1UP, BehaviorIds.bhv1UpWalking)
				end
			else
				monty_mole_inc.sMontyMoleKillStreak = 0
			end
		end

		-- No overflow check
		monty_mole_inc.sMontyMoleKillStreak += 1
		monty_mole_inc.sMontyMoleLastKilledPosX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		monty_mole_inc.sMontyMoleLastKilledPosY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		monty_mole_inc.sMontyMoleLastKilledPosZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		monty_mole_inc.monty_mole_hide_in_hole()
		-- Throw rock if holding one
		o.prevObj = nil
	end

	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_rock_act_held L405-427
function monty_mole_inc.monty_mole_rock_act_held()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, 80.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, -50.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, 0.0)

	if parentObj.prevObj == nil then
		local distToMario = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario)
		if distToMario > 600.0 then
			distToMario = 600.0
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONTY_MOLE_ROCK_ACT_MOVE)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32((buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 500) - F32(distToMario * F32(0.1)))))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(distToMario * F32(0.08)) + 8.0)

		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
	end
end

-- from src/game/behaviors/monty_mole.inc.c:monty_mole_rock_act_move L465-474
function monty_mole_inc.monty_mole_rock_act_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER)) then
		ObjectHelpers.cur_obj_spawn_particles(monty_mole_inc.sMontyMoleRockBreakParticles)
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/monty_mole.inc.c:bhv_monty_mole_rock_update L479-494
function monty_mole_inc.bhv_monty_mole_rock_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_check_attacks(monty_mole_inc.sMontyMoleRockHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MONTY_MOLE_ROCK_ACT_HELD then
		monty_mole_inc.monty_mole_rock_act_held()
	elseif action == IncludeObjectConstantsH.MONTY_MOLE_ROCK_ACT_MOVE then
		monty_mole_inc.monty_mole_rock_act_move()
	end
end

return monty_mole_inc
