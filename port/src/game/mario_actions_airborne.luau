--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_airborne.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSoundsH = require("../../include/sounds_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Mario = require("./mario")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const Camera = require("./camera")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const MarioStep = require("./mario_step")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const InteractionH = require("./interaction_h")
const SaveFile = require("./save_file")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const Interaction = require("./interaction")
const Rom = require("../rom/rom")
const Audio = require("../rom/audio_recorder")
const LevelUpdate = require("./level_update")
const LevelUpdateH = require("./level_update_h")
const GameInit = require("./game_init")

const mario_actions_airborne = {}

Registry.Register("src__game__mario_actions_airborne", mario_actions_airborne)

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/mario_actions_airborne.c:play_flip_sounds L17-22
function mario_actions_airborne.play_flip_sounds(m: GroupsTypesHPlus3.MarioState, frame1: number, frame2: number, frame3: number)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const animFrame = marioObj.header.gfx.animInfo.animFrame

	if animFrame == frame1 or animFrame == frame2 or animFrame == frame3 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, marioObj.header.gfx.cameraToObject)
	end
end

-- from src/game/mario_actions_airborne.c:play_far_fall_sound L24-33
function mario_actions_airborne.play_far_fall_sound(m: GroupsTypesHPlus3.MarioState)
	const action = m.action

	if not bit32.btest(action, IncludeSm64H.ACT_FLAG_INVULNERABLE) and action ~= IncludeSm64H.ACT_TWIRLING and action ~= IncludeSm64H.ACT_FLYING and not bit32.btest(m.flags, IncludeSm64H.MARIO_UNKNOWN_18) then
		if F32(m.peakHeight - m.pos[2]) > 1150 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_UNKNOWN_18)
		end
	end
end

-- from src/game/mario_actions_airborne.c:play_knockback_sound L36-42
function mario_actions_airborne.play_knockback_sound(m: GroupsTypesHPlus3.MarioState)
	if m.actionArg == 0 and (m.forwardVel <= -28 or m.forwardVel >= 28) then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DOH, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	else
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_UH, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end
end

-- from src/game/mario_actions_airborne.c:lava_boost_on_wall L45-59
function mario_actions_airborne.lava_boost_on_wall(m: GroupsTypesHPlus3.MarioState): number
	const wall = m.wall :: GroupsTypesHPlus3.Surface

	m.faceAngle[2] = S16(SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x))

	if m.forwardVel < 24 then
		m.forwardVel = 24
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 12 else 18))
	end

	Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ON_FIRE, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	Mario.update_mario_sound_and_camera(m)

	return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_LAVA_BOOST, 1)
end

-- from src/game/mario_actions_airborne.c:check_fall_damage L61-106
function mario_actions_airborne.check_fall_damage(m: GroupsTypesHPlus3.MarioState, hardFallAction: number): number
	const fallHeight = F32(m.peakHeight - m.pos[2])
	const damageHeight = if m.actionState == IncludeSm64H.ACT_GROUND_POUND then 600 else 1150

	if m.action ~= IncludeSm64H.ACT_TWIRLING and (m.floor :: GroupsTypesHPlus3.Surface).type_ ~= IncludeSurfaceTerrainsH.SURFACE_BURNING then
		if m.vel[2] < -55 then
			if fallHeight > 3000 then
				m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 16 else 24))

				Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_FALL_DAMAGE)
				Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ATTACKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

				return Mario.drop_and_set_mario_action(m, hardFallAction, 4)
			elseif fallHeight > damageHeight and Mario.mario_floor_is_slippery(m) == 0 then
				m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 8 else 12))
				m.squishTimer = 30

				Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_FALL_DAMAGE)
				Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ATTACKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:check_kick_or_dive_in_air L108-113
function mario_actions_airborne.check_kick_or_dive_in_air(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, if m.forwardVel > 28 then IncludeSm64H.ACT_DIVE else IncludeSm64H.ACT_JUMP_KICK, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:should_get_stuck_in_ground L115-129
function mario_actions_airborne.should_get_stuck_in_ground(m: GroupsTypesHPlus3.MarioState): number
	const area = m.area :: GroupsTypesHPlus3.Area
	const terrainType = bit32.band(area.terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK)
	const floor = m.floor :: GroupsTypesHPlus3.Surface
	const flags = floor.flags
	const type_ = floor.type_

	if m.floor ~= nil and (terrainType == IncludeSurfaceTerrainsH.TERRAIN_SNOW or terrainType == IncludeSurfaceTerrainsH.TERRAIN_SAND) and type_ ~= IncludeSurfaceTerrainsH.SURFACE_BURNING and IncludeSurfaceTerrainsH.SURFACE_IS_NOT_HARD(type_) ~= 0 then
		if not bit32.btest(flags, 0x01) and F32(m.peakHeight - m.pos[2]) > 1000 and floor.normal.y >= F32(0.8660254) then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:check_fall_damage_or_get_stuck L131-147
function mario_actions_airborne.check_fall_damage_or_get_stuck(m: GroupsTypesHPlus3.MarioState, hardFallAction: number): number
	if mario_actions_airborne.should_get_stuck_in_ground(m) ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_MIST_CIRCLE)
		Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FEET_STUCK_IN_GROUND, 0)

		return IncludePRUltratypesH.TRUE
	end

	return mario_actions_airborne.check_fall_damage(m, hardFallAction)
end

-- from src/game/mario_actions_airborne.c:check_horizontal_wind L149-184
function mario_actions_airborne.check_horizontal_wind(m: GroupsTypesHPlus3.MarioState): number
	const floor = m.floor :: GroupsTypesHPlus3.Surface

	if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_HORIZONTAL_WIND then
		const pushAngle = S16(bit32.lshift(floor.force, 8))

		m.slideVelX = F32(m.slideVelX + F32(F32(1.2) * SrcEngineMathUtilH.sins(pushAngle)))
		m.slideVelZ = F32(m.slideVelZ + F32(F32(1.2) * SrcEngineMathUtilH.coss(pushAngle)))

		local speed = F32(math.sqrt(F32(F32(m.slideVelX * m.slideVelX) + F32(m.slideVelZ * m.slideVelZ))))

		if speed > 48 then
			m.slideVelX = F32(F32(m.slideVelX * 48) / speed)
			m.slideVelZ = F32(F32(m.slideVelZ * 48) / speed)
			speed = 32 --! This was meant to be 48?
		elseif speed > 32 then
			speed = 32
		end

		m.vel[1] = m.slideVelX
		m.vel[3] = m.slideVelZ
		m.slideYaw = S16(SrcEngineMathUtil.atan2s(m.slideVelZ, m.slideVelX))
		m.forwardVel = F32(speed * SrcEngineMathUtilH.coss(m.faceAngle[2] - m.slideYaw))

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:update_air_with_turn L186-214
function mario_actions_airborne.update_air_with_turn(m: GroupsTypesHPlus3.MarioState)
	if mario_actions_airborne.check_horizontal_wind(m) == 0 then
		const dragThreshold = if m.action == IncludeSm64H.ACT_LONG_JUMP then 48 else 32

		m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0, F32(0.35), F32(0.35))

		if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
			const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
			const intendedMag = F32(m.intendedMag / 32)

			m.forwardVel = F32(m.forwardVel + F32(F32(1.5 * SrcEngineMathUtilH.coss(intendedDYaw)) * intendedMag))
			m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] + F32(F32(512 * SrcEngineMathUtilH.sins(intendedDYaw)) * intendedMag))))
		end

		--! Uncapped air speed. Net positive when moving forward.
		if m.forwardVel > dragThreshold then
			m.forwardVel = F32(m.forwardVel - 1)
		end
		if m.forwardVel < -16 then
			m.forwardVel = F32(m.forwardVel + 2)
		end

		m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
		m.vel[1] = m.slideVelX
		m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))
		m.vel[3] = m.slideVelZ
	end
