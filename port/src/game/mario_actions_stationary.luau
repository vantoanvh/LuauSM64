--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_stationary.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Interaction = require("./interaction")
const Mario = require("./mario")
const Memory = require("./memory")
const MarioStep = require("./mario_step")
const Area = require("./area")
const Camera = require("./camera")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const InteractionH = require("./interaction_h")
const LevelUpdate = require("./level_update")
const LevelUpdateH = require("./level_update_h")
const SaveFile = require("./save_file")
const SoundInit = require("./sound_init")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")

const mario_actions_stationary = {}

Registry.Register("src__game__mario_actions_stationary", mario_actions_stationary)

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/mario_actions_stationary.c:check_common_idle_cancels L20-60
function mario_actions_stationary.check_common_idle_cancels(m: GroupsTypesHPlus3Types.MarioState): number
	Interaction.mario_drop_held_object(m)

	if (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y < F32(0.29237169) then
		return MarioStep.mario_push_off_steep_floor(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FIRST_PERSON, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.faceAngle[2] = S16(m.intendedYaw)

		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PUNCHING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_START_CROUCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:check_common_hold_idle_cancels L62-103
function mario_actions_stationary.check_common_hold_idle_cancels(m: GroupsTypesHPlus3Types.MarioState): number
	if (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y < F32(0.29237169) then
		return MarioStep.mario_push_off_steep_floor(m, IncludeSm64H.ACT_HOLD_FREEFALL, 0)
	end

	if bit32.btest(buffer.readu32((m.heldObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY) then
		buffer.writeu32((m.heldObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.band(buffer.readu32((m.heldObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype), bit32.bnot(InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY)))

		return Mario.set_mario_action(m, IncludeSm64H.ACT_PLACING_DOWN, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_HOLD_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.faceAngle[2] = S16(m.intendedYaw)

		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WALKING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_START_CROUCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_idle L105-173
function mario_actions_stationary.act_idle(m: GroupsTypesHPlus3Types.MarioState): number
	if m.quicksandDepth > 30 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IN_QUICKSAND, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_IN_POISON_GAS) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_COUGHING, 0)
	end

	if not bit32.btest(m.actionArg, 1) and m.health < 0x300 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PANTING, 0)
	end

	if mario_actions_stationary.check_common_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if m.actionState == 3 then
		if bit32.band((m.area :: GroupsTypesHPlus3Types.Area).terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SNOW then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_SHIVERING, 0)
		else
			return Mario.set_mario_action(m, IncludeSm64H.ACT_START_SLEEPING, 0)
		end
	end

	if bit32.btest(m.actionArg, 1) then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STAND_AGAINST_WALL)
	else
		if m.actionState == 0 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAD_LEFT)
		elseif m.actionState == 1 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAD_RIGHT)
		elseif m.actionState == 2 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAD_CENTER)
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			m.actionState = U16(m.actionState + 1)

			if m.actionState == 3 then
				const deltaYOfFloorBehindMario = F32(m.pos[2] - Mario.find_floor_height_relative_polar(m, -0x8000, 60))

				if deltaYOfFloorBehindMario < -24 or 24 < deltaYOfFloorBehindMario or bit32.btest((m.floor :: GroupsTypesHPlus3Types.Surface).flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_DYNAMIC) then
					m.actionState = 0
				else
					m.actionTimer = U16(m.actionTimer + 1)

					if m.actionTimer < 10 then
						m.actionState = 0
					end
				end
			end
		end
	end

	MarioStep.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:play_anim_sound L175-179
function mario_actions_stationary.play_anim_sound(m: GroupsTypesHPlus3Types.MarioState, actionState: number, animFrame: number, sound: number)
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	if m.actionState == actionState and marioObj.header.gfx.animInfo.animFrame == animFrame then
		Audio.play_sound(sound, marioObj.header.gfx.cameraToObject)
	end
end

-- from src/game/mario_actions_stationary.c:act_start_sleeping L181-254
function mario_actions_stationary.act_start_sleeping(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if m.quicksandDepth > 30 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IN_QUICKSAND, 0)
	end

	if m.actionState == 4 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SLEEPING, 0)
	end

	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState
	local animFrame = 0

	if m.actionState == 0 then
		animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_SLEEP_IDLE)
	elseif m.actionState == 1 then
		animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_SLEEP_SCRATCH)
	elseif m.actionState == 2 then
		animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_SLEEP_YAWN)
		bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
	elseif m.actionState == 3 then
		animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_SLEEP_SITTING)
		bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
	end

	mario_actions_stationary.play_anim_sound(m, 1, 41, IncludeSoundsH.SOUND_ACTION_PAT_BACK)
	mario_actions_stationary.play_anim_sound(m, 1, 49, IncludeSoundsH.SOUND_ACTION_PAT_BACK)
	mario_actions_stationary.play_anim_sound(m, 3, 15, m.terrainSoundAddend + IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)

	if Mario.is_anim_at_end(m) ~= 0 then
		m.actionState = U16(m.actionState + 1)
	end

	if m.actionState == 2 and animFrame == -1 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAWNING, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end

	if m.actionState == 1 and animFrame == -1 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_IMA_TIRED, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end

	MarioStep.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_sleeping L256-324
