--!strict
--!optimize 2

--[[
	Port of src/game/envfx_snow.c.
]]

const Registry = require("../../groups/registry")

const EnvfxSnowH = require("./envfx_snow_h")
const EnvfxBubbles = require("./envfx_bubbles")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Memory = require("./memory")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")

-- from src/game/envfx_snow.c:SnowFlakeVertex
export type SnowFlakeVertex = {
	x: number,
	y: number,
	z: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/envfx_snow.luau:scratch
const Scratch = {
	envfx_update_snow_radius = { 0 },
	envfx_update_snow_pitch = { 0 },
	envfx_update_snow_yaw = { 0 },
	envfx_update_snow_snowCylinderPos = { 0, 0, 0 },
	envfx_update_snow_vertex1 = { 0, 0, 0 },
	envfx_update_snow_vertex2 = { 0, 0, 0 },
	envfx_update_snow_vertex3 = { 0, 0, 0 },
}

-- from src/game/envfx_snow.c:data
const envfx_snow = {
	-- from src/game/envfx_snow.c:gEnvFxBuffer L35-35
	gEnvFxBuffer = nil :: { EnvfxSnowH.EnvFxParticle }?,
	-- from src/game/envfx_snow.c:gSnowCylinderLastPos L36-36
	gSnowCylinderLastPos = table.create(3, 0),
	-- from src/game/envfx_snow.c:gSnowParticleCount L37-37
	gSnowParticleCount = 0,
	-- from src/game/envfx_snow.c:gSnowParticleMaxCount L38-38
	gSnowParticleMaxCount = 0,
	-- from src/game/envfx_snow.c:gEnvFxMode L41-41
	gEnvFxMode = EnvfxSnowH.ENVFX_MODE_NONE,
	-- from src/game/envfx_snow.c:D_80330644 L42-42
	D_80330644 = 0,
	-- from src/game/envfx_snow.c:gSnowTempVtx L45-47
	gSnowTempVtx = {
		{ { -5, 5, 0 }, 0, { 0, 0 }, { 0x7F, 0x7F, 0x7F, 0xFF } },
		{ { -5, -5, 0 }, 0, { 0, 960 }, { 0x7F, 0x7F, 0x7F, 0xFF } },
		{ { 5, 5, 0 }, 0, { 960, 0 }, { 0x7F, 0x7F, 0x7F, 0xFF } },
	},
	-- from src/game/envfx_snow.c:gSnowFlakeVertex1 L50-50
	gSnowFlakeVertex1 = { x = -5, y = 5, z = 0 },
	-- from src/game/envfx_snow.c:gSnowFlakeVertex2 L51-51
	gSnowFlakeVertex2 = { x = -5, y = -5, z = 0 },
	-- from src/game/envfx_snow.c:gSnowFlakeVertex3 L52-52
	gSnowFlakeVertex3 = { x = 5, y = 5, z = 0 },
}

Registry.Register("src__game__envfx_snow", envfx_snow)

-- from src/game/envfx_snow.c:SnowFlakeVertex (zero-filled constructor)
function envfx_snow.new_SnowFlakeVertex(): SnowFlakeVertex
	return { x = 0, y = 0, z = 0 } :: SnowFlakeVertex
end

-- from src/game/envfx_snow.c:envfx_init_snow L62-93
function envfx_snow.envfx_init_snow(mode: number): number
	if mode == EnvfxSnowH.ENVFX_MODE_NONE then
		return IncludePRUltratypesH.FALSE
	elseif mode == EnvfxSnowH.ENVFX_SNOW_NORMAL then
		envfx_snow.gSnowParticleMaxCount = 140
		envfx_snow.gSnowParticleCount = 5
	elseif mode == EnvfxSnowH.ENVFX_SNOW_WATER then
		envfx_snow.gSnowParticleMaxCount = 30
		envfx_snow.gSnowParticleCount = 30
	elseif mode == EnvfxSnowH.ENVFX_SNOW_BLIZZARD then
		envfx_snow.gSnowParticleMaxCount = 140
		envfx_snow.gSnowParticleCount = 140
	end

	-- mem_pool_alloc of the effects pool and its NULL test: the buffer is a table of zero filled particles (envfx-particle-buffer-table)
	const particles: { EnvfxSnowH.EnvFxParticle } = {}

	for index = 1, envfx_snow.gSnowParticleMaxCount do
		particles[index] = EnvfxSnowH.new_EnvFxParticle()
	end

	envfx_snow.gEnvFxBuffer = particles
	envfx_snow.gEnvFxMode = S8(mode)

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_snow.c:envfx_update_snowflake_count L101-133
function envfx_snow.envfx_update_snowflake_count(mode: number, marioPos: { number })
	const globalTimer: number = Registry.Members.src__game__game_init.gGlobalTimer

	if mode == EnvfxSnowH.ENVFX_SNOW_NORMAL then
		if envfx_snow.gSnowParticleMaxCount > envfx_snow.gSnowParticleCount then
			if bit32.band(globalTimer, 63) == 0 then
				envfx_snow.gSnowParticleCount = S16(envfx_snow.gSnowParticleCount + 5)
			end
		end
	elseif mode == EnvfxSnowH.ENVFX_SNOW_WATER then
		const waterLevel = SrcEngineSurfaceCollision.find_water_level(marioPos[1], marioPos[3])
		const scaled = TruncS32((F32(F32(waterLevel - 400.0) - marioPos[2])) * 0.001)

		envfx_snow.gSnowParticleCount = S16(S32(bit32.arshift(S32(bit32.lshift(scaled, 0x10)), 0x10)) * 5)

		if envfx_snow.gSnowParticleCount < 0 then
			envfx_snow.gSnowParticleCount = 0
		end

		if envfx_snow.gSnowParticleCount > envfx_snow.gSnowParticleMaxCount then
			envfx_snow.gSnowParticleCount = envfx_snow.gSnowParticleMaxCount
		end
	elseif mode == EnvfxSnowH.ENVFX_SNOW_BLIZZARD then
		-- no update
	end
end

-- from src/game/envfx_snow.c:envfx_cleanup_snow L139-146
function envfx_snow.envfx_cleanup_snow(snowParticleArray: unknown)
	if envfx_snow.gEnvFxMode ~= EnvfxSnowH.ENVFX_MODE_NONE then
		if snowParticleArray ~= nil then
			-- mem_pool_free of the effects pool: the buffer is a table (envfx-particle-buffer-table)
		end

		envfx_snow.gEnvFxMode = EnvfxSnowH.ENVFX_MODE_NONE
	end
end

-- from src/game/envfx_snow.c:orbit_from_positions L152-160
function envfx_snow.orbit_from_positions(from: { number }, to: { number }, radius: { number }, pitch: { number }, yaw: { number })
	const dx = F32(to[1] - from[1])
	const dy = F32(to[2] - from[2])
	const dz = F32(to[3] - from[3])

	radius[1] = S16(TruncS32(F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))))
	pitch[1] = SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz)))), dy)
	yaw[1] = SrcEngineMathUtil.atan2s(dz, dx)