end

-- from src/game/mario_actions_airborne.c:update_air_without_turn L216-251
function mario_actions_airborne.update_air_without_turn(m: GroupsTypesHPlus3.MarioState)
	local sidewaysSpeed = 0

	if mario_actions_airborne.check_horizontal_wind(m) == 0 then
		const dragThreshold = if m.action == IncludeSm64H.ACT_LONG_JUMP then 48 else 32

		m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0, F32(0.35), F32(0.35))

		if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
			const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
			const intendedMag = F32(m.intendedMag / 32)

			m.forwardVel = F32(m.forwardVel + F32(F32(intendedMag * SrcEngineMathUtilH.coss(intendedDYaw)) * 1.5))
			sidewaysSpeed = F32(F32(intendedMag * SrcEngineMathUtilH.sins(intendedDYaw)) * 10)
		end

		--! Uncapped air speed. Net positive when moving forward.
		if m.forwardVel > dragThreshold then
			m.forwardVel = F32(m.forwardVel - 1)
		end
		if m.forwardVel < -16 then
			m.forwardVel = F32(m.forwardVel + 2)
		end

		m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
		m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))

		m.slideVelX = F32(m.slideVelX + F32(sidewaysSpeed * SrcEngineMathUtilH.sins(m.faceAngle[2] + 0x4000)))
		m.slideVelZ = F32(m.slideVelZ + F32(sidewaysSpeed * SrcEngineMathUtilH.coss(m.faceAngle[2] + 0x4000)))

		m.vel[1] = m.slideVelX
		m.vel[3] = m.slideVelZ
	end
end

-- from src/game/mario_actions_airborne.c:update_lava_boost_or_twirling L253-276
function mario_actions_airborne.update_lava_boost_or_twirling(m: GroupsTypesHPlus3.MarioState)
	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
		const intendedMag = F32(m.intendedMag / 32)

		m.forwardVel = F32(m.forwardVel + F32(SrcEngineMathUtilH.coss(intendedDYaw) * intendedMag))
		m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] + F32(F32(SrcEngineMathUtilH.sins(intendedDYaw) * intendedMag) * 1024))))

		if m.forwardVel < 0 then
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
			m.forwardVel = F32(m.forwardVel * -1)
		end

		if m.forwardVel > 32 then
			m.forwardVel = F32(m.forwardVel - 2)
		end
	end

	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[1] = m.slideVelX
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))
	m.vel[3] = m.slideVelZ
end

-- from src/game/mario_actions_airborne.c:update_flying_yaw L278-305
function mario_actions_airborne.update_flying_yaw(m: GroupsTypesHPlus3.MarioState)
	const controller = m.controller :: GroupsTypesHPlus3.Controller
	const targetYawVel = S16(-S16(TruncS32(F32(controller.stickX * F32(m.forwardVel / 4)))))

	if targetYawVel > 0 then
		if m.angleVel[2] < 0 then
			m.angleVel[2] = S16(m.angleVel[2] + 0x40)

			if m.angleVel[2] > 0x10 then
				m.angleVel[2] = 0x10
			end
		else
			m.angleVel[2] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[2], targetYawVel, 0x10, 0x20))
		end
	elseif targetYawVel < 0 then
		if m.angleVel[2] > 0 then
			m.angleVel[2] = S16(m.angleVel[2] - 0x40)

			if m.angleVel[2] < -0x10 then
				m.angleVel[2] = -0x10
			end
		else
			m.angleVel[2] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[2], targetYawVel, 0x20, 0x10))
		end
	else
		m.angleVel[2] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[2], 0, 0x40, 0x40))
	end

	m.faceAngle[2] = S16(m.faceAngle[2] + m.angleVel[2])
	m.faceAngle[3] = S16(20 * -m.angleVel[2])
end

-- from src/game/mario_actions_airborne.c:update_flying_pitch L307-331
function mario_actions_airborne.update_flying_pitch(m: GroupsTypesHPlus3.MarioState)
	const controller = m.controller :: GroupsTypesHPlus3.Controller
	const targetPitchVel = S16(-S16(TruncS32(F32(controller.stickY * F32(m.forwardVel / 5)))))

	if targetPitchVel > 0 then
		if m.angleVel[1] < 0 then
			m.angleVel[1] = S16(m.angleVel[1] + 0x40)

			if m.angleVel[1] > 0x20 then
				m.angleVel[1] = 0x20
			end
		else
			m.angleVel[1] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[1], targetPitchVel, 0x20, 0x40))
		end
	elseif targetPitchVel < 0 then
		if m.angleVel[1] > 0 then
			m.angleVel[1] = S16(m.angleVel[1] - 0x40)

			if m.angleVel[1] < -0x20 then
				m.angleVel[1] = -0x20
			end
		else
			m.angleVel[1] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[1], targetPitchVel, 0x40, 0x20))
		end
	else
		m.angleVel[1] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[1], 0, 0x40, 0x40))
	end
end

-- from src/game/mario_actions_airborne.c:update_flying L333-369
function mario_actions_airborne.update_flying(m: GroupsTypesHPlus3.MarioState)
	mario_actions_airborne.update_flying_pitch(m)
	mario_actions_airborne.update_flying_yaw(m)

	m.forwardVel = F32(m.forwardVel - F32(F32(2 * F32(m.faceAngle[1] / 0x4000)) + F32(0.1)))
	m.forwardVel = F32(m.forwardVel - F32(F32(0.5) * F32(1 - SrcEngineMathUtilH.coss(m.angleVel[2]))))

	if m.forwardVel < 0 then
		m.forwardVel = 0
	end

	if m.forwardVel > 16 then
		m.faceAngle[1] = S16(TruncS32(F32(m.faceAngle[1] + F32(F32(m.forwardVel - 32) * 6))))
	elseif m.forwardVel > 4 then
		m.faceAngle[1] = S16(TruncS32(F32(m.faceAngle[1] + F32(F32(m.forwardVel - 32) * 10))))
	else
		m.faceAngle[1] = S16(m.faceAngle[1] - 0x400)
	end

	m.faceAngle[1] = S16(m.faceAngle[1] + m.angleVel[1])

	if m.faceAngle[1] > 0x2AAA then
		m.faceAngle[1] = 0x2AAA
	end
	if m.faceAngle[1] < -0x2AAA then
		m.faceAngle[1] = -0x2AAA
	end

	m.vel[1] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[2] = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[1]))
	m.vel[3] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.coss(m.faceAngle[2]))

	m.slideVelX = m.vel[1]
	m.slideVelZ = m.vel[3]
