--!strict
--!optimize 2

--[[
	Port of include/types.h, src/engine/graph_node.h, src/game/area.h, src/game/camera.h.
]]

const IncludePROsContH = require("../include/PR/os_cont_h")
const IncludePROsMessageH = require("../include/PR/os_message_h")

const SrcGameMemoryH = require("../src/game/memory_h")
const SrcGameObjectHelpersH = require("../src/game/object_helpers_h")

-- from include/types.h:Controller
export type Controller = {
	rawStickX: number,
	rawStickY: number,
	stickX: number,
	stickY: number,
	stickMag: number,
	buttonDown: number,
	buttonPressed: number,
	statusData: IncludePROsContH.OSContStatus?,
	controllerData: IncludePROsContH.OSContPad?,
}

-- from include/types.h:SPTask
export type SPTask = {
	task: unknown,
	msgqueue: IncludePROsMessageH.OSMesgQueue_s?,
	msg: unknown,
	state: number,
}

-- from include/types.h:VblankHandler
export type VblankHandler = {
	queue: IncludePROsMessageH.OSMesgQueue_s?,
	msg: unknown,
}

-- from include/types.h:Animation
export type Animation = {
	flags: number,
	animYTransDivisor: number,
	startFrame: number,
	loopStart: number,
	loopEnd: number,
	unusedBoneCount: number,
	values: { number }?,
	index: { number }?,
	length: number,
}

-- from include/types.h:GraphNode
export type GraphNode = {
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
}

-- from include/types.h:AnimInfo
export type AnimInfo = {
	animID: number,
	animYTrans: number,
	curAnim: number?,
	animFrame: number,
	animTimer: number,
	animFrameAccelAssist: number,
	animAccel: number,
}

-- from include/types.h:GraphNodeObject
export type GraphNodeObject = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	sharedChild: GraphNode?,
	areaIndex: number,
	activeAreaIndex: number,
	angle: { number },
	pos: { number },
	scale: { number },
	animInfo: AnimInfo,
	unk4C: SpawnInfo?,
	throwMatrix: { { { number } } }?,
	cameraToObject: { number },
}

-- from include/types.h:ObjectNode
export type ObjectNode = {
	gfx: GraphNodeObject, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	sharedChild: GraphNode?,
	areaIndex: number,
	activeAreaIndex: number,
	angle: { number },
	pos: { number },
	scale: { number },
	animInfo: AnimInfo,
	unk4C: SpawnInfo?,
	throwMatrix: { { { number } } }?,
	cameraToObject: { number },
	ObjectNode_next: ObjectNode?, -- next in the source
	ObjectNode_prev: ObjectNode?, -- prev in the source
}

-- from include/types.h:Object_rawData
-- union: the fields are views of the same storage in C; decide how they alias
export type Object_rawData = {
	asU32: { number }, -- [80]
	asS32: { number }, -- [80]
	asS16: { { number } }, -- [80][2]
	asF32: { number }, -- [80]
}

-- from include/types.h:Object_ptrData
-- union: the fields are views of the same storage in C; decide how they alias
export type Object_ptrData = {
	asS16P: { { number } }, -- [80]
	asS32P: { { number } }, -- [80]
	asAnims: { number }, -- [80]
	asWaypoint: { Waypoint? }, -- [80]
	asChainSegment: { SrcGameObjectHelpersH.ChainSegment? }, -- [80]
	asObject: { Object? }, -- [80]
	asSurface: { Surface? }, -- [80]
	asVoidPtr: unknown, -- [80]
	asConstVoidPtr: unknown, -- [80]
}

-- from include/types.h:Object
export type Object = {
	header: ObjectNode, -- first member: this table itself
	gfx: GraphNodeObject, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	sharedChild: GraphNode?,
	areaIndex: number,
	activeAreaIndex: number,
	angle: { number },
	pos: { number },
	scale: { number },
	animInfo: AnimInfo,
	unk4C: SpawnInfo?,
	throwMatrix: { { { number } } }?,
	cameraToObject: { number },
	ObjectNode_next: ObjectNode?, -- next in the source
	ObjectNode_prev: ObjectNode?, -- prev in the source
	parentObj: Object?,
	prevObj: Object?,
	collidedObjInteractTypes: number,
	activeFlags: number,
	numCollidedObjs: number,
	collidedObjs: { Object? }, -- [4]
	rawData: buffer,
	ptrData: { unknown },
	unused1: number,
	curBhvCommand: number?,
	bhvStackIndex: number,
	bhvStack: { number }, -- [8]
	bhvDelayTimer: number,
	respawnInfoType: number,
	hitboxRadius: number,
	hitboxHeight: number,
	hurtboxRadius: number,
	hurtboxHeight: number,
	hitboxDownOffset: number,
	behavior: number?,
	unused2: number,
	platform: Object?,
	collisionData: number?,
	transform: { { number } },
	respawnInfo: unknown,
}

-- from include/types.h:ObjectHitbox
export type ObjectHitbox = {
	interactType: number,
	downOffset: number,
	damageOrCoinValue: number,
	health: number,
	numLootCoins: number,
	radius: number,
	height: number,
	hurtboxRadius: number,
	hurtboxHeight: number,
}

-- from include/types.h:Waypoint
export type Waypoint = {
	flags: number,
	pos: { number },
}

-- from include/types.h:Surface_normal
export type Surface_normal = {
	x: number,
	y: number,
	z: number,
}

-- from include/types.h:Surface
export type Surface = {
	type_: number,
	force: number,
	flags: number,
	room: number,
	lowerY: number,
	upperY: number,
	vertex1: { number },
	vertex2: { number },
	vertex3: { number },
	normal: Surface_normal,
	originOffset: number,
	object: Object?,
}

-- from include/types.h:MarioBodyState
export type MarioBodyState = {
	action: number,
	capState: number,
	eyeState: number,
	handState: number,
	wingFlutter: number,
	modelState: number,
	grabPos: number,
	punchState: number,
	torsoAngle: { number },
	headAngle: { number },
	heldObjLastPosition: { number },
	filler: buffer, -- [4]
}

-- from include/types.h:MarioState
export type MarioState = {
	unk00: number,
	input: number,
	flags: number,
	particleFlags: number,
	action: number,
	prevAction: number,
	terrainSoundAddend: number,
	actionState: number,
	actionTimer: number,
	actionArg: number,
	intendedMag: number,
	intendedYaw: number,
	invincTimer: number,
	framesSinceA: number,
	framesSinceB: number,
	wallKickTimer: number,
	doubleJumpTimer: number,
	faceAngle: { number },
	angleVel: { number },
	slideYaw: number,
	twirlYaw: number,
	pos: { number },
	vel: { number },
	forwardVel: number,
	slideVelX: number,
	slideVelZ: number,
	wall: Surface?,
	ceil: Surface?,
	floor: Surface?,
	ceilHeight: number,
	floorHeight: number,
	floorAngle: number,
	waterLevel: number,
	interactObj: Object?,
	heldObj: Object?,
	usedObj: Object?,
	riddenObj: Object?,
	marioObj: Object?,
	spawnInfo: SpawnInfo?,
	area: Area?,
	statusForCamera: PlayerCameraState?,
	marioBodyState: MarioBodyState?,
	controller: Controller?,
	animList: SrcGameMemoryH.DmaHandlerList?,
	collidedObjInteractTypes: number,
	numCoins: number,
	numStars: number,
	numKeys: number,
	numLives: number,
	health: number,
	unkB0: number,
	hurtCounter: number,
	healCounter: number,
	squishTimer: number,
	fadeWarpOpacity: number,
	capTimer: number,
	prevNumStarsForDialog: number,
	peakHeight: number,
	quicksandDepth: number,
	gettingBlownGravity: number,
}

-- from src/engine/graph_node.h:FnGraphNode
export type FnGraphNode = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
}

-- from src/engine/graph_node.h:GraphNodeRoot
export type GraphNodeRoot = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	areaIndex: number,
	unk15: number,
	x: number,
	y: number,
	width: number,
	height: number,
	numViews: number,
	views: { GraphNode? }?,
}

-- from src/engine/graph_node.h:GraphNodeOrthoProjection
export type GraphNodeOrthoProjection = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	scale: number,
}

-- from src/engine/graph_node.h:GraphNodePerspective
export type GraphNodePerspective = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	unused: number,
	fov: number,
	near: number,
	far: number,
}

