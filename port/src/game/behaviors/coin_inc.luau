--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/coin.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")

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

-- from src/game/behaviors/coin.inc.c:data
const coin_inc = {
	-- from src/game/behaviors/coin.inc.c:sYellowCoinHitbox L3-13
	sYellowCoinHitbox = {
		interactType = InteractionH.INTERACT_COIN,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 100,
		height = 64,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
	-- from src/game/behaviors/coin.inc.c:sCoinArrowPositions L159-168
	sCoinArrowPositions = {
		{ 0, -150 },
		{ 0, -50 },
		{ 0, 50 },
		{ 0, 150 },
		{ -50, 100 },
		{ -100, 50 },
		{ 50, 100 },
		{ 100, 50 },
	},
}

Registry.Register("src__game__behaviors__coin_inc", coin_inc)

-- from src/game/behaviors/coin.inc.c:bhv_coin_sparkles_init L15-26
function coin_inc.bhv_coin_sparkles_init(): number
	const o = ObjectListProcessor.gCurrentObject

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) and not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_TOUCHED_BOB_OMB) then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
		ObjectHelpers.obj_mark_for_deletion(o)
		return IncludePRUltratypesH.TRUE
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/coin.inc.c:bhv_yellow_coin_init L28-41
function coin_inc.bhv_yellow_coin_init()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_set_behavior(BehaviorIds.bhvYellowCoin)
	ObjectHelpers.obj_set_hitbox(o, coin_inc.sYellowCoinHitbox)
	ObjectHelpers.bhv_init_room()
	ObjectHelpers.cur_obj_update_floor_height()

	if 500 < ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))) then
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_YELLOW_COIN_NO_SHADOW)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/coin.inc.c:bhv_yellow_coin_loop L43-46
function coin_inc.bhv_yellow_coin_loop()
	const o = ObjectListProcessor.gCurrentObject

	coin_inc.bhv_coin_sparkles_init()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
end

-- from src/game/behaviors/coin.inc.c:bhv_temp_coin_loop L48-56
function coin_inc.bhv_temp_coin_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)

	if ObjectHelpers.cur_obj_wait_then_blink(200, 20) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	coin_inc.bhv_coin_sparkles_init()
end

-- from src/game/behaviors/coin.inc.c:bhv_spawned_coin_init L58-66
function coin_inc.bhv_spawned_coin_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(F32(SrcEngineBehaviorScript.random_float() * 10) + 30) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oCoinBaseVelY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineBehaviorScript.random_float() * 10)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())

	ObjectHelpers.cur_obj_set_behavior(BehaviorIds.bhvYellowCoin)
	ObjectHelpers.obj_set_hitbox(o, coin_inc.sYellowCoinHitbox)
	ObjectHelpers.cur_obj_become_intangible()
end

-- from src/game/behaviors/coin.inc.c:bhv_spawned_coin_loop L68-123
function coin_inc.bhv_spawned_coin_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_if_hit_wall_bounce_away()
	ObjectHelpers.cur_obj_move_standard(-62)

	-- from src/game/behaviors/coin.inc.c:floor
	const floor = o.ptrData[IncludeObjectFieldsH.oFloor + 1] :: GroupsTypesHPlus3.Surface?
	if floor ~= nil then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 1 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBounciness, 0)

			if floor.normal.y < 0.9 then
				-- from src/game/behaviors/coin.inc.c:sp1A
				const sp1A = SrcEngineMathUtil.atan2s(floor.normal.z, floor.normal.x)
				ObjectHelpers.cur_obj_rotate_yaw_toward(sp1A, 0x400)
			end
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_SPURT)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
		ObjectHelpers.cur_obj_become_tangible()
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_ABOVE_DEATH_BARRIER, IncludeObjectConstantsH.OBJ_MOVE_ABOVE_LAVA)) then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_BOUNCE) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCoinNumBounceSoundPlayed) < 5 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_DROP)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCoinNumBounceSoundPlayed, buffer.readi32(o.rawData, IncludeObjectFieldsH.oCoinNumBounceSoundPlayed) + 1)
	end

	if ObjectHelpers.cur_obj_wait_then_blink(400, 20) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	coin_inc.bhv_coin_sparkles_init()
