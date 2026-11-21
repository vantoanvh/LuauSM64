--!strict
--!optimize 2

--[[
	Port of src/game/envfx_bubbles.c.
]]

const Audio = require("../rom/audio_recorder")
const EnvfxBubblesH = require("./envfx_bubbles_h")
const EnvfxSnowH = require("./envfx_snow_h")
const GameInit = require("./game_init")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../include/sounds_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Memory = require("./memory")
const Registry = require("../../groups/registry")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
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

-- from src/game/envfx_bubbles.luau:scratch
const Scratch = {
	envfx_update_flower_floorGeo = {} :: { SrcEngineSurfaceCollisionH.FloorGeometry? },
	envfx_set_lava_bubble_position_surface = {} :: { GroupsTypesHPlus3.Surface? },
	envfx_update_whirlpool_x = { 0 },
	envfx_update_whirlpool_y = { 0 },
	envfx_update_whirlpool_z = { 0 },
	envfx_update_bubble_particles_radius = { 0 },
	envfx_update_bubble_particles_pitch = { 0 },
	envfx_update_bubble_particles_yaw = { 0 },
	envfx_update_bubble_particles_vertex1 = { 0, 0, 0 },
	envfx_update_bubble_particles_vertex2 = { 0, 0, 0 },
	envfx_update_bubble_particles_vertex3 = { 0, 0, 0 },
}

-- from src/game/envfx_bubbles.c:data
const envfx_bubbles = {
	-- from src/game/envfx_bubbles.c:gEnvFxBubbleConfig L23-23
	gEnvFxBubbleConfig = table.create(10, 0),
	-- from src/game/envfx_bubbles.c:sGfxCursor L24-24
	sGfxCursor = nil :: { unknown }?,
	-- from src/game/envfx_bubbles.c:sBubbleParticleCount L25-25
	sBubbleParticleCount = 0,
	-- from src/game/envfx_bubbles.c:sBubbleParticleMaxCount L26-26
	sBubbleParticleMaxCount = 0,
	-- from src/game/envfx_bubbles.c:D_80330690 L28-28
	D_80330690 = 0,
	-- from src/game/envfx_bubbles.c:D_80330694 L29-29
	D_80330694 = 0,
	-- from src/game/envfx_bubbles.c:gBubbleTempVtx L32-36
	gBubbleTempVtx = {
		{ { 0, 0, 0 }, 0, { 1544, 964 }, { 0xFF, 0xFF, 0xFF, 0xFF } },
		{ { 0, 0, 0 }, 0, { 522, -568 }, { 0xFF, 0xFF, 0xFF, 0xFF } },
		{ { 0, 0, 0 }, 0, { -498, 964 }, { 0xFF, 0xFF, 0xFF, 0xFF } },
	},
}

Registry.Register("src__game__envfx_bubbles", envfx_bubbles)

-- from src/game/envfx_bubbles.c:particle_is_laterally_close L43-52
function envfx_bubbles.particle_is_laterally_close(index: number, x: number, z: number, distance: number): number
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const xPos = buffer[index + 1].xPos
	const zPos = buffer[index + 1].zPos

	-- sqr on s32 operands is an int multiplication (the ported sqr rounds to f32)
	if (xPos - x) * (xPos - x) + (zPos - z) * (zPos - z) > distance * distance then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_bubbles.c:random_flower_offset L58-67
function envfx_bubbles.random_flower_offset(): number
	local result = TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 2000.0) - 1000.0))

	if result < 0 then
		result -= 1000
	else
		result += 1000
	end

	return result
end

