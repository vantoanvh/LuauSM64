--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/purple_switch.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const purple_switch_inc = {}

Registry.Register("src__game__behaviors__purple_switch_inc", purple_switch_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/purple_switch.inc.c:bhv_purple_switch_loop L10-87
function purple_switch_inc.bhv_purple_switch_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_IDLE then
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_PURPLE_SWITCH)
		ObjectHelpers.cur_obj_scale(1.5)

		if gMario.platform == o and not bit32.btest(LevelUpdate.gMarioStates[1].action, IncludeSm64H.MARIO_UNKNOWN_13) then
			if ObjectHelpers.lateral_dist_between_objects(o, gMario) < 127.5 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PURPLE_SWITCH_ACT_PRESSED)
			end
		end
	elseif action == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_PRESSED then
		ObjectHelpers.cur_obj_scale_over_time(2, 3, 1.5, F32(0.2))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 3 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_PURPLE_SWITCH)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING)
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		end
	elseif action == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 1 and gMario.platform ~= o then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			else
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 360 then
					Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_FAST, Audio.gGlobalSoundSource)
				else
					Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_SLOW, Audio.gGlobalSoundSource)
				end

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 400 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PURPLE_SWITCH_ACT_WAIT_FOR_MARIO_TO_GET_OFF)
				end
			end
		end
	elseif action == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_UNPRESSED then
		ObjectHelpers.cur_obj_scale_over_time(2, 3, F32(0.2), 1.5)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 3 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PURPLE_SWITCH_ACT_IDLE)
		end
	elseif action == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_WAIT_FOR_MARIO_TO_GET_OFF then
		if ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PURPLE_SWITCH_ACT_UNPRESSED)
		end
	end
end

return purple_switch_inc
