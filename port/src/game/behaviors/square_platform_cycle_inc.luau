--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/square_platform_cycle.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const square_platform_cycle_inc = {}

Registry.Register("src__game__behaviors__square_platform_cycle_inc", square_platform_cycle_inc)

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/square_platform_cycle.inc.c:square_plat_set_yaw_until_timer L3-10
function square_platform_cycle_inc.square_plat_set_yaw_until_timer(yaw: number, a: number): number
	yaw = U16(TruncS32(yaw))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, yaw)

	if a < buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/square_platform_cycle.inc.c:bhv_squarish_path_moving_loop L12-45
function square_platform_cycle_inc.bhv_squarish_path_moving_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), 0x03) + 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if square_platform_cycle_inc.square_plat_set_yaw_until_timer(0, 60) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if square_platform_cycle_inc.square_plat_set_yaw_until_timer(0x4000, 60) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		if square_platform_cycle_inc.square_plat_set_yaw_until_timer(0x8000, 60) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		if square_platform_cycle_inc.square_plat_set_yaw_until_timer(0xc000, 60) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	SrcEngineSurfaceLoad.load_object_collision_model()
end

return square_platform_cycle_inc