-- from src/engine/graph_node.h:DisplayListNode
export type DisplayListNode = {
	transform: { unknown }?,
	displayList: unknown,
	next: DisplayListNode?,
}

-- from src/engine/graph_node.h:GraphNodeMasterList
export type GraphNodeMasterList = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	listHeads: { DisplayListNode? }, -- [8]
	listTails: { DisplayListNode? }, -- [8]
}

-- from src/engine/graph_node.h:GraphNodeStart
export type GraphNodeStart = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
}

-- from src/engine/graph_node.h:GraphNodeLevelOfDetail
export type GraphNodeLevelOfDetail = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	minDistance: number,
	maxDistance: number,
}

-- from src/engine/graph_node.h:GraphNodeSwitchCase
export type GraphNodeSwitchCase = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	unused: number,
	numCases: number,
	selectedCase: number,
}

-- from src/engine/graph_node.h:GraphNodeCamera_config
-- union: the fields are views of the same storage in C; decide how they alias
export type GraphNodeCamera_config = {
	mode: number,
	camera: Camera?,
}

-- from src/engine/graph_node.h:GraphNodeCamera
export type GraphNodeCamera = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	config: GraphNodeCamera_config,
	pos: { number },
	focus: { number },
	matrixPtr: { { { number } } }?,
	roll: number,
	rollScreen: number,
}

-- from src/engine/graph_node.h:GraphNodeTranslationRotation
export type GraphNodeTranslationRotation = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	translation: { number },
	rotation: { number },
}

-- from src/engine/graph_node.h:GraphNodeTranslation
export type GraphNodeTranslation = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	translation: { number },
	filler: buffer, -- [2]
}

-- from src/engine/graph_node.h:GraphNodeRotation
export type GraphNodeRotation = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	rotation: { number },
	filler: buffer, -- [2]
}

-- from src/engine/graph_node.h:GraphNodeAnimatedPart
export type GraphNodeAnimatedPart = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	translation: { number },
}

-- from src/engine/graph_node.h:GraphNodeBillboard
export type GraphNodeBillboard = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	translation: { number },
}

-- from src/engine/graph_node.h:GraphNodeDisplayList
export type GraphNodeDisplayList = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
}

-- from src/engine/graph_node.h:GraphNodeScale
export type GraphNodeScale = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	displayList: unknown,
	scale: number,
}

-- from src/engine/graph_node.h:GraphNodeShadow
export type GraphNodeShadow = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	shadowScale: number,
	shadowSolidity: number,
	shadowType: number,
}

-- from src/engine/graph_node.h:GraphNodeObjectParent
export type GraphNodeObjectParent = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	sharedChild: GraphNode?,
}

-- from src/engine/graph_node.h:GraphNodeGenerated
export type GraphNodeGenerated = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	parameter: number,
}

-- from src/engine/graph_node.h:GraphNodeBackground
export type GraphNodeBackground = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	unused: number,
	background: number,
}

-- from src/engine/graph_node.h:GraphNodeHeldObject
export type GraphNodeHeldObject = {
	fnNode: FnGraphNode, -- first member: this table itself
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	func: ((number, GraphNode, unknown) -> unknown)?,
	playerIndex: number,
	objNode: Object?,
	translation: { number },
}

-- from src/engine/graph_node.h:GraphNodeCullingRadius
export type GraphNodeCullingRadius = {
	node: GraphNode, -- first member: this table itself
	type_: number,
	flags: number,
	prev: GraphNode?,
	next: GraphNode?,
	parent: GraphNode?,
	children: GraphNode?,
	cullingRadius: number,
	filler: buffer, -- [2]
}

-- from src/game/area.h:WarpNode
export type WarpNode = {
	id: number,
	destLevel: number,
	destArea: number,
	destNode: number,
}

-- from src/game/area.h:ObjectWarpNode
export type ObjectWarpNode = {
	node: WarpNode, -- first member: this table itself
	id: number,
	destLevel: number,
	destArea: number,
	destNode: number,
	object: Object?,
	next: ObjectWarpNode?,
}

-- from src/game/area.h:InstantWarp
export type InstantWarp = {
	id: number,
	area: number,
	displacement: { number },
}

-- from src/game/area.h:SpawnInfo
export type SpawnInfo = {
	startPos: { number },
	startAngle: { number },
	areaIndex: number,
	activeAreaIndex: number,
	behaviorArg: number,
	behaviorScript: unknown,
	model: GraphNode?,
	next: SpawnInfo?,
}

-- from src/game/area.h:UnusedArea28
export type UnusedArea28 = {
	unk00: number,
	unk02: number,
	unk04: number,
	unk06: number,
	unk08: number,
}

-- from src/game/area.h:Whirlpool
export type Whirlpool = {
	pos: { number },
	strength: number,
}

-- from src/game/area.h:Area
export type Area = {
	index: number,
	flags: number,
	terrainType: number,
	unk04: GraphNodeRoot?,
	terrainData: number?,
	surfaceRooms: number?,
	macroObjects: number?,
	warpNodes: ObjectWarpNode?,
	paintingWarpNodes: { WarpNode }?,
	instantWarps: { InstantWarp }?,
	objectSpawnInfos: SpawnInfo?,
	camera: Camera?,
	unused: UnusedArea28?,
	whirlpools: { Whirlpool? }, -- [2]
	dialog: buffer, -- [2]
	musicParam: number,
	musicParam2: number,
}

-- from src/game/area.h:WarpTransitionData
export type WarpTransitionData = {
	red: number,
	green: number,
	blue: number,
	startTexRadius: number,
	endTexRadius: number,
	startTexX: number,
	startTexY: number,
	endTexX: number,
	endTexY: number,
	texTimer: number,
}

-- from src/game/area.h:WarpTransition
export type WarpTransition = {
	isActive: number,
	type_: number,
	time: number,
	pauseRendering: number,
	data: WarpTransitionData,
}

-- from src/game/camera.h:PlayerCameraState
export type PlayerCameraState = {
	action: number,
	pos: { number },
	faceAngle: { number },
	headRotation: { number },
	unused: number,
	cameraEvent: number,
	usedObj: Object?,
}

-- from src/game/camera.h:TransitionInfo
export type TransitionInfo = {
	posPitch: number,
	posYaw: number,
	posDist: number,
	focPitch: number,
	focYaw: number,
	focDist: number,
	framesLeft: number,
	marioPos: { number },
	unused: number,
}

-- from src/game/camera.h:HandheldShakePoint
export type HandheldShakePoint = {
	index: number,
	unused: number,
	point: { number },
}

-- from src/game/camera.h:CameraTrigger
export type CameraTrigger = {
	area: number,
	event: ((Camera) -> ())?,
	centerX: number,
	centerY: number,
	centerZ: number,
	boundsX: number,
	boundsY: number,
	boundsZ: number,
	boundsYaw: number,
}

-- from src/game/camera.h:Cutscene
export type Cutscene = {
	shot: ((Camera) -> ())?,
	duration: number,
}

-- from src/game/camera.h:CameraFOVStatus
export type CameraFOVStatus = {
	fovFunc: number,
	fov: number,
	fovOffset: number,
	unusedIsSleeping: number,
	shakeAmplitude: number,
	shakePhase: number,
	shakeSpeed: number,
	decay: number,
}

-- from src/game/camera.h:CutsceneSplinePoint
export type CutsceneSplinePoint = {
	index: number,
	speed: number,
	point: { number },
}

-- from src/game/camera.h:PlayerGeometry
export type PlayerGeometry = {
	currFloor: Surface?,
	currFloorHeight: number,
	currFloorType: number,
	currCeil: Surface?,
	currCeilType: number,
	currCeilHeight: number,
	prevFloor: Surface?,
	prevFloorHeight: number,
	prevFloorType: number,
	prevCeil: Surface?,
	prevCeilHeight: number,
	prevCeilType: number,
	waterHeight: number,
}

-- from src/game/camera.h:LinearTransitionPoint
export type LinearTransitionPoint = {
	focus: { number },
	pos: { number },
	dist: number,
	pitch: number,
	yaw: number,
}

-- from src/game/camera.h:ModeTransitionInfo
export type ModeTransitionInfo = {
	newMode: number,
	lastMode: number,
	max: number,
	frame: number,
	transitionStart: LinearTransitionPoint,
	transitionEnd: LinearTransitionPoint,
}

