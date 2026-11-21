--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bobomb.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const CorkboxInc = require("./corkbox_inc")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const SaveFile = require("../save_file")
const Area = require("../area")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")

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

-- from src/game/behaviors/bobomb.inc.c:data
const bobomb_inc = {
	-- from src/game/behaviors/bobomb.inc.c:sBobombHitbox L3-13
	sBobombHitbox = {
		interactType = InteractionH.INTERACT_GRABBABLE,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 65,
		height = 113,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__bobomb_inc", bobomb_inc)

-- from src/game/behaviors/bobomb.inc.c:bhv_bobomb_init L15-20
function bobomb_inc.bhv_bobomb_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, F32(0.8))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, F32(1.3))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_KICKABLE)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_spawn_coin L22-28
function bobomb_inc.bobomb_spawn_coin()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 8, 0x01) == 0 then
		ObjBehaviors.obj_spawn_yellow_coins(o, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams, 0x100)
		ObjectListProcessor.set_object_respawn_info_bits(o, 1)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_act_explode L30-42
function bobomb_inc.bobomb_act_explode()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 5 then
		ObjectHelpers.cur_obj_scale(F32(1.0 + buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 5.0))
	else
		const explosion = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_EXPLOSION, BehaviorIds.bhvExplosion)
		buffer.writef32(explosion.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(explosion.rawData, IncludeObjectFieldsH.oGraphYOffset) + 100.0)
		bobomb_inc.bobomb_spawn_coin()
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BLACK_BOBOMB, BehaviorIds.bhvBobomb, 3000)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_check_interactions L44-65
function bobomb_inc.bobomb_check_interactions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, bobomb_inc.sBobombHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_KNOCKBACK_DMG) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).header.gfx.angle[2])
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_LAUNCHED)
		end

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_TOUCHED_BOB_OMB) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end

	if ObjectHelpers.obj_attack_collided_from_other_object(o) == IncludePRUltratypesH.TRUE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_act_patrol L67-82
function bobomb_inc.bobomb_act_patrol()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)
	const collisionFlags = S16(ObjBehaviors.object_step())

	if ObjBehaviors.obj_return_home_if_safe(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 400) == IncludePRUltratypesH.TRUE and ObjBehaviors.obj_check_if_facing_toward_angle(U32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), U32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x2000) == IncludePRUltratypesH.TRUE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombFuseLit, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_CHASE_MARIO)
	end

	ObjBehaviors.obj_check_floor_death(collisionFlags, ObjBehaviors.sObjFloor)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_act_chase_mario L84-98
function bobomb_inc.bobomb_act_chase_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.animInfo.animFrame = S16(o.header.gfx.animInfo.animFrame + 1)
	const animFrame = o.header.gfx.animInfo.animFrame

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	const collisionFlags = S16(ObjBehaviors.object_step())

	if animFrame == 5 or animFrame == 16 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOBOMB_WALK)
	end

	ObjectHelpers.obj_turn_toward_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 16, 0x800)
	ObjBehaviors.obj_check_floor_death(collisionFlags, ObjBehaviors.sObjFloor)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_act_launched L100-106
function bobomb_inc.bobomb_act_launched()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) == ObjBehaviors.OBJ_COL_FLAG_GROUNDED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/bobomb.inc.c:generic_bobomb_free_loop L108-143
function bobomb_inc.generic_bobomb_free_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOBOMB_ACT_PATROL then
		bobomb_inc.bobomb_act_patrol()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_LAUNCHED then
		bobomb_inc.bobomb_act_launched()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_CHASE_MARIO then
		bobomb_inc.bobomb_act_chase_mario()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE then
		bobomb_inc.bobomb_act_explode()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_LAVA_DEATH then
		if ObjBehaviors.obj_lava_death() == IncludePRUltratypesH.TRUE then
			CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BLACK_BOBOMB, BehaviorIds.bhvBobomb, 3000)
		end
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_DEATH_PLANE_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BLACK_BOBOMB, BehaviorIds.bhvBobomb, 3000)
	end

	bobomb_inc.bobomb_check_interactions()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer) > 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/bobomb.inc.c:stationary_bobomb_free_loop L145-172
