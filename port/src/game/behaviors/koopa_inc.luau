--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/koopa.inc.c.
]]

const SegmentSymbols = require("../../rom/segment_symbols")
const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const IncludeDialogIdsH = require("../../../include/dialog_ids_h")

const InteractionH = require("../interaction_h")
const ObjBehaviors2H = require("../obj_behaviors_2_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const LevelUpdateH = require("../level_update_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const Memory = require("../memory")
const ObjectHelpersH = require("../object_helpers_h")
const SpawnStarInc = require("./spawn_star_inc")

const SeqPlayerLevel = 0

-- from src/game/behaviors/koopa.inc.c:KoopaTheQuickProperties
export type KoopaTheQuickProperties = {
	initDialogID: number,
	winDialogID: number,
	path: number?,
	starPos: { number },
}

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

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/koopa_inc.luau:scratch
const Scratch = {
	koopa_unshelled_act_run_distToShell = { 0 },
	koopa_unshelled_act_dive_distToShell = { 0 },
	koopa_the_quick_detect_bowling_ball_distToBall = { 0 },
}

-- from src/game/behaviors/koopa.inc.c:data
const koopa_inc = {
	-- from src/game/behaviors/koopa.inc.c:sKoopaHitbox L14-24
	sKoopaHitbox = {
			interactType = InteractionH.INTERACT_KOOPA,
			downOffset = 0,
			damageOrCoinValue = 0,
			health = 0,
			numLootCoins = -1,
			radius = 60,
			height = 40,
			hurtboxRadius = 40,
			hurtboxHeight = 30,
		},
	-- from src/game/behaviors/koopa.inc.c:sKoopaUnshelledAttackHandlers L29-36
	sKoopaUnshelledAttackHandlers = {
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		},
	-- from src/game/behaviors/koopa.inc.c:sKoopaShelledAttackHandlers L41-48
	sKoopaShelledAttackHandlers = {
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL,
		},
	-- from src/game/behaviors/koopa.inc.c:sKoopaTheQuickProperties L63-66
	sKoopaTheQuickProperties = {
			{
				initDialogID = IncludeDialogIdsH.DIALOG_005,
				winDialogID = IncludeDialogIdsH.DIALOG_007,
				path = SegmentSymbols.bob_seg7_trajectory_koopa,
				starPos = { 3030, 4500, -4600 },
			},
			{
				initDialogID = IncludeDialogIdsH.DIALOG_009,
				winDialogID = IncludeDialogIdsH.DIALOG_031,
				path = SegmentSymbols.thi_seg7_trajectory_koopa,
				starPos = { 7100, -1300, -6000 },
			},
		},
}

Registry.Register("src__game__behaviors__koopa_inc", koopa_inc)

-- from src/game/behaviors/koopa.inc.c:KoopaTheQuickProperties (zero-filled constructor)
function koopa_inc.new_KoopaTheQuickProperties(): KoopaTheQuickProperties
	return { initDialogID = 0, winDialogID = 0, path = nil, starPos = table.create(3, 0) } :: KoopaTheQuickProperties
end

-- from src/game/behaviors/koopa.inc.c:bhv_koopa_init L71-87
function koopa_inc.bhv_koopa_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType) == IncludeObjectConstantsH.KOOPA_BP_TINY then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType, IncludeObjectConstantsH.KOOPA_BP_NORMAL)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, F32(1.6) / 3.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDrawingDistance, 1500.0)
		ObjectHelpers.cur_obj_scale(F32(0.8))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, F32(-6.4) / 3.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType) >= IncludeObjectConstantsH.KOOPA_BP_KOOPA_THE_QUICK_BASE then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickRaceIndex, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType) - IncludeObjectConstantsH.KOOPA_BP_KOOPA_THE_QUICK_BASE))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, 4.0)
		ObjectHelpers.cur_obj_scale(3.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, 1.0)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_play_footstep_sound L92-102
function koopa_inc.koopa_play_footstep_sound(animFrame1: number, animFrame2: number)
	animFrame1 = S8(TruncS32(animFrame1))
	animFrame2 = S8(TruncS32(animFrame2))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local sound = IncludeSoundsH.SOUND_OBJ_KOOPA_WALK

	if o.header.gfx.scale[1] > F32(1.5) then
		sound = IncludeSoundsH.SOUND_OBJ_KOOPA_THE_QUICK_WALK
	end

	ObjBehaviors2.cur_obj_play_sound_at_anim_range(animFrame1, animFrame2, sound)
end

