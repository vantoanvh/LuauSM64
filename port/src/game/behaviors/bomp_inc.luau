--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bomp.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const bomp_inc = {}

Registry.Register("src__game__behaviors__bomp_inc", bomp_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/bomp.inc.c:bhv_small_bomp_init L3-7
function bomp_inc.bhv_small_bomp_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSmallBompInitX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0)))
end

-- from src/game/behaviors/bomp.inc.c:bhv_small_bomp_loop L9-58
function bomp_inc.bhv_small_bomp_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOMP_ACT_WAIT then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_POKE_OUT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_POKE_OUT then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) > 3450.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3450.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_EXTEND)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN2)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_EXTEND then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) > 3830.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3830.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_RETRACT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN2)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_RETRACT then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) < 3330.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3330.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 90 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_POKE_OUT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
		end
	end
end

-- from src/game/behaviors/bomp.inc.c:bhv_large_bomp_init L60-63
function bomp_inc.bhv_large_bomp_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0)))
end

-- from src/game/behaviors/bomp.inc.c:bhv_large_bomp_loop L65-114
function bomp_inc.bhv_large_bomp_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOMP_ACT_WAIT then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_POKE_OUT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_POKE_OUT then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) > 3450.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3450.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_EXTEND)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN2)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_EXTEND then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) > 3830.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3830.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_RETRACT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN2)
		end
	elseif action == IncludeObjectConstantsH.BOMP_ACT_RETRACT then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) < 3330.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 3330.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 90 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOMP_ACT_POKE_OUT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
		end
	end
end

return bomp_inc
