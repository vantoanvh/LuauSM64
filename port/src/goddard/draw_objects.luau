--!strict
--!optimize 2

--[[
	Port of src/goddard/draw_objects.c.
]]

const GdTypesH = require("./gd_types_h")
const GdMath = require("./gd_math")
const Registry = require("../../groups/registry")
const DebugUtils = require("./debug_utils")
const Gbi = require("../rom/gbi")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const RendererH = require("./renderer_h")
const DrawObjectsH = require("./draw_objects_h")
const GdMain = require("./gd_main")

-- from src/goddard/draw_objects.c:BetaVtx
export type BetaVtx = {
	filler: buffer, -- [68]
	s: number,
	t: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/goddard/draw_objects.luau:scratch
const Scratch = {
	calc_vtx_normal_particle = { x = 0, y = 0, z = 0 },
	draw_shape_sp1C = { x = 0, y = 0, z = 0 },
	draw_shape_2d_sp1C = { x = 0, y = 0, z = 0 },
	draw_light_sp54 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
	draw_light_sp94 = { x = 0, y = 0, z = 0 },
	draw_camera_sp44 = { x = 0, y = 0, z = 0 },
	check_grabbable_click_objPos = { x = 0, y = 0, z = 0 },
	update_view_objTypeAbbr = buffer.create(0x100),
}

-- from src/goddard/draw_objects.c:data
const draw_objects = {
	RENDER_SCENE = 26,
	FIND_PICKS = 27,
	-- from src/goddard/draw_objects.c:sClrWhite L53-53
	sClrWhite = { r = 1.0, g = 1.0, b = 1.0 },
	-- from src/goddard/draw_objects.c:sClrRed L54-54
	sClrRed = { r = 1.0, g = 0.0, b = 0.0 },
	-- from src/goddard/draw_objects.c:sClrGreen L55-55
	sClrGreen = { r = 0.0, g = 1.0, b = 0.0 },
	-- from src/goddard/draw_objects.c:sClrBlue L56-56
	sClrBlue = { r = 0.0, g = 0.0, b = 1.0 },
	-- from src/goddard/draw_objects.c:sClrErrDarkBlue L57-57
	sClrErrDarkBlue = { r = 0.0, g = 0.0, b = 6.0 },
	-- from src/goddard/draw_objects.c:sClrPink L58-58
	sClrPink = { r = 1.0, g = 0.0, b = 1.0 },
	-- from src/goddard/draw_objects.c:sClrBlack L59-59
	sClrBlack = { r = 0.0, g = 0.0, b = 0.0 },
	-- from src/goddard/draw_objects.c:sClrGrey L60-60
	sClrGrey = { r = 0.6000000238418579, g = 0.6000000238418579, b = 0.6000000238418579 },
	-- from src/goddard/draw_objects.c:sClrDarkGrey L61-61
	sClrDarkGrey = { r = 0.4000000059604645, g = 0.4000000059604645, b = 0.4000000059604645 },
	-- from src/goddard/draw_objects.c:sClrYellow L62-62
	sClrYellow = { r = 1.0, g = 1.0, b = 0.0 },
	-- from src/goddard/draw_objects.c:sLightColours L63-63
	sLightColours = { { r = 1.0, g = 1.0, b = 0.0 } },
	-- from src/goddard/draw_objects.c:gViewUpdateCamera L65-65
	gViewUpdateCamera = nil :: GdTypesH.ObjCamera?,
	-- from src/goddard/draw_objects.c:sUnref801A80FC L66-66
	sUnref801A80FC = nil,
	-- from src/goddard/draw_objects.c:sUnreadShapeFlag L67-67
	sUnreadShapeFlag = 0,
	-- from src/goddard/draw_objects.c:sUnref801A8120 L76-78
	sUnref801A8120 = { { 1.0, 0.0, 0.0, 0.0 }, { 0.0, 0.0, 0.0, 0.0 }, { 0.0, 0.0, 1.0, 0.0 }, { 0.0, 0.0, 0.0, 1.0 } },
	-- from src/goddard/draw_objects.c:sUnrefIden801A8160 L79-81
	sUnrefIden801A8160 = { { 1.0, 0.0, 0.0, 0.0 }, { 0.0, 1.0, 0.0, 0.0 }, { 0.0, 0.0, 1.0, 0.0 }, { 0.0, 0.0, 0.0, 1.0 } },
	-- from src/goddard/draw_objects.c:sLightDlCounter L82-82
	sLightDlCounter = 1,
	-- from src/goddard/draw_objects.c:sUnref801A81A4 L83-83
	sUnref801A81A4 = { 0, 0, 0, 0 },
	-- from src/goddard/draw_objects.c:gUnref_801B9B30 L86-86
	gUnref_801B9B30 = buffer.create(136),
	-- from src/goddard/draw_objects.c:gGdLightGroup L87-87
	gGdLightGroup = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/draw_objects.c:sUnref_801B9BBC L89-89
	sUnref_801B9BBC = buffer.create(64),
	-- from src/goddard/draw_objects.c:sSceneProcessType L90-90
	sSceneProcessType = 0,
	-- from src/goddard/draw_objects.c:sUseSelectedColor L91-91
	sUseSelectedColor = 0,
	-- from src/goddard/draw_objects.c:sPickBuffer L92-92
	sPickBuffer = table.create(100, 0),
	-- from src/goddard/draw_objects.c:sPickDataTemp L93-93
	sPickDataTemp = 0,
	-- from src/goddard/draw_objects.c:sPickObjDistance L94-94
	sPickObjDistance = 0,
	-- from src/goddard/draw_objects.c:sPickedObject L95-95
	sPickedObject = nil :: GdTypesH.GdObj?,
	-- from src/goddard/draw_objects.c:sUpdateViewState L97-104
	sUpdateViewState = {
		filler1 = buffer.create(4),
		view = nil :: GdTypesH.ObjView?,
		unreadCounter = 0,
		mtlDlNum = 0,
		shapesDrawn = 0,
		unused = 0,
	},
	-- from src/goddard/draw_objects.c:sPhongLight L105-105
	sPhongLight = nil :: GdTypesH.ObjLight?,
	-- from src/goddard/draw_objects.c:sPhongLightPosition L106-106
	sPhongLightPosition = { x = 0, y = 0, z = 0 },
	-- from src/goddard/draw_objects.c:sLightPositionOffset L108-108
	sLightPositionOffset = { x = 0, y = 0, z = 0 },
	-- from src/goddard/draw_objects.c:sLightPositionCache L109-109
	sLightPositionCache = {
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
	},
	-- from src/goddard/draw_objects.c:sNumActiveLights L110-110
	sNumActiveLights = 0,
	-- from src/goddard/draw_objects.c:sGrabCords L111-111
	sGrabCords = { x = 0, y = 0, z = 0 },
}

-- from src/goddard/draw_objects.c:BetaVtx (zero-filled constructor)
function draw_objects.new_BetaVtx(): BetaVtx
	return { filler = buffer.create(68), s = 0, t = 0 } :: BetaVtx
end

-- from src/goddard/draw_objects.c:setup_lights L116-127
function draw_objects.setup_lights()
	Registry.Members.src__goddard__renderer.set_light_num(Gbi.NUMLIGHTS_2)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_AMB_COLOUR, 0.5, 0.5, 0.5)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_CULLING, 1.0, 0.0, 0.0)

	if true then
		return
	end

	-- dead code
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_STUB17, 2.0, 0.0, 0.0)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_ZBUF_FN, 24.0, 0.0, 0.0)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_CULLING, 1.0, 0.0, 0.0)
end

