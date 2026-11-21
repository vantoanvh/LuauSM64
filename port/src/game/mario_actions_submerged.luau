--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_submerged.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const Area = require("./area")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Mario = require("./mario")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Interaction = require("./interaction")
const InteractionH = require("./interaction_h")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const Camera = require("./camera")
const LevelUpdate = require("./level_update")
const LevelUpdateH = require("./level_update_h")
const Memory = require("./memory")
const SoundInit = require("./sound_init")
const MarioStep = require("./mario_step")

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/mario_actions_submerged.luau:scratch
const Floor: { GroupsTypesHPlus3.Surface? } = {}
-- from src/game/mario_actions_submerged.luau:scratch
const Ceil: { GroupsTypesHPlus3.Surface? } = {}
-- from src/game/mario_actions_submerged.luau:scratch
const Step = { 0, 0, 0 }
-- from src/game/mario_actions_submerged.luau:scratch
const NextPos = { 0, 0, 0 }

-- from src/game/mario_actions_submerged.c:data
const mario_actions_submerged = {
	MIN_SWIM_STRENGTH = 160,
	MIN_SWIM_SPEED = 16.0,
	-- from src/game/mario_actions_submerged.c:sWasAtSurface L23-23
	sWasAtSurface = 0,
	-- from src/game/mario_actions_submerged.c:sWaterCurrentSpeeds L25-25
	sWaterCurrentSpeeds = { 28, 12, 8, 4 },
	-- from src/game/mario_actions_submerged.c:sBobTimer L27-27
	sBobTimer = 0,
	-- from src/game/mario_actions_submerged.c:sBobIncrement L28-28
	sBobIncrement = 0,
	-- from src/game/mario_actions_submerged.c:sBobHeight L29-29
	sBobHeight = 0,
}

Registry.Register("src__game__mario_actions_submerged", mario_actions_submerged)

-- from src/game/mario_actions_submerged.c:set_swimming_at_surface_particles L31-42
function mario_actions_submerged.set_swimming_at_surface_particles(m: GroupsTypesHPlus3.MarioState, particleFlag: number)
	const atSurface = if m.pos[2] >= m.waterLevel - 130 then 1 else 0

	if atSurface ~= 0 then
		m.particleFlags = bit32.bor(m.particleFlags, particleFlag)

		if bit32.bxor(atSurface, mario_actions_submerged.sWasAtSurface) ~= 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN431, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	end

	mario_actions_submerged.sWasAtSurface = atSurface
end

-- from src/game/mario_actions_submerged.c:swimming_near_surface L44-50
function mario_actions_submerged.swimming_near_surface(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return IncludePRUltratypesH.FALSE
	end

	return if F32((m.waterLevel - 80) - m.pos[2]) < 400.0 then 1 else 0
end

-- from src/game/mario_actions_submerged.c:get_buoyancy L52-68
function mario_actions_submerged.get_buoyancy(m: GroupsTypesHPlus3.MarioState): number
	local buoyancy = 0.0

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INVULNERABLE) then
			buoyancy = -2.0
		else
			buoyancy = -18.0
		end
	elseif mario_actions_submerged.swimming_near_surface(m) ~= 0 then
		buoyancy = 1.25
	elseif not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_MOVING) then
		buoyancy = -2.0
	end

	return buoyancy
end

-- from src/game/mario_actions_submerged.c:perform_water_full_step L70-117
function mario_actions_submerged.perform_water_full_step(m: GroupsTypesHPlus3.MarioState, nextPos: { number }): number
	const wall = Mario.resolve_and_return_wall_collisions(nextPos, 10.0, 110.0)
	const floorHeight = SrcEngineSurfaceCollision.find_floor(nextPos[1], nextPos[2], nextPos[3], Floor)
	const floor = Floor[1]
	const ceilHeight = Mario.vec3f_find_ceil(nextPos, floorHeight, Ceil)

	if floor == nil then
		return IncludeSm64H.WATER_STEP_CANCELLED
	end

	if nextPos[2] >= floorHeight then
		if F32(ceilHeight - nextPos[2]) >= 160.0 then
			SrcEngineMathUtil.vec3f_copy(m.pos, nextPos)
			m.floor = floor
			m.floorHeight = floorHeight

			if wall ~= nil then
				return IncludeSm64H.WATER_STEP_HIT_WALL
			else
				return IncludeSm64H.WATER_STEP_NONE
			end
		end

		if F32(ceilHeight - floorHeight) < 160.0 then
			return IncludeSm64H.WATER_STEP_CANCELLED
		end

		-- Water ceiling downwarp.
		SrcEngineMathUtil.vec3f_set(m.pos, nextPos[1], F32(ceilHeight - 160.0), nextPos[3])
		m.floor = floor
		m.floorHeight = floorHeight
		return IncludeSm64H.WATER_STEP_HIT_CEILING
	else
		if F32(ceilHeight - floorHeight) < 160.0 then
			return IncludeSm64H.WATER_STEP_CANCELLED
		end

		SrcEngineMathUtil.vec3f_set(m.pos, nextPos[1], floorHeight, nextPos[3])
		m.floor = floor
		m.floorHeight = floorHeight
		return IncludeSm64H.WATER_STEP_HIT_FLOOR
	end
end

