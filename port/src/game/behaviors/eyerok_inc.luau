--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/eyerok.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const InteractionH = require("../interaction_h")
const Camera = require("../camera")
const GroundParticlesInc = require("./ground_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const SeqPlayerLevel = 0

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

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/eyerok_inc.luau:scratch
const Scratch = {
	eyerok_hand_act_open_sp1E = { 0 },
}

-- from src/game/behaviors/eyerok.inc.c:data
const eyerok_inc = {
	-- from src/game/behaviors/eyerok.inc.c:sEyerokHitbox L3-13
	sEyerokHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 4,
		numLootCoins = 0,
		radius = 150,
		height = 100,
		hurtboxRadius = 1,
		hurtboxHeight = 1,
	},
	-- from src/game/behaviors/eyerok.inc.c:D_80331BA4 L15-15
	D_80331BA4 = { 0, 1, 3, 2, 1, 0 },
}

Registry.Register("src__game__behaviors__eyerok_inc", eyerok_inc)

-- from src/game/behaviors/eyerok.inc.c:eyerok_check_mario_relative_z L17-23
function eyerok_inc.eyerok_check_mario_relative_z(arg0: number): number
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ)) < arg0 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_spawn_hand L25-31
function eyerok_inc.eyerok_spawn_hand(side: number, model: number, behavior: number)
	side = S16(TruncS32(side))
	const o = ObjectListProcessor.gCurrentObject

	const hand: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative_with_scale(side, S16(-500 * side), 0, 300, 1.5, o, model, behavior)
	if hand ~= nil then
		buffer.writei32(hand.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(hand.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x4000 * side)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_boss_act_sleep L33-41
function eyerok_inc.eyerok_boss_act_sleep()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		eyerok_inc.eyerok_spawn_hand(-1, IncludeModelIdsH.MODEL_EYEROK_LEFT_HAND, BehaviorIds.bhvEyerokHand)
		eyerok_inc.eyerok_spawn_hand(1, IncludeModelIdsH.MODEL_EYEROK_RIGHT_HAND, BehaviorIds.bhvEyerokHand)
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_EYEROK_EXPLODE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_BOSS_ACT_WAKE_UP)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_boss_act_wake_up L43-64
function eyerok_inc.eyerok_boss_act_wake_up()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
				Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			end

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110) == 0 and MarioActionsCutscene.mario_ready_to_speak() ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_BOSS_ACT_SHOW_INTRO_TEXT)
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
				const Approached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110, 0, 10)
				if Approached ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
				end
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
				ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110, 300, 10)
			end
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_boss_act_show_intro_text L66-70
function eyerok_inc.eyerok_boss_act_show_intro_text()
	const o = ObjectListProcessor.gCurrentObject

	if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_NONE, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_117) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_BOSS_ACT_FIGHT)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_boss_act_fight L72-117
function eyerok_inc.eyerok_boss_act_fight()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_BOSS_ACT_DIE)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC) == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) ~= 0 then
			const Approached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110, 1, F32(0.02))
			if Approached ~= 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) < 0 then
					if eyerok_inc.eyerok_check_mario_relative_z(400) == 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) + 1)
						if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) == 0 then
							buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104, 1)
						end
					end
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) - 1)
				end

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) ~= 1 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC) + 1)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC), 0x1)))
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, -1)
					end
				end
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC) + 1)

			if eyerok_inc.eyerok_check_mario_relative_z(400) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104, -8)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110, 1)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk108, 0)
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) == 2 and math.fmod(buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC), 6) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk104, 8)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk110, 0)

				const RandomBit = S32(bit32.band(SrcEngineBehaviorScript.random_u16(), 0x1))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC, RandomBit)
				if RandomBit ~= 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk108, -1)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk108, 1)
				end

				buffer.writef32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk10C, buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ))
				ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnk10C, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 400), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 1600))
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossUnkFC), 0x1)))
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, -1)
				end
			end
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_boss_act_die L119-130
function eyerok_inc.eyerok_boss_act_die()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
		if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_NONE, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_118) ~= 0 then
			SpawnStarInc.spawn_default_star(0, -900, -3700)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 120 then
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/eyerok.inc.c:bhv_eyerok_boss_loop L132-150
function eyerok_inc.bhv_eyerok_boss_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_SLEEP then
		eyerok_inc.eyerok_boss_act_sleep()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_WAKE_UP then
		eyerok_inc.eyerok_boss_act_wake_up()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_SHOW_INTRO_TEXT then
		eyerok_inc.eyerok_boss_act_show_intro_text()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_FIGHT then
		eyerok_inc.eyerok_boss_act_fight()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_DIE then
		eyerok_inc.eyerok_boss_act_die()
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_check_attacked L152-175
function eyerok_inc.eyerok_hand_check_attacked(): number
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokReceivedAttack) ~= 0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) < 0x3000 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_EYEROK_SOUND_SHORT)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) >= 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_ATTACKED)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30)
		else
			const parent = o.parentObj :: GroupsTypesHPlus3.Object
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) - 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_DIE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.2))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x8000)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 3)

		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_pound_ground L177-181
