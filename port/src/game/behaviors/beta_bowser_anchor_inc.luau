--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_bowser_anchor.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const beta_bowser_anchor_inc = {}

Registry.Register("src__game__behaviors__beta_bowser_anchor_inc", beta_bowser_anchor_inc)

-- from src/game/behaviors/beta_bowser_anchor.inc.c:bhv_beta_bowser_anchor_loop L15-24
function beta_bowser_anchor_inc.bhv_beta_bowser_anchor_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Set the object's position to be 30 units above Mario's feet,
	-- and 300 units in front of him.
	ObjectHelpers.cur_obj_set_pos_relative(ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 0, 30.0, 300.0)

	-- DEBUG_PAGE_EFFECTINFO is 4 (gDebugInfo row 5)
	o.hitboxRadius = ObjectListProcessor.gDebugInfo[5][1] + 100
	o.hitboxHeight = ObjectListProcessor.gDebugInfo[5][2] + 300

	ObjectHelpers.obj_attack_collided_from_other_object(o)
end

return beta_bowser_anchor_inc
