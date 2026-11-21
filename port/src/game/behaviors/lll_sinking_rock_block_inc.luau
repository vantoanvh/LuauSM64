--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_sinking_rock_block.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const LllOctagonalRotatingMeshInc = require("./lll_octagonal_rotating_mesh_inc")
const ObjectListProcessor = require("../object_list_processor")

const lll_sinking_rock_block_inc = {}

Registry.Register("src__game__behaviors__lll_sinking_rock_block_inc", lll_sinking_rock_block_inc)

-- from src/game/behaviors/lll_sinking_rock_block.inc.c:bhv_lll_sinking_rock_block_loop L3-8
function lll_sinking_rock_block_inc.bhv_lll_sinking_rock_block_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	LllOctagonalRotatingMeshInc.lll_octagonal_mesh_find_y_offset(o.rawData, IncludeObjectFieldsH.oSinkWhenSteppedOnUnk104, IncludeObjectFieldsH.oSinkWhenSteppedOnUnk108, 124, -110)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oSinkWhenSteppedOnUnk108))
end

return lll_sinking_rock_block_inc