-- from src/game/camera.h:ParallelTrackingPoint
export type ParallelTrackingPoint = {
	startOfPath: number,
	pos: { number },
	distThresh: number,
	zoom: number,
}

-- from src/game/camera.h:CameraStoredInfo
export type CameraStoredInfo = {
	pos: { number },
	focus: { number },
	panDist: number,
	cannonYOffset: number,
}

-- from src/game/camera.h:CutsceneVariable
export type CutsceneVariable = {
	unused1: number,
	point: { number },
	unusedPoint: { number },
	angle: { number },
	unused2: number,
}

-- from src/game/camera.h:Camera
export type Camera = {
	mode: number,
	defMode: number,
	yaw: number,
	focus: { number },
	pos: { number },
	unusedVec1: { number },
	areaCenX: number,
	areaCenZ: number,
	cutscene: number,
	filler1: buffer, -- [8]
	nextYaw: number,
	filler2: buffer, -- [40]
	doorStatus: number,
	areaCenY: number,
}

-- from src/game/camera.h:LakituState
export type LakituState = {
	curFocus: { number },
	curPos: { number },
	goalFocus: { number },
	goalPos: { number },
	filler1: buffer, -- [12]
	mode: number,
	defMode: number,
	filler2: buffer, -- [10]
	focusDistance: number,
	oldPitch: number,
	oldYaw: number,
	oldRoll: number,
	shakeMagnitude: { number },
	shakePitchPhase: number,
	shakePitchVel: number,
	shakePitchDecay: number,
	unusedVec1: { number },
	unusedVec2: { number },
	filler3: buffer, -- [8]
	roll: number,
	yaw: number,
	nextYaw: number,
	focus: { number },
	pos: { number },
	shakeRollPhase: number,
	shakeRollVel: number,
	shakeRollDecay: number,
	shakeYawPhase: number,
	shakeYawVel: number,
	shakeYawDecay: number,
	focHSpeed: number,
	focVSpeed: number,
	posHSpeed: number,
	posVSpeed: number,
	keyDanceRoll: number,
	lastFrameAction: number,
	unused: number,
}