end

-- from src/game/mario_actions_airborne.c:common_air_action_step L371-444
function mario_actions_airborne.common_air_action_step(m: GroupsTypesHPlus3.MarioState, landAction: number, animation: number, stepArg: number): number
	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, stepArg)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		Mario.set_mario_animation(m, animation)
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
			Mario.set_mario_action(m, landAction, 0)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.set_mario_animation(m, animation)

		if m.forwardVel > 16 then
			MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)

			if m.wall ~= nil then
				Mario.set_mario_action(m, IncludeSm64H.ACT_AIR_HIT_WALL, 0)
			else
				if m.vel[2] > 0 then
					m.vel[2] = 0
				end

				--! Hands-free holding. Bonking while no wall is referenced
				-- sets Mario's action to a non-holding action without
				-- dropping the object, causing the hands-free holding
				-- glitch. This can be achieved using an exposed ceiling,
				-- out of bounds, grazing the bottom of a wall while
				-- falling such that the final quarter step does not find a
				-- wall collision, or by rising into the top of a wall such
				-- that the final quarter step detects a ledge, but you are
				-- not able to ledge grab it.
				if m.forwardVel >= 38 then
					m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
					Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
				else
					if m.forwardVel > 8 then
						Mario.mario_set_forward_vel(m, -8)
					end

					return Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
				end
			end
		else
			Mario.mario_set_forward_vel(m, 0)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_GRABBED_LEDGE then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_ON_LEDGE)
		Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_LEDGE_GRAB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_GRABBED_CEILING then
		Mario.set_mario_action(m, IncludeSm64H.ACT_START_HANGING, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return stepResult
end

-- from src/game/mario_actions_airborne.c:act_jump L446-459
function mario_actions_airborne.act_jump(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_airborne.check_kick_or_dive_in_air(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_JUMP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP, bit32.bor(IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB, IncludeSm64H.AIR_STEP_CHECK_HANG))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_double_jump L461-478
function mario_actions_airborne.act_double_jump(m: GroupsTypesHPlus3.MarioState): number
	const animation = if m.vel[2] >= 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_DOUBLE_JUMP_RISE else IncludeMarioAnimationIdsH.MARIO_ANIM_DOUBLE_JUMP_FALL

	if mario_actions_airborne.check_kick_or_dive_in_air(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_HOOHOO)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_DOUBLE_JUMP_LAND, animation, bit32.bor(IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB, IncludeSm64H.AIR_STEP_CHECK_HANG))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_triple_jump L480-507
function mario_actions_airborne.act_triple_jump(m: GroupsTypesHPlus3.MarioState): number
	if SaveFile.gSpecialTripleJump ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_SPECIAL_TRIPLE_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)

	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_TRIPLE_JUMP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP, 0)

	mario_actions_airborne.play_flip_sounds(m, 2, 8, 20)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_backflip L509-523
function mario_actions_airborne.act_backflip(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_YAH_WAH_HOO)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_BACKFLIP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKFLIP, 0)

	mario_actions_airborne.play_flip_sounds(m, 2, 3, 17)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_freefall L525-550
function mario_actions_airborne.act_freefall(m: GroupsTypesHPlus3.MarioState): number
	local animation = 0

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	if m.actionArg == 0 then
		animation = IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL
	elseif m.actionArg == 1 then
		animation = IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_FROM_SLIDE
	elseif m.actionArg == 2 then
		animation = IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_FROM_SLIDE_KICK
	end

	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_FREEFALL_LAND, animation, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hold_jump L552-569
function mario_actions_airborne.act_hold_jump(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) and not bit32.btest(buffer.readu32((m.heldObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_HOLDABLE_NPC) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_AIR_THROW, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_HOLD_JUMP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_WITH_LIGHT_OBJ, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hold_freefall L571-593
function mario_actions_airborne.act_hold_freefall(m: GroupsTypesHPlus3.MarioState): number
	const animation = if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_WITH_LIGHT_OBJ else IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_FROM_SLIDING_WITH_LIGHT_OBJ
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) and not bit32.btest(buffer.readu32((m.heldObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_HOLDABLE_NPC) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_AIR_THROW, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_HOLD_FREEFALL_LAND, animation, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_side_flip L595-616
function mario_actions_airborne.act_side_flip(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)

	if mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_SIDE_FLIP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDEFLIP, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB) ~= IncludeSm64H.AIR_STEP_GRABBED_LEDGE then
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	end

	if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 6 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SIDE_FLIP_UNK, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_wall_kick_air L618-630
function mario_actions_airborne.act_wall_kick_air(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_jump_sound(m)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_JUMP_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDEJUMP, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_long_jump L632-654
function mario_actions_airborne.act_long_jump(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const animation = if buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioLongJumpIsSlow) == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_FAST_LONGJUMP else IncludeMarioAnimationIdsH.MARIO_ANIM_SLOW_LONGJUMP

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_YAHOO)

	if (m.floor :: GroupsTypesHPlus3.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_VERTICAL_WIND and m.actionState == 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, marioObj.header.gfx.cameraToObject)
		m.actionState = 1
	end

	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_LONG_JUMP_LAND, animation, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_riding_shell_air L656-678
function mario_actions_airborne.act_riding_shell_air(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_RIDING_SHELL)

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_RIDING_SHELL_GROUND, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.pos[2] = F32(marioObj.header.gfx.pos[2] + 42)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_twirling L680-723
function mario_actions_airborne.act_twirling(m: GroupsTypesHPlus3.MarioState): number
	const startTwirlYaw = m.twirlYaw
	const yawVelTarget = if bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then 0x2000 else 0x1800

	m.angleVel[2] = S16(SrcEngineMathUtil.approach_s32(m.angleVel[2], yawVelTarget, 0x200, 0x200))
	m.twirlYaw = S16(m.twirlYaw + m.angleVel[2])

	Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_START_TWIRL else IncludeMarioAnimationIdsH.MARIO_ANIM_TWIRL)

	if Mario.is_anim_past_end(m) ~= 0 then
		m.actionArg = 1
	end

	if startTwirlYaw > m.twirlYaw then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_TWIRL, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	mario_actions_airborne.update_lava_boost_or_twirling(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_TWIRL_LAND, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + m.twirlYaw)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_dive L725-794
function mario_actions_airborne.act_dive(m: GroupsTypesHPlus3.MarioState): number
	if m.actionArg == 0 then
		Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_THROW, IncludeSoundsH.SOUND_MARIO_HOOHOO)
	else
		Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)

	if Interaction.mario_check_object_grab(m) ~= 0 then
		const bodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		Interaction.mario_grab_used_object(m)
		bodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_LIGHT_OBJ

		if m.action ~= IncludeSm64H.ACT_DIVE then
			return IncludePRUltratypesH.TRUE
		end
	end

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		if m.vel[2] < 0 and m.faceAngle[1] > -0x2AAA then
			m.faceAngle[1] = S16(m.faceAngle[1] - 0x200)

			if m.faceAngle[1] < -0x2AAA then
				m.faceAngle[1] = -0x2AAA
			end
		end

		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		marioObj.header.gfx.angle[1] = S16(-m.faceAngle[1])
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.should_get_stuck_in_ground(m) ~= 0 and m.faceAngle[1] == -0x2AAA then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_MIST_CIRCLE)
			Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_HEAD_STUCK_IN_GROUND, 0)
		elseif mario_actions_airborne.check_fall_damage(m, IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB) == 0 then
			if m.heldObj == nil then
				Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE_SLIDE, 0)
			else
				Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE_PICKING_UP, 0)
			end
		end

		m.faceAngle[1] = 0
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
		m.faceAngle[1] = 0

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_air_throw L796-822
function mario_actions_airborne.act_air_throw(m: GroupsTypesHPlus3.MarioState): number
	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 4 then
		Interaction.mario_throw_held_object(m)
	end

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAH2, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_THROW_LIGHT_OBJECT)
	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
			m.action = IncludeSm64H.ACT_AIR_THROW_LAND
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_water_jump L824-856
function mario_actions_airborne.act_water_jump(m: GroupsTypesHPlus3.MarioState): number
	if m.forwardVel < 15 then
		Mario.mario_set_forward_vel(m, 15)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_UNKNOWN432, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP)

	const stepResult = MarioStep.perform_air_step(m, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_JUMP_LAND, 0)

		const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 15)
	elseif stepResult == IncludeSm64H.AIR_STEP_GRABBED_LEDGE then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_ON_LEDGE)
		Mario.set_mario_action(m, IncludeSm64H.ACT_LEDGE_GRAB, 0)

		const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hold_water_jump L858-886
