--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/boo.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const ObjectListProcessorH = require("../object_list_processor_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const InteractionH = require("../interaction_h")
const Camera = require("../camera")
const SpawnStarInc = require("./spawn_star_inc")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const Audio = require("../../rom/audio_recorder")

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

-- from src/game/behaviors/boo.inc.c:data
const boo_inc = {
	SPAWN_CASTLE_BOO_STAR_REQUIREMENT = 12,
	-- from src/game/behaviors/boo.inc.c:sBooGivingStarHitbox L5-15
	sBooGivingStarHitbox = {
		interactType = 0,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 3,
		numLootCoins = 0,
		radius = 140,
		height = 80,
		hurtboxRadius = 40,
		hurtboxHeight = 60,
	},
	-- from src/game/behaviors/boo.inc.c:sCourtyardBooTripletPositions L18-22
	sCourtyardBooTripletPositions = { { 0, 50, 0 }, { 210, 110, 210 }, { -210, 70, -210 } },
}

Registry.Register("src__game__behaviors__boo_inc", boo_inc)

-- from src/game/behaviors/boo.inc.c:boo_stop L24-28
function boo_inc.boo_stop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_init L30-32
function boo_inc.bhv_boo_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooInitialMoveYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
end

-- from src/game/behaviors/boo.inc.c:boo_should_be_stopped L34-52
function boo_inc.boo_should_be_stopped(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvMerryGoRoundBigBoo) ~= 0 or ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvMerryGoRoundBoo) ~= 0 then
		if ObjectListProcessor.gMarioOnMerryGoRound == IncludePRUltratypesH.FALSE then
			return IncludePRUltratypesH.TRUE
		else
			return IncludePRUltratypesH.FALSE
		end
	else
		if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
			return IncludePRUltratypesH.TRUE
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom) == 10 and bit32.btest(ObjectListProcessor.gTimeStopState, ObjectListProcessorH.TIME_STOP_MARIO_OPENED_DOOR) then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/boo.inc.c:boo_should_be_active L54-81
function boo_inc.boo_should_be_active(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const activationRadius = if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvBalconyBigBoo) ~= 0 then 5000.0 else 1500.0

	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvMerryGoRoundBigBoo) ~= 0 or ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvMerryGoRoundBoo) ~= 0 then
		if ObjectListProcessor.gMarioOnMerryGoRound == IncludePRUltratypesH.TRUE then
			return IncludePRUltratypesH.TRUE
		else
			return IncludePRUltratypesH.FALSE
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom) == -1 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < activationRadius then
			return IncludePRUltratypesH.TRUE
		end
	elseif boo_inc.boo_should_be_stopped() == IncludePRUltratypesH.FALSE then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < activationRadius and (buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom) == ObjectListProcessor.gMarioCurrentRoom or ObjectListProcessor.gMarioCurrentRoom == 0) then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/boo.inc.c:bhv_courtyard_boo_triplet_init L83-97
function boo_inc.bhv_courtyard_boo_triplet_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if LevelUpdate.gHudDisplay.stars < boo_inc.SPAWN_CASTLE_BOO_STAR_REQUIREMENT then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		for TripletIndex = 1, 3 do
			const boo = ObjectHelpers.spawn_object_relative(IncludeObjectConstantsH.BOO_BP_GENERIC, boo_inc.sCourtyardBooTripletPositions[TripletIndex][1], boo_inc.sCourtyardBooTripletPositions[TripletIndex][2], boo_inc.sCourtyardBooTripletPositions[TripletIndex][3], o, IncludeModelIdsH.MODEL_BOO, BehaviorIds.bhvGhostHuntBoo)
			buffer.writei32(boo.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		end
	end
end

-- from src/game/behaviors/boo.inc.c:boo_approach_target_opacity_and_update_scale L99-120
function boo_inc.boo_approach_target_opacity_and_update_scale()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity) ~= buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) + 20)
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity) < buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity))
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 20)
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity))
			end
		end
	end

	const scale = F32((F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) / 255.0) * 0.4 + 0.6) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale))
	ObjectHelpers.obj_scale(o, scale) -- why no cur_obj_scale? was cur_obj_scale written later?
end