-- from src/goddard/draw_objects.c:Unknown801781DC L132-167
function draw_objects.Unknown801781DC(zone: GdTypesH.ObjZone)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_shape L170-247
function draw_objects.draw_shape(shape: GdTypesH.ObjShape?, flag: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number, n: number, colorIdx: number, rotMtx: { { number } }?)
	c = F32(c)
	d = F32(d)
	e = F32(e)
	f = F32(f)
	g = F32(g)
	h = F32(h)
	i = F32(i)
	j = F32(j)
	k = F32(k)
	l = F32(l)
	m = F32(m)
	n = F32(n)
	draw_objects.sUpdateViewState.shapesDrawn += 1

	if shape == nil then
		return
	end

	const sp1C = Scratch.draw_shape_sp1C

	sp1C.x = 0.0
	sp1C.y = 0.0
	sp1C.z = 0.0

	if bit32.btest(flag, 2) then
		Registry.Members.src__goddard__renderer.gd_dl_load_trans_matrix(f, g, h)
		sp1C.x = F32(sp1C.x + f)
		sp1C.y = F32(sp1C.y + g)
		sp1C.z = F32(sp1C.z + h)
	end

	if bit32.btest(flag, 0x10) and rotMtx ~= nil then
		Registry.Members.src__goddard__renderer.gd_dl_load_matrix(rotMtx)
		sp1C.x = F32(sp1C.x + rotMtx[4][1])
		sp1C.y = F32(sp1C.y + rotMtx[4][2])
		sp1C.z = F32(sp1C.z + rotMtx[4][3])
	end

	if bit32.btest(flag, 8) then
		if m ~= 0.0 then
			Registry.Members.src__goddard__renderer.func_8019F2C4(m, 121)
		end

		if l ~= 0.0 then
			Registry.Members.src__goddard__renderer.func_8019F2C4(l, 120)
		end

		if n ~= 0.0 then
			Registry.Members.src__goddard__renderer.func_8019F2C4(n, 122)
		end
	end

	if colorIdx ~= 0 then
		draw_objects.sUseSelectedColor = IncludePRUltratypesH.TRUE

		const selectedColour = draw_objects.gd_get_colour(colorIdx)

		draw_objects.sSelectedColour = selectedColour

		if selectedColour ~= nil then
			Registry.Members.src__goddard__renderer.gd_dl_material_lighting(-1, selectedColour, GdTypesH.GD_MTL_LIGHTS)
		else
			DebugUtils.fatal_print("Draw_shape(): Bad colour")
		end
	else
		draw_objects.sUseSelectedColor = IncludePRUltratypesH.FALSE
		draw_objects.sSelectedColour = nil
	end

	if draw_objects.sNumActiveLights ~= 0 and shape.mtlGroup ~= nil then
		if rotMtx ~= nil then
			sp1C.x = rotMtx[4][1]
			sp1C.y = rotMtx[4][2]
			sp1C.z = rotMtx[4][3]
		else
			sp1C.x = 0.0
			sp1C.y = 0.0
			sp1C.z = 0.0
		end

		draw_objects.update_shaders(shape, sp1C)
	end

	if bit32.btest(flag, 4) then
		Registry.Members.src__goddard__renderer.gd_dl_mul_trans_matrix(i, j, k)
	end

	if bit32.btest(flag, 1) then
		Registry.Members.src__goddard__renderer.gd_dl_scale(c, d, e)
	end

	draw_objects.draw_shape_faces(shape)
	draw_objects.sUseSelectedColor = IncludePRUltratypesH.FALSE
end

-- from src/goddard/draw_objects.c:draw_shape_2d L249-273
function draw_objects.draw_shape_2d(shape: GdTypesH.ObjShape?, flag: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number, n: number, color: number, p: number)
	f = F32(f)
	g = F32(g)
	h = F32(h)
	draw_objects.sUpdateViewState.shapesDrawn += 1

	if shape == nil then
		return
	end

	if bit32.btest(flag, 2) then
		const sp1C = Scratch.draw_shape_2d_sp1C

		sp1C.x = f
		sp1C.y = g
		sp1C.z = h

		const camera = draw_objects.gViewUpdateCamera

		if camera ~= nil then
			GdMath.gd_rotate_and_translate_vec3f(sp1C, camera.unkE8)
		end

		Registry.Members.src__goddard__renderer.gd_dl_load_trans_matrix(sp1C.x, sp1C.y, sp1C.z)
	end

	draw_objects.draw_shape_faces(shape)
