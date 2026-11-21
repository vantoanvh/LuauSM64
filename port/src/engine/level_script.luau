--!strict
--!optimize 2

--[[
	Port of src/engine/level_script.c.

	Design Notes
		Level scripts are ROM resident. A command is a byte offset into Rom.Memory (sCurrentCmd, a number); its type is the byte at
		offset 0 and its size the byte at offset 1. CMD_SIZE_SHIFT is 0 with 32-bit pointers, so CMD_NEXT is sCurrentCmd + size.
		CMD_GET(type, n) is the read of that type at sCurrentCmd + n, written at each use.
		sStack holds 32-bit values (ROM offsets, counts, s16 arguments). sStackTop is the 0-based offset of the next free slot,
		sStackBase the offset of the frame base; 0 is NULL (a base is set after two pushes, so 0 is never a live base).
]]

const Registry = require("../../groups/registry")
const Rom = require("../rom/rom")
const Audio = require("../rom/audio_recorder")
const NativeCalls = require("../rom/native_calls")
const IncludeMacrosH = require("../../include/macros_h")
const SrcGameMemory = require("../game/memory")
const SrcGameMemoryH = require("../game/memory_h")
const GeoLayout = require("./geo_layout")
const GraphNode = require("./graph_node")
const MathUtil = require("./math_util")
const SrcGameArea = require("../game/area")
const SrcGameObjectListProcessor = require("../game/object_list_processor")
const SurfaceLoad = require("./surface_load")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const SrcGameSaveFile = require("../game/save_file")
const SrcGameSaveFileH = require("../game/save_file_h")
const IncludePlatformInfoH = require("../../include/platform_info_h")
const SrcGameSoundInit = require("../game/sound_init")
const SrcGameGameInit = require("../game/game_init")
const GoddardRenderer = require("../goddard/renderer")
const Symbols = require("../rom/symbols")

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/engine/level_script.c:data
const level_script = {
	-- from src/engine/level_script.c:sCurrentCmd L56-56
	sCurrentCmd = 0,
	SCRIPT_RUNNING = 1,
	SCRIPT_PAUSED = 0,
	SCRIPT_PAUSED2 = -1,
	-- from src/engine/level_script.c:sStack L42-42
	sStack = table.create(32, 0),
	-- from src/engine/level_script.c:sLevelPool L44-44
	sLevelPool = nil :: SrcGameMemoryH.AllocOnlyPool?,
	-- from src/engine/level_script.c:sDelayFrames L46-46
	sDelayFrames = 0,
	-- from src/engine/level_script.c:sDelayFrames2 L47-47
	sDelayFrames2 = 0,
	-- from src/engine/level_script.c:sCurrAreaIndex L49-49
	sCurrAreaIndex = -1,
	-- from src/engine/level_script.c:sStackBase L52-52
	sStackBase = 0,
	-- from src/engine/level_script.c:sScriptStatus L54-54
	sScriptStatus = 0,
	-- from src/engine/level_script.c:sRegister L55-55
	sRegister = 0,
}

Registry.Register("src__engine__level_script", level_script)

-- from src/engine/level_script.c:CMD_GET L28-28
function level_script.CMD_GET(type_: number, offset: number): number
	error("stale")
end

-- from src/engine/level_script.c:eval_script_op L58-89
function level_script.eval_script_op(op: number, arg: number): number
	op = S8(TruncS32(op))
	local result = 0

	if op == 0 then
		result = S32(bit32.band(level_script.sRegister, arg))
	elseif op == 1 then
		result = if bit32.band(level_script.sRegister, arg) == 0 then 1 else 0
	elseif op == 2 then
		result = if level_script.sRegister == arg then 1 else 0
	elseif op == 3 then
		result = if level_script.sRegister ~= arg then 1 else 0
	elseif op == 4 then
		result = if level_script.sRegister < arg then 1 else 0
	elseif op == 5 then
		result = if level_script.sRegister <= arg then 1 else 0
	elseif op == 6 then
		result = if level_script.sRegister > arg then 1 else 0
	elseif op == 7 then
		result = if level_script.sRegister >= arg then 1 else 0
	end

	return result
end

-- from src/engine/level_script.c:level_cmd_load_and_execute L91-100
function level_script.level_cmd_load_and_execute()
	SrcGameMemory.main_pool_push_state()
	SrcGameMemory.load_segment(Rom.ReadS16(level_script.sCurrentCmd + 2), Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8), SrcGameMemoryH.MEMORY_POOL_LEFT)

	level_script.sStack[level_script.sStackTop + 1] = level_script.sCurrentCmd + Rom.ReadU8(level_script.sCurrentCmd + 1)
	level_script.sStackTop += 1
	level_script.sStack[level_script.sStackTop + 1] = level_script.sStackBase
	level_script.sStackTop += 1
	level_script.sStackBase = level_script.sStackTop

	level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 12))
