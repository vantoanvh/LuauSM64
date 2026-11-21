--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sushi.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const sushi_inc = {}

Registry.Register("src__game__behaviors__sushi_inc", sushi_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/sushi.inc.c:bhv_sushi_shark_collision_loop L3-4
function sushi_inc.bhv_sushi_shark_collision_loop()
	-- Empty in the C source.
end

-- from src/game/behaviors/sushi.inc.c:bhv_sushi_shark_loop L6-26
function sushi_inc.bhv_sushi_shark_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp1C = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const SinUnkF4: number = SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSushiSharkUnkF4))
	const CosUnkF4: number = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSushiSharkUnkF4))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(SinUnkF4 * 1700.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(CosUnkF4 * 1700.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(Sp1C + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) + F32(SinUnkF4 * 200.0))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSushiSharkUnkF4) + 0x4000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSushiSharkUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSushiSharkUnkF4) + 0x80)

	if F32(buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) - Sp1C) > -500.0 then
		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - Sp1C) > -200.0 then
			ObjectHelpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_WAVE_TRAIL, BehaviorIds.bhvObjectWaveTrail, 4.0)
		end
	end

	if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 0x0F) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SUSHI_SHARK_WATER_SOUND)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return sushi_inc