-- from src/game/behaviors/boo.inc.c:boo_oscillate L122-132
function boo_inc.boo_oscillate(ignoreOpacity: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const oscillationTimer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooOscillationTimer)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, SrcEngineMathUtilH.sins(oscillationTimer) * 0x400)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 255 or ignoreOpacity == IncludePRUltratypesH.TRUE then
		o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(oscillationTimer) * 0.08 + buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale))
		o.header.gfx.scale[2] = F32(-SrcEngineMathUtilH.sins(oscillationTimer) * 0.08 + buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale))
		o.header.gfx.scale[3] = o.header.gfx.scale[1]
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, SrcEngineMathUtilH.sins(oscillationTimer) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooOscillationTimer, oscillationTimer + 0x400)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_vanish_or_appear L134-159
function boo_inc.boo_vanish_or_appear(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	const relativeAngleToMario = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	const relativeMarioFaceAngle = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oFaceAngleYaw))))

	-- magic?
	const relativeAngleToMarioThreshhold = 0x1568
	const relativeMarioFaceAngleThreshhold = 0x6B58
	local doneAppearing = IncludePRUltratypesH.FALSE

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

	if relativeAngleToMario > relativeAngleToMarioThreshhold or relativeMarioFaceAngle < relativeMarioFaceAngleThreshhold then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 40 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 255)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOO_LAUGH_LONG)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) > 180 then
			doneAppearing = IncludePRUltratypesH.TRUE
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 255 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 40)
	end

	return doneAppearing
end

-- from src/game/behaviors/boo.inc.c:boo_set_move_yaw_for_during_hit L161-174
function boo_inc.boo_set_move_yaw_for_during_hit(hurt: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_intangible()
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooMoveYawBeforeHit, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if hurt ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooMoveYawDuringHit, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	elseif SrcEngineMathUtilH.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) - S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) < 0.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooMoveYawDuringHit, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooMoveYawDuringHit, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
	end
end

-- from src/game/behaviors/boo.inc.c:boo_move_during_hit L176-192
function boo_inc.boo_move_during_hit(roll: number, fVel: number)
	fVel = F32(fVel)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	-- Boos seem to have been supposed to oscillate up then down then back again
	-- when hit. However it seems the programmers forgot to scale the cosine,
	-- so the Y velocity goes from 1 to -1 and back to 1 over 32 frames.
	-- This is such a small change that the Y position only changes by 5 units.
	-- It's completely unnoticable in-game.
	const oscillationVel = timer * 0x800 + 0x800
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, fVel)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.coss(oscillationVel))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooMoveYawDuringHit))

	if roll ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + BehaviorActions.sBooHitRotations[timer + 1])
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + BehaviorActions.sBooHitRotations[timer + 1])
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_shake_after_hit L194-198
function boo_inc.big_boo_shake_after_hit()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Oscillate yaw
	const oscillationVel = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x2000 - 0x3E000
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + F32(SrcEngineMathUtilH.coss(oscillationVel) * 0x400))))
end

-- from src/game/behaviors/boo.inc.c:boo_reset_after_hit L200-204
function boo_inc.boo_reset_after_hit()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooMoveYawBeforeHit)))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/boo.inc.c:boo_update_after_bounced_on L207-225
function boo_inc.boo_update_after_bounced_on(a0: number): number
	a0 = F32(a0)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	boo_inc.boo_stop()

	if timer == 0 then
		boo_inc.boo_set_move_yaw_for_during_hit(IncludePRUltratypesH.FALSE)
	end

	if timer < 32 then
		boo_inc.boo_move_during_hit(IncludePRUltratypesH.FALSE, F32(F32(BehaviorActions.sBooHitRotations[timer + 1] / 5000.0) * a0))
	else
		ObjectHelpers.cur_obj_become_tangible()
		boo_inc.boo_reset_after_hit()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/boo.inc.c:big_boo_update_during_nonlethal_hit L228-248
function boo_inc.big_boo_update_during_nonlethal_hit(a0: number): number
	a0 = F32(a0)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	boo_inc.boo_stop()

	if timer == 0 then
		boo_inc.boo_set_move_yaw_for_during_hit(IncludePRUltratypesH.TRUE)
	end

	if timer < 32 then
		boo_inc.boo_move_during_hit(IncludePRUltratypesH.TRUE, F32(F32(BehaviorActions.sBooHitRotations[timer + 1] / 5000.0) * a0))
	elseif timer < 48 then
		boo_inc.big_boo_shake_after_hit()
	else
		ObjectHelpers.cur_obj_become_tangible()
		boo_inc.boo_reset_after_hit()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/boo.inc.c:boo_update_during_death L252-288
