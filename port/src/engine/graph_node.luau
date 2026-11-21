--!strict
--!optimize 2

--[[
	Port of src/engine/graph_node.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const Rom = require("../rom/rom")

const SrcGameMemoryH = require("../game/memory_h")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const MathUtil = require("./math_util")
const SrcGameMemory = require("../game/memory")
const SrcGameRenderingGraphNode = require("../game/rendering_graph_node")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/engine/graph_node.c:data
const graph_node = {
	-- from src/engine/graph_node.c:identityMtx L13-13
	identityMtx = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } },
	-- from src/engine/graph_node.c:zeroMtx L14-14
	zeroMtx = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
	-- from src/engine/graph_node.c:gVec3fZero L16-16
	gVec3fZero = { 0.0, 0.0, 0.0 },
	-- from src/engine/graph_node.c:gVec3sZero L17-17
	gVec3sZero = { 0, 0, 0 },
	-- from src/engine/graph_node.c:gVec3fOne L18-18
	gVec3fOne = { 1.0, 1.0, 1.0 },
	-- from src/engine/graph_node.c:gVec3sOne L19-19
	gVec3sOne = { 1, 1, 1 },
}

-- Cursor of the animation attribute pointer in geo_retreive_animation_translation (no re-entrancy)
const AttributesScratch = table.create(1, 0)

Registry.Register("src__engine__graph_node", graph_node)

-- from src/engine/graph_node.c:init_scene_graph_node_links L25-32
function graph_node.init_scene_graph_node_links(graphNode: GroupsTypesHPlus3Types.GraphNode, type_: number)
	graphNode.type_ = S16(type_)
	graphNode.flags = GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE
	graphNode.prev = graphNode
	graphNode.next = graphNode
	graphNode.parent = nil
	graphNode.children = nil
end

-- from src/engine/graph_node.c:init_graph_node_root L37-57
function graph_node.init_graph_node_root(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeRoot?, areaIndex: number, x: number, y: number, width: number, height: number): GroupsTypesHPlus3Types.GraphNodeRoot?
	areaIndex = S16(TruncS32(areaIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	width = S16(TruncS32(width))
	height = S16(TruncS32(height))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeRoot()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_ROOT)

		graphNode.areaIndex = U8(areaIndex)
		graphNode.unk15 = 0
		graphNode.x = x
		graphNode.y = y
		graphNode.width = width
		graphNode.height = height
		graphNode.views = nil
		graphNode.numViews = 0
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_ortho_projection L62-75
function graph_node.init_graph_node_ortho_projection(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeOrthoProjection?, scale: number): GroupsTypesHPlus3Types.GraphNodeOrthoProjection?
	scale = F32(scale)
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeOrthoProjection()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_ORTHO_PROJECTION)
		graphNode.scale = scale
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_perspective L80-103
function graph_node.init_graph_node_perspective(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodePerspective?, fov: number, near: number, far: number, nodeFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, unused: number): GroupsTypesHPlus3Types.GraphNodePerspective?
	fov = F32(fov)
	near = S16(TruncS32(near))
	far = S16(TruncS32(far))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodePerspective()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_PERSPECTIVE)

		graphNode.fov = fov
		graphNode.near = near
		graphNode.far = far
		graphNode.func = nodeFunc
		graphNode.unused = unused

		if nodeFunc ~= nil then
			nodeFunc(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_start L108-119
function graph_node.init_graph_node_start(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeStart?): GroupsTypesHPlus3Types.GraphNodeStart?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeStart()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_START)
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_master_list L124-139
function graph_node.init_graph_node_master_list(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeMasterList?, on: number): GroupsTypesHPlus3Types.GraphNodeMasterList?
	on = S16(TruncS32(on))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeMasterList()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_MASTER_LIST)

		if on ~= 0 then
			graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_Z_BUFFER))
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_render_range L144-158
function graph_node.init_graph_node_render_range(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeLevelOfDetail?, minDistance: number, maxDistance: number): GroupsTypesHPlus3Types.GraphNodeLevelOfDetail?
	minDistance = S16(TruncS32(minDistance))
	maxDistance = S16(TruncS32(maxDistance))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeLevelOfDetail()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_LEVEL_OF_DETAIL)
		graphNode.minDistance = minDistance
		graphNode.maxDistance = maxDistance
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_switch_case L163-184
function graph_node.init_graph_node_switch_case(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeSwitchCase?, numCases: number, selectedCase: number, nodeFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, unused: number): GroupsTypesHPlus3Types.GraphNodeSwitchCase?
	numCases = S16(TruncS32(numCases))
	selectedCase = S16(TruncS32(selectedCase))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeSwitchCase()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_SWITCH_CASE)
		graphNode.numCases = numCases
		graphNode.selectedCase = selectedCase
		graphNode.func = nodeFunc
		graphNode.unused = unused

		if nodeFunc ~= nil then
			nodeFunc(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_camera L189-211
function graph_node.init_graph_node_camera(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeCamera?, pos: { number }, focus: { number }, func: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, mode: number): GroupsTypesHPlus3Types.GraphNodeCamera?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeCamera()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_CAMERA)
		MathUtil.vec3f_copy(graphNode.pos, pos)
		MathUtil.vec3f_copy(graphNode.focus, focus)
		graphNode.func = func
		graphNode.config.mode = mode
		graphNode.roll = 0
		graphNode.rollScreen = 0

		if func ~= nil then
			func(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_translation_rotation L216-234
function graph_node.init_graph_node_translation_rotation(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeTranslationRotation?, drawingLayer: number, displayList: unknown, translation: { number }, rotation: { number }): GroupsTypesHPlus3Types.GraphNodeTranslationRotation?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeTranslationRotation()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_TRANSLATION_ROTATION)

		MathUtil.vec3s_copy(graphNode.translation, translation)
		MathUtil.vec3s_copy(graphNode.rotation, rotation)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_translation L239-256
