--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/king_bobomb.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorActions = require("../behavior_actions")
const BreakParticlesInc = require("./break_particles_inc")
const Camera = require("../camera")
const ChuckyaInc = require("./chuckya_inc")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const InteractionH = require("../interaction_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const RenderingGraphNode = require("../rendering_graph_node")
const GrandStarInc = require("./grand_star_inc")

const SeqPlayerLevel = 0

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/king_bobomb_inc.luau:scratch
const Scratch = {
	geo_update_held_mario_pos_sp20 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
	king_bobomb_act_5_home = { 0, 0, 0 },
	king_bobomb_act_5_pos = { 0, 0, 0 },
}

-- from src/game/behaviors/king_bobomb.inc.c:data
const king_bobomb_inc = {
	-- from src/game/behaviors/king_bobomb.inc.c:sKingBobombSoundStates L342-355
	sKingBobombSoundStates = {
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 1,
			animFrame2 = 20,
			soundMagic = IncludeSoundsH.SOUND_OBJ_POUNDING1_HIGHPRIO,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 15,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_POUNDING1_HIGHPRIO,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 33,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_POUNDING1_HIGHPRIO,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 1,
			animFrame2 = 15,
			soundMagic = IncludeSoundsH.SOUND_OBJ_POUNDING1_HIGHPRIO,
		},
	},
}

Registry.Register("src__game__behaviors__king_bobomb_inc", king_bobomb_inc)

-- from src/game/behaviors/king_bobomb.inc.c:geo_update_held_mario_pos L4-16
function king_bobomb_inc.geo_update_held_mario_pos(run: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if run == IncludePRUltratypesH.TRUE then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object

		if obj.prevObj ~= nil then
			const prevObj = obj.prevObj :: GroupsTypesHPlus3.Object
			const cameraNode = RenderingGraphNode.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera
			const cameraMatrix = cameraNode.matrixPtr :: { { { number } } }

			ObjectHelpers.create_transformation_from_matrices(Scratch.geo_update_held_mario_pos_sp20, mtx, cameraMatrix[1])
			ObjectHelpers.obj_update_pos_from_parent_transformation(Scratch.geo_update_held_mario_pos_sp20, prevObj)
			ObjectHelpers.obj_set_gfx_pos_from_pos(prevObj)
		end
	end

	return nil
end

-- from src/game/behaviors/king_bobomb.inc.c:bhv_bobomb_anchor_mario_loop L18-20
function king_bobomb_inc.bhv_bobomb_anchor_mario_loop()
	ChuckyaInc.common_anchor_mario_behavior(50.0, 50.0, InteractionH.INT_STATUS_MARIO_UNK6)
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_0 L22-44
function king_bobomb_inc.king_bobomb_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		ObjectHelpers.cur_obj_become_intangible()
		Camera.gSecondCameraFocus = o
		ObjectHelpers.cur_obj_init_animation_with_sound(5)
		ObjectHelpers.cur_obj_set_pos_to_home()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 3)

		if ObjectHelpers.cur_obj_can_mario_activate_textbox_2(500.0, 100.0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
		end
	elseif ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_017) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_HOLDABLE)))
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:mario_is_far_below_object L46-52
function king_bobomb_inc.mario_is_far_below_object(arg0: number): number
	arg0 = F32(arg0)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if arg0 < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY)) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_2 L54-95
function king_bobomb_inc.king_bobomb_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_tangible()

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) < -100.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		ObjectHelpers.cur_obj_become_intangible()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk100) == 0 then
		if ObjectHelpers.cur_obj_check_anim_frame(15) ~= 0 then
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		end

		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(4) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk100, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk100) + 1))
		end
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk100) == 1 then
			ObjectHelpers.cur_obj_init_animation_and_anim_frame(11, 7)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk100, 2)
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(11)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk108) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x100)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk108, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk108) - 1))
		end
	end

	if ObjectHelpers.cur_obj_check_grabbed_mario() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	if king_bobomb_inc.mario_is_far_below_object(1200.0) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_3 L97-143
function king_bobomb_inc.king_bobomb_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkFC, 0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN3)
		end

		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			ObjectHelpers.cur_obj_init_animation_and_anim_frame(1, 0)
		end
	elseif subAction == 1 then
		ObjectHelpers.cur_obj_init_animation_with_sound(1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkFC, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkFC) + ObjectHelpers.player_performed_grab_escape_action()))

		-- print_debug_bottom_up("%d", ...): debug print, dropped

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkFC) > 10 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk88, 3)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk108, 35)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_GRABBED_MARIO))))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104) > 20 and ObjectHelpers.cur_obj_rotate_yaw_toward(0, 0x400) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
				ObjectHelpers.cur_obj_init_animation_and_anim_frame(9, 22)
			end
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104) + 1))
	else
		ObjectHelpers.cur_obj_init_animation_with_sound(9)

		if ObjectHelpers.cur_obj_check_anim_frame(31) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk88, 2)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN4)
		elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_GRABBED_MARIO))))
		end
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_1 L145-161
function king_bobomb_inc.king_bobomb_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

	ObjectHelpers.cur_obj_init_animation_with_sound(11)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if king_bobomb_inc.mario_is_far_below_object(1200.0) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_6 L163-199