end

-- from src/game/behaviors/coin.inc.c:bhv_coin_formation_spawn_loop L125-157
function coin_inc.bhv_coin_formation_spawn_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_set_behavior(BehaviorIds.bhvYellowCoin)
		ObjectHelpers.obj_set_hitbox(o, coin_inc.sYellowCoinHitbox)
		ObjectHelpers.bhv_init_room()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCoinOnGround) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 300)
			ObjectHelpers.cur_obj_update_floor_height()

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) or buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
				ObjectHelpers.obj_mark_for_deletion(o)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
			end
		else
			ObjectHelpers.cur_obj_update_floor_height()

			if ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))) > 250 then
				ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_YELLOW_COIN_NO_SHADOW)
			end
		end
	else
		if coin_inc.bhv_coin_sparkles_init() ~= 0 then
			const parent = o.parentObj :: GroupsTypesHPlus3.Object
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oCoinCollectedFlags, S32(bit32.bor(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oCoinCollectedFlags), ObjectHelpers.bit_shift_left(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
	end

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COIN_FORMATION_ACT_RESPAWN_COINS then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/coin.inc.c:spawn_coin_in_formation L170-220
function coin_inc.spawn_coin_in_formation(coinIndex: number, coinFormationFlags: number)
	const o = ObjectListProcessor.gCurrentObject

	local setSpawner = IncludePRUltratypesH.TRUE
	local onGround = IncludePRUltratypesH.TRUE

	local pos0 = 0
	local pos1 = 0
	local pos2 = 0

	const formation = bit32.band(coinFormationFlags, IncludeObjectConstantsH.COIN_FORMATION_BP_FLAG_MASK)

	if formation == IncludeObjectConstantsH.COIN_FORMATION_BP_LINE_HORIZONTAL then
		pos2 = 160 * (coinIndex - 2)
		if coinIndex > 4 then
			setSpawner = IncludePRUltratypesH.FALSE
		end
	elseif formation == IncludeObjectConstantsH.COIN_FORMATION_BP_LINE_VERTICAL then
		onGround = IncludePRUltratypesH.FALSE
		pos1 = TruncS32(160 * coinIndex * 0.8) -- 128 * coinIndex
		if coinIndex > 4 then
			setSpawner = IncludePRUltratypesH.FALSE
		end
	elseif formation == IncludeObjectConstantsH.COIN_FORMATION_BP_RING_HORIZONTAL then
		pos0 = TruncS32(F32(SrcEngineMathUtilH.sins(bit32.lshift(coinIndex, 13)) * 300))
		pos2 = TruncS32(F32(SrcEngineMathUtilH.coss(bit32.lshift(coinIndex, 13)) * 300))
	elseif formation == IncludeObjectConstantsH.COIN_FORMATION_BP_RING_VERTICAL then
		onGround = IncludePRUltratypesH.FALSE
		pos0 = TruncS32(F32(SrcEngineMathUtilH.coss(bit32.lshift(coinIndex, 13)) * 200))
		pos1 = TruncS32(F32(F32(SrcEngineMathUtilH.sins(bit32.lshift(coinIndex, 13)) * 200) + 200))
	elseif formation == IncludeObjectConstantsH.COIN_FORMATION_BP_ARROW then
		pos0 = coin_inc.sCoinArrowPositions[coinIndex + 1][1]
		pos2 = coin_inc.sCoinArrowPositions[coinIndex + 1][2]
	end

	if bit32.btest(coinFormationFlags, IncludeObjectConstantsH.COIN_FORMATION_BP_FLAG_FLYING) then
		onGround = IncludePRUltratypesH.FALSE
	end

	if setSpawner ~= 0 then
		const coinSpawner = ObjectHelpers.spawn_object_relative(S16(coinIndex), S16(pos0), S16(pos1), S16(pos2), o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvCoinFormationSpawn)

		buffer.writei32(coinSpawner.rawData, IncludeObjectFieldsH.oCoinOnGround, onGround)
	end
end

-- from src/game/behaviors/coin.inc.c:bhv_coin_formation_init L222-224
function coin_inc.bhv_coin_formation_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCoinCollectedFlags, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 256, 0xFF)))
end