-- from src/game/mario_actions_submerged.c:apply_water_current L119-165
function mario_actions_submerged.apply_water_current(m: GroupsTypesHPlus3.MarioState, step: { number })
	const floor = m.floor :: GroupsTypesHPlus3.Surface
	local whirlpoolRadius = 2000.0

	if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_FLOWING_WATER then
		const currentAngle = S16(bit32.lshift(floor.force, 8))
		const currentSpeed = mario_actions_submerged.sWaterCurrentSpeeds[(floor.force // 256) + 1]

		step[1] = F32(step[1] + F32(currentSpeed * SrcEngineMathUtilH.sins(currentAngle)))
		step[3] = F32(step[3] + F32(currentSpeed * SrcEngineMathUtilH.coss(currentAngle)))
	end

	for i = 0, 1 do
		const whirlpool = (Area.gCurrentArea :: GroupsTypesHPlus3.Area).whirlpools[i + 1]

		if whirlpool ~= nil then
			local strength = 0.0

			const dx = F32(whirlpool.pos[1] - m.pos[1])
			const dy = F32(whirlpool.pos[2] - m.pos[2])
			const dz = F32(whirlpool.pos[3] - m.pos[3])

			const lateralDist = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))
			const distance = F32(math.sqrt(F32(F32(lateralDist * lateralDist) + F32(dy * dy))))

			const pitchToWhirlpool = SrcEngineMathUtil.atan2s(lateralDist, dy)
			local yawToWhirlpool = SrcEngineMathUtil.atan2s(dz, dx)

			yawToWhirlpool = S16(yawToWhirlpool - S16(TruncS32(F32(F32(0x2000 * 1000.0) / F32(distance + 1000.0)))))

			if whirlpool.strength >= 0 then
				if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_DDD and Area.gCurrAreaIndex == 2 then
					whirlpoolRadius = 4000.0
				end

				if distance >= 26.0 and distance < whirlpoolRadius then
					strength = F32(whirlpool.strength * F32(1.0 - F32(distance / whirlpoolRadius)))
				end
			elseif distance < 2000.0 then
				strength = F32(whirlpool.strength * F32(1.0 - F32(distance / 2000.0)))
			end

			step[1] = F32(step[1] + F32(F32(strength * SrcEngineMathUtilH.coss(pitchToWhirlpool)) * SrcEngineMathUtilH.sins(yawToWhirlpool)))
			step[2] = F32(step[2] + F32(strength * SrcEngineMathUtilH.sins(pitchToWhirlpool)))
			step[3] = F32(step[3] + F32(F32(strength * SrcEngineMathUtilH.coss(pitchToWhirlpool)) * SrcEngineMathUtilH.coss(yawToWhirlpool)))
		end
	end
end

-- from src/game/mario_actions_submerged.c:perform_water_step L167-195
function mario_actions_submerged.perform_water_step(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	SrcEngineMathUtil.vec3f_copy(Step, m.vel)

	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SWIMMING) then
		mario_actions_submerged.apply_water_current(m, Step)
	end

	NextPos[1] = F32(m.pos[1] + Step[1])
	NextPos[2] = F32(m.pos[2] + Step[2])
	NextPos[3] = F32(m.pos[3] + Step[3])

	if NextPos[2] > m.waterLevel - 80 then
		NextPos[2] = m.waterLevel - 80
		m.vel[2] = 0.0
	end

	const stepResult = mario_actions_submerged.perform_water_full_step(m, NextPos)

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, S16(-m.faceAngle[1]), m.faceAngle[2], m.faceAngle[3])

	return stepResult
end

-- from src/game/mario_actions_submerged.c:update_water_pitch L197-212
function mario_actions_submerged.update_water_pitch(m: GroupsTypesHPlus3.MarioState)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if marioObj.header.gfx.angle[1] > 0 then
		marioObj.header.gfx.pos[2] = F32(marioObj.header.gfx.pos[2] + F32(F32(60.0 * SrcEngineMathUtilH.sins(marioObj.header.gfx.angle[1])) * SrcEngineMathUtilH.sins(marioObj.header.gfx.angle[1])))
	end

	if marioObj.header.gfx.angle[1] < 0 then
		marioObj.header.gfx.angle[1] = S16(TruncS32(marioObj.header.gfx.angle[1] * 6 / 10))
	end

	if marioObj.header.gfx.angle[1] > 0 then
		marioObj.header.gfx.angle[1] = S16(TruncS32(marioObj.header.gfx.angle[1] * 10 / 8))
	end
end

-- from src/game/mario_actions_submerged.c:stationary_slow_down L214-228
function mario_actions_submerged.stationary_slow_down(m: GroupsTypesHPlus3.MarioState)
	const buoyancy = mario_actions_submerged.get_buoyancy(m)

	m.angleVel[2] = 0
	m.angleVel[3] = 0

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0.0, 1.0, 1.0)
	m.vel[2] = SrcEngineMathUtil.approach_f32(m.vel[2], buoyancy, 2.0, 1.0)

	m.faceAngle[1] = S16(SrcEngineMathUtil.approach_s32(m.faceAngle[1], 0, 0x200, 0x200))
	m.faceAngle[3] = S16(SrcEngineMathUtil.approach_s32(m.faceAngle[3], 0, 0x100, 0x100))

	m.vel[1] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[3] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.coss(m.faceAngle[2]))
end

-- from src/game/mario_actions_submerged.c:update_swimming_speed L230-253
function mario_actions_submerged.update_swimming_speed(m: GroupsTypesHPlus3.MarioState, decelThreshold: number)
	decelThreshold = F32(decelThreshold)
	const buoyancy = mario_actions_submerged.get_buoyancy(m)
	const maxSpeed = 28.0

	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_STATIONARY) then
		m.forwardVel = F32(m.forwardVel - 2.0)
	end

	if m.forwardVel < 0.0 then
		m.forwardVel = 0.0
	end

	if m.forwardVel > maxSpeed then
		m.forwardVel = maxSpeed
	end

	if m.forwardVel > decelThreshold then
		m.forwardVel = F32(m.forwardVel - 0.5)
	end

	m.vel[1] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[2] = F32(F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[1])) + buoyancy)
	m.vel[3] = F32(F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[1])) * SrcEngineMathUtilH.coss(m.faceAngle[2]))
end

-- from src/game/mario_actions_submerged.c:update_swimming_yaw L255-282
function mario_actions_submerged.update_swimming_yaw(m: GroupsTypesHPlus3.MarioState)
	const targetYawVel = S16(-S16(TruncS32(F32(10.0 * (m.controller :: GroupsTypesHPlus3.Controller).stickX))))

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
	m.faceAngle[3] = S16(-m.angleVel[2] * 8)
end

-- from src/game/mario_actions_submerged.c:update_swimming_pitch L284-303
function mario_actions_submerged.update_swimming_pitch(m: GroupsTypesHPlus3.MarioState)
	const targetPitch = S16(-S16(TruncS32(F32(252.0 * (m.controller :: GroupsTypesHPlus3.Controller).stickY))))
	const pitchVel = if m.faceAngle[1] < 0 then 0x100 else 0x200

	if m.faceAngle[1] < targetPitch then
		m.faceAngle[1] = S16(m.faceAngle[1] + pitchVel)

		if m.faceAngle[1] > targetPitch then
			m.faceAngle[1] = targetPitch
		end
	elseif m.faceAngle[1] > targetPitch then
		m.faceAngle[1] = S16(m.faceAngle[1] - pitchVel)

		if m.faceAngle[1] < targetPitch then
			m.faceAngle[1] = targetPitch
		end
	end
