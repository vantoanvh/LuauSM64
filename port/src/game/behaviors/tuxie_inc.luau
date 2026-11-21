--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tuxie.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const GameInit = require("../game_init")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const InteractionH = require("../interaction_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const Memory = require("../memory")
const ObjectListProcessor = require("../object_list_processor")
const RenderingGraphNode = require("../rendering_graph_node")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const tuxie_inc = {}

Registry.Register("src__game__behaviors__tuxie_inc", tuxie_inc)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/tuxie_inc.luau:scratch
const Scratch = {
	tuxies_mother_act_2_sp24 = { 0 },
	tuxies_mother_act_0_sp28 = { 0 },
}

-- from src/game/behaviors/tuxie.inc.c:play_penguin_walking_sound L3-14
function tuxie_inc.play_penguin_walking_sound(walk: number)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID) == 0 then
		local Sound: number

		if walk == IncludeObjectConstantsH.PENGUIN_WALK_BABY then
			Sound = IncludeSoundsH.SOUND_OBJ_BABY_PENGUIN_WALK
		else
			-- PENGUIN_WALK_BIG
			Sound = IncludeSoundsH.SOUND_OBJ_BIG_PENGUIN_WALK
		end

		BehaviorActions.set_obj_anim_with_accel_and_sound(1, 11, Sound)
	end
end

-- from src/game/behaviors/tuxie.inc.c:tuxies_mother_act_2 L16-46
function tuxie_inc.tuxies_mother_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const SmallPenguin = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvSmallPenguin, Scratch.tuxies_mother_act_2_sp24)
	const Sp24 = Scratch.tuxies_mother_act_2_sp24[1]

	if ObjectHelpers.cur_obj_find_nearby_held_actor(BehaviorIds.bhvUnused20E0, 1000.0) ~= nil then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)

			if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 800.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
			end

			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			ObjectHelpers.cur_obj_init_animation_with_sound(3)

			if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() < 700.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
			end
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(3)
	end

	if SmallPenguin ~= nil and Sp24 < 300.0 and buffer.readi32(SmallPenguin.rawData, IncludeObjectFieldsH.oHeldState) ~= IncludeObjectConstantsH.HELD_FREE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writei32(SmallPenguin.rawData, IncludeObjectFieldsH.oSmallPenguinUnk88, IncludePRUltratypesH.TRUE)
		o.prevObj = SmallPenguin
	end
end

-- from src/game/behaviors/tuxie.inc.c:tuxies_mother_act_1 L48-106
function tuxie_inc.tuxies_mother_act_1()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const PrevObj = o.prevObj :: GroupsTypesHPlus3.Object
	const SubAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if SubAction == 0 then
		ObjectHelpers.cur_obj_init_animation_with_sound(3)

		if ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
			const sp2C = S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2^16, 0xFF))
			const sp28 = S32(bit32.band(buffer.readi32(PrevObj.rawData, IncludeObjectFieldsH.oBhvParams) // 2^16, 0xFF))
			local dialogID: number

			if sp2C == sp28 then
				dialogID = IncludeDialogIdsH.DIALOG_058
			else
				dialogID = IncludeDialogIdsH.DIALOG_059
			end

			if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, dialogID) ~= 0 then
				if dialogID == IncludeDialogIdsH.DIALOG_058 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 2)
				end

				buffer.writeu32(PrevObj.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.bor(buffer.readu32(PrevObj.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY)))
			end
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(0)
		end
	elseif SubAction == 1 then
		if buffer.readu32(PrevObj.rawData, IncludeObjectFieldsH.oHeldState) == IncludeObjectConstantsH.HELD_FREE then
			-- The C indexes prevObj's rawData with the value of o's oInteractionSubtype (a word index), not with the field's offset.
			const flagOffset = buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype) * 4

			buffer.writei32(PrevObj.rawData, flagOffset, S32(bit32.band(buffer.readi32(PrevObj.rawData, flagOffset), bit32.bnot(InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY))))
			ObjectHelpers.obj_set_behavior(PrevObj, BehaviorIds.bhvUnused20E0)

			ObjectHelpers.cur_obj_spawn_star_at_y_offset(3167.0, -4300.0, 5108.0, 200.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	elseif SubAction == 2 then
		if buffer.readu32(PrevObj.rawData, IncludeObjectFieldsH.oHeldState) == IncludeObjectConstantsH.HELD_FREE then
			-- Same index use as in case 1.
			const flagOffset = buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype) * 4

			buffer.writei32(PrevObj.rawData, flagOffset, S32(bit32.band(buffer.readi32(PrevObj.rawData, flagOffset), bit32.bnot(InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY))))
			ObjectHelpers.obj_set_behavior(PrevObj, BehaviorIds.bhvPenguinBaby)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	end
