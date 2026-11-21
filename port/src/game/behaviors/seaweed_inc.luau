--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/seaweed.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const seaweed_inc = {}

Registry.Register("src__game__behaviors__seaweed_inc", seaweed_inc)

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

-- from src/game/behaviors/seaweed.inc.c:bhv_seaweed_init L3-5
function seaweed_inc.bhv_seaweed_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)))
end

-- from src/game/behaviors/seaweed.inc.c:bhv_seaweed_bundle_init L7-45
function seaweed_inc.bhv_seaweed_bundle_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	local seaweed = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SEAWEED, BehaviorIds.bhvSeaweed)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 14523)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 5500)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 9600)
	seaweed.header.gfx.scale[1] = 1.0
	seaweed.header.gfx.scale[2] = 1.0
	seaweed.header.gfx.scale[3] = 1.0
	-- gfx.animFrame uninitialized in the source

	seaweed = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SEAWEED, BehaviorIds.bhvSeaweed)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 41800)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 6102)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
	seaweed.header.gfx.scale[1] = F32(0.8)
	seaweed.header.gfx.scale[2] = F32(0.9)
	seaweed.header.gfx.scale[3] = F32(0.8)
	seaweed.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)))

	seaweed = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SEAWEED, BehaviorIds.bhvSeaweed)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 40500)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 8700)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 4100)
	seaweed.header.gfx.scale[1] = F32(0.8)
	seaweed.header.gfx.scale[2] = F32(0.8)
	seaweed.header.gfx.scale[3] = F32(0.8)
	seaweed.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)))

	seaweed = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SEAWEED, BehaviorIds.bhvSeaweed)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 57236)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 9500)
	buffer.writei32(seaweed.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
	seaweed.header.gfx.scale[1] = F32(1.2)
	seaweed.header.gfx.scale[2] = F32(1.2)
	seaweed.header.gfx.scale[3] = F32(1.2)
	seaweed.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)))
end

return seaweed_inc
