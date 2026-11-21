--!strict
--!optimize 2

--[[
	Port of src/game/mario.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const Rom = require("../rom/rom")

const IncludeSoundsH = require("../../include/sounds_h")

const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePROsH = require("../../include/PR/os_h")
const Camera = require("./camera")
const Interaction = require("./interaction")
const SoundInit = require("./sound_init")
const InteractionH = require("./interaction_h")
const LevelUpdate = require("./level_update")
const LevelUpdateH = require("./level_update_h")
const Area = require("./area")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const BehaviorsWindInc = require("./behaviors/wind_inc")
const GameInit = require("./game_init")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludeModelIdsH = require("../../include/model_ids_h")
const Main = require("./main")
const MarioActionsCutscene = require("./mario_actions_cutscene")
const MarioMisc = require("./mario_misc")
const ObjectHelpers = require("./object_helpers")
const ObjectListProcessor = require("./object_list_processor")
const SaveFile = require("./save_file")
const SaveFileH = require("./save_file_h")
const SrcEngineGraphNode = require("../engine/graph_node")
const Memory = require("./memory")
const IncludeMacrosH = require("../../include/macros_h")
const MemoryH = require("./memory_h")

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/mario.c:data
const mario = {
	-- from src/game/mario.c:unused80339F10 L36-36
	unused80339F10 = 0,
	-- from src/game/mario.c:unused80339F1C L37-37
	unused80339F1C = buffer.create(20),
	-- from src/game/mario.c:sTerrainSounds L435-452
	sTerrainSounds = {
		{
			IncludeSoundsH.SOUND_TERRAIN_DEFAULT,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
			IncludeSoundsH.SOUND_TERRAIN_DEFAULT,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_SNOW,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
			IncludeSoundsH.SOUND_TERRAIN_SNOW,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_SAND,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_SAND,
			IncludeSoundsH.SOUND_TERRAIN_SAND,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_SPOOKY,
			IncludeSoundsH.SOUND_TERRAIN_SPOOKY,
			IncludeSoundsH.SOUND_TERRAIN_SPOOKY,
			IncludeSoundsH.SOUND_TERRAIN_SPOOKY,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_DEFAULT,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_GRASS,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
		},
		{
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_STONE,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
			IncludeSoundsH.SOUND_TERRAIN_ICE,
		},
	},
	-- from src/game/mario.c:sSquishScaleOverTime L1199-1200
	sSquishScaleOverTime = { 0x46, 0x32, 0x32, 0x3C, 0x46, 0x50, 0x50, 0x3C, 0x28, 0x14, 0x14, 0x1E, 0x32, 0x3C, 0x3C, 0x28 },
	-- from src/game/mario.c:sCapFlickerFrames L1562-1562
	sCapFlickerFrames = { Bits = 64, Unsigned = false, Words = { 0x49255555, 0x44444492 } },
}

-- from src/game/mario.c:resolve_and_return_wall_collisions:collisionData L521-542
const CollisionData = {
	x = 0,
	y = 0,
	z = 0,
	offsetY = 0,
	radius = 0,
	filler = buffer.create(2),
	numWalls = 0,
	walls = {},
} :: SrcEngineSurfaceCollisionH.WallCollisionData
const Floor: { GroupsTypesHPlus3Types.Surface? } = {}
const Translation = { 0, 0, 0 }
const CapPos = { 0, 0, 0 }
const AnimIndex = { 0 }
const Ceil: { GroupsTypesHPlus3Types.Surface? } = {}
const WallX = { 0 }
const WallY = { 0 }
const WallZ = { 0 }

Registry.Register("src__game__mario", mario)

-- from src/game/mario.c:is_anim_at_end L46-50
function mario.is_anim_at_end(m: GroupsTypesHPlus3Types.MarioState): number
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object
	const animInfo = o.header.gfx.animInfo
	const curAnim = animInfo.curAnim :: number

	return if animInfo.animFrame + 1 == Rom.ReadS16(curAnim + 8) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:is_anim_past_end L55-59
function mario.is_anim_past_end(m: GroupsTypesHPlus3Types.MarioState): number
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object
	const animInfo = o.header.gfx.animInfo
	const curAnim = animInfo.curAnim :: number

	return if animInfo.animFrame >= Rom.ReadS16(curAnim + 8) - 2 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:set_mario_animation L64-91
function mario.set_mario_animation(m: GroupsTypesHPlus3Types.MarioState, targetAnimID: number): number
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object
	const targetAnim = (m.animList :: MemoryH.DmaHandlerList).bufTarget :: number

	if Memory.load_patchable_table(m.animList :: MemoryH.DmaHandlerList, targetAnimID) ~= 0 then
		Rom.WriteU32(targetAnim + 12, IncludeMacrosH.VIRTUAL_TO_PHYSICAL(targetAnim + Rom.ReadU32(targetAnim + 12)))
		Rom.WriteU32(targetAnim + 16, IncludeMacrosH.VIRTUAL_TO_PHYSICAL(targetAnim + Rom.ReadU32(targetAnim + 16)))
	end

	if o.header.gfx.animInfo.animID ~= targetAnimID then
		o.header.gfx.animInfo.animID = S16(targetAnimID)
		o.header.gfx.animInfo.curAnim = targetAnim
		o.header.gfx.animInfo.animAccel = 0
		o.header.gfx.animInfo.animYTrans = m.unkB0

		if bit32.btest(Rom.ReadS16(targetAnim), GroupsTypesHPlus3.ANIM_FLAG_2) then
			o.header.gfx.animInfo.animFrame = Rom.ReadS16(targetAnim + 4)
		else
			if bit32.btest(Rom.ReadS16(targetAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
				o.header.gfx.animInfo.animFrame = S16(Rom.ReadS16(targetAnim + 4) + 1)
			else
				o.header.gfx.animInfo.animFrame = S16(Rom.ReadS16(targetAnim + 4) - 1)
			end
		end
	end

	return o.header.gfx.animInfo.animFrame
end

-- from src/game/mario.c:set_mario_anim_with_accel L97-127
function mario.set_mario_anim_with_accel(m: GroupsTypesHPlus3Types.MarioState, targetAnimID: number, accel: number): number
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object
	const targetAnim = (m.animList :: MemoryH.DmaHandlerList).bufTarget :: number

	if Memory.load_patchable_table(m.animList :: MemoryH.DmaHandlerList, targetAnimID) ~= 0 then
		Rom.WriteU32(targetAnim + 12, IncludeMacrosH.VIRTUAL_TO_PHYSICAL(targetAnim + Rom.ReadU32(targetAnim + 12)))
		Rom.WriteU32(targetAnim + 16, IncludeMacrosH.VIRTUAL_TO_PHYSICAL(targetAnim + Rom.ReadU32(targetAnim + 16)))
	end

	if o.header.gfx.animInfo.animID ~= targetAnimID then
		o.header.gfx.animInfo.animID = S16(targetAnimID)
		o.header.gfx.animInfo.curAnim = targetAnim
		o.header.gfx.animInfo.animYTrans = m.unkB0

		if bit32.btest(Rom.ReadS16(targetAnim), GroupsTypesHPlus3.ANIM_FLAG_2) then
			o.header.gfx.animInfo.animFrameAccelAssist = S32(bit32.lshift(Rom.ReadS16(targetAnim + 4), 0x10))
		else
			if bit32.btest(Rom.ReadS16(targetAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
				o.header.gfx.animInfo.animFrameAccelAssist = S32(bit32.lshift(Rom.ReadS16(targetAnim + 4), 0x10) + accel)
			else
				o.header.gfx.animInfo.animFrameAccelAssist = S32(bit32.lshift(Rom.ReadS16(targetAnim + 4), 0x10) - accel)
			end
		end

		o.header.gfx.animInfo.animFrame = S16(bit32.arshift(o.header.gfx.animInfo.animFrameAccelAssist, 0x10))
	end

	o.header.gfx.animInfo.animAccel = S32(accel)

	return o.header.gfx.animInfo.animFrame
end

-- from src/game/mario.c:set_anim_to_frame L132-149
function mario.set_anim_to_frame(m: GroupsTypesHPlus3Types.MarioState, animFrame: number)
	animFrame = S16(TruncS32(animFrame))
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object
	const animInfo = marioObj.header.gfx.animInfo
	const curAnim = animInfo.curAnim :: number

	if animInfo.animAccel ~= 0 then
		if bit32.btest(Rom.ReadS16(curAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
			animInfo.animFrameAccelAssist = S32(bit32.lshift(animFrame, 0x10) + animInfo.animAccel)
		else
			animInfo.animFrameAccelAssist = S32(bit32.lshift(animFrame, 0x10) - animInfo.animAccel)
		end
	else
		if bit32.btest(Rom.ReadS16(curAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
			animInfo.animFrame = S16(animFrame + 1)
		else
			animInfo.animFrame = S16(animFrame - 1)
		end
	end
end

-- from src/game/mario.c:is_anim_past_frame L151-176
function mario.is_anim_past_frame(m: GroupsTypesHPlus3Types.MarioState, animFrame: number): number
	animFrame = S16(TruncS32(animFrame))
	local isPastFrame: number
	const acceleratedFrame = S32(bit32.lshift(animFrame, 0x10))
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object
	const animInfo = marioObj.header.gfx.animInfo
	const curAnim = animInfo.curAnim :: number

	if animInfo.animAccel ~= 0 then
		if bit32.btest(Rom.ReadS16(curAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
			isPastFrame = if animInfo.animFrameAccelAssist > acceleratedFrame and acceleratedFrame >= S32(animInfo.animFrameAccelAssist - animInfo.animAccel) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
		else
			isPastFrame = if animInfo.animFrameAccelAssist < acceleratedFrame and acceleratedFrame <= S32(animInfo.animFrameAccelAssist + animInfo.animAccel) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
		end
	else
		if bit32.btest(Rom.ReadS16(curAnim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
			isPastFrame = if animInfo.animFrame == animFrame + 1 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
		else
			isPastFrame = if animInfo.animFrame + 1 == animFrame then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
		end
	end

	return isPastFrame
end

-- from src/game/mario.c:find_mario_anim_flags_and_translation L182-202
function mario.find_mario_anim_flags_and_translation(obj: GroupsTypesHPlus3Types.Object, yaw: number, translation: { number }): number
	const curAnim = obj.header.gfx.animInfo.curAnim :: number
	const animFrame = SrcEngineGraphNode.geo_update_animation_frame(obj.header.gfx.animInfo, nil)

	AnimIndex[1] = Memory.segmented_to_virtual(Rom.ReadU32(curAnim + 16))

	const animValues = Memory.segmented_to_virtual(Rom.ReadU32(curAnim + 12))
	const s = SrcEngineMathUtilH.sins(yaw)
	const c = SrcEngineMathUtilH.coss(yaw)

	const dx = F32(Rom.ReadS16(animValues + 2 * SrcEngineGraphNode.retrieve_animation_index(animFrame, AnimIndex)) / 4)

	translation[2] = S16(TruncS32(F32(Rom.ReadS16(animValues + 2 * SrcEngineGraphNode.retrieve_animation_index(animFrame, AnimIndex)) / 4)))

	const dz = F32(Rom.ReadS16(animValues + 2 * SrcEngineGraphNode.retrieve_animation_index(animFrame, AnimIndex)) / 4)

	translation[1] = S16(TruncS32(F32(F32(dx * c) + F32(dz * s))))
	translation[3] = S16(TruncS32(F32(F32(-dx * s) + F32(dz * c))))

	return Rom.ReadS16(curAnim)
end

-- from src/game/mario.c:update_mario_pos_for_anim L207-221
function mario.update_mario_pos_for_anim(m: GroupsTypesHPlus3Types.MarioState)
	const flags = mario.find_mario_anim_flags_and_translation(m.marioObj :: GroupsTypesHPlus3Types.Object, m.faceAngle[2], Translation)

	if bit32.btest(flags, bit32.bor(GroupsTypesHPlus3.ANIM_FLAG_HOR_TRANS, GroupsTypesHPlus3.ANIM_FLAG_6)) then
		m.pos[1] = F32(m.pos[1] + Translation[1])
		m.pos[3] = F32(m.pos[3] + Translation[3])
	end

	if bit32.btest(flags, bit32.bor(GroupsTypesHPlus3.ANIM_FLAG_VERT_TRANS, GroupsTypesHPlus3.ANIM_FLAG_6)) then
		m.pos[2] = F32(m.pos[2] + Translation[2])
	end
end

-- from src/game/mario.c:return_mario_anim_y_translation L226-231
function mario.return_mario_anim_y_translation(m: GroupsTypesHPlus3Types.MarioState): number
	mario.find_mario_anim_flags_and_translation(m.marioObj :: GroupsTypesHPlus3Types.Object, 0, Translation)

	return Translation[2]
end

-- from src/game/mario.c:play_sound_if_no_flag L240-245
function mario.play_sound_if_no_flag(m: GroupsTypesHPlus3Types.MarioState, soundBits: number, flags: number)
	if not bit32.btest(m.flags, flags) then
		Audio.play_sound(soundBits, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		m.flags = bit32.bor(m.flags, flags)
	end
end

-- from src/game/mario.c:play_mario_jump_sound L250-265
function mario.play_mario_jump_sound(m: GroupsTypesHPlus3Types.MarioState)
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED) then
		-- gAudioRandom is 0 in the port (native stub value): (gAudioRandom % 5 << 16) and (gAudioRandom % 3 << 16) are 0
		if m.action == IncludeSm64H.ACT_TRIPLE_JUMP then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAHOO_WAHA_YIPPEE, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAH_WAH_HOO, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
		end

		m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end
end

-- from src/game/mario.c:adjust_sound_for_speed L270-273
function mario.adjust_sound_for_speed(m: GroupsTypesHPlus3Types.MarioState)
	const absForwardVel = TruncS32(if m.forwardVel > 0 then m.forwardVel else -m.forwardVel)

	Audio.set_sound_moving_speed(IncludeSoundsH.SOUND_BANK_MOVING, if absForwardVel > 100 then 100 else absForwardVel)
end

-- from src/game/mario.c:play_sound_and_spawn_particles L278-299
function mario.play_sound_and_spawn_particles(m: GroupsTypesHPlus3Types.MarioState, soundBits: number, waveParticleType: number)
	if m.terrainSoundAddend == bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_WATER, 16) then
		if waveParticleType ~= 0 then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_SHALLOW_WATER_SPLASH)
		else
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_SHALLOW_WATER_WAVE)
		end
	else
		if m.terrainSoundAddend == bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_SAND, 16) then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_DIRT)
		elseif m.terrainSoundAddend == bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_SNOW, 16) then
			m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_SNOW)
		end
	end

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) or soundBits == IncludeSoundsH.SOUND_ACTION_UNSTUCK_FROM_GROUND or soundBits == IncludeSoundsH.SOUND_MARIO_PUNCH_HOO then
		Audio.play_sound(soundBits, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	else
		Audio.play_sound(m.terrainSoundAddend + soundBits, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.cameraToObject)
	end
end

-- from src/game/mario.c:play_mario_action_sound L304-309
function mario.play_mario_action_sound(m: GroupsTypesHPlus3Types.MarioState, soundBits: number, waveParticleType: number)
	if not bit32.btest(m.flags, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED) then
		mario.play_sound_and_spawn_particles(m, soundBits, waveParticleType)
		m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	end
end

-- from src/game/mario.c:play_mario_landing_sound L314-317
function mario.play_mario_landing_sound(m: GroupsTypesHPlus3Types.MarioState, soundBits: number)
	mario.play_sound_and_spawn_particles(m, if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_LANDING else soundBits, 1)
end

-- from src/game/mario.c:play_mario_landing_sound_once L324-327
function mario.play_mario_landing_sound_once(m: GroupsTypesHPlus3Types.MarioState, soundBits: number)
	mario.play_mario_action_sound(m, if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_LANDING else soundBits, 1)
end

-- from src/game/mario.c:play_mario_heavy_landing_sound L332-335
function mario.play_mario_heavy_landing_sound(m: GroupsTypesHPlus3Types.MarioState, soundBits: number)
	mario.play_sound_and_spawn_particles(m, if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_HEAVY_LANDING else soundBits, 1)
end

-- from src/game/mario.c:play_mario_heavy_landing_sound_once L342-345
function mario.play_mario_heavy_landing_sound_once(m: GroupsTypesHPlus3Types.MarioState, soundBits: number)
	mario.play_mario_action_sound(m, if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_HEAVY_LANDING else soundBits, 1)
end

-- from src/game/mario.c:play_mario_sound L350-365
function mario.play_mario_sound(m: GroupsTypesHPlus3Types.MarioState, actionSound: number, marioSound: number)
	if actionSound == IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP then
		mario.play_mario_action_sound(m, if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_JUMP else IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 1)
	else
		mario.play_sound_if_no_flag(m, actionSound, IncludeSm64H.MARIO_ACTION_SOUND_PLAYED)
	end

	if marioSound == 0 then
		mario.play_mario_jump_sound(m)
	end

	if marioSound ~= -1 then
		mario.play_sound_if_no_flag(m, marioSound, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)
	end
end

-- from src/game/mario.c:mario_set_forward_vel L374-382
function mario.mario_set_forward_vel(m: GroupsTypesHPlus3Types.MarioState, forwardVel: number)
	forwardVel = F32(forwardVel)
	m.forwardVel = forwardVel

	m.slideVelX = F32(SrcEngineMathUtilH.sins(m.faceAngle[2]) * m.forwardVel)
	m.slideVelZ = F32(SrcEngineMathUtilH.coss(m.faceAngle[2]) * m.forwardVel)

	m.vel[1] = m.slideVelX
	m.vel[3] = m.slideVelZ
end

-- from src/game/mario.c:mario_get_floor_class L387-432
function mario.mario_get_floor_class(m: GroupsTypesHPlus3Types.MarioState): number
	const area = m.area :: GroupsTypesHPlus3Types.Area
	local floorClass: number

	-- The slide terrain type defaults to slide slipperiness.
	-- This doesn't matter too much since normally the slide terrain
	-- is checked for anyways.
	if bit32.band(area.terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SLIDE then
		floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY
	else
		floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_DEFAULT
	end

	if m.floor ~= nil then
		const floorType = m.floor.type_

		if floorType == IncludeSurfaceTerrainsH.SURFACE_NOT_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_NOT_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_SWITCH then
			floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_NOT_SLIPPERY
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_SLIPPERY then
			floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_SLIPPERY
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_ICE or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY_73 or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY_74 or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_VERY_SLIPPERY then
			floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY
		end
	end

	-- Crawling allows Mario to not slide on certain steeper surfaces.
	if m.action == IncludeSm64H.ACT_CRAWLING and (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y > 0.5 and floorClass == IncludeSurfaceTerrainsH.SURFACE_CLASS_DEFAULT then
		floorClass = IncludeSurfaceTerrainsH.SURFACE_CLASS_NOT_SLIPPERY
	end

	return floorClass
end

-- from src/game/mario.c:mario_get_terrain_sound_addend L459-516
function mario.mario_get_terrain_sound_addend(m: GroupsTypesHPlus3Types.MarioState): number
	const area = m.area :: GroupsTypesHPlus3Types.Area
	const terrainType = S16(bit32.band(area.terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK))
	local ret = S32(bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_DEFAULT, 16))

	if m.floor ~= nil then
		const floorType = m.floor.type_

		if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_LLL and m.floorHeight < F32(m.waterLevel - 10) then
			-- Water terrain sound, excluding LLL since it uses water in the volcano.
			ret = S32(bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_WATER, 16))
		elseif IncludeSurfaceTerrainsH.SURFACE_IS_QUICKSAND(floorType) ~= 0 then
			ret = S32(bit32.lshift(IncludeSoundsH.SOUND_TERRAIN_SAND, 16))
		else
			local floorSoundType: number

			if floorType == IncludeSurfaceTerrainsH.SURFACE_NOT_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_NOT_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_SWITCH then
				floorSoundType = 1
			elseif floorType == IncludeSurfaceTerrainsH.SURFACE_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_SLIPPERY then
				floorSoundType = 2
			elseif floorType == IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_ICE or floorType == IncludeSurfaceTerrainsH.SURFACE_HARD_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY_73 or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY_74 or floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_VERY_SLIPPERY or floorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_VERY_SLIPPERY then
				floorSoundType = 3
			elseif floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_DEFAULT then
				floorSoundType = 4
			elseif floorType == IncludeSurfaceTerrainsH.SURFACE_NOISE_SLIPPERY then
				floorSoundType = 5
			else
				floorSoundType = 0
			end

			ret = S32(bit32.lshift(mario.sTerrainSounds[terrainType + 1][floorSoundType + 1], 16))
		end
	end

	return ret
end

-- from src/game/mario.c:resolve_and_return_wall_collisions L521-542
function mario.resolve_and_return_wall_collisions(pos: { number }, offset: number, radius: number): GroupsTypesHPlus3Types.Surface?
	offset = F32(offset)
	radius = F32(radius)
	local wall: GroupsTypesHPlus3Types.Surface? = nil

	CollisionData.x = pos[1]
	CollisionData.y = pos[2]
	CollisionData.z = pos[3]
	CollisionData.radius = radius
	CollisionData.offsetY = offset

	if SrcEngineSurfaceCollision.find_wall_collisions(CollisionData) ~= 0 then
		wall = CollisionData.walls[CollisionData.numWalls]
	end

	pos[1] = CollisionData.x
	pos[2] = CollisionData.y
	pos[3] = CollisionData.z

	-- This only returns the most recent wall and can also return NULL
	-- there are no wall collisions.
	return wall
end

-- from src/game/mario.c:vec3f_find_ceil L547-551
function mario.vec3f_find_ceil(pos: { number }, height: number, ceil: { GroupsTypesHPlus3Types.Surface? }): number
	height = F32(height)
	return SrcEngineSurfaceCollision.find_ceil(pos[1], F32(height + 80.0), pos[3], ceil)
end

-- from src/game/mario.c:mario_facing_downhill L556-568
function mario.mario_facing_downhill(m: GroupsTypesHPlus3Types.MarioState, turnYaw: number): number
	local faceAngleYaw = m.faceAngle[2]

	-- This is never used in practice, as turnYaw is
	-- always passed as zero.
	if turnYaw ~= 0 and m.forwardVel < 0.0 then
		faceAngleYaw = S16(faceAngleYaw + 0x8000)
	end

	faceAngleYaw = S16(m.floorAngle - faceAngleYaw)

	return if -0x4000 < faceAngleYaw and faceAngleYaw < 0x4000 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:mario_floor_is_slippery L573-601
function mario.mario_floor_is_slippery(m: GroupsTypesHPlus3Types.MarioState): number
	const area = m.area :: GroupsTypesHPlus3Types.Area
	local normY: number

	if bit32.band(area.terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SLIDE and (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y < F32(0.9998477) then
		return IncludePRUltratypesH.TRUE
	end

	const floorClass = mario.mario_get_floor_class(m)

	if floorClass == IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY then
		normY = F32(0.9848077)
	elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_SLIPPERY then
		normY = F32(0.9396926)
	elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_NOT_SLIPPERY then
		normY = 0.0
	else
		normY = F32(0.7880108)
	end

	return if (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y <= normY then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:mario_floor_is_slope L606-633
function mario.mario_floor_is_slope(m: GroupsTypesHPlus3Types.MarioState): number
	const area = m.area :: GroupsTypesHPlus3Types.Area
	local normY: number

	if bit32.band(area.terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SLIDE and (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y < F32(0.9998477) then
		return IncludePRUltratypesH.TRUE
	end

	const floorClass = mario.mario_get_floor_class(m)

	if floorClass == IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY then
		normY = F32(0.9961947)
	elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_SLIPPERY then
		normY = F32(0.9848077)
	elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_NOT_SLIPPERY then
		normY = F32(0.9396926)
	else
		normY = F32(0.9659258)
	end

	return if (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y <= normY then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:mario_floor_is_steep L638-669
function mario.mario_floor_is_steep(m: GroupsTypesHPlus3Types.MarioState): number
	local result = IncludePRUltratypesH.FALSE

	-- Interestingly, this function does not check for the
	-- slide terrain type. This means that steep behavior persists for
	-- non-slippery and slippery surfaces.
	-- This does not matter in vanilla game practice.
	if mario.mario_facing_downhill(m, IncludePRUltratypesH.FALSE) == 0 then
		local normY: number
		const floorClass = mario.mario_get_floor_class(m)

		if floorClass == IncludeSurfaceTerrainsH.SURFACE_VERY_SLIPPERY then
			normY = F32(0.9659258)
		elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_SLIPPERY then
			normY = F32(0.9396926)
		elseif floorClass == IncludeSurfaceTerrainsH.SURFACE_NOT_SLIPPERY then
			normY = F32(0.8660254)
		else
			normY = F32(0.8660254)
		end

		result = if (m.floor :: GroupsTypesHPlus3Types.Surface).normal.y <= normY then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
	end

	return result
end

-- from src/game/mario.c:find_floor_height_relative_polar L674-684
function mario.find_floor_height_relative_polar(m: GroupsTypesHPlus3Types.MarioState, angleFromMario: number, distFromMario: number): number
	angleFromMario = S16(TruncS32(angleFromMario))
	distFromMario = F32(distFromMario)
	const y = F32(SrcEngineMathUtilH.sins(m.faceAngle[2] + angleFromMario) * distFromMario)
	const x = F32(SrcEngineMathUtilH.coss(m.faceAngle[2] + angleFromMario) * distFromMario)

	const floorY = SrcEngineSurfaceCollision.find_floor(F32(m.pos[1] + y), F32(m.pos[2] + 100.0), F32(m.pos[3] + x), Floor)

	return floorY
end

-- from src/game/mario.c:find_floor_slope L689-713
function mario.find_floor_slope(m: GroupsTypesHPlus3Types.MarioState, yawOffset: number): number
	yawOffset = S16(TruncS32(yawOffset))
	const x = F32(SrcEngineMathUtilH.sins(m.faceAngle[2] + yawOffset) * 5.0)
	const z = F32(SrcEngineMathUtilH.coss(m.faceAngle[2] + yawOffset) * 5.0)

	const forwardFloorY = SrcEngineSurfaceCollision.find_floor(F32(m.pos[1] + x), F32(m.pos[2] + 100.0), F32(m.pos[3] + z), Floor)
	const backwardFloorY = SrcEngineSurfaceCollision.find_floor(F32(m.pos[1] - x), F32(m.pos[2] + 100.0), F32(m.pos[3] - z), Floor)

	--! If Mario is near OOB, these floorY's can sometimes be -11000.
	-- This will cause these to be off and give improper slopes.
	const forwardYDelta = F32(forwardFloorY - m.pos[2])
	const backwardYDelta = F32(m.pos[2] - backwardFloorY)

	local result: number

	if F32(forwardYDelta * forwardYDelta) < F32(backwardYDelta * backwardYDelta) then
		result = SrcEngineMathUtil.atan2s(5.0, forwardYDelta)
	else
		result = SrcEngineMathUtil.atan2s(5.0, backwardYDelta)
	end

	return result
end

-- from src/game/mario.c:update_mario_sound_and_camera L718-736
function mario.update_mario_sound_and_camera(m: GroupsTypesHPlus3Types.MarioState)
	const action = m.action
	const area = m.area :: GroupsTypesHPlus3Types.Area
	const camPreset = (area.camera :: GroupsTypesHPlus3Types.Camera).mode

	if action == IncludeSm64H.ACT_FIRST_PERSON then
		SoundInit.raise_background_noise(2)
		Camera.gCameraMovementFlags = S16(bit32.band(Camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE)))
		-- Go back to the last camera mode
		Camera.set_camera_mode(area.camera :: GroupsTypesHPlus3Types.Camera, -1, 1)
	elseif action == IncludeSm64H.ACT_SLEEPING then
		SoundInit.raise_background_noise(2)
	end

	if not bit32.btest(action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
		if camPreset == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO or camPreset == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
			const camera = area.camera :: GroupsTypesHPlus3Types.Camera
			Camera.set_camera_mode(camera, camera.defMode, 1)
		end
	end
end

-- from src/game/mario.c:set_steep_jump_action L741-758
function mario.set_steep_jump_action(m: GroupsTypesHPlus3Types.MarioState)
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMarioSteepJumpYaw, m.faceAngle[2])

	if m.forwardVel > 0 then
		const angleTemp = S16(m.floorAngle + 0x8000)
		const faceAngleTemp = S16(m.faceAngle[2] - angleTemp)
		const y = F32(SrcEngineMathUtilH.sins(faceAngleTemp) * m.forwardVel)
		const x = F32(F32(SrcEngineMathUtilH.coss(faceAngleTemp) * m.forwardVel) * 0.75)

		m.forwardVel = F32(math.sqrt(F32(F32(y * y) + F32(x * x))))
		m.faceAngle[2] = S16(SrcEngineMathUtil.atan2s(x, y) + angleTemp)
	end

	mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_STEEP_JUMP, 0)
end

-- from src/game/mario.c:set_mario_y_vel_based_on_fspeed L763-771
function mario.set_mario_y_vel_based_on_fspeed(m: GroupsTypesHPlus3Types.MarioState, initialVelY: number, multiplier: number)
	initialVelY = F32(initialVelY)
	multiplier = F32(multiplier)
	-- get_additive_y_vel_for_jumps is always 0 and a stubbed function.
	-- It was likely trampoline related based on code location.
	m.vel[2] = F32(F32(initialVelY + Registry.Members.src__game__mario_step.get_additive_y_vel_for_jumps()) + F32(m.forwardVel * multiplier))

	if m.squishTimer ~= 0 or m.quicksandDepth > 1.0 then
		m.vel[2] = F32(m.vel[2] * 0.5)
	end
end

-- from src/game/mario.c:set_mario_action_airborne L776-891
function mario.set_mario_action_airborne(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	if (m.squishTimer ~= 0 or m.quicksandDepth >= 1.0) and (action == IncludeSm64H.ACT_DOUBLE_JUMP or action == IncludeSm64H.ACT_TWIRLING) then
		action = IncludeSm64H.ACT_JUMP
	end

	if action == IncludeSm64H.ACT_DOUBLE_JUMP then
		mario.set_mario_y_vel_based_on_fspeed(m, 52.0, 0.25)
		m.forwardVel = F32(m.forwardVel * F32(0.8))
	elseif action == IncludeSm64H.ACT_BACKFLIP then
		marioObj.header.gfx.animInfo.animID = -1
		m.forwardVel = -16.0
		mario.set_mario_y_vel_based_on_fspeed(m, 62.0, 0.0)
	elseif action == IncludeSm64H.ACT_TRIPLE_JUMP then
		mario.set_mario_y_vel_based_on_fspeed(m, 69.0, 0.0)
		m.forwardVel = F32(m.forwardVel * F32(0.8))
	elseif action == IncludeSm64H.ACT_FLYING_TRIPLE_JUMP then
		mario.set_mario_y_vel_based_on_fspeed(m, 82.0, 0.0)
	elseif action == IncludeSm64H.ACT_WATER_JUMP or action == IncludeSm64H.ACT_HOLD_WATER_JUMP then
		if actionArg == 0 then
			mario.set_mario_y_vel_based_on_fspeed(m, 42.0, 0.0)
		end
	elseif action == IncludeSm64H.ACT_BURNING_JUMP then
		m.vel[2] = 31.5
		m.forwardVel = 8.0
	elseif action == IncludeSm64H.ACT_RIDING_SHELL_JUMP then
		mario.set_mario_y_vel_based_on_fspeed(m, 42.0, 0.25)
	elseif action == IncludeSm64H.ACT_JUMP or action == IncludeSm64H.ACT_HOLD_JUMP then
		marioObj.header.gfx.animInfo.animID = -1
		mario.set_mario_y_vel_based_on_fspeed(m, 42.0, 0.25)
		m.forwardVel = F32(m.forwardVel * F32(0.8))
	elseif action == IncludeSm64H.ACT_WALL_KICK_AIR or action == IncludeSm64H.ACT_TOP_OF_POLE_JUMP then
		mario.set_mario_y_vel_based_on_fspeed(m, 62.0, 0.0)
		if m.forwardVel < 24.0 then
			m.forwardVel = 24.0
		end
		m.wallKickTimer = 0
	elseif action == IncludeSm64H.ACT_SIDE_FLIP then
		mario.set_mario_y_vel_based_on_fspeed(m, 62.0, 0.0)
		m.forwardVel = 8.0
		m.faceAngle[2] = m.intendedYaw
	elseif action == IncludeSm64H.ACT_STEEP_JUMP then
		marioObj.header.gfx.animInfo.animID = -1
		mario.set_mario_y_vel_based_on_fspeed(m, 42.0, 0.25)
		m.faceAngle[1] = -0x2000
	elseif action == IncludeSm64H.ACT_LAVA_BOOST then
		m.vel[2] = 84.0
		if actionArg == 0 then
			m.forwardVel = 0.0
		end
	elseif action == IncludeSm64H.ACT_DIVE then
		local forwardVel = F32(m.forwardVel + 15.0)

		if forwardVel > 48.0 then
			forwardVel = 48.0
		end

		mario.mario_set_forward_vel(m, forwardVel)
	elseif action == IncludeSm64H.ACT_LONG_JUMP then
		marioObj.header.gfx.animInfo.animID = -1
		mario.set_mario_y_vel_based_on_fspeed(m, 30.0, 0.0)
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioLongJumpIsSlow, if m.forwardVel > 16.0 then IncludePRUltratypesH.FALSE else IncludePRUltratypesH.TRUE)

		--! (BLJ's) This properly handles long jumps from getting forward speed with
		-- too much velocity, but misses backwards longs allowing high negative speeds.
		m.forwardVel = F32(m.forwardVel * 1.5)
		if m.forwardVel > 48.0 then
			m.forwardVel = 48.0
		end
	elseif action == IncludeSm64H.ACT_SLIDE_KICK then
		m.vel[2] = 12.0
		if m.forwardVel < 32.0 then
			m.forwardVel = 32.0
		end
	elseif action == IncludeSm64H.ACT_JUMP_KICK then
		m.vel[2] = 20.0
	end

	m.peakHeight = m.pos[2]
	m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_UNKNOWN_08)

	return action
end

-- from src/game/mario.c:set_mario_action_moving L896-936
function mario.set_mario_action_moving(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	const floorClass = S16(mario.mario_get_floor_class(m))
	const forwardVel = m.forwardVel
	const mag = SrcEngineMathUtilH.min(m.intendedMag, 8.0)

	if action == IncludeSm64H.ACT_WALKING then
		if floorClass ~= IncludeSurfaceTerrainsH.SURFACE_CLASS_VERY_SLIPPERY then
			if 0.0 <= forwardVel and forwardVel < mag then
				m.forwardVel = mag
			end
		end

		const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioWalkingPitch, 0)
	elseif action == IncludeSm64H.ACT_HOLD_WALKING then
		if 0.0 <= forwardVel and forwardVel < F32(mag / 2.0) then
			m.forwardVel = F32(mag / 2.0)
		end
	elseif action == IncludeSm64H.ACT_BEGIN_SLIDING then
		if mario.mario_facing_downhill(m, IncludePRUltratypesH.FALSE) ~= 0 then
			action = IncludeSm64H.ACT_BUTT_SLIDE
		else
			action = IncludeSm64H.ACT_STOMACH_SLIDE
		end
	elseif action == IncludeSm64H.ACT_HOLD_BEGIN_SLIDING then
		if mario.mario_facing_downhill(m, IncludePRUltratypesH.FALSE) ~= 0 then
			action = IncludeSm64H.ACT_HOLD_BUTT_SLIDE
		else
			action = IncludeSm64H.ACT_HOLD_STOMACH_SLIDE
		end
	end

	return action
end

-- from src/game/mario.c:set_mario_action_submerged L941-947
function mario.set_mario_action_submerged(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	if action == IncludeSm64H.ACT_METAL_WATER_JUMP or action == IncludeSm64H.ACT_HOLD_METAL_WATER_JUMP then
		m.vel[2] = 32.0
	end

	return action
end

-- from src/game/mario.c:set_mario_action_cutscene L952-973
function mario.set_mario_action_cutscene(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	if action == IncludeSm64H.ACT_EMERGE_FROM_PIPE then
		m.vel[2] = 52.0
	elseif action == IncludeSm64H.ACT_FALL_AFTER_STAR_GRAB then
		mario.mario_set_forward_vel(m, 0.0)
	elseif action == IncludeSm64H.ACT_SPAWN_SPIN_AIRBORNE then
		mario.mario_set_forward_vel(m, 2.0)
	elseif action == IncludeSm64H.ACT_SPECIAL_EXIT_AIRBORNE or action == IncludeSm64H.ACT_SPECIAL_DEATH_EXIT then
		m.vel[2] = 64.0
	end

	return action
end

-- from src/game/mario.c:set_mario_action L979-1013
function mario.set_mario_action(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	if bit32.band(action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_MOVING then
		action = mario.set_mario_action_moving(m, action, actionArg)
	elseif bit32.band(action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_AIRBORNE then
		action = mario.set_mario_action_airborne(m, action, actionArg)
	elseif bit32.band(action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_SUBMERGED then
		action = mario.set_mario_action_submerged(m, action, actionArg)
	elseif bit32.band(action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_CUTSCENE then
		action = mario.set_mario_action_cutscene(m, action, actionArg)
	end

	-- Resets the sound played flags, meaning Mario can play those sound types again.
	m.flags = bit32.band(m.flags, bit32.bnot(bit32.bor(IncludeSm64H.MARIO_ACTION_SOUND_PLAYED, IncludeSm64H.MARIO_MARIO_SOUND_PLAYED)))

	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
		m.flags = bit32.band(m.flags, bit32.bnot(IncludeSm64H.MARIO_UNKNOWN_18))
	end

	-- Initialize the action information.
	m.prevAction = m.action
	m.action = action
	m.actionArg = actionArg
	m.actionState = 0
	m.actionTimer = 0

	return IncludePRUltratypesH.TRUE
end

-- from src/game/mario.c:set_jump_from_landing L1018-1068
function mario.set_jump_from_landing(m: GroupsTypesHPlus3Types.MarioState): number
	if m.quicksandDepth >= 11.0 then
		if m.heldObj == nil then
			return mario.set_mario_action(m, IncludeSm64H.ACT_QUICKSAND_JUMP_LAND, 0)
		else
			return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_QUICKSAND_JUMP_LAND, 0)
		end
	end

	if mario.mario_floor_is_steep(m) ~= 0 then
		mario.set_steep_jump_action(m)
	else
		if m.doubleJumpTimer == 0 or m.squishTimer ~= 0 then
			mario.set_mario_action(m, IncludeSm64H.ACT_JUMP, 0)
		elseif m.prevAction == IncludeSm64H.ACT_JUMP_LAND then
			mario.set_mario_action(m, IncludeSm64H.ACT_DOUBLE_JUMP, 0)
		elseif m.prevAction == IncludeSm64H.ACT_FREEFALL_LAND then
			mario.set_mario_action(m, IncludeSm64H.ACT_DOUBLE_JUMP, 0)
		elseif m.prevAction == IncludeSm64H.ACT_SIDE_FLIP_LAND_STOP then
			mario.set_mario_action(m, IncludeSm64H.ACT_DOUBLE_JUMP, 0)
		elseif m.prevAction == IncludeSm64H.ACT_DOUBLE_JUMP_LAND then
			-- If Mario has a wing cap, he ignores the typical speed
			-- requirement for a triple jump.
			if bit32.btest(m.flags, IncludeSm64H.MARIO_WING_CAP) then
				mario.set_mario_action(m, IncludeSm64H.ACT_FLYING_TRIPLE_JUMP, 0)
			elseif m.forwardVel > 20.0 then
				mario.set_mario_action(m, IncludeSm64H.ACT_TRIPLE_JUMP, 0)
			else
				mario.set_mario_action(m, IncludeSm64H.ACT_JUMP, 0)
			end
		else
			mario.set_mario_action(m, IncludeSm64H.ACT_JUMP, 0)
		end
	end

	m.doubleJumpTimer = 0

	return IncludePRUltratypesH.TRUE
end

-- from src/game/mario.c:set_jumping_action L1074-1093
function mario.set_jumping_action(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	if m.quicksandDepth >= 11.0 then
		-- Checks whether Mario is holding an object or not.
		if m.heldObj == nil then
			return mario.set_mario_action(m, IncludeSm64H.ACT_QUICKSAND_JUMP_LAND, 0)
		else
			return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_QUICKSAND_JUMP_LAND, 0)
		end
	end

	if mario.mario_floor_is_steep(m) ~= 0 then
		mario.set_steep_jump_action(m)
	else
		mario.set_mario_action(m, action, actionArg)
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/mario.c:drop_and_set_mario_action L1098-1102
function mario.drop_and_set_mario_action(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number): number
	Interaction.mario_stop_riding_and_holding(m)

	return mario.set_mario_action(m, action, actionArg)
end

-- from src/game/mario.c:hurt_and_set_mario_action L1107-1111
function mario.hurt_and_set_mario_action(m: GroupsTypesHPlus3Types.MarioState, action: number, actionArg: number, hurtCounter: number): number
	hurtCounter = S16(TruncS32(hurtCounter))
	m.hurtCounter = U8(hurtCounter)

	return mario.set_mario_action(m, action, actionArg)
end

-- from src/game/mario.c:check_common_action_exits L1117-1132
function mario.check_common_action_exits(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_BEGIN_SLIDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:check_common_hold_action_exits L1138-1153
function mario.check_common_hold_action_exits(m: GroupsTypesHPlus3Types.MarioState): number
	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_JUMP, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_OFF_FLOOR) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_FREEFALL, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WALKING, 0)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE) then
		return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_BEGIN_SLIDING, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario.c:transition_submerged_to_walking L1158-1168
function mario.transition_submerged_to_walking(m: GroupsTypesHPlus3Types.MarioState): number
	const area = m.area :: GroupsTypesHPlus3Types.Area
	const camera = area.camera :: GroupsTypesHPlus3Types.Camera

	Camera.set_camera_mode(camera, camera.defMode, 1)

	SrcEngineMathUtil.vec3s_set(m.angleVel, 0, 0, 0)

	if m.heldObj == nil then
		return mario.set_mario_action(m, IncludeSm64H.ACT_WALKING, 0)
	else
		return mario.set_mario_action(m, IncludeSm64H.ACT_HOLD_WALKING, 0)
	end
end

-- from src/game/mario.c:set_water_plunge_action L1174-1193
function mario.set_water_plunge_action(m: GroupsTypesHPlus3Types.MarioState): number
	m.forwardVel = F32(m.forwardVel / 4.0)
	m.vel[2] = F32(m.vel[2] / 2.0)

	m.pos[2] = F32(m.waterLevel - 100)

	m.faceAngle[3] = 0

	SrcEngineMathUtil.vec3s_set(m.angleVel, 0, 0, 0)

	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_DIVING) then
		m.faceAngle[1] = 0
	end

	const camera = (m.area :: GroupsTypesHPlus3Types.Area).camera :: GroupsTypesHPlus3Types.Camera

	if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
		Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE, 1)
	end

	return mario.set_mario_action(m, IncludeSm64H.ACT_WATER_PLUNGE, 0)
end

-- from src/game/mario.c:squish_mario_model L1205-1227
function mario.squish_mario_model(m: GroupsTypesHPlus3Types.MarioState)
	if m.squishTimer ~= 0xFF then
		const scale = (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.scale

		-- If no longer squished, scale back to default.
		if m.squishTimer == 0 then
			SrcEngineMathUtil.vec3f_set(scale, 1.0, 1.0, 1.0)
		-- If timer is less than 16, rubber-band Mario's size scale up and down.
		elseif m.squishTimer <= 16 then
			m.squishTimer = U8(m.squishTimer - 1)

			scale[2] = F32(1.0 - F32(F32(mario.sSquishScaleOverTime[16 - m.squishTimer] * F32(0.6)) / 100.0))
			scale[1] = F32(F32(F32(mario.sSquishScaleOverTime[16 - m.squishTimer] * F32(0.4)) / 100.0) + 1.0)

			scale[3] = scale[1]
		else
			m.squishTimer = U8(m.squishTimer - 1)

			SrcEngineMathUtil.vec3f_set(scale, F32(1.4), F32(0.4), F32(1.4))
		end
	end
end

-- from src/game/mario.c:debug_print_speed_action_normal L1232-1248
function mario.debug_print_speed_action_normal(m: GroupsTypesHPlus3Types.MarioState)
	-- Debug text printing is replaced (debug-print-externals): nothing is written.
end

-- from src/game/mario.c:update_mario_button_inputs L1253-1288
function mario.update_mario_button_inputs(m: GroupsTypesHPlus3Types.MarioState)
	const controller = m.controller :: GroupsTypesHPlus3Types.Controller

	if bit32.btest(controller.buttonPressed, IncludePROsH.A_BUTTON) then
		m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_A_PRESSED))
	end

	if bit32.btest(controller.buttonDown, IncludePROsH.A_BUTTON) then
		m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_A_DOWN))
	end

	-- Don't update for these buttons if squished.
	if m.squishTimer == 0 then
		if bit32.btest(controller.buttonPressed, IncludePROsH.B_BUTTON) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_B_PRESSED))
		end

		if bit32.btest(controller.buttonDown, IncludePROsH.Z_TRIG) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_Z_DOWN))
		end

		if bit32.btest(controller.buttonPressed, IncludePROsH.Z_TRIG) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_Z_PRESSED))
		end
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_A_PRESSED) then
		m.framesSinceA = 0
	elseif m.framesSinceA < 0xFF then
		m.framesSinceA = U8(m.framesSinceA + 1)
	end

	if bit32.btest(m.input, IncludeSm64H.INPUT_B_PRESSED) then
		m.framesSinceB = 0
	elseif m.framesSinceB < 0xFF then
		m.framesSinceB = U8(m.framesSinceB + 1)
	end
end

-- from src/game/mario.c:update_mario_joystick_inputs L1293-1309
function mario.update_mario_joystick_inputs(m: GroupsTypesHPlus3Types.MarioState)
	const controller = m.controller :: GroupsTypesHPlus3Types.Controller
	const mag = F32(F32(F32(controller.stickMag / 64.0) * F32(controller.stickMag / 64.0)) * 64.0)

	if m.squishTimer == 0 then
		m.intendedMag = F32(mag / 2.0)
	else
		m.intendedMag = F32(mag / 8.0)
	end

	if m.intendedMag > 0.0 then
		const camera = (m.area :: GroupsTypesHPlus3Types.Area).camera :: GroupsTypesHPlus3Types.Camera

		m.intendedYaw = S16(SrcEngineMathUtil.atan2s(-controller.stickY, controller.stickX) + camera.yaw)
		m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_NONZERO_ANALOG))
	else
		m.intendedYaw = m.faceAngle[2]
	end
end

-- from src/game/mario.c:update_mario_geometry_inputs L1314-1368
function mario.update_mario_geometry_inputs(m: GroupsTypesHPlus3Types.MarioState)
	-- f32_find_wall_collision writes its three pointers: copy the position in and out.
	WallX[1] = m.pos[1]
	WallY[1] = m.pos[2]
	WallZ[1] = m.pos[3]
	SrcEngineSurfaceCollision.f32_find_wall_collision(WallX, WallY, WallZ, 60.0, 50.0)
	m.pos[1] = WallX[1]
	m.pos[2] = WallY[1]
	m.pos[3] = WallZ[1]

	WallX[1] = m.pos[1]
	WallY[1] = m.pos[2]
	WallZ[1] = m.pos[3]
	SrcEngineSurfaceCollision.f32_find_wall_collision(WallX, WallY, WallZ, 30.0, 24.0)
	m.pos[1] = WallX[1]
	m.pos[2] = WallY[1]
	m.pos[3] = WallZ[1]

	m.floorHeight = SrcEngineSurfaceCollision.find_floor(m.pos[1], m.pos[2], m.pos[3], Floor)
	m.floor = Floor[1]

	-- If Mario is OOB, move his position to his graphical position (which was not updated)
	-- and check for the floor there.
	-- This can cause errant behavior when combined with astral projection,
	-- since the graphical position was not Mario's previous location.
	if m.floor == nil then
		SrcEngineMathUtil.vec3f_copy(m.pos, (m.marioObj :: GroupsTypesHPlus3Types.Object).header.gfx.pos)
		m.floorHeight = SrcEngineSurfaceCollision.find_floor(m.pos[1], m.pos[2], m.pos[3], Floor)
		m.floor = Floor[1]
	end

	m.ceilHeight = mario.vec3f_find_ceil(m.pos, m.floorHeight, Ceil)
	m.ceil = Ceil[1]

	const gasLevel = SrcEngineSurfaceCollision.find_poison_gas_level(m.pos[1], m.pos[3])
	m.waterLevel = S16(TruncS32(SrcEngineSurfaceCollision.find_water_level(m.pos[1], m.pos[3])))

	if m.floor ~= nil then
		const floor = m.floor :: GroupsTypesHPlus3Types.Surface

		m.floorAngle = SrcEngineMathUtil.atan2s(floor.normal.z, floor.normal.x)
		m.terrainSoundAddend = mario.mario_get_terrain_sound_addend(m)

		if m.pos[2] > F32(m.waterLevel - 40) and mario.mario_floor_is_slippery(m) ~= 0 then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_ABOVE_SLIDE))
		end

		if bit32.btest(floor.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_DYNAMIC) or (m.ceil ~= nil and bit32.btest(m.ceil.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_DYNAMIC)) then
			const ceilToFloorDist = F32(m.ceilHeight - m.floorHeight)

			if 0.0 <= ceilToFloorDist and ceilToFloorDist <= 150.0 then
				m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_SQUISHED))
			end
		end

		if m.pos[2] > F32(m.floorHeight + 100.0) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_OFF_FLOOR))
		end

		if m.pos[2] < F32(m.waterLevel - 10) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_IN_WATER))
		end

		if m.pos[2] < F32(gasLevel - 100.0) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_IN_POISON_GAS))
		end
	else
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
	end
