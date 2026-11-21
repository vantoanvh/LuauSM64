--!strict
--!optimize 2

--[[
	Port of src/game/object_helpers.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeLevelTableH = require("../../include/level_table_h")

const ObjectHelpersH = require("./object_helpers_h")
const ObjectListProcessor = require("./object_list_processor")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const SrcEngineMathUtil = require("../engine/math_util")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Memory = require("./memory")
const ObjectListProcessorH = require("./object_list_processor_h")
const Area = require("./area")
const Rom = require("../rom/rom")
const Gbi = require("../rom/gbi")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const InteractionH = require("./interaction_h")
const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")
const LevelUpdate = require("./level_update")
const SrcEngineGraphNode = require("../engine/graph_node")
const IncludeSm64H = require("../../include/sm64_h")
const BehaviorIds = require("../rom/behavior_ids")
const SpawnObject = require("./spawn_object")
const BehaviorActions = require("./behavior_actions")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const MarioActionsCutscene = require("./mario_actions_cutscene")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const BehaviorsBreakParticlesInc = require("./behaviors/break_particles_inc")
const IncludeModelIdsH = require("../../include/model_ids_h")

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/object_helpers.luau:scratch
const Scratch = {
	cur_obj_dist_to_nearest_object_with_behavior_dist = { 0 },
	cur_obj_update_floor_height_and_get_floor_floor = { nil } :: { GroupsTypesHPlus3.Surface? },
	cur_obj_align_gfx_with_floor_floor = { nil } :: { GroupsTypesHPlus3.Surface? },
	cur_obj_align_gfx_with_floor_floorNormal = { 0, 0, 0 },
	cur_obj_align_gfx_with_floor_position = { 0, 0, 0 },
	cur_obj_unused_resolve_wall_collisions_posX = { 0 },
	cur_obj_unused_resolve_wall_collisions_posY = { 0 },
	cur_obj_unused_resolve_wall_collisions_posZ = { 0 },
	obj_spawn_loot_coins_floor = { nil } :: { GroupsTypesHPlus3.Surface? },
	bhv_init_room_floor = { nil } :: { GroupsTypesHPlus3.Surface? },
	cur_obj_nearest_object_with_behavior_dist = { 0 },
}
-- from src/game/object_helpers.luau:scratch
local grabReleaseState = 0

-- from src/game/object_helpers.c:data
const object_helpers = {
	-- from src/game/object_helpers.c:sBBHStairJiggleOffsets L30-30
	sBBHStairJiggleOffsets = { -8, 8, -4, 4 },
	-- from src/game/object_helpers.c:sPowersOfTwo L31-31
	sPowersOfTwo = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 },
	-- from src/game/object_helpers.c:sLevelsWithRooms L32-32
	sLevelsWithRooms = { IncludeLevelTableH.LEVEL_BBH, IncludeLevelTableH.LEVEL_CASTLE, IncludeLevelTableH.LEVEL_HMC, -1 },
	o = ObjectListProcessor.gCurrentObject,
}

Registry.Register("src__game__object_helpers", object_helpers)

-- from src/game/object_helpers.c:geo_update_projectile_pos_from_parent L38-50
function object_helpers.geo_update_projectile_pos_from_parent(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const sp20 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }
		const obj = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const prevObj = obj.prevObj

		if prevObj ~= nil then
			object_helpers.create_transformation_from_matrices(sp20, mtx, (Registry.Members.src__game__rendering_graph_node.gCurGraphNodeCamera.matrixPtr :: { { { number } } })[1])
			object_helpers.obj_update_pos_from_parent_transformation(sp20, prevObj)
			object_helpers.obj_set_gfx_pos_from_pos(prevObj)
		end
	end

	return nil
end

-- from src/game/object_helpers.c:geo_update_layer_transparency L52-126
function object_helpers.geo_update_layer_transparency(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	local dlStart: number? = nil
	local objectGraphNode: GroupsTypesHPlus3.Object = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
	const currentGraphNode: GroupsTypesHPlus3.GraphNodeGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const heldObject: GroupsTypesHPlus3.GraphNodeHeldObject? = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeHeldObject

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if heldObject ~= nil then
			objectGraphNode = heldObject.objNode :: GroupsTypesHPlus3.Object
		end

		const objectOpacity = buffer.readi32(objectGraphNode.rawData, IncludeObjectFieldsH.oOpacity)
		dlStart = Gbi.alloc_display_list(3 * 8)

		const outer = Gbi.Redirect(dlStart)

		if objectOpacity == 0xFF then
			if currentGraphNode.parameter == 20 then
				currentGraphNode.fnNode.node.flags = S16(bit32.bor(0x600, bit32.band(currentGraphNode.fnNode.node.flags, 0xFF)))
			else
				currentGraphNode.fnNode.node.flags = S16(bit32.bor(0x100, bit32.band(currentGraphNode.fnNode.node.flags, 0xFF)))
			end

			buffer.writei32(objectGraphNode.rawData, IncludeObjectFieldsH.oAnimState, 0)
		else
			if currentGraphNode.parameter == 20 then
				currentGraphNode.fnNode.node.flags = S16(bit32.bor(0x600, bit32.band(currentGraphNode.fnNode.node.flags, 0xFF)))
			else
				currentGraphNode.fnNode.node.flags = S16(bit32.bor(0x500, bit32.band(currentGraphNode.fnNode.node.flags, 0xFF)))
			end

			buffer.writei32(objectGraphNode.rawData, IncludeObjectFieldsH.oAnimState, 1)

			if objectOpacity == 0 and Memory.segmented_to_virtual(BehaviorIds.bhvBowser) == objectGraphNode.behavior then
				buffer.writei32(objectGraphNode.rawData, IncludeObjectFieldsH.oAnimState, 2)
			end

			if currentGraphNode.parameter ~= 10 then
				if bit32.btest(objectGraphNode.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_DITHERED_ALPHA) then
					Gbi.gDPSetAlphaCompare(Gbi.G_AC_DITHER)
				end
			end
		end

		Gbi.gDPSetEnvColor(255, 255, 255, objectOpacity)
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)
	end

	return dlStart
end

-- from src/game/object_helpers.c:geo_switch_anim_state L136-166
function object_helpers.geo_switch_anim_state(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		local obj = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
		const heldObject = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeHeldObject

		if heldObject ~= nil then
			obj = heldObject.objNode :: GroupsTypesHPlus3.Object
		end

		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAnimState) >= switchCase.numCases then
			buffer.writei32(obj.rawData, IncludeObjectFieldsH.oAnimState, 0)
		end

		switchCase.selectedCase = S16(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAnimState))
	end

	return nil
end

-- from src/game/object_helpers.c:geo_switch_area L170-204
function object_helpers.geo_switch_area(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): { unknown }?
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const marioObject = ObjectListProcessor.gMarioObject

		if marioObject == nil then
			switchCase.selectedCase = 0
		else
			ObjectListProcessor.gFindFloorIncludeSurfaceIntangible = IncludePRUltratypesH.TRUE

			const floorOut = { nil } :: { GroupsTypesHPlus3.Surface? }

			Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ), floorOut)

			const floor = floorOut[1]

			if floor ~= nil then
				ObjectListProcessor.gMarioCurrentRoom = floor.room

				const sp26 = S16(floor.room - 1)

				if sp26 >= 0 then
					switchCase.selectedCase = sp26
				end
			end
		end
	else
		switchCase.selectedCase = 0
	end

	return nil
end

-- from src/game/object_helpers.c:obj_update_pos_from_parent_transformation L206-214
function object_helpers.obj_update_pos_from_parent_transformation(a0: { { number } }, a1: GroupsTypesHPlus3.Object)
	const spC = buffer.readf32(a1.rawData, IncludeObjectFieldsH.oParentRelativePosX)
	const sp8 = buffer.readf32(a1.rawData, IncludeObjectFieldsH.oParentRelativePosY)
	const sp4 = buffer.readf32(a1.rawData, IncludeObjectFieldsH.oParentRelativePosZ)

	buffer.writef32(a1.rawData, IncludeObjectFieldsH.oPosX, F32(F32(F32(F32(spC * a0[1][1]) + F32(sp8 * a0[2][1])) + F32(sp4 * a0[3][1])) + a0[4][1]))
	buffer.writef32(a1.rawData, IncludeObjectFieldsH.oPosY, F32(F32(F32(F32(spC * a0[1][2]) + F32(sp8 * a0[2][2])) + F32(sp4 * a0[3][2])) + a0[4][2]))
	buffer.writef32(a1.rawData, IncludeObjectFieldsH.oPosZ, F32(F32(F32(F32(spC * a0[1][3]) + F32(sp8 * a0[2][3])) + F32(sp4 * a0[3][3])) + a0[4][3]))
end

-- from src/game/object_helpers.c:obj_apply_scale_to_matrix L216-236
function object_helpers.obj_apply_scale_to_matrix(obj: GroupsTypesHPlus3.Object, dst: { { number } }, src: { { number } })
	const scaleX = obj.header.gfx.scale[1]
	const scaleY = obj.header.gfx.scale[2]
	const scaleZ = obj.header.gfx.scale[3]

	dst[1][1] = F32(src[1][1] * scaleX)
	dst[2][1] = F32(src[2][1] * scaleY)
	dst[3][1] = F32(src[3][1] * scaleZ)
	dst[4][1] = src[4][1]

	dst[1][2] = F32(src[1][2] * scaleX)
	dst[2][2] = F32(src[2][2] * scaleY)
	dst[3][2] = F32(src[3][2] * scaleZ)
	dst[4][2] = src[4][2]

	dst[1][3] = F32(src[1][3] * scaleX)
	dst[2][3] = F32(src[2][3] * scaleY)
	dst[3][3] = F32(src[3][3] * scaleZ)
	dst[4][3] = src[4][3]

	dst[1][4] = src[1][4]
	dst[2][4] = src[2][4]
	dst[3][4] = src[3][4]
	dst[4][4] = src[4][4]
end

-- from src/game/object_helpers.c:create_transformation_from_matrices L238-265
function object_helpers.create_transformation_from_matrices(a0: { { number } }, a1: { { number } }, a2: { { number } })
	const spC = F32(F32(F32(a2[4][1] * a2[1][1]) + F32(a2[4][2] * a2[1][2])) + F32(a2[4][3] * a2[1][3]))
	const sp8 = F32(F32(F32(a2[4][1] * a2[2][1]) + F32(a2[4][2] * a2[2][2])) + F32(a2[4][3] * a2[2][3]))
	const sp4 = F32(F32(F32(a2[4][1] * a2[3][1]) + F32(a2[4][2] * a2[3][2])) + F32(a2[4][3] * a2[3][3]))

	a0[1][1] = F32(F32(F32(a1[1][1] * a2[1][1]) + F32(a1[1][2] * a2[1][2])) + F32(a1[1][3] * a2[1][3]))
	a0[1][2] = F32(F32(F32(a1[1][1] * a2[2][1]) + F32(a1[1][2] * a2[2][2])) + F32(a1[1][3] * a2[2][3]))
	a0[1][3] = F32(F32(F32(a1[1][1] * a2[3][1]) + F32(a1[1][2] * a2[3][2])) + F32(a1[1][3] * a2[3][3]))

	a0[2][1] = F32(F32(F32(a1[2][1] * a2[1][1]) + F32(a1[2][2] * a2[1][2])) + F32(a1[2][3] * a2[1][3]))
	a0[2][2] = F32(F32(F32(a1[2][1] * a2[2][1]) + F32(a1[2][2] * a2[2][2])) + F32(a1[2][3] * a2[2][3]))
	a0[2][3] = F32(F32(F32(a1[2][1] * a2[3][1]) + F32(a1[2][2] * a2[3][2])) + F32(a1[2][3] * a2[3][3]))

	a0[3][1] = F32(F32(F32(a1[3][1] * a2[1][1]) + F32(a1[3][2] * a2[1][2])) + F32(a1[3][3] * a2[1][3]))
	a0[3][2] = F32(F32(F32(a1[3][1] * a2[2][1]) + F32(a1[3][2] * a2[2][2])) + F32(a1[3][3] * a2[2][3]))
	a0[3][3] = F32(F32(F32(a1[3][1] * a2[3][1]) + F32(a1[3][2] * a2[3][2])) + F32(a1[3][3] * a2[3][3]))

	a0[4][1] = F32(F32(F32(F32(a1[4][1] * a2[1][1]) + F32(a1[4][2] * a2[1][2])) + F32(a1[4][3] * a2[1][3])) - spC)
	a0[4][2] = F32(F32(F32(F32(a1[4][1] * a2[2][1]) + F32(a1[4][2] * a2[2][2])) + F32(a1[4][3] * a2[2][3])) - sp8)
	a0[4][3] = F32(F32(F32(F32(a1[4][1] * a2[3][1]) + F32(a1[4][2] * a2[3][2])) + F32(a1[4][3] * a2[3][3])) - sp4)

	a0[1][4] = 0
	a0[2][4] = 0
	a0[3][4] = 0
	a0[4][4] = 1
end

-- from src/game/object_helpers.c:obj_set_held_state L267-286
function object_helpers.obj_set_held_state(obj: GroupsTypesHPlus3.Object, heldBehavior: number)
	obj.parentObj = ObjectListProcessor.gCurrentObject

	if bit32.btest(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_HOLDABLE) then
		if heldBehavior == BehaviorIds.bhvCarrySomething3 then
			buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_HELD)
		end

		if heldBehavior == BehaviorIds.bhvCarrySomething5 then
			buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_THROWN)
		end

		if heldBehavior == BehaviorIds.bhvCarrySomething4 then
			buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_DROPPED)
		end
	else
		obj.curBhvCommand = Memory.segmented_to_virtual(heldBehavior)
		obj.bhvStackIndex = 0
	end
end

-- from src/game/object_helpers.c:lateral_dist_between_objects L288-293
function object_helpers.lateral_dist_between_objects(obj1: GroupsTypesHPlus3.Object, obj2: GroupsTypesHPlus3.Object): number
	const dx = F32(buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosZ))

	return F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))
end

-- from src/game/object_helpers.c:dist_between_objects L295-301
function object_helpers.dist_between_objects(obj1: GroupsTypesHPlus3.Object, obj2: GroupsTypesHPlus3.Object): number
	const dx = F32(buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosX))
	const dy = F32(buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosY))
	const dz = F32(buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosZ))

	return F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))
end

-- from src/game/object_helpers.c:cur_obj_forward_vel_approach_upward L303-309
function object_helpers.cur_obj_forward_vel_approach_upward(target: number, increment: number)
	target = F32(target)
	increment = F32(increment)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) >= target then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, target)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) + increment)
	end
end

-- from src/game/object_helpers.c:approach_f32_signed L311-329
function object_helpers.approach_f32_signed(Buffer: buffer, Offset: number, target: number, increment: number): number
	target = F32(target)
	increment = F32(increment)
	local reachedTarget = IncludePRUltratypesH.FALSE

	buffer.writef32(Buffer, Offset, buffer.readf32(Buffer, Offset) + increment)

	if increment >= 0 then
		if buffer.readf32(Buffer, Offset) > target then
			buffer.writef32(Buffer, Offset, target)
			reachedTarget = IncludePRUltratypesH.TRUE
		end
	else
		if buffer.readf32(Buffer, Offset) < target then
			buffer.writef32(Buffer, Offset, target)
			reachedTarget = IncludePRUltratypesH.TRUE
		end
	end

	return reachedTarget
