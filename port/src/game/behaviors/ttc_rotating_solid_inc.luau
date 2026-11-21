--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_rotating_solid.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/ttc_rotating_solid.inc.c:data
const ttc_rotating_solid_inc = {
	-- from src/game/behaviors/ttc_rotating_solid.inc.c:sTTCRotatingSolidCollisionModels L10-13
	sTTCRotatingSolidCollisionModels = { 0x07014F70 --[[ ttc_seg7_collision_07014F70 ]], 0x07015008 --[[ ttc_seg7_collision_07015008 ]] },
	-- from src/game/behaviors/ttc_rotating_solid.inc.c:sTTCRotatingSolidInitialDelays L18-23
	sTTCRotatingSolidInitialDelays = { 120, 40, 0, 0 },
}

Registry.Register("src__game__behaviors__ttc_rotating_solid_inc", ttc_rotating_solid_inc)

-- from src/game/behaviors/ttc_rotating_solid.inc.c:bhv_ttc_rotating_solid_init L28-34
function ttc_rotating_solid_inc.bhv_ttc_rotating_solid_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.collisionData = Memory.segmented_to_virtual(ttc_rotating_solid_inc.sTTCRotatingSolidCollisionModels[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumSides, if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.TTC_ROTATING_SOLID_BP_CUBE then 4 else 3)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidRotationDelay, ttc_rotating_solid_inc.sTTCRotatingSolidInitialDelays[ObjectListProcessor.gTTCSpeedSetting + 1])
end

-- from src/game/behaviors/ttc_rotating_solid.inc.c:bhv_ttc_rotating_solid_update L40-79
function ttc_rotating_solid_inc.bhv_ttc_rotating_solid_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectListProcessor.gTTCSpeedSetting ~= IncludeObjectConstantsH.TTC_SPEED_STOPPED and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidRotationDelay) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidSoundTimer) ~= 0 then
			-- 3. Play a sound after 6 frames
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidSoundTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidSoundTimer) - 1)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidSoundTimer) == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_ROTATING_BLOCK_ALERT)
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidVelY) > 0.0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) >= buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			-- 4. Rotate
			const TargetRoll = S32(TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumTurns) / buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumSides)) * 0x10000)))
			const StartRoll = buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)

			ObjBehaviors2.obj_face_roll_approach(S16(TargetRoll), 1200)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - StartRoll)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_ROTATING_BLOCK_CLICK)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumTurns, (buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumTurns) + 1) % buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidNumSides))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)

				if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidRotationDelay, ObjBehaviors2.random_mod_offset(5, 20, 7))
				end
			end
		else
			-- 2. Move vertically with vel -4.5, -4.0, ... until reached back home
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidVelY) + 0.5)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidVelY))

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) >= buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidSoundTimer, 6)
			end
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCRotatingSolidVelY, -5.0)
	end
end

return ttc_rotating_solid_inc
