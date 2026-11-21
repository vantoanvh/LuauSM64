--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/manta_ray.inc.c.
]]

const Registry = require("../../../groups/registry")


const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/manta_ray.inc.c:data
const manta_ray_inc = {
	-- from src/game/behaviors/manta_ray.inc.c:sMantaRayTraj L9-19
	sMantaRayTraj = {
		0, -4500, -1380, -40,
		1, -4120, -2240, 740,
		2, -3280, -3080, 1040,
		3, -2240, -3320, 720,
		4, -1840, -3140, -280,
		5, -2320, -2480, -1100,
		6, -3220, -1600, -1360,
		7, -4180, -1020, -1040,
		-1,
	},
	-- from src/game/behaviors/manta_ray.inc.c:sMantaRayHitbox L21-31
	sMantaRayHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 3,
		numLootCoins = 0,
		radius = 210,
		height = 60,
		hurtboxRadius = 200,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__manta_ray_inc", manta_ray_inc)

-- from src/game/behaviors/manta_ray.inc.c:bhv_manta_ray_init L36-41
function manta_ray_inc.bhv_manta_ray_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const ringManager = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvMantaRayRingManager)

	o.parentObj = ringManager
	ObjectHelpers.obj_set_hitbox(o, manta_ray_inc.sMantaRayHitbox)
	ObjectHelpers.cur_obj_scale(2.5)
end

-- from src/game/behaviors/manta_ray.inc.c:manta_ray_move L43-78
function manta_ray_inc.manta_ray_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = S16(o.header.gfx.animInfo.animFrame)

	o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Rom.StaticS16Array("sMantaRayTraj", manta_ray_inc.sMantaRayTraj)
	ObjectHelpers.cur_obj_follow_path(0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMantaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMantaTargetPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetPitch))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMantaTargetYaw)), 0x80))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMantaTargetPitch)), 0x80))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMantaTargetYaw)) ~= S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll) - 91))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll) < -5461.3332 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, TruncS32(-0x4000 / 3))
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll) + 91))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll) > 5461.3332 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, TruncS32(0x4000 / 3))
		end
	end

	ObjectHelpers.cur_obj_set_pos_via_transform()

	if animFrame == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_MOVING_WATER)
	end
end

-- from src/game/behaviors/manta_ray.inc.c:manta_ray_act_spawn_ring L80-103
function manta_ray_inc.manta_ray_act_spawn_ring()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const ringManager = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 300 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	if timer == 0 or timer == 50 or timer == 150 or timer == 200 or timer == 250 then
		const ring = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WATER_RING, BehaviorIds.bhvMantaRayWaterRing)

		buffer.writei32(ring.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writei32(ring.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + 0x4000))
		buffer.writef32(ring.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(200.0 * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)))
		buffer.writef32(ring.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 10.0) + F32(200.0 * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))))
		buffer.writef32(ring.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(200.0 * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)))
		buffer.writei32(ring.rawData, IncludeObjectFieldsH.oWaterRingIndex, buffer.readi32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex))

		buffer.writei32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex, S32(buffer.readi32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex) + 1))

		if buffer.readi32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex) > 10000 then
			buffer.writei32(ringManager.rawData, IncludeObjectFieldsH.oWaterRingMgrNextRingIndex, 0)
		end
	end
end

-- from src/game/behaviors/manta_ray.inc.c:bhv_manta_ray_loop L108-130
function manta_ray_inc.bhv_manta_ray_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MANTA_ACT_SPAWN_RINGS then
		manta_ray_inc.manta_ray_move()
		manta_ray_inc.manta_ray_act_spawn_ring()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterRingSpawnerRingsCollected) == 5 then
			ObjectHelpers.spawn_mist_particles()
			SpawnStarInc.spawn_default_star(-3180.0, -3600.0, 120.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MANTA_ACT_NO_RINGS)
		end
	elseif action == IncludeObjectConstantsH.MANTA_ACT_NO_RINGS then
		manta_ray_inc.manta_ray_move()
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

return manta_ray_inc
