--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/klepto.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Interaction = require("../interaction")
const LevelUpdate = require("../level_update")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const SpawnStarInc = require("./spawn_star_inc")

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

-- from src/game/behaviors/klepto_inc.luau:scratch
const Scratch = {
	klepto_circle_target_turnAmount = { 0 },
}

-- from src/game/behaviors/klepto.inc.c:data
const klepto_inc = {
	-- from src/game/behaviors/klepto.inc.c:sKleptoHitbox L3-13
	sKleptoHitbox = {
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 160,
		height = 250,
		hurtboxRadius = 80,
		hurtboxHeight = 200,
	},
	-- from src/game/behaviors/klepto.inc.c:sKleptoTargetPositions L15-19
	sKleptoTargetPositions = { { 2200.0, 1250.0, -2820.0 }, { -6200.0, 1250.0, -2800.0 }, { -6200.0, 1250.0, 1150.0 } },
	-- from src/game/behaviors/klepto.inc.c:sKleptoAttackHandlers L21-21
	sKleptoAttackHandlers = { 2, 2, 5, 5, 2, 2 },
}

Registry.Register("src__game__behaviors__klepto_inc", klepto_inc)

-- from src/game/behaviors/klepto.inc.c:klepto_target_mario L23-28
function klepto_inc.klepto_target_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget, ObjectHelpers.lateral_dist_between_objects(marioObj, o))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0, S16(ObjBehaviors2.obj_turn_pitch_toward_mario(250.0, 0)))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, -60)
end

-- from src/game/behaviors/klepto.inc.c:klepto_set_and_check_if_anim_at_end L30-46
function klepto_inc.klepto_set_and_check_if_anim_at_end(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const soundStateID = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID)

	if soundStateID == 6 then
		ObjBehaviors2.cur_obj_set_anim_if_at_end(5)
	elseif soundStateID == 5 then
		if ObjBehaviors2.cur_obj_set_anim_if_at_end(0) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
			o.header.gfx.animInfo.animFrame = 9
		end
	else
		if ObjectHelpers.cur_obj_check_anim_frame(9) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
		end

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/klepto.inc.c:klepto_anim_dive L48-76
function klepto_inc.klepto_anim_dive()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE) > 0 then
		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0) < -400 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, 0)
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID) == 0 then
				if ObjectHelpers.cur_obj_check_anim_frame(9) ~= 0 then
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
					ObjectHelpers.cur_obj_init_animation_with_sound(6)
				end
			else
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE) - 1))

				if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE) == 0 then
					buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, S16(-ObjBehaviors2.random_linear_offset(60, 60)))
				end
			end

			ObjBehaviors2.obj_move_pitch_approach(400, 10)
		end
	else
		ObjBehaviors2.obj_move_pitch_approach(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0), 600)

		if klepto_inc.klepto_set_and_check_if_anim_at_end() ~= 0 then
			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE) ~= 0 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE) + 1))
			elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0) > -100 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, S16(ObjBehaviors2.random_linear_offset(60, 60)))
			end
		end
	end

	ObjBehaviors2.obj_face_pitch_approach(0, 1000)
end

-- from src/game/behaviors/klepto.inc.c:bhv_klepto_init L78-92
function klepto_inc.bhv_klepto_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_STAR)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

		if bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_CAP)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_WAIT_FOR_MARIO)
		end
	end
end

-- from src/game/behaviors/klepto.inc.c:klepto_change_target L94-126
function klepto_inc.klepto_change_target()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local newTarget = 0

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2000.0 then
		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
		local minTargetDist = 99999.0

		for i = 0, 2 do
			const dx = F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosX) - klepto_inc.sKleptoTargetPositions[i + 1][1])
			const dz = F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosZ) - klepto_inc.sKleptoTargetPositions[i + 1][3])
			const targetDist = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

			if targetDist < minTargetDist then
				minTargetDist = targetDist
				newTarget = i
			end
		end
	else
		newTarget = SrcEngineBehaviorScript.random_u16() % 3
	end

	const targetNumber = buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoTargetNumber)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoUnkF8, 400 * ObjectHelpers.absi(newTarget - targetNumber))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoTargetNumber, S16(newTarget))

	const newTargetNumber = buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoTargetNumber)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, klepto_inc.sKleptoTargetPositions[newTargetNumber + 1][1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, klepto_inc.sKleptoTargetPositions[newTargetNumber + 1][2] + buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoUnkF8))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, klepto_inc.sKleptoTargetPositions[newTargetNumber + 1][3])

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoUnkFC, ObjectHelpers.cur_obj_lateral_dist_to_home() / 2.0)
end

