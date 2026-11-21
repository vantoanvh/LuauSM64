--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/fly_guy.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
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
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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

-- from src/game/behaviors/fly_guy_inc.luau:scratch
const Scratch = {
	fly_guy_act_idle_scale = buffer.create(4),
	fly_guy_act_shoot_fire_scaleVel = { 0 },
	fly_guy_act_shoot_fire_movePitch = { 0 },
}

-- from src/game/behaviors/fly_guy.inc.c:data
const fly_guy_inc = {
	-- from src/game/behaviors/fly_guy.inc.c:sFlyGuyHitbox L9-19
	sFlyGuyHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 2,
		radius = 70,
		height = 60,
		hurtboxRadius = 40,
		hurtboxHeight = 50,
	},
	-- from src/game/behaviors/fly_guy.inc.c:sFlyGuyJitterAmounts L24-24
	sFlyGuyJitterAmounts = { 0x1000, -0x2000, 0x2000 },
}

Registry.Register("src__game__behaviors__fly_guy_inc", fly_guy_inc)

-- from src/game/behaviors/fly_guy.inc.c:fly_guy_act_idle L30-54
function fly_guy_inc.fly_guy_act_idle()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)

	buffer.writef32(Scratch.fly_guy_act_idle_scale, 0, o.header.gfx.scale[1])
	const Reached: number = ObjBehaviors2.approach_f32_ptr(Scratch.fly_guy_act_idle_scale, 0, F32(1.5), F32(0.02))
	o.header.gfx.scale[1] = buffer.readf32(Scratch.fly_guy_act_idle_scale, 0)

	if Reached ~= 0 then
		-- If we are >2000 units from home or Mario is <2000 units from us
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
			-- Turn toward home or Mario
			ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x300)

			if ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x300) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_APPROACH_MARIO)
			end
		else
			-- Randomly enter the approach mario action - but this doesn't
			-- really do anything since we come right back to idle
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer) >= 3 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer) == bit32.band(SrcEngineBehaviorScript.random_u16(), 1) + 2 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_APPROACH_MARIO)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyUnusedJitter, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + fly_guy_inc.sFlyGuyJitterAmounts[buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer) + 1])
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyIdleTimer) + 1)
			end
		end
	end
end

-- from src/game/behaviors/fly_guy.inc.c:fly_guy_act_approach_mario L60-89
function fly_guy_inc.fly_guy_act_approach_mario()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- If we are >2000 units from home or Mario is <2000 units from us
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
		ObjBehaviors2.obj_forward_vel_approach(10, F32(0.5))

		-- Turn toward home or Mario
		ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)

		-- If facing toward mario and we are either near mario laterally or
		-- far above him
		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) < 0x2000 and (F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY)) > 400 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 400) then
			-- Either shoot fire or lunge
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.FLY_GUY_BP_GENERIC and SrcEngineBehaviorScript.random_u16() % 2 ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_SHOOT_FIRE)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlyGuyScaleVel, 0.06)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_LUNGE)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeTargetPitch, ObjBehaviors2.obj_turn_pitch_toward_mario(-200, 0))

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25 * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeTargetPitch)))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 25 * -SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeTargetPitch)))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeYDecel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) / 30)
			end
		end
	elseif ObjBehaviors2.obj_forward_vel_approach(0, F32(0.2)) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_IDLE)
	end
end

-- from src/game/behaviors/fly_guy.inc.c:fly_guy_act_lunge L95-129
function fly_guy_inc.fly_guy_act_lunge()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
		-- Lunge downward

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeYDecel))

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), 0x800)
		ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyLungeTargetPitch)), 0x400)

		-- Possible values: {-0x1000, 0x0000, 0x1000}
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyTargetRoll, 0x1000 * S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 3))) - 0x1000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	else
		-- Twirl back upward

		ObjBehaviors2.obj_face_pitch_approach(0, 0x100)
		ObjBehaviors2.obj_face_roll_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyTargetRoll)), 300)

		-- Twirl in a spiral with curvature proportional to oFaceAngleRoll
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) / 4))
		ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 0x800)

		-- Continue moving upward until at least 200 units above mario
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) + 200) then
			ObjBehaviors2.obj_y_vel_approach(20, F32(0.5))
		elseif ObjBehaviors2.obj_y_vel_approach(0, F32(0.5)) ~= 0 then
			-- Wait until roll is zero
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_APPROACH_MARIO)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyTargetRoll, 0)
		end
	end
end

-- from src/game/behaviors/fly_guy.inc.c:fly_guy_act_shoot_fire L134-174
function fly_guy_inc.fly_guy_act_shoot_fire()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)

	if ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x800) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

		-- Increase scale by 0.06, 0.05, ..., -0.03. Then wait ~8 frames, then
		-- starting moving scale by 0.05 each frame toward 1.1. The first time
		-- it becomes below 1.2 during this latter portion, shoot fire.
		Scratch.fly_guy_act_shoot_fire_scaleVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlyGuyScaleVel)
		const ScaleStatus: number = ObjBehaviors2.obj_grow_then_shrink(Scratch.fly_guy_act_shoot_fire_scaleVel, F32(1.2), F32(1.1))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlyGuyScaleVel, Scratch.fly_guy_act_shoot_fire_scaleVel[1])

		if ScaleStatus ~= 0 then
			if ScaleStatus < 0 then
				-- We have reached scale 1.1
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FLY_GUY_ACT_IDLE)
			else
				-- We have reached below scale 1.2 in the shrinking portion
				Scratch.fly_guy_act_shoot_fire_movePitch[1] = ObjBehaviors2.obj_turn_pitch_toward_mario(0, 0)

				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_FLAME_BLOWN)
				ObjBehaviors2.clamp_s16(Scratch.fly_guy_act_shoot_fire_movePitch, 0x800, 0x3000)

				ObjBehaviors2.obj_spit_fire(0, 38, 20, F32(2.5), IncludeModelIdsH.MODEL_RED_FLAME_SHADOW, 25, 20, Scratch.fly_guy_act_shoot_fire_movePitch[1])
			end
		end
	else
		-- By triggering this repeatedly, we can keep obj_grow_then_shrink
		-- in the "grow" phase. But because oFlyGuyScaleVel continues decreasing
		-- past -0.03, the fly guy shrinks more than he is supposed to. We can
		-- arbitrarily decrease the fly guy's scale in this way.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/fly_guy.inc.c:bhv_fly_guy_update L179-217
function fly_guy_inc.bhv_fly_guy_update()
	const o = ObjectListProcessor.gCurrentObject

	-- PARTIAL_UPDATE (appears in non-roomed levels)

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_KOOPA_FLYGUY_DEATH)

		ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
		ObjBehaviors2.treat_far_home_as_mario(2000)
		ObjectHelpers.cur_obj_update_floor_and_walls()

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 6)
		end

		-- Oscillate up and down
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlyGuyOscTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyOscTimer) + 1)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(SrcEngineMathUtilH.coss(0x400 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlyGuyOscTimer)) * 1.5))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FLY_GUY_ACT_IDLE then
			fly_guy_inc.fly_guy_act_idle()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FLY_GUY_ACT_APPROACH_MARIO then
			fly_guy_inc.fly_guy_act_approach_mario()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FLY_GUY_ACT_LUNGE then
			fly_guy_inc.fly_guy_act_lunge()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FLY_GUY_ACT_SHOOT_FIRE then
			fly_guy_inc.fly_guy_act_shoot_fire()
		end

		ObjectHelpers.cur_obj_move_standard(78)
		ObjBehaviors2.obj_check_attacks(fly_guy_inc.sFlyGuyHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	end
end

return fly_guy_inc
