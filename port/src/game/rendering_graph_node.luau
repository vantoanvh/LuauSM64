--!strict
--!optimize 2

--[[
	Port of src/game/rendering_graph_node.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const MemoryH = require("./memory_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Memory = require("./memory")
const RenderingGraphNodeH = require("./rendering_graph_node_h")
const Rom = require("../rom/rom")
const Recorder = require("../rom/render_recorder")
const SrcEngineMathUtil = require("../engine/math_util")
const GameInit = require("./game_init")

-- from src/game/rendering_graph_node.c:GeoAnimState
export type GeoAnimState = {
	type_: number,
	enabled: number,
	frame: number,
	translationMultiplier: number,
	attribute: number?,
	data: number?,
}

-- from src/game/rendering_graph_node.c:RenderModeContainer
export type RenderModeContainer = {
	modes: { number }, -- [8]
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/rendering_graph_node.luau:scratch
const AnimFrameAccelAssist = table.create(1, 0)
-- from src/game/rendering_graph_node.luau:scratch
const AnimTranslation = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const AnimRotation = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const AnimMatrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }
-- from src/game/rendering_graph_node.luau:scratch
const BillboardTranslation = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const HeldTranslation = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const HeldMatrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }
-- from src/game/rendering_graph_node.luau:scratch
const NodeMatrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }
-- from src/game/rendering_graph_node.luau:scratch
const NodeTranslation = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const ScaleVector = table.create(3, 0)
-- from src/game/rendering_graph_node.luau:scratch
const CameraTransform = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }

