--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/piranha_plant.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const Area = require("../area")
const IncludeLevelTableH = require("../../../include/level_table_h")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/piranha_plant.inc.c:data
const piranha_plant_inc = {
	-- from src/game/behaviors/piranha_plant.inc.c:sPiranhaPlantBiteSoundFrames L237-237
	sPiranhaPlantBiteSoundFrames = { 12, 28, 50, 64, -1 },
}

Registry.Register("src__game__behaviors__piranha_plant_inc", piranha_plant_inc)

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_reset_when_far L143-147
function piranha_plant_inc.piranha_plant_reset_when_far()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_FAR_AWAY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_IDLE)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_idle L13-29
function piranha_plant_inc.piranha_plant_act_idle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_intangible()
	ObjectHelpers.cur_obj_init_animation_with_sound(8)

	-- A Piranha Plant may enter this state with a scale below 1.
	ObjectHelpers.cur_obj_scale(1.0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1200.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_SLEEPING)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_check_interactions L39-62
function piranha_plant_inc.piranha_plant_check_interactions(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local interacted = IncludePRUltratypesH.TRUE

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		Audio.stop_secondary_music(50)
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_WAS_ATTACKED) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_PIRANHA_PLANT_DYING)

			-- Spawn 20 intangible purple particles that quickly dissipate.
			for Index = 1, 20 do
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PURPLE_MARBLE, BehaviorIds.bhvPurpleParticle)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_ATTACKED)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_WOKEN_UP)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	else
		interacted = IncludePRUltratypesH.FALSE
	end

	return interacted
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_sleeping L70-103
function piranha_plant_inc.piranha_plant_act_sleeping()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_tangible()
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_BOUNCE_TOP)

	ObjectHelpers.cur_obj_init_animation_with_sound(8)

	ObjectHelpers.cur_obj_set_hitbox_radius_and_height(250.0, 200.0)
	ObjectHelpers.cur_obj_set_hurtbox_radius_and_height(150.0, 100.0)

	-- Make Piranha Plants harmless, but tangible, while they sleep.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 400.0 then
		if piranha_plant_inc.mario_moving_fast_enough_to_make_piranha_plant_bite() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_WOKEN_UP)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
		Audio.play_secondary_music(IncludeSeqIdsH.SEQ_EVENT_PIRANHA_PLANT, 0, 255, 1000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantSleepMusicState, IncludeObjectConstantsH.PIRANHA_PLANT_SLEEP_MUSIC_PLAYING)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantSleepMusicState) == IncludeObjectConstantsH.PIRANHA_PLANT_SLEEP_MUSIC_PLAYING then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantSleepMusicState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantSleepMusicState) + 1)
		Audio.stop_secondary_music(50)
	end

	piranha_plant_inc.piranha_plant_check_interactions()
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_woken_up L109-125
function piranha_plant_inc.piranha_plant_act_woken_up()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Make Piranha Plants damage the player while awake.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 3)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		Audio.stop_secondary_music(50)
	end

	if piranha_plant_inc.piranha_plant_check_interactions() == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_BITING)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_attacked L154-164
