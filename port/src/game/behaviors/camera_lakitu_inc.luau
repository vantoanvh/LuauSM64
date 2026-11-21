--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/camera_lakitu.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")

const SeqPlayerLevel = 0

const camera_lakitu_inc = {}

Registry.Register("src__game__behaviors__camera_lakitu_inc", camera_lakitu_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/camera_lakitu.inc.c:bhv_camera_lakitu_init L13-22
function camera_lakitu_inc.bhv_camera_lakitu_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.CAMERA_LAKITU_BP_FOLLOW_CAMERA then
		-- Despawn unless this is the very beginning of the game
		if LevelUpdate.gNeverEnteredCastle ~= IncludePRUltratypesH.TRUE then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	else
		ObjectHelpers.spawn_object_relative_with_scale(IncludeObjectConstantsH.CLOUD_BP_LAKITU_CLOUD, 0, 0, 0, 2.0, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvCloud)
	end
end

-- from src/game/behaviors/camera_lakitu.inc.c:camera_lakitu_intro_act_trigger_cutscene L28-37
function camera_lakitu_inc.camera_lakitu_intro_act_trigger_cutscene()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX) > -544.0 and buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX) < 545.0 and buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY) > 800.0 and buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) > -2000.0 and buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) < -177.0 and buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) <= -177.0 and MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_START then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CAMERA_LAKITU_INTRO_ACT_SPAWN_CLOUD)
	end
end

-- from src/game/behaviors/camera_lakitu.inc.c:camera_lakitu_intro_act_spawn_cloud L42-56
function camera_lakitu_inc.camera_lakitu_intro_act_spawn_cloud()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CAMERA_LAKITU_INTRO_ACT_UNK2)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 1800.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 2400.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, -2400.0)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x4000)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed, 60.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCameraLakituCircleRadius, 1000.0)

		ObjectHelpers.spawn_object_relative_with_scale(IncludeObjectConstantsH.CLOUD_BP_LAKITU_CLOUD, 0, 0, 0, 2.0, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvCloud)
	end
end

-- from src/game/behaviors/camera_lakitu.inc.c:camera_lakitu_intro_act_show_dialog L61-134
function camera_lakitu_inc.camera_lakitu_intro_act_show_dialog()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local TargetMovePitch = 0
	local TargetMoveYaw = 0

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_LAKITU_FLY)

	-- Face toward mario
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, ObjBehaviors2.obj_turn_pitch_toward_mario(120.0, 0))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))

	-- After finishing dialog, fly away and despawn
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCameraLakituFinishedDialog) ~= 0 then
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed, 60.0, 3.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 6000.0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		TargetMovePitch = -0x3000
		TargetMoveYaw = -0x6000
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed) ~= 0.0 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 5000.0 then
				TargetMovePitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
				TargetMoveYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			else
				-- Stay moving in a circle around mario
				local TurnAmount = S16(0x4000 - SrcEngineMathUtil.atan2s(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCameraLakituCircleRadius), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oCameraLakituCircleRadius))))

				if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) < 0 then
					TurnAmount = S16(-TurnAmount)
				end

				TargetMoveYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + TurnAmount)
				TargetMovePitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))

				ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oCameraLakituCircleRadius, 200.0, 50.0)

				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCameraLakituUnk104) == 0 then
						Audio.play_music(SeqPlayerLevel, bit32.bor(bit32.lshift(15, 8), IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_LAKITU), 0)
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oCameraLakituUnk104, IncludePRUltratypesH.TRUE)
					end

					-- Once within 1000 units, slow down
					ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed, 20.0, 1.0)

					if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(marioObject.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) > 0x7000 then
						-- Once within 500 units and facing toward mario, come
						-- to a stop
						ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed, 0.0, 5.0)
					end
				end
			end
		elseif ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_034) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCameraLakituFinishedDialog, IncludePRUltratypesH.TRUE)
		end
	end

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oCameraLakituPitchVel, S16(ObjectHelpers.approach_s16_symmetric(buffer.readi16(o.rawData, IncludeObjectFieldsH.oCameraLakituPitchVel), 2000, 400)))
	ObjBehaviors2.obj_move_pitch_approach(TargetMovePitch, buffer.readi16(o.rawData, IncludeObjectFieldsH.oCameraLakituPitchVel))

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oCameraLakituYawVel, S16(ObjectHelpers.approach_s16_symmetric(buffer.readi16(o.rawData, IncludeObjectFieldsH.oCameraLakituYawVel), 2000, 100)))
	ObjectHelpers.cur_obj_rotate_yaw_toward(TargetMoveYaw, buffer.readi16(o.rawData, IncludeObjectFieldsH.oCameraLakituYawVel))

	-- vel y is explicitly computed, so gravity doesn't apply
	ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCameraLakituSpeed))
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/camera_lakitu.inc.c:bhv_camera_lakitu_update L139-178
function camera_lakitu_inc.bhv_camera_lakitu_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oCameraLakituBlinkTimer, 20, 40, 4)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.CAMERA_LAKITU_BP_FOLLOW_CAMERA then
			const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

			if action == IncludeObjectConstantsH.CAMERA_LAKITU_INTRO_ACT_TRIGGER_CUTSCENE then
				camera_lakitu_inc.camera_lakitu_intro_act_trigger_cutscene()
			elseif action == IncludeObjectConstantsH.CAMERA_LAKITU_INTRO_ACT_SPAWN_CLOUD then
				camera_lakitu_inc.camera_lakitu_intro_act_spawn_cloud()
			elseif action == IncludeObjectConstantsH.CAMERA_LAKITU_INTRO_ACT_UNK2 then
				camera_lakitu_inc.camera_lakitu_intro_act_show_dialog()
			end
		else
			const Val0C = F32(F32(4331.53) - Camera.gLakituState.curPos[1])

			if Camera.gLakituState.curPos[1] < 1700.0 or Val0C < 0.0 then
				ObjectHelpers.cur_obj_hide()
			else
				ObjectHelpers.cur_obj_unhide()

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Camera.gLakituState.curPos[1])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Camera.gLakituState.curPos[2])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Camera.gLakituState.curPos[3])

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, Camera.gLakituState.curFocus[1])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, Camera.gLakituState.curFocus[3])

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, -ObjectHelpers.cur_obj_angle_to_home())
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, SrcEngineMathUtil.atan2s(ObjectHelpers.cur_obj_lateral_dist_to_home(), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - Camera.gLakituState.curFocus[2])))

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(4331.53) + Val0C)
			end
		end
	end
end

return camera_lakitu_inc
