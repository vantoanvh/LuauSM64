--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_mist_particle.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroundParticlesInc = require("./ground_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const water_mist_particle_inc = {}

Registry.Register("src__game__behaviors__water_mist_particle_inc", water_mist_particle_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/water_mist_particle.inc.c:bhv_water_mist_spawn_loop L4-7
function water_mist_particle_inc.bhv_water_mist_spawn_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	GroundParticlesInc.clear_particle_flags(IncludeObjectConstantsH.ACTIVE_PARTICLE_BREATH)
	ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvWaterMist)
end

-- from src/game/behaviors/water_mist_particle.inc.c:bhv_water_mist_loop L9-25
function water_mist_particle_inc.bhv_water_mist_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		ObjectHelpers.obj_translate_xz_random(o, 10)
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 42))

	const Scale = F32((254 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity)) / 254.0 * 1.0 + 0.5)

	ObjectHelpers.cur_obj_scale(Scale)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 2 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return water_mist_particle_inc
