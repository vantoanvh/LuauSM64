--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_object.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const Audio = require("../rom/audio_recorder")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Interaction = require("./interaction")
const InteractionH = require("./interaction_h")
const Mario = require("./mario")
const SrcEngineMathUtil = require("../engine/math_util")

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/mario_actions_object.c:data
const mario_actions_object = {
	-- from src/game/mario_actions_object.c:sPunchingForwardVelocities L17-17
	sPunchingForwardVelocities = { 0, 1, 1, 2, 3, 5, 7, 10 },
}

Registry.Register("src__game__mario_actions_object", mario_actions_object)

-- from src/game/mario_actions_object.c:animated_stationary_ground_step L19-25
function mario_actions_object.animated_stationary_ground_step(m: GroupsTypesHPlus3Types.MarioState, animation: number, endAction: number)
	Registry.Members.src__game__mario_step.stationary_ground_step(m)
	Mario.set_mario_animation(m, animation)
	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, endAction, 0)
	end
end

-- from src/game/mario_actions_object.c:mario_update_punch_sequence L27-145
function mario_actions_object.mario_update_punch_sequence(m: GroupsTypesHPlus3Types.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object
	const endAction = if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_MOVING) then IncludeSm64H.ACT_WALKING else IncludeSm64H.ACT_IDLE
	const crouchEndAction = if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_MOVING) then IncludeSm64H.ACT_CROUCH_SLIDE else IncludeSm64H.ACT_CROUCHING

	if m.actionArg == 0 or m.actionArg == 1 then
		if m.actionArg == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_PUNCH_YAH, marioObj.header.gfx.cameraToObject)
		end

		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PUNCH)

		if Mario.is_anim_past_end(m) ~= 0 then
			m.actionArg = 2
		else
			m.actionArg = 1
		end

		if marioObj.header.gfx.animInfo.animFrame >= 2 then
			if Interaction.mario_check_object_grab(m) ~= 0 then
				return IncludePRUltratypesH.TRUE
			end

			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_PUNCHING)
		end

		if m.actionArg == 2 then
			const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

			bodyState.punchState = U8(bit32.bor(bit32.lshift(0, 6), 4))
		end
	elseif m.actionArg == 2 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PUNCH_FAST)

		if marioObj.header.gfx.animInfo.animFrame <= 0 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_PUNCHING)
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
			m.actionArg = 3
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, endAction, 0)
		end
	elseif m.actionArg == 3 or m.actionArg == 4 then
		if m.actionArg == 3 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_PUNCH_WAH, marioObj.header.gfx.cameraToObject)
		end

		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SECOND_PUNCH)

		if Mario.is_anim_past_end(m) ~= 0 then
			m.actionArg = 5
		else
			m.actionArg = 4
		end

		if marioObj.header.gfx.animInfo.animFrame > 0 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_PUNCHING)
		end

		if m.actionArg == 5 then
			const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

			bodyState.punchState = U8(bit32.bor(bit32.lshift(1, 6), 4))
		end
	elseif m.actionArg == 5 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SECOND_PUNCH_FAST)

		if marioObj.header.gfx.animInfo.animFrame <= 0 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_PUNCHING)
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
			m.actionArg = 6
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, endAction, 0)
		end
	elseif m.actionArg == 6 then
		Mario.play_mario_action_sound(m, IncludeSoundsH.SOUND_MARIO_PUNCH_HOO, 1)

		const animFrame = Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GROUND_KICK)

		if animFrame == 0 then
			const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

			bodyState.punchState = U8(bit32.bor(bit32.lshift(2, 6), 6))
		end

		if animFrame >= 0 and animFrame < 8 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_KICKING)
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, endAction, 0)
		end
	elseif m.actionArg == 9 then
		Mario.play_mario_action_sound(m, IncludeSoundsH.SOUND_MARIO_PUNCH_HOO, 1)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BREAKDANCE)

		const animFrame = marioObj.header.gfx.animInfo.animFrame

		if animFrame >= 2 and animFrame < 8 then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_TRIPPING)
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, crouchEndAction, 0)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_punching L147-173
function mario_actions_object.act_punching(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED, IncludeSm64H.INPUT_OFF_FLOOR, IncludeSm64H.INPUT_ABOVE_SLIDE)) then
		return Mario.check_common_action_exits(m)
	end

	if m.actionState == 0 and bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_JUMP_KICK, 0)
	end

	m.actionState = 1
	if m.actionArg == 0 then
		m.actionTimer = 7
	end

	Mario.mario_set_forward_vel(m, mario_actions_object.sPunchingForwardVelocities[m.actionTimer + 1])
	if m.actionTimer > 0 then
		m.actionTimer = U16(m.actionTimer - 1)
	end

	mario_actions_object.mario_update_punch_sequence(m)
	Registry.Members.src__game__mario_step.perform_ground_step(m)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_picking_up L175-211
