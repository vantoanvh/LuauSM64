--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/white_puff.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")

const white_puff_inc = {}

Registry.Register("src__game__behaviors__white_puff_inc", white_puff_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/white_puff.inc.c:bhv_white_puff_1_loop L3-19
function white_puff_inc.bhv_white_puff_1_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.obj_translate_xz_random(o, 40)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 30)
	end

	ObjectHelpers.cur_obj_scale(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0.5) + F32(0.1)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 50)
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 4 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/white_puff.inc.c:bhv_white_puff_2_loop L21-25
function white_puff_inc.bhv_white_puff_2_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.obj_translate_xz_random(o, 40)
	end
end

return white_puff_inc
