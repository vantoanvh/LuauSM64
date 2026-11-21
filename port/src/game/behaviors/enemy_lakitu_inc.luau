--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/enemy_lakitu.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

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

-- from src/game/behaviors/enemy_lakitu_inc.luau:scratch
const Scratch = {
	enemy_lakitu_update_speed_and_angle_turnSpeed = { 0 },
}

-- from src/game/behaviors/enemy_lakitu.inc.c:data
const enemy_lakitu_inc = {
	-- from src/game/behaviors/enemy_lakitu.inc.c:sEnemyLakituHitbox L11-21
	sEnemyLakituHitbox = {
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 5,
		radius = 50,
		height = 50,
		hurtboxRadius = 40,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__enemy_lakitu_inc", enemy_lakitu_inc)

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_act_uninitialized L26-33
function enemy_lakitu_inc.enemy_lakitu_act_uninitialized()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
		ObjectHelpers.spawn_object_relative_with_scale(IncludeObjectConstantsH.CLOUD_BP_LAKITU_CLOUD, 0, 0, 0, 2, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvCloud)

		ObjectHelpers.cur_obj_unhide()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.ENEMY_LAKITU_ACT_MAIN)
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_update_vel_y L38-53
function enemy_lakitu_inc.enemy_lakitu_update_vel_y(offsetY: number)
	offsetY = F32(offsetY)
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- In order to encourage oscillation, pass mario by a small margin before
	-- accelerating the opposite direction
	local margin = 0
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
		margin = -3
	else
		margin = 3
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) + offsetY) + margin) then
		ObjBehaviors2.obj_y_vel_approach(4, F32(0.4))
	else
		ObjBehaviors2.obj_y_vel_approach(-4, F32(0.4))
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_update_speed_and_angle L59-89
function enemy_lakitu_inc.enemy_lakitu_update_speed_and_angle()
	const o = ObjectListProcessor.gCurrentObject

	-- from src/game/behaviors/enemy_lakitu.inc.c:distToMario
	local distToMario = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario)
	if distToMario > 500 then
		distToMario = 500
	end

	-- Move faster the farther away mario is and the faster mario is moving
	local minSpeed = F32(F32(1.2) * LevelUpdate.gMarioStates[1].forwardVel)
	if minSpeed < 8 then
		minSpeed = 8
	end
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, distToMario * F32(0.04))
	ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oForwardVel, minSpeed, 40)

	-- Accelerate toward mario vertically
	enemy_lakitu_inc.enemy_lakitu_update_vel_y(300)

	-- Turn toward mario except right after throwing a spiny
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituFaceForwardCountdown) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituFaceForwardCountdown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituFaceForwardCountdown) - 1)
	else
		ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x600)
	end

	-- Change move angle toward mario faster when farther from mario
	Scratch.enemy_lakitu_update_speed_and_angle_turnSpeed[1] = S16(TruncS32(F32(distToMario * 2)))
	ObjBehaviors2.clamp_s16(Scratch.enemy_lakitu_update_speed_and_angle_turnSpeed, 200, 4000)
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), Scratch.enemy_lakitu_update_speed_and_angle_turnSpeed[1])
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_sub_act_no_spiny L95-113
function enemy_lakitu_inc.enemy_lakitu_sub_act_no_spiny()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown) - 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies) < 3 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 800 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) < 0x4000 then
		const spiny: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPINY_BALL, BehaviorIds.bhvSpiny)
		if spiny ~= nil then
			o.prevObj = spiny
			buffer.writei32(spiny.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SPINY_ACT_HELD_BY_LAKITU)
			ObjectHelpers.obj_init_animation_with_sound(spiny, Memory.segmented_to_virtual(0x050157E4), 0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies) + 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_HOLD_SPINY)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown, 30)
		end
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_sub_act_hold_spiny L119-132
function enemy_lakitu_inc.enemy_lakitu_sub_act_hold_spiny()
	const o = ObjectListProcessor.gCurrentObject

	ObjBehaviors2.cur_obj_init_anim_extend(3)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown) - 1)
	-- Source note: check if anything interesting happens if we bypass this with speed
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDrawingDistance) - 100) or (buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) < 0x2000) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_THROW_SPINY)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituFaceForwardCountdown, 20)
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_sub_act_throw_spiny L137-147
function enemy_lakitu_inc.enemy_lakitu_sub_act_throw_spiny()
	const o = ObjectListProcessor.gCurrentObject

	if ObjBehaviors2.cur_obj_init_anim_check_frame(2, 2) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_EVIL_LAKITU_THROW)
		o.prevObj = nil
	end

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_NO_SPINY)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEnemyLakituSpinyCooldown, ObjBehaviors2.random_linear_offset(100, 100))
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:enemy_lakitu_act_main L152-183
function enemy_lakitu_inc.enemy_lakitu_act_main()
	const o = ObjectListProcessor.gCurrentObject

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_LAKITU_FLY)

	ObjectHelpers.cur_obj_update_floor_and_walls()

	enemy_lakitu_inc.enemy_lakitu_update_speed_and_angle()
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
	end

	ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oEnemyLakituBlinkTimer, 20, 40, 4)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_NO_SPINY then
		enemy_lakitu_inc.enemy_lakitu_sub_act_no_spiny()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_HOLD_SPINY then
		enemy_lakitu_inc.enemy_lakitu_sub_act_hold_spiny()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.ENEMY_LAKITU_SUB_ACT_THROW_SPINY then
		enemy_lakitu_inc.enemy_lakitu_sub_act_throw_spiny()
	end

	ObjectHelpers.cur_obj_move_standard(78)

	-- Die and drop held spiny when attacked by mario
	if ObjBehaviors2.obj_check_attacks(enemy_lakitu_inc.sEnemyLakituHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)) ~= 0 then
		-- The spiny uses this as a signal to get thrown
		o.prevObj = nil
	end
end

-- from src/game/behaviors/enemy_lakitu.inc.c:bhv_enemy_lakitu_update L188-201
function enemy_lakitu_inc.bhv_enemy_lakitu_update()
	const o = ObjectListProcessor.gCurrentObject

	-- PARTIAL_UPDATE

	ObjBehaviors2.treat_far_home_as_mario(2000)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.ENEMY_LAKITU_ACT_UNINITIALIZED then
		enemy_lakitu_inc.enemy_lakitu_act_uninitialized()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.ENEMY_LAKITU_ACT_MAIN then
		enemy_lakitu_inc.enemy_lakitu_act_main()
	end
end

return enemy_lakitu_inc
