--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/reds_star_marker.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const ObjectListProcessor = require("../object_list_processor")

const reds_star_marker_inc = {}

Registry.Register("src__game__behaviors__reds_star_marker_inc", reds_star_marker_inc)

-- from src/game/behaviors/reds_star_marker.inc.c:bhv_red_coin_star_marker_init L4-6
function reds_star_marker_inc.bhv_red_coin_star_marker_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.scale[3] = 0.75
end

return reds_star_marker_inc
