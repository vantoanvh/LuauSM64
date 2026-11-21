--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bubble.inc.c.
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
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const bubble_inc = {}

Registry.Register("src__game__behaviors__bubble_inc", bubble_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/bubble.inc.c:bhv_object_bubble_init L3-7
function bubble_inc.bhv_object_bubble_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineBehaviorScript.random_float() * 30.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(SrcEngineBehaviorScript.random_float() * 30.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineBehaviorScript.random_float() * 30.0))
end

-- from src/game/behaviors/bubble.inc.c:bhv_object_bubble_loop L9-24
function bubble_inc.bhv_object_bubble_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const waterY = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const bubbleY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)

	if bubbleY > waterY then
		if ObjectListProcessor.gFreeObjectList.ObjectNode_next ~= nil then
			const bubbleSplash = ObjectHelpers.spawn_object_at_origin(o, 0, IncludeModelIdsH.MODEL_SMALL_WATER_SPLASH, BehaviorIds.bhvBubbleSplash)

			buffer.writef32(bubbleSplash.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
			buffer.writef32(bubbleSplash.rawData, IncludeObjectFieldsH.oPosY, bubbleY + 5.0)
			buffer.writef32(bubbleSplash.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return bubble_inc
