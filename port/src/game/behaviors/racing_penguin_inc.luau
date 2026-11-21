--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/racing_penguin.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const KoopaInc = require("./koopa_inc")
const LevelUpdate = require("../level_update")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const TuxieInc = require("./tuxie_inc")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const Memory = require("../memory")
const SegmentSymbols = require("../../rom/segment_symbols")

-- from src/game/behaviors/racing_penguin.inc.c:RacingPenguinData
export type RacingPenguinData = {
	dialogID: number,
	radius: number,
	height: number,
}

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

-- from src/game/behaviors/racing_penguin_inc.luau:scratch
const Scratch = {
	racing_penguin_act_race_targetSpeed = buffer.create(4),
}

-- from src/game/behaviors/racing_penguin.inc.c:data
const racing_penguin_inc = {
	-- from src/game/behaviors/racing_penguin.inc.c:sRacingPenguinData L9-12
	sRacingPenguinData = {
		{ dialogID = IncludeDialogIdsH.DIALOG_055, radius = 200.0, height = 200.0 },
		{ dialogID = IncludeDialogIdsH.DIALOG_164, radius = 350.0, height = 250.0 },
	},
}

Registry.Register("src__game__behaviors__racing_penguin_inc", racing_penguin_inc)

-- from src/game/behaviors/racing_penguin.inc.c:RacingPenguinData (zero-filled constructor)
function racing_penguin_inc.new_RacingPenguinData(): RacingPenguinData
	return { dialogID = 0, radius = 0, height = 0 } :: RacingPenguinData
end

-- from src/game/behaviors/racing_penguin.inc.c:bhv_racing_penguin_init L14-20
function racing_penguin_inc.bhv_racing_penguin_init()
	if LevelUpdate.gMarioState.numStars == 120 then
		ObjectHelpers.cur_obj_scale(8.0)
		const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
		o.header.gfx.scale[2] = 5.0
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.RACING_PENGUIN_BP_FAT)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_wait_for_mario L22-27
function racing_penguin_inc.racing_penguin_act_wait_for_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oRacingPenguinInitTextCooldown) and F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosY)) <= 0.0 and ObjectHelpers.cur_obj_can_mario_activate_textbox_2(400.0, 400.0) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_SHOW_INIT_TEXT)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_show_init_text L29-51
function racing_penguin_inc.racing_penguin_act_show_init_text()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const response: number = ObjBehaviors2.obj_update_race_proposition_dialog(racing_penguin_inc.sRacingPenguinData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1].dialogID)

	if response == GroupsIngameMenuPlus1.DIALOG_RESPONSE_YES then
		local child = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvPenguinRaceFinishLine) :: GroupsTypesHPlus3.Object

		child.parentObj = o
		child = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvPenguinRaceShortcutCheck) :: GroupsTypesHPlus3.Object
		child.parentObj = o
		o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.ccm_seg7_trajectory_penguin_race)
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_PREPARE_FOR_RACE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 60.0)
	elseif response == GroupsIngameMenuPlus1.DIALOG_RESPONSE_NO then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_WAIT_FOR_MARIO)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oRacingPenguinInitTextCooldown, 60)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_prepare_for_race L53-60
function racing_penguin_inc.racing_penguin_act_prepare_for_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if KoopaInc.obj_begin_race(IncludePRUltratypesH.TRUE) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_RACE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	end

	ObjectHelpers.cur_obj_rotate_yaw_toward(0x4000, 2500)
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_race L62-101
function racing_penguin_inc.racing_penguin_act_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_follow_path(0) == ObjectHelpersH.PATH_REACHED_END then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinReachedBottom, IncludePRUltratypesH.TRUE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_FINISH_RACE)
	else
		local targetSpeed = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosY))
		local minSpeed = 70.0

		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_ROUGH_SLIDE)

		if targetSpeed < 100.0 or bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags), ObjectHelpersH.WAYPOINT_MASK_00FF) >= 35 then
			if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags), ObjectHelpersH.WAYPOINT_MASK_00FF) >= 35 then
				minSpeed = 60.0
			end

			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oRacingPenguinWeightedNewTargetSpeed, -500.0, 100.0)
		else
			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oRacingPenguinWeightedNewTargetSpeed, 1000.0, 30.0)
		end

		targetSpeed = F32(F32(0.1) * F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oRacingPenguinWeightedNewTargetSpeed) + targetSpeed))
		buffer.writef32(Scratch.racing_penguin_act_race_targetSpeed, 0, targetSpeed)
		ObjBehaviors2.clamp_f32(Scratch.racing_penguin_act_race_targetSpeed, 0, minSpeed, 150.0)
		targetSpeed = buffer.readf32(Scratch.racing_penguin_act_race_targetSpeed, 0)
		ObjBehaviors2.obj_forward_vel_approach(targetSpeed, F32(0.4))

		ObjectHelpers.cur_obj_init_animation_with_sound(1)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw)), S16(TruncS32(F32(15.0 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)))))

		if ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
			ObjectHelpers.spawn_object_relative_with_scale(0, 0, -100, 0, 4.0, o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2)
		end
	end

	if ObjectHelpers.mario_is_in_air_action() ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioCheated, IncludePRUltratypesH.TRUE)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_finish_race L103-113
