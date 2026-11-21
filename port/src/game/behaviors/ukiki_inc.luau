--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ukiki.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const IncludeSoundsH = require("../../../include/sounds_h")
const GameInit = require("../game_init")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const Interaction = require("../interaction")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const MetalBoxInc = require("./metal_box_inc")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const BehaviorIds = require("../../rom/behavior_ids")
const ObjectHelpersH = require("../object_helpers_h")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const Audio = require("../../rom/audio_recorder")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/ukiki_inc.luau:scratch
const Scratch = {
	geo_update_projectile_pos_from_parent_copy_mtx2 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
}

-- from src/game/behaviors/ukiki.inc.c:data
const ukiki_inc = {
	-- from src/game/behaviors/ukiki.inc.c:sCageUkikiPath L313-326
	sCageUkikiPath = {
		0, 1011, 2306, -285,
		0, 1151, 2304, -510,
		0, 1723, 1861, -964,
		0, 2082, 1775, -1128,
		0, 2489, 1717, -1141,
		0, 2662, 1694, -1140,
		0, 2902, 1536, -947,
		0, 2946, 1536, -467,
		0, 2924, 1536, 72,
		0, 2908, 1536, 536,
		0, 2886, 1536, 783,
		-1,
	},
	-- from src/game/behaviors/ukiki.inc.c:sUkikiSoundStates L436-450
	sUkikiSoundStates = {
		{
			playSound = 1,
			animFrame1 = 1,
			animFrame2 = 10,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_STEP_DEFAULT,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_CHATTER_SHORT,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_CHATTER_LONG,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_CHATTER_LONG,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_STEP_LEAVES,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_UKIKI_CHATTER_IDLE,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
	},
}

Registry.Register("src__game__behaviors__ukiki_inc", ukiki_inc)

-- from src/game/behaviors/ukiki.inc.c:handle_cap_ukiki_reset L13-22
function ukiki_inc.handle_cap_ukiki_reset()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.UKIKI_BP_CAP then
		if ObjectHelpers.cur_obj_mario_far_away() ~= 0 then
			ObjectHelpers.cur_obj_set_pos_to_home_and_stop()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_IDLE)
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_WAIT_TO_RESPAWN)
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:is_cap_ukiki_and_mario_has_normal_cap_on_head L28-35
function ukiki_inc.is_cap_ukiki_and_mario_has_normal_cap_on_head(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.UKIKI_BP_CAP and Interaction.does_mario_have_normal_cap_on_head(LevelUpdate.gMarioState) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/ukiki.inc.c:geo_update_projectile_pos_from_parent_copy L40-53
function ukiki_inc.geo_update_projectile_pos_from_parent_copy(run: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if run == IncludePRUltratypesH.TRUE then
		const obj = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const prevObj = obj.prevObj

		if prevObj ~= nil then
			ObjectHelpers.create_transformation_from_matrices(Scratch.geo_update_projectile_pos_from_parent_copy_mtx2, mtx, (Registry.Members.src__game__rendering_graph_node.gCurGraphNodeCamera.matrixPtr :: { { { number } } })[1])
			ObjectHelpers.obj_update_pos_from_parent_transformation(Scratch.geo_update_projectile_pos_from_parent_copy_mtx2, prevObj)
			ObjectHelpers.obj_set_gfx_pos_from_pos(prevObj)
		end
	end

	return nil
end

-- from src/game/behaviors/ukiki.inc.c:idle_ukiki_taunt L58-113
function ukiki_inc.idle_ukiki_taunt()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_NONE then
		-- Subaction is between 1 and 4.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 4) + 1))))

		-- Counter keeps track of the iterations done, while ToBeDone
		-- is the count of iterations to be done (between 2 and 5).
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter, 0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTauntsToBeDone, S16(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 4) + 2))))
	end

	-- Switch goes from 1-4.
	const SubAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_ITCH then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_ITCH)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_NONE)
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_SCREECH then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_SCREECH)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter) + 1))
		end

		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter) >= buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntsToBeDone) * 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_NONE)
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_JUMP_CLAP then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_JUMP_CLAP)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter) + 1))
		end

		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntCounter) >= buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTauntsToBeDone) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_NONE)
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_HANDSTAND then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_HANDSTAND)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_NONE)
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_idle L119-165
function ukiki_inc.ukiki_act_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ukiki_inc.idle_ukiki_taunt()

	if ukiki_inc.is_cap_ukiki_and_mario_has_normal_cap_on_head() ~= 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 700 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RUN)
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) <= 700 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 200 then
			if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) > 0x1000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_TURN_TO_MARIO)
			end
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 300 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RUN)
	end

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTextState) == IncludeObjectConstantsH.UKIKI_TEXT_GO_TO_CAGE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_GO_TO_CAGE)
	end

	-- Jump away from Mario after stealing his cap.
	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTextState) == IncludeObjectConstantsH.UKIKI_TEXT_STOLE_CAP then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))

		if MetalBoxInc.check_if_moving_over_floor(50, 150) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_JUMP)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000))

			if MetalBoxInc.check_if_moving_over_floor(50, 150) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_JUMP)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x4000))

				if MetalBoxInc.check_if_moving_over_floor(50, 150) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_JUMP)
				end
			end
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_HAS_CAP)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.UKIKI_BP_CAP then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < -1550 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RETURN_HOME)
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_return_home L171-182
function ukiki_inc.ukiki_act_return_home()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_RUN)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_angle_to_home())
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)

	-- If ukiki somehow walked home, go back to the idle action.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > -1550 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_IDLE)
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_wait_to_respawn L188-195
function ukiki_inc.ukiki_act_wait_to_respawn()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ukiki_inc.idle_ukiki_taunt()

	if ObjectHelpers.cur_obj_mario_far_away() ~= 0 then
		ObjectHelpers.cur_obj_set_pos_to_home_and_stop()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_IDLE)
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_unused_turn L203-209
function ukiki_inc.ukiki_act_unused_turn()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ukiki_inc.idle_ukiki_taunt()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.UKIKI_SUB_ACT_TAUNT_JUMP_CLAP then
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_turn_to_mario L214-237
function ukiki_inc.ukiki_act_turn_to_mario()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Initialize the action with a random fVel from 2-5.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(F32(SrcEngineBehaviorScript.random_float() * 3) + 2))
	end

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_TURN)

	const facingMario = ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x800)

	if facingMario ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_IDLE)
	end

	if ukiki_inc.is_cap_ukiki_and_mario_has_normal_cap_on_head() ~= 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 500 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RUN)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 300 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RUN)
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_run L242-281
function ukiki_inc.ukiki_act_run()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	local fleeMario = IncludePRUltratypesH.TRUE
	local goalYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000)

	if ukiki_inc.is_cap_ukiki_and_mario_has_normal_cap_on_head() ~= 0 then
		fleeMario = IncludePRUltratypesH.FALSE
		goalYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oUkikiChaseFleeRange, F32(SrcEngineBehaviorScript.random_float() * 100) + 350)
	end

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_RUN)
	ObjectHelpers.cur_obj_rotate_yaw_toward(goalYaw, 0x800)

	-- @bug (Ukikispeedia) This function sets forward speed to 0.9 * Mario's
	-- forward speed, which means ukiki can move at hyperspeed rates.
	ObjectHelpers.cur_obj_set_vel_from_mario_vel(20, F32(0.9))

	if fleeMario ~= 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oUkikiChaseFleeRange) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_TURN_TO_MARIO)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oUkikiChaseFleeRange) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_TURN_TO_MARIO)
	end

	if fleeMario ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) and ObjectHelpers.is_mario_moving_fast_or_in_air(10) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_JUMP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle))
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) and ObjectHelpers.is_mario_moving_fast_or_in_air(10) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_JUMP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_jump L287-308
function ukiki_inc.ukiki_act_jump()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
	ObjectHelpers.cur_obj_become_intangible()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.cur_obj_set_y_vel_and_animation(F32(F32(SrcEngineBehaviorScript.random_float() * 10) + 45), IncludeObjectConstantsH.UKIKI_ANIM_JUMP)
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE, IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_LAND)
		ObjectHelpers.cur_obj_become_tangible()

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_RUN)
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_act_go_to_cage L332-430
function ukiki_inc.ukiki_act_go_to_cage()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local latDistToCage = 0
	local yawToCage = 0
	const obj = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvUkikiCageChild)

	-- Ultimately is checking the cage, as it points to the parent
	-- of a dummy child object of the cage.
	if obj ~= nil then
		latDistToCage = ObjectHelpers.lateral_dist_between_objects(o, obj.parentObj :: GroupsTypesHPlus3.Object)
		yawToCage = S16(ObjectHelpers.obj_angle_to_object(o, obj.parentObj :: GroupsTypesHPlus3.Object))
	end

	ObjectHelpers.cur_obj_become_intangible()
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_ACTIVE_FROM_AFAR))

	-- Switch goes from 0-7 in order.
	const SubAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_RUN_TO_CAGE then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_RUN)

		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Rom.StaticS16Array("sCageUkikiPath", ukiki_inc.sCageUkikiPath)

		if ObjectHelpers.cur_obj_follow_path(0) ~= ObjectHelpersH.PATH_REACHED_END then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw)), 0x400)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_WAIT_FOR_MARIO or SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_TALK_TO_MARIO then
		-- The wait case falls through into the talk case when Mario activates the textbox.
		if SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_WAIT_FOR_MARIO then
			ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_JUMP_CLAP)
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)

			if ObjectHelpers.cur_obj_can_mario_activate_textbox(200, 30, 0x7FFF) == 0 then
				return
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end

		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_HANDSTAND)

		if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_DOWN, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_080) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_TURN_TO_CAGE then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_RUN)

		if ObjectHelpers.cur_obj_rotate_yaw_toward(yawToCage, 0x400) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_JUMP_TO_CAGE then
		ObjectHelpers.cur_obj_set_y_vel_and_animation(55, IncludeObjectConstantsH.UKIKI_ANIM_JUMP)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 36)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_LAND_ON_CAGE then
		if latDistToCage < 50 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		end

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			Audio.play_puzzle_jingle()
			ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.UKIKI_ANIM_JUMP_CLAP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiCageSpinTimer, 32)
			buffer.writei32(((obj :: GroupsTypesHPlus3.Object).parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oUkikiCageNextAction, IncludeObjectConstantsH.UKIKI_CAGE_ACT_SPIN)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_SPIN_ON_CAGE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x800))
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiCageSpinTimer, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiCageSpinTimer) - 1))

		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiCageSpinTimer) < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
			buffer.writei32(((obj :: GroupsTypesHPlus3.Object).parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oUkikiCageNextAction, IncludeObjectConstantsH.UKIKI_CAGE_ACT_FALL)
		end
	elseif SubAction == IncludeObjectConstantsH.UKIKI_SUB_ACT_CAGE_DESPAWN then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < -1300 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_free_loop L471-489
function ukiki_inc.ukiki_free_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(ukiki_inc.sUkikiActions)

	const steepSlopeAngleDegrees = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.UKIKI_ACT_GO_TO_CAGE or buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.UKIKI_ACT_RETURN_HOME then -88 else -20

	ObjectHelpers.cur_obj_move_standard(steepSlopeAngleDegrees)
	ukiki_inc.handle_cap_ukiki_reset()

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		SpawnSound.exec_anim_sound_state(ukiki_inc.sUkikiSoundStates)
	end
end

-- from src/game/behaviors/ukiki.inc.c:ukiki_blink_timer L497-503
function ukiki_inc.ukiki_blink_timer()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if GameInit.gGlobalTimer % 50 < 7 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.UKIKI_ANIM_STATE_EYE_CLOSED)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.UKIKI_ANIM_STATE_DEFAULT)
	end
