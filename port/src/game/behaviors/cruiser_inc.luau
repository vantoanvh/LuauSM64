--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/cruiser.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const cruiser_inc = {}

Registry.Register("src__game__behaviors__cruiser_inc", cruiser_inc)

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

-- from src/game/behaviors/cruiser.inc.c:bhv_rr_cruiser_wing_init L3-6
function cruiser_inc.bhv_rr_cruiser_wing_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
end

-- from src/game/behaviors/cruiser.inc.c:bhv_rr_cruiser_wing_loop L8-22
function cruiser_inc.bhv_rr_cruiser_wing_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF4) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x400) * 8192))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF8) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x400) * 2048))))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF4) - F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x400) * 8192))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oRRCruiserWingUnkF8) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x400) * 2048))))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 64 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOAT_ROCK)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

return cruiser_inc
