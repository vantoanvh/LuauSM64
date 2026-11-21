--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pyramid_wall.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")

const pyramid_wall_inc = {}

Registry.Register("src__game__behaviors__pyramid_wall_inc", pyramid_wall_inc)

-- from src/game/behaviors/pyramid_wall.inc.c:bhv_ssl_moving_pyramid_wall_init L14-29
function pyramid_wall_inc.bhv_ssl_moving_pyramid_wall_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const positionType = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if positionType == IncludeObjectConstantsH.PYRAMID_WALL_BP_POSITION_HIGH then
		-- Stays at its initial height.
	elseif positionType == IncludeObjectConstantsH.PYRAMID_WALL_BP_POSITION_MIDDLE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 256.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 50)
	elseif positionType == IncludeObjectConstantsH.PYRAMID_WALL_BP_POSITION_LOW then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 512.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_WALL_ACT_MOVING_UP)
	end
end

-- from src/game/behaviors/pyramid_wall.inc.c:bhv_ssl_moving_pyramid_wall_loop L35-53
function pyramid_wall_inc.bhv_ssl_moving_pyramid_wall_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PYRAMID_WALL_ACT_MOVING_DOWN then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -5.12)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_WALL_ACT_MOVING_UP)
		end
	elseif action == IncludeObjectConstantsH.PYRAMID_WALL_ACT_MOVING_UP then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 5.12)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_WALL_ACT_MOVING_DOWN)
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

return pyramid_wall_inc
