--!strict
--!optimize 2

--[[
	Port of src/engine/geo_layout.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const SrcGameMemoryH = require("../game/memory_h")
const GeoLayoutH = require("./geo_layout_h")
const SrcGameMemory = require("../game/memory")
const GraphNode = require("./graph_node")
const MathUtil = require("./math_util")
const Rom = require("../rom/rom")
const NativeCalls = require("../rom/native_calls")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/engine/geo_layout.c:data
const geo_layout = {
	-- from src/engine/geo_layout.c:gObjParentGraphNode L47-47
	gObjParentGraphNode = GroupsTypesHPlus3Types.new_GraphNodeObjectParent(),
	-- from src/engine/geo_layout.c:gGraphNodePool L48-48
	gGraphNodePool = nil :: SrcGameMemoryH.AllocOnlyPool?,
	-- from src/engine/geo_layout.c:gCurRootGraphNode L49-49
	gCurRootGraphNode = nil :: GroupsTypesHPlus3Types.GraphNode?,
	-- from src/engine/geo_layout.c:D_8038BCA8 L51-51
	D_8038BCA8 = 0,
	-- from src/engine/geo_layout.c:gGeoViews L92-92
	gGeoViews = nil :: { GroupsTypesHPlus3Types.GraphNode? }?,
	-- from src/engine/geo_layout.c:gGeoNumViews L93-93
	gGeoNumViews = 0,
	-- from src/engine/geo_layout.c:gGeoLayoutStack L95-95
	gGeoLayoutStack = table.create(16, 0),
	-- from src/engine/geo_layout.c:gCurGraphNodeList L96-96
	gCurGraphNodeList = {
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	} :: { GroupsTypesHPlus3Types.GraphNode? },
	-- from src/engine/geo_layout.c:gCurGraphNodeIndex L97-97
	gCurGraphNodeIndex = 0,
	-- from src/engine/geo_layout.c:gGeoLayoutStackIndex L98-98
	gGeoLayoutStackIndex = 0,
	-- from src/engine/geo_layout.c:D_8038BD7C L99-99
	D_8038BD7C = 0,
	-- from src/engine/geo_layout.c:gGeoLayoutReturnIndex L100-100
	gGeoLayoutReturnIndex = 0,
	-- from src/engine/geo_layout.c:gGeoLayoutCommand L101-101
	gGeoLayoutCommand = 0,
	-- from src/engine/geo_layout.c:unused_8038B894 L103-103
	unused_8038B894 = { 0, 0, 0 },
}

Registry.Register("src__engine__geo_layout", geo_layout)

-- Script cursor of the node commands (the C cmdPos); read_vec3s advances it in place
const CommandCursorScratch = table.create(1, 0)
-- Vec3s locals of the node commands that are passed by pointer to the init functions (no re-entrancy)
const TranslationScratch = table.create(3, 0)
const RotationScratch = table.create(3, 0)
const Sp2cScratch = table.create(3, 0)
-- Vec3f locals of geo_layout_cmd_node_camera that are passed by pointer to init_graph_node_camera
const PositionScratch = table.create(3, 0)
const FocusScratch = table.create(3, 0)

-- The function of the script slot at the command offset, nil where the word is NULL (rom-function-pointer-table, rom-block-source)
const function CurGeoCmdFunction(Offset: number): ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)?
	if GeoLayoutH.cur_geo_cmd_ptr(Offset) == 0 then
		return nil
	end

	const BlockStart, SlotOffset = Rom.BlockOf(geo_layout.gGeoLayoutCommand + GeoLayoutH.CMD_PROCESS_OFFSET(Offset))

	return NativeCalls.FunctionAt(BlockStart, SlotOffset) :: (number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown
end

-- from src/engine/geo_layout.c:geo_layout_cmd_branch_and_link L109-114
function geo_layout.geo_layout_cmd_branch_and_link()
	geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1] = geo_layout.gGeoLayoutCommand + GeoLayoutH.CMD_PROCESS_OFFSET(8)
	geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex + 1)
	geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1] = bit32.lshift(geo_layout.gCurGraphNodeIndex, 16) + geo_layout.gGeoLayoutReturnIndex
	geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex + 1)
	geo_layout.gGeoLayoutReturnIndex = geo_layout.gGeoLayoutStackIndex
	geo_layout.gGeoLayoutCommand = SrcGameMemory.segmented_to_virtual(GeoLayoutH.cur_geo_cmd_ptr(0x04))