function mario_actions_stationary.act_sleeping(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE, IncludeSm64H.INPUT_FIRST_PERSON, IncludeSm64H.INPUT_STOMPED, IncludeSm64H.INPUT_B_PRESSED, IncludeSm64H.INPUT_Z_PRESSED)) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WAKING_UP, m.actionState)
	end

	if m.quicksandDepth > 30 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WAKING_UP, m.actionState)
	end

	if F32(m.pos[2] - Mario.find_floor_height_relative_polar(m, -0x8000, 60)) > 24 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WAKING_UP, m.actionState)
	end

	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

	bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED
	MarioStep.stationary_ground_step(m)

	if m.actionState == 0 then
		const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLEEP_IDLE)

		if animFrame == -1 and m.actionTimer == 0 then
			SoundInit.lower_background_noise(2)
		end

		if animFrame == 2 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_SNORING1, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		if animFrame == 20 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_SNORING2, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			m.actionTimer = U16(m.actionTimer + 1)
			if m.actionTimer > 45 then
				m.actionState = U16(m.actionState + 1)
			end
		end
	elseif m.actionState == 1 then
		if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLEEP_START_LYING) == 18 then
			Mario.play_mario_heavy_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			m.actionState = U16(m.actionState + 1)
		end
	elseif m.actionState == 2 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLEEP_LYING)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_SNORING3, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_waking_up L326-359
function mario_actions_stationary.act_waking_up(m: GroupsTypesHPlus3Types.MarioState): number
	if m.actionTimer == 0 then
		Audio.stop_sound(IncludeSoundsH.SOUND_MARIO_SNORING1, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		Audio.stop_sound(IncludeSoundsH.SOUND_MARIO_SNORING2, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		Audio.stop_sound(IncludeSoundsH.SOUND_MARIO_SNORING3, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		SoundInit.raise_background_noise(2)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer > 20 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	MarioStep.stationary_ground_step(m)

	if m.actionArg == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WAKE_FROM_SLEEP)
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WAKE_FROM_LYING)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_shivering L361-413
function mario_actions_stationary.act_shivering(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE, IncludeSm64H.INPUT_FIRST_PERSON, IncludeSm64H.INPUT_STOMPED, IncludeSm64H.INPUT_B_PRESSED, IncludeSm64H.INPUT_Z_PRESSED)) then
		m.actionState = 2
	end

	MarioStep.stationary_ground_step(m)

	if m.actionState == 0 then
		const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SHIVERING_WARMING_HAND)

		if animFrame == 49 then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_BREATH)
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_PANTING_COLD, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		if animFrame == 7 or animFrame == 81 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_CLAP_HANDS_COLD, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		if Mario.is_anim_past_end(m) ~= 0 then
			m.actionState = 1
		end
	elseif m.actionState == 1 then
		const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SHIVERING)

		if animFrame == 9 or animFrame == 25 or animFrame == 44 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_CLAP_HANDS_COLD, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end
	elseif m.actionState == 2 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SHIVERING_RETURN_TO_IDLE)

		if Mario.is_anim_past_end(m) ~= 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_coughing L415-437
function mario_actions_stationary.act_coughing(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	MarioStep.stationary_ground_step(m)

	const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_COUGHING)
	const cameraToObject = (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject

	if animFrame == 25 or animFrame == 35 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_COUGHING3, cameraToObject)
	end

	if animFrame == 50 or animFrame == 58 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_COUGHING2, cameraToObject)
	end

	if animFrame == 71 or animFrame == 80 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_COUGHING1, cameraToObject)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_idle L439-459
