--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_mist.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const water_mist_inc = {}

Registry.Register("src__game__behaviors__water_mist_inc", water_mist_inc)

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

-- from src/game/behaviors/water_mist.inc.c:bhv_water_mist_2_loop L4-9
function water_mist_inc.bhv_water_mist_2_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const HomeX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX)
	const HomeZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, SrcEngineSurfaceCollision.find_water_level(HomeX, HomeZ) + 20)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, HomeX + ObjectHelpers.random_f32_around_zero(150))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, HomeZ + ObjectHelpers.random_f32_around_zero(150))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 50) + 200))))
end

return water_mist_inc