end

-- from src/game/envfx_snow.c:pos_from_orbit L166-170
function envfx_snow.pos_from_orbit(origin: { number }, result: { number }, radius: number, pitch: number, yaw: number)
	radius = S16(TruncS32(radius))
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	result[1] = S16(TruncS32(F32(origin[1] + F32(F32(radius * SrcEngineMathUtilH.coss(pitch)) * SrcEngineMathUtilH.sins(yaw)))))
	result[2] = S16(TruncS32(F32(origin[2] + F32(radius * SrcEngineMathUtilH.sins(pitch)))))
	result[3] = S16(TruncS32(F32(origin[3] + F32(F32(radius * SrcEngineMathUtilH.coss(pitch)) * SrcEngineMathUtilH.coss(yaw)))))
end

-- from src/game/envfx_snow.c:envfx_is_snowflake_alive L177-191
function envfx_snow.envfx_is_snowflake_alive(index: number, snowCylinderX: number, snowCylinderY: number, snowCylinderZ: number): number
	const buffer = envfx_snow.gEnvFxBuffer :: { EnvfxSnowH.EnvFxParticle }
	const x = buffer[index + 1].xPos
	const y = buffer[index + 1].yPos
	const z = buffer[index + 1].zPos

	-- sqr on s32 operands is an int multiplication (the ported sqr rounds to f32)
	if (x - snowCylinderX) * (x - snowCylinderX) + (z - snowCylinderZ) * (z - snowCylinderZ) > 300 * 300 then
		return IncludePRUltratypesH.FALSE
	end

	if y < snowCylinderY - 201 or snowCylinderY + 201 < y then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_snow.c:envfx_update_snow_normal L207-233
