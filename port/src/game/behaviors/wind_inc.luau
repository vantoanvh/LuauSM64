--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/wind.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const wind_inc = {}

Registry.Register("src__game__behaviors__wind_inc", wind_inc)

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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/wind.inc.c:spawn_wind_particles L3-10
function wind_inc.spawn_wind_particles(pitch: number, yaw: number)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	for I = 1, 3 do
		const Wind = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvWind)

		buffer.writei32(Wind.rawData, IncludeObjectFieldsH.oMoveAngleYaw, yaw)
		buffer.writei32(Wind.rawData, IncludeObjectFieldsH.oMoveAnglePitch, pitch)
	end
end

-- from src/game/behaviors/wind.inc.c:bhv_wind_loop L12-43
function wind_inc.bhv_wind_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp2E = 500
	const Scale = 1

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 100)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) == 0 then
			ObjectHelpers.obj_translate_xz_random(o, 900)
			-- NOP as Pitch is 0
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000) * Sp2E))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(80 + ObjectHelpers.random_f32_around_zero(200)))
			-- -coss(a) * sp2E
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000) * Sp2E))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + ObjectHelpers.random_f32_around_zero(4000)))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 70) + 50)
		else
			ObjectHelpers.obj_translate_xz_random(o, 600)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - (Sp2E - 200))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 30) + 50)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10)
		end

		ObjectHelpers.obj_set_billboard(o)
		ObjectHelpers.cur_obj_scale(Scale)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 8 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + F32(4000 + F32(2000 * SrcEngineBehaviorScript.random_float()))))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + F32(4000 + F32(2000 * SrcEngineBehaviorScript.random_float()))))))
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

return wind_inc
