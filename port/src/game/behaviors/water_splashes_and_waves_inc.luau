--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_splashes_and_waves.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")

const ObjectHelpersH = require("../object_helpers_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const LevelUpdate = require("../level_update")
const Memory = require("../memory")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:data
const water_splashes_and_waves_inc = {
	-- from src/game/behaviors/water_splashes_and_waves.inc.c:sWaterSplashDropletParams L4-12
	sWaterSplashDropletParams = {
		flags = ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE,
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL,
		behavior = BehaviorIds.bhvWaterDroplet,
		moveAngleRange = 0,
		moveRange = 0,
		randForwardVelOffset = 5.0,
		randForwardVelScale = 3.0,
		randYVelOffset = 30.0,
		randYVelScale = 20.0,
		randSizeOffset = 0.5,
		randSizeScale = 1.0,
	} :: ObjectHelpersH.WaterDropletParams,
	-- from src/game/behaviors/water_splashes_and_waves.inc.c:gShallowWaterSplashDropletParams L15-23
	gShallowWaterSplashDropletParams = {
		flags = bit32.bor(ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE, ObjectHelpersH.WATER_DROPLET_FLAG_SET_Y_TO_WATER_LEVEL),
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL,
		behavior = BehaviorIds.bhvWaterDroplet,
		moveAngleRange = 0,
		moveRange = 0,
		randForwardVelOffset = 2.0,
		randForwardVelScale = 3.0,
		randYVelOffset = 20.0,
		randYVelScale = 20.0,
		randSizeOffset = 0.5,
		randSizeScale = 1.0,
	} :: ObjectHelpersH.WaterDropletParams,
	-- from src/game/behaviors/water_splashes_and_waves.inc.c:sWaterDropletFishParams L26-34
	sWaterDropletFishParams = {
		flags = bit32.bor(ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE, ObjectHelpersH.WATER_DROPLET_FLAG_SET_Y_TO_WATER_LEVEL),
		model = IncludeModelIdsH.MODEL_FISH,
		behavior = BehaviorIds.bhvWaterDroplet,
		moveAngleRange = 0,
		moveRange = 0,
		randForwardVelOffset = 2.0,
		randForwardVelScale = 3.0,
		randYVelOffset = 20.0,
		randYVelScale = 20.0,
		randSizeOffset = 1.0,
		randSizeScale = 0.0,
	} :: ObjectHelpersH.WaterDropletParams,
	-- from src/game/behaviors/water_splashes_and_waves.inc.c:gShallowWaterWaveDropletParams L37-46
	gShallowWaterWaveDropletParams = {
		flags = bit32.bor(bit32.bor(ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE_INCR_PLUS_8000, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE), ObjectHelpersH.WATER_DROPLET_FLAG_SET_Y_TO_WATER_LEVEL),
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL,
		behavior = BehaviorIds.bhvWaterDroplet,
		moveAngleRange = 0x6000,
		moveRange = 0,
		randForwardVelOffset = 2.0,
		randForwardVelScale = 8.0,
		randYVelOffset = 10.0,
		randYVelScale = 10.0,
		randSizeOffset = 0.5,
		randSizeScale = 1.0,
	} :: ObjectHelpersH.WaterDropletParams,
}

Registry.Register("src__game__behaviors__water_splashes_and_waves_inc", water_splashes_and_waves_inc)

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_water_splash_spawn_droplets L49-60
function water_splashes_and_waves_inc.bhv_water_splash_spawn_droplets()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
	end

	-- Make sure it is not at the default water level
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		for I = 1, 3 do
			ObjectHelpers.spawn_water_droplet(o, water_splashes_and_waves_inc.sWaterSplashDropletParams)
		end
	end
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_water_droplet_loop L62-90
function water_splashes_and_waves_inc.bhv_water_droplet_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const WaterLevel = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		if ObjectHelpers.cur_obj_has_model(IncludeModelIdsH.MODEL_FISH) ~= 0 then
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD)))
		else
			o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, SrcEngineBehaviorScript.random_u16())
	end

	-- Apply gravity
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - 4)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	-- Check if fallen back into the water
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
		if WaterLevel > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
			-- Create the smaller splash
			ObjectHelpers.try_to_spawn_object(0, 1, o, IncludeModelIdsH.MODEL_SMALL_WATER_SPLASH, BehaviorIds.bhvWaterDropletSplash)
			ObjectHelpers.obj_mark_for_deletion(o)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end

	if WaterLevel < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_idle_water_wave_loop L92-99
function water_splashes_and_waves_inc.bhv_idle_water_wave_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_copy_pos(o, MarioObject)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, LevelUpdate.gMarioStates[1].waterLevel + 5)

	if not bit32.btest(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMarioParticleFlags), IncludeObjectConstantsH.ACTIVE_PARTICLE_IDLE_WATER_WAVE) then
		buffer.writeu32(MarioObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags, bit32.band(buffer.readu32(MarioObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags), U16(bit32.bnot(IncludeObjectConstantsH.ACTIVE_PARTICLE_IDLE_WATER_WAVE))))
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_water_droplet_splash_init L101-103
function water_splashes_and_waves_inc.bhv_water_droplet_splash_init()
	ObjectHelpers.cur_obj_scale(F32(SrcEngineBehaviorScript.random_float() + 1.5))
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_bubble_splash_init L105-109
function water_splashes_and_waves_inc.bhv_bubble_splash_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const WaterLevel = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	ObjectHelpers.obj_scale_xyz(o, 0.5, 1, 0.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, WaterLevel + 5)
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_shallow_water_splash_init L111-117
function water_splashes_and_waves_inc.bhv_shallow_water_splash_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Have a 1 in 256 chance to spawn the fish particle easter egg.
	-- Strange
	if bit32.band(SrcEngineBehaviorScript.random_u16(), 0xFF) <= 0 then
		const FishObj = ObjectHelpers.spawn_water_droplet(o, water_splashes_and_waves_inc.sWaterDropletFishParams)

		-- blue_fish_seg3_anims_0301C2B0 is segmented address 0x0301C2B0
		ObjectHelpers.obj_init_animation_with_sound(FishObj, Memory.segmented_to_virtual(0x0301C2B0), 0)
	end
end

-- from src/game/behaviors/water_splashes_and_waves.inc.c:bhv_wave_trail_shrink L119-139
function water_splashes_and_waves_inc.bhv_wave_trail_shrink()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const WaterLevel = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	-- Destroy every other water wave to space them out (this is a terrible way of doing it)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and bit32.btest(GameInit.gGlobalTimer, 1) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, WaterLevel + 5)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaveTrailSize, o.header.gfx.scale[1])
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) > 3 then
		-- Shrink the wave
		local WaveTrailSize = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaveTrailSize) - 0.1)

		if WaveTrailSize < 0 then
			WaveTrailSize = 0
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaveTrailSize, WaveTrailSize)
		o.header.gfx.scale[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaveTrailSize)
		o.header.gfx.scale[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaveTrailSize)
	end
end

return water_splashes_and_waves_inc