function envfx_snow.envfx_update_snow_normal(snowCylinderX: number, snowCylinderY: number, snowCylinderZ: number)
	const buffer = envfx_snow.gEnvFxBuffer :: { EnvfxSnowH.EnvFxParticle }
	const deltaX = snowCylinderX - envfx_snow.gSnowCylinderLastPos[1]
	const deltaY = snowCylinderY - envfx_snow.gSnowCylinderLastPos[2]
	const deltaZ = snowCylinderZ - envfx_snow.gSnowCylinderLastPos[3]

	for i = 0, envfx_snow.gSnowParticleCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_snow.envfx_is_snowflake_alive(i, snowCylinderX, snowCylinderY, snowCylinderZ))

		if particle.isAlive == 0 then
			particle.xPos = TruncS32(F32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderX) + S16(deltaX * 2)))
			particle.zPos = TruncS32(F32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderZ) + S16(deltaZ * 2)))
			particle.yPos = TruncS32(F32(F32(200.0 * SrcEngineBehaviorScript.random_float()) + snowCylinderY))
			particle.isAlive = IncludePRUltratypesH.TRUE
		else
			particle.xPos = TruncS32(F32(F32(particle.xPos) + F32(F32(F32(SrcEngineBehaviorScript.random_float() * 2) - 1.0) + S16(TruncS32(deltaX / 1.2)))))
			particle.yPos -= 2 - S16(TruncS32(deltaY * 0.8))
			particle.zPos = TruncS32(F32(F32(particle.zPos) + F32(F32(F32(SrcEngineBehaviorScript.random_float() * 2) - 1.0) + S16(TruncS32(deltaZ / 1.2)))))
		end
	end

	envfx_snow.gSnowCylinderLastPos[1] = snowCylinderX
	envfx_snow.gSnowCylinderLastPos[2] = snowCylinderY
	envfx_snow.gSnowCylinderLastPos[3] = snowCylinderZ
end

-- from src/game/envfx_snow.c:envfx_update_snow_blizzard L241-267
function envfx_snow.envfx_update_snow_blizzard(snowCylinderX: number, snowCylinderY: number, snowCylinderZ: number)
	const buffer = envfx_snow.gEnvFxBuffer :: { EnvfxSnowH.EnvFxParticle }
	const deltaX = snowCylinderX - envfx_snow.gSnowCylinderLastPos[1]
	const deltaY = snowCylinderY - envfx_snow.gSnowCylinderLastPos[2]
	const deltaZ = snowCylinderZ - envfx_snow.gSnowCylinderLastPos[3]

	for i = 0, envfx_snow.gSnowParticleCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_snow.envfx_is_snowflake_alive(i, snowCylinderX, snowCylinderY, snowCylinderZ))

		if particle.isAlive == 0 then
			particle.xPos = TruncS32(F32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderX) + S16(deltaX * 2)))
			particle.zPos = TruncS32(F32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderZ) + S16(deltaZ * 2)))
			particle.yPos = TruncS32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderY))
			particle.isAlive = IncludePRUltratypesH.TRUE
		else
			particle.xPos = TruncS32(F32(F32(particle.xPos) + F32(F32(F32(F32(SrcEngineBehaviorScript.random_float() * 2) - 1.0) + S16(TruncS32(deltaX / 1.2))) + 20.0)))
			particle.yPos -= 5 - S16(TruncS32(deltaY * 0.8))
			particle.zPos = TruncS32(F32(F32(particle.zPos) + F32(F32(F32(SrcEngineBehaviorScript.random_float() * 2) - 1.0) + S16(TruncS32(deltaZ / 1.2)))))
		end
	end

	envfx_snow.gSnowCylinderLastPos[1] = snowCylinderX
	envfx_snow.gSnowCylinderLastPos[2] = snowCylinderY
	envfx_snow.gSnowCylinderLastPos[3] = snowCylinderZ
end

-- from src/game/envfx_snow.c:is_in_mystery_snow_area L278-283
function envfx_snow.is_in_mystery_snow_area(x: number, y: number, z: number): number
	if (x - 3380) * (x - 3380) + (z + 520) * (z + 520) < 3000 * 3000 then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/envfx_snow.c:envfx_update_snow_water L289-302
function envfx_snow.envfx_update_snow_water(snowCylinderX: number, snowCylinderY: number, snowCylinderZ: number)
	const buffer = envfx_snow.gEnvFxBuffer :: { EnvfxSnowH.EnvFxParticle }

	for i = 0, envfx_snow.gSnowParticleCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_snow.envfx_is_snowflake_alive(i, snowCylinderX, snowCylinderY, snowCylinderZ))

		if particle.isAlive == 0 then
			particle.xPos = TruncS32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderX))
			particle.zPos = TruncS32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderZ))
			particle.yPos = TruncS32(F32(F32(F32(400.0 * SrcEngineBehaviorScript.random_float()) - 200.0) + snowCylinderY))
			particle.isAlive = IncludePRUltratypesH.TRUE
		end
	end
end