-- from src/game/rendering_graph_node.c:data
const rendering_graph_node = {
	-- from src/game/rendering_graph_node.c:gMatStackIndex L39-39
	gMatStackIndex = 0,
	-- from src/game/rendering_graph_node.c:gMatStack L40-40
	gMatStack = {
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
			{ table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
		},
	-- from src/game/rendering_graph_node.c:gMatStackFixed L41-41
	gMatStackFixed = {
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
		} :: { { unknown } },
	-- from src/game/rendering_graph_node.c:gGeoTempState L59-59
	gGeoTempState = { type_ = 0, enabled = 0, frame = 0, translationMultiplier = 0, attribute = nil, data = nil } :: GeoAnimState,
	-- from src/game/rendering_graph_node.c:gCurrAnimType L61-61
	gCurrAnimType = 0,
	-- from src/game/rendering_graph_node.c:gCurrAnimEnabled L62-62
	gCurrAnimEnabled = 0,
	-- from src/game/rendering_graph_node.c:gCurrAnimFrame L63-63
	gCurrAnimFrame = 0,
	-- from src/game/rendering_graph_node.c:gCurrAnimTranslationMultiplier L64-64
	gCurrAnimTranslationMultiplier = 0,
	-- from src/game/rendering_graph_node.c:gCurrAnimAttribute L65-65
	gCurrAnimAttribute = table.create(1, 0) :: { number },
	-- from src/game/rendering_graph_node.c:gCurrAnimData L66-66
	gCurrAnimData = nil :: number?,
	-- from src/game/rendering_graph_node.c:gDisplayListHeap L68-68
	gDisplayListHeap = nil :: MemoryH.AllocOnlyPool?,
	-- from src/game/rendering_graph_node.c:renderModeTable_1Cycle L75-95
	renderModeTable_1Cycle = {
			{
				modes = {
					nil --[[ ? G_RM_OPA_SURF ]],
					nil --[[ ? G_RM_AA_OPA_SURF ]],
					nil --[[ ? G_RM_AA_OPA_SURF ]],
					nil --[[ ? G_RM_AA_OPA_SURF ]],
					nil --[[ ? G_RM_AA_TEX_EDGE ]],
					nil --[[ ? G_RM_AA_XLU_SURF ]],
					nil --[[ ? G_RM_AA_XLU_SURF ]],
					nil --[[ ? G_RM_AA_XLU_SURF ]],
				},
			},
			{
				modes = {
					nil --[[ ? G_RM_ZB_OPA_SURF ]],
					nil --[[ ? G_RM_AA_ZB_OPA_SURF ]],
					nil --[[ ? G_RM_AA_ZB_OPA_DECAL ]],
					nil --[[ ? G_RM_AA_ZB_OPA_INTER ]],
					nil --[[ ? G_RM_AA_ZB_TEX_EDGE ]],
					nil --[[ ? G_RM_AA_ZB_XLU_SURF ]],
					nil --[[ ? G_RM_AA_ZB_XLU_DECAL ]],
					nil --[[ ? G_RM_AA_ZB_XLU_INTER ]],
				},
			},
		},
	-- from src/game/rendering_graph_node.c:renderModeTable_2Cycle L98-118
	renderModeTable_2Cycle = {
			{
				modes = {
					nil --[[ ? G_RM_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_TEX_EDGE2 ]],
					nil --[[ ? G_RM_AA_XLU_SURF2 ]],
					nil --[[ ? G_RM_AA_XLU_SURF2 ]],
					nil --[[ ? G_RM_AA_XLU_SURF2 ]],
				},
			},
			{
				modes = {
					nil --[[ ? G_RM_ZB_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_ZB_OPA_SURF2 ]],
					nil --[[ ? G_RM_AA_ZB_OPA_DECAL2 ]],
					nil --[[ ? G_RM_AA_ZB_OPA_INTER2 ]],
					nil --[[ ? G_RM_AA_ZB_TEX_EDGE2 ]],
					nil --[[ ? G_RM_AA_ZB_XLU_SURF2 ]],
					nil --[[ ? G_RM_AA_ZB_XLU_DECAL2 ]],
					nil --[[ ? G_RM_AA_ZB_XLU_INTER2 ]],
				},
			},
		},
	-- from src/game/rendering_graph_node.c:gCurGraphNodeRoot L120-120
	gCurGraphNodeRoot = nil :: GroupsTypesHPlus3.GraphNodeRoot?,
	-- from src/game/rendering_graph_node.c:gCurGraphNodeMasterList L121-121
	gCurGraphNodeMasterList = nil :: GroupsTypesHPlus3.GraphNodeMasterList?,
	-- from src/game/rendering_graph_node.c:gCurGraphNodeCamFrustum L122-122
	gCurGraphNodeCamFrustum = nil :: GroupsTypesHPlus3.GraphNodePerspective?,
	-- from src/game/rendering_graph_node.c:gCurGraphNodeCamera L123-123
	gCurGraphNodeCamera = nil :: GroupsTypesHPlus3.GraphNodeCamera?,
	-- from src/game/rendering_graph_node.c:gCurGraphNodeObject L124-124
	gCurGraphNodeObject = nil :: GroupsTypesHPlus3.GraphNodeObject?,
	-- from src/game/rendering_graph_node.c:gCurGraphNodeHeldObject L125-125
	gCurGraphNodeHeldObject = nil :: GroupsTypesHPlus3.GraphNodeHeldObject?,
	-- from src/game/rendering_graph_node.c:gAreaUpdateCounter L126-126
	gAreaUpdateCounter = 0,
}

Registry.Register("src__game__rendering_graph_node", rendering_graph_node)

-- from src/game/rendering_graph_node.c:GeoAnimState (zero-filled constructor)
function rendering_graph_node.new_GeoAnimState(): GeoAnimState
	return { type_ = 0, enabled = 0, frame = 0, translationMultiplier = 0, attribute = nil, data = nil } :: GeoAnimState
end

-- from src/game/rendering_graph_node.c:RenderModeContainer (zero-filled constructor)
function rendering_graph_node.new_RenderModeContainer(): RenderModeContainer
	return { modes = table.create(8, 0) } :: RenderModeContainer
end

-- from src/game/rendering_graph_node.c:geo_process_master_list_sub L135-170
function rendering_graph_node.geo_process_master_list_sub(node: GroupsTypesHPlus3.GraphNodeMasterList)
	-- gDPPipeSync, gSPSetGeometryMode, gDPSetRenderMode, gSPMatrix, gSPDisplayList and gSPClearGeometryMode over the layer lists: display list only (gfx-display-lists-noop)
	if Recorder.Enabled then
		Recorder.MasterList(node)
	end
end

-- from src/game/rendering_graph_node.c:geo_append_display_list L177-196
function rendering_graph_node.geo_append_display_list(displayList: unknown, layer: number)
	layer = S16(TruncS32(layer))

	if rendering_graph_node.gCurGraphNodeMasterList ~= nil then
		const masterList = rendering_graph_node.gCurGraphNodeMasterList
		const listNode = GroupsTypesHPlus3.new_DisplayListNode()

		listNode.transform = rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1]
		listNode.displayList = displayList
		listNode.next = nil

		if masterList.listHeads[layer + 1] == nil then
			masterList.listHeads[layer + 1] = listNode
		else
			(masterList.listTails[layer + 1] :: GroupsTypesHPlus3.DisplayListNode).next = listNode
		end

		masterList.listTails[layer + 1] = listNode
	end
end

-- from src/game/rendering_graph_node.c:geo_process_master_list L201-214
function rendering_graph_node.geo_process_master_list(node: GroupsTypesHPlus3.GraphNodeMasterList)
	if rendering_graph_node.gCurGraphNodeMasterList == nil and node.node.children ~= nil then
		rendering_graph_node.gCurGraphNodeMasterList = node

		for Layer = 1, GroupsTypesHPlus3.GFX_NUM_MASTER_LISTS do
			node.listHeads[Layer] = nil
		end

		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
		rendering_graph_node.geo_process_master_list_sub(node)
		rendering_graph_node.gCurGraphNodeMasterList = nil
	end
end

