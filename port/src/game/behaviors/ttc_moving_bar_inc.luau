--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_moving_bar.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:data
const ttc_moving_bar_inc = {
	-- from src/game/behaviors/ttc_moving_bar.inc.c:sTTCMovingBarDelays L10-15
	sTTCMovingBarDelays = { 55, 30, 55, 0 },
	-- from src/game/behaviors/ttc_moving_bar.inc.c:sTTCMovingBarRandomDelays L20-20
	sTTCMovingBarRandomDelays = { 1, 12, 55, 100 },
}

Registry.Register("src__game__behaviors__ttc_moving_bar_inc", ttc_moving_bar_inc)

-- from src/game/behaviors/ttc_moving_bar.inc.c:bhv_ttc_moving_bar_init L25-36
function ttc_moving_bar_inc.bhv_ttc_moving_bar_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- If on still setting, then stick out
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarDelay, ttc_moving_bar_inc.sTTCMovingBarDelays[ObjectListProcessor.gTTCSpeedSetting + 1])

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarDelay) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset, 250.0)
	end

	-- This causes the first cycle to start at different times for different
	-- bars
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer, 10 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x4000 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:ttc_moving_bar_act_wait L41-63
function ttc_moving_bar_inc.ttc_moving_bar_act_wait()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarDelay) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarDelay) then
		-- This is zero except on the first cycle, and is used to desync the
		-- bars from each other at the very beginning
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer) - 1)
		else
			if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
				-- Set the delay for the next cycle
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarDelay, ttc_moving_bar_inc.sTTCMovingBarRandomDelays[bit32.band(SrcEngineBehaviorScript.random_u16(), 0x03) + 1])

				-- With 50% probability, pause after pulling back
				if SrcEngineBehaviorScript.random_u16() % 2 == 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer, ObjBehaviors2.random_linear_offset(20, 100))
				end
			end

			-- Begin pulling back
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_PULL_BACK)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, -8.0)
		end
	end
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:ttc_moving_bar_act_pull_back L68-81
function ttc_moving_bar_inc.ttc_moving_bar_act_pull_back()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const SpeedAfterPull = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed) + F32(0.73))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, SpeedAfterPull)

	-- Started with -8 speed, accelerate back to > 0
	if SpeedAfterPull > 0.0 then
		-- Possibly pause after pulling back
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStoppedTimer) - 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, 0.0)
		else
			-- Begin extending
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_EXTEND)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, 29.0)
		end
	end
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:ttc_moving_bar_reset L86-89
function ttc_moving_bar_inc.ttc_moving_bar_reset()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_WAIT)
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:ttc_moving_bar_act_extend L96-128
function ttc_moving_bar_inc.ttc_moving_bar_act_extend()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Offset = buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset)
	const StartOffset = buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStartOffset)
	const Speed = buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed)

	-- If we passed the 250 threshold and we have decelerated enough
	if (Offset == 250.0 or F32(F32(250.0 - Offset) * F32(250.0 - StartOffset)) < 0.0) and Speed > -8.0 and Speed < 8.0 then
		-- Begin retracting
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_RETRACT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, 0.0)
	else
		local Accel = F32(6.4)

		-- Accelerate before reaching 250, and decelerate after reaching it
		if Offset < 250.0 then
			Accel = F32(6.4)
		else
			Accel = -F32(6.4)
		end

		-- Strengthen deceleration
		if F32(Speed * Accel) < 0.0 then
			Accel = F32(Accel * F32(2.35))
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, Speed + Accel)

		-- When we pass neutral on random setting, then stop immediately with
		-- 25% probability (fake out)
		if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM and F32(Offset * StartOffset) < 0.0 and SrcEngineBehaviorScript.random_u16() % 4 == 0 then
			ttc_moving_bar_inc.ttc_moving_bar_reset()
		end
	end
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:ttc_moving_bar_act_retract L133-142
function ttc_moving_bar_inc.ttc_moving_bar_act_retract()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Wait a second
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		-- Retract
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed, -5.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset) < 0.0 then
			ttc_moving_bar_inc.ttc_moving_bar_reset()
		end
	end
end

-- from src/game/behaviors/ttc_moving_bar.inc.c:bhv_ttc_moving_bar_update L147-170
function ttc_moving_bar_inc.bhv_ttc_moving_bar_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarStartOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset))
	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_SAVE_POSITION)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarSpeed))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_WAIT then
		ttc_moving_bar_inc.ttc_moving_bar_act_wait()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_PULL_BACK then
		ttc_moving_bar_inc.ttc_moving_bar_act_pull_back()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_EXTEND then
		ttc_moving_bar_inc.ttc_moving_bar_act_extend()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.TTC_MOVING_BAR_ACT_RETRACT then
		ttc_moving_bar_inc.ttc_moving_bar_act_retract()
	end

	ObjBehaviors2.obj_set_dist_from_home(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCMovingBarOffset))
	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_COMPUTE_VELOCITY)
end

return ttc_moving_bar_inc
