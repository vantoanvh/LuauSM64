--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/unused_poundable_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BreakParticlesInc = require("./break_particles_inc")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const unused_poundable_platform_inc = {}

Registry.Register("src__game__behaviors__unused_poundable_platform_inc", unused_poundable_platform_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/unused_poundable_platform.inc.c:bhv_unused_poundable_platform L16-30
function unused_poundable_platform_inc.bhv_unused_poundable_platform()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_scale(F32(1.02))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if ObjectHelpers.cur_obj_is_mario_ground_pounding_platform() ~= 0 then
			ObjectHelpers.spawn_mist_particles()
			BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_SL_CRACKED_ICE_CHUNK, 3, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 7 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	SrcEngineSurfaceLoad.load_object_collision_model()
end

return unused_poundable_platform_inc
