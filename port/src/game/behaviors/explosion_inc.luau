--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/explosion.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const explosion_inc = {}

Registry.Register("src__game__behaviors__explosion_inc", explosion_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/explosion.inc.c:bhv_explosion_init L3-8
function explosion_inc.bhv_explosion_init()
	const o = ObjectListProcessor.gCurrentObject

	SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL2_BOBOMB_EXPLOSION)
	Camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_EXPLOSION)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
end

-- from src/game/behaviors/explosion.inc.c:bhv_explosion_loop L10-28
function explosion_inc.bhv_explosion_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 9 then
		if SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
			for i = 1, 40 do
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvBobombExplosionBubble)
			end
		else
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvBobombBullyDeathSmoke)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 14)

	ObjectHelpers.cur_obj_scale(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 9) + 1))
end

return explosion_inc
