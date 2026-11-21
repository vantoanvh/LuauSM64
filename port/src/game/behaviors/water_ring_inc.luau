--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_ring.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SpawnStarInc = require("./spawn_star_inc")

const water_ring_inc = {}

Registry.Register("src__game__behaviors__water_ring_inc", water_ring_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_calc_mario_dist L3-11
function water_ring_inc.water_ring_calc_mario_dist(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	const MarioDistX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - MarioObject.header.gfx.pos[1])
	const MarioDistY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(MarioObject.header.gfx.pos[2] + 80))
	const MarioDistZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - MarioObject.header.gfx.pos[3])

	const MarioDistInFront = F32(F32(F32(MarioDistX * buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalX)) + F32(MarioDistY * buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalY))) + F32(MarioDistZ * buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalZ)))

	return MarioDistInFront
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_init L13-35
function water_ring_inc.water_ring_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation(0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseX, S32(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4096)) + 0x1000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseY, S32(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4096)) + 0x1000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseZ, S32(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4096)) + 0x1000))

	-- This normal calculation assumes a facing yaw of 0, which is not the case
	-- for the manta ray rings. It also errs by multiplying the normal X by -1.
	-- This cause the ring's orientation for the purposes of collision to be
	-- different than the graphical orientation, which means that Mario won't
	-- necessarily collect a ring even if he appears to swim through it.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalX, F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))) * -1)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalY, SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingNormalZ, SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingMarioDistInFront, water_ring_inc.water_ring_calc_mario_dist())

	-- Adding this code will alter the ring's graphical orientation to align with the faulty
	-- collision orientation:
	--
	-- o->oFaceAngleYaw = 0;
	-- o->oFaceAngleRoll *= -1;
end

-- from src/game/behaviors/water_ring.inc.c:bhv_jet_stream_water_ring_init L37-42
function water_ring_inc.bhv_jet_stream_water_ring_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	water_ring_inc.water_ring_init()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 70)
	ObjectHelpers.cur_obj_init_animation(0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x8000)
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_check_collection L44-81
function water_ring_inc.water_ring_check_collection(avgScale: number, ringManager: GroupsTypesHPlus3.Object)
	avgScale = F32(avgScale)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const MarioDistInFront = water_ring_inc.water_ring_calc_mario_dist()

	if ObjBehaviors.is_point_close_to_object(o, MarioObject.header.gfx.pos[1], MarioObject.header.gfx.pos[2] + 80, MarioObject.header.gfx.pos[3], TruncS32(F32((avgScale + 0.2) * 120))) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingMarioDistInFront, MarioDistInFront)
		return
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterRingMarioDistInFront) * MarioDistInFront) < 0 then
		const RingSpawner = o.parentObj

		if RingSpawner ~= nil then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingIndex) == buffer.readi32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrLastRingCollected) + 1 or buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) == 0 then
				buffer.writei32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected, S32(buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) + 1))

				if buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) < 6 then
					ObjBehaviors.spawn_orange_number(buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected), 0, -40, 0)
					Audio.play_sound(IncludeSoundsH.SOUND_MENU_COLLECT_SECRET + bit32.lshift(bit32.band(buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected), 0xFF) - 1, 16), Audio.gGlobalSoundSource)
				end

				buffer.writei32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrLastRingCollected, buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingIndex))
			else
				buffer.writei32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected, 0)
			end
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_RING_ACT_COLLECTED)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingMarioDistInFront, MarioDistInFront)
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_set_scale L83-90
function water_ring_inc.water_ring_set_scale(avgScale: number)
	avgScale = F32(avgScale)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseX)) * 0.1 + avgScale)
	o.header.gfx.scale[2] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseY)) * 0.5 + avgScale)
	o.header.gfx.scale[3] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseZ)) * 0.1 + avgScale)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseX, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseX) + 0x1700))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseY, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseY) + 0x1700))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseZ, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingScalePhaseZ) + 0x1700))
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_act_collected L92-105
function water_ring_inc.water_ring_act_collected()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const AvgScale = F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0.2 + buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterRingAvgScale))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 10))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
	end

	water_ring_inc.water_ring_set_scale(AvgScale)
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_act_not_collected L107-135
function water_ring_inc.water_ring_act_not_collected()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const AvgScale = F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 225 * 3 + 0.5)
	const RingSpawner = o.parentObj :: GroupsTypesHPlus3.Object
	const RingManager = RingSpawner.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 225 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 2))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 3 then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end

	water_ring_inc.water_ring_check_collection(AvgScale, RingManager)
	water_ring_inc.water_ring_set_scale(AvgScale)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 10)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x100))
	ObjBehaviors.set_object_visibility(o, 5000)

	if buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) == 4 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingIndex) == buffer.readi32(RingManager.rawData, IncludeObjectFieldsH.oWaterRingMgrLastRingCollected) + 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(TruncS32(F32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 200) + 50))))
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingAvgScale, AvgScale)
end

