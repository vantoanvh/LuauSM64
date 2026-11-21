--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/snow_mound.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const snow_mound_inc = {}

Registry.Register("src__game__behaviors__snow_mound_inc", snow_mound_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/snow_mound.inc.c:bhv_sliding_snow_mound_loop L3-25
function snow_mound_inc.bhv_sliding_snow_mound_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, -40.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 117 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end

		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_SINK_QUICKSAND)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, -5.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -10.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - 2.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 50 then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

-- from src/game/behaviors/snow_mound.inc.c:bhv_snow_mound_spawn_loop L27-47
function snow_mound_inc.bhv_snow_mound_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local snowMound: GroupsTypesHPlus3.Object? = nil

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 6000) == 0
		or F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 1000.0) < (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).header.gfx.pos[2] then
		return
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 64 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 128 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 192 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 224 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 256 then
		snowMound = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SL_SNOW_TRIANGLE, BehaviorIds.bhvSlidingSnowMound)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 256 then
		const SnowMound = snowMound :: GroupsTypesHPlus3.Object

		SnowMound.header.gfx.scale[1] = 2.0
		SnowMound.header.gfx.scale[2] = 2.0
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 256 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

return snow_mound_inc
