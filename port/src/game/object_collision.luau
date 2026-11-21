--!strict
--!optimize 2

--[[
	Port of src/game/object_collision.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const InteractionH = require("./interaction_h")
const ObjectListProcessor = require("./object_list_processor")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const ObjectListProcessorH = require("./object_list_processor_h")

const object_collision = {}

Registry.Register("src__game__object_collision", object_collision)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/object_collision.c:debug_print_obj_collision L10-23
function object_collision.debug_print_obj_collision(a: GroupsTypesHPlus3Types.Object): GroupsTypesHPlus3Types.Object?
	for i = 0, a.numCollidedObjs - 1 do
		-- print_debug_top_down_objectinfo: no call (debug-print-externals)
		const sp24 = a.collidedObjs[i + 1] :: GroupsTypesHPlus3Types.Object

		if sp24 ~= Registry.Members.src__game__object_list_processor.gMarioObject then
			return sp24
		end
	end

	return nil
end

-- from src/game/object_collision.c:detect_object_hitbox_overlap L25-63
function object_collision.detect_object_hitbox_overlap(a: GroupsTypesHPlus3Types.Object, b: GroupsTypesHPlus3Types.Object): number
	const aBottom = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosY) - a.hitboxDownOffset)
	const bBottom = F32(buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosY) - b.hitboxDownOffset)
	const dx = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosZ))
	const collisionRadius = F32(a.hitboxRadius + b.hitboxRadius)
	const distance = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	if collisionRadius > distance then
		const aTop = F32(a.hitboxHeight + aBottom)
		const bTop = F32(b.hitboxHeight + bBottom)

		if aBottom > bTop then
			return 0
		end

		if aTop < bBottom then
			return 0
		end

		if a.numCollidedObjs >= 4 then
			return 0
		end

		if b.numCollidedObjs >= 4 then
			return 0
		end

		a.collidedObjs[a.numCollidedObjs + 1] = b
		b.collidedObjs[b.numCollidedObjs + 1] = a
		a.collidedObjInteractTypes = bit32.bor(a.collidedObjInteractTypes, buffer.readu32(b.rawData, IncludeObjectFieldsH.oInteractType))
		b.collidedObjInteractTypes = bit32.bor(b.collidedObjInteractTypes, buffer.readu32(a.rawData, IncludeObjectFieldsH.oInteractType))
		a.numCollidedObjs = S16(a.numCollidedObjs + 1)
		b.numCollidedObjs = S16(b.numCollidedObjs + 1)

		return 1
	end

	return 0
end

