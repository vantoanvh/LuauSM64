--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/moving_coin.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/moving_coin_inc.luau:scratch
const Scratch = {
	moving_coin_flicker_collisionFlags = { 0 },
	bhv_moving_yellow_coin_loop_collisionFlags = { 0 },
	bhv_blue_coin_sliding_loop_collisionFlags = { 0 },
	bhv_blue_coin_jumping_loop_collisionFlags = { 0 },
	blue_coin_sliding_away_from_mario_collisionFlags = { 0 },
	blue_coin_sliding_slow_down_collisionFlags = { 0 },
}

-- from src/game/behaviors/moving_coin.inc.c:data
const moving_coin_inc = {
	-- from src/game/behaviors/moving_coin.inc.c:sMovingYellowCoinHitbox L3-13
	sMovingYellowCoinHitbox = {
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
	-- from src/game/behaviors/moving_coin.inc.c:sMovingBlueCoinHitbox L15-25
	sMovingBlueCoinHitbox = {
		interactType = InteractionH.INTERACT_COIN,
		downOffset = 0,
		damageOrCoinValue = 5,
		health = 0,
		numLootCoins = 0,
		radius = 100,
		height = 64,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__moving_coin_inc", moving_coin_inc)

-- from src/game/behaviors/moving_coin.inc.c:coin_step L27-39
function moving_coin_inc.coin_step(collisionFlagsPtr: { number }): number
	collisionFlagsPtr[1] = S16(ObjBehaviors.object_step())

	ObjBehaviors.obj_check_floor_death(collisionFlagsPtr[1], ObjBehaviors.sObjFloor)

	if bit32.btest(collisionFlagsPtr[1], ObjBehaviors.OBJ_COL_FLAG_GROUNDED) and not bit32.btest(collisionFlagsPtr[1], ObjBehaviors.OBJ_COL_FLAG_NO_Y_VEL) then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_DROP)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/moving_coin.inc.c:moving_coin_flicker L41-46
function moving_coin_inc.moving_coin_flicker()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	moving_coin_inc.coin_step(Scratch.moving_coin_flicker_collisionFlags)
	ObjBehaviors.obj_flicker_and_disappear(o, 0)
end

-- from src/game/behaviors/moving_coin.inc.c:coin_collected L48-51
function moving_coin_inc.coin_collected()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
	o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_moving_yellow_coin_init L53-59
function moving_coin_inc.bhv_moving_yellow_coin_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.5)

	ObjectHelpers.obj_set_hitbox(o, moving_coin_inc.sMovingYellowCoinHitbox)
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_moving_yellow_coin_loop L61-96
function moving_coin_inc.bhv_moving_yellow_coin_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MOV_YCOIN_ACT_IDLE then
		moving_coin_inc.coin_step(Scratch.bhv_moving_yellow_coin_loop_collisionFlags)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
			ObjectHelpers.cur_obj_become_intangible()
		else
			ObjectHelpers.cur_obj_become_tangible()
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 300 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MOV_YCOIN_ACT_BLINKING)
		end
	elseif action == IncludeObjectConstantsH.MOV_YCOIN_ACT_BLINKING then
		moving_coin_inc.moving_coin_flicker()
	elseif action == IncludeObjectConstantsH.MOV_YCOIN_ACT_LAVA_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	elseif action == IncludeObjectConstantsH.MOV_YCOIN_ACT_DEATH_PLANE_DEATH then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		moving_coin_inc.coin_collected()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_moving_blue_coin_init L98-104
function moving_coin_inc.bhv_moving_blue_coin_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.5)

	ObjectHelpers.obj_set_hitbox(o, moving_coin_inc.sMovingBlueCoinHitbox)
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_moving_blue_coin_loop L106-140
function moving_coin_inc.bhv_moving_blue_coin_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MOV_BCOIN_ACT_STILL then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1500) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MOV_BCOIN_ACT_MOVING)
		end
	elseif action == IncludeObjectConstantsH.MOV_BCOIN_ACT_MOVING then
		const collisionFlags = S16(ObjBehaviors.object_step())

		if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) + 25.0)
			if not bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_NO_Y_VEL) then
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_COIN_DROP)
			end
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 0.98)
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 75.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 75.0)
		end

		ObjBehaviors.obj_flicker_and_disappear(o, 600)
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		moving_coin_inc.coin_collected()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_blue_coin_sliding_jumping_init L142-148
function moving_coin_inc.bhv_blue_coin_sliding_jumping_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.98)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.5)

	ObjectHelpers.obj_set_hitbox(o, moving_coin_inc.sMovingBlueCoinHitbox)
end

-- from src/game/behaviors/moving_coin.inc.c:blue_coin_sliding_away_from_mario L150-167
function moving_coin_inc.blue_coin_sliding_away_from_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000)
	if moving_coin_inc.coin_step(Scratch.blue_coin_sliding_away_from_mario_collisionFlags) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + 18.0)
	end

	if bit32.btest(Scratch.blue_coin_sliding_away_from_mario_collisionFlags[1], ObjBehaviors.OBJ_COL_FLAG_HIT_WALL) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/moving_coin.inc.c:blue_coin_sliding_slow_down L169-181
function moving_coin_inc.blue_coin_sliding_slow_down()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	moving_coin_inc.coin_step(Scratch.blue_coin_sliding_slow_down_collisionFlags)

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 500) == IncludePRUltratypesH.TRUE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_blue_coin_sliding_loop L183-228
function moving_coin_inc.bhv_blue_coin_sliding_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 500) == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end

		ObjBehaviors.set_object_visibility(o, 3000)
	elseif action == 1 then
		moving_coin_inc.blue_coin_sliding_away_from_mario()
	elseif action == 2 then
		moving_coin_inc.blue_coin_sliding_slow_down()
		ObjBehaviors.set_object_visibility(o, 3000)
	elseif action == 3 then
		moving_coin_inc.coin_step(Scratch.bhv_blue_coin_sliding_loop_collisionFlags)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
		end
	elseif action == 4 then
		moving_coin_inc.moving_coin_flicker()
	elseif action == 100 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	elseif action == 101 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		moving_coin_inc.coin_collected()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/moving_coin.inc.c:bhv_blue_coin_jumping_loop L230-273
function moving_coin_inc.bhv_blue_coin_jumping_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.cur_obj_become_intangible()
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
		end

		ObjBehaviors.object_step()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		moving_coin_inc.blue_coin_sliding_away_from_mario()
	elseif action == 2 then
		moving_coin_inc.blue_coin_sliding_slow_down()
		ObjBehaviors.set_object_visibility(o, 3000)
	elseif action == 3 then
		moving_coin_inc.coin_step(Scratch.bhv_blue_coin_jumping_loop_collisionFlags)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
		end
	elseif action == 4 then
		moving_coin_inc.moving_coin_flicker()
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		moving_coin_inc.coin_collected()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

return moving_coin_inc
