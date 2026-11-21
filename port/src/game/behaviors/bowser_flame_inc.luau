--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_flame.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const GameInit = require("../game_init")
const IncludeSurfaceTerrainsH = require("../../../include/surface_terrains_h")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/bowser_flame.inc.c:data
const bowser_flame_inc = {
	-- from src/game/behaviors/bowser_flame.inc.c:sGrowingBowserFlameHitbox L3-13
	sGrowingBowserFlameHitbox = {
		interactType = InteractionH.INTERACT_FLAME,
		downOffset = 20,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 10,
		height = 40,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
	-- from src/game/behaviors/bowser_flame.inc.c:sBowserFlameHitbox L15-25
	sBowserFlameHitbox = {
		interactType = InteractionH.INTERACT_FLAME,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 10,
		height = 40,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
	-- from src/game/behaviors/bowser_flame.inc.c:sFlameFloatingYLimit L159-159
	sFlameFloatingYLimit = { -8.0, -6.0, -3.0 },
}

Registry.Register("src__game__behaviors__bowser_flame_inc", bowser_flame_inc)

-- from src/game/behaviors/bowser_flame.inc.c:bowser_flame_despawn L27-33
function bowser_flame_inc.bowser_flame_despawn()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_mark_for_deletion(o)
	ObjectHelpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvBlackSmokeUpward, 1.0)

	if SrcEngineBehaviorScript.random_float() < 0.1 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvTemporaryYellowCoin)
	end
end

-- from src/game/behaviors/bowser_flame.inc.c:bowser_flame_should_despawn L35-49
function bowser_flame_inc.bowser_flame_should_despawn(maxTime: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if maxTime < buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) then
		return IncludePRUltratypesH.TRUE
	end

	-- Flames should despawn if they fall off the arena.
	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oFloorType) == IncludeSurfaceTerrainsH.SURFACE_BURNING then
		return IncludePRUltratypesH.TRUE
	end

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oFloorType) == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_bowser_init L51-58
function bowser_flame_inc.bhv_flame_bowser_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, if SrcEngineBehaviorScript.random_float() < 0.2 then 80.0 else 20.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, SrcEngineBehaviorScript.random_float() + 1.0)
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_large_burning_out_init L60-66
function bowser_flame_inc.bhv_flame_large_burning_out_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 10.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, 7.0)
end