end

-- from src/game/object_helpers.c:approach_f32_symmetric L331-349
function object_helpers.approach_f32_symmetric(value: number, target: number, increment: number): number
	value = F32(value)
	target = F32(target)
	increment = F32(increment)
	const dist = F32(target - value)

	if dist >= 0 then
		if dist > increment then
			value = F32(value + increment)
		else
			value = target
		end
	else
		if dist < -increment then
			value = F32(value - increment)
		else
			value = target
		end
	end

	return value
end

-- from src/game/object_helpers.c:approach_s16_symmetric L351-369
function object_helpers.approach_s16_symmetric(value: number, target: number, increment: number): number
	value = S16(TruncS32(value))
	target = S16(TruncS32(target))
	increment = S16(TruncS32(increment))
	const dist = S16(target - value)

	if dist >= 0 then
		if dist > increment then
			value = S16(value + increment)
		else
			value = target
		end
	else
		if dist < -increment then
			value = S16(value - increment)
		else
			value = target
		end
	end

	return value
end

-- from src/game/object_helpers.c:cur_obj_rotate_yaw_toward L371-382
function object_helpers.cur_obj_rotate_yaw_toward(target: number, increment: number): number
	target = S16(TruncS32(target))
	increment = S16(TruncS32(increment))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const startYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, object_helpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), target, increment))

	const angleVelYaw = S16(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) - startYaw)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, angleVelYaw)

	if angleVelYaw == 0 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:obj_angle_to_object L384-393
function object_helpers.obj_angle_to_object(obj1: GroupsTypesHPlus3.Object, obj2: GroupsTypesHPlus3.Object): number
	const z1 = buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosZ)
	const z2 = buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosZ)
	const x1 = buffer.readf32(obj1.rawData, IncludeObjectFieldsH.oPosX)
	const x2 = buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosX)

	return SrcEngineMathUtil.atan2s(F32(z2 - z1), F32(x2 - x1))
end

-- from src/game/object_helpers.c:obj_turn_toward_object L395-427
function object_helpers.obj_turn_toward_object(obj: GroupsTypesHPlus3.Object, target: GroupsTypesHPlus3.Object, angleIndex: number, turnAmount: number): number
	angleIndex = S16(TruncS32(angleIndex))
	turnAmount = S16(TruncS32(turnAmount))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local a: number
	local b: number
	local c: number
	local d: number
	local targetAngle = 0

	if angleIndex == IncludeObjectFieldsH.O_MOVE_ANGLE_PITCH_INDEX or angleIndex == IncludeObjectFieldsH.O_FACE_ANGLE_PITCH_INDEX then
		a = F32(buffer.readf32(target.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX))
		c = F32(buffer.readf32(target.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ))
		a = F32(math.sqrt(F32(F32(a * a) + F32(c * c))))

		b = -buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
		d = -buffer.readf32(target.rawData, IncludeObjectFieldsH.oPosY)

		targetAngle = SrcEngineMathUtil.atan2s(a, F32(d - b))
	elseif angleIndex == IncludeObjectFieldsH.O_MOVE_ANGLE_YAW_INDEX or angleIndex == IncludeObjectFieldsH.O_FACE_ANGLE_YAW_INDEX then
		a = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)
		c = buffer.readf32(target.rawData, IncludeObjectFieldsH.oPosZ)
		b = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
		d = buffer.readf32(target.rawData, IncludeObjectFieldsH.oPosX)

		targetAngle = SrcEngineMathUtil.atan2s(F32(c - a), F32(d - b))
	end

	const startAngle = S16(buffer.readu32(o.rawData, angleIndex * 4))

	buffer.writeu32(o.rawData, angleIndex * 4, U32(object_helpers.approach_s16_symmetric(startAngle, targetAngle, turnAmount)))

	return targetAngle
end

-- from src/game/object_helpers.c:obj_set_parent_relative_pos L429-433
function object_helpers.obj_set_parent_relative_pos(obj: GroupsTypesHPlus3.Object, relX: number, relY: number, relZ: number)
	relX = S16(TruncS32(relX))
	relY = S16(TruncS32(relY))
	relZ = S16(TruncS32(relZ))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oParentRelativePosX, relX)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oParentRelativePosY, relY)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oParentRelativePosZ, relZ)
end

-- from src/game/object_helpers.c:obj_set_pos L435-439
function object_helpers.obj_set_pos(obj: GroupsTypesHPlus3.Object, x: number, y: number, z: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, x)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, y)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, z)
end

-- from src/game/object_helpers.c:obj_set_angle L441-449
function object_helpers.obj_set_angle(obj: GroupsTypesHPlus3.Object, pitch: number, yaw: number, roll: number)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	roll = S16(TruncS32(roll))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAnglePitch, pitch)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAngleYaw, yaw)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAngleRoll, roll)

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAnglePitch, pitch)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, yaw)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleRoll, roll)
end

-- from src/game/object_helpers.c:spawn_object_abs_with_rot L454-463
function object_helpers.spawn_object_abs_with_rot(parent: GroupsTypesHPlus3.Object, uselessArg: number, model: number, behavior: number, x: number, y: number, z: number, pitch: number, yaw: number, roll: number): GroupsTypesHPlus3.Object
	uselessArg = S16(TruncS32(uselessArg))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	roll = S16(TruncS32(roll))
	const newObj = object_helpers.spawn_object_at_origin(parent, uselessArg, model, behavior)

	object_helpers.obj_set_pos(newObj, x, y, z)
	object_helpers.obj_set_angle(newObj, pitch, yaw, roll)

	return newObj
end

-- from src/game/object_helpers.c:spawn_object_rel_with_rot L470-478
function object_helpers.spawn_object_rel_with_rot(parent: GroupsTypesHPlus3.Object, model: number, behavior: number, xOff: number, yOff: number, zOff: number, pitch: number, yaw: number, roll: number): GroupsTypesHPlus3.Object
	xOff = S16(TruncS32(xOff))
	yOff = S16(TruncS32(yOff))
	zOff = S16(TruncS32(zOff))
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	roll = S16(TruncS32(roll))
	const newObj = object_helpers.spawn_object_at_origin(parent, 0, model, behavior)

	buffer.writeu32(newObj.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(newObj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_TRANSFORM_RELATIVE_TO_PARENT))
	object_helpers.obj_set_parent_relative_pos(newObj, xOff, yOff, zOff)
	object_helpers.obj_set_angle(newObj, pitch, yaw, zOff)

	return newObj
end

-- from src/game/object_helpers.c:spawn_obj_with_transform_flags L480-484
function object_helpers.spawn_obj_with_transform_flags(sp20: GroupsTypesHPlus3.Object, model: number, sp28: number): GroupsTypesHPlus3.Object
	const sp1C = object_helpers.spawn_object(sp20, model, sp28)

	buffer.writeu32(sp1C.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(sp1C.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_0020, IncludeObjectConstantsH.OBJ_FLAG_SET_THROW_MATRIX_FROM_TRANSFORM))

	return sp1C
end

-- from src/game/object_helpers.c:spawn_water_droplet L486-523
function object_helpers.spawn_water_droplet(parent: GroupsTypesHPlus3.Object, params: ObjectHelpersH.WaterDropletParams): GroupsTypesHPlus3.Object
	const newObj = object_helpers.spawn_object(parent, params.model, params.behavior :: number)

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE) then
		buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
	end

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE_INCR_PLUS_8000) then
		buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(S16(buffer.readi32(newObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000) + S16(TruncS32(object_helpers.random_f32_around_zero(params.moveAngleRange)))))
	end

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_ANGLE_INCR) then
		buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(S16(buffer.readi32(newObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) + S16(TruncS32(object_helpers.random_f32_around_zero(params.moveAngleRange)))))
	end

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_SET_Y_TO_WATER_LEVEL) then
		const waterLevel = Registry.Members.src__engine__surface_collision.find_water_level(buffer.readf32(newObj.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(newObj.rawData, IncludeObjectFieldsH.oPosZ))

		buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oPosY, waterLevel)
	end

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_OFFSET_XZ) then
		object_helpers.obj_translate_xz_random(newObj, params.moveRange)
	end

	if bit32.btest(params.flags, ObjectHelpersH.WATER_DROPLET_FLAG_RAND_OFFSET_XYZ) then
		object_helpers.obj_translate_xyz_random(newObj, params.moveRange)
	end

	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * params.randForwardVelScale) + params.randForwardVelOffset)
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * params.randYVelScale) + params.randYVelOffset)

	const randomScale = F32(F32(SrcEngineBehaviorScript.random_float() * params.randSizeScale) + params.randSizeOffset)

	object_helpers.obj_scale(newObj, randomScale)

	return newObj
end

-- from src/game/object_helpers.c:spawn_object_at_origin L525-541
function object_helpers.spawn_object_at_origin(parent: GroupsTypesHPlus3.Object, unusedArg: number, model: number, behavior: number): GroupsTypesHPlus3.Object
	const behaviorAddr = Memory.segmented_to_virtual(behavior)
	const obj = SpawnObject.create_object(behaviorAddr)

	obj.parentObj = parent
	obj.header.gfx.areaIndex = parent.header.gfx.areaIndex
	obj.header.gfx.activeAreaIndex = parent.header.gfx.areaIndex

	SrcEngineGraphNode.geo_obj_init(obj.header.gfx, Area.gLoadedGraphNodes[model + 1], SrcEngineGraphNode.gVec3fZero, SrcEngineGraphNode.gVec3sZero)

	return obj
end

-- from src/game/object_helpers.c:spawn_object L543-549
function object_helpers.spawn_object(parent: GroupsTypesHPlus3.Object, model: number, behavior: number): GroupsTypesHPlus3.Object
	const obj = object_helpers.spawn_object_at_origin(parent, 0, model, behavior)

	object_helpers.obj_copy_pos_and_angle(obj, parent)

	return obj
end

-- from src/game/object_helpers.c:try_to_spawn_object L551-563
function object_helpers.try_to_spawn_object(offsetY: number, scale: number, parent: GroupsTypesHPlus3.Object, model: number, behavior: number): GroupsTypesHPlus3.Object?
	offsetY = S16(TruncS32(offsetY))
	scale = F32(scale)
	if ObjectListProcessor.gFreeObjectList.ObjectNode_next ~= nil then
		const obj = object_helpers.spawn_object(parent, model, behavior)

		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + offsetY)
		object_helpers.obj_scale(obj, scale)

		return obj
	else
		return nil
	end
end

-- from src/game/object_helpers.c:spawn_object_with_scale L565-572
function object_helpers.spawn_object_with_scale(parent: GroupsTypesHPlus3.Object, model: number, behavior: number, scale: number): GroupsTypesHPlus3.Object
	scale = F32(scale)
	const obj = object_helpers.spawn_object_at_origin(parent, 0, model, behavior)

	object_helpers.obj_copy_pos_and_angle(obj, parent)
	object_helpers.obj_scale(obj, scale)

	return obj
end

-- from src/game/object_helpers.c:obj_build_relative_transform L574-577
function object_helpers.obj_build_relative_transform(obj: GroupsTypesHPlus3.Object)
	object_helpers.obj_build_transform_from_pos_and_angle(obj, IncludeObjectFieldsH.O_PARENT_RELATIVE_POS_INDEX, IncludeObjectFieldsH.O_FACE_ANGLE_INDEX)
	object_helpers.obj_translate_local(obj, IncludeObjectFieldsH.O_POS_INDEX, IncludeObjectFieldsH.O_PARENT_RELATIVE_POS_INDEX)
end

-- from src/game/object_helpers.c:spawn_object_relative L579-591
function object_helpers.spawn_object_relative(behaviorParam: number, relativePosX: number, relativePosY: number, relativePosZ: number, parent: GroupsTypesHPlus3.Object, model: number, behavior: number): GroupsTypesHPlus3.Object
	behaviorParam = S16(TruncS32(behaviorParam))
	relativePosX = S16(TruncS32(relativePosX))
	relativePosY = S16(TruncS32(relativePosY))
	relativePosZ = S16(TruncS32(relativePosZ))
	const obj = object_helpers.spawn_object_at_origin(parent, 0, model, behavior)

	object_helpers.obj_copy_pos_and_angle(obj, parent)
	object_helpers.obj_set_parent_relative_pos(obj, relativePosX, relativePosY, relativePosZ)
	object_helpers.obj_build_relative_transform(obj)

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, behaviorParam)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.lshift(bit32.band(behaviorParam, 0xFF), 16)))

	return obj
end

-- from src/game/object_helpers.c:spawn_object_relative_with_scale L593-601
function object_helpers.spawn_object_relative_with_scale(behaviorParam: number, relativePosX: number, relativePosY: number, relativePosZ: number, scale: number, parent: GroupsTypesHPlus3.Object, model: number, behavior: number): GroupsTypesHPlus3.Object
	behaviorParam = S16(TruncS32(behaviorParam))
	relativePosX = S16(TruncS32(relativePosX))
	relativePosY = S16(TruncS32(relativePosY))
	relativePosZ = S16(TruncS32(relativePosZ))
	scale = F32(scale)
	const obj = object_helpers.spawn_object_relative(behaviorParam, relativePosX, relativePosY, relativePosZ, parent, model, behavior)

	object_helpers.obj_scale(obj, scale)

	return obj
end

-- from src/game/object_helpers.c:cur_obj_move_using_vel L603-607
function object_helpers.cur_obj_move_using_vel()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
end