-- from include/types.h:data
const types_h_plus3 = {
	GRAPH_RENDER_ACTIVE = 1,
	GRAPH_RENDER_CHILDREN_FIRST = 2,
	GRAPH_RENDER_BILLBOARD = 4,
	GRAPH_RENDER_Z_BUFFER = 8,
	GRAPH_RENDER_INVISIBLE = 16,
	GRAPH_RENDER_HAS_ANIMATION = 32,
	GRAPH_NODE_TYPE_FUNCTIONAL = 0x100,
	GRAPH_NODE_TYPE_400 = 0x400,
	GRAPH_NODE_TYPE_ROOT = 0x001,
	INSTANT_WARP_INDEX_START = 0x00,
	GRAPH_NODE_TYPE_ORTHO_PROJECTION = 0x002,
	INSTANT_WARP_INDEX_STOP = 0x04,
	GRAPH_NODE_TYPE_PERSPECTIVE = 0x103, -- (0x003 | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_MASTER_LIST = 0x004,
	GRAPH_NODE_TYPE_START = 0x00A,
	GRAPH_NODE_TYPE_LEVEL_OF_DETAIL = 0x00B,
	GRAPH_NODE_TYPE_SWITCH_CASE = 0x10C, -- (0x00C | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_CAMERA = 0x114, -- (0x014 | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_TRANSLATION_ROTATION = 0x015,
	GRAPH_NODE_TYPE_TRANSLATION = 0x016,
	GRAPH_NODE_TYPE_ROTATION = 0x017,
	GRAPH_NODE_TYPE_OBJECT = 0x018,
	GRAPH_NODE_TYPE_ANIMATED_PART = 0x019,
	GRAPH_NODE_TYPE_BILLBOARD = 0x01A,
	GRAPH_NODE_TYPE_DISPLAY_LIST = 0x01B,
	GRAPH_NODE_TYPE_SCALE = 0x01C,
	GRAPH_NODE_TYPE_SHADOW = 0x028,
	GRAPH_NODE_TYPE_OBJECT_PARENT = 0x029,
	GRAPH_NODE_TYPE_GENERATED_LIST = 0x12A, -- (0x02A | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_BACKGROUND = 0x12C, -- (0x02C | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_HELD_OBJ = 0x12E, -- (0x02E | GRAPH_NODE_TYPE_FUNCTIONAL)
	GRAPH_NODE_TYPE_CULLING_RADIUS = 0x02F,
	AREA_BBH = 65, -- LEVEL_AREA_INDEX(LEVEL_BBH, 1)
	AREA_CCM_OUTSIDE = 81, -- LEVEL_AREA_INDEX(LEVEL_CCM, 1)
	AREA_CCM_SLIDE = 82, -- LEVEL_AREA_INDEX(LEVEL_CCM, 2)
	GFX_NUM_MASTER_LISTS = 8,
	AREA_CASTLE_LOBBY = 97, -- LEVEL_AREA_INDEX(LEVEL_CASTLE, 1)
	AREA_CASTLE_TIPPY = 98, -- LEVEL_AREA_INDEX(LEVEL_CASTLE, 2)
	AREA_CASTLE_BASEMENT = 99, -- LEVEL_AREA_INDEX(LEVEL_CASTLE, 3)
	AREA_HMC = 113, -- LEVEL_AREA_INDEX(LEVEL_HMC, 1)
	GEO_CONTEXT_CREATE = 0,
	AREA_SSL_OUTSIDE = 129, -- LEVEL_AREA_INDEX(LEVEL_SSL, 1)
	GEO_CONTEXT_RENDER = 1,
	AREA_SSL_PYRAMID = 130, -- LEVEL_AREA_INDEX(LEVEL_SSL, 2)
	GEO_CONTEXT_AREA_UNLOAD = 2,
	AREA_SSL_EYEROK = 131, -- LEVEL_AREA_INDEX(LEVEL_SSL, 3)
	GEO_CONTEXT_AREA_LOAD = 3,
	AREA_BOB = 145, -- LEVEL_AREA_INDEX(LEVEL_BOB, 1)
	GEO_CONTEXT_AREA_INIT = 4,
	AREA_SL_OUTSIDE = 161, -- LEVEL_AREA_INDEX(LEVEL_SL, 1)
	GEO_CONTEXT_HELD_OBJ = 5,
	AREA_SL_IGLOO = 162, -- LEVEL_AREA_INDEX(LEVEL_SL, 2)
	AREA_WDW_MAIN = 177, -- LEVEL_AREA_INDEX(LEVEL_WDW, 1)
	SPTASK_STATE_NOT_STARTED = 0,
	SPTASK_STATE_RUNNING = 1,
	SPTASK_STATE_INTERRUPTED = 2,
	SPTASK_STATE_FINISHED = 3,
	SPTASK_STATE_FINISHED_DP = 4,
	AREA_WDW_TOWN = 178, -- LEVEL_AREA_INDEX(LEVEL_WDW, 2)
	AREA_JRB_MAIN = 193, -- LEVEL_AREA_INDEX(LEVEL_JRB, 1)
	AREA_JRB_SHIP = 194, -- LEVEL_AREA_INDEX(LEVEL_JRB, 2)
	AREA_THI_HUGE = 209, -- LEVEL_AREA_INDEX(LEVEL_THI, 1)
	AREA_THI_TINY = 210, -- LEVEL_AREA_INDEX(LEVEL_THI, 2)
	AREA_THI_WIGGLER = 211, -- LEVEL_AREA_INDEX(LEVEL_THI, 3)
	AREA_TTC = 225, -- LEVEL_AREA_INDEX(LEVEL_TTC, 1)
	AREA_RR = 241, -- LEVEL_AREA_INDEX(LEVEL_RR, 1)
	AREA_CASTLE_GROUNDS = 257, -- LEVEL_AREA_INDEX(LEVEL_CASTLE_GROUNDS, 1)
	AREA_BITDW = 273, -- LEVEL_AREA_INDEX(LEVEL_BITDW, 1)
	AREA_VCUTM = 289, -- LEVEL_AREA_INDEX(LEVEL_VCUTM, 1)
	AREA_BITFS = 305, -- LEVEL_AREA_INDEX(LEVEL_BITFS, 1)
	AREA_SA = 321, -- LEVEL_AREA_INDEX(LEVEL_SA, 1)
	AREA_BITS = 337, -- LEVEL_AREA_INDEX(LEVEL_BITS, 1)
	AREA_LLL_OUTSIDE = 353, -- LEVEL_AREA_INDEX(LEVEL_LLL, 1)
	AREA_LLL_VOLCANO = 354, -- LEVEL_AREA_INDEX(LEVEL_LLL, 2)
	AREA_DDD_WHIRLPOOL = 369, -- LEVEL_AREA_INDEX(LEVEL_DDD, 1)
	AREA_DDD_SUB = 370, -- LEVEL_AREA_INDEX(LEVEL_DDD, 2)
	AREA_WF = 385, -- LEVEL_AREA_INDEX(LEVEL_WF, 1)
	AREA_ENDING = 401, -- LEVEL_AREA_INDEX(LEVEL_ENDING, 1)
	ANIM_FLAG_NOLOOP = 1,
	AREA_COURTYARD = 417, -- LEVEL_AREA_INDEX(LEVEL_CASTLE_COURTYARD, 1)
	ANIM_FLAG_BACKWARD = 2,
	AREA_PSS = 433, -- LEVEL_AREA_INDEX(LEVEL_PSS, 1)
	ANIM_FLAG_2 = 4,
	AREA_COTMC = 449, -- LEVEL_AREA_INDEX(LEVEL_COTMC, 1)
	ANIM_FLAG_HOR_TRANS = 8,
	AREA_TOTWC = 465, -- LEVEL_AREA_INDEX(LEVEL_TOTWC, 1)
	ANIM_FLAG_VERT_TRANS = 16,
	AREA_BOWSER_1 = 481, -- LEVEL_AREA_INDEX(LEVEL_BOWSER_1, 1)
	ANIM_FLAG_5 = 32,
	AREA_WMOTR = 497, -- LEVEL_AREA_INDEX(LEVEL_WMOTR, 1)
	ANIM_FLAG_6 = 64,
	AREA_BOWSER_2 = 529, -- LEVEL_AREA_INDEX(LEVEL_BOWSER_2, 1)
	ANIM_FLAG_7 = 128,
	AREA_BOWSER_3 = 545, -- LEVEL_AREA_INDEX(LEVEL_BOWSER_3, 1)
	AREA_TTM_OUTSIDE = 577, -- LEVEL_AREA_INDEX(LEVEL_TTM, 1)
	CAM_MODE_MARIO_ACTIVE = 0x01,
	CAM_MODE_LAKITU_WAS_ZOOMED_OUT = 0x02,
	CAM_MODE_MARIO_SELECTED = 0x04,
	WARP_TRANSITION_FADE_FROM_COLOR = 0x00,
	WARP_TRANSITION_FADE_INTO_COLOR = 0x01,
	CAM_SELECTION_MARIO = 1,
	WARP_TRANSITION_FADE_FROM_STAR = 0x08,
	CAM_SELECTION_FIXED = 2,
	WARP_TRANSITION_FADE_INTO_STAR = 0x09,
	WARP_TRANSITION_FADE_FROM_CIRCLE = 0x0A,
	CAM_ANGLE_MARIO = 1,
	WARP_TRANSITION_FADE_INTO_CIRCLE = 0x0B,
	CAM_ANGLE_LAKITU = 2,
	WARP_TRANSITION_FADE_FROM_MARIO = 0x10,
	WARP_TRANSITION_FADE_INTO_MARIO = 0x11,
	CAMERA_MODE_NONE = 0x00,
	WARP_TRANSITION_FADE_FROM_BOWSER = 0x12,
	CAMERA_MODE_RADIAL = 0x01,
	WARP_TRANSITION_FADE_INTO_BOWSER = 0x13,
	CAMERA_MODE_OUTWARD_RADIAL = 0x02,
	CAMERA_MODE_BEHIND_MARIO = 0x03,
	CAMERA_MODE_CLOSE = 0x04,
	CAMERA_MODE_C_UP = 0x06,
	CAMERA_MODE_WATER_SURFACE = 0x08,
	CAMERA_MODE_SLIDE_HOOT = 0x09,
	CAMERA_MODE_INSIDE_CANNON = 0x0A,
	CAMERA_MODE_BOSS_FIGHT = 0x0B,
	CAMERA_MODE_PARALLEL_TRACKING = 0x0C,
	CAMERA_MODE_FIXED = 0x0D,
	MENU_OPT_NONE = 0,
	MENU_OPT_1 = 1,
	MENU_OPT_2 = 2,
	MENU_OPT_3 = 3,
	MENU_OPT_DEFAULT = 1,
	MENU_OPT_CONTINUE = 1,
	MENU_OPT_EXIT_COURSE = 2,
	MENU_OPT_CAMERA_ANGLE_R = 3,
	MENU_OPT_SAVE_AND_CONTINUE = 1,
	MENU_OPT_SAVE_AND_QUIT = 2,
	MENU_OPT_CONTINUE_DONT_SAVE = 3,
	CAMERA_MODE_8_DIRECTIONS = 0x0E,
	CAMERA_MODE_FREE_ROAM = 0x10,
	CAMERA_MODE_SPIRAL_STAIRS = 0x11,
	CAM_MOVE_RETURN_TO_MIDDLE = 0x0001,
	CAM_MOVE_ZOOMED_OUT = 0x0002,
	CAM_MOVE_ROTATE_RIGHT = 0x0004,
	CAM_MOVE_ROTATE_LEFT = 0x0008,
	CAM_MOVE_ENTERED_ROTATE_SURFACE = 0x0010,
	CAM_MOVE_METAL_BELOW_WATER = 0x0020,
	CAM_MOVE_FIX_IN_PLACE = 0x0040,
	CAM_MOVE_UNKNOWN_8 = 0x0080,
	CAM_MOVING_INTO_MODE = 0x0100,
	CAM_MOVE_STARTED_EXITING_C_UP = 0x0200,
	CAM_MOVE_UNKNOWN_11 = 0x0400,
	CAM_MOVE_INIT_CAMERA = 0x0800,
	CAM_MOVE_ALREADY_ZOOMED_OUT = 0x1000,
	CAM_MOVE_C_UP_MODE = 0x2000,
	CAM_MOVE_SUBMERGED = 0x4000,
	CAM_MOVE_PAUSE_SCREEN = 0x8000,
	CAM_MOVE_ROTATE = 13, -- (CAM_MOVE_ROTATE_RIGHT | CAM_MOVE_ROTATE_LEFT | CAM_MOVE_RETURN_TO_MIDDLE)
	CAM_MOVE_RESTRICT = 240, -- (CAM_MOVE_ENTERED_ROTATE_SURFACE | CAM_MOVE_METAL_BELOW_WATER | CAM_MOVE_FIX_IN_PLACE | CAM_MOVE_UNKNOWN_8)
	CAM_SOUND_C_UP_PLAYED = 0x01,
	CAM_SOUND_MARIO_ACTIVE = 0x02,
	CAM_SOUND_NORMAL_ACTIVE = 0x04,
	CAM_SOUND_UNUSED_SELECT_MARIO = 0x08,
	CAM_SOUND_UNUSED_SELECT_FIXED = 0x10,
	CAM_SOUND_FIXED_ACTIVE = 0x20,
	CAM_FLAG_SMOOTH_MOVEMENT = 0x0001,
	CAM_FLAG_BLOCK_SMOOTH_MOVEMENT = 0x0002,
	CAM_FLAG_FRAME_AFTER_CAM_INIT = 0x0004,
	CAM_FLAG_CHANGED_PARTRACK_INDEX = 0x0008,
	CAM_FLAG_CCM_SLIDE_SHORTCUT = 0x0010,
	CAM_FLAG_CAM_NEAR_WALL = 0x0020,
	CAM_FLAG_SLEEPING = 0x0040,
	CAM_FLAG_UNUSED_7 = 0x0080,
	CAM_FLAG_UNUSED_8 = 0x0100,
	CAM_FLAG_COLLIDED_WITH_WALL = 0x0200,
	CAM_FLAG_START_TRANSITION = 0x0400,
	CAM_FLAG_TRANSITION_OUT_OF_C_UP = 0x0800,
	CAM_FLAG_BLOCK_AREA_PROCESSING = 0x1000,
	CAM_FLAG_UNUSED_13 = 0x2000,
	CAM_FLAG_UNUSED_CUTSCENE_ACTIVE = 0x4000,
	CAM_FLAG_BEHIND_MARIO_POST_DOOR = 0x8000,
	CAM_STATUS_NONE = 0,
	CAM_STATUS_MARIO = 1,
	CAM_STATUS_LAKITU = 2,
	CAM_STATUS_FIXED = 4,
	CAM_STATUS_C_DOWN = 8,
	CAM_STATUS_C_UP = 16,
	CAM_STATUS_MODE_GROUP = 7, -- (CAM_STATUS_MARIO | CAM_STATUS_LAKITU | CAM_STATUS_FIXED)
	CAM_STATUS_C_MODE_GROUP = 24, -- (CAM_STATUS_C_DOWN | CAM_STATUS_C_UP)
	SHAKE_ATTACK = 1,
	SHAKE_GROUND_POUND = 2,
	SHAKE_SMALL_DAMAGE = 3,
	SHAKE_MED_DAMAGE = 4,
	SHAKE_LARGE_DAMAGE = 5,
	SHAKE_HIT_FROM_BELOW = 8,
	SHAKE_FALL_DAMAGE = 9,
	SHAKE_SHOCK = 10,
	SHAKE_ENV_EXPLOSION = 1,
	SHAKE_ENV_BOWSER_THROW_BOUNCE = 2,
	SHAKE_ENV_BOWSER_JUMP = 3,
	SHAKE_ENV_UNUSED_5 = 5,
	SHAKE_ENV_UNUSED_6 = 6,
	SHAKE_ENV_UNUSED_7 = 7,
	SHAKE_ENV_PYRAMID_EXPLODE = 8,
	SHAKE_ENV_JRB_SHIP_DRAIN = 9,
	SHAKE_ENV_FALLING_BITS_PLAT = 10,
	SHAKE_FOV_SMALL = 1,
	SHAKE_FOV_UNUSED = 2,
	SHAKE_FOV_MEDIUM = 3,
	SHAKE_FOV_LARGE = 4,
	SHAKE_POS_SMALL = 1,
	SHAKE_POS_MEDIUM = 2,
	SHAKE_POS_LARGE = 3,
	SHAKE_POS_BOWLING_BALL = 4,
	CUTSCENE_DOOR_PULL = 130,
	CUTSCENE_DOOR_PUSH = 131,
	CUTSCENE_ENTER_CANNON = 133,
	CUTSCENE_ENTER_PAINTING = 134,
	CUTSCENE_DEATH_EXIT = 135,
	CUTSCENE_DOOR_WARP = 139,
	CUTSCENE_DOOR_PULL_MODE = 140,
	CUTSCENE_DOOR_PUSH_MODE = 141,
	CUTSCENE_INTRO_PEACH = 142,
	CUTSCENE_DANCE_ROTATE = 143,
	CUTSCENE_ENTER_BOWSER_ARENA = 144,
	CUTSCENE_0F_UNUSED = 145,
	CUTSCENE_UNUSED_EXIT = 147,
	CUTSCENE_SLIDING_DOORS_OPEN = 149,
	CUTSCENE_PREPARE_CANNON = 150,
	CUTSCENE_UNLOCK_KEY_DOOR = 151,
	CUTSCENE_STANDING_DEATH = 152,
	CUTSCENE_DEATH_ON_STOMACH = 153,
	CUTSCENE_DEATH_ON_BACK = 154,
	CUTSCENE_QUICKSAND_DEATH = 155,
	CUTSCENE_SUFFOCATION_DEATH = 156,
	CUTSCENE_EXIT_BOWSER_SUCC = 157,
	CUTSCENE_EXIT_BOWSER_DEATH = 158,
	CUTSCENE_WATER_DEATH = 159,
	CUTSCENE_EXIT_PAINTING_SUCC = 160,
	CUTSCENE_CAP_SWITCH_PRESS = 161,
	CUTSCENE_DIALOG = 162,
	CUTSCENE_RACE_DIALOG = 163,
	CUTSCENE_ENTER_PYRAMID_TOP = 164,
	CUTSCENE_DANCE_FLY_AWAY = 165,
	CUTSCENE_DANCE_CLOSEUP = 166,
	CUTSCENE_KEY_DANCE = 167,
	CUTSCENE_SSL_PYRAMID_EXPLODE = 168,
	CUTSCENE_EXIT_SPECIAL_SUCC = 169,
	CUTSCENE_NONPAINTING_DEATH = 170,
	CUTSCENE_READ_MESSAGE = 171,
	CUTSCENE_ENDING = 172,
	CUTSCENE_STAR_SPAWN = 173,
	CUTSCENE_GRAND_STAR = 174,
	CUTSCENE_DANCE_DEFAULT = 175,
	CUTSCENE_RED_COIN_STAR_SPAWN = 176,
	CUTSCENE_END_WAVING = 177,
	CUTSCENE_CREDITS = 178,
	CUTSCENE_EXIT_WATERFALL = 179,
	CUTSCENE_EXIT_FALL_WMOTR = 180,
	CUTSCENE_ENTER_POOL = 181,
	CUTSCENE_STOP = 0x8000,
	CUTSCENE_LOOP = 0x7FFF,
	HAND_CAM_SHAKE_OFF = 0,
	HAND_CAM_SHAKE_CUTSCENE = 1,
	HAND_CAM_SHAKE_UNUSED = 2,
	HAND_CAM_SHAKE_HANG_OWL = 3,
	HAND_CAM_SHAKE_HIGH = 4,
	HAND_CAM_SHAKE_STAR_DANCE = 5,
	HAND_CAM_SHAKE_LOW = 6,
	DOOR_DEFAULT = 0,
	DOOR_LEAVING_SPECIAL = 1,
	DOOR_ENTER_LOBBY = 2,
	CAM_FOV_SET_45 = 1,
	CAM_FOV_DEFAULT = 2,
	CAM_FOV_APP_45 = 4,
	CAM_FOV_SET_30 = 5,
	CAM_FOV_APP_20 = 6,
	CAM_FOV_BBH = 7,
	CAM_FOV_APP_80 = 9,
	CAM_FOV_APP_30 = 10,
	CAM_FOV_APP_60 = 11,
	CAM_FOV_ZOOM_30 = 12,
	CAM_FOV_SET_29 = 13,
	CAM_EVENT_CANNON = 1,
	CAM_EVENT_SHOT_FROM_CANNON = 2,
	CAM_EVENT_UNUSED_3 = 3,
	CAM_EVENT_BOWSER_INIT = 4,
	CAM_EVENT_DOOR_WARP = 5,
	CAM_EVENT_DOOR = 6,
	CAM_EVENT_BOWSER_JUMP = 7,
	CAM_EVENT_BOWSER_THROW_BOUNCE = 8,
	CAM_EVENT_START_INTRO = 9,
	CAM_EVENT_START_GRAND_STAR = 10,
	CAM_EVENT_START_ENDING = 11,
	CAM_EVENT_START_END_WAVING = 12,
	CAM_EVENT_START_CREDITS = 13,
}

-- from include/types.h:Controller (zero-filled constructor)
function types_h_plus3.new_Controller(): Controller
	return {
		rawStickX = 0,
		rawStickY = 0,
		stickX = 0,
		stickY = 0,
		stickMag = 0,
		buttonDown = 0,
		buttonPressed = 0,
		statusData = nil,
		controllerData = nil,
	} :: Controller
end

-- from include/types.h:SPTask (zero-filled constructor)
function types_h_plus3.new_SPTask(): SPTask
	return { task = 0, msgqueue = nil, msg = nil, state = 0 } :: SPTask
end

-- from include/types.h:VblankHandler (zero-filled constructor)
function types_h_plus3.new_VblankHandler(): VblankHandler
	return { queue = nil, msg = nil } :: VblankHandler
end

-- from include/types.h:Animation (zero-filled constructor)
function types_h_plus3.new_Animation(): Animation
	return {
		flags = 0,
		animYTransDivisor = 0,
		startFrame = 0,
		loopStart = 0,
		loopEnd = 0,
		unusedBoneCount = 0,
		values = nil,
		index = nil,
		length = 0,
	} :: Animation
end

-- from include/types.h:GraphNode (zero-filled constructor)
function types_h_plus3.new_GraphNode(): GraphNode
	return { type_ = 0, flags = 0, prev = nil, next = nil, parent = nil, children = nil } :: GraphNode
end

-- from include/types.h:AnimInfo (zero-filled constructor)
function types_h_plus3.new_AnimInfo(): AnimInfo
	return {
		animID = 0,
		animYTrans = 0,
		curAnim = nil,
		animFrame = 0,
		animTimer = 0,
		animFrameAccelAssist = 0,
		animAccel = 0,
	} :: AnimInfo
end

-- from include/types.h:GraphNodeObject (zero-filled constructor)
function types_h_plus3.new_GraphNodeObject(): GraphNodeObject
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		sharedChild = nil,
		areaIndex = 0,
		activeAreaIndex = 0,
		angle = table.create(3, 0),
		pos = table.create(3, 0),
		scale = table.create(3, 0),
		animInfo = {
			animID = 0,
			animYTrans = 0,
			curAnim = nil,
			animFrame = 0,
			animTimer = 0,
			animFrameAccelAssist = 0,
			animAccel = 0,
		},
		unk4C = nil,
		throwMatrix = nil,
		cameraToObject = table.create(3, 0),
		node = nil :: unknown,
	} :: GraphNodeObject

	Result.node = Result

	return Result
end

-- from include/types.h:ObjectNode (zero-filled constructor)
function types_h_plus3.new_ObjectNode(): ObjectNode
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		sharedChild = nil,
		areaIndex = 0,
		activeAreaIndex = 0,
		angle = table.create(3, 0),
		pos = table.create(3, 0),
		scale = table.create(3, 0),
		animInfo = {
			animID = 0,
			animYTrans = 0,
			curAnim = nil,
			animFrame = 0,
			animTimer = 0,
			animFrameAccelAssist = 0,
			animAccel = 0,
		},
		unk4C = nil,
		throwMatrix = nil,
		cameraToObject = table.create(3, 0),
		ObjectNode_next = nil,
		ObjectNode_prev = nil,
		gfx = nil :: unknown,
		node = nil :: unknown,
	} :: ObjectNode

	Result.gfx = Result
	Result.node = Result

	return Result
end

-- from include/types.h:Object (zero-filled constructor)
function types_h_plus3.new_Object(): Object
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		sharedChild = nil,
		areaIndex = 0,
		activeAreaIndex = 0,
		angle = table.create(3, 0),
		pos = table.create(3, 0),
		scale = table.create(3, 0),
		animInfo = {
			animID = 0,
			animYTrans = 0,
			curAnim = nil,
			animFrame = 0,
			animTimer = 0,
			animFrameAccelAssist = 0,
			animAccel = 0,
		},
		unk4C = nil,
		throwMatrix = nil,
		cameraToObject = table.create(3, 0),
		ObjectNode_next = nil,
		ObjectNode_prev = nil,
		parentObj = nil,
		prevObj = nil,
		collidedObjInteractTypes = 0,
		activeFlags = 0,
		numCollidedObjs = 0,
		collidedObjs = { nil, nil, nil, nil },
		rawData = buffer.create(320),
		ptrData = table.create(80),
		unused1 = 0,
		curBhvCommand = nil,
		bhvStackIndex = 0,
		bhvStack = table.create(8, 0),
		bhvDelayTimer = 0,
		respawnInfoType = 0,
		hitboxRadius = 0,
		hitboxHeight = 0,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
		hitboxDownOffset = 0,
		behavior = nil,
		unused2 = 0,
		platform = nil,
		collisionData = nil,
		transform = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		respawnInfo = nil,
		header = nil :: unknown,
		gfx = nil :: unknown,
		node = nil :: unknown,
	} :: Object

	Result.header = Result
	Result.gfx = Result
	Result.node = Result

	return Result
end

-- from include/types.h:ObjectHitbox (zero-filled constructor)
function types_h_plus3.new_ObjectHitbox(): ObjectHitbox
	return {
		interactType = 0,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 0,
		height = 0,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	} :: ObjectHitbox
end

-- from include/types.h:Waypoint (zero-filled constructor)
function types_h_plus3.new_Waypoint(): Waypoint
	return { flags = 0, pos = table.create(3, 0) } :: Waypoint
end

-- from include/types.h:Surface_normal (zero-filled constructor)
function types_h_plus3.new_Surface_normal(): Surface_normal
	return { x = 0, y = 0, z = 0 } :: Surface_normal
end

-- from include/types.h:Surface (zero-filled constructor)
function types_h_plus3.new_Surface(): Surface
	return {
		type_ = 0,
		force = 0,
		flags = 0,
		room = 0,
		lowerY = 0,
		upperY = 0,
		vertex1 = table.create(3, 0),
		vertex2 = table.create(3, 0),
		vertex3 = table.create(3, 0),
		normal = { x = 0, y = 0, z = 0 },
		originOffset = 0,
		object = nil,
	} :: Surface
end

-- from include/types.h:MarioBodyState (zero-filled constructor)
function types_h_plus3.new_MarioBodyState(): MarioBodyState
	return {
		action = 0,
		capState = 0,
		eyeState = 0,
		handState = 0,
		wingFlutter = 0,
		modelState = 0,
		grabPos = 0,
		punchState = 0,
		torsoAngle = table.create(3, 0),
		headAngle = table.create(3, 0),
		heldObjLastPosition = table.create(3, 0),
		filler = buffer.create(4),
	} :: MarioBodyState
end

-- from include/types.h:MarioState (zero-filled constructor)
function types_h_plus3.new_MarioState(): MarioState
	return {
		unk00 = 0,
		input = 0,
		flags = 0,
		particleFlags = 0,
		action = 0,
		prevAction = 0,
		terrainSoundAddend = 0,
		actionState = 0,
		actionTimer = 0,
		actionArg = 0,
		intendedMag = 0,
		intendedYaw = 0,
		invincTimer = 0,
		framesSinceA = 0,
		framesSinceB = 0,
		wallKickTimer = 0,
		doubleJumpTimer = 0,
		faceAngle = table.create(3, 0),
		angleVel = table.create(3, 0),
		slideYaw = 0,
		twirlYaw = 0,
		pos = table.create(3, 0),
		vel = table.create(3, 0),
		forwardVel = 0,
		slideVelX = 0,
		slideVelZ = 0,
		wall = nil,
		ceil = nil,
		floor = nil,
		ceilHeight = 0,
		floorHeight = 0,
		floorAngle = 0,
		waterLevel = 0,
		interactObj = nil,
		heldObj = nil,
		usedObj = nil,
		riddenObj = nil,
		marioObj = nil,
		spawnInfo = nil,
		area = nil,
		statusForCamera = nil,
		marioBodyState = nil,
		controller = nil,
		animList = nil,
		collidedObjInteractTypes = 0,
		numCoins = 0,
		numStars = 0,
		numKeys = 0,
		numLives = 0,
		health = 0,
		unkB0 = 0,
		hurtCounter = 0,
		healCounter = 0,
		squishTimer = 0,
		fadeWarpOpacity = 0,
		capTimer = 0,
		prevNumStarsForDialog = 0,
		peakHeight = 0,
		quicksandDepth = 0,
		gettingBlownGravity = 0,
	} :: MarioState
end

-- from src/engine/graph_node.h:FnGraphNode (zero-filled constructor)
function types_h_plus3.new_FnGraphNode(): FnGraphNode
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		node = nil :: unknown,
	} :: FnGraphNode

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeRoot (zero-filled constructor)
function types_h_plus3.new_GraphNodeRoot(): GraphNodeRoot
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		areaIndex = 0,
		unk15 = 0,
		x = 0,
		y = 0,
		width = 0,
		height = 0,
		numViews = 0,
		views = nil,
		node = nil :: unknown,
	} :: GraphNodeRoot

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeOrthoProjection (zero-filled constructor)
function types_h_plus3.new_GraphNodeOrthoProjection(): GraphNodeOrthoProjection
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		scale = 0,
		node = nil :: unknown,
	} :: GraphNodeOrthoProjection

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodePerspective (zero-filled constructor)
function types_h_plus3.new_GraphNodePerspective(): GraphNodePerspective
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		unused = 0,
		fov = 0,
		near = 0,
		far = 0,
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodePerspective

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:DisplayListNode (zero-filled constructor)
function types_h_plus3.new_DisplayListNode(): DisplayListNode
	return { transform = nil, displayList = nil, next = nil } :: DisplayListNode