end

-- from src/game/mario.c:update_mario_inputs L1373-1414
function mario.update_mario_inputs(m: GroupsTypesHPlus3Types.MarioState)
	m.particleFlags = 0
	m.input = 0
	m.collidedObjInteractTypes = (m.marioObj :: GroupsTypesHPlus3Types.Object).collidedObjInteractTypes
	m.flags = bit32.band(m.flags, 0xFFFFFF)

	mario.update_mario_button_inputs(m)
	mario.update_mario_joystick_inputs(m)
	mario.update_mario_geometry_inputs(m)

	mario.debug_print_speed_action_normal(m)

	if bit32.btest(Camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE) then
		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_ALLOW_FIRST_PERSON) then
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_FIRST_PERSON))
		else
			Camera.gCameraMovementFlags = S16(bit32.band(Camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE)))
		end
	end

	if not bit32.btest(m.input, bit32.bor(IncludeSm64H.INPUT_NONZERO_ANALOG, IncludeSm64H.INPUT_A_PRESSED)) then
		m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_UNKNOWN_5))
	end

	-- These 3 flags are defined by Bowser stomping attacks
	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	if bit32.btest(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bor(InteractionH.INT_STATUS_MARIO_STUNNED, InteractionH.INT_STATUS_MARIO_KNOCKBACK_DMG, InteractionH.INT_STATUS_MARIO_SHOCKWAVE)) then
		m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_STOMPED))
	end

	-- This function is located near other unused trampoline functions,
	-- perhaps logically grouped here with the timers.
	Registry.Members.src__game__mario_step.stub_mario_step_1(m)

	if m.wallKickTimer > 0 then
		m.wallKickTimer = U8(m.wallKickTimer - 1)
	end

	if m.doubleJumpTimer > 0 then
		m.doubleJumpTimer = U8(m.doubleJumpTimer - 1)
	end