-- from src/game/object_helpers.c:obj_copy_graph_y_offset L609-611
function object_helpers.obj_copy_graph_y_offset(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	buffer.writef32(dst.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(src.rawData, IncludeObjectFieldsH.oGraphYOffset))
end

-- from src/game/object_helpers.c:obj_copy_pos_and_angle L613-616
function object_helpers.obj_copy_pos_and_angle(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	object_helpers.obj_copy_pos(dst, src)
	object_helpers.obj_copy_angle(dst, src)
end

-- from src/game/object_helpers.c:obj_copy_pos L618-622
function object_helpers.obj_copy_pos(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	buffer.writef32(dst.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(src.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(dst.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(src.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(dst.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(src.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/object_helpers.c:obj_copy_angle L624-632
function object_helpers.obj_copy_angle(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi32(src.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(src.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oMoveAngleRoll, buffer.readi32(src.rawData, IncludeObjectFieldsH.oMoveAngleRoll))

	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(src.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(src.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(src.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
end

-- from src/game/object_helpers.c:obj_set_gfx_pos_from_pos L634-638
function object_helpers.obj_set_gfx_pos_from_pos(obj: GroupsTypesHPlus3.Object)
	obj.header.gfx.pos[1] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	obj.header.gfx.pos[2] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
	obj.header.gfx.pos[3] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)
end

-- from src/game/object_helpers.c:obj_init_animation L640-643
function object_helpers.obj_init_animation(obj: GroupsTypesHPlus3.Object, animIndex: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const anims = o.ptrData[IncludeObjectFieldsH.oAnimations + 1] :: number

	SrcEngineGraphNode.geo_obj_init_animation(obj.header.gfx, anims + 4 * animIndex)
end

-- from src/game/object_helpers.c:linear_mtxf_mul_vec3f L653-658
function object_helpers.linear_mtxf_mul_vec3f(m: { { number } }, dst: { number }, v: { number })
	for i = 0, 2 do
		dst[i + 1] = F32(F32(F32(m[1][i + 1] * v[1]) + F32(m[2][i + 1] * v[2])) + F32(m[3][i + 1] * v[3]))
	end
end

-- from src/game/object_helpers.c:linear_mtxf_transpose_mul_vec3f L668-673
function object_helpers.linear_mtxf_transpose_mul_vec3f(m: { { number } }, dst: { number }, v: { number })
	for i = 0, 2 do
		dst[i + 1] = F32(F32(F32(m[i + 1][1] * v[1]) + F32(m[i + 1][2] * v[2])) + F32(m[i + 1][3] * v[3]))
	end
end

-- from src/game/object_helpers.c:obj_apply_scale_to_transform L675-691
function object_helpers.obj_apply_scale_to_transform(obj: GroupsTypesHPlus3.Object)
	const scaleX = obj.header.gfx.scale[1]
	const scaleY = obj.header.gfx.scale[2]
	const scaleZ = obj.header.gfx.scale[3]

	obj.transform[1][1] = F32(obj.transform[1][1] * scaleX)
	obj.transform[1][2] = F32(obj.transform[1][2] * scaleX)
	obj.transform[1][3] = F32(obj.transform[1][3] * scaleX)

	obj.transform[2][1] = F32(obj.transform[2][1] * scaleY)
	obj.transform[2][2] = F32(obj.transform[2][2] * scaleY)
	obj.transform[2][3] = F32(obj.transform[2][3] * scaleY)

	obj.transform[3][1] = F32(obj.transform[3][1] * scaleZ)
	obj.transform[3][2] = F32(obj.transform[3][2] * scaleZ)
	obj.transform[3][3] = F32(obj.transform[3][3] * scaleZ)
end

-- from src/game/object_helpers.c:obj_copy_scale L693-697
function object_helpers.obj_copy_scale(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	dst.header.gfx.scale[1] = src.header.gfx.scale[1]
	dst.header.gfx.scale[2] = src.header.gfx.scale[2]
	dst.header.gfx.scale[3] = src.header.gfx.scale[3]
end

-- from src/game/object_helpers.c:obj_scale_xyz L699-703
function object_helpers.obj_scale_xyz(obj: GroupsTypesHPlus3.Object, xScale: number, yScale: number, zScale: number)
	xScale = F32(xScale)
	yScale = F32(yScale)
	zScale = F32(zScale)
	obj.header.gfx.scale[1] = xScale
	obj.header.gfx.scale[2] = yScale
	obj.header.gfx.scale[3] = zScale
end

-- from src/game/object_helpers.c:obj_scale L705-709
function object_helpers.obj_scale(obj: GroupsTypesHPlus3.Object, scale: number)
	scale = F32(scale)
	obj.header.gfx.scale[1] = scale
	obj.header.gfx.scale[2] = scale
	obj.header.gfx.scale[3] = scale
end

-- from src/game/object_helpers.c:cur_obj_scale L711-715
function object_helpers.cur_obj_scale(scale: number)
	scale = F32(scale)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.scale[1] = scale
	o.header.gfx.scale[2] = scale
	o.header.gfx.scale[3] = scale
end

-- from src/game/object_helpers.c:cur_obj_init_animation L717-720
function object_helpers.cur_obj_init_animation(animIndex: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const anims = o.ptrData[IncludeObjectFieldsH.oAnimations + 1] :: number

	SrcEngineGraphNode.geo_obj_init_animation(o.header.gfx, anims + 4 * animIndex)
end

-- from src/game/object_helpers.c:cur_obj_init_animation_with_sound L722-726
function object_helpers.cur_obj_init_animation_with_sound(animIndex: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const anims = o.ptrData[IncludeObjectFieldsH.oAnimations + 1] :: number

	SrcEngineGraphNode.geo_obj_init_animation(o.header.gfx, anims + 4 * animIndex)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSoundStateID, animIndex)
end

-- from src/game/object_helpers.c:cur_obj_init_animation_with_accel_and_sound L728-733
function object_helpers.cur_obj_init_animation_with_accel_and_sound(animIndex: number, accel: number)
	accel = F32(accel)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const anims = o.ptrData[IncludeObjectFieldsH.oAnimations + 1] :: number
	const animAccel = TruncS32(accel * 65536)

	SrcEngineGraphNode.geo_obj_init_animation_accel(o.header.gfx, anims + 4 * animIndex, animAccel)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSoundStateID, animIndex)
end

-- from src/game/object_helpers.c:obj_init_animation_with_sound L735-740
function object_helpers.obj_init_animation_with_sound(obj: GroupsTypesHPlus3.Object, animations: number, animIndex: number)
	obj.ptrData[IncludeObjectFieldsH.oAnimations + 1] = animations

	SrcEngineGraphNode.geo_obj_init_animation(obj.header.gfx, animations + 4 * animIndex)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oSoundStateID, animIndex)
end

-- from src/game/object_helpers.c:cur_obj_enable_rendering_and_become_tangible L742-745
function object_helpers.cur_obj_enable_rendering_and_become_tangible(obj: GroupsTypesHPlus3.Object)
	obj.header.gfx.node.flags = S16(bit32.bor(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oIntangibleTimer, 0)
end

-- from src/game/object_helpers.c:cur_obj_enable_rendering L747-749
function object_helpers.cur_obj_enable_rendering()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
end

-- from src/game/object_helpers.c:cur_obj_disable_rendering_and_become_intangible L751-754
function object_helpers.cur_obj_disable_rendering_and_become_intangible(obj: GroupsTypesHPlus3.Object)
	obj.header.gfx.node.flags = S16(bit32.band(obj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
end

-- from src/game/object_helpers.c:cur_obj_disable_rendering L756-758
function object_helpers.cur_obj_disable_rendering()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
end

-- from src/game/object_helpers.c:cur_obj_unhide L760-762
function object_helpers.cur_obj_unhide()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
end

-- from src/game/object_helpers.c:cur_obj_hide L764-766
function object_helpers.cur_obj_hide()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
end

-- from src/game/object_helpers.c:cur_obj_set_pos_relative L768-780
function object_helpers.cur_obj_set_pos_relative(other: GroupsTypesHPlus3.Object, dleft: number, dy: number, dforward: number)
	dleft = F32(dleft)
	dy = F32(dy)
	dforward = F32(dforward)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const facingZ = Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const facingX = Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

	const dz = F32(F32(dforward * facingZ) - F32(dleft * facingX))
	const dx = F32(F32(dforward * facingX) + F32(dleft * facingZ))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosX) + dx)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosY) + dy)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosZ) + dz)
end

-- from src/game/object_helpers.c:cur_obj_set_pos_relative_to_parent L782-784
function object_helpers.cur_obj_set_pos_relative_to_parent(dleft: number, dy: number, dforward: number)
	dleft = F32(dleft)
	dy = F32(dy)
	dforward = F32(dforward)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_set_pos_relative(o.parentObj :: GroupsTypesHPlus3.Object, dleft, dy, dforward)
end

-- from src/game/object_helpers.c:cur_obj_enable_rendering_2 L786-788
function object_helpers.cur_obj_enable_rendering_2()
	object_helpers.cur_obj_enable_rendering()
end

-- from src/game/object_helpers.c:cur_obj_unused_init_on_floor L790-798
function object_helpers.cur_obj_unused_init_on_floor()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_enable_rendering()

	const floorY = Registry.Members.src__engine__surface_collision.find_floor_height(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, floorY)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		object_helpers.cur_obj_set_pos_relative_to_parent(0, 0, -70)

		const floorYAfterMove = Registry.Members.src__engine__surface_collision.find_floor_height(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, floorYAfterMove)
	end
end

-- from src/game/object_helpers.c:obj_set_face_angle_to_move_angle L800-804
function object_helpers.obj_set_face_angle_to_move_angle(obj: GroupsTypesHPlus3.Object)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleRoll))
end

-- from src/game/object_helpers.c:get_object_list_from_behavior L806-818
function object_helpers.get_object_list_from_behavior(behavior: number): number
	const firstCommand = Rom.ReadU32(behavior)
	local objectList: number

	if bit32.rshift(firstCommand, 24) == 0 then
		objectList = bit32.band(bit32.rshift(firstCommand, 16), 0xFFFF)
	else
		objectList = ObjectListProcessorH.OBJ_LIST_DEFAULT
	end

	return objectList
end

-- from src/game/object_helpers.c:cur_obj_nearest_object_with_behavior L820-827
function object_helpers.cur_obj_nearest_object_with_behavior(behavior: number): GroupsTypesHPlus3.Object?
	const obj: GroupsTypesHPlus3.Object? = object_helpers.cur_obj_find_nearest_object_with_behavior(behavior, Scratch.cur_obj_nearest_object_with_behavior_dist)

	return obj
end

-- from src/game/object_helpers.c:cur_obj_dist_to_nearest_object_with_behavior L829-839
function object_helpers.cur_obj_dist_to_nearest_object_with_behavior(behavior: number): number
	const obj = object_helpers.cur_obj_find_nearest_object_with_behavior(behavior, Scratch.cur_obj_dist_to_nearest_object_with_behavior_dist)

	if obj == nil then
		Scratch.cur_obj_dist_to_nearest_object_with_behavior_dist[1] = 15000.0
	end

	return Scratch.cur_obj_dist_to_nearest_object_with_behavior_dist[1]
end

-- from src/game/object_helpers.c:cur_obj_find_nearest_object_with_behavior L841-866
function object_helpers.cur_obj_find_nearest_object_with_behavior(behavior: number, dist: { number }): GroupsTypesHPlus3.Object?
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const behaviorAddr = Memory.segmented_to_virtual(behavior)
	const listHead = (ObjectListProcessor.gObjectLists :: { GroupsTypesHPlus3.ObjectNode })[object_helpers.get_object_list_from_behavior(behaviorAddr) + 1]
	local closestObj: GroupsTypesHPlus3.Object? = nil
	local minDist = 0x20000
	local obj: GroupsTypesHPlus3.Object = listHead.ObjectNode_next :: GroupsTypesHPlus3.Object

	while obj ~= listHead do
		if obj.behavior == behaviorAddr then
			if obj.activeFlags ~= IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED and obj ~= o then
				const objDist = object_helpers.dist_between_objects(o, obj)

				if objDist < minDist then
					closestObj = obj
					minDist = objDist
				end
			end
		end

		obj = obj.header.ObjectNode_next :: GroupsTypesHPlus3.Object
	end

	dist[1] = minDist

	return closestObj
end

-- from src/game/object_helpers.c:find_unimportant_object L868-877
function object_helpers.find_unimportant_object(): GroupsTypesHPlus3.Object
	const listHead = (ObjectListProcessor.gObjectLists :: { GroupsTypesHPlus3.ObjectNode })[ObjectListProcessorH.OBJ_LIST_UNIMPORTANT + 1]
	local obj: GroupsTypesHPlus3.ObjectNode? = listHead.ObjectNode_next

	if listHead == obj then
		obj = nil
	end

	return obj :: GroupsTypesHPlus3.Object
end

-- from src/game/object_helpers.c:count_unimportant_objects L879-890
function object_helpers.count_unimportant_objects(): number
	const listHead = (ObjectListProcessor.gObjectLists :: { GroupsTypesHPlus3.ObjectNode })[ObjectListProcessorH.OBJ_LIST_UNIMPORTANT + 1]
	local obj: GroupsTypesHPlus3.ObjectNode = listHead.ObjectNode_next :: GroupsTypesHPlus3.ObjectNode
	local count = 0

	while listHead ~= obj do
		count += 1
		obj = obj.ObjectNode_next :: GroupsTypesHPlus3.ObjectNode
	end

	return count
end

-- from src/game/object_helpers.c:count_objects_with_behavior L892-907
function object_helpers.count_objects_with_behavior(behavior: number): number
	const behaviorAddr = Memory.segmented_to_virtual(behavior)
	const listHead = (ObjectListProcessor.gObjectLists :: { GroupsTypesHPlus3.ObjectNode })[object_helpers.get_object_list_from_behavior(behaviorAddr) + 1]
	local obj: GroupsTypesHPlus3.ObjectNode? = listHead.ObjectNode_next
	local count = 0

	while listHead ~= obj do
		if (obj :: GroupsTypesHPlus3.Object).behavior == behaviorAddr then
			count += 1
		end

		obj = (obj :: GroupsTypesHPlus3.ObjectNode).ObjectNode_next
	end

	return count
end

-- from src/game/object_helpers.c:cur_obj_find_nearby_held_actor L909-933
function object_helpers.cur_obj_find_nearby_held_actor(behavior: number, maxDist: number): GroupsTypesHPlus3.Object?
	maxDist = F32(maxDist)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const behaviorAddr = Memory.segmented_to_virtual(behavior)
	const listHead = (ObjectListProcessor.gObjectLists :: { GroupsTypesHPlus3.ObjectNode })[ObjectListProcessorH.OBJ_LIST_GENACTOR + 1]
	local obj: GroupsTypesHPlus3.Object = listHead.ObjectNode_next :: GroupsTypesHPlus3.Object
	local foundObj: GroupsTypesHPlus3.Object? = nil

	while listHead ~= obj do
		if obj.behavior == behaviorAddr then
			if obj.activeFlags ~= IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
				if buffer.readu32(obj.rawData, IncludeObjectFieldsH.oHeldState) ~= IncludeObjectConstantsH.HELD_FREE then
					if object_helpers.dist_between_objects(o, obj) < maxDist then
						foundObj = obj

						break
					end
				end
			end
		end

		obj = obj.header.ObjectNode_next :: GroupsTypesHPlus3.Object
	end

	return foundObj
end

-- from src/game/object_helpers.c:cur_obj_reset_timer_and_subaction L935-938
function object_helpers.cur_obj_reset_timer_and_subaction()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
end

-- from src/game/object_helpers.c:cur_obj_change_action L940-944
function object_helpers.cur_obj_change_action(action: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, action)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPrevAction, action)

	object_helpers.cur_obj_reset_timer_and_subaction()
end

-- from src/game/object_helpers.c:cur_obj_set_vel_from_mario_vel L946-955
function object_helpers.cur_obj_set_vel_from_mario_vel(objBaseForwardVel: number, multiplier: number)
	objBaseForwardVel = F32(objBaseForwardVel)
	multiplier = F32(multiplier)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioForwardVel = LevelUpdate.gMarioStates[1].forwardVel
	const objForwardVel = F32(objBaseForwardVel * multiplier)

	if marioForwardVel < objForwardVel then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, objForwardVel)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(marioForwardVel * multiplier))
	end
end

-- from src/game/object_helpers.c:cur_obj_reverse_animation L957-961
function object_helpers.cur_obj_reverse_animation()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.header.gfx.animInfo.animFrame >= 0 then
		o.header.gfx.animInfo.animFrame = S16(o.header.gfx.animInfo.animFrame - 1)
	end
end

-- from src/game/object_helpers.c:cur_obj_extend_animation_if_at_end L963-970
function object_helpers.cur_obj_extend_animation_if_at_end()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame
	const sp0 = Rom.ReadS16((o.header.gfx.animInfo.curAnim :: number) + 8) - 2

	if animFrame == sp0 then
		o.header.gfx.animInfo.animFrame = S16(o.header.gfx.animInfo.animFrame - 1)
	end
end

-- from src/game/object_helpers.c:cur_obj_check_if_near_animation_end L972-987
function object_helpers.cur_obj_check_if_near_animation_end(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const curAnim = o.header.gfx.animInfo.curAnim :: number
	const animFlags = Rom.ReadS16(curAnim)
	const animFrame = o.header.gfx.animInfo.animFrame
	const nearLoopEnd = Rom.ReadS16(curAnim + 8) - 2
	local isNearEnd = IncludePRUltratypesH.FALSE

	if bit32.btest(animFlags, GroupsTypesHPlus3.ANIM_FLAG_NOLOOP) and nearLoopEnd + 1 == animFrame then
		isNearEnd = IncludePRUltratypesH.TRUE
	end

	if animFrame == nearLoopEnd then
		isNearEnd = IncludePRUltratypesH.TRUE
	end

	return isNearEnd
end

-- from src/game/object_helpers.c:cur_obj_check_if_at_animation_end L989-998
function object_helpers.cur_obj_check_if_at_animation_end(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame
	const lastFrame = Rom.ReadS16((o.header.gfx.animInfo.curAnim :: number) + 8) - 1

	if animFrame == lastFrame then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_check_anim_frame L1000-1008
function object_helpers.cur_obj_check_anim_frame(frame: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame

	if animFrame == frame then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_check_anim_frame_in_range L1010-1018
function object_helpers.cur_obj_check_anim_frame_in_range(startFrame: number, rangeLength: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame

	if animFrame >= startFrame and animFrame < startFrame + rangeLength then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_check_frame_prior_current_frame L1020-1032
function object_helpers.cur_obj_check_frame_prior_current_frame(a0: { number }): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const animFrame = o.header.gfx.animInfo.animFrame
	local index = 1

	while a0[index] ~= -1 do
		if a0[index] == animFrame then
			return IncludePRUltratypesH.TRUE
		end

		index += 1
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:mario_is_in_air_action L1034-1040
function object_helpers.mario_is_in_air_action(): number
	if bit32.btest(LevelUpdate.gMarioStates[1].action, IncludeSm64H.ACT_FLAG_AIR) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:mario_is_dive_sliding L1042-1048
function object_helpers.mario_is_dive_sliding(): number
	if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_DIVE_SLIDE then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_set_y_vel_and_animation L1050-1053
function object_helpers.cur_obj_set_y_vel_and_animation(yVel: number, animIndex: number)
	yVel = F32(yVel)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, yVel)

	object_helpers.cur_obj_init_animation_with_sound(animIndex)
end

-- from src/game/object_helpers.c:cur_obj_unrender_set_action_and_anim L1055-1065
function object_helpers.cur_obj_unrender_set_action_and_anim(animIndex: number, action: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_become_intangible()
	object_helpers.cur_obj_disable_rendering()

	if animIndex >= 0 then
		object_helpers.cur_obj_init_animation_with_sound(animIndex)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, action)
end

-- from src/game/object_helpers.c:cur_obj_move_after_thrown_or_dropped L1067-1085
function object_helpers.cur_obj_move_after_thrown_or_dropped(forwardVel: number, velY: number)
	forwardVel = F32(forwardVel)
	velY = F32(velY)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)

	const floorHeight = Registry.Members.src__engine__surface_collision.find_floor_height(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 160), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, floorHeight)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		object_helpers.obj_copy_pos(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object)

		const floorHeightAfterCopy = Registry.Members.src__engine__surface_collision.find_floor_height(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, floorHeightAfterCopy)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, forwardVel)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, velY)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0 then
		object_helpers.cur_obj_move_y(-4, F32(-0.1), 2)
	end
end

-- from src/game/object_helpers.c:cur_obj_get_thrown_or_placed L1087-1106
function object_helpers.cur_obj_get_thrown_or_placed(forwardVel: number, velY: number, thrownAction: number)
	forwardVel = F32(forwardVel)
	velY = F32(velY)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvBowser) then
		object_helpers.cur_obj_set_pos_relative_to_parent(F32(-41.684), F32(85.859), F32(321.577))
	end

	object_helpers.cur_obj_become_tangible()
	object_helpers.cur_obj_enable_rendering()

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_HOLDABLE_NPC) or forwardVel == 0 then
		object_helpers.cur_obj_move_after_thrown_or_dropped(0, 0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, thrownAction)
		object_helpers.cur_obj_move_after_thrown_or_dropped(forwardVel, velY)
	end
end

-- from src/game/object_helpers.c:cur_obj_get_dropped L1108-1114
function object_helpers.cur_obj_get_dropped()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_become_tangible()
	object_helpers.cur_obj_enable_rendering()

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)
	object_helpers.cur_obj_move_after_thrown_or_dropped(0, 0)
end

-- from src/game/object_helpers.c:cur_obj_set_model L1116-1118
function object_helpers.cur_obj_set_model(modelID: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.sharedChild = Area.gLoadedGraphNodes[modelID + 1]
end

-- from src/game/object_helpers.c:mario_set_flag L1120-1122
function object_helpers.mario_set_flag(flag: number)
	LevelUpdate.gMarioStates[1].flags = bit32.bor(LevelUpdate.gMarioStates[1].flags, flag)
end

-- from src/game/object_helpers.c:cur_obj_clear_interact_status_flag L1124-1130
function object_helpers.cur_obj_clear_interact_status_flag(flag: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), flag) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bxor(flag, 0xFFFFFFFF))))

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:obj_mark_for_deletion L1135-1141
function object_helpers.obj_mark_for_deletion(obj: GroupsTypesHPlus3.Object)
	obj.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