-- from src/game/rendering_graph_node.c:geo_process_ortho_projection L219-233
function rendering_graph_node.geo_process_ortho_projection(node: GroupsTypesHPlus3.GraphNodeOrthoProjection)
	if node.node.children ~= nil then
		-- guOrtho, gSPPerspNormalize and gSPMatrix on the projection matrix: display list only (gfx-display-lists-noop)
		if Recorder.Enabled then
			Recorder.Ortho(node)
		end

		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_perspective L238-261
function rendering_graph_node.geo_process_perspective(node: GroupsTypesHPlus3.GraphNodePerspective)
	if node.func ~= nil then
		node.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	end

	if node.node.children ~= nil then
		-- guPerspective, gSPPerspNormalize and gSPMatrix on the projection matrix: display list only (gfx-display-lists-noop)
		if Recorder.Enabled then
			Recorder.Perspective(node)
		end

		rendering_graph_node.gCurGraphNodeCamFrustum = node
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
		rendering_graph_node.gCurGraphNodeCamFrustum = nil
	end
end

-- from src/game/rendering_graph_node.c:geo_process_level_of_detail L269-285
function rendering_graph_node.geo_process_level_of_detail(node: GroupsTypesHPlus3.GraphNodeLevelOfDetail)
	const Matrix = rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1]
	const HighWord: number = Registry.Members.include__sm64_h.GET_HIGH_S16_OF_32(Matrix[8] :: number)
	const DistanceFromCam = S16(-HighWord)

	if node.minDistance <= DistanceFromCam and DistanceFromCam < node.maxDistance then
		if node.node.children ~= nil then
			rendering_graph_node.geo_process_node_and_siblings(node.node.children)
		end
	end
end

-- from src/game/rendering_graph_node.c:geo_process_switch L292-305
function rendering_graph_node.geo_process_switch(node: GroupsTypesHPlus3.GraphNodeSwitchCase)
	local SelectedChild = node.fnNode.node.children

	if node.fnNode.func ~= nil then
		node.fnNode.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.fnNode.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	end

	local Index = 0

	while SelectedChild ~= nil and node.selectedCase > Index do
		SelectedChild = SelectedChild.next
		Index += 1
	end

	if SelectedChild ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(SelectedChild)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_camera L310-334
function rendering_graph_node.geo_process_camera(node: GroupsTypesHPlus3.GraphNodeCamera)
	const mtx = Memory.alloc_display_list(64) :: { unknown }

	if node.func ~= nil then
		node.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	end

	-- mtxf_rotate_xy and gSPMatrix of the roll matrix: display list only (gfx-display-lists-noop)

	SrcEngineMathUtil.mtxf_lookat(CameraTransform, node.pos, node.focus, node.roll)
	SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], CameraTransform, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(mtx, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = mtx

	if node.node.children ~= nil then
		rendering_graph_node.gCurGraphNodeCamera = node

		const CameraMatrix = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1]

		node.matrixPtr = { CameraMatrix }

		if Recorder.Enabled then
			Recorder.Camera(CameraMatrix :: { { number } })
		end

		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
		rendering_graph_node.gCurGraphNodeCamera = nil
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_translation_rotation L342-360
function rendering_graph_node.geo_process_translation_rotation(node: GroupsTypesHPlus3.GraphNodeTranslationRotation)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }

	SrcEngineMathUtil.vec3s_to_vec3f(NodeTranslation, node.translation)
	SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(NodeMatrix, NodeTranslation, node.rotation)
	SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], NodeMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_translation L367-385
function rendering_graph_node.geo_process_translation(node: GroupsTypesHPlus3.GraphNodeTranslation)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }
	const Zero: { number } = Registry.Members.src__engine__graph_node.gVec3sZero

	SrcEngineMathUtil.vec3s_to_vec3f(NodeTranslation, node.translation)
	SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(NodeMatrix, NodeTranslation, Zero)
	SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], NodeMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_rotation L392-408
function rendering_graph_node.geo_process_rotation(node: GroupsTypesHPlus3.GraphNodeRotation)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }
	const Zero: { number } = Registry.Members.src__engine__graph_node.gVec3fZero

	SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(NodeMatrix, Zero, node.rotation)
	SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], NodeMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_scale L415-432
function rendering_graph_node.geo_process_scale(node: GroupsTypesHPlus3.GraphNodeScale)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }

	SrcEngineMathUtil.vec3f_set(ScaleVector, node.scale, node.scale, node.scale)
	SrcEngineMathUtil.mtxf_scale_vec3f(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], ScaleVector)
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_billboard L440-468
function rendering_graph_node.geo_process_billboard(node: GroupsTypesHPlus3.GraphNodeBillboard)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.vec3s_to_vec3f(BillboardTranslation, node.translation)

	const CameraNode = rendering_graph_node.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera

	SrcEngineMathUtil.mtxf_billboard(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex], BillboardTranslation, CameraNode.roll)

	if rendering_graph_node.gCurGraphNodeHeldObject ~= nil then
		SrcEngineMathUtil.mtxf_scale_vec3f(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], (rendering_graph_node.gCurGraphNodeHeldObject.objNode :: GroupsTypesHPlus3.Object).header.gfx.scale)
	elseif rendering_graph_node.gCurGraphNodeObject ~= nil then
		SrcEngineMathUtil.mtxf_scale_vec3f(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], rendering_graph_node.gCurGraphNodeObject.scale)
	end

	SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_process_display_list L475-482
