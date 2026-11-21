--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/warp.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")

const warp_inc = {}

Registry.Register("src__game__behaviors__warp_inc", warp_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/warp.inc.c:bhv_warp_loop L3-18
function warp_inc.bhv_warp_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		const BhvParams1stByte = bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF)

		if BhvParams1stByte == 0x00 then
			o.hitboxRadius = 50
		elseif BhvParams1stByte == 0xFF then
			o.hitboxRadius = 10000
		else
			o.hitboxRadius = F32(BhvParams1stByte * 10.0)
		end

		o.hitboxHeight = 50
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/warp.inc.c:bhv_fading_warp_loop L21-36
function warp_inc.bhv_fading_warp_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		const BhvParams1stByte = bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF)

		if BhvParams1stByte == 0x00 then
			o.hitboxRadius = 85
		elseif BhvParams1stByte == 0xFF then
			o.hitboxRadius = 10000
		else
			o.hitboxRadius = F32(BhvParams1stByte * 10.0)
		end

		o.hitboxHeight = 50
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return warp_inc
