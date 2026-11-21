--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/whomp.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")
const BehaviorActions = require("../behavior_actions")
const BreakParticlesInc = require("./break_particles_inc")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")
const Area = require("../area")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeSm64H = require("../../../include/sm64_h")
const KingBobombInc = require("./king_bobomb_inc")
const LevelUpdate = require("../level_update")
const SpawnStarInc = require("./spawn_star_inc")

const SeqPlayerLevel = 0

const whomp_inc = {}

Registry.Register("src__game__behaviors__whomp_inc", whomp_inc)

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/whomp.inc.c:whomp_play_sfx_from_pound_animation L3-18
function whomp_inc.whomp_play_sfx_from_pound_animation()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local PlaySound = IncludePRUltratypesH.FALSE

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) < 5 then
		PlaySound = ObjectHelpers.cur_obj_check_anim_frame(0)
		PlaySound = S32(bit32.bor(PlaySound, ObjectHelpers.cur_obj_check_anim_frame(23)))
	else
		PlaySound = ObjectHelpers.cur_obj_check_anim_frame_in_range(0, 3)
		PlaySound = S32(bit32.bor(PlaySound, ObjectHelpers.cur_obj_check_anim_frame_in_range(23, 3)))
	end

	if PlaySound ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_POUNDING1)
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_init L20-44
function whomp_inc.whomp_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	ObjectHelpers.cur_obj_set_pos_to_home()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.WHOMP_BP_SMALL then
		Camera.gSecondCameraFocus = o
		ObjectHelpers.cur_obj_scale(2)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 600 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
				Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
			else
				ObjectHelpers.cur_obj_set_pos_to_home()
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 3)
			end
		elseif ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_114) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end

	whomp_inc.whomp_play_sfx_from_pound_animation()
end

-- from src/game/behaviors/whomp.inc.c:whomp_turn L46-63
function whomp_inc.whomp_turn()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 31 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x400))
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 42 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end

	whomp_inc.whomp_play_sfx_from_pound_animation()
end

-- from src/game/behaviors/whomp.inc.c:whomp_patrol L65-92
function whomp_inc.whomp_patrol()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioAngle = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	const DistWalked = ObjectHelpers.cur_obj_lateral_dist_to_home()
	const PatrolDist = if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BITS then 200 else 700

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3)

	if DistWalked > PatrolDist then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 7)
	elseif MarioAngle < 0x2000 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 9)
			ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 3)
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 300 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	end

	whomp_inc.whomp_play_sfx_from_pound_animation()
end

-- from src/game/behaviors/whomp.inc.c:king_whomp_chase L94-118
function whomp_inc.king_whomp_chase()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3)
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		const MarioAngle = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

		if MarioAngle < 0x2000 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 9)
				ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 3)
			end

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 300 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
			end
		end
	end

	whomp_inc.whomp_play_sfx_from_pound_animation()

	if KingBobombInc.mario_is_far_below_object(1000) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_prepare_jump L120-126
function whomp_inc.whomp_prepare_jump()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(1, 1)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_jump L128-143
function whomp_inc.whomp_jump()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 8 then
		-- Empty in the C source.
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + 0x100))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x4000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		end
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_land L145-156
function whomp_inc.whomp_land()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_WHOMP)
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 6)
	end
end

-- from src/game/behaviors/whomp.inc.c:king_whomp_on_ground L158-190
function whomp_inc.king_whomp_on_ground()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if ObjectHelpers.cur_obj_is_mario_ground_pounding_platform() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1))
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_WHOMP_SOUND_SHORT)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_WHOMP_DEATH)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 8)
			else
				-- vec3f_copy_2(pos, &o->oPosX): the object's position, saved
				const PosX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
				const PosY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
				const PosZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

				-- vec3f_copy_2(&o->oPosX, &gMarioObject->oPosX)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ))

				BehaviorActions.spawn_mist_particles_variable(0, 0, 100)
				BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3, 4)
				ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)

				-- vec3f_copy_2(&o->oPosX, pos)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, PosX)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, PosY)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, PosZ)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhompShakeVal, 0)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhompShakeVal) < 10 then
			if math.fmod(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhompShakeVal), 2) ~= 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 8)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 8)
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 10)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhompShakeVal, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhompShakeVal) + 1))
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_on_ground L192-207
function whomp_inc.whomp_on_ground()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if MarioObject.platform == o then
			if ObjectHelpers.cur_obj_is_mario_ground_pounding_platform() ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 5)
				ObjectHelpers.obj_spawn_loot_yellow_coins(o, 5, 20)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 8)
			else
				ObjectHelpers.cur_obj_spawn_loot_coin_at_mario_pos()
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			end
		end
	elseif ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_on_ground_general L209-236
function whomp_inc.whomp_on_ground_general()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) ~= 10 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.WHOMP_BP_SMALL then
			whomp_inc.king_whomp_on_ground()
		else
			whomp_inc.whomp_on_ground()
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 or (LevelUpdate.gMarioState.action == IncludeSm64H.ACT_SQUISHED and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 10)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, -0x200)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.WHOMP_BP_SMALL then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/whomp.inc.c:whomp_die L238-260
function whomp_inc.whomp_die()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.WHOMP_BP_SMALL then
		if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_115) ~= 0 then
			ObjectHelpers.obj_set_angle(o, 0, 0, 0)
			ObjectHelpers.cur_obj_hide()
			ObjectHelpers.cur_obj_become_intangible()
			BehaviorActions.spawn_mist_particles_variable(0, 0, 200)
			BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3, 4)
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 100)
			SpawnStarInc.spawn_default_star(180, 3880, 340)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_WHOMP_DEATH)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 9)
		end
	else
		BehaviorActions.spawn_mist_particles_variable(0, 0, 100)
		BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3, 4)
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_THWOMP)
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/whomp.inc.c:king_whomp_stop_music L262-266
function whomp_inc.king_whomp_stop_music()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
	end
end

-- from src/game/behaviors/whomp.inc.c:bhv_whomp_loop L280-292
function whomp_inc.bhv_whomp_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(whomp_inc.sWhompActions)
	ObjectHelpers.cur_obj_move_standard(-20)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= 9 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.WHOMP_BP_SMALL then
			ObjectHelpers.cur_obj_hide_if_mario_far_away_y(2000)
		else
			ObjectHelpers.cur_obj_hide_if_mario_far_away_y(1000)
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

-- from src/game/behaviors/whomp.inc.c:sWhompActions L268-278
whomp_inc.sWhompActions = {
	whomp_inc.whomp_init,
	whomp_inc.whomp_patrol,
	whomp_inc.king_whomp_chase,
	whomp_inc.whomp_prepare_jump,
	whomp_inc.whomp_jump,
	whomp_inc.whomp_land,
	whomp_inc.whomp_on_ground_general,
	whomp_inc.whomp_turn,
	whomp_inc.whomp_die,
	whomp_inc.king_whomp_stop_music,
}

return whomp_inc