end

-- from src/goddard/draw_objects.c:draw_light L275-311
function draw_objects.draw_light(light: GdTypesH.ObjLight)
	if draw_objects.sSceneProcessType == draw_objects.FIND_PICKS then
		return
	end

	const lightColour = draw_objects.sLightColours[1]

	lightColour.r = light.colour.r
	lightColour.g = light.colour.g
	lightColour.b = light.colour.b

	local shape: GdTypesH.ObjShape

	if bit32.btest(light.flags, GdTypesH.LIGHT_UNK02) then
		const sp54 = Scratch.draw_light_sp54
		const sp94 = Scratch.draw_light_sp94

		GdMath.gd_set_identity_mat4(sp54)
		sp94.x = -light.unk80.x
		sp94.y = -light.unk80.y
		sp94.z = -light.unk80.z
		GdMath.gd_create_origin_lookat(sp54, sp94, 0.0)

		const spotShape: GdTypesH.ObjShape = Registry.Members.src__goddard__shape_helper.gSpotShape

		shape = spotShape
	else
		shape = light.unk9C :: GdTypesH.ObjShape
		draw_objects.sLightDlCounter += 1

		if draw_objects.sLightDlCounter >= 17 then
			draw_objects.sLightDlCounter = 1
		end

		shape.unk50 = draw_objects.sLightDlCounter
	end

	draw_objects.draw_shape_2d(shape, 2, 1.0, 1.0, 1.0, light.position.x, light.position.y, light.position.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1, 0)
end

-- from src/goddard/draw_objects.c:draw_material L313-333
function draw_objects.draw_material(mtl: GdTypesH.ObjMaterial)
	local mtlType = mtl.ObjMaterial_type

	if mtlType == GdTypesH.GD_MTL_SHINE_DL then
		const phongLight = draw_objects.sPhongLight

		if phongLight ~= nil and phongLight.unk30 > 0.0 then
			const camera = draw_objects.gViewUpdateCamera

			if camera ~= nil then
				Registry.Members.src__goddard__renderer.gd_dl_hilite(mtl.gddlNumber, camera, phongLight.position, draw_objects.sLightPositionOffset, draw_objects.sPhongLightPosition, phongLight.colour)
			else
				DebugUtils.fatal_printf("draw_material() no active camera for phong")
			end
		else
			mtlType = GdTypesH.GD_MTL_BREAK
		end
	end

	if draw_objects.sUseSelectedColor == IncludePRUltratypesH.FALSE then
		Registry.Members.src__goddard__renderer.gd_dl_material_lighting(mtl.gddlNumber, mtl.Kd, mtlType)
	else
		Registry.Members.src__goddard__renderer.gd_dl_material_lighting(mtl.gddlNumber, draw_objects.sSelectedColour :: GdTypesH.GdColour, GdTypesH.GD_MTL_LIGHTS)
	end
end

-- from src/goddard/draw_objects.c:create_mtl_gddl_if_empty L339-343
function draw_objects.create_mtl_gddl_if_empty(mtl: GdTypesH.ObjMaterial)
	if mtl.gddlNumber == 0 then
		const gddlNumber: number = Registry.Members.src__goddard__renderer.create_mtl_gddl(mtl.ObjMaterial_type)

		mtl.gddlNumber = gddlNumber
	end
end

-- from src/goddard/draw_objects.c:check_face_bad_vtx L350-365
function draw_objects.check_face_bad_vtx(face: GdTypesH.ObjFace)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:gd_get_colour L380-421
function draw_objects.gd_get_colour(idx: number): GdTypesH.GdColour?
	error("stale")
end

-- from src/goddard/draw_objects.c:Unknown80178ECC L427-433
function draw_objects.Unknown80178ECC(v0X: number, v0Y: number, v0Z: number, v1X: number, v1Y: number, v1Z: number)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_face L439-495
function draw_objects.draw_face(face: GdTypesH.ObjFace)
	const hasTextCoords = IncludePRUltratypesH.FALSE

	if draw_objects.sUseSelectedColor == IncludePRUltratypesH.FALSE and face.mtlId >= 0 then
		if face.mtl ~= nil then
			const gddlNumber = face.mtl.gddlNumber

			if gddlNumber ~= 0 then
				if gddlNumber ~= draw_objects.sUpdateViewState.mtlDlNum then
					Registry.Members.src__goddard__renderer.gd_dl_flush_vertices()
					Registry.Members.src__goddard__renderer.branch_to_gddl(gddlNumber)
					draw_objects.sUpdateViewState.mtlDlNum = gddlNumber
				end
			end
		end
	end

	Registry.Members.src__goddard__renderer.check_tri_display(face.vtxCount)

	if GdMain.gGdUseVtxNormal == 0 then
		Registry.Members.src__goddard__renderer.set_Vtx_norm_buf_1(face.normal)
	end

	for i = 0, face.vtxCount - 1 do
		const vtx = face.vertices[i + 1] :: GdTypesH.ObjVertex
		const x = vtx.pos.x
		const y = vtx.pos.y
		const z = vtx.pos.z

		if GdMain.gGdUseVtxNormal ~= 0 then
			Registry.Members.src__goddard__renderer.set_Vtx_norm_buf_2(vtx.normal)
		end

		if hasTextCoords ~= 0 then
			const betaVtx = (vtx :: unknown) :: BetaVtx

			Registry.Members.src__goddard__renderer.set_vtx_tc_buf(betaVtx.s, betaVtx.t)
		end

		const gbiVtx: number? = Registry.Members.src__goddard__renderer.gd_dl_make_vertex(x, y, z, vtx.alpha)

		if gbiVtx ~= nil then
			const vtxLink: GdTypesH.VtxLink = Registry.Members.src__goddard__objects.make_vtx_link(vtx.gbiVerts, gbiVtx)

			vtx.gbiVerts = vtxLink
		end
	end

	Registry.Members.src__goddard__renderer.func_8019FEF0()