-- from src/game/behaviors/koopa.inc.c:koopa_check_run_from_mario L108-116
function koopa_inc.koopa_check_run_from_mario(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaDistanceToMario) < 300.0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x3000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_RUN_FROM_MARIO)

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/koopa.inc.c:koopa_shelled_act_stopped L122-128
function koopa_inc.koopa_shelled_act_stopped()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(7) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_WALK)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x2000 * S16(SrcEngineBehaviorScript.random_sign())))
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_walk_start L133-140
function koopa_inc.koopa_walk_start()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_forward_vel_approach(F32(3.0 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility)), F32(F32(0.3) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility)))

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(11) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown, S16(ObjBehaviors2.random_linear_offset(30, 100)))
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_walk L145-154
function koopa_inc.koopa_walk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(9)
	koopa_inc.koopa_play_footstep_sound(2, 17)

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) ~= 0 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) - 1))
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_walk_stop L159-164
function koopa_inc.koopa_walk_stop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_forward_vel_approach(0.0, F32(1.0 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility)))

	if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(10) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_STOPPED)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_shelled_act_walk L170-196
function koopa_inc.koopa_shelled_act_walk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), 0x200))
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall, ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw))
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), 0x200)
	end

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == IncludeObjectConstantsH.KOOPA_SHELLED_SUB_ACT_START_WALK then
		koopa_inc.koopa_walk_start()
	elseif subAction == IncludeObjectConstantsH.KOOPA_SHELLED_SUB_ACT_WALK then
		koopa_inc.koopa_walk()
	elseif subAction == IncludeObjectConstantsH.KOOPA_SHELLED_SUB_ACT_STOP_WALK then
		koopa_inc.koopa_walk_stop()
	end

	koopa_inc.koopa_check_run_from_mario()
end

-- from src/game/behaviors/koopa.inc.c:koopa_shelled_act_run_from_mario L202-220
function koopa_inc.koopa_shelled_act_run_from_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(1)
	koopa_inc.koopa_play_footstep_sound(0, 11)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, 0.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 800.0 then
		if ObjBehaviors2.obj_forward_vel_approach(0.0, 1.0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_STOPPED)
		end
	else
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000), 0x400)
		ObjBehaviors2.obj_forward_vel_approach(17.0, 1.0)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_dive_update_speed L225-234
function koopa_inc.koopa_dive_update_speed(decel: number)
	decel = F32(decel)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		ObjBehaviors2.obj_forward_vel_approach(0.0, decel)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 5.0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) % 4 == 0 then
				ObjectHelpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2, 1.0)
			end
		end
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_shelled_act_lying L239-253
function koopa_inc.koopa_shelled_act_lying()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0.0 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
		end

		ObjBehaviors2.cur_obj_init_anim_extend(5)
		koopa_inc.koopa_dive_update_speed(F32(0.3))
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) ~= 0 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) - 1))
		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	elseif ObjBehaviors2.cur_obj_init_anim_and_check_if_end(6) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_STOPPED)
	end
end

-- from src/game/behaviors/koopa.inc.c:shelled_koopa_attack_handler L259-283
function koopa_inc.shelled_koopa_attack_handler(attackType: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.header.gfx.scale[1] > F32(0.8) then
		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KOOPA_DAMAGE)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType, IncludeObjectConstantsH.KOOPA_BP_UNSHELLED)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_LYING)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)

		if attackType ~= InteractionH.ATTACK_FROM_ABOVE and attackType ~= InteractionH.ATTACK_GROUND_POUND_OR_TWIRL then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.obj_angle_to_object(marioObj, o))
		end

		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_KOOPA_WITHOUT_SHELL)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_KOOPA_SHELL, BehaviorIds.bhvKoopaShell)

		ObjectHelpers.cur_obj_become_intangible()
	else
		ObjBehaviors2.obj_die_if_health_non_positive()
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_shelled_update L288-322
function koopa_inc.koopa_shelled_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oKoopaBlinkTimer, 20, 50, 4)

	if action == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_STOPPED then
		koopa_inc.koopa_shelled_act_stopped()
		koopa_inc.koopa_check_run_from_mario()
	elseif action == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_WALK then
		koopa_inc.koopa_shelled_act_walk()
	elseif action == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_RUN_FROM_MARIO then
		koopa_inc.koopa_shelled_act_run_from_mario()
	elseif action == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_LYING then
		koopa_inc.koopa_shelled_act_lying()
	end

	if o.header.gfx.scale[1] > F32(0.8) then
		ObjBehaviors2.obj_handle_attacks(koopa_inc.sKoopaHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction), koopa_inc.sKoopaShelledAttackHandlers)
	else
		ObjBehaviors2.obj_handle_attacks(koopa_inc.sKoopaHitbox, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_DIE, koopa_inc.sKoopaUnshelledAttackHandlers)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_DIE then
			ObjBehaviors2.obj_die_if_health_non_positive()
		end
	end

	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/behaviors/koopa.inc.c:koopa_unshelled_act_run L330-382