function rendering_graph_node.geo_process_display_list(node: GroupsTypesHPlus3.GraphNodeDisplayList)
	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_generated_list L488-500
function rendering_graph_node.geo_process_generated_list(node: GroupsTypesHPlus3.GraphNodeGenerated)
	if node.fnNode.func ~= nil then
		const List = node.fnNode.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.fnNode.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])

		if List ~= nil then
			-- VIRTUAL_TO_PHYSICAL(list) is the RSP address of the display list: a Gfx pointer is a table here (gfx-display-lists-noop)
			rendering_graph_node.geo_append_display_list(List, S16(node.fnNode.node.flags // 256))
		end
	end

	if node.fnNode.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.fnNode.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_background L507-538
function rendering_graph_node.geo_process_background(node: GroupsTypesHPlus3.GraphNodeBackground)
	local list: unknown = nil

	if node.func ~= nil then
		list = node.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	end

	if list ~= nil then
		-- VIRTUAL_TO_PHYSICAL(list) is the RSP address of the display list: a Gfx pointer is a table here (gfx-display-lists-noop)
		rendering_graph_node.geo_append_display_list(list, S16(bit32.rshift(node.node.flags, 8)))
	elseif rendering_graph_node.gCurGraphNodeMasterList ~= nil then
		-- the fill color rectangle of the background color (gDPSetFillColor, gDPFillRectangle): display list only (gfx-display-lists-noop)
	end

	if Recorder.Enabled then
		const Root = rendering_graph_node.gCurGraphNodeRoot :: GroupsTypesHPlus3.GraphNodeRoot

		Recorder.Background(node, (Root.views :: { GroupsTypesHPlus3.GraphNodeCamera? })[1])
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_animated_part L544-602
function rendering_graph_node.geo_process_animated_part(node: GroupsTypesHPlus3.GraphNodeAnimatedPart)
	const MatrixPtr = Memory.alloc_display_list(64) :: { unknown }
	const Zero: { number } = Registry.Members.src__engine__graph_node.gVec3sZero

	SrcEngineMathUtil.vec3s_copy(AnimRotation, Zero)
	SrcEngineMathUtil.vec3f_set(AnimTranslation, node.translation[1], node.translation[2], node.translation[3])

	if rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_TRANSLATION then
		const IndexX: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[1] = F32(AnimTranslation[1] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexX) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		const IndexY: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[2] = F32(AnimTranslation[2] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexY) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		const IndexZ: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[3] = F32(AnimTranslation[3] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexZ) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_ROTATION)
	elseif rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_LATERAL_TRANSLATION then
		const IndexX: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[1] = F32(AnimTranslation[1] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexX) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		rendering_graph_node.gCurrAnimAttribute[1] += 2 * 2

		const IndexZ: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[3] = F32(AnimTranslation[3] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexZ) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_ROTATION)
	elseif rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_VERTICAL_TRANSLATION then
		rendering_graph_node.gCurrAnimAttribute[1] += 2 * 2

		const IndexY: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimTranslation[2] = F32(AnimTranslation[2] + F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexY) * rendering_graph_node.gCurrAnimTranslationMultiplier))

		rendering_graph_node.gCurrAnimAttribute[1] += 2 * 2
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_ROTATION)
	elseif rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_NO_TRANSLATION then
		rendering_graph_node.gCurrAnimAttribute[1] += 6 * 2
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_ROTATION)
	end

	if rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_ROTATION then
		const IndexRotX: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimRotation[1] = Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexRotX)

		const IndexRotY: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimRotation[2] = Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexRotY)

		const IndexRotZ: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)

		AnimRotation[3] = Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexRotZ)
	end

	SrcEngineMathUtil.mtxf_rotate_xyz_and_translate(AnimMatrix, AnimTranslation, AnimRotation)
	SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], AnimMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
	SrcEngineMathUtil.mtxf_to_mtx(MatrixPtr, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = MatrixPtr

	if node.displayList ~= nil then
		rendering_graph_node.geo_append_display_list(node.displayList, S16(node.node.flags // 256))
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end

	rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
end

-- from src/game/rendering_graph_node.c:geo_set_animation_globals L608-635
function rendering_graph_node.geo_set_animation_globals(node: GroupsTypesHPlus3.AnimInfo, hasAnimation: number)
	const anim = node.curAnim :: number

	if hasAnimation ~= 0 then
		AnimFrameAccelAssist[1] = node.animFrameAccelAssist

		const Frame: number = Registry.Members.src__engine__graph_node.geo_update_animation_frame(node, AnimFrameAccelAssist)

		node.animFrame = S16(Frame)
		node.animFrameAccelAssist = AnimFrameAccelAssist[1]
	end

	node.animTimer = rendering_graph_node.gAreaUpdateCounter

	if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_HOR_TRANS) then
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_VERTICAL_TRANSLATION)
	elseif bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_VERT_TRANS) then
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_LATERAL_TRANSLATION)
	elseif bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_6) then
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_NO_TRANSLATION)
	else
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_TRANSLATION)
	end

	rendering_graph_node.gCurrAnimFrame = node.animFrame
	rendering_graph_node.gCurrAnimEnabled = U8(if bit32.btest(Rom.ReadS16(anim), GroupsTypesHPlus3.ANIM_FLAG_5) then 0 else 1)
	rendering_graph_node.gCurrAnimAttribute[1] = Memory.segmented_to_virtual(Rom.ReadU32(anim + 16))
	rendering_graph_node.gCurrAnimData = Memory.segmented_to_virtual(Rom.ReadU32(anim + 12))

	if Rom.ReadS16(anim + 2) == 0 then
		rendering_graph_node.gCurrAnimTranslationMultiplier = 1.0
	else
		rendering_graph_node.gCurrAnimTranslationMultiplier = F32(node.animYTrans / Rom.ReadS16(anim + 2))
	end
