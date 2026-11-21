--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/intro_peach.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const Camera = require("../camera")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtil = require("../../engine/math_util")

const intro_peach_inc = {}

Registry.Register("src__game__behaviors__intro_peach_inc", intro_peach_inc)

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

-- from src/game/behaviors/intro_peach_inc.luau:scratch
const Scratch = {
	intro_peach_set_pos_and_opacity_dist = { 0 },
	intro_peach_set_pos_and_opacity_focusPitch = { 0 },
	intro_peach_set_pos_and_opacity_focusYaw = { 0 },
	intro_peach_set_pos_and_opacity_newPos = { 0, 0, 0 },
	intro_peach_set_pos_and_opacity_newOpacity = { 0 },
}

-- from src/game/behaviors/intro_peach.inc.c:intro_peach_set_pos_and_opacity L7-21
function intro_peach_inc.intro_peach_set_pos_and_opacity(obj: GroupsTypesHPlus3.Object, targetOpacity: number, increment: number)
	targetOpacity = F32(targetOpacity)
	increment = F32(increment)
	const gLakituState = Camera.gLakituState :: GroupsTypesHPlus3.LakituState

	SrcEngineMathUtil.vec3f_get_dist_and_angle(gLakituState.pos, gLakituState.focus, Scratch.intro_peach_set_pos_and_opacity_dist, Scratch.intro_peach_set_pos_and_opacity_focusPitch, Scratch.intro_peach_set_pos_and_opacity_focusYaw)

	const pitch = S16(TruncS32(F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oIntroPeachPitchFromFocus) + Scratch.intro_peach_set_pos_and_opacity_focusPitch[1])))
	const yaw = S16(TruncS32(F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oIntroPeachYawFromFocus) + Scratch.intro_peach_set_pos_and_opacity_focusYaw[1])))

	SrcEngineMathUtil.vec3f_set_dist_and_angle(gLakituState.pos, Scratch.intro_peach_set_pos_and_opacity_newPos, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oIntroPeachDistToCamera), pitch, yaw)
	Camera.vec3f_to_object_pos(obj, Scratch.intro_peach_set_pos_and_opacity_newPos)

	Scratch.intro_peach_set_pos_and_opacity_newOpacity[1] = buffer.readi32(obj.rawData, IncludeObjectFieldsH.oOpacity)
	Camera.camera_approach_f32_symmetric_bool(Scratch.intro_peach_set_pos_and_opacity_newOpacity, targetOpacity, increment)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oOpacity, TruncS32(Scratch.intro_peach_set_pos_and_opacity_newOpacity[1]))
end

-- from src/game/behaviors/intro_peach.inc.c:bhv_intro_peach_loop L23-61
function intro_peach_inc.bhv_intro_peach_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x400)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0x7500)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -0x3700)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroPeachDistToCamera, 186.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroPeachPitchFromFocus, -9984.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroPeachYawFromFocus, -768.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
		o.header.gfx.animInfo.animFrame = 100
	elseif action == 1 then
		intro_peach_inc.intro_peach_set_pos_and_opacity(o, 0.0, 0.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 2 then
		intro_peach_inc.intro_peach_set_pos_and_opacity(o, 255.0, 3.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 and GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 3 then
		intro_peach_inc.intro_peach_set_pos_and_opacity(o, 0.0, 8.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end
end

return intro_peach_inc
