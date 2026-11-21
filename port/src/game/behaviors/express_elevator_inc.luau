--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/express_elevator.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const express_elevator_inc = {}

Registry.Register("src__game__behaviors__express_elevator_inc", express_elevator_inc)

-- from src/game/behaviors/express_elevator.inc.c:bhv_wdw_express_elevator_loop L3-31
function express_elevator_inc.bhv_wdw_express_elevator_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -20)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR4)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 132 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 110 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 10)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR4)
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) >= buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

return express_elevator_inc