end

-- from src/game/rendering_graph_node.c:geo_process_shadow L642-714
function rendering_graph_node.geo_process_shadow(node: GroupsTypesHPlus3.GraphNodeShadow)
	-- create_shadow_below_xyz and the shadow matrix: display list only (gfx-display-lists-noop); the animation offset of the shadow position
	-- steps gCurrAnimAttribute by a net zero
	if Recorder.Enabled and rendering_graph_node.gCurGraphNodeCamera ~= nil and rendering_graph_node.gCurGraphNodeObject ~= nil then
		-- The position and scale of the shadow as the C settles on them, for the renderer (render-recorder)
		const Camera = rendering_graph_node.gCurGraphNodeCamera
		const Object = rendering_graph_node.gCurGraphNodeObject
		const ShadowPos = { 0, 0, 0 }
		local ShadowScale: number

		if rendering_graph_node.gCurGraphNodeHeldObject ~= nil then
			SrcEngineMathUtil.get_pos_from_transform_mtx(ShadowPos, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], Camera.matrixPtr[1])
			ShadowScale = node.shadowScale
		else
			SrcEngineMathUtil.vec3f_copy(ShadowPos, Object.pos)
			ShadowScale = F32(node.shadowScale * Object.scale[1])
		end

		if rendering_graph_node.gCurrAnimEnabled ~= 0 and (rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_TRANSLATION or rendering_graph_node.gCurrAnimType == RenderingGraphNodeH.ANIM_TYPE_LATERAL_TRANSLATION) then
			local ObjectScale = 1.0
			const Geo = node.node.children

			if Geo ~= nil and Geo.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_SCALE then
				ObjectScale = (Geo :: GroupsTypesHPlus3.GraphNodeScale).scale
			end

			const IndexX: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)
			const OffsetX = F32(F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexX) * rendering_graph_node.gCurrAnimTranslationMultiplier) * ObjectScale)

			rendering_graph_node.gCurrAnimAttribute[1] += 2 * 2

			const IndexZ: number = Registry.Members.src__engine__graph_node.retrieve_animation_index(rendering_graph_node.gCurrAnimFrame, rendering_graph_node.gCurrAnimAttribute)
			const OffsetZ = F32(F32(Rom.ReadS16((rendering_graph_node.gCurrAnimData :: number) + 2 * IndexZ) * rendering_graph_node.gCurrAnimTranslationMultiplier) * ObjectScale)

			rendering_graph_node.gCurrAnimAttribute[1] -= 6 * 2

			const Sine: number = Registry.Members.src__engine__math_util_h.sins(Object.angle[2])
			const Cosine: number = Registry.Members.src__engine__math_util_h.coss(Object.angle[2])

			ShadowPos[1] = F32(ShadowPos[1] + OffsetX * Cosine + OffsetZ * Sine)
			ShadowPos[3] = F32(ShadowPos[3] + -OffsetX * Sine + OffsetZ * Cosine)
		end

		Recorder.Shadow(node, Object, ShadowPos, ShadowScale, Camera.matrixPtr[1])
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end
end

