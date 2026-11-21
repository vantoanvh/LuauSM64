--!strict
--!optimize 2

--[[
	Port of src/goddard/objects.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const DebugUtils = require("./debug_utils")
const DrawObjects = require("./draw_objects")
const GdMath = require("./gd_math")
const Skin = require("./skin")
const GdMain = require("./gd_main")
const GdMainH = require("./gd_main_h")
const Sfx = require("./sfx")
const SfxH = require("./sfx_h")
const GdMathH = require("./gd_math_h")

-- from src/goddard/objects.c:Unk801B9E68
export type Unk801B9E68 = {
	count: number,
	filler: buffer, -- [20]
}

-- from src/goddard/objects.c:Unk8017F3CC
export type Unk8017F3CC = {
	filler: buffer, -- [32]
	unk20: GdTypesH.GdVec3f,
}

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/goddard/objects.luau:scratch
const BoundingBoxPosition = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const ChildTransformScale = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const AnimationTransform = GdTypesH.new_GdAnimTransform()
-- from src/goddard/objects.luau:scratch
const AnimationMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/objects.luau:scratch
const CurrentKeyTransform = GdTypesH.new_GdAnimTransform()
-- from src/goddard/objects.luau:scratch
const NextKeyTransform = GdTypesH.new_GdAnimTransform()
-- from src/goddard/objects.luau:scratch
const CameraAttachedPosition = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const CameraPosition = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const CameraAttachedMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/objects.luau:scratch
const CameraOrbitX = { 0 }
-- from src/goddard/objects.luau:scratch
const CameraOrbitY = { 0 }
-- from src/goddard/objects.luau:scratch
const DragDisplacement = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const DragNetDisplacement = GdTypesH.new_GdVec3f()
-- from src/goddard/objects.luau:scratch
const DragInverseCameraMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/objects.luau:scratch
const DragInverseNetMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/objects.luau:scratch
const LightMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }

-- from src/goddard/objects.c:data
const objects = {
	-- from src/goddard/objects.c:D_801A81C0 L35-35
	D_801A81C0 = 0.0,
	-- from src/goddard/objects.c:D_801A81C4 L36-36
	D_801A81C4 = 0.0,
	-- from src/goddard/objects.c:gSomeBoundingBox L39-39
	gSomeBoundingBox = { minX = 0, minY = 0, minZ = 0, maxX = 0, maxY = 0, maxZ = 0 },
	-- from src/goddard/objects.c:sCurrentMoveCamera L40-40
	sCurrentMoveCamera = nil :: GdTypesH.ObjCamera?,
	-- from src/goddard/objects.c:sCurrentMoveView L41-41
	sCurrentMoveView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/objects.c:gGdCounter L42-42
	gGdCounter = { ctr0 = 0, ctr1 = 0 },
	-- from src/goddard/objects.c:D_801B9DC8 L43-43
	D_801B9DC8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
	-- from src/goddard/objects.c:D_801B9E08 L44-44
	D_801B9E08 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/objects.c:sCurrentMoveGrp L45-45
	sCurrentMoveGrp = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/objects.c:D_801B9E18 L46-46
	D_801B9E18 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/objects.c:D_801B9E28 L47-47
	D_801B9E28 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/objects.c:D_801B9E34 L48-48
	D_801B9E34 = 0,
	-- from src/goddard/objects.c:D_801B9E38 L49-49
	D_801B9E38 = nil :: { { { number } } }?,
	-- from src/goddard/objects.c:D_801B9E3C L50-50
	D_801B9E3C = nil :: GdTypesH.ObjParticle?,
	-- from src/goddard/objects.c:D_801B9E40 L51-51
	D_801B9E40 = 0,
	-- from src/goddard/objects.c:D_801B9E44 L52-52
	D_801B9E44 = 0,
	-- from src/goddard/objects.c:D_801B9E48 L53-53
	D_801B9E48 = nil :: { { { number } } }?,
	-- from src/goddard/objects.c:gGdCameraList L54-54
	gGdCameraList = nil :: GdTypesH.ObjCamera?,
	-- from src/goddard/objects.c:D_801B9E50 L55-55
	D_801B9E50 = nil,
	-- from src/goddard/objects.c:gGdGroupList L56-56
	gGdGroupList = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/objects.c:gGdObjCount L57-57
	gGdObjCount = 0,
	-- from src/goddard/objects.c:gGdGroupCount L58-58
	gGdGroupCount = 0,
	-- from src/goddard/objects.c:gGdPlaneCount L59-59
	gGdPlaneCount = 0,
	-- from src/goddard/objects.c:gGdCameraCount L60-60
	gGdCameraCount = 0,
	-- from src/goddard/objects.c:sGdViewInfo L61-61
	sGdViewInfo = { count = 0, filler = buffer.create(20) },
	-- from src/goddard/objects.c:D_801B9E80 L62-62
	D_801B9E80 = nil,
	-- from src/goddard/objects.c:gGdJointList L63-63
	gGdJointList = nil :: GdTypesH.ObjJoint?,
	-- from src/goddard/objects.c:gGdBoneList L64-64
	gGdBoneList = nil :: GdTypesH.ObjBone?,
	-- from src/goddard/objects.c:gGdObjectList L65-65
	gGdObjectList = nil :: GdTypesH.GdObj?,
	-- from src/goddard/objects.c:gGdViewsGroup L66-66
	gGdViewsGroup = nil :: GdTypesH.ObjGroup?,
}

Registry.Register("src__goddard__objects", objects)

-- from src/goddard/objects.c:Unk801B9E68 (zero-filled constructor)
function objects.new_Unk801B9E68(): Unk801B9E68
	return { count = 0, filler = buffer.create(20) } :: Unk801B9E68
end

-- from src/goddard/objects.c:Unk8017F3CC (zero-filled constructor)
function objects.new_Unk8017F3CC(): Unk8017F3CC
	return { filler = buffer.create(32), unk20 = { x = 0, y = 0, z = 0 } } :: Unk8017F3CC
end

-- from src/goddard/objects.c:reset_bounding_box L69-77
function objects.reset_bounding_box()
	objects.gSomeBoundingBox.minX = 10000000
	objects.gSomeBoundingBox.minY = 10000000
	objects.gSomeBoundingBox.minZ = 10000000
	objects.gSomeBoundingBox.maxX = -10000000
	objects.gSomeBoundingBox.maxY = -10000000
	objects.gSomeBoundingBox.maxZ = -10000000
end

-- from src/goddard/objects.c:add_obj_pos_to_bounding_box L79-108
function objects.add_obj_pos_to_bounding_box(obj: GdTypesH.GdObj)
	const pos = BoundingBoxPosition

	Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(obj)
	Registry.Members.src__goddard__dynlist_proc.d_get_world_pos(pos)

	if pos.x < objects.gSomeBoundingBox.minX then
		objects.gSomeBoundingBox.minX = pos.x
	end

	if pos.y < objects.gSomeBoundingBox.minY then
		objects.gSomeBoundingBox.minY = pos.y
	end

	if pos.z < objects.gSomeBoundingBox.minZ then
		objects.gSomeBoundingBox.minZ = pos.z
	end

	if pos.x > objects.gSomeBoundingBox.maxX then
		objects.gSomeBoundingBox.maxX = pos.x
	end

	if pos.y > objects.gSomeBoundingBox.maxY then
		objects.gSomeBoundingBox.maxY = pos.y
	end

	if pos.z > objects.gSomeBoundingBox.maxZ then
		objects.gSomeBoundingBox.maxZ = pos.z
	end
end

-- from src/goddard/objects.c:get_some_bounding_box L111-119
function objects.get_some_bounding_box(a0: GdTypesH.GdBoundingBox)
	error("stale")

	return
end

-- from src/goddard/objects.c:stub_objects_1 L122-126
function objects.stub_objects_1(a0: GdTypesH.ObjGroup, a1: GdTypesH.GdObj)
	error("stale")

	return
end

-- from src/goddard/objects.c:get_obj_name_str L131-196
function objects.get_obj_name_str(objFlag: number): string
	if objFlag == GdTypesH.OBJ_TYPE_JOINTS then
		return "joints"
	elseif objFlag == GdTypesH.OBJ_TYPE_BONES then
		return "bones"
	elseif objFlag == GdTypesH.OBJ_TYPE_GROUPS then
		return "groups"
	elseif objFlag == GdTypesH.OBJ_TYPE_PARTICLES then
		return "particles"
	elseif objFlag == GdTypesH.OBJ_TYPE_SHAPES then
		return "shapes"
	elseif objFlag == GdTypesH.OBJ_TYPE_NETS then
		return "nets"
	elseif objFlag == GdTypesH.OBJ_TYPE_PLANES then
		return "planes"
	elseif objFlag == GdTypesH.OBJ_TYPE_VERTICES then
		return "vertices"
	elseif objFlag == GdTypesH.OBJ_TYPE_CAMERAS then
		return "cameras"
	elseif objFlag == GdTypesH.OBJ_TYPE_FACES then
		return "faces"
	elseif objFlag == GdTypesH.OBJ_TYPE_MATERIALS then
		return "materials"
	elseif objFlag == GdTypesH.OBJ_TYPE_LIGHTS then
		return "lights"
	elseif objFlag == GdTypesH.OBJ_TYPE_WEIGHTS then
		return "weights"
	elseif objFlag == GdTypesH.OBJ_TYPE_GADGETS then
		return "gadgets"
	elseif objFlag == GdTypesH.OBJ_TYPE_VIEWS then
		return "views"
	elseif objFlag == GdTypesH.OBJ_TYPE_LABELS then
		return "labels"
	elseif objFlag == GdTypesH.OBJ_TYPE_ANIMATORS then
		return "animators"
	elseif objFlag == GdTypesH.OBJ_TYPE_VALPTRS then
		return "valptrs"
	elseif objFlag == GdTypesH.OBJ_TYPE_ZONES then
		return "zones"
	end

	return "unkown"
end

-- from src/goddard/objects.c:make_object L201-334
function objects.make_object(objType: number): GdTypesH.GdObj?
	local newObj: GdTypesH.GdObj
	local objDrawFn: (never) -> ()

	if objType == GdTypesH.OBJ_TYPE_JOINTS then
		newObj = GdTypesH.new_ObjJoint()
		objDrawFn = DrawObjects.draw_joint
	elseif objType == GdTypesH.OBJ_TYPE_BONES then
		newObj = GdTypesH.new_ObjBone()
		objDrawFn = DrawObjects.draw_bone
	elseif objType == GdTypesH.OBJ_TYPE_GROUPS then
		newObj = GdTypesH.new_ObjGroup()
		objDrawFn = DrawObjects.draw_group
	elseif objType == GdTypesH.OBJ_TYPE_PARTICLES then
		newObj = GdTypesH.new_ObjParticle()
		objDrawFn = DrawObjects.draw_particle
	elseif objType == GdTypesH.OBJ_TYPE_SHAPES then
		newObj = GdTypesH.new_ObjShape()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_UNK200000 then
		newObj = GdTypesH.new_ObjUnk200000()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_NETS then
		newObj = GdTypesH.new_ObjNet()
		objDrawFn = DrawObjects.draw_net
	elseif objType == GdTypesH.OBJ_TYPE_PLANES then
		newObj = GdTypesH.new_ObjPlane()
		objDrawFn = DrawObjects.draw_plane
	elseif objType == GdTypesH.OBJ_TYPE_VERTICES then
		newObj = GdTypesH.new_ObjVertex()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_CAMERAS then
		newObj = GdTypesH.new_ObjCamera()
		objDrawFn = DrawObjects.draw_camera
	elseif objType == GdTypesH.OBJ_TYPE_FACES then
		newObj = GdTypesH.new_ObjFace()
		objDrawFn = DrawObjects.draw_face
	elseif objType == GdTypesH.OBJ_TYPE_MATERIALS then
		newObj = GdTypesH.new_ObjMaterial()
		objDrawFn = DrawObjects.draw_material
	elseif objType == GdTypesH.OBJ_TYPE_LIGHTS then
		newObj = GdTypesH.new_ObjLight()
		objDrawFn = DrawObjects.draw_light
	elseif objType == GdTypesH.OBJ_TYPE_WEIGHTS then
		newObj = GdTypesH.new_ObjWeight()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_GADGETS then
		newObj = GdTypesH.new_ObjGadget()
		objDrawFn = DrawObjects.draw_gadget
	elseif objType == GdTypesH.OBJ_TYPE_VIEWS then
		newObj = GdTypesH.new_ObjView()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_LABELS then
		newObj = GdTypesH.new_ObjLabel()
		objDrawFn = DrawObjects.draw_label
	elseif objType == GdTypesH.OBJ_TYPE_ANIMATORS then
		newObj = GdTypesH.new_ObjAnimator()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_VALPTRS then
		newObj = GdTypesH.new_ObjValPtr()
		objDrawFn = DrawObjects.draw_nothing
	elseif objType == GdTypesH.OBJ_TYPE_ZONES then
		newObj = GdTypesH.new_ObjZone()
		objDrawFn = DrawObjects.draw_nothing
	else
		error("make_object() : Unkown object!")
	end

	objects.gGdObjCount += 1

	const objListOldHead = objects.gGdObjectList

	objects.gGdObjectList = newObj
	newObj.prev = nil

	if objListOldHead ~= nil then
		newObj.next = objListOldHead
		objListOldHead.prev = newObj
	end

	newObj.index = S16(objects.gGdObjCount)
	newObj.type_ = objType
	newObj.objDrawFn = (objDrawFn :: unknown) :: () -> ()
	newObj.drawFlags = 0

	return newObj
end

-- from src/goddard/objects.c:make_zone L337-354
function objects.make_zone(a0: GdTypesH.ObjGroup?, bbox: GdTypesH.GdBoundingBox, a2: GdTypesH.ObjGroup?): GdTypesH.ObjZone
	error("stale")
end

-- from src/goddard/objects.c:func_8017C7A0 L357-364
function objects.func_8017C7A0(a0: GdTypesH.ObjVertex, a1: GdTypesH.ObjFace): GdTypesH.ObjUnk200000
	error("stale")
end

-- from src/goddard/objects.c:make_link_to_obj L369-390
function objects.make_link_to_obj(prevNode: GdTypesH.ListNode?, obj: GdTypesH.GdObj): GdTypesH.ListNode
	const newNode = GdTypesH.new_ListNode()

	if prevNode ~= nil then
		prevNode.next = newNode
	end

	newNode.prev = prevNode
	newNode.next = nil
	newNode.obj = obj

	return newNode
end

-- from src/goddard/objects.c:make_vtx_link L395-418
function objects.make_vtx_link(prevNode: GdTypesH.VtxLink?, data: number): GdTypesH.VtxLink
	const newNode = GdTypesH.new_VtxLink()

	if prevNode ~= nil then
		prevNode.next = newNode
	end

	newNode.prev = prevNode
	newNode.next = nil
	newNode.data = data

	return newNode
end

-- from src/goddard/objects.c:make_valptr L421-430
function objects.make_valptr(obj: GdTypesH.GdObj, flag: number, type_: number, offset: number): GdTypesH.ObjValPtr
	error("stale")
end

-- from src/goddard/objects.c:reset_plane L433-510
function objects.reset_plane(plane: GdTypesH.ObjPlane)
	error("stale")

	return
end

-- from src/goddard/objects.c:make_plane L513-524
function objects.make_plane(inZone: number, a1: GdTypesH.ObjFace?): GdTypesH.ObjPlane
	error("stale")
end

-- from src/goddard/objects.c:make_camera L527-569
function objects.make_camera(flags: number, a1: GdTypesH.GdObj?): GdTypesH.ObjCamera
	const newCam = objects.make_object(GdTypesH.OBJ_TYPE_CAMERAS) :: GdTypesH.ObjCamera

	objects.gGdCameraCount += 1
	newCam.id = objects.gGdCameraCount

	const oldCameraHead = objects.gGdCameraList

	objects.gGdCameraList = newCam

	if oldCameraHead ~= nil then
		newCam.ObjCamera_next = oldCameraHead
		oldCameraHead.ObjCamera_prev = newCam
	end

	newCam.flags = bit32.bor(flags, 0x10)
	newCam.unk30 = a1
	GdMath.gd_set_identity_mat4(newCam.unk64)
	GdMath.gd_set_identity_mat4(newCam.unkA8)

	newCam.unk180.x = 1
	newCam.unk180.y = F32(0.1)
	newCam.unk180.z = 1
	newCam.unk134.x = 4
	newCam.unk134.y = 4
	newCam.unk134.z = 4

	newCam.unk178 = 0
	newCam.unk17C = 0.25
	newCam.zoomLevel = 0
	newCam.maxZoomLevel = -1
	newCam.unkA4 = 0
	newCam.lookAt.x = 0
	newCam.lookAt.y = 0
	newCam.lookAt.z = 0
	newCam.worldPos.x = 0
	newCam.worldPos.y = 0
	newCam.worldPos.z = 0

	return newCam
end

-- from src/goddard/objects.c:make_material L572-588
function objects.make_material(a0: number, name: string?, id: number): GdTypesH.ObjMaterial
	const newMtl = objects.make_object(GdTypesH.OBJ_TYPE_MATERIALS) :: GdTypesH.ObjMaterial

	if name ~= nil then
		DebugUtils.gd_strcpy(newMtl.name, name)
	else
		DebugUtils.gd_strcpy(newMtl.name, "NoName")
	end

	newMtl.id = id
	newMtl.gddlNumber = 0
	newMtl.ObjMaterial_type = 16

	return newMtl
end

-- from src/goddard/objects.c:make_light L591-612
function objects.make_light(flags: number, name: string?, id: number): GdTypesH.ObjLight
	const newLight = objects.make_object(GdTypesH.OBJ_TYPE_LIGHTS) :: GdTypesH.ObjLight

	if name ~= nil then
		DebugUtils.gd_strcpy(newLight.name, name)
	else
		DebugUtils.gd_strcpy(newLight.name, "NoName")
	end

	newLight.id = id
	newLight.unk30 = 1
	newLight.unk4C = 0
	newLight.flags = bit32.bor(flags, GdTypesH.LIGHT_NEW_UNCOUNTED)
	newLight.unk98 = 0
	newLight.unk40 = 0
	newLight.unk68.x = 0
	newLight.unk68.y = 0
	newLight.unk68.z = 0

	return newLight
end

-- from src/goddard/objects.c:make_view L615-663
function objects.make_view(name: string?, flags: number, projectionType: number, ulx: number, uly: number, lrx: number, lry: number, parts: GdTypesH.ObjGroup?): GdTypesH.ObjView
	const newView = objects.make_object(GdTypesH.OBJ_TYPE_VIEWS) :: GdTypesH.ObjView
	const oldViewsGroup = objects.gGdViewsGroup
	const viewsGroup = if oldViewsGroup == nil then objects.make_group(0) else oldViewsGroup

	objects.gGdViewsGroup = viewsGroup
	objects.addto_group(viewsGroup, newView.header)

	newView.flags = bit32.bor(flags, GdTypesH.VIEW_UPDATE, GdTypesH.VIEW_LIGHT)
	newView.id = objects.sGdViewInfo.count
	objects.sGdViewInfo.count += 1
	newView.components = parts

	if parts ~= nil then
		objects.reset_nets_and_gadgets(parts)
	end

	newView.unk78 = 0
	newView.projectionType = projectionType
	newView.clipping.x = 30
	newView.clipping.y = 5000
	newView.clipping.z = 45

	newView.upperLeft.x = F32(ulx)
	newView.upperLeft.y = F32(uly)
	newView.lowerRight.x = F32(lrx)
	newView.lowerRight.y = F32(lry)

	newView.unk48 = 1
	newView.unk4C = 1

	newView.colour.r = F32(newView.id * 0.1)
	newView.colour.g = F32(0.06)
	newView.colour.b = 1
	newView.proc = nil
	newView.unk9C = 0

	if name ~= nil then
		newView.unk1C = Registry.Members.src__goddard__renderer.setup_view_buffers(name, newView, ulx, uly, lrx, lry)
	end

	newView.namePtr = name
	newView.lights = nil

	return newView
end

-- from src/goddard/objects.c:make_animator L666-675
function objects.make_animator(): GdTypesH.ObjAnimator
	const newAnim = objects.make_object(GdTypesH.OBJ_TYPE_ANIMATORS) :: GdTypesH.ObjAnimator

	newAnim.unk24 = 1
	newAnim.frame = 1
	newAnim.controlFunc = nil
	newAnim.state = 0

	return newAnim
end

-- from src/goddard/objects.c:make_weight L678-686
function objects.make_weight(a0: number, vtxId: number, vtx: GdTypesH.ObjVertex?, weight: number): GdTypesH.ObjWeight
	weight = F32(weight)

	const newWeight = objects.make_object(GdTypesH.OBJ_TYPE_WEIGHTS) :: GdTypesH.ObjWeight

	newWeight.vtxId = vtxId
	newWeight.weightVal = weight
	newWeight.vtx = vtx

	return newWeight
end

-- from src/goddard/objects.c:make_group_of_type L692-712
function objects.make_group_of_type(type_: number, fromObj: GdTypesH.GdObj, toObj: GdTypesH.GdObj?): GdTypesH.ObjGroup
	const newGroup = objects.make_group(0)
	local curObj: GdTypesH.GdObj? = fromObj

	while curObj ~= nil do
		if bit32.btest(curObj.type_, type_) then
			objects.addto_group(newGroup, curObj)
		end

		if curObj == toObj then
			break
		end

		curObj = curObj.prev
	end

	return newGroup
end

-- from src/goddard/objects.c:format_object_id L717-749
function objects.format_object_id(str: buffer, obj: GdTypesH.GdObj)
	const type_ = obj.type_
	local text: string

	if type_ == GdTypesH.OBJ_TYPE_BONES then
		text = string.format("b%d ", (obj :: GdTypesH.ObjBone).id)
	elseif type_ == GdTypesH.OBJ_TYPE_JOINTS then
		text = string.format("j%d ", (obj :: GdTypesH.ObjJoint).id)
	elseif type_ == GdTypesH.OBJ_TYPE_GROUPS then
		text = string.format("g%d ", (obj :: GdTypesH.ObjGroup).id)
	elseif type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		text = string.format("p%d ", (obj :: GdTypesH.ObjParticle).id)
	elseif type_ == GdTypesH.OBJ_TYPE_NETS then
		text = "net(no id) "
	elseif type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		text = string.format("c%d ", (obj :: GdTypesH.ObjCamera).id)
	elseif type_ == GdTypesH.OBJ_TYPE_VERTICES then
		text = "v(no id) "
	elseif type_ == GdTypesH.OBJ_TYPE_PLANES then
		text = string.format("pl%d ", (obj :: GdTypesH.ObjPlane).id)
	else
		text = string.format("?%x ", type_)
	end

	DebugUtils.gd_strcpy(str, text)
end

-- from src/goddard/objects.c:make_group L752-810
function objects.make_group(count: number, ...: GdTypesH.GdObj): GdTypesH.ObjGroup
	const newGroup = objects.make_object(GdTypesH.OBJ_TYPE_GROUPS) :: GdTypesH.ObjGroup

	objects.gGdGroupCount += 1
	newGroup.id = objects.gGdGroupCount
	newGroup.memberCount = 0
	newGroup.firstMember = nil
	newGroup.lastMember = nil

	const oldGroupListHead = objects.gGdGroupList

	objects.gGdGroupList = newGroup

	if oldGroupListHead ~= nil then
		newGroup.ObjGroup_next = oldGroupListHead
		oldGroupListHead.ObjGroup_prev = newGroup
	end

	if count == 0 then
		return newGroup
	end

	const arguments = { ... }

	for i = 1, count do
		const vargObj = arguments[i]

		if vargObj == nil then
			error("make_group() NULL group ptr")
		end

		newGroup.memberTypes = bit32.bor(newGroup.memberTypes, vargObj.type_)
		objects.addto_group(newGroup, vargObj)
	end

	return newGroup
end

-- from src/goddard/objects.c:addto_group L815-841
function objects.addto_group(group: GdTypesH.ObjGroup, obj: GdTypesH.GdObj)
	if group.firstMember == nil then
		group.firstMember = objects.make_link_to_obj(nil, obj)
		group.lastMember = group.firstMember
	else
		group.lastMember = objects.make_link_to_obj(group.lastMember, obj)
	end

	group.memberTypes = bit32.bor(group.memberTypes, obj.type_)
	group.memberCount += 1
end

-- from src/goddard/objects.c:addto_groupfirst L846-864
function objects.addto_groupfirst(group: GdTypesH.ObjGroup, obj: GdTypesH.GdObj)
	const firstMember = group.firstMember

	if firstMember == nil then
		const newNode = objects.make_link_to_obj(nil, obj)

		group.firstMember = newNode
		group.lastMember = newNode
	else
		const newNode = objects.make_link_to_obj(nil, obj)

		firstMember.prev = newNode
		newNode.next = firstMember
		group.firstMember = newNode
	end

	group.memberTypes = bit32.bor(group.memberTypes, obj.type_)
	group.memberCount += 1
end

-- from src/goddard/objects.c:group_contains_obj L869-880
function objects.group_contains_obj(group: GdTypesH.ObjGroup, obj: GdTypesH.GdObj): number
	local node = group.firstMember

	while node ~= nil do
		const linkedObj = node.obj :: GdTypesH.GdObj

		if linkedObj.index == obj.index then
			return 1
		end

		node = node.next
	end

	return 0
end

-- from src/goddard/objects.c:show_details L885-988
function objects.show_details(type_: number)
	error("stale")

	return
end

-- from src/goddard/objects.c:stub_objects_2 L991-994
function objects.stub_objects_2(): number
	error("stale")
end

-- from src/goddard/objects.c:make_scene L999-1002
function objects.make_scene(): number
	error("stale")
end

-- from src/goddard/objects.c:reset_joint_or_net L1005-1017
function objects.reset_joint_or_net(obj: GdTypesH.GdObj)
	error("stale")

	return
end

-- from src/goddard/objects.c:menu_cb_reset_positions L1023-1025
function objects.menu_cb_reset_positions()
	error("stale")

	return
end

-- from src/goddard/objects.c:func_8017E2F0 L1030-1058
function objects.func_8017E2F0(obj: GdTypesH.GdObj, type_: number): GdTypesH.GdObj?
	error("stale")
end

-- from src/goddard/objects.c:apply_to_obj_types_in_group L1065-1114
function objects.apply_to_obj_types_in_group(types: number, func: (never) -> (), group: GdTypesH.ObjGroup?): number
	local fnAppliedCount = 0

	if group == nil then
		return fnAppliedCount
	end

	if bit32.btest(group.linkType, 1) then
		return fnAppliedCount
	end

	if not bit32.btest(group.memberTypes, bit32.bor(GdTypesH.OBJ_TYPE_GROUPS, types)) then
		return fnAppliedCount
	end

	local curLink = group.firstMember

	while curLink ~= nil do
		const linkedObj = curLink.obj :: GdTypesH.GdObj
		const linkedObjType = linkedObj.type_
		const nextLink = curLink.next

		if linkedObjType == GdTypesH.OBJ_TYPE_GROUPS then
			fnAppliedCount += objects.apply_to_obj_types_in_group(types, func, linkedObj :: GdTypesH.ObjGroup)
		end

		if bit32.btest(linkedObjType, types) then
			func(linkedObj :: never)
			fnAppliedCount += 1
		end

		curLink = nextLink
	end

	return fnAppliedCount
end

-- from src/goddard/objects.c:func_8017E584 L1117-1170
function objects.func_8017E584(a0: GdTypesH.ObjNet, a1: GdTypesH.GdVec3f, a2: GdTypesH.GdVec3f)
	error("stale")

	return
end

-- from src/goddard/objects.c:func_8017E838 L1173-1204
function objects.func_8017E838(a0: GdTypesH.ObjNet, a1: GdTypesH.GdVec3f, a2: GdTypesH.GdVec3f)
	error("stale")

	return
end

-- from src/goddard/objects.c:func_8017E9EC L1207-1220
function objects.func_8017E9EC(net: GdTypesH.ObjNet)
	error("stale")

	return
end

-- from src/goddard/objects.c:func_8017EA94 L1225-1232
function objects.func_8017EA94(vec: GdTypesH.GdVec3f, matrix: { { number } }): number
	error("stale")
end

-- from src/goddard/objects.c:func_8017EB24 L1237-1275
function objects.func_8017EB24(obj1: GdTypesH.GdObj, obj2: GdTypesH.GdObj): number
	error("stale")
end

-- from src/goddard/objects.c:is_obj_xz_in_bounding_box L1280-1297
function objects.is_obj_xz_in_bounding_box(obj: GdTypesH.GdObj, bbox: GdTypesH.GdBoundingBox): number
	error("stale")
end

-- from src/goddard/objects.c:is_point_xz_in_bounding_box L1302-1314
function objects.is_point_xz_in_bounding_box(point: GdTypesH.GdVec3f, bbox: GdTypesH.GdBoundingBox): number
	error("stale")
end

-- from src/goddard/objects.c:gd_plane_point_within L1320-1366
function objects.gd_plane_point_within(box1: GdTypesH.GdBoundingBox, box2: GdTypesH.GdBoundingBox): number
	error("stale")
end

-- from src/goddard/objects.c:transform_child_objects_recursive L1369-1420
function objects.transform_child_objects_recursive(obj: GdTypesH.GdObj, parentObj: GdTypesH.GdObj?): number
	const scale = ChildTransformScale

	if parentObj ~= nil then
		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(parentObj)

		const parentUnkMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_matrix_ptr()
		const rotMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()

		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(obj)

		const iMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_i_mtx_ptr()
		const rotMtx2: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()

		Registry.Members.src__goddard__dynlist_proc.d_get_scale(scale)

		const unkMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_matrix_ptr()

		GdMath.gd_mult_mat4f(iMtx, parentUnkMtx, unkMtx)
		GdMath.gd_mult_mat4f(iMtx, rotMtx, rotMtx2)
		GdMath.gd_scale_mat4f_by_vec3f(rotMtx2, scale)
	else
		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(obj)

		const unkMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_matrix_ptr()
		const iMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_i_mtx_ptr()
		const rotMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()

		Registry.Members.src__goddard__dynlist_proc.d_get_scale(scale)
		GdMath.gd_set_identity_mat4(unkMtx)
		GdMath.gd_copy_mat4f(iMtx, rotMtx)
		GdMath.gd_scale_mat4f_by_vec3f(rotMtx, scale)
	end

	Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(obj)

	const curGroup: GdTypesH.ObjGroup? = Registry.Members.src__goddard__dynlist_proc.d_get_att_objgroup()

	if curGroup ~= nil then
		local curLink = curGroup.firstMember

		while curLink ~= nil do
			objects.transform_child_objects_recursive(curLink.obj :: GdTypesH.GdObj, obj)
			curLink = curLink.next
		end
	end

	return 0
end

-- from src/goddard/objects.c:func_8017F210 L1423-1472
function objects.func_8017F210(a0: GdTypesH.GdObj, a1: GdTypesH.GdObj?): number
	error("stale")
end

-- from src/goddard/objects.c:func_8017F3CC L1475-1477
function objects.func_8017F3CC(a0: Unk8017F3CC)
	error("stale")

	return
end

-- from src/goddard/objects.c:stub_objects_3 L1480-1482
function objects.stub_objects_3(a0: number, a1: GdTypesH.GdObj, a2: GdTypesH.GdObj)
	error("stale")

	return
end

-- from src/goddard/objects.c:interpolate_animation_transform L1489-1518
function objects.interpolate_animation_transform(t1: GdTypesH.GdAnimTransform, t2: GdTypesH.GdAnimTransform, dt: number)
	dt = F32(dt)
	const mtx = AnimationMatrix

	GdMath.gd_set_identity_mat4(mtx)

	if dt ~= 0.0 then
		const transform = AnimationTransform

		transform.rotate.x = F32(t1.rotate.x + F32(F32(t2.rotate.x - t1.rotate.x) * dt))
		transform.rotate.y = F32(t1.rotate.y + F32(F32(t2.rotate.y - t1.rotate.y) * dt))
		transform.rotate.z = F32(t1.rotate.z + F32(F32(t2.rotate.z - t1.rotate.z) * dt))
		transform.pos.x = F32(t1.pos.x + F32(F32(t2.pos.x - t1.pos.x) * dt))
		transform.pos.y = F32(t1.pos.y + F32(F32(t2.pos.y - t1.pos.y) * dt))
		transform.pos.z = F32(t1.pos.z + F32(F32(t2.pos.z - t1.pos.z) * dt))

		GdMath.gd_scale_mat4f_by_vec3f(mtx, t1.scale)
		GdMath.gd_rot_mat_about_vec(mtx, transform.rotate)
		GdMath.gd_add_vec3f_to_mat4f_offset(mtx, transform.pos)
	else
		Registry.Members.src__goddard__dynlist_proc.d_set_scale(t1.scale.x, t1.scale.y, t1.scale.z)
		GdMath.gd_rot_mat_about_vec(mtx, t1.rotate)
		GdMath.gd_add_vec3f_to_mat4f_offset(mtx, t1.pos)
	end

	Registry.Members.src__goddard__dynlist_proc.d_set_i_matrix(AnimationMatrix)
end

-- from src/goddard/objects.c:move_animator L1521-1763
function objects.move_animator(animObj: GdTypesH.ObjAnimator)
	const controlFunc = animObj.controlFunc

	if controlFunc ~= nil then
		controlFunc(animObj)
	end

	const parts = animObj.animatedPartsGrp

	if parts == nil then
		return
	end

	const animationGroup = animObj.animdataGrp :: GdTypesH.ObjGroup
	const firstMember = animationGroup.firstMember :: GdTypesH.ListNode
	const sequences = (firstMember.obj :: unknown) :: { GdTypesH.AnimDataInfo }
	local animData = sequences[1]
	const attached = animObj.attachedToObj :: GdTypesH.ObjAnimator?

	if attached ~= nil then
		animObj.frame = F32(attached.frame / attached.unk24)
		animData = sequences[attached.animSeqNum + 1]
	end

	if animData.type_ == 0 then
		return
	end

	if animObj.frame > F32(animData.count) then
		animObj.frame = 1.0
	elseif animObj.frame < 0.0 then
		animObj.frame = F32(animData.count)
	end

	const currKeyFrame = TruncS32(animObj.frame)
	const dt = F32(animObj.frame - F32(currKeyFrame))
	local nextKeyFrame = currKeyFrame + 1

	if nextKeyFrame > animData.count then
		nextKeyFrame = 1
	end

	const currTransform = CurrentKeyTransform
	const nextTransform = NextKeyTransform
	const scale = F32(0.1)
	local stubObj1: GdTypesH.GdObj? = nil
	local stubObj2: GdTypesH.GdObj? = nil
	local link = parts.firstMember

	while link ~= nil do
		const linkedObj = link.obj :: GdTypesH.GdObj

		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(linkedObj)

		if animData.type_ == GdTypesH.GD_ANIM_MTX4x4 then
			const mtxArr = animData.data :: { { { number } } }

			-- The original matrix-only path indexes with frame directly, before the other formats' zero-base conversion.
			Registry.Members.src__goddard__dynlist_proc.d_set_i_matrix(mtxArr[currKeyFrame + 1])
		elseif animData.type_ == GdTypesH.GD_ANIM_ROT3S then
			const animData3s16 = animData.data :: { { number } }
			const Current = animData3s16[currKeyFrame]
			const Next = animData3s16[nextKeyFrame]

			Registry.Members.src__goddard__dynlist_proc.d_get_scale(currTransform.scale)
			nextTransform.scale.x = currTransform.scale.x
			nextTransform.scale.y = currTransform.scale.y
			nextTransform.scale.z = currTransform.scale.z

			Registry.Members.src__goddard__dynlist_proc.d_get_init_pos(currTransform.pos)
			nextTransform.pos.x = currTransform.pos.x
			nextTransform.pos.y = currTransform.pos.y
			nextTransform.pos.z = currTransform.pos.z

			currTransform.rotate.x = F32(Current[1] * scale)
			currTransform.rotate.y = F32(Current[2] * scale)
			currTransform.rotate.z = F32(Current[3] * scale)
			nextTransform.rotate.x = F32(Next[1] * scale)
			nextTransform.rotate.y = F32(Next[2] * scale)
			nextTransform.rotate.z = F32(Next[3] * scale)
			objects.interpolate_animation_transform(currTransform, nextTransform, dt)
		elseif animData.type_ == GdTypesH.GD_ANIM_POS3S then
			const animData3s16 = animData.data :: { { number } }
			const Current = animData3s16[currKeyFrame]
			const Next = animData3s16[nextKeyFrame]

			Registry.Members.src__goddard__dynlist_proc.d_get_scale(currTransform.scale)
			nextTransform.scale.x = currTransform.scale.x
			nextTransform.scale.y = currTransform.scale.y
			nextTransform.scale.z = currTransform.scale.z

			Registry.Members.src__goddard__dynlist_proc.d_get_init_rot(currTransform.rotate)
			nextTransform.rotate.x = currTransform.rotate.x
			nextTransform.rotate.y = currTransform.rotate.y
			nextTransform.rotate.z = currTransform.rotate.z

			currTransform.pos.x = F32(Current[1])
			currTransform.pos.y = F32(Current[2])
			currTransform.pos.z = F32(Current[3])
			nextTransform.pos.x = F32(Next[1])
			nextTransform.pos.y = F32(Next[2])
			nextTransform.pos.z = F32(Next[3])
			objects.interpolate_animation_transform(currTransform, nextTransform, dt)
		elseif animData.type_ == GdTypesH.GD_ANIM_ROT3S_POS3S then
			const animData6s16 = animData.data :: { { number } }
			const Current = animData6s16[currKeyFrame]
			const Next = animData6s16[nextKeyFrame]

			Registry.Members.src__goddard__dynlist_proc.d_get_scale(currTransform.scale)
			nextTransform.scale.x = currTransform.scale.x
			nextTransform.scale.y = currTransform.scale.y
			nextTransform.scale.z = currTransform.scale.z

			currTransform.rotate.x = F32(Current[1] * scale)
			currTransform.rotate.y = F32(Current[2] * scale)
			currTransform.rotate.z = F32(Current[3] * scale)
			nextTransform.rotate.x = F32(Next[1] * scale)
			nextTransform.rotate.y = F32(Next[2] * scale)
			nextTransform.rotate.z = F32(Next[3] * scale)

			currTransform.pos.x = F32(Current[4])
			currTransform.pos.y = F32(Current[5])
			currTransform.pos.z = F32(Current[6])
			nextTransform.pos.x = F32(Next[4])
			nextTransform.pos.y = F32(Next[5])
			nextTransform.pos.z = F32(Next[6])
			objects.interpolate_animation_transform(currTransform, nextTransform, dt)
		elseif animData.type_ == GdTypesH.GD_ANIM_SCALE3S_POS3S_ROT3S then
			const animData9s16 = animData.data :: { { number } }
			const Current = animData9s16[currKeyFrame]
			const Next = animData9s16[nextKeyFrame]

			currTransform.scale.x = F32(Current[1] * scale)
			currTransform.scale.y = F32(Current[2] * scale)
			currTransform.scale.z = F32(Current[3] * scale)
			currTransform.rotate.x = F32(Current[4] * scale)
			currTransform.rotate.y = F32(Current[5] * scale)
			currTransform.rotate.z = F32(Current[6] * scale)
			currTransform.pos.x = F32(Current[7])
			currTransform.pos.y = F32(Current[8])
			currTransform.pos.z = F32(Current[9])

			nextTransform.scale.x = F32(Next[1] * scale)
			nextTransform.scale.y = F32(Next[2] * scale)
			nextTransform.scale.z = F32(Next[3] * scale)
			nextTransform.rotate.x = F32(Next[4] * scale)
			nextTransform.rotate.y = F32(Next[5] * scale)
			nextTransform.rotate.z = F32(Next[6] * scale)
			nextTransform.pos.x = F32(Next[7])
			nextTransform.pos.y = F32(Next[8])
			nextTransform.pos.z = F32(Next[9])
			objects.interpolate_animation_transform(currTransform, nextTransform, dt)
		elseif animData.type_ == GdTypesH.GD_ANIM_CAMERA_EYE3S_LOOKAT3S then
			if linkedObj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
				const animDataCam = animData.data :: { { number } }
				const Current = animDataCam[currKeyFrame]
				const Camera = linkedObj :: GdTypesH.ObjCamera

				Camera.worldPos.x = F32(Current[1])
				Camera.worldPos.y = F32(Current[2])
				Camera.worldPos.z = F32(Current[3])
				Camera.lookAt.x = F32(Current[4])
				Camera.lookAt.y = F32(Current[5])
				Camera.lookAt.z = F32(Current[6])
			end
		elseif animData.type_ == GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F then
			const triPtr = animData.data :: { GdTypesH.GdAnimTransform }

			objects.interpolate_animation_transform(triPtr[currKeyFrame], triPtr[nextKeyFrame], dt)
		elseif animData.type_ == GdTypesH.GD_ANIM_MTX4x4F_SCALE3F then
			const Entries = animData.data :: { GdTypesH.AnimMtxVec }
			const Entry = Entries[currKeyFrame]

			Registry.Members.src__goddard__dynlist_proc.d_set_i_matrix(Entry.matrix)
			Registry.Members.src__goddard__dynlist_proc.d_set_scale(Entry.vec.x, Entry.vec.y, Entry.vec.z)
		elseif animData.type_ == GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F_2 then
			const Entries = animData.data :: { GdTypesH.GdAnimTransform }
			const triPtr = Entries[1]
			const localMtx = AnimationMatrix

			GdMath.gd_set_identity_mat4(localMtx)
			GdMath.gd_scale_mat4f_by_vec3f(localMtx, triPtr.scale)
			GdMath.gd_rot_mat_about_vec(localMtx, triPtr.rotate)
			GdMath.gd_add_vec3f_to_mat4f_offset(localMtx, triPtr.pos)
			Registry.Members.src__goddard__dynlist_proc.d_set_i_matrix(AnimationMatrix)
		elseif animData.type_ == GdTypesH.GD_ANIM_STUB then
			if stubObj1 == nil then
				stubObj1 = linkedObj
			elseif stubObj2 == nil then
				stubObj2 = linkedObj
				-- The native morph callback has an empty body.
			else
				error("Too many objects to morph")
			end
		else
			error("move_animator(): Unkown animation data type")
		end

		link = link.next
	end
end

-- from src/goddard/objects.c:drag_picked_object L1766-1826
function objects.drag_picked_object(inputObj: GdTypesH.GdObj)
	const ctrl = GdMain.gGdCtrl
	const camera = DrawObjects.gViewUpdateCamera

	if camera == nil then
		return
	end

	local dispMag = GdMath.gd_vec3f_magnitude(camera.unk40)

	dispMag = F32(dispMag / 1000.0)

	DragDisplacement.x = F32(F32(S32(ctrl.csrX - ctrl.dragStartX)) * dispMag)
	DragDisplacement.y = F32(F32(-S32(ctrl.csrY - ctrl.dragStartY)) * dispMag)
	DragDisplacement.z = 0.0

	GdMath.gd_inverse_mat4f(camera.unkE8, DragInverseCameraMatrix)
	GdMath.gd_mat4f_mult_vec3f(DragDisplacement, DragInverseCameraMatrix)

	const obj = inputObj

	if bit32.btest(inputObj.drawFlags, GdTypesH.OBJ_PICKED) and GdMain.gGdCtrl.dragging ~= 0 then
		Sfx.gd_play_sfx(SfxH.GD_SFX_PINCH_FACE)

		-- Note: this second sfx won't play, as it is "overwritten" by the first
		if math.abs(ctrl.stickDeltaX) + math.abs(ctrl.stickDeltaY) >= 11 then
			Sfx.gd_play_sfx(SfxH.GD_SFX_PINCH_FACE_2)
		end

		if inputObj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
			const joint = (obj :: unknown) :: GdTypesH.ObjJoint

			joint.mat128[4][1] = F32(joint.mat128[4][1] + DragDisplacement.x)
			joint.mat128[4][2] = F32(joint.mat128[4][2] + DragDisplacement.y)
			joint.mat128[4][3] = F32(joint.mat128[4][3] + DragDisplacement.z)
		elseif inputObj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
			-- Nothing to move.
		elseif inputObj.type_ == GdTypesH.OBJ_TYPE_NETS then
			const net = (obj :: unknown) :: GdTypesH.ObjNet

			GdMath.gd_inverse_mat4f(net.mat128, DragInverseNetMatrix)
			DragNetDisplacement.x = DragDisplacement.x
			DragNetDisplacement.y = DragDisplacement.y
			DragNetDisplacement.z = DragDisplacement.z
			GdMath.gd_mat4f_mult_vec3f(DragNetDisplacement, DragInverseNetMatrix)
			net.matE8[4][1] = F32(net.matE8[4][1] + DragDisplacement.x)
			net.matE8[4][2] = F32(net.matE8[4][2] + DragDisplacement.y)
			net.matE8[4][3] = F32(net.matE8[4][3] + DragDisplacement.z)
		elseif inputObj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
			-- Nothing to move.
		end
	end
end

-- from src/goddard/objects.c:move_animators L1829-1833
function objects.move_animators(group: GdTypesH.ObjGroup)
	objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ANIMATORS, objects.move_animator, group)
