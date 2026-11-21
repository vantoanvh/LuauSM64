--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_2d_rotator.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/ttc_2d_rotator.inc.c:data
const ttc_2d_rotator_inc = {
	-- from src/game/behaviors/ttc_2d_rotator.inc.c:sTTC2DRotatorSpeeds L11-14
	sTTC2DRotatorSpeeds = { -0x444, -0xCCC },
	-- from src/game/behaviors/ttc_2d_rotator.inc.c:sTTC2DRotatorTimeBetweenTurns L21-34
	sTTC2DRotatorTimeBetweenTurns = { { 40, 10, 10, 0 }, { 20, 5, 5, 0 } },
}

Registry.Register("src__game__behaviors__ttc_2d_rotator_inc", ttc_2d_rotator_inc)

-- from src/game/behaviors/ttc_2d_rotator.inc.c:bhv_ttc_2d_rotator_init L39-43
function ttc_2d_rotator_inc.bhv_ttc_2d_rotator_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Speed = ttc_2d_rotator_inc.sTTC2DRotatorSpeeds[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorMinTimeUntilNextTurn, ttc_2d_rotator_inc.sTTC2DRotatorTimeBetweenTurns[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1][ObjectListProcessor.gTTCSpeedSetting + 1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorIncrement, Speed)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorSpeed, Speed)
end

-- from src/game/behaviors/ttc_2d_rotator.inc.c:bhv_ttc_2d_rotator_update L50-88
function ttc_2d_rotator_inc.bhv_ttc_2d_rotator_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const StartYaw = buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer) - 1)
	end

	-- Wait until rotated to target yaw
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorMinTimeUntilNextTurn) ~= 0 and ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorTargetYaw)), 0xC8) ~= 0 then
		-- and until MinTimeUntilNextTurn has passed.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorMinTimeUntilNextTurn) then
			-- Increment target yaw
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorTargetYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorIncrement))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)

			if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
				-- If ready for a change in direction, then pick a new
				-- direction
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer) == 0 then
					if bit32.btest(SrcEngineBehaviorScript.random_u16(), 0x03) then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorIncrement, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorSpeed))
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer, ObjBehaviors2.random_mod_offset(90, 60, 4))
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorIncrement, -buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorSpeed))
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorRandomDirTimer, ObjBehaviors2.random_mod_offset(30, 30, 3))
					end
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTC2DRotatorMinTimeUntilNextTurn, ObjBehaviors2.random_mod_offset(10, 20, 3))
			end
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - StartYaw)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.TTC_2D_ROTATOR_BP_HAND then
		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

return ttc_2d_rotator_inc