function mario_actions_airborne.act_hold_water_jump(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if m.forwardVel < 15 then
		Mario.mario_set_forward_vel(m, 15)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_UNKNOWN432, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_WITH_LIGHT_OBJ)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_JUMP_LAND, 0)

		const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 15)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_steep_jump L888-916
function mario_actions_airborne.act_steep_jump(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	Mario.mario_set_forward_vel(m, F32(F32(0.98) * m.forwardVel))

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
			m.faceAngle[1] = 0
			Mario.set_mario_action(m, if m.forwardVel < 0 then IncludeSm64H.ACT_BEGIN_SLIDING else IncludeSm64H.ACT_JUMP_LAND, 0)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioSteepJumpYaw))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_ground_pound L918-984
function mario_actions_airborne.act_ground_pound(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_THROW, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)

	if m.actionState == 0 then
		if m.actionTimer < 10 then
			const yOffset = 20 - 2 * m.actionTimer

			if F32(F32(m.pos[2] + yOffset) + 160) < m.ceilHeight then
				m.pos[2] = F32(m.pos[2] + yOffset)
				m.peakHeight = m.pos[2]
				SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
			end
		end

		m.vel[2] = -50
		Mario.mario_set_forward_vel(m, 0)

		Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_START_GROUND_POUND else IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_GROUND_POUND)

		if m.actionTimer == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, marioObj.header.gfx.cameraToObject)
		end

		m.actionTimer = U16(m.actionTimer + 1)

		const curAnim = marioObj.header.gfx.animInfo.curAnim :: number

		if m.actionTimer >= Rom.ReadS16(curAnim + 8) + 4 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_GROUND_POUND_WAH, marioObj.header.gfx.cameraToObject)
			m.actionState = 1
		end
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GROUND_POUND)

		const stepResult = MarioStep.perform_air_step(m, 0)

		if stepResult == IncludeSm64H.AIR_STEP_LANDED then
			if mario_actions_airborne.should_get_stuck_in_ground(m) ~= 0 then
				Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, marioObj.header.gfx.cameraToObject)
				m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_MIST_CIRCLE)
				Mario.set_mario_action(m, IncludeSm64H.ACT_BUTT_STUCK_IN_GROUND, 0)
			else
				Mario.play_mario_heavy_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_HEAVY_LANDING)

				if mario_actions_airborne.check_fall_damage(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
					m.particleFlags = bit32.bor(m.particleFlags, bit32.bor(IncludeSm64H.PARTICLE_MIST_CIRCLE, IncludeSm64H.PARTICLE_HORIZONTAL_STAR))
					Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND_LAND, 0)
				end
			end

			Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_GROUND_POUND)
		elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
			Mario.mario_set_forward_vel(m, -16)

			if m.vel[2] > 0 then
				m.vel[2] = 0
			end

			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
			Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_burning_jump L986-1009
