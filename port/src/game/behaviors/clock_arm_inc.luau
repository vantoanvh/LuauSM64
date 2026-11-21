--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/clock_arm.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSurfaceTerrainsH = require("../../../include/surface_terrains_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const clock_arm_inc = {}

Registry.Register("src__game__behaviors__clock_arm_inc", clock_arm_inc)

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/clock_arm_inc.luau:scratch
const Scratch = {
	bhv_rotating_clock_arm_loop_marioSurface = {},
}

-- from src/game/behaviors/clock_arm.inc.c:bhv_rotating_clock_arm_loop L6-55
function clock_arm_inc.bhv_rotating_clock_arm_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const RollAngle = U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, SrcEngineSurfaceCollision.find_floor(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_rotating_clock_arm_loop_marioSurface))
	const MarioSurface = Scratch.bhv_rotating_clock_arm_loop_marioSurface[1] :: GroupsTypesHPlus3.Surface?

	-- Seems to make sure Mario is on a default surface & 4 frames pass before allowing him to change the Tick Tock Clock speed setting.
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if (MarioSurface :: GroupsTypesHPlus3.Surface).type_ == IncludeSurfaceTerrainsH.SURFACE_DEFAULT and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 4 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 1 then
		-- If Mario is touching the Tick Tock Clock painting...
		if MarioSurface ~= nil and (MarioSurface.type_ == IncludeSurfaceTerrainsH.SURFACE_TTC_PAINTING_1 or MarioSurface.type_ == IncludeSurfaceTerrainsH.SURFACE_TTC_PAINTING_2 or MarioSurface.type_ == IncludeSurfaceTerrainsH.SURFACE_TTC_PAINTING_3) then
			-- And this is the minute hand...
			if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvClockMinuteHand) ~= 0 then
				-- Set Tick Tock Clock's speed based on the angle of the hand (the angle counts down from 0xFFFF to 0).
				if RollAngle < 0xAAA then
					ObjectListProcessor.gTTCSpeedSetting = IncludeObjectConstantsH.TTC_SPEED_STOPPED
				elseif RollAngle < 0x6AA4 then
					ObjectListProcessor.gTTCSpeedSetting = IncludeObjectConstantsH.TTC_SPEED_FAST
				elseif RollAngle < 0x954C then
					ObjectListProcessor.gTTCSpeedSetting = IncludeObjectConstantsH.TTC_SPEED_RANDOM
				elseif RollAngle < 0xF546 then
					ObjectListProcessor.gTTCSpeedSetting = IncludeObjectConstantsH.TTC_SPEED_SLOW
				else
					ObjectListProcessor.gTTCSpeedSetting = IncludeObjectConstantsH.TTC_SPEED_STOPPED
				end
			end

			-- Increment the action to stop animating the hands.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		else
			-- Mario is not on the painting: nothing to do.
		end
	end

	-- Only rotate the hands until Mario enters the painting.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) < 2 then
		ObjectHelpers.cur_obj_rotate_face_angle_using_vel()
	end
end

return clock_arm_inc
