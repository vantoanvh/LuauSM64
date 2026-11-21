--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sound_spawner.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")

const sound_spawner_inc = {}

Registry.Register("src__game__behaviors__sound_spawner_inc", sound_spawner_inc)

-- from src/game/behaviors/sound_spawner.inc.c:bhv_sound_spawner_init L3-6
function sound_spawner_inc.bhv_sound_spawner_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp1C = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundEffectUnkF4)

	Audio.play_sound(sp1C, o.header.gfx.cameraToObject)
end

return sound_spawner_inc
