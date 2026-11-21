--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/castle_cannon_grate.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const SaveFile = require("../save_file")

const castle_cannon_grate_inc = {}

Registry.Register("src__game__behaviors__castle_cannon_grate_inc", castle_cannon_grate_inc)

-- from src/game/behaviors/castle_cannon_grate.inc.c:bhv_castle_cannon_grate_init L3-7
function castle_cannon_grate_inc.bhv_castle_cannon_grate_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1) >= 120 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return castle_cannon_grate_inc
