--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_types.h.
]]

-- from src/goddard/gd_types.h:GdVec3f
export type GdVec3f = {
	x: number,
	y: number,
	z: number,
}

-- from src/goddard/gd_types.h:GdBoundingBox
export type GdBoundingBox = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

-- from src/goddard/gd_types.h:GdTriangleF
export type GdTriangleF = {
	p0: GdVec3f, -- first member: this table itself
	x: number,
	y: number,
	z: number,
	p1: GdVec3f,
	p2: GdVec3f,
}

-- from src/goddard/gd_types.h:GdAnimTransform
export type GdAnimTransform = {
	scale: GdVec3f, -- first member: this table itself
	x: number,
	y: number,
	z: number,
	rotate: GdVec3f,
	pos: GdVec3f,
}

-- from src/goddard/gd_types.h:GdColour
export type GdColour = {
	r: number,
	g: number,
	b: number,
}

-- from src/goddard/gd_types.h:DynUnion
-- union: the fields are views of the same storage in C; decide how they alias
export type DynUnion = {
	ptr: unknown,
	str: string?,
	word: number,
}

-- from src/goddard/gd_types.h:DynList
export type DynList = {
	cmd: number,
	w1: DynUnion,
	w2: DynUnion,
	vec: GdVec3f,
}

-- from src/goddard/gd_types.h:GdObj
export type GdObj = {
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
}

-- from src/goddard/gd_types.h:ListNode
export type ListNode = {
	prev: ListNode?,
	next: ListNode?,
	obj: GdObj?,
}

-- from src/goddard/gd_types.h:VtxLink
export type VtxLink = {
	prev: VtxLink?,
	next: VtxLink?,
	data: number?,
}

-- from src/goddard/gd_types.h:GdFaceData
export type GdFaceData = {
	count: number,
	type_: number,
	data: { { number } }, -- [4]
}

-- from src/goddard/gd_types.h:GdVtxData
export type GdVtxData = {
	count: number,
	type_: number,
	data: { { number } }, -- [3]
}

-- from src/goddard/gd_types.h:ObjGroup
export type ObjGroup = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	ObjGroup_prev: ObjGroup?, -- prev in the source
	ObjGroup_next: ObjGroup?, -- next in the source
	firstMember: ListNode?,
	lastMember: ListNode?,
	memberTypes: number,
	memberCount: number,
	debugPrint: number,
	linkType: number,
	name: buffer, -- [64]
	id: number,
}

-- from src/goddard/gd_types.h:ObjBone
export type ObjBone = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	worldPos: GdVec3f,
	ObjBone_prev: ObjBone?, -- prev in the source
	ObjBone_next: ObjBone?, -- next in the source
	unk28: GdVec3f,
	filler1: buffer, -- [12]
	unk40: GdVec3f,
	filler2: buffer, -- [12]
	unk58: GdVec3f,
	unk64: GdVec3f,
	mat70: { { number } },
	matB0: { { number } },
	shapePtr: ObjShape?,
	unkF4: number,
	unkF8: number,
	unkFC: number,
	colourNum: number,
	unk104: number,
	id: number,
	unk10C: ObjGroup?,
	spring: number,
	unk114: number,
	unk118: number,
	filler3: buffer, -- [8]
}

-- from src/goddard/gd_types.h:ObjJoint
export type ObjJoint = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	worldPos: GdVec3f,
	shapePtr: ObjShape?,
	prevjoint: ObjJoint?,
	nextjoint: ObjJoint?,
	updateFunc: ((ObjJoint) -> ())?,
	unk30: GdVec3f,
	unk3C: GdVec3f,
	unk48: GdVec3f,
	initPos: GdVec3f,
	filler1: buffer, -- [12]
	unk6C: GdVec3f,
	velocity: GdVec3f,
	unk84: GdVec3f,
	unk90: GdVec3f,
	scale: GdVec3f,
	unkA8: GdVec3f,
	unkB4: GdVec3f,
	shapeOffset: GdVec3f,
	unkCC: GdVec3f,
	filler2: buffer, -- [4]
	friction: GdVec3f,
	matE8: { { number } },
	mat128: { { number } },
	mat168: { { number } },
	unk1A8: GdVec3f,
	id: number,
	filler3: buffer, -- [4]
	flags: number,
	unk1C0: number,
	unk1C4: ObjGroup?,
	colourNum: number,
	ObjJoint_type: number, -- type in the source
	rootAnimator: ObjAnimator?,
	filler4: buffer, -- [32]
	weightGrp: ObjGroup?,
	attachedObjsGrp: ObjGroup?,
	attachFlags: number,
	attachOffset: GdVec3f,
	attachedToObj: GdObj?,
	filler5: buffer, -- [24]
	unk228: number,
}