end

-- from src/game/mario_actions_submerged.c:common_idle_step L305-327
function mario_actions_submerged.common_idle_step(m: GroupsTypesHPlus3.MarioState, animation: number, arg: number)
	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	mario_actions_submerged.update_swimming_yaw(m)
	mario_actions_submerged.update_swimming_pitch(m)
	mario_actions_submerged.update_swimming_speed(m, mario_actions_submerged.MIN_SWIM_SPEED)
	mario_actions_submerged.perform_water_step(m)
	mario_actions_submerged.update_water_pitch(m)

	if m.faceAngle[1] > 0 then
		marioBodyState.headAngle[1] = S16(SrcEngineMathUtil.approach_s32(marioBodyState.headAngle[1], TruncS32(m.faceAngle[1] / 2), 0x80, 0x200))
	else
		marioBodyState.headAngle[1] = S16(SrcEngineMathUtil.approach_s32(marioBodyState.headAngle[1], 0, 0x200, 0x200))
	end

	if arg == 0 then
		Mario.set_mario_animation(m, animation)
	else
		Mario.set_mario_anim_with_accel(m, animation, arg)
	end

	mario_actions_submerged.set_swimming_at_surface_particles(m, IncludeSm64H.PARTICLE_IDLE_WATER_WAVE)
end

-- from src/game/mario_actions_submerged.c:act_water_idle L329-350
function mario_actions_submerged.act_water_idle(m: GroupsTypesHPlus3.MarioState): number
	local val = 0x10000

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PUNCH, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BREASTSTROKE, 0)
	end

	if m.faceAngle[1] < -0x1000 then
		val = 0x30000
	end

	mario_actions_submerged.common_idle_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_IDLE, val)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_water_idle L352-371
function mario_actions_submerged.act_hold_water_idle(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BREASTSTROKE, 0)
	end

	mario_actions_submerged.common_idle_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_IDLE_WITH_OBJ, 0)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_action_end L373-391
function mario_actions_submerged.act_water_action_end(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PUNCH, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_BREASTSTROKE, 0)
	end

	mario_actions_submerged.common_idle_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_ACTION_END, 0)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_water_action_end L393-417
function mario_actions_submerged.act_hold_water_action_end(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BREASTSTROKE, 0)
	end

	mario_actions_submerged.common_idle_step(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_ACTION_END_WITH_OBJ else IncludeMarioAnimationIdsH.MARIO_ANIM_STOP_GRAB_OBJ_WATER, 0)

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:reset_bob_variables L419-423
function mario_actions_submerged.reset_bob_variables(m: GroupsTypesHPlus3.MarioState)
	mario_actions_submerged.sBobTimer = 0
	mario_actions_submerged.sBobIncrement = 0x800
	mario_actions_submerged.sBobHeight = F32(F32(m.faceAngle[1] / 256.0) + 20.0)
end

-- from src/game/mario_actions_submerged.c:surface_swim_bob L428-437
function mario_actions_submerged.surface_swim_bob(m: GroupsTypesHPlus3.MarioState)
	if mario_actions_submerged.sBobIncrement ~= 0 and m.pos[2] > m.waterLevel - 85 and m.faceAngle[1] >= 0 then
		mario_actions_submerged.sBobTimer = S16(mario_actions_submerged.sBobTimer + mario_actions_submerged.sBobIncrement)

		if mario_actions_submerged.sBobTimer >= 0 then
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
			marioObj.header.gfx.pos[2] = F32(marioObj.header.gfx.pos[2] + F32(mario_actions_submerged.sBobHeight * SrcEngineMathUtilH.sins(mario_actions_submerged.sBobTimer)))
			return
		end
	end

	mario_actions_submerged.sBobIncrement = 0
end

-- from src/game/mario_actions_submerged.c:common_swimming_step L439-483
function mario_actions_submerged.common_swimming_step(m: GroupsTypesHPlus3.MarioState, swimStrength: number)
	swimStrength = S16(TruncS32(swimStrength))
	mario_actions_submerged.update_swimming_yaw(m)
	mario_actions_submerged.update_swimming_pitch(m)
	mario_actions_submerged.update_swimming_speed(m, F32(swimStrength / 10.0))

	const stepResult = mario_actions_submerged.perform_water_step(m)

	if stepResult == IncludeSm64H.WATER_STEP_HIT_FLOOR then
		const floorPitch = S16(-Mario.find_floor_slope(m, -0x8000))

		if m.faceAngle[1] < floorPitch then
			m.faceAngle[1] = floorPitch
		end
	elseif stepResult == IncludeSm64H.WATER_STEP_HIT_CEILING then
		if m.faceAngle[1] > -0x3000 then
			m.faceAngle[1] = S16(m.faceAngle[1] - 0x100)
		end
	elseif stepResult == IncludeSm64H.WATER_STEP_HIT_WALL then
		if (m.controller :: GroupsTypesHPlus3.Controller).stickY == 0.0 then
			if m.faceAngle[1] > 0.0 then
				m.faceAngle[1] = S16(m.faceAngle[1] + 0x200)

				if m.faceAngle[1] > 0x3F00 then
					m.faceAngle[1] = 0x3F00
				end
			else
				m.faceAngle[1] = S16(m.faceAngle[1] - 0x200)

				if m.faceAngle[1] < -0x3F00 then
					m.faceAngle[1] = -0x3F00
				end
			end
		end
	end

	mario_actions_submerged.update_water_pitch(m)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[1] = S16(SrcEngineMathUtil.approach_s32(marioBodyState.headAngle[1], 0, 0x200, 0x200))

	mario_actions_submerged.surface_swim_bob(m)
	mario_actions_submerged.set_swimming_at_surface_particles(m, IncludeSm64H.PARTICLE_WAVE_TRAIL)
end

