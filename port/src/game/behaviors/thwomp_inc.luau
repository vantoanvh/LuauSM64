--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/thwomp.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const thwomp_inc = {}

Registry.Register("src__game__behaviors__thwomp_inc", thwomp_inc)

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

-- from src/game/behaviors/thwomp.inc.c:grindel_thwomp_act_idle_at_bottom L3-10
function thwomp_inc.grindel_thwomp_act_idle_at_bottom()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGrindelThwompRandomTimer, S32(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 10.0) + 20.0))))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oGrindelThwompRandomTimer) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GRINDEL_THWOMP_ACT_RAISE)
	end
end

-- from src/game/behaviors/thwomp.inc.c:grindel_thwomp_act_lower L12-20
function thwomp_inc.grindel_thwomp_act_lower()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - 4.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GRINDEL_THWOMP_ACT_LAND)
	end
end

-- from src/game/behaviors/thwomp.inc.c:grindel_thwomp_act_land L22-32
function thwomp_inc.grindel_thwomp_act_land()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_THWOMP)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 10 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GRINDEL_THWOMP_ACT_IDLE_AT_BOTTOM)
	end
end

-- from src/game/behaviors/thwomp.inc.c:grindel_thwomp_act_idle_at_top L34-41
function thwomp_inc.grindel_thwomp_act_idle_at_top()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGrindelThwompRandomTimer, S32(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 30.0) + 10.0))))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oGrindelThwompRandomTimer) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GRINDEL_THWOMP_ACT_LOWER)
	end
end

-- from src/game/behaviors/thwomp.inc.c:grindel_thwomp_act_raise L43-50
function thwomp_inc.grindel_thwomp_act_raise()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 40 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GRINDEL_THWOMP_ACT_IDLE_AT_TOP)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 10.0)
	end
end

-- from src/game/behaviors/thwomp.inc.c:bhv_grindel_thwomp_loop L60-62
function thwomp_inc.bhv_grindel_thwomp_loop()
	ObjectHelpers.cur_obj_call_action_function(thwomp_inc.sGrindelThwompActions)
end

-- from src/game/behaviors/thwomp.inc.c:sGrindelThwompActions L52-58
thwomp_inc.sGrindelThwompActions = {
	thwomp_inc.grindel_thwomp_act_raise,
	thwomp_inc.grindel_thwomp_act_idle_at_top,
	thwomp_inc.grindel_thwomp_act_lower,
	thwomp_inc.grindel_thwomp_act_land,
	thwomp_inc.grindel_thwomp_act_idle_at_bottom,
}

return thwomp_inc