-- from src/goddard/gd_types.h:ObjParticle
export type ObjParticle = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler1: buffer, -- [8]
	shapePtr: ObjShape?,
	pos: GdVec3f,
	filler2: buffer, -- [4]
	unk30: number,
	filler3: buffer, -- [4]
	unk38: GdVec3f,
	unk44: number,
	unk48: number,
	filler4: buffer, -- [4]
	id: number,
	flags: number,
	colourNum: number,
	timeout: number,
	unk60: number,
	unk64: number,
	filler5: buffer, -- [4]
	subParticlesGrp: ObjGroup?,
	filler6: buffer, -- [4]
	unk74: number,
	unk78: buffer, -- [4]
	unk7C: ObjAnimator?,
	unk80: ObjLight?,
	filler7: buffer, -- [44]
	unkB0: number,
	attachedObjsGrp: ObjGroup?,
	attachFlags: number,
	attachedToObj: GdObj?,
}

-- from src/goddard/gd_types.h:ObjShape
export type ObjShape = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	prevShape: ObjShape?,
	nextShape: ObjShape?,
	faceGroup: ObjGroup?,
	vtxGroup: ObjGroup?,
	scaledVtxGroup: ObjGroup?,
	filler1: buffer, -- [4]
	mtlGroup: ObjGroup?,
	unk30: number,
	faceCount: number,
	vtxCount: number,
	unk3C: number,
	id: number,
	flag: number,
	dlNums: { number }, -- [2]
	unk50: number,
	filler2: buffer, -- [4]
	alpha: number,
	name: buffer, -- [64]
}

-- from src/goddard/gd_types.h:ObjNet
export type ObjNet = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	worldPos: GdVec3f,
	initPos: GdVec3f,
	filler1: buffer, -- [8]
	flags: number,
	id: number,
	unk3C: number,
	colourNum: number,
	unusedForce: GdVec3f,
	velocity: GdVec3f,
	rotation: GdVec3f,
	unk68: GdVec3f,
	collDisp: GdVec3f,
	collTorque: GdVec3f,
	unusedCollTorqueL: GdVec3f,
	unusedCollTorqueD: GdVec3f,
	torque: GdVec3f,
	centerOfGravity: GdVec3f,
	boundingBox: GdBoundingBox,
	unusedCollDispOff: GdVec3f,
	unusedCollMaxD: number,
	maxRadius: number,
	matE8: { { number } },
	mat128: { { number } },
	mat168: { { number } },
	shapePtr: ObjShape?,
	scale: GdVec3f,
	unusedMass: number,
	numModes: number,
	unk1C0: ObjGroup?,
	skinGrp: ObjGroup?,
	unk1C8: ObjGroup?,
	unk1CC: ObjGroup?,
	unk1D0: ObjGroup?,
	attachedObjsGrp: ObjGroup?,
	attachOffset: GdVec3f,
	attachFlags: number,
	attachedToObj: GdObj?,
	netType: number,
	unk1F0: ObjNet?,
	unk1F4: GdVec3f,
	unk200: GdVec3f,
	unk20C: ObjGroup?,
	ctrlType: number,
	filler2: buffer, -- [8]
	unk21C: ObjGroup?,
}

-- from src/goddard/gd_types.h:ObjPlane
export type ObjPlane = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	id: number,
	unk18: number,
	unk1C: number,
	unk20: number,
	unk24: number,
	boundingBox: GdBoundingBox,
	unk40: ObjFace?,
}

-- from src/goddard/gd_types.h:ObjVertex
export type ObjVertex = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	initPos: GdVec3f,
	pos: GdVec3f,
	normal: GdVec3f,
	id: number,
	scaleFactor: number,
	alpha: number,
	gbiVerts: VtxLink?,
}

-- from src/goddard/gd_types.h:ObjFace
export type ObjFace = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	colour: GdColour,
	colourNum: number,
	normal: GdVec3f,
	vtxCount: number,
	vertices: { ObjVertex? }, -- [4]
	mtlId: number,
	mtl: ObjMaterial?,
}