end

-- from src/game/mario.c:set_submerged_cam_preset_and_spawn_bubbles L1419-1449
function mario.set_submerged_cam_preset_and_spawn_bubbles(m: GroupsTypesHPlus3Types.MarioState)
	if bit32.band(m.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_SUBMERGED then
		const heightBelowWater = F32(F32(m.waterLevel - 80) - m.pos[2])
		const camera = (m.area :: GroupsTypesHPlus3Types.Area).camera :: GroupsTypesHPlus3Types.Camera
		const camPreset = camera.mode

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
			if camPreset ~= GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
				Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 1)
			end
		else
			if heightBelowWater > 800.0 and camPreset ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
				Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
			end

			if heightBelowWater < 400.0 and camPreset ~= GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
				Camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE, 1)
			end

			-- As long as Mario isn't drowning or at the top
			-- of the water with his head out, spawn bubbles.
			if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INTANGIBLE) then
				if m.pos[2] < F32(m.waterLevel - 160) or m.faceAngle[1] < -0x800 then
					m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_BUBBLE)
				end
			end
		end
	end
end

-- from src/game/mario.c:update_mario_health L1454-1511
function mario.update_mario_health(m: GroupsTypesHPlus3Types.MarioState)
	if m.health >= 0x100 then
		-- When already healing or hurting Mario, Mario's HP is not changed any more here.
		if bit32.bor(m.healCounter, m.hurtCounter) == 0 then
			if bit32.btest(m.input, IncludeSm64H.INPUT_IN_POISON_GAS) and not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INTANGIBLE) then
				if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) and Main.gDebugLevelSelect == 0 then
					m.health = S16(m.health - 4)
				end
			else
				if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SWIMMING) and not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INTANGIBLE) then
					const terrainIsSnow = bit32.band((m.area :: GroupsTypesHPlus3Types.Area).terrainType, IncludeSurfaceTerrainsH.TERRAIN_MASK) == IncludeSurfaceTerrainsH.TERRAIN_SNOW

					-- When Mario is near the water surface, recover health (unless in snow),
					-- when in snow terrains lose 3 health.
					-- If using the debug level select, do not lose any HP to water.
					if m.pos[2] >= F32(m.waterLevel - 140) and not terrainIsSnow then
						m.health = S16(m.health + 0x1A)
					elseif Main.gDebugLevelSelect == 0 then
						m.health = S16(m.health - (if terrainIsSnow then 3 else 1))
					end
				end
			end
		end

		if m.healCounter > 0 then
			m.health = S16(m.health + 0x40)
			m.healCounter = U8(m.healCounter - 1)
		end
		if m.hurtCounter > 0 then
			m.health = S16(m.health - 0x40)
			m.hurtCounter = U8(m.hurtCounter - 1)
		end

		if m.health > 0x880 then
			m.health = 0x880
		end
		if m.health < 0x100 then
			m.health = 0xFF
		end

		-- Play a noise to alert the player when Mario is close to drowning.
		if bit32.band(m.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_SUBMERGED and m.health < 0x300 then
			Audio.play_sound(IncludeSoundsH.SOUND_MOVING_ALMOST_DROWNING, Audio.gGlobalSoundSource)
		end
	end
end

-- from src/game/mario.c:update_mario_info_for_cam L1516-1525
function mario.update_mario_info_for_cam(m: GroupsTypesHPlus3Types.MarioState)
	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState
	const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3Types.PlayerCameraState

	bodyState.action = m.action
	statusForCamera.action = m.action

	SrcEngineMathUtil.vec3s_copy(statusForCamera.faceAngle, m.faceAngle)

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_UNKNOWN_25) then
		SrcEngineMathUtil.vec3f_copy(statusForCamera.pos, m.pos)
	end