function racing_penguin_inc.racing_penguin_act_finish_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0.0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_POUNDING_LOUD)
			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end
	elseif ObjBehaviors2.cur_obj_init_anim_and_check_if_end(2) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.RACING_PENGUIN_ACT_SHOW_FINAL_TEXT)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:racing_penguin_act_show_final_text L115-157
function racing_penguin_inc.racing_penguin_act_show_final_text()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox) == 0 then
		if ObjectHelpers.cur_obj_rotate_yaw_toward(0, 200) ~= 0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(3)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			if ObjectHelpers.cur_obj_can_mario_activate_textbox_2(400.0, 400.0) ~= 0 then
				if buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioWon) ~= 0 then
					if buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioCheated) ~= 0 then
						buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox, IncludeDialogIdsH.DIALOG_132)
						buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioWon, 0)
					else
						buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox, IncludeDialogIdsH.DIALOG_056)
					end
				else
					buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox, IncludeDialogIdsH.DIALOG_037)
				end
			end
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(0)
			TuxieInc.play_penguin_walking_sound(1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 4.0)
		end
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox) > 0 then
		const textResult = ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox))
		if textResult ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinFinalTextbox, -1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioWon) ~= 0 then
		ObjectHelpers.cur_obj_spawn_star_at_y_offset(-7339.0, -5700.0, -6774.0, 200.0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oRacingPenguinMarioWon, 0)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:bhv_racing_penguin_update L159-187
function racing_penguin_inc.bhv_racing_penguin_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_WAIT_FOR_MARIO then
		racing_penguin_inc.racing_penguin_act_wait_for_mario()
	elseif action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_SHOW_INIT_TEXT then
		racing_penguin_inc.racing_penguin_act_show_init_text()
	elseif action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_PREPARE_FOR_RACE then
		racing_penguin_inc.racing_penguin_act_prepare_for_race()
	elseif action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_RACE then
		racing_penguin_inc.racing_penguin_act_race()
	elseif action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_FINISH_RACE then
		racing_penguin_inc.racing_penguin_act_finish_race()
	elseif action == IncludeObjectConstantsH.RACING_PENGUIN_ACT_SHOW_FINAL_TEXT then
		racing_penguin_inc.racing_penguin_act_show_final_text()
	end

	ObjectHelpers.cur_obj_move_standard(78)
	ObjectHelpers.cur_obj_align_gfx_with_floor()

	const penguinData = racing_penguin_inc.sRacingPenguinData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]
	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(penguinData.radius, penguinData.height)
end

-- from src/game/behaviors/racing_penguin.inc.c:bhv_penguin_race_finish_line_update L189-195
function racing_penguin_inc.bhv_penguin_race_finish_line_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if (buffer.readi16(parentObj.rawData, IncludeObjectFieldsH.oRacingPenguinReachedBottom) ~= 0 or (buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 and F32(buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) < 0.0)) and buffer.readi16(parentObj.rawData, IncludeObjectFieldsH.oRacingPenguinReachedBottom) == 0 then
		buffer.writei16(parentObj.rawData, IncludeObjectFieldsH.oRacingPenguinMarioWon, IncludePRUltratypesH.TRUE)
	end
end

-- from src/game/behaviors/racing_penguin.inc.c:bhv_penguin_race_shortcut_check_update L197-201
function racing_penguin_inc.bhv_penguin_race_shortcut_check_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
		buffer.writei16(parentObj.rawData, IncludeObjectFieldsH.oRacingPenguinMarioCheated, IncludePRUltratypesH.TRUE)
	end
end

return racing_penguin_inc
