--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bouncing_fireball.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const bouncing_fireball_inc = {}

Registry.Register("src__game__behaviors__bouncing_fireball_inc", bouncing_fireball_inc)

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

-- from src/game/behaviors/bouncing_fireball.inc.c:bhv_bouncing_fireball_flame_loop L3-41
function bouncing_fireball_inc.bhv_bouncing_fireball_flame_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK10))

	ObjectHelpers.cur_obj_update_floor_and_walls()

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
		end

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
		end

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE, IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND)) and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 300 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	ObjectHelpers.cur_obj_move_standard(78)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/bouncing_fireball.inc.c:bhv_bouncing_fireball_loop L43-79
function bouncing_fireball_inc.bhv_bouncing_fireball_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		const sp2C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvBouncingFireballFlame)
		const sp28 = F32((10 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)) * 0.5)

		ObjectHelpers.obj_scale_xyz(sp2C, sp28, sp28, sp28)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.obj_become_tangible(sp2C)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBouncingFireBallUnkF4, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0)))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBouncingFireBallUnkF4) + 100 < buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	end
end

return bouncing_fireball_inc