end

-- from src/game/behaviors/tuxie.inc.c:tuxies_mother_act_0 L108-148
function tuxie_inc.tuxies_mother_act_0()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local sp2C = IncludePRUltratypesH.FALSE
	const sp24 = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvSmallPenguin, Scratch.tuxies_mother_act_0_sp28)
	const sp28 = Scratch.tuxies_mother_act_0_sp28[1]

	ObjectHelpers.cur_obj_scale(4.0)
	ObjectHelpers.cur_obj_init_animation_with_sound(3)

	if sp28 < 500.0 then
		sp2C = IncludePRUltratypesH.TRUE
	end

	if sp24 ~= nil and sp28 < 300.0 and buffer.readu32(sp24.rawData, IncludeObjectFieldsH.oHeldState) ~= IncludeObjectConstantsH.HELD_FREE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writei32(sp24.rawData, IncludeObjectFieldsH.oSmallPenguinUnk88, IncludePRUltratypesH.TRUE)
		o.prevObj = sp24
	else
		const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

		if subAction == 0 then
			if ObjectHelpers.cur_obj_can_mario_activate_textbox_2(300.0, 100.0) ~= 0 and sp2C == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			end
		elseif subAction == 1 then
			if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_057) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			end
		elseif subAction == 2 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 450.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
			end
		end
	end

	if ObjectHelpers.cur_obj_check_anim_frame(1) ~= 0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BIG_PENGUIN_YELL)
	end
end

-- from src/game/behaviors/tuxie.inc.c:bhv_tuxies_mother_loop L156-163
function tuxie_inc.bhv_tuxies_mother_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK10))
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(tuxie_inc.sTuxiesMotherActions)
	ObjectHelpers.cur_obj_move_standard(-78)
	tuxie_inc.play_penguin_walking_sound(IncludeObjectConstantsH.PENGUIN_WALK_BIG)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_dive_with_mario L165-170
function tuxie_inc.small_penguin_dive_with_mario()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectHelpers.mario_is_dive_sliding() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk100, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_2 L172-189
function tuxie_inc.small_penguin_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local sp1C = IncludePRUltratypesH.FALSE

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and ObjectHelpers.cur_obj_dist_to_nearest_object_with_behavior(BehaviorIds.bhvTuxiesMother) < 1000.0 then
		sp1C = IncludePRUltratypesH.TRUE
	end

	ObjectHelpers.cur_obj_init_animation_with_sound(0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk104) + 3.0)
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk110) + 0x600))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk108) + 500.0) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	tuxie_inc.small_penguin_dive_with_mario()

	if sp1C ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
	end
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_1 L191-202
function tuxie_inc.small_penguin_act_1()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_sound(0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk104) + 3.0)
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk110) + 0x600))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk108) + 300.0) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1100.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	tuxie_inc.small_penguin_dive_with_mario()
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_3 L204-214
function tuxie_inc.small_penguin_act_3()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 6 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BABY_PENGUIN_DIVE)
		end

		ObjectHelpers.cur_obj_init_animation_with_sound(1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 25 and ObjectHelpers.mario_is_dive_sliding() == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
		end
	end
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_4 L216-224
function tuxie_inc.small_penguin_act_4()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(2)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 40 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk100))
		end
	end
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_0 L226-250
function tuxie_inc.small_penguin_act_0()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local sp1C = IncludePRUltratypesH.FALSE

	ObjectHelpers.cur_obj_init_animation_with_sound(3)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk110, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 0x400)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk108, SrcEngineBehaviorScript.random_float() * 100.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk104, SrcEngineBehaviorScript.random_float())
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

		if ObjectHelpers.cur_obj_dist_to_nearest_object_with_behavior(BehaviorIds.bhvTuxiesMother) < 1000.0 then
			sp1C = IncludePRUltratypesH.TRUE
		end
	end

	const distToMario = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario)

	if distToMario < 1000.0 and distToMario > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk108) + 600.0) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	elseif distToMario < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk108) + 300.0) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if sp1C ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
	end

	if ObjectHelpers.cur_obj_mario_far_away() ~= 0 then
		ObjectHelpers.cur_obj_set_pos_to_home()
	end
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_act_5 L252-277
function tuxie_inc.small_penguin_act_5()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sp1C = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvTuxiesMother)

	if sp1C ~= nil then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 2.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		const sp24 = ObjectHelpers.dist_between_objects(o, sp1C)
		const sp22 = ObjectHelpers.obj_angle_to_object(o, sp1C)

		if sp24 > 200.0 then
			ObjectHelpers.cur_obj_rotate_yaw_toward(sp22, 0x400)
		else
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(sp22 + 0x8000), 0x400)
		end

		ObjectHelpers.cur_obj_init_animation_with_sound(0)
	end

	tuxie_inc.small_penguin_dive_with_mario()
