--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/unused_particle_spawn.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const unused_particle_spawn_inc = {}

Registry.Register("src__game__behaviors__unused_particle_spawn_inc", unused_particle_spawn_inc)

-- from src/game/behaviors/unused_particle_spawn.inc.c:bhv_unused_particle_spawn_loop L9-25
function unused_particle_spawn_inc.bhv_unused_particle_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)

		for I = 1, 10 do
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PURPLE_MARBLE, BehaviorIds.bhvPurpleParticle)
		end
	end
end

return unused_particle_spawn_inc