end

-- from src/goddard/draw_objects.c:draw_rect_fill L504-507
function draw_objects.draw_rect_fill(color: number, ulx: number, uly: number, lrx: number, lry: number)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_rect_stroke L516-519
function draw_objects.draw_rect_stroke(color: number, ulx: number, uly: number, lrx: number, lry: number)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:Unknown801792F0 L525-534
function draw_objects.Unknown801792F0(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_label L539-594
function draw_objects.draw_label(label: GdTypesH.ObjLabel)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_net L597-620
function draw_objects.draw_net(self: GdTypesH.ObjNet)
	if draw_objects.sSceneProcessType == draw_objects.FIND_PICKS then
		return
	end

	const net = self
	local netColor: number

	if bit32.btest(net.header.drawFlags, GdTypesH.OBJ_HIGHLIGHTED) then
		netColor = DrawObjectsH.COLOUR_YELLOW
	else
		netColor = net.colourNum
	end

	if net.shapePtr ~= nil then
		draw_objects.draw_shape(net.shapePtr, 0x10, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, netColor, net.mat168)
	end

	if net.unk1C8 ~= nil then
		draw_objects.draw_group(net.unk1C8)
	end
end

-- from src/goddard/draw_objects.c:draw_gadget L625-646
function draw_objects.draw_gadget(gdgt: GdTypesH.ObjGadget)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_camera L649-679
function draw_objects.draw_camera(cam: GdTypesH.ObjCamera)
	const sp44 = Scratch.draw_camera_sp44

	sp44.x = 0.0
	sp44.y = 0.0
	sp44.z = 0.0

	if cam.unk30 ~= nil then
		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(cam.unk30)
		Registry.Members.src__goddard__dynlist_proc.d_get_world_pos(sp44)
		sp44.x = F32(sp44.x + cam.lookAt.x)
		sp44.y = F32(sp44.y + cam.lookAt.y)
		sp44.z = F32(sp44.z + cam.lookAt.z)
	else
		sp44.x = cam.lookAt.x
		sp44.y = cam.lookAt.y
		sp44.z = cam.lookAt.z
	end

	if F32(math.abs(F32(cam.worldPos.x - sp44.x)) + math.abs(F32(cam.worldPos.z - sp44.z))) == 0.0 then
		-- gd_printf("Draw_Camera(): Zero view distance\n") is dropped
		return
	end

	Registry.Members.src__goddard__renderer.gd_dl_lookat(cam, cam.worldPos.x, cam.worldPos.y, cam.worldPos.z, sp44.x, sp44.y, sp44.z, cam.unkA4)
end

-- from src/goddard/draw_objects.c:Unknown80179ACC L687-698
function draw_objects.Unknown80179ACC(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:func_80179B64 L704-708
function draw_objects.func_80179B64(group: GdTypesH.ObjGroup)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:world_pos_to_screen_coords L711-721
function draw_objects.world_pos_to_screen_coords(pos: GdTypesH.GdVec3f, cam: GdTypesH.ObjCamera, view: GdTypesH.ObjView)
	GdMath.gd_rotate_and_translate_vec3f(pos, cam.unkE8)

	if pos.z > -256.0 then
		return
	end

	pos.x = F32(pos.x * (256.0 / -pos.z))
	pos.y = F32(pos.y * (256.0 / pos.z))
	pos.x = F32(pos.x + F32(view.lowerRight.x / 2.0))
	pos.y = F32(pos.y + F32(view.lowerRight.y / 2.0))
end

-- from src/goddard/draw_objects.c:check_grabbable_click L734-764
function draw_objects.check_grabbable_click(input: GdTypesH.GdObj)
	const camera = draw_objects.gViewUpdateCamera

	if camera == nil then
		return
	end

	const obj = input

	if not bit32.btest(obj.drawFlags, GdTypesH.OBJ_IS_GRABBABLE) then
		return
	end

	Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(obj)

	const mtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()
	const objPos = Scratch.check_grabbable_click_objPos

	objPos.x = mtx[4][1]
	objPos.y = mtx[4][2]
	objPos.z = mtx[4][3]
	draw_objects.world_pos_to_screen_coords(objPos, camera, draw_objects.sUpdateViewState.view :: GdTypesH.ObjView)

	if math.abs(F32(GdMain.gGdCtrl.csrX - objPos.x)) < 20.0 then
		if math.abs(F32(GdMain.gGdCtrl.csrY - objPos.y)) < 20.0 then
			-- store (size, Obj Type, Obj Index) in s16 pick buffer array
			Registry.Members.src__goddard__renderer.store_in_pickbuf(2)
			Registry.Members.src__goddard__renderer.store_in_pickbuf(obj.type_)
			Registry.Members.src__goddard__renderer.store_in_pickbuf(obj.index)
			draw_objects.sGrabCords.x = objPos.x
			draw_objects.sGrabCords.y = objPos.y
		end
	end
end

-- from src/goddard/draw_objects.c:drawscene L778-841
function draw_objects.drawscene(process: number, interactables: GdTypesH.ObjGroup, lightgrp: GdTypesH.ObjGroup?)
	const view = draw_objects.sUpdateViewState.view :: GdTypesH.ObjView

	draw_objects.sUnreadShapeFlag = 0
	draw_objects.sUpdateViewState.unreadCounter = 0
	Registry.Members.src__goddard__renderer.set_gd_mtx_parameters(bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))

	if view.projectionType == 1 then
		Registry.Members.src__goddard__renderer.gd_create_perspective_matrix(view.clipping.z, F32(view.lowerRight.x / view.lowerRight.y), view.clipping.x, view.clipping.y)
	else
		Registry.Members.src__goddard__renderer.gd_create_ortho_matrix(-view.lowerRight.x / 2.0, view.lowerRight.x / 2.0, -view.lowerRight.y / 2.0, view.lowerRight.y / 2.0, view.clipping.x, view.clipping.y)
	end

	if lightgrp ~= nil then
		Registry.Members.src__goddard__renderer.set_gd_mtx_parameters(bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_PUSH))
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(bit32.bor(GdTypesH.OBJ_TYPE_LIGHTS, GdTypesH.OBJ_TYPE_PARTICLES), draw_objects.apply_obj_draw_fn, lightgrp)
		Registry.Members.src__goddard__renderer.set_gd_mtx_parameters(bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	end

	if draw_objects.gViewUpdateCamera ~= nil then
		draw_objects.draw_camera(draw_objects.gViewUpdateCamera)
	else
		Registry.Members.src__goddard__renderer.gd_dl_mul_trans_matrix(0.0, 0.0, -1000.0)
	end

	draw_objects.setup_lights()
	Registry.Members.src__goddard__renderer.set_gd_mtx_parameters(bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_PUSH))
	Registry.Members.src__goddard__renderer.gd_dl_push_matrix()
	draw_objects.sSceneProcessType = process
	draw_objects.sNumActiveLights = S32(bit32.band(view.flags, GdTypesH.VIEW_LIGHT))

	if draw_objects.sNumActiveLights ~= 0 then
		view.flags = S32(bit32.band(view.flags, bit32.bnot(GdTypesH.VIEW_LIGHT)))
	end

	draw_objects.sNumActiveLights = 1
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_LIGHTS, draw_objects.register_light, draw_objects.gGdLightGroup)

	if draw_objects.sSceneProcessType == draw_objects.FIND_PICKS then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, draw_objects.check_grabbable_click, interactables)
	else
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(bit32.bor(GdTypesH.OBJ_TYPE_LIGHTS, GdTypesH.OBJ_TYPE_GADGETS, GdTypesH.OBJ_TYPE_NETS, GdTypesH.OBJ_TYPE_PARTICLES), draw_objects.apply_obj_draw_fn, interactables)
	end

	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_LIGHTING, 0.0, 0.0, 0.0)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_LABELS, draw_objects.apply_obj_draw_fn, interactables)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_LIGHTING, 1.0, 0.0, 0.0)
	Registry.Members.src__goddard__renderer.gd_dl_pop_matrix()
