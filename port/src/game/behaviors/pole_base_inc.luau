--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pole_base.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const pole_base_inc = {}

Registry.Register("src__game__behaviors__pole_base_inc", pole_base_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/pole_base.inc.c:bhv_pole_base_loop L3-10
function pole_base_inc.bhv_pole_base_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 10.0) < buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosY) < F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + o.hitboxHeight) + 30.0) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 and not bit32.btest(LevelUpdate.gMarioStates[1].action, IncludeSm64H.MARIO_PUNCHING) then
			ObjectHelpers.cur_obj_push_mario_away(70.0)
		end
	end
end

return pole_base_inc
