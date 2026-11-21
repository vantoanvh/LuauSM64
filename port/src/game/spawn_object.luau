--!strict
--!optimize 2

--[[
	Port of src/game/spawn_object.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const ObjectListProcessorH = require("./object_list_processor_h")
const Area = require("./area")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../include/level_table_h")
const Rom = require("../rom/rom")
const Audio = require("../rom/audio_recorder")
const SrcEngineMathUtil = require("../engine/math_util")

-- from src/game/spawn_object.c:LinkedList
export type LinkedList = {
	next: LinkedList?,
	prev: LinkedList?,
}

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const spawn_object = {}

Registry.Register("src__game__spawn_object", spawn_object)

-- from src/game/spawn_object.c:LinkedList (zero-filled constructor)
function spawn_object.new_LinkedList(): LinkedList
	return { next = nil, prev = nil } :: LinkedList
end

-- Out pointer of find_floor (&surface in snap_object_to_floor)
const FloorSurface = { nil } :: { GroupsTypesHPlus3Types.Surface? }

-- from src/game/spawn_object.c:unused_init_free_list L29-48
function spawn_object.unused_init_free_list(usedList: LinkedList, pFreeList: { LinkedList? }, pool: LinkedList, itemSize: number, poolLength: number)
	error("unused_init_free_list is UNUSED in the C and not ported (unused-init-free-list-dropped)")
end

-- from src/game/spawn_object.c:unused_try_allocate L56-72
function spawn_object.unused_try_allocate(destList: LinkedList, freeList: LinkedList): LinkedList?
	const node = freeList.next

	if node ~= nil then
		-- Remove from free list
		freeList.next = node.next

		-- Insert at the end of destination list
		node.prev = destList.prev
		node.next = destList

		const prevNode = destList.prev :: LinkedList

		prevNode.next = node
		destList.prev = node
	end

	return node
end

-- from src/game/spawn_object.c:try_allocate_object L79-99
function spawn_object.try_allocate_object(destList: GroupsTypesHPlus3Types.ObjectNode, freeList: GroupsTypesHPlus3Types.ObjectNode): GroupsTypesHPlus3Types.Object?
	if freeList.ObjectNode_next ~= nil then
		const nextObj = freeList.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

		-- Remove from free list
		freeList.ObjectNode_next = nextObj.ObjectNode_next

		-- Insert at end of destination list
		nextObj.ObjectNode_prev = destList.ObjectNode_prev
		nextObj.ObjectNode_next = destList

		const oldTail = destList.ObjectNode_prev :: GroupsTypesHPlus3Types.ObjectNode

		oldTail.ObjectNode_next = nextObj
		destList.ObjectNode_prev = nextObj

		Registry.Members.src__engine__graph_node.geo_remove_child(nextObj.gfx.node)
		Registry.Members.src__engine__graph_node.geo_add_child(Registry.Members.src__engine__geo_layout.gObjParentGraphNode, nextObj.gfx.node)

		return nextObj :: GroupsTypesHPlus3Types.Object
	end

	return nil
end

-- from src/game/spawn_object.c:unused_deallocate L106-114
function spawn_object.unused_deallocate(freeList: LinkedList, node: LinkedList)
	-- Remove from doubly linked list
	const nextNode = node.next :: LinkedList

	nextNode.prev = node.prev

	const prevNode = node.prev :: LinkedList

	prevNode.next = node.next

	-- Insert at beginning of singly linked list
	node.next = freeList.next
	freeList.next = node
end

-- from src/game/spawn_object.c:deallocate_object L119-127
function spawn_object.deallocate_object(freeList: GroupsTypesHPlus3Types.ObjectNode, obj: GroupsTypesHPlus3Types.ObjectNode)
	-- Remove from object list
	const nextNode = obj.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

	nextNode.ObjectNode_prev = obj.ObjectNode_prev

	const prevNode = obj.ObjectNode_prev :: GroupsTypesHPlus3Types.ObjectNode

	prevNode.ObjectNode_next = obj.ObjectNode_next

	-- Insert at beginning of free list
	obj.ObjectNode_next = freeList.ObjectNode_next
	freeList.ObjectNode_next = obj
end

-- from src/game/spawn_object.c:init_free_object_list L132-148
function spawn_object.init_free_object_list()
	const poolLength = ObjectListProcessorH.OBJECT_POOL_CAPACITY
	local obj = 1

	-- Add the first object in the pool to the free list
	Registry.Members.src__game__object_list_processor.gFreeObjectList.ObjectNode_next = Registry.Members.src__game__object_list_processor.gObjectPool[obj].header

	-- Link each object in the pool to the following object
	for i = 0, poolLength - 2 do
		Registry.Members.src__game__object_list_processor.gObjectPool[obj].header.ObjectNode_next = Registry.Members.src__game__object_list_processor.gObjectPool[obj + 1].header
		obj += 1
	end

	-- End the list
	Registry.Members.src__game__object_list_processor.gObjectPool[obj].header.ObjectNode_next = nil
end

-- from src/game/spawn_object.c:clear_object_lists L153-160
function spawn_object.clear_object_lists(objLists: { GroupsTypesHPlus3Types.ObjectNode })
	for i = 0, ObjectListProcessorH.NUM_OBJ_LISTS - 1 do
		objLists[i + 1].ObjectNode_next = objLists[i + 1]
		objLists[i + 1].ObjectNode_prev = objLists[i + 1]
	end
end

-- from src/game/spawn_object.c:unused_delete_leaf_nodes L166-183
function spawn_object.unused_delete_leaf_nodes(obj: GroupsTypesHPlus3Types.Object)
	const obj0 = obj
	const children = obj.header.gfx.node.children :: GroupsTypesHPlus3Types.Object?

	if children ~= nil then
		spawn_object.unused_delete_leaf_nodes(children)
	else
		-- No children
		spawn_object.mark_obj_for_deletion(obj)
	end

	-- Probably meant to be !=
	local sibling = obj.header.gfx.node.next :: GroupsTypesHPlus3Types.Object?

	while sibling == obj0 do
		spawn_object.unused_delete_leaf_nodes(sibling :: GroupsTypesHPlus3Types.Object)
		obj = (sibling :: GroupsTypesHPlus3Types.Object).header.gfx.node.next :: GroupsTypesHPlus3Types.Object
		sibling = obj.header.gfx.node.next :: GroupsTypesHPlus3Types.Object?
	end
end

-- from src/game/spawn_object.c:unload_object L188-201
function spawn_object.unload_object(obj: GroupsTypesHPlus3Types.Object)
	obj.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	obj.prevObj = nil
	obj.header.gfx.throwMatrix = nil

	Audio.stop_sounds_from_source(obj.header.gfx.cameraToObject)
	Registry.Members.src__engine__graph_node.geo_remove_child(obj.header.gfx.node)
	Registry.Members.src__engine__graph_node.geo_add_child(Registry.Members.src__engine__geo_layout.gObjParentGraphNode, obj.header.gfx.node)
	obj.header.gfx.node.flags = S16(bit32.band(obj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD)))
	obj.header.gfx.node.flags = S16(bit32.band(obj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

	spawn_object.deallocate_object(Registry.Members.src__game__object_list_processor.gFreeObjectList, obj.header)
end

-- from src/game/spawn_object.c:allocate_object L208-294
function spawn_object.allocate_object(objList: GroupsTypesHPlus3Types.ObjectNode): GroupsTypesHPlus3Types.Object?
	local obj = spawn_object.try_allocate_object(objList, Registry.Members.src__game__object_list_processor.gFreeObjectList)

	-- The object list is full if the newly created pointer is NULL.
	-- If this happens, we first attempt to unload unimportant objects
	-- in order to finish allocating the object.
	if obj == nil then
		-- Look for an unimportant object to kick out.
		const unimportantObj = Registry.Members.src__game__object_helpers.find_unimportant_object()

		-- If no unimportant object exists, then the object pool is exhausted.
		if unimportantObj == nil then
			-- We've met with a terrible fate.
			while true do
			end
		else
			-- If an unimportant object does exist, unload it and take its slot.
			spawn_object.unload_object(unimportantObj)
			obj = spawn_object.try_allocate_object(objList, Registry.Members.src__game__object_list_processor.gFreeObjectList)

			if Registry.Members.src__game__object_list_processor.gCurrentObject == obj then
				--! Uh oh, the unimportant object was in the middle of
				--  updating! This could cause some interesting logic errors,
				--  but I don't know of any unimportant objects that spawn
				--  other objects.
			end
		end
	end

	const newObj = obj :: GroupsTypesHPlus3Types.Object

	-- Initialize object fields
	newObj.activeFlags = S16(bit32.bor(IncludeObjectConstantsH.ACTIVE_FLAG_ACTIVE, IncludeObjectConstantsH.ACTIVE_FLAG_UNK8))
	newObj.parentObj = newObj
	newObj.prevObj = nil
	newObj.collidedObjInteractTypes = 0
	newObj.numCollidedObjs = 0

	for i = 0, 0x50 - 1 do
		buffer.writei32(newObj.rawData, i * 4, 0)
		newObj.ptrData[i + 1] = nil
	end

	newObj.unused1 = 0
	newObj.bhvStackIndex = 0
	newObj.bhvDelayTimer = 0
	newObj.hitboxRadius = 50.0
	newObj.hitboxHeight = 100.0
	newObj.hurtboxRadius = 0.0
	newObj.hurtboxHeight = 0.0
	newObj.hitboxDownOffset = 0.0
	newObj.unused2 = 0
	newObj.platform = nil
	newObj.collisionData = nil

	buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
	buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 0)
	buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oHealth, 2048)
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oCollisionDistance, 1000.0)

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_TTC then
		buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oDrawingDistance, 2000.0)
	else
		buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oDrawingDistance, 4000.0)
	end

	SrcEngineMathUtil.mtxf_identity(newObj.transform)
	newObj.respawnInfoType = IncludeObjectConstantsH.RESPAWN_INFO_TYPE_NULL
	newObj.respawnInfo = nil
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oDistanceToMario, 19000.0)
	buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oRoom, -1)
	newObj.header.gfx.node.flags = S16(bit32.band(newObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	newObj.header.gfx.pos[1] = -10000.0
	newObj.header.gfx.pos[2] = -10000.0
	newObj.header.gfx.pos[3] = -10000.0
	newObj.header.gfx.throwMatrix = nil

	return newObj
end

-- from src/game/spawn_object.c:snap_object_to_floor L299-308
function spawn_object.snap_object_to_floor(obj: GroupsTypesHPlus3Types.Object)
	const foundFloorHeight = Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ), FloorSurface)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oFloorHeight, foundFloorHeight)

	const floorHeight = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oFloorHeight)

	if F32(floorHeight + 2) > buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) > F32(floorHeight - 10) then
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, floorHeight)
		buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND))
	end
