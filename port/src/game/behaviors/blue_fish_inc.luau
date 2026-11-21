--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/blue_fish.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const blue_fish_inc = {}

Registry.Register("src__game__behaviors__blue_fish_inc", blue_fish_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/blue_fish.inc.c:bhv_blue_fish_movement_loop L10-96
function blue_fish_inc.bhv_blue_fish_movement_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BLUE_FISH_ACT_DIVE then
		-- Initial dive phase after spawning
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1.0)

		-- Assigns random values to variables that help determine natural motion.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomAngle, SrcEngineBehaviorScript.random_sign() * 0x800)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomVel, SrcEngineBehaviorScript.random_float() * 2)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomTime, S32(bit32.band(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 30)), 0xFE)))

			-- Adjusts pitch velocity or sets to zero dependant on outcome of randomSwitch.
			const randomSwitch = F32(SrcEngineBehaviorScript.random_float() * 5)
			if randomSwitch < 2.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, TruncS32(ObjectHelpers.random_f32_around_zero(128)))
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
			end
		end

		-- Set forward velocity and progress oAction to BLUE_FISH_ACT_TURN.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomVel) + 3.0)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= buffer.readi32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomTime) + 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		-- Set pitch velocity
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < (buffer.readi32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomTime) + 60) // 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		end

		-- Calculate new Y velocity
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))
	elseif action == IncludeObjectConstantsH.BLUE_FISH_ACT_TURN then
		-- Animates and adjusts fish yaw angle.
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 2.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomAngle) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BLUE_FISH_ACT_ASCEND then
		-- Animates and adjusts pitch to an upward direction.
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 1.0)

		-- Progresses oAction to BLUE_FISH_ACT_TURN_BACK after elapsed time.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= buffer.readi32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomTime) + 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		-- Adjusts pitch angle. Direction relies on time not passed.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < (buffer.readi32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomTime) + 60) // 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		end
	elseif action == IncludeObjectConstantsH.BLUE_FISH_ACT_TURN_BACK then
		-- Animates and turns fish around
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 2.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBlueFishRandomAngle) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

		-- Sets the fish back to the BLUE_FISH_ACT_DIVE phase.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BLUE_FISH_ACT_DIVE)
		end
	end

	-- Calculates Y velocity and calls physics engine.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	-- Deletes object if the parent has oAction set to BLUE_FISH_ACT_DUPLICATE.
	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BLUE_FISH_ACT_DUPLICATE then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/blue_fish.inc.c:bhv_tank_fish_group_loop L102-133
function blue_fish_inc.bhv_tank_fish_group_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BLUE_FISH_ACT_SPAWN then
		if ObjectListProcessor.gMarioCurrentRoom == 15 or ObjectListProcessor.gMarioCurrentRoom == 7 then
			-- spawns fifteen fish and moves them within 200.0f
			for FishIndex = 1, 15 do
				const fish = ObjectHelpers.spawn_object_relative(0, 300, 0, -200, o, IncludeModelIdsH.MODEL_FISH, BehaviorIds.bhvBlueFish)
				ObjectHelpers.obj_translate_xyz_random(fish, 200.0)
			end

			-- Proceed to BLUE_FISH_ACT_ROOM phase.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BLUE_FISH_ACT_ROOM then
		-- Sets next oAction phase if Mario is not in rooms fifteen and seven.
		if ObjectListProcessor.gMarioCurrentRoom ~= 15 and ObjectListProcessor.gMarioCurrentRoom ~= 7 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BLUE_FISH_ACT_DUPLICATE then
		-- Sets oAction to the BLUE_FISH_ACT_SPAWN phase.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BLUE_FISH_ACT_SPAWN)
	end
end

return blue_fish_inc