end

-- from src/engine/level_script.c:level_cmd_exit_and_execute L102-113
function level_script.level_cmd_exit_and_execute()
	const targetAddr = Rom.ReadU32(level_script.sCurrentCmd + 12)

	SrcGameMemory.main_pool_pop_state()
	SrcGameMemory.main_pool_push_state()
	SrcGameMemory.load_segment(Rom.ReadS16(level_script.sCurrentCmd + 2), Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8), SrcGameMemoryH.MEMORY_POOL_LEFT)

	level_script.sStackTop = level_script.sStackBase
	level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(targetAddr)
end

-- from src/engine/level_script.c:level_cmd_exit L115-121
function level_script.level_cmd_exit()
	SrcGameMemory.main_pool_pop_state()

	level_script.sStackTop = level_script.sStackBase
	level_script.sStackTop -= 1
	level_script.sStackBase = level_script.sStack[level_script.sStackTop + 1]
	level_script.sStackTop -= 1
	level_script.sCurrentCmd = level_script.sStack[level_script.sStackTop + 1]
end

-- from src/engine/level_script.c:level_cmd_sleep L123-132
function level_script.level_cmd_sleep()
	level_script.sScriptStatus = level_script.SCRIPT_PAUSED

	if level_script.sDelayFrames == 0 then
		level_script.sDelayFrames = U16(Rom.ReadS16(level_script.sCurrentCmd + 2))
	else
		level_script.sDelayFrames = U16(level_script.sDelayFrames - 1)

		if level_script.sDelayFrames == 0 then
			level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
			level_script.sScriptStatus = level_script.SCRIPT_RUNNING
		end
	end
end

-- from src/engine/level_script.c:level_cmd_sleep2 L134-143
function level_script.level_cmd_sleep2()
	level_script.sScriptStatus = level_script.SCRIPT_PAUSED2

	if level_script.sDelayFrames2 == 0 then
		level_script.sDelayFrames2 = U16(Rom.ReadS16(level_script.sCurrentCmd + 2))
	else
		level_script.sDelayFrames2 = U16(level_script.sDelayFrames2 - 1)

		if level_script.sDelayFrames2 == 0 then
			level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
			level_script.sScriptStatus = level_script.SCRIPT_RUNNING
		end
	end
end

-- from src/engine/level_script.c:level_cmd_jump L145-147
function level_script.level_cmd_jump()
	level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 4))
end

-- from src/engine/level_script.c:level_cmd_jump_and_link L149-152
function level_script.level_cmd_jump_and_link()
	level_script.sStack[level_script.sStackTop + 1] = level_script.sCurrentCmd + Rom.ReadU8(level_script.sCurrentCmd + 1)
	level_script.sStackTop += 1
	level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 4))
end

-- from src/engine/level_script.c:level_cmd_return L154-156
function level_script.level_cmd_return()
	level_script.sStackTop -= 1
	level_script.sCurrentCmd = level_script.sStack[level_script.sStackTop + 1]
end

-- from src/engine/level_script.c:level_cmd_jump_and_link_push_arg L158-162
function level_script.level_cmd_jump_and_link_push_arg()
	level_script.sStack[level_script.sStackTop + 1] = level_script.sCurrentCmd + Rom.ReadU8(level_script.sCurrentCmd + 1)
	level_script.sStackTop += 1
	level_script.sStack[level_script.sStackTop + 1] = Rom.ReadS16(level_script.sCurrentCmd + 2)
	level_script.sStackTop += 1
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_jump_repeat L164-176
function level_script.level_cmd_jump_repeat()
	local val = level_script.sStack[level_script.sStackTop]

	if val == 0 then
		level_script.sCurrentCmd = level_script.sStack[level_script.sStackTop - 1]
	else
		val -= 1

		if val ~= 0 then
			level_script.sStack[level_script.sStackTop] = val
			level_script.sCurrentCmd = level_script.sStack[level_script.sStackTop - 1]
		else
			level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
			level_script.sStackTop -= 2
		end
	end
end

-- from src/engine/level_script.c:level_cmd_loop_begin L178-182
function level_script.level_cmd_loop_begin()
	level_script.sStack[level_script.sStackTop + 1] = level_script.sCurrentCmd + Rom.ReadU8(level_script.sCurrentCmd + 1)
	level_script.sStackTop += 1
	level_script.sStack[level_script.sStackTop + 1] = 0
	level_script.sStackTop += 1
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_loop_until L184-191
function level_script.level_cmd_loop_until()
	if level_script.eval_script_op(Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadS32(level_script.sCurrentCmd + 4)) ~= 0 then
		level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
		level_script.sStackTop -= 2
	else
		level_script.sCurrentCmd = level_script.sStack[level_script.sStackTop - 1]
	end
