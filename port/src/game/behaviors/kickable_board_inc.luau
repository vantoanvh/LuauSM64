--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/kickable_board.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const kickable_board_inc = {}

Registry.Register("src__game__behaviors__kickable_board_inc", kickable_board_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
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

-- from src/game/behaviors/kickable_board.inc.c:check_mario_attacking L3-27
function kickable_board_inc.check_mario_attacking(unused: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, marioObj) ~= 0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) > 0x6000 then
		const action = LevelUpdate.gMarioStates[1].action

		if action == IncludeSm64H.ACT_SLIDE_KICK then
			return 1
		end

		if action == IncludeSm64H.ACT_PUNCHING then
			return 1
		end

		if action == IncludeSm64H.ACT_MOVE_PUNCHING then
			return 1
		end

		if action == IncludeSm64H.ACT_SLIDE_KICK_SLIDE then
			return 1
		end

		if action == IncludeSm64H.ACT_JUMP_KICK then
			return 2
		end

		if action == IncludeSm64H.ACT_WALL_KICK_AIR then
			return 2
		end
	end

	return 0
end

-- from src/game/behaviors/kickable_board.inc.c:init_kickable_board_rock L29-32
function kickable_board_inc.init_kickable_board_rock()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oKickableBoardF8, 1600)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oKickableBoardF4, 0)
end

-- from src/game/behaviors/kickable_board.inc.c:bhv_kickable_board_loop L34-104
function kickable_board_inc.bhv_kickable_board_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)

		if kickable_board_inc.check_mario_attacking(0) ~= 0 then
			kickable_board_inc.init_kickable_board_rock()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	elseif action == 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		SrcEngineSurfaceLoad.load_object_collision_model()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(F32(-SrcEngineMathUtilH.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF4))) * buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF8))))

		local sp24 = 0

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			sp24 = kickable_board_inc.check_mario_attacking(0)
		end

		if sp24 ~= 0 then
			if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 160.0) and sp24 == 2 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BUTTON_PRESS_2)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKickableBoardF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF8) - 8))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF8) < 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
			end
		else
			kickable_board_inc.init_kickable_board_rock()
		end

		if not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF4), 0x7FFF) then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BUTTON_PRESS_2)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKickableBoardF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKickableBoardF4) + 0x400))
	elseif action == 2 then
		ObjectHelpers.cur_obj_become_intangible()
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_WF_KICKABLE_BOARD_FELLED)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) - 0x80))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < -0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, -0x4000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))

			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNKNOWN4)
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	elseif action == 3 then
		SrcEngineSurfaceLoad.load_object_collision_model()
	end

	o.header.gfx.throwMatrix = nil
end

return kickable_board_inc
