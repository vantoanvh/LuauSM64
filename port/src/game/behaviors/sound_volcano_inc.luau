--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_volcano.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const sound_volcano_inc = {}

Registry.Register("src__game__behaviors__sound_volcano_inc", sound_volcano_inc)

-- from src/game/behaviors/sound_volcano.inc.c:bhv_volcano_sound_loop L3-5
function sound_volcano_inc.bhv_volcano_sound_loop()
	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_DRONING1)
end

return sound_volcano_inc
