--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_waterfall.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const sound_waterfall_inc = {}

Registry.Register("src__game__behaviors__sound_waterfall_inc", sound_waterfall_inc)

-- from src/game/behaviors/sound_waterfall.inc.c:bhv_waterfall_sound_loop L3-5
function sound_waterfall_inc.bhv_waterfall_sound_loop()
	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATERFALL2)
end

return sound_waterfall_inc