function mario_actions_airborne.act_burning_jump(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, if m.actionArg == 0 then 0 else -1)
	Mario.mario_set_forward_vel(m, m.forwardVel)

	if MarioStep.perform_air_step(m, 0) == IncludeSm64H.AIR_STEP_LANDED then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BURNING_GROUND, 0)
	end

	Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP else IncludeMarioAnimationIdsH.MARIO_ANIM_FIRE_LAVA_BURN)
	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_FIRE)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_LAVA_BURN, marioObj.header.gfx.cameraToObject)
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer) + 3)

	m.health = S16(m.health - 10)

	if m.health < 0x100 then
		m.health = 0xFF
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_burning_fall L1011-1031
function mario_actions_airborne.act_burning_fall(m: GroupsTypesHPlus3.MarioState): number
	Mario.mario_set_forward_vel(m, m.forwardVel)

	if MarioStep.perform_air_step(m, 0) == IncludeSm64H.AIR_STEP_LANDED then
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BURNING_GROUND, 0)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_FIRE)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer) + 3)

	m.health = S16(m.health - 10)

	if m.health < 0x100 then
		m.health = 0xFF
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_crazy_box_bounce L1033-1095
function mario_actions_airborne.act_crazy_box_bounce(m: GroupsTypesHPlus3.MarioState): number
	local minSpeed = 0

	if m.actionTimer == 0 then
		if m.actionArg == 0 then
			m.vel[2] = 45
			minSpeed = 32
		elseif m.actionArg == 1 then
			m.vel[2] = 60
			minSpeed = 36
		elseif m.actionArg == 2 then
			m.vel[2] = 100
			minSpeed = 48
		end

		Audio.play_sound(if minSpeed < 40 then IncludeSoundsH.SOUND_GENERAL_BOING1 else IncludeSoundsH.SOUND_GENERAL_BOING2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		if m.forwardVel < minSpeed then
			Mario.mario_set_forward_vel(m, minSpeed)
		end

		m.actionTimer = 1
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if m.actionArg < 2 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_CRAZY_BOX_BOUNCE, m.actionArg + 1)
		else
			buffer.writei32((m.heldObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_STOP_RIDING)
			m.heldObj = nil
			Mario.set_mario_action(m, IncludeSm64H.ACT_STOMACH_SLIDE, 0)
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_MIST_CIRCLE)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[1] = S16(SrcEngineMathUtil.atan2s(m.forwardVel, -m.vel[2]))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:common_air_knockback_step L1097-1145
function mario_actions_airborne.common_air_knockback_step(m: GroupsTypesHPlus3.MarioState, landAction: number, hardFallAction: number, animation: number, speed: number): number
	speed = F32(speed)
	Mario.mario_set_forward_vel(m, speed)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		Mario.set_mario_animation(m, animation)
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, hardFallAction) == 0 then
			if m.action == IncludeSm64H.ACT_THROWN_FORWARD or m.action == IncludeSm64H.ACT_THROWN_BACKWARD then
				Mario.set_mario_action(m, landAction, m.hurtCounter)
			else
				Mario.set_mario_action(m, landAction, m.actionArg)
			end
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARD_AIR_KB)
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		Mario.mario_set_forward_vel(m, -speed)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return stepResult
end

-- from src/game/mario_actions_airborne.c:check_wall_kick L1147-1154
function mario_actions_airborne.check_wall_kick(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) and m.wallKickTimer ~= 0 and m.prevAction == IncludeSm64H.ACT_AIR_HIT_WALL then
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WALL_KICK_AIR, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_backward_air_kb L1156-1168
function mario_actions_airborne.act_backward_air_kb(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_airborne.check_wall_kick(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_airborne.play_knockback_sound(m)

	mario_actions_airborne.common_air_knockback_step(m, IncludeSm64H.ACT_BACKWARD_GROUND_KB, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB, 0x0002, -16)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_forward_air_kb L1170-1182
function mario_actions_airborne.act_forward_air_kb(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_airborne.check_wall_kick(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_airborne.play_knockback_sound(m)

	mario_actions_airborne.common_air_knockback_step(m, IncludeSm64H.ACT_FORWARD_GROUND_KB, IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB, 0x002D, 16)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hard_backward_air_kb L1184-1193
function mario_actions_airborne.act_hard_backward_air_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_airborne.play_knockback_sound(m)

	mario_actions_airborne.common_air_knockback_step(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB, 0x0002, -16)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hard_forward_air_kb L1195-1203
function mario_actions_airborne.act_hard_forward_air_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_airborne.play_knockback_sound(m)

	mario_actions_airborne.common_air_knockback_step(m, IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB, IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB, 0x002D, 16)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_thrown_backward L1205-1219
function mario_actions_airborne.act_thrown_backward(m: GroupsTypesHPlus3.MarioState): number
	const landAction = if m.actionArg ~= 0 then IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB else IncludeSm64H.ACT_BACKWARD_GROUND_KB

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAAAOOOW, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	mario_actions_airborne.common_air_knockback_step(m, landAction, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB, 0x0002, m.forwardVel)

	m.forwardVel = F32(m.forwardVel * F32(0.98))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_thrown_forward L1221-1245
function mario_actions_airborne.act_thrown_forward(m: GroupsTypesHPlus3.MarioState): number
	const landAction = if m.actionArg ~= 0 then IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB else IncludeSm64H.ACT_FORWARD_GROUND_KB

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAAAOOOW, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	if mario_actions_airborne.common_air_knockback_step(m, landAction, IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB, 0x002D, m.forwardVel) == IncludeSm64H.AIR_STEP_NONE then
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
		local pitch = S16(SrcEngineMathUtil.atan2s(m.forwardVel, -m.vel[2]))

		if pitch > 0x1800 then
			pitch = 0x1800
		end

		marioObj.header.gfx.angle[1] = S16(pitch + 0x1800)
	end

	m.forwardVel = F32(m.forwardVel * F32(0.98))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_soft_bonk L1247-1260
function mario_actions_airborne.act_soft_bonk(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_airborne.check_wall_kick(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_airborne.play_knockback_sound(m)

	mario_actions_airborne.common_air_knockback_step(m, IncludeSm64H.ACT_FREEFALL_LAND, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB, 0x0056, m.forwardVel)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_getting_blown L1262-1307
function mario_actions_airborne.act_getting_blown(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		if m.forwardVel > -60 then
			m.forwardVel = F32(m.forwardVel - 6)
		else
			m.actionState = 1
		end
	else
		if m.forwardVel < -16 then
			m.forwardVel = F32(m.forwardVel + F32(0.8))
		end

		if m.vel[2] < 0 and m.gettingBlownGravity < 4 then
			m.gettingBlownGravity = F32(m.gettingBlownGravity + F32(0.05))
		end
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 20 then
		Interaction.mario_blow_off_cap(m, 50)
	end

	Mario.mario_set_forward_vel(m, m.forwardVel)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARD_AIR_KB)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HARD_BACKWARD_AIR_KB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_AIR_FORWARD_KB)
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		Mario.mario_set_forward_vel(m, -m.forwardVel)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_air_hit_wall L1309-1351
function mario_actions_airborne.act_air_hit_wall(m: GroupsTypesHPlus3.MarioState): number
	if m.heldObj ~= nil then
		Interaction.mario_drop_held_object(m)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer <= 2 then
		if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			m.vel[2] = 52
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)

			return Mario.set_mario_action(m, IncludeSm64H.ACT_WALL_KICK_AIR, 0)
		end
	elseif m.forwardVel >= 38 then
		m.wallKickTimer = 5

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)

		return Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
	else
		m.wallKickTimer = 5

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		if m.forwardVel > 8 then
			Mario.mario_set_forward_vel(m, -8)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_SOFT_BONK, 0)
	end

	-- Missing return statement in C: the returned value is the result of this call (nonzero in practice).
	return Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_START_WALLKICK)
end

-- from src/game/mario_actions_airborne.c:act_forward_rollout L1353-1392
function mario_actions_airborne.act_forward_rollout(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		m.vel[2] = 30
		m.actionState = 1
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		if m.actionState == 1 then
			if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING) == 4 then
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end
		else
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL_LAND_STOP, 0)
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	if m.actionState == 1 and Mario.is_anim_past_end(m) ~= 0 then
		m.actionState = 2
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_backward_rollout L1394-1433
function mario_actions_airborne.act_backward_rollout(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		m.vel[2] = 30
		m.actionState = 1
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 0)
	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		if m.actionState == 1 then
			if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARD_SPINNING) == 4 then
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end
		else
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL_LAND_STOP, 0)
		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.actionState == 1 and marioObj.header.gfx.animInfo.animFrame == 2 then
		m.actionState = 2
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_butt_slide_air L1435-1468
function mario_actions_airborne.act_butt_slide_air(m: GroupsTypesHPlus3.MarioState): number
	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer > 30 and F32(m.pos[2] - m.floorHeight) > 500 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 1)
	end

	mario_actions_airborne.update_air_with_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if m.actionState == 0 and m.vel[2] < 0 and (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.9848077) then
			m.vel[2] = F32(-m.vel[2] / 2)
			m.actionState = 1
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_BUTT_SLIDE, 0)
		end

		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_hold_butt_slide_air L1470-1509