end

-- from src/game/behaviors/tuxie.inc.c:small_penguin_free_actions L288-297
function tuxie_inc.small_penguin_free_actions()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk88) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSmallPenguinUnk88, IncludePRUltratypesH.FALSE)
	end

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(tuxie_inc.sSmallPenguinActions)
	ObjectHelpers.cur_obj_move_standard(-78)
	tuxie_inc.play_penguin_walking_sound(IncludeObjectConstantsH.PENGUIN_WALK_BABY)
end

-- from src/game/behaviors/tuxie.inc.c:bhv_small_penguin_loop L299-325
function tuxie_inc.bhv_small_penguin_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		tuxie_inc.small_penguin_free_actions()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(0, 0)

		if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvPenguinBaby) ~= 0 then
			ObjectHelpers.obj_set_behavior(o, BehaviorIds.bhvSmallPenguin)
		end

		ObjectHelpers.obj_copy_pos(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object)

		if math.fmod(GameInit.gGlobalTimer, 30) == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_OBJ2_BABY_PENGUIN_YELL, (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		ObjectHelpers.cur_obj_get_thrown_or_placed(0.0, 0.0, 0)
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_dropped()
	end
end

-- from src/game/behaviors/tuxie.inc.c:geo_switch_tuxie_mother_eyes L330-362
function tuxie_inc.geo_switch_tuxie_mother_eyes(run: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { { number } } }): { unknown }?
	if run == IncludePRUltratypesH.TRUE then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase

		switchCase.selectedCase = 0

		-- timer logic for blinking. uses cases 0-2.
		const timer = math.fmod(GameInit.gGlobalTimer, 50)

		if timer < 43 then
			switchCase.selectedCase = 0
		elseif timer < 45 then
			switchCase.selectedCase = 1
		elseif timer < 47 then
			switchCase.selectedCase = 2
		else
			switchCase.selectedCase = 1
		end

		-- make Tuxie's Mother have angry eyes if Mario takes the correct baby after giving it back.
		if obj.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvTuxiesMother) then
			if buffer.readf32(obj.rawData, IncludeObjectFieldsH.oForwardVel) > 5.0 then
				switchCase.selectedCase = 3
			end
		end
	end

	return nil
end

-- from src/game/behaviors/tuxie.inc.c:sTuxiesMotherActions L150-154
tuxie_inc.sTuxiesMotherActions = { tuxie_inc.tuxies_mother_act_0, tuxie_inc.tuxies_mother_act_1, tuxie_inc.tuxies_mother_act_2 }

-- from src/game/behaviors/tuxie.inc.c:sSmallPenguinActions L279-286
tuxie_inc.sSmallPenguinActions = {
	tuxie_inc.small_penguin_act_0,
	tuxie_inc.small_penguin_act_1,
	tuxie_inc.small_penguin_act_2,
	tuxie_inc.small_penguin_act_3,
	tuxie_inc.small_penguin_act_4,
	tuxie_inc.small_penguin_act_5,
}

return tuxie_inc
