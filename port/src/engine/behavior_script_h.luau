--!strict
--!optimize 2

--[[
	Port of src/engine/behavior_script.h.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/engine/behavior_script.h:data
const behavior_script_h = {
	BHV_PROC_CONTINUE = 0,
	BHV_PROC_BREAK = 1,
}

-- from src/engine/behavior_script.h:cur_obj_get_int L9-9
function behavior_script_h.cur_obj_get_int(offset: number): number
	return buffer.readi32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, offset)
end

-- from src/engine/behavior_script.h:cur_obj_get_float L10-10
function behavior_script_h.cur_obj_get_float(offset: number): number
	return buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, offset)
end

-- from src/engine/behavior_script.h:cur_obj_add_float L12-12
function behavior_script_h.cur_obj_add_float(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sum = F32(buffer.readf32(currentObject.rawData, offset) + F32(value))

	buffer.writef32(currentObject.rawData, offset, sum)
	return sum
end

-- from src/engine/behavior_script.h:cur_obj_set_float L13-13
function behavior_script_h.cur_obj_set_float(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const result = F32(value)

	buffer.writef32(currentObject.rawData, offset, result)
	return result
end

-- from src/engine/behavior_script.h:cur_obj_add_int L14-14
function behavior_script_h.cur_obj_add_int(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sum = S32(buffer.readi32(currentObject.rawData, offset) + S32(value))

	buffer.writei32(currentObject.rawData, offset, sum)
	return sum
end

-- from src/engine/behavior_script.h:cur_obj_set_int L15-15
function behavior_script_h.cur_obj_set_int(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const result = S32(value)

	buffer.writei32(currentObject.rawData, offset, result)
	return result
end

-- from src/engine/behavior_script.h:cur_obj_or_int L16-16
function behavior_script_h.cur_obj_or_int(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const result = S32(bit32.bor(buffer.readi32(currentObject.rawData, offset), S32(value)))

	buffer.writei32(currentObject.rawData, offset, result)
	return result
end

-- from src/engine/behavior_script.h:cur_obj_and_int L17-17
function behavior_script_h.cur_obj_and_int(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	const result = S32(bit32.band(buffer.readi32(currentObject.rawData, offset), S32(value)))

	buffer.writei32(currentObject.rawData, offset, result)
	return result
end

-- from src/engine/behavior_script.h:cur_obj_set_vptr L18-18
function behavior_script_h.cur_obj_set_vptr(offset: number, value: number): number
	const currentObject = Registry.Members.src__game__object_list_processor.gCurrentObject
	currentObject.ptrData[offset + 1] = value

	return value
end

-- from src/engine/behavior_script.h:obj_and_int L20-20
function behavior_script_h.obj_and_int(object: unknown, offset: number, value: number): number
	const targetObject = object :: GroupsTypesHPlus3Types.Object
	const result = S32(bit32.band(buffer.readi32(targetObject.rawData, offset), S32(value)))

	buffer.writei32(targetObject.rawData, offset, result)
	return result
end

return behavior_script_h