function koopa_inc.koopa_unshelled_act_run()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	Scratch.koopa_unshelled_act_run_distToShell[1] = 99999.0

	ObjectHelpers.cur_obj_init_animation_with_sound(3)
	koopa_inc.koopa_play_footstep_sound(0, 6)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), 0x600))
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		end

		const shell: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvKoopaShell, Scratch.koopa_unshelled_act_run_distToShell)

		if shell ~= nil then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw, ObjectHelpers.obj_angle_to_object(o, shell))
		else
			const turningAwayFromWall = ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall, turningAwayFromWall)

			if turningAwayFromWall == 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaUnshelledTimeUntilTurn) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaUnshelledTimeUntilTurn, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaUnshelledTimeUntilTurn) - 1))
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw, ObjBehaviors2.obj_random_fixed_turn(0x2000))
				end
			end
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 800.0 or (shell ~= nil and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000)) < 0x2000) then
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), 0x600)
		else
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000), 0x600)
		end
	end

	if ObjBehaviors2.obj_forward_vel_approach(20.0, 1.0) ~= 0 and Scratch.koopa_unshelled_act_run_distToShell[1] < 600.0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0xC00 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaTargetYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_DIVE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(1.2))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, Scratch.koopa_unshelled_act_run_distToShell[1] / 20.0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown, 20)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_unshelled_act_dive L388-435
function koopa_inc.koopa_unshelled_act_dive()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		ObjectHelpers.cur_obj_become_tangible()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		const shell: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvKoopaShell, Scratch.koopa_unshelled_act_dive_distToShell)

		if shell ~= nil and ObjectHelpers.dist_between_objects(shell, marioObj) > 200.0 and Scratch.koopa_unshelled_act_dive_distToShell[1] < 50.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType, IncludeObjectConstantsH.KOOPA_BP_NORMAL)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_SHELLED_ACT_LYING)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 0.5)

			ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_KOOPA_WITH_SHELL)
			ObjectHelpers.obj_mark_for_deletion(shell)

			return
		end
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0.0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_LYING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
			ObjBehaviors2.cur_obj_init_anim_extend(2)
		else
			ObjBehaviors2.cur_obj_init_anim_extend(5)
		end

		koopa_inc.koopa_dive_update_speed(0.5)
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) ~= 0 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaCountdown) - 1))
		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	elseif ObjBehaviors2.cur_obj_init_anim_and_check_if_end(6) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_RUN)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_unshelled_act_unused3 L440-442
function koopa_inc.koopa_unshelled_act_unused3()
	ObjBehaviors2.cur_obj_init_anim_extend(0)
end

-- from src/game/behaviors/koopa.inc.c:koopa_unshelled_update L447-466
function koopa_inc.koopa_unshelled_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oKoopaBlinkTimer, 10, 15, 3)

	if action == IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_RUN then
		koopa_inc.koopa_unshelled_act_run()
	elseif action == IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_DIVE or action == IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_LYING then
		koopa_inc.koopa_unshelled_act_dive()
	elseif action == IncludeObjectConstantsH.KOOPA_UNSHELLED_ACT_UNUSED3 then
		koopa_inc.koopa_unshelled_act_unused3()
	end

	ObjBehaviors2.obj_handle_attacks(koopa_inc.sKoopaHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction), koopa_inc.sKoopaUnshelledAttackHandlers)
	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/behaviors/koopa.inc.c:obj_begin_race L472-493
function koopa_inc.obj_begin_race(noTimer: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 50 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_RACE_GUN_SHOT)

		if noTimer == 0 then
			Audio.play_music(SeqPlayerLevel, bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_LEVEL_SLIDE), 0)

			LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_SHOW)
			LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_START)

			const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceBegun, IncludePRUltratypesH.TRUE)
		end

		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		ObjectHelpers.disable_time_stop_including_mario()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 50 then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_wait_before_race L498-512
function koopa_inc.koopa_the_quick_act_wait_before_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	koopa_inc.koopa_shelled_act_stopped()

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickInitTextboxCooldown) ~= 0 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickInitTextboxCooldown, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickInitTextboxCooldown) - 1))
	elseif ObjectHelpers.cur_obj_can_mario_activate_textbox_2(400.0, 400.0) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_SHOW_INIT_TEXT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(7)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_show_init_text L518-539