function graph_node.init_graph_node_translation(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeTranslation?, drawingLayer: number, displayList: unknown, translation: { number }): GroupsTypesHPlus3Types.GraphNodeTranslation?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeTranslation()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_TRANSLATION)

		MathUtil.vec3s_copy(graphNode.translation, translation)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_rotation L261-277
function graph_node.init_graph_node_rotation(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeRotation?, drawingLayer: number, displayList: unknown, rotation: { number }): GroupsTypesHPlus3Types.GraphNodeRotation?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeRotation()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_ROTATION)
		MathUtil.vec3s_copy(graphNode.rotation, rotation)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_scale L282-297
function graph_node.init_graph_node_scale(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeScale?, drawingLayer: number, displayList: unknown, scale: number): GroupsTypesHPlus3Types.GraphNodeScale?
	scale = F32(scale)
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeScale()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_SCALE)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.scale = scale
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_object L302-327
function graph_node.init_graph_node_object(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeObject?, sharedChild: GroupsTypesHPlus3Types.GraphNode?, pos: { number }, angle: { number }, scale: { number }): GroupsTypesHPlus3Types.GraphNodeObject?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeObject()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT)
		MathUtil.vec3f_copy(graphNode.pos, pos)
		MathUtil.vec3f_copy(graphNode.scale, scale)
		MathUtil.vec3s_copy(graphNode.angle, angle)
		graphNode.sharedChild = sharedChild
		graphNode.throwMatrix = nil
		graphNode.animInfo.animID = 0
		graphNode.animInfo.curAnim = nil
		graphNode.animInfo.animFrame = 0
		graphNode.animInfo.animFrameAccelAssist = 0
		graphNode.animInfo.animAccel = 0x10000
		graphNode.animInfo.animTimer = 0
		graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION))
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_culling_radius L332-345
function graph_node.init_graph_node_culling_radius(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeCullingRadius?, radius: number): GroupsTypesHPlus3Types.GraphNodeCullingRadius?
	radius = S16(TruncS32(radius))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeCullingRadius()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_CULLING_RADIUS)
		graphNode.cullingRadius = radius
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_animated_part L350-366
function graph_node.init_graph_node_animated_part(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeAnimatedPart?, drawingLayer: number, displayList: unknown, translation: { number }): GroupsTypesHPlus3Types.GraphNodeAnimatedPart?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeAnimatedPart()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_ANIMATED_PART)
		MathUtil.vec3s_copy(graphNode.translation, translation)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_billboard L371-387
