--!strict
--!optimize 2

--[[
	Types of include/types_h, src/engine/graph_node_h, src/game/area_h, src/game/camera_h.
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

const types_h_plus3_types = {}

-- from include/types.h:Controller (zero-filled constructor)
function types_h_plus3_types.new_Controller(): Controller
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
function types_h_plus3_types.new_SPTask(): SPTask
	return { task = 0, msgqueue = nil, msg = nil, state = 0 } :: SPTask
end

-- from include/types.h:VblankHandler (zero-filled constructor)
function types_h_plus3_types.new_VblankHandler(): VblankHandler
	return { queue = nil, msg = nil } :: VblankHandler
end

-- from include/types.h:Animation (zero-filled constructor)
function types_h_plus3_types.new_Animation(): Animation
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
function types_h_plus3_types.new_GraphNode(): GraphNode
	return { type_ = 0, flags = 0, prev = nil, next = nil, parent = nil, children = nil } :: GraphNode
end

-- from include/types.h:AnimInfo (zero-filled constructor)
function types_h_plus3_types.new_AnimInfo(): AnimInfo
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
function types_h_plus3_types.new_GraphNodeObject(): GraphNodeObject
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
function types_h_plus3_types.new_ObjectNode(): ObjectNode
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
function types_h_plus3_types.new_Object(): Object
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
function types_h_plus3_types.new_ObjectHitbox(): ObjectHitbox
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
function types_h_plus3_types.new_Waypoint(): Waypoint
	return { flags = 0, pos = table.create(3, 0) } :: Waypoint
end

-- from include/types.h:Surface_normal (zero-filled constructor)
function types_h_plus3_types.new_Surface_normal(): Surface_normal
	return { x = 0, y = 0, z = 0 } :: Surface_normal
end

-- from include/types.h:Surface (zero-filled constructor)
function types_h_plus3_types.new_Surface(): Surface
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
function types_h_plus3_types.new_MarioBodyState(): MarioBodyState
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
function types_h_plus3_types.new_MarioState(): MarioState
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
function types_h_plus3_types.new_FnGraphNode(): FnGraphNode
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
function types_h_plus3_types.new_GraphNodeRoot(): GraphNodeRoot
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
function types_h_plus3_types.new_GraphNodeOrthoProjection(): GraphNodeOrthoProjection
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
function types_h_plus3_types.new_GraphNodePerspective(): GraphNodePerspective
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
function types_h_plus3_types.new_DisplayListNode(): DisplayListNode
	return { transform = nil, displayList = nil, next = nil } :: DisplayListNode
end

-- from src/engine/graph_node.h:GraphNodeMasterList (zero-filled constructor)
function types_h_plus3_types.new_GraphNodeMasterList(): GraphNodeMasterList
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
function types_h_plus3_types.new_GraphNodeStart(): GraphNodeStart
	const Result = { type_ = 0, flags = 0, prev = nil, next = nil, parent = nil, children = nil, node = nil :: unknown } :: GraphNodeStart

	Result.node = Result

	return Result
end

-- from src/engine/graph_node.h:GraphNodeLevelOfDetail (zero-filled constructor)
function types_h_plus3_types.new_GraphNodeLevelOfDetail(): GraphNodeLevelOfDetail
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
function types_h_plus3_types.new_GraphNodeSwitchCase(): GraphNodeSwitchCase
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
function types_h_plus3_types.new_GraphNodeCamera(): GraphNodeCamera
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
function types_h_plus3_types.new_GraphNodeTranslationRotation(): GraphNodeTranslationRotation
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
function types_h_plus3_types.new_GraphNodeTranslation(): GraphNodeTranslation
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
function types_h_plus3_types.new_GraphNodeRotation(): GraphNodeRotation
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
function types_h_plus3_types.new_GraphNodeAnimatedPart(): GraphNodeAnimatedPart
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
function types_h_plus3_types.new_GraphNodeBillboard(): GraphNodeBillboard
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
function types_h_plus3_types.new_GraphNodeDisplayList(): GraphNodeDisplayList
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
function types_h_plus3_types.new_GraphNodeScale(): GraphNodeScale
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
function types_h_plus3_types.new_GraphNodeShadow(): GraphNodeShadow
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
function types_h_plus3_types.new_GraphNodeObjectParent(): GraphNodeObjectParent
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
function types_h_plus3_types.new_GraphNodeGenerated(): GraphNodeGenerated
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
function types_h_plus3_types.new_GraphNodeBackground(): GraphNodeBackground
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
function types_h_plus3_types.new_GraphNodeHeldObject(): GraphNodeHeldObject
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
function types_h_plus3_types.new_GraphNodeCullingRadius(): GraphNodeCullingRadius
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
function types_h_plus3_types.new_WarpNode(): WarpNode
	return { id = 0, destLevel = 0, destArea = 0, destNode = 0 } :: WarpNode
end

-- from src/game/area.h:ObjectWarpNode (zero-filled constructor)
function types_h_plus3_types.new_ObjectWarpNode(): ObjectWarpNode
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
function types_h_plus3_types.new_InstantWarp(): InstantWarp
	return { id = 0, area = 0, displacement = table.create(3, 0) } :: InstantWarp
end

-- from src/game/area.h:SpawnInfo (zero-filled constructor)
function types_h_plus3_types.new_SpawnInfo(): SpawnInfo
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
function types_h_plus3_types.new_UnusedArea28(): UnusedArea28
	return { unk00 = 0, unk02 = 0, unk04 = 0, unk06 = 0, unk08 = 0 } :: UnusedArea28
end

-- from src/game/area.h:Whirlpool (zero-filled constructor)
function types_h_plus3_types.new_Whirlpool(): Whirlpool
	return { pos = table.create(3, 0), strength = 0 } :: Whirlpool
end

-- from src/game/area.h:Area (zero-filled constructor)
function types_h_plus3_types.new_Area(): Area
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
function types_h_plus3_types.new_WarpTransitionData(): WarpTransitionData
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
function types_h_plus3_types.new_WarpTransition(): WarpTransition
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
function types_h_plus3_types.new_PlayerCameraState(): PlayerCameraState
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
function types_h_plus3_types.new_TransitionInfo(): TransitionInfo
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
function types_h_plus3_types.new_HandheldShakePoint(): HandheldShakePoint
	return { index = 0, unused = 0, point = table.create(3, 0) } :: HandheldShakePoint
end

-- from src/game/camera.h:CameraTrigger (zero-filled constructor)
function types_h_plus3_types.new_CameraTrigger(): CameraTrigger
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
function types_h_plus3_types.new_Cutscene(): Cutscene
	return { shot = nil, duration = 0 } :: Cutscene
end

-- from src/game/camera.h:CameraFOVStatus (zero-filled constructor)
function types_h_plus3_types.new_CameraFOVStatus(): CameraFOVStatus
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
function types_h_plus3_types.new_CutsceneSplinePoint(): CutsceneSplinePoint
	return { index = 0, speed = 0, point = table.create(3, 0) } :: CutsceneSplinePoint
end

-- from src/game/camera.h:PlayerGeometry (zero-filled constructor)
function types_h_plus3_types.new_PlayerGeometry(): PlayerGeometry
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
function types_h_plus3_types.new_LinearTransitionPoint(): LinearTransitionPoint
	return { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 } :: LinearTransitionPoint
end

-- from src/game/camera.h:ModeTransitionInfo (zero-filled constructor)
function types_h_plus3_types.new_ModeTransitionInfo(): ModeTransitionInfo
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
function types_h_plus3_types.new_ParallelTrackingPoint(): ParallelTrackingPoint
	return { startOfPath = 0, pos = table.create(3, 0), distThresh = 0, zoom = 0 } :: ParallelTrackingPoint
end

-- from src/game/camera.h:CameraStoredInfo (zero-filled constructor)
function types_h_plus3_types.new_CameraStoredInfo(): CameraStoredInfo
	return { pos = table.create(3, 0), focus = table.create(3, 0), panDist = 0, cannonYOffset = 0 } :: CameraStoredInfo
end

-- from src/game/camera.h:CutsceneVariable (zero-filled constructor)
function types_h_plus3_types.new_CutsceneVariable(): CutsceneVariable
	return {
		unused1 = 0,
		point = table.create(3, 0),
		unusedPoint = table.create(3, 0),
		angle = table.create(3, 0),
		unused2 = 0,
	} :: CutsceneVariable
end

-- from src/game/camera.h:Camera (zero-filled constructor)
function types_h_plus3_types.new_Camera(): Camera
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
function types_h_plus3_types.new_LakituState(): LakituState
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

return types_h_plus3_types
