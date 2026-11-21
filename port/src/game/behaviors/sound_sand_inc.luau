--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_sand.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const sound_sand_inc = {}

Registry.Register("src__game__behaviors__sound_sand_inc", sound_sand_inc)

-- from src/game/behaviors/sound_sand.inc.c:bhv_sand_sound_loop L3-9
function sound_sand_inc.bhv_sand_sound_loop()
	if (Camera.gCamera :: GroupsTypesHPlus3.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		return
	end

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_MOVINGSAND)
end

return sound_sand_inc
