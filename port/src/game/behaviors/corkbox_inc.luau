--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/corkbox.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const LevelUpdate = require("../level_update")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const corkbox_inc = {}

Registry.Register("src__game__behaviors__corkbox_inc", corkbox_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/corkbox.inc.c:bhv_bobomb_bully_death_smoke_init L4-8
function corkbox_inc.bhv_bobomb_bully_death_smoke_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 300)

	ObjectHelpers.cur_obj_scale(10)
end

-- from src/game/behaviors/corkbox.inc.c:bhv_bobomb_explosion_bubble_init L10-17
function corkbox_inc.bhv_bobomb_explosion_bubble_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_scale_xyz(o, 2, 2, 1)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxExpRateX, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048)) + 0x800)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxExpRateY, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048)) + 0x800)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4)) + 4)
end

-- from src/game/behaviors/corkbox.inc.c:bhv_bobomb_explosion_bubble_loop L19-40
function corkbox_inc.bhv_bobomb_explosion_bubble_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const waterY = LevelUpdate.gMarioStates[1].waterLevel

	const ScaleSinX: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacX))
	o.header.gfx.scale[1] = F32(ScaleSinX * 0.5 + 2)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacX, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacX) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxExpRateX))

	const ScaleSinY: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacY))
	o.header.gfx.scale[2] = F32(ScaleSinY * 0.5 + 2)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacY, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxScaleFacY) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oBobombExpBubGfxExpRateY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > waterY then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMALL_WATER_SPLASH, BehaviorIds.bhvObjectWaterSplash)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 1)
end

-- from src/game/behaviors/corkbox.inc.c:bhv_respawner_loop L42-49
function corkbox_inc.bhv_respawner_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oRespawnerMinSpawnDist))) == 0 then
		const spawnedObject = ObjectHelpers.spawn_object(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oRespawnerModelToRespawn), o.ptrData[IncludeObjectFieldsH.oRespawnerBehaviorToRespawn + 1] :: number)

		buffer.writei32(spawnedObject.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/corkbox.inc.c:create_respawner L51-58
function corkbox_inc.create_respawner(model: number, behToSpawn: number, minSpawnDist: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	const respawner = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvRespawner, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))), 0, 0, 0)

	buffer.writei32(respawner.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
	buffer.writei32(respawner.rawData, IncludeObjectFieldsH.oRespawnerModelToRespawn, model)
	buffer.writef32(respawner.rawData, IncludeObjectFieldsH.oRespawnerMinSpawnDist, minSpawnDist)
	respawner.ptrData[IncludeObjectFieldsH.oRespawnerBehaviorToRespawn + 1] = behToSpawn
end

return corkbox_inc