function mario_actions_airborne.act_hold_butt_slide_air(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 1)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer > 30 and F32(m.pos[2] - m.floorHeight) > 500 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 1)
	end

	mario_actions_airborne.update_air_with_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if m.actionState == 0 and m.vel[2] < 0 and (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.9848077) then
			m.vel[2] = F32(-m.vel[2] / 2)
			m.actionState = 1
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BUTT_SLIDE, 0)
		end

		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		Interaction.mario_drop_held_object(m)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDING_ON_BOTTOM_WITH_LIGHT_OBJ)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_lava_boost L1511-1578
function mario_actions_airborne.act_lava_boost(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_ON_FIRE, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	if not bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0, F32(0.35), F32(0.35))
	end

	mario_actions_airborne.update_lava_boost_or_twirling(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if (m.floor :: GroupsTypesHPlus3.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
			m.actionState = 0

			if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
				m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 12 else 18))
			end

			m.vel[2] = 84
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ON_FIRE, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		else
			Mario.play_mario_heavy_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)

			if m.actionState < 2 and m.vel[2] < 0 then
				m.vel[2] = F32(-m.vel[2] * F32(0.4))
				Mario.mario_set_forward_vel(m, F32(m.forwardVel * 0.5))
				m.actionState = U16(m.actionState + 1)
			else
				Mario.set_mario_action(m, IncludeSm64H.ACT_LAVA_BOOST_LAND, 0)
			end
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRE_LAVA_BURN)

	if bit32.band((m.area :: GroupsTypesHPlus3.Area).terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) ~= IncludeSurfaceTerrainsH.TERRAIN_SNOW and not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) and m.vel[2] > 0 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_FIRE)

		if m.actionState == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_MOVING_LAVA_BURN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	end

	if m.health < 0x100 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
	end

	const bodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_DEAD

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_slide_kick L1580-1629
function mario_actions_airborne.act_slide_kick(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 and m.actionTimer == 0 then
		Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_HOOHOO)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SLIDE_KICK)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer > 30 and F32(m.pos[2] - m.floorHeight) > 500 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 2)
	end

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		if m.actionState == 0 then
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

			marioObj.header.gfx.angle[1] = S16(SrcEngineMathUtil.atan2s(m.forwardVel, -m.vel[2]))

			if marioObj.header.gfx.angle[1] > 0x1800 then
				marioObj.header.gfx.angle[1] = 0x1800
			end
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if m.actionState == 0 and m.vel[2] < 0 then
			m.vel[2] = F32(-m.vel[2] / 2)
			m.actionState = 1
			m.actionTimer = 0
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_SLIDE_KICK_SLIDE, 0)
		end

		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_jump_kick L1631-1664
function mario_actions_airborne.act_jump_kick(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.actionState == 0 then
		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_PUNCH_HOO, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
		marioObj.header.gfx.animInfo.animID = -1
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_AIR_KICK)
		m.actionState = 1
	end

	const animFrame = marioObj.header.gfx.animInfo.animFrame

	if animFrame == 0 then
		const bodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		bodyState.punchState = U8(bit32.bor(bit32.lshift(2, 6), 6))
	end

	if animFrame >= 0 and animFrame < 8 then
		m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_KICKING)
	end

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL_LAND, 0)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_shot_from_cannon L1666-1724
function mario_actions_airborne.act_shot_from_cannon(m: GroupsTypesHPlus3.MarioState): number
	const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera

	if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		(m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState).cameraEvent = GroupsTypesHPlus3.CAM_EVENT_SHOT_FROM_CANNON
	end

	Mario.mario_set_forward_vel(m, m.forwardVel)
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_YAHOO, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_AIRBORNE_ON_STOMACH)
		m.faceAngle[1] = S16(SrcEngineMathUtil.atan2s(m.forwardVel, m.vel[2]))
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
		marioObj.header.gfx.angle[1] = S16(-m.faceAngle[1])
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE_SLIDE, 0)
		m.faceAngle[1] = 0
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, -16)
		m.faceAngle[1] = 0

		if m.vel[2] > 0 then
			m.vel[2] = 0
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
		Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	if bit32.btest(m.flags, IncludeSm64H.MARIO_WING_CAP) and m.vel[2] < 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_FLYING, 0)
	end

	m.forwardVel = F32(m.forwardVel - 0.05)

	if m.forwardVel < 10 then
		Mario.mario_set_forward_vel(m, 10)
	end

	if m.vel[2] > 0 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_flying L1726-1848
