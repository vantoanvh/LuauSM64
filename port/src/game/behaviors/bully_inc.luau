--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bully.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const Camera = require("../camera")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const Audio = require("../../rom/audio_recorder")

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

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/bully.inc.c:data
const bully_inc = {
	-- from src/game/behaviors/bully.inc.c:sSmallBullyHitbox L3-13
	sSmallBullyHitbox = {
		interactType = InteractionH.INTERACT_BULLY,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 73,
		height = 123,
		hurtboxRadius = 63,
		hurtboxHeight = 113,
	},
	-- from src/game/behaviors/bully.inc.c:sBigBullyHitbox L15-25
	sBigBullyHitbox = {
		interactType = InteractionH.INTERACT_BULLY,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 115,
		height = 235,
		hurtboxRadius = 105,
		hurtboxHeight = 225,
	},
}

Registry.Register("src__game__behaviors__bully_inc", bully_inc)

-- from src/game/behaviors/bully.inc.c:bhv_small_bully_init L27-38
function bully_inc.bhv_small_bully_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation(0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 4.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.91)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.3)

	ObjectHelpers.obj_set_hitbox(o, bully_inc.sSmallBullyHitbox)
end

-- from src/game/behaviors/bully.inc.c:bhv_big_bully_init L40-52
function bully_inc.bhv_big_bully_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation(0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.BULLY_BP_SIZE_BIG)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.93)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.3)

	ObjectHelpers.obj_set_hitbox(o, bully_inc.sBigBullyHitbox)
end

-- from src/game/behaviors/bully.inc.c:bully_check_mario_collision L54-72
function bully_inc.bully_check_mario_collision()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_BULLY_ATTACKED)
		else
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_LARGE_BULLY_ATTACKED)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_INTERACTED))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_KNOCKBACK)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))
		ObjectHelpers.cur_obj_init_animation(3)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBullyMarioCollisionAngle, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	end
end

-- from src/game/behaviors/bully.inc.c:bully_act_chase_mario L74-98
function bully_inc.bully_act_chase_mario()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const HomeX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX)
	const PosY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	const HomeZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
		ObjectHelpers.obj_turn_toward_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 16, 0x1000)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 35 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end

	if ObjBehaviors.is_point_within_radius_of_mario(HomeX, PosY, HomeZ, 1000) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_PATROL)
		ObjectHelpers.cur_obj_init_animation(0)
	end
end

-- from src/game/behaviors/bully.inc.c:bully_act_knockback L100-116
function bully_inc.bully_act_knockback()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) < 10.0 and TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 1.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter) + 1))
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		ObjectHelpers.obj_turn_toward_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 16, 0x500)
	else
		o.header.gfx.animInfo.animFrame = 0
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter) == 18 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter, 0)
		ObjectHelpers.cur_obj_init_animation(1)
	end
end

-- from src/game/behaviors/bully.inc.c:bully_act_back_up L118-138
function bully_inc.bully_act_back_up()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)

	-- bully_backup_check() runs after this function and can reset the action to BULLY_ACT_BACK_UP on this frame: kept as in the C.

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_PATROL)
	end
end

-- from src/game/behaviors/bully.inc.c:bully_backup_check L140-146
function bully_inc.bully_backup_check(collisionFlags: number)
	collisionFlags = S16(TruncS32(collisionFlags))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if not bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_NO_Y_VEL) and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.BULLY_ACT_KNOCKBACK then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBullyPrevX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBullyPrevZ))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_BACK_UP)
	end
end

-- from src/game/behaviors/bully.inc.c:bully_play_stomping_sound L148-173
function bully_inc.bully_play_stomping_sound()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const animFrame: number = o.header.gfx.animInfo.animFrame
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BULLY_ACT_PATROL then
		if animFrame == 0 or animFrame == 12 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BULLY_WALK)
			else
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BULLY_WALKING)
			end
		end
	elseif action == IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO or action == IncludeObjectConstantsH.BULLY_ACT_BACK_UP then
		if animFrame == 0 or animFrame == 5 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BULLY_WALK)
			else
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BULLY_WALKING)
			end
		end
	end
end

-- from src/game/behaviors/bully.inc.c:bully_step L175-188
function bully_inc.bully_step()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const collisionFlags = S16(ObjBehaviors.object_step())

	bully_inc.bully_backup_check(collisionFlags)
	bully_inc.bully_play_stomping_sound()
	ObjBehaviors.obj_check_floor_death(collisionFlags, ObjBehaviors.sObjFloor)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullySubtype), IncludeObjectConstantsH.BULLY_STYPE_CHILL) then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < 1030.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_LAVA_DEATH)
		end
	end
end

-- from src/game/behaviors/bully.inc.c:bully_spawn_coin L190-199
function bully_inc.bully_spawn_coin()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const coin: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvMovingYellowCoin)

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_SPURT)

	buffer.writef32(coin.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
	buffer.writef32(coin.rawData, IncludeObjectFieldsH.oVelY, 100.0)
	buffer.writef32(coin.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 310.0)
	buffer.writei32(coin.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullyMarioCollisionAngle) + 0x8000) + F32(SrcEngineBehaviorScript.random_float() * 1024.0))))