function mario_actions_stationary.act_hold_idle(m: GroupsTypesHPlus3Types.MarioState): number
	if Memory.segmented_to_virtual(BehaviorIds.bhvJumpingBox) == (m.heldObj :: GroupsTypesHPlus3Types.Object).behavior then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_CRAZY_BOX_BOUNCE, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if m.quicksandDepth > 30 then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_IN_QUICKSAND, 0)
	end

	if mario_actions_stationary.check_common_hold_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_heavy_idle L461-485
function mario_actions_stationary.act_hold_heavy_idle(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_HEAVY_WALKING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HEAVY_THROW, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_HEAVY_OBJ)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_standing_against_wall L487-507
function mario_actions_stationary.act_standing_against_wall(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FIRST_PERSON, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PUNCHING, 0)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STAND_AGAINST_WALL)
	MarioStep.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_in_quicksand L509-526
function mario_actions_stationary.act_in_quicksand(m: GroupsTypesHPlus3Types.MarioState): number
	if m.quicksandDepth < 30 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if mario_actions_stationary.check_common_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if m.quicksandDepth > 70 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DYING_IN_QUICKSAND)
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_IN_QUICKSAND)
	end

	MarioStep.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_crouching L528-564
function mario_actions_stationary.act_crouching(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_BACKFLIP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CROUCHING, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CROUCHING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_START_CRAWLING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PUNCHING, 9)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCHING)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_panting L566-587
function mario_actions_stationary.act_panting(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if m.health >= 0x500 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if mario_actions_stationary.check_common_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALK_PANTING) == 1 then
		-- gAudioRandom is 0 in the port (native stub value): (gAudioRandom % 3U << 0x10) is 0
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_PANTING, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end

	MarioStep.stationary_ground_step(m)

	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

	bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_panting_unused L589-610
function mario_actions_stationary.act_hold_panting_unused(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_PANTING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if m.health >= 0x500 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_IDLE, 0)
	end

	if mario_actions_stationary.check_common_hold_idle_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALK_PANTING)
	MarioStep.stationary_ground_step(m)

	const BodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

	BodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:stopping_step L612-618
function mario_actions_stationary.stopping_step(m: GroupsTypesHPlus3Types.MarioState, animID: number, action: number)
	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, animID)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, action, 0)
	end
end