-- from src/game/envfx_bubbles.c:envfx_update_flower L73-98
function envfx_bubbles.envfx_update_flower(centerPos: { number })
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const globalTimer = GameInit.gGlobalTimer
	const floorGeo = Scratch.envfx_update_flower_floorGeo

	const centerX = centerPos[1]
	const centerZ = centerPos[3]

	for i = 0, envfx_bubbles.sBubbleParticleMaxCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_bubbles.particle_is_laterally_close(i, centerX, centerZ, 3000))

		if particle.isAlive == 0 then
			particle.xPos = envfx_bubbles.random_flower_offset() + centerX
			particle.zPos = envfx_bubbles.random_flower_offset() + centerZ
			particle.yPos = TruncS32(SrcEngineSurfaceCollision.find_floor_height_and_data(particle.xPos, 10000.0, particle.zPos, floorGeo))
			particle.isAlive = IncludePRUltratypesH.TRUE
			particle.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 5.0)))
		elseif bit32.band(globalTimer, 3) == 0 then
			particle.animFrame = S16(particle.animFrame + 1)

			if particle.animFrame > 5 then
				particle.animFrame = 0
			end
		end
	end
end

-- from src/game/envfx_bubbles.c:envfx_set_lava_bubble_position L109-146
function envfx_bubbles.envfx_set_lava_bubble_position(index: number, centerPos: { number })
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const particle = buffer[index + 1]
	const surface = Scratch.envfx_set_lava_bubble_position_surface

	const centerX = centerPos[1]
	const centerY = centerPos[2]
	const centerZ = centerPos[3]

	particle.xPos = TruncS32(F32(F32(F32(SrcEngineBehaviorScript.random_float() * 6000.0) - 3000.0) + centerX))
	particle.zPos = TruncS32(F32(F32(F32(SrcEngineBehaviorScript.random_float() * 6000.0) - 3000.0) + centerZ))

	if particle.xPos > 8000 then
		particle.xPos = 16000 - particle.xPos
	end
	if particle.xPos < -8000 then
		particle.xPos = -16000 - particle.xPos
	end

	if particle.zPos > 8000 then
		particle.zPos = 16000 - particle.zPos
	end
	if particle.zPos < -8000 then
		particle.zPos = -16000 - particle.zPos
	end

	const floorY = S16(TruncS32(SrcEngineSurfaceCollision.find_floor(particle.xPos, centerY + 500, particle.zPos, surface)))

	const floor = surface[1]

	if floor == nil then
		particle.yPos = SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC

		return
	end

	if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
		particle.yPos = floorY
	else
		particle.yPos = SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC
	end
end

-- from src/game/envfx_bubbles.c:envfx_update_lava L152-177
function envfx_bubbles.envfx_update_lava(centerPos: { number })
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const globalTimer = GameInit.gGlobalTimer

	for i = 0, envfx_bubbles.sBubbleParticleMaxCount - 1 do
		const particle = buffer[i + 1]

		if particle.isAlive == 0 then
			envfx_bubbles.envfx_set_lava_bubble_position(i, centerPos)
			particle.isAlive = IncludePRUltratypesH.TRUE
		elseif bit32.band(globalTimer, 1) == 0 then
			particle.animFrame = S16(particle.animFrame + 1)

			if particle.animFrame > 8 then
				particle.isAlive = IncludePRUltratypesH.FALSE
				particle.animFrame = 0
			end
		end
	end

	const chance = S8(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 16.0)))

	if chance == 8 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_QUIET_BUBBLE2, Audio.gGlobalSoundSource)
	end
end

