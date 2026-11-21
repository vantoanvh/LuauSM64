--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/fishing_boo.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const fishing_boo_inc = {}

Registry.Register("src__game__behaviors__fishing_boo_inc", fishing_boo_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/fishing_boo.inc.c:bhv_beta_moving_flames_spawn_loop L10-32
function fishing_boo_inc.bhv_beta_moving_flames_spawn_loop()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, ObjectHelpers.lateral_dist_between_objects(o, mario))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 100)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)
	if action == 0 or action == 1 or action == 2 or action == 3 or action == 4 or action == 5 or action == 6 or action == 7 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvBetaMovingFlames)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, action + 1)
	elseif action == 8 then
		-- Empty in the C source: wait for the spawn loop to end.
	elseif action == 9 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, action + 1)
	end
end

-- from src/game/behaviors/fishing_boo.inc.c:bhv_beta_moving_flames_loop L34-39
function fishing_boo_inc.bhv_beta_moving_flames_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_scale(5)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMovingFlameTimer)) * 70))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMovingFlameTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMovingFlameTimer) + 0x800)
end

return fishing_boo_inc