end

-- from src/goddard/draw_objects.c:draw_nothing L847-848
function draw_objects.draw_nothing(nop: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_shape_faces L855-868
function draw_objects.draw_shape_faces(shape: GdTypesH.ObjShape)
	draw_objects.sUpdateViewState.mtlDlNum = 0
	draw_objects.sUpdateViewState.unreadCounter = 0
	Registry.Members.src__goddard__renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
	draw_objects.sUnreadShapeFlag = S32(bit32.band(shape.flag, 1))
	Registry.Members.src__goddard__renderer.set_render_alpha(shape.alpha)

	const frameBufNum: number = Registry.Members.src__goddard__renderer.gGdFrameBufNum

	if shape.dlNums[frameBufNum + 1] ~= 0 then
		Registry.Members.src__goddard__renderer.draw_indexed_dl(shape.dlNums[frameBufNum + 1], shape.unk50)
	elseif shape.faceGroup ~= nil then
		Registry.Members.src__goddard__renderer.func_801A0038()
		draw_objects.draw_group(shape.faceGroup)
		Registry.Members.src__goddard__renderer.gd_dl_flush_vertices()
	end
end

-- from src/goddard/draw_objects.c:draw_particle L873-905
function draw_objects.draw_particle(obj: GdTypesH.GdObj)
	const ptc = (obj :: unknown) :: GdTypesH.ObjParticle
	const lightColour = draw_objects.sLightColours[1]

	if ptc.timeout > 0 then
		const white = draw_objects.sColourPalette[1] :: GdTypesH.GdColour
		const black = draw_objects.sWhiteBlack[2] :: GdTypesH.GdColour
		const brightness = F32(ptc.timeout / 10.0)

		lightColour.r = F32(F32(F32(white.r - black.r) * brightness) + black.r)
		lightColour.g = F32(F32(F32(white.g - black.g) * brightness) + black.g)
		lightColour.b = F32(F32(F32(white.b - black.b) * brightness) + black.b)
	else
		lightColour.r = 0.0
		lightColour.g = 0.0
		lightColour.b = 0.0
	end

	if ptc.timeout > 0 then
		const shape = ptc.shapePtr :: GdTypesH.ObjShape

		shape.unk50 = ptc.timeout
		draw_objects.draw_shape_2d(shape, 2, 1.0, 1.0, 1.0, ptc.pos.x, ptc.pos.y, ptc.pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1, 0)
	end

	if ptc.unk60 == 3 then
		if ptc.subParticlesGrp ~= nil then
			draw_objects.draw_group(ptc.subParticlesGrp)
		end
	end
end

-- from src/goddard/draw_objects.c:draw_bone L913-939
function draw_objects.draw_bone(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_joint L944-967
function draw_objects.draw_joint(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:draw_group L975-981
function draw_objects.draw_group(grp: GdTypesH.ObjGroup?)
	if grp == nil then
		DebugUtils.fatal_print("Draw_Group: Bad group definition!")
	end

	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, draw_objects.apply_obj_draw_fn, grp)
end

-- from src/goddard/draw_objects.c:draw_plane L986-996
function draw_objects.draw_plane(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:apply_obj_draw_fn L1004-1013
function draw_objects.apply_obj_draw_fn(obj: GdTypesH.GdObj?)
	if obj == nil then
		DebugUtils.fatal_print("Bad object!")
	end

	const drawObj = obj :: GdTypesH.GdObj

	if bit32.btest(drawObj.drawFlags, GdTypesH.OBJ_INVISIBLE) then
		return
	end

	const drawFn = (drawObj.objDrawFn :: unknown) :: (GdTypesH.GdObj) -> ()

	drawFn(drawObj)
end

-- from src/goddard/draw_objects.c:register_light L1018-1025
function draw_objects.register_light(light: GdTypesH.ObjLight)
	Registry.Members.src__goddard__renderer.set_light_id(light.id)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_LIGHTING, 2.0, 0.0, 0.0)

	if bit32.btest(light.flags, GdTypesH.LIGHT_NEW_UNCOUNTED) then
		draw_objects.sNumActiveLights += 1
	end

	light.flags = S32(bit32.band(light.flags, bit32.bnot(GdTypesH.LIGHT_NEW_UNCOUNTED)))
end

-- from src/goddard/draw_objects.c:Proc8017A980 L1028-1068
function draw_objects.Proc8017A980(light: GdTypesH.ObjLight)
	const lightPosition = draw_objects.sLightPositionCache[light.id + 1]

	light.colour.r = F32(light.diffuse.r * light.unk30)
	light.colour.g = F32(light.diffuse.g * light.unk30)
	light.colour.b = F32(light.diffuse.b * light.unk30)
	lightPosition.x = F32(light.position.x - draw_objects.sLightPositionOffset.x)
	lightPosition.y = F32(light.position.y - draw_objects.sLightPositionOffset.y)
	lightPosition.z = F32(light.position.z - draw_objects.sLightPositionOffset.z)
	GdMath.gd_normalize_vec3f(lightPosition)

	if bit32.btest(light.flags, GdTypesH.LIGHT_UNK20) then
		draw_objects.sPhongLightPosition.x = lightPosition.x
		draw_objects.sPhongLightPosition.y = lightPosition.y
		draw_objects.sPhongLightPosition.z = lightPosition.z
		draw_objects.sPhongLight = light
	end

	local sp24 = light.unk30

	if bit32.btest(light.flags, GdTypesH.LIGHT_UNK02) then
		local sp20 = -GdMath.gd_dot_vec3f(lightPosition, light.unk80)
		const sp1C = F32(1.0 - light.unk38 / 90.0)

		if sp20 > sp1C then
			sp20 = F32(F32(sp20 - sp1C) * (1.0 / (1.0 - sp1C)))

			if sp20 > 1.0 then
				sp20 = 1.0
			elseif sp20 < 0.0 then
				sp20 = 0.0
			end
		else
			sp20 = 0.0
		end

		sp24 = F32(sp24 * sp20)
	end

	Registry.Members.src__goddard__renderer.set_light_id(light.id)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_DIFUSE_COLOUR, F32(light.diffuse.r * sp24), F32(light.diffuse.g * sp24), F32(light.diffuse.b * sp24))
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_LIGHT_DIR, lightPosition.x, lightPosition.y, lightPosition.z)
	Registry.Members.src__goddard__renderer.gd_setproperty(RendererH.GD_PROP_LIGHTING, 2.0, 0.0, 0.0)