end

-- from src/engine/graph_node.h:GraphNodeMasterList (zero-filled constructor)
function types_h_plus3.new_GraphNodeMasterList(): GraphNodeMasterList
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		listHeads = { nil, nil, nil, nil, nil, nil, nil, nil },
		listTails = { nil, nil, nil, nil, nil, nil, nil, nil },
		node = nil :: unknown,
	} :: GraphNodeMasterList

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeStart (zero-filled constructor)
function types_h_plus3.new_GraphNodeStart(): GraphNodeStart
	const Result = { type_ = 0, flags = 0, prev = nil, next = nil, parent = nil, children = nil, node = nil :: unknown } :: GraphNodeStart

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeLevelOfDetail (zero-filled constructor)
function types_h_plus3.new_GraphNodeLevelOfDetail(): GraphNodeLevelOfDetail
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		minDistance = 0,
		maxDistance = 0,
		node = nil :: unknown,
	} :: GraphNodeLevelOfDetail

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeSwitchCase (zero-filled constructor)
function types_h_plus3.new_GraphNodeSwitchCase(): GraphNodeSwitchCase
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		unused = 0,
		numCases = 0,
		selectedCase = 0,
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodeSwitchCase

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeCamera (zero-filled constructor)
function types_h_plus3.new_GraphNodeCamera(): GraphNodeCamera
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		config = { mode = 0 },
		pos = table.create(3, 0),
		focus = table.create(3, 0),
		matrixPtr = nil,
		roll = 0,
		rollScreen = 0,
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodeCamera

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeTranslationRotation (zero-filled constructor)
function types_h_plus3.new_GraphNodeTranslationRotation(): GraphNodeTranslationRotation
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		translation = table.create(3, 0),
		rotation = table.create(3, 0),
		node = nil :: unknown,
	} :: GraphNodeTranslationRotation

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeTranslation (zero-filled constructor)
function types_h_plus3.new_GraphNodeTranslation(): GraphNodeTranslation
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		translation = table.create(3, 0),
		filler = buffer.create(2),
		node = nil :: unknown,
	} :: GraphNodeTranslation

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeRotation (zero-filled constructor)
function types_h_plus3.new_GraphNodeRotation(): GraphNodeRotation
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		rotation = table.create(3, 0),
		filler = buffer.create(2),
		node = nil :: unknown,
	} :: GraphNodeRotation

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeAnimatedPart (zero-filled constructor)
function types_h_plus3.new_GraphNodeAnimatedPart(): GraphNodeAnimatedPart
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		translation = table.create(3, 0),
		node = nil :: unknown,
	} :: GraphNodeAnimatedPart

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeBillboard (zero-filled constructor)
function types_h_plus3.new_GraphNodeBillboard(): GraphNodeBillboard
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		translation = table.create(3, 0),
		node = nil :: unknown,
	} :: GraphNodeBillboard

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeDisplayList (zero-filled constructor)
function types_h_plus3.new_GraphNodeDisplayList(): GraphNodeDisplayList
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		node = nil :: unknown,
	} :: GraphNodeDisplayList

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeScale (zero-filled constructor)
function types_h_plus3.new_GraphNodeScale(): GraphNodeScale
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		displayList = nil,
		scale = 0,
		node = nil :: unknown,
	} :: GraphNodeScale

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeShadow (zero-filled constructor)
function types_h_plus3.new_GraphNodeShadow(): GraphNodeShadow
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		shadowScale = 0,
		shadowSolidity = 0,
		shadowType = 0,
		node = nil :: unknown,
	} :: GraphNodeShadow

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeObjectParent (zero-filled constructor)
function types_h_plus3.new_GraphNodeObjectParent(): GraphNodeObjectParent
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		sharedChild = nil,
		node = nil :: unknown,
	} :: GraphNodeObjectParent

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeGenerated (zero-filled constructor)
function types_h_plus3.new_GraphNodeGenerated(): GraphNodeGenerated
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		parameter = 0,
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodeGenerated

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeBackground (zero-filled constructor)
function types_h_plus3.new_GraphNodeBackground(): GraphNodeBackground
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		unused = 0,
		background = 0,
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodeBackground

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeHeldObject (zero-filled constructor)
function types_h_plus3.new_GraphNodeHeldObject(): GraphNodeHeldObject
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		func = nil,
		playerIndex = 0,
		objNode = nil,
		translation = table.create(3, 0),
		fnNode = nil :: unknown,
		node = nil :: unknown,
	} :: GraphNodeHeldObject

	Result.fnNode = Result
	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeCullingRadius (zero-filled constructor)