function piranha_plant_inc.piranha_plant_attacked()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_intangible()
	ObjectHelpers.cur_obj_init_animation_with_sound(2)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_SHRINK_AND_DIE)
	end

	piranha_plant_inc.piranha_plant_reset_when_far()
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_shrink_and_die L170-196
function piranha_plant_inc.piranha_plant_act_shrink_and_die()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_ENEMY_DEFEAT_SHRINK)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, 1.0)
	end

	-- Note that this if-statement occurs unconditionally after the above if-statement.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale) > 0.0 then
		-- Shrink by 0.04 per frame.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale) - 0.04)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, 0.0)
		ObjectHelpers.cur_obj_spawn_loot_blue_coin()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_WAIT_TO_RESPAWN)
	end

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale))

	piranha_plant_inc.piranha_plant_reset_when_far()
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_wait_to_respawn L201-205
function piranha_plant_inc.piranha_plant_act_wait_to_respawn()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1200.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_RESPAWN)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_respawn L211-231
function piranha_plant_inc.piranha_plant_act_respawn()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(8)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, 0.3)
	end

	-- This state only occurs after PIRANHA_PLANT_ACT_WAIT_TO_RESPAWN, which in turn only occurs
	-- after PIRANHA_PLANT_ACT_SHRINK_AND_DIE, which sets the scale to 0: the plant grows from the ground.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale) < 1.0 then
		-- Grow by 0.02 per frame.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale) + 0.02)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale, 1.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_IDLE)
	end

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPiranhaPlantScale))
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_biting L245-274
function piranha_plant_inc.piranha_plant_act_biting()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame

	ObjectHelpers.cur_obj_become_tangible()
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_DAMAGE)
	ObjectHelpers.cur_obj_init_animation_with_sound(0)
	ObjectHelpers.cur_obj_set_hitbox_radius_and_height(150.0, 100.0)
	ObjectHelpers.cur_obj_set_hurtbox_radius_and_height(150.0, 100.0)

	-- Play a bite sound effect on certain frames.
	if ObjectHelpers.is_item_in_array(S8(animFrame), piranha_plant_inc.sPiranhaPlantBiteSoundFrames) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_PIRANHA_PLANT_BITE)
	end

	-- Move to face the player.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 500.0 and ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_STOPPED_BITING)
	end

	-- If the player is wearing the Metal Cap and interacts with the Piranha Plant, the Piranha Plant will die.
	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) and bit32.btest(LevelUpdate.gMarioState.flags, IncludeSm64H.MARIO_METAL_CAP) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_ATTACKED)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:mario_moving_fast_enough_to_make_piranha_plant_bite L282-290
function piranha_plant_inc.mario_moving_fast_enough_to_make_piranha_plant_bite(): number
	if LevelUpdate.gMarioStates[1].vel[2] > 10.0 then
		return IncludePRUltratypesH.TRUE
	end

	if LevelUpdate.gMarioStates[1].forwardVel > 10.0 then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/piranha_plant.inc.c:piranha_plant_act_stopped_biting L297-315
function piranha_plant_inc.piranha_plant_act_stopped_biting()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_intangible()
	ObjectHelpers.cur_obj_init_animation_with_sound(6)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_SLEEPING)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 400.0 and piranha_plant_inc.mario_moving_fast_enough_to_make_piranha_plant_bite() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_ACT_BITING)
	end
end

-- from src/game/behaviors/piranha_plant.inc.c:bhv_piranha_plant_loop L335-348
function piranha_plant_inc.bhv_piranha_plant_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_call_action_function(piranha_plant_inc.TablePiranhaPlantActions)

	-- In WF, hide all Piranha Plants once high enough up.
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_WF then
		const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		if buffer.readf32(gMario.rawData, IncludeObjectFieldsH.oPosY) > 3400.0 then
			ObjectHelpers.cur_obj_hide()
		else
			ObjectHelpers.cur_obj_unhide()
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/piranha_plant.inc.c:TablePiranhaPlantActions L320-330
piranha_plant_inc.TablePiranhaPlantActions = {
	piranha_plant_inc.piranha_plant_act_idle,
	piranha_plant_inc.piranha_plant_act_sleeping,
	piranha_plant_inc.piranha_plant_act_biting,
	piranha_plant_inc.piranha_plant_act_woken_up,
	piranha_plant_inc.piranha_plant_act_stopped_biting,
	piranha_plant_inc.piranha_plant_attacked,
	piranha_plant_inc.piranha_plant_act_shrink_and_die,
	piranha_plant_inc.piranha_plant_act_wait_to_respawn,
	piranha_plant_inc.piranha_plant_act_respawn,
}

return piranha_plant_inc
