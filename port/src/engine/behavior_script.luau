--!strict
--!optimize 2

--[[
	Port of src/engine/behavior_script.c.
]]

const Registry = require("../../groups/registry")

const Rom = require("../rom/rom")
const NativeCalls = require("../rom/native_calls")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const BehaviorScriptH = require("./behavior_script_h")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const SrcGameMemory = require("../game/memory")
const BehaviorIds = require("../rom/behavior_ids")
const SrcGameObjectHelpersH = require("../game/object_helpers_h")

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

-- from src/engine/behavior_script.c:data
const behavior_script = {
	-- from src/engine/behavior_script.c:gRandomSeed16 L31-31
	gRandomSeed16 = 0,
}

Registry.Register("src__engine__behavior_script", behavior_script)

-- The C stack array table[16] of bhv_cmd_set_int_random_from_table: module scratch, no allocation per call
const RandomFromTableScratch = table.create(16, 0)

-- from src/engine/behavior_script.c:BHV_CMD_GET_1ST_U8 L18-18
function behavior_script.BHV_CMD_GET_1ST_U8(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return U8(bit32.band(bit32.rshift(Command, 24), 0xFF))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_2ND_U8 L19-19
function behavior_script.BHV_CMD_GET_2ND_U8(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return U8(bit32.band(bit32.rshift(Command, 16), 0xFF))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_3RD_U8 L20-20
function behavior_script.BHV_CMD_GET_3RD_U8(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return U8(bit32.band(bit32.rshift(Command, 8), 0xFF))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_4TH_U8 L21-21
function behavior_script.BHV_CMD_GET_4TH_U8(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return U8(bit32.band(Command, 0xFF))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_1ST_S16 L23-23
function behavior_script.BHV_CMD_GET_1ST_S16(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return S16(bit32.rshift(Command, 16))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_2ND_S16 L24-24
function behavior_script.BHV_CMD_GET_2ND_S16(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return S16(bit32.band(Command, 0xFFFF))
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_U32 L26-26
function behavior_script.BHV_CMD_GET_U32(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return Command
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_VPTR L27-27
function behavior_script.BHV_CMD_GET_VPTR(index: number): number
	const Command = Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4)

	return Command
end

-- from src/engine/behavior_script.c:BHV_CMD_GET_ADDR_OF_CMD L29-29
function behavior_script.BHV_CMD_GET_ADDR_OF_CMD(index: number): number
	return Registry.Members.src__game__object_list_processor.gCurBhvCommand + index * 4
end

-- from src/engine/behavior_script.c:goto_behavior_unused L34-37
function behavior_script.goto_behavior_unused(bhvAddr: number)
	Registry.Members.src__game__object_list_processor.gCurBhvCommand = SrcGameMemory.segmented_to_virtual(bhvAddr)
	Registry.Members.src__game__object_list_processor.gCurrentObject.bhvStackIndex = 0
end

-- from src/engine/behavior_script.c:random_u16 L40-66
function behavior_script.random_u16(): number
	if behavior_script.gRandomSeed16 == 22026 then
		behavior_script.gRandomSeed16 = 0
	end

	local temp1 = U16(bit32.lshift(bit32.band(behavior_script.gRandomSeed16, 0x00FF), 8))

	temp1 = U16(bit32.bxor(temp1, behavior_script.gRandomSeed16))

	behavior_script.gRandomSeed16 = U16(bit32.lshift(bit32.band(temp1, 0x00FF), 8) + bit32.rshift(bit32.band(temp1, 0xFF00), 8))

	temp1 = U16(bit32.bxor(bit32.lshift(bit32.band(temp1, 0x00FF), 1), behavior_script.gRandomSeed16))

	const temp2 = U16(bit32.bxor(bit32.rshift(temp1, 1), 0xFF80))

	if not bit32.btest(temp1, 1) then
		if temp2 == 43605 then
			behavior_script.gRandomSeed16 = 0
		else
			behavior_script.gRandomSeed16 = U16(bit32.bxor(temp2, 0x1FF4))
		end
	else
		behavior_script.gRandomSeed16 = U16(bit32.bxor(temp2, 0x8180))
	end

	return behavior_script.gRandomSeed16
end

-- from src/engine/behavior_script.c:random_float L69-72
function behavior_script.random_float(): number
	const rnd = behavior_script.random_u16()

	return F32(rnd / 0x10000)
end

-- from src/engine/behavior_script.c:random_sign L75-81
function behavior_script.random_sign(): number
	if behavior_script.random_u16() >= 0x7FFF then
		return 1
	else
		return -1
	end
end

-- from src/engine/behavior_script.c:obj_update_gfx_pos_and_angle L84-92
function behavior_script.obj_update_gfx_pos_and_angle(obj: GroupsTypesHPlus3Types.Object)
	obj.header.gfx.pos[1] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	obj.header.gfx.pos[2] = F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(obj.rawData, IncludeObjectFieldsH.oGraphYOffset))
	obj.header.gfx.pos[3] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)

	obj.header.gfx.angle[1] = S16(bit32.band(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oFaceAnglePitch), 0xFFFF))
	obj.header.gfx.angle[2] = S16(bit32.band(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oFaceAngleYaw), 0xFFFF))
	obj.header.gfx.angle[3] = S16(bit32.band(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oFaceAngleRoll), 0xFFFF))
end

-- from src/engine/behavior_script.c:cur_obj_bhv_stack_push L95-98
function behavior_script.cur_obj_bhv_stack_push(bhvAddr: number)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.bhvStack[currentObject.bhvStackIndex + 1] = bhvAddr
	currentObject.bhvStackIndex += 1
end

-- from src/engine/behavior_script.c:cur_obj_bhv_stack_pop L101-108
function behavior_script.cur_obj_bhv_stack_pop(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.bhvStackIndex -= 1

	const bhvAddr = currentObject.bhvStack[currentObject.bhvStackIndex + 1]

	return bhvAddr
end

-- from src/engine/behavior_script.c:stub_behavior_script_1 L110-114
function behavior_script.stub_behavior_script_1()
	while true do
	end
end

-- from src/engine/behavior_script.c:bhv_cmd_hide L118-123
function behavior_script.bhv_cmd_hide(): number
	Registry.Members.src__game__object_helpers.cur_obj_hide()
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_disable_rendering L127-132
function behavior_script.bhv_cmd_disable_rendering(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.header.gfx.node.flags = S16(bit32.band(currentObject.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_billboard L136-141
function behavior_script.bhv_cmd_billboard(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.header.gfx.node.flags = S16(bit32.bor(currentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_model L145-152
function behavior_script.bhv_cmd_set_model(): number
	const modelID = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.header.gfx.sharedChild = Registry.Members.src__game__area.gLoadedGraphNodes[modelID + 1]

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_spawn_child L156-165
function behavior_script.bhv_cmd_spawn_child(): number
	const model = behavior_script.BHV_CMD_GET_U32(1)
	const behavior = behavior_script.BHV_CMD_GET_VPTR(2)
	const child = Registry.Members.src__game__object_helpers.spawn_object_at_origin(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, model, behavior)

	Registry.Members.src__game__object_helpers.obj_copy_pos_and_angle(child, Registry.Members.src__game__object_list_processor.gCurrentObject)
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 12

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_spawn_obj L169-180
function behavior_script.bhv_cmd_spawn_obj(): number
	const model = behavior_script.BHV_CMD_GET_U32(1)
	const behavior = behavior_script.BHV_CMD_GET_VPTR(2)
	const object = Registry.Members.src__game__object_helpers.spawn_object_at_origin(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, model, behavior)

	Registry.Members.src__game__object_helpers.obj_copy_pos_and_angle(object, Registry.Members.src__game__object_list_processor.gCurrentObject)

	-- Does this cmd need renaming? This line is the only difference between this and the above func.
	Registry.Members.src__game__object_list_processor.gCurrentObject.prevObj = object
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 12

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_spawn_child_with_param L184-195
function behavior_script.bhv_cmd_spawn_child_with_param(): number
	const bhvParam = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const modelID = behavior_script.BHV_CMD_GET_U32(1)
	const behavior = behavior_script.BHV_CMD_GET_VPTR(2)
	const child = Registry.Members.src__game__object_helpers.spawn_object_at_origin(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, modelID, behavior)

	Registry.Members.src__game__object_helpers.obj_copy_pos_and_angle(child, Registry.Members.src__game__object_list_processor.gCurrentObject)
	buffer.writei32(child.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, bhvParam)
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 12

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_deactivate L199-202
function behavior_script.bhv_cmd_deactivate(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED

	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_break L206-208
function behavior_script.bhv_cmd_break(): number
	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_break_unused L212-214
function behavior_script.bhv_cmd_break_unused(): number
	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_call L218-227
function behavior_script.bhv_cmd_call(): number
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4
	behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))

	const jumpAddress = SrcGameMemory.segmented_to_virtual(behavior_script.BHV_CMD_GET_VPTR(0))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand = jumpAddress

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_return L231-234
function behavior_script.bhv_cmd_return(): number
	Registry.Members.src__game__object_list_processor.gCurBhvCommand = behavior_script.cur_obj_bhv_stack_pop()

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_delay L238-249
function behavior_script.bhv_cmd_delay(): number
	const num = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	if currentObject.bhvDelayTimer < num - 1 then
		currentObject.bhvDelayTimer = S16(currentObject.bhvDelayTimer + 1)
	else
		currentObject.bhvDelayTimer = 0
		Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4
	end

	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_delay_var L253-265
function behavior_script.bhv_cmd_delay_var(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const num = BehaviorScriptH.cur_obj_get_int(field * 4)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	if currentObject.bhvDelayTimer < num - 1 then
		currentObject.bhvDelayTimer = S16(currentObject.bhvDelayTimer + 1)
	else
		currentObject.bhvDelayTimer = 0
		Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4
	end

	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_goto L269-273
function behavior_script.bhv_cmd_goto(): number
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4 -- Useless as a step, but BHV_CMD_GET_VPTR(0) reads the word after the command
	Registry.Members.src__game__object_list_processor.gCurBhvCommand = SrcGameMemory.segmented_to_virtual(behavior_script.BHV_CMD_GET_VPTR(0)) -- Jump directly to address

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_begin_repeat_unused L278-286
function behavior_script.bhv_cmd_begin_repeat_unused(): number
	const count = behavior_script.BHV_CMD_GET_2ND_U8(0)

	behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))
	behavior_script.cur_obj_bhv_stack_push(count)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_begin_repeat L290-298
function behavior_script.bhv_cmd_begin_repeat(): number
	const count = behavior_script.BHV_CMD_GET_2ND_S16(0)

	behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))
	behavior_script.cur_obj_bhv_stack_push(count)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_end_repeat L302-318
function behavior_script.bhv_cmd_end_repeat(): number
	local count = U32(behavior_script.cur_obj_bhv_stack_pop())

	count = U32(count - 1)

	if count ~= 0 then
		Registry.Members.src__game__object_list_processor.gCurBhvCommand = behavior_script.cur_obj_bhv_stack_pop()
		behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(0))
		behavior_script.cur_obj_bhv_stack_push(count)
	else
		behavior_script.cur_obj_bhv_stack_pop()
		Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4
	end

	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_end_repeat_continue L322-338
function behavior_script.bhv_cmd_end_repeat_continue(): number
	local count = U32(behavior_script.cur_obj_bhv_stack_pop())

	count = U32(count - 1)

	if count ~= 0 then
		Registry.Members.src__game__object_list_processor.gCurBhvCommand = behavior_script.cur_obj_bhv_stack_pop()
		behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(0))
		behavior_script.cur_obj_bhv_stack_push(count)
	else
		behavior_script.cur_obj_bhv_stack_pop()
		Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4
	end

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_begin_loop L342-347
function behavior_script.bhv_cmd_begin_loop(): number
	behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_end_loop L351-356
function behavior_script.bhv_cmd_end_loop(): number
	Registry.Members.src__game__object_list_processor.gCurBhvCommand = behavior_script.cur_obj_bhv_stack_pop()
	behavior_script.cur_obj_bhv_stack_push(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(0))

	return BehaviorScriptH.BHV_PROC_BREAK
end

-- from src/engine/behavior_script.c:bhv_cmd_call_native L361-368
function behavior_script.bhv_cmd_call_native(): number
	const BlockStart, SlotOffset = Rom.BlockOf(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))
	const behaviorFunc = NativeCalls.FunctionAt(BlockStart, SlotOffset) :: () -> ()

	behaviorFunc()

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4
	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_float L372-380
function behavior_script.bhv_cmd_set_float(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	BehaviorScriptH.cur_obj_set_float(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_int L384-392
function behavior_script.bhv_cmd_set_int(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	BehaviorScriptH.cur_obj_set_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_int_unused L395-403
function behavior_script.bhv_cmd_set_int_unused(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const value = behavior_script.BHV_CMD_GET_2ND_S16(1)

	BehaviorScriptH.cur_obj_set_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_random_float L407-416
function behavior_script.bhv_cmd_set_random_float(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const min = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const range = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const value = F32(F32(range * behavior_script.random_float()) + min)

	BehaviorScriptH.cur_obj_set_float(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_random_int L420-429
function behavior_script.bhv_cmd_set_random_int(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const min = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const range = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const value = S32(TruncS32(F32(range * behavior_script.random_float())) + min)

	BehaviorScriptH.cur_obj_set_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_int_rand_rshift L433-442
function behavior_script.bhv_cmd_set_int_rand_rshift(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const min = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const rshift = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const value = S32(bit32.arshift(behavior_script.random_u16(), rshift) + min)

	BehaviorScriptH.cur_obj_set_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_add_random_float L446-455
function behavior_script.bhv_cmd_add_random_float(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const min = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const range = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const value = F32(F32(BehaviorScriptH.cur_obj_get_float(field * 4) + min) + F32(range * behavior_script.random_float()))

	BehaviorScriptH.cur_obj_set_float(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_add_int_rand_rshift L459-469
function behavior_script.bhv_cmd_add_int_rand_rshift(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const min = behavior_script.BHV_CMD_GET_2ND_S16(0)
	const rshift = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const rnd = behavior_script.random_u16()

	const value = S32(S32(BehaviorScriptH.cur_obj_get_int(field * 4) + min) + bit32.arshift(rnd, rshift))

	BehaviorScriptH.cur_obj_set_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_add_float L473-481
function behavior_script.bhv_cmd_add_float(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	BehaviorScriptH.cur_obj_add_float(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_add_int L485-493
function behavior_script.bhv_cmd_add_int(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	BehaviorScriptH.cur_obj_add_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_or_int L498-507
function behavior_script.bhv_cmd_or_int(): number
	const objectOffset = behavior_script.BHV_CMD_GET_2ND_U8(0)
	local value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	value = bit32.band(value, 0xFFFF)
	BehaviorScriptH.cur_obj_or_int(objectOffset * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_bit_clear L511-520
function behavior_script.bhv_cmd_bit_clear(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	local value = behavior_script.BHV_CMD_GET_2ND_S16(0)

	value = bit32.bxor(bit32.band(value, 0xFFFF), 0xFFFF)
	BehaviorScriptH.cur_obj_and_int(field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_load_animations L524-531
function behavior_script.bhv_cmd_load_animations(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)

	BehaviorScriptH.cur_obj_set_vptr(field, behavior_script.BHV_CMD_GET_VPTR(1))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_animate L535-543
function behavior_script.bhv_cmd_animate(): number
	const animIndex = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const animations = Registry.Members.src__game__object_list_processor.gCurrentObject.ptrData[IncludeObjectFieldsH.oAnimations + 1] :: number

	Registry.Members.src__engine__graph_node.geo_obj_init_animation(Registry.Members.src__game__object_list_processor.gCurrentObject.header.gfx, animations + animIndex * 4)
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_drop_to_floor L547-558
function behavior_script.bhv_cmd_drop_to_floor(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const x = buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosX)
	const y = buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosY)
	const z = buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosZ)

	const floor = Registry.Members.src__engine__surface_collision.find_floor_height(x, F32(y + 200), z)

	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oPosY, floor)
	buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(currentObject.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_nop_1 L562-567
function behavior_script.bhv_cmd_nop_1(): number
	behavior_script.BHV_CMD_GET_2ND_U8(0)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_nop_3 L571-576
function behavior_script.bhv_cmd_nop_3(): number
	behavior_script.BHV_CMD_GET_2ND_U8(0)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_nop_2 L580-585
function behavior_script.bhv_cmd_nop_2(): number
	behavior_script.BHV_CMD_GET_2ND_U8(0)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_sum_float L589-598
function behavior_script.bhv_cmd_sum_float(): number
	const fieldDst = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const fieldSrc1 = behavior_script.BHV_CMD_GET_3RD_U8(0)
	const fieldSrc2 = behavior_script.BHV_CMD_GET_4TH_U8(0)
	const sum = F32(BehaviorScriptH.cur_obj_get_float(fieldSrc1 * 4) + BehaviorScriptH.cur_obj_get_float(fieldSrc2 * 4))

	BehaviorScriptH.cur_obj_set_float(fieldDst * 4, sum)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_sum_int L602-611
function behavior_script.bhv_cmd_sum_int(): number
	const fieldDst = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const fieldSrc1 = behavior_script.BHV_CMD_GET_3RD_U8(0)
	const fieldSrc2 = behavior_script.BHV_CMD_GET_4TH_U8(0)
	const sum = S32(BehaviorScriptH.cur_obj_get_int(fieldSrc1 * 4) + BehaviorScriptH.cur_obj_get_int(fieldSrc2 * 4))

	BehaviorScriptH.cur_obj_set_int(fieldDst * 4, sum)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_hitbox L615-624
function behavior_script.bhv_cmd_set_hitbox(): number
	const radius = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const height = behavior_script.BHV_CMD_GET_2ND_S16(1)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.hitboxRadius = radius
	currentObject.hitboxHeight = height

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_hurtbox L628-637
function behavior_script.bhv_cmd_set_hurtbox(): number
	const radius = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const height = behavior_script.BHV_CMD_GET_2ND_S16(1)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.hurtboxRadius = radius
	currentObject.hurtboxHeight = height

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_hitbox_with_offset L641-652
function behavior_script.bhv_cmd_set_hitbox_with_offset(): number
	const radius = behavior_script.BHV_CMD_GET_1ST_S16(1)
	const height = behavior_script.BHV_CMD_GET_2ND_S16(1)
	const downOffset = behavior_script.BHV_CMD_GET_1ST_S16(2)
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	currentObject.hitboxRadius = radius
	currentObject.hitboxHeight = height
	currentObject.hitboxDownOffset = downOffset

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 3 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_nop_4 L656-662
function behavior_script.bhv_cmd_nop_4(): number
	behavior_script.BHV_CMD_GET_2ND_U8(0)
	behavior_script.BHV_CMD_GET_2ND_S16(0)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_begin L667-684
function behavior_script.bhv_cmd_begin(): number
	-- Initiate the room if the object is a haunted chair or the mad piano.
	if Registry.Members.src__game__object_helpers.cur_obj_has_behavior(BehaviorIds.bhvHauntedChair) ~= 0 then
		Registry.Members.src__game__object_helpers.bhv_init_room()
	end

	if Registry.Members.src__game__object_helpers.cur_obj_has_behavior(BehaviorIds.bhvMadPiano) ~= 0 then
		Registry.Members.src__game__object_helpers.bhv_init_room()
	end

	-- Set collision distance if the object is a message panel.
	if Registry.Members.src__game__object_helpers.cur_obj_has_behavior(BehaviorIds.bhvMessagePanel) ~= 0 then
		buffer.writef32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oCollisionDistance, 150.0)
	end

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_int_random_from_table L690-703
function behavior_script.bhv_cmd_set_int_random_from_table(tableSize: number)
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const limit = math.modf(tableSize / 2)

	for i = 0, limit, 2 do
		RandomFromTableScratch[i + 1] = behavior_script.BHV_CMD_GET_1ST_S16(i + 1)
		RandomFromTableScratch[i + 2] = behavior_script.BHV_CMD_GET_2ND_S16(i + 1)
	end

	const index = TruncS32(F32(tableSize * behavior_script.random_float()))

	BehaviorScriptH.cur_obj_set_int(field * 4, RandomFromTableScratch[index + 1])
end

-- from src/engine/behavior_script.c:bhv_cmd_load_collision_data L732-739
function behavior_script.bhv_cmd_load_collision_data(): number
	const collisionData = SrcGameMemory.segmented_to_virtual(behavior_script.BHV_CMD_GET_VPTR(1))

	Registry.Members.src__game__object_list_processor.gCurrentObject.collisionData = collisionData
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 8

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_home L743-750
function behavior_script.bhv_cmd_set_home(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosZ))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_interact_type L754-759
function behavior_script.bhv_cmd_set_interact_type(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oInteractType, behavior_script.BHV_CMD_GET_U32(1))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_interact_subtype L763-768
function behavior_script.bhv_cmd_set_interact_subtype(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oInteractionSubtype, behavior_script.BHV_CMD_GET_U32(1))

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_scale L772-780
function behavior_script.bhv_cmd_scale(): number
	-- unusedField is a dead read
	const percent = behavior_script.BHV_CMD_GET_2ND_S16(0)

	Registry.Members.src__game__object_helpers.cur_obj_scale(F32(percent / 100.0))
	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_set_obj_physics L785-800
function behavior_script.bhv_cmd_set_obj_physics(): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oWallHitboxRadius, behavior_script.BHV_CMD_GET_1ST_S16(1))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oGravity, F32(behavior_script.BHV_CMD_GET_2ND_S16(1) / 100))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oBounciness, F32(behavior_script.BHV_CMD_GET_1ST_S16(2) / 100))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oDragStrength, F32(behavior_script.BHV_CMD_GET_2ND_S16(2) / 100))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oFriction, F32(behavior_script.BHV_CMD_GET_1ST_S16(3) / 100))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oBuoyancy, F32(behavior_script.BHV_CMD_GET_2ND_S16(3) / 100))

	-- The C unused1 and unused2 are dead stores: their reads are kept, their values are not.
	behavior_script.BHV_CMD_GET_1ST_S16(4)
	behavior_script.BHV_CMD_GET_2ND_S16(4)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 5 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_parent_bit_clear L805-814
function behavior_script.bhv_cmd_parent_bit_clear(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	local value = S32(behavior_script.BHV_CMD_GET_U32(1))

	value = S32(bit32.bxor(value, 0xFFFFFFFF))
	BehaviorScriptH.obj_and_int(Registry.Members.src__game__object_list_processor.gCurrentObject.parentObj, field * 4, value)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_spawn_water_droplet L818-825
function behavior_script.bhv_cmd_spawn_water_droplet(): number
	const BlockStart, SlotOffset = Rom.BlockOf(behavior_script.BHV_CMD_GET_ADDR_OF_CMD(1))
	const dropletParams = NativeCalls.DataAt(BlockStart, SlotOffset) :: SrcGameObjectHelpersH.WaterDropletParams

	Registry.Members.src__game__object_helpers.spawn_water_droplet(Registry.Members.src__game__object_list_processor.gCurrentObject, dropletParams)

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 2 * 4
	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:bhv_cmd_animate_texture L829-840
function behavior_script.bhv_cmd_animate_texture(): number
	const field = behavior_script.BHV_CMD_GET_2ND_U8(0)
	const rate = behavior_script.BHV_CMD_GET_2ND_S16(0)

	-- The u32 timer takes rate as unsigned in its %.
	if math.fmod(Registry.Members.src__game__game_init.gGlobalTimer, U32(rate)) == 0 then
		BehaviorScriptH.cur_obj_add_int(field * 4, 1)
	end

	Registry.Members.src__game__object_list_processor.gCurBhvCommand += 4

	return BehaviorScriptH.BHV_PROC_CONTINUE
end

-- from src/engine/behavior_script.c:stub_behavior_script_2 L842-843
function behavior_script.stub_behavior_script_2()
	-- Empty in the source.
end

-- from src/engine/behavior_script.c:cur_obj_update L906-1003
function behavior_script.cur_obj_update()
	local objFlags = S16(buffer.readu32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oFlags))
	local distanceFromMario: number

	-- Calculate the distance from the object to Mario.
	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_COMPUTE_DIST_TO_MARIO) then
		const distToMario = Registry.Members.src__game__object_helpers.dist_between_objects(Registry.Members.src__game__object_list_processor.gCurrentObject, Registry.Members.src__game__object_list_processor.gMarioObject) :: number

		buffer.writef32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oDistanceToMario, distToMario)
		distanceFromMario = buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oDistanceToMario)
	else
		distanceFromMario = 0.0
	end

	-- Calculate the angle from the object to Mario.
	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO) then
		const angleToMario = Registry.Members.src__game__object_helpers.obj_angle_to_object(Registry.Members.src__game__object_list_processor.gCurrentObject, Registry.Members.src__game__object_list_processor.gMarioObject) :: number

		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oAngleToMario, angleToMario)
	end

	-- If the object's action has changed, reset the action timer.
	if buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oAction) ~= buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPrevAction) then
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oTimer, 0)
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oSubAction, 0)
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPrevAction, buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oAction))
	end

	-- Execute the behavior script.
	Registry.Members.src__game__object_list_processor.gCurBhvCommand = Registry.Members.src__game__object_list_processor.gCurrentObject.curBhvCommand :: number

	local bhvProcResult: number

	repeat
		const bhvCmdProc = behavior_script.BehaviorCmdTable[bit32.rshift(Rom.ReadU32(Registry.Members.src__game__object_list_processor.gCurBhvCommand), 24) + 1]

		bhvProcResult = bhvCmdProc()
	until not (bhvProcResult == BehaviorScriptH.BHV_PROC_CONTINUE)

	Registry.Members.src__game__object_list_processor.gCurrentObject.curBhvCommand = Registry.Members.src__game__object_list_processor.gCurBhvCommand

	-- Increment the object's timer.
	if buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oTimer) < 0x3FFFFFFF then
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oTimer, buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oTimer) + 1)
	end

	-- If the object's action has changed, reset the action timer.
	if buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oAction) ~= buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPrevAction) then
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oTimer, 0)
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oSubAction, 0)
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPrevAction, buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oAction))
	end

	-- Execute various code based on object flags.
	objFlags = S16(buffer.readu32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oFlags))

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_ANGLE_TO_MOVE_ANGLE) then
		Registry.Members.src__game__object_helpers.obj_set_face_angle_to_move_angle(Registry.Members.src__game__object_list_processor.gCurrentObject)
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW) then
		buffer.writei32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_MOVE_XZ_USING_FVEL) then
		Registry.Members.src__game__object_helpers.cur_obj_move_xz_using_fvel_and_yaw()
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_MOVE_Y_WITH_TERMINAL_VEL) then
		Registry.Members.src__game__object_helpers.cur_obj_move_y_with_terminal_vel()
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_TRANSFORM_RELATIVE_TO_PARENT) then
		Registry.Members.src__game__object_helpers.obj_build_transform_relative_to_parent(Registry.Members.src__game__object_list_processor.gCurrentObject)
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_SET_THROW_MATRIX_FROM_TRANSFORM) then
		Registry.Members.src__game__object_helpers.obj_set_throw_matrix_from_transform(Registry.Members.src__game__object_list_processor.gCurrentObject)
	end

	if bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE) then
		behavior_script.obj_update_gfx_pos_and_angle(Registry.Members.src__game__object_list_processor.gCurrentObject)
	end

	-- Handle visibility of object
	if buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oRoom) ~= -1 then
		-- If the object is in a room, only show it when Mario is in the room.
		Registry.Members.src__game__object_helpers.cur_obj_enable_rendering_if_mario_in_room()
	elseif bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_COMPUTE_DIST_TO_MARIO) and Registry.Members.src__game__object_list_processor.gCurrentObject.collisionData == nil then
		if not bit32.btest(objFlags, IncludeObjectConstantsH.OBJ_FLAG_ACTIVE_FROM_AFAR) then
			-- If the object has a render distance, check if it should be shown.
			if distanceFromMario > buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oDrawingDistance) then
				-- Out of render distance, hide the object.
				Registry.Members.src__game__object_list_processor.gCurrentObject.header.gfx.node.flags = S16(bit32.band(Registry.Members.src__game__object_list_processor.gCurrentObject.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
				Registry.Members.src__game__object_list_processor.gCurrentObject.activeFlags = S16(bit32.bor(Registry.Members.src__game__object_list_processor.gCurrentObject.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_FAR_AWAY))
			elseif buffer.readu32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oHeldState) == IncludeObjectConstantsH.HELD_FREE then
				-- In render distance (and not being held), show the object.
				Registry.Members.src__game__object_list_processor.gCurrentObject.header.gfx.node.flags = S16(bit32.bor(Registry.Members.src__game__object_list_processor.gCurrentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
				Registry.Members.src__game__object_list_processor.gCurrentObject.activeFlags = S16(bit32.band(Registry.Members.src__game__object_list_processor.gCurrentObject.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_FAR_AWAY)))
			end
		end
	end
end

-- from src/engine/behavior_script.c:BehaviorCmdTable L846-903
behavior_script.BehaviorCmdTable = {
	behavior_script.bhv_cmd_begin,
	behavior_script.bhv_cmd_delay,
	behavior_script.bhv_cmd_call,
	behavior_script.bhv_cmd_return,
	behavior_script.bhv_cmd_goto,
	behavior_script.bhv_cmd_begin_repeat,
	behavior_script.bhv_cmd_end_repeat,
	behavior_script.bhv_cmd_end_repeat_continue,
	behavior_script.bhv_cmd_begin_loop,
	behavior_script.bhv_cmd_end_loop,
	behavior_script.bhv_cmd_break,
	behavior_script.bhv_cmd_break_unused,
	behavior_script.bhv_cmd_call_native,
	behavior_script.bhv_cmd_add_float,
	behavior_script.bhv_cmd_set_float,
	behavior_script.bhv_cmd_add_int,
	behavior_script.bhv_cmd_set_int,
	behavior_script.bhv_cmd_or_int,
	behavior_script.bhv_cmd_bit_clear,
	behavior_script.bhv_cmd_set_int_rand_rshift,
	behavior_script.bhv_cmd_set_random_float,
	behavior_script.bhv_cmd_set_random_int,
	behavior_script.bhv_cmd_add_random_float,
	behavior_script.bhv_cmd_add_int_rand_rshift,
	behavior_script.bhv_cmd_nop_1,
	behavior_script.bhv_cmd_nop_2,
	behavior_script.bhv_cmd_nop_3,
	behavior_script.bhv_cmd_set_model,
	behavior_script.bhv_cmd_spawn_child,
	behavior_script.bhv_cmd_deactivate,
	behavior_script.bhv_cmd_drop_to_floor,
	behavior_script.bhv_cmd_sum_float,
	behavior_script.bhv_cmd_sum_int,
	behavior_script.bhv_cmd_billboard,
	behavior_script.bhv_cmd_hide,
	behavior_script.bhv_cmd_set_hitbox,
	behavior_script.bhv_cmd_nop_4,
	behavior_script.bhv_cmd_delay_var,
	behavior_script.bhv_cmd_begin_repeat_unused,
	behavior_script.bhv_cmd_load_animations,
	behavior_script.bhv_cmd_animate,
	behavior_script.bhv_cmd_spawn_child_with_param,
	behavior_script.bhv_cmd_load_collision_data,
	behavior_script.bhv_cmd_set_hitbox_with_offset,
	behavior_script.bhv_cmd_spawn_obj,
	behavior_script.bhv_cmd_set_home,
	behavior_script.bhv_cmd_set_hurtbox,
	behavior_script.bhv_cmd_set_interact_type,
	behavior_script.bhv_cmd_set_obj_physics,
	behavior_script.bhv_cmd_set_interact_subtype,
	behavior_script.bhv_cmd_scale,
	behavior_script.bhv_cmd_parent_bit_clear,
	behavior_script.bhv_cmd_animate_texture,
	behavior_script.bhv_cmd_disable_rendering,
	behavior_script.bhv_cmd_set_int_unused,
	behavior_script.bhv_cmd_spawn_water_droplet,
}

return behavior_script
