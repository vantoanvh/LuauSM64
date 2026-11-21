--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_rotating_hex_flame.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const lll_rotating_hex_flame_inc = {}

Registry.Register("src__game__behaviors__lll_rotating_hex_flame_inc", lll_rotating_hex_flame_inc)

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

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:bhv_lll_rotating_hex_flame_loop L3-14
function lll_rotating_hex_flame_inc.bhv_lll_rotating_hex_flame_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
	const sp24 = buffer.readf32(o.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkF4)
	const sp20 = buffer.readf32(o.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkF8)
	const sp1C = buffer.readf32(o.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkFC)

	ObjectHelpers.cur_obj_set_pos_relative(parentObj, sp24, sp20, sp1C)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPosY) + 100.0)

	if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:fire_bar_spawn_flames L16-35
function lll_rotating_hex_flame_inc.fire_bar_spawn_flames(a0: number)
	a0 = S16(TruncS32(a0))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local sp1C = F32(SrcEngineMathUtilH.sins(a0) * 200.0)
	local sp18 = F32(SrcEngineMathUtilH.coss(a0) * 200.0)
	const sp20 = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then 4 else 3

	for i = 0, sp20 - 1 do
		const sp2C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvLLLRotatingHexFlame)

		buffer.writef32(sp2C.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkF4, buffer.readf32(sp2C.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkF4) + sp1C)
		buffer.writef32(sp2C.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 200.0)
		buffer.writef32(sp2C.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkFC, buffer.readf32(sp2C.rawData, IncludeObjectFieldsH.oLLLRotatingHexFlameUnkFC) + sp18)
		ObjectHelpers.obj_scale_xyz(sp2C, 6.0, 6.0, 6.0)

		sp1C = F32(sp1C + F32(SrcEngineMathUtilH.sins(a0) * 150.0))
		sp18 = F32(sp18 + F32(SrcEngineMathUtilH.coss(a0) * 150.0))
	end
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:fire_bar_act_0 L37-41
function lll_rotating_hex_flame_inc.fire_bar_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 3000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:fire_bar_act_1 L43-49
function lll_rotating_hex_flame_inc.fire_bar_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	lll_rotating_hex_flame_inc.fire_bar_spawn_flames(0)
	lll_rotating_hex_flame_inc.fire_bar_spawn_flames(-0x8000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:fire_bar_act_2 L51-57
function lll_rotating_hex_flame_inc.fire_bar_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, -0x100)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 3200.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:fire_bar_act_3 L59-61
function lll_rotating_hex_flame_inc.fire_bar_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:bhv_lll_rotating_block_fire_bars_loop L70-75
function lll_rotating_hex_flame_inc.bhv_lll_rotating_block_fire_bars_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_call_action_function(lll_rotating_hex_flame_inc.sRotatingCwFireBarsActions)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

-- from src/game/behaviors/lll_rotating_hex_flame.inc.c:sRotatingCwFireBarsActions L63-68
lll_rotating_hex_flame_inc.sRotatingCwFireBarsActions = {
	lll_rotating_hex_flame_inc.fire_bar_act_0,
	lll_rotating_hex_flame_inc.fire_bar_act_1,
	lll_rotating_hex_flame_inc.fire_bar_act_2,
	lll_rotating_hex_flame_inc.fire_bar_act_3,
}

return lll_rotating_hex_flame_inc