-- from src/game/envfx_bubbles.c:envfx_rotate_around_whirlpool L183-199
function envfx_bubbles.envfx_rotate_around_whirlpool(x: { number }, y: { number }, z: { number })
	const config = envfx_bubbles.gEnvFxBubbleConfig

	const vecX = x[1] - config[EnvfxBubblesH.ENVFX_STATE_DEST_X + 1]
	const vecY = y[1] - config[EnvfxBubblesH.ENVFX_STATE_DEST_Y + 1]
	const vecZ = z[1] - config[EnvfxBubblesH.ENVFX_STATE_DEST_Z + 1]
	const cosPitch = SrcEngineMathUtilH.coss(config[EnvfxBubblesH.ENVFX_STATE_PITCH + 1])
	const sinPitch = SrcEngineMathUtilH.sins(config[EnvfxBubblesH.ENVFX_STATE_PITCH + 1])
	const cosMYaw = SrcEngineMathUtilH.coss(-config[EnvfxBubblesH.ENVFX_STATE_YAW + 1])
	const sinMYaw = SrcEngineMathUtilH.sins(-config[EnvfxBubblesH.ENVFX_STATE_YAW + 1])

	const rotatedX = F32(F32(F32(vecX * cosMYaw) - F32(F32(sinMYaw * cosPitch) * vecY)) - F32(F32(sinPitch * sinMYaw) * vecZ))
	const rotatedY = F32(F32(F32(vecX * sinMYaw) + F32(F32(cosPitch * cosMYaw) * vecY)) - F32(F32(sinPitch * cosMYaw) * vecZ))
	const rotatedZ = F32(F32(vecY * sinPitch) + F32(cosPitch * vecZ))

	x[1] = config[EnvfxBubblesH.ENVFX_STATE_DEST_X + 1] + TruncS32(rotatedX)
	y[1] = config[EnvfxBubblesH.ENVFX_STATE_DEST_Y + 1] + TruncS32(rotatedY)
	z[1] = config[EnvfxBubblesH.ENVFX_STATE_DEST_Z + 1] + TruncS32(rotatedZ)
end

-- from src/game/envfx_bubbles.c:envfx_is_whirlpool_bubble_alive L205-217
function envfx_bubbles.envfx_is_whirlpool_bubble_alive(index: number): number
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer

	if buffer[index + 1].bubbleY < envfx_bubbles.gEnvFxBubbleConfig[EnvfxBubblesH.ENVFX_STATE_DEST_Y + 1] - 100 then
		return IncludePRUltratypesH.FALSE
	end

	if buffer[index + 1].angleAndDist[2] < 10 then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_bubbles.c:envfx_update_whirlpool L223-262
