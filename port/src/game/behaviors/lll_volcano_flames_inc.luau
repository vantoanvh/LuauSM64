--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_volcano_flames.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const lll_volcano_flames_inc = {}

Registry.Register("src__game__behaviors__lll_volcano_flames_inc", lll_volcano_flames_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/lll_volcano_flames.inc.c:bhv_volcano_flames_loop L3-16
function lll_volcano_flames_inc.bhv_volcano_flames_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_height()
	ObjectHelpers.cur_obj_compute_vel_xz()

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	ObjectHelpers.cur_obj_move_y(-4.0, F32(-0.7), 2.0)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE, IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_OFF_GROUND)) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return lll_volcano_flames_inc
