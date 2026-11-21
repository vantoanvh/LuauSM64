--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/moat_drainer.inc.c.
]]

const Registry = require("../../../groups/registry")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")

const moat_drainer_inc = {}

Registry.Register("src__game__behaviors__moat_drainer_inc", moat_drainer_inc)

-- from src/game/behaviors/moat_drainer.inc.c:bhv_invisible_objects_under_bridge_init L3-8
function moat_drainer_inc.bhv_invisible_objects_under_bridge_init()
	if bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_MOAT_DRAINED) then
		const Regions = ObjectListProcessor.gEnvironmentRegions :: number
		Rom.WriteS16(Regions + 2 * 6, -800)
		Rom.WriteS16(Regions + 2 * 12, -800)
	end
end

return moat_drainer_inc