-- from src/game/rendering_graph_node.c:obj_is_in_view L747-803
function rendering_graph_node.obj_is_in_view(node: GroupsTypesHPlus3.GraphNodeObject, matrix: { { number } }): number
	if bit32.btest(node.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE) then
		return IncludePRUltratypesH.FALSE
	end

	const Geo = node.sharedChild
	const Frustum = rendering_graph_node.gCurGraphNodeCamFrustum :: GroupsTypesHPlus3.GraphNodePerspective
	const HalfFov = S16(TruncS32(F32(F32(F32(F32(F32(Frustum.fov / 2) + 1) * 32768) / 180) + 0.5)))
	const Sine: number = Registry.Members.src__engine__math_util_h.sins(HalfFov)
	const Cosine: number = Registry.Members.src__engine__math_util_h.coss(HalfFov)
	const HScreenEdge = F32(F32(F32(-matrix[4][3]) * Sine) / Cosine)

	local CullingRadius: number

	if Geo ~= nil and Geo.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_CULLING_RADIUS then
		CullingRadius = (Geo :: GroupsTypesHPlus3.GraphNodeCullingRadius).cullingRadius
	else
		CullingRadius = S16(300)
	end

	if matrix[4][3] > F32(-100.0 + CullingRadius) then
		return IncludePRUltratypesH.FALSE
	end

	if matrix[4][3] < F32(-20000.0 - CullingRadius) then
		return IncludePRUltratypesH.FALSE
	end

	-- The sides of the view are not culled while the recorder runs (the presenter): the game takes the field of view as the horizontal one
	-- too, so on a 4:3 screen it drops the objects in the outer quarter of the picture (a door at the edge goes), where the presenter's
	-- own frustum culling shows exactly what is in view. A run without the recorder (the hash runs) is the game's.
	if not Recorder.Enabled then
		if matrix[4][1] > F32(HScreenEdge + CullingRadius) then
			return IncludePRUltratypesH.FALSE
		end

		if matrix[4][1] < F32(-HScreenEdge - CullingRadius) then
			return IncludePRUltratypesH.FALSE
		end
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/rendering_graph_node.c:geo_process_object L808-856
function rendering_graph_node.geo_process_object(node: GroupsTypesHPlus3.Object)
	const HasAnimation: number = if bit32.btest(node.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION) then 1 else 0

	if node.header.gfx.areaIndex == (rendering_graph_node.gCurGraphNodeRoot :: GroupsTypesHPlus3.GraphNodeRoot).areaIndex then
		if node.header.gfx.throwMatrix ~= nil then
			SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], node.header.gfx.throwMatrix[1], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
		elseif bit32.btest(node.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD) then
			SrcEngineMathUtil.mtxf_billboard(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1], node.header.gfx.pos, (rendering_graph_node.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera).roll)
		else
			SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(NodeMatrix, node.header.gfx.pos, node.header.gfx.angle)
			SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], NodeMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
		end

		SrcEngineMathUtil.mtxf_scale_vec3f(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], node.header.gfx.scale)
		rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
		node.header.gfx.throwMatrix = { rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1] }
		node.header.gfx.cameraToObject[1] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][1]
		node.header.gfx.cameraToObject[2] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][2]
		node.header.gfx.cameraToObject[3] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][3]

		if node.header.gfx.animInfo.curAnim ~= nil then
			rendering_graph_node.geo_set_animation_globals(node.header.gfx.animInfo, HasAnimation)
		end

		if rendering_graph_node.obj_is_in_view(node.header.gfx, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1]) ~= 0 then
			const Matrix = Memory.alloc_display_list(64) :: { unknown }

			SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
			rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix

			if node.header.gfx.sharedChild ~= nil then
				rendering_graph_node.gCurGraphNodeObject = node.header.gfx
				node.header.gfx.sharedChild.parent = node.header.gfx.node
				rendering_graph_node.geo_process_node_and_siblings(node.header.gfx.sharedChild)
				node.header.gfx.sharedChild.parent = nil
				rendering_graph_node.gCurGraphNodeObject = nil
			end

			if node.header.gfx.node.children ~= nil then
				rendering_graph_node.geo_process_node_and_siblings(node.header.gfx.node.children)
			end
		end

		rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
		rendering_graph_node.gCurrAnimType = U8(RenderingGraphNodeH.ANIM_TYPE_NONE)
		node.header.gfx.throwMatrix = nil
	end
end

-- from src/game/rendering_graph_node.c:geo_process_object_parent L863-872
function rendering_graph_node.geo_process_object_parent(node: GroupsTypesHPlus3.GraphNodeObjectParent)
	if node.sharedChild ~= nil then
		node.sharedChild.parent = node.node
		rendering_graph_node.geo_process_node_and_siblings(node.sharedChild)
		node.sharedChild.parent = nil
	end

	if node.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_held_object L877-937