end

-- from src/goddard/objects.c:find_and_drag_picked_object L1836-1838
function objects.find_and_drag_picked_object(group: GdTypesH.ObjGroup)
	objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, objects.drag_picked_object, group)
end

-- from src/goddard/objects.c:move_camera L1841-1959
function objects.move_camera(cam: GdTypesH.ObjCamera)
	const ctrl = GdMain.gGdCtrl

	if not bit32.btest(cam.flags, 0x10) then
		return
	end

	const attachedPos = CameraAttachedPosition
	const pos = CameraPosition

	attachedPos.x = 0.0
	attachedPos.y = 0.0
	attachedPos.z = 0.0

	const attached = cam.unk30

	if attached ~= nil then
		Registry.Members.src__goddard__dynlist_proc.set_cur_dynobj(attached)
		Registry.Members.src__goddard__dynlist_proc.d_get_world_pos(attachedPos)
		Registry.Members.src__goddard__dynlist_proc.d_get_matrix(CameraAttachedMatrix)

		const DeltaX = F32(CameraAttachedMatrix[3][1] - cam.unk58)
		const DeltaZ = F32(CameraAttachedMatrix[3][3] - cam.unk60)

		cam.unk58 = F32(cam.unk58 + F32(DeltaX * cam.unk180.y))
		cam.unk60 = F32(cam.unk60 + F32(DeltaZ * cam.unk180.y))

		cam.unkA8[3][1] = cam.unk58
		cam.unkA8[3][2] = 0.0
		cam.unkA8[3][3] = cam.unk60
		cam.unkA8[1][1] = cam.unkA8[3][3]
		cam.unkA8[1][2] = 0.0
		cam.unkA8[1][3] = -cam.unkA8[3][1]
		cam.unkA8[2][1] = 0.0
		cam.unkA8[2][2] = 1.0
		cam.unkA8[2][3] = 0.0

		GdMath.gd_set_identity_mat4(cam.unkA8)
	else
		GdMath.gd_set_identity_mat4(cam.unkA8)
	end

	const matrix = cam.unk64

	if bit32.btest(cam.flags, GdTypesH.CAMERA_FLAG_CONTROLLABLE) then
		if ctrl.btnB ~= 0 and (ctrl.prevFrame :: GdMainH.GdControl).btnB == 0 then
			cam.zoomLevel += 1

			if cam.zoomLevel > cam.maxZoomLevel then
				cam.zoomLevel = 0
			end

			if cam.zoomLevel == 0 then
				Sfx.gd_play_sfx(SfxH.GD_SFX_CAM_ZOOM_IN)
			elseif cam.zoomLevel == 1 or cam.zoomLevel == 2 then
				Sfx.gd_play_sfx(SfxH.GD_SFX_CAM_ZOOM_OUT)
			end
		end

		if ctrl.cleft ~= 0 then
			cam.unk128.y = F32(cam.unk128.y + cam.unk134.y)
		end

		if ctrl.cright ~= 0 then
			cam.unk128.y = F32(cam.unk128.y - cam.unk134.y)
		end

		if ctrl.cup ~= 0 then
			cam.unk128.x = F32(cam.unk128.x + cam.unk134.x)
		end

		if ctrl.cdown ~= 0 then
			cam.unk128.x = F32(cam.unk128.x - cam.unk134.x)
		end

		cam.unk128.x = GdMath.gd_clamp_f32(cam.unk128.x, 80.0)

		const Zoom = cam.zoomPositions[cam.zoomLevel + 1]

		cam.unk4C.x = Zoom.x
		cam.unk4C.y = Zoom.y
		cam.unk4C.z = Zoom.z

		CameraOrbitX[1] = cam.unk4C.y
		CameraOrbitY[1] = cam.unk4C.z
		GdMath.gd_rot_2d_vec(cam.unk128.x, CameraOrbitX, CameraOrbitY)
		cam.unk4C.y = CameraOrbitX[1]
		cam.unk4C.z = CameraOrbitY[1]

		CameraOrbitX[1] = cam.unk4C.x
		CameraOrbitY[1] = cam.unk4C.z
		GdMath.gd_rot_2d_vec(-cam.unk128.y, CameraOrbitX, CameraOrbitY)
		cam.unk4C.x = CameraOrbitX[1]
		cam.unk4C.z = CameraOrbitY[1]

		cam.unk40.x = F32(cam.unk40.x + F32(F32(cam.unk4C.x - cam.unk40.x) * cam.unk17C))
		cam.unk40.y = F32(cam.unk40.y + F32(F32(cam.unk4C.y - cam.unk40.y) * cam.unk17C))
		cam.unk40.z = F32(cam.unk40.z + F32(F32(cam.unk4C.z - cam.unk40.z) * cam.unk17C))
	else
		GdMath.gd_set_identity_mat4(matrix)
	end

	-- The source adds a zero-initialized vector before applying the view transforms.
	pos.x = F32(cam.unk40.x + 0.0)
	pos.y = F32(cam.unk40.y + 0.0)
	pos.z = F32(cam.unk40.z + 0.0)

	GdMath.gd_mult_mat4f(matrix, cam.unkA8, cam.unkA8)
	GdMath.gd_mat4f_mult_vec3f(pos, cam.unkA8)

	cam.worldPos.x = F32(pos.x + attachedPos.x)
	cam.worldPos.y = F32(pos.y + attachedPos.y)
	cam.worldPos.z = F32(pos.z + attachedPos.z)