-- from src/game/object_collision.c:detect_object_hurtbox_overlap L65-98
function object_collision.detect_object_hurtbox_overlap(a: GroupsTypesHPlus3Types.Object, b: GroupsTypesHPlus3Types.Object): number
	const aBottom = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosY) - a.hitboxDownOffset)
	const bBottom = F32(buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosY) - b.hitboxDownOffset)
	const dx = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(a.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(b.rawData, IncludeObjectFieldsH.oPosZ))
	const hurtboxRadius = F32(a.hurtboxRadius + b.hurtboxRadius)
	const distance = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	if a == ObjectListProcessor.gMarioObject then
		buffer.writeu32(b.rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.bor(buffer.readu32(b.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY))
	end

	if hurtboxRadius > distance then
		const aTop = F32(a.hitboxHeight + aBottom)
		const bTop = F32(b.hurtboxHeight + bBottom)

		if aBottom > bTop then
			return 0
		end

		if aTop < bBottom then
			return 0
		end

		if a == ObjectListProcessor.gMarioObject then
			buffer.writeu32(b.rawData, IncludeObjectFieldsH.oInteractionSubtype, bit32.band(buffer.readu32(b.rawData, IncludeObjectFieldsH.oInteractionSubtype), bit32.bnot(InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY)))
		end

		return 1
	end

	return 0
end

-- from src/game/object_collision.c:clear_object_collision L100-111
function object_collision.clear_object_collision(a: GroupsTypesHPlus3Types.Object)
	local sp4 = a.ObjectNode_next :: GroupsTypesHPlus3Types.Object

	while sp4 ~= a do
		sp4.numCollidedObjs = 0
		sp4.collidedObjInteractTypes = 0

		if buffer.readi32(sp4.rawData, IncludeObjectFieldsH.oIntangibleTimer) > 0 then
			buffer.writei32(sp4.rawData, IncludeObjectFieldsH.oIntangibleTimer, buffer.readi32(sp4.rawData, IncludeObjectFieldsH.oIntangibleTimer) - 1)
		end

		sp4 = sp4.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object
	end
end

-- from src/game/object_collision.c:check_collision_in_list L113-124
function object_collision.check_collision_in_list(a: GroupsTypesHPlus3Types.Object, b: GroupsTypesHPlus3Types.Object, c: GroupsTypesHPlus3Types.Object)
	if buffer.readi32(a.rawData, IncludeObjectFieldsH.oIntangibleTimer) == 0 then
		while b ~= c do
			if buffer.readi32(b.rawData, IncludeObjectFieldsH.oIntangibleTimer) == 0 then
				if object_collision.detect_object_hitbox_overlap(a, b) ~= 0 and b.hurtboxRadius ~= 0.0 then
					object_collision.detect_object_hurtbox_overlap(a, b)
				end
			end

			b = b.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object
		end
	end
end

-- from src/game/object_collision.c:check_player_object_collision L126-146
function object_collision.check_player_object_collision()
	const sp1C = Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PLAYER + 1] :: GroupsTypesHPlus3Types.Object
	local sp18 = sp1C.ObjectNode_next :: GroupsTypesHPlus3Types.Object

	while sp18 ~= sp1C do
		object_collision.check_collision_in_list(sp18, sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object, sp1C)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_POLELIKE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_POLELIKE + 1] :: GroupsTypesHPlus3Types.Object)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_LEVEL + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_LEVEL + 1] :: GroupsTypesHPlus3Types.Object)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1] :: GroupsTypesHPlus3Types.Object)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1] :: GroupsTypesHPlus3Types.Object)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1] :: GroupsTypesHPlus3Types.Object)
		object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_DESTRUCTIVE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_DESTRUCTIVE + 1] :: GroupsTypesHPlus3Types.Object)

		sp18 = sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object
	end
end

-- from src/game/object_collision.c:check_pushable_object_collision L148-156
function object_collision.check_pushable_object_collision()
	const sp1C = Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1] :: GroupsTypesHPlus3Types.Object
	local sp18 = sp1C.ObjectNode_next :: GroupsTypesHPlus3Types.Object

	while sp18 ~= sp1C do
		object_collision.check_collision_in_list(sp18, sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object, sp1C)

		sp18 = sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object
	end
end

-- from src/game/object_collision.c:check_destructive_object_collision L158-174
function object_collision.check_destructive_object_collision()
	const sp1C = Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_DESTRUCTIVE + 1] :: GroupsTypesHPlus3Types.Object
	local sp18 = sp1C.ObjectNode_next :: GroupsTypesHPlus3Types.Object

	while sp18 ~= sp1C do
		if buffer.readf32(sp18.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 and not bit32.btest(sp18.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK9) then
			object_collision.check_collision_in_list(sp18, sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object, sp1C)
			object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1] :: GroupsTypesHPlus3Types.Object)
			object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1] :: GroupsTypesHPlus3Types.Object)
			object_collision.check_collision_in_list(sp18, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1].ObjectNode_next :: GroupsTypesHPlus3Types.Object, Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1] :: GroupsTypesHPlus3Types.Object)
		end

		sp18 = sp18.header.ObjectNode_next :: GroupsTypesHPlus3Types.Object
	end
end

-- from src/game/object_collision.c:detect_object_collisions L176-187
function object_collision.detect_object_collisions()
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_POLELIKE + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PLAYER + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_PUSHABLE + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_LEVEL + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1] :: GroupsTypesHPlus3Types.Object)
	object_collision.clear_object_collision(Registry.Members.src__game__object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_DESTRUCTIVE + 1] :: GroupsTypesHPlus3Types.Object)

	object_collision.check_player_object_collision()
	object_collision.check_destructive_object_collision()
	object_collision.check_pushable_object_collision()
end

return object_collision
