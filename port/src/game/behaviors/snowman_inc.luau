--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/snowman.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const Area = require("../area")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const CorkboxInc = require("./corkbox_inc")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SrcEngineMathUtil = require("../../engine/math_util")
const SpawnStarInc = require("./spawn_star_inc")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const Memory = require("../memory")
const ObjectHelpersH = require("../object_helpers_h")
const ObjectListProcessor = require("../object_list_processor")
const SegmentSymbols = require("../../rom/segment_symbols")
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

-- from src/game/behaviors/snowman_inc.luau:scratch
const Scratch = {
	bhv_snowmans_head_loop_oSnowmansHeadDialogActive = { 0 },
}

-- from src/game/behaviors/snowman.inc.c:data
const snowman_inc = {
	-- from src/game/behaviors/snowman.inc.c:sRollingSphereHitbox L3-13
	sRollingSphereHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 0,
		numLootCoins = 0,
		radius = 210,
		height = 350,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__snowman_inc", snowman_inc)

-- from src/game/behaviors/snowman.inc.c:bhv_snowmans_bottom_init L15-35
function snowman_inc.bhv_snowmans_bottom_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 10.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale, 0.4)

	const SnowmansHead: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvSnowmansHead)

	if SnowmansHead ~= nil then
		o.parentObj = SnowmansHead
	end

	ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSnowmansBodyCheckpoint, -402, 461, -2898, 0, 0, 0)
end

-- from src/game/behaviors/snowman.inc.c:set_rolling_sphere_hitbox L37-43
function snowman_inc.set_rolling_sphere_hitbox()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, snowman_inc.sRollingSphereHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/snowman.inc.c:adjust_rolling_face_pitch L45-52
function snowman_inc.adjust_rolling_face_pitch(f12: number)
	f12 = F32(f12)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + S16(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(100.0 / f12)))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 0.0001)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale) > 1.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale, 1.0)
	end
end

-- from src/game/behaviors/snowman.inc.c:snowmans_bottom_act_1 L54-82
function snowman_inc.snowmans_bottom_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local followStatus = 0

	o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.ccm_seg7_trajectory_snowman)
	ObjBehaviors.object_step_without_floor_orient()

	--! Uninitialized parameter, but the parameter is unused in the called function
	followStatus = ObjectHelpers.cur_obj_follow_path(followStatus)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnkF8)), 0x400))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 70.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 70.0)
	end

	if followStatus == ObjectHelpersH.PATH_REACHED_END then
		if ObjBehaviors.obj_check_if_facing_toward_angle(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw), buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario), 0x2000) == IncludePRUltratypesH.TRUE and buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnk1AC) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/snowman.inc.c:snowmans_bottom_act_2 L84-108
function snowman_inc.snowmans_bottom_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- collisionFlags is UNUSED: the call stays, its value is dropped
	ObjBehaviors.object_step_without_floor_orient()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 70.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 70.0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomUnkF8)), 0x400))

	if ObjBehaviors.is_point_close_to_object(o, -4230.0, -1344.0, 1813.0, 300) ~= 0 then
		BehaviorActions.spawn_mist_particles_variable(0, 0, 70.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(F32(1813.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)), F32(-4230.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 80.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)

		const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

		buffer.writei32(ParentObj.rawData, IncludeObjectFieldsH.oAction, 2)
		buffer.writef32(ParentObj.rawData, IncludeObjectFieldsH.oVelY, 100.0)
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNOWMAN_BOUNCE)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 200 then
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_CCM_SNOWMAN_BASE, BehaviorIds.bhvSnowmansBottom, 3000)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/snowman.inc.c:snowmans_bottom_act_3 L110-124
function snowman_inc.snowmans_bottom_act_3()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const collisionFlags = S16(ObjBehaviors.object_step_without_floor_orient())

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAGS_LANDED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
		ObjectHelpers.cur_obj_become_intangible()
	end

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		BehaviorActions.spawn_mist_particles_variable(0, 0, 70.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, -4230.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, 1813.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	end
end

-- from src/game/behaviors/snowman.inc.c:bhv_snowmans_bottom_loop L126-165
function snowman_inc.bhv_snowmans_bottom_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 400) == 1
			and MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			const Response = S16(Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, IncludeDialogIdsH.DIALOG_110))

			if Response ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		snowman_inc.snowmans_bottom_act_1()
		snowman_inc.adjust_rolling_face_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale))
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_UNKNOWN2)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		snowman_inc.snowmans_bottom_act_2()
		snowman_inc.adjust_rolling_face_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale))
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_UNKNOWN2)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		snowman_inc.snowmans_bottom_act_3()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		ObjectHelpers.cur_obj_push_mario_away_from_cylinder(210.0, 550)
	end

	snowman_inc.set_rolling_sphere_hitbox()
	ObjBehaviors.set_object_visibility(o, 8000)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnowmansBottomScale) * 180.0)
end

-- from src/game/behaviors/snowman.inc.c:bhv_snowmans_head_init L167-185
function snowman_inc.bhv_snowmans_head_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const starFlags = U8(SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Area.gCurrCourseNum)))
	const sp36 = S8(bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF))

	ObjectHelpers.cur_obj_scale(F32(0.7))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)

	if bit32.btest(starFlags, bit32.lshift(1, sp36)) and Area.gCurrActNum ~= sp36 + 1 then
		ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_CCM_SNOWMAN_BASE, BehaviorIds.bhvBigSnowmanWhole, -4230, -1344, 1813, 0, 0, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, -4230.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, -994.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, 1813.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/snowman.inc.c:bhv_snowmans_head_loop L187-228
function snowman_inc.bhv_snowmans_head_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnowmansHeadDialogActive)
		const Triggered: number = ObjBehaviors.trigger_obj_dialog_when_facing(Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive, IncludeDialogIdsH.DIALOG_109, 400.0, MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnowmansHeadDialogActive, Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive[1])

		if Triggered ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		-- Nothing to do while waiting.
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		const collisionFlags = S16(ObjBehaviors.object_step_without_floor_orient())

		if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_NO_Y_VEL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjBehaviors.object_step_without_floor_orient()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < -994.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, -994.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNOWMAN_EXPLODE)
			Audio.play_puzzle_jingle()
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnowmansHeadDialogActive)
		const Triggered: number = ObjBehaviors.trigger_obj_dialog_when_facing(Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive, IncludeDialogIdsH.DIALOG_111, 700.0, MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnowmansHeadDialogActive, Scratch.bhv_snowmans_head_loop_oSnowmansHeadDialogActive[1])

		if Triggered ~= 0 then
			ObjectHelpers.spawn_mist_particles()
			SpawnStarInc.spawn_default_star(-4700.0, -1024.0, 1890.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(180.0, 150.0)
end

-- from src/game/behaviors/snowman.inc.c:bhv_snowmans_body_checkpoint_loop L230-239
function snowman_inc.bhv_snowmans_body_checkpoint_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 800) ~= 0 then
		const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

		buffer.writei32(ParentObj.rawData, IncludeObjectFieldsH.oSnowmansBottomUnk1AC, buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oSnowmansBottomUnk1AC) + 1)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	if (o.parentObj :: GroupsTypesHPlus3.Object).activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return snowman_inc