-- from src/game/mario_actions_submerged.c:play_swimming_noise L485-490
function mario_actions_submerged.play_swimming_noise(m: GroupsTypesHPlus3.MarioState)
	const animFrame = (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame

	if animFrame == 0 or animFrame == 12 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN434, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end
end

-- from src/game/mario_actions_submerged.c:check_water_jump L492-510
function mario_actions_submerged.check_water_jump(m: GroupsTypesHPlus3.MarioState): number
	const probe = TruncS32(F32(m.pos[2] + 1.5))

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		if probe >= m.waterLevel - 80 and m.faceAngle[1] >= 0 and (m.controller :: GroupsTypesHPlus3.Controller).stickY < -60.0 then
			SrcEngineMathUtil.vec3s_set(m.angleVel, 0, 0, 0)

			m.vel[2] = 62.0

			if m.heldObj == nil then
				return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_JUMP, 0)
			else
				return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_JUMP, 0)
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_breaststroke L512-570
function mario_actions_submerged.act_breaststroke(m: GroupsTypesHPlus3.MarioState): number
	if m.actionArg == 0 then
		mario_actions_submerged.sSwimStrength = mario_actions_submerged.MIN_SWIM_STRENGTH
	end

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PUNCH, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 14 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_FLUTTER_KICK, 0)
	end

	if mario_actions_submerged.check_water_jump(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if m.actionTimer < 6 then
		m.forwardVel = F32(m.forwardVel + 0.5)
	end

	if m.actionTimer >= 9 then
		m.forwardVel = F32(m.forwardVel + 1.5)
	end

	if m.actionTimer >= 2 then
		if m.actionTimer < 6 and bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			m.actionState = 1
		end

		if m.actionTimer == 9 and m.actionState == 1 then
			Mario.set_anim_to_frame(m, 0)
			m.actionState = 0
			m.actionTimer = 1
			mario_actions_submerged.sSwimStrength = mario_actions_submerged.MIN_SWIM_STRENGTH
		end
	end

	if m.actionTimer == 1 then
		Audio.play_sound(if mario_actions_submerged.sSwimStrength == mario_actions_submerged.MIN_SWIM_STRENGTH then IncludeSoundsH.SOUND_ACTION_SWIM else IncludeSoundsH.SOUND_ACTION_SWIM_FAST, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		mario_actions_submerged.reset_bob_variables(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SWIM_PART1)
	mario_actions_submerged.common_swimming_step(m, mario_actions_submerged.sSwimStrength)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_swimming_end L572-607
function mario_actions_submerged.act_swimming_end(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PUNCH, 0)
	end

	if m.actionTimer >= 15 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_ACTION_END, 0)
	end

	if mario_actions_submerged.check_water_jump(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) and m.actionTimer >= 7 then
		if m.actionTimer == 7 and mario_actions_submerged.sSwimStrength < 280 then
			mario_actions_submerged.sSwimStrength = S16(mario_actions_submerged.sSwimStrength + 10)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_BREASTSTROKE, 1)
	end

	if m.actionTimer >= 7 then
		mario_actions_submerged.sSwimStrength = mario_actions_submerged.MIN_SWIM_STRENGTH
	end

	m.actionTimer = U16(m.actionTimer + 1)

	m.forwardVel = F32(m.forwardVel - 0.25)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SWIM_PART2)
	mario_actions_submerged.common_swimming_step(m, mario_actions_submerged.sSwimStrength)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_flutter_kick L609-636
function mario_actions_submerged.act_flutter_kick(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PUNCH, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		if m.actionTimer == 0 and mario_actions_submerged.sSwimStrength < 280 then
			mario_actions_submerged.sSwimStrength = S16(mario_actions_submerged.sSwimStrength + 10)
		end

		return Mario.set_mario_action(m, IncludeSm64H.ACT_SWIMMING_END, 0)
	end

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 12.0, F32(0.1), F32(0.15))
	m.actionTimer = 1
	mario_actions_submerged.sSwimStrength = mario_actions_submerged.MIN_SWIM_STRENGTH

	if m.forwardVel < 14.0 then
		mario_actions_submerged.play_swimming_noise(m)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLUTTERKICK)
	end

	mario_actions_submerged.common_swimming_step(m, mario_actions_submerged.sSwimStrength)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_breaststroke L638-687
function mario_actions_submerged.act_hold_breaststroke(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	if m.actionTimer == 17 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FLUTTER_KICK, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	if mario_actions_submerged.check_water_jump(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if m.actionTimer < 6 then
		m.forwardVel = F32(m.forwardVel + 0.5)
	end

	if m.actionTimer >= 9 then
		m.forwardVel = F32(m.forwardVel + 1.5)
	end

	if m.actionTimer >= 2 then
		if m.actionTimer < 6 and bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
			m.actionState = 1
		end

		if m.actionTimer == 9 and m.actionState == 1 then
			Mario.set_anim_to_frame(m, 0)
			m.actionState = 0
			m.actionTimer = 1
		end
	end

	if m.actionTimer == 1 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SWIM, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		mario_actions_submerged.reset_bob_variables(m)
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SWIM_WITH_OBJ_PART1)
	mario_actions_submerged.common_swimming_step(m, 0x00A0)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_swimming_end L689-720
function mario_actions_submerged.act_hold_swimming_end(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if m.actionTimer >= 15 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_ACTION_END, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	if mario_actions_submerged.check_water_jump(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) and m.actionTimer >= 7 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BREASTSTROKE, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	m.forwardVel = F32(m.forwardVel - 0.25)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SWIM_WITH_OBJ_PART2)
	mario_actions_submerged.common_swimming_step(m, 0x00A0)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_flutter_kick L722-746
function mario_actions_submerged.act_hold_flutter_kick(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
	end

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	if not bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_SWIMMING_END, 0)
	end

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 12.0, F32(0.1), F32(0.15))

	if m.forwardVel < 14.0 then
		mario_actions_submerged.play_swimming_noise(m)
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLUTTERKICK_WITH_OBJ)
	end

	mario_actions_submerged.common_swimming_step(m, 0x00A0)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_shell_swimming L748-771
function mario_actions_submerged.act_water_shell_swimming(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_THROW, 0)
	end

	const actionTimer = m.actionTimer
	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 240 then
		const heldObj = m.heldObj :: GroupsTypesHPlus3.Object
		buffer.writei32(heldObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_STOP_RIDING)

		m.heldObj = nil
		SoundInit.stop_shell_music()
		Mario.set_mario_action(m, IncludeSm64H.ACT_FLUTTER_KICK, 0)
	end

	m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 30.0, 2.0, 1.0)

	mario_actions_submerged.play_swimming_noise(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLUTTERKICK_WITH_OBJ)
	mario_actions_submerged.common_swimming_step(m, 0x012C)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:check_water_grab L773-792