function types_h_plus3.new_GraphNodeCullingRadius(): GraphNodeCullingRadius
	const Result = {
		type_ = 0,
		flags = 0,
		prev = nil,
		next = nil,
		parent = nil,
		children = nil,
		cullingRadius = 0,
		filler = buffer.create(2),
		node = nil :: unknown,
	} :: GraphNodeCullingRadius

	Result.node = Result

	return Result
end

-- from src/game/area.h:WarpNode (zero-filled constructor)
function types_h_plus3.new_WarpNode(): WarpNode
	return { id = 0, destLevel = 0, destArea = 0, destNode = 0 } :: WarpNode
end

-- from src/game/area.h:ObjectWarpNode (zero-filled constructor)
function types_h_plus3.new_ObjectWarpNode(): ObjectWarpNode
	const Result = {
		id = 0,
		destLevel = 0,
		destArea = 0,
		destNode = 0,
		object = nil,
		next = nil,
		node = nil :: unknown,
	} :: ObjectWarpNode

	Result.node = Result

	return Result
end

-- from src/game/area.h:InstantWarp (zero-filled constructor)
function types_h_plus3.new_InstantWarp(): InstantWarp
	return { id = 0, area = 0, displacement = table.create(3, 0) } :: InstantWarp
end

-- from src/game/area.h:SpawnInfo (zero-filled constructor)
function types_h_plus3.new_SpawnInfo(): SpawnInfo
	return {
		startPos = table.create(3, 0),
		startAngle = table.create(3, 0),
		areaIndex = 0,
		activeAreaIndex = 0,
		behaviorArg = 0,
		behaviorScript = nil,
		model = nil,
		next = nil,
	} :: SpawnInfo