end

-- from src/engine/level_script.c:level_cmd_jump_if L193-199
function level_script.level_cmd_jump_if()
	if level_script.eval_script_op(Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadS32(level_script.sCurrentCmd + 4)) ~= 0 then
		level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 8))
	else
		level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
	end
end

-- from src/engine/level_script.c:level_cmd_jump_and_link_if L201-208
function level_script.level_cmd_jump_and_link_if()
	if level_script.eval_script_op(Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadS32(level_script.sCurrentCmd + 4)) ~= 0 then
		level_script.sStack[level_script.sStackTop + 1] = level_script.sCurrentCmd + Rom.ReadU8(level_script.sCurrentCmd + 1)
		level_script.sStackTop += 1
		level_script.sCurrentCmd = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 8))
	else
		level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
	end
end

-- from src/engine/level_script.c:level_cmd_skip_if L210-218
function level_script.level_cmd_skip_if()
	if level_script.eval_script_op(Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadS32(level_script.sCurrentCmd + 4)) == 0 then
		repeat
			level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
		until not (Rom.ReadU8(level_script.sCurrentCmd) == 0x0F or Rom.ReadU8(level_script.sCurrentCmd) == 0x10)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_skip L220-226
function level_script.level_cmd_skip()
	repeat
		level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
	until not (Rom.ReadU8(level_script.sCurrentCmd) == 0x10)

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_skippable_nop L228-230
function level_script.level_cmd_skippable_nop()
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_call L232-237
function level_script.level_cmd_call()
	const BlockStart, SlotOffset = Rom.BlockOf(level_script.sCurrentCmd + 4)
	const func = NativeCalls.FunctionAt(BlockStart, SlotOffset) :: (number, number) -> number

	level_script.sRegister = func(Rom.ReadS16(level_script.sCurrentCmd + 2), level_script.sRegister)
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_call_loop L239-250
function level_script.level_cmd_call_loop()
	const BlockStart, SlotOffset = Rom.BlockOf(level_script.sCurrentCmd + 4)
	const func = NativeCalls.FunctionAt(BlockStart, SlotOffset) :: (number, number) -> number

	level_script.sRegister = func(Rom.ReadS16(level_script.sCurrentCmd + 2), level_script.sRegister)

	if level_script.sRegister == 0 then
		level_script.sScriptStatus = level_script.SCRIPT_PAUSED
	else
		level_script.sScriptStatus = level_script.SCRIPT_RUNNING
		level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
	end
end