end

-- from src/goddard/draw_objects.c:update_shaders L1071-1087
function draw_objects.update_shaders(shape: GdTypesH.ObjShape, offset: GdTypesH.GdVec3f)
	Registry.Members.src__goddard__renderer.stash_current_gddl()
	draw_objects.sLightPositionOffset.x = offset.x
	draw_objects.sLightPositionOffset.y = offset.y
	draw_objects.sLightPositionOffset.z = offset.z
	draw_objects.sPhongLight = nil

	if draw_objects.gGdLightGroup ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_LIGHTS, draw_objects.Proc8017A980, draw_objects.gGdLightGroup)
	end

	if shape.mtlGroup ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_MATERIALS, draw_objects.apply_obj_draw_fn, shape.mtlGroup)
	end

	Registry.Members.src__goddard__renderer.pop_gddl_stash()
end

-- from src/goddard/draw_objects.c:create_shape_mtl_gddls L1096-1101
function draw_objects.create_shape_mtl_gddls(shape: GdTypesH.ObjShape)
	if shape.mtlGroup ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_MATERIALS, draw_objects.create_mtl_gddl_if_empty, shape.mtlGroup)
	end
end

-- from src/goddard/draw_objects.c:unref_8017AEDC L1111-1120
function draw_objects.unref_8017AEDC(grp: GdTypesH.ObjGroup)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:create_shape_gddl L1133-1166
function draw_objects.create_shape_gddl(s: GdTypesH.ObjShape)
	const shape = s

	draw_objects.create_shape_mtl_gddls(shape)

	const shapedl: number = Registry.Members.src__goddard__renderer.gd_startdisplist(7)

	if shapedl == 0 then
		return
	end

	draw_objects.setup_lights()
	draw_objects.sUseSelectedColor = IncludePRUltratypesH.FALSE

	if shape.unk3C == 0 then
		draw_objects.draw_shape_faces(shape)
	end

	Registry.Members.src__goddard__renderer.gd_enddlsplist_parent()
	shape.dlNums[1] = shapedl
	shape.dlNums[2] = shapedl

	if buffer.readu8(shape.name, 0) ~= 0 then
		-- printf("Generated '%s' (%d) display list ok.(%d)\n") is dropped
	else
		-- printf("Generated 'UNKNOWN' (%d) display list ok.(%d)\n") is dropped
	end
end

-- from src/goddard/draw_objects.c:create_gddl_for_shapes L1176-1180
function draw_objects.create_gddl_for_shapes(grp: GdTypesH.ObjGroup)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_SHAPES, draw_objects.create_shape_gddl, grp)
end

-- from src/goddard/draw_objects.c:map_face_materials L1190-1216
function draw_objects.map_face_materials(faces: GdTypesH.ObjGroup, mtls: GdTypesH.ObjGroup)
	local linkFaces: GdTypesH.ListNode? = faces.firstMember

	while linkFaces ~= nil do
		const face = linkFaces.obj :: GdTypesH.ObjFace
		local linkMtls: GdTypesH.ListNode? = mtls.firstMember
		local mtl: GdTypesH.ObjMaterial? = nil

		while linkMtls ~= nil do
			mtl = linkMtls.obj :: GdTypesH.ObjMaterial
			if mtl.id == face.mtlId then
				break
			end

			linkMtls = linkMtls.next
		end

		if linkMtls ~= nil then
			face.mtl = mtl
		end

		linkFaces = linkFaces.next
	end