end

-- from src/goddard/objects.c:move_cameras_in_grp L1962-1964
function objects.move_cameras_in_grp(group: GdTypesH.ObjGroup)
	objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_CAMERAS, objects.move_camera, group)
end

-- from src/goddard/objects.c:func_8018100C L1967-2024
function objects.func_8018100C(light: GdTypesH.ObjLight)
	if light.unk40 == 3 then
		if light.unk30 > 0.0 then
			light.unk30 = F32(light.unk30 - 0.2)
		end

		if light.unk30 < 0.0 then
			light.unk30 = 0.0
		end

		if bit32.btest(light.unk3C, 0x1) then
			light.unk30 = 1.0
		end

		light.unk3C = S32(bit32.band(light.unk3C, bit32.bnot(1)))
	end

	-- if (1)?
	if true then
		return
	end

	-- unreachable
	light.position.x = F32(light.position.x + light.unk80.x)
	light.position.y = F32(light.position.y + light.unk80.y)
	light.position.z = F32(light.position.z + light.unk80.z)

	-- should be position.x for second comparison?
	if light.position.x > 500.0 or light.position.y < -500.0 then
		light.unk80.x = -light.unk80.x
	end

	if light.position.y > 500.0 or light.position.y < -500.0 then
		light.unk80.y = -light.unk80.y
	end

	if light.position.z > 500.0 or light.position.z < -500.0 then
		light.unk80.z = -light.unk80.z
	end

	if true then
		return
	end

	-- more unreachable
	objects.D_801A81C0 = F32(objects.D_801A81C0 + 1.0)
	objects.D_801A81C4 = F32(objects.D_801A81C4 + 0.6)

	GdMath.gd_set_identity_mat4(LightMatrix)
	GdMath.gd_absrot_mat4(LightMatrix, GdMathH.GD_Y_AXIS, light.unk68.y)
	GdMath.gd_absrot_mat4(LightMatrix, GdMathH.GD_X_AXIS, light.unk68.x)
	GdMath.gd_absrot_mat4(LightMatrix, GdMathH.GD_Z_AXIS, light.unk68.z)
	GdMath.gd_mat4f_mult_vec3f(light.unk8C, LightMatrix)

	light.position.x = light.unk8C.x
	light.position.y = light.unk8C.y
	light.position.z = light.unk8C.z

	if true then
		return
	end

	-- even more unreachable
	GdMath.gd_mat4f_mult_vec3f(light.unk80, LightMatrix)