-- from src/engine/level_script.c:level_cmd_set_register L252-255
function level_script.level_cmd_set_register()
	level_script.sRegister = Rom.ReadS16(level_script.sCurrentCmd + 2)
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_push_pool_state L257-260
function level_script.level_cmd_push_pool_state()
	SrcGameMemory.main_pool_push_state()
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_pop_pool_state L262-265
function level_script.level_cmd_pop_pool_state()
	SrcGameMemory.main_pool_pop_state()
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_to_fixed_address L267-270
function level_script.level_cmd_load_to_fixed_address()
	SrcGameMemory.load_to_fixed_pool_addr(Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8), Rom.ReadU32(level_script.sCurrentCmd + 12))
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_raw L272-276
function level_script.level_cmd_load_raw()
	SrcGameMemory.load_segment(Rom.ReadS16(level_script.sCurrentCmd + 2), Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8), SrcGameMemoryH.MEMORY_POOL_LEFT)
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_mio0 L278-281
function level_script.level_cmd_load_mio0()
	SrcGameMemory.load_segment_decompress(Rom.ReadS16(level_script.sCurrentCmd + 2), Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8))
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_mario_head L283-297
function level_script.level_cmd_load_mario_head()
	const addr = SrcGameMemory.main_pool_alloc(IncludePlatformInfoH.DOUBLE_SIZE_ON_64_BIT(0xE1000), SrcGameMemoryH.MEMORY_POOL_LEFT)

	if addr ~= nil then
		GoddardRenderer.gdm_init(addr, IncludePlatformInfoH.DOUBLE_SIZE_ON_64_BIT(0xE1000))
		GoddardRenderer.gd_add_to_heap(Symbols.GoddardZBuffer, Symbols.ZBufferSize) -- 0x25800
		GoddardRenderer.gd_add_to_heap(Symbols.GoddardFramebuffers, 3 * Symbols.FramebufferSize) -- 0x70800
		GoddardRenderer.gdm_setup()
		GoddardRenderer.gdm_maketestdl(Rom.ReadS16(level_script.sCurrentCmd + 2))
	else
		IncludeMacrosH.CN_DEBUG_PRINTF("face anime memory overflow\n")
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_mio0_texture L299-302
function level_script.level_cmd_load_mio0_texture()
	SrcGameMemory.load_segment_decompress_heap(Rom.ReadS16(level_script.sCurrentCmd + 2), Rom.ReadU32(level_script.sCurrentCmd + 4), Rom.ReadU32(level_script.sCurrentCmd + 8))
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_init_level L304-311
function level_script.level_cmd_init_level()
	GraphNode.init_graph_node_start(nil, GeoLayout.gObjParentGraphNode :: GroupsTypesHPlus3Types.GraphNodeStart)
	SrcGameObjectListProcessor.clear_objects()
	SrcGameArea.clear_areas()
	SrcGameMemory.main_pool_push_state()

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_clear_level L313-320
function level_script.level_cmd_clear_level()
	SrcGameObjectListProcessor.clear_objects()
	SrcGameArea.clear_area_graph_nodes()
	SrcGameArea.clear_areas()
	SrcGameMemory.main_pool_pop_state()

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_alloc_level_pool L322-329
function level_script.level_cmd_alloc_level_pool()
	if level_script.sLevelPool == nil then
		level_script.sLevelPool = SrcGameMemory.alloc_only_pool_init(SrcGameMemory.main_pool_available() - 24, SrcGameMemoryH.MEMORY_POOL_LEFT) -- sizeof(struct AllocOnlyPool), 64-bit layout
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_free_level_pool L331-345
function level_script.level_cmd_free_level_pool()
	SrcGameMemory.alloc_only_pool_resize(level_script.sLevelPool :: SrcGameMemoryH.AllocOnlyPool, (level_script.sLevelPool :: SrcGameMemoryH.AllocOnlyPool).usedSpace)
	level_script.sLevelPool = nil

	for i = 1, 8 do
		if SrcGameArea.gAreaData[i].terrainData ~= nil then
			SurfaceLoad.alloc_surface_pools()

			break
		end
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_begin_area L347-368
function level_script.level_cmd_begin_area()
	const areaIndex = Rom.ReadU8(level_script.sCurrentCmd + 2)
	const geoLayoutAddr = Rom.ReadU32(level_script.sCurrentCmd + 4)

	if areaIndex < 8 then
		const screenArea = GeoLayout.process_geo_layout(level_script.sLevelPool :: SrcGameMemoryH.AllocOnlyPool, geoLayoutAddr) :: GroupsTypesHPlus3Types.GraphNodeRoot
		const node = (screenArea.views :: { GroupsTypesHPlus3Types.GraphNode? })[1] :: GroupsTypesHPlus3Types.GraphNodeCamera?

		level_script.sCurrAreaIndex = areaIndex
		screenArea.areaIndex = areaIndex
		SrcGameArea.gAreas[areaIndex + 1].unk04 = screenArea

		if node ~= nil then
			SrcGameArea.gAreas[areaIndex + 1].camera = node.config.camera
		else
			SrcGameArea.gAreas[areaIndex + 1].camera = nil
		end
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_end_area L370-373
function level_script.level_cmd_end_area()
	level_script.sCurrAreaIndex = -1
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_model_from_dl L375-386
function level_script.level_cmd_load_model_from_dl()
	const val1 = bit32.band(Rom.ReadU16(level_script.sCurrentCmd + 2), 0x0FFF)
	const val2 = bit32.rshift(Rom.ReadU16(level_script.sCurrentCmd + 2), 12)
	const val3 = Rom.ReadU32(level_script.sCurrentCmd + 4)

	if val1 < 256 then
		SrcGameArea.gLoadedGraphNodes[val1 + 1] = GraphNode.init_graph_node_display_list(level_script.sLevelPool, nil, val2, val3)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_model_from_geo L388-397
function level_script.level_cmd_load_model_from_geo()
	const arg0 = Rom.ReadS16(level_script.sCurrentCmd + 2)
	const arg1 = Rom.ReadU32(level_script.sCurrentCmd + 4)

	if arg0 < 256 then
		SrcGameArea.gLoadedGraphNodes[arg0 + 1] = GeoLayout.process_geo_layout(level_script.sLevelPool :: SrcGameMemoryH.AllocOnlyPool, arg1)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_23 L399-419
function level_script.level_cmd_23()
	const model = bit32.band(Rom.ReadU16(level_script.sCurrentCmd + 2), 0x0FFF)
	const arg0H = bit32.rshift(Rom.ReadU16(level_script.sCurrentCmd + 2), 12)
	const arg1 = Rom.ReadU32(level_script.sCurrentCmd + 4)
	-- the s32 at offset 8 read as f32 bits (the C union)
	const arg2 = Rom.ReadF32(level_script.sCurrentCmd + 8)

	if model < 256 then
		SrcGameArea.gLoadedGraphNodes[model + 1] = GraphNode.init_graph_node_scale(level_script.sLevelPool, nil, arg0H, arg1, arg2)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_init_mario L421-433