function graph_node.init_graph_node_billboard(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeBillboard?, drawingLayer: number, displayList: unknown, translation: { number }): GroupsTypesHPlus3Types.GraphNodeBillboard?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeBillboard()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_BILLBOARD)
		MathUtil.vec3s_copy(graphNode.translation, translation)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_display_list L392-406
function graph_node.init_graph_node_display_list(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeDisplayList?, drawingLayer: number, displayList: unknown): GroupsTypesHPlus3Types.GraphNodeDisplayList?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeDisplayList()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_DISPLAY_LIST)
		graphNode.node.flags = S16(bit32.bor(bit32.lshift(drawingLayer, 8), bit32.band(graphNode.node.flags, 0xFF)))
		graphNode.displayList = displayList
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_shadow L411-426
function graph_node.init_graph_node_shadow(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeShadow?, shadowScale: number, shadowSolidity: number, shadowType: number): GroupsTypesHPlus3Types.GraphNodeShadow?
	shadowScale = S16(TruncS32(shadowScale))
	shadowSolidity = U8(TruncS32(shadowSolidity))
	shadowType = U8(TruncS32(shadowType))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeShadow()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_SHADOW)
		graphNode.shadowScale = shadowScale
		graphNode.shadowSolidity = shadowSolidity
		graphNode.shadowType = shadowType
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_object_parent L431-444
function graph_node.init_graph_node_object_parent(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeObjectParent?, sharedChild: GroupsTypesHPlus3Types.GraphNode?): GroupsTypesHPlus3Types.GraphNodeObjectParent?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeObjectParent()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT_PARENT)
		graphNode.sharedChild = sharedChild
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_generated L449-467
function graph_node.init_graph_node_generated(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeGenerated?, gfxFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, parameter: number): GroupsTypesHPlus3Types.GraphNodeGenerated?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeGenerated()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_GENERATED_LIST)
		graphNode.func = gfxFunc
		graphNode.parameter = parameter

		if gfxFunc ~= nil then
			gfxFunc(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_background L472-493
function graph_node.init_graph_node_background(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeBackground?, background: number, backgroundFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, zero: number): GroupsTypesHPlus3Types.GraphNodeBackground?
	background = U16(TruncS32(background))
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeBackground()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_BACKGROUND)

		graphNode.background = S32(bit32.bor(bit32.lshift(background, 16), background))
		graphNode.func = backgroundFunc
		graphNode.unused = zero -- always 0, unused

		if backgroundFunc ~= nil then
			backgroundFunc(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:init_graph_node_held_object L498-520
function graph_node.init_graph_node_held_object(pool: SrcGameMemoryH.AllocOnlyPool?, graphNode: GroupsTypesHPlus3Types.GraphNodeHeldObject?, objNode: GroupsTypesHPlus3Types.Object?, translation: { number }, nodeFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?, playerIndex: number): GroupsTypesHPlus3Types.GraphNodeHeldObject?
	if pool ~= nil then
		graphNode = GroupsTypesHPlus3.new_GraphNodeHeldObject()
	end

	if graphNode ~= nil then
		graph_node.init_scene_graph_node_links(graphNode.node, GroupsTypesHPlus3.GRAPH_NODE_TYPE_HELD_OBJ)
		MathUtil.vec3s_copy(graphNode.translation, translation)
		graphNode.objNode = objNode
		graphNode.func = nodeFunc
		graphNode.playerIndex = playerIndex

		if nodeFunc ~= nil then
			nodeFunc(GroupsTypesHPlus3.GEO_CONTEXT_CREATE, graphNode.node, pool)
		end
	end

	return graphNode
end

-- from src/engine/graph_node.c:geo_add_child L525-547
function graph_node.geo_add_child(parent: GroupsTypesHPlus3Types.GraphNode, childNode: GroupsTypesHPlus3Types.GraphNode?): GroupsTypesHPlus3Types.GraphNode?
	if childNode ~= nil then
		childNode.parent = parent
		const parentFirstChild = parent.children

		if parentFirstChild == nil then
			parent.children = childNode
			childNode.prev = childNode
			childNode.next = childNode
		else
			const parentLastChild = parentFirstChild.prev :: GroupsTypesHPlus3Types.GraphNode

			childNode.prev = parentLastChild
			childNode.next = parentFirstChild
			parentFirstChild.prev = childNode
			parentLastChild.next = childNode
		end
	end

	return childNode
end

-- from src/engine/graph_node.c:geo_remove_child L555-577
function graph_node.geo_remove_child(graphNode: GroupsTypesHPlus3Types.GraphNode): GroupsTypesHPlus3Types.GraphNode
	const parent = graphNode.parent :: GroupsTypesHPlus3Types.GraphNode

	-- Remove link with siblings
	const prevSibling = graphNode.prev :: GroupsTypesHPlus3Types.GraphNode
	prevSibling.next = graphNode.next
	const nextSibling = graphNode.next :: GroupsTypesHPlus3Types.GraphNode
	nextSibling.prev = graphNode.prev

	-- If this node was the first child, a new first child must be chosen
	if parent.children == graphNode then
		-- The list is circular, so this checks whether it was the only child
		if graphNode.next == graphNode then
			parent.children = nil -- Parent has no children anymore
		else
			parent.children = graphNode.next -- Choose a new first child
		end
	end

	return parent
end

-- from src/engine/graph_node.c:geo_make_first_child L585-607
function graph_node.geo_make_first_child(newFirstChild: GroupsTypesHPlus3Types.GraphNode): GroupsTypesHPlus3Types.GraphNode
	const parent = newFirstChild.parent :: GroupsTypesHPlus3Types.GraphNode

	if parent.children ~= newFirstChild then
		const firstChild = parent.children :: GroupsTypesHPlus3Types.GraphNode

		if firstChild.prev ~= newFirstChild then
			const prevSibling = newFirstChild.prev :: GroupsTypesHPlus3Types.GraphNode
			prevSibling.next = newFirstChild.next
			const nextSibling = newFirstChild.next :: GroupsTypesHPlus3Types.GraphNode
			nextSibling.prev = newFirstChild.prev

			const lastSibling = firstChild.prev :: GroupsTypesHPlus3Types.GraphNode
			newFirstChild.prev = lastSibling
			newFirstChild.next = firstChild
			firstChild.prev = newFirstChild
			lastSibling.next = newFirstChild
		end

		parent.children = newFirstChild
	end

	return parent
end

-- from src/engine/graph_node.c:geo_call_global_function_nodes_helper L613-659
function graph_node.geo_call_global_function_nodes_helper(graphNode: GroupsTypesHPlus3Types.GraphNode, callContext: number)
	local curNode = graphNode

	repeat
		const asFnNode = curNode :: GroupsTypesHPlus3Types.FnGraphNode

		if bit32.btest(curNode.type_, GroupsTypesHPlus3.GRAPH_NODE_TYPE_FUNCTIONAL) then
			if asFnNode.func ~= nil then
				asFnNode.func(callContext, curNode, nil)
			end
		end

		if curNode.children ~= nil then
			if curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_MASTER_LIST then
				SrcGameRenderingGraphNode.gCurGraphNodeMasterList = curNode :: GroupsTypesHPlus3Types.GraphNodeMasterList
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_PERSPECTIVE then
				SrcGameRenderingGraphNode.gCurGraphNodeCamFrustum = curNode :: GroupsTypesHPlus3Types.GraphNodePerspective
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_CAMERA then
				SrcGameRenderingGraphNode.gCurGraphNodeCamera = curNode :: GroupsTypesHPlus3Types.GraphNodeCamera
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT then
				SrcGameRenderingGraphNode.gCurGraphNodeObject = curNode :: GroupsTypesHPlus3Types.GraphNodeObject
			end

			graph_node.geo_call_global_function_nodes_helper(curNode.children, callContext)

			if curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_MASTER_LIST then
				SrcGameRenderingGraphNode.gCurGraphNodeMasterList = nil
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_PERSPECTIVE then
				SrcGameRenderingGraphNode.gCurGraphNodeCamFrustum = nil
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_CAMERA then
				SrcGameRenderingGraphNode.gCurGraphNodeCamera = nil
			elseif curNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT then
				SrcGameRenderingGraphNode.gCurGraphNodeObject = nil
			end
		end

		curNode = curNode.next :: GroupsTypesHPlus3Types.GraphNode
	until curNode == graphNode
end

-- from src/engine/graph_node.c:geo_call_global_function_nodes L668-678
function graph_node.geo_call_global_function_nodes(graphNode: GroupsTypesHPlus3Types.GraphNode, callContext: number)
	if bit32.btest(graphNode.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		SrcGameRenderingGraphNode.gCurGraphNodeRoot = graphNode :: GroupsTypesHPlus3Types.GraphNodeRoot

		if graphNode.children ~= nil then
			graph_node.geo_call_global_function_nodes_helper(graphNode.children, callContext)
		end

		SrcGameRenderingGraphNode.gCurGraphNodeRoot = nil
	end
end

-- from src/engine/graph_node.c:geo_reset_object_node L683-688
function graph_node.geo_reset_object_node(graphNode: GroupsTypesHPlus3Types.GraphNodeObject)
	graph_node.init_graph_node_object(nil, graphNode, nil, graph_node.gVec3fZero, graph_node.gVec3sZero, graph_node.gVec3fOne)

	graph_node.geo_add_child(Registry.Members.src__engine__geo_layout.gObjParentGraphNode, graphNode.node)
	graphNode.node.flags = S16(bit32.band(graphNode.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
end

-- from src/engine/graph_node.c:geo_obj_init L693-707
function graph_node.geo_obj_init(graphNode: GroupsTypesHPlus3Types.GraphNodeObject, sharedChild: unknown, pos: { number }, angle: { number })
	MathUtil.vec3f_set(graphNode.scale, 1.0, 1.0, 1.0)
	MathUtil.vec3f_copy(graphNode.pos, pos)
	MathUtil.vec3s_copy(graphNode.angle, angle)

	graphNode.sharedChild = sharedChild :: GroupsTypesHPlus3Types.GraphNode?
	graphNode.unk4C = nil
	graphNode.throwMatrix = nil
	graphNode.animInfo.curAnim = nil

	graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
	graphNode.node.flags = S16(bit32.band(graphNode.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION))
	graphNode.node.flags = S16(bit32.band(graphNode.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD)))
end

-- from src/engine/graph_node.c:geo_obj_init_spawninfo L712-731
function graph_node.geo_obj_init_spawninfo(graphNode: GroupsTypesHPlus3Types.GraphNodeObject, spawn: GroupsTypesHPlus3Types.SpawnInfo)
	MathUtil.vec3f_set(graphNode.scale, 1.0, 1.0, 1.0)
	MathUtil.vec3s_copy(graphNode.angle, spawn.startAngle)

	graphNode.pos[1] = spawn.startPos[1]
	graphNode.pos[2] = spawn.startPos[2]
	graphNode.pos[3] = spawn.startPos[3]

	graphNode.areaIndex = spawn.areaIndex
	graphNode.activeAreaIndex = spawn.activeAreaIndex
	graphNode.sharedChild = spawn.model
	graphNode.unk4C = spawn
	graphNode.throwMatrix = nil
	graphNode.animInfo.curAnim = nil

	graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
	graphNode.node.flags = S16(bit32.band(graphNode.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	graphNode.node.flags = S16(bit32.bor(graphNode.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION))
	graphNode.node.flags = S16(bit32.band(graphNode.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD)))
end

-- from src/engine/graph_node.c:geo_obj_init_animation L736-746
function graph_node.geo_obj_init_animation(graphNode: GroupsTypesHPlus3Types.GraphNodeObject, animPtrAddr: number)
	const animSegmented = SrcGameMemory.segmented_to_virtual(animPtrAddr)
	const anim = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(animSegmented))

	if graphNode.animInfo.curAnim ~= anim then
		graphNode.animInfo.curAnim = anim
		graphNode.animInfo.animFrame = S16(Rom.ReadS16(anim + 4) + (if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then 1 else -1))
		graphNode.animInfo.animAccel = 0
		graphNode.animInfo.animYTrans = 0
	end
end

-- from src/engine/graph_node.c:geo_obj_init_animation_accel L751-764
function graph_node.geo_obj_init_animation_accel(graphNode: GroupsTypesHPlus3Types.GraphNodeObject, animPtrAddr: number, animAccel: number)
	const animSegmented = SrcGameMemory.segmented_to_virtual(animPtrAddr)
	const anim = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(animSegmented))

	if graphNode.animInfo.curAnim ~= anim then
		graphNode.animInfo.curAnim = anim
		graphNode.animInfo.animYTrans = 0
		graphNode.animInfo.animFrameAccelAssist = S32(bit32.lshift(Rom.ReadS16(anim + 4), 16) + (if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then animAccel else -animAccel))
		graphNode.animInfo.animFrame = S16(bit32.arshift(graphNode.animInfo.animFrameAccelAssist, 16))
	end

	graphNode.animInfo.animAccel = animAccel
end

-- from src/engine/graph_node.c:retrieve_animation_index L773-785
function graph_node.retrieve_animation_index(frame: number, attributes: { number }): number
	const indexAddress = attributes[1]
	const count = Rom.ReadU16(indexAddress)
	const base = Rom.ReadU16(indexAddress + 2)
	local result: number

	if frame < count then
		result = base + frame
	else
		result = base + count - 1
	end

	attributes[1] += 2 * 2

	return result
end

-- from src/engine/graph_node.c:geo_update_animation_frame L792-839
function graph_node.geo_update_animation_frame(obj: GroupsTypesHPlus3Types.AnimInfo, accelAssist: { number }?): number
	const anim = obj.curAnim :: number

	if obj.animTimer == SrcGameRenderingGraphNode.gAreaUpdateCounter or bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_2) then
		if accelAssist ~= nil then
			accelAssist[1] = obj.animFrameAccelAssist
		end

		return obj.animFrame
	end

	local result: number

	if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_BACKWARD) then
		if obj.animAccel ~= 0 then
			result = S32(obj.animFrameAccelAssist - obj.animAccel)
		else
			result = S32(bit32.lshift(obj.animFrame - 1, 16))
		end

		if result // 65536 < Rom.ReadS16(anim + 6) then
			if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_NOLOOP) then
				result = S32(bit32.bor(bit32.band(result, 0xFFFF), bit32.lshift(Rom.ReadS16(anim + 6), 16)))
			else
				result = S32(bit32.bor(bit32.band(result, 0xFFFF), bit32.lshift(Rom.ReadS16(anim + 8) - 1, 16)))
			end
		end
	else
		if obj.animAccel ~= 0 then
			result = S32(obj.animFrameAccelAssist + obj.animAccel)
		else
			result = S32(bit32.lshift(obj.animFrame + 1, 16))
		end

		if result // 65536 >= Rom.ReadS16(anim + 8) then
			if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_NOLOOP) then
				result = S32(bit32.bor(bit32.band(result, 0xFFFF), bit32.lshift(Rom.ReadS16(anim + 8) - 1, 16)))
			else
				result = S32(bit32.bor(bit32.band(result, 0xFFFF), bit32.lshift(Rom.ReadS16(anim + 6), 16)))
			end
		end
	end

	if accelAssist ~= nil then
		accelAssist[1] = result
	end

	return result // 65536
