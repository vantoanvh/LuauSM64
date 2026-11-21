--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sparkle_spawn_star.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const ObjectListProcessorH = require("../object_list_processor_h")
const SaveFile = require("../save_file")
const SpawnObject = require("../spawn_object")
const Audio = require("../../rom/audio_recorder")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:data
const sparkle_spawn_star_inc = {
	-- from src/game/behaviors/sparkle_spawn_star.inc.c:sSparkleSpawnStarHitbox L3-13
	sSparkleSpawnStarHitbox = {
			interactType = InteractionH.INTERACT_STAR_OR_KEY,
			downOffset = 0,
			damageOrCoinValue = 0,
			health = 0,
			numLootCoins = 0,
			radius = 80,
			height = 50,
			hurtboxRadius = 0,
			hurtboxHeight = 0,
		},
}

Registry.Register("src__game__behaviors__sparkle_spawn_star_inc", sparkle_spawn_star_inc)

-- from src/game/behaviors/sparkle_spawn_star.inc.c:bhv_spawned_star_init L15-30
function sparkle_spawn_star_inc.bhv_spawned_star_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NO_EXIT) then
		const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oBhvParams))
	end

	const StarIndex = bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF)

	if bit32.btest(ObjectHelpers.bit_shift_left(StarIndex), SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Area.gCurrCourseNum))) then
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_TRANSPARENT_STAR)
	end

	Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_STAR_APPEARS)
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:set_sparkle_spawn_star_hitbox L32-38
function sparkle_spawn_star_inc.set_sparkle_spawn_star_hitbox()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, sparkle_spawn_star_inc.sSparkleSpawnStarHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		SpawnObject.mark_obj_for_deletion(o)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:set_home_to_mario L40-54
function sparkle_spawn_star_inc.set_home_to_mario()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 250.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))

	const Sp1C = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const Sp18 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(F32(math.sqrt(F32(F32(Sp1C * Sp1C) + F32(Sp18 * Sp18)))) / 23.0))
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:set_y_home_to_pos L56-59
function sparkle_spawn_star_inc.set_y_home_to_pos()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:slow_star_rotation L61-65
function sparkle_spawn_star_inc.slow_star_rotation()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) > 0x400 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) - 0x40)
	end
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:bhv_spawned_star_loop L67-126
function sparkle_spawn_star_inc.bhv_spawned_star_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o)
			ObjectHelpers.set_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x800)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
				sparkle_spawn_star_inc.set_home_to_mario()
			else
				sparkle_spawn_star_inc.set_y_home_to_pos()
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_angle_to_home())
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
			ObjectHelpers.spawn_mist_particles()
		end

		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_STAR)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -1.0)

			if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NO_EXIT) then
				Audio.play_power_star_jingle(1)
			else
				Audio.play_power_star_jingle(1)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -4.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -4.0)
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			Camera.gObjCutsceneDone = IncludePRUltratypesH.TRUE
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if (Camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene == 0 and Camera.gRecentCutscene == 0 then
			ObjectHelpers.clear_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
			o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	else
		sparkle_spawn_star_inc.set_sparkle_spawn_star_hitbox()
		sparkle_spawn_star_inc.slow_star_rotation()
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/sparkle_spawn_star.inc.c:bhv_spawn_star_no_level_exit L128-133
function sparkle_spawn_star_inc.bhv_spawn_star_no_level_exit(starIndex: number)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const star = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvSpawnedStarNoLevelExit)

	buffer.writei32(star.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.lshift(starIndex, 24)))
	buffer.writeu32(star.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_NO_EXIT)
	ObjectHelpers.obj_set_angle(star, 0, 0, 0)
end

return sparkle_spawn_star_inc
