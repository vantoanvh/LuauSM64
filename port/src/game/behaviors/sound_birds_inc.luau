--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_birds.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const sound_birds_inc = {}

Registry.Register("src__game__behaviors__sound_birds_inc", sound_birds_inc)

-- from src/game/behaviors/sound_birds.inc.c:bhv_birds_sound_loop L3-21
function sound_birds_inc.bhv_birds_sound_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if (Camera.gCamera :: GroupsTypesHPlus3.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		return
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_OBJ2_BIRD_CHIRP1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 1 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_GENERAL2_BIRD_CHIRP2)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 2 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_OBJ_BIRD_CHIRP3)
	end
end

return sound_birds_inc