function level_script.level_cmd_init_mario()
	MathUtil.vec3s_set(SrcGameArea.gMarioSpawnInfo.startPos, 0, 0, 0)
	MathUtil.vec3s_set(SrcGameArea.gMarioSpawnInfo.startAngle, 0, 0, 0)

	SrcGameArea.gMarioSpawnInfo.activeAreaIndex = -1
	SrcGameArea.gMarioSpawnInfo.areaIndex = 0
	SrcGameArea.gMarioSpawnInfo.behaviorArg = Rom.ReadU32(level_script.sCurrentCmd + 4)
	SrcGameArea.gMarioSpawnInfo.behaviorScript = Rom.ReadU32(level_script.sCurrentCmd + 8)
	SrcGameArea.gMarioSpawnInfo.model = SrcGameArea.gLoadedGraphNodes[Rom.ReadU8(level_script.sCurrentCmd + 3) + 1]
	SrcGameArea.gMarioSpawnInfo.next = nil

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_place_object L435-464
function level_script.level_cmd_place_object()
	const val7 = U8(bit32.lshift(1, SrcGameArea.gCurrActNum - 1))

	if level_script.sCurrAreaIndex ~= -1 and (bit32.btest(Rom.ReadU8(level_script.sCurrentCmd + 2), val7) or Rom.ReadU8(level_script.sCurrentCmd + 2) == 0x1F) then
		const model = Rom.ReadU8(level_script.sCurrentCmd + 3)
		const spawnInfo = GroupsTypesHPlus3Types.new_SpawnInfo() -- alloc_only_pool_alloc(sLevelPool, sizeof(struct SpawnInfo)): a record is allocated with its constructor (struct-allocation)

		spawnInfo.startPos[1] = Rom.ReadS16(level_script.sCurrentCmd + 4)
		spawnInfo.startPos[2] = Rom.ReadS16(level_script.sCurrentCmd + 6)
		spawnInfo.startPos[3] = Rom.ReadS16(level_script.sCurrentCmd + 8)

		spawnInfo.startAngle[1] = S16((math.modf(Rom.ReadS16(level_script.sCurrentCmd + 10) * 0x8000 / 180)))
		spawnInfo.startAngle[2] = S16((math.modf(Rom.ReadS16(level_script.sCurrentCmd + 12) * 0x8000 / 180)))
		spawnInfo.startAngle[3] = S16((math.modf(Rom.ReadS16(level_script.sCurrentCmd + 14) * 0x8000 / 180)))

		spawnInfo.areaIndex = S8(level_script.sCurrAreaIndex)
		spawnInfo.activeAreaIndex = S8(level_script.sCurrAreaIndex)

		spawnInfo.behaviorArg = Rom.ReadU32(level_script.sCurrentCmd + 16)
		spawnInfo.behaviorScript = Rom.ReadU32(level_script.sCurrentCmd + 20)
		spawnInfo.model = SrcGameArea.gLoadedGraphNodes[model + 1]
		spawnInfo.next = SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].objectSpawnInfos

		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].objectSpawnInfos = spawnInfo
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_create_warp_node L466-483
function level_script.level_cmd_create_warp_node()
	if level_script.sCurrAreaIndex ~= -1 then
		const warpNode = GroupsTypesHPlus3Types.new_ObjectWarpNode() -- alloc_only_pool_alloc(sLevelPool, sizeof(struct ObjectWarpNode))

		warpNode.node.id = Rom.ReadU8(level_script.sCurrentCmd + 2)
		warpNode.node.destLevel = U8(Rom.ReadU8(level_script.sCurrentCmd + 3) + Rom.ReadU8(level_script.sCurrentCmd + 6))
		warpNode.node.destArea = Rom.ReadU8(level_script.sCurrentCmd + 4)
		warpNode.node.destNode = Rom.ReadU8(level_script.sCurrentCmd + 5)

		warpNode.object = nil

		warpNode.next = SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].warpNodes
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].warpNodes = warpNode
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_create_instant_warp L485-510
function level_script.level_cmd_create_instant_warp()
	if level_script.sCurrAreaIndex ~= -1 then
		if SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].instantWarps == nil then
			-- alloc_only_pool_alloc(sLevelPool, 4 * sizeof(struct InstantWarp))
			const warps = { GroupsTypesHPlus3Types.new_InstantWarp(), GroupsTypesHPlus3Types.new_InstantWarp(), GroupsTypesHPlus3Types.new_InstantWarp(), GroupsTypesHPlus3Types.new_InstantWarp() }

			SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].instantWarps = warps

			for i = GroupsTypesHPlus3.INSTANT_WARP_INDEX_START, GroupsTypesHPlus3.INSTANT_WARP_INDEX_STOP - 1 do
				warps[i + 1].id = 0
			end
		end

		const warp = SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].instantWarps :: { GroupsTypesHPlus3Types.InstantWarp }
		const warpIndex = Rom.ReadU8(level_script.sCurrentCmd + 2)

		warp[warpIndex + 1].id = 1
		warp[warpIndex + 1].area = Rom.ReadU8(level_script.sCurrentCmd + 3)

		warp[warpIndex + 1].displacement[1] = Rom.ReadS16(level_script.sCurrentCmd + 4)
		warp[warpIndex + 1].displacement[2] = Rom.ReadS16(level_script.sCurrentCmd + 6)
		warp[warpIndex + 1].displacement[3] = Rom.ReadS16(level_script.sCurrentCmd + 8)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_terrain_type L512-518
