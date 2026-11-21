--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/spawn_star_exit.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnStarInc = require("./spawn_star_inc")

const spawn_star_exit_inc = {}

Registry.Register("src__game__behaviors__spawn_star_exit_inc", spawn_star_exit_inc)

-- from src/game/behaviors/spawn_star_exit.inc.c:bhv_ccm_touched_star_spawn_loop L3-11
function spawn_star_exit_inc.bhv_ccm_touched_star_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(ObjectListProcessor.gCCMEnteredSlide, 1) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 100.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, 2780.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, 4666.0)
		SpawnStarInc.spawn_default_star(2500.0, -4350.0, 5750.0)
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return spawn_star_exit_inc