-- from src/game/behaviors/bowser_flame.inc.c:bowser_flame_move L68-72
function bowser_flame_inc.bowser_flame_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = bit32.lshift(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFlameSpeedTimerOffset) + GameInit.gGlobalTimer, 0x3F), 10)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * SrcEngineMathUtilH.sins(timer) * 4.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * SrcEngineMathUtilH.sins(timer) * 4.0))
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_bowser_loop L74-111
function bowser_flame_inc.bhv_flame_bowser_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -4.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -4.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		ObjectHelpers.cur_obj_become_intangible()
		bowser_flame_inc.bowser_flame_move()

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)

			if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvFlameLargeBurningOut) ~= IncludePRUltratypesH.FALSE then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, 8.0)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, F32(SrcEngineBehaviorScript.random_float() * 2) + 6.0)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
		end
	else
		ObjectHelpers.cur_obj_become_tangible()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) * 10) + 5.0) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) - 0.15)

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) <= 0 then
				bowser_flame_inc.bowser_flame_despawn()
			end
		end
	end

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, o.header.gfx.scale[2] * 14.0)
	ObjectHelpers.obj_set_hitbox(o, bowser_flame_inc.sBowserFlameHitbox)
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_moving_forward_growing_init L113-118
function bowser_flame_inc.bhv_flame_moving_forward_growing_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
	ObjectHelpers.obj_translate_xz_random(o, 80.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, 3.0)
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_moving_forward_growing_loop L120-144
function bowser_flame_inc.bhv_flame_moving_forward_growing_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, bowser_flame_inc.sGrowingBowserFlameHitbox)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) + 0.5)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) > 0x800 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) - 0x200)
	end

	ObjectHelpers.cur_obj_set_pos_via_transform()
	ObjectHelpers.cur_obj_update_floor_height()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) > 30.0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvFlameBowser)
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_floating_landing_init L146-157
function bowser_flame_inc.bhv_flame_floating_landing_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineBehaviorScript.random_float() * 5.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineBehaviorScript.random_float() * 70.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineBehaviorScript.random_float() * 20.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -1.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlameSpeedTimerOffset, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 64.0)))
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_floating_landing_loop L161-186
function bowser_flame_inc.bhv_flame_floating_landing_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bhvParams = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)
	bowser_flame_inc.bowser_flame_move()

	if bowser_flame_inc.bowser_flame_should_despawn(900) ~= IncludePRUltratypesH.FALSE then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < bowser_flame_inc.sFlameFloatingYLimit[bhvParams + 1] then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, bowser_flame_inc.sFlameFloatingYLimit[bhvParams + 1])
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		if bhvParams == 0 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvFlameLargeBurningOut)
		else
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvBlueFlamesGroup)
		end

		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, o.header.gfx.scale[2] * 14.0)
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_blue_bowser_flame_init L188-197
function bowser_flame_inc.bhv_blue_bowser_flame_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_translate_xz_random(o, 80.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 7.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 35.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameUnusedRand, SrcEngineBehaviorScript.random_float() * 0.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 1.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlameSpeedTimerOffset, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 64.0)))
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_blue_bowser_flame_loop L199-226
function bowser_flame_inc.bhv_blue_bowser_flame_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, bowser_flame_inc.sGrowingBowserFlameHitbox)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) < 16.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale) + 0.5)
	end

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale))
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
			for FlameIndex = 0, 2 do
				ObjectHelpers.spawn_object_relative_with_scale(0, 0, 0, 0, 5.0, o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvFlameFloatingLanding)
			end
		else
			ObjectHelpers.spawn_object_relative_with_scale(1, 0, 0, 0, 8.0, o, IncludeModelIdsH.MODEL_BLUE_FLAME, BehaviorIds.bhvFlameFloatingLanding)
			ObjectHelpers.spawn_object_relative_with_scale(2, 0, 0, 0, 8.0, o, IncludeModelIdsH.MODEL_BLUE_FLAME, BehaviorIds.bhvFlameFloatingLanding)
		end

		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_bouncing_init L228-234
function bowser_flame_inc.bhv_flame_bouncing_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFlameScale, o.header.gfx.scale[1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlameSpeedTimerOffset, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 64.0)))
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_flame_bouncing_loop L236-262
function bowser_flame_inc.bhv_flame_bouncing_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		o.ptrData[IncludeObjectFieldsH.oFlameBowser + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvBowser)
	end

	const bowser = o.ptrData[IncludeObjectFieldsH.oFlameBowser + 1] :: GroupsTypesHPlus3.Object?

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBounciness, -1.0)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFlameScale))
	ObjectHelpers.obj_set_hitbox(o, bowser_flame_inc.sGrowingBowserFlameHitbox)
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	if bowser_flame_inc.bowser_flame_should_despawn(300) ~= IncludePRUltratypesH.FALSE then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if bowser ~= nil then
		if buffer.readu32(bowser.rawData, IncludeObjectFieldsH.oHeldState) == IncludeObjectConstantsH.HELD_FREE then
			if ObjectHelpers.lateral_dist_between_objects(o, bowser) < 300.0 then
				ObjectHelpers.obj_mark_for_deletion(o)
			end
		end
	end
end

-- from src/game/behaviors/bowser_flame.inc.c:bhv_blue_flames_group_loop L264-285
function bowser_flame_inc.bhv_blue_flames_group_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.obj_angle_to_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBlueFlameNextScale, 5.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 16 then
		if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 1) == 0 then
			for FlameIndex = 0, 2 do
				const flame = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BLUE_FLAME, BehaviorIds.bhvFlameBouncing)
				buffer.writei32(flame.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(flame.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + FlameIndex * 0x5555)
				flame.header.gfx.scale[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oBlueFlameNextScale)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBlueFlameNextScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBlueFlameNextScale) - 0.5)
		end
	else
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return bowser_flame_inc
