--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/drawbridge.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const drawbridge_inc = {}

Registry.Register("src__game__behaviors__drawbridge_inc", drawbridge_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/drawbridge.inc.c:bhv_lll_drawbridge_spawner_loop L3-17
function drawbridge_inc.bhv_lll_drawbridge_spawner_loop()
	const o = ObjectListProcessor.gCurrentObject

	const drawbridge1 = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_LLL_DRAWBRIDGE_PART, BehaviorIds.bhvLLLDrawbridge)
	buffer.writei32(drawbridge1.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	buffer.writef32(drawbridge1.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(drawbridge1.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 640))
	buffer.writef32(drawbridge1.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(drawbridge1.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 640))

	const drawbridge2 = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_LLL_DRAWBRIDGE_PART, BehaviorIds.bhvLLLDrawbridge)
	buffer.writei32(drawbridge2.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)
	buffer.writef32(drawbridge2.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(drawbridge2.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * -640))
	buffer.writef32(drawbridge2.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(drawbridge2.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * -640))

	o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

-- from src/game/behaviors/drawbridge.inc.c:bhv_lll_drawbridge_loop L19-53
function drawbridge_inc.bhv_lll_drawbridge_loop()
	const o = ObjectListProcessor.gCurrentObject
	const globalTimer = GameInit.gGlobalTimer

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.LLL_DRAWBRIDGE_ACT_LOWER then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x100)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.LLL_DRAWBRIDGE_ACT_RAISE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - 0x100)
	end

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)) < -0x1FFD then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0xDFFF)

		-- Because the global timer increments when the game is paused, pausing and unpausing
		--  the game at regular intervals can leave the drawbridge raised indefinitely.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 50 and math.fmod(globalTimer, 8) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.LLL_DRAWBRIDGE_ACT_LOWER)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOAT_TILT1)
		end
	end

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)) >= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)

		-- Because the global timer increments when the game is paused, pausing and unpausing
		--  the game at regular intervals can leave the drawbridge lowered indefinitely.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 50 and math.fmod(globalTimer, 8) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.LLL_DRAWBRIDGE_ACT_RAISE)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOAT_TILT2)
		end
	end
end

return drawbridge_inc