function mario_actions_submerged.check_water_grab(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if bit32.btest(marioObj.collidedObjInteractTypes, InteractionH.INTERACT_GRABBABLE) then
		const object = Interaction.mario_get_collided_object(m, InteractionH.INTERACT_GRABBABLE) :: GroupsTypesHPlus3.Object
		const dx = F32(buffer.readf32(object.rawData, IncludeObjectFieldsH.oPosX) - m.pos[1])
		const dz = F32(buffer.readf32(object.rawData, IncludeObjectFieldsH.oPosZ) - m.pos[3])
		const dAngleToObject = S16(SrcEngineMathUtil.atan2s(dz, dx) - m.faceAngle[2])

		if dAngleToObject >= -0x2AAA and dAngleToObject <= 0x2AAA then
			m.usedObj = object
			Interaction.mario_grab_used_object(m)
			const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

			marioBodyState.grabPos = IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_LIGHT_OBJ

			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_throw L794-818
function mario_actions_submerged.act_water_throw(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.update_swimming_yaw(m)
	mario_actions_submerged.update_swimming_pitch(m)
	mario_actions_submerged.update_swimming_speed(m, mario_actions_submerged.MIN_SWIM_SPEED)
	mario_actions_submerged.perform_water_step(m)
	mario_actions_submerged.update_water_pitch(m)

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_THROW_OBJ)
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_SWIM, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[1] = S16(SrcEngineMathUtil.approach_s32(marioBodyState.headAngle[1], 0, 0x200, 0x200))

	const actionTimer = m.actionTimer
	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 5 then
		Interaction.mario_throw_held_object(m)
	end

	if Mario.is_anim_at_end(m) ~= 0 then
		Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_punch L820-864
function mario_actions_submerged.act_water_punch(m: GroupsTypesHPlus3.MarioState): number
	if m.forwardVel < 7.0 then
		m.forwardVel = F32(m.forwardVel + 1.0)
	end

	mario_actions_submerged.update_swimming_yaw(m)
	mario_actions_submerged.update_swimming_pitch(m)
	mario_actions_submerged.update_swimming_speed(m, mario_actions_submerged.MIN_SWIM_SPEED)
	mario_actions_submerged.perform_water_step(m)
	mario_actions_submerged.update_water_pitch(m)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[1] = S16(SrcEngineMathUtil.approach_s32(marioBodyState.headAngle[1], 0, 0x200, 0x200))

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_SWIM, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)

	if m.actionState == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_GRAB_OBJ_PART1)

		if Mario.is_anim_at_end(m) ~= 0 then
			m.actionState = U16(mario_actions_submerged.check_water_grab(m) + 1)
		end
	elseif m.actionState == 1 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_GRAB_OBJ_PART2)

		if Mario.is_anim_at_end(m) ~= 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_ACTION_END, 0)
		end
	elseif m.actionState == 2 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_PICK_UP_OBJ)

		if Mario.is_anim_at_end(m) ~= 0 then
			if (m.heldObj :: GroupsTypesHPlus3.Object).behavior == Memory.segmented_to_virtual(BehaviorIds.bhvKoopaShellUnderwater) then
				SoundInit.play_shell_music()
				Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_SHELL_SWIMMING, 0)
			else
				Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_ACTION_END, 1)
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:common_water_knockback_step L866-880
function mario_actions_submerged.common_water_knockback_step(m: GroupsTypesHPlus3.MarioState, animation: number, endAction: number, arg3: number)
	mario_actions_submerged.stationary_slow_down(m)
	mario_actions_submerged.perform_water_step(m)
	Mario.set_mario_animation(m, animation)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[1] = 0

	if Mario.is_anim_at_end(m) ~= 0 then
		if arg3 > 0 then
			m.invincTimer = 30
		end

		Mario.set_mario_action(m, if m.health >= 0x100 then endAction else IncludeSm64H.ACT_WATER_DEATH, 0)
	end
end

-- from src/game/mario_actions_submerged.c:act_backward_water_kb L882-885
function mario_actions_submerged.act_backward_water_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.common_water_knockback_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARDS_WATER_KB, IncludeSm64H.ACT_WATER_IDLE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_forward_water_kb L887-890
function mario_actions_submerged.act_forward_water_kb(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.common_water_knockback_step(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_FORWARD_KB, IncludeSm64H.ACT_WATER_IDLE, m.actionArg)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_shocked L892-911
function mario_actions_submerged.act_water_shocked(m: GroupsTypesHPlus3.MarioState): number
	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAAAOOOW, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_SHOCKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_SHOCK)

	if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SHOCKED) == 0 then
		m.actionTimer = U16(m.actionTimer + 1)
		m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_METAL_SHOCK)
	end

	if m.actionTimer >= 6 then
		m.invincTimer = 30
		Mario.set_mario_action(m, if m.health < 0x100 then IncludeSm64H.ACT_WATER_DEATH else IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	mario_actions_submerged.stationary_slow_down(m)
	mario_actions_submerged.perform_water_step(m)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[1] = 0

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_drowning L913-937
function mario_actions_submerged.act_drowning(m: GroupsTypesHPlus3.MarioState): number
	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	if m.actionState == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DROWNING_PART1)
		marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED

		if Mario.is_anim_at_end(m) ~= 0 then
			m.actionState = 1
		end
	elseif m.actionState == 1 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DROWNING_PART2)
		marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_DEAD

		if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 30 then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
		end
	end

	Mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DROWNING, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	mario_actions_submerged.stationary_slow_down(m)
	mario_actions_submerged.perform_water_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_death L939-951
function mario_actions_submerged.act_water_death(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.stationary_slow_down(m)
	mario_actions_submerged.perform_water_step(m)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_DEAD

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_DYING)

	if Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_DYING) == 35 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_water_plunge L953-1038
