--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/shock_wave.inc.c.
]]

const Registry = require("../../../groups/registry")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/shock_wave.inc.c:data
const shock_wave_inc = {
	-- from src/game/behaviors/shock_wave.inc.c:sBowserShockwaveHitPoints L6-6
	sBowserShockwaveHitPoints = { F32(1.9), F32(2.4), 4.0, F32(4.8) },
}

Registry.Register("src__game__behaviors__shock_wave_inc", shock_wave_inc)

-- from src/game/behaviors/shock_wave.inc.c:bhv_bowser_shock_wave_loop L11-44
function shock_wave_inc.bhv_bowser_shock_wave_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const fadeFrames = 70

	-- Scale shockwave as the timer goes on
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 10)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale))

	-- Slightly reduce opacity each 3 frames
	if GameInit.gGlobalTimer % 3 ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 1)
	end

	-- Reduce opacity faster after 70 frames have passed
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > fadeFrames then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 5)
	end

	-- Delete object when it's fully transparent
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) <= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	-- If object times is less than 70 frame and Mario is not in the air...
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < fadeFrames and ObjectHelpers.mario_is_in_air_action() == 0 then
		-- ..define distance values depending of the scale multiplied by hit points
		const distMin1 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale) * shock_wave_inc.sBowserShockwaveHitPoints[1])
		const distMax1 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale) * shock_wave_inc.sBowserShockwaveHitPoints[2])
		const distMin2 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale) * shock_wave_inc.sBowserShockwaveHitPoints[3])
		const distMax2 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserShockWaveScale) * shock_wave_inc.sBowserShockwaveHitPoints[4])

		-- If Mario is in between distMin and distMax values, shock him
		if (distMin1 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < distMax1) or (distMin2 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < distMax2) then
			buffer.writei32(gMario.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(gMario.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_SHOCKWAVE)))
		end
	end
end

return shock_wave_inc
