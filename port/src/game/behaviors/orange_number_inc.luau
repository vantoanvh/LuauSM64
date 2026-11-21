--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/orange_number.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const orange_number_inc = {}

Registry.Register("src__game__behaviors__orange_number_inc", orange_number_inc)

-- from src/game/behaviors/orange_number.inc.c:bhv_orange_number_init L3-6
function orange_number_inc.bhv_orange_number_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 26.0)
end

-- from src/game/behaviors/orange_number.inc.c:bhv_orange_number_loop L8-21
function orange_number_inc.bhv_orange_number_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - 2.0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -21.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 14.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 35 then
		const sp1C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
		buffer.writef32(sp1C.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(sp1C.rawData, IncludeObjectFieldsH.oPosY) - 30.0)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return orange_number_inc