function boo_inc.boo_update_during_death(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooDeathStatus, IncludeObjectConstantsH.BOO_DEATH_STATUS_DYING)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			ObjectHelpers.spawn_mist_particles()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooDeathStatus, IncludeObjectConstantsH.BOO_DEATH_STATUS_DEAD)

			if o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] ~= nil then
				const parentBigBoo = o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] :: GroupsTypesHPlus3.Object

				if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvBoo) == IncludePRUltratypesH.FALSE then
					buffer.writei32(parentBigBoo.rawData, IncludeObjectFieldsH.oBigBooNumMinionBoosKilled, buffer.readi32(parentBigBoo.rawData, IncludeObjectFieldsH.oBigBooNumMinionBoosKilled) + 1)
				end
			end

			return IncludePRUltratypesH.TRUE
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 5.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x800)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/boo.inc.c:obj_has_attack_type L290-296
function boo_inc.obj_has_attack_type(attackType: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACK_MASK) == attackType then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/boo.inc.c:boo_get_attack_status L298-321
function boo_inc.boo_get_attack_status(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local attackStatus = IncludeObjectConstantsH.BOO_NOT_ATTACKED

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_WAS_ATTACKED) and boo_inc.obj_has_attack_type(InteractionH.ATTACK_FROM_ABOVE) == IncludePRUltratypesH.FALSE then
			ObjectHelpers.cur_obj_become_intangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOO_LAUGH_SHORT)
			attackStatus = IncludeObjectConstantsH.BOO_ATTACKED
		else
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOO_BOUNCE_TOP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			attackStatus = IncludeObjectConstantsH.BOO_BOUNCED_ON
		end
	end

	return attackStatus
end

-- from src/game/behaviors/boo.inc.c:boo_chase_mario L324-360
function boo_inc.boo_chase_mario(a0: number, turnSpeed: number, velMultiplier: number)
	a0 = F32(a0)
	turnSpeed = S16(TruncS32(turnSpeed))
	velMultiplier = F32(velMultiplier)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_vanish_or_appear() ~= IncludePRUltratypesH.FALSE then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_BOUNCE_TOP)

		local targetYaw: number

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 1500.0 then
			targetYaw = S16(ObjectHelpers.cur_obj_angle_to_home())
		else
			targetYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(targetYaw, turnSpeed)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

		if ObjectHelpers.mario_is_in_air_action() == IncludePRUltratypesH.FALSE then
			const dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY))

			if a0 < dy and dy < 500.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, ObjectHelpers.increment_velocity_toward_range(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) + 50.0), 10.0, 2.0))
			end
		end

		ObjectHelpers.cur_obj_set_vel_from_mario_vel(F32(10.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooNegatedAggressiveness)), velMultiplier)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0 then
			boo_inc.boo_oscillate(IncludePRUltratypesH.FALSE)
		end
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, 0)
		-- why is boo_stop not used here
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_0 L362-386
function boo_inc.boo_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_MOVE_THROUGH_GRATE))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOO_BP_MERRY_GO_ROUND then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oRoom, 10)
	end

	ObjectHelpers.cur_obj_set_pos_to_home()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooInitialMoveYaw))
	boo_inc.boo_stop()
	o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvGhostHuntBigBoo)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooBaseScale, 1.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 255)

	if boo_inc.boo_should_be_active() ~= IncludePRUltratypesH.FALSE then
		-- Condition is met if the object is bhvBalconyBigBoo or bhvMerryGoRoundBoo
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOO_BP_MERRY_GO_ROUND then
			o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] = nil
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_5 L388-398
function boo_inc.boo_act_5()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 30 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 13.0)
		boo_inc.boo_oscillate(IncludePRUltratypesH.FALSE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 0.0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 30.0)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_1 L400-427
function boo_inc.boo_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooNegatedAggressiveness, -SrcEngineBehaviorScript.random_float() * 5.0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBooTurningSpeed, S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 128.0))))
	end

	boo_inc.boo_chase_mario(-100.0, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBooTurningSpeed) + 0x180), F32(0.5))
	const attackStatus = boo_inc.boo_get_attack_status()

	if boo_inc.boo_should_be_stopped() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_BOUNCED_ON then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_ATTACKED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_ATTACKED then
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_DYING_ENEMY1)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_2 L429-433
function boo_inc.boo_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_update_after_bounced_on(20.0) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_3 L435-444
function boo_inc.boo_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_update_during_death() ~= IncludePRUltratypesH.FALSE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.BOO_BP_GHOST_HUNT then
			ObjectHelpers.obj_mark_for_deletion(o)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
			ObjectHelpers.cur_obj_disable()
		end
	end