end

-- from src/game/behaviors/ukiki.inc.c:cage_ukiki_held_loop L508-548
function ukiki_inc.cage_ukiki_held_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) > -100 then
		const TextState = buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTextState)

		if TextState == IncludeObjectConstantsH.UKIKI_TEXT_DEFAULT then
			if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
				GroupsIngameMenuPlus1.create_dialog_box_with_response(IncludeDialogIdsH.DIALOG_079)
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_CAGE_TEXTBOX)
			end
		elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_CAGE_TEXTBOX then
			if GroupsIngameMenuPlus1.gDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)

				if GroupsIngameMenuPlus1.gDialogResponse == GroupsIngameMenuPlus1.DIALOG_RESPONSE_YES then
					buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY))
					buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_GO_TO_CAGE)
				else
					buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_DO_NOT_LET_GO)
					buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextboxTimer, 60)
				end
			end
		elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_GO_TO_CAGE then
			-- Empty in the C source.
		elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_DO_NOT_LET_GO then
			-- Pester Mario with textboxes to discourage walking far.
			const TextboxTimer = buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTextboxTimer)

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextboxTimer, S16(TextboxTimer - 1))

			if TextboxTimer < 0 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_DEFAULT)
			end
		end
	else
		-- If ukiki is far below his home, stop him from trying to
		-- walk to the cage and getting stuck.
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_DEFAULT)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_WAIT_TO_RESPAWN)
	end
