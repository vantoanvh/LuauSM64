--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/triplet_butterfly.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

-- from src/game/behaviors/triplet_butterfly.inc.c:TripletButterflyActivationData
export type TripletButterflyActivationData = {
	model: number,
	behavior: number?,
	scale: number,
}

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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/triplet_butterfly.inc.c:data
const triplet_butterfly_inc = {
	-- from src/game/behaviors/triplet_butterfly.inc.c:sTripletButterflyExplodeHitbox L3-13
	sTripletButterflyExplodeHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 50,
		damageOrCoinValue = 2,
		health = 1,
		numLootCoins = 0,
		radius = 100,
		height = 50,
		hurtboxRadius = 100,
		hurtboxHeight = 50,
	},
	-- from src/game/behaviors/triplet_butterfly.inc.c:sTripletButterflyActivationData L21-24
	sTripletButterflyActivationData = {
		{ model = IncludeModelIdsH.MODEL_BOWLING_BALL, behavior = nil, scale = 0.5 },
		{ model = IncludeModelIdsH.MODEL_1UP, behavior = 0x13003FDC --[[ bhv1UpWalking ]], scale = 1.0 },
	},
}

Registry.Register("src__game__behaviors__triplet_butterfly_inc", triplet_butterfly_inc)

-- from src/game/behaviors/triplet_butterfly.inc.c:TripletButterflyActivationData (zero-filled constructor)
function triplet_butterfly_inc.new_TripletButterflyActivationData(): TripletButterflyActivationData
	return { model = 0, behavior = nil, scale = 0 } :: TripletButterflyActivationData
end

-- from src/game/behaviors/triplet_butterfly.inc.c:triplet_butterfly_act_init L26-55
function triplet_butterfly_inc.triplet_butterfly_act_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ButterflySpawnType = bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.TRIPLET_BUTTERFLY_BP_SPAWN_TYPE_MASK)

	if ButterflySpawnType ~= IncludeObjectConstantsH.TRIPLET_BUTTERFLY_BP_SPAWN_TYPE_SPAWNER or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200.0 then
		if ButterflySpawnType == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_BP_SPAWN_TYPE_SPAWNER then
			for Index = 1, 2 do
				ObjectHelpers.spawn_object_relative(S16(Index), 0, 0, 0, o, IncludeModelIdsH.MODEL_BUTTERFLY, BehaviorIds.bhvTripletButterfly)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflySelectedButterfly, SrcEngineBehaviorScript.random_u16() % 3)
		end

		-- Glitch noted in the C source (its description is not ported)
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTripletButterflySelectedButterfly) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType, IncludeObjectConstantsH.TRIPLET_BUTTERFLY_TYPE_SPAWN_1UP)
		elseif bit32.btest(buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.TRIPLET_BUTTERFLY_BP_NO_BOMBS) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType, IncludeObjectConstantsH.TRIPLET_BUTTERFLY_TYPE_NORMAL)
		end
		-- Default butterfly type is TRIPLET_BUTTERFLY_TYPE_EXPLODES

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_WANDER)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflyBaseYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * (0x10000 // 3))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyBaseYaw) + ObjBehaviors2.random_linear_offset(0, 0x5555)))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflySpeed, ObjBehaviors2.random_linear_offset(15, 15))

		ObjectHelpers.cur_obj_unhide()
	end
end

-- from src/game/behaviors/triplet_butterfly.inc.c:triplet_butterfly_act_wander L57-87
function triplet_butterfly_inc.triplet_butterfly_act_wander()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1500.0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oTripletButterflySpeed, 8.0, 0.5)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetYaw, ObjectHelpers.cur_obj_angle_to_home())
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetYaw, S32(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyBaseYaw))))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 110 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200.0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) > IncludeObjectConstantsH.TRIPLET_BUTTERFLY_TYPE_NORMAL then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_ACTIVATE)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflySpeed, 0.0)
			end
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + ObjBehaviors2.random_linear_offset(50, 50)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetPitch, -0x2000)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetPitch, 0x2000)
		end

		ObjBehaviors2.obj_move_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetPitch)), 400)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyTargetYaw)), S16(ObjBehaviors2.random_linear_offset(400, 800)))
	end
end

-- from src/game/behaviors/triplet_butterfly.inc.c:triplet_butterfly_act_activate L89-117
function triplet_butterfly_inc.triplet_butterfly_act_activate()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyModel) == 0 then
			ObjectHelpers.spawn_object_relative_with_scale(0, 0, -40, 0, 1.5, o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyModel, triplet_butterfly_inc.sTripletButterflyActivationData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) + 1].model)
			ObjectHelpers.cur_obj_set_model(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyModel))
			ObjectHelpers.obj_set_billboard(o)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale) >= triplet_butterfly_inc.sTripletButterflyActivationData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) + 1].scale then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) ~= IncludeObjectConstantsH.TRIPLET_BUTTERFLY_TYPE_EXPLODES then
				ObjectHelpers.spawn_object(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyModel), triplet_butterfly_inc.sTripletButterflyActivationData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) + 1].behavior :: number)
				ObjectHelpers.obj_mark_for_deletion(o)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_EXPLODE)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 100.0)
			end
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale) + F32(triplet_butterfly_inc.sTripletButterflyActivationData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) + 1].scale / 30.0))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyType) == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_TYPE_EXPLODES then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, F32(250.0 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale)))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset))
		end
	end
end

-- from src/game/behaviors/triplet_butterfly.inc.c:triplet_butterfly_act_explode L119-143
function triplet_butterfly_inc.triplet_butterfly_act_explode()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjBehaviors2.obj_check_attacks(triplet_butterfly_inc.sTripletButterflyExplodeHitbox, -1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == -1 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 158 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset))
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_EXPLOSION, BehaviorIds.bhvExplosion)
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 120 then
			const CosPhase: number = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScalePhase))
			local ScaleIncrease = F32(F32(0.04) * CosPhase)

			if ScaleIncrease > 0.0 then
				ScaleIncrease = F32(ScaleIncrease * 4.5)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScalePhase, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScalePhase) + 10000)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScalePhase, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScalePhase) + 4000)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale) + ScaleIncrease)
		end

		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oTripletButterflySpeed, 20.0, 1.0)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 800)
		ObjBehaviors2.obj_turn_pitch_toward_mario(-100.0, 800)
	end
end

-- from src/game/behaviors/triplet_butterfly.inc.c:bhv_triplet_butterfly_update L145-166
function triplet_butterfly_inc.bhv_triplet_butterfly_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_INIT then
		triplet_butterfly_inc.triplet_butterfly_act_init()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_WANDER then
		triplet_butterfly_inc.triplet_butterfly_act_wander()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_ACTIVATE then
		triplet_butterfly_inc.triplet_butterfly_act_activate()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TRIPLET_BUTTERFLY_ACT_EXPLODE then
		triplet_butterfly_inc.triplet_butterfly_act_explode()
	end

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflyScale))
	ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTripletButterflySpeed))
	ObjectHelpers.cur_obj_move_standard(78)
end

return triplet_butterfly_inc