end

-- from src/game/behaviors/boo.inc.c:boo_act_4 L447-465
function boo_inc.boo_act_4()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local dialogID: number
	const nearestBoo: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvGhostHuntBoo)

	-- If there are no remaining "minion" boos, show the dialog of the Big Boo
	if nearestBoo == nil then
		dialogID = IncludeDialogIdsH.DIALOG_108
	else
		dialogID = IncludeDialogIdsH.DIALOG_107
	end

	if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, dialogID, 0) ~= IncludePRUltratypesH.FALSE then
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_DYING_ENEMY1)
		ObjectHelpers.obj_mark_for_deletion(o)

		if dialogID == IncludeDialogIdsH.DIALOG_108 then
			-- If the Big Boo should spawn, play the jingle
			Audio.play_puzzle_jingle()
		end
	end
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_loop L476-490
function boo_inc.bhv_boo_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- PARTIAL_UPDATE
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(boo_inc.sBooActions)
	ObjectHelpers.cur_obj_move_standard(78)
	boo_inc.boo_approach_target_opacity_and_update_scale()

	if ObjectHelpers.obj_has_behavior(o.parentObj :: GroupsTypesHPlus3.Object, BehaviorIds.bhvMerryGoRoundBooManager) ~= IncludePRUltratypesH.FALSE and o.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosKilled, buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosKilled) + 1)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/boo.inc.c:big_boo_act_0 L492-527
function boo_inc.big_boo_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvBalconyBigBoo) ~= IncludePRUltratypesH.FALSE then
		boo_inc.obj_set_secondary_camera_focus()
		-- number of killed boos set > 5 so that boo always loads
		-- redundant? this is also done in behavior_data.s
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBigBooNumMinionBoosKilled, 10)
	end

	o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] = nil

	if boo_inc.boo_should_be_active() ~= IncludePRUltratypesH.FALSE and buffer.readi32(o.rawData, IncludeObjectFieldsH.oBigBooNumMinionBoosKilled) >= ObjectListProcessor.gDebugInfo[6][1] + 5 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		ObjectHelpers.cur_obj_set_pos_to_home()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBooInitialMoveYaw))
		ObjectHelpers.cur_obj_unhide()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 255)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooBaseScale, 3.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 3)
		ObjectHelpers.cur_obj_scale(3.0)
		ObjectHelpers.cur_obj_become_tangible()
	else
		ObjectHelpers.cur_obj_hide()
		ObjectHelpers.cur_obj_become_intangible()
		boo_inc.boo_stop()
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_act_1 L529-566
function boo_inc.big_boo_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const health = buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth)

	local turnSpeed: number
	local velMultiplier: number

	if health == 3 then
		turnSpeed = 0x180
		velMultiplier = 0.5
	elseif health == 2 then
		turnSpeed = 0x240
		velMultiplier = F32(0.6)
	else
		turnSpeed = 0x300
		velMultiplier = F32(0.8)
	end

	boo_inc.boo_chase_mario(-100.0, turnSpeed, velMultiplier)
	const attackStatus = boo_inc.boo_get_attack_status()

	-- redundant; this check is in boo_should_be_stopped
	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvMerryGoRoundBigBoo) ~= IncludePRUltratypesH.FALSE then
		if ObjectListProcessor.gMarioOnMerryGoRound == IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	elseif boo_inc.boo_should_be_stopped() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_BOUNCED_ON then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_ATTACKED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_ATTACKED then
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_THWOMP)
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_act_2 L568-572
function boo_inc.big_boo_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_update_after_bounced_on(20.0) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_spawn_ghost_hunt_star L574-576
function boo_inc.big_boo_spawn_ghost_hunt_star()
	SpawnStarInc.spawn_default_star(980.0, 1100.0, 250.0)
end

-- from src/game/behaviors/boo.inc.c:big_boo_spawn_balcony_star L578-580
function boo_inc.big_boo_spawn_balcony_star()
	SpawnStarInc.spawn_default_star(700.0, 3200.0, 1900.0)
