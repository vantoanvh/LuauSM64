--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/static_checkered_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const static_checkered_platform_inc = {}

Registry.Register("src__game__behaviors__static_checkered_platform_inc", static_checkered_platform_inc)

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/static_checkered_platform.inc.c:bhv_static_checkered_platform_loop L3-26
function static_checkered_platform_inc.bhv_static_checkered_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- DEBUG_PAGE_ENEMYINFO is row 6 of gDebugInfo (C index 5)
	if ObjectListProcessor.gDebugInfo[6][1] == 1 then
		ObjectHelpers.obj_set_angle(o, 0, 0, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0)
	end

	if ObjectListProcessor.gDebugInfo[6][1] == 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(bit32.lshift(ObjectListProcessor.gDebugInfo[6][2], 12)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(bit32.lshift(ObjectListProcessor.gDebugInfo[6][3], 12)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(bit32.lshift(ObjectListProcessor.gDebugInfo[6][4], 12)))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, ObjectListProcessor.gDebugInfo[6][5])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, ObjectListProcessor.gDebugInfo[6][6])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, ObjectListProcessor.gDebugInfo[6][7])

	if ObjectListProcessor.gDebugInfo[6][1] == 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll))
	end
end

return static_checkered_platform_inc
