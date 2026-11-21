--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/breakable_box.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SwitchHiddenObjectsInc = require("./switch_hidden_objects_inc")

const breakable_box_inc = {}

Registry.Register("src__game__behaviors__breakable_box_inc", breakable_box_inc)

-- from src/game/behaviors/breakable_box.inc.c:bhv_breakable_box_loop L3-15
function breakable_box_inc.bhv_breakable_box_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, SwitchHiddenObjectsInc.sBreakableBoxHitbox)
	ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BREAKABLE_BOX_SMALL)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SwitchHiddenObjectsInc.breakable_box_init()
	end

	if ObjectHelpers.cur_obj_was_attacked_or_ground_pounded() ~= 0 then
		ObjectHelpers.obj_explode_and_spawn_coins(46.0, 1)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BREAK_BOX)
	end
end

return breakable_box_inc