function koopa_inc.koopa_the_quick_act_show_init_text()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const response: number = ObjBehaviors2.obj_update_race_proposition_dialog(koopa_inc.sKoopaTheQuickProperties[buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickRaceIndex) + 1].initDialogID)

	if response == GroupsIngameMenuPlus1.DIALOG_RESPONSE_YES then
		ObjectListProcessor.gMarioShotFromCannon = IncludePRUltratypesH.FALSE
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_RACE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		o.parentObj = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvKoopaRaceEndpoint)
		o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = Memory.segmented_to_virtual(koopa_inc.sKoopaTheQuickProperties[buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickRaceIndex) + 1].path :: number)
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaTurningAwayFromWall, IncludePRUltratypesH.FALSE)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_ACTIVE_FROM_AFAR))
	elseif response == GroupsIngameMenuPlus1.DIALOG_RESPONSE_NO then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_WAIT_BEFORE_RACE)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickInitTextboxCooldown, 60)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_detect_bowling_ball L545-578
function koopa_inc.koopa_the_quick_detect_bowling_ball(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const ball: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvBowlingBall, Scratch.koopa_the_quick_detect_bowling_ball_distToBall)

	if ball ~= nil then
		const distToBall = Scratch.koopa_the_quick_detect_bowling_ball_distToBall[1]
		const angleToBall = S16(ObjectHelpers.obj_turn_toward_object(o, ball, IncludeObjectFieldsH.O_MOVE_ANGLE_YAW_INDEX, 0))
		const ballSpeedInKoopaRunDir = F32(buffer.readf32(ball.rawData, IncludeObjectFieldsH.oForwardVel) * SrcEngineMathUtilH.coss(buffer.readi32(ball.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), angleToBall) < 0x4000 then
			if distToBall < 400.0 then
				if ballSpeedInKoopaRunDir < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.7)) then
					return 1
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) - 2.0)
				end
			end
		elseif distToBall < 300.0 and ballSpeedInKoopaRunDir > buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) then
			return -1
		end
	end

	return 0
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_animate_footsteps L584-589
function koopa_inc.koopa_the_quick_animate_footsteps()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(9, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.09)))
	koopa_inc.koopa_play_footstep_sound(2, 17)
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_race L595-674
function koopa_inc.koopa_the_quick_act_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if koopa_inc.obj_begin_race(IncludePRUltratypesH.FALSE) ~= 0 then
		ObjectHelpers.cur_obj_push_mario_away_from_cylinder(180.0, 300.0)

		if ObjectHelpers.cur_obj_follow_path(0) == ObjectHelpersH.PATH_REACHED_END then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_DECELERATE)
		else
			const downhillSteepness = F32(1.0 + SrcEngineMathUtilH.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetPitch))))

			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw)), S16(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility) * 150.0))))

			const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

			if subAction == IncludeObjectConstantsH.KOOPA_THE_QUICK_SUB_ACT_START_RUN then
				koopa_inc.koopa_walk_start()
			elseif subAction == IncludeObjectConstantsH.KOOPA_THE_QUICK_SUB_ACT_RUN then
				koopa_inc.koopa_the_quick_animate_footsteps()

				if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus) ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1500.0 and bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags), 0x00FF) < 28 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, 8.0)
				elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickRaceIndex) ~= IncludeObjectConstantsH.KOOPA_THE_QUICK_BOB_INDEX then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, 6.0)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaAgility, 4.0)
				end

				ObjBehaviors2.obj_forward_vel_approach(F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility) * 6.0) * downhillSteepness), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility) * F32(0.1)))

				if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
				end

				const bowlingBallStatus = koopa_inc.koopa_the_quick_detect_bowling_ball()

				if bowlingBallStatus ~= 0 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) then
					if bowlingBallStatus < 0 then
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
					end

					if bowlingBallStatus ~= 0 or bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags), 0x00FF) >= 8 then
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 80.0)
					else
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
					end

					buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -6.0)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 2)
					buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)

					ObjectHelpers.cur_obj_init_animation_with_sound(12)
				end
			elseif subAction == IncludeObjectConstantsH.KOOPA_THE_QUICK_SUB_ACT_JUMP then
				if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
					if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(13) ~= 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) - 1))
					end

					koopa_inc.koopa_the_quick_detect_bowling_ball()
				end
			end
		end
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_decelerate L679-687
function koopa_inc.koopa_the_quick_act_decelerate()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_forward_vel_approach(3.0, 1.0)
	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(9, F32(0.99))

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_STOP)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_stop L692-700
function koopa_inc.koopa_the_quick_act_stop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	koopa_inc.koopa_walk_stop()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.KOOPA_SHELLED_ACT_STOPPED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_AFTER_RACE)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_act_after_race L707-747
function koopa_inc.koopa_the_quick_act_after_race()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
	const props = koopa_inc.sKoopaTheQuickProperties[buffer.readi16(o.rawData, IncludeObjectFieldsH.oKoopaTheQuickRaceIndex) + 1]

	ObjectHelpers.cur_obj_init_animation_with_sound(7)

	if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog) == 0 then
		if ObjectHelpers.cur_obj_can_mario_activate_textbox_2(400.0, 400.0) ~= 0 then
			Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_LEVEL_SLIDE))

			if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus) ~= 0 then
				if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus) < 0 then
					buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus, 0)
					buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog, IncludeDialogIdsH.DIALOG_006)
				else
					buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog, props.winDialogID)
				end
			else
				buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog, IncludeDialogIdsH.DIALOG_041)
			end

			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_ACTIVE_FROM_AFAR))))
		end
	elseif buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog) > 0 then
		const dialogResponse = ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog))

		if dialogResponse ~= 0 then
			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointDialog, IncludeDialogIdsH.DIALOG_NONE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus) ~= 0 then
		SpawnStarInc.spawn_default_star(props.starPos[1], props.starPos[2], props.starPos[3])

		buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus, 0)
	end