-- from src/game/object_helpers.c:cur_obj_disable L1143-1147
function object_helpers.cur_obj_disable()
	object_helpers.cur_obj_disable_rendering()
	object_helpers.cur_obj_hide()
	object_helpers.cur_obj_become_intangible()
end

-- from src/game/object_helpers.c:cur_obj_become_intangible L1149-1153
function object_helpers.cur_obj_become_intangible()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
end

-- from src/game/object_helpers.c:cur_obj_become_tangible L1155-1157
function object_helpers.cur_obj_become_tangible()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oIntangibleTimer, 0)
end

-- from src/game/object_helpers.c:obj_become_tangible L1159-1161
function object_helpers.obj_become_tangible(obj: GroupsTypesHPlus3.Object)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oIntangibleTimer, 0)
end

-- from src/game/object_helpers.c:cur_obj_update_floor_height L1163-1166
function object_helpers.cur_obj_update_floor_height()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const floorOut = { nil } :: { GroupsTypesHPlus3.Surface? }
	const floorHeight = Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), floorOut)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, floorHeight)
end

-- from src/game/object_helpers.c:cur_obj_update_floor_height_and_get_floor L1168-1172
function object_helpers.cur_obj_update_floor_height_and_get_floor(): GroupsTypesHPlus3.Surface?
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.cur_obj_update_floor_height_and_get_floor_floor)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, floorHeight)

	return Scratch.cur_obj_update_floor_height_and_get_floor_floor[1]
end

-- from src/game/object_helpers.c:apply_drag_to_value L1174-1193
function object_helpers.apply_drag_to_value(Buffer: buffer, Offset: number, dragStrength: number)
	dragStrength = F32(dragStrength)
	local value = buffer.readf32(Buffer, Offset)

	if value ~= 0 then
		const decel = F32(F32(value * value) * (dragStrength * 0.0001))

		if value > 0 then
			value = F32(value - decel)

			if value < 0.001 then
				value = 0
			end
		else
			value = F32(value + decel)

			if value > -0.001 then
				value = 0
			end
		end

		buffer.writef32(Buffer, Offset, value)
	end
end

-- from src/game/object_helpers.c:cur_obj_apply_drag_xz L1195-1198
function object_helpers.cur_obj_apply_drag_xz(dragStrength: number)
	dragStrength = F32(dragStrength)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	object_helpers.apply_drag_to_value(o.rawData, IncludeObjectFieldsH.oVelX, dragStrength)
	object_helpers.apply_drag_to_value(o.rawData, IncludeObjectFieldsH.oVelZ, dragStrength)
end

-- from src/game/object_helpers.c:cur_obj_move_xz L1200-1257
function object_helpers.cur_obj_move_xz(steepSlopeNormalY: number, careAboutEdgesAndSteepSlopes: number): number
	steepSlopeNormalY = F32(steepSlopeNormalY)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const intendedX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	const intendedZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	const floorOut = { nil } :: { GroupsTypesHPlus3.Surface? }
	const intendedFloorHeight = Registry.Members.src__engine__surface_collision.find_floor(intendedX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), intendedZ, floorOut)
	const intendedFloor = floorOut[1]
	const deltaFloorHeight = F32(intendedFloorHeight - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE)))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom) ~= -1 and intendedFloor ~= nil then
		-- Don't leave native room
		if intendedFloor.room ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom) ~= intendedFloor.room and intendedFloor.room ~= 18 then
			return IncludePRUltratypesH.FALSE
		end
	end

	if intendedFloorHeight < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
		-- Don't move into OoB
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE))

		return IncludePRUltratypesH.FALSE
	elseif deltaFloorHeight < 5 then
		if careAboutEdgesAndSteepSlopes == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, intendedX)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, intendedZ)

			return IncludePRUltratypesH.TRUE
		elseif deltaFloorHeight < -50 and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			-- Don't walk off an edge
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE))

			return IncludePRUltratypesH.FALSE
		elseif (intendedFloor :: GroupsTypesHPlus3.Surface).normal.y > steepSlopeNormalY then
			-- Allow movement onto a slope, provided it's not too steep
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, intendedX)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, intendedZ)

			return IncludePRUltratypesH.TRUE
		else
			-- We are likely trying to move onto a steep downward slope
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE))

			return IncludePRUltratypesH.FALSE
		end
	elseif (intendedFloor :: GroupsTypesHPlus3.Surface).normal.y > steepSlopeNormalY or buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > intendedFloorHeight then
		-- Allow movement upward, provided the target floor is flat enough or we are above it.
		-- Returning FALSE but moving anyway (the return value is never used).
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, intendedX)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, intendedZ)
	end

	-- We are likely trying to move onto a steep upward slope
	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_move_update_underwater_flags L1259-1274
function object_helpers.cur_obj_move_update_underwater_flags()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const velY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)
	const dragStrength = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDragStrength)
	const speedY = F32(math.sqrt(F32(velY * velY)))
	const decelY = F32(F32(speedY * F32(dragStrength * 7)) / 100)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - decelY)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + decelY)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND))
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_OFF_GROUND))
	end
end

-- from src/game/object_helpers.c:cur_obj_move_update_ground_air_flags L1276-1309
function object_helpers.cur_obj_move_update_ground_air_flags(gravity: number, bounciness: number)
	gravity = F32(gravity)
	bounciness = F32(bounciness)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_BOUNCE)))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
		if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			if object_helpers.clear_move_flag(o.rawData, IncludeObjectFieldsH.oMoveFlags, IncludeObjectConstantsH.OBJ_MOVE_LANDED) ~= 0 then
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND))
			else
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED))
			end
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) * bounciness)
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 5 then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_BOUNCE))
		end
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_LANDED)))

		if object_helpers.clear_move_flag(o.rawData, IncludeObjectFieldsH.oMoveFlags, IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) ~= 0 then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LEFT_GROUND))
		end
	end

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER)))
end

-- from src/game/object_helpers.c:cur_obj_move_y_and_get_water_level L1311-1327
function object_helpers.cur_obj_move_y_and_get_water_level(gravity: number, buoyancy: number): number
	gravity = F32(gravity)
	buoyancy = F32(buoyancy)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + F32(gravity + buoyancy))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -78 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -78)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	local waterLevel: number

	if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK10) then
		waterLevel = SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT
	else
		waterLevel = Registry.Members.src__engine__surface_collision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	end

	return waterLevel
end

-- from src/game/object_helpers.c:cur_obj_move_y L1329-1377
function object_helpers.cur_obj_move_y(gravity: number, bounciness: number, buoyancy: number)
	gravity = F32(gravity)
	bounciness = F32(bounciness)
	buoyancy = F32(buoyancy)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local waterLevel: number

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_LEFT_GROUND)))

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE) then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 5 then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER)))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LEAVING_WATER))
		end
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		waterLevel = object_helpers.cur_obj_move_y_and_get_water_level(gravity, 0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > waterLevel then
			object_helpers.cur_obj_move_update_ground_air_flags(gravity, bounciness)
		else
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND)))
		end
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER)))

		waterLevel = object_helpers.cur_obj_move_y_and_get_water_level(gravity, buoyancy)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < waterLevel then
			object_helpers.cur_obj_move_update_underwater_flags()
		else
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER)))
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, waterLevel)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_OFF_GROUND, IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND))))
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE))
			end
		end
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE, IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_OFF_GROUND)) then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_IN_AIR)))
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_IN_AIR))
	end
end

-- from src/game/object_helpers.c:stub_obj_helpers_1 L1379-1380
function object_helpers.stub_obj_helpers_1()
	-- Empty in the C source.
end

-- from src/game/object_helpers.c:clear_move_flag L1382-1389
function object_helpers.clear_move_flag(Buffer: buffer, Offset: number, flag: number): number
	if bit32.btest(buffer.readu32(Buffer, Offset), flag) then
		buffer.writeu32(Buffer, Offset, bit32.band(buffer.readu32(Buffer, Offset), bit32.bxor(flag, 0xFFFFFFFF)))
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_unused_resolve_wall_collisions L1391-1395
function object_helpers.cur_obj_unused_resolve_wall_collisions(offsetY: number, radius: number)
	offsetY = F32(offsetY)
	radius = F32(radius)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if radius > 0.1 then
		Scratch.cur_obj_unused_resolve_wall_collisions_posX[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		Scratch.cur_obj_unused_resolve_wall_collisions_posY[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Scratch.cur_obj_unused_resolve_wall_collisions_posZ[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

		Registry.Members.src__engine__surface_collision.f32_find_wall_collision(Scratch.cur_obj_unused_resolve_wall_collisions_posX, Scratch.cur_obj_unused_resolve_wall_collisions_posY, Scratch.cur_obj_unused_resolve_wall_collisions_posZ, offsetY, radius)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Scratch.cur_obj_unused_resolve_wall_collisions_posX[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Scratch.cur_obj_unused_resolve_wall_collisions_posY[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Scratch.cur_obj_unused_resolve_wall_collisions_posZ[1])
	end
end

-- from src/game/object_helpers.c:abs_angle_diff L1397-1409
function object_helpers.abs_angle_diff(x0: number, x1: number): number
	x0 = S16(TruncS32(x0))
	x1 = S16(TruncS32(x1))
	local diff = S16(x1 - x0)

	if diff == -0x8000 then
		diff = -0x7FFF
	end

	if diff < 0 then
		diff = S16(-diff)
	end

	return diff
end

-- from src/game/object_helpers.c:cur_obj_move_xz_using_fvel_and_yaw L1411-1417
function object_helpers.cur_obj_move_xz_using_fvel_and_yaw()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
end

-- from src/game/object_helpers.c:cur_obj_move_y_with_terminal_vel L1419-1425
function object_helpers.cur_obj_move_y_with_terminal_vel()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -70 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -70)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

-- from src/game/object_helpers.c:cur_obj_compute_vel_xz L1427-1430
function object_helpers.cur_obj_compute_vel_xz()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))))
end