function rendering_graph_node.geo_process_held_object(node: GroupsTypesHPlus3.GraphNodeHeldObject)
	const Matrix = Memory.alloc_display_list(64) :: { unknown }

	if node.fnNode.func ~= nil then
		node.fnNode.func(GroupsTypesHPlus3.GEO_CONTEXT_RENDER, node.fnNode.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
	end

	if node.objNode ~= nil and node.objNode.header.gfx.sharedChild ~= nil then
		const HasAnimation: number = if bit32.btest(node.objNode.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION) then 1 else 0

		HeldTranslation[1] = F32(node.translation[1] / 4.0)
		HeldTranslation[2] = F32(node.translation[2] / 4.0)
		HeldTranslation[3] = F32(node.translation[3] / 4.0)

		SrcEngineMathUtil.mtxf_translate(HeldMatrix, HeldTranslation)

		const ThrowMatrix = (rendering_graph_node.gCurGraphNodeObject :: GroupsTypesHPlus3.GraphNodeObject).throwMatrix :: { { { number } } }

		SrcEngineMathUtil.mtxf_copy(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], ThrowMatrix[1])
		rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2][4][1] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][1]
		rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2][4][2] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][2]
		rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2][4][3] = rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1][4][3]
		SrcEngineMathUtil.mtxf_mul(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], HeldMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2])
		SrcEngineMathUtil.mtxf_scale_vec3f(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2], node.objNode.header.gfx.scale)

		if node.fnNode.func ~= nil then
			node.fnNode.func(GroupsTypesHPlus3.GEO_CONTEXT_HELD_OBJ, node.fnNode.node, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 2])
		end

		rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex + 1)
		SrcEngineMathUtil.mtxf_to_mtx(Matrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
		rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = Matrix
		rendering_graph_node.gGeoTempState.type_ = rendering_graph_node.gCurrAnimType
		rendering_graph_node.gGeoTempState.enabled = rendering_graph_node.gCurrAnimEnabled
		rendering_graph_node.gGeoTempState.frame = rendering_graph_node.gCurrAnimFrame
		rendering_graph_node.gGeoTempState.translationMultiplier = rendering_graph_node.gCurrAnimTranslationMultiplier
		rendering_graph_node.gGeoTempState.attribute = rendering_graph_node.gCurrAnimAttribute[1]
		rendering_graph_node.gGeoTempState.data = rendering_graph_node.gCurrAnimData
		rendering_graph_node.gCurrAnimType = U8(0)
		rendering_graph_node.gCurGraphNodeHeldObject = node

		if node.objNode.header.gfx.animInfo.curAnim ~= nil then
			rendering_graph_node.geo_set_animation_globals(node.objNode.header.gfx.animInfo, HasAnimation)
		end

		rendering_graph_node.geo_process_node_and_siblings(node.objNode.header.gfx.sharedChild)
		rendering_graph_node.gCurGraphNodeHeldObject = nil
		rendering_graph_node.gCurrAnimType = rendering_graph_node.gGeoTempState.type_
		rendering_graph_node.gCurrAnimEnabled = rendering_graph_node.gGeoTempState.enabled
		rendering_graph_node.gCurrAnimFrame = rendering_graph_node.gGeoTempState.frame
		rendering_graph_node.gCurrAnimTranslationMultiplier = rendering_graph_node.gGeoTempState.translationMultiplier
		rendering_graph_node.gCurrAnimAttribute[1] = rendering_graph_node.gGeoTempState.attribute :: number
		rendering_graph_node.gCurrAnimData = rendering_graph_node.gGeoTempState.data
		rendering_graph_node.gMatStackIndex = S16(rendering_graph_node.gMatStackIndex - 1)
	end

	if node.fnNode.node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.fnNode.node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_try_process_children L942-946
function rendering_graph_node.geo_try_process_children(node: GroupsTypesHPlus3.GraphNode)
	if node.children ~= nil then
		rendering_graph_node.geo_process_node_and_siblings(node.children)
	end
end

-- from src/game/rendering_graph_node.c:geo_process_node_and_siblings L953-1039
function rendering_graph_node.geo_process_node_and_siblings(firstNode: GroupsTypesHPlus3.GraphNode)
	local IterateChildren = S16(IncludePRUltratypesH.TRUE)
	local CurGraphNode = firstNode
	const Parent = firstNode.parent

	if Parent ~= nil then
		IterateChildren = S16(if Parent.type_ ~= GroupsTypesHPlus3.GRAPH_NODE_TYPE_SWITCH_CASE then 1 else 0)
	end

	repeat
		if bit32.btest(CurGraphNode.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
			if bit32.btest(CurGraphNode.flags, GroupsTypesHPlus3.GRAPH_RENDER_CHILDREN_FIRST) then
				rendering_graph_node.geo_try_process_children(CurGraphNode)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_ORTHO_PROJECTION then
				rendering_graph_node.geo_process_ortho_projection(CurGraphNode :: GroupsTypesHPlus3.GraphNodeOrthoProjection)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_PERSPECTIVE then
				rendering_graph_node.geo_process_perspective(CurGraphNode :: GroupsTypesHPlus3.GraphNodePerspective)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_MASTER_LIST then
				rendering_graph_node.geo_process_master_list(CurGraphNode :: GroupsTypesHPlus3.GraphNodeMasterList)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_LEVEL_OF_DETAIL then
				rendering_graph_node.geo_process_level_of_detail(CurGraphNode :: GroupsTypesHPlus3.GraphNodeLevelOfDetail)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_SWITCH_CASE then
				rendering_graph_node.geo_process_switch(CurGraphNode :: GroupsTypesHPlus3.GraphNodeSwitchCase)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_CAMERA then
				rendering_graph_node.geo_process_camera(CurGraphNode :: GroupsTypesHPlus3.GraphNodeCamera)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_TRANSLATION_ROTATION then
				rendering_graph_node.geo_process_translation_rotation(CurGraphNode :: GroupsTypesHPlus3.GraphNodeTranslationRotation)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_TRANSLATION then
				rendering_graph_node.geo_process_translation(CurGraphNode :: GroupsTypesHPlus3.GraphNodeTranslation)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_ROTATION then
				rendering_graph_node.geo_process_rotation(CurGraphNode :: GroupsTypesHPlus3.GraphNodeRotation)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT then
				rendering_graph_node.geo_process_object(CurGraphNode :: GroupsTypesHPlus3.Object)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_ANIMATED_PART then
				rendering_graph_node.geo_process_animated_part(CurGraphNode :: GroupsTypesHPlus3.GraphNodeAnimatedPart)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_BILLBOARD then
				rendering_graph_node.geo_process_billboard(CurGraphNode :: GroupsTypesHPlus3.GraphNodeBillboard)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_DISPLAY_LIST then
				rendering_graph_node.geo_process_display_list(CurGraphNode :: GroupsTypesHPlus3.GraphNodeDisplayList)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_SCALE then
				rendering_graph_node.geo_process_scale(CurGraphNode :: GroupsTypesHPlus3.GraphNodeScale)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_SHADOW then
				rendering_graph_node.geo_process_shadow(CurGraphNode :: GroupsTypesHPlus3.GraphNodeShadow)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT_PARENT then
				rendering_graph_node.geo_process_object_parent(CurGraphNode :: GroupsTypesHPlus3.GraphNodeObjectParent)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_GENERATED_LIST then
				rendering_graph_node.geo_process_generated_list(CurGraphNode :: GroupsTypesHPlus3.GraphNodeGenerated)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_BACKGROUND then
				rendering_graph_node.geo_process_background(CurGraphNode :: GroupsTypesHPlus3.GraphNodeBackground)
			elseif CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_HELD_OBJ then
				rendering_graph_node.geo_process_held_object(CurGraphNode :: GroupsTypesHPlus3.GraphNodeHeldObject)
			else
				rendering_graph_node.geo_try_process_children(CurGraphNode)
			end
		else
			if CurGraphNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT then
				(CurGraphNode :: GroupsTypesHPlus3.GraphNodeObject).throwMatrix = nil
			end
		end

		if IterateChildren == 0 then
			break
		end

		CurGraphNode = CurGraphNode.next :: GroupsTypesHPlus3.GraphNode
	until CurGraphNode == firstNode
end

-- from src/game/rendering_graph_node.c:geo_process_root L1046-1088
function rendering_graph_node.geo_process_root(node: GroupsTypesHPlus3.GraphNodeRoot, b: { unknown }?, c: { unknown }?, clearColor: number)
	if bit32.btest(node.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		const initialMatrix = Memory.alloc_display_list(64) :: { unknown }

		-- gDisplayListHeap (alloc_only_pool_init over the free main pool, freed at the end) only holds display list nodes: dropped (gfx-display-lists-noop)
		rendering_graph_node.gMatStackIndex = 0
		rendering_graph_node.gCurrAnimType = 0

		-- the viewport vtrans and vscale (vec3s_set) are display list data
		if b ~= nil then
			GameInit.clear_framebuffer(clearColor)
			GameInit.make_viewport_clip_rect(b)
		elseif c ~= nil then
			GameInit.clear_framebuffer(clearColor)
			GameInit.make_viewport_clip_rect(c)
		end

		SrcEngineMathUtil.mtxf_identity(rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
		SrcEngineMathUtil.mtxf_to_mtx(initialMatrix, rendering_graph_node.gMatStack[rendering_graph_node.gMatStackIndex + 1])
		rendering_graph_node.gMatStackFixed[rendering_graph_node.gMatStackIndex + 1] = initialMatrix
		-- gSPViewport, gSPMatrix: display list only (gfx-display-lists-noop)
		if Recorder.Enabled then
			Recorder.Root(node)
		end

		rendering_graph_node.gCurGraphNodeRoot = node

		if node.node.children ~= nil then
			rendering_graph_node.geo_process_node_and_siblings(node.node.children)
		end

		rendering_graph_node.gCurGraphNodeRoot = nil

		if Registry.Members.src__game__main.gShowDebugText ~= 0 then
			-- print_text_fmt_int: no call (debug-print-externals)
		end
	end
end

return rendering_graph_node
