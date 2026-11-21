--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/swing_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")

const swing_platform_inc = {}

Registry.Register("src__game__behaviors__swing_platform_inc", swing_platform_inc)

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

-- from src/game/behaviors/swing_platform.inc.c:bhv_swing_platform_init L3-5
function swing_platform_inc.bhv_swing_platform_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSwingPlatformAngle, 0x2000)
end

-- from src/game/behaviors/swing_platform.inc.c:bhv_swing_platform_update L7-19
function swing_platform_inc.bhv_swing_platform_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const StartRoll = buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) < 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSwingPlatformSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSwingPlatformSpeed) + 4.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSwingPlatformSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSwingPlatformSpeed) - 4.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSwingPlatformAngle, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSwingPlatformAngle) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oSwingPlatformSpeed))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSwingPlatformAngle))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - StartRoll)
end

return swing_platform_inc