function mario_actions_object.act_picking_up(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if m.actionState == 0 and Mario.is_anim_at_end(m) ~= 0 then
		Interaction.mario_grab_used_object(m)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_HRMM, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
		m.actionState = 1
	end

	if m.actionState == 1 then
		const BodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState
		if bit32.btest(buffer.readu32((m.heldObj :: GroupsTypesHPlus3Types.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO) then
			BodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_HEAVY_OBJ
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GRAB_HEAVY_OBJECT)
			if Mario.is_anim_at_end(m) ~= 0 then
				Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_HEAVY_IDLE, 0)
			end
		else
			BodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_LIGHT_OBJ
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PICK_UP_LIGHT_OBJ)
			if Mario.is_anim_at_end(m) ~= 0 then
				Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_IDLE, 0)
			end
		end
	end

	Registry.Members.src__game__mario_step.stationary_ground_step(m)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_dive_picking_up L213-231
function mario_actions_object.act_dive_picking_up(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_SLIDE_LIGHT_OBJ, IncludeSm64H.ACT_HOLD_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_placing_down L233-248
function mario_actions_object.act_placing_down(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)
	if m.actionTimer == 8 then
		Interaction.mario_drop_held_object(m)
	end

	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PLACE_LIGHT_OBJ, IncludeSm64H.ACT_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_throwing L250-274
function mario_actions_object.act_throwing(m: GroupsTypesHPlus3Types.MarioState): number
	if m.heldObj ~= nil and bit32.btest(buffer.readu32(m.heldObj.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_HOLDABLE_NPC) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_PLACING_DOWN, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)
	if m.actionTimer == 7 then
		Interaction.mario_throw_held_object(m)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAH2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_THROW, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	end

	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GROUND_THROW, IncludeSm64H.ACT_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_heavy_throw L276-296
function mario_actions_object.act_heavy_throw(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)
	if m.actionTimer == 13 then
		Interaction.mario_drop_held_object(m)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAH2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_THROW, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	end

	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HEAVY_THROW, IncludeSm64H.ACT_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_stomach_slide_stop L298-313
function mario_actions_object.act_stomach_slide_stop(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_STOMPED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SHOCKWAVE_BOUNCE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLOW_LAND_FROM_DIVE, IncludeSm64H.ACT_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_picking_up_bowser L315-334
function mario_actions_object.act_picking_up_bowser(m: GroupsTypesHPlus3Types.MarioState): number
	if m.actionState == 0 then
		const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

		m.actionState = 1
		m.angleVel[2] = 0
		bodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_BOWSER
		Interaction.mario_grab_used_object(m)
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HRMM, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GRAB_BOWSER)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLDING_BOWSER, 0)
	end

	Registry.Members.src__game__mario_step.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_holding_bowser L336-419