end

-- from src/game/mario.c:mario_reset_bodystate L1530-1540
function mario.mario_reset_bodystate(m: GroupsTypesHPlus3Types.MarioState)
	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

	bodyState.capState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAS_DEFAULT_CAP_OFF
	bodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_BLINK
	bodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_FISTS
	bodyState.modelState = 0
	bodyState.wingFlutter = IncludePRUltratypesH.FALSE

	m.flags = bit32.band(m.flags, bit32.bnot(IncludeSm64H.MARIO_METAL_SHOCK))
end

-- from src/game/mario.c:sink_mario_in_quicksand L1545-1553
function mario.sink_mario_in_quicksand(m: GroupsTypesHPlus3Types.MarioState)
	const o = m.marioObj :: GroupsTypesHPlus3Types.Object
	const throwMatrix = o.header.gfx.throwMatrix

	if throwMatrix ~= nil then
		throwMatrix[1][4][2] = F32(throwMatrix[1][4][2] - m.quicksandDepth)
	end

	o.header.gfx.pos[2] = F32(o.header.gfx.pos[2] - m.quicksandDepth)
end

-- from src/game/mario.c:update_and_return_cap_flags L1567-1604
function mario.update_and_return_cap_flags(m: GroupsTypesHPlus3Types.MarioState): number
	local flags = m.flags

	if m.capTimer > 0 then
		const action = m.action

		if m.capTimer <= 60 or (action ~= IncludeSm64H.ACT_READING_AUTOMATIC_DIALOG and action ~= IncludeSm64H.ACT_READING_NPC_DIALOG and action ~= IncludeSm64H.ACT_READING_SIGN and action ~= IncludeSm64H.ACT_IN_CANNON) then
			m.capTimer = U16(m.capTimer - 1)
		end

		if m.capTimer == 0 then
			SoundInit.stop_cap_music()

			m.flags = bit32.band(m.flags, bit32.bnot(IncludeSm64H.MARIO_SPECIAL_CAPS))
			if not bit32.btest(m.flags, IncludeSm64H.MARIO_CAPS) then
				m.flags = bit32.band(m.flags, bit32.bnot(IncludeSm64H.MARIO_CAP_ON_HEAD))
			end
		end

		if m.capTimer == 60 then
			SoundInit.fadeout_cap_music()
		end

		-- This code flickers the cap through a long binary string, increasing in how
		-- common it flickers near the end.
		-- sCapFlickerFrames is a 64-bit mask: bit n is bit n % 32 of word n // 32 + 1.
		const flickerWord = if m.capTimer < 32 then mario.sCapFlickerFrames.Words[1] else mario.sCapFlickerFrames.Words[2]

		if m.capTimer < 64 and bit32.btest(flickerWord, bit32.lshift(1, m.capTimer % 32)) then
			flags = bit32.band(flags, bit32.bnot(IncludeSm64H.MARIO_SPECIAL_CAPS))
			if not bit32.btest(flags, IncludeSm64H.MARIO_CAPS) then
				flags = bit32.band(flags, bit32.bnot(IncludeSm64H.MARIO_CAP_ON_HEAD))
			end
		end
	end

	return flags
