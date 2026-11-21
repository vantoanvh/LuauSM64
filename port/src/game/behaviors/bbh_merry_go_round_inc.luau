--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bbh_merry_go_round.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const IncludeSurfaceTerrainsH = require("../../../include/surface_terrains_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const bbh_merry_go_round_inc = {}

Registry.Register("src__game__behaviors__bbh_merry_go_round_inc", bbh_merry_go_round_inc)

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/bbh_merry_go_round_inc.luau:scratch
const Scratch = {
	handle_merry_go_round_music_marioFloor = {} :: { GroupsTypesHPlus3.Surface? },
}

-- from src/game/behaviors/bbh_merry_go_round.inc.c:handle_merry_go_round_music L13-64
function bbh_merry_go_round_inc.handle_merry_go_round_music()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- If the music should play, play it and check whether it still should.
	-- Otherwise, don't play it and check whether it should.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMusicShouldPlay) == IncludePRUltratypesH.FALSE then
		if ObjectListProcessor.gMarioCurrentRoom == IncludeObjectConstantsH.BBH_NEAR_MERRY_GO_ROUND_ROOM then
			-- Play the merry-go-round and BBH music at the same time
			Audio.play_secondary_music(IncludeSeqIdsH.SEQ_EVENT_MERRY_GO_ROUND, 45, 20, 200)
			-- Set to TRUE
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMusicShouldPlay, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMusicShouldPlay) + 1)
		end
	else
		-- Get Mario's floor and floor surface type
		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		SrcEngineSurfaceCollision.find_floor(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosZ), Scratch.handle_merry_go_round_music_marioFloor)

		const marioFloor = Scratch.handle_merry_go_round_music_marioFloor[1]
		const marioFloorType = if marioFloor == nil then 0 else U16(marioFloor.type_)

		-- All floors in the merry-go-round's enclosure have surface type 0x1A.
		-- The cur_obj_is_mario_on_platform check is redundant since the merry-go-round
		-- has surface type 0x1A, so Mario cannot be on the merry-go-round
		-- without being on a floor with surface type 0x1A (SURFACE_MGR_MUSIC).
		if ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 or marioFloorType == IncludeSurfaceTerrainsH.SURFACE_MGR_MUSIC then
			-- If Mario is in the merry-go-round's enclosure, play only the merry-go-round music.
			Audio.play_secondary_music(IncludeSeqIdsH.SEQ_EVENT_MERRY_GO_ROUND, 0, 78, 50)
			ObjectListProcessor.gMarioOnMerryGoRound = IncludePRUltratypesH.TRUE
		else
			-- If Mario is not in the merry-go-round's enclosure,
			-- i.e. he's around it, play both the merry-go-round music and the BBH music.
			Audio.play_secondary_music(IncludeSeqIdsH.SEQ_EVENT_MERRY_GO_ROUND, 45, 20, 200)
			ObjectListProcessor.gMarioOnMerryGoRound = IncludePRUltratypesH.FALSE
		end

		-- If Mario is not in the merry-go-round's area of the basement anymore,
		-- stop playing the music.
		-- If he is, play the creaking sound.
		if ObjectListProcessor.gMarioCurrentRoom ~= IncludeObjectConstantsH.BBH_DYNAMIC_SURFACE_ROOM and ObjectListProcessor.gMarioCurrentRoom ~= IncludeObjectConstantsH.BBH_NEAR_MERRY_GO_ROUND_ROOM then
			Audio.stop_secondary_music(300)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMusicShouldPlay, IncludePRUltratypesH.FALSE)
		else
			SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_MERRY_GO_ROUND_CREAKING)
		end
	end
end

-- from src/game/behaviors/bbh_merry_go_round.inc.c:bhv_merry_go_round_loop L69-101
function bbh_merry_go_round_inc.bhv_merry_go_round_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Surprisingly, the merry-go-round is what's responsible
	-- for playing the howling wind sound in BBH.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMarioIsOutside) == IncludePRUltratypesH.FALSE then
		if ObjectListProcessor.gMarioCurrentRoom == IncludeObjectConstantsH.BBH_OUTSIDE_ROOM then
			-- Set to TRUE
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMarioIsOutside, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMarioIsOutside) + 1)
		end
	else
		Audio.play_sound(IncludeSoundsH.SOUND_AIR_HOWLING_WIND, Audio.gGlobalSoundSource)

		-- There are objects outside BBH, such as corkboxes.
		-- The howling wind should not stop when Mario stands on a cork box.
		-- @bug Interestingly, this means if Mario goes from outside
		-- to a dynamic surface *inside* the mansion in a single frame,
		-- the howling wind music will still play.
		if ObjectListProcessor.gMarioCurrentRoom ~= IncludeObjectConstantsH.BBH_OUTSIDE_ROOM and ObjectListProcessor.gMarioCurrentRoom ~= IncludeObjectConstantsH.BBH_DYNAMIC_SURFACE_ROOM then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundMarioIsOutside, IncludePRUltratypesH.FALSE)
		end
	end

	-- Rotate the merry-go-round and play appropriate music if it's not stopped.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundStopped) == IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x80)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		bbh_merry_go_round_inc.handle_merry_go_round_music()
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
		Audio.stop_secondary_music(300)
	end
end

return bbh_merry_go_round_inc
