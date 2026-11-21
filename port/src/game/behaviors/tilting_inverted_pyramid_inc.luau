--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tilting_inverted_pyramid.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const SrcEngineMathUtil = require("../../engine/math_util")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const PlatformDisplacement = require("../platform_displacement")

const tilting_inverted_pyramid_inc = {}

Registry.Register("src__game__behaviors__tilting_inverted_pyramid_inc", tilting_inverted_pyramid_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/tilting_inverted_pyramid_inc.luau:scratch
const Scratch = {
	create_transform_from_normals_pos = { 0, 0, 0 },
	create_transform_from_normals_normal = { 0, 0, 0 },
	bhv_tilting_inverted_pyramid_loop_mx = { 0 },
	bhv_tilting_inverted_pyramid_loop_my = { 0 },
	bhv_tilting_inverted_pyramid_loop_mz = { 0 },
	bhv_tilting_inverted_pyramid_loop_dist = { 0, 0, 0 },
	bhv_tilting_inverted_pyramid_loop_posBeforeRotation = { 0, 0, 0 },
	bhv_tilting_inverted_pyramid_loop_posAfterRotation = { 0, 0, 0 },
}

-- from src/game/behaviors/tilting_inverted_pyramid.inc.c:create_transform_from_normals L11-24
function tilting_inverted_pyramid_inc.create_transform_from_normals(transform: { { number } }, xNorm: number, yNorm: number, zNorm: number)
	xNorm = F32(xNorm)
	yNorm = F32(yNorm)
	zNorm = F32(zNorm)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	Scratch.create_transform_from_normals_pos[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	Scratch.create_transform_from_normals_pos[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	Scratch.create_transform_from_normals_pos[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

	Scratch.create_transform_from_normals_normal[1] = xNorm
	Scratch.create_transform_from_normals_normal[2] = yNorm
	Scratch.create_transform_from_normals_normal[3] = zNorm

	SrcEngineMathUtil.mtxf_align_terrain_normal(transform, Scratch.create_transform_from_normals_normal, Scratch.create_transform_from_normals_pos, 0)
end

-- from src/game/behaviors/tilting_inverted_pyramid.inc.c:bhv_platform_normals_init L29-37
function tilting_inverted_pyramid_inc.bhv_platform_normals_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalX, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalY, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalZ, 0.0)

	-- The C pointer to the object's transform is kept as the one element table throwMatrix holds.
	o.header.gfx.throwMatrix = { o.transform }
	tilting_inverted_pyramid_inc.create_transform_from_normals(o.transform, 0.0, 1.0, 0.0)
end

-- from src/game/behaviors/tilting_inverted_pyramid.inc.c:approach_by_increment L43-59
function tilting_inverted_pyramid_inc.approach_by_increment(goal: number, src: number, inc: number): number
	goal = F32(goal)
	src = F32(src)
	inc = F32(inc)
	local NewVal: number

	if src <= goal then
		if F32(goal - src) < inc then
			NewVal = goal
		else
			NewVal = F32(src + inc)
		end
	elseif F32(goal - src) > -inc then
		NewVal = goal
	else
		NewVal = F32(src - inc)
	end

	return NewVal
end

-- from src/game/behaviors/tilting_inverted_pyramid.inc.c:bhv_tilting_inverted_pyramid_loop L65-140
function tilting_inverted_pyramid_inc.bhv_tilting_inverted_pyramid_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Transform = o.header.gfx.throwMatrix :: { { { number } } }
	local dx: number
	local dy: number
	local dz: number
	local d: number
	local MarioOnPlatform = IncludePRUltratypesH.FALSE

	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		PlatformDisplacement.get_mario_pos(Scratch.bhv_tilting_inverted_pyramid_loop_mx, Scratch.bhv_tilting_inverted_pyramid_loop_my, Scratch.bhv_tilting_inverted_pyramid_loop_mz)

		Scratch.bhv_tilting_inverted_pyramid_loop_dist[1] = F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		Scratch.bhv_tilting_inverted_pyramid_loop_dist[2] = F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
		Scratch.bhv_tilting_inverted_pyramid_loop_dist[3] = F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		ObjectHelpers.linear_mtxf_mul_vec3f(o.transform, Scratch.bhv_tilting_inverted_pyramid_loop_posBeforeRotation, Scratch.bhv_tilting_inverted_pyramid_loop_dist)

		dx = F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		dy = 500.0
		dz = F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		d = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

		-- Always true since dy = 500, making d >= 500.
		if d ~= 0.0 then
			-- Normalizing
			d = F32(1.0 / d)
			dx = F32(dx * d)
			dy = F32(dy * d)
			dz = F32(dz * d)
		else
			dx = 0.0
			dy = 1.0
			dz = 0.0
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidMarioOnPlatform) == IncludePRUltratypesH.TRUE then
			MarioOnPlatform += 1
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidMarioOnPlatform, IncludePRUltratypesH.TRUE)
	else
		dx = 0.0
		dy = 1.0
		dz = 0.0
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidMarioOnPlatform, IncludePRUltratypesH.FALSE)
	end

	-- Approach the normals by 0.01f towards the new goal, then create a transform matrix and orient the object.
	-- Outside of the other conditionals since it needs to tilt regardless of whether Mario is on.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalX, tilting_inverted_pyramid_inc.approach_by_increment(dx, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalX), F32(0.01)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalY, tilting_inverted_pyramid_inc.approach_by_increment(dy, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalY), F32(0.01)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalZ, tilting_inverted_pyramid_inc.approach_by_increment(dz, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalZ), F32(0.01)))
	tilting_inverted_pyramid_inc.create_transform_from_normals(o.transform, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oTiltingPyramidNormalZ))

	-- If Mario is on the platform, adjust his position for the platform tilt.
	if MarioOnPlatform ~= 0 then
		ObjectHelpers.linear_mtxf_mul_vec3f(o.transform, Scratch.bhv_tilting_inverted_pyramid_loop_posAfterRotation, Scratch.bhv_tilting_inverted_pyramid_loop_dist)
		Scratch.bhv_tilting_inverted_pyramid_loop_mx[1] = F32(Scratch.bhv_tilting_inverted_pyramid_loop_mx[1] + F32(Scratch.bhv_tilting_inverted_pyramid_loop_posAfterRotation[1] - Scratch.bhv_tilting_inverted_pyramid_loop_posBeforeRotation[1]))
		Scratch.bhv_tilting_inverted_pyramid_loop_my[1] = F32(Scratch.bhv_tilting_inverted_pyramid_loop_my[1] + F32(Scratch.bhv_tilting_inverted_pyramid_loop_posAfterRotation[2] - Scratch.bhv_tilting_inverted_pyramid_loop_posBeforeRotation[2]))
		Scratch.bhv_tilting_inverted_pyramid_loop_mz[1] = F32(Scratch.bhv_tilting_inverted_pyramid_loop_mz[1] + F32(Scratch.bhv_tilting_inverted_pyramid_loop_posAfterRotation[3] - Scratch.bhv_tilting_inverted_pyramid_loop_posBeforeRotation[3]))
		PlatformDisplacement.set_mario_pos(Scratch.bhv_tilting_inverted_pyramid_loop_mx[1], Scratch.bhv_tilting_inverted_pyramid_loop_my[1], Scratch.bhv_tilting_inverted_pyramid_loop_mz[1])
	end

	o.header.gfx.throwMatrix = Transform
end

return tilting_inverted_pyramid_inc
