--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/flame.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const FirePiranhaPlantInc = require("./fire_piranha_plant_inc")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const flame_inc = {}

Registry.Register("src__game__behaviors__flame_inc", flame_inc)

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/flame_inc.luau:scratch
const Scratch = {
	bhv_fly_guy_flame_loop_scale_buffer = buffer.create(4),
}

-- from src/game/behaviors/flame.inc.c:bhv_small_piranha_flame_loop L3-44
function flame_inc.bhv_small_piranha_flame_loop()
	const o = ObjectListProcessor.gCurrentObject

	if U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		else
			const rnd = F32(SrcEngineBehaviorScript.random_float() - 0.5)

			o.header.gfx.scale[2] = F32(o.header.gfx.scale[3] * F32(1 + F32(F32(0.7) * rnd)))
			o.header.gfx.scale[1] = F32(o.header.gfx.scale[3] * F32(F32(0.9) - F32(0.5 * rnd)))

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, SrcEngineBehaviorScript.random_u16())
		end
	else
		ObjectHelpers.cur_obj_update_floor_and_walls()

		if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameStartSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameEndSpeed), F32(0.6)) ~= 0 then
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)
		end

		ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameStartSpeed))
		ObjectHelpers.cur_obj_move_standard(-78)
		ObjectHelpers.spawn_object_with_scale(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameModel), BehaviorIds.bhvSmallPiranhaFlame, F32(F32(0.4) * o.header.gfx.scale[1]))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameNextFlameTimer) then
			ObjectHelpers.spawn_object_relative_with_scale(1, 0, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset))), 0, o.header.gfx.scale[1], o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameModel), BehaviorIds.bhvFlyguyFlame)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameNextFlameTimer, ObjBehaviors2.random_linear_offset(8, 15))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end

		ObjBehaviors2.obj_check_attacks(FirePiranhaPlantInc.sPiranhaPlantFireHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameSpeed) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameStartSpeed))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameSpeed) > 1500 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL, IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER)) then
			ObjBehaviors2.obj_die_if_health_non_positive()
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 15 * o.header.gfx.scale[2])
end

-- from src/game/behaviors/flame.inc.c:bhv_fly_guy_flame_loop L46-54
function flame_inc.bhv_fly_guy_flame_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	buffer.writef32(Scratch.bhv_fly_guy_flame_loop_scale_buffer, 0, o.header.gfx.scale[1])
	const Reached: number = ObjBehaviors2.approach_f32_ptr(Scratch.bhv_fly_guy_flame_loop_scale_buffer, 0, 0, F32(0.6))
	o.header.gfx.scale[1] = buffer.readf32(Scratch.bhv_fly_guy_flame_loop_scale_buffer, 0)

	if Reached ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
end

return flame_inc