-- from src/goddard/gd_types.h:ObjCamera
export type ObjCamera = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	worldPos: GdVec3f,
	ObjCamera_prev: ObjCamera?, -- prev in the source
	ObjCamera_next: ObjCamera?, -- next in the source
	id: number,
	flags: number,
	unk30: GdObj?,
	lookAt: GdVec3f,
	unk40: GdVec3f,
	unk4C: GdVec3f,
	unk58: number,
	filler: buffer, -- [4]
	unk60: number,
	unk64: { { number } },
	unkA4: number,
	unkA8: { { number } },
	unkE8: { { number } },
	unk128: GdVec3f,
	unk134: GdVec3f,
	zoomPositions: { GdVec3f }, -- [4]
	maxZoomLevel: number,
	zoomLevel: number,
	unk178: number,
	unk17C: number,
	unk180: GdVec3f,
	unk18C: ObjView?,
}

-- from src/goddard/gd_types.h:ObjMaterial
export type ObjMaterial = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler1: buffer, -- [8]
	id: number,
	name: buffer, -- [8]
	ObjMaterial_type: number, -- type in the source
	filler2: buffer, -- [4]
	Ka: GdColour,
	Kd: GdColour,
	filler3: buffer, -- [16]
	texture: unknown,
	gddlNumber: number,
}

-- from src/goddard/gd_types.h:ObjWeight
export type ObjWeight = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler1: buffer, -- [8]
	vtxId: number,
	vec20: GdVec3f,
	filler2: buffer, -- [12]
	weightVal: number,
	vtx: ObjVertex?,
}

-- from src/goddard/gd_types.h:ObjVarVal
-- union: the fields are views of the same storage in C; decide how they alias
export type ObjVarVal = {
	i: number,
	f: number,
	l: number,
}

-- from src/goddard/gd_types.h:ObjGadget
export type ObjGadget = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	worldPos: GdVec3f,
	unk20: number,
	ObjGadget_type: number, -- type in the source
	sliderPos: number,
	filler1: buffer, -- [4]
	varval: ObjVarVal,
	rangeMin: number,
	rangeMax: number,
	size: GdVec3f,
	valueGrp: ObjGroup?,
	shapePtr: ObjShape?,
	unk54: ObjGroup?,
	filler2: buffer, -- [4]
	colourNum: number,
}

-- from src/goddard/gd_types.h:ObjView
export type ObjView = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler1: buffer, -- [8]
	unk1C: number,
	id: number,
	activeCam: ObjCamera?,
	components: ObjGroup?,
	lights: ObjGroup?,
	pickedObj: GdObj?,
	flags: number,
	projectionType: number,
	upperLeft: GdVec3f,
	unk48: number,
	unk4C: number,
	filler2: buffer, -- [4]
	lowerRight: GdVec3f,
	clipping: GdVec3f,
	namePtr: string?,
	gdDlNum: number,
	unk74: number,
	unk78: number,
	colour: GdColour,
	parent: ObjView?,
	zbuf: number?,
	colourBufs: { number? }, -- [2]
	proc: ((ObjView) -> ())?,
	unk9C: number,
}

-- from src/goddard/gd_types.h:ObjLabel
export type ObjLabel = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	position: GdVec3f,
	fmtstr: string?,
	unk24: number,
	valptr: ObjValPtr?,
	valfn: ((ObjVarVal, ObjVarVal) -> ObjVarVal)?,
	unk30: number,
}

-- from src/goddard/gd_types.h:ObjAnimator
export type ObjAnimator = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	animatedPartsGrp: ObjGroup?,
	animdataGrp: ObjGroup?,
	filler1: buffer, -- [4]
	animSeqNum: number,
	unk24: number,
	frame: number,
	filler2: buffer, -- [4]
	attachedObjsGrp: ObjGroup?,
	attachFlags: number,
	filler3: buffer, -- [12]
	attachedToObj: GdObj?,
	controlFunc: ((ObjAnimator) -> ())?,
	state: number,
	nods: number,
	stillTimer: number,
}

-- from src/goddard/gd_types.h:AnimDataInfo
export type AnimDataInfo = {
	count: number,
	type_: number,
	data: unknown,
}

-- from src/goddard/gd_types.h:AnimMtxVec
export type AnimMtxVec = {
	matrix: { { number } },
	vec: GdVec3f,
}

-- from src/goddard/gd_types.h:ObjValPtr
export type ObjValPtr = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	obj: GdObj?,
	offset: number,
	datatype: number,
	flag: number,
}

-- from src/goddard/gd_types.h:ObjLight
export type ObjLight = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler1: buffer, -- [8]
	id: number,
	name: buffer, -- [8]
	filler2: buffer, -- [4]
	flags: number,
	unk30: number,
	filler3: buffer, -- [4]
	unk38: number,
	unk3C: number,
	unk40: number,
	filler4: buffer, -- [8]
	unk4C: number,
	diffuse: GdColour,
	colour: GdColour,
	unk68: GdVec3f,
	position: GdVec3f,
	unk80: GdVec3f,
	unk8C: GdVec3f,
	unk98: number,
	unk9C: ObjShape?,
}

