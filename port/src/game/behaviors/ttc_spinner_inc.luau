--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_spinner.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

-- from src/game/behaviors/ttc_spinner.inc.c:data
const ttc_spinner_inc = {
	-- from src/game/behaviors/ttc_spinner.inc.c:sTTCSpinnerSpeeds L9-14
	sTTCSpinnerSpeeds = { 200, 600, 200, 0 },
}

Registry.Register("src__game__behaviors__ttc_spinner_inc", ttc_spinner_inc)

-- from src/game/behaviors/ttc_spinner.inc.c:bhv_ttc_spinner_update L19-36
function ttc_spinner_inc.bhv_ttc_spinner_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, ttc_spinner_inc.sTTCSpinnerSpeeds[ObjectListProcessor.gTTCSpeedSetting + 1])

	if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCChangeDirTimer) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCSpinnerDir, SrcEngineBehaviorScript.random_sign())
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCChangeDirTimer, ObjBehaviors2.random_mod_offset(30, 30, 4))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) * buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCSpinnerDir))
		else
			-- Stop for 5 frames after changing direction
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
end

return ttc_spinner_inc