function level_script.level_cmd_set_terrain_type()
	if level_script.sCurrAreaIndex ~= -1 then
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].terrainType = U16(bit32.bor(SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].terrainType, Rom.ReadU16(level_script.sCurrentCmd + 2)))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_create_painting_warp_node L520-543
function level_script.level_cmd_create_painting_warp_node()
	if level_script.sCurrAreaIndex ~= -1 then
		if SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].paintingWarpNodes == nil then
			-- alloc_only_pool_alloc(sLevelPool, 45 * sizeof(struct WarpNode))
			const nodes: { GroupsTypesHPlus3Types.WarpNode } = {}

			for i = 0, 44 do
				nodes[i + 1] = GroupsTypesHPlus3Types.new_WarpNode()
				nodes[i + 1].id = 0
			end

			SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].paintingWarpNodes = nodes
		end

		const node = (SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].paintingWarpNodes :: { GroupsTypesHPlus3Types.WarpNode })[Rom.ReadU8(level_script.sCurrentCmd + 2) + 1]

		node.id = 1
		node.destLevel = U8(Rom.ReadU8(level_script.sCurrentCmd + 3) + Rom.ReadU8(level_script.sCurrentCmd + 6))
		node.destArea = Rom.ReadU8(level_script.sCurrentCmd + 4)
		node.destNode = Rom.ReadU8(level_script.sCurrentCmd + 5)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_3A L545-562
