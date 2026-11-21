--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/music_touch.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")
const Audio = require("../../rom/audio_recorder")

const music_touch_inc = {}

Registry.Register("src__game__behaviors__music_touch_inc", music_touch_inc)

-- from src/game/behaviors/music_touch.inc.c:bhv_play_music_track_when_touched_loop L3-10
function music_touch_inc.bhv_play_music_track_when_touched_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200.0 then
			Audio.play_puzzle_jingle()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	end
end

return music_touch_inc