end

-- from src/game/behaviors/bully.inc.c:bully_act_level_death L201-220
function bully_inc.bully_act_level_death()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjBehaviors.obj_lava_death() == IncludePRUltratypesH.TRUE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullySubtype) == IncludeObjectConstantsH.BULLY_STYPE_MINION then
				const parent = o.parentObj :: GroupsTypesHPlus3.Object

				buffer.writei32(parent.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter, S32(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter) + 1))
			end

			bully_inc.bully_spawn_coin()
		else
			ObjectHelpers.spawn_mist_particles()

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullySubtype) == IncludeObjectConstantsH.BULLY_STYPE_CHILL then
				SpawnStarInc.spawn_default_star(130.0, 1600.0, -4335.0)
			else
				SpawnStarInc.spawn_default_star(0, 950.0, -6800.0)
				ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvLLLTumblingBridge, 0, 154, -5631, 0, 0, 0)
			end
		end
	end
end

-- from src/game/behaviors/bully.inc.c:bhv_bully_loop L222-270
function bully_inc.bhv_bully_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	-- The C notes that Mario can interrupt the death action by colliding with the bully under a lava floor (kept as in the C).
	bully_inc.bully_check_mario_collision()

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BULLY_ACT_PATROL then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)

		if ObjBehaviors.obj_return_home_if_safe(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 800) == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO)
			ObjectHelpers.cur_obj_init_animation(1)
		end

		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO then
		bully_inc.bully_act_chase_mario()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_KNOCKBACK then
		bully_inc.bully_act_knockback()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_BACK_UP then
		bully_inc.bully_act_back_up()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_LAVA_DEATH then
		bully_inc.bully_act_level_death()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_DEATH_PLANE_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/bully.inc.c:big_bully_spawn_minion L272-277
function bully_inc.big_bully_spawn_minion(x: number, y: number, z: number, yaw: number)
	yaw = S16(TruncS32(yaw))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const bully = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_BULLY, BehaviorIds.bhvSmallBully, S16(x), S16(y), S16(z), 0, yaw, 0)

	buffer.writei32(bully.rawData, IncludeObjectFieldsH.oBullySubtype, IncludeObjectConstantsH.BULLY_STYPE_MINION)
	buffer.writei32(bully.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.BULLY_BP_SIZE_SMALL)
end

-- from src/game/behaviors/bully.inc.c:bhv_big_bully_with_minions_init L279-289
function bully_inc.bhv_big_bully_with_minions_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	bully_inc.big_bully_spawn_minion(4454, 307, -5426, 0)
	bully_inc.big_bully_spawn_minion(3840, 307, -6041, 0)
	bully_inc.big_bully_spawn_minion(3226, 307, -5426, 0)

	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))

	ObjectHelpers.cur_obj_become_intangible()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_INACTIVE)
end

-- from src/game/behaviors/bully.inc.c:big_bully_spawn_star L291-296
function bully_inc.big_bully_spawn_star()
	if ObjBehaviors.obj_lava_death() == IncludePRUltratypesH.TRUE then
		ObjectHelpers.spawn_mist_particles()
		SpawnStarInc.spawn_default_star(3700.0, 600.0, -5500.0)
	end
end

-- from src/game/behaviors/bully.inc.c:bhv_big_bully_with_minions_loop L298-372
function bully_inc.bhv_big_bully_with_minions_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBullyPrevZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	bully_inc.bully_check_mario_collision()

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BULLY_ACT_PATROL then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)

		if ObjBehaviors.obj_return_home_if_safe(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 1000) == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO)
			ObjectHelpers.cur_obj_init_animation(1)
		end

		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_CHASE_MARIO then
		bully_inc.bully_act_chase_mario()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_KNOCKBACK then
		bully_inc.bully_act_knockback()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_BACK_UP then
		bully_inc.bully_act_back_up()
		bully_inc.bully_step()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_INACTIVE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBullyKBTimerAndMinionKOCounter) == 3 then
			Audio.play_puzzle_jingle()

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_ACTIVATE_AND_FALL)
			end
		end
	elseif action == IncludeObjectConstantsH.BULLY_ACT_ACTIVATE_AND_FALL then
		const collisionFlags = S16(ObjBehaviors.object_step())

		if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAGS_LANDED then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BULLY_ACT_PATROL)
		end

		if collisionFlags == ObjBehaviors.OBJ_COL_FLAG_GROUNDED then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_THWOMP)
			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			ObjectHelpers.spawn_mist_particles()
		end

		o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		ObjectHelpers.cur_obj_become_tangible()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_LAVA_DEATH then
		bully_inc.big_bully_spawn_star()
	elseif action == IncludeObjectConstantsH.BULLY_ACT_DEATH_PLANE_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return bully_inc
