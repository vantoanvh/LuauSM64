--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/moat_grill.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const moat_grill_inc = {}

Registry.Register("src__game__behaviors__moat_grill_inc", moat_grill_inc)

-- from src/game/behaviors/moat_grill.inc.c:bhv_moat_grills_loop L3-9
function moat_grill_inc.bhv_moat_grills_loop()
	if bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_MOAT_DRAINED) then
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_NONE)
	else
		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

return moat_grill_inc