-- from src/goddard/gd_types.h:ObjZone
export type ObjZone = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	boundingBox: GdBoundingBox,
	unk2C: ObjGroup?,
	unk30: ObjGroup?,
	filler: buffer, -- [4]
}

-- from src/goddard/gd_types.h:ObjUnk200000
export type ObjUnk200000 = {
	header: GdObj, -- first member: this table itself
	prev: GdObj?,
	next: GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler: buffer, -- [28]
	unk30: ObjVertex?,
	unk34: ObjFace?,
}

-- from src/goddard/gd_types.h:data
const gd_types_h = {
	OBJ_TYPE_GROUPS = 1,
	OBJ_TYPE_BONES = 2,
	OBJ_TYPE_JOINTS = 4,
	OBJ_TYPE_PARTICLES = 8,
	OBJ_TYPE_SHAPES = 16,
	OBJ_TYPE_NETS = 32,
	OBJ_TYPE_PLANES = 64,
	OBJ_TYPE_FACES = 128,
	OBJ_TYPE_VERTICES = 256,
	OBJ_TYPE_CAMERAS = 512,
	OBJ_TYPE_MATERIALS = 2048,
	OBJ_TYPE_WEIGHTS = 4096,
	OBJ_TYPE_GADGETS = 8192,
	OBJ_TYPE_VIEWS = 16384,
	OBJ_TYPE_LABELS = 32768,
	OBJ_TYPE_ANIMATORS = 65536,
	OBJ_TYPE_VALPTRS = 131072,
	OBJ_TYPE_LIGHTS = 524288,
	OBJ_TYPE_ZONES = 1048576,
	OBJ_TYPE_UNK200000 = 2097152,
	OBJ_TYPE_ALL = 0x00FFFFFF,
	OBJ_DRAW_UNK01 = 1,
	OBJ_INVISIBLE = 2,
	OBJ_PICKED = 4,
	OBJ_IS_GRABBABLE = 8,
	OBJ_HIGHLIGHTED = 16,
	CAMERA_FLAG_CONTROLLABLE = 0x4,
	GD_MTL_STUB_DL = 1,
	GD_MTL_BREAK = 4,
	GD_MTL_SHINE_DL = 16,
	GD_MTL_TEX_OFF = 32,
	GD_MTL_LIGHTS = 64,
	VIEW_2_COL_BUF = 8,
	VIEW_ALLOC_ZBUF = 16,
	VIEW_SAVE_TO_GLOBAL = 64,
	VIEW_DEFAULT_PARENT = 256,
	VIEW_BORDERED = 1024,
	VIEW_UPDATE = 2048,
	VIEW_UNK_1000 = 4096,
	VIEW_UNK_2000 = 8192,
	VIEW_UNK_4000 = 16384,
	VIEW_COLOUR_BUF = 32768,
	VIEW_Z_BUF = 65536,
	VIEW_1_CYCLE = 131072,
	VIEW_MOVEMENT = 262144,
	VIEW_DRAW = 524288,
	VIEW_WAS_UPDATED = 1048576,
	VIEW_LIGHT = 2097152,
	GD_ANIM_EMPTY = 0,
	GD_ANIM_MTX4x4 = 1,
	GD_ANIM_SCALE3F_ROT3F_POS3F = 2,
	GD_ANIM_SCALE3S_POS3S_ROT3S = 3,
	GD_ANIM_SCALE3F_ROT3F_POS3F_2 = 4,
	GD_ANIM_STUB = 5,
	GD_ANIM_ROT3S = 6,
	GD_ANIM_POS3S = 7,
	GD_ANIM_ROT3S_POS3S = 8,
	GD_ANIM_MTX4x4F_SCALE3F = 9,
	GD_ANIM_CAMERA_EYE3S_LOOKAT3S = 11,
	OBJ_VALUE_INT = 1,
	OBJ_VALUE_FLOAT = 2,
	LIGHT_UNK02 = 2,
	LIGHT_NEW_UNCOUNTED = 16,
	LIGHT_UNK20 = 32,
}

-- from src/goddard/gd_types.h:GdVec3f (zero-filled constructor)
function gd_types_h.new_GdVec3f(): GdVec3f
	return { x = 0, y = 0, z = 0 } :: GdVec3f
end