function eyerok_inc.eyerok_hand_pound_ground()
	const o = ObjectListProcessor.gCurrentObject

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_POUNDING_LOUD)
	Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	GroundParticlesInc.spawn_mist_from_global()
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_sleep L183-207
function eyerok_inc.eyerok_hand_act_sleep()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	local WakingUp = false
	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.EYEROK_BOSS_ACT_SLEEP then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandWakeUpTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandWakeUpTimer) + 1)
		WakingUp = buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandWakeUpTimer) > -3 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)
	end

	if WakingUp then
		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) + 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_IDLE)
			o.collisionData = Memory.segmented_to_virtual(0x07028274)
		else
			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), 15)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32((200 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 400) * SrcEngineMathUtilH.sins(S16(TruncS32(F32(F32(ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))) / 724) * 0x8000))))))
			ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 400)
		end
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) < 0 then
			o.collisionData = Memory.segmented_to_virtual(0x070284B0)
		else
			o.collisionData = Memory.segmented_to_virtual(0x07028370)
		end

		ObjectHelpers.cur_obj_reverse_animation()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(724 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_idle L209-242
function eyerok_inc.eyerok_hand_act_idle()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(2)

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_BOSS_ACT_FIGHT then
		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) ~= 0 then
			if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) ~= 1 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_BEGIN_DOUBLE_POUND)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
			end
		elseif buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC) == 0 and buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) ~= 0 then
			if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
				if eyerok_inc.eyerok_check_mario_relative_z(400) ~= 0 or SrcEngineBehaviorScript.random_u16() % 2 ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_TARGET_MARIO)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_FIST_PUSH)
					if F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosX)) < 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, -0x800)
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x800)
					end

					buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4)
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_OPEN)
			end
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk110))
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_open L244-263
function eyerok_inc.eyerok_hand_act_open()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(4) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_SHOW_EYE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC, 2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnk100, 60)

		o.collisionData = Memory.segmented_to_virtual(0x070282F8)

		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) ~= 2 then
			Scratch.eyerok_hand_act_open_sp1E[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			ObjBehaviors2.clamp_s16(Scratch.eyerok_hand_act_open_sp1E, -0x3000, 0x3000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Scratch.eyerok_hand_act_open_sp1E[1])
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_show_eye L265-298
function eyerok_inc.eyerok_hand_act_show_eye()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(5)
	ObjBehaviors2.cur_obj_play_sound_at_anim_range(0, 0, IncludeSoundsH.SOUND_OBJ_EYEROK_SHOW_EYE)

	if eyerok_inc.eyerok_hand_check_attacked() == 0 then
		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) < 3 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
			elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_CLOSE)
			end
		else
			const HandTimerBefore = buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnk100)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnk100, HandTimerBefore - 1)
			if HandTimerBefore ~= 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC) - 1)
				end
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, eyerok_inc.D_80331BA4[buffer.readi32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC) + 1])
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnkFC, 5)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokHandUnk100, ObjBehaviors2.random_linear_offset(20, 50))
			end

			if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) ~= 2 then
				ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 0x800)
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 and (F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ)) > 0 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE)) then
					buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, 0)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
				end
			end
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_close L300-312
function eyerok_inc.eyerok_hand_act_close()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_check_frame(7, 1) ~= 0 then
		o.collisionData = Memory.segmented_to_virtual(0x07028274)

		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) ~= 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT)
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		elseif buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_IDLE)
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC, 0)
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_attacked L314-323
function eyerok_inc.eyerok_hand_act_attacked()
	const o = ObjectListProcessor.gCurrentObject

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(3) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RECOVER)
		o.collisionData = Memory.segmented_to_virtual(0x07028274)
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_recover L325-329
function eyerok_inc.eyerok_hand_act_recover()
	const o = ObjectListProcessor.gCurrentObject

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(0) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_BECOME_ACTIVE)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_become_active L331-336
function eyerok_inc.eyerok_hand_act_become_active()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == 0 or buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) ~= 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT)
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_die L338-349
function eyerok_inc.eyerok_hand_act_die()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(1) ~= 0 then
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC, 0)
		ObjectHelpers.obj_explode_and_spawn_coins(150, 1)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ2_EYEROK_SOUND_LONG)
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_POUNDING_LOUD)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_retreat L351-372
function eyerok_inc.eyerok_hand_act_retreat()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	local distToHome = ObjectHelpers.cur_obj_lateral_dist_to_home()
	const angleToHome = ObjectHelpers.cur_obj_angle_to_home()

	distToHome = F32(distToHome - 40)
	if distToHome < 0 then
		distToHome = 0
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - F32(distToHome * SrcEngineMathUtilH.sins(angleToHome)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - F32(distToHome * SrcEngineMathUtilH.coss(angleToHome)))

	ObjBehaviors2.obj_face_yaw_approach(0, 400)

	const Approached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), 20)
	if Approached ~= 0 and distToHome == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_IDLE)
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))

		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC, 0)
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_target_mario L374-387
function eyerok_inc.eyerok_hand_act_target_mario()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if eyerok_inc.eyerok_check_mario_relative_z(400) ~= 0 or F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ)) > 0 or F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ)) > 1700 or ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX))) > 900 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		const Reached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 300), 20)
		if Reached ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_SMASH)
		end
	else
		ObjBehaviors2.obj_forward_vel_approach(50, 5)
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 300), 20)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 4000)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_smash L389-412
function eyerok_inc.eyerok_hand_act_smash()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity) < -4 then
				eyerok_inc.eyerok_hand_pound_ground()
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4)
			else
				const sp1E = ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)))
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 300 and sp1E > 0x2000 and sp1E < 0x6000 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_FIST_SWEEP)
					if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) < 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x4000)
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, -0x4000)
					end
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT)
				end
			end
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -20)
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_fist_push L414-427
function eyerok_inc.eyerok_hand_act_fist_push()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 and (F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ)) > 0 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_FIST_SWEEP)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)

		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosX)) < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x4000)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, -0x4000)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_fist_sweep L429-438
