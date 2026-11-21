--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pole.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const PoleBaseInc = require("./pole_base_inc")

const pole_inc = {}

Registry.Register("src__game__behaviors__pole_inc", pole_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/pole.inc.c:bhv_pole_init L15-22
function pole_inc.bhv_pole_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const tenthHitboxHeight = bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16, 0xFF)

	o.hitboxHeight = tenthHitboxHeight * 10
end

-- from src/game/behaviors/pole.inc.c:bhv_giant_pole_loop L29-35
function pole_inc.bhv_giant_pole_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		const topBall = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_SPHERE, BehaviorIds.bhvYellowBall)
		buffer.writef32(topBall.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(topBall.rawData, IncludeObjectFieldsH.oPosY) + F32(o.hitboxHeight + 50.0))
	end

	PoleBaseInc.bhv_pole_base_loop()
end

return pole_inc
