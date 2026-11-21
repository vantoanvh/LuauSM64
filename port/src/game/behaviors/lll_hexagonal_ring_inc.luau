--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_hexagonal_ring.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const lll_hexagonal_ring_inc = {}

Registry.Register("src__game__behaviors__lll_hexagonal_ring_inc", lll_hexagonal_ring_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
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

-- from src/game/behaviors/lll_hexagonal_ring.inc.c:hexagonal_ring_spawn_flames L3-19
function lll_hexagonal_ring_inc.hexagonal_ring_spawn_flames()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp1C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvVolcanoFlames)

	buffer.writef32(sp1C.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(sp1C.rawData, IncludeObjectFieldsH.oPosY) + 550.0)
	buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S16(SrcEngineBehaviorScript.random_u16()))
	buffer.writef32(sp1C.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 40.0) + 20.0)
	buffer.writef32(sp1C.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 50.0) + 10.0)

	const size = F32(SrcEngineBehaviorScript.random_float() * 6.0 + 3.0)

	ObjectHelpers.obj_scale_xyz(sp1C, size, size, size)

	if SrcEngineBehaviorScript.random_float() < 0.1 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_VOLCANO_EXPLOSION)
	end
end

-- from src/game/behaviors/lll_hexagonal_ring.inc.c:bhv_lll_rotating_hexagonal_ring_loop L21-72
function lll_hexagonal_ring_inc.bhv_lll_rotating_hexagonal_ring_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionDistance, 4000.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oDrawingDistance, 8000.0)

	if action == 0 then
		if marioObj.platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x100)
	elseif action == 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, TruncS32(F32(256.0 - F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 128) * 256.0))))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 128 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 2 then
		if marioObj.platform ~= o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 128 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
		lll_hexagonal_ring_inc.hexagonal_ring_spawn_flames()
	elseif action == 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, TruncS32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 128) * 256.0)))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 128 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	elseif action == 4 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S32(-buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
end

return lll_hexagonal_ring_inc