function eyerok_inc.eyerok_hand_act_fist_sweep()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ)) < 1000 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	else
		ObjBehaviors2.obj_forward_vel_approach(5, F32(0.02))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(1.08))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_begin_double_pound L440-454
function eyerok_inc.eyerok_hand_act_begin_double_pound()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) < 0 or buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_DOUBLE_POUND)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - F32(0x4000 * buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk108)))))
	else
		const sp4 = F32(F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX) + F32(400 * buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk108))) - F32(180 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(F32(sp4 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX)) * buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk110)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(300 * buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk110)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk10C) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ)) * buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk110)))
	end
end

-- from src/game/behaviors/eyerok.inc.c:eyerok_hand_act_double_pound L456-480
function eyerok_inc.eyerok_hand_act_double_pound()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossNumHands) ~= 2 then
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	end

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk104) == 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT)
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk1AC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	elseif buffer.readi32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity) < -15 then
				buffer.writei32(parent.rawData, IncludeObjectFieldsH.oEyerokBossActiveHand, 0)
				eyerok_inc.eyerok_hand_pound_ground()
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -15)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30 * ObjectHelpers.absf(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oEyerokBossUnk108)))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 100)
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) <= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -20)
		end
	end
end

-- from src/game/behaviors/eyerok.inc.c:bhv_eyerok_hand_loop L482-544
function eyerok_inc.bhv_eyerok_hand_loop()
	const o = ObjectListProcessor.gCurrentObject

	o.header.gfx.scale[1] = F32(1.5)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_SLEEP then
		eyerok_inc.eyerok_hand_act_sleep()
	else
		ObjectHelpers.cur_obj_update_floor_and_walls()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_IDLE then
			eyerok_inc.eyerok_hand_act_idle()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_OPEN then
			eyerok_inc.eyerok_hand_act_open()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_SHOW_EYE then
			eyerok_inc.eyerok_hand_act_show_eye()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_CLOSE then
			eyerok_inc.eyerok_hand_act_close()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_RETREAT then
			eyerok_inc.eyerok_hand_act_retreat()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_TARGET_MARIO then
			eyerok_inc.eyerok_hand_act_target_mario()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_SMASH then
			eyerok_inc.eyerok_hand_act_smash()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_FIST_PUSH then
			eyerok_inc.eyerok_hand_act_fist_push()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_FIST_SWEEP then
			eyerok_inc.eyerok_hand_act_fist_sweep()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_BEGIN_DOUBLE_POUND then
			eyerok_inc.eyerok_hand_act_begin_double_pound()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_DOUBLE_POUND then
			eyerok_inc.eyerok_hand_act_double_pound()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_ATTACKED then
			eyerok_inc.eyerok_hand_act_attacked()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_RECOVER then
			eyerok_inc.eyerok_hand_act_recover()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_BECOME_ACTIVE then
			eyerok_inc.eyerok_hand_act_become_active()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.EYEROK_HAND_ACT_DIE then
			eyerok_inc.eyerok_hand_act_die()
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oEyerokReceivedAttack, ObjBehaviors2.obj_check_attacks(eyerok_inc.sEyerokHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)))
		ObjectHelpers.cur_obj_move_standard(-78)
	end

	SrcEngineSurfaceLoad.load_object_collision_model()
	o.header.gfx.scale[1] = F32(1.5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
end

return eyerok_inc