end

-- from src/game/behaviors/ukiki.inc.c:cap_ukiki_held_loop L553-588
function ukiki_inc.cap_ukiki_held_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const TextState = buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiTextState)

	if TextState == IncludeObjectConstantsH.UKIKI_TEXT_DEFAULT then
		if Interaction.mario_lose_cap_to_enemy(2) ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_STEAL_CAP)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap, S16(bit32.bor(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap), IncludeObjectConstantsH.UKIKI_CAP_ON)))
		end
	elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_STEAL_CAP then
		if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, IncludeDialogIdsH.DIALOG_100, 0) ~= 0 then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_STOLE_CAP)
		end
	elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_STOLE_CAP then
		-- Empty in the C source.
	elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_HAS_CAP then
		if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, bit32.bor(IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED), IncludeDialogIdsH.DIALOG_101, 0) ~= 0 then
			Interaction.mario_retrieve_cap()
			MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap, S16(bit32.band(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap), bit32.bnot(IncludeObjectConstantsH.UKIKI_CAP_ON))))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_GAVE_CAP_BACK)
		end
	elseif TextState == IncludeObjectConstantsH.UKIKI_TEXT_GAVE_CAP_BACK then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_DEFAULT)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_ACT_IDLE)
	end
end

-- from src/game/behaviors/ukiki.inc.c:bhv_ukiki_init L593-599
function ukiki_inc.bhv_ukiki_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.UKIKI_BP_CAP and bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_CAP_ON_UKIKI) then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextState, IncludeObjectConstantsH.UKIKI_TEXT_HAS_CAP)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap, S16(bit32.bor(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap), IncludeObjectConstantsH.UKIKI_CAP_ON)))
	end
