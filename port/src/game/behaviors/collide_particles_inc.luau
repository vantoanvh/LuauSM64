--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/collide_particles.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/collide_particles.inc.c:data
const collide_particles_inc = {
	-- from src/game/behaviors/collide_particles.inc.c:sTinyTriMovementParams L3-4
	sTinyTriMovementParams = { -12288, 0, 0x3000, 0, -8601, 0x2199, 0x2199, 0x2199, -8601, -8601, 0x2199, -8601 },
	-- from src/game/behaviors/collide_particles.inc.c:sTinyStarMovementParams L6-7
	sTinyStarMovementParams = { -8192, 0, 0, 0, 0x2000, 0, -5734, 0x1666, 0x1666, 0x1666, -5734, -5734, 0x1666, -5734 },
}

Registry.Register("src__game__behaviors__collide_particles_inc", collide_particles_inc)

-- from src/game/behaviors/collide_particles.inc.c:bhv_punch_tiny_triangle_loop L9-25
function collide_particles_inc.bhv_punch_tiny_triangle_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		-- from src/game/behaviors/collide_particles.inc.c:sp1E
		const sp1E = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, 1.28)
		ObjectHelpers.cur_obj_set_pos_relative(ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 0, 60, 100)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, sp1E)
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 5)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4) - F32(0.2))

	if ObjectListProcessor.gDebugInfo[5][1] + 6 < buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/collide_particles.inc.c:bhv_punch_tiny_triangle_init L27-37
function collide_particles_inc.bhv_punch_tiny_triangle_init()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	for i = 0, 5 do
		const triangle = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_DIRT_ANIMATION, BehaviorIds.bhvPunchTinyTriangle)

		buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(mario.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + collide_particles_inc.sTinyTriMovementParams[2 * i + 1] + 0x8000)
		buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.sins(collide_particles_inc.sTinyTriMovementParams[2 * i + 2]) * 25)
		buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineMathUtilH.coss(collide_particles_inc.sTinyTriMovementParams[2 * i + 2]) * 25)
	end
end

-- from src/game/behaviors/collide_particles.inc.c:bhv_wall_tiny_star_particle_loop L39-51
function collide_particles_inc.bhv_wall_tiny_star_particle_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		-- from src/game/behaviors/collide_particles.inc.c:sp1E
		const sp1E = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, 0.28)
		ObjectHelpers.cur_obj_set_pos_relative(ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 0, 30, 110)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, sp1E)
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 4)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4) - F32(0.015))
end

-- from src/game/behaviors/collide_particles.inc.c:bhv_tiny_star_particles_init L53-63
function collide_particles_inc.bhv_tiny_star_particles_init()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	for i = 0, 6 do
		const particle = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_CARTOON_STAR, BehaviorIds.bhvWallTinyStarParticle)

		buffer.writei32(particle.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(mario.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + collide_particles_inc.sTinyStarMovementParams[2 * i + 1] + 0x8000)
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.sins(collide_particles_inc.sTinyStarMovementParams[2 * i + 2]) * 25)
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineMathUtilH.coss(collide_particles_inc.sTinyStarMovementParams[2 * i + 2]) * 25)
	end
end

-- from src/game/behaviors/collide_particles.inc.c:bhv_pound_tiny_star_particle_loop L65-77
function collide_particles_inc.bhv_pound_tiny_star_particle_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, 0.28)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 20)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 14)
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 4)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCollisionParticleUnkF4) - F32(0.015))
end

-- from src/game/behaviors/collide_particles.inc.c:bhv_pound_tiny_star_particle_init L79-87
function collide_particles_inc.bhv_pound_tiny_star_particle_init()
	const o = ObjectListProcessor.gCurrentObject
	-- from src/game/behaviors/collide_particles.inc.c:sp20
	const sp20 = 8

	-- from src/game/behaviors/collide_particles.inc.c:sp24
	for sp24 = 0, sp20 - 1 do
		const particle = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_CARTOON_STAR, BehaviorIds.bhvPoundTinyStarParticle)

		buffer.writei32(particle.rawData, IncludeObjectFieldsH.oMoveAngleYaw, (sp24 * 65536) // sp20)
	end
end

return collide_particles_inc
