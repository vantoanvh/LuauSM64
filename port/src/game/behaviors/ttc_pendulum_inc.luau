--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_pendulum.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

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

-- from src/game/behaviors/ttc_pendulum.inc.c:data
const ttc_pendulum_inc = {
	-- from src/game/behaviors/ttc_pendulum.inc.c:sTTCPendulumInitialAccels L10-15
	sTTCPendulumInitialAccels = { 13.0, 22.0, 13.0, 0.0 },
}

Registry.Register("src__game__behaviors__ttc_pendulum_inc", ttc_pendulum_inc)

-- from src/game/behaviors/ttc_pendulum.inc.c:bhv_ttc_pendulum_init L20-27
function ttc_pendulum_inc.bhv_ttc_pendulum_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectListProcessor.gTTCSpeedSetting ~= IncludeObjectConstantsH.TTC_SPEED_STOPPED then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleAccel, ttc_pendulum_inc.sTTCPendulumInitialAccels[ObjectListProcessor.gTTCSpeedSetting + 1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle, 6500.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle, F32(6371.5557))
	end
end

-- from src/game/behaviors/ttc_pendulum.inc.c:bhv_ttc_pendulum_update L32-86
function ttc_pendulum_inc.bhv_ttc_pendulum_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectListProcessor.gTTCSpeedSetting ~= IncludeObjectConstantsH.TTC_SPEED_STOPPED then
		-- Play sound
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumSoundTimer) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPendulumSoundTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumSoundTimer) - 1)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumSoundTimer) == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_PENDULUM_SWING)
			end
		end

		-- Stay still for a while
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumDelay) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPendulumDelay, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumDelay) - 1)
		else
			-- Accelerate in the direction that moves angle to zero
			if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAccelDir)) > 0.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAccelDir, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAccelDir))
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleVel) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleAccel) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAccelDir)))

			-- Ignoring floating point imprecision, angle vel should always be
			-- a multiple of angle accel, and so it will eventually reach zero
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleVel) == 0.0 then
				if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
					-- Select a new acceleration
					if SrcEngineBehaviorScript.random_u16() % 3 ~= 0 then
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleAccel, 13.0)
					else
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleAccel, 42.0)
					end

					-- Pick a random delay
					if SrcEngineBehaviorScript.random_u16() % 2 == 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPendulumDelay, ObjBehaviors2.random_linear_offset(5, 30))
					end
				end

				-- Play the sound 15 frames after beginning to move
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPendulumSoundTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPendulumDelay) + 15)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngleVel))
		end
	else
		-- Stopped: the pendulum keeps its angle.
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPendulumAngle))))
	-- Note: no platform displacement
end

return ttc_pendulum_inc