end

-- from src/game/spawn_object.c:create_object L313-353
function spawn_object.create_object(bhvScript: number): GroupsTypesHPlus3Types.Object
	const bhvWord = Rom.ReadU32(bhvScript)
	local objListIndex: number

	-- If the first behavior script command is "begin <object list>", then
	-- extract the object list from it
	if bit32.rshift(bhvWord, 24) == 0 then
		objListIndex = bit32.band(bit32.rshift(bhvWord, 16), 0xFFFF)
	else
		objListIndex = ObjectListProcessorH.OBJ_LIST_DEFAULT
	end

	const objList = Registry.Members.src__game__object_list_processor.gObjectLists[objListIndex + 1]
	const obj = spawn_object.allocate_object(objList) :: GroupsTypesHPlus3Types.Object

	obj.curBhvCommand = bhvScript
	obj.behavior = bhvScript

	if objListIndex == ObjectListProcessorH.OBJ_LIST_UNIMPORTANT then
		obj.activeFlags = S16(bit32.bor(obj.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNIMPORTANT))
	end

	--! They intended to snap certain objects to the floor when they spawn.
	--  However, at this point the object's position is the origin. So this will
	--  place the object at the floor beneath the origin. Typically this
	--  doesn't matter since the caller of this function sets oPosX/Y/Z
	--  themselves.
	if objListIndex == ObjectListProcessorH.OBJ_LIST_GENACTOR then
		spawn_object.snap_object_to_floor(obj)
	elseif objListIndex == ObjectListProcessorH.OBJ_LIST_PUSHABLE then
		spawn_object.snap_object_to_floor(obj)
	elseif objListIndex == ObjectListProcessorH.OBJ_LIST_POLELIKE then
		spawn_object.snap_object_to_floor(obj)
	end

	return obj
end

-- from src/game/spawn_object.c:mark_obj_for_deletion L358-361
function spawn_object.mark_obj_for_deletion(obj: GroupsTypesHPlus3Types.Object)
	obj.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

return spawn_object
