--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ground_particles.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const BehaviorIds = require("../../rom/behavior_ids")

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/ground_particles.inc.c:data
const ground_particles_inc = {
	-- from src/game/behaviors/ground_particles.inc.c:sGlobalMistParticles L8-21
	sGlobalMistParticles = {
		bhvParam = 3,
		count = 20,
		model = IncludeModelIdsH.MODEL_MIST,
		offsetY = 20,
		forwardVelBase = 10,
		forwardVelRange = 5,
		velYBase = 0,
		velYRange = 0,
		gravity = 0,
		dragStrength = 30,
		sizeBase = 30.0,
		sizeRange = 1.5,
	},
	-- from src/game/behaviors/ground_particles.inc.c:sSandParticles L27-40
	sSandParticles = {
		bhvParam = 0,
		count = 5,
		model = IncludeModelIdsH.MODEL_SAND_DUST,
		offsetY = 0,
		forwardVelBase = 0,
		forwardVelRange = 20,
		velYBase = 20,
		velYRange = 0,
		gravity = -4,
		dragStrength = 30,
		sizeBase = 5.0,
		sizeRange = 2.0,
	},
	-- from src/game/behaviors/ground_particles.inc.c:sSmokeMovementParams L47-47
	sSmokeMovementParams = { 2, -8, 1, 4 },
	-- from src/game/behaviors/ground_particles.inc.c:sSnowParticles L64-77
	sSnowParticles = {
		bhvParam = 0,
		count = 5,
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_DL,
		offsetY = 0,
		forwardVelBase = 0,
		forwardVelRange = 20,
		velYBase = 20,
		velYRange = 0,
		gravity = -4,
		dragStrength = 30,
		sizeBase = 2.0,
		sizeRange = 2.0,
	},
}

Registry.Register("src__game__behaviors__ground_particles_inc", ground_particles_inc)

-- from src/game/behaviors/ground_particles.inc.c:bhv_pound_white_puffs_init L3-6
function ground_particles_inc.bhv_pound_white_puffs_init()
	ground_particles_inc.clear_particle_flags(IncludeObjectConstantsH.ACTIVE_PARTICLE_MIST_CIRCLE)
	ground_particles_inc.spawn_mist_from_global()
end

-- from src/game/behaviors/ground_particles.inc.c:spawn_mist_from_global L23-25
function ground_particles_inc.spawn_mist_from_global()
	Registry.Members.src__game__object_helpers.cur_obj_spawn_particles(ground_particles_inc.sGlobalMistParticles)
end

-- from src/game/behaviors/ground_particles.inc.c:bhv_ground_sand_init L42-45
function ground_particles_inc.bhv_ground_sand_init()
	ground_particles_inc.clear_particle_flags(IncludeObjectConstantsH.ACTIVE_PARTICLE_DIRT)
	Registry.Members.src__game__object_helpers.cur_obj_spawn_particles(ground_particles_inc.sSandParticles)
end

-- from src/game/behaviors/ground_particles.inc.c:spawn_smoke_with_velocity L49-57
function ground_particles_inc.spawn_smoke_with_velocity()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const smoke: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2, 1.0)

	buffer.writef32(smoke.rawData, IncludeObjectFieldsH.oForwardVel, ground_particles_inc.sSmokeMovementParams[1])
	buffer.writef32(smoke.rawData, IncludeObjectFieldsH.oVelY, ground_particles_inc.sSmokeMovementParams[2])
	buffer.writef32(smoke.rawData, IncludeObjectFieldsH.oGravity, ground_particles_inc.sSmokeMovementParams[3])

	Registry.Members.src__game__object_helpers.obj_translate_xyz_random(smoke, ground_particles_inc.sSmokeMovementParams[4])
end

-- from src/game/behaviors/ground_particles.inc.c:clear_particle_flags L60-62
function ground_particles_inc.clear_particle_flags(flags: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writeu32(parentObj.rawData, IncludeObjectFieldsH.oActiveParticleFlags, U32(bit32.band(buffer.readu32(parentObj.rawData, IncludeObjectFieldsH.oActiveParticleFlags), bit32.bxor(flags, 0xFFFFFFFF))))
end

-- from src/game/behaviors/ground_particles.inc.c:bhv_ground_snow_init L79-82
function ground_particles_inc.bhv_ground_snow_init()
	ground_particles_inc.clear_particle_flags(IncludeObjectConstantsH.ACTIVE_PARTICLE_SNOW)
	Registry.Members.src__game__object_helpers.cur_obj_spawn_particles(ground_particles_inc.sSnowParticles)
end

return ground_particles_inc
