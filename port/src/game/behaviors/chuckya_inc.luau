--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/chuckya.inc.c.
]]

const Registry = require("../../../groups/registry")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const MetalBoxInc = require("./metal_box_inc")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

-- from src/game/behaviors/chuckya.inc.c:UnusedChuckyaData
export type UnusedChuckyaData = {
	unk0: number,
	unk4: number,
	unk8: number,
}

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/chuckya_inc.luau:scratch
const Scratch = {
	unknown_chuckya_function_angleToMario = { 0 },
	chuckya_act_0_forwardVel = { 0 },
}

-- from src/game/behaviors/chuckya.inc.c:data
const chuckya_inc = {
	-- from src/game/behaviors/chuckya.inc.c:sUnusedChuckyaData L9-15
	sUnusedChuckyaData = {
		{ unk0 = 2, unk4 = 0.0, unk8 = 1.0 },
		{ unk0 = 2, unk4 = 10.0, unk8 = 1.0 },
		{ unk0 = 2, unk4 = 20.0, unk8 = 1.0 },
		{ unk0 = 2, unk4 = 20.0, unk8 = 1.0 },
		{ unk0 = 8, unk4 = 10.0, unk8 = 1.0 },
	},
}

Registry.Register("src__game__behaviors__chuckya_inc", chuckya_inc)

-- from src/game/behaviors/chuckya.inc.c:UnusedChuckyaData (zero-filled constructor)
function chuckya_inc.new_UnusedChuckyaData(): UnusedChuckyaData
	return { unk0 = 0, unk4 = 0, unk8 = 0 } :: UnusedChuckyaData
end

-- from src/game/behaviors/chuckya.inc.c:common_anchor_mario_behavior L17-46
function chuckya_inc.common_anchor_mario_behavior(sp28: number, sp2C: number, sp30: number)
	sp28 = F32(sp28)
	sp2C = F32(sp2C)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const ParentChuckyaUnk88 = buffer.readi32(parent.rawData, IncludeObjectFieldsH.oChuckyaUnk88)

	if ParentChuckyaUnk88 == 0 then
		-- Nothing to do.
	elseif ParentChuckyaUnk88 == 1 then
		ObjectHelpers.obj_set_gfx_pos_at_obj_pos(marioObject, o)
	elseif ParentChuckyaUnk88 == 2 then
		buffer.writei32(marioObject.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObject.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK2 + sp30)))
		LevelUpdate.gMarioStates[1].forwardVel = sp28
		LevelUpdate.gMarioStates[1].vel[2] = sp2C
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oChuckyaUnk88, 0)
	elseif ParentChuckyaUnk88 == 3 then
		buffer.writei32(marioObject.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObject.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bor(InteractionH.INT_STATUS_MARIO_UNK2, InteractionH.INT_STATUS_MARIO_UNK6))))
		LevelUpdate.gMarioStates[1].forwardVel = 10.0
		LevelUpdate.gMarioStates[1].vel[2] = 10.0
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oChuckyaUnk88, 0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if parent.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/chuckya.inc.c:bhv_chuckya_anchor_mario_loop L48-50
function chuckya_inc.bhv_chuckya_anchor_mario_loop()
	chuckya_inc.common_anchor_mario_behavior(40.0, 40.0, InteractionH.INT_STATUS_MARIO_UNK6)
end

-- from src/game/behaviors/chuckya.inc.c:unknown_chuckya_function L52-81
function chuckya_inc.unknown_chuckya_function(sp20: number, sp24: number, sp28: number, sp2C: number): number
	sp24 = F32(sp24)
	sp28 = F32(sp28)
	sp2C = S16(TruncS32(sp2C))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	local Sp1C = 0

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkF8) ~= 4 then
		if sp24 < ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() then
			if ObjectHelpers.cur_obj_lateral_dist_to_home() < 200.0 then
				Sp1C = 0
			else
				Sp1C = 1
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > sp28 then
			if math.fmod(GameInit.gGlobalTimer, sp2C) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.obj_angle_to_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object))
			end

			Sp1C = 2
		else
			Sp1C = 3
		end

		if sp20 ~= 0 then
			Scratch.unknown_chuckya_function_angleToMario[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)
			const AngleUpdated: number = Registry.Members.src__game__behaviors__scuttlebug_inc.update_angle_from_move_flags(Scratch.unknown_chuckya_function_angleToMario)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, Scratch.unknown_chuckya_function_angleToMario[1])

			if AngleUpdated ~= 0 then
				Sp1C = 4
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkF8, 4)
			end
		end
	else
		Sp1C = 4
	end

	return Sp1C
end