function mario_actions_airborne.act_flying(m: GroupsTypesHPlus3.MarioState): number
	const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera
	const startPitch = m.faceAngle[1]

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		if camera.mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
			Camera.set_camera_mode(camera, camera.defMode, 1)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 1)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_WING_CAP) then
		if camera.mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
			Camera.set_camera_mode(camera, camera.defMode, 1)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
	end

	if m.actionState == 0 then
		if m.actionArg == 0 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLY_FROM_CANNON)
		else
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING_FLIP)

			if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 1 then
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end
		end

		if Mario.is_anim_at_end(m) ~= 0 then
			if m.actionArg == 2 then
				LevelUpdate.load_level_init_text(0)
				m.actionArg = 1
			end

			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WING_CAP_FLY)
			m.actionState = 1
		end
	end

	mario_actions_airborne.update_flying(m)

	const stepResult = MarioStep.perform_air_step(m, 0)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if stepResult == IncludeSm64H.AIR_STEP_NONE then
		marioObj.header.gfx.angle[1] = S16(-m.faceAngle[1])
		marioObj.header.gfx.angle[3] = m.faceAngle[3]
		m.actionTimer = 0
	elseif stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE_SLIDE, 0)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)
		Mario.set_anim_to_frame(m, 7)
		m.faceAngle[1] = 0
		Camera.set_camera_mode(camera, camera.defMode, 1)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		if m.wall ~= nil then
			Mario.mario_set_forward_vel(m, -16)
			m.faceAngle[1] = 0

			if m.vel[2] > 0 then
				m.vel[2] = 0
			end

			Audio.play_sound(if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_BONK else IncludeSoundsH.SOUND_ACTION_BONK, marioObj.header.gfx.cameraToObject)
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_VERTICAL_STAR)
			Mario.set_mario_action(m, IncludeSm64H.ACT_BACKWARD_AIR_KB, 0)
			Camera.set_camera_mode(camera, camera.defMode, 1)
		else
			const timerWasZero = m.actionTimer == 0
			m.actionTimer = U16(m.actionTimer + 1)

			if timerWasZero then
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HIT, marioObj.header.gfx.cameraToObject)
			end

			if m.actionTimer == 30 then
				m.actionTimer = 0
			end

			m.faceAngle[1] = S16(m.faceAngle[1] - 0x200)

			if m.faceAngle[1] < -0x2AAA then
				m.faceAngle[1] = -0x2AAA
			end

			marioObj.header.gfx.angle[1] = S16(-m.faceAngle[1])
			marioObj.header.gfx.angle[3] = m.faceAngle[3]
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	if m.faceAngle[1] > 0x800 and m.forwardVel >= 48 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end

	if startPitch <= 0 and m.faceAngle[1] > 0 and m.forwardVel >= 48 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_FLYING_FAST, marioObj.header.gfx.cameraToObject)
		-- gAudioRandom is 0 in the port (native stub value): (gAudioRandom % 5 << 16) is 0
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAHOO_WAHA_YIPPEE, marioObj.header.gfx.cameraToObject)
	end

	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_FLYING, marioObj.header.gfx.cameraToObject)
	Mario.adjust_sound_for_speed(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_riding_hoot L1850-1880
function mario_actions_airborne.act_riding_hoot(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) or bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK7) then
		buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oHootMarioReleaseTime, GameInit.gGlobalTimer)

		Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_UH, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

		return Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	m.pos[1] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX)
	m.pos[2] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY) - 92.5)
	m.pos[3] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ)

	m.faceAngle[2] = S16(0x4000 - buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if m.actionState == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANG_ON_CEILING)

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HANG_ON_OWL)
			m.actionState = 1
		end
	end

	SrcEngineMathUtil.vec3f_set(m.vel, 0, 0, 0)
	SrcEngineMathUtil.vec3f_set(marioObj.header.gfx.pos, m.pos[1], m.pos[2], m.pos[3])
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, S16(0x4000 - m.faceAngle[2]), 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_flying_triple_jump L1882-1960
function mario_actions_airborne.act_flying_triple_jump(m: GroupsTypesHPlus3.MarioState): number
	const camera = (m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera

	if bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_B_PRESSED, IncludeSm64H.INPUT_Z_PRESSED)) then
		if camera.mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
			Camera.set_camera_mode(camera, camera.defMode, 1)
		end

		if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
			return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
		else
			return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
		end
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_YAHOO)

	if m.actionState == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TRIPLE_JUMP_FLY)

		if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 7 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		if Mario.is_anim_past_end(m) ~= 0 then
			Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING)

			m.actionState = 1
		end
	end

	if m.actionState == 1 and (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 1 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if m.vel[2] < 4 then
		if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
			Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
		end

		if m.forwardVel < 32 then
			Mario.mario_set_forward_vel(m, 32)
		end

		Mario.set_mario_action(m, IncludeSm64H.ACT_FLYING, 1)
	end

	const timerWasTen = m.actionTimer == 10
	m.actionTimer = U16(m.actionTimer + 1)

	if timerWasTen and camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
	end

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		if mario_actions_airborne.check_fall_damage_or_get_stuck(m, IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB) == 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_DOUBLE_JUMP_LAND, 0)
		end
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.FALSE)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_LAVA_WALL then
		mario_actions_airborne.lava_boost_on_wall(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_top_of_pole_jump L1962-1966
function mario_actions_airborne.act_top_of_pole_jump(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_mario_jump_sound(m)
	mario_actions_airborne.common_air_action_step(m, IncludeSm64H.ACT_FREEFALL_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_HANDSTAND_JUMP, IncludeSm64H.AIR_STEP_CHECK_LEDGE_GRAB)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_vertical_wind L1968-2004
function mario_actions_airborne.act_vertical_wind(m: GroupsTypesHPlus3.MarioState): number
	const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])
	const intendedMag = F32(m.intendedMag / 32)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)

	if m.actionState == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING_FLIP)

		if marioObj.header.gfx.animInfo.animFrame == 1 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, marioObj.header.gfx.cameraToObject)
		end

		if Mario.is_anim_past_end(m) ~= 0 then
			m.actionState = 1
		end
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_AIRBORNE_ON_STOMACH)
	end

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE_SLIDE, 0)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		Mario.mario_set_forward_vel(m, -16)
	end

	marioObj.header.gfx.angle[1] = S16(TruncS32(F32(F32(6144 * intendedMag) * SrcEngineMathUtilH.coss(intendedDYaw))))
	marioObj.header.gfx.angle[3] = S16(TruncS32(F32(F32(-4096 * intendedMag) * SrcEngineMathUtilH.sins(intendedDYaw))))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:act_special_triple_jump L2006-2044
function mario_actions_airborne.act_special_triple_jump(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_DIVE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_Z_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_GROUND_POUND, 0)
	end

	Mario.play_mario_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, IncludeSoundsH.SOUND_MARIO_YAHOO)

	mario_actions_airborne.update_air_without_turn(m)

	const stepResult = MarioStep.perform_air_step(m, 0)

	if stepResult == IncludeSm64H.AIR_STEP_LANDED then
		const wasFirstLanding = m.actionState == 0
		m.actionState = U16(m.actionState + 1)

		if wasFirstLanding then
			m.vel[2] = 42
		else
			Mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL_LAND_STOP, 0)
		end

		Mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	elseif stepResult == IncludeSm64H.AIR_STEP_HIT_WALL then
		MarioStep.mario_bonk_reflection(m, IncludePRUltratypesH.TRUE)
	end

	if m.actionState == 0 or m.vel[2] > 0 then
		if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING) == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	else
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	end

	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_SPARKLES)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:check_common_airborne_cancels L2046-2061
