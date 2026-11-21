--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/moneybag.inc.c.
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
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")

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

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/moneybag.inc.c:data
const moneybag_inc = {
	-- from src/game/behaviors/moneybag.inc.c:sMoneybagHitbox L3-13
	sMoneybagHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 1,
		numLootCoins = 0,
		radius = 120,
		height = 60,
		hurtboxRadius = 100,
		hurtboxHeight = 50,
	},
	-- from src/game/behaviors/moneybag.inc.c:sMoneybagHiddenHitbox L15-25
	sMoneybagHiddenHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 1,
		numLootCoins = 0,
		radius = 120,
		height = 60,
		hurtboxRadius = 100,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__moneybag_inc", moneybag_inc)

-- from src/game/behaviors/moneybag.inc.c:bhv_moneybag_init L27-33
function moneybag_inc.bhv_moneybag_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)

	ObjectHelpers.cur_obj_init_animation(0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_check_mario_collision L35-50
function moneybag_inc.moneybag_check_mario_collision()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, moneybag_inc.sMoneybagHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACKED_MARIO) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
		end

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_WAS_ATTACKED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONEYBAG_ACT_DEATH)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_jump L52-103
function moneybag_inc.moneybag_jump(collisionFlags: number)
	collisionFlags = S8(TruncS32(collisionFlags))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame
	const jumpState = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState)

	if jumpState == IncludeObjectConstantsH.MONEYBAG_JUMP_PREPARE then
		ObjectHelpers.cur_obj_init_animation(1)
		if animFrame == 5 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
		end

		if ObjectHelpers.cur_obj_check_if_near_animation_end() == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_JUMP)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOING2_LOWPRIO)
		end
	elseif jumpState == IncludeObjectConstantsH.MONEYBAG_JUMP_JUMP then
		ObjectHelpers.cur_obj_init_animation(2)

		if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) == ObjBehaviors.OBJ_COL_FLAG_GROUNDED then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING)
		end
	elseif jumpState == IncludeObjectConstantsH.MONEYBAG_JUMP_JUMP_AND_BOUNCE then
		ObjectHelpers.cur_obj_init_animation(3)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING)
		end
	elseif jumpState == IncludeObjectConstantsH.MONEYBAG_JUMP_WALK_AROUND then
		ObjectHelpers.cur_obj_init_animation(4)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			o.header.gfx.animInfo.animFrame = 0
		end
	elseif jumpState == IncludeObjectConstantsH.MONEYBAG_JUMP_WALK_HOME then
		ObjectHelpers.cur_obj_init_animation(4)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)
	end
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_act_move_around L105-129
function moneybag_inc.moneybag_act_move_around()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors.obj_return_and_displace_home(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 200)

	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAGS_LANDED and buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState) == IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING then
		if TruncS32(F32(SrcEngineBehaviorScript.random_float() * 6.0)) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_WALK_AROUND)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_PREPARE)
		end
	end

	moneybag_inc.moneybag_jump(S8(collisionFlags))
	moneybag_inc.moneybag_check_mario_collision()

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 800) == 0 and bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAGS_LANDED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONEYBAG_ACT_RETURN_HOME)
	end
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_act_return_home L131-162
function moneybag_inc.moneybag_act_return_home()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp28 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const sp24 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const sp22 = S16(SrcEngineMathUtil.atan2s(sp24, sp28))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), sp22, 0x800))

	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAGS_LANDED and buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState) == IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_WALK_HOME)
	end

	moneybag_inc.moneybag_jump(S8(collisionFlags))
	moneybag_inc.moneybag_check_mario_collision()

	if ObjBehaviors.is_point_close_to_object(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 100) ~= 0 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvMoneybagHidden)

		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_VANISH_SFX)

		ObjectHelpers.cur_obj_init_animation(0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONEYBAG_ACT_DISAPPEAR)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 800) == IncludePRUltratypesH.TRUE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONEYBAG_ACT_MOVE_AROUND)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoneybagJumpState, IncludeObjectConstantsH.MONEYBAG_JUMP_LANDING)
	end
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_act_disappear L164-170
function moneybag_inc.moneybag_act_disappear()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 6)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/moneybag.inc.c:moneybag_act_death L172-179
function moneybag_inc.moneybag_act_death()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 1 then
		ObjBehaviors.obj_spawn_yellow_coins(o, 5)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_SPLATTERING)
		ObjectHelpers.spawn_mist_particles()
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/moneybag.inc.c:bhv_moneybag_loop L181-212
function moneybag_inc.bhv_moneybag_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MONEYBAG_ACT_APPEAR or action == IncludeObjectConstantsH.MONEYBAG_ACT_UNUSED_APPEAR then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) + 12)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) > 255 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
			const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
			parentObj.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MONEYBAG_ACT_MOVE_AROUND)
		end
	elseif action == IncludeObjectConstantsH.MONEYBAG_ACT_MOVE_AROUND then
		moneybag_inc.moneybag_act_move_around()
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			ObjectHelpers.cur_obj_become_tangible()
		end
	elseif action == IncludeObjectConstantsH.MONEYBAG_ACT_RETURN_HOME then
		moneybag_inc.moneybag_act_return_home()
	elseif action == IncludeObjectConstantsH.MONEYBAG_ACT_DISAPPEAR then
		moneybag_inc.moneybag_act_disappear()
	elseif action == IncludeObjectConstantsH.MONEYBAG_ACT_DEATH then
		moneybag_inc.moneybag_act_death()
	end
end

-- from src/game/behaviors/moneybag.inc.c:bhv_moneybag_hidden_loop L214-233
function moneybag_inc.bhv_moneybag_hidden_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, moneybag_inc.sMoneybagHiddenHitbox)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.FAKE_MONEYBAG_COIN_ACT_IDLE then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 400) ~= 0 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_MONEYBAG, BehaviorIds.bhvMoneybag)

			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_VANISH_SFX)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FAKE_MONEYBAG_COIN_ACT_TRANSFORM)
		end
	elseif action == IncludeObjectConstantsH.FAKE_MONEYBAG_COIN_ACT_TRANSFORM then
		-- Nothing to do.
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return moneybag_inc