end

-- from src/goddard/objects.c:move_lights_in_grp L2027-2029
function objects.move_lights_in_grp(group: GdTypesH.ObjGroup)
	objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_LIGHTS, objects.func_8018100C, group)
end

-- from src/goddard/objects.c:move_group_members L2032-2047
function objects.move_group_members()
	if GdMain.gGdMoveScene ~= 0 then
		const Group = objects.sCurrentMoveGrp :: GdTypesH.ObjGroup

		Registry.Members.src__goddard__old_menu.reset_gadgets_in_grp(Group)
		objects.move_lights_in_grp(Group)
		Registry.Members.src__goddard__particles.move_particles_in_grp(Group)
		objects.move_animators(Group)

		for Index = 0, 0 do
			Skin.move_nets(Group)
		end

		objects.move_cameras_in_grp(Group)
	end
end

-- from src/goddard/objects.c:proc_view_movement L2050-2061
function objects.proc_view_movement(view: GdTypesH.ObjView)
	objects.sCurrentMoveCamera = view.activeCam
	objects.sCurrentMoveView = view
	objects.sCurrentMoveGrp = view.components

	if objects.sCurrentMoveGrp ~= nil then
		objects.move_group_members()
	end

	objects.sCurrentMoveGrp = view.lights

	if objects.sCurrentMoveGrp ~= nil then
		objects.move_group_members()
	end
end

-- from src/goddard/objects.c:reset_nets_and_gadgets L2064-2067
function objects.reset_nets_and_gadgets(group: GdTypesH.ObjGroup)
	Skin.func_80193848(group)
	objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_GADGETS, Registry.Members.src__goddard__old_menu.reset_gadget, group)
end

-- from src/goddard/objects.c:null_obj_lists L2070-2089
function objects.null_obj_lists()
	objects.D_801B9E44 = 0
	objects.gGdObjCount = 0
	objects.gGdGroupCount = 0
	objects.gGdPlaneCount = 0
	objects.gGdCameraCount = 0
	objects.sGdViewInfo.count = 0

	objects.gGdCameraList = nil
	objects.D_801B9E50 = nil
	objects.gGdBoneList = nil
	objects.gGdJointList = nil
	objects.gGdGroupList = nil
	objects.D_801B9E80 = nil
	objects.gGdObjectList = nil
	objects.gGdViewsGroup = nil

	Skin.reset_net_count()
	Registry.Members.src__goddard__joints.reset_joint_counts()
end

return objects
