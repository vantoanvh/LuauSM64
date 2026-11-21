--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_elevator.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/ttc_elevator.inc.c:data
const ttc_elevator_inc = {
	-- from src/game/behaviors/ttc_elevator.inc.c:sTTCElevatorSpeeds L9-14
	sTTCElevatorSpeeds = { 6, 10, 6, 0 },
}

Registry.Register("src__game__behaviors__ttc_elevator_inc", ttc_elevator_inc)

-- from src/game/behaviors/ttc_elevator.inc.c:bhv_ttc_elevator_init L19-26
function ttc_elevator_inc.bhv_ttc_elevator_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const PeakOffset = if bit32.btest(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16), 0xFFFF) then F32(100.0 * bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16), 0xFFFF)) else 500.0

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCElevatorPeakY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + PeakOffset)
end

-- from src/game/behaviors/ttc_elevator.inc.c:bhv_ttc_elevator_update L31-52
function ttc_elevator_inc.bhv_ttc_elevator_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(ttc_elevator_inc.sTTCElevatorSpeeds[ObjectListProcessor.gTTCSpeedSetting + 1] * buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCElevatorDir)))

	if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
		-- Occasionally stop for 5 frames then change direction
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCElevatorMoveTime) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCElevatorDir, SrcEngineBehaviorScript.random_sign())
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCElevatorMoveTime, ObjBehaviors2.random_mod_offset(30, 30, 6))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 5 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		end
	end

	-- This is basically equivalent to posY += velY
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	-- Flip directions if the elevator tries to run away
	if ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCElevatorPeakY)) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCElevatorDir, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCElevatorDir))
	end
end

return ttc_elevator_inc