-- from src/game/envfx_snow.c:rotate_triangle_vertices L308-339
function envfx_snow.rotate_triangle_vertices(vertex1: { number }, vertex2: { number }, vertex3: { number }, pitch: number, yaw: number)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	const cosPitch = SrcEngineMathUtilH.coss(pitch)
	const sinPitch = SrcEngineMathUtilH.sins(pitch)
	const cosMYaw = SrcEngineMathUtilH.coss(-yaw)
	const sinMYaw = SrcEngineMathUtilH.sins(-yaw)

	const v1x = vertex1[1]
	const v1y = vertex1[2]
	const v1z = vertex1[3]

	const v2x = vertex2[1]
	const v2y = vertex2[2]
	const v2z = vertex2[3]

	const v3x = vertex3[1]
	const v3y = vertex3[2]
	const v3z = vertex3[3]

	vertex1[1] = S16(TruncS32(F32(F32(F32(v1x * cosMYaw) + F32(v1y * F32(sinPitch * sinMYaw))) + F32(v1z * F32(F32(-sinMYaw) * cosPitch)))))
	vertex1[2] = S16(TruncS32(F32(F32(v1y * cosPitch) + F32(v1z * sinPitch))))
	vertex1[3] = S16(TruncS32(F32(F32(F32(v1x * sinMYaw) + F32(v1y * F32(F32(-sinPitch) * cosMYaw))) + F32(v1z * F32(cosPitch * cosMYaw)))))

	vertex2[1] = S16(TruncS32(F32(F32(F32(v2x * cosMYaw) + F32(v2y * F32(sinPitch * sinMYaw))) + F32(v2z * F32(F32(-sinMYaw) * cosPitch)))))
	vertex2[2] = S16(TruncS32(F32(F32(v2y * cosPitch) + F32(v2z * sinPitch))))
	vertex2[3] = S16(TruncS32(F32(F32(F32(v2x * sinMYaw) + F32(v2y * F32(F32(-sinPitch) * cosMYaw))) + F32(v2z * F32(cosPitch * cosMYaw)))))

	vertex3[1] = S16(TruncS32(F32(F32(F32(v3x * cosMYaw) + F32(v3y * F32(sinPitch * sinMYaw))) + F32(v3z * F32(F32(-sinMYaw) * cosPitch)))))
	vertex3[2] = S16(TruncS32(F32(F32(v3y * cosPitch) + F32(v3z * sinPitch))))
	vertex3[3] = S16(TruncS32(F32(F32(F32(v3x * sinMYaw) + F32(v3y * F32(F32(-sinPitch) * cosMYaw))) + F32(v3z * F32(cosPitch * cosMYaw)))))
end

-- from src/game/envfx_snow.c:append_snowflake_vertex_buffer L347-373
function envfx_snow.append_snowflake_vertex_buffer(gfx: { unknown }, index: number, vertex1: { number }, vertex2: { number }, vertex3: { number })
	-- gfx-display-lists-noop: only fills a display list vertex buffer (alloc_display_list) and emits gSPVertex
end