function bobomb_inc.stationary_bobomb_free_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOBOMB_ACT_LAUNCHED then
		bobomb_inc.bobomb_act_launched()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE then
		bobomb_inc.bobomb_act_explode()
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_LAVA_DEATH then
		if ObjBehaviors.obj_lava_death() == IncludePRUltratypesH.TRUE then
			CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BLACK_BOBOMB, BehaviorIds.bhvBobomb, 3000)
		end
	elseif action == IncludeObjectConstantsH.BOBOMB_ACT_DEATH_PLANE_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BLACK_BOBOMB, BehaviorIds.bhvBobomb, 3000)
	end

	bobomb_inc.bobomb_check_interactions()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer) > 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_free_loop L174-180
function bobomb_inc.bobomb_free_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOBOMB_BP_STYPE_GENERIC then
		bobomb_inc.generic_bobomb_free_loop()
	else
		bobomb_inc.stationary_bobomb_free_loop()
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_held_loop L182-195
function bobomb_inc.bobomb_held_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
	ObjectHelpers.cur_obj_init_animation(1)
	ObjectHelpers.cur_obj_set_pos_relative(marioObj, 0, 60.0, 100.0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombFuseLit, 1)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer) > 150 then
		-- Although the Bob-omb's action is set to explode when the fuse timer expires,
		-- bobomb_act_explode() will not execute until the bob-omb's held state changes.
		-- This allows the Bob-omb to be regrabbed indefinitely.
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_DROP_OBJECT)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_dropped_loop L197-205
function bobomb_inc.bobomb_dropped_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_get_dropped()

	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	ObjectHelpers.cur_obj_init_animation(0)

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_PATROL)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_thrown_loop L207-216
function bobomb_inc.bobomb_thrown_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_enable_rendering_2()

	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, 0)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_ACT_LAUNCHED)
end

-- from src/game/behaviors/bobomb.inc.c:curr_obj_random_blink L218-240
function bobomb_inc.curr_obj_random_blink(Buffer: buffer, Offset: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(Buffer, Offset) == 0 then
		if S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0))) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
			buffer.writei32(Buffer, Offset, 1)
		end
	else
		buffer.writei32(Buffer, Offset, buffer.readi32(Buffer, Offset) + 1)

		if buffer.readi32(Buffer, Offset) > 5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
		end

		if buffer.readi32(Buffer, Offset) > 10 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
		end

		if buffer.readi32(Buffer, Offset) > 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
			buffer.writei32(Buffer, Offset, 0)
		end
	end
end

-- from src/game/behaviors/bobomb.inc.c:bhv_bobomb_loop L242-283
function bobomb_inc.bhv_bobomb_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 4000) ~= 0 then
		const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

		if heldState == IncludeObjectConstantsH.HELD_FREE then
			bobomb_inc.bobomb_free_loop()
		elseif heldState == IncludeObjectConstantsH.HELD_HELD then
			bobomb_inc.bobomb_held_loop()
		elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
			bobomb_inc.bobomb_thrown_loop()
		elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
			bobomb_inc.bobomb_dropped_loop()
		end

		bobomb_inc.curr_obj_random_blink(o.rawData, IncludeObjectFieldsH.oBobombBlinkTimer)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseLit) == 1 then
			const dustPeriodMinus1 = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer) > 120 then 1 else 7

			-- oBobombFuseTimer % 2 or oBobombFuseTimer % 8
			if bit32.band(dustPeriodMinus1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer)) == 0 then
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvBobombFuseSmoke)
			end

			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BOBOMB_LIT_FUSE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombFuseTimer) + 1)
		end
	end
end

-- from src/game/behaviors/bobomb.inc.c:bhv_bobomb_fuse_smoke_init L285-290
function bobomb_inc.bhv_bobomb_fuse_smoke_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + (TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)) - 40))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + (TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)) + 60))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + (TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)) - 40))
	ObjectHelpers.cur_obj_scale(F32(1.2))
end

