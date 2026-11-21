--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/yoshi.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const BobombInc = require("./bobomb_inc")
const Camera = require("../camera")
const CorkboxInc = require("./corkbox_inc")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")

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

-- from src/game/behaviors/yoshi.inc.c:data
const yoshi_inc = {
	-- from src/game/behaviors/yoshi.inc.c:sYoshiHomeLocations L6-6
	sYoshiHomeLocations = { 0, -5625, -1364, -5912, -1403, -4609, -1004, -5308 },
}

Registry.Register("src__game__behaviors__yoshi_inc", yoshi_inc)

-- from src/game/behaviors/yoshi.inc.c:bhv_yoshi_init L8-18
function yoshi_inc.bhv_yoshi_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, F32(0.9))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, F32(1.3))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_NPC)

	if SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1) < 120 or ObjBehaviors.sYoshiDead == IncludePRUltratypesH.TRUE then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_walk_loop L20-46
function yoshi_inc.yoshi_walk_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const AnimFrame = o.header.gfx.animInfo.animFrame

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
	ObjBehaviors.object_step()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oYoshiTargetYaw)), 0x500))

	if ObjBehaviors.is_point_close_to_object(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), 3174, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 200) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_IDLE)
	end

	ObjectHelpers.cur_obj_init_animation(1)

	if AnimFrame == 0 or AnimFrame == 15 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_YOSHI_WALK)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus) == InteractionH.INT_STATUS_INTERACTED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_TALK)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < 2100 then
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_YOSHI, BehaviorIds.bhvYoshi, 3000)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_idle_loop L48-81
function yoshi_inc.yoshi_idle_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
		const ChosenHome = S16(TruncS32(SrcEngineBehaviorScript.random_float() * 3.99))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oYoshiChosenHome) == ChosenHome then
			return
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oYoshiChosenHome, ChosenHome)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, yoshi_inc.sYoshiHomeLocations[ChosenHome * 2 + 1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, yoshi_inc.sYoshiHomeLocations[ChosenHome * 2 + 2])
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oYoshiTargetYaw, SrcEngineMathUtil.atan2s(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_WALK)
	end

	ObjectHelpers.cur_obj_init_animation(0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus) == InteractionH.INT_STATUS_INTERACTED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_TALK)
	end

	-- Credits; Yoshi appears at this position overlooking the castle near the end of the credits
	const CameraEvent = Camera.gPlayerCameraState[1].cameraEvent

	if CameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_ENDING or CameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_END_WAVING then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_CREDITS)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, -1798)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 3174)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, -3644)
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_talk_loop L83-102
function yoshi_inc.yoshi_talk_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) == S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) then
		ObjectHelpers.cur_obj_init_animation(0)

		if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))

			if Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, IncludeDialogIdsH.DIALOG_161) ~= 0 then
				o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, yoshi_inc.sYoshiHomeLocations[3])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, yoshi_inc.sYoshiHomeLocations[4])
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oYoshiTargetYaw, SrcEngineMathUtil.atan2s(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_GIVE_PRESENT)
			end
		end
	else
		ObjectHelpers.cur_obj_init_animation(1)
		Audio.play_puzzle_jingle()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x500))
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_walk_and_jump_off_roof_loop L104-129
function yoshi_inc.yoshi_walk_and_jump_off_roof_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const AnimFrame = o.header.gfx.animInfo.animFrame

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
	ObjBehaviors.object_step()
	ObjectHelpers.cur_obj_init_animation(1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oYoshiTargetYaw)), 0x500))

	if ObjBehaviors.is_point_close_to_object(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), 3174, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 200) ~= 0 then
		ObjectHelpers.cur_obj_init_animation(2)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_ENEMY_ALERT1)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, -0x3FFF)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_FINISH_JUMPING_AND_DESPAWN)
	end

	if AnimFrame == 0 or AnimFrame == 15 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_YOSHI_WALK)
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_finish_jumping_and_despawn_loop L131-143
function yoshi_inc.yoshi_finish_jumping_and_despawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_extend_animation_if_at_end()
	ObjBehaviors.obj_move_xyz_using_fvel_and_yaw(o)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - 2)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < 2100 then
		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		Camera.gObjCutsceneDone = IncludePRUltratypesH.TRUE
		ObjBehaviors.sYoshiDead = IncludePRUltratypesH.TRUE
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/yoshi.inc.c:yoshi_give_present_loop L145-159
function yoshi_inc.yoshi_give_present_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const GlobalTimer = GameInit.gGlobalTimer

	if LevelUpdate.gHudDisplay.lives == 100 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_COLLECT_1UP, Audio.gGlobalSoundSource)
		SaveFile.gSpecialTripleJump = IncludePRUltratypesH.TRUE
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.YOSHI_ACT_WALK_JUMP_OFF_ROOF)
		return
	end

	if bit32.band(GlobalTimer, 3) == 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_YOSHI_GAIN_LIVES, Audio.gGlobalSoundSource)
		LevelUpdate.gMarioState.numLives = S8(LevelUpdate.gMarioState.numLives + 1)
	end
end

-- from src/game/behaviors/yoshi.inc.c:bhv_yoshi_loop L161-193
function yoshi_inc.bhv_yoshi_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.YOSHI_ACT_IDLE then
		yoshi_inc.yoshi_idle_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_WALK then
		yoshi_inc.yoshi_walk_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_TALK then
		yoshi_inc.yoshi_talk_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_WALK_JUMP_OFF_ROOF then
		yoshi_inc.yoshi_walk_and_jump_off_roof_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_FINISH_JUMPING_AND_DESPAWN then
		yoshi_inc.yoshi_finish_jumping_and_despawn_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_GIVE_PRESENT then
		yoshi_inc.yoshi_give_present_loop()
	elseif Action == IncludeObjectConstantsH.YOSHI_ACT_CREDITS then
		ObjectHelpers.cur_obj_init_animation(0)
	end

	BobombInc.curr_obj_random_blink(o.rawData, IncludeObjectFieldsH.oYoshiBlinkTimer)
end

return yoshi_inc
