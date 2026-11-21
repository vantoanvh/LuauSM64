--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_ambient.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const sound_ambient_inc = {}

Registry.Register("src__game__behaviors__sound_ambient_inc", sound_ambient_inc)

-- from src/game/behaviors/sound_ambient.inc.c:bhv_ambient_sounds_init L3-9
function sound_ambient_inc.bhv_ambient_sounds_init()
	if (Camera.gCamera :: GroupsTypesHPlus3.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		return
	end

	Audio.play_sound(IncludeSoundsH.SOUND_AIR_CASTLE_OUTDOORS_AMBIENT, Audio.gGlobalSoundSource)
end

return sound_ambient_inc