-- from src/goddard/gd_types.h:GdBoundingBox (zero-filled constructor)
function gd_types_h.new_GdBoundingBox(): GdBoundingBox
	return { minX = 0, minY = 0, minZ = 0, maxX = 0, maxY = 0, maxZ = 0 } :: GdBoundingBox
end

-- from src/goddard/gd_types.h:GdTriangleF (zero-filled constructor)
function gd_types_h.new_GdTriangleF(): GdTriangleF
	const Result = {
		x = 0,
		y = 0,
		z = 0,
		p1 = { x = 0, y = 0, z = 0 },
		p2 = { x = 0, y = 0, z = 0 },
		p0 = nil :: unknown,
	} :: GdTriangleF

	Result.p0 = Result

	return Result
end

-- from src/goddard/gd_types.h:GdAnimTransform (zero-filled constructor)
function gd_types_h.new_GdAnimTransform(): GdAnimTransform
	const Result = {
		x = 0,
		y = 0,
		z = 0,
		rotate = { x = 0, y = 0, z = 0 },
		pos = { x = 0, y = 0, z = 0 },
		scale = nil :: unknown,
	} :: GdAnimTransform

	Result.scale = Result

	return Result
end

-- from src/goddard/gd_types.h:GdColour (zero-filled constructor)
function gd_types_h.new_GdColour(): GdColour
	return { r = 0, g = 0, b = 0 } :: GdColour
end

-- from src/goddard/gd_types.h:DynList (zero-filled constructor)
function gd_types_h.new_DynList(): DynList
	return { cmd = 0, w1 = { ptr = nil }, w2 = { ptr = nil }, vec = { x = 0, y = 0, z = 0 } } :: DynList
end

-- from src/goddard/gd_types.h:GdObj (zero-filled constructor)
function gd_types_h.new_GdObj(): GdObj
	return { prev = nil, next = nil, objDrawFn = nil, type_ = 0, index = 0, drawFlags = 0 } :: GdObj
end

-- from src/goddard/gd_types.h:ListNode (zero-filled constructor)
function gd_types_h.new_ListNode(): ListNode
	return { prev = nil, next = nil, obj = nil } :: ListNode
end

-- from src/goddard/gd_types.h:VtxLink (zero-filled constructor)
function gd_types_h.new_VtxLink(): VtxLink
	return { prev = nil, next = nil, data = nil } :: VtxLink
end

-- from src/goddard/gd_types.h:GdFaceData (zero-filled constructor)
function gd_types_h.new_GdFaceData(): GdFaceData
	return { count = 0, type_ = 0, data = { nil, nil, nil, nil } } :: GdFaceData
end

-- from src/goddard/gd_types.h:GdVtxData (zero-filled constructor)
function gd_types_h.new_GdVtxData(): GdVtxData
	return { count = 0, type_ = 0, data = { nil, nil, nil } } :: GdVtxData
end