function mario_actions_submerged.act_water_plunge(m: GroupsTypesHPlus3.MarioState): number
	local stateFlags = if m.heldObj ~= nil then 1 else 0
	const endVSpeed = if mario_actions_submerged.swimming_near_surface(m) ~= 0 then 0.0 else -5.0

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		stateFlags = S32(bit32.bor(stateFlags, 4))
	elseif bit32.btest(m.prevAction, IncludeSm64H.ACT_FLAG_DIVING) or bit32.btest(m.input, IncludeSm64H.INPUT_A_DOWN) then
		stateFlags = S32(bit32.bor(stateFlags, 2))
	end

	m.actionTimer = U16(m.actionTimer + 1)

	mario_actions_submerged.stationary_slow_down(m)

	const stepResult = mario_actions_submerged.perform_water_step(m)

	if m.actionState == 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN430, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		if F32(m.peakHeight - m.pos[2]) > 1150.0 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HAHA_2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_WATER_SPLASH)
		m.actionState = 1
	end

	if stepResult == IncludeSm64H.WATER_STEP_HIT_FLOOR or m.vel[2] >= endVSpeed or m.actionTimer > 20 then
		if stateFlags == 0 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_ACTION_END, 0)
		elseif stateFlags == 1 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_ACTION_END, 0)
		elseif stateFlags == 2 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_FLUTTER_KICK, 0)
		elseif stateFlags == 3 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FLUTTER_KICK, 0)
		elseif stateFlags == 4 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 0)
		elseif stateFlags == 5 then
			Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 0)
		end

		mario_actions_submerged.sBobIncrement = 0
	end

	if stateFlags == 0 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_ACTION_END)
	elseif stateFlags == 1 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_ACTION_END_WITH_OBJ)
	elseif stateFlags == 2 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLUTTERKICK)
	elseif stateFlags == 3 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FLUTTERKICK_WITH_OBJ)
	elseif stateFlags == 4 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	elseif stateFlags == 5 then
		Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_WITH_LIGHT_OBJ)
	end

	m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_PLUNGE_BUBBLE)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_caught_in_whirlpool L1040-1098
function mario_actions_submerged.act_caught_in_whirlpool(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const whirlpool = m.usedObj :: GroupsTypesHPlus3.Object

	local dx = F32(m.pos[1] - buffer.readf32(whirlpool.rawData, IncludeObjectFieldsH.oPosX))
	local dz = F32(m.pos[3] - buffer.readf32(whirlpool.rawData, IncludeObjectFieldsH.oPosZ))
	const distance = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	const whirlpoolPosY = F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY) + m.vel[2])
	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY, whirlpoolPosY)

	if whirlpoolPosY < 0.0 then
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY, 0.0)

		if distance < F32(16.1) then
			const actionTimer = m.actionTimer
			m.actionTimer = U16(m.actionTimer + 1)

			if actionTimer == 16 then
				LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
			end
		end
	end

	local newDistance = 0.0
	local angleChange = 0

	if distance <= 28.0 then
		newDistance = 16.0
		angleChange = 0x1800
	elseif distance < 256.0 then
		newDistance = F32(distance - F32(12.0 - F32(distance / 32.0)))
		angleChange = S16(TruncS32(F32(0x1C00 - F32(distance * 20.0))))
	else
		newDistance = F32(distance - 4.0)
		angleChange = 0x800
	end

	m.vel[2] = F32(-640.0 / F32(newDistance + 16.0))

	const sinAngleChange = SrcEngineMathUtilH.sins(angleChange)
	const cosAngleChange = SrcEngineMathUtilH.coss(angleChange)

	if distance < 1.0 then
		dx = F32(newDistance * SrcEngineMathUtilH.sins(m.faceAngle[2]))
		dz = F32(newDistance * SrcEngineMathUtilH.coss(m.faceAngle[2]))
	else
		dx = F32(dx * F32(newDistance / distance))
		dz = F32(dz * F32(newDistance / distance))
	end

	m.pos[1] = F32(F32(buffer.readf32(whirlpool.rawData, IncludeObjectFieldsH.oPosX) + F32(dx * cosAngleChange)) + F32(dz * sinAngleChange))
	m.pos[3] = F32(F32(buffer.readf32(whirlpool.rawData, IncludeObjectFieldsH.oPosZ) - F32(dx * sinAngleChange)) + F32(dz * cosAngleChange))
	m.pos[2] = F32(buffer.readf32(whirlpool.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY))

	m.faceAngle[2] = S16(SrcEngineMathUtil.atan2s(dz, dx) + 0x8000)

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:play_metal_water_jumping_sound L1100-1107
function mario_actions_submerged.play_metal_water_jumping_sound(m: GroupsTypesHPlus3.MarioState, landing: number)
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED) then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_MIST_CIRCLE)
	end

	Mario.play_sound_if_no_flag(m, if landing ~= 0 then IncludeSoundsH.SOUND_ACTION_METAL_LAND_WATER else IncludeSoundsH.SOUND_ACTION_METAL_JUMP_WATER, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
end

-- from src/game/mario_actions_submerged.c:play_metal_water_walking_sound L1109-1114
function mario_actions_submerged.play_metal_water_walking_sound(m: GroupsTypesHPlus3.MarioState)
	if Mario.is_anim_past_frame(m, 10) ~= 0 or Mario.is_anim_past_frame(m, 49) ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_METAL_STEP_WATER, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DUST)
	end
end

-- from src/game/mario_actions_submerged.c:update_metal_water_walking_speed L1116-1140
function mario_actions_submerged.update_metal_water_walking_speed(m: GroupsTypesHPlus3.MarioState)
	const val = F32(m.intendedMag / 1.5)

	if m.forwardVel <= 0.0 then
		m.forwardVel = F32(m.forwardVel + F32(1.1))
	elseif m.forwardVel <= val then
		m.forwardVel = F32(m.forwardVel + F32(F32(1.1) - F32(m.forwardVel / 43.0)))
	elseif (m.floor :: GroupsTypesHPlus3.Surface).normal.y >= F32(0.95) then
		m.forwardVel = F32(m.forwardVel - 1.0)
	end

	if m.forwardVel > 32.0 then
		m.forwardVel = 32.0
	end

	m.faceAngle[2] = S16(m.intendedYaw - SrcEngineMathUtil.approach_s32(S16(m.intendedYaw - m.faceAngle[2]), 0, 0x800, 0x800))

	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))

	m.vel[1] = m.slideVelX
	m.vel[2] = 0.0
	m.vel[3] = m.slideVelZ