function level_script.level_cmd_3A()
	if level_script.sCurrAreaIndex ~= -1 then
		local val4 = SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].unused

		if val4 == nil then
			val4 = GroupsTypesHPlus3Types.new_UnusedArea28() -- alloc_only_pool_alloc(sLevelPool, sizeof(struct UnusedArea28))
			SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].unused = val4
		end

		const unused = val4 :: GroupsTypesHPlus3Types.UnusedArea28

		unused.unk00 = Rom.ReadS16(level_script.sCurrentCmd + 2)
		unused.unk02 = Rom.ReadS16(level_script.sCurrentCmd + 4)
		unused.unk04 = Rom.ReadS16(level_script.sCurrentCmd + 6)
		unused.unk06 = Rom.ReadS16(level_script.sCurrentCmd + 8)
		unused.unk08 = Rom.ReadS16(level_script.sCurrentCmd + 10)
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_create_whirlpool L564-584
function level_script.level_cmd_create_whirlpool()
	const index = Rom.ReadU8(level_script.sCurrentCmd + 2)
	const beatBowser2 = bit32.btest(SrcGameSaveFile.save_file_get_flags(), bit32.bor(SrcGameSaveFileH.SAVE_FLAG_HAVE_KEY_2, SrcGameSaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR))

	if Rom.ReadU8(level_script.sCurrentCmd + 3) == 0 or (Rom.ReadU8(level_script.sCurrentCmd + 3) == 1 and not beatBowser2) or (Rom.ReadU8(level_script.sCurrentCmd + 3) == 2 and beatBowser2) or (Rom.ReadU8(level_script.sCurrentCmd + 3) == 3 and SrcGameArea.gCurrActNum >= 2) then
		if level_script.sCurrAreaIndex ~= -1 and index < 2 then
			local whirlpool = SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].whirlpools[index + 1]

			if whirlpool == nil then
				whirlpool = GroupsTypesHPlus3Types.new_Whirlpool() -- alloc_only_pool_alloc(sLevelPool, sizeof(struct Whirlpool))
				SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].whirlpools[index + 1] = whirlpool
			end

			const live = whirlpool :: GroupsTypesHPlus3Types.Whirlpool

			MathUtil.vec3s_set(live.pos, Rom.ReadS16(level_script.sCurrentCmd + 4), Rom.ReadS16(level_script.sCurrentCmd + 6), Rom.ReadS16(level_script.sCurrentCmd + 8))
			live.strength = Rom.ReadS16(level_script.sCurrentCmd + 10)
		end
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_blackout L586-589
function level_script.level_cmd_set_blackout()
	-- osViBlack: no call (native-stub-externals)
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_gamma L591-594
function level_script.level_cmd_set_gamma()
	-- osViSetSpecialFeatures: no call (native-stub-externals)
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_terrain_data L596-612
function level_script.level_cmd_set_terrain_data()
	if level_script.sCurrAreaIndex ~= -1 then
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].terrainData = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 4))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_rooms L614-619
function level_script.level_cmd_set_rooms()
	if level_script.sCurrAreaIndex ~= -1 then
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].surfaceRooms = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 4))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_macro_objects L621-638
function level_script.level_cmd_set_macro_objects()
	if level_script.sCurrAreaIndex ~= -1 then
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].macroObjects = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(level_script.sCurrentCmd + 4))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_load_area L640-648
function level_script.level_cmd_load_area()
	const areaIndex = Rom.ReadU8(level_script.sCurrentCmd + 2)

	Audio.stop_sounds_in_continuous_banks()
	SrcGameArea.load_area(areaIndex)

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_unload_area L650-653
function level_script.level_cmd_unload_area()
	SrcGameArea.unload_area()

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_mario_start_pos L655-666
function level_script.level_cmd_set_mario_start_pos()
	SrcGameArea.gMarioSpawnInfo.areaIndex = S8(Rom.ReadU8(level_script.sCurrentCmd + 2))

	MathUtil.vec3s_set(SrcGameArea.gMarioSpawnInfo.startPos, Rom.ReadS16(level_script.sCurrentCmd + 6), Rom.ReadS16(level_script.sCurrentCmd + 8), Rom.ReadS16(level_script.sCurrentCmd + 10))
	MathUtil.vec3s_set(SrcGameArea.gMarioSpawnInfo.startAngle, 0, S16((math.modf(Rom.ReadS16(level_script.sCurrentCmd + 4) * 0x8000 / 180))), 0)

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_2C L668-671
function level_script.level_cmd_2C()
	SrcGameArea.unload_mario_area()

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_2D L673-676
function level_script.level_cmd_2D()
	SrcGameArea.area_update_objects()

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_transition L678-683
function level_script.level_cmd_set_transition()
	if SrcGameArea.gCurrentArea ~= nil then
		SrcGameArea.play_transition(Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadU8(level_script.sCurrentCmd + 3), Rom.ReadU8(level_script.sCurrentCmd + 4), Rom.ReadU8(level_script.sCurrentCmd + 5), Rom.ReadU8(level_script.sCurrentCmd + 6))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_nop L685-688
function level_script.level_cmd_nop()
	IncludeMacrosH.CN_DEBUG_PRINTF("BAD: seqBlankColor\n")
	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_show_dialog L690-697
function level_script.level_cmd_show_dialog()
	if level_script.sCurrAreaIndex ~= -1 then
		if Rom.ReadU8(level_script.sCurrentCmd + 2) < 2 then
			buffer.writeu8(SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].dialog, Rom.ReadU8(level_script.sCurrentCmd + 2), Rom.ReadU8(level_script.sCurrentCmd + 3))
		end
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_music L699-705
function level_script.level_cmd_set_music()
	if level_script.sCurrAreaIndex ~= -1 then
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].musicParam = U16(Rom.ReadS16(level_script.sCurrentCmd + 2))
		SrcGameArea.gAreas[level_script.sCurrAreaIndex + 1].musicParam2 = U16(Rom.ReadS16(level_script.sCurrentCmd + 4))
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_set_menu_music L707-710
function level_script.level_cmd_set_menu_music()
	SrcGameSoundInit.set_background_music(0, Rom.ReadS16(level_script.sCurrentCmd + 2), 0)

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_38 L712-715
function level_script.level_cmd_38()
	SrcGameSoundInit.fadeout_music(Rom.ReadS16(level_script.sCurrentCmd + 2))

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_cmd_get_or_set_var L717-757
function level_script.level_cmd_get_or_set_var()
	if Rom.ReadU8(level_script.sCurrentCmd + 2) == 0 then
		if Rom.ReadU8(level_script.sCurrentCmd + 3) == 0 then
			SrcGameArea.gCurrSaveFileNum = S16(level_script.sRegister)
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 1 then
			SrcGameArea.gCurrCourseNum = S16(level_script.sRegister)
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 2 then
			SrcGameArea.gCurrActNum = S16(level_script.sRegister)
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 3 then
			SrcGameArea.gCurrLevelNum = S16(level_script.sRegister)
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 4 then
			SrcGameArea.gCurrAreaIndex = S16(level_script.sRegister)
		end
	else
		if Rom.ReadU8(level_script.sCurrentCmd + 3) == 0 then
			level_script.sRegister = SrcGameArea.gCurrSaveFileNum
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 1 then
			level_script.sRegister = SrcGameArea.gCurrCourseNum
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 2 then
			level_script.sRegister = SrcGameArea.gCurrActNum
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 3 then
			level_script.sRegister = SrcGameArea.gCurrLevelNum
		elseif Rom.ReadU8(level_script.sCurrentCmd + 3) == 4 then
			level_script.sRegister = SrcGameArea.gCurrAreaIndex
		end
	end

	level_script.sCurrentCmd += Rom.ReadU8(level_script.sCurrentCmd + 1)