end

-- from src/game/area.h:UnusedArea28 (zero-filled constructor)
function types_h_plus3.new_UnusedArea28(): UnusedArea28
	return { unk00 = 0, unk02 = 0, unk04 = 0, unk06 = 0, unk08 = 0 } :: UnusedArea28
end

-- from src/game/area.h:Whirlpool (zero-filled constructor)
function types_h_plus3.new_Whirlpool(): Whirlpool
	return { pos = table.create(3, 0), strength = 0 } :: Whirlpool
end

-- from src/game/area.h:Area (zero-filled constructor)
function types_h_plus3.new_Area(): Area
	return {
		index = 0,
		flags = 0,
		terrainType = 0,
		unk04 = nil,
		terrainData = nil,
		surfaceRooms = nil,
		macroObjects = nil,
		warpNodes = nil,
		paintingWarpNodes = nil,
		instantWarps = nil,
		objectSpawnInfos = nil,
		camera = nil,
		unused = nil,
		whirlpools = { nil, nil },
		dialog = buffer.create(2),
		musicParam = 0,
		musicParam2 = 0,
	} :: Area
end

-- from src/game/area.h:WarpTransitionData (zero-filled constructor)
function types_h_plus3.new_WarpTransitionData(): WarpTransitionData
	return {
		red = 0,
		green = 0,
		blue = 0,
		startTexRadius = 0,
		endTexRadius = 0,
		startTexX = 0,
		startTexY = 0,
		endTexX = 0,
		endTexY = 0,
		texTimer = 0,
	} :: WarpTransitionData
end

-- from src/game/area.h:WarpTransition (zero-filled constructor)
function types_h_plus3.new_WarpTransition(): WarpTransition
	return {
		isActive = 0,
		type_ = 0,
		time = 0,
		pauseRendering = 0,
		data = {
			red = 0,
			green = 0,
			blue = 0,
			startTexRadius = 0,
			endTexRadius = 0,
			startTexX = 0,
			startTexY = 0,
			endTexX = 0,
			endTexY = 0,
			texTimer = 0,
		},
	} :: WarpTransition