-- from src/game/behaviors/bobomb.inc.c:bhv_bobomb_buddy_init L292-297
function bobomb_inc.bhv_bobomb_buddy_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, F32(0.8))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, F32(1.3))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_NPC)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_buddy_act_idle L299-321
function bobomb_inc.bobomb_buddy_act_idle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBobombBuddyPosXCopy, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBobombBuddyPosYCopy, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBobombBuddyPosZCopy, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	ObjBehaviors.object_step()

	if animFrame == 5 or animFrame == 16 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOBOMB_WALK)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x140))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus) == InteractionH.INT_STATUS_INTERACTED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_TURN_TO_TALK)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_buddy_cannon_dialog L331-374
function bobomb_inc.bobomb_buddy_cannon_dialog(dialogFirstText: number, dialogSecondText: number)
	dialogFirstText = S16(TruncS32(dialogFirstText))
	dialogSecondText = S16(TruncS32(dialogSecondText))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const status = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus)

	if status == IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_UNOPENED then
		const buddyText = S16(Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, dialogFirstText))

		if buddyText ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
			SaveFile.save_file_set_cannon_unlocked()

			const cannonClosed: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvCannonClosed)

			if cannonClosed ~= nil then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus, IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_OPENING)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus, IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_STOP_TALKING)
			end
		end
	elseif status == IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_OPENING then
		const cannonClosed: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvCannonClosed)
		const cutscene = S16(Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_PREPARE_CANNON, cannonClosed :: GroupsTypesHPlus3.Object))

		if cutscene == -1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus, IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_OPENED)
		end
	elseif status == IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_OPENED then
		const buddyText = S16(Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, dialogSecondText))

		if buddyText ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus, IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_STOP_TALKING)
		end
	elseif status == IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_STOP_TALKING then
		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyHasTalkedToMario, IncludeObjectConstantsH.BOBOMB_BUDDY_HAS_TALKED)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_IDLE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyCannonStatus, IncludeObjectConstantsH.BOBOMB_BUDDY_CANNON_OPENED)
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_buddy_act_talk L376-402
function bobomb_inc.bobomb_buddy_act_talk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
		o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))

		const role = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombBuddyRole)

		if role == IncludeObjectConstantsH.BOBOMB_BUDDY_ROLE_ADVICE then
			if S16(Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))) ~= IncludeObjectConstantsH.BOBOMB_BUDDY_BP_STYPE_GENERIC then
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
				o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombBuddyHasTalkedToMario, IncludeObjectConstantsH.BOBOMB_BUDDY_HAS_TALKED)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_IDLE)
			end
		elseif role == IncludeObjectConstantsH.BOBOMB_BUDDY_ROLE_CANNON then
			if Area.gCurrCourseNum == IncludeCourseTableH.COURSE_BOB then
				bobomb_inc.bobomb_buddy_cannon_dialog(IncludeDialogIdsH.DIALOG_004, IncludeDialogIdsH.DIALOG_105)
			else
				bobomb_inc.bobomb_buddy_cannon_dialog(IncludeDialogIdsH.DIALOG_047, IncludeDialogIdsH.DIALOG_106)
			end
		end
	end
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_buddy_act_turn_to_talk L404-418
function bobomb_inc.bobomb_buddy_act_turn_to_talk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame

	if animFrame == 5 or animFrame == 16 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOBOMB_WALK)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x1000))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) == S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_TALK)
	end

	Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_ACTION_READ_SIGN)
end

-- from src/game/behaviors/bobomb.inc.c:bobomb_buddy_actions L420-436
function bobomb_inc.bobomb_buddy_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_IDLE then
		bobomb_inc.bobomb_buddy_act_idle()
	elseif action == IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_TURN_TO_TALK then
		bobomb_inc.bobomb_buddy_act_turn_to_talk()
	elseif action == IncludeObjectConstantsH.BOBOMB_BUDDY_ACT_TALK then
		bobomb_inc.bobomb_buddy_act_talk()
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/bobomb.inc.c:bhv_bobomb_buddy_loop L438-444
function bobomb_inc.bhv_bobomb_buddy_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	bobomb_inc.bobomb_buddy_actions()
	bobomb_inc.curr_obj_random_blink(o.rawData, IncludeObjectFieldsH.oBobombBuddyBlinkTimer)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return bobomb_inc