-- from src/goddard/gd_types.h:ObjGroup (zero-filled constructor)
function gd_types_h.new_ObjGroup(): ObjGroup
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		ObjGroup_prev = nil,
		ObjGroup_next = nil,
		firstMember = nil,
		lastMember = nil,
		memberTypes = 0,
		memberCount = 0,
		debugPrint = 0,
		linkType = 0,
		name = buffer.create(64),
		id = 0,
		header = nil :: unknown,
	} :: ObjGroup

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjBone (zero-filled constructor)
function gd_types_h.new_ObjBone(): ObjBone
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		worldPos = { x = 0, y = 0, z = 0 },
		ObjBone_prev = nil,
		ObjBone_next = nil,
		unk28 = { x = 0, y = 0, z = 0 },
		filler1 = buffer.create(12),
		unk40 = { x = 0, y = 0, z = 0 },
		filler2 = buffer.create(12),
		unk58 = { x = 0, y = 0, z = 0 },
		unk64 = { x = 0, y = 0, z = 0 },
		mat70 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		matB0 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		shapePtr = nil,
		unkF4 = 0,
		unkF8 = 0,
		unkFC = 0,
		colourNum = 0,
		unk104 = 0,
		id = 0,
		unk10C = nil,
		spring = 0,
		unk114 = 0,
		unk118 = 0,
		filler3 = buffer.create(8),
		header = nil :: unknown,
	} :: ObjBone

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjJoint (zero-filled constructor)
function gd_types_h.new_ObjJoint(): ObjJoint
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		worldPos = { x = 0, y = 0, z = 0 },
		shapePtr = nil,
		prevjoint = nil,
		nextjoint = nil,
		updateFunc = nil,
		unk30 = { x = 0, y = 0, z = 0 },
		unk3C = { x = 0, y = 0, z = 0 },
		unk48 = { x = 0, y = 0, z = 0 },
		initPos = { x = 0, y = 0, z = 0 },
		filler1 = buffer.create(12),
		unk6C = { x = 0, y = 0, z = 0 },
		velocity = { x = 0, y = 0, z = 0 },
		unk84 = { x = 0, y = 0, z = 0 },
		unk90 = { x = 0, y = 0, z = 0 },
		scale = { x = 0, y = 0, z = 0 },
		unkA8 = { x = 0, y = 0, z = 0 },
		unkB4 = { x = 0, y = 0, z = 0 },
		shapeOffset = { x = 0, y = 0, z = 0 },
		unkCC = { x = 0, y = 0, z = 0 },
		filler2 = buffer.create(4),
		friction = { x = 0, y = 0, z = 0 },
		matE8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		mat128 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		mat168 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		unk1A8 = { x = 0, y = 0, z = 0 },
		id = 0,
		filler3 = buffer.create(4),
		flags = 0,
		unk1C0 = 0,
		unk1C4 = nil,
		colourNum = 0,
		ObjJoint_type = 0,
		rootAnimator = nil,
		filler4 = buffer.create(32),
		weightGrp = nil,
		attachedObjsGrp = nil,
		attachFlags = 0,
		attachOffset = { x = 0, y = 0, z = 0 },
		attachedToObj = nil,
		filler5 = buffer.create(24),
		unk228 = 0,
		header = nil :: unknown,
	} :: ObjJoint

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjParticle (zero-filled constructor)
function gd_types_h.new_ObjParticle(): ObjParticle
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler1 = buffer.create(8),
		shapePtr = nil,
		pos = { x = 0, y = 0, z = 0 },
		filler2 = buffer.create(4),
		unk30 = 0,
		filler3 = buffer.create(4),
		unk38 = { x = 0, y = 0, z = 0 },
		unk44 = 0,
		unk48 = 0,
		filler4 = buffer.create(4),
		id = 0,
		flags = 0,
		colourNum = 0,
		timeout = 0,
		unk60 = 0,
		unk64 = 0,
		filler5 = buffer.create(4),
		subParticlesGrp = nil,
		filler6 = buffer.create(4),
		unk74 = 0,
		unk78 = buffer.create(4),
		unk7C = nil,
		unk80 = nil,
		filler7 = buffer.create(44),
		unkB0 = 0,
		attachedObjsGrp = nil,
		attachFlags = 0,
		attachedToObj = nil,
		header = nil :: unknown,
	} :: ObjParticle

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjShape (zero-filled constructor)
function gd_types_h.new_ObjShape(): ObjShape
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		prevShape = nil,
		nextShape = nil,
		faceGroup = nil,
		vtxGroup = nil,
		scaledVtxGroup = nil,
		filler1 = buffer.create(4),
		mtlGroup = nil,
		unk30 = 0,
		faceCount = 0,
		vtxCount = 0,
		unk3C = 0,
		id = 0,
		flag = 0,
		dlNums = table.create(2, 0),
		unk50 = 0,
		filler2 = buffer.create(4),
		alpha = 0,
		name = buffer.create(64),
		header = nil :: unknown,
	} :: ObjShape

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjNet (zero-filled constructor)
function gd_types_h.new_ObjNet(): ObjNet
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		worldPos = { x = 0, y = 0, z = 0 },
		initPos = { x = 0, y = 0, z = 0 },
		filler1 = buffer.create(8),
		flags = 0,
		id = 0,
		unk3C = 0,
		colourNum = 0,
		unusedForce = { x = 0, y = 0, z = 0 },
		velocity = { x = 0, y = 0, z = 0 },
		rotation = { x = 0, y = 0, z = 0 },
		unk68 = { x = 0, y = 0, z = 0 },
		collDisp = { x = 0, y = 0, z = 0 },
		collTorque = { x = 0, y = 0, z = 0 },
		unusedCollTorqueL = { x = 0, y = 0, z = 0 },
		unusedCollTorqueD = { x = 0, y = 0, z = 0 },
		torque = { x = 0, y = 0, z = 0 },
		centerOfGravity = { x = 0, y = 0, z = 0 },
		boundingBox = { minX = 0, minY = 0, minZ = 0, maxX = 0, maxY = 0, maxZ = 0 },
		unusedCollDispOff = { x = 0, y = 0, z = 0 },
		unusedCollMaxD = 0,
		maxRadius = 0,
		matE8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		mat128 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		mat168 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		shapePtr = nil,
		scale = { x = 0, y = 0, z = 0 },
		unusedMass = 0,
		numModes = 0,
		unk1C0 = nil,
		skinGrp = nil,
		unk1C8 = nil,
		unk1CC = nil,
		unk1D0 = nil,
		attachedObjsGrp = nil,
		attachOffset = { x = 0, y = 0, z = 0 },
		attachFlags = 0,
		attachedToObj = nil,
		netType = 0,
		unk1F0 = nil,
		unk1F4 = { x = 0, y = 0, z = 0 },
		unk200 = { x = 0, y = 0, z = 0 },
		unk20C = nil,
		ctrlType = 0,
		filler2 = buffer.create(8),
		unk21C = nil,
		header = nil :: unknown,
	} :: ObjNet

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjPlane (zero-filled constructor)
function gd_types_h.new_ObjPlane(): ObjPlane
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		id = 0,
		unk18 = 0,
		unk1C = 0,
		unk20 = 0,
		unk24 = 0,
		boundingBox = { minX = 0, minY = 0, minZ = 0, maxX = 0, maxY = 0, maxZ = 0 },
		unk40 = nil,
		header = nil :: unknown,
	} :: ObjPlane

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjVertex (zero-filled constructor)
function gd_types_h.new_ObjVertex(): ObjVertex
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		initPos = { x = 0, y = 0, z = 0 },
		pos = { x = 0, y = 0, z = 0 },
		normal = { x = 0, y = 0, z = 0 },
		id = 0,
		scaleFactor = 0,
		alpha = 0,
		gbiVerts = nil,
		header = nil :: unknown,
	} :: ObjVertex

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjFace (zero-filled constructor)
function gd_types_h.new_ObjFace(): ObjFace
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		colour = { r = 0, g = 0, b = 0 },
		colourNum = 0,
		normal = { x = 0, y = 0, z = 0 },
		vtxCount = 0,
		vertices = { nil, nil, nil, nil },
		mtlId = 0,
		mtl = nil,
		header = nil :: unknown,
	} :: ObjFace

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjCamera (zero-filled constructor)
function gd_types_h.new_ObjCamera(): ObjCamera
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		worldPos = { x = 0, y = 0, z = 0 },
		ObjCamera_prev = nil,
		ObjCamera_next = nil,
		id = 0,
		flags = 0,
		unk30 = nil,
		lookAt = { x = 0, y = 0, z = 0 },
		unk40 = { x = 0, y = 0, z = 0 },
		unk4C = { x = 0, y = 0, z = 0 },
		unk58 = 0,
		filler = buffer.create(4),
		unk60 = 0,
		unk64 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		unkA4 = 0,
		unkA8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		unkE8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		unk128 = { x = 0, y = 0, z = 0 },
		unk134 = { x = 0, y = 0, z = 0 },
		zoomPositions = {
			{ x = 0, y = 0, z = 0 },
			{ x = 0, y = 0, z = 0 },
			{ x = 0, y = 0, z = 0 },
			{ x = 0, y = 0, z = 0 },
		},
		maxZoomLevel = 0,
		zoomLevel = 0,
		unk178 = 0,
		unk17C = 0,
		unk180 = { x = 0, y = 0, z = 0 },
		unk18C = nil,
		header = nil :: unknown,
	} :: ObjCamera

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjMaterial (zero-filled constructor)
function gd_types_h.new_ObjMaterial(): ObjMaterial
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler1 = buffer.create(8),
		id = 0,
		name = buffer.create(8),
		ObjMaterial_type = 0,
		filler2 = buffer.create(4),
		Ka = { r = 0, g = 0, b = 0 },
		Kd = { r = 0, g = 0, b = 0 },
		filler3 = buffer.create(16),
		texture = nil,
		gddlNumber = 0,
		header = nil :: unknown,
	} :: ObjMaterial

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjWeight (zero-filled constructor)
function gd_types_h.new_ObjWeight(): ObjWeight
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler1 = buffer.create(8),
		vtxId = 0,
		vec20 = { x = 0, y = 0, z = 0 },
		filler2 = buffer.create(12),
		weightVal = 0,
		vtx = nil,
		header = nil :: unknown,
	} :: ObjWeight

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjGadget (zero-filled constructor)
function gd_types_h.new_ObjGadget(): ObjGadget
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		worldPos = { x = 0, y = 0, z = 0 },
		unk20 = 0,
		ObjGadget_type = 0,
		sliderPos = 0,
		filler1 = buffer.create(4),
		varval = { i = 0 },
		rangeMin = 0,
		rangeMax = 0,
		size = { x = 0, y = 0, z = 0 },
		valueGrp = nil,
		shapePtr = nil,
		unk54 = nil,
		filler2 = buffer.create(4),
		colourNum = 0,
		header = nil :: unknown,
	} :: ObjGadget

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjView (zero-filled constructor)
function gd_types_h.new_ObjView(): ObjView
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler1 = buffer.create(8),
		unk1C = 0,
		id = 0,
		activeCam = nil,
		components = nil,
		lights = nil,
		pickedObj = nil,
		flags = 0,
		projectionType = 0,
		upperLeft = { x = 0, y = 0, z = 0 },
		unk48 = 0,
		unk4C = 0,
		filler2 = buffer.create(4),
		lowerRight = { x = 0, y = 0, z = 0 },
		clipping = { x = 0, y = 0, z = 0 },
		namePtr = nil,
		gdDlNum = 0,
		unk74 = 0,
		unk78 = 0,
		colour = { r = 0, g = 0, b = 0 },
		parent = nil,
		zbuf = nil,
		colourBufs = {},
		proc = nil,
		unk9C = 0,
		header = nil :: unknown,
	} :: ObjView

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjLabel (zero-filled constructor)
function gd_types_h.new_ObjLabel(): ObjLabel
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		position = { x = 0, y = 0, z = 0 },
		fmtstr = nil,
		unk24 = 0,
		valptr = nil,
		valfn = nil,
		unk30 = 0,
		header = nil :: unknown,
	} :: ObjLabel

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjAnimator (zero-filled constructor)
function gd_types_h.new_ObjAnimator(): ObjAnimator
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		animatedPartsGrp = nil,
		animdataGrp = nil,
		filler1 = buffer.create(4),
		animSeqNum = 0,
		unk24 = 0,
		frame = 0,
		filler2 = buffer.create(4),
		attachedObjsGrp = nil,
		attachFlags = 0,
		filler3 = buffer.create(12),
		attachedToObj = nil,
		controlFunc = nil,
		state = 0,
		nods = 0,
		stillTimer = 0,
		header = nil :: unknown,
	} :: ObjAnimator

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:AnimDataInfo (zero-filled constructor)
function gd_types_h.new_AnimDataInfo(): AnimDataInfo
	return { count = 0, type_ = 0, data = nil } :: AnimDataInfo
