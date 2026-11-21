--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/cannon_door.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SpawnSound = require("../spawn_sound")

const cannon_door_inc = {}

Registry.Register("src__game__behaviors__cannon_door_inc", cannon_door_inc)

-- from src/game/behaviors/cannon_door.inc.c:bhv_cannon_closed_init L3-16
function cannon_door_inc.bhv_cannon_closed_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if SaveFile.save_file_is_cannon_unlocked() == IncludePRUltratypesH.TRUE then
		-- If the cannon is open, spawn a cannon and despawn the object.
		const cannon: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_CANNON_BASE, BehaviorIds.bhvCannon)

		buffer.writei32(cannon.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		buffer.writef32(cannon.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		buffer.writef32(cannon.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(cannon.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_OPEN)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/cannon_door.inc.c:cannon_door_act_opening L18-37
function cannon_door_inc.cannon_door_act_opening()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CANNON_UP)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 30 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -0.5)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 80 then
			cannon_door_inc.bhv_cannon_closed_init()
			return
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 4.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	end
end

-- from src/game/behaviors/cannon_door.inc.c:bhv_cannon_closed_loop L39-62
function cannon_door_inc.bhv_cannon_closed_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_CLOSED then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDrawingDistance, 4000.0)

		if SaveFile.save_file_is_cannon_unlocked() == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_CAM_ZOOM)
		end
	elseif action == IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_CAM_ZOOM then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_OPENING)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDrawingDistance, 20000.0)
	elseif action == IncludeObjectConstantsH.CANNON_TRAP_DOOR_ACT_OPENING then
		cannon_door_inc.cannon_door_act_opening()
	end
end

return cannon_door_inc
