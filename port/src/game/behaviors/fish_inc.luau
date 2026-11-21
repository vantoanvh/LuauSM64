--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/fish.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")

const fish_inc = {}

Registry.Register("src__game__behaviors__fish_inc", fish_inc)

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

-- from src/game/behaviors/fish.inc.c:fish_spawner_act_spawn L11-49
function fish_inc.fish_spawner_act_spawn()
	const o = ObjectListProcessor.gCurrentObject

	local model = 0
	local schoolQuantity = 0
	local minDistToMario = 0
	local fishAnimation = 0

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.FISH_SPAWNER_BP_MANY_BLUE then
		model = IncludeModelIdsH.MODEL_FISH
		schoolQuantity = 20
		minDistToMario = 1500
		fishAnimation = Memory.segmented_to_virtual(0x0301C2B0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.FISH_SPAWNER_BP_FEW_BLUE then
		model = IncludeModelIdsH.MODEL_FISH
		schoolQuantity = 5
		minDistToMario = 1500
		fishAnimation = Memory.segmented_to_virtual(0x0301C2B0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.FISH_SPAWNER_BP_MANY_CYAN then
		model = IncludeModelIdsH.MODEL_CYAN_FISH
		schoolQuantity = 20
		minDistToMario = 1500
		fishAnimation = Memory.segmented_to_virtual(0x0600E264)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.FISH_SPAWNER_BP_FEW_CYAN then
		model = IncludeModelIdsH.MODEL_CYAN_FISH
		schoolQuantity = 5
		minDistToMario = 1500
		fishAnimation = Memory.segmented_to_virtual(0x0600E264)
	end

	-- Spawn and animate the schoolQuantity of fish if Mario enters render distance
	-- or the stage is Secret Aquarium.
	-- Fish moves randomly within a range of 700.0f.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < minDistToMario or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SA then
		for i = 0, schoolQuantity - 1 do
			const fishObject = ObjectHelpers.spawn_object(o, model, BehaviorIds.bhvFish)
			buffer.writei32(fishObject.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
			ObjectHelpers.obj_init_animation_with_sound(fishObject, fishAnimation, 0)
			ObjectHelpers.obj_translate_xyz_random(fishObject, 700)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_SPAWNER_ACT_IDLE)
	end
end

-- from src/game/behaviors/fish.inc.c:fish_spawner_act_idle L55-59
function fish_inc.fish_spawner_act_idle()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_SA and F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) > 2000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_SPAWNER_ACT_RESPAWN)
	end
end

-- from src/game/behaviors/fish.inc.c:fish_spawner_act_respawn L64-66
function fish_inc.fish_spawner_act_respawn()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_SPAWNER_ACT_SPAWN)
end

-- from src/game/behaviors/fish.inc.c:bhv_fish_spawner_loop L74-76
function fish_inc.bhv_fish_spawner_loop()
	ObjectHelpers.cur_obj_call_action_function(fish_inc.sFishSpawnerActions)
end

-- from src/game/behaviors/fish.inc.c:fish_vertical_roam L81-98
function fish_inc.fish_vertical_roam(speed: number)
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	const parentY = buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY)

	-- If the stage is Secret Aquarium, the fish can
	-- travel as far vertically as they wish.
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SA then
		if 500 < ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishGoalY))) then
			speed = 10
		end
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, ObjectHelpers.approach_f32_symmetric(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishGoalY), speed))

	-- Allow the fish to roam vertically if within
	-- range of the fish spawner.
	elseif F32(F32(parentY - 100) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishDepthDistance)) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(F32(parentY + 1000) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishDepthDistance)) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, ObjectHelpers.approach_f32_symmetric(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishGoalY), speed))
	end
end

