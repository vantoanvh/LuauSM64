--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ddd_warp.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const Memory = require("../memory")
const ObjectListProcessor = require("../object_list_processor")
const Paintings = require("../paintings")
const PaintingsH = require("../paintings_h")
const SegmentSymbols = require("../../rom/segment_symbols")

const ddd_warp_inc = {}

Registry.Register("src__game__behaviors__ddd_warp_inc", ddd_warp_inc)

-- from src/game/behaviors/ddd_warp.inc.c:bhv_ddd_warp_loop L3-9
function ddd_warp_inc.bhv_ddd_warp_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(Paintings.gDDDPaintingStatus, PaintingsH.BOWSERS_SUB_BEATEN) then
		o.collisionData = Memory.segmented_to_virtual(SegmentSymbols.inside_castle_seg7_collision_ddd_warp_2)
	else
		o.collisionData = Memory.segmented_to_virtual(SegmentSymbols.inside_castle_seg7_collision_ddd_warp)
	end
end

return ddd_warp_inc