end

-- from src/game/mario.c:mario_update_hitbox_and_cap_model L1609-1659
function mario.mario_update_hitbox_and_cap_model(m: GroupsTypesHPlus3Types.MarioState)
	const bodyState = m.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState
	const flags = mario.update_and_return_cap_flags(m)

	if bit32.btest(flags, IncludeSm64H.MARIO_VANISH_CAP) then
		bodyState.modelState = IncludeSm64H.MODEL_STATE_NOISE_ALPHA
	end

	if bit32.btest(flags, IncludeSm64H.MARIO_METAL_CAP) then
		bodyState.modelState = S16(bit32.bor(bodyState.modelState, IncludeSm64H.MODEL_STATE_METAL))
	end

	if bit32.btest(flags, IncludeSm64H.MARIO_METAL_SHOCK) then
		bodyState.modelState = S16(bit32.bor(bodyState.modelState, IncludeSm64H.MODEL_STATE_METAL))
	end

	-- (Pause buffered hitstun) Since the global timer increments while paused,
	-- this can be paused through to give continual invisibility. This leads to
	-- no interaction with objects.
	if m.invincTimer >= 3 and bit32.btest(GameInit.gGlobalTimer, 1) then
		const marioObj = LevelUpdate.gMarioState.marioObj :: GroupsTypesHPlus3Types.Object

		marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
	end

	if bit32.btest(flags, IncludeSm64H.MARIO_CAP_IN_HAND) then
		if bit32.btest(flags, IncludeSm64H.MARIO_WING_CAP) then
			bodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_HOLDING_WING_CAP
		else
			bodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_HOLDING_CAP
		end
	end

	if bit32.btest(flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then
		if bit32.btest(flags, IncludeSm64H.MARIO_WING_CAP) then
			bodyState.capState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAS_WING_CAP_ON
		else
			bodyState.capState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAS_DEFAULT_CAP_ON
		end
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3Types.Object

	-- Short hitbox for crouching/crawling/etc.
	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SHORT_HITBOX) then
		marioObj.hitboxHeight = 100
	else
		marioObj.hitboxHeight = 160
	end

	if bit32.btest(m.flags, IncludeSm64H.MARIO_TELEPORTING) and m.fadeWarpOpacity ~= 0xFF then
		bodyState.modelState = S16(bit32.band(bodyState.modelState, bit32.bnot(0xFF)))
		bodyState.modelState = S16(bit32.bor(bodyState.modelState, bit32.bor(0x100, m.fadeWarpOpacity)))
	end
