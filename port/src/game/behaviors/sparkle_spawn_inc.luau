--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sparkle_spawn.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")

const sparkle_spawn_inc = {}

Registry.Register("src__game__behaviors__sparkle_spawn_inc", sparkle_spawn_inc)

-- from src/game/behaviors/sparkle_spawn.inc.c:bhv_sparkle_spawn_loop L10-19
function sparkle_spawn_inc.bhv_sparkle_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sparkle = ObjectHelpers.try_to_spawn_object(0, 1.0, o, IncludeModelIdsH.MODEL_SPARKLES_ANIMATION, BehaviorIds.bhvSparkle)

	if sparkle ~= nil then
		ObjectHelpers.obj_translate_xyz_random(sparkle, 90.0)
		ObjectHelpers.obj_scale_random(sparkle, 1.0, 0.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 1 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return sparkle_spawn_inc