-- from src/game/mario_actions_stationary.c:act_braking_stop L620-640
function mario_actions_stationary.act_braking_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PUNCHING, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) and bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	mario_actions_stationary.stopping_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_SKID, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_butt_slide_stop L642-657
function mario_actions_stationary.act_butt_slide_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	mario_actions_stationary.stopping_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_SLIDE, IncludeSm64H.ACT_IDLE)

	if (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.animInfo.animFrame == 6 then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_butt_slide_stop L659-678
function mario_actions_stationary.act_hold_butt_slide_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_hold_action_exits(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	mario_actions_stationary.stopping_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STAND_UP_FROM_SLIDING_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_slide_kick_slide_stop L680-691
function mario_actions_stationary.act_slide_kick_slide_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	mario_actions_stationary.stopping_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCH_FROM_SLIDE_KICK, IncludeSm64H.ACT_CROUCHING)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_start_crouching L693-716
function mario_actions_stationary.act_start_crouching(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_BACKFLIP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_CROUCHING)

	if Mario.is_anim_past_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_CROUCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_stop_crouching L718-741
function mario_actions_stationary.act_stop_crouching(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_jumping_action(m, IncludeSm64H.ACT_BACKFLIP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_CROUCHING)

	if Mario.is_anim_past_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_start_crawling L743-767
function mario_actions_stationary.act_start_crawling(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_STOP_CROUCHING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_CRAWLING)

	if Mario.is_anim_past_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_CRAWLING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_stop_crawling L769-788
function mario_actions_stationary.act_stop_crawling(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_CRAWLING)

	if Mario.is_anim_past_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_CROUCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_shockwave_bounce L790-828
function mario_actions_stationary.act_shockwave_bounce(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_SHOCKWAVE) then
		return Mario.hurt_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKED, 0, 4)
	end

	if m.actionTimer == 0 then
		if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_KNOCKBACK_DMG) then
			return Mario.hurt_and_set_mario_action(m, IncludeSm64H.ACT_BACKWARD_GROUND_KB, 0, 0xC)
		end
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 48 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	const sp1E = S16(bit32.lshift(math.fmod(m.actionTimer, 16), 12))
	const sp18 = F32(F32(F32(6 - math.modf(m.actionTimer / 8)) * 8) + 4)

	Mario.mario_set_forward_vel(m, 0)
	SrcEngineMathUtil.vec3f_set(m.vel, 0, 0, 0)

	if SrcEngineMathUtilH.sins(sp1E) >= 0 then
		m.pos[2] = F32(F32(SrcEngineMathUtilH.sins(sp1E) * sp18) + m.floorHeight)
	else
		m.pos[2] = F32(m.floorHeight - F32(SrcEngineMathUtilH.sins(sp1E) * sp18))
	end

	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set((m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.angle, 0, m.faceAngle[2], 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_A_POSE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:landing_step L830-837
function mario_actions_stationary.landing_step(m: GroupsTypesHPlus3Types.MarioState, arg1: number, action: number): number
	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, arg1)

	if Mario.is_anim_at_end(m) ~= 0 then
		return Mario.set_mario_action(m, action, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:check_common_landing_cancels L839-865
function mario_actions_stationary.check_common_landing_cancels(m: GroupsTypesHPlus3Types.MarioState, action: number): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		if action == 0 then
			return Mario.set_jump_from_landing(m)
		else
			return Mario.set_jumping_action(m, action, 0)
		end
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PUNCHING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_jump_land_stop L867-874
function mario_actions_stationary.act_jump_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_landing_cancels(m, 0) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_double_jump_land_stop L876-883
function mario_actions_stationary.act_double_jump_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_landing_cancels(m, 0) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_DOUBLE_JUMP, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_side_flip_land_stop L885-893
function mario_actions_stationary.act_side_flip_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_landing_cancels(m, 0) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDEFLIP_LAND, IncludeSm64H.ACT_IDLE)

	const GfxAngle = (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.angle

	GfxAngle[2] = S16(GfxAngle[2] + 0x8000)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_freefall_land_stop L895-902
function mario_actions_stationary.act_freefall_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_landing_cancels(m, 0) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_triple_jump_land_stop L904-911
function mario_actions_stationary.act_triple_jump_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_landing_cancels(m, IncludeSm64H.ACT_JUMP) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_LAND, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_backflip_land_stop L913-924
function mario_actions_stationary.act_backflip_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if not bit32.btest(m.input, IncludeSm64H.INPUT_Z_DOWN) or (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.animInfo.animFrame >= 6 then
		m.input = U16(bit32.band(m.input, bit32.bnot(IncludeSm64H.INPUT_A_PRESSED)))
	end

	if mario_actions_stationary.check_common_landing_cancels(m, IncludeSm64H.ACT_BACKFLIP) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_LAND, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_lava_boost_land L926-935
function mario_actions_stationary.act_lava_boost_land(m: GroupsTypesHPlus3Types.MarioState): number
	m.input = U16(bit32.band(m.input, bit32.bnot(bit32.bor(IncludeSm64H.INPUT_FIRST_PERSON, IncludeSm64H.INPUT_B_PRESSED))))

	if mario_actions_stationary.check_common_landing_cancels(m, 0) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STAND_UP_FROM_LAVA_BOOST, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_long_jump_land_stop L937-947
function mario_actions_stationary.act_long_jump_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	m.input = U16(bit32.band(m.input, bit32.bnot(IncludeSm64H.INPUT_B_PRESSED)))

	if mario_actions_stationary.check_common_landing_cancels(m, IncludeSm64H.ACT_JUMP) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_stationary.landing_step(m, if buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oMarioLongJumpIsSlow) == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCH_FROM_FAST_LONGJUMP else IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCH_FROM_SLOW_LONGJUMP, IncludeSm64H.ACT_CROUCHING)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_jump_land_stop L949-968
function mario_actions_stationary.act_hold_jump_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_hold_action_exits(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_LAND_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_hold_freefall_land_stop L970-988
function mario_actions_stationary.act_hold_freefall_land_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_hold_action_exits(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_THROWING, 0)
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_LAND_WITH_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_air_throw_land L990-1005
function mario_actions_stationary.act_air_throw_land(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 4 then
		Interaction.mario_throw_held_object(m)
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_THROW_LIGHT_OBJECT, IncludeSm64H.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_twirl_land L1007-1035
function mario_actions_stationary.act_twirl_land(m: GroupsTypesHPlus3Types.MarioState): number
	m.actionState = 1

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TWIRL_LAND)

	if m.angleVel[2] > 0 then
		m.angleVel[2] = S16(m.angleVel[2] - 0x400)

		if m.angleVel[2] < 0 then
			m.angleVel[2] = 0
		end

		m.twirlYaw = S16(m.twirlYaw + m.angleVel[2])
	end

	const GfxAngle = (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.angle

	GfxAngle[2] = S16(GfxAngle[2] + m.twirlYaw)

	if Mario.is_anim_at_end(m) ~= 0 and m.angleVel[2] == 0 then
		m.faceAngle[2] = S16(m.faceAngle[2] + m.twirlYaw)
		Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_ground_pound_land L1037-1053
function mario_actions_stationary.act_ground_pound_land(m: GroupsTypesHPlus3Types.MarioState): number
	m.actionState = 1

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BUTT_SLIDE, 0)
	end

	mario_actions_stationary.landing_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GROUND_POUND_LANDING, IncludeSm64H.ACT_BUTT_SLIDE_STOP)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:act_first_person L1055-1081
function mario_actions_stationary.act_first_person(m: GroupsTypesHPlus3Types.MarioState): number
	const sp1C = bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE, IncludeSm64H.INPUT_STOMPED))

	if m.actionState == 0 then
		SoundInit.lower_background_noise(2)
		Camera.set_camera_mode((m.area :: GroupsTypesHPlus3Types.Area).camera :: GroupsTypesHPlus3Types.Camera, GroupsTypesHPlus3.CAMERA_MODE_C_UP, 0x10)
		m.actionState = 1
	elseif not bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) or sp1C then
		SoundInit.raise_background_noise(2)
		Camera.set_camera_mode((m.area :: GroupsTypesHPlus3Types.Area).camera :: GroupsTypesHPlus3Types.Camera, -1, 1)

		return Mario.set_mario_action(m, IncludeSm64H.ACT_IDLE, 0)
	end

	if (m.floor :: GroupsTypesHPlus3Types.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_LOOK_UP_WARP and SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1) >= 10 then
		const sp1A = (m.statusForCamera :: GroupsTypesHPlus3Types.PlayerCameraState).headRotation[1]
		const sp18 = S16(math.modf((m.statusForCamera :: GroupsTypesHPlus3Types.PlayerCameraState).headRotation[2] * 4 / 3) + m.faceAngle[2])

		if sp1A == -0x1800 and (sp18 < -0x6FFF or sp18 >= 0x7000) then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_UNKNOWN_01)
		end
	end

	MarioStep.stationary_ground_step(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:check_common_stationary_cancels L1083-1104
function mario_actions_stationary.check_common_stationary_cancels(m: GroupsTypesHPlus3Types.MarioState): number
	if m.pos[2] < F32(m.waterLevel - 100) then
		if m.action == IncludeSm64H.ACT_SPAWN_SPIN_LANDING then
			LevelUpdate.load_level_init_text(0)
		end

		Mario.update_mario_sound_and_camera(m)

		return Mario.set_water_plunge_action(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_SQUISHED) then
		Mario.update_mario_sound_and_camera(m)

		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SQUISHED, 0)
	end

	if m.action ~= IncludeSm64H.ACT_UNKNOWN_0002020E then
		if m.health < 0x100 then
			Mario.update_mario_sound_and_camera(m)

			return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_STANDING_DEATH, 0)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_stationary.c:mario_execute_stationary_action L1106-1163