-- from src/game/object_helpers.c:increment_velocity_toward_range L1432-1447
function object_helpers.increment_velocity_toward_range(value: number, center: number, zeroThreshold: number, increment: number): number
	value = F32(value)
	center = F32(center)
	zeroThreshold = F32(zeroThreshold)
	increment = F32(increment)
	const relative = F32(value - center)

	if relative > 0 then
		if relative < zeroThreshold then
			return 0
		else
			return -increment
		end
	else
		if relative > -zeroThreshold then
			return 0
		else
			return increment
		end
	end
end

-- from src/game/object_helpers.c:obj_check_if_collided_with_object L1449-1458
function object_helpers.obj_check_if_collided_with_object(obj1: GroupsTypesHPlus3.Object, obj2: GroupsTypesHPlus3.Object): number
	for i = 0, obj1.numCollidedObjs - 1 do
		if obj1.collidedObjs[i + 1] == obj2 then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_set_behavior L1460-1462
function object_helpers.cur_obj_set_behavior(behavior: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.behavior = Memory.segmented_to_virtual(behavior)
end

-- from src/game/object_helpers.c:obj_set_behavior L1464-1466
function object_helpers.obj_set_behavior(obj: GroupsTypesHPlus3.Object, behavior: number)
	obj.behavior = Memory.segmented_to_virtual(behavior)
end

-- from src/game/object_helpers.c:cur_obj_has_behavior L1468-1474
function object_helpers.cur_obj_has_behavior(behavior: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.behavior == Memory.segmented_to_virtual(behavior) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:obj_has_behavior L1476-1482
function object_helpers.obj_has_behavior(obj: GroupsTypesHPlus3.Object, behavior: number): number
	if obj.behavior == Memory.segmented_to_virtual(behavior) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_lateral_dist_from_mario_to_home L1484-1491
function object_helpers.cur_obj_lateral_dist_from_mario_to_home(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ))

	const dist = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	return dist
end

-- from src/game/object_helpers.c:cur_obj_lateral_dist_to_home L1493-1500
function object_helpers.cur_obj_lateral_dist_to_home(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	const dist = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	return dist
end

-- from src/game/object_helpers.c:cur_obj_outside_home_square L1502-1520
function object_helpers.cur_obj_outside_home_square(halfLength: number): number
	halfLength = F32(halfLength)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - halfLength) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + halfLength) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - halfLength) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + halfLength) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_outside_home_rectangle L1522-1540
function object_helpers.cur_obj_outside_home_rectangle(minX: number, maxX: number, minZ: number, maxZ: number): number
	minX = F32(minX)
	maxX = F32(maxX)
	minZ = F32(minZ)
	maxZ = F32(maxZ)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + minX) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + maxX) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + minZ) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.TRUE
	end

	if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + maxZ) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_set_pos_to_home L1542-1546
function object_helpers.cur_obj_set_pos_to_home()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
end

-- from src/game/object_helpers.c:cur_obj_set_pos_to_home_and_stop L1548-1553
function object_helpers.cur_obj_set_pos_to_home_and_stop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_set_pos_to_home()

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
end

-- from src/game/object_helpers.c:cur_obj_shake_y L1555-1562
function object_helpers.cur_obj_shake_y(amount: number)
	amount = F32(amount)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) % 2 == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + amount))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - amount))
	end
end

-- from src/game/object_helpers.c:cur_obj_start_cam_event L1564-1567
function object_helpers.cur_obj_start_cam_event(obj: GroupsTypesHPlus3.Object, cameraEvent: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	Registry.Members.src__game__camera.gPlayerCameraState[1].cameraEvent = S16(cameraEvent)
	Registry.Members.src__game__camera.gSecondCameraFocus = o
end

-- from src/game/object_helpers.c:set_mario_interact_true_if_in_range L1570-1574
function object_helpers.set_mario_interact_true_if_in_range(arg0: number, arg1: number, range: number)
	range = F32(range)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < range then
		buffer.writei32(marioObject.rawData, IncludeObjectFieldsH.oInteractStatus, IncludePRUltratypesH.TRUE)
	end
end

-- from src/game/object_helpers.c:obj_set_billboard L1576-1578
function object_helpers.obj_set_billboard(obj: GroupsTypesHPlus3.Object)
	obj.header.gfx.node.flags = S16(bit32.bor(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD))
end

-- from src/game/object_helpers.c:cur_obj_set_hitbox_radius_and_height L1580-1583
function object_helpers.cur_obj_set_hitbox_radius_and_height(radius: number, height: number)
	radius = F32(radius)
	height = F32(height)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.hitboxRadius = radius
	o.hitboxHeight = height
end

-- from src/game/object_helpers.c:cur_obj_set_hurtbox_radius_and_height L1585-1588
function object_helpers.cur_obj_set_hurtbox_radius_and_height(radius: number, height: number)
	radius = F32(radius)
	height = F32(height)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.hurtboxRadius = radius
	o.hurtboxHeight = height
end

-- from src/game/object_helpers.c:obj_spawn_loot_coins L1590-1615
function object_helpers.obj_spawn_loot_coins(obj: GroupsTypesHPlus3.Object, numCoins: number, baseVelY: number, coinBehavior: number, posJitter: number, model: number)
	baseVelY = F32(baseVelY)
	posJitter = S16(TruncS32(posJitter))
	model = S16(TruncS32(model))
	const spawnHeight: number = Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ), Scratch.obj_spawn_loot_coins_floor)
	local coinHeight = spawnHeight

	if F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) - spawnHeight) > 100 then
		coinHeight = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
	end

	for i = 1, numCoins do
		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oNumLootCoins) <= 0 then
			break
		end

		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oNumLootCoins, buffer.readi32(obj.rawData, IncludeObjectFieldsH.oNumLootCoins) - 1)

		const coin: GroupsTypesHPlus3.Object = object_helpers.spawn_object(obj, model, coinBehavior)
		object_helpers.obj_translate_xz_random(coin, posJitter)
		buffer.writef32(coin.rawData, IncludeObjectFieldsH.oPosY, coinHeight)
		buffer.writef32(coin.rawData, IncludeObjectFieldsH.oCoinBaseVelY, baseVelY)
	end
end

-- from src/game/object_helpers.c:obj_spawn_loot_blue_coins L1617-1619
function object_helpers.obj_spawn_loot_blue_coins(obj: GroupsTypesHPlus3.Object, numCoins: number, baseVelY: number, posJitter: number)
	baseVelY = F32(baseVelY)
	posJitter = S16(TruncS32(posJitter))
	object_helpers.obj_spawn_loot_coins(obj, numCoins, baseVelY, BehaviorIds.bhvBlueCoinJumping, posJitter, IncludeModelIdsH.MODEL_BLUE_COIN)
end

-- from src/game/object_helpers.c:obj_spawn_loot_yellow_coins L1621-1623
function object_helpers.obj_spawn_loot_yellow_coins(obj: GroupsTypesHPlus3.Object, numCoins: number, baseVelY: number)
	baseVelY = F32(baseVelY)
	object_helpers.obj_spawn_loot_coins(obj, numCoins, baseVelY, BehaviorIds.bhvSingleCoinGetsSpawned, 0, IncludeModelIdsH.MODEL_YELLOW_COIN)
end

-- from src/game/object_helpers.c:cur_obj_spawn_loot_coin_at_mario_pos L1625-1637
function object_helpers.cur_obj_spawn_loot_coin_at_mario_pos()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins) <= 0 then
		return
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins) - 1))

	const coin = object_helpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvSingleCoinGetsSpawned)

	buffer.writef32(coin.rawData, IncludeObjectFieldsH.oVelY, 30)

	object_helpers.obj_copy_pos(coin, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object)
end

-- from src/game/object_helpers.c:cur_obj_abs_y_dist_to_home L1639-1647
function object_helpers.cur_obj_abs_y_dist_to_home(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local dist = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))

	if dist < 0 then
		dist = -dist
	end

	return dist
end

-- from src/game/object_helpers.c:cur_obj_advance_looping_anim L1649-1665
function object_helpers.cur_obj_advance_looping_anim(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const curAnim = o.header.gfx.animInfo.curAnim :: number
	local animFrame = o.header.gfx.animInfo.animFrame
	const loopEnd = Rom.ReadS16(curAnim + 8)
	local result: number

	if animFrame < 0 then
		animFrame = 0
	elseif loopEnd - 1 == animFrame then
		animFrame = 0
	else
		animFrame += 1
	end

	result = bit32.lshift(animFrame, 16) // loopEnd

	return result
end

-- from src/game/object_helpers.c:cur_obj_detect_steep_floor L1667-1692
function object_helpers.cur_obj_detect_steep_floor(steepAngleDegrees: number): number
	steepAngleDegrees = S16(TruncS32(steepAngleDegrees))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const steepNormalY = Registry.Members.src__engine__math_util_h.coss(S16(steepAngleDegrees * (0x10000 // 360)))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0 then
		const intendedX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
		const intendedZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

		const floorOut = { nil } :: { GroupsTypesHPlus3.Surface? }
		const intendedFloorHeight = Registry.Members.src__engine__surface_collision.find_floor(intendedX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), intendedZ, floorOut)
		const intendedFloor = floorOut[1]
		const deltaFloorHeight = F32(intendedFloorHeight - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))

		if intendedFloorHeight < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWallAngle, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))

			return 2
		elseif (intendedFloor :: GroupsTypesHPlus3.Surface).normal.y < steepNormalY and deltaFloorHeight > 0 and intendedFloorHeight > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWallAngle, SrcEngineMathUtil.atan2s((intendedFloor :: GroupsTypesHPlus3.Surface).normal.z, (intendedFloor :: GroupsTypesHPlus3.Surface).normal.x))

			return 1
		else
			return 0
		end
	end

	return 0
end

-- from src/game/object_helpers.c:cur_obj_resolve_wall_collisions L1694-1726
function object_helpers.cur_obj_resolve_wall_collisions(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const offsetY = 10
	const radius = buffer.readf32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius)

	-- 0.1L is a long double; no f32 lies between 0.1 and F32(0.1) on the other side of 0.1, so > 0.1 is the same test
	if radius > 0.1 then
		const collisionData = { x = 0, y = 0, z = 0, offsetY = 0, radius = 0, filler = buffer.create(2), numWalls = 0, walls = {} } :: SrcEngineSurfaceCollisionH.WallCollisionData

		collisionData.offsetY = offsetY
		collisionData.radius = radius
		collisionData.x = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)))
		collisionData.y = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))
		collisionData.z = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))

		const numCollisions = Registry.Members.src__engine__surface_collision.find_wall_collisions(collisionData)

		if numCollisions ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, collisionData.x)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, collisionData.y)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, collisionData.z)

			const wall = collisionData.walls[collisionData.numWalls] :: GroupsTypesHPlus3.Surface

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWallAngle, SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x))

			if object_helpers.abs_angle_diff(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle), buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) > 0x4000 then
				return IncludePRUltratypesH.TRUE
			else
				return IncludePRUltratypesH.FALSE
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_update_floor L1728-1749
function object_helpers.cur_obj_update_floor()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const floor = object_helpers.cur_obj_update_floor_height_and_get_floor()

	o.ptrData[IncludeObjectFieldsH.oFloor + 1] = floor

	if floor ~= nil then
		if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ABOVE_LAVA))
		elseif floor.type_ == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ABOVE_DEATH_BARRIER))
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oFloorType, floor.type_)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oFloorRoom, floor.room)
	else
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oFloorType, 0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oFloorRoom, 0)
	end
end

-- from src/game/object_helpers.c:cur_obj_update_floor_and_resolve_wall_collisions L1751-1781
function object_helpers.cur_obj_update_floor_and_resolve_wall_collisions(steepSlopeDegrees: number)
	steepSlopeDegrees = S16(TruncS32(steepSlopeDegrees))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_ABOVE_LAVA, IncludeObjectConstantsH.OBJ_MOVE_ABOVE_DEATH_BARRIER))))

	if bit32.btest(o.activeFlags, bit32.bor(IncludeObjectConstantsH.ACTIVE_FLAG_FAR_AWAY, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM)) then
		object_helpers.cur_obj_update_floor()
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL, IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER))))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_IN_AIR))
		end
	else
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL)))

		if object_helpers.cur_obj_resolve_wall_collisions() ~= IncludePRUltratypesH.FALSE then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL))
		end

		object_helpers.cur_obj_update_floor()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_IN_AIR))
		end

		if object_helpers.cur_obj_detect_steep_floor(steepSlopeDegrees) ~= IncludePRUltratypesH.FALSE then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL))
		end
	end
end

-- from src/game/object_helpers.c:cur_obj_update_floor_and_walls L1783-1785
function object_helpers.cur_obj_update_floor_and_walls()
	object_helpers.cur_obj_update_floor_and_resolve_wall_collisions(60)
end

-- from src/game/object_helpers.c:cur_obj_move_standard L1787-1825
function object_helpers.cur_obj_move_standard(steepSlopeAngleDegrees: number)
	steepSlopeAngleDegrees = S16(TruncS32(steepSlopeAngleDegrees))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const gravity = buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity)
	const bounciness = buffer.readf32(o.rawData, IncludeObjectFieldsH.oBounciness)
	const buoyancy = buffer.readf32(o.rawData, IncludeObjectFieldsH.oBuoyancy)
	const dragStrength = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDragStrength)
	local steepSlopeNormalY: number
	local careAboutEdgesAndSteepSlopes = IncludePRUltratypesH.FALSE
	local negativeSpeed = IncludePRUltratypesH.FALSE

	if not bit32.btest(o.activeFlags, bit32.bor(IncludeObjectConstantsH.ACTIVE_FLAG_FAR_AWAY, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM)) then
		if steepSlopeAngleDegrees < 0 then
			careAboutEdgesAndSteepSlopes = IncludePRUltratypesH.TRUE
			steepSlopeAngleDegrees = S16(-steepSlopeAngleDegrees)
		end

		steepSlopeNormalY = Registry.Members.src__engine__math_util_h.coss(steepSlopeAngleDegrees * (0x10000 // 360))

		object_helpers.cur_obj_compute_vel_xz()
		object_helpers.cur_obj_apply_drag_xz(dragStrength)

		object_helpers.cur_obj_move_xz(steepSlopeNormalY, careAboutEdgesAndSteepSlopes)
		object_helpers.cur_obj_move_y(gravity, bounciness, buoyancy)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) < 0 then
			negativeSpeed = IncludePRUltratypesH.TRUE
		end

		const velX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX)
		const velZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ)
		const sumSquares = F32(Registry.Members.src__engine__math_util_h.sqr(velX) + Registry.Members.src__engine__math_util_h.sqr(velZ))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(math.sqrt(sumSquares)))

		if negativeSpeed == IncludePRUltratypesH.TRUE then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))
		end
	end
end

-- from src/game/object_helpers.c:cur_obj_within_12k_bounds L1827-1841
function object_helpers.cur_obj_within_12k_bounds(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) < -12000 or 12000 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.FALSE
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < -12000 or 12000 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		return IncludePRUltratypesH.FALSE
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) < -12000 or 12000 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/object_helpers.c:cur_obj_move_using_vel_and_gravity L1843-1850
function object_helpers.cur_obj_move_using_vel_and_gravity()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if object_helpers.cur_obj_within_12k_bounds() ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)))
	end
