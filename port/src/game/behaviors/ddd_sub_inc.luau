--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ddd_sub.inc.c.
]]

const Registry = require("../../../groups/registry")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")

const ddd_sub_inc = {}

Registry.Register("src__game__behaviors__ddd_sub_inc", ddd_sub_inc)

-- from src/game/behaviors/ddd_sub.inc.c:bhv_bowsers_sub_loop L3-7
function ddd_sub_inc.bhv_bowsers_sub_loop()
	const o = ObjectListProcessor.gCurrentObject

	if bit32.btest(SaveFile.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_2, SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return ddd_sub_inc