end

-- from src/game/mario_actions_submerged.c:update_metal_water_jump_speed L1142-1169
function mario_actions_submerged.update_metal_water_jump_speed(m: GroupsTypesHPlus3.MarioState): number
	const waterSurface = m.waterLevel - 100

	if m.vel[2] > 0.0 and m.pos[2] > waterSurface then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		const intendedDYaw = S16(m.intendedYaw - m.faceAngle[2])

		m.forwardVel = F32(m.forwardVel + F32(F32(0.8) * SrcEngineMathUtilH.coss(intendedDYaw)))
		m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] + F32(0x200 * SrcEngineMathUtilH.sins(intendedDYaw)))))
	else
		m.forwardVel = SrcEngineMathUtil.approach_f32(m.forwardVel, 0.0, 0.25, 0.25)
	end

	if m.forwardVel > 16.0 then
		m.forwardVel = F32(m.forwardVel - 1.0)
	end

	if m.forwardVel < 0.0 then
		m.forwardVel = F32(m.forwardVel + 2.0)
	end

	m.slideVelX = F32(m.forwardVel * SrcEngineMathUtilH.sins(m.faceAngle[2]))
	m.vel[1] = m.slideVelX
	m.slideVelZ = F32(m.forwardVel * SrcEngineMathUtilH.coss(m.faceAngle[2]))
	m.vel[3] = m.slideVelZ

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_standing L1171-1206
function mario_actions_submerged.act_metal_water_standing(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_WALKING, 0)
	end

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
			m.actionState = 0
		end
	end

	MarioStep.stop_and_set_height_to_floor(m)

	if m.pos[2] >= m.waterLevel - 150 then
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_IDLE_WATER_WAVE)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_standing L1208-1228
function mario_actions_submerged.act_hold_metal_water_standing(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_WALKING, 0)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_walking L1230-1268
function mario_actions_submerged.act_metal_water_walking(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_FIRST_PERSON) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	local val04 = TruncS32(F32(F32(m.forwardVel / 4.0) * 0x10000))

	if val04 < 0x1000 then
		val04 = 0x1000
	end

	Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING, val04)
	mario_actions_submerged.play_metal_water_walking_sound(m)
	mario_actions_submerged.update_metal_water_walking_speed(m)

	const groundStep = MarioStep.perform_ground_step(m)

	if groundStep == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 1)
	elseif groundStep == IncludeSm64H.GROUND_STEP_HIT_WALL then
		m.forwardVel = 0.0
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_walking L1270-1310
function mario_actions_submerged.act_hold_metal_water_walking(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_WALKING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_UNKNOWN_5) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_STANDING, 0)
	end

	m.intendedMag = F32(m.intendedMag * F32(0.4))

	local val04 = TruncS32(F32(F32(m.forwardVel / 2.0) * 0x10000))

	if val04 < 0x1000 then
		val04 = 0x1000
	end

	Mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RUN_WITH_LIGHT_OBJ, val04)
	mario_actions_submerged.play_metal_water_walking_sound(m)
	mario_actions_submerged.update_metal_water_walking_speed(m)

	const groundStep = MarioStep.perform_ground_step(m)

	if groundStep == IncludeSm64H.GROUND_STEP_LEFT_GROUND then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING, 1)
	elseif groundStep == IncludeSm64H.GROUND_STEP_HIT_WALL then
		m.forwardVel = 0.0
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_jump L1312-1335
function mario_actions_submerged.act_metal_water_jump(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if mario_actions_submerged.update_metal_water_jump_speed(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_JUMP, 1)
	end

	mario_actions_submerged.play_metal_water_jumping_sound(m, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP)

	const airStep = MarioStep.perform_air_step(m, 0)

	if airStep == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_JUMP_LAND, 0)
	elseif airStep == IncludeSm64H.AIR_STEP_HIT_WALL then
		m.forwardVel = 0.0
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_jump L1337-1364
function mario_actions_submerged.act_hold_metal_water_jump(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if mario_actions_submerged.update_metal_water_jump_speed(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_JUMP, 1)
	end

	mario_actions_submerged.play_metal_water_jumping_sound(m, 0)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_WITH_LIGHT_OBJ)

	const airStep = MarioStep.perform_air_step(m, 0)

	if airStep == IncludeSm64H.AIR_STEP_LANDED then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP_LAND, 0)
	elseif airStep == IncludeSm64H.AIR_STEP_HIT_WALL then
		m.forwardVel = 0.0
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_falling L1366-1383
function mario_actions_submerged.act_metal_water_falling(m: GroupsTypesHPlus3.MarioState): number
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] + F32(0x400 * SrcEngineMathUtilH.sins(m.intendedYaw - m.faceAngle[2])))))
	end

	Mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL else IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_FROM_WATER)
	mario_actions_submerged.stationary_slow_down(m)

	if bit32.btest(mario_actions_submerged.perform_water_step(m), IncludeSm64H.WATER_STEP_HIT_FLOOR) then
		Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALL_LAND, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_falling L1385-1406
function mario_actions_submerged.act_hold_metal_water_falling(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_FALLING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		m.faceAngle[2] = S16(TruncS32(F32(m.faceAngle[2] + F32(0x400 * SrcEngineMathUtilH.sins(m.intendedYaw - m.faceAngle[2])))))
	end

	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_WITH_LIGHT_OBJ)
	mario_actions_submerged.stationary_slow_down(m)

	if bit32.btest(mario_actions_submerged.perform_water_step(m), IncludeSm64H.WATER_STEP_HIT_FLOOR) then
		Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_FALL_LAND, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_jump_land L1408-1427
