--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/boo_cage.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const Audio = require("../../rom/audio_recorder")

-- from src/game/behaviors/boo_cage.inc.c:data
const boo_cage_inc = {
	-- from src/game/behaviors/boo_cage.inc.c:sBooCageHitbox L13-23
	sBooCageHitbox = {
		interactType = InteractionH.INTERACT_BBH_ENTRANCE,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 120,
		height = 300,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__boo_cage_inc", boo_cage_inc)

-- from src/game/behaviors/boo_cage.inc.c:bhv_boo_cage_loop L28-112
function boo_cage_inc.bhv_boo_cage_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	ObjectHelpers.obj_set_hitbox(o, boo_cage_inc.sBooCageHitbox)

	if action == IncludeObjectConstantsH.BOO_CAGE_ACT_IN_BOO then
		-- Don't let Mario enter BBH until the boo is killed
		ObjectHelpers.cur_obj_become_intangible()

		-- Useless scale. This is also found in the code for BOO_CAGE_ACT_ON_GROUND.
		-- Was the boo cage originally meant to have been shrunk and grow while falling?
		ObjectHelpers.cur_obj_scale(1.0)

		-- If the cage's parent boo is killed, set the action to BOO_CAGE_ACT_FALLING,
		-- give the cage an initial Y velocity of 60 units/frame, and play the puzzle jingle.
		-- Otherwise, stay inside the boo.
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBooDeathStatus) ~= IncludeObjectConstantsH.BOO_DEATH_STATUS_ALIVE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 60.0)
			Audio.play_puzzle_jingle()
		else
			ObjectHelpers.obj_copy_pos_and_angle(o, o.parentObj :: GroupsTypesHPlus3.Object)
		end
	elseif action == IncludeObjectConstantsH.BOO_CAGE_ACT_FALLING then
		-- Reset pitch and roll. This is useless, since the cage never rotates.
		-- Was it meant to rotate inside the boo, like the beta boo key?
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)

		-- Apply standard physics to the cage.
		ObjectHelpers.cur_obj_update_floor_and_walls()
		ObjectHelpers.cur_obj_move_standard(-78)

		-- Spawn sparkles while the cage falls.
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)

		-- When the cage lands/bounces, play a landing/bouncing sound.
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SOFT_LANDING)
		end

		-- Once the cage stops bouncing and settles on the ground,
		-- set the action to BOO_CAGE_ACT_ON_GROUND.
		-- This is the only use of the OBJ_MOVE_AT_WATER_SURFACE flag in the game.
		-- It seems to serve no purpose here.
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE, IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BOO_CAGE_ACT_ON_GROUND then
		-- Allow Mario to enter the cage once it's still on the ground.
		ObjectHelpers.cur_obj_become_tangible()

		-- The other useless scale
		ObjectHelpers.cur_obj_scale(1.0)

		-- Set the action to BOO_CAGE_ACT_MARIO_JUMPING_IN when Mario jumps in.
		if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BOO_CAGE_ACT_MARIO_JUMPING_IN then
		-- All this action does is wait 100 frames after Mario starts
		-- jumping into the cage to set the action to BOO_CAGE_ACT_USELESS,
		-- which does nothing. By extension, this action is also useless.

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BOO_CAGE_ACT_USELESS then
		-- Nothing to do.
	end
end

return boo_cage_inc
