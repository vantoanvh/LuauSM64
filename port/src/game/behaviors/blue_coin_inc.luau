--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/blue_coin.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const blue_coin_inc = {}

Registry.Register("src__game__behaviors__blue_coin_inc", blue_coin_inc)

-- from src/game/behaviors/blue_coin.inc.c:bhv_hidden_blue_coin_loop L11-60
function blue_coin_inc.bhv_hidden_blue_coin_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.HIDDEN_BLUE_COIN_ACT_INACTIVE then
		-- Become invisible and intangible
		ObjectHelpers.cur_obj_disable_rendering()
		ObjectHelpers.cur_obj_become_intangible()

		-- Set action to HIDDEN_BLUE_COIN_ACT_WAITING after the blue coin switch is found.
		o.ptrData[IncludeObjectFieldsH.oHiddenBlueCoinSwitch + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvBlueCoinSwitch)

		if o.ptrData[IncludeObjectFieldsH.oHiddenBlueCoinSwitch + 1] ~= nil then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.HIDDEN_BLUE_COIN_ACT_WAITING then
		-- Wait until the blue coin switch starts ticking to activate.
		const blueCoinSwitch = o.ptrData[IncludeObjectFieldsH.oHiddenBlueCoinSwitch + 1] :: GroupsTypesHPlus3.Object

		if buffer.readi32(blueCoinSwitch.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BLUE_COIN_SWITCH_ACT_TICKING then
			-- Set to HIDDEN_BLUE_COIN_ACT_ACTIVE
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.HIDDEN_BLUE_COIN_ACT_ACTIVE then
		-- Become tangible
		ObjectHelpers.cur_obj_enable_rendering()
		ObjectHelpers.cur_obj_become_tangible()

		-- Delete the coin once collected
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		-- After 200 frames of waiting and 20 2-frame blinks (for 240 frames total),
		-- delete the object.
		if ObjectHelpers.cur_obj_wait_then_blink(200, 20) ~= 0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/blue_coin.inc.c:bhv_blue_coin_switch_loop L65-132
function blue_coin_inc.bhv_blue_coin_switch_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	-- The switch's model is 1/3 size.
	ObjectHelpers.cur_obj_scale(3.0)

	if action == IncludeObjectConstantsH.BLUE_COIN_SWITCH_ACT_IDLE then
		-- If Mario is on the switch and has ground-pounded,
		-- recede and get ready to start ticking.
		if marioObj.platform == o then
			if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_GROUND_POUND_LAND then
				-- Set to BLUE_COIN_SWITCH_ACT_RECEDING
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)

				-- Recede at a rate of 20 units/frame.
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -20.0)
				-- Set gravity to 0 so it doesn't accelerate when receding.
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)

				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWITCH_DOOR_OPEN)
			end
		end

		-- Have collision
		SrcEngineSurfaceLoad.load_object_collision_model()
	elseif action == IncludeObjectConstantsH.BLUE_COIN_SWITCH_ACT_RECEDING then
		-- Recede for 6 frames before going invisible and ticking.
		-- This is probably an off-by-one error, since the switch is 100 units tall
		-- and recedes at 20 units/frame, which means it will fully recede after 5 frames.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
			ObjectHelpers.cur_obj_hide()

			-- Set to BLUE_COIN_SWITCH_ACT_TICKING
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			-- ???
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) - 40.0)

			-- Spawn particles. There's a function that calls this same function
			-- with the same arguments, spawn_mist_particles, why didn't they just call that?
			BehaviorActions.spawn_mist_particles_variable(0, 0, 46.0)
		else
			-- Have collision while receding
			SrcEngineSurfaceLoad.load_object_collision_model()
			-- Recede
			ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
		end
	elseif action == IncludeObjectConstantsH.BLUE_COIN_SWITCH_ACT_TICKING then
		-- Tick faster when the blue coins start blinking
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 200 then
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_FAST, Audio.gGlobalSoundSource)
		else
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_SLOW, Audio.gGlobalSoundSource)
		end

		-- Delete the switch (which stops the sound) after the last coin is collected,
		-- or after the coins unload after the 240-frame timer expires.
		if ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHiddenBlueCoin) == nil or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 240 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end
end

return blue_coin_inc