end

-- from src/game/behaviors/boo.inc.c:big_boo_spawn_merry_go_round_star L582-592
function boo_inc.big_boo_spawn_merry_go_round_star()
	SpawnStarInc.spawn_default_star(-1600.0, -2100.0, 205.0)

	const merryGoRound: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvMerryGoRound)

	if merryGoRound ~= nil then
		buffer.writei32(merryGoRound.rawData, IncludeObjectFieldsH.oMerryGoRoundStopped, IncludePRUltratypesH.TRUE)
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_act_3 L594-625
function boo_inc.big_boo_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 0 then
		if boo_inc.boo_update_during_death() ~= IncludePRUltratypesH.FALSE then
			ObjectHelpers.cur_obj_disable()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
			ObjectHelpers.obj_set_angle(o, 0, 0, 0)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BIG_BOO_BP_GHOST_HUNT then
				boo_inc.big_boo_spawn_ghost_hunt_star()
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BIG_BOO_BP_MERRY_GO_ROUND then
				boo_inc.big_boo_spawn_merry_go_round_star()
			else
				boo_inc.big_boo_spawn_balcony_star()
			end
		end
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.spawn_mist_particles()
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooBaseScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale) - 0.5)
		end

		if boo_inc.big_boo_update_during_nonlethal_hit(40.0) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/boo.inc.c:big_boo_act_4 L627-647
function boo_inc.big_boo_act_4()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	boo_inc.boo_stop()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BIG_BOO_BP_GHOST_HUNT then
		ObjectHelpers.obj_set_pos(o, 973, 0, 626)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 600.0 then
			ObjectHelpers.obj_set_pos(o, 973, 0, 717)
			ObjectHelpers.spawn_object_relative(0, 0, 0, 0, o, IncludeModelIdsH.MODEL_BBH_STAIRCASE_STEP, BehaviorIds.bhvBooStaircase)
			ObjectHelpers.spawn_object_relative(1, 0, 0, -200, o, IncludeModelIdsH.MODEL_BBH_STAIRCASE_STEP, BehaviorIds.bhvBooStaircase)
			ObjectHelpers.spawn_object_relative(2, 0, 0, 200, o, IncludeModelIdsH.MODEL_BBH_STAIRCASE_STEP, BehaviorIds.bhvBooStaircase)
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	else
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/boo.inc.c:bhv_big_boo_loop L657-671
function boo_inc.bhv_big_boo_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- PARTIAL_UPDATE
	ObjectHelpers.obj_set_hitbox(o, boo_inc.sBooGivingStarHitbox)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale) * 60.0)
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(boo_inc.sBooGivingStarActions)
	ObjectHelpers.cur_obj_move_standard(78)
	boo_inc.boo_approach_target_opacity_and_update_scale()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/boo.inc.c:boo_with_cage_act_0 L673-684
function boo_inc.boo_with_cage_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.ptrData[IncludeObjectFieldsH.oBooParentBigBoo + 1] = nil
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBooTargetOpacity, 255)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooBaseScale, 2.0)
	ObjectHelpers.cur_obj_scale(2.0)
	ObjectHelpers.cur_obj_become_tangible()

	if boo_inc.boo_should_be_active() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_with_cage_act_1 L686-704
function boo_inc.boo_with_cage_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	boo_inc.boo_chase_mario(100.0, 0x200, F32(0.5))
	const attackStatus = boo_inc.boo_get_attack_status()

	if boo_inc.boo_should_be_stopped() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_BOUNCED_ON then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if attackStatus == IncludeObjectConstantsH.BOO_ATTACKED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_with_cage_act_2 L706-710