-- from src/game/behaviors/coin.inc.c:bhv_coin_formation_loop L226-253
function coin_inc.bhv_coin_formation_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COIN_FORMATION_ACT_SPAWN_COINS then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
			for coinIndex = 0, 7 do
				if not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCoinCollectedFlags), bit32.lshift(1, coinIndex)) then
					coin_inc.spawn_coin_in_formation(coinIndex, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
				end
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COIN_FORMATION_ACT_IDLE then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COIN_FORMATION_ACT_RESPAWN_COINS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.COIN_FORMATION_ACT_SPAWN_COINS)
	end

	ObjectListProcessor.set_object_respawn_info_bits(o, U8(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCoinCollectedFlags), 0xFF)))
end

-- from src/game/behaviors/coin.inc.c:coin_inside_boo_act_1 L255-279
function coin_inc.coin_inside_boo_act_1()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_if_hit_wall_bounce_away()

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_BOUNCE) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_DROP)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		ObjectHelpers.obj_set_hitbox(o, coin_inc.sYellowCoinHitbox)
		ObjectHelpers.cur_obj_become_tangible()
		ObjectHelpers.cur_obj_set_behavior(BehaviorIds.bhvYellowCoin)
	end

	ObjectHelpers.cur_obj_move_standard(-30)
	coin_inc.bhv_coin_sparkles_init()

	if ObjectHelpers.cur_obj_has_model(IncludeModelIdsH.MODEL_BLUE_COIN) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 5)
	end

	if ObjectHelpers.cur_obj_wait_then_blink(400, 20) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/coin.inc.c:coin_inside_boo_act_0 L281-303
function coin_inc.coin_inside_boo_act_0()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_intangible()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BBH then
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BLUE_COIN)
		ObjectHelpers.cur_obj_scale(F32(0.7))
	end

	ObjectHelpers.obj_copy_pos(o, parent)

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBooDeathStatus) == IncludeObjectConstantsH.BOO_DEATH_STATUS_DYING then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		-- from src/game/behaviors/coin.inc.c:sp26
		const sp26 = S16(buffer.readi32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		-- from src/game/behaviors/coin.inc.c:sp20
		const sp20 = 3
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, SrcEngineMathUtilH.sins(sp26) * sp20)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, SrcEngineMathUtilH.coss(sp26) * sp20)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 35)
	end
end

-- from src/game/behaviors/coin.inc.c:bhv_coin_inside_boo_loop L310-312
function coin_inc.bhv_coin_inside_boo_loop()
	ObjectHelpers.cur_obj_call_action_function(coin_inc.sCoinInsideBooActions)
end

-- from src/game/behaviors/coin.inc.c:bhv_coin_sparkles_loop L314-316
function coin_inc.bhv_coin_sparkles_loop()
	ObjectHelpers.cur_obj_scale(F32(0.6))
end

-- from src/game/behaviors/coin.inc.c:bhv_golden_coin_sparkles_loop L318-326
function coin_inc.bhv_golden_coin_sparkles_loop()
	const o = ObjectListProcessor.gCurrentObject
	-- from src/game/behaviors/coin.inc.c:sp24
	const sp24 = 30

	const sparkles = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvCoinSparkles)

	buffer.writef32(sparkles.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(sparkles.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SrcEngineBehaviorScript.random_float() * sp24) - F32(sp24 / 2)))
	buffer.writef32(sparkles.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(sparkles.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(SrcEngineBehaviorScript.random_float() * sp24) - F32(sp24 / 2)))
end

-- from src/game/behaviors/coin.inc.c:sCoinInsideBooActions L305-308
coin_inc.sCoinInsideBooActions = { coin_inc.coin_inside_boo_act_0, coin_inc.coin_inside_boo_act_1 }

return coin_inc