function mario_actions_airborne.check_common_airborne_cancels(m: GroupsTypesHPlus3.MarioState): number
	if m.pos[2] < F32(m.waterLevel - 100) then
		return Mario.set_water_plunge_action(m)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_SQUISHED) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SQUISHED, 0)
	end

	if (m.floor :: GroupsTypesHPlus3.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_VERTICAL_WIND and bit32.btest(m.action, IncludeSm64H.ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_VERTICAL_WIND, 0)
	end

	m.quicksandDepth = 0

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_airborne.c:mario_execute_airborne_action L2063-2123
function mario_actions_airborne.mario_execute_airborne_action(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_airborne.check_common_airborne_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	mario_actions_airborne.play_far_fall_sound(m)

	local cancel = 0

	if m.action == IncludeSm64H.ACT_JUMP then
		cancel = mario_actions_airborne.act_jump(m)
	elseif m.action == IncludeSm64H.ACT_DOUBLE_JUMP then
		cancel = mario_actions_airborne.act_double_jump(m)
	elseif m.action == IncludeSm64H.ACT_FREEFALL then
		cancel = mario_actions_airborne.act_freefall(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_JUMP then
		cancel = mario_actions_airborne.act_hold_jump(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_FREEFALL then
		cancel = mario_actions_airborne.act_hold_freefall(m)
	elseif m.action == IncludeSm64H.ACT_SIDE_FLIP then
		cancel = mario_actions_airborne.act_side_flip(m)
	elseif m.action == IncludeSm64H.ACT_WALL_KICK_AIR then
		cancel = mario_actions_airborne.act_wall_kick_air(m)
	elseif m.action == IncludeSm64H.ACT_TWIRLING then
		cancel = mario_actions_airborne.act_twirling(m)
	elseif m.action == IncludeSm64H.ACT_WATER_JUMP then
		cancel = mario_actions_airborne.act_water_jump(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_WATER_JUMP then
		cancel = mario_actions_airborne.act_hold_water_jump(m)
	elseif m.action == IncludeSm64H.ACT_STEEP_JUMP then
		cancel = mario_actions_airborne.act_steep_jump(m)
	elseif m.action == IncludeSm64H.ACT_BURNING_JUMP then
		cancel = mario_actions_airborne.act_burning_jump(m)
	elseif m.action == IncludeSm64H.ACT_BURNING_FALL then
		cancel = mario_actions_airborne.act_burning_fall(m)
	elseif m.action == IncludeSm64H.ACT_TRIPLE_JUMP then
		cancel = mario_actions_airborne.act_triple_jump(m)
	elseif m.action == IncludeSm64H.ACT_BACKFLIP then
		cancel = mario_actions_airborne.act_backflip(m)
	elseif m.action == IncludeSm64H.ACT_LONG_JUMP then
		cancel = mario_actions_airborne.act_long_jump(m)
	elseif m.action == IncludeSm64H.ACT_RIDING_SHELL_JUMP then
		cancel = mario_actions_airborne.act_riding_shell_air(m)
	elseif m.action == IncludeSm64H.ACT_RIDING_SHELL_FALL then
		cancel = mario_actions_airborne.act_riding_shell_air(m)
	elseif m.action == IncludeSm64H.ACT_DIVE then
		cancel = mario_actions_airborne.act_dive(m)
	elseif m.action == IncludeSm64H.ACT_AIR_THROW then
		cancel = mario_actions_airborne.act_air_throw(m)
	elseif m.action == IncludeSm64H.ACT_BACKWARD_AIR_KB then
		cancel = mario_actions_airborne.act_backward_air_kb(m)
	elseif m.action == IncludeSm64H.ACT_FORWARD_AIR_KB then
		cancel = mario_actions_airborne.act_forward_air_kb(m)
	elseif m.action == IncludeSm64H.ACT_HARD_FORWARD_AIR_KB then
		cancel = mario_actions_airborne.act_hard_forward_air_kb(m)
	elseif m.action == IncludeSm64H.ACT_HARD_BACKWARD_AIR_KB then
		cancel = mario_actions_airborne.act_hard_backward_air_kb(m)
	elseif m.action == IncludeSm64H.ACT_SOFT_BONK then
		cancel = mario_actions_airborne.act_soft_bonk(m)
	elseif m.action == IncludeSm64H.ACT_AIR_HIT_WALL then
		cancel = mario_actions_airborne.act_air_hit_wall(m)
	elseif m.action == IncludeSm64H.ACT_FORWARD_ROLLOUT then
		cancel = mario_actions_airborne.act_forward_rollout(m)
	elseif m.action == IncludeSm64H.ACT_SHOT_FROM_CANNON then
		cancel = mario_actions_airborne.act_shot_from_cannon(m)
	elseif m.action == IncludeSm64H.ACT_BUTT_SLIDE_AIR then
		cancel = mario_actions_airborne.act_butt_slide_air(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_BUTT_SLIDE_AIR then
		cancel = mario_actions_airborne.act_hold_butt_slide_air(m)
	elseif m.action == IncludeSm64H.ACT_LAVA_BOOST then
		cancel = mario_actions_airborne.act_lava_boost(m)
	elseif m.action == IncludeSm64H.ACT_GETTING_BLOWN then
		cancel = mario_actions_airborne.act_getting_blown(m)
	elseif m.action == IncludeSm64H.ACT_BACKWARD_ROLLOUT then
		cancel = mario_actions_airborne.act_backward_rollout(m)
	elseif m.action == IncludeSm64H.ACT_CRAZY_BOX_BOUNCE then
		cancel = mario_actions_airborne.act_crazy_box_bounce(m)
	elseif m.action == IncludeSm64H.ACT_SPECIAL_TRIPLE_JUMP then
		cancel = mario_actions_airborne.act_special_triple_jump(m)
	elseif m.action == IncludeSm64H.ACT_GROUND_POUND then
		cancel = mario_actions_airborne.act_ground_pound(m)
	elseif m.action == IncludeSm64H.ACT_THROWN_FORWARD then
		cancel = mario_actions_airborne.act_thrown_forward(m)
	elseif m.action == IncludeSm64H.ACT_THROWN_BACKWARD then
		cancel = mario_actions_airborne.act_thrown_backward(m)
	elseif m.action == IncludeSm64H.ACT_FLYING_TRIPLE_JUMP then
		cancel = mario_actions_airborne.act_flying_triple_jump(m)
	elseif m.action == IncludeSm64H.ACT_SLIDE_KICK then
		cancel = mario_actions_airborne.act_slide_kick(m)
	elseif m.action == IncludeSm64H.ACT_JUMP_KICK then
		cancel = mario_actions_airborne.act_jump_kick(m)
	elseif m.action == IncludeSm64H.ACT_FLYING then
		cancel = mario_actions_airborne.act_flying(m)
	elseif m.action == IncludeSm64H.ACT_RIDING_HOOT then
		cancel = mario_actions_airborne.act_riding_hoot(m)
	elseif m.action == IncludeSm64H.ACT_TOP_OF_POLE_JUMP then
		cancel = mario_actions_airborne.act_top_of_pole_jump(m)
	elseif m.action == IncludeSm64H.ACT_VERTICAL_WIND then
		cancel = mario_actions_airborne.act_vertical_wind(m)
	end

	return cancel
end

return mario_actions_airborne