end

-- from src/game/behaviors/koopa.inc.c:koopa_the_quick_update L752-786
function koopa_inc.koopa_the_quick_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oKoopaBlinkTimer, 10, 15, 3)

	if action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_WAIT_BEFORE_RACE or action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_UNUSED1 then
		koopa_inc.koopa_the_quick_act_wait_before_race()
	elseif action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_SHOW_INIT_TEXT then
		koopa_inc.koopa_the_quick_act_show_init_text()
	elseif action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_RACE then
		koopa_inc.koopa_the_quick_act_race()
	elseif action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_DECELERATE then
		koopa_inc.koopa_the_quick_act_decelerate()
	elseif action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_STOP then
		koopa_inc.koopa_the_quick_act_stop()
	elseif action == IncludeObjectConstantsH.KOOPA_THE_QUICK_ACT_AFTER_RACE then
		koopa_inc.koopa_the_quick_act_after_race()
	end

	if o.parentObj ~= o then
		const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

		if ObjectHelpers.dist_between_objects(o, parentObj) < 400.0 then
			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointKoopaFinished, IncludePRUltratypesH.TRUE)
		end
	end

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(140.0, 300.0)
	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/behaviors/koopa.inc.c:bhv_koopa_update L791-820
function koopa_inc.bhv_koopa_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_KOOPA_FLYGUY_DEATH)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType) >= IncludeObjectConstantsH.KOOPA_BP_KOOPA_THE_QUICK_BASE then
		koopa_inc.koopa_the_quick_update()
	elseif ObjBehaviors2.obj_update_standard_actions(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaAgility) * 1.5)) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaDistanceToMario, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaAngleToMario, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		ObjBehaviors2.treat_far_home_as_mario(1000.0)

		const movementType = buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaMovementType)

		if movementType == IncludeObjectConstantsH.KOOPA_BP_UNSHELLED then
			koopa_inc.koopa_unshelled_update()
		elseif movementType == IncludeObjectConstantsH.KOOPA_BP_NORMAL then
			koopa_inc.koopa_shelled_update()
		elseif movementType == IncludeObjectConstantsH.KOOPA_BP_KOOPA_THE_QUICK_BOB or movementType == IncludeObjectConstantsH.KOOPA_BP_KOOPA_THE_QUICK_THI then
			koopa_inc.koopa_the_quick_update()
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	end

	ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 0x600)
end

-- from src/game/behaviors/koopa.inc.c:bhv_koopa_race_endpoint_update L825-841
function koopa_inc.bhv_koopa_race_endpoint_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceBegun) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceEnded) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointKoopaFinished) ~= 0 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 400.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceEnded, IncludePRUltratypesH.TRUE)
			LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_STOP)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointKoopaFinished) == 0 then
				Audio.play_race_fanfare()

				if ObjectListProcessor.gMarioShotFromCannon ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus, -1)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oKoopaRaceEndpointRaceStatus, 1)
				end
			end
		end
	end
end

return koopa_inc
