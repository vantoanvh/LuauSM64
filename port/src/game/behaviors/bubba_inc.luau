--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bubba.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/bubba_inc.luau:scratch
const Scratch = {
	bhv_bubba_loop_unk1B0 = { 0 },
	bhv_bubba_loop_moveAnglePitch = { 0 },
	bhv_bubba_loop_unk1B2 = { 0 },
	bhv_bubba_loop_moveAngleYaw = { 0 },
}

-- from src/game/behaviors/bubba.inc.c:data
const bubba_inc = {
	-- from src/game/behaviors/bubba.inc.c:sBubbaHitbox L3-13
	sBubbaHitbox = {
		interactType = InteractionH.INTERACT_CLAM_OR_BUBBA,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 99,
		numLootCoins = 0,
		radius = 300,
		height = 200,
		hurtboxRadius = 300,
		hurtboxHeight = 200,
	},
}

Registry.Register("src__game__behaviors__bubba_inc", bubba_inc)

-- from src/game/behaviors/bubba.inc.c:bubba_act_0 L15-46
function bubba_inc.bubba_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp24 = ObjectHelpers.cur_obj_lateral_dist_to_home()

	ObjBehaviors2.treat_far_home_as_mario(2000.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC, S16(ObjBehaviors2.obj_get_pitch_to_home(Sp24)))

	ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4, 5.0, 0.5)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnkFC) ~= 0 then
		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE)) < 800 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnkFC, 0)
		end
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF8, ObjBehaviors2.random_linear_offset(20, 30))
		end

		const HitWall = S32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL))

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnkFC, HitWall)

		if HitWall ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(ObjectHelpers.cur_obj_reflect_move_angle_off_wall()))
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF8) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF8) - 1))
		else
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(ObjBehaviors2.obj_random_fixed_turn(0x2000)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF8, ObjBehaviors2.random_linear_offset(100, 100))
		end
	end
end

-- from src/game/behaviors/bubba.inc.c:bubba_act_1 L48-96
function bubba_inc.bubba_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.treat_far_home_as_mario(2500.0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100) - 1))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BUBBA_CHOMP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100) < 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100) == 20 then
			const Val06 = S16(10000 - S16(TruncS32(F32(20.0 * F32(SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))))))

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC) - Val06))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4, 40.0)
			ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
		else
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk104)))

			ObjectHelpers.cur_obj_rotate_yaw_toward(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE), 400)
			ObjBehaviors2.obj_move_pitch_approach(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC), 400)
		end
	else
		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(marioObject.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) < 0x3000 then
			local Val04 = S16(0x4000 - SrcEngineMathUtil.atan2s(800.0, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) - 800.0)))

			if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) < 0 then
				Val04 = S16(-Val04)
			end

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + Val04))
		else
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk104)))

		if ObjBehaviors2.obj_is_near_to_and_facing_mario(500.0, 3000) ~= 0 and ObjectHelpers.abs_angle_diff(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))) < 3000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnk100, 30)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
		else
			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4, 20.0, 0.5)
		end
	end
end

-- from src/game/behaviors/bubba.inc.c:bhv_bubba_loop L98-164
function bubba_inc.bhv_bubba_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), bit32.bnot(InteractionH.INT_SUBTYPE_EATS_MARIO))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBubbaUnk104, ObjBehaviors2.obj_turn_pitch_toward_mario(120.0, 0))

	if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x1000 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBubbaUnk104) + 0x800), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))) < 0x2000 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 250.0 then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_EATS_MARIO)))
		end

		o.hurtboxRadius = 100.0
	else
		o.hurtboxRadius = 150.0
	end

	ObjectHelpers.cur_obj_update_floor_and_walls()

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		bubba_inc.bubba_act_0()
	elseif action == 1 then
		bubba_inc.bubba_act_1()
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER) then
			const Sp38: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WATER_SPLASH, BehaviorIds.bhvWaterSplash)

			if Sp38 ~= nil then
				ObjectHelpers.obj_scale(Sp38, 3.0)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnk108, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnk10C, 0.0)
		else
			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oBubbaUnk108, 0.0, 4.0)

			const Unk10C = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBubbaUnk10C) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oBubbaUnk108))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnk10C, Unk10C)

			if Unk10C > 1.0 then
				const Sp36 = S16(SrcEngineBehaviorScript.random_u16())

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnk10C, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBubbaUnk10C) - 1.0)
				ObjectHelpers.spawn_object_relative(0, S16(TruncS32(F32(150.0 * SrcEngineMathUtilH.coss(Sp36)))), 0x64, S16(TruncS32(F32(150.0 * SrcEngineMathUtilH.sins(Sp36)))), o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvSmallParticleSnow)
			end
		end

		Scratch.bhv_bubba_loop_unk1B0[1] = buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1B0)
		Scratch.bhv_bubba_loop_moveAnglePitch[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)
		ObjBehaviors2.obj_smooth_turn(Scratch.bhv_bubba_loop_unk1B0, Scratch.bhv_bubba_loop_moveAnglePitch, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AC), F32(0.05), 10, 50, 2000)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1B0, Scratch.bhv_bubba_loop_unk1B0[1])
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, Scratch.bhv_bubba_loop_moveAnglePitch[1])

		Scratch.bhv_bubba_loop_unk1B2[1] = buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1B2)
		Scratch.bhv_bubba_loop_moveAngleYaw[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)
		ObjBehaviors2.obj_smooth_turn(Scratch.bhv_bubba_loop_unk1B2, Scratch.bhv_bubba_loop_moveAngleYaw, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1AE), F32(0.05), 10, 50, 2000)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1B2, Scratch.bhv_bubba_loop_unk1B2[1])
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Scratch.bhv_bubba_loop_moveAngleYaw[1])

		ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4))
	else
		const ForwardVelSquared = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))
		const VelYSquared = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBubbaUnkF4, F32(math.sqrt(F32(ForwardVelSquared + VelYSquared))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjBehaviors2.obj_get_pitch_from_vel())
		ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), 400)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBubbaUnk1B0, 0)
	end

	ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), 400)
	ObjBehaviors2.obj_check_attacks(bubba_inc.sBubbaHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))

	ObjectHelpers.cur_obj_move_standard(78)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) + 150.0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
	end
end

return bubba_inc
