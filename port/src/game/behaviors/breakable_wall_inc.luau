--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/breakable_wall.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const Audio = require("../../rom/audio_recorder")

const breakable_wall_inc = {}

Registry.Register("src__game__behaviors__breakable_wall_inc", breakable_wall_inc)

-- from src/game/behaviors/breakable_wall.inc.c:bhv_wf_breakable_wall_loop L3-22
function breakable_wall_inc.bhv_wf_breakable_wall_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_SHOT_FROM_CANNON then
		ObjectHelpers.cur_obj_become_tangible()

		if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
			if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvWFBreakableWallRight) ~= 0 then
				Audio.play_puzzle_jingle()
			end

			SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_WALL_EXPLOSION)

			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_DAMAGE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 1)

			ObjectHelpers.obj_explode_and_spawn_coins(80.0, 0)
		end
	else
		ObjectHelpers.cur_obj_become_intangible()
	end
end

return breakable_wall_inc