end

-- from src/game/object_helpers.c:cur_obj_move_using_fvel_and_gravity L1852-1855
function object_helpers.cur_obj_move_using_fvel_and_gravity()
	object_helpers.cur_obj_compute_vel_xz()
	object_helpers.cur_obj_move_using_vel_and_gravity()
end

-- from src/game/object_helpers.c:obj_set_pos_relative L1857-1870
function object_helpers.obj_set_pos_relative(obj: GroupsTypesHPlus3.Object, other: GroupsTypesHPlus3.Object, dleft: number, dy: number, dforward: number)
	dleft = F32(dleft)
	dy = F32(dy)
	dforward = F32(dforward)
	const facingZ = Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const facingX = Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

	const dz = F32(F32(dforward * facingZ) - F32(dleft * facingX))
	const dx = F32(F32(dforward * facingX) + F32(dleft * facingZ))

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(other.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosX) + dx))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosY) + dy))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(other.rawData, IncludeObjectFieldsH.oPosZ) + dz))
end

-- from src/game/object_helpers.c:cur_obj_angle_to_home L1872-1879
function object_helpers.cur_obj_angle_to_home(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	const angle = SrcEngineMathUtil.atan2s(dz, dx)

	return angle
end

-- from src/game/object_helpers.c:obj_set_gfx_pos_at_obj_pos L1881-1889
function object_helpers.obj_set_gfx_pos_at_obj_pos(obj1: GroupsTypesHPlus3.Object, obj2: GroupsTypesHPlus3.Object)
	obj1.header.gfx.pos[1] = buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosX)
	obj1.header.gfx.pos[2] = F32(buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oGraphYOffset))
	obj1.header.gfx.pos[3] = buffer.readf32(obj2.rawData, IncludeObjectFieldsH.oPosZ)

	obj1.header.gfx.angle[1] = S16(bit32.band(buffer.readi32(obj2.rawData, IncludeObjectFieldsH.oMoveAnglePitch), 0xFFFF))
	obj1.header.gfx.angle[2] = S16(bit32.band(buffer.readi32(obj2.rawData, IncludeObjectFieldsH.oMoveAngleYaw), 0xFFFF))
	obj1.header.gfx.angle[3] = S16(bit32.band(buffer.readi32(obj2.rawData, IncludeObjectFieldsH.oMoveAngleRoll), 0xFFFF))
end

-- from src/game/object_helpers.c:obj_translate_local L1895-1906
function object_helpers.obj_translate_local(obj: GroupsTypesHPlus3.Object, posIndex: number, localTranslateIndex: number)
	posIndex = S16(TruncS32(posIndex))
	localTranslateIndex = S16(TruncS32(localTranslateIndex))
	const dx = buffer.readf32(obj.rawData, (localTranslateIndex + 0) * 4)
	const dy = buffer.readf32(obj.rawData, (localTranslateIndex + 1) * 4)
	const dz = buffer.readf32(obj.rawData, (localTranslateIndex + 2) * 4)

	const addX = F32(F32(F32(obj.transform[1][1] * dx) + F32(obj.transform[2][1] * dy)) + F32(obj.transform[3][1] * dz))
	const addY = F32(F32(F32(obj.transform[1][2] * dx) + F32(obj.transform[2][2] * dy)) + F32(obj.transform[3][2] * dz))
	const addZ = F32(F32(F32(obj.transform[1][3] * dx) + F32(obj.transform[2][3] * dy)) + F32(obj.transform[3][3] * dz))

	buffer.writef32(obj.rawData, (posIndex + 0) * 4, F32(buffer.readf32(obj.rawData, (posIndex + 0) * 4) + addX))
	buffer.writef32(obj.rawData, (posIndex + 1) * 4, F32(buffer.readf32(obj.rawData, (posIndex + 1) * 4) + addY))
	buffer.writef32(obj.rawData, (posIndex + 2) * 4, F32(buffer.readf32(obj.rawData, (posIndex + 2) * 4) + addZ))
end

-- from src/game/object_helpers.c:obj_build_transform_from_pos_and_angle L1908-1921
function object_helpers.obj_build_transform_from_pos_and_angle(obj: GroupsTypesHPlus3.Object, posIndex: number, angleIndex: number)
	posIndex = S16(TruncS32(posIndex))
	angleIndex = S16(TruncS32(angleIndex))
	const translate = table.create(3, 0)
	const rotation = table.create(3, 0)

	translate[1] = buffer.readf32(obj.rawData, (posIndex + 0) * 4)
	translate[2] = buffer.readf32(obj.rawData, (posIndex + 1) * 4)
	translate[3] = buffer.readf32(obj.rawData, (posIndex + 2) * 4)

	rotation[1] = S16(buffer.readi32(obj.rawData, (angleIndex + 0) * 4))
	rotation[2] = S16(buffer.readi32(obj.rawData, (angleIndex + 1) * 4))
	rotation[3] = S16(buffer.readi32(obj.rawData, (angleIndex + 2) * 4))

	SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(obj.transform, translate, rotation)
end

-- from src/game/object_helpers.c:obj_set_throw_matrix_from_transform L1923-1934
function object_helpers.obj_set_throw_matrix_from_transform(obj: GroupsTypesHPlus3.Object)
	if bit32.btest(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_0020) then
		object_helpers.obj_build_transform_from_pos_and_angle(obj, IncludeObjectFieldsH.O_POS_INDEX, IncludeObjectFieldsH.O_FACE_ANGLE_INDEX)
		object_helpers.obj_apply_scale_to_transform(obj)
	end

	obj.header.gfx.throwMatrix = { obj.transform }

	object_helpers.cur_obj_scale(1)
end

-- from src/game/object_helpers.c:obj_build_transform_relative_to_parent L1936-1952
function object_helpers.obj_build_transform_relative_to_parent(obj: GroupsTypesHPlus3.Object)
	const parent = obj.parentObj :: GroupsTypesHPlus3.Object

	object_helpers.obj_build_transform_from_pos_and_angle(obj, IncludeObjectFieldsH.O_PARENT_RELATIVE_POS_INDEX, IncludeObjectFieldsH.O_FACE_ANGLE_INDEX)
	object_helpers.obj_apply_scale_to_transform(obj)
	SrcEngineMathUtil.mtxf_mul(obj.transform, obj.transform, parent.transform)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, obj.transform[4][1])
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, obj.transform[4][2])
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, obj.transform[4][3])

	obj.header.gfx.throwMatrix = { obj.transform }

	object_helpers.cur_obj_scale(1)
end

-- from src/game/object_helpers.c:obj_create_transform_from_self L1954-1961
function object_helpers.obj_create_transform_from_self(obj: GroupsTypesHPlus3.Object)
	buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_TRANSFORM_RELATIVE_TO_PARENT)))
	buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_THROW_MATRIX_FROM_TRANSFORM))

	obj.transform[4][1] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	obj.transform[4][2] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
	obj.transform[4][3] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)
end

-- from src/game/object_helpers.c:cur_obj_rotate_move_angle_using_vel L1963-1967
function object_helpers.cur_obj_rotate_move_angle_using_vel()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll)))
end

-- from src/game/object_helpers.c:cur_obj_rotate_face_angle_using_vel L1969-1973
function object_helpers.cur_obj_rotate_face_angle_using_vel()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll)))
end

-- from src/game/object_helpers.c:cur_obj_set_face_angle_to_move_angle L1975-1979
function object_helpers.cur_obj_set_face_angle_to_move_angle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll))
end

-- from src/game/object_helpers.c:cur_obj_follow_path L1981-2029
function object_helpers.cur_obj_follow_path(unusedArg: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags) == 0 then
		o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags, ObjectHelpersH.WAYPOINT_FLAGS_INITIALIZED)
	end

	const startWaypoint = o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] :: number
	const lastWaypoint = o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] :: number
	local targetWaypoint: number

	if Rom.ReadS16(lastWaypoint + 8) ~= ObjectHelpersH.WAYPOINT_FLAGS_END then
		targetWaypoint = lastWaypoint + 8
	else
		targetWaypoint = startWaypoint
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags, S32(bit32.bor(Rom.ReadS16(lastWaypoint), ObjectHelpersH.WAYPOINT_FLAGS_INITIALIZED)))

	const prevToNextX = Rom.ReadS16(targetWaypoint + 2) - Rom.ReadS16(lastWaypoint + 2)
	const prevToNextY = Rom.ReadS16(targetWaypoint + 4) - Rom.ReadS16(lastWaypoint + 4)
	const prevToNextZ = Rom.ReadS16(targetWaypoint + 6) - Rom.ReadS16(lastWaypoint + 6)

	const objToNextX = F32(Rom.ReadS16(targetWaypoint + 2) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const objToNextY = F32(Rom.ReadS16(targetWaypoint + 4) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	const objToNextZ = F32(Rom.ReadS16(targetWaypoint + 6) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const objToNextXZ = F32(math.sqrt(F32(Registry.Members.src__engine__math_util_h.sqr(objToNextX) + Registry.Members.src__engine__math_util_h.sqr(objToNextZ))))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw, SrcEngineMathUtil.atan2s(objToNextZ, objToNextX))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedTargetPitch, SrcEngineMathUtil.atan2s(objToNextXZ, -objToNextY))

	if F32(F32(F32(prevToNextX * objToNextX) + F32(prevToNextY * objToNextY)) + F32(prevToNextZ * objToNextZ)) <= 0 then
		o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = targetWaypoint

		if Rom.ReadS16(targetWaypoint + 8) == ObjectHelpersH.WAYPOINT_FLAGS_END then
			return ObjectHelpersH.PATH_REACHED_END
		else
			return ObjectHelpersH.PATH_REACHED_WAYPOINT
		end
	end

	return ObjectHelpersH.PATH_NONE
end

-- from src/game/object_helpers.c:chain_segment_init L2031-2039
function object_helpers.chain_segment_init(segment: ObjectHelpersH.ChainSegment)
	segment.posX = 0
	segment.posY = 0
	segment.posZ = 0

	segment.pitch = 0
	segment.yaw = 0
	segment.roll = 0
end

-- from src/game/object_helpers.c:random_f32_around_zero L2041-2043
function object_helpers.random_f32_around_zero(diameter: number): number
	diameter = F32(diameter)
	return F32(F32(SrcEngineBehaviorScript.random_float() * diameter) - F32(diameter / 2))
end

-- from src/game/object_helpers.c:obj_scale_random L2045-2048
function object_helpers.obj_scale_random(obj: GroupsTypesHPlus3.Object, rangeLength: number, minScale: number)
	rangeLength = F32(rangeLength)
	minScale = F32(minScale)
	const scale = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) + minScale)

	object_helpers.obj_scale_xyz(obj, scale, scale, scale)
end

-- from src/game/object_helpers.c:obj_translate_xyz_random L2050-2054
function object_helpers.obj_translate_xyz_random(obj: GroupsTypesHPlus3.Object, rangeLength: number)
	rangeLength = F32(rangeLength)
	const deltaX = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) - rangeLength * 0.5)
	const deltaY = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) - rangeLength * 0.5)
	const deltaZ = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) - rangeLength * 0.5)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX) + deltaX))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + deltaY))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ) + deltaZ))
end

-- from src/game/object_helpers.c:obj_translate_xz_random L2056-2059
function object_helpers.obj_translate_xz_random(obj: GroupsTypesHPlus3.Object, rangeLength: number)
	rangeLength = F32(rangeLength)
	const deltaX = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) - rangeLength * 0.5)
	const deltaZ = F32(F32(SrcEngineBehaviorScript.random_float() * rangeLength) - rangeLength * 0.5)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX) + deltaX))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ) + deltaZ))
end

-- from src/game/object_helpers.c:obj_build_vel_from_transform L2061-2070
function object_helpers.obj_build_vel_from_transform(obj: GroupsTypesHPlus3.Object)
	const up = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oUpVel)
	const left = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oLeftVel)
	const forward = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oForwardVel)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oVelX, F32(F32(F32(obj.transform[1][1] * up) + F32(obj.transform[2][1] * left)) + F32(obj.transform[3][1] * forward)))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oVelY, F32(F32(F32(obj.transform[1][2] * up) + F32(obj.transform[2][2] * left)) + F32(obj.transform[3][2] * forward)))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oVelZ, F32(F32(F32(obj.transform[1][3] * up) + F32(obj.transform[2][3] * left)) + F32(obj.transform[3][3] * forward)))
end

-- from src/game/object_helpers.c:cur_obj_set_pos_via_transform L2072-2078
function object_helpers.cur_obj_set_pos_via_transform()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.obj_build_transform_from_pos_and_angle(o, IncludeObjectFieldsH.O_PARENT_RELATIVE_POS_INDEX, IncludeObjectFieldsH.O_MOVE_ANGLE_INDEX)
	object_helpers.obj_build_vel_from_transform(o)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
end

-- from src/game/object_helpers.c:cur_obj_reflect_move_angle_off_wall L2080-2083
function object_helpers.cur_obj_reflect_move_angle_off_wall(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const wallAngle = buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle)
	const angle = S16(wallAngle - (S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) - S16(wallAngle)) + 0x8000)

	return angle
end

-- from src/game/object_helpers.c:cur_obj_spawn_particles L2085-2118
function object_helpers.cur_obj_spawn_particles(info: ObjectHelpersH.SpawnParticlesInfo)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local numParticles = info.count

	if ObjectListProcessor.gPrevFrameObjectCount > ObjectListProcessorH.OBJECT_POOL_CAPACITY - 90 and numParticles > 10 then
		numParticles = 10
	end

	if ObjectListProcessor.gPrevFrameObjectCount > ObjectListProcessorH.OBJECT_POOL_CAPACITY - 30 then
		numParticles = 0
	end

	for i = 0, numParticles - 1 do
		const scale = F32(F32(SrcEngineBehaviorScript.random_float() * F32(info.sizeRange * F32(0.1))) + F32(info.sizeBase * F32(0.1)))
		const particle = object_helpers.spawn_object(o, info.model, BehaviorIds.bhvWhitePuffExplosion)

		buffer.writei32(particle.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, info.bhvParam)
		buffer.writei32(particle.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oGravity, info.gravity)
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oDragStrength, info.dragStrength)

		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(particle.rawData, IncludeObjectFieldsH.oPosY) + info.offsetY)
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * info.forwardVelRange) + info.forwardVelBase)
		buffer.writef32(particle.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * info.velYRange) + info.velYBase)

		object_helpers.obj_scale_xyz(particle, scale, scale, scale)
	end
end

-- from src/game/object_helpers.c:obj_set_hitbox L2120-2137
function object_helpers.obj_set_hitbox(obj: GroupsTypesHPlus3.Object, hitbox: GroupsTypesHPlus3.ObjectHitbox)
	if not bit32.btest(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_30) then
		buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(obj.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_30))

		buffer.writeu32(obj.rawData, IncludeObjectFieldsH.oInteractType, hitbox.interactType)
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, hitbox.damageOrCoinValue)
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oHealth, hitbox.health)
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oNumLootCoins, hitbox.numLootCoins)

		object_helpers.cur_obj_become_tangible()
	end

	obj.hitboxRadius = F32(obj.header.gfx.scale[1] * hitbox.radius)
	obj.hitboxHeight = F32(obj.header.gfx.scale[2] * hitbox.height)
	obj.hurtboxRadius = F32(obj.header.gfx.scale[1] * hitbox.hurtboxRadius)
	obj.hurtboxHeight = F32(obj.header.gfx.scale[2] * hitbox.hurtboxHeight)
	obj.hitboxDownOffset = F32(obj.header.gfx.scale[2] * hitbox.downOffset)