end

-- from src/engine/graph_node.c:geo_retreive_animation_translation L849-868
function graph_node.geo_retreive_animation_translation(obj: GroupsTypesHPlus3Types.GraphNodeObject, position: { number })
	const animation = obj.animInfo.curAnim

	if animation ~= nil then
		AttributesScratch[1] = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(animation + 16))
		const values = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(animation + 12))

		local frame = obj.animInfo.animFrame

		if frame < 0 then
			frame = 0
		end

		position[1] = Rom.ReadS16(values + 2 * graph_node.retrieve_animation_index(frame, AttributesScratch))
		position[2] = Rom.ReadS16(values + 2 * graph_node.retrieve_animation_index(frame, AttributesScratch))
		position[3] = Rom.ReadS16(values + 2 * graph_node.retrieve_animation_index(frame, AttributesScratch))
	else
		MathUtil.vec3f_set(position, 0, 0, 0)
	end
end

-- from src/engine/graph_node.c:geo_find_root L874-886
function graph_node.geo_find_root(graphNode: GroupsTypesHPlus3Types.GraphNode): GroupsTypesHPlus3Types.GraphNodeRoot?
	while graphNode.parent ~= nil do
		graphNode = graphNode.parent :: GroupsTypesHPlus3Types.GraphNode
	end

	local resGraphNode: GroupsTypesHPlus3Types.GraphNodeRoot? = nil

	if graphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_ROOT then
		resGraphNode = graphNode :: GroupsTypesHPlus3Types.GraphNodeRoot
	end

	return resGraphNode
end

return graph_node