-- from src/game/behaviors/klepto.inc.c:klepto_circle_target L128-159
function klepto_inc.klepto_circle_target(radius: number, targetSpeed: number)
	radius = F32(radius)
	targetSpeed = F32(targetSpeed)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) ~= IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_NOTHING and ((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2000.0) or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= buffer.readi32(o.rawData, IncludeObjectFieldsH.oKleptoTimeUntilTargetChange)) then
		klepto_inc.klepto_change_target()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKleptoTimeUntilTargetChange, ObjBehaviors2.random_linear_offset(300, 300))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_APPROACH_TARGET_HOLDING)
	else
		local turnAmount = S16(0x4000 - SrcEngineMathUtil.atan2s(radius, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget) - radius)))
		local accel = F32(0.05)

		if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget)) < 0 then
			turnAmount = S16(-turnAmount)
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget) + turnAmount))
		klepto_inc.klepto_anim_dive()

		const angleDiff = ObjectHelpers.abs_angle_diff(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
		turnAmount = S16(TruncS32(F32(angleDiff * F32(F32(0.03) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoSpeed)))))

		Scratch.klepto_circle_target_turnAmount[1] = turnAmount
		ObjBehaviors2.clamp_s16(Scratch.klepto_circle_target_turnAmount, 400, 700)
		turnAmount = Scratch.klepto_circle_target_turnAmount[1]

		ObjBehaviors2.obj_rotate_yaw_and_bounce_off_walls(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), turnAmount)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoSpeed) > 50.0 then
			accel = 2.0
		end

		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oKleptoSpeed, targetSpeed, accel)
	end
end

-- from src/game/behaviors/klepto.inc.c:klepto_approach_target L161-175
function klepto_inc.klepto_approach_target(targetSpeed: number)
	targetSpeed = F32(targetSpeed)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget) < 1800.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_CIRCLE_TARGET_HOLDING)
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoUnkFC) > 0.0 then
			const unkFC = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoUnkFC) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoUnkFC, unkFC)

			if unkFC <= 0.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoUnkF8))
			end
		end

		klepto_inc.klepto_anim_dive()
		ObjBehaviors2.obj_rotate_yaw_and_bounce_off_walls(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), 400)

		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oKleptoSpeed, targetSpeed, F32(0.05))
	end
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_wait_for_mario L177-187
function klepto_inc.klepto_act_wait_for_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget) < 1000.0 then
		klepto_inc.klepto_target_mario()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget) < 1000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_TURN_TOWARD_MARIO)
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))
		end
	end

	klepto_inc.klepto_circle_target(300.0, 40.0)
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_turn_toward_mario L189-205
function klepto_inc.klepto_act_turn_toward_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	klepto_inc.klepto_target_mario()

	if klepto_inc.klepto_set_and_check_if_anim_at_end() ~= 0 and ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget) > 800.0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) < 0x800 and buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0) < 0x400 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KLEPTO1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_DIVE_AT_MARIO)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))

		ObjectHelpers.cur_obj_init_animation_with_sound(3)
	end

	klepto_inc.klepto_circle_target(1000.0, 40.0)
	ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 1000)
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_dive_at_mario L207-256
function klepto_inc.klepto_act_dive_at_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oKleptoSpeed, 60.0, 10.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID) == 2 then
		if ObjectHelpers.cur_obj_check_anim_frame(11) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
		end

		if ObjBehaviors2.cur_obj_set_anim_if_at_end(0) ~= 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) ~= IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_NOTHING then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_CIRCLE_TARGET_HOLDING)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oKleptoTimeUntilTargetChange, 0)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_WAIT_FOR_MARIO)
			end
		end
	else
		const dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID) == 3 then
			ObjBehaviors2.cur_obj_set_anim_if_at_end(4)
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 0.0 and dy > 200.0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(2)
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0, -0x3000)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) == IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_NOTHING then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0, S16(ObjBehaviors2.obj_turn_pitch_toward_mario(0.0, 0)))
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))

				if dy < 160.0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
				end
			end

			if LevelUpdate.gMarioStates[1].action ~= IncludeSm64H.ACT_SLEEPING and not bit32.btest(LevelUpdate.gMarioStates[1].action, bit32.bor(IncludeSm64H.ACT_FLAG_SHORT_HITBOX, IncludeSm64H.ACT_FLAG_BUTT_OR_STOMACH_SLIDE)) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200.0 and dy > 50.0 and dy < 90.0 and Interaction.mario_lose_cap_to_enemy(1) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_CAP)
			end
		end
	end

	ObjBehaviors2.obj_move_pitch_approach(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0), 600)
	ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), 600)
	ObjBehaviors2.obj_rotate_yaw_and_bounce_off_walls(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), 600)
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_struck_by_mario L258-276
function klepto_inc.klepto_act_struck_by_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	ObjBehaviors2.obj_face_pitch_approach(0, 800)
	ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000), 800)
	ObjBehaviors2.obj_face_roll_approach(0, 800)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_RETREAT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(-ObjBehaviors2.obj_get_pitch_from_vel()))

		const forwardVel = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
		const velY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoSpeed, F32(math.sqrt(F32(F32(forwardVel * forwardVel) + F32(velY * velY)))))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 500.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	end
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_retreat L278-295
function klepto_inc.klepto_act_retreat()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(0)

	ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oKleptoSpeed, 40.0, 10.0)

	ObjBehaviors2.obj_move_pitch_approach(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0), 1000)

	ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), 1000)
	ObjBehaviors2.obj_rotate_yaw_and_bounce_off_walls(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), 600)

	if ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 1000) ~= 0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_RESET_POSITION)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, 1500.0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1AE, -100)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		ObjectHelpers.cur_obj_become_tangible()
	end
