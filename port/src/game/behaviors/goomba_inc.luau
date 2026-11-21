--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/goomba.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeSoundsH = require("../../../include/sounds_h")

const InteractionH = require("../interaction_h")
const ObjBehaviors2H = require("../obj_behaviors_2_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
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

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/behaviors/goomba.inc.c:data
const goomba_inc = {
	-- from src/game/behaviors/goomba.inc.c:sGoombaHitbox L11-21
	sGoombaHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 1,
		radius = 72,
		height = 50,
		hurtboxRadius = 42,
		hurtboxHeight = 40,
	},
	-- from src/game/behaviors/goomba.inc.c:sGoombaProperties L36-40
	sGoombaProperties = {
		{
			scale = 1.5,
			deathSound = IncludeSoundsH.SOUND_OBJ_ENEMY_DEATH_HIGH,
			drawDistance = 4000,
			damage = 1,
		},
		{
			scale = 3.5,
			deathSound = IncludeSoundsH.SOUND_OBJ_ENEMY_DEATH_LOW,
			drawDistance = 4000,
			damage = 2,
		},
		{
			scale = 0.5,
			deathSound = IncludeSoundsH.SOUND_OBJ_ENEMY_DEATH_HIGH,
			drawDistance = 1500,
			damage = 0,
		},
	},
	-- from src/game/behaviors/goomba.inc.c:sGoombaAttackHandlers L45-64
	sGoombaAttackHandlers = {
		{
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
			ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		},
		{
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_HUGE_GOOMBA_WEAKLY_ATTACKED,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_HUGE_GOOMBA_WEAKLY_ATTACKED,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
			ObjBehaviors2H.ATTACK_HANDLER_SQUISHED_WITH_BLUE_COIN,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_HUGE_GOOMBA_WEAKLY_ATTACKED,
			ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_HUGE_GOOMBA_WEAKLY_ATTACKED,
		},
	},
}

Registry.Register("src__game__behaviors__goomba_inc", goomba_inc)

-- from src/game/behaviors/goomba.inc.c:bhv_goomba_triplet_spawner_update L69-103
function goomba_inc.bhv_goomba_triplet_spawner_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.GOOMBA_TRIPLET_SPAWNER_ACT_UNLOADED then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 3000.0 then
			const dAngle = 0x10000 // ((bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.GOOMBA_TRIPLET_SPAWNER_BP_EXTRA_GOOMBAS_MASK) // 4) + 3)
			local angle = 0
			local goombaFlag = 0x100

			while angle < 0xFFFF do
				if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), goombaFlag) == 0 then
					const dx = S16(TruncS32(F32(500.0 * SrcEngineMathUtilH.coss(angle))))
					const dz = S16(TruncS32(F32(500.0 * SrcEngineMathUtilH.sins(angle))))

					ObjectHelpers.spawn_object_relative(S16(bit32.bor(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.GOOMBA_BP_SIZE_MASK), goombaFlag // 64)), dx, 0, dz, o, IncludeModelIdsH.MODEL_GOOMBA, BehaviorIds.bhvGoomba)
				end

				angle += dAngle
				goombaFlag = S16(bit32.lshift(goombaFlag, 1))
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 4000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GOOMBA_TRIPLET_SPAWNER_ACT_UNLOADED)
	end
end

-- from src/game/behaviors/goomba.inc.c:bhv_goomba_init L108-120
function goomba_inc.bhv_goomba_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaSize, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.GOOMBA_BP_SIZE_MASK)))

	const properties = goomba_inc.sGoombaProperties[buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaSize) + 1]

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGoombaScale, properties.scale)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, properties.deathSound)

	ObjectHelpers.obj_set_hitbox(o, goomba_inc.sGoombaHitbox)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oDrawingDistance, properties.drawDistance)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, properties.damage)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, F32(-8.0 / 3.0) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale))
end

-- from src/game/behaviors/goomba.inc.c:goomba_begin_jump L125-131
function goomba_inc.goomba_begin_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_GOOMBA_ALERT)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GOOMBA_ACT_JUMP)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(50.0 / 3.0) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale))
end

-- from src/game/behaviors/goomba.inc.c:mark_goomba_as_dead L138-146
function goomba_inc.mark_goomba_as_dead()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.parentObj ~= o then
		const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

		ObjectListProcessor.set_object_respawn_info_bits(parentObj, U8(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.GOOMBA_BP_TRIPLET_RESPAWN_FLAG_MASK) // 4))

		buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.bor(buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oBhvParams), bit32.lshift(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.GOOMBA_BP_TRIPLET_RESPAWN_FLAG_MASK), 6))))
	end