function envfx_bubbles.envfx_update_whirlpool()
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const config = envfx_bubbles.gEnvFxBubbleConfig
	const x = Scratch.envfx_update_whirlpool_x
	const y = Scratch.envfx_update_whirlpool_y
	const z = Scratch.envfx_update_whirlpool_z

	for i = 0, envfx_bubbles.sBubbleParticleMaxCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_bubbles.envfx_is_whirlpool_bubble_alive(i))

		if particle.isAlive == 0 then
			particle.angleAndDist[2] = TruncS32(F32(SrcEngineBehaviorScript.random_float() * 1000.0))
			particle.angleAndDist[1] = TruncS32(F32(SrcEngineBehaviorScript.random_float() * 65536.0))
			particle.xPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1] + F32(SrcEngineMathUtilH.sins(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.zPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1] + F32(SrcEngineMathUtilH.coss(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.bubbleY = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_Y + 1] + F32(F32(SrcEngineBehaviorScript.random_float() * 100.0) - 50.0)))
			particle.yPos = particle.bubbleY
			particle.unusedBubbleVar = 0
			particle.isAlive = IncludePRUltratypesH.TRUE

			x[1] = particle.xPos
			y[1] = particle.yPos
			z[1] = particle.zPos
			envfx_bubbles.envfx_rotate_around_whirlpool(x, y, z)
			particle.xPos = x[1]
			particle.yPos = y[1]
			particle.zPos = z[1]
		else
			particle.angleAndDist[2] -= 40
			particle.angleAndDist[1] += S16(3000 - particle.angleAndDist[2] * 2) + 0x400
			particle.xPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1] + F32(SrcEngineMathUtilH.sins(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.zPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1] + F32(SrcEngineMathUtilH.coss(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.bubbleY -= 40 - TruncS32(S16(particle.angleAndDist[2]) / 100)
			particle.yPos = particle.bubbleY

			x[1] = particle.xPos
			y[1] = particle.yPos
			z[1] = particle.zPos
			envfx_bubbles.envfx_rotate_around_whirlpool(x, y, z)
			particle.xPos = x[1]
			particle.yPos = y[1]
			particle.zPos = z[1]
		end
	end
end

-- from src/game/envfx_bubbles.c:envfx_is_jestream_bubble_alive L268-278
function envfx_bubbles.envfx_is_jestream_bubble_alive(index: number): number
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const config = envfx_bubbles.gEnvFxBubbleConfig

	if envfx_bubbles.particle_is_laterally_close(index, config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1], config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1], 1000) == 0
		or config[EnvfxBubblesH.ENVFX_STATE_SRC_Y + 1] + 1500 < buffer[index + 1].yPos then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_bubbles.c:envfx_update_jetstream L284-307
function envfx_bubbles.envfx_update_jetstream()
	const buffer: { EnvfxSnowH.EnvFxParticle } = Registry.Members.src__game__envfx_snow.gEnvFxBuffer
	const config = envfx_bubbles.gEnvFxBubbleConfig

	for i = 0, envfx_bubbles.sBubbleParticleMaxCount - 1 do
		const particle = buffer[i + 1]

		particle.isAlive = S8(envfx_bubbles.envfx_is_jestream_bubble_alive(i))

		if particle.isAlive == 0 then
			particle.angleAndDist[2] = TruncS32(F32(SrcEngineBehaviorScript.random_float() * 300.0))
			particle.angleAndDist[1] = SrcEngineBehaviorScript.random_u16()
			particle.xPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1] + F32(SrcEngineMathUtilH.sins(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.zPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1] + F32(SrcEngineMathUtilH.coss(particle.angleAndDist[1]) * particle.angleAndDist[2])))
			particle.yPos = TruncS32(F32(config[EnvfxBubblesH.ENVFX_STATE_SRC_Y + 1] + F32(F32(SrcEngineBehaviorScript.random_float() * 400.0) - 200.0)))
		else
			particle.angleAndDist[2] += 10
			particle.xPos = TruncS32(F32(F32(particle.xPos) + F32(SrcEngineMathUtilH.sins(particle.angleAndDist[1]) * 10.0)))
			particle.zPos = TruncS32(F32(F32(particle.zPos) + F32(SrcEngineMathUtilH.coss(particle.angleAndDist[1]) * 10.0)))
			particle.yPos -= TruncS32(particle.angleAndDist[2] / 30) - 50
		end
	end
end

-- from src/game/envfx_bubbles.c:envfx_init_bubble L314-359
function envfx_bubbles.envfx_init_bubble(mode: number): number
	if mode == EnvfxSnowH.ENVFX_MODE_NONE then
		return IncludePRUltratypesH.FALSE
	elseif mode == EnvfxSnowH.ENVFX_FLOWERS then
		envfx_bubbles.sBubbleParticleCount = 30
		envfx_bubbles.sBubbleParticleMaxCount = 30
	elseif mode == EnvfxSnowH.ENVFX_LAVA_BUBBLES then
		envfx_bubbles.sBubbleParticleCount = 15
		envfx_bubbles.sBubbleParticleMaxCount = 15
	elseif mode == EnvfxSnowH.ENVFX_WHIRLPOOL_BUBBLES then
		envfx_bubbles.sBubbleParticleCount = 60
	elseif mode == EnvfxSnowH.ENVFX_JETSTREAM_BUBBLES then
		envfx_bubbles.sBubbleParticleCount = 60
	end

	-- mem_pool_alloc of the effects pool and its NULL test: the buffer is a table of zero filled particles (envfx-particle-buffer-table)
	const particles: { EnvfxSnowH.EnvFxParticle } = {}

	for index = 1, envfx_bubbles.sBubbleParticleCount do
		particles[index] = EnvfxSnowH.new_EnvFxParticle()
	end

	Registry.Members.src__game__envfx_snow.gEnvFxBuffer = particles

	for index = 1, 10 do
		envfx_bubbles.gEnvFxBubbleConfig[index] = 0
	end

	if mode == EnvfxSnowH.ENVFX_LAVA_BUBBLES then
		for i = 0, envfx_bubbles.sBubbleParticleCount - 1 do
			particles[i + 1].animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 7.0)))
		end
	end

	Registry.Members.src__game__envfx_snow.gEnvFxMode = S8(mode)

	return IncludePRUltratypesH.TRUE