end

-- from src/game/object_helpers.c:signum_positive L2139-2145
function object_helpers.signum_positive(x: number): number
	if x >= 0 then
		return 1
	else
		return -1
	end
end

-- from src/game/object_helpers.c:absf L2147-2153
function object_helpers.absf(x: number): number
	x = F32(x)
	if x >= 0 then
		return x
	else
		return -x
	end
end

-- from src/game/object_helpers.c:absi L2155-2161
function object_helpers.absi(x: number): number
	if x >= 0 then
		return x
	else
		return -x
	end
end

-- from src/game/object_helpers.c:cur_obj_wait_then_blink L2163-2179
function object_helpers.cur_obj_wait_then_blink(timeUntilBlinking: number, numBlinks: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local done = IncludePRUltratypesH.FALSE
	local timeBlinking: number

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= timeUntilBlinking then
		timeBlinking = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - timeUntilBlinking

		if timeBlinking % 2 ~= 0 then
			o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))

			if timeBlinking // 2 > numBlinks then
				done = IncludePRUltratypesH.TRUE
			end
		else
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	end

	return done
end

-- from src/game/object_helpers.c:cur_obj_is_mario_ground_pounding_platform L2181-2189
function object_helpers.cur_obj_is_mario_ground_pounding_platform(): number
	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == ObjectListProcessor.gCurrentObject then
		if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_GROUND_POUND_LAND then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:spawn_mist_particles L2191-2193
function object_helpers.spawn_mist_particles()
	BehaviorActions.spawn_mist_particles_variable(0, 0, 46)
end

-- from src/game/object_helpers.c:spawn_mist_particles_with_sound L2195-2198
function object_helpers.spawn_mist_particles_with_sound(soundMagic: number)
	BehaviorActions.spawn_mist_particles_variable(0, 0, 46)
	Registry.Members.src__game__spawn_sound.create_sound_spawner(soundMagic)
end

-- from src/game/object_helpers.c:cur_obj_push_mario_away L2200-2211
function object_helpers.cur_obj_push_mario_away(radius: number)
	radius = F32(radius)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const marioRelX = F32(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const marioRelZ = F32(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const marioDist = F32(math.sqrt(F32(Registry.Members.src__engine__math_util_h.sqr(marioRelX) + Registry.Members.src__engine__math_util_h.sqr(marioRelZ))))

	if marioDist < radius then
		const pushX = F32(F32(F32(radius - marioDist) / radius) * marioRelX)
		const pushZ = F32(F32(F32(radius - marioDist) / radius) * marioRelZ)

		LevelUpdate.gMarioStates[1].pos[1] = F32(LevelUpdate.gMarioStates[1].pos[1] + pushX)
		LevelUpdate.gMarioStates[1].pos[3] = F32(LevelUpdate.gMarioStates[1].pos[3] + pushZ)
	end
end

-- from src/game/object_helpers.c:cur_obj_push_mario_away_from_cylinder L2213-2223
function object_helpers.cur_obj_push_mario_away_from_cylinder(radius: number, extentY: number)
	radius = F32(radius)
	extentY = F32(extentY)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local marioRelY = F32(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))

	if marioRelY < 0 then
		marioRelY = -marioRelY
	end

	if marioRelY < extentY then
		object_helpers.cur_obj_push_mario_away(radius)
	end
end

-- from src/game/object_helpers.c:bhv_dust_smoke_loop L2225-2235
function object_helpers.bhv_dust_smoke_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ)))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmokeTimer) == 10 then
		object_helpers.obj_mark_for_deletion(o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSmokeTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSmokeTimer) + 1))
end

-- from src/game/object_helpers.c:stub_obj_helpers_2 L2237-2238
function object_helpers.stub_obj_helpers_2()
	-- Empty in the C source.
end

-- from src/game/object_helpers.c:cur_obj_set_action_table L2240-2245
function object_helpers.cur_obj_set_action_table(actionTable: { number }): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.ptrData[IncludeObjectFieldsH.oToxBoxActionTable + 1] = actionTable
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oToxBoxActionStep, 0)

	return actionTable[1]
end

-- from src/game/object_helpers.c:cur_obj_progress_action_table L2247-2261
function object_helpers.cur_obj_progress_action_table(): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const actionTable: { number } = o.ptrData[IncludeObjectFieldsH.oToxBoxActionTable + 1] :: { number }
	const nextActionIndex = buffer.readi32(o.rawData, IncludeObjectFieldsH.oToxBoxActionStep) + 1
	local nextAction: number

	if actionTable[nextActionIndex + 1] ~= IncludeObjectConstantsH.TOX_BOX_ACT_TABLE_END then
		nextAction = actionTable[nextActionIndex + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oToxBoxActionStep, buffer.readi32(o.rawData, IncludeObjectFieldsH.oToxBoxActionStep) + 1)
	else
		nextAction = actionTable[1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oToxBoxActionStep, 0)
	end

	return nextAction
end

-- from src/game/object_helpers.c:stub_obj_helpers_3 L2263-2264
function object_helpers.stub_obj_helpers_3(arg0: number, arg1: number)
	-- Empty in the C source.
end

-- from src/game/object_helpers.c:cur_obj_scale_over_time L2266-2281
function object_helpers.cur_obj_scale_over_time(a0: number, a1: number, sp10: number, sp14: number)
	sp10 = F32(sp10)
	sp14 = F32(sp14)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const sp4 = F32(sp14 - sp10)
	const sp0 = F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / a1)

	if bit32.btest(a0, 0x01) then
		o.header.gfx.scale[1] = F32(F32(sp4 * sp0) + sp10)
	end

	if bit32.btest(a0, 0x02) then
		o.header.gfx.scale[2] = F32(F32(sp4 * sp0) + sp10)
	end

	if bit32.btest(a0, 0x04) then
		o.header.gfx.scale[3] = F32(F32(sp4 * sp0) + sp10)
	end
end

-- from src/game/object_helpers.c:cur_obj_set_pos_to_home_with_debug L2283-2288
function object_helpers.cur_obj_set_pos_to_home_with_debug()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- DEBUG_PAGE_ENEMYINFO is 5 (gDebugInfo row 6)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + ObjectListProcessor.gDebugInfo[6][1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + ObjectListProcessor.gDebugInfo[6][2])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + ObjectListProcessor.gDebugInfo[6][3])
	object_helpers.cur_obj_scale(F32(F32(ObjectListProcessor.gDebugInfo[6][4] / 100) + 1))
end

-- from src/game/object_helpers.c:stub_obj_helpers_4 L2290-2291
function object_helpers.stub_obj_helpers_4()
	-- Empty in the C source.
end

-- from src/game/object_helpers.c:cur_obj_is_mario_on_platform L2293-2299
function object_helpers.cur_obj_is_mario_on_platform(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_shake_y_until L2301-2313
function object_helpers.cur_obj_shake_y_until(cycles: number, amount: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) % 2 ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - amount))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + amount))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == cycles * 2 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:jiggle_bbh_stair L2315-2322
function object_helpers.jiggle_bbh_stair(a0: number): number
	if a0 >= 4 or a0 < 0 then
		return IncludePRUltratypesH.TRUE
	end

	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + object_helpers.sBBHStairJiggleOffsets[a0 + 1])

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_call_action_function L2324-2327
function object_helpers.cur_obj_call_action_function(actionFunctions: { () -> () })
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const actionFunction = actionFunctions[buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1]

	actionFunction()
end

-- from src/game/object_helpers.c:spawn_star_with_no_lvl_exit L2329-2336
function object_helpers.spawn_star_with_no_lvl_exit(sp20: number, sp24: number): GroupsTypesHPlus3.Object
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp1C = object_helpers.spawn_object(o, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvSpawnedStarNoLevelExit)

	buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oSparkleSpawnUnk1B0, sp24)
	buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
	buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, sp20)

	return sp1C
end

-- from src/game/object_helpers.c:spawn_base_star_with_no_lvl_exit L2340-2342
function object_helpers.spawn_base_star_with_no_lvl_exit()
	object_helpers.spawn_star_with_no_lvl_exit(0, 0)
end

-- from src/game/object_helpers.c:bit_shift_left L2344-2346
function object_helpers.bit_shift_left(a0: number): number
	return object_helpers.sPowersOfTwo[a0 + 1]
end

-- from src/game/object_helpers.c:cur_obj_mario_far_away L2348-2359
function object_helpers.cur_obj_mario_far_away(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX))
	const dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY))
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ))
	const marioDistToHome = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2000 and marioDistToHome > 2000 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:is_mario_moving_fast_or_in_air L2361-2371
function object_helpers.is_mario_moving_fast_or_in_air(speedThreshold: number): number
	if LevelUpdate.gMarioStates[1].forwardVel > speedThreshold then
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(LevelUpdate.gMarioStates[1].action, IncludeSm64H.ACT_FLAG_AIR) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:is_item_in_array L2373-2383
function object_helpers.is_item_in_array(item: number, array: { number }): number
	item = S8(TruncS32(item))
	local index = 1

	while array[index] ~= -1 do
		if array[index] == item then
			return IncludePRUltratypesH.TRUE
		end

		index += 1
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:stub_obj_helpers_5 L2385-2386
function object_helpers.stub_obj_helpers_5()
	-- Empty in the C source.
end

-- from src/game/object_helpers.c:bhv_init_room L2388-2411
function object_helpers.bhv_init_room()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const currLevelNum: number = Registry.Members.src__game__area.gCurrLevelNum

	if object_helpers.is_item_in_array(S8(currLevelNum), object_helpers.sLevelsWithRooms) ~= 0 then
		const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_init_room_floor)
		const floor = Scratch.bhv_init_room_floor[1]

		if floor ~= nil then
			if floor.room ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oRoom, floor.room)
			else
				-- Floor probably belongs to a platform object. Try looking underneath it
				Registry.Members.src__engine__surface_collision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), F32(floorHeight - 100), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_init_room_floor)
				const lowerFloor = Scratch.bhv_init_room_floor[1]

				if lowerFloor ~= nil then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oRoom, lowerFloor.room)
				end
			end
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oRoom, -1)
	end
end

-- from src/game/object_helpers.c:cur_obj_enable_rendering_if_mario_in_room L2413-2437
function object_helpers.cur_obj_enable_rendering_if_mario_in_room()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const room = buffer.readi32(o.rawData, IncludeObjectFieldsH.oRoom)

	if room ~= -1 and ObjectListProcessor.gMarioCurrentRoom ~= 0 then
		local marioInRoom: number

		if ObjectListProcessor.gMarioCurrentRoom == room then
			marioInRoom = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 0) == room then
			marioInRoom = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 1) == room then
			marioInRoom = IncludePRUltratypesH.TRUE
		else
			marioInRoom = IncludePRUltratypesH.FALSE
		end

		if marioInRoom ~= IncludePRUltratypesH.FALSE then
			object_helpers.cur_obj_enable_rendering()
			o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM)))
			ObjectListProcessor.gNumRoomedObjectsInMarioRoom = S16(ObjectListProcessor.gNumRoomedObjectsInMarioRoom + 1)
		else
			object_helpers.cur_obj_disable_rendering()
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM))
			ObjectListProcessor.gNumRoomedObjectsNotInMarioRoom = S16(ObjectListProcessor.gNumRoomedObjectsNotInMarioRoom + 1)
		end
	end
end

-- from src/game/object_helpers.c:cur_obj_set_hitbox_and_die_if_attacked L2439-2461
function object_helpers.cur_obj_set_hitbox_and_die_if_attacked(hitbox: GroupsTypesHPlus3.ObjectHitbox, deathSound: number, noLootCoins: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local interacted = IncludePRUltratypesH.FALSE

	object_helpers.obj_set_hitbox(o, hitbox)

	if noLootCoins ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_WAS_ATTACKED) then
			object_helpers.spawn_mist_particles()
			object_helpers.obj_spawn_loot_yellow_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20)
			object_helpers.obj_mark_for_deletion(o)
			Registry.Members.src__game__spawn_sound.create_sound_spawner(deathSound)
		else
			interacted = IncludePRUltratypesH.TRUE
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	return interacted
end

-- from src/game/object_helpers.c:obj_explode_and_spawn_coins L2463-2473
function object_helpers.obj_explode_and_spawn_coins(mistParticleSize: number, sp1C: number)
	mistParticleSize = F32(mistParticleSize)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	BehaviorActions.spawn_mist_particles_variable(0, 0, mistParticleSize)
	BehaviorsBreakParticlesInc.spawn_triangle_break_particles(30, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3, 4)
	object_helpers.obj_mark_for_deletion(o)

	if sp1C == 1 then
		object_helpers.obj_spawn_loot_yellow_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20)
	elseif sp1C == 2 then
		object_helpers.obj_spawn_loot_blue_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20, 150)
	end
end

-- from src/game/object_helpers.c:obj_set_collision_data L2475-2477
function object_helpers.obj_set_collision_data(obj: GroupsTypesHPlus3.Object, segAddr: unknown)
	obj.collisionData = Memory.segmented_to_virtual(segAddr :: number)
end

-- from src/game/object_helpers.c:cur_obj_if_hit_wall_bounce_away L2479-2483
function object_helpers.cur_obj_if_hit_wall_bounce_away()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle))
	end
end

-- from src/game/object_helpers.c:cur_obj_hide_if_mario_far_away_y L2485-2493
function object_helpers.cur_obj_hide_if_mario_far_away_y(distY: number): number
	distY = F32(distY)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if object_helpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY))) < distY then
		object_helpers.cur_obj_unhide()

		return IncludePRUltratypesH.FALSE
	else
		object_helpers.cur_obj_hide()

		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/object_helpers.c:geo_offset_klepto_held_object L2495-2503
