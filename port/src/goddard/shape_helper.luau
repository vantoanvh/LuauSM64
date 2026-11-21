--!strict
--!optimize 2

--[[
	Port of src/goddard/shape_helper.c.
]]

const Registry = require("../../groups/registry")

const IncludeMacrosH = require("../../include/macros_h")

const DebugUtilsH = require("./debug_utils_h")
const DynlistProcH = require("./dynlist_proc_h")
const DynlistsDynlistMacrosH = require("./dynlists/dynlist_macros_h")
const GdTypesH = require("./gd_types_h")
const DebugUtils = require("./debug_utils")
const DrawObjects = require("./draw_objects")
const DynlistProc = require("./dynlist_proc")
const DynlistsDynlistTestCube = require("./dynlists/dynlist_test_cube")
const DynlistsDynlistUnused = require("./dynlists/dynlist_unused")
const GdMain = require("./gd_main")
const GdMath = require("./gd_math")
const Objects = require("./objects")
const DrawObjectsH = require("./draw_objects_h")
const DynlistsDynlistsH = require("./dynlists/dynlists_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Joints = require("./joints")
const Particles = require("./particles")
const Skin = require("./skin")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/goddard/shape_helper.luau:scratch
const Scratch = {
	calc_face_normal_normal = { x = 0, y = 0, z = 0 },
	scale_obj_position_pos = { x = 0, y = 0, z = 0 },
}

-- from src/goddard/shape_helper.c:data
const shape_helper = {
	-- from src/goddard/shape_helper.c:gMarioFaceGrp L24-24
	gMarioFaceGrp = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/shape_helper.c:gSpotShape L25-25
	gSpotShape = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:sGrabJointTestShape L26-26
	sGrabJointTestShape = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:gShapeRedSpark L27-27
	gShapeRedSpark = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:gShapeSilverSpark L28-28
	gShapeSilverSpark = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:gShapeRedStar L29-29
	gShapeRedStar = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:gShapeSilverStar L30-30
	gShapeSilverStar = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:unusedAnimData1 L34-36
	unusedAnimData1 = {
		GdTypesH.new_GdAnimTransform(),
	},
	-- from src/goddard/shape_helper.c:unusedAnimData2 L40-42
	unusedAnimData2 = {
		GdTypesH.new_GdAnimTransform(),
	},
	-- from src/goddard/shape_helper.c:unusedAnimData3 L46-48
	unusedAnimData3 = {
		GdTypesH.new_GdAnimTransform(),
	},
	-- from src/goddard/shape_helper.c:sUnref801A838C L52-52
	sUnref801A838C = { 0, 0, 0, 0, 0, 0 },
	-- from src/goddard/shape_helper.c:sSimpleShape L53-53
	sSimpleShape = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:sUnref801A83A8 L54-54
	sUnref801A83A8 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
	-- from src/goddard/shape_helper.c:sDynlist801A84E4 L65-69
	sDynlist801A84E4 = {
		DynlistsDynlistMacrosH.BeginList(),
		DynlistsDynlistMacrosH.SetFlag(0x1800),
		DynlistsDynlistMacrosH.EndList(),
	},
	-- from src/goddard/shape_helper.c:D_801A8668 L86-86
	D_801A8668 = 0.0,
	-- from src/goddard/shape_helper.c:sUnrefSpaceB00 L89-89
	sUnrefSpaceB00 = buffer.create(44),
	-- from src/goddard/shape_helper.c:sCubeShapeGroup L90-90
	sCubeShapeGroup = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/shape_helper.c:sUnrefSpaceB30 L91-91
	sUnrefSpaceB30 = buffer.create(12),
	-- from src/goddard/shape_helper.c:sCubeShape L92-92
	sCubeShape = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:sUnrefSpaceB40 L93-93
	sUnrefSpaceB40 = buffer.create(8),
	-- from src/goddard/shape_helper.c:sGdLineBuf L94-94
	sGdLineBuf = buffer.create(256),
	-- from src/goddard/shape_helper.c:sGdLineBufCsr L95-95
	sGdLineBufCsr = 0,
	-- from src/goddard/shape_helper.c:sGdShapeFile L96-96
	sGdShapeFile = nil :: DebugUtilsH.GdFile?,
	-- from src/goddard/shape_helper.c:sGdShapeListHead L97-97
	sGdShapeListHead = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/shape_helper.c:sGdShapeCount L98-98
	sGdShapeCount = 0,
	-- from src/goddard/shape_helper.c:sUnrefSpaceC58 L99-99
	sUnrefSpaceC58 = buffer.create(8),
	-- from src/goddard/shape_helper.c:D_801BAC60 L100-100
	D_801BAC60 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/shape_helper.c:sUnrefSpaceC6C L101-101
	sUnrefSpaceC6C = 0,
	-- from src/goddard/shape_helper.c:sUnrefSpaceC70 L102-102
	sUnrefSpaceC70 = 0,
	-- from src/goddard/shape_helper.c:D_801BAC74 L103-103
	D_801BAC74 = nil :: GdTypesH.ObjPlane?,
	-- from src/goddard/shape_helper.c:D_801BAC78 L104-104
	D_801BAC78 = nil :: GdTypesH.ObjPlane?,
	-- from src/goddard/shape_helper.c:sUnrefSpaceC80 L105-105
	sUnrefSpaceC80 = buffer.create(28),
	-- from src/goddard/shape_helper.c:D_801BAC9C L106-106
	D_801BAC9C = nil :: GdTypesH.ObjFace?,
	-- from src/goddard/shape_helper.c:D_801BACA0 L107-107
	D_801BACA0 = nil :: GdTypesH.ObjFace?,
	-- from src/goddard/shape_helper.c:sUnrefSpaceCA8 L108-108
	sUnrefSpaceCA8 = buffer.create(16),
	-- from src/goddard/shape_helper.c:sVertexScaleFactor L110-110
	sVertexScaleFactor = { x = 0, y = 0, z = 0 },
	-- from src/goddard/shape_helper.c:sVertexTranslateOffset L112-112
	sVertexTranslateOffset = { x = 0, y = 0, z = 0 },
	-- from src/goddard/shape_helper.c:sUnrefSpaceCD8 L113-113
	sUnrefSpaceCD8 = buffer.create(48),
	-- from src/goddard/shape_helper.c:D_801BAD08 L114-114
	D_801BAD08 = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/shape_helper.c:sUnrefSpaceD10 L115-115
	sUnrefSpaceD10 = buffer.create(32),
	-- from src/goddard/shape_helper.c:sShapeCenter L116-116
	sShapeCenter = { x = 0, y = 0, z = 0 },
	-- from src/goddard/shape_helper.c:sUnrefSpaceD40 L117-117
	sUnrefSpaceD40 = buffer.create(288),
}

Registry.Register("src__goddard__shape_helper", shape_helper)

-- from src/goddard/shape_helper.c:unusedAnimData1 L34-36: { {1.0, 1.0, 1.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0} }
for Index, UnusedAnimData in { shape_helper.unusedAnimData1, shape_helper.unusedAnimData2, shape_helper.unusedAnimData3 } do
	UnusedAnimData[1].x = 1.0
	UnusedAnimData[1].y = 1.0
	UnusedAnimData[1].z = 1.0
end

-- from src/goddard/shape_helper.c:func_80197280 L124-128
function shape_helper.func_80197280()
	shape_helper.sGdShapeCount = 0
	shape_helper.sGdShapeListHead = nil
	DrawObjects.gGdLightGroup = Objects.make_group(0)
end

-- from src/goddard/shape_helper.c:calc_face_normal L133-176
function shape_helper.calc_face_normal(face: GdTypesH.ObjFace)
	local p1x = 0.0
	local p1y = 0.0
	local p1z = 0.0
	local p2x = 0.0
	local p2y = 0.0
	local p2z = 0.0
	local p3x = 0.0
	local p3y = 0.0
	local p3z = 0.0
	const normal = Scratch.calc_face_normal_normal
	const mul = 1000.0

	if face.vtxCount >= 3 then
		const vtx1 = face.vertices[1] :: GdTypesH.ObjVertex
		p1x = vtx1.pos.x
		p1y = vtx1.pos.y
		p1z = vtx1.pos.z

		const vtx2 = face.vertices[2] :: GdTypesH.ObjVertex
		p2x = vtx2.pos.x
		p2y = vtx2.pos.y
		p2z = vtx2.pos.z

		const vtx3 = face.vertices[3] :: GdTypesH.ObjVertex
		p3x = vtx3.pos.x
		p3y = vtx3.pos.y
		p3z = vtx3.pos.z

		normal.x = F32(F32(F32(F32(p2y - p1y) * F32(p3z - p2z)) - F32(F32(p2z - p1z) * F32(p3y - p2y))) * mul)
		normal.y = F32(F32(F32(F32(p2z - p1z) * F32(p3x - p2x)) - F32(F32(p2x - p1x) * F32(p3z - p2z))) * mul)
		normal.z = F32(F32(F32(F32(p2x - p1x) * F32(p3y - p2y)) - F32(F32(p2y - p1y) * F32(p3x - p2x))) * mul)

		GdMath.gd_normalize_vec3f(normal)

		face.normal.x = normal.x
		face.normal.y = normal.y
		face.normal.z = normal.z
	end
end

-- from src/goddard/shape_helper.c:gd_make_vertex L179-202
function shape_helper.gd_make_vertex(x: number, y: number, z: number): GdTypesH.ObjVertex
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const vtx = Objects.make_object(GdTypesH.OBJ_TYPE_VERTICES) :: GdTypesH.ObjVertex
	vtx.id = S16(0xD1D4)

	vtx.pos.x = x
	vtx.pos.y = y
	vtx.pos.z = z

	vtx.initPos.x = x
	vtx.initPos.y = y
	vtx.initPos.z = z

	vtx.scaleFactor = 1.0
	vtx.gbiVerts = nil
	vtx.alpha = 1.0

	vtx.normal.x = 0.0
	vtx.normal.y = 1.0
	vtx.normal.z = 0.0

	return vtx
end

-- from src/goddard/shape_helper.c:make_face_with_colour L205-221
function shape_helper.make_face_with_colour(r: number, g: number, b: number): GdTypesH.ObjFace
	r = F32(r)
	g = F32(g)
	b = F32(b)
	const newFace = Objects.make_object(GdTypesH.OBJ_TYPE_FACES) :: GdTypesH.ObjFace

	newFace.colour.r = r
	newFace.colour.g = g
	newFace.colour.b = b

	newFace.vtxCount = 0
	newFace.mtlId = -1
	newFace.mtl = nil

	return newFace
end

-- from src/goddard/shape_helper.c:make_face_with_material L224-234
function shape_helper.make_face_with_material(mtl: GdTypesH.ObjMaterial): GdTypesH.ObjFace
	error("stale")
end

-- from src/goddard/shape_helper.c:add_4_vertices_to_face L237-245
function shape_helper.add_4_vertices_to_face(face: GdTypesH.ObjFace, vtx1: GdTypesH.ObjVertex, vtx2: GdTypesH.ObjVertex, vtx3: GdTypesH.ObjVertex, vtx4: GdTypesH.ObjVertex)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:add_3_vtx_to_face L248-255
function shape_helper.add_3_vtx_to_face(face: GdTypesH.ObjFace, vtx1: GdTypesH.ObjVertex, vtx2: GdTypesH.ObjVertex, vtx3: GdTypesH.ObjVertex)
	face.vertices[1] = vtx1
	face.vertices[2] = vtx2
	face.vertices[3] = vtx3
	face.vtxCount = 3
	shape_helper.calc_face_normal(face)
end

-- from src/goddard/shape_helper.c:make_shape L260-302
function shape_helper.make_shape(flag: number, name: string?): GdTypesH.ObjShape
	const newShape = Objects.make_object(GdTypesH.OBJ_TYPE_SHAPES) :: GdTypesH.ObjShape

	if name ~= nil then
		DebugUtils.gd_strcpy(newShape.name, name)
	else
		DebugUtils.gd_strcpy(newShape.name, "NoName")
	end

	shape_helper.sGdShapeCount = U32(shape_helper.sGdShapeCount + 1)

	const curShapeHead = shape_helper.sGdShapeListHead
	shape_helper.sGdShapeListHead = newShape

	if curShapeHead ~= nil then
		newShape.nextShape = curShapeHead
		curShapeHead.prevShape = newShape
	end

	newShape.id = shape_helper.sGdShapeCount
	newShape.flag = flag

	newShape.vtxCount = 0
	newShape.faceCount = 0
	newShape.dlNums[1] = 0
	newShape.dlNums[2] = 0
	newShape.unk3C = 0
	newShape.faceGroup = nil

	newShape.alpha = 1.0

	newShape.vtxGroup = nil
	newShape.faceGroup = nil
	newShape.mtlGroup = nil
	newShape.unk30 = 0
	newShape.unk50 = 0

	return newShape
end

-- from src/goddard/shape_helper.c:clear_buf_to_cr L305-308
function shape_helper.clear_buf_to_cr()
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:get_current_buf_char L311-313
function shape_helper.get_current_buf_char(): number
	error("stale")
end

-- from src/goddard/shape_helper.c:get_and_advance_buf L316-322
function shape_helper.get_and_advance_buf(): number
	error("stale")
end

-- from src/goddard/shape_helper.c:load_next_line_into_buf L325-335
function shape_helper.load_next_line_into_buf(): number
	error("stale")
end

-- from src/goddard/shape_helper.c:is_line_end L338-340
function shape_helper.is_line_end(c: number): number
	error("stale")
end

-- from src/goddard/shape_helper.c:is_white_space L343-345
function shape_helper.is_white_space(c: number): number
	error("stale")
end

-- from src/goddard/shape_helper.c:scan_to_next_non_whitespace L350-374
function shape_helper.scan_to_next_non_whitespace(): number
	error("stale")
end

-- from src/goddard/shape_helper.c:is_next_buf_word L377-395
function shape_helper.is_next_buf_word(a0: string): number
	error("stale")
end

-- from src/goddard/shape_helper.c:getfloat L398-433
function shape_helper.getfloat(floatPtr: { number }): number
	error("stale")
end

-- from src/goddard/shape_helper.c:getint L436-466
function shape_helper.getint(intPtr: { number }): number
	error("stale")
end

-- from src/goddard/shape_helper.c:Unknown80198068 L469-471
function shape_helper.Unknown80198068(a0: number)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:func_8019807C L474-478
function shape_helper.func_8019807C(vtx: GdTypesH.ObjVertex)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:func_801980E8 L481-485
function shape_helper.func_801980E8(a0: { number })
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown80198154 L488-492
function shape_helper.Unknown80198154(x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown80198184 L495-502
function shape_helper.Unknown80198184(shape: GdTypesH.ObjShape, x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:scale_obj_position L505-521
function shape_helper.scale_obj_position(obj: GdTypesH.GdObj)
	const pos = Scratch.scale_obj_position_pos

	if obj.type_ == GdTypesH.OBJ_TYPE_GROUPS then
		return
	end

	DynlistProc.set_cur_dynobj(obj)
	DynlistProc.d_get_rel_pos(pos)

	pos.x = F32(pos.x * shape_helper.sVertexScaleFactor.x)
	pos.y = F32(pos.y * shape_helper.sVertexScaleFactor.y)
	pos.z = F32(pos.z * shape_helper.sVertexScaleFactor.z)

	DynlistProc.d_set_rel_pos(pos.x, pos.y, pos.z)
	DynlistProc.d_set_init_pos(pos.x, pos.y, pos.z)
end

-- from src/goddard/shape_helper.c:translate_obj_position L524-535
function shape_helper.translate_obj_position(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:scale_verts_in_shape L538-546
function shape_helper.scale_verts_in_shape(shape: GdTypesH.ObjShape, x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	shape_helper.sVertexScaleFactor.x = x
	shape_helper.sVertexScaleFactor.y = y
	shape_helper.sVertexScaleFactor.z = z

	if shape.vtxGroup ~= nil then
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, shape_helper.scale_obj_position, shape.vtxGroup)
	end
end

-- from src/goddard/shape_helper.c:translate_verts_in_shape L550-556
function shape_helper.translate_verts_in_shape(shape: GdTypesH.ObjShape, x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown80198444 L559-573
function shape_helper.Unknown80198444(vtx: GdTypesH.ObjVertex)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown80198524 L576-584
function shape_helper.Unknown80198524(vtx: GdTypesH.ObjVertex)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown801985E8 L587-603
function shape_helper.Unknown801985E8(shape: GdTypesH.ObjShape)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:get_3DG1_shape L606-722
function shape_helper.get_3DG1_shape(shape: GdTypesH.ObjShape)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:get_OBJ_shape L725-816
function shape_helper.get_OBJ_shape(shape: GdTypesH.ObjShape)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:group_faces_in_mtl_grp L819-849
function shape_helper.group_faces_in_mtl_grp(mtlGroup: GdTypesH.ObjGroup, fromObj: GdTypesH.GdObj, toObj: GdTypesH.GdObj?): GdTypesH.ObjGroup
	error("stale")
end

-- from src/goddard/shape_helper.c:find_or_add_new_mtl L852-877
function shape_helper.find_or_add_new_mtl(group: GdTypesH.ObjGroup, a1: number, r: number, g: number, b: number): GdTypesH.ObjMaterial
	error("stale")
end

-- from src/goddard/shape_helper.c:read_ARK_shape L880-1008
function shape_helper.read_ARK_shape(shape: GdTypesH.ObjShape, fileName: string)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:get_shape_from_file L1011-1047
function shape_helper.get_shape_from_file(shape: GdTypesH.ObjShape, fileName: string): DebugUtilsH.GdFile?
	error("stale")
end

-- from src/goddard/shape_helper.c:make_grid_shape L1050-1160
function shape_helper.make_grid_shape(gridType: number, a1: number, a2: number, a3: number, a4: number): GdTypesH.ObjShape
	error("stale")
end

-- from src/goddard/shape_helper.c:Unknown80199E44 L1163-1165
function shape_helper.Unknown80199E44(a0: number, a1: GdTypesH.GdObj, a2: GdTypesH.GdObj, a3: number)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:Unknown80199E88 L1168-1174
function shape_helper.Unknown80199E88(face: GdTypesH.ObjFace)
	error("stale")
	return
end

-- from src/goddard/shape_helper.c:make_netfromshape L1177-1191
function shape_helper.make_netfromshape(shape: GdTypesH.ObjShape?): GdTypesH.ObjNet
	error("stale")
end

-- from src/goddard/shape_helper.c:animate_mario_head_gameover L1196-1214
function shape_helper.animate_mario_head_gameover(self: GdTypesH.ObjAnimator)
	if self.state == 0 then
		self.frame = 1.0
		self.animSeqNum = 1
		self.state = 1
	elseif self.state == 1 then
		self.frame = F32(self.frame + 1.0)

		if self.frame == 166.0 then
			self.frame = 69.0
			self.state = 4
			self.controlFunc = shape_helper.animate_mario_head_normal
			self.animSeqNum = 0
		end
	end
end

-- from src/goddard/shape_helper.c:animate_mario_head_normal L1219-1294
function shape_helper.animate_mario_head_normal(self: GdTypesH.ObjAnimator)
	local state = 0
	const aBtnPressed = GdMain.gGdCtrl.dragging

	if self.state == 0 then
		self.frame = 1.0
		self.animSeqNum = 0
		state = 2
		self.nods = 5
	elseif self.state == 2 then
		if aBtnPressed ~= 0 then
			state = 5
		end

		self.frame = F32(self.frame + 1.0)

		if self.frame == 810.0 then
			self.frame = 750.0
			self.nods = S32(self.nods - 1)

			if self.nods == 0 then
				state = 3
			end
		end
	elseif self.state == 3 then
		self.frame = F32(self.frame + 1.0)

		if self.frame == 820.0 then
			self.frame = 69.0
			state = 4
		end
	elseif self.state == 4 then
		self.frame = F32(self.frame + 1.0)

		if self.frame == 660.0 then
			self.frame = 661.0
			state = 2
			self.nods = 5
		end
	elseif self.state == 5 then
		if self.frame == 660.0 then
			state = 7
		elseif self.frame > 660.0 then
			self.frame = F32(self.frame - 1.0)
		elseif self.frame < 660.0 then
			self.frame = F32(self.frame + 1.0)
		end

		self.stillTimer = 150
	elseif self.state == 7 then
		if aBtnPressed ~= 0 then
			self.stillTimer = 300
		else
			self.stillTimer = S32(self.stillTimer - 1)

			if self.stillTimer == 0 then
				state = 6
			end
		end

		self.frame = 660.0
	elseif self.state == 6 then
		state = 2
		self.nods = 5
	end

	if state ~= 0 then
		self.state = state
	end
end

-- from src/goddard/shape_helper.c:load_mario_head L1300-1437
function shape_helper.load_mario_head(aniFn: (GdTypesH.ObjAnimator) -> ()): number
	DynlistProc.d_set_name_suffix("l")

	DynlistProc.d_use_integer_names(IncludePRUltratypesH.TRUE)
	const animator = DynlistProc.d_makeobj(DynlistProcH.D_ANIMATOR, DynlistsDynlistsH.DYNOBJ_MARIO_MAIN_ANIMATOR) :: GdTypesH.ObjAnimator
	animator.controlFunc = aniFn
	DynlistProc.d_use_integer_names(IncludePRUltratypesH.FALSE)

	const dynlistMarioMaster: { GdTypesH.DynList } = Registry.Members.src__goddard__dynlists__dynlist_mario_master.dynlist_mario_master
	const marioFaceDynlist: GdTypesH.GdObj = Registry.Members.src__goddard__renderer.load_dynlist(dynlistMarioMaster)
	const marioFaceGrp = marioFaceDynlist :: GdTypesH.ObjGroup
	shape_helper.gMarioFaceGrp = marioFaceGrp

	const camera = DynlistProc.d_makeobj(DynlistProcH.D_CAMERA, nil) :: GdTypesH.ObjCamera
	DynlistProc.d_set_rel_pos(0.0, 200.0, 2000.0)
	DynlistProc.d_set_world_pos(0.0, 200.0, 2000.0)
	DynlistProc.d_set_flags(4)
	camera.lookAt.x = 0.0
	camera.lookAt.y = 200.0
	camera.lookAt.z = 0.0

	Objects.addto_group(marioFaceGrp, camera.header)
	Objects.addto_group(marioFaceGrp, animator.header)

	DynlistProc.d_set_name_suffix(nil)

	local particle = Particles.make_particle(0, DrawObjectsH.COLOUR_WHITE, 0.0, 0.0, 0.0)
	particle.unk60 = 3
	particle.unk64 = 3
	particle.attachedToObj = camera.header
	particle.shapePtr = shape_helper.gShapeSilverSpark
	Objects.addto_group(DrawObjects.gGdLightGroup :: GdTypesH.ObjGroup, particle.header)

	particle = Particles.make_particle(0, DrawObjectsH.COLOUR_WHITE, 0.0, 0.0, 0.0)
	particle.unk60 = 3
	particle.unk64 = 2
	particle.attachedToObj = DynlistProc.d_use_obj("N228l")
	particle.shapePtr = shape_helper.gShapeSilverSpark
	Objects.addto_group(DrawObjects.gGdLightGroup :: GdTypesH.ObjGroup, particle.header)

	particle = Particles.make_particle(0, DrawObjectsH.COLOUR_RED, 0.0, 0.0, 0.0)
	particle.unk60 = 3
	particle.unk64 = 2
	particle.attachedToObj = DynlistProc.d_use_obj("N231l")
	particle.shapePtr = shape_helper.gShapeRedSpark
	Objects.addto_group(DrawObjects.gGdLightGroup :: GdTypesH.ObjGroup, particle.header)

	const mainShapesGrp = DynlistProc.d_use_obj("N1000l") :: GdTypesH.ObjGroup
	DrawObjects.create_gddl_for_shapes(mainShapesGrp)
	const sp38 = Objects.gGdObjectList :: GdTypesH.GdObj

	const grabJointTestShape = shape_helper.sGrabJointTestShape :: GdTypesH.ObjShape

	local grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, -500.0, 0.0, -150.0)
	local faceJoint = DynlistProc.d_use_obj("N167l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 500.0, 0.0, -150.0)
	faceJoint = DynlistProc.d_use_obj("N176l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 0.0, 700.0, 300.0)
	faceJoint = DynlistProc.d_use_obj("N131l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	faceJoint = DynlistProc.d_use_obj("N206l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)
	faceJoint = DynlistProc.d_use_obj("N215l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)
	faceJoint = DynlistProc.d_use_obj("N31l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)
	faceJoint = DynlistProc.d_use_obj("N65l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 0.0, 0.0, 600.0)
	faceJoint = DynlistProc.d_use_obj("N185l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 0.0, -300.0, 300.0)
	faceJoint = DynlistProc.d_use_obj("N194l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 250.0, -150.0, 300.0)
	faceJoint = DynlistProc.d_use_obj("N158l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	faceJoint = DynlistProc.d_use_obj("N15l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, -250.0, -150.0, 300.0)
	faceJoint = DynlistProc.d_use_obj("N149l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)

	faceJoint = DynlistProc.d_use_obj("N6l")
	Objects.addto_group(grabberJoint.attachedObjsGrp :: GdTypesH.ObjGroup, faceJoint)

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, 100.0, 200.0, 400.0)
	faceJoint = DynlistProc.d_use_obj("N112l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)
	grabberJoint.updateFunc = Joints.eye_joint_update_func
	grabberJoint.rootAnimator = animator
	grabberJoint.header.drawFlags = U16(bit32.band(grabberJoint.header.drawFlags, bit32.bnot(GdTypesH.OBJ_IS_GRABBABLE)))

	grabberJoint = Joints.make_grabber_joint(grabJointTestShape, 0, -100.0, 200.0, 400.0)
	faceJoint = DynlistProc.d_use_obj("N96l")
	grabberJoint.attachedObjsGrp = Objects.make_group(1, faceJoint)
	grabberJoint.updateFunc = Joints.eye_joint_update_func
	grabberJoint.rootAnimator = animator
	grabberJoint.header.drawFlags = U16(bit32.band(grabberJoint.header.drawFlags, bit32.bnot(GdTypesH.OBJ_IS_GRABBABLE)))

	const sp48 = Objects.make_group_of_type(GdTypesH.OBJ_TYPE_JOINTS, sp38, nil)
	const sp54 = Skin.make_net(0, nil, sp48, nil, nil)
	sp54.netType = 3
	Objects.addto_group(marioFaceGrp, sp48.header)
	Objects.addto_groupfirst(marioFaceGrp, sp54.header)

	return 0
end

-- from src/goddard/shape_helper.c:load_shapes2 L1440-1457
function shape_helper.load_shapes2()
	DynlistProc.reset_dynlist()
	shape_helper.func_80197280()

	const cubeShape = shape_helper.make_shape(0, "cube")
	shape_helper.sCubeShape = cubeShape

	const spotShape = Registry.Members.src__goddard__renderer.load_dynlist(DynlistsDynlistUnused.dynlist_spot_shape) :: GdTypesH.ObjShape
	shape_helper.gSpotShape = spotShape
	shape_helper.scale_verts_in_shape(spotShape, 200.0, 200.0, 200.0)

	const grabJointTestShape = Registry.Members.src__goddard__renderer.load_dynlist(DynlistsDynlistTestCube.dynlist_test_cube) :: GdTypesH.ObjShape
	shape_helper.sGrabJointTestShape = grabJointTestShape
	shape_helper.scale_verts_in_shape(grabJointTestShape, 30.0, 30.0, 30.0)

	const cubeShapeGroup = Objects.make_group_of_type(GdTypesH.OBJ_TYPE_SHAPES, cubeShape.header, nil)
	shape_helper.sCubeShapeGroup = cubeShapeGroup
	DrawObjects.create_gddl_for_shapes(cubeShapeGroup)
end

-- from src/goddard/shape_helper.c:Unknown8019AB98 L1460-1501
function shape_helper.Unknown8019AB98(a0: number): GdTypesH.ObjGroup
	error("stale")
end

-- from src/goddard/shape_helper.c:Unknown8019ADC4 L1504-1526
function shape_helper.Unknown8019ADC4(a0: number): GdTypesH.ObjGroup
	error("stale")
end

-- from src/goddard/shape_helper.c:Unknown8019AEC4 L1529-1536
function shape_helper.Unknown8019AEC4(a0: number): GdTypesH.ObjGroup
	error("stale")
end

-- from src/goddard/shape_helper.c:unusedAnim1 L38-38
shape_helper.unusedAnim1 = {
	count = IncludeMacrosH.ARRAY_COUNT(shape_helper.unusedAnimData1),
	type_ = GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F_2,
	data = shape_helper.unusedAnimData1,
}

-- from src/goddard/shape_helper.c:unusedAnim2 L44-44
shape_helper.unusedAnim2 = {
	count = IncludeMacrosH.ARRAY_COUNT(shape_helper.unusedAnimData2),
	type_ = GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F_2,
	data = shape_helper.unusedAnimData2,
}

-- from src/goddard/shape_helper.c:unusedAnim3 L50-50
shape_helper.unusedAnim3 = {
	count = IncludeMacrosH.ARRAY_COUNT(shape_helper.unusedAnimData3),
	type_ = GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F_2,
	data = shape_helper.unusedAnimData3,
}

-- from src/goddard/shape_helper.c:sSimpleDylist L55-64
shape_helper.sSimpleDylist = {
	DynlistsDynlistMacrosH.BeginList(),
	DynlistsDynlistMacrosH.StartGroup("simpleg"),
	DynlistsDynlistMacrosH.MakeDynObj(DynlistProcH.D_NET, "simple"),
	DynlistsDynlistMacrosH.SetType(3),
	DynlistsDynlistMacrosH.SetShapePtrPtr({ Base = shape_helper, Key = "sSimpleShape" }),
	DynlistsDynlistMacrosH.EndGroup("simpleg"),
	DynlistsDynlistMacrosH.UseObj("simpleg"),
	DynlistsDynlistMacrosH.EndList(),
}

-- from src/goddard/shape_helper.c:sDynlist801A85B3 L70-73
shape_helper.sDynlist801A85B3 = {
	DynlistsDynlistMacrosH.BeginList(),
	DynlistsDynlistMacrosH.CallList(shape_helper.sDynlist801A84E4),
	DynlistsDynlistMacrosH.SetFlag(0x400),
	DynlistsDynlistMacrosH.SetFriction(0.04, 0.01, 0.01),
	DynlistsDynlistMacrosH.EndList(),
}

-- from src/goddard/shape_helper.c:sDynlist801A85A4 L74-79
shape_helper.sDynlist801A85A4 = {
	DynlistsDynlistMacrosH.BeginList(),
	DynlistsDynlistMacrosH.CallList(shape_helper.sDynlist801A84E4),
	DynlistsDynlistMacrosH.SetFriction(0.04, 0.01, 0.01),
	DynlistsDynlistMacrosH.EndList(),
}

-- from src/goddard/shape_helper.c:sDynlist801A8604 L80-85
shape_helper.sDynlist801A8604 = {
	DynlistsDynlistMacrosH.BeginList(),
	DynlistsDynlistMacrosH.CallList(shape_helper.sDynlist801A84E4),
	DynlistsDynlistMacrosH.SetFriction(0.005, 0.005, 0.005),
	DynlistsDynlistMacrosH.EndList(),
}

return shape_helper