function boo_inc.boo_with_cage_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_update_after_bounced_on(20.0) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/boo.inc.c:boo_with_cage_act_3 L712-716
function boo_inc.boo_with_cage_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if boo_inc.boo_update_during_death() ~= IncludePRUltratypesH.FALSE then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_with_cage_init L718-725
function boo_inc.bhv_boo_with_cage_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if LevelUpdate.gHudDisplay.stars < boo_inc.SPAWN_CASTLE_BOO_STAR_REQUIREMENT then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		const cage = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_HAUNTED_CAGE, BehaviorIds.bhvBooCage)
		buffer.writei32(cage.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
	end
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_with_cage_loop L734-744
function boo_inc.bhv_boo_with_cage_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- PARTIAL_UPDATE
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(boo_inc.sBooWithCageActions)
	ObjectHelpers.cur_obj_move_standard(78)
	boo_inc.boo_approach_target_opacity_and_update_scale()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/boo.inc.c:bhv_merry_go_round_boo_manager_loop L746-788
function boo_inc.bhv_merry_go_round_boo_manager_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosKilled) < 5 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosSpawned) ~= 5 then
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosSpawned) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosKilled) < 2 then
						ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOO, BehaviorIds.bhvMerryGoRoundBoo)
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosSpawned, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosSpawned) + 1)
					end
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			end

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMerryGoRoundBooManagerNumBoosKilled) >= 5 then
				const bigBoo = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOO, BehaviorIds.bhvMerryGoRoundBigBoo)
				ObjectHelpers.obj_copy_behavior_params(bigBoo, o)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
				Audio.play_puzzle_jingle()
			end
		end
	elseif action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	elseif action == 2 then
		-- Nothing to do: the manager is done.
	end
end

-- from src/game/behaviors/boo.inc.c:obj_set_secondary_camera_focus L790-792
function boo_inc.obj_set_secondary_camera_focus()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	Camera.gSecondCameraFocus = o
end

-- from src/game/behaviors/boo.inc.c:bhv_animated_texture_loop L794-796
function boo_inc.bhv_animated_texture_loop()
	ObjectHelpers.cur_obj_set_pos_to_home_with_debug()
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_in_castle_loop L798-857
function boo_inc.bhv_boo_in_castle_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)
	local targetAngle: number

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBooBaseScale, 2.0)

	if action == 0 then
		ObjectHelpers.cur_obj_hide()

		if LevelUpdate.gHudDisplay.stars < boo_inc.SPAWN_CASTLE_BOO_STAR_REQUIREMENT then
			ObjectHelpers.obj_mark_for_deletion(o)
		end

		if ObjectListProcessor.gMarioCurrentRoom == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == 1 then
		ObjectHelpers.cur_obj_unhide()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 180)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBooBaseScale))
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOO_LAUGH_LONG)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		targetAngle = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
	else
		ObjectHelpers.cur_obj_forward_vel_approach_upward(32.0, 1.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, -1000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, -9000.0)
		targetAngle = S16(ObjectHelpers.cur_obj_angle_to_home())

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) < -5000.0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) > 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 20)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
			end
		end

		if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	targetAngle = S16(ObjectHelpers.cur_obj_angle_to_home())
	ObjectHelpers.cur_obj_rotate_yaw_toward(targetAngle, 0x5A8)
	boo_inc.boo_oscillate(IncludePRUltratypesH.TRUE)
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/boo.inc.c:bhv_boo_staircase L859-908
function boo_inc.bhv_boo_staircase()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local targetY = 0.0
	local action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 1 then
		targetY = 0.0
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		targetY = -206.0
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 2 then
		targetY = -413.0
	end

	if action == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 620.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		-- fallthrough
		action = 1
	end

	if action == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 8.0)
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR2)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > targetY then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, targetY)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNKNOWN4_LOWPRIO)
		end

		if ObjectHelpers.jiggle_bbh_stair(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == 3 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 1 then
			Audio.play_puzzle_jingle()
		end
	end
end

-- from src/game/behaviors/boo.inc.c:sBooActions L467-474
boo_inc.sBooActions = {
	boo_inc.boo_act_0,
	boo_inc.boo_act_1,
	boo_inc.boo_act_2,
	boo_inc.boo_act_3,
	boo_inc.boo_act_4,
	boo_inc.boo_act_5,
}

-- from src/game/behaviors/boo.inc.c:sBooGivingStarActions L649-655
boo_inc.sBooGivingStarActions = {
	boo_inc.big_boo_act_0,
	boo_inc.big_boo_act_1,
	boo_inc.big_boo_act_2,
	boo_inc.big_boo_act_3,
	boo_inc.big_boo_act_4,
}

-- from src/game/behaviors/boo.inc.c:sBooWithCageActions L727-732
boo_inc.sBooWithCageActions = {
	boo_inc.boo_with_cage_act_0,
	boo_inc.boo_with_cage_act_1,
	boo_inc.boo_with_cage_act_2,
	boo_inc.boo_with_cage_act_3,
}

return boo_inc