end

-- from src/engine/geo_layout.c:geo_layout_cmd_end L117-122
function geo_layout.geo_layout_cmd_end()
	geo_layout.gGeoLayoutStackIndex = geo_layout.gGeoLayoutReturnIndex
	geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex - 1)
	geo_layout.gGeoLayoutReturnIndex = S16(bit32.band(geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1], 0xFFFF))
	geo_layout.gCurGraphNodeIndex = S16(bit32.rshift(geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1], 16))
	geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex - 1)
	geo_layout.gGeoLayoutCommand = geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_branch L128-134
function geo_layout.geo_layout_cmd_branch()
	if GeoLayoutH.cur_geo_cmd_u8(0x01) == 1 then
		geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1] = geo_layout.gGeoLayoutCommand + GeoLayoutH.CMD_PROCESS_OFFSET(8)
		geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex + 1)
	end

	geo_layout.gGeoLayoutCommand = SrcGameMemory.segmented_to_virtual(GeoLayoutH.cur_geo_cmd_ptr(0x04))
end

-- from src/engine/geo_layout.c:geo_layout_cmd_return L137-139
function geo_layout.geo_layout_cmd_return()
	geo_layout.gGeoLayoutStackIndex = S16(geo_layout.gGeoLayoutStackIndex - 1)
	geo_layout.gGeoLayoutCommand = geo_layout.gGeoLayoutStack[geo_layout.gGeoLayoutStackIndex + 1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_open_node L142-146
function geo_layout.geo_layout_cmd_open_node()
	geo_layout.gCurGraphNodeList[geo_layout.gCurGraphNodeIndex + 2] = geo_layout.gCurGraphNodeList[geo_layout.gCurGraphNodeIndex + 1]
	geo_layout.gCurGraphNodeIndex = S16(geo_layout.gCurGraphNodeIndex + 1)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_close_node L149-152
function geo_layout.geo_layout_cmd_close_node()
	geo_layout.gCurGraphNodeIndex = S16(geo_layout.gCurGraphNodeIndex - 1)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_assign_as_view L160-168
function geo_layout.geo_layout_cmd_assign_as_view()
	const index = U16(GeoLayoutH.cur_geo_cmd_s16(0x02))

	if index < geo_layout.gGeoNumViews then
		const views = geo_layout.gGeoViews :: { GroupsTypesHPlus3Types.GraphNode? }

		views[index + 1] = geo_layout.gCurGraphNodeList[geo_layout.gCurGraphNodeIndex + 1]
	end

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_update_node_flags L175-192
function geo_layout.geo_layout_cmd_update_node_flags()
	const operation = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const flagBits = U16(GeoLayoutH.cur_geo_cmd_s16(0x02))
	const graphNode = geo_layout.gCurGraphNodeList[geo_layout.gCurGraphNodeIndex + 1] :: GroupsTypesHPlus3Types.GraphNode

	if operation == GeoLayoutH.GEO_CMD_FLAGS_RESET then
		graphNode.flags = S16(flagBits)
	elseif operation == GeoLayoutH.GEO_CMD_FLAGS_SET then
		graphNode.flags = S16(bit32.bor(graphNode.flags, flagBits))
	elseif operation == GeoLayoutH.GEO_CMD_FLAGS_CLEAR then
		graphNode.flags = S16(bit32.band(graphNode.flags, bit32.bnot(flagBits)))
	end

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_root L202-231
function geo_layout.geo_layout_cmd_node_root()
	const x = GeoLayoutH.cur_geo_cmd_s16(0x04)
	const y = GeoLayoutH.cur_geo_cmd_s16(0x06)
	const width = GeoLayoutH.cur_geo_cmd_s16(0x08)
	const height = GeoLayoutH.cur_geo_cmd_s16(0x0A)

	geo_layout.gGeoNumViews = U16(GeoLayoutH.cur_geo_cmd_s16(0x02) + 2)

	const graphNode = GraphNode.init_graph_node_root(geo_layout.gGraphNodePool, nil, 0, x, y, width, height) :: GroupsTypesHPlus3Types.GraphNodeRoot

	const views = table.create(geo_layout.gGeoNumViews, nil) :: { GroupsTypesHPlus3Types.GraphNode? }

	geo_layout.gGeoViews = views
	graphNode.views = views
	graphNode.numViews = S16(geo_layout.gGeoNumViews)

	for i = 0, geo_layout.gGeoNumViews - 1 do
		views[i + 1] = nil
	end

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x0C, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_ortho_projection L237-246
function geo_layout.geo_layout_cmd_node_ortho_projection()
	const scale = F32(GeoLayoutH.cur_geo_cmd_s16(0x02) / 100)
	const graphNode = GraphNode.init_graph_node_ortho_projection(geo_layout.gGraphNodePool, nil, scale) :: GroupsTypesHPlus3Types.GraphNodeOrthoProjection

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_perspective L256-274
function geo_layout.geo_layout_cmd_node_perspective()
	local frustumFunc: ((number, GroupsTypesHPlus3Types.GraphNode, unknown) -> unknown)? = nil
	const fov = GeoLayoutH.cur_geo_cmd_s16(0x02)
	const near = GeoLayoutH.cur_geo_cmd_s16(0x04)
	const far = GeoLayoutH.cur_geo_cmd_s16(0x06)

	if GeoLayoutH.cur_geo_cmd_u8(0x01) ~= 0 then
		-- optional asm function
		frustumFunc = CurGeoCmdFunction(0x08)
		geo_layout.gGeoLayoutCommand += bit32.lshift(4, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_perspective(geo_layout.gGraphNodePool, nil, fov, near, far, frustumFunc, 0) :: GroupsTypesHPlus3Types.GraphNodePerspective

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_start L280-288
function geo_layout.geo_layout_cmd_node_start()
	const graphNode = GraphNode.init_graph_node_start(geo_layout.gGraphNodePool, nil) :: GroupsTypesHPlus3Types.GraphNodeStart

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_nop3 L291-293
function geo_layout.geo_layout_cmd_nop3()
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x10, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_master_list L299-307
function geo_layout.geo_layout_cmd_node_master_list()
	const graphNode = GraphNode.init_graph_node_master_list(geo_layout.gGraphNodePool, nil, GeoLayoutH.cur_geo_cmd_u8(0x01)) :: GroupsTypesHPlus3Types.GraphNodeMasterList

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_level_of_detail L315-325
function geo_layout.geo_layout_cmd_node_level_of_detail()
	const minDistance = GeoLayoutH.cur_geo_cmd_s16(0x04)
	const maxDistance = GeoLayoutH.cur_geo_cmd_s16(0x06)
	const graphNode = GraphNode.init_graph_node_render_range(geo_layout.gGraphNodePool, nil, minDistance, maxDistance) :: GroupsTypesHPlus3Types.GraphNodeLevelOfDetail

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_switch_case L335-348
function geo_layout.geo_layout_cmd_node_switch_case()
	const graphNode = GraphNode.init_graph_node_switch_case(
		geo_layout.gGraphNodePool,
		nil,
		GeoLayoutH.cur_geo_cmd_s16(0x02), -- case which is initially selected
		0,
		CurGeoCmdFunction(0x04), -- case update function
		0
	) :: GroupsTypesHPlus3Types.GraphNodeSwitchCase

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_camera L361-378
function geo_layout.geo_layout_cmd_node_camera()
	const cmdPos = CommandCursorScratch

	cmdPos[1] = geo_layout.gGeoLayoutCommand + 4

	Registry.Members.src__engine__graph_node_manager.read_vec3s_to_vec3f(PositionScratch, cmdPos)
	Registry.Members.src__engine__graph_node_manager.read_vec3s_to_vec3f(FocusScratch, cmdPos)

	const graphNode = GraphNode.init_graph_node_camera(geo_layout.gGraphNodePool, nil, PositionScratch, FocusScratch, CurGeoCmdFunction(0x10), GeoLayoutH.cur_geo_cmd_s16(0x02)) :: GroupsTypesHPlus3Types.GraphNodeCamera

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	const geoViews = geo_layout.gGeoViews :: { GroupsTypesHPlus3Types.GraphNode? }

	geoViews[1] = graphNode.node

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x14, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_translation_rotation L414-456
function geo_layout.geo_layout_cmd_node_translation_rotation()
	const params = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const cmdPos = CommandCursorScratch
	const mode = bit32.band(params, 0x70) // 16
	local drawingLayer = 0
	local displayList: number? = nil

	cmdPos[1] = geo_layout.gGeoLayoutCommand

	if mode == 0 then
		cmdPos[1] += 2 * 2
		Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)
		Registry.Members.src__engine__graph_node_manager.read_vec3s_angle(RotationScratch, cmdPos)
	elseif mode == 1 then
		cmdPos[1] += 2 * 1
		Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)
		MathUtil.vec3s_copy(RotationScratch, GraphNode.gVec3sZero)
	elseif mode == 2 then
		cmdPos[1] += 2 * 1
		Registry.Members.src__engine__graph_node_manager.read_vec3s_angle(RotationScratch, cmdPos)
		MathUtil.vec3s_copy(TranslationScratch, GraphNode.gVec3sZero)
	elseif mode == 3 then
		MathUtil.vec3s_copy(TranslationScratch, GraphNode.gVec3sZero)
		MathUtil.vec3s_set(RotationScratch, 0, S16(math.modf(S32(bit32.lshift(Rom.ReadS16(cmdPos[1] + 2 * 1), 15)) / 180)), 0)
		cmdPos[1] += bit32.lshift(2 * 2, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	if bit32.btest(params, 0x80) then
		displayList = Rom.ReadU32(cmdPos[1])
		drawingLayer = bit32.band(params, 0x0F)
		cmdPos[1] += bit32.lshift(2 * 2, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_translation_rotation(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, TranslationScratch, RotationScratch) :: GroupsTypesHPlus3Types.GraphNodeTranslationRotation

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand = cmdPos[1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_translation L468-492
function geo_layout.geo_layout_cmd_node_translation()
	const params = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const cmdPos = CommandCursorScratch
	local drawingLayer = 0
	local displayList: number? = nil

	cmdPos[1] = geo_layout.gGeoLayoutCommand
	cmdPos[1] += 2 * 1
	Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)

	if bit32.btest(params, 0x80) then
		displayList = Rom.ReadU32(cmdPos[1])
		drawingLayer = bit32.band(params, 0x0F)
		cmdPos[1] += bit32.lshift(2 * 2, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_translation(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, TranslationScratch) :: GroupsTypesHPlus3Types.GraphNodeTranslation

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand = cmdPos[1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_rotation L504-527
function geo_layout.geo_layout_cmd_node_rotation()
	const params = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const cmdPos = CommandCursorScratch
	local drawingLayer = 0
	local displayList: number? = nil

	cmdPos[1] = geo_layout.gGeoLayoutCommand
	cmdPos[1] += 2 * 1
	Registry.Members.src__engine__graph_node_manager.read_vec3s_angle(Sp2cScratch, cmdPos)

	if bit32.btest(params, 0x80) then
		displayList = Rom.ReadU32(cmdPos[1])
		drawingLayer = bit32.band(params, 0x0F)
		cmdPos[1] += bit32.lshift(2 * 2, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_rotation(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, Sp2cScratch) :: GroupsTypesHPlus3Types.GraphNodeRotation

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand = cmdPos[1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_scale L537-556
function geo_layout.geo_layout_cmd_node_scale()
	local drawingLayer = 0
	const params = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const scale = F32(GeoLayoutH.cur_geo_cmd_u32(0x04) / 65536)
	local displayList: number? = nil

	if bit32.btest(params, 0x80) then
		displayList = GeoLayoutH.cur_geo_cmd_ptr(0x08)
		drawingLayer = bit32.band(params, 0x0F)
		geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_scale(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, scale) :: GroupsTypesHPlus3Types.GraphNodeScale

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_nop2 L559-561
function geo_layout.geo_layout_cmd_nop2()
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_animated_part L571-586
function geo_layout.geo_layout_cmd_node_animated_part()
	const drawingLayer = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const displayList = GeoLayoutH.cur_geo_cmd_ptr(0x08)
	const cmdPos = CommandCursorScratch

	cmdPos[1] = geo_layout.gGeoLayoutCommand
	cmdPos[1] += 2 * 1
	Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)

	const graphNode = GraphNode.init_graph_node_animated_part(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, TranslationScratch) :: GroupsTypesHPlus3Types.GraphNodeAnimatedPart

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x0C, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_billboard L598-619
function geo_layout.geo_layout_cmd_node_billboard()
	const params = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const cmdPos = CommandCursorScratch
	local drawingLayer = 0
	local displayList: number? = nil

	cmdPos[1] = geo_layout.gGeoLayoutCommand
	cmdPos[1] += 2 * 1
	Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)

	if bit32.btest(params, 0x80) then
		displayList = Rom.ReadU32(cmdPos[1])
		drawingLayer = bit32.band(params, 0x0F)
		cmdPos[1] += bit32.lshift(2 * 2, GeoLayoutH.CMD_SIZE_SHIFT)
	end

	const graphNode = GraphNode.init_graph_node_billboard(geo_layout.gGraphNodePool, nil, drawingLayer, displayList, TranslationScratch) :: GroupsTypesHPlus3Types.GraphNodeBillboard

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand = cmdPos[1]
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_display_list L626-636
function geo_layout.geo_layout_cmd_node_display_list()
	const drawingLayer = GeoLayoutH.cur_geo_cmd_u8(0x01)
	const displayList = GeoLayoutH.cur_geo_cmd_ptr(0x04)
	const graphNode = GraphNode.init_graph_node_display_list(geo_layout.gGraphNodePool, nil, drawingLayer, displayList) :: GroupsTypesHPlus3Types.GraphNodeDisplayList

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_shadow L644-655
function geo_layout.geo_layout_cmd_node_shadow()
	const shadowType = U8(GeoLayoutH.cur_geo_cmd_s16(0x02))
	const shadowSolidity = U8(GeoLayoutH.cur_geo_cmd_s16(0x04))
	const shadowScale = GeoLayoutH.cur_geo_cmd_s16(0x06)
	const graphNode = GraphNode.init_graph_node_shadow(geo_layout.gGraphNodePool, nil, shadowScale, shadowSolidity, shadowType) :: GroupsTypesHPlus3Types.GraphNodeShadow

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_object_parent L658-666
function geo_layout.geo_layout_cmd_node_object_parent()
	const graphNode = GraphNode.init_graph_node_object_parent(geo_layout.gGraphNodePool, nil, geo_layout.gObjParentGraphNode) :: GroupsTypesHPlus3Types.GraphNodeObjectParent

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_generated L673-683
function geo_layout.geo_layout_cmd_node_generated()
	const graphNode = GraphNode.init_graph_node_generated(
		geo_layout.gGraphNodePool,
		nil,
		CurGeoCmdFunction(0x04), -- asm function
		GeoLayoutH.cur_geo_cmd_s16(0x02) -- parameter
	) :: GroupsTypesHPlus3Types.GraphNodeGenerated

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_background L690-702
function geo_layout.geo_layout_cmd_node_background()
	const graphNode = GraphNode.init_graph_node_background(
		geo_layout.gGraphNodePool,
		nil,
		U16(GeoLayoutH.cur_geo_cmd_s16(0x02)), -- background ID, or RGBA5551 color if asm function is null
		CurGeoCmdFunction(0x04), -- asm function
		0
	) :: GroupsTypesHPlus3Types.GraphNodeBackground

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_nop L705-707
function geo_layout.geo_layout_cmd_nop()
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x08, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_copy_view L714-734
function geo_layout.geo_layout_cmd_copy_view()
	const index = GeoLayoutH.cur_geo_cmd_s16(0x02)
	local node: GroupsTypesHPlus3Types.GraphNode? = nil

	if index >= 0 then
		const views = geo_layout.gGeoViews :: { GroupsTypesHPlus3Types.GraphNode? }
		node = views[index + 1] :: GroupsTypesHPlus3Types.GraphNode

		if node.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT_PARENT then
			node = (node :: GroupsTypesHPlus3Types.GraphNodeObjectParent).sharedChild
		else
			node = nil
		end
	end

	const graphNode = GraphNode.init_graph_node_object_parent(geo_layout.gGraphNodePool, nil, node) :: GroupsTypesHPlus3Types.GraphNodeObjectParent

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_held_obj L744-756
function geo_layout.geo_layout_cmd_node_held_obj()
	const cmdPos = CommandCursorScratch

	cmdPos[1] = geo_layout.gGeoLayoutCommand + 0x02

	Registry.Members.src__engine__graph_node_manager.read_vec3s(TranslationScratch, cmdPos)

	const graphNode = GraphNode.init_graph_node_held_object(geo_layout.gGraphNodePool, nil, nil, TranslationScratch, CurGeoCmdFunction(0x08), GeoLayoutH.cur_geo_cmd_u8(0x01)) :: GroupsTypesHPlus3Types.GraphNodeHeldObject

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)

	geo_layout.gGeoLayoutCommand += bit32.lshift(0x0C, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:geo_layout_cmd_node_culling_radius L763-768
function geo_layout.geo_layout_cmd_node_culling_radius()
	const graphNode = GraphNode.init_graph_node_culling_radius(geo_layout.gGraphNodePool, nil, GeoLayoutH.cur_geo_cmd_s16(0x02)) :: GroupsTypesHPlus3Types.GraphNodeCullingRadius

	Registry.Members.src__engine__graph_node_manager.register_scene_graph_node(graphNode.node)
	geo_layout.gGeoLayoutCommand += bit32.lshift(0x04, GeoLayoutH.CMD_SIZE_SHIFT)
end

-- from src/engine/geo_layout.c:process_geo_layout L770-795
function geo_layout.process_geo_layout(pool: SrcGameMemoryH.AllocOnlyPool, segptr: number): GroupsTypesHPlus3Types.GraphNode?
	geo_layout.gCurRootGraphNode = nil

	geo_layout.gGeoNumViews = 0

	geo_layout.gCurGraphNodeList[1] = nil
	geo_layout.gCurGraphNodeIndex = 0

	geo_layout.gGeoLayoutStackIndex = 2
	geo_layout.gGeoLayoutReturnIndex = 2

	geo_layout.gGeoLayoutCommand = SrcGameMemory.segmented_to_virtual(segptr)

	geo_layout.gGraphNodePool = pool

	geo_layout.gGeoLayoutStack[1] = 0
	geo_layout.gGeoLayoutStack[2] = 0

	while geo_layout.gGeoLayoutCommand ~= 0 do
		geo_layout.GeoLayoutJumpTable[GeoLayoutH.cur_geo_cmd_u8(0x00) + 1]()
	end

	return geo_layout.gCurRootGraphNode
end

-- from src/engine/geo_layout.c:GeoLayoutJumpTable L11-45
geo_layout.GeoLayoutJumpTable = {
	geo_layout.geo_layout_cmd_branch_and_link,
	geo_layout.geo_layout_cmd_end,
	geo_layout.geo_layout_cmd_branch,
	geo_layout.geo_layout_cmd_return,
	geo_layout.geo_layout_cmd_open_node,
	geo_layout.geo_layout_cmd_close_node,
	geo_layout.geo_layout_cmd_assign_as_view,
	geo_layout.geo_layout_cmd_update_node_flags,
	geo_layout.geo_layout_cmd_node_root,
	geo_layout.geo_layout_cmd_node_ortho_projection,
	geo_layout.geo_layout_cmd_node_perspective,
	geo_layout.geo_layout_cmd_node_start,
	geo_layout.geo_layout_cmd_node_master_list,
	geo_layout.geo_layout_cmd_node_level_of_detail,
	geo_layout.geo_layout_cmd_node_switch_case,
	geo_layout.geo_layout_cmd_node_camera,
	geo_layout.geo_layout_cmd_node_translation_rotation,
	geo_layout.geo_layout_cmd_node_translation,
	geo_layout.geo_layout_cmd_node_rotation,
	geo_layout.geo_layout_cmd_node_animated_part,
	geo_layout.geo_layout_cmd_node_billboard,
	geo_layout.geo_layout_cmd_node_display_list,
	geo_layout.geo_layout_cmd_node_shadow,
	geo_layout.geo_layout_cmd_node_object_parent,
	geo_layout.geo_layout_cmd_node_generated,
	geo_layout.geo_layout_cmd_node_background,
	geo_layout.geo_layout_cmd_nop,
	geo_layout.geo_layout_cmd_copy_view,
	geo_layout.geo_layout_cmd_node_held_obj,
	geo_layout.geo_layout_cmd_node_scale,
	geo_layout.geo_layout_cmd_nop2,
	geo_layout.geo_layout_cmd_nop3,
	geo_layout.geo_layout_cmd_node_culling_radius,
}

return geo_layout