function mario_actions_submerged.act_metal_water_jump_land(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.play_metal_water_jumping_sound(m, IncludePRUltratypesH.TRUE)

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_WALKING, 0)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP)

	if Mario.is_anim_at_end(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_jump_land L1429-1452
function mario_actions_submerged.act_hold_metal_water_jump_land(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.play_metal_water_jumping_sound(m, IncludePRUltratypesH.TRUE)

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_WALKING, 0)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_JUMP_LAND_WITH_LIGHT_OBJ)

	if Mario.is_anim_at_end(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_STANDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_metal_water_fall_land L1454-1473
function mario_actions_submerged.act_metal_water_fall_land(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.play_metal_water_jumping_sound(m, IncludePRUltratypesH.TRUE)

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_WALKING, 0)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND)

	if Mario.is_anim_at_end(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:act_hold_metal_water_fall_land L1475-1498
function mario_actions_submerged.act_hold_metal_water_fall_land(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_submerged.play_metal_water_jumping_sound(m, IncludePRUltratypesH.TRUE)

	if bit32.btest(buffer.readi32((m.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT) then
		return Mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_METAL_WATER_STANDING, 0)
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WATER_IDLE, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_WALKING, 0)
	end

	MarioStep.stop_and_set_height_to_floor(m)
	Mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FALL_LAND_WITH_LIGHT_OBJ)

	if Mario.is_anim_at_end(m) ~= 0 then
		return Mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_METAL_WATER_STANDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:check_common_submerged_cancels L1500-1524
function mario_actions_submerged.check_common_submerged_cancels(m: GroupsTypesHPlus3.MarioState): number
	if m.pos[2] > m.waterLevel - 80 then
		if m.waterLevel - 80 > m.floorHeight then
			m.pos[2] = m.waterLevel - 80
		else
			-- Water shell swimming and a held shell can coexist for ~5 frames after B (DDD cloning window); the held shell is released here.
			if m.action == IncludeSm64H.ACT_WATER_SHELL_SWIMMING and m.heldObj ~= nil then
				const heldObj = m.heldObj :: GroupsTypesHPlus3.Object
				buffer.writei32(heldObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_STOP_RIDING)

				m.heldObj = nil
				SoundInit.stop_shell_music()
			end

			return Mario.transition_submerged_to_walking(m)
		end
	end

	if m.health < 0x100 and not bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_INTANGIBLE, IncludeSm64H.ACT_FLAG_INVULNERABLE)) then
		Mario.set_mario_action(m, IncludeSm64H.ACT_DROWNING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_submerged.c:mario_execute_submerged_action L1526-1576
function mario_actions_submerged.mario_execute_submerged_action(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_submerged.check_common_submerged_cancels(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	m.quicksandDepth = 0.0

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState
	marioBodyState.headAngle[2] = 0
	marioBodyState.headAngle[3] = 0

	local cancel = 0

	if m.action == IncludeSm64H.ACT_WATER_IDLE then
		cancel = mario_actions_submerged.act_water_idle(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_WATER_IDLE then
		cancel = mario_actions_submerged.act_hold_water_idle(m)
	elseif m.action == IncludeSm64H.ACT_WATER_ACTION_END then
		cancel = mario_actions_submerged.act_water_action_end(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_WATER_ACTION_END then
		cancel = mario_actions_submerged.act_hold_water_action_end(m)
	elseif m.action == IncludeSm64H.ACT_DROWNING then
		cancel = mario_actions_submerged.act_drowning(m)
	elseif m.action == IncludeSm64H.ACT_BACKWARD_WATER_KB then
		cancel = mario_actions_submerged.act_backward_water_kb(m)
	elseif m.action == IncludeSm64H.ACT_FORWARD_WATER_KB then
		cancel = mario_actions_submerged.act_forward_water_kb(m)
	elseif m.action == IncludeSm64H.ACT_WATER_DEATH then
		cancel = mario_actions_submerged.act_water_death(m)
	elseif m.action == IncludeSm64H.ACT_WATER_SHOCKED then
		cancel = mario_actions_submerged.act_water_shocked(m)
	elseif m.action == IncludeSm64H.ACT_BREASTSTROKE then
		cancel = mario_actions_submerged.act_breaststroke(m)
	elseif m.action == IncludeSm64H.ACT_SWIMMING_END then
		cancel = mario_actions_submerged.act_swimming_end(m)
	elseif m.action == IncludeSm64H.ACT_FLUTTER_KICK then
		cancel = mario_actions_submerged.act_flutter_kick(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_BREASTSTROKE then
		cancel = mario_actions_submerged.act_hold_breaststroke(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_SWIMMING_END then
		cancel = mario_actions_submerged.act_hold_swimming_end(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_FLUTTER_KICK then
		cancel = mario_actions_submerged.act_hold_flutter_kick(m)
	elseif m.action == IncludeSm64H.ACT_WATER_SHELL_SWIMMING then
		cancel = mario_actions_submerged.act_water_shell_swimming(m)
	elseif m.action == IncludeSm64H.ACT_WATER_THROW then
		cancel = mario_actions_submerged.act_water_throw(m)
	elseif m.action == IncludeSm64H.ACT_WATER_PUNCH then
		cancel = mario_actions_submerged.act_water_punch(m)
	elseif m.action == IncludeSm64H.ACT_WATER_PLUNGE then
		cancel = mario_actions_submerged.act_water_plunge(m)
	elseif m.action == IncludeSm64H.ACT_CAUGHT_IN_WHIRLPOOL then
		cancel = mario_actions_submerged.act_caught_in_whirlpool(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_STANDING then
		cancel = mario_actions_submerged.act_metal_water_standing(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_WALKING then
		cancel = mario_actions_submerged.act_metal_water_walking(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_FALLING then
		cancel = mario_actions_submerged.act_metal_water_falling(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_FALL_LAND then
		cancel = mario_actions_submerged.act_metal_water_fall_land(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_JUMP then
		cancel = mario_actions_submerged.act_metal_water_jump(m)
	elseif m.action == IncludeSm64H.ACT_METAL_WATER_JUMP_LAND then
		cancel = mario_actions_submerged.act_metal_water_jump_land(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_STANDING then
		cancel = mario_actions_submerged.act_hold_metal_water_standing(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_WALKING then
		cancel = mario_actions_submerged.act_hold_metal_water_walking(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_FALLING then
		cancel = mario_actions_submerged.act_hold_metal_water_falling(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_FALL_LAND then
		cancel = mario_actions_submerged.act_hold_metal_water_fall_land(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP then
		cancel = mario_actions_submerged.act_hold_metal_water_jump(m)
	elseif m.action == IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP_LAND then
		cancel = mario_actions_submerged.act_hold_metal_water_jump_land(m)
	end

	return cancel
end

-- from src/game/mario_actions_submerged.c:sSwimStrength L24-24
mario_actions_submerged.sSwimStrength = mario_actions_submerged.MIN_SWIM_STRENGTH

return mario_actions_submerged