end

-- from src/game/mario.c:debug_update_mario_cap L1665-1679
function mario.debug_update_mario_cap(button: number, flags: number, capTimer: number, capMusic: number)
	button = U16(TruncS32(button))
	capTimer = U16(TruncS32(capTimer))
	capMusic = U16(TruncS32(capMusic))
	if bit32.btest(GameInit.gPlayer1Controller.buttonDown, IncludePROsH.Z_TRIG) and bit32.btest(GameInit.gPlayer1Controller.buttonPressed, button) and not bit32.btest(LevelUpdate.gMarioState.flags, flags) then
		LevelUpdate.gMarioState.flags = bit32.bor(LevelUpdate.gMarioState.flags, flags + IncludeSm64H.MARIO_CAP_ON_HEAD)

		if capTimer > LevelUpdate.gMarioState.capTimer then
			LevelUpdate.gMarioState.capTimer = capTimer
		end

		SoundInit.play_cap_music(capMusic)
	end
end

-- from src/game/mario.c:execute_mario_action L1699-1782
function mario.execute_mario_action(o: GroupsTypesHPlus3Types.Object): number
	local inLoop = IncludePRUltratypesH.TRUE

	if LevelUpdate.gMarioState.action ~= 0 then
		const marioObj = LevelUpdate.gMarioState.marioObj :: GroupsTypesHPlus3Types.Object

		marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		mario.mario_reset_bodystate(LevelUpdate.gMarioState)
		mario.update_mario_inputs(LevelUpdate.gMarioState)
		Interaction.mario_handle_special_floors(LevelUpdate.gMarioState)
		Interaction.mario_process_interactions(LevelUpdate.gMarioState)

		-- If Mario is OOB, stop executing actions.
		if LevelUpdate.gMarioState.floor == nil then
			return 0
		end

		-- The function can loop through many action shifts in one frame,
		-- which can lead to unexpected sub-frame behavior. Could potentially hang
		-- if a loop of actions were found, but there has not been a situation found.
		while inLoop ~= 0 do
			if bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_STATIONARY then
				inLoop = Registry.Members.src__game__mario_actions_stationary.mario_execute_stationary_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_MOVING then
				inLoop = Registry.Members.src__game__mario_actions_moving.mario_execute_moving_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_AIRBORNE then
				inLoop = Registry.Members.src__game__mario_actions_airborne.mario_execute_airborne_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_SUBMERGED then
				inLoop = Registry.Members.src__game__mario_actions_submerged.mario_execute_submerged_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_CUTSCENE then
				inLoop = MarioActionsCutscene.mario_execute_cutscene_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_AUTOMATIC then
				inLoop = Registry.Members.src__game__mario_actions_automatic.mario_execute_automatic_action(LevelUpdate.gMarioState)
			elseif bit32.band(LevelUpdate.gMarioState.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_OBJECT then
				inLoop = Registry.Members.src__game__mario_actions_object.mario_execute_object_action(LevelUpdate.gMarioState)
			end
		end

		mario.sink_mario_in_quicksand(LevelUpdate.gMarioState)
		mario.squish_mario_model(LevelUpdate.gMarioState)
		mario.set_submerged_cam_preset_and_spawn_bubbles(LevelUpdate.gMarioState)
		mario.update_mario_health(LevelUpdate.gMarioState)
		mario.update_mario_info_for_cam(LevelUpdate.gMarioState)
		mario.mario_update_hitbox_and_cap_model(LevelUpdate.gMarioState)

		const floor = LevelUpdate.gMarioState.floor :: GroupsTypesHPlus3Types.Surface

		if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_HORIZONTAL_WIND then
			BehaviorsWindInc.spawn_wind_particles(0, S16(bit32.lshift(floor.force, 8)))
			Audio.play_sound(IncludeSoundsH.SOUND_ENV_WIND2, marioObj.header.gfx.cameraToObject)
		end

		if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_VERTICAL_WIND then
			BehaviorsWindInc.spawn_wind_particles(1, 0)
			Audio.play_sound(IncludeSoundsH.SOUND_ENV_WIND2, marioObj.header.gfx.cameraToObject)
		end

		SoundInit.play_infinite_stairs_music()
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

		return LevelUpdate.gMarioState.particleFlags
	end

	return 0
end

-- from src/game/mario.c:init_mario L1788-1869
function mario.init_mario()
	mario.unused80339F10 = 0

	LevelUpdate.gMarioState.actionTimer = 0
	LevelUpdate.gMarioState.framesSinceA = 0xFF
	LevelUpdate.gMarioState.framesSinceB = 0xFF

	LevelUpdate.gMarioState.invincTimer = 0

	if bit32.btest(SaveFile.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_CAP_ON_GROUND, SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO, SaveFileH.SAVE_FLAG_CAP_ON_UKIKI, SaveFileH.SAVE_FLAG_CAP_ON_MR_BLIZZARD)) then
		LevelUpdate.gMarioState.flags = 0
	else
		LevelUpdate.gMarioState.flags = bit32.bor(IncludeSm64H.MARIO_NORMAL_CAP, IncludeSm64H.MARIO_CAP_ON_HEAD)
	end

	LevelUpdate.gMarioState.forwardVel = 0
	LevelUpdate.gMarioState.squishTimer = 0

	LevelUpdate.gMarioState.hurtCounter = 0
	LevelUpdate.gMarioState.healCounter = 0

	LevelUpdate.gMarioState.capTimer = 0
	LevelUpdate.gMarioState.quicksandDepth = 0

	LevelUpdate.gMarioState.heldObj = nil
	LevelUpdate.gMarioState.riddenObj = nil
	LevelUpdate.gMarioState.usedObj = nil

	LevelUpdate.gMarioState.waterLevel = S16(TruncS32(SrcEngineSurfaceCollision.find_water_level(Area.gMarioSpawnInfo.startPos[1], Area.gMarioSpawnInfo.startPos[3])))

	LevelUpdate.gMarioState.area = Area.gCurrentArea
	LevelUpdate.gMarioState.marioObj = ObjectListProcessor.gMarioObject

	const marioObj = LevelUpdate.gMarioState.marioObj :: GroupsTypesHPlus3Types.Object

	marioObj.header.gfx.animInfo.animID = -1
	SrcEngineMathUtil.vec3s_copy(LevelUpdate.gMarioState.faceAngle, Area.gMarioSpawnInfo.startAngle)
	SrcEngineMathUtil.vec3s_set(LevelUpdate.gMarioState.angleVel, 0, 0, 0)
	SrcEngineMathUtil.vec3s_to_vec3f(LevelUpdate.gMarioState.pos, Area.gMarioSpawnInfo.startPos)
	SrcEngineMathUtil.vec3f_set(LevelUpdate.gMarioState.vel, 0, 0, 0)

	LevelUpdate.gMarioState.floorHeight = SrcEngineSurfaceCollision.find_floor(LevelUpdate.gMarioState.pos[1], LevelUpdate.gMarioState.pos[2], LevelUpdate.gMarioState.pos[3], Floor)
	LevelUpdate.gMarioState.floor = Floor[1]

	if LevelUpdate.gMarioState.pos[2] < LevelUpdate.gMarioState.floorHeight then
		LevelUpdate.gMarioState.pos[2] = LevelUpdate.gMarioState.floorHeight
	end

	marioObj.header.gfx.pos[2] = LevelUpdate.gMarioState.pos[2]

	LevelUpdate.gMarioState.action = if LevelUpdate.gMarioState.pos[2] <= F32(LevelUpdate.gMarioState.waterLevel - 100) then IncludeSm64H.ACT_WATER_IDLE else IncludeSm64H.ACT_IDLE

	mario.mario_reset_bodystate(LevelUpdate.gMarioState)
	mario.update_mario_info_for_cam(LevelUpdate.gMarioState)

	const marioBodyState = LevelUpdate.gMarioState.marioBodyState :: GroupsTypesHPlus3Types.MarioBodyState

	marioBodyState.punchState = 0

	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oPosX, LevelUpdate.gMarioState.pos[1])
	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oPosY, LevelUpdate.gMarioState.pos[2])
	buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oPosZ, LevelUpdate.gMarioState.pos[3])

	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMoveAnglePitch, LevelUpdate.gMarioState.faceAngle[1])
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, LevelUpdate.gMarioState.faceAngle[2])
	buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleRoll, LevelUpdate.gMarioState.faceAngle[3])

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, LevelUpdate.gMarioState.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, LevelUpdate.gMarioState.faceAngle[2], 0)

	if SaveFile.save_file_get_cap_pos(CapPos) ~= 0 then
		const capObject = ObjectHelpers.spawn_object(marioObj, IncludeModelIdsH.MODEL_MARIOS_CAP, BehaviorIds.bhvNormalCap)

		buffer.writef32(capObject.rawData, IncludeObjectFieldsH.oPosX, CapPos[1])
		buffer.writef32(capObject.rawData, IncludeObjectFieldsH.oPosY, CapPos[2])
		buffer.writef32(capObject.rawData, IncludeObjectFieldsH.oPosZ, CapPos[3])

		buffer.writei32(capObject.rawData, IncludeObjectFieldsH.oForwardVelS32, 0)
		buffer.writei32(capObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)
	end
