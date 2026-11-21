--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/flame_mario.inc.c.
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

const flame_mario_inc = {}

Registry.Register("src__game__behaviors__flame_mario_inc", flame_mario_inc)

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/flame_mario.inc.c:bhv_black_smoke_upward_loop L3-5
function flame_mario_inc.bhv_black_smoke_upward_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_BURN_SMOKE, BehaviorIds.bhvBlackSmokeBowser, o.header.gfx.scale[1])
end

-- from src/game/behaviors/flame_mario.inc.c:bhv_black_smoke_bowser_loop L7-18
function flame_mario_inc.bhv_black_smoke_bowser_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 2) + 0.5)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 8)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBlackSmokeBowserUnkF4, o.header.gfx.scale[1])
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

-- from src/game/behaviors/flame_mario.inc.c:bhv_black_smoke_mario_loop L20-31
function flame_mario_inc.bhv_black_smoke_mario_loop()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_set_pos_relative(mario, 0, 0, -30)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 2) + 0.5)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readi32(mario.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x7000 + F32(SrcEngineBehaviorScript.random_float() * 8192))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 8)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

-- from src/game/behaviors/flame_mario.inc.c:bhv_flame_mario_loop L33-50
function flame_mario_inc.bhv_flame_mario_loop()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_scale(2)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) ~= 0 then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 1) then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BURN_SMOKE, BehaviorIds.bhvBlackSmokeMario)
		end
	end

	mario.prevObj = o
	ObjectHelpers.obj_set_parent_relative_pos(o, 40, -120, 0)

	if not bit32.btest(buffer.readi32(mario.rawData, IncludeObjectFieldsH.oMarioParticleFlags), IncludeObjectConstantsH.ACTIVE_PARTICLE_FIRE) then
		const parent = o.parentObj :: GroupsTypesHPlus3.Object
		buffer.writeu32(parent.rawData, IncludeObjectFieldsH.oActiveParticleFlags, U32(bit32.band(buffer.readu32(parent.rawData, IncludeObjectFieldsH.oActiveParticleFlags), bit32.bnot(IncludeObjectConstantsH.ACTIVE_PARTICLE_FIRE))))
		ObjectHelpers.obj_mark_for_deletion(o)
		mario.prevObj = nil
	end
end

return flame_mario_inc