end

-- from src/game/envfx_bubbles.c:envfx_bubbles_update_switch L366-396
function envfx_bubbles.envfx_bubbles_update_switch(mode: number, camTo: { number }, vertex1: { number }, vertex2: { number }, vertex3: { number })
	if mode == EnvfxSnowH.ENVFX_FLOWERS then
		envfx_bubbles.envfx_update_flower(camTo)
		vertex1[1] = 50
		vertex1[2] = 0
		vertex1[3] = 0
		vertex2[1] = 0
		vertex2[2] = 75
		vertex2[3] = 0
		vertex3[1] = -50
		vertex3[2] = 0
		vertex3[3] = 0
	elseif mode == EnvfxSnowH.ENVFX_LAVA_BUBBLES then
		envfx_bubbles.envfx_update_lava(camTo)
		vertex1[1] = 100
		vertex1[2] = 0
		vertex1[3] = 0
		vertex2[1] = 0
		vertex2[2] = 150
		vertex2[3] = 0
		vertex3[1] = -100
		vertex3[2] = 0
		vertex3[3] = 0
	elseif mode == EnvfxSnowH.ENVFX_WHIRLPOOL_BUBBLES then
		envfx_bubbles.envfx_update_whirlpool()
		vertex1[1] = 40
		vertex1[2] = 0
		vertex1[3] = 0
		vertex2[1] = 0
		vertex2[2] = 60
		vertex2[3] = 0
		vertex3[1] = -40
		vertex3[2] = 0
		vertex3[3] = 0
	elseif mode == EnvfxSnowH.ENVFX_JETSTREAM_BUBBLES then
		envfx_bubbles.envfx_update_jetstream()
		vertex1[1] = 40
		vertex1[2] = 0
		vertex1[3] = 0
		vertex2[1] = 0
		vertex2[2] = 60
		vertex2[3] = 0
		vertex3[1] = -40
		vertex3[2] = 0
		vertex3[3] = 0
	end
end

-- from src/game/envfx_bubbles.c:append_bubble_vertex_buffer L403-430
function envfx_bubbles.append_bubble_vertex_buffer(gfx: { unknown }, index: number, vertex1: { number }, vertex2: { number }, vertex3: { number }, template: unknown)
	-- gfx-display-lists-noop: only fills a display list vertex buffer (alloc_display_list) and emits gSPVertex
end

-- from src/game/envfx_bubbles.c:envfx_set_bubble_texture L437-461
function envfx_bubbles.envfx_set_bubble_texture(mode: number, index: number)
	-- gfx-display-lists-noop: only emits gDPSetTextureImage and gSPDisplayList into sGfxCursor
end

