--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bird.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")

const bird_inc = {}

Registry.Register("src__game__behaviors__bird_inc", bird_inc)

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

-- from src/game/behaviors/bird.inc.c:bird_act_inactive L16-48
function bird_inc.bird_act_inactive()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Start flying if the object is a spawned bird or if it's a spawner bird
	-- and Mario is within 2000 units.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BIRD_BP_SPAWNED or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 then
		-- If the object is a spawner bird, play the sound of birds flying away,
		-- and spawn 6 spawned birds (which will start flying on the next frame).
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.BIRD_BP_SPAWNED then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BIRDS_FLY_AWAY)

			for SpawnIndex = 1, 6 do
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvBird)
			end

			-- The spawner bird's home acts as its target location.
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, -20.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, -3990.0)
		end

		-- Start flying
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BIRD_ACT_FLY)

		-- Start with a random yaw, and a random pitch from 1000 to 5000.
		-- Positive pitch is downwards.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 5000 - TruncS32(F32(4000.0 * SrcEngineBehaviorScript.random_float())))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBirdSpeed, 40.0)

		ObjectHelpers.cur_obj_unhide()
	end
end

-- from src/game/behaviors/bird.inc.c:bird_act_fly L55-105
function bird_inc.bird_act_fly()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Compute forward velocity and vertical velocity from oBirdSpeed and pitch
	ObjBehaviors2.obj_compute_vel_from_move_pitch(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBirdSpeed))

	-- If the bird's parent is higher than 8000 units, despawn the bird.
	-- A spawned bird's parent is its spawner bird. A spawner bird's parent
	-- is itself. In other words, when a group of birds has its spawner bird
	-- fly past Y=8000, they will all despawn simultaneously. Otherwise, fly.
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY) > 8000.0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		-- If the bird is a spawner bird, fly towards its home; otherwise,
		-- fly towards the bird's spawner bird.
		local distance: number

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.BIRD_BP_SPAWNED then
			distance = ObjectHelpers.cur_obj_lateral_dist_to_home()

			-- The spawner bird will start with its downwards (positive) pitch
			-- and will continuously decrease its pitch (i.e. make itself face more upwards)
			-- until it reaches its home, at which point it will face directly up.
			-- This is done by making its target pitch the arctangent of its distance
			-- to its home and its position - 10,000 (which is always negative).
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBirdTargetPitch, SrcEngineMathUtil.atan2s(distance, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 10000.0)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBirdTargetYaw, ObjectHelpers.cur_obj_angle_to_home())
		else
			distance = ObjectHelpers.lateral_dist_between_objects(o, parent)

			-- The bird's target pitch will face directly to its spawner bird.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBirdTargetPitch, SrcEngineMathUtil.atan2s(distance, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY))))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBirdTargetYaw, ObjectHelpers.obj_angle_to_object(o, parent))

			-- The bird goes faster the farther it is from its spawner bird so it can catch up.
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBirdSpeed, F32(F32(0.04) * ObjectHelpers.dist_between_objects(o, parent)) + 20.0)
		end

		-- Approach to match the bird's target yaw and pitch.
		ObjBehaviors2.obj_move_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBirdTargetPitch)), 140)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBirdTargetYaw)), 800)
		ObjBehaviors2.obj_roll_to_match_yaw_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBirdTargetYaw)), 0x3000, 600)
	end

	-- The bird has no gravity, so this function only
	-- moves the bird using its forward velocity.
	-- Even if it did have gravity, it would only act as
	-- a constant added to its Y position every frame since
	-- its Y velocity is reset every frame by
	-- obj_compute_vel_from_move_pitch.
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/bird.inc.c:bhv_bird_update L110-119
function bird_inc.bhv_bird_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BIRD_ACT_INACTIVE then
		bird_inc.bird_act_inactive()
	elseif action == IncludeObjectConstantsH.BIRD_ACT_FLY then
		bird_inc.bird_act_fly()
	end
end

return bird_inc