end

-- from src/goddard/draw_objects.c:calc_vtx_normal L1229-1256
function draw_objects.calc_vtx_normal(vtx: GdTypesH.ObjVertex, facegrp: GdTypesH.ObjGroup)
	const particle = vtx.type_ == GdTypesH.OBJ_TYPE_PARTICLES
	const normal = if particle then Scratch.calc_vtx_normal_particle else vtx.normal

	normal.x = 0.0
	normal.y = 0.0
	normal.z = 0.0

	local faceCount = 0
	local node: GdTypesH.ListNode? = facegrp.firstMember

	while node ~= nil do
		const curFace = node.obj :: GdTypesH.ObjFace

		for i = 1, curFace.vtxCount do
			if curFace.vertices[i] == vtx then
				normal.x = F32(normal.x + curFace.normal.x)
				normal.y = F32(normal.y + curFace.normal.y)
				normal.z = F32(normal.z + curFace.normal.z)
				faceCount += 1
			end
		end

		node = node.next
	end

	if faceCount ~= 0 then
		normal.x = F32(normal.x / F32(faceCount))
		normal.y = F32(normal.y / F32(faceCount))
		normal.z = F32(normal.z / F32(faceCount))
	end

	if particle then
		-- The C vertex cast places the three components over the particle's 0x2C, 0x30 and 0x34 fields.
		const particleVertex = (vtx :: unknown) :: GdTypesH.ObjParticle

		buffer.writef32(particleVertex.filler2, 0, normal.x)
		particleVertex.unk30 = normal.y
		buffer.writef32(particleVertex.filler3, 0, normal.z)
	end
end

-- from src/goddard/draw_objects.c:find_thisface_verts L1270-1295
function draw_objects.find_thisface_verts(face: GdTypesH.ObjFace, vertexGrp: GdTypesH.ObjGroup)
	for i = 1, face.vtxCount do
		-- During mapping, the face's slots hold indices in place of vertex records.
		const vertexIndex = (face.vertices[i] :: unknown) :: number?
		const targetIndex = U32(vertexIndex or 0)
		local node: GdTypesH.ListNode? = vertexGrp.firstMember
		local currIndex = 0

		while node ~= nil do
			const obj = node.obj :: GdTypesH.GdObj

			if obj.type_ == GdTypesH.OBJ_TYPE_VERTICES or obj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
				const index = currIndex
				currIndex = U32(currIndex + 1)

				if index == targetIndex then
					break
				end
			end

			node = node.next
		end

		if node == nil then
			error("find_thisface_verts(): Vertex not found")
		end

		face.vertices[i] = node.obj :: GdTypesH.ObjVertex
	end

	Registry.Members.src__goddard__shape_helper.calc_face_normal(face)
end

-- from src/goddard/draw_objects.c:map_vertices L1311-1336
function draw_objects.map_vertices(facegrp: GdTypesH.ObjGroup, vtxgrp: GdTypesH.ObjGroup)
	local faceNode: GdTypesH.ListNode? = facegrp.firstMember

	while faceNode ~= nil do
		const curFace = faceNode.obj :: GdTypesH.ObjFace

		draw_objects.find_thisface_verts(curFace, vtxgrp)
		faceNode = faceNode.next
	end

	local vtxNode: GdTypesH.ListNode? = vtxgrp.firstMember

	while vtxNode ~= nil do
		const vtx = vtxNode.obj :: GdTypesH.ObjVertex

		draw_objects.calc_vtx_normal(vtx, facegrp)
		vtxNode = vtxNode.next
	end
end

-- from src/goddard/draw_objects.c:unpick_obj L1345-1350
function draw_objects.unpick_obj(obj: GdTypesH.GdObj)
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:find_closest_pickable_obj L1361-1380
function draw_objects.find_closest_pickable_obj(input: GdTypesH.GdObj)
	const obj = input

	if bit32.btest(obj.drawFlags, GdTypesH.OBJ_IS_GRABBABLE) then
		if obj.index == draw_objects.sPickDataTemp then
			local distance: number
			const camera = draw_objects.gViewUpdateCamera

			if camera ~= nil then
				const worldDistance: number = Registry.Members.src__goddard__dynlist_proc.d_calc_world_dist_btwn(camera.header, obj)

				distance = worldDistance
			else
				distance = 0.0
			end

			if distance < draw_objects.sPickObjDistance then
				draw_objects.sPickObjDistance = distance
				draw_objects.sPickedObject = obj
			end
		end
	end
end

-- from src/goddard/draw_objects.c:set_view_update_camera L1390-1396
function draw_objects.set_view_update_camera(cam: GdTypesH.ObjCamera)
	if draw_objects.gViewUpdateCamera ~= nil then
		return
	end

	draw_objects.gViewUpdateCamera = cam
end