function king_bobomb_inc.king_bobomb_act_6()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104, 0)

			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_KING_BOBOMB_DAMAGE)
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
			BehaviorActions.spawn_mist_particles_variable(0, 0, 100.0)

			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_DAMAGE)

			ObjectHelpers.cur_obj_become_tangible()
		end

		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(2) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104) + 1))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk104) > 3 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 1 then
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(10) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_GRABBABLE)

			ObjectHelpers.cur_obj_become_intangible()
		end
	else
		ObjectHelpers.cur_obj_init_animation_with_sound(11)

		if ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x800) == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_7 L201-223
function king_bobomb_inc.king_bobomb_act_7()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(2)

	if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_116) ~= 0 then
		Registry.Members.src__game__spawn_sound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_KING_WHOMP_DEATH)

		ObjectHelpers.cur_obj_hide()
		ObjectHelpers.cur_obj_become_intangible()

		BehaviorActions.spawn_mist_particles_variable(0, 0, 200.0)
		BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3.0, 4)
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)

		ObjectHelpers.cur_obj_spawn_star_at_y_offset(2000.0, 4500.0, -4500.0, 200.0)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 8)
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_8 L225-229
function king_bobomb_inc.king_bobomb_act_8()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_4 L231-263
function king_bobomb_inc.king_bobomb_act_4()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) > -100.0 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 6)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 7)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB)
		end
	else
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(10) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_act_5 L265-328
function king_bobomb_inc.king_bobomb_act_5()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB_JUMP)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkF8, 1)

		ObjectHelpers.cur_obj_init_animation_and_extend_if_at_end(8)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_angle_to_home())

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 100.0)
		else
			Scratch.king_bobomb_act_5_home[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX)
			Scratch.king_bobomb_act_5_home[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)
			Scratch.king_bobomb_act_5_home[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ)
			Scratch.king_bobomb_act_5_pos[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
			Scratch.king_bobomb_act_5_pos[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
			Scratch.king_bobomb_act_5_pos[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
			GrandStarInc.arc_to_goal_pos(Scratch.king_bobomb_act_5_home, Scratch.king_bobomb_act_5_pos, 100.0, -4.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif subAction == 1 then
		ObjectHelpers.cur_obj_init_animation_and_extend_if_at_end(8)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkF8, 0)

			ObjectHelpers.cur_obj_init_animation_with_sound(7)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB)
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif subAction == 2 then
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(7) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif subAction == 3 then
		if king_bobomb_inc.mario_is_far_below_object(1200.0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
			Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
		end

		if ObjectHelpers.cur_obj_can_mario_activate_textbox_2(500.0, 100.0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif subAction == 4 then
		if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_128) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:king_bobomb_move L357-374
function king_bobomb_inc.king_bobomb_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKingBobombUnkF8) == 0 then
		ObjectHelpers.cur_obj_move_standard(-78)
	else
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end

	ObjectHelpers.cur_obj_call_action_function(king_bobomb_inc.sKingBobombActions)
	Registry.Members.src__game__spawn_sound.exec_anim_sound_state(king_bobomb_inc.sKingBobombSoundStates)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 5000.0 then
		ObjectHelpers.cur_obj_enable_rendering()
	else
		ObjectHelpers.cur_obj_disable_rendering()
	end
end

-- from src/game/behaviors/king_bobomb.inc.c:bhv_king_bobomb_loop L376-399
function king_bobomb_inc.bhv_king_bobomb_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO)))

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		king_bobomb_inc.king_bobomb_move()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(6, 1)
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN or heldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_thrown_or_placed(20.0, 50.0, 4)
		ObjectHelpers.cur_obj_become_intangible()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 20.0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/king_bobomb.inc.c:sKingBobombActions L330-340
king_bobomb_inc.sKingBobombActions = {
	king_bobomb_inc.king_bobomb_act_0,
	king_bobomb_inc.king_bobomb_act_1,
	king_bobomb_inc.king_bobomb_act_2,
	king_bobomb_inc.king_bobomb_act_3,
	king_bobomb_inc.king_bobomb_act_4,
	king_bobomb_inc.king_bobomb_act_5,
	king_bobomb_inc.king_bobomb_act_6,
	king_bobomb_inc.king_bobomb_act_7,
	king_bobomb_inc.king_bobomb_act_8,
}

return king_bobomb_inc
