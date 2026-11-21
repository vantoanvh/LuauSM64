--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/scuttlebug.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
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

-- from src/game/behaviors/scuttlebug_inc.luau:scratch
const Scratch = {
	bhv_scuttlebug_loop_angleToMario = { 0 },
}

-- from src/game/behaviors/scuttlebug.inc.c:data
const scuttlebug_inc = {
	-- from src/game/behaviors/scuttlebug.inc.c:sScuttlebugHitbox L3-13
	sScuttlebugHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 1,
		numLootCoins = 3,
		radius = 130,
		height = 70,
		hurtboxRadius = 90,
		hurtboxHeight = 60,
	},
}

Registry.Register("src__game__behaviors__scuttlebug_inc", scuttlebug_inc)

-- from src/game/behaviors/scuttlebug.inc.c:update_angle_from_move_flags L15-24
function scuttlebug_inc.update_angle_from_move_flags(angle: { number }): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		angle[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle)
		return 1
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) then
		angle[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000
		return -1
	end

	return 0
end

-- from src/game/behaviors/scuttlebug.inc.c:bhv_scuttlebug_loop L26-143
function scuttlebug_inc.bhv_scuttlebug_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) ~= 0 and ObjectHelpers.cur_obj_set_hitbox_and_die_if_attacked(scuttlebug_inc.sScuttlebugHitbox, IncludeSoundsH.SOUND_OBJ_DYING_ENEMY1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF4)) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 3)
	end

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction ~= 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF8, 0)
	end

	if subAction == 0 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_GOOMBA_ALERT)
		end

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)
		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 1000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF8) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.obj_angle_to_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object))
				if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x800 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF8, 1)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_SCUTTLEBUG_ALERT)
				end
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF8) == 1 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC) + 1)
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC) > 50 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF8, 0)
				end
			end
		end

		Scratch.bhv_scuttlebug_loop_angleToMario[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)
		const flagsAngleUpdated = scuttlebug_inc.update_angle_from_move_flags(Scratch.bhv_scuttlebug_loop_angleToMario)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, Scratch.bhv_scuttlebug_loop_angleToMario[1])
		if flagsAngleUpdated ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 2)
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)
	elseif subAction == 2 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)
		if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) == S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
		end

		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) < -200.0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
	elseif subAction == 3 then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -10.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_SCUTTLEBUG_ALERT)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
	elseif subAction == 4 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -10.0)
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC, 0)
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		end
	elseif subAction == 5 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 2.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC) + 1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkFC) > 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
		end
	end

	const sp18 = if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) < 10.0 then 1.0 else 3.0
	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, sp18)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		BehaviorActions.set_obj_anim_with_accel_and_sound(1, 23, IncludeSoundsH.SOUND_OBJ2_SCUTTLEBUG_WALK)
	end

	if o.parentObj ~= o then
		if ObjectHelpers.obj_is_hidden(o) ~= 0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		if o.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
			const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oScuttlebugSpawnerUnk88, 1)
		end
	end

	ObjectHelpers.cur_obj_move_standard(-50)
end

-- from src/game/behaviors/scuttlebug.inc.c:bhv_scuttlebug_spawn_loop L145-161
function scuttlebug_inc.bhv_scuttlebug_spawn_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 and 500.0 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_SCUTTLEBUG_ALERT)
			const scuttlebug = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SCUTTLEBUG, BehaviorIds.bhvScuttlebug)
			buffer.writei32(scuttlebug.rawData, IncludeObjectFieldsH.oScuttlebugUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugSpawnerUnkF4))
			buffer.writef32(scuttlebug.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
			buffer.writef32(scuttlebug.rawData, IncludeObjectFieldsH.oVelY, 80.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugUnkF4, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oScuttlebugSpawnerUnk88) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oScuttlebugSpawnerUnk88, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

return scuttlebug_inc