-- from src/game/behaviors/fish.inc.c:fish_act_roam L103-151
function fish_inc.fish_act_roam()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	local fishY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY))

	-- Alters speed of animation for natural movement.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 2)
	else
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	end

	-- Initializes some variables when the fish first begins roaming.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 2) + 3)
		if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SA then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishHeightOffset, SrcEngineBehaviorScript.random_float() * 700)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishHeightOffset, SrcEngineBehaviorScript.random_float() * 100)
		end
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishRoamDistance, F32(SrcEngineBehaviorScript.random_float() * 500) + 200)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishGoalY, buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishHeightOffset))

	-- Rotate the fish towards Mario.
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel) - 50) then
		if fishY < 0 then
			fishY = 0 - fishY
		end
		if fishY < 500 then
			fish_inc.fish_vertical_roam(2)
		else
			fish_inc.fish_vertical_roam(4)
		end

	-- Don't let the fish leave the water vertically.
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel) - 50)
		if fishY > 300 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 1)
		end
	end

	-- Flee from Mario if the fish gets too close.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishRoamDistance) + 150) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_ACT_FLEE)
	end
end

-- from src/game/behaviors/fish.inc.c:fish_act_flee L156-219
function fish_inc.fish_act_flee()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	local fishY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishGoalY, buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishHeightOffset))

	-- Initialize some variables when the flee action first starts.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishActiveDistance, SrcEngineBehaviorScript.random_float() * 300)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFishYawVel, TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 1024) + 1024)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishGoalVel, F32(F32(SrcEngineBehaviorScript.random_float() * 4) + 8) + 5)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 600 then
			-- UNUSED distance = 1 in the C: never read
		else
			-- UNUSED distance = (s32)(1.0 / (oDistanceToMario / 600.0)) in the C: never read
		end

		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_MOVING_WATER)
	end

	-- Speed the animation up over time.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 20 then
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 4)
	else
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	end

	-- Accelerate over time.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishGoalVel) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) + 0.5)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishGoalY, buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishHeightOffset))

	-- Rotate fish away from Mario.
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFishYawVel)))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel) - 50) then
		if fishY < 0 then
			fishY = 0 - fishY
		end

		if fishY < 500 then
			fish_inc.fish_vertical_roam(2)
		else
			fish_inc.fish_vertical_roam(4)
		end

	-- Don't let the fish leave the water vertically.
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel) - 50)
		if fishY > 300 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 1)
		end
	end

	-- If distance to Mario is too great, then set fish to active.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishActiveDistance) + 500) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_ACT_ROAM)
	end
end

-- from src/game/behaviors/fish.inc.c:fish_act_init L224-230
function fish_inc.fish_act_init()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1)
	o.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 28)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishDepthDistance, SrcEngineBehaviorScript.random_float() * 300)
	ObjectHelpers.cur_obj_scale(F32(SrcEngineBehaviorScript.random_float() * 0.4 + 0.8))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FISH_ACT_ROAM)
end

-- from src/game/behaviors/fish.inc.c:bhv_fish_loop L241-276
function fish_inc.bhv_fish_loop()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_scale(1)

	-- oFishWaterLevel tracks if a fish has roamed out of water.
	-- This can't happen in Secret Aquarium, so set it to 0.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel, SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SA then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel, 0)
	end

	-- Apply hitbox and resolve wall collisions
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 30)
	ObjectHelpers.cur_obj_resolve_wall_collisions()

	-- Delete fish if it's drifted to an area with no water.
	if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_UNKNOWN_32 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
			ObjectHelpers.obj_mark_for_deletion(o)
			return
		end

	-- Unreachable code, perhaps for debugging or testing.
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFishWaterLevel, 1000)
	end

	-- Call fish action methods and apply physics engine.
	ObjectHelpers.cur_obj_call_action_function(fish_inc.sFishActions)
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	-- If the parent object has action set to two, then delete the fish object.
	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FISH_SPAWNER_ACT_RESPAWN then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/fish.inc.c:sFishSpawnerActions L68-72
fish_inc.sFishSpawnerActions = {
	fish_inc.fish_spawner_act_spawn,
	fish_inc.fish_spawner_act_idle,
	fish_inc.fish_spawner_act_respawn,
}

-- from src/game/behaviors/fish.inc.c:sFishActions L232-236
fish_inc.sFishActions = { fish_inc.fish_act_init, fish_inc.fish_act_roam, fish_inc.fish_act_flee }

return fish_inc
