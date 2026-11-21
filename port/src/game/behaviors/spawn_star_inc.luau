--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/spawn_star.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const InteractionH = require("../interaction_h")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessorH = require("../object_list_processor_h")
const SaveFile = require("../save_file")
const SrcEngineMathUtil = require("../../engine/math_util")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const Audio = require("../../rom/audio_recorder")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/spawn_star.inc.c:data
const spawn_star_inc = {
	-- from src/game/behaviors/spawn_star.inc.c:sCollectStarHitbox L3-13
	sCollectStarHitbox = {
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

Registry.Register("src__game__behaviors__spawn_star_inc", spawn_star_inc)

-- from src/game/behaviors/spawn_star.inc.c:bhv_collect_star_init L15-26
function spawn_star_inc.bhv_collect_star_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const starIndex = S8(bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF))
	const currentLevelStarFlags = U8(SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Area.gCurrCourseNum)))

	if bit32.btest(currentLevelStarFlags, bit32.lshift(1, starIndex)) then
		o.header.gfx.sharedChild = Area.gLoadedGraphNodes[IncludeModelIdsH.MODEL_TRANSPARENT_STAR + 1]
	else
		o.header.gfx.sharedChild = Area.gLoadedGraphNodes[IncludeModelIdsH.MODEL_STAR + 1]
	end

	ObjectHelpers.obj_set_hitbox(o, spawn_star_inc.sCollectStarHitbox)
end

-- from src/game/behaviors/spawn_star.inc.c:bhv_collect_star_loop L28-35
function spawn_star_inc.bhv_collect_star_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		Registry.Members.src__game__spawn_object.mark_obj_for_deletion(o)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/spawn_star.inc.c:bhv_star_spawn_init L37-53
function spawn_star_inc.bhv_star_spawn_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const DeltaX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const DeltaZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(DeltaZ, DeltaX))
	const SqrDeltaX: number = Registry.Members.src__engine__math_util_h.sqr(DeltaX)
	const SqrDeltaZ: number = Registry.Members.src__engine__math_util_h.sqr(DeltaZ)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSpawnDisFromHome, F32(math.sqrt(F32(SqrDeltaX + SqrDeltaZ))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) / 30.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSpawnDisFromHome) / 30.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSpawnUnkFC, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 or Area.gCurrCourseNum == IncludeCourseTableH.COURSE_BBH then
		Registry.Members.src__game__camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o)
	else
		Registry.Members.src__game__camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_RED_COIN_STAR_SPAWN, o)
	end

	ObjectHelpers.set_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))
	ObjectHelpers.cur_obj_become_intangible()
end

-- from src/game/behaviors/spawn_star.inc.c:bhv_star_spawn_loop L55-112
function spawn_star_inc.bhv_star_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		ObjBehaviors.obj_move_xyz_using_fvel_and_yaw(o)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSpawnUnkFC, buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSpawnUnkFC) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		const SinValue: number = Registry.Members.src__engine__math_util_h.sins((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x8000) // 30)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSpawnUnkFC) + F32(SinValue * 400.0))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_STAR)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			Audio.play_power_star_jingle(1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 20 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -10.0)
		end

		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		ObjBehaviors.obj_move_xyz_using_fvel_and_yaw(o)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x10 + 0x1000)
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_STAR)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_STAR_APPEARS)
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
			Registry.Members.src__game__camera.gObjCutsceneDone = IncludePRUltratypesH.TRUE
			ObjectHelpers.clear_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
			o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
		end

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			Registry.Members.src__game__spawn_object.mark_obj_for_deletion(o)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		end
	end
end

-- from src/game/behaviors/spawn_star.inc.c:spawn_star L114-124
function spawn_star_inc.spawn_star(star: GroupsTypesHPlus3.Object?, homeX: number, homeY: number, homeZ: number): GroupsTypesHPlus3.Object
	homeX = F32(homeX)
	homeY = F32(homeY)
	homeZ = F32(homeZ)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	star = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvStarSpawnCoordinates, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))), 0, 0, 0)

	buffer.writei32(star.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
	buffer.writef32(star.rawData, IncludeObjectFieldsH.oHomeX, homeX)
	buffer.writef32(star.rawData, IncludeObjectFieldsH.oHomeY, homeY)
	buffer.writef32(star.rawData, IncludeObjectFieldsH.oHomeZ, homeZ)
	buffer.writei32(star.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	buffer.writei32(star.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)

	return star
end

-- from src/game/behaviors/spawn_star.inc.c:spawn_default_star L126-129
function spawn_star_inc.spawn_default_star(homeX: number, homeY: number, homeZ: number)
	homeX = F32(homeX)
	homeY = F32(homeY)
	homeZ = F32(homeZ)
	-- star is passed uninitialized in the C; spawn_star overwrites it before reading it
	const Star = spawn_star_inc.spawn_star(nil, homeX, homeY, homeZ)

	buffer.writei32(Star.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 0)
end

-- from src/game/behaviors/spawn_star.inc.c:spawn_red_coin_cutscene_star L131-134
function spawn_star_inc.spawn_red_coin_cutscene_star(homeX: number, homeY: number, homeZ: number)
	homeX = F32(homeX)
	homeY = F32(homeY)
	homeZ = F32(homeZ)
	-- star is passed uninitialized in the C; spawn_star overwrites it before reading it
	const Star = spawn_star_inc.spawn_star(nil, homeX, homeY, homeZ)

	buffer.writei32(Star.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 1)
end

-- from src/game/behaviors/spawn_star.inc.c:spawn_no_exit_star L136-140
function spawn_star_inc.spawn_no_exit_star(homeX: number, homeY: number, homeZ: number)
	homeX = F32(homeX)
	homeY = F32(homeY)
	homeZ = F32(homeZ)
	-- star is passed uninitialized in the C; spawn_star overwrites it before reading it
	const Star = spawn_star_inc.spawn_star(nil, homeX, homeY, homeZ)

	buffer.writei32(Star.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 1)
	buffer.writeu32(Star.rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.bor(buffer.readu32(Star.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NO_EXIT))
end

-- from src/game/behaviors/spawn_star.inc.c:bhv_hidden_red_coin_star_init L142-158
function spawn_star_inc.bhv_hidden_red_coin_star_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if Area.gCurrCourseNum ~= IncludeCourseTableH.COURSE_JRB then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_TRANSPARENT_STAR, BehaviorIds.bhvRedCoinStarMarker)
	end

	const Count = S16(ObjectHelpers.count_objects_with_behavior(BehaviorIds.bhvRedCoin))

	if Count == 0 then
		const Star = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvStar, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))), 0, 0, 0)

		buffer.writei32(Star.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter, 8 - Count)
end

-- from src/game/behaviors/spawn_star.inc.c:bhv_hidden_red_coin_star_loop L160-178
function spawn_star_inc.bhv_hidden_red_coin_star_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	Registry.Members.groups__ingame_menu_plus1.gRedCoinsCollected = S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) == 8 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 2 then
			spawn_star_inc.spawn_red_coin_cutscene_star(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			ObjectHelpers.spawn_mist_particles()
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

return spawn_star_inc