function object_helpers.geo_offset_klepto_held_object(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const translationRotation = node.next :: GroupsTypesHPlus3.GraphNodeTranslationRotation

		translationRotation.translation[1] = 300
		translationRotation.translation[2] = 300
		translationRotation.translation[3] = 0
	end

	return nil
end

-- from src/game/object_helpers.c:geo_offset_klepto_debug L2505-2516
function object_helpers.geo_offset_klepto_debug(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const translationRotation: GroupsTypesHPlus3.GraphNodeTranslationRotation = node.next :: GroupsTypesHPlus3.GraphNodeTranslationRotation
		const debugInfo: { { number } } = Registry.Members.src__game__object_list_processor.gDebugInfo

		-- DEBUG_PAGE_EFFECTINFO is row 4 of gDebugInfo
		translationRotation.translation[1] = debugInfo[5][1]
		translationRotation.translation[2] = debugInfo[5][2]
		translationRotation.translation[3] = debugInfo[5][3]
		translationRotation.rotation[1] = debugInfo[5][4]
		translationRotation.rotation[2] = debugInfo[5][5]
		translationRotation.rotation[3] = debugInfo[5][6]
	end

	return nil
end

-- from src/game/object_helpers.c:obj_is_hidden L2518-2524
function object_helpers.obj_is_hidden(obj: GroupsTypesHPlus3.Object): number
	if bit32.btest(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:enable_time_stop L2526-2528
function object_helpers.enable_time_stop()
	ObjectListProcessor.gTimeStopState = bit32.bor(ObjectListProcessor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ENABLED)
end

-- from src/game/object_helpers.c:disable_time_stop L2530-2532
function object_helpers.disable_time_stop()
	ObjectListProcessor.gTimeStopState = bit32.band(ObjectListProcessor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_ENABLED))
end

-- from src/game/object_helpers.c:set_time_stop_flags L2534-2536
function object_helpers.set_time_stop_flags(flags: number)
	ObjectListProcessor.gTimeStopState = bit32.bor(ObjectListProcessor.gTimeStopState, flags)
end

-- from src/game/object_helpers.c:clear_time_stop_flags L2538-2540
function object_helpers.clear_time_stop_flags(flags: number)
	ObjectListProcessor.gTimeStopState = bit32.band(ObjectListProcessor.gTimeStopState, bit32.bxor(flags, 0xFFFFFFFF))
end

-- from src/game/object_helpers.c:cur_obj_can_mario_activate_textbox L2542-2555
function object_helpers.cur_obj_can_mario_activate_textbox(radius: number, height: number, unused: number): number
	radius = F32(radius)
	height = F32(height)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500 then
		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
		const latDistToMario = object_helpers.lateral_dist_between_objects(o, marioObj)

		object_helpers.obj_angle_to_object(marioObj, o)

		if latDistToMario < radius and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) + 160) and buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + height) and not bit32.btest(LevelUpdate.gMarioStates[1].action, IncludeSm64H.ACT_FLAG_AIR) and MarioActionsCutscene.mario_ready_to_speak() ~= IncludePRUltratypesH.FALSE then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:cur_obj_can_mario_activate_textbox_2 L2557-2560
function object_helpers.cur_obj_can_mario_activate_textbox_2(radius: number, height: number): number
	radius = F32(radius)
	height = F32(height)
	return object_helpers.cur_obj_can_mario_activate_textbox(radius, height, 0x1000)
end

-- from src/game/object_helpers.c:cur_obj_end_dialog L2562-2569
function object_helpers.cur_obj_end_dialog(dialogFlags: number, dialogResult: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, S16(dialogResult))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))

	if not bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED) then
		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
	end
end

-- from src/game/object_helpers.c:cur_obj_update_dialog L2571-2654
function object_helpers.cur_obj_update_dialog(actionArg: number, dialogFlags: number, dialogID: number, unused: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local dialogResponse = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE
	const dialogState = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState)
	local interruptNow = false

	if dialogState == IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP then
		-- BUGFIX_DIALOG_TIME_STOP: wait for Mario to be ready to speak, and then enable time stop
		if MarioActionsCutscene.mario_ready_to_speak() ~= IncludePRUltratypesH.FALSE or LevelUpdate.gMarioState.action == IncludeSm64H.ACT_READING_NPC_DIALOG then
			ObjectListProcessor.gTimeStopState = bit32.bor(ObjectListProcessor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ENABLED)
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
			-- Fall through so that the action of Mario is interrupted immediately after time is stopped
			interruptNow = true
		end
	end

	if interruptNow or dialogState == IncludeObjectConstantsH.DIALOG_STATUS_INTERRUPT then
		if MarioActionsCutscene.set_mario_npc_dialog(actionArg) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
		end
	elseif dialogState == IncludeObjectConstantsH.DIALOG_STATUS_START_DIALOG then
		if bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_RESPONSE) then
			GroupsIngameMenuPlus1.create_dialog_box_with_response(dialogID)
		elseif bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT) then
			GroupsIngameMenuPlus1.create_dialog_box(dialogID)
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
	elseif dialogState == IncludeObjectConstantsH.DIALOG_STATUS_STOP_DIALOG then
		if bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_RESPONSE) then
			if GroupsIngameMenuPlus1.gDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
				object_helpers.cur_obj_end_dialog(dialogFlags, GroupsIngameMenuPlus1.gDialogResponse)
			end
		elseif bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT) then
			if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
				object_helpers.cur_obj_end_dialog(dialogFlags, GroupsIngameMenuPlus1.DIALOG_RESPONSE_NOT_DEFINED)
			end
		else
			object_helpers.cur_obj_end_dialog(dialogFlags, GroupsIngameMenuPlus1.DIALOG_RESPONSE_NOT_DEFINED)
		end
	elseif dialogState == IncludeObjectConstantsH.DIALOG_STATUS_DISABLE_TIME_STOP then
		if LevelUpdate.gMarioState.action ~= IncludeSm64H.ACT_READING_NPC_DIALOG or bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED) then
			ObjectListProcessor.gTimeStopState = bit32.band(ObjectListProcessor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_ENABLED))
			o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
			dialogResponse = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP)
		end
	else
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP)
	end

	return dialogResponse
end

-- from src/game/object_helpers.c:cur_obj_update_dialog_with_cutscene L2656-2743
function object_helpers.cur_obj_update_dialog_with_cutscene(actionArg: number, dialogFlags: number, cutsceneTable: number, dialogID: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local dialogResponse = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE
	local doneTurning = IncludePRUltratypesH.TRUE
	const dialogState = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState)
	local interruptNow = false

	if dialogState == IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP then
		-- BUGFIX_DIALOG_TIME_STOP: wait for Mario to be ready to speak, and then enable time stop
		if MarioActionsCutscene.mario_ready_to_speak() ~= IncludePRUltratypesH.FALSE or LevelUpdate.gMarioState.action == IncludeSm64H.ACT_READING_NPC_DIALOG then
			ObjectListProcessor.gTimeStopState = bit32.bor(ObjectListProcessor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ENABLED)
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE)
			-- Fall through so that the action of Mario is interrupted immediately after time is stopped
			interruptNow = true
		end
	end

	if interruptNow or dialogState == IncludeObjectConstantsH.DIALOG_STATUS_INTERRUPT then
		if bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO) then
			doneTurning = object_helpers.cur_obj_rotate_yaw_toward(object_helpers.obj_angle_to_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object), 0x800)

			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse) >= 33 then
				doneTurning = IncludePRUltratypesH.TRUE
			end
		end

		if MarioActionsCutscene.set_mario_npc_dialog(actionArg) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK and doneTurning ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, 0)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
		else
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse) + 1))
		end
	elseif dialogState == IncludeObjectConstantsH.DIALOG_STATUS_START_DIALOG then
		if cutsceneTable == GroupsTypesHPlus3.CUTSCENE_CAP_SWITCH_PRESS then
			const response = Registry.Members.src__game__camera.cutscene_object_without_dialog(cutsceneTable, o)

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, S16(response))

			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse) ~= 0 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
			end
		else
			const response = Registry.Members.src__game__camera.cutscene_object_with_dialog(cutsceneTable, o, dialogID)

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogResponse, S16(response))

			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse) ~= 0 then
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogState) + 1))
			end
		end
	elseif dialogState == IncludeObjectConstantsH.DIALOG_STATUS_STOP_DIALOG then
		if bit32.btest(dialogFlags, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED) then
			dialogResponse = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP)
		elseif LevelUpdate.gMarioState.action ~= IncludeSm64H.ACT_READING_NPC_DIALOG then
			ObjectListProcessor.gTimeStopState = bit32.band(ObjectListProcessor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_ENABLED))
			o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
			dialogResponse = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDialogResponse)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDialogState, IncludeObjectConstantsH.DIALOG_STATUS_ENABLE_TIME_STOP)
		else
			MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		end
	end

	return dialogResponse
end

-- from src/game/object_helpers.c:cur_obj_has_model L2745-2751
function object_helpers.cur_obj_has_model(modelID: number): number
	modelID = U16(TruncS32(modelID))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.header.gfx.sharedChild == Area.gLoadedGraphNodes[modelID + 1] then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_align_gfx_with_floor L2753-2771
function object_helpers.cur_obj_align_gfx_with_floor()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const position = Scratch.cur_obj_align_gfx_with_floor_position

	position[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	position[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	position[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

	Registry.Members.src__engine__surface_collision.find_floor(position[1], position[2], position[3], Scratch.cur_obj_align_gfx_with_floor_floor)

	const floor = Scratch.cur_obj_align_gfx_with_floor_floor[1]

	if floor ~= nil then
		const floorNormal = Scratch.cur_obj_align_gfx_with_floor_floorNormal

		floorNormal[1] = floor.normal.x
		floorNormal[2] = floor.normal.y
		floorNormal[3] = floor.normal.z

		SrcEngineMathUtil.mtxf_align_terrain_normal(o.transform, floorNormal, position, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)))
		o.header.gfx.throwMatrix = { o.transform }
	end
end

-- from src/game/object_helpers.c:mario_is_within_rectangle L2773-2783
function object_helpers.mario_is_within_rectangle(minX: number, maxX: number, minZ: number, maxZ: number): number
	minX = S16(TruncS32(minX))
	maxX = S16(TruncS32(maxX))
	minZ = S16(TruncS32(minZ))
	maxZ = S16(TruncS32(maxZ))
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX) < minX or maxX < buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosX) then
		return IncludePRUltratypesH.FALSE
	end

	if buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) < minZ or maxZ < buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosZ) then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/object_helpers.c:cur_obj_shake_screen L2785-2787
function object_helpers.cur_obj_shake_screen(shake: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	Registry.Members.src__game__camera.set_camera_shake_from_point(shake, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/object_helpers.c:obj_attack_collided_from_other_object L2789-2806
function object_helpers.obj_attack_collided_from_other_object(obj: GroupsTypesHPlus3.Object): number
	local touchedOtherObject = IncludePRUltratypesH.FALSE
	const numCollidedObjs = obj.numCollidedObjs

	if numCollidedObjs ~= 0 then
		const other = obj.collidedObjs[1] :: GroupsTypesHPlus3.Object

		if other ~= ObjectListProcessor.gMarioObject then
			buffer.writei32(other.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(other.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.ATTACK_PUNCH, InteractionH.INT_STATUS_WAS_ATTACKED, InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_TOUCHED_BOB_OMB)))
			touchedOtherObject = IncludePRUltratypesH.TRUE
		end
	end

	return touchedOtherObject
end

-- from src/game/object_helpers.c:cur_obj_was_attacked_or_ground_pounded L2808-2822
function object_helpers.cur_obj_was_attacked_or_ground_pounded(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	local attacked = IncludePRUltratypesH.FALSE

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) and bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_WAS_ATTACKED) then
		attacked = IncludePRUltratypesH.TRUE
	end

	if object_helpers.cur_obj_is_mario_ground_pounding_platform() ~= IncludePRUltratypesH.FALSE then
		attacked = IncludePRUltratypesH.TRUE
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	return attacked
end

-- from src/game/object_helpers.c:obj_copy_behavior_params L2824-2827
function object_helpers.obj_copy_behavior_params(dst: GroupsTypesHPlus3.Object, src: GroupsTypesHPlus3.Object)
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(src.rawData, IncludeObjectFieldsH.oBhvParams))
	buffer.writei32(dst.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(src.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
end

-- from src/game/object_helpers.c:cur_obj_init_animation_and_anim_frame L2829-2832
function object_helpers.cur_obj_init_animation_and_anim_frame(animIndex: number, animFrame: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	object_helpers.cur_obj_init_animation_with_sound(animIndex)
	o.header.gfx.animInfo.animFrame = S16(animFrame)
end

-- from src/game/object_helpers.c:cur_obj_init_animation_and_check_if_near_end L2834-2837
function object_helpers.cur_obj_init_animation_and_check_if_near_end(animIndex: number): number
	object_helpers.cur_obj_init_animation_with_sound(animIndex)

	return object_helpers.cur_obj_check_if_near_animation_end()
end

-- from src/game/object_helpers.c:cur_obj_init_animation_and_extend_if_at_end L2839-2842
function object_helpers.cur_obj_init_animation_and_extend_if_at_end(animIndex: number)
	object_helpers.cur_obj_init_animation_with_sound(animIndex)
	object_helpers.cur_obj_extend_animation_if_at_end()
end

-- from src/game/object_helpers.c:cur_obj_check_grabbed_mario L2844-2852
function object_helpers.cur_obj_check_grabbed_mario(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_GRABBED_MARIO) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oKingBobombUnk88, 1)
		object_helpers.cur_obj_become_intangible()

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/object_helpers.c:player_performed_grab_escape_action L2854-2872
function object_helpers.player_performed_grab_escape_action(): number
	local result = IncludePRUltratypesH.FALSE
	const controller: GroupsTypesHPlus3.Controller = Registry.Members.src__game__game_init.gPlayer1Controller
	const aButton: number = Registry.Members.include__PR__os_h.A_BUTTON

	if controller.stickMag < 30 then
		grabReleaseState = 0
	end

	if grabReleaseState == 0 and controller.stickMag > 40 then
		grabReleaseState = 1
		result = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(controller.buttonPressed, aButton) then
		result = IncludePRUltratypesH.TRUE
	end

	return result
end

-- from src/game/object_helpers.c:cur_obj_unused_play_footstep_sound L2874-2878
function object_helpers.cur_obj_unused_play_footstep_sound(animFrame1: number, animFrame2: number, sound: number)
	if object_helpers.cur_obj_check_anim_frame(animFrame1) ~= 0 or object_helpers.cur_obj_check_anim_frame(animFrame2) ~= 0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(sound)
	end
end

-- from src/game/object_helpers.c:enable_time_stop_including_mario L2880-2883
function object_helpers.enable_time_stop_including_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectListProcessor.gTimeStopState = bit32.bor(ObjectListProcessor.gTimeStopState, bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))
end

-- from src/game/object_helpers.c:disable_time_stop_including_mario L2885-2888
function object_helpers.disable_time_stop_including_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectListProcessor.gTimeStopState = bit32.band(ObjectListProcessor.gTimeStopState, bit32.bnot(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS)))
	o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
end

-- from src/game/object_helpers.c:cur_obj_check_interacted L2890-2897
function object_helpers.cur_obj_check_interacted(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/object_helpers.c:cur_obj_spawn_loot_blue_coin L2899-2904
function object_helpers.cur_obj_spawn_loot_blue_coin()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins) >= 5 then
		object_helpers.spawn_object(o, IncludeModelIdsH.MODEL_BLUE_COIN, BehaviorIds.bhvSpawnedBlueCoin)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins) - 5))
	end
end

-- from src/game/object_helpers.c:cur_obj_spawn_star_at_y_offset L2907-2912
function object_helpers.cur_obj_spawn_star_at_y_offset(targetX: number, targetY: number, targetZ: number, offsetY: number)
	targetX = F32(targetX)
	targetY = F32(targetY)
	targetZ = F32(targetZ)
	offsetY = F32(offsetY)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const debugInfo: number = Registry.Members.src__game__object_list_processor.gDebugInfo[6][1]
	const objectPosY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(offsetY + debugInfo))

	Registry.Members.src__game__behaviors__spawn_star_inc.spawn_default_star(targetX, targetY, targetZ)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, objectPosY)
end

return object_helpers