-- from src/game/envfx_bubbles.c:envfx_update_bubble_particles L467-504
function envfx_bubbles.envfx_update_bubble_particles(mode: number, marioPos: { number }, camFrom: { number }, camTo: { number }): { unknown }?
	const radius = Scratch.envfx_update_bubble_particles_radius
	const pitch = Scratch.envfx_update_bubble_particles_pitch
	const yaw = Scratch.envfx_update_bubble_particles_yaw
	const vertex1 = Scratch.envfx_update_bubble_particles_vertex1
	const vertex2 = Scratch.envfx_update_bubble_particles_vertex2
	const vertex3 = Scratch.envfx_update_bubble_particles_vertex3

	-- The display list allocation never fails (gfx-display-lists-noop): its NULL test is dropped
	const gfxStart = Memory.alloc_display_list((TruncS32(envfx_bubbles.sBubbleParticleMaxCount / 5) * 10 + envfx_bubbles.sBubbleParticleMaxCount + 3) * 8) :: { unknown }

	envfx_bubbles.sGfxCursor = gfxStart

	Registry.Members.src__game__envfx_snow.orbit_from_positions(camTo, camFrom, radius, pitch, yaw)
	envfx_bubbles.envfx_bubbles_update_switch(mode, camTo, vertex1, vertex2, vertex3)
	Registry.Members.src__game__envfx_snow.rotate_triangle_vertices(vertex1, vertex2, vertex3, pitch[1], yaw[1])

	-- gSPDisplayList is dropped (gfx-display-lists-noop)

	for i = 0, envfx_bubbles.sBubbleParticleMaxCount - 1, 5 do
		-- gDPPipeSync is dropped (gfx-display-lists-noop)
		envfx_bubbles.envfx_set_bubble_texture(mode, i)
		envfx_bubbles.append_bubble_vertex_buffer(gfxStart, i, vertex1, vertex2, vertex3, envfx_bubbles.gBubbleTempVtx)
		-- the five gSP1Triangle are dropped (gfx-display-lists-noop)
	end

	-- the closing gSPDisplayList and gSPEndDisplayList are dropped (gfx-display-lists-noop)
	return gfxStart
end

-- from src/game/envfx_bubbles.c:envfx_set_max_bubble_particles L510-519
function envfx_bubbles.envfx_set_max_bubble_particles(mode: number)
	if mode == EnvfxSnowH.ENVFX_WHIRLPOOL_BUBBLES then
		envfx_bubbles.sBubbleParticleMaxCount = envfx_bubbles.gEnvFxBubbleConfig[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1]
	elseif mode == EnvfxSnowH.ENVFX_JETSTREAM_BUBBLES then
		envfx_bubbles.sBubbleParticleMaxCount = envfx_bubbles.gEnvFxBubbleConfig[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1]
	end
end

-- from src/game/envfx_bubbles.c:envfx_update_bubbles L526-561
function envfx_bubbles.envfx_update_bubbles(mode: number, marioPos: { number }, camTo: { number }, camFrom: { number }): { unknown }?
	const envFxMode: number = Registry.Members.src__game__envfx_snow.gEnvFxMode

	if envFxMode == EnvfxSnowH.ENVFX_MODE_NONE and envfx_bubbles.envfx_init_bubble(mode) == 0 then
		return nil
	end

	envfx_bubbles.envfx_set_max_bubble_particles(mode)

	if envfx_bubbles.sBubbleParticleMaxCount == 0 then
		return nil
	end

	if mode == EnvfxSnowH.ENVFX_FLOWERS then
		return envfx_bubbles.envfx_update_bubble_particles(EnvfxSnowH.ENVFX_FLOWERS, marioPos, camFrom, camTo)
	elseif mode == EnvfxSnowH.ENVFX_LAVA_BUBBLES then
		return envfx_bubbles.envfx_update_bubble_particles(EnvfxSnowH.ENVFX_LAVA_BUBBLES, marioPos, camFrom, camTo)
	elseif mode == EnvfxSnowH.ENVFX_WHIRLPOOL_BUBBLES then
		return envfx_bubbles.envfx_update_bubble_particles(EnvfxSnowH.ENVFX_WHIRLPOOL_BUBBLES, marioPos, camFrom, camTo)
	elseif mode == EnvfxSnowH.ENVFX_JETSTREAM_BUBBLES then
		return envfx_bubbles.envfx_update_bubble_particles(EnvfxSnowH.ENVFX_JETSTREAM_BUBBLES, marioPos, camFrom, camTo)
	end

	return nil
end

return envfx_bubbles