-- from src/game/envfx_snow.c:envfx_update_snow L379-460
function envfx_snow.envfx_update_snow(snowMode: number, marioPos: { number }, camFrom: { number }, camTo: { number }): { unknown }?
	const radius = Scratch.envfx_update_snow_radius
	const pitch = Scratch.envfx_update_snow_pitch
	const yaw = Scratch.envfx_update_snow_yaw
	const snowCylinderPos = Scratch.envfx_update_snow_snowCylinderPos
	const vertex1 = Scratch.envfx_update_snow_vertex1
	const vertex2 = Scratch.envfx_update_snow_vertex2
	const vertex3 = Scratch.envfx_update_snow_vertex3

	vertex1[1] = envfx_snow.gSnowFlakeVertex1.x
	vertex1[2] = envfx_snow.gSnowFlakeVertex1.y
	vertex1[3] = envfx_snow.gSnowFlakeVertex1.z
	vertex2[1] = envfx_snow.gSnowFlakeVertex2.x
	vertex2[2] = envfx_snow.gSnowFlakeVertex2.y
	vertex2[3] = envfx_snow.gSnowFlakeVertex2.z
	vertex3[1] = envfx_snow.gSnowFlakeVertex3.x
	vertex3[2] = envfx_snow.gSnowFlakeVertex3.y
	vertex3[3] = envfx_snow.gSnowFlakeVertex3.z

	-- The display list allocation never fails (gfx-display-lists-noop): its NULL test is dropped
	const gfxStart = Memory.alloc_display_list((envfx_snow.gSnowParticleCount * 6 + 3) * 8)

	envfx_snow.envfx_update_snowflake_count(snowMode, marioPos)

	-- Note: to and from are inverted here, so the resulting vector goes towards the camera
	envfx_snow.orbit_from_positions(camTo, camFrom, radius, pitch, yaw)

	if snowMode == EnvfxSnowH.ENVFX_SNOW_NORMAL then
		-- ensure the snow cylinder is no further than 250 units in front of the camera, and no closer than 1 unit.
		if radius[1] > 250 then
			radius[1] = S16(radius[1] - 250)
		else
			radius[1] = 1
		end

		envfx_snow.pos_from_orbit(camTo, snowCylinderPos, radius[1], pitch[1], yaw[1])
		envfx_snow.envfx_update_snow_normal(snowCylinderPos[1], snowCylinderPos[2], snowCylinderPos[3])
	elseif snowMode == EnvfxSnowH.ENVFX_SNOW_WATER then
		if radius[1] > 500 then
			radius[1] = S16(radius[1] - 500)
		else
			radius[1] = 1
		end

		envfx_snow.pos_from_orbit(camTo, snowCylinderPos, radius[1], pitch[1], yaw[1])
		envfx_snow.envfx_update_snow_water(snowCylinderPos[1], snowCylinderPos[2], snowCylinderPos[3])
	elseif snowMode == EnvfxSnowH.ENVFX_SNOW_BLIZZARD then
		if radius[1] > 250 then
			radius[1] = S16(radius[1] - 250)
		else
			radius[1] = 1
		end

		envfx_snow.pos_from_orbit(camTo, snowCylinderPos, radius[1], pitch[1], yaw[1])
		envfx_snow.envfx_update_snow_blizzard(snowCylinderPos[1], snowCylinderPos[2], snowCylinderPos[3])
	end

	envfx_snow.rotate_triangle_vertices(vertex1, vertex2, vertex3, pitch[1], yaw[1])

	if snowMode == EnvfxSnowH.ENVFX_SNOW_NORMAL or snowMode == EnvfxSnowH.ENVFX_SNOW_BLIZZARD then
		-- gSPDisplayList of the snowflake with gray edge: dropped (gfx-display-lists-noop)
	elseif snowMode == EnvfxSnowH.ENVFX_SNOW_WATER then
		-- gSPDisplayList of the snowflake with blue edge: dropped (gfx-display-lists-noop)
	end

	for i = 0, envfx_snow.gSnowParticleCount - 1, 5 do
		envfx_snow.append_snowflake_vertex_buffer(gfxStart :: { unknown }, i, vertex1, vertex2, vertex3)
		-- the five gSP1Triangle are dropped (gfx-display-lists-noop)
	end

	-- the closing gSPDisplayList and gSPEndDisplayList are dropped (gfx-display-lists-noop)
	return gfxStart :: { unknown }
end

-- from src/game/envfx_snow.c:envfx_update_particles L466-508
function envfx_snow.envfx_update_particles(mode: number, marioPos: { number }, camTo: { number }, camFrom: { number }): { unknown }?
	if GroupsIngameMenuPlus1.get_dialog_id() ~= IncludeDialogIdsH.DIALOG_NONE then
		return nil
	end

	if envfx_snow.gEnvFxMode ~= EnvfxSnowH.ENVFX_MODE_NONE and envfx_snow.gEnvFxMode ~= mode then
		mode = EnvfxSnowH.ENVFX_MODE_NONE
	end

	if mode >= EnvfxSnowH.ENVFX_BUBBLE_START then
		const bubbles = EnvfxBubbles.envfx_update_bubbles(mode, marioPos, camTo, camFrom)

		return bubbles
	end

	if envfx_snow.gEnvFxMode == EnvfxSnowH.ENVFX_MODE_NONE and envfx_snow.envfx_init_snow(mode) == 0 then
		return nil
	end

	if mode == EnvfxSnowH.ENVFX_MODE_NONE then
		envfx_snow.envfx_cleanup_snow(envfx_snow.gEnvFxBuffer)

		return nil
	elseif mode == EnvfxSnowH.ENVFX_SNOW_NORMAL then
		return envfx_snow.envfx_update_snow(1, marioPos, camFrom, camTo)
	elseif mode == EnvfxSnowH.ENVFX_SNOW_WATER then
		return envfx_snow.envfx_update_snow(2, marioPos, camFrom, camTo)
	elseif mode == EnvfxSnowH.ENVFX_SNOW_BLIZZARD then
		return envfx_snow.envfx_update_snow(3, marioPos, camFrom, camTo)
	end

	return nil
end

return envfx_snow
