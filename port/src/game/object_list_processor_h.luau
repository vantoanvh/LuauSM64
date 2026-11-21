--!strict
--!optimize 2

--[[
	Port of src/game/object_list_processor.h.
]]

-- from src/game/object_list_processor.h:NumTimesCalled
export type NumTimesCalled = {
	floor: number,
	ceil: number,
	wall: number,
}

-- from src/game/object_list_processor.h:data
const object_list_processor_h = {
	TIME_STOP_UNKNOWN_0 = 1,
	TIME_STOP_ENABLED = 2,
	TIME_STOP_DIALOG = 4,
	TIME_STOP_MARIO_AND_DOORS = 8,
	TIME_STOP_ALL_OBJECTS = 16,
	TIME_STOP_MARIO_OPENED_DOOR = 32,
	TIME_STOP_ACTIVE = 64,
	OBJECT_POOL_CAPACITY = 240,
	OBJ_LIST_PLAYER = 0,
	OBJ_LIST_UNUSED_1 = 1,
	OBJ_LIST_DESTRUCTIVE = 2,
	OBJ_LIST_UNUSED_3 = 3,
	OBJ_LIST_GENACTOR = 4,
	OBJ_LIST_PUSHABLE = 5,
	OBJ_LIST_LEVEL = 6,
	OBJ_LIST_UNUSED_7 = 7,
	OBJ_LIST_DEFAULT = 8,
	OBJ_LIST_SURFACE = 9,
	OBJ_LIST_POLELIKE = 10,
	OBJ_LIST_SPAWNER = 11,
	OBJ_LIST_UNIMPORTANT = 12,
	NUM_OBJ_LISTS = 13,
}

-- from src/game/object_list_processor.h:NumTimesCalled (zero-filled constructor)
function object_list_processor_h.new_NumTimesCalled(): NumTimesCalled
	return { floor = 0, ceil = 0, wall = 0 } :: NumTimesCalled
end

return object_list_processor_h