end

-- from src/game/camera.h:PlayerCameraState (zero-filled constructor)
function types_h_plus3.new_PlayerCameraState(): PlayerCameraState
	return {
		action = 0,
		pos = table.create(3, 0),
		faceAngle = table.create(3, 0),
		headRotation = table.create(3, 0),
		unused = 0,
		cameraEvent = 0,
		usedObj = nil,
	} :: PlayerCameraState
end

-- from src/game/camera.h:TransitionInfo (zero-filled constructor)
function types_h_plus3.new_TransitionInfo(): TransitionInfo
	return {
		posPitch = 0,
		posYaw = 0,
		posDist = 0,
		focPitch = 0,
		focYaw = 0,
		focDist = 0,
		framesLeft = 0,
		marioPos = table.create(3, 0),
		unused = 0,
	} :: TransitionInfo
end

-- from src/game/camera.h:HandheldShakePoint (zero-filled constructor)
function types_h_plus3.new_HandheldShakePoint(): HandheldShakePoint
	return { index = 0, unused = 0, point = table.create(3, 0) } :: HandheldShakePoint
end

-- from src/game/camera.h:CameraTrigger (zero-filled constructor)
function types_h_plus3.new_CameraTrigger(): CameraTrigger
	return {
		area = 0,
		event = nil,
		centerX = 0,
		centerY = 0,
		centerZ = 0,
		boundsX = 0,
		boundsY = 0,
		boundsZ = 0,
		boundsYaw = 0,
	} :: CameraTrigger
end

-- from src/game/camera.h:Cutscene (zero-filled constructor)
function types_h_plus3.new_Cutscene(): Cutscene
	return { shot = nil, duration = 0 } :: Cutscene
end

-- from src/game/camera.h:CameraFOVStatus (zero-filled constructor)
function types_h_plus3.new_CameraFOVStatus(): CameraFOVStatus
	return {
		fovFunc = 0,
		fov = 0,
		fovOffset = 0,
		unusedIsSleeping = 0,
		shakeAmplitude = 0,
		shakePhase = 0,
		shakeSpeed = 0,
		decay = 0,
	} :: CameraFOVStatus
end

-- from src/game/camera.h:CutsceneSplinePoint (zero-filled constructor)
function types_h_plus3.new_CutsceneSplinePoint(): CutsceneSplinePoint
	return { index = 0, speed = 0, point = table.create(3, 0) } :: CutsceneSplinePoint
end

-- from src/game/camera.h:PlayerGeometry (zero-filled constructor)
function types_h_plus3.new_PlayerGeometry(): PlayerGeometry
	return {
		currFloor = nil,
		currFloorHeight = 0,
		currFloorType = 0,
		currCeil = nil,
		currCeilType = 0,
		currCeilHeight = 0,
		prevFloor = nil,
		prevFloorHeight = 0,
		prevFloorType = 0,
		prevCeil = nil,
		prevCeilHeight = 0,
		prevCeilType = 0,
		waterHeight = 0,
	} :: PlayerGeometry
end

-- from src/game/camera.h:LinearTransitionPoint (zero-filled constructor)
function types_h_plus3.new_LinearTransitionPoint(): LinearTransitionPoint
	return { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 } :: LinearTransitionPoint
end

-- from src/game/camera.h:ModeTransitionInfo (zero-filled constructor)
function types_h_plus3.new_ModeTransitionInfo(): ModeTransitionInfo
	return {
		newMode = 0,
		lastMode = 0,
		max = 0,
		frame = 0,
		transitionStart = { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 },
		transitionEnd = { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 },
	} :: ModeTransitionInfo
end

-- from src/game/camera.h:ParallelTrackingPoint (zero-filled constructor)
function types_h_plus3.new_ParallelTrackingPoint(): ParallelTrackingPoint
	return { startOfPath = 0, pos = table.create(3, 0), distThresh = 0, zoom = 0 } :: ParallelTrackingPoint
end

-- from src/game/camera.h:CameraStoredInfo (zero-filled constructor)
function types_h_plus3.new_CameraStoredInfo(): CameraStoredInfo
	return { pos = table.create(3, 0), focus = table.create(3, 0), panDist = 0, cannonYOffset = 0 } :: CameraStoredInfo
end

-- from src/game/camera.h:CutsceneVariable (zero-filled constructor)
function types_h_plus3.new_CutsceneVariable(): CutsceneVariable
	return {
		unused1 = 0,
		point = table.create(3, 0),
		unusedPoint = table.create(3, 0),
		angle = table.create(3, 0),
		unused2 = 0,
	} :: CutsceneVariable
end

-- from src/game/camera.h:Camera (zero-filled constructor)
function types_h_plus3.new_Camera(): Camera
	return {
		mode = 0,
		defMode = 0,
		yaw = 0,
		focus = table.create(3, 0),
		pos = table.create(3, 0),
		unusedVec1 = table.create(3, 0),
		areaCenX = 0,
		areaCenZ = 0,
		cutscene = 0,
		filler1 = buffer.create(8),
		nextYaw = 0,
		filler2 = buffer.create(40),
		doorStatus = 0,
		areaCenY = 0,
	} :: Camera
end

-- from src/game/camera.h:LakituState (zero-filled constructor)
function types_h_plus3.new_LakituState(): LakituState
	return {
		curFocus = table.create(3, 0),
		curPos = table.create(3, 0),
		goalFocus = table.create(3, 0),
		goalPos = table.create(3, 0),
		filler1 = buffer.create(12),
		mode = 0,
		defMode = 0,
		filler2 = buffer.create(10),
		focusDistance = 0,
		oldPitch = 0,
		oldYaw = 0,
		oldRoll = 0,
		shakeMagnitude = table.create(3, 0),
		shakePitchPhase = 0,
		shakePitchVel = 0,
		shakePitchDecay = 0,
		unusedVec1 = table.create(3, 0),
		unusedVec2 = table.create(3, 0),
		filler3 = buffer.create(8),
		roll = 0,
		yaw = 0,
		nextYaw = 0,
		focus = table.create(3, 0),
		pos = table.create(3, 0),
		shakeRollPhase = 0,
		shakeRollVel = 0,
		shakeRollDecay = 0,
		shakeYawPhase = 0,
		shakeYawVel = 0,
		shakeYawDecay = 0,
		focHSpeed = 0,
		focVSpeed = 0,
		posHSpeed = 0,
		posVSpeed = 0,
		keyDanceRoll = 0,
		lastFrameAction = 0,
		unused = 0,
	} :: LakituState
end

-- from include/types.h:ANIMINDEX_NUMPARTS L101-101
function types_h_plus3.ANIMINDEX_NUMPARTS(animindex: number): number
	error("stale")
end

-- from src/game/camera.h:ABS L19-19
function types_h_plus3.ABS(x: number): number
	return if x > 0 then x else -x
end

-- from src/game/camera.h:ABS2 L20-20
function types_h_plus3.ABS2(x: number): number
	return if x >= 0 then x else -x
end

-- from src/game/camera.h:DEGREES L26-26
function types_h_plus3.DEGREES(x: number): number
	return (math.modf(x * 0x10000 / 360))
end

-- from src/game/camera.h:LEVEL_AREA_INDEX L28-28
function types_h_plus3.LEVEL_AREA_INDEX(levelNum: number, areaNum: number): number
	return bit32.lshift(levelNum, 4) + areaNum
end

-- from src/game/camera.h:ZOOMOUT_AREA_MASK L34-43
function types_h_plus3.ZOOMOUT_AREA_MASK(level1Area1: number, level1Area2: number, level1Area3: number, level1Area4: number, level2Area1: number, level2Area2: number, level2Area3: number, level2Area4: number): number
	return bit32.bor(bit32.lshift(level2Area4, 7), bit32.lshift(level2Area3, 6), bit32.lshift(level2Area2, 5), bit32.lshift(level2Area1, 4), bit32.lshift(level1Area4, 3), bit32.lshift(level1Area3, 2), bit32.lshift(level1Area2, 1), bit32.lshift(level1Area1, 0))
end

return types_h_plus3