-- from src/game/behaviors/chuckya.inc.c:approach_forward_vel L83-101
function chuckya_inc.approach_forward_vel(forwardVel: { number }, spC: number, sp10: number): number
	spC = F32(spC)
	sp10 = F32(sp10)
	local Result = 0

	if forwardVel[1] > spC then
		forwardVel[1] = F32(forwardVel[1] - sp10)

		if forwardVel[1] < spC then
			forwardVel[1] = spC
		end
	elseif forwardVel[1] < spC then
		forwardVel[1] = F32(forwardVel[1] + sp10)

		if forwardVel[1] > spC then
			forwardVel[1] = spC
		end
	else
		Result = 1
	end

	return Result
end

-- from src/game/behaviors/chuckya.inc.c:chuckya_act_0 L103-176
function chuckya_inc.chuckya_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC, 0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.obj_angle_to_object(o, marioObject))

	const SubAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if SubAction == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() < 2000.0 then
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC) > 40 or ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) < 0x1000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 3)
		end
	elseif SubAction == 1 then
		Scratch.chuckya_act_0_forwardVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
		chuckya_inc.approach_forward_vel(Scratch.chuckya_act_0_forwardVel, 30.0, 4.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Scratch.chuckya_act_0_forwardVel[1])

		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) > 0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 2)
		end

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 2000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 3)
		end
	elseif SubAction == 2 then
		Scratch.chuckya_act_0_forwardVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
		chuckya_inc.approach_forward_vel(Scratch.chuckya_act_0_forwardVel, 0, 4.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Scratch.chuckya_act_0_forwardVel[1])

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC) > 48 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
		end
	elseif SubAction == 3 then
		if ObjectHelpers.cur_obj_lateral_dist_to_home() < 500.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		else
			Scratch.chuckya_act_0_forwardVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
			chuckya_inc.approach_forward_vel(Scratch.chuckya_act_0_forwardVel, 10.0, 4.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Scratch.chuckya_act_0_forwardVel[1])

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x800)
		end

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() < 1900.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) ~= SubAction then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC, 0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC) + 1))
	end

	ObjectHelpers.cur_obj_init_animation_with_sound(4)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 1.0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_CHUCKYA_MOVE)
	end
end

-- from src/game/behaviors/chuckya.inc.c:chuckya_act_1 L178-212
function chuckya_inc.chuckya_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC, TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 30.0) + 10.0)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk100, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk100, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk100) + ObjectHelpers.player_performed_grab_escape_action()))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk100) > 10 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk88, 3)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_GRABBED_MARIO))))
			else
				ObjectHelpers.cur_obj_init_animation_with_sound(1)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + InteractionH.INT_STATUS_GRABBED_MARIO))

				const FrameCounter = buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC, S32(FrameCounter - 1))

				if FrameCounter < 0 and (MetalBoxInc.check_if_moving_over_floor(50.0, 150.0) ~= 0 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oChuckyaUnkFC) < -16) then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
				end
			end
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(3)

			if ObjectHelpers.cur_obj_check_anim_frame(18) ~= 0 then
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN4)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk88, 2)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_GRABBED_MARIO))))
			end
		end
	end
end

-- from src/game/behaviors/chuckya.inc.c:chuckya_act_3 L214-221
function chuckya_inc.chuckya_act_3()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	ObjectHelpers.cur_obj_init_animation_with_sound(4)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/chuckya.inc.c:chuckya_act_2 L223-229
function chuckya_inc.chuckya_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL, IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER, IncludeObjectConstantsH.OBJ_MOVE_LANDED)) then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.obj_spawn_loot_yellow_coins(o, 5, 20.0)
		ObjectHelpers.spawn_mist_particles_with_sound(IncludeSoundsH.SOUND_OBJ_CHUCKYA_DEATH)
	end
end

-- from src/game/behaviors/chuckya.inc.c:chuckya_move L238-247
function chuckya_inc.chuckya_move()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(chuckya_inc.sChuckyaActions)
	ObjectHelpers.cur_obj_move_standard(-30)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_GRABBED_MARIO) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChuckyaUnk88, 1)
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN3)
	end
end

-- from src/game/behaviors/chuckya.inc.c:bhv_chuckya_loop L249-272
function chuckya_inc.bhv_chuckya_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp2C = 20.0
	const Sp28 = 50.0

	ObjectHelpers.cur_obj_scale(2.0)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO)))

	const HeldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if HeldState == IncludeObjectConstantsH.HELD_FREE then
		chuckya_inc.chuckya_move()
	elseif HeldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(2, 0)
	elseif HeldState == IncludeObjectConstantsH.HELD_THROWN or HeldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_thrown_or_placed(Sp2C, Sp28, 2)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/chuckya.inc.c:sChuckyaActions L231-236
chuckya_inc.sChuckyaActions = {
	chuckya_inc.chuckya_act_0,
	chuckya_inc.chuckya_act_1,
	chuckya_inc.chuckya_act_2,
	chuckya_inc.chuckya_act_3,
}

return chuckya_inc
