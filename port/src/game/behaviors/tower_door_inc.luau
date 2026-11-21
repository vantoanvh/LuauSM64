--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tower_door.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const KickableBoardInc = require("./kickable_board_inc")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")

const tower_door_inc = {}

Registry.Register("src__game__behaviors__tower_door_inc", tower_door_inc)

-- from src/game/behaviors/tower_door.inc.c:bhv_tower_door_loop L3-12
function tower_door_inc.bhv_tower_door_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x4000)
	end

	if KickableBoardInc.check_mario_attacking(0) ~= 0 then
		ObjectHelpers.obj_explode_and_spawn_coins(80.0, 0)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_WALL_EXPLOSION)
	end
end

return tower_door_inc