end

-- from src/game/behaviors/goomba.inc.c:goomba_act_walk L152-212
function goomba_inc.goomba_act_walk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.treat_far_home_as_mario(1000.0)
	ObjBehaviors2.obj_forward_vel_approach(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaRelativeSpeed) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale)), F32(0.4))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaRelativeSpeed) > F32(4.0 / 3.0) then
		ObjBehaviors2.cur_obj_play_sound_at_anim_range(2, 17, IncludeSoundsH.SOUND_OBJ_GOOMBA_WALK)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaTurningAwayFromWall) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw)), 0x200))
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaWalkTimer, ObjBehaviors2.random_linear_offset(20, 30))
		end

		const turningAwayFromWall = ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTurningAwayFromWall, turningAwayFromWall)

		if turningAwayFromWall == 0 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaRelativeSpeed) <= 2.0 then
					goomba_inc.goomba_begin_jump()
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGoombaRelativeSpeed, 20.0)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oGoombaRelativeSpeed, 4.0 / 3.0)

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaWalkTimer) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaWalkTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaWalkTimer) - 1))
				else
					if bit32.btest(SrcEngineBehaviorScript.random_u16(), 3) then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw, ObjBehaviors2.obj_random_fixed_turn(0x2000))
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaWalkTimer, ObjBehaviors2.random_linear_offset(100, 100))
					else
						goomba_inc.goomba_begin_jump()
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw, ObjBehaviors2.obj_random_fixed_turn(0x6000))
					end
				end
			end
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw)), 0x200)
	end
end

-- from src/game/behaviors/goomba.inc.c:goomba_act_attacked_mario L218-230
function goomba_inc.goomba_act_attacked_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaSize) == IncludeObjectConstantsH.GOOMBA_SIZE_TINY then
		goomba_inc.mark_goomba_as_dead()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
		ObjBehaviors2.obj_die_if_health_non_positive()
	else
		goomba_inc.goomba_begin_jump()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oGoombaTurningAwayFromWall, IncludePRUltratypesH.FALSE)
	end
end

-- from src/game/behaviors/goomba.inc.c:goomba_act_jump L235-250
function goomba_inc.goomba_act_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_resolve_object_collisions(nil)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GOOMBA_ACT_WALK)
	else
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaTargetYaw)), 0x800)
	end
end

-- from src/game/behaviors/goomba.inc.c:huge_goomba_weakly_attacked L258-260
function goomba_inc.huge_goomba_weakly_attacked()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.GOOMBA_ACT_ATTACKED_MARIO)
end

-- from src/game/behaviors/goomba.inc.c:bhv_goomba_update L265-315
function goomba_inc.bhv_goomba_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.obj_update_standard_actions(buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale)) ~= 0 then
		if o.parentObj ~= o then
			const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

			if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.GOOMBA_TRIPLET_SPAWNER_ACT_UNLOADED then
				ObjectHelpers.obj_mark_for_deletion(o)
			end
		end

		ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale))
		ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oGoombaBlinkTimer, 30, 50, 5)
		ObjectHelpers.cur_obj_update_floor_and_walls()

		local animSpeed = F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) / buffer.readf32(o.rawData, IncludeObjectFieldsH.oGoombaScale)) * F32(0.4))

		if animSpeed < 1.0 then
			animSpeed = 1.0
		end

		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, animSpeed)

		const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if action == IncludeObjectConstantsH.GOOMBA_ACT_WALK then
			goomba_inc.goomba_act_walk()
		elseif action == IncludeObjectConstantsH.GOOMBA_ACT_ATTACKED_MARIO then
			goomba_inc.goomba_act_attacked_mario()
		elseif action == IncludeObjectConstantsH.GOOMBA_ACT_JUMP then
			goomba_inc.goomba_act_jump()
		end

		if ObjBehaviors2.obj_handle_attacks(goomba_inc.sGoombaHitbox, IncludeObjectConstantsH.GOOMBA_ACT_ATTACKED_MARIO, goomba_inc.sGoombaAttackHandlers[bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oGoombaSize), 1) + 1]) ~= 0 then
			goomba_inc.mark_goomba_as_dead()
		end

		ObjectHelpers.cur_obj_move_standard(-78)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	end
end

return goomba_inc
