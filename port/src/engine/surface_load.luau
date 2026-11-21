--!strict
--!optimize 2

--[[
	Port of src/engine/surface_load.c.

	Design Notes
		TerrainData/RoomData pointers (terrain data, vertex data, rooms, macro objects, environment regions) are byte offsets into
		Rom.Memory; `TerrainData **data` is a one element table holding the offset, a module level scratch where the C takes the
		address of a local. A pointer step of n elements is 2 * n (s16) or n (s8).
		The surface and node pools are Luau tables filled by alloc_surface_pools instead of main_pool_alloc blocks.
		Object fields are read through Object.rawData with the byte offsets of object_fields.h (buffer.readf32(rawData, oPosX)).
		A behavior is an id of rom/behavior_ids, so segmented_to_virtual(bhvDDDWarp) is the id itself.
		The vertexData[600] stack array of load_object_collision_model is Rom stack memory (PushStack/PopStack).
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const Rom = require("../rom/rom")
const BehaviorIds = require("../rom/behavior_ids")
const SrcGameMemory = require("../game/memory")

const SurfaceLoadH = require("./surface_load_h")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const SrcGameMacroSpecialObjects = require("../game/macro_special_objects")
const SrcGameObjectListProcessor = require("../game/object_list_processor")
const SrcGameObjectListProcessorH = require("../game/object_list_processor_h")
const SurfaceCollisionH = require("./surface_collision_h")
const IncludeMacrosH = require("../../include/macros_h")
const SrcGameObjectHelpers = require("../game/object_helpers")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C stack locals whose address is passed down: pointer to the terrain data cursor (&data) and to the room cursor (&surfaceRooms)
const DataPointer = { 0 }
const RoomsPointer: { number? } = {}

-- C stack local of load_object_collision_model: pointer to the collision data cursor (&collisionData)
const CollisionPointer = { 0 }

-- C stack local of transform_object_vertices: the object's transformation with its scale applied
const ObjectMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
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

-- from src/engine/surface_load.c:data
const surface_load = {
	-- from src/engine/surface_load.c:unused8038BE90 L16-16
	unused8038BE90 = 0,
	-- from src/engine/surface_load.c:gStaticSurfacePartition L22-22
	gStaticSurfacePartition = {
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
		} :: { { { SurfaceLoadH.SurfaceNode } } },
	-- from src/engine/surface_load.c:gDynamicSurfacePartition L23-23
	gDynamicSurfacePartition = {
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
			{
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
				{ { next = nil, surface = nil }, { next = nil, surface = nil }, { next = nil, surface = nil } },
			},
		} :: { { { SurfaceLoadH.SurfaceNode } } },
	-- from src/engine/surface_load.c:sSurfaceNodePool L28-28
	sSurfaceNodePool = {} :: { SurfaceLoadH.SurfaceNode },
	-- from src/engine/surface_load.c:sSurfacePool L29-29
	sSurfacePool = {} :: { GroupsTypesHPlus3Types.Surface },
	-- from src/engine/surface_load.c:sSurfacePoolSize L34-34
	sSurfacePoolSize = 0,
	-- from src/engine/surface_load.c:unused8038EEA8 L36-36
	unused8038EEA8 = buffer.create(48),
}

Registry.Register("src__engine__surface_load", surface_load)

-- from src/engine/surface_load.c:alloc_surface_node L41-52
function surface_load.alloc_surface_node(): SurfaceLoadH.SurfaceNode
	const node = surface_load.sSurfaceNodePool[SrcGameObjectListProcessor.gSurfaceNodesAllocated + 1]

	SrcGameObjectListProcessor.gSurfaceNodesAllocated += 1

	node.next = nil

	if SrcGameObjectListProcessor.gSurfaceNodesAllocated >= 7000 then
		IncludeMacrosH.CN_DEBUG_PRINTF(" mcMakeBGCheckList OVERFLOW\n")
	end

	return node
end

-- from src/engine/surface_load.c:alloc_surface L58-74
function surface_load.alloc_surface(): GroupsTypesHPlus3Types.Surface
	const surface = surface_load.sSurfacePool[SrcGameObjectListProcessor.gSurfacesAllocated + 1]

	SrcGameObjectListProcessor.gSurfacesAllocated += 1

	if SrcGameObjectListProcessor.gSurfacesAllocated >= surface_load.sSurfacePoolSize then
		IncludeMacrosH.CN_DEBUG_PRINTF(" mcMakeBGCheckData OVERFLOW\n")
	end

	surface.type_ = 0
	surface.force = 0
	surface.flags = 0
	surface.room = 0
	surface.object = nil

	return surface
end

-- from src/engine/surface_load.c:clear_spatial_partition L79-89
function surface_load.clear_spatial_partition(cells: { { { SurfaceLoadH.SurfaceNode } } })
	local cellIndex = 0
	local i = SurfaceLoadH.NUM_CELLS * SurfaceLoadH.NUM_CELLS

	while i ~= 0 do
		i -= 1

		const cell = cells[cellIndex // SurfaceLoadH.NUM_CELLS + 1][cellIndex % SurfaceLoadH.NUM_CELLS + 1]

		cell[SurfaceLoadH.SPATIAL_PARTITION_FLOORS + 1].next = nil
		cell[SurfaceLoadH.SPATIAL_PARTITION_CEILS + 1].next = nil
		cell[SurfaceLoadH.SPATIAL_PARTITION_WALLS + 1].next = nil

		cellIndex += 1
	end
end

-- from src/engine/surface_load.c:clear_static_surfaces L94-96
function surface_load.clear_static_surfaces()
	surface_load.clear_spatial_partition(surface_load.gStaticSurfacePartition)
end

-- from src/engine/surface_load.c:add_surface_to_cell L105-157
function surface_load.add_surface_to_cell(dynamic: number, cellX: number, cellZ: number, surface: GroupsTypesHPlus3Types.Surface)
	dynamic = S16(TruncS32(dynamic))
	cellX = S16(TruncS32(cellX))
	cellZ = S16(TruncS32(cellZ))
	const newNode = surface_load.alloc_surface_node()
	local list: SurfaceLoadH.SurfaceNode
	local surfacePriority: number
	local priority: number
	local sortDir: number
	local listIndex: number

	if surface.normal.y > 0.01 then
		listIndex = SurfaceLoadH.SPATIAL_PARTITION_FLOORS
		sortDir = 1 -- highest to lowest, then insertion order
	elseif surface.normal.y < -0.01 then
		listIndex = SurfaceLoadH.SPATIAL_PARTITION_CEILS
		sortDir = -1 -- lowest to highest, then insertion order
	else
		listIndex = SurfaceLoadH.SPATIAL_PARTITION_WALLS
		sortDir = 0 -- insertion order

		if surface.normal.x < -0.707 or surface.normal.x > 0.707 then
			surface.flags = S8(bit32.bor(surface.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_X_PROJECTION))
		end
	end

	--! (Surface Cucking) Surfaces are sorted by the height of their first
	--  vertex. Since vertices aren't ordered by height, this causes many
	--  lower triangles to be sorted higher. This worsens surface cucking since
	--  many functions only use the first triangle in surface order that fits,
	--  missing higher surfaces.
	--  upperY would be a better sort method.
	surfacePriority = S16(surface.vertex1[2] * sortDir)

	newNode.surface = surface

	if dynamic ~= 0 then
		list = surface_load.gDynamicSurfacePartition[cellZ + 1][cellX + 1][listIndex + 1]
	else
		list = surface_load.gStaticSurfacePartition[cellZ + 1][cellX + 1][listIndex + 1]
	end

	-- Loop until we find the appropriate place for the surface in the list.
	while list.next ~= nil do
		priority = S16((list.next.surface :: GroupsTypesHPlus3Types.Surface).vertex1[2] * sortDir)

		if surfacePriority > priority then
			break
		end

		list = list.next
	end

	newNode.next = list.next
	list.next = newNode
end

-- from src/engine/surface_load.c:min_3 L162-172
function surface_load.min_3(a0: number, a1: number, a2: number): number
	a0 = S16(TruncS32(a0))
	a1 = S16(TruncS32(a1))
	a2 = S16(TruncS32(a2))
	if a1 < a0 then
		a0 = a1
	end

	if a2 < a0 then
		a0 = a2
	end

	return a0
end

-- from src/engine/surface_load.c:max_3 L177-187
function surface_load.max_3(a0: number, a1: number, a2: number): number
	a0 = S16(TruncS32(a0))
	a1 = S16(TruncS32(a1))
	a2 = S16(TruncS32(a2))
	if a1 > a0 then
		a0 = a1
	end

	if a2 > a0 then
		a0 = a2
	end

	return a0
end

-- from src/engine/surface_load.c:lower_cell_index L194-219
function surface_load.lower_cell_index(coord: number): number
	local index: number

	-- Move from range [-0x2000, 0x2000) to [0, 0x4000)
	coord = S16(coord + SurfaceCollisionH.LEVEL_BOUNDARY_MAX)

	if coord < 0 then
		coord = 0
	end

	-- [0, 16)
	index = S16(coord // SurfaceCollisionH.CELL_SIZE)

	-- Include extra cell if close to boundary
	--! Some wall checks are larger than the buffer, meaning wall checks can
	--  miss walls that are near a cell border.
	if math.fmod(coord, SurfaceCollisionH.CELL_SIZE) < 50 then
		index = S16(index - 1)
	end

	if index < 0 then
		index = 0
	end

	-- Potentially > 15, but since the upper index is <= 15, not exploitable
	return index
end

-- from src/engine/surface_load.c:upper_cell_index L226-251
function surface_load.upper_cell_index(coord: number): number
	local index: number

	-- Move from range [-0x2000, 0x2000) to [0, 0x4000)
	coord = S16(coord + SurfaceCollisionH.LEVEL_BOUNDARY_MAX)

	if coord < 0 then
		coord = 0
	end

	-- [0, 16)
	index = S16(coord // SurfaceCollisionH.CELL_SIZE)

	-- Include extra cell if close to boundary
	--! Some wall checks are larger than the buffer, meaning wall checks can
	--  miss walls that are near a cell border.
	if math.fmod(coord, SurfaceCollisionH.CELL_SIZE) > SurfaceCollisionH.CELL_SIZE - 50 then
		index = S16(index + 1)
	end

	if index > SurfaceLoadH.NUM_CELLS_INDEX then
		index = SurfaceLoadH.NUM_CELLS_INDEX
	end

	-- Potentially < 0, but since lower index is >= 0, not exploitable
	return index
end

-- from src/engine/surface_load.c:add_surface L260-286
function surface_load.add_surface(surface: GroupsTypesHPlus3Types.Surface, dynamic: number)
	local minX: number
	local minZ: number
	local maxX: number
	local maxZ: number

	local minCellX: number
	local minCellZ: number
	local maxCellX: number
	local maxCellZ: number

	minX = surface_load.min_3(surface.vertex1[1], surface.vertex2[1], surface.vertex3[1])
	minZ = surface_load.min_3(surface.vertex1[3], surface.vertex2[3], surface.vertex3[3])
	maxX = surface_load.max_3(surface.vertex1[1], surface.vertex2[1], surface.vertex3[1])
	maxZ = surface_load.max_3(surface.vertex1[3], surface.vertex2[3], surface.vertex3[3])

	minCellX = surface_load.lower_cell_index(minX)
	maxCellX = surface_load.upper_cell_index(maxX)
	minCellZ = surface_load.lower_cell_index(minZ)
	maxCellZ = surface_load.upper_cell_index(maxZ)

	for cellZ = minCellZ, maxCellZ do
		for cellX = minCellX, maxCellX do
			surface_load.add_surface_to_cell(dynamic, cellX, cellZ, surface)
		end
	end
end

-- from src/engine/surface_load.c:stub_surface_load_1 L288-289
function surface_load.stub_surface_load_1()
	return
end

-- from src/engine/surface_load.c:read_surface_data L296-378
function surface_load.read_surface_data(vertexData: number, vertexIndices: { number }): GroupsTypesHPlus3Types.Surface?
	local surface: GroupsTypesHPlus3Types.Surface
	local x1: number
	local y1: number
	local z1: number
	local x2: number
	local y2: number
	local z2: number
	local x3: number
	local y3: number
	local z3: number
	local maxY: number
	local minY: number
	local nx: number
	local ny: number
	local nz: number
	local mag: number
	local offset1: number
	local offset2: number
	local offset3: number

	offset1 = S16(3 * Rom.ReadS16(vertexIndices[1]))
	offset2 = S16(3 * Rom.ReadS16(vertexIndices[1] + 2 * 1))
	offset3 = S16(3 * Rom.ReadS16(vertexIndices[1] + 2 * 2))

	x1 = Rom.ReadS16(vertexData + 2 * (offset1 + 0))
	y1 = Rom.ReadS16(vertexData + 2 * (offset1 + 1))
	z1 = Rom.ReadS16(vertexData + 2 * (offset1 + 2))

	x2 = Rom.ReadS16(vertexData + 2 * (offset2 + 0))
	y2 = Rom.ReadS16(vertexData + 2 * (offset2 + 1))
	z2 = Rom.ReadS16(vertexData + 2 * (offset2 + 2))

	x3 = Rom.ReadS16(vertexData + 2 * (offset3 + 0))
	y3 = Rom.ReadS16(vertexData + 2 * (offset3 + 1))
	z3 = Rom.ReadS16(vertexData + 2 * (offset3 + 2))

	-- (v2 - v1) x (v3 - v2)
	nx = F32(S32((y2 - y1) * (z3 - z2) - (z2 - z1) * (y3 - y2)))
	ny = F32(S32((z2 - z1) * (x3 - x2) - (x2 - x1) * (z3 - z2)))
	nz = F32(S32((x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2)))
	mag = F32(math.sqrt(F32(F32(F32(nx * nx) + F32(ny * ny)) + F32(nz * nz))))

	-- Could have used min_3 and max_3 for this...
	minY = y1

	if y2 < minY then
		minY = y2
	end

	if y3 < minY then
		minY = y3
	end

	maxY = y1

	if y2 > maxY then
		maxY = y2
	end

	if y3 > maxY then
		maxY = y3
	end

	-- Checking to make sure no DIV/0
	if mag < 0.0001 then
		return nil
	end

	mag = F32(1.0 / mag)
	nx = F32(nx * mag)
	ny = F32(ny * mag)
	nz = F32(nz * mag)

	surface = surface_load.alloc_surface()

	surface.vertex1[1] = S16(x1)
	surface.vertex2[1] = S16(x2)
	surface.vertex3[1] = S16(x3)

	surface.vertex1[2] = S16(y1)
	surface.vertex2[2] = S16(y2)
	surface.vertex3[2] = S16(y3)

	surface.vertex1[3] = S16(z1)
	surface.vertex2[3] = S16(z2)
	surface.vertex3[3] = S16(z3)

	surface.normal.x = nx
	surface.normal.y = ny
	surface.normal.z = nz

	surface.originOffset = -F32(F32(F32(nx * x1) + F32(ny * y1)) + F32(nz * z1))

	surface.lowerY = S16(minY - 5)
	surface.upperY = S16(maxY + 5)

	return surface
end

-- from src/engine/surface_load.c:surface_has_force L384-403
function surface_load.surface_has_force(surfaceType: number): number
	surfaceType = S16(TruncS32(surfaceType))
	local hasForce = IncludePRUltratypesH.FALSE

	if surfaceType == IncludeSurfaceTerrainsH.SURFACE_0004 -- Unused
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_FLOWING_WATER
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_DEEP_MOVING_QUICKSAND
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_MOVING_QUICKSAND
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_MOVING_QUICKSAND
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_HORIZONTAL_WIND
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_MOVING_QUICKSAND
	then
		hasForce = IncludePRUltratypesH.TRUE
	end

	return hasForce
end

-- from src/engine/surface_load.c:surf_has_no_cam_collision L409-425
function surface_load.surf_has_no_cam_collision(surfaceType: number): number
	surfaceType = S16(TruncS32(surfaceType))
	local flags = 0

	if surfaceType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COLLISION
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COLLISION_77 -- Unused
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_VERY_SLIPPERY
		or surfaceType == IncludeSurfaceTerrainsH.SURFACE_SWITCH
	then
		flags = IncludeSurfaceTerrainsH.SURFACE_FLAG_NO_CAM_COLLISION
	end

	return flags
end

-- from src/engine/surface_load.c:load_static_surfaces L431-468
function surface_load.load_static_surfaces(data: { number }, vertexData: number, surfaceType: number, surfaceRooms: { number? })
	surfaceType = S16(TruncS32(surfaceType))
	local numSurfaces: number
	local room = 0
	const hasForce = S16(surface_load.surface_has_force(surfaceType))
	const flags = S16(surface_load.surf_has_no_cam_collision(surfaceType))

	numSurfaces = Rom.ReadS16(data[1])
	data[1] += 2

	for i = 0, numSurfaces - 1 do
		const roomPointer = surfaceRooms[1]

		if roomPointer ~= nil then
			room = Rom.ReadS8(roomPointer)
			surfaceRooms[1] = roomPointer + 1
		end

		const surface = surface_load.read_surface_data(vertexData, data)

		if surface ~= nil then
			surface.room = room
			surface.type_ = surfaceType
			surface.flags = S8(flags)

			if hasForce ~= 0 then
				surface.force = Rom.ReadS16(data[1] + 2 * 3)
			else
				surface.force = 0
			end

			surface_load.add_surface(surface, IncludePRUltratypesH.FALSE)
		end

		data[1] += 2 * 3

		if hasForce ~= 0 then
			data[1] += 2
		end
	end
end

-- from src/engine/surface_load.c:read_vertex_data L473-485
function surface_load.read_vertex_data(data: { number }): number
	local numVertices: number
	local vertexData: number

	numVertices = Rom.ReadS16(data[1])
	data[1] += 2

	vertexData = data[1]
	data[1] += 2 * (3 * numVertices)

	return vertexData
end

-- from src/engine/surface_load.c:load_environmental_regions L490-516
function surface_load.load_environmental_regions(data: { number })
	SrcGameObjectListProcessor.gEnvironmentRegions = data[1]

	const numRegions = Rom.ReadS16(data[1])

	data[1] += 2

	if numRegions > 20 then
		IncludeMacrosH.CN_DEBUG_PRINTF("Error Water Over\n")
	end

	for i = 0, numRegions - 1 do
		local height: number

		-- val, loX, hiX, loZ, hiZ
		data[1] += 2 * 5

		height = Rom.ReadS16(data[1])
		data[1] += 2

		SrcGameObjectListProcessor.gEnvironmentLevels[i + 1] = height
	end
end

-- from src/engine/surface_load.c:alloc_surface_pools L521-528
function surface_load.alloc_surface_pools()
	const nodePool: { SurfaceLoadH.SurfaceNode } = {}
	const surfacePool: { GroupsTypesHPlus3Types.Surface } = {}

	surface_load.sSurfacePoolSize = 2300

	for i = 1, 7000 do
		nodePool[i] = { next = nil, surface = nil }
	end

	for i = 1, surface_load.sSurfacePoolSize do
		surfacePool[i] = {
			type_ = 0,
			force = 0,
			flags = 0,
			room = 0,
			lowerY = 0,
			upperY = 0,
			vertex1 = { 0, 0, 0 },
			vertex2 = { 0, 0, 0 },
			vertex3 = { 0, 0, 0 },
			normal = { x = 0, y = 0, z = 0 },
			originOffset = 0,
			object = nil,
		}
	end

	surface_load.sSurfaceNodePool = nodePool
	surface_load.sSurfacePool = surfacePool

	SrcGameObjectListProcessor.gCCMEnteredSlide = 0
	GroupsIngameMenuPlus1.reset_red_coins_collected()
end

-- from src/engine/surface_load.c:load_area_terrain L585-638
function surface_load.load_area_terrain(index: number, data: number, surfaceRooms: number?, macroObjects: number?)
	index = S16(TruncS32(index))
	local terrainLoadType: number
	local vertexData = 0

	DataPointer[1] = data
	RoomsPointer[1] = surfaceRooms

	-- Initialize the data for this.
	SrcGameObjectListProcessor.gEnvironmentRegions = nil
	surface_load.unused8038BE90 = 0
	SrcGameObjectListProcessor.gSurfaceNodesAllocated = 0
	SrcGameObjectListProcessor.gSurfacesAllocated = 0

	surface_load.clear_static_surfaces()

	-- A while loop iterating through each section of the level data. Sections of data
	-- are prefixed by a terrain "type." This type is reused for surfaces as the surface
	-- type.
	while true do
		terrainLoadType = Rom.ReadS16(DataPointer[1])
		DataPointer[1] += 2

		if IncludeSurfaceTerrainsH.TERRAIN_LOAD_IS_SURFACE_TYPE_LOW(terrainLoadType) ~= 0 then
			surface_load.load_static_surfaces(DataPointer, vertexData, terrainLoadType, RoomsPointer)
		elseif terrainLoadType == IncludeSurfaceTerrainsH.TERRAIN_LOAD_VERTICES then
			vertexData = surface_load.read_vertex_data(DataPointer)
		elseif terrainLoadType == IncludeSurfaceTerrainsH.TERRAIN_LOAD_OBJECTS then
			SrcGameMacroSpecialObjects.spawn_special_objects(index, DataPointer)
		elseif terrainLoadType == IncludeSurfaceTerrainsH.TERRAIN_LOAD_ENVIRONMENT then
			surface_load.load_environmental_regions(DataPointer)
		elseif terrainLoadType == IncludeSurfaceTerrainsH.TERRAIN_LOAD_CONTINUE then
			continue
		elseif terrainLoadType == IncludeSurfaceTerrainsH.TERRAIN_LOAD_END then
			break
		elseif IncludeSurfaceTerrainsH.TERRAIN_LOAD_IS_SURFACE_TYPE_HIGH(terrainLoadType) ~= 0 then
			surface_load.load_static_surfaces(DataPointer, vertexData, terrainLoadType, RoomsPointer)
		else
			IncludeMacrosH.CN_DEBUG_PRINTF(" BGCode Error \n")
		end
	end

	if macroObjects ~= nil and Rom.ReadS16(macroObjects) ~= -1 then
		-- If the first macro object presetID is within the range [0, 29].
		-- Generally an early spawning method, every object is in BBH (the first level).
		if 0 <= Rom.ReadS16(macroObjects) and Rom.ReadS16(macroObjects) < 30 then
			SrcGameMacroSpecialObjects.spawn_macro_objects_hardcoded(index, macroObjects)
		-- A more general version that can spawn more objects.
		else
			SrcGameMacroSpecialObjects.spawn_macro_objects(index, macroObjects)
		end
	end

	SrcGameObjectListProcessor.gNumStaticSurfaceNodes = SrcGameObjectListProcessor.gSurfaceNodesAllocated
	SrcGameObjectListProcessor.gNumStaticSurfaces = SrcGameObjectListProcessor.gSurfacesAllocated
end

-- from src/engine/surface_load.c:clear_dynamic_surfaces L643-650
function surface_load.clear_dynamic_surfaces()
	if not bit32.btest(SrcGameObjectListProcessor.gTimeStopState, SrcGameObjectListProcessorH.TIME_STOP_ACTIVE) then
		SrcGameObjectListProcessor.gSurfacesAllocated = SrcGameObjectListProcessor.gNumStaticSurfaces
		SrcGameObjectListProcessor.gSurfaceNodesAllocated = SrcGameObjectListProcessor.gNumStaticSurfaceNodes

		surface_load.clear_spatial_partition(surface_load.gDynamicSurfacePartition)
	end
end

-- from src/engine/surface_load.c:unused_80383604 L652-653
function surface_load.unused_80383604()
	return
end

-- from src/engine/surface_load.c:transform_object_vertices L658-693
function surface_load.transform_object_vertices(data: { number }, vertexData: number)
	local vertices: number
	local vx: number
	local vy: number
	local vz: number
	local numVertices: number

	const currentObject = SrcGameObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3Types.Object
	const m = ObjectMatrix
	const objectTransform = currentObject.transform -- &gCurrentObject->transform, a pointer to the Mat4 stored in the object

	numVertices = Rom.ReadS16(data[1])
	data[1] += 2

	vertices = data[1]

	if currentObject.header.gfx.throwMatrix == nil then
		currentObject.header.gfx.throwMatrix = { objectTransform }
		SrcGameObjectHelpers.obj_build_transform_from_pos_and_angle(currentObject, IncludeObjectFieldsH.O_POS_INDEX, IncludeObjectFieldsH.O_FACE_ANGLE_INDEX)
	end

	SrcGameObjectHelpers.obj_apply_scale_to_matrix(currentObject, m, objectTransform)

	-- Go through all vertices, rotating and translating them to transform the object.
	while numVertices ~= 0 do
		numVertices -= 1

		vx = Rom.ReadS16(vertices)
		vertices += 2
		vy = Rom.ReadS16(vertices)
		vertices += 2
		vz = Rom.ReadS16(vertices)
		vertices += 2

		--! No bounds check on vertex data
		Rom.WriteS16(vertexData, S16(TruncS32(F32(F32(F32(F32(vx * m[1][1]) + F32(vy * m[2][1])) + F32(vz * m[3][1])) + m[4][1]))))
		vertexData += 2
		Rom.WriteS16(vertexData, S16(TruncS32(F32(F32(F32(F32(vx * m[1][2]) + F32(vy * m[2][2])) + F32(vz * m[3][2])) + m[4][2]))))
		vertexData += 2
		Rom.WriteS16(vertexData, S16(TruncS32(F32(F32(F32(F32(vx * m[1][3]) + F32(vy * m[2][3])) + F32(vz * m[3][3])) + m[4][3]))))
		vertexData += 2
	end

	data[1] = vertices
end

-- from src/engine/surface_load.c:load_object_surfaces L698-749
function surface_load.load_object_surfaces(data: { number }, vertexData: number)
	local surfaceType: number
	local numSurfaces: number
	local hasForce: number
	local flags: number
	local room: number

	surfaceType = Rom.ReadS16(data[1])
	data[1] += 2

	numSurfaces = Rom.ReadS16(data[1])
	data[1] += 2

	hasForce = S16(surface_load.surface_has_force(S16(surfaceType)))

	flags = S16(surface_load.surf_has_no_cam_collision(S16(surfaceType)))
	flags = S16(bit32.bor(flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_DYNAMIC))

	-- The DDD warp is initially loaded at the origin and moved to the proper
	-- position in paintings.c and doesn't update its room, so set it here.
	if (SrcGameObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3Types.Object).behavior == SrcGameMemory.segmented_to_virtual(BehaviorIds.bhvDDDWarp) then
		room = 5
	else
		room = 0
	end

	for i = 0, numSurfaces - 1 do
		const surface = surface_load.read_surface_data(vertexData, data)

		if surface ~= nil then
			surface.object = SrcGameObjectListProcessor.gCurrentObject
			surface.type_ = S16(surfaceType)

			if hasForce ~= 0 then
				surface.force = Rom.ReadS16(data[1] + 2 * 3)
			else
				surface.force = 0
			end

			surface.flags = S8(bit32.bor(surface.flags, flags))
			surface.room = S8(room)
			surface_load.add_surface(surface, IncludePRUltratypesH.TRUE)
		end

		if hasForce ~= 0 then
			data[1] += 2 * 4
		else
			data[1] += 2 * 3
		end
	end
end

-- from src/engine/surface_load.c:load_object_collision_model L754-791
function surface_load.load_object_collision_model()
	const currentObject = SrcGameObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3Types.Object
	const rawData = currentObject.rawData
	const vertexData = Rom.PushStack(2 * 600)

	CollisionPointer[1] = currentObject.collisionData :: number

	local marioDist = buffer.readf32(rawData, IncludeObjectFieldsH.oDistanceToMario)
	const tangibleDist = buffer.readf32(rawData, IncludeObjectFieldsH.oCollisionDistance)

	-- On an object's first frame, the distance is set to 19000.0f.
	-- If the distance hasn't been updated, update it now.
	if buffer.readf32(rawData, IncludeObjectFieldsH.oDistanceToMario) == 19000 then
		marioDist = SrcGameObjectHelpers.dist_between_objects(currentObject, SrcGameObjectListProcessor.gMarioObject :: GroupsTypesHPlus3Types.Object)
	end

	-- If the object collision is supposed to be loaded more than the
	-- drawing distance of 4000, extend the drawing range.
	if buffer.readf32(rawData, IncludeObjectFieldsH.oCollisionDistance) > 4000 then
		buffer.writef32(rawData, IncludeObjectFieldsH.oDrawingDistance, buffer.readf32(rawData, IncludeObjectFieldsH.oCollisionDistance))
	end

	-- Update if no Time Stop, in range, and in the current room.
	if bit32.band(SrcGameObjectListProcessor.gTimeStopState, SrcGameObjectListProcessorH.TIME_STOP_ACTIVE) == 0 and marioDist < tangibleDist and bit32.band(currentObject.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) == 0 then
		CollisionPointer[1] += 2
		surface_load.transform_object_vertices(CollisionPointer, vertexData)

		-- TERRAIN_LOAD_CONTINUE acts as an "end" to the terrain data.
		while Rom.ReadS16(CollisionPointer[1]) ~= IncludeSurfaceTerrainsH.TERRAIN_LOAD_CONTINUE do
			surface_load.load_object_surfaces(CollisionPointer, vertexData)
		end
	end

	if marioDist < buffer.readf32(rawData, IncludeObjectFieldsH.oDrawingDistance) then
		currentObject.header.gfx.node.flags = S16(bit32.bor(currentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
	else
		currentObject.header.gfx.node.flags = S16(bit32.band(currentObject.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
	end

	Rom.PopStack(2 * 600)
end

return surface_load