-- from src/game/behaviors/water_ring.inc.c:bhv_jet_stream_water_ring_loop L137-147
function water_ring_inc.bhv_jet_stream_water_ring_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.WATER_RING_ACT_NOT_COLLECTED then
		water_ring_inc.water_ring_act_not_collected()
	elseif Action == IncludeObjectConstantsH.WATER_RING_ACT_COLLECTED then
		water_ring_inc.water_ring_act_collected()
	end
end

-- from src/game/behaviors/water_ring.inc.c:spawn_manta_ray_ring_manager L149-152
function water_ring_inc.spawn_manta_ray_ring_manager()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const RingManager = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvMantaRayRingManager)

	o.parentObj = RingManager
end

-- from src/game/behaviors/water_ring.inc.c:water_ring_spawner_act_inactive L154-176
function water_ring_inc.water_ring_spawner_act_inactive()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const CurrentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 300 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	const Timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	if Timer == 0 or Timer == 50 or Timer == 150 or Timer == 200 or Timer == 250 then
		const WaterRing = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WATER_RING, BehaviorIds.bhvJetStreamWaterRing)

		buffer.writei32(WaterRing.rawData, IncludeObjectFieldsH.oWaterRingIndex, buffer.readi32(CurrentObj.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex))
		buffer.writei32(CurrentObj.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex, S32(buffer.readi32(CurrentObj.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex) + 1))

		if buffer.readi32(CurrentObj.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex) > 10000 then
			buffer.writei32(CurrentObj.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex, 0)
		end
	end
end

-- from src/game/behaviors/water_ring.inc.c:bhv_jet_stream_ring_spawner_loop L178-193
function water_ring_inc.bhv_jet_stream_ring_spawner_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.JS_RING_SPAWNER_ACT_ACTIVE then
		water_ring_inc.water_ring_spawner_act_inactive()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) == 5 then
			ObjectHelpers.spawn_mist_particles()
			SpawnStarInc.spawn_default_star(3400, -3200, -500)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.JS_RING_SPAWNER_ACT_INACTIVE)
		end
	elseif Action == IncludeObjectConstantsH.JS_RING_SPAWNER_ACT_INACTIVE then
		-- Empty in the C source.
	end
end

-- from src/game/behaviors/water_ring.inc.c:bhv_manta_ray_water_ring_init L195-198
function water_ring_inc.bhv_manta_ray_water_ring_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	water_ring_inc.water_ring_init()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 150)
end

-- from src/game/behaviors/water_ring.inc.c:manta_water_ring_act_not_collected L200-226
function water_ring_inc.manta_water_ring_act_not_collected()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local AvgScale = F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 50) * 1.3 + 0.1)
	const RingSpawner = o.parentObj :: GroupsTypesHPlus3.Object
	const RingManager = RingSpawner.parentObj :: GroupsTypesHPlus3.Object

	if AvgScale > 1.3 then
		AvgScale = F32(1.3)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 2))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 3 then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end

	water_ring_inc.water_ring_check_collection(AvgScale, RingManager)
	water_ring_inc.water_ring_set_scale(AvgScale)
	ObjBehaviors.set_object_visibility(o, 5000)

	if buffer.readi32(RingSpawner.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) == 4 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingIndex) == buffer.readi32(RingManager.rawData, IncludeObjectFieldsH.oWaterRingMgrLastRingCollected) + 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(TruncS32(F32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 200) + 50))))
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterRingAvgScale, AvgScale)
end

-- from src/game/behaviors/water_ring.inc.c:bhv_manta_ray_water_ring_loop L228-238
function water_ring_inc.bhv_manta_ray_water_ring_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.WATER_RING_ACT_NOT_COLLECTED then
		water_ring_inc.manta_water_ring_act_not_collected()
	elseif Action == IncludeObjectConstantsH.WATER_RING_ACT_COLLECTED then
		water_ring_inc.water_ring_act_collected()
	end
end

return water_ring_inc
