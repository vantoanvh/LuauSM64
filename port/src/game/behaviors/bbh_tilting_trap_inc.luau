--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bbh_tilting_trap.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const bbh_tilting_trap_inc = {}

Registry.Register("src__game__behaviors__bbh_tilting_trap_inc", bbh_tilting_trap_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/bbh_tilting_trap.inc.c:bhv_bbh_tilting_trap_platform_loop L11-64
function bbh_tilting_trap_inc.bhv_bbh_tilting_trap_platform_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Post-JP versions use oAction for the
	-- if statement, while immediately setting it over here.
	-- This was done so that Mario leaving or getting on the platform
	-- resets oTimer to 0.

	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BBH_TILTING_TRAP_PLATFORM_ACT_MARIO_ON)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BBH_TILTING_TRAP_PLATFORM_ACT_MARIO_OFF)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BBH_TILTING_TRAP_PLATFORM_ACT_MARIO_ON then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
	else
		-- In the post-JP versions, if the platform has tilted more than 3000 angle units
		-- in less than 16 frames since Mario got on it, and he has stepped off,
		-- this code will not run, so it will continue to rotate with the same
		-- angular velocity for 16 more frames. This was probably done to make
		-- the platform more dangerous. This code will not work correctly
		-- without the oAction changes above, since oTimer will not ever
		-- reset to 0 without them.
		if ObjectHelpers.absi(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) < 3000 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
			-- Make the platform return to the horizontal at a speed of
			-- 200 angle units/frame, and clamp it to 0 if it's within 200 units of 0.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)

			if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) > 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < 200 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, -200)
				end
			else
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > -200 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 200)
				end
			end
		end
	end

	-- Update angle
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
end

return bbh_tilting_trap_inc