end

-- from src/game/mario.c:init_mario_from_save_file L1871-1894
function mario.init_mario_from_save_file()
	LevelUpdate.gMarioState.unk00 = 0
	LevelUpdate.gMarioState.flags = 0
	LevelUpdate.gMarioState.action = 0
	LevelUpdate.gMarioState.spawnInfo = Area.gPlayerSpawnInfos[1]
	LevelUpdate.gMarioState.statusForCamera = Camera.gPlayerCameraState[1]
	LevelUpdate.gMarioState.marioBodyState = MarioMisc.gBodyStates[1]
	LevelUpdate.gMarioState.controller = GameInit.gControllers[1]
	LevelUpdate.gMarioState.animList = GameInit.gMarioAnimsBuf

	LevelUpdate.gMarioState.numCoins = 0
	LevelUpdate.gMarioState.numStars = S16(SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1))
	LevelUpdate.gMarioState.numKeys = 0

	LevelUpdate.gMarioState.numLives = 4
	LevelUpdate.gMarioState.health = 0x880

	LevelUpdate.gMarioState.prevNumStarsForDialog = LevelUpdate.gMarioState.numStars
	LevelUpdate.gMarioState.unkB0 = 0xBD

	LevelUpdate.gHudDisplay.coins = 0
	LevelUpdate.gHudDisplay.wedges = 8
end

return mario