end

-- from src/engine/level_script.c:level_script_execute L823-841
function level_script.level_script_execute(cmd: number): number
	level_script.sScriptStatus = level_script.SCRIPT_RUNNING
	level_script.sCurrentCmd = cmd

	while level_script.sScriptStatus == level_script.SCRIPT_RUNNING do
		IncludeMacrosH.CN_DEBUG_PRINTF("%08X: ")
		IncludeMacrosH.CN_DEBUG_PRINTF("%02d\n")

		level_script.LevelScriptJumpTable[Rom.ReadU8(level_script.sCurrentCmd) + 1]()
	end

	-- profiler_log_thread5_time: no call (native-stub-externals)
	SrcGameGameInit.init_rcp()
	SrcGameArea.render_game()
	SrcGameGameInit.end_master_display_list()
	SrcGameMemory.alloc_display_list(0)

	return level_script.sCurrentCmd
end

-- from src/engine/level_script.c:sStackTop L51-51
level_script.sStackTop = 0

-- from src/engine/level_script.c:LevelScriptJumpTable L759-821
level_script.LevelScriptJumpTable = {
	level_script.level_cmd_load_and_execute,
	level_script.level_cmd_exit_and_execute,
	level_script.level_cmd_exit,
	level_script.level_cmd_sleep,
	level_script.level_cmd_sleep2,
	level_script.level_cmd_jump,
	level_script.level_cmd_jump_and_link,
	level_script.level_cmd_return,
	level_script.level_cmd_jump_and_link_push_arg,
	level_script.level_cmd_jump_repeat,
	level_script.level_cmd_loop_begin,
	level_script.level_cmd_loop_until,
	level_script.level_cmd_jump_if,
	level_script.level_cmd_jump_and_link_if,
	level_script.level_cmd_skip_if,
	level_script.level_cmd_skip,
	level_script.level_cmd_skippable_nop,
	level_script.level_cmd_call,
	level_script.level_cmd_call_loop,
	level_script.level_cmd_set_register,
	level_script.level_cmd_push_pool_state,
	level_script.level_cmd_pop_pool_state,
	level_script.level_cmd_load_to_fixed_address,
	level_script.level_cmd_load_raw,
	level_script.level_cmd_load_mio0,
	level_script.level_cmd_load_mario_head,
	level_script.level_cmd_load_mio0_texture,
	level_script.level_cmd_init_level,
	level_script.level_cmd_clear_level,
	level_script.level_cmd_alloc_level_pool,
	level_script.level_cmd_free_level_pool,
	level_script.level_cmd_begin_area,
	level_script.level_cmd_end_area,
	level_script.level_cmd_load_model_from_dl,
	level_script.level_cmd_load_model_from_geo,
	level_script.level_cmd_23,
	level_script.level_cmd_place_object,
	level_script.level_cmd_init_mario,
	level_script.level_cmd_create_warp_node,
	level_script.level_cmd_create_painting_warp_node,
	level_script.level_cmd_create_instant_warp,
	level_script.level_cmd_load_area,
	level_script.level_cmd_unload_area,
	level_script.level_cmd_set_mario_start_pos,
	level_script.level_cmd_2C,
	level_script.level_cmd_2D,
	level_script.level_cmd_set_terrain_data,
	level_script.level_cmd_set_rooms,
	level_script.level_cmd_show_dialog,
	level_script.level_cmd_set_terrain_type,
	level_script.level_cmd_nop,
	level_script.level_cmd_set_transition,
	level_script.level_cmd_set_blackout,
	level_script.level_cmd_set_gamma,
	level_script.level_cmd_set_music,
	level_script.level_cmd_set_menu_music,
	level_script.level_cmd_38,
	level_script.level_cmd_set_macro_objects,
	level_script.level_cmd_3A,
	level_script.level_cmd_create_whirlpool,
	level_script.level_cmd_get_or_set_var,
}

return level_script
