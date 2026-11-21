--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/floating_box.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const floating_box_inc = {}

Registry.Register("src__game__behaviors__floating_box_inc", floating_box_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/floating_box.inc.c:bhv_jrb_floating_box_loop L3-5
function floating_box_inc.bhv_jrb_floating_box_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x400) * 10))
end

return floating_box_inc
