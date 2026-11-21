--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/white_puff_explode.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")

const white_puff_explode_inc = {}

Registry.Register("src__game__behaviors__white_puff_explode_inc", white_puff_explode_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/white_puff_explode.inc.c:bhv_white_puff_exploding_loop L3-45
function white_puff_explode_inc.bhv_white_puff_exploding_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_compute_vel_xz()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF4, o.header.gfx.scale[1])

		const BhvParams2ndByte = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

		if BhvParams2ndByte == 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 254)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF8, -21)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkFC, 0)
		elseif BhvParams2ndByte == 3 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 254)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF8, -13)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkFC, 1)
		end
	end

	ObjectHelpers.cur_obj_move_using_vel_and_gravity()
	ObjectHelpers.cur_obj_apply_drag_xz(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDragStrength))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 100 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 100)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF8)))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 2 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		const Scale = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkFC) ~= 0 then F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF4) * ((254 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity)) / 254.0)) else F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWhitePuffUnkF4) * (buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) / 254.0))

		ObjectHelpers.cur_obj_scale(Scale)
	end
end

return white_puff_explode_inc
