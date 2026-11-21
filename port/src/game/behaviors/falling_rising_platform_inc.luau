--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/falling_rising_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const falling_rising_platform_inc = {}

Registry.Register("src__game__behaviors__falling_rising_platform_inc", falling_rising_platform_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/falling_rising_platform.inc.c:bhv_squishable_platform_loop L3-6
function falling_rising_platform_inc.bhv_squishable_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	o.header.gfx.scale[2] = F32((SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer)) + 1) * 0.3 + 0.4)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer) + 0x80)
end

-- from src/game/behaviors/falling_rising_platform.inc.c:bhv_bitfs_sinking_platform_loop L8-12
function falling_rising_platform_inc.bhv_bitfs_sinking_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	-- f32 double conversion error accumulates on Wii VC causing the platform to rise up
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer)) * 0.58)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer) + 0x100)
end

-- from src/game/behaviors/falling_rising_platform.inc.c:bhv_ddd_moving_pole_loop L15-17
function falling_rising_platform_inc.bhv_ddd_moving_pole_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.obj_copy_pos_and_angle(o, o.parentObj :: GroupsTypesHPlus3.Object)
end

-- from src/game/behaviors/falling_rising_platform.inc.c:bhv_bitfs_sinking_cage_platform_loop L19-30
function falling_rising_platform_inc.bhv_bitfs_sinking_cage_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 300)
		end
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer)) * 7))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer)) * 3))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitFSPlatformTimer) + 0x100)
end

return falling_rising_platform_inc