function mario_actions_object.act_holding_bowser(m: GroupsTypesHPlus3Types.MarioState): number
	local spin: number

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		if m.angleVel[2] <= -0xE00 or m.angleVel[2] >= 0xE00 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_SO_LONGA_BOWSER, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_RELEASING_BOWSER, 0)
	end

	if m.angleVel[2] == 0 then
		const timerExceeded = m.actionTimer > 120

		m.actionTimer = U16(m.actionTimer + 1)

		if timerExceeded then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_RELEASING_BOWSER, 1)
		end

		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HOLDING_BOWSER)
	else
		m.actionTimer = 0
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SWINGING_BOWSER)
	end

	if m.intendedMag > 20 then
		if m.actionArg == 0 then
			m.actionArg = 1
			m.twirlYaw = m.intendedYaw
		else
			-- spin = acceleration
			spin = S16(TruncS32(S16(m.intendedYaw - m.twirlYaw) / 0x80))

			if spin < -0x80 then
				spin = -0x80
			end
			if spin > 0x80 then
				spin = 0x80
			end

			m.twirlYaw = m.intendedYaw
			m.angleVel[2] = S16(m.angleVel[2] + spin)

			if m.angleVel[2] > 0x1000 then
				m.angleVel[2] = 0x1000
			end
			if m.angleVel[2] < -0x1000 then
				m.angleVel[2] = -0x1000
			end
		end
	else
		m.actionArg = 0
		m.angleVel[2] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[2], 0, 64, 64))
	end

	-- spin = starting yaw
	spin = m.faceAngle[2]
	m.faceAngle[2] = S16(m.faceAngle[2] + m.angleVel[2])

	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	-- play sound on overflow
	if m.angleVel[2] <= -0x100 and spin < m.faceAngle[2] then
		Audio.play_sound(IncludeSoundsH.SOUND_OBJ_BOWSER_SPINNING, marioObj.header.gfx.cameraToObject)
	end

	if m.angleVel[2] >= 0x100 and spin > m.faceAngle[2] then
		Audio.play_sound(IncludeSoundsH.SOUND_OBJ_BOWSER_SPINNING, marioObj.header.gfx.cameraToObject)
	end

	Registry.Members.src__game__mario_step.stationary_ground_step(m)

	if m.angleVel[2] >= 0 then
		marioObj.header.gfx.angle[1] = S16(-m.angleVel[2])
	else
		marioObj.header.gfx.angle[1] = m.angleVel[2]
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:act_releasing_bowser L421-439
function mario_actions_object.act_releasing_bowser(m: GroupsTypesHPlus3Types.MarioState): number
	m.actionTimer = U16(m.actionTimer + 1)
	if m.actionTimer == 1 then
		if m.actionArg == 0 then
			Interaction.mario_throw_held_object(m)
		else
			Interaction.mario_drop_held_object(m)
		end
	end

	m.angleVel[2] = 0
	mario_actions_object.animated_stationary_ground_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RELEASE_BOWSER, IncludeSm64H.ACT_IDLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:check_common_object_cancels L441-456
function mario_actions_object.check_common_object_cancels(m: GroupsTypesHPlus3Types.MarioState): number
	const waterSurface = F32(m.waterLevel - 100)
	if m.pos[2] < waterSurface then
		return Mario.set_water_plunge_action(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_SQUISHED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SQUISHED, 0)
	end

	if m.health < 0x100 then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_STANDING_DEATH, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_object.c:mario_execute_object_action L458-489
function mario_actions_object.mario_execute_object_action(m: GroupsTypesHPlus3Types.MarioState): number
	if mario_actions_object.check_common_object_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if Registry.Members.src__game__mario_step.mario_update_quicksand(m, 0.5) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	local cancel = IncludePRUltratypesH.FALSE
	if m.action == IncludeSm64H.ACT_PUNCHING then
		cancel = mario_actions_object.act_punching(m)
	elseif m.action == IncludeSm64H.ACT_PICKING_UP then
		cancel = mario_actions_object.act_picking_up(m)
	elseif m.action == IncludeSm64H.ACT_DIVE_PICKING_UP then
		cancel = mario_actions_object.act_dive_picking_up(m)
	elseif m.action == IncludeSm64H.ACT_STOMACH_SLIDE_STOP then
		cancel = mario_actions_object.act_stomach_slide_stop(m)
	elseif m.action == IncludeSm64H.ACT_PLACING_DOWN then
		cancel = mario_actions_object.act_placing_down(m)
	elseif m.action == IncludeSm64H.ACT_THROWING then
		cancel = mario_actions_object.act_throwing(m)
	elseif m.action == IncludeSm64H.ACT_HEAVY_THROW then
		cancel = mario_actions_object.act_heavy_throw(m)
	elseif m.action == IncludeSm64H.ACT_PICKING_UP_BOWSER then
		cancel = mario_actions_object.act_picking_up_bowser(m)
	elseif m.action == IncludeSm64H.ACT_HOLDING_BOWSER then
		cancel = mario_actions_object.act_holding_bowser(m)
	elseif m.action == IncludeSm64H.ACT_RELEASING_BOWSER then
		cancel = mario_actions_object.act_releasing_bowser(m)
	end

	if cancel == 0 and bit32.btest(m.input, IncludeSm64H.INPUT_IN_WATER) then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_IDLE_WATER_WAVE)
	end

	return cancel
end

return mario_actions_object