end

-- from src/goddard/gd_types.h:AnimMtxVec (zero-filled constructor)
function gd_types_h.new_AnimMtxVec(): AnimMtxVec
	return {
		matrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		vec = { x = 0, y = 0, z = 0 },
	} :: AnimMtxVec
end

-- from src/goddard/gd_types.h:ObjValPtr (zero-filled constructor)
function gd_types_h.new_ObjValPtr(): ObjValPtr
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		obj = nil,
		offset = 0,
		datatype = 0,
		flag = 0,
		header = nil :: unknown,
	} :: ObjValPtr

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjLight (zero-filled constructor)
function gd_types_h.new_ObjLight(): ObjLight
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler1 = buffer.create(8),
		id = 0,
		name = buffer.create(8),
		filler2 = buffer.create(4),
		flags = 0,
		unk30 = 0,
		filler3 = buffer.create(4),
		unk38 = 0,
		unk3C = 0,
		unk40 = 0,
		filler4 = buffer.create(8),
		unk4C = 0,
		diffuse = { r = 0, g = 0, b = 0 },
		colour = { r = 0, g = 0, b = 0 },
		unk68 = { x = 0, y = 0, z = 0 },
		position = { x = 0, y = 0, z = 0 },
		unk80 = { x = 0, y = 0, z = 0 },
		unk8C = { x = 0, y = 0, z = 0 },
		unk98 = 0,
		unk9C = nil,
		header = nil :: unknown,
	} :: ObjLight

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjZone (zero-filled constructor)
function gd_types_h.new_ObjZone(): ObjZone
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		boundingBox = { minX = 0, minY = 0, minZ = 0, maxX = 0, maxY = 0, maxZ = 0 },
		unk2C = nil,
		unk30 = nil,
		filler = buffer.create(4),
		header = nil :: unknown,
	} :: ObjZone

	Result.header = Result

	return Result
end

-- from src/goddard/gd_types.h:ObjUnk200000 (zero-filled constructor)
function gd_types_h.new_ObjUnk200000(): ObjUnk200000
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler = buffer.create(28),
		unk30 = nil,
		unk34 = nil,
		header = nil :: unknown,
	} :: ObjUnk200000

	Result.header = Result

	return Result
end

return gd_types_h
