--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ddd_pole.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")

const ddd_pole_inc = {}

Registry.Register("src__game__behaviors__ddd_pole_inc", ddd_pole_inc)


-- from src/game/behaviors/ddd_pole.inc.c:bhv_ddd_pole_init L3-10
function ddd_pole_inc.bhv_ddd_pole_init()
	const o = ObjectListProcessor.gCurrentObject

	if not bit32.btest(SaveFile.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_2, SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		o.hitboxDownOffset = 100
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDDDPoleMaxOffset, 100 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	end
end

-- from src/game/behaviors/ddd_pole.inc.c:bhv_ddd_pole_update L12-23
function ddd_pole_inc.bhv_ddd_pole_update()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDDDPoleOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDDDPoleOffset) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oDDDPoleVel))

		const Clamped: number = ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oDDDPoleOffset, 0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDDDPoleMaxOffset))

		if Clamped ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oDDDPoleVel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oDDDPoleVel))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end

	ObjBehaviors2.obj_set_dist_from_home(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDDDPoleOffset))
end

return ddd_pole_inc