end

-- from src/game/behaviors/klepto.inc.c:klepto_act_reset_position L297-316
function klepto_inc.klepto_act_reset_position()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 300 then
		klepto_inc.klepto_circle_target(300.0, 20.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, -2000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, -1000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget, 9999.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, 9999.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > 5000.0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		else
			klepto_inc.klepto_approach_target(20.0)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_WAIT_FOR_MARIO)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoStartPosZ))
	end
end

-- from src/game/behaviors/klepto.inc.c:obj_set_speed_to_zero L318-320
function klepto_inc.obj_set_speed_to_zero()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
end

-- from src/game/behaviors/klepto.inc.c:bhv_klepto_update L322-389
function klepto_inc.bhv_klepto_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget, ObjectHelpers.cur_obj_lateral_dist_to_home())
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoUnk1B0, S16(ObjBehaviors2.obj_get_pitch_to_home(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoDistanceToTarget))))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget, S16(ObjectHelpers.cur_obj_angle_to_home()))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.KLEPTO_ACT_STRUCK_BY_MARIO then
		klepto_inc.klepto_act_struck_by_mario()
	else
		ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKleptoSpeed))

		const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if action == IncludeObjectConstantsH.KLEPTO_ACT_CIRCLE_TARGET_HOLDING then
			klepto_inc.klepto_circle_target(300.0, 40.0)
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_APPROACH_TARGET_HOLDING then
			klepto_inc.klepto_approach_target(50.0)
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_WAIT_FOR_MARIO then
			klepto_inc.klepto_act_wait_for_mario()
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_TURN_TOWARD_MARIO then
			klepto_inc.klepto_act_turn_toward_mario()
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_DIVE_AT_MARIO then
			klepto_inc.klepto_act_dive_at_mario()
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_RESET_POSITION then
			klepto_inc.klepto_act_reset_position()
		elseif action == IncludeObjectConstantsH.KLEPTO_ACT_RETREAT then
			klepto_inc.klepto_act_retreat()
		end

		if ObjBehaviors2.obj_handle_attacks(klepto_inc.sKleptoHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction), klepto_inc.sKleptoAttackHandlers) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KLEPTO2)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) == IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_CAP then
				SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO)
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_MARIOS_CAP, BehaviorIds.bhvNormalCap)
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) == IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_STAR then
				SpawnStarInc.spawn_default_star(-5550.0, 300.0, -930.0)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.KLEPTO_ANIM_STATE_HOLDING_NOTHING)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KLEPTO_ACT_STRUCK_BY_MARIO)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -2.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))

			ObjectHelpers.cur_obj_become_intangible()
		elseif LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_SLEEPING or bit32.btest(LevelUpdate.gMarioStates[1].action, bit32.bor(IncludeSm64H.ACT_FLAG_SHORT_HITBOX, IncludeSm64H.ACT_FLAG_BUTT_OR_STOMACH_SLIDE)) then
			ObjectHelpers.cur_obj_become_intangible()
		else
			ObjectHelpers.cur_obj_become_tangible()
		end
	end

	ObjBehaviors2.obj_roll_to_match_yaw_turn(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKleptoYawToTarget), 0x3000, 600)
	ObjectHelpers.cur_obj_move_standard(78)
end

return klepto_inc