function mario_actions_stationary.mario_execute_stationary_action(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_stationary.check_common_stationary_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if MarioStep.mario_update_quicksand(m, 0.5) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	local cancel = IncludePRUltratypesH.FALSE

	if m.action == IncludeSm64H.ACT_IDLE then
		cancel = mario_actions_stationary.act_idle(m)
	elseif m.action == IncludeSm64H.ACT_START_SLEEPING then
		cancel = mario_actions_stationary.act_start_sleeping(m)
	elseif m.action == IncludeSm64H.ACT_SLEEPING then
		cancel = mario_actions_stationary.act_sleeping(m)
	elseif m.action == IncludeSm64H.ACT_WAKING_UP then
		cancel = mario_actions_stationary.act_waking_up(m)
	elseif m.action == IncludeSm64H.ACT_PANTING then
		cancel = mario_actions_stationary.act_panting(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_PANTING_UNUSED then
		cancel = mario_actions_stationary.act_hold_panting_unused(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_IDLE then
		cancel = mario_actions_stationary.act_hold_idle(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_HEAVY_IDLE then
		cancel = mario_actions_stationary.act_hold_heavy_idle(m)
	elseif m.action == IncludeSm64H.ACT_IN_QUICKSAND then
		cancel = mario_actions_stationary.act_in_quicksand(m)
	elseif m.action == IncludeSm64H.ACT_STANDING_AGAINST_WALL then
		cancel = mario_actions_stationary.act_standing_against_wall(m)
	elseif m.action == IncludeSm64H.ACT_COUGHING then
		cancel = mario_actions_stationary.act_coughing(m)
	elseif m.action == IncludeSm64H.ACT_SHIVERING then
		cancel = mario_actions_stationary.act_shivering(m)
	elseif m.action == IncludeSm64H.ACT_CROUCHING then
		cancel = mario_actions_stationary.act_crouching(m)
	elseif m.action == IncludeSm64H.ACT_START_CROUCHING then
		cancel = mario_actions_stationary.act_start_crouching(m)
	elseif m.action == IncludeSm64H.ACT_STOP_CROUCHING then
		cancel = mario_actions_stationary.act_stop_crouching(m)
	elseif m.action == IncludeSm64H.ACT_START_CRAWLING then
		cancel = mario_actions_stationary.act_start_crawling(m)
	elseif m.action == IncludeSm64H.ACT_STOP_CRAWLING then
		cancel = mario_actions_stationary.act_stop_crawling(m)
	elseif m.action == IncludeSm64H.ACT_SLIDE_KICK_SLIDE_STOP then
		cancel = mario_actions_stationary.act_slide_kick_slide_stop(m)
	elseif m.action == IncludeSm64H.ACT_SHOCKWAVE_BOUNCE then
		cancel = mario_actions_stationary.act_shockwave_bounce(m)
	elseif m.action == IncludeSm64H.ACT_FIRST_PERSON then
		cancel = mario_actions_stationary.act_first_person(m)
	elseif m.action == IncludeSm64H.ACT_JUMP_LAND_STOP then
		cancel = mario_actions_stationary.act_jump_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_DOUBLE_JUMP_LAND_STOP then
		cancel = mario_actions_stationary.act_double_jump_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_FREEFALL_LAND_STOP then
		cancel = mario_actions_stationary.act_freefall_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_SIDE_FLIP_LAND_STOP then
		cancel = mario_actions_stationary.act_side_flip_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_JUMP_LAND_STOP then
		cancel = mario_actions_stationary.act_hold_jump_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_FREEFALL_LAND_STOP then
		cancel = mario_actions_stationary.act_hold_freefall_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_AIR_THROW_LAND then
		cancel = mario_actions_stationary.act_air_throw_land(m)
	elseif m.action == IncludeSm64H.ACT_LAVA_BOOST_LAND then
		cancel = mario_actions_stationary.act_lava_boost_land(m)
	elseif m.action == IncludeSm64H.ACT_TWIRL_LAND then
		cancel = mario_actions_stationary.act_twirl_land(m)
	elseif m.action == IncludeSm64H.ACT_TRIPLE_JUMP_LAND_STOP then
		cancel = mario_actions_stationary.act_triple_jump_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_BACKFLIP_LAND_STOP then
		cancel = mario_actions_stationary.act_backflip_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_LONG_JUMP_LAND_STOP then
		cancel = mario_actions_stationary.act_long_jump_land_stop(m)
	elseif m.action == IncludeSm64H.ACT_GROUND_POUND_LAND then
		cancel = mario_actions_stationary.act_ground_pound_land(m)
	elseif m.action == IncludeSm64H.ACT_BRAKING_STOP then
		cancel = mario_actions_stationary.act_braking_stop(m)
	elseif m.action == IncludeSm64H.ACT_BUTT_SLIDE_STOP then
		cancel = mario_actions_stationary.act_butt_slide_stop(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_BUTT_SLIDE_STOP then
		cancel = mario_actions_stationary.act_hold_butt_slide_stop(m)
	end

	if cancel == 0 and bit32.btest(m.input, IncludeSm64H.INPUT_IN_WATER) then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_IDLE_WATER_WAVE)
	end

	return cancel
end

return mario_actions_stationary