end

-- from src/game/behaviors/ukiki.inc.c:bhv_ukiki_loop L605-640
function ukiki_inc.bhv_ukiki_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const HeldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if HeldState == IncludeObjectConstantsH.HELD_FREE then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUkikiTextboxTimer, 0)
		ukiki_inc.ukiki_free_loop()
	elseif HeldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(IncludeObjectConstantsH.UKIKI_ANIM_HELD, 0)
		ObjectHelpers.obj_copy_pos(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.UKIKI_BP_CAP then
			ukiki_inc.cap_ukiki_held_loop()
		else
			ukiki_inc.cage_ukiki_held_loop()
		end
	elseif HeldState == IncludeObjectConstantsH.HELD_THROWN or HeldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_dropped()
	end

	if bit32.btest(buffer.readi16(o.rawData, IncludeObjectFieldsH.oUkikiHasCap), IncludeObjectConstantsH.UKIKI_CAP_ON) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.UKIKI_ANIM_STATE_CAP_ON)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.UKIKI_ANIM_STATE_DEFAULT)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	-- print_debug_bottom_up x2: no call (debug-print-externals)
end

-- from src/game/behaviors/ukiki.inc.c:sUkikiActions L456-465
ukiki_inc.sUkikiActions = {
	ukiki_inc.ukiki_act_idle,
	ukiki_inc.ukiki_act_run,
	ukiki_inc.ukiki_act_turn_to_mario,
	ukiki_inc.ukiki_act_jump,
	ukiki_inc.ukiki_act_go_to_cage,
	ukiki_inc.ukiki_act_wait_to_respawn,
	ukiki_inc.ukiki_act_unused_turn,
	ukiki_inc.ukiki_act_return_home,
}

return ukiki_inc