-- from src/goddard/draw_objects.c:update_view L1408-1538
function draw_objects.update_view(view: GdTypesH.ObjView)
	draw_objects.sUpdateViewState.shapesDrawn = 0
	draw_objects.sUpdateViewState.unused = 0

	if not bit32.btest(view.flags, GdTypesH.VIEW_UPDATE) then
		view.flags = bit32.band(view.flags, bit32.bnot(GdTypesH.VIEW_WAS_UPDATED))

		return
	end

	const proc = view.proc

	if proc ~= nil then
		proc(view)
	end

	if not bit32.btest(view.flags, GdTypesH.VIEW_WAS_UPDATED) then
		view.flags = bit32.bor(view.flags, GdTypesH.VIEW_WAS_UPDATED)
	end

	draw_objects.gViewUpdateCamera = nil

	if view.components ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_CAMERAS, draw_objects.set_view_update_camera, view.components)
		view.activeCam = draw_objects.gViewUpdateCamera

		if view.activeCam ~= nil then
			const updateCamera = draw_objects.gViewUpdateCamera :: GdTypesH.ObjCamera

			updateCamera.unk18C = view
		end
	end

	if bit32.btest(view.flags, GdTypesH.VIEW_MOVEMENT) then
		Registry.Members.src__goddard__objects.proc_view_movement(view)
		draw_objects.gViewUpdateCamera = view.activeCam
	end

	if not bit32.btest(view.flags, GdTypesH.VIEW_DRAW) then
		return
	end

	draw_objects.sUpdateViewState.view = view
	Registry.Members.src__goddard__renderer.set_active_view(view)

	const gdDlNum: number = Registry.Members.src__goddard__renderer.gd_startdisplist(8)

	view.gdDlNum = gdDlNum

	const stateView = draw_objects.sUpdateViewState.view :: GdTypesH.ObjView

	Registry.Members.src__goddard__renderer.start_view_dl(stateView)
	Registry.Members.src__goddard__renderer.gd_shading(9)

	if bit32.btest(view.flags, bit32.bor(GdTypesH.VIEW_UNK_2000, GdTypesH.VIEW_UNK_4000)) then
		Registry.Members.src__goddard__renderer.gd_set_one_cycle()
	end

	if view.components ~= nil then
		if GdMain.gGdCtrl.dragging ~= 0 then
			const pickProperty: number = Registry.Members.src__goddard__renderer.gd_getproperty(3, 0)

			if pickProperty ~= IncludePRUltratypesH.FALSE and GdMain.gGdCtrl.startedDragging ~= IncludePRUltratypesH.FALSE then
				Registry.Members.src__goddard__renderer.init_pick_buf(draw_objects.sPickBuffer, #draw_objects.sPickBuffer)
				draw_objects.drawscene(draw_objects.FIND_PICKS, stateView.components :: GdTypesH.ObjGroup, nil)

				const pickOffset: number = Registry.Members.src__goddard__renderer.get_cur_pickbuf_offset(draw_objects.sPickBuffer)

				draw_objects.sPickDataTemp = 0
				draw_objects.sPickedObject = nil
				draw_objects.sPickObjDistance = 10000000.0

				if pickOffset < 0 then
					DebugUtils.fatal_printf("UpdateView(): Pick buffer too small")
				elseif pickOffset > 0 then
					local pickedObjType = 0
					local pickDataIdx = 0

					for i = 0, pickOffset - 1 do
						const pickDataSize = draw_objects.sPickBuffer[pickDataIdx + 1]

						pickDataIdx += 1

						if pickDataSize ~= 0 then
							pickedObjType = draw_objects.sPickBuffer[pickDataIdx + 1]
							pickDataIdx += 1

							if pickedObjType == GdTypesH.OBJ_TYPE_JOINTS then
								DebugUtils.gd_strcpy(Scratch.update_view_objTypeAbbr, "J")
							elseif pickedObjType == GdTypesH.OBJ_TYPE_NETS then
								DebugUtils.gd_strcpy(Scratch.update_view_objTypeAbbr, "N")
							elseif pickedObjType == GdTypesH.OBJ_TYPE_PARTICLES then
								DebugUtils.gd_strcpy(Scratch.update_view_objTypeAbbr, "P")
							else
								DebugUtils.gd_strcpy(Scratch.update_view_objTypeAbbr, "?")
							end
						end

						if pickDataSize >= 2 then
							for j = 0, pickDataSize - 2 do
								draw_objects.sPickDataTemp = draw_objects.sPickBuffer[pickDataIdx + 1]
								pickDataIdx += 1
								Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(pickedObjType, draw_objects.find_closest_pickable_obj, stateView.components)
							end
						end
					end
				end

				const pickedObject = draw_objects.sPickedObject

				if pickedObject ~= nil then
					pickedObject.drawFlags = U16(bit32.bor(pickedObject.drawFlags, GdTypesH.OBJ_PICKED))
					pickedObject.drawFlags = U16(bit32.bor(pickedObject.drawFlags, GdTypesH.OBJ_HIGHLIGHTED))
					stateView.pickedObj = pickedObject
					GdMain.gGdCtrl.csrX = TruncS32(draw_objects.sGrabCords.x)
					GdMain.gGdCtrl.dragStartX = GdMain.gGdCtrl.csrX
					GdMain.gGdCtrl.csrY = TruncS32(draw_objects.sGrabCords.y)
					GdMain.gGdCtrl.dragStartY = GdMain.gGdCtrl.csrY
				end
			end

			Registry.Members.src__goddard__objects.find_and_drag_picked_object(stateView.components :: GdTypesH.ObjGroup)
		else
			const pickedObj = stateView.pickedObj

			if pickedObj ~= nil then
				pickedObj.drawFlags = U16(bit32.band(pickedObj.drawFlags, bit32.bnot(GdTypesH.OBJ_PICKED)))
				pickedObj.drawFlags = U16(bit32.band(pickedObj.drawFlags, bit32.bnot(GdTypesH.OBJ_HIGHLIGHTED)))
				stateView.pickedObj = nil
			end
		end

		draw_objects.drawscene(draw_objects.RENDER_SCENE, stateView.components :: GdTypesH.ObjGroup, stateView.lights)
	end

	Registry.Members.src__goddard__renderer.border_active_view()
	Registry.Members.src__goddard__renderer.gd_enddlsplist_parent()
end

-- from src/goddard/draw_objects.c:stub_draw_objects_1 L1543-1544
function draw_objects.stub_draw_objects_1()
	error("stale")
	return
end

-- from src/goddard/draw_objects.c:sSelectedColour L64-64
draw_objects.sSelectedColour = draw_objects.sClrRed :: GdTypesH.GdColour?

-- from src/goddard/draw_objects.c:sColourPalette L68-70
draw_objects.sColourPalette = {
	draw_objects.sClrWhite,
	draw_objects.sClrYellow,
	draw_objects.sClrRed,
	draw_objects.sClrBlack,
	draw_objects.sClrBlack,
}

-- from src/goddard/draw_objects.c:sWhiteBlack L71-75
draw_objects.sWhiteBlack = { draw_objects.sClrWhite, draw_objects.sClrBlack }

return draw_objects
