--!strict
--!optimize 2

--[[
	Port of src/game/object_list_processor.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludeSm64H = require("../../include/sm64_h")

const BehaviorIds = require("../rom/behavior_ids")
const Rom = require("../rom/rom")

const Memory = require("./memory")
const ObjectListProcessorH = require("./object_list_processor_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const LevelUpdate = require("./level_update")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const InteractionH = require("./interaction_h")
const PlatformDisplacement = require("./platform_displacement")
const SpawnObject = require("./spawn_object")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const SrcEngineGraphNode = require("../engine/graph_node")
const Area = require("./area")
const MemoryH = require("./memory_h")

-- from src/game/object_list_processor.c:ParticleProperties
export type ParticleProperties = {
	particleFlag: number,
	activeParticleFlag: number,
	model: number,
	behavior: number?,
}

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/object_list_processor.c:data
const object_list_processor = {
	-- from src/game/object_list_processor.c:gDebugInfoFlags L27-27
	gDebugInfoFlags = 0,
	-- from src/game/object_list_processor.c:gNumFindFloorMisses L33-33
	gNumFindFloorMisses = 0,
	-- from src/game/object_list_processor.c:unused_8033BEF8 L35-35
	unused_8033BEF8 = 0,
	-- from src/game/object_list_processor.c:gUnknownWallCount L40-40
	gUnknownWallCount = 0,
	-- from src/game/object_list_processor.c:gObjectCounter L46-46
	gObjectCounter = 0,
	-- from src/game/object_list_processor.c:gNumCalls L51-51
	gNumCalls = { floor = 0, ceil = 0, wall = 0 },
	-- from src/game/object_list_processor.c:gDebugInfo L57-57
	gDebugInfo = {
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
		},
	-- from src/game/object_list_processor.c:gDebugInfoOverwrite L58-58
	gDebugInfoOverwrite = {
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
			table.create(8, 0),
		},
	-- from src/game/object_list_processor.c:gTimeStopState L64-64
	gTimeStopState = 0,
	-- from src/game/object_list_processor.c:gObjectPool L69-69
	gObjectPool = {
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
			GroupsTypesHPlus3Types.new_Object(),
		},
	-- from src/game/object_list_processor.c:gMacroObjectDefaultParent L74-74
	gMacroObjectDefaultParent = GroupsTypesHPlus3Types.new_Object(),
	-- from src/game/object_list_processor.c:gObjectLists L81-81
	gObjectLists = {} :: { GroupsTypesHPlus3Types.ObjectNode },
	-- from src/game/object_list_processor.c:gFreeObjectList L86-86
	gFreeObjectList = GroupsTypesHPlus3Types.new_ObjectNode(),
	-- from src/game/object_list_processor.c:gMarioObject L91-91
	gMarioObject = nil :: GroupsTypesHPlus3Types.Object?,
	-- from src/game/object_list_processor.c:gLuigiObject L98-98
	gLuigiObject = nil :: GroupsTypesHPlus3Types.Object?,
	-- from src/game/object_list_processor.c:gCurrentObject L105-105
	gCurrentObject = GroupsTypesHPlus3Types.new_Object(),
	-- from src/game/object_list_processor.c:gCurBhvCommand L110-110
	gCurBhvCommand = nil :: number?,
	-- from src/game/object_list_processor.c:gPrevFrameObjectCount L118-118
	gPrevFrameObjectCount = 0,
	-- from src/game/object_list_processor.c:gSurfaceNodesAllocated L124-124
	gSurfaceNodesAllocated = 0,
	-- from src/game/object_list_processor.c:gSurfacesAllocated L129-129
	gSurfacesAllocated = 0,
	-- from src/game/object_list_processor.c:gNumStaticSurfaceNodes L134-134
	gNumStaticSurfaceNodes = 0,
	-- from src/game/object_list_processor.c:gNumStaticSurfaces L139-139
	gNumStaticSurfaces = 0,
	-- from src/game/object_list_processor.c:gObjectMemoryPool L144-144
	gObjectMemoryPool = nil :: number?,
	-- from src/game/object_list_processor.c:gCheckingSurfaceCollisionsForCamera L147-147
	gCheckingSurfaceCollisionsForCamera = 0,
	-- from src/game/object_list_processor.c:gFindFloorIncludeSurfaceIntangible L148-148
	gFindFloorIncludeSurfaceIntangible = 0,
	-- from src/game/object_list_processor.c:gEnvironmentRegions L149-149
	gEnvironmentRegions = nil :: number?,
	-- from src/game/object_list_processor.c:gEnvironmentLevels L150-150
	gEnvironmentLevels = table.create(20, 0),
	-- from src/game/object_list_processor.c:gDoorAdjacentRooms L151-151
	gDoorAdjacentRooms = {
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
			buffer.create(2),
		},
	-- from src/game/object_list_processor.c:gMarioCurrentRoom L152-152
	gMarioCurrentRoom = 0,
	-- from src/game/object_list_processor.c:D_8035FEE2 L153-153
	D_8035FEE2 = 0,
	-- from src/game/object_list_processor.c:D_8035FEE4 L154-154
	D_8035FEE4 = 0,
	-- from src/game/object_list_processor.c:gTHIWaterDrained L155-155
	gTHIWaterDrained = 0,
	-- from src/game/object_list_processor.c:gTTCSpeedSetting L156-156
	gTTCSpeedSetting = 0,
	-- from src/game/object_list_processor.c:gMarioShotFromCannon L157-157
	gMarioShotFromCannon = 0,
	-- from src/game/object_list_processor.c:gCCMEnteredSlide L158-158
	gCCMEnteredSlide = 0,
	-- from src/game/object_list_processor.c:gNumRoomedObjectsInMarioRoom L159-159
	gNumRoomedObjectsInMarioRoom = 0,
	-- from src/game/object_list_processor.c:gNumRoomedObjectsNotInMarioRoom L160-160
	gNumRoomedObjectsNotInMarioRoom = 0,
	-- from src/game/object_list_processor.c:gWDWWaterLevelChanging L161-161
	gWDWWaterLevelChanging = 0,
	-- from src/game/object_list_processor.c:gMarioOnMerryGoRound L162-162
	gMarioOnMerryGoRound = 0,
	-- from src/game/object_list_processor.c:gObjectListArray L167-167
	gObjectListArray = {
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
			GroupsTypesHPlus3Types.new_ObjectNode(),
		},
	-- from src/game/object_list_processor.c:sObjectListUpdateOrder L172-182
	sObjectListUpdateOrder = {
			ObjectListProcessorH.OBJ_LIST_SPAWNER,
			ObjectListProcessorH.OBJ_LIST_SURFACE,
			ObjectListProcessorH.OBJ_LIST_POLELIKE,
			ObjectListProcessorH.OBJ_LIST_PLAYER,
			ObjectListProcessorH.OBJ_LIST_PUSHABLE,
			ObjectListProcessorH.OBJ_LIST_GENACTOR,
			ObjectListProcessorH.OBJ_LIST_DESTRUCTIVE,
			ObjectListProcessorH.OBJ_LIST_LEVEL,
			ObjectListProcessorH.OBJ_LIST_DEFAULT,
			ObjectListProcessorH.OBJ_LIST_UNIMPORTANT,
			-1,
		},
	-- from src/game/object_list_processor.c:sParticleTypes L198-218
	sParticleTypes = {
			{
				particleFlag = IncludeSm64H.PARTICLE_DUST,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_DUST,
				model = IncludeModelIdsH.MODEL_MIST,
				behavior = BehaviorIds.bhvMistParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_VERTICAL_STAR,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_V_STAR,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvVertStarParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_HORIZONTAL_STAR,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_H_STAR,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvHorStarParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_SPARKLES,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_SPARKLES,
				model = IncludeModelIdsH.MODEL_SPARKLES,
				behavior = BehaviorIds.bhvSparkleParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_BUBBLE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_BUBBLE,
				model = IncludeModelIdsH.MODEL_BUBBLE,
				behavior = BehaviorIds.bhvBubbleParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_WATER_SPLASH,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_WATER_SPLASH,
				model = IncludeModelIdsH.MODEL_WATER_SPLASH,
				behavior = BehaviorIds.bhvWaterSplash,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_IDLE_WATER_WAVE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_IDLE_WATER_WAVE,
				model = IncludeModelIdsH.MODEL_IDLE_WATER_WAVE,
				behavior = BehaviorIds.bhvIdleWaterWave,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_PLUNGE_BUBBLE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_PLUNGE_BUBBLE,
				model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL,
				behavior = BehaviorIds.bhvPlungeBubble,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_WAVE_TRAIL,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_WAVE_TRAIL,
				model = IncludeModelIdsH.MODEL_WAVE_TRAIL,
				behavior = BehaviorIds.bhvWaveTrail,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_FIRE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_FIRE,
				model = IncludeModelIdsH.MODEL_RED_FLAME,
				behavior = BehaviorIds.bhvFireParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_SHALLOW_WATER_WAVE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_SHALLOW_WATER_WAVE,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvShallowWaterWave,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_SHALLOW_WATER_SPLASH,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_SHALLOW_WATER_SPLASH,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvShallowWaterSplash,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_LEAF,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_LEAF,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvLeafParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_SNOW,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_SNOW,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvSnowParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_BREATH,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_BREATH,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvBreathParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_DIRT,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_DIRT,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvDirtParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_MIST_CIRCLE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_MIST_CIRCLE,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvMistCircParticleSpawner,
			},
			{
				particleFlag = IncludeSm64H.PARTICLE_TRIANGLE,
				activeParticleFlag = IncludeObjectConstantsH.ACTIVE_PARTICLE_TRIANGLE,
				model = IncludeModelIdsH.MODEL_NONE,
				behavior = BehaviorIds.bhvTriangleParticleSpawner,
			},
			{ particleFlag = 0, activeParticleFlag = 0, model = IncludeModelIdsH.MODEL_NONE, behavior = nil },
		},
}

Registry.Register("src__game__object_list_processor", object_list_processor)

-- from src/game/object_list_processor.c:ParticleProperties (zero-filled constructor)
function object_list_processor.new_ParticleProperties(): ParticleProperties
	return { particleFlag = 0, activeParticleFlag = 0, model = 0, behavior = nil } :: ParticleProperties
end

-- from src/game/object_list_processor.c:copy_mario_state_to_object L224-250
function object_list_processor.copy_mario_state_to_object()
	local i = 0

	if object_list_processor.gCurrentObject ~= object_list_processor.gMarioObject then
		i += 1
	end

	const o = object_list_processor.gCurrentObject :: GroupsTypesHPlus3Types.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, LevelUpdate.gMarioStates[i + 1].vel[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, LevelUpdate.gMarioStates[i + 1].vel[2])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, LevelUpdate.gMarioStates[i + 1].vel[3])

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, LevelUpdate.gMarioStates[i + 1].pos[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, LevelUpdate.gMarioStates[i + 1].pos[2])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, LevelUpdate.gMarioStates[i + 1].pos[3])

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, o.header.gfx.angle[1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, o.header.gfx.angle[2])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll, o.header.gfx.angle[3])

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, o.header.gfx.angle[1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, o.header.gfx.angle[2])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, o.header.gfx.angle[3])

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, LevelUpdate.gMarioStates[i + 1].angleVel[1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, LevelUpdate.gMarioStates[i + 1].angleVel[2])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, LevelUpdate.gMarioStates[i + 1].angleVel[3])
end

-- from src/game/object_list_processor.c:spawn_particle L255-262
function object_list_processor.spawn_particle(activeParticleFlag: number, model: number, behavior: number)
	model = S16(TruncS32(model))
	if not bit32.btest(buffer.readu32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags), activeParticleFlag) then
		buffer.writeu32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags, bit32.bor(buffer.readu32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags), activeParticleFlag))

		const particle = Registry.Members.src__game__object_helpers.spawn_object_at_origin(object_list_processor.gCurrentObject, 0, model, behavior)

		Registry.Members.src__game__object_helpers.obj_copy_pos_and_angle(particle, object_list_processor.gCurrentObject)
	end
end

-- from src/game/object_list_processor.c:bhv_mario_update L267-287
function object_list_processor.bhv_mario_update()
	const particleFlags = Registry.Members.src__game__mario.execute_mario_action(object_list_processor.gCurrentObject)

	buffer.writei32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oMarioParticleFlags, particleFlags)

	-- Mario code updates MarioState's versions of position etc, so we need
	-- to sync it with the Mario object
	object_list_processor.copy_mario_state_to_object()

	local i = 0

	while object_list_processor.sParticleTypes[i + 1].particleFlag ~= 0 do
		if bit32.btest(particleFlags, object_list_processor.sParticleTypes[i + 1].particleFlag) then
			object_list_processor.spawn_particle(object_list_processor.sParticleTypes[i + 1].activeParticleFlag, object_list_processor.sParticleTypes[i + 1].model, object_list_processor.sParticleTypes[i + 1].behavior :: number)
		end

		i += 1
	end
end

-- from src/game/object_list_processor.c:update_objects_starting_at L293-307
function object_list_processor.update_objects_starting_at(objList: GroupsTypesHPlus3Types.ObjectNode, firstObj: GroupsTypesHPlus3Types.ObjectNode): number
	local count = 0

	while objList ~= firstObj do
		object_list_processor.gCurrentObject = firstObj :: GroupsTypesHPlus3Types.Object
		object_list_processor.gCurrentObject.header.gfx.node.flags = S16(bit32.bor(object_list_processor.gCurrentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION))

		SrcEngineBehaviorScript.cur_obj_update()

		firstObj = firstObj.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode
		count += 1
	end

	return count
end

-- from src/game/object_list_processor.c:update_objects_during_time_stop L318-357
function object_list_processor.update_objects_during_time_stop(objList: GroupsTypesHPlus3Types.ObjectNode, firstObj: GroupsTypesHPlus3Types.ObjectNode): number
	local count = 0

	while objList ~= firstObj do
		object_list_processor.gCurrentObject = firstObj :: GroupsTypesHPlus3Types.Object

		local unfrozen = IncludePRUltratypesH.FALSE

		-- Selectively unfreeze certain objects
		if not bit32.btest(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ALL_OBJECTS) then
			if object_list_processor.gCurrentObject == object_list_processor.gMarioObject and not bit32.btest(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS) then
				unfrozen = IncludePRUltratypesH.TRUE
			end

			if bit32.btest(buffer.readu32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oInteractType), bit32.bor(InteractionH.INTERACT_DOOR, InteractionH.INTERACT_WARP_DOOR)) and not bit32.btest(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS) then
				unfrozen = IncludePRUltratypesH.TRUE
			end

			if bit32.btest(object_list_processor.gCurrentObject.activeFlags, bit32.bor(IncludeObjectConstantsH.ACTIVE_FLAG_UNIMPORTANT, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)) then
				unfrozen = IncludePRUltratypesH.TRUE
			end
		end

		-- Only update if unfrozen
		if unfrozen ~= 0 then
			object_list_processor.gCurrentObject.header.gfx.node.flags = S16(bit32.bor(object_list_processor.gCurrentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION))

			SrcEngineBehaviorScript.cur_obj_update()
		else
			object_list_processor.gCurrentObject.header.gfx.node.flags = S16(bit32.band(object_list_processor.gCurrentObject.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_HAS_ANIMATION)))
		end

		firstObj = firstObj.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode
		count += 1
	end

	return count
end

-- from src/game/object_list_processor.c:update_objects_in_list L363-374
function object_list_processor.update_objects_in_list(objList: GroupsTypesHPlus3Types.ObjectNode): number
	const firstObj = objList.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

	local count: number

	if not bit32.btest(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ACTIVE) then
		count = object_list_processor.update_objects_starting_at(objList, firstObj)
	else
		count = object_list_processor.update_objects_during_time_stop(objList, firstObj)
	end

	return count
end

-- from src/game/object_list_processor.c:unload_deactivated_objects_in_list L379-399
function object_list_processor.unload_deactivated_objects_in_list(objList: GroupsTypesHPlus3Types.ObjectNode): number
	local obj = objList.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

	while objList ~= obj do
		object_list_processor.gCurrentObject = obj :: GroupsTypesHPlus3Types.Object
		obj = obj.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

		if bit32.band(object_list_processor.gCurrentObject.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_ACTIVE) ~= IncludeObjectConstantsH.ACTIVE_FLAG_ACTIVE then
			-- Prevent object from respawning after exiting and re-entering the area
			if not bit32.btest(buffer.readu32(object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_PERSISTENT_RESPAWN) then
				object_list_processor.set_object_respawn_info_bits(object_list_processor.gCurrentObject, IncludeObjectConstantsH.RESPAWN_INFO_DONT_RESPAWN)
			end

			SpawnObject.unload_object(object_list_processor.gCurrentObject)
		end
	end

	return 0
end

-- from src/game/object_list_processor.c:set_object_respawn_info_bits L408-423
function object_list_processor.set_object_respawn_info_bits(obj: GroupsTypesHPlus3Types.Object, bits: number)
	bits = U8(TruncS32(bits))
	if obj.respawnInfoType == IncludeObjectConstantsH.RESPAWN_INFO_TYPE_32 then
		const Reference = obj.respawnInfo :: { Base: { [string]: number }, Key: string }

		Reference.Base[Reference.Key] = bit32.bor(Reference.Base[Reference.Key], bit32.lshift(bits, 8))
	elseif obj.respawnInfoType == IncludeObjectConstantsH.RESPAWN_INFO_TYPE_16 then
		const Address = obj.respawnInfo :: number

		Rom.WriteS16(Address, bit32.bor(Rom.ReadU16(Address), bit32.lshift(bits, 8)))
	end
end

-- from src/game/object_list_processor.c:unload_objects_from_area L428-448
function object_list_processor.unload_objects_from_area(unused: number, areaIndex: number)
	object_list_processor.gObjectLists = object_list_processor.gObjectListArray

	for i = 0, ObjectListProcessorH.NUM_OBJ_LISTS - 1 do
		const list = object_list_processor.gObjectLists[i + 1]
		local node = list.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

		while node ~= list do
			const obj = node :: GroupsTypesHPlus3Types.Object

			node = node.ObjectNode_next :: GroupsTypesHPlus3Types.ObjectNode

			if obj.header.gfx.activeAreaIndex == areaIndex then
				SpawnObject.unload_object(obj)
			end
		end
	end
end

-- from src/game/object_list_processor.c:spawn_objects_from_info L453-520
function object_list_processor.spawn_objects_from_info(unused: number, spawnInfo: GroupsTypesHPlus3Types.SpawnInfo?)
	object_list_processor.gObjectLists = object_list_processor.gObjectListArray
	object_list_processor.gTimeStopState = 0
	object_list_processor.gWDWWaterLevelChanging = IncludePRUltratypesH.FALSE
	object_list_processor.gMarioOnMerryGoRound = IncludePRUltratypesH.FALSE

	--! (Spawning Displacement) On the Japanese version, Mario's platform object
	--  isn't cleared when transitioning between areas. This can cause Mario to
	--  receive displacement after spawning.
	PlatformDisplacement.clear_mario_platform()

	if Area.gCurrAreaIndex == 2 then
		object_list_processor.gCCMEnteredSlide = S16(bit32.bor(object_list_processor.gCCMEnteredSlide, 1))
	end

	while spawnInfo ~= nil do
		const script = Memory.segmented_to_virtual(spawnInfo.behaviorScript :: number)

		-- If the object was previously killed/collected, don't respawn it
		if bit32.band(spawnInfo.behaviorArg, bit32.lshift(IncludeObjectConstantsH.RESPAWN_INFO_DONT_RESPAWN, 8)) ~= bit32.lshift(IncludeObjectConstantsH.RESPAWN_INFO_DONT_RESPAWN, 8) then
			const object = SpawnObject.create_object(script)

			-- Behavior parameters are often treated as four separate bytes, but
			-- are stored as an s32.
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oBhvParams, spawnInfo.behaviorArg)

			-- The second byte of the behavior parameters is copied over to a special field
			-- as it is the most frequently used by objects.
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, bit32.band(bit32.rshift(spawnInfo.behaviorArg, 16), 0xFF))
			object.behavior = script
			object.unused1 = 0

			-- Record death/collection in the SpawnInfo
			object.respawnInfoType = IncludeObjectConstantsH.RESPAWN_INFO_TYPE_32
			object.respawnInfo = { Base = spawnInfo, Key = "behaviorArg" }

			if bit32.btest(spawnInfo.behaviorArg, 0x01) then
				object_list_processor.gMarioObject = object
				SrcEngineGraphNode.geo_make_first_child(object.header.gfx.node)
			end

			SrcEngineGraphNode.geo_obj_init_spawninfo(object.header.gfx, spawnInfo)
			buffer.writef32(object.rawData, IncludeObjectFieldsH.oPosX, spawnInfo.startPos[1])
			buffer.writef32(object.rawData, IncludeObjectFieldsH.oPosY, spawnInfo.startPos[2])
			buffer.writef32(object.rawData, IncludeObjectFieldsH.oPosZ, spawnInfo.startPos[3])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oFaceAnglePitch, spawnInfo.startAngle[1])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oFaceAngleYaw, spawnInfo.startAngle[2])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oFaceAngleRoll, spawnInfo.startAngle[3])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oMoveAnglePitch, spawnInfo.startAngle[1])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oMoveAngleYaw, spawnInfo.startAngle[2])
			buffer.writei32(object.rawData, IncludeObjectFieldsH.oMoveAngleRoll, spawnInfo.startAngle[3])
		end

		spawnInfo = spawnInfo.next
	end
end

-- from src/game/object_list_processor.c:stub_obj_list_processor_1 L522-523
function object_list_processor.stub_obj_list_processor_1()
	-- The C body is empty.
end

-- from src/game/object_list_processor.c:clear_objects L528-558
function object_list_processor.clear_objects()
	object_list_processor.gTHIWaterDrained = 0
	object_list_processor.gTimeStopState = 0
	object_list_processor.gMarioObject = nil
	object_list_processor.gMarioCurrentRoom = 0

	for i = 0, 60 - 1 do
		buffer.writeu8(object_list_processor.gDoorAdjacentRooms[i + 1], 0, 0)
		buffer.writeu8(object_list_processor.gDoorAdjacentRooms[i + 1], 1, 0)
	end

	-- debug_unknown_level_select_check: no call (replaced)
	SpawnObject.init_free_object_list()
	SpawnObject.clear_object_lists(object_list_processor.gObjectListArray)
	SrcEngineBehaviorScript.stub_behavior_script_2()
	object_list_processor.stub_obj_list_processor_1()

	for i = 0, ObjectListProcessorH.OBJECT_POOL_CAPACITY - 1 do
		object_list_processor.gObjectPool[i + 1].activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		SrcEngineGraphNode.geo_reset_object_node(object_list_processor.gObjectPool[i + 1].header.gfx)
	end

	object_list_processor.gObjectMemoryPool = Memory.mem_pool_init(0x800, MemoryH.MEMORY_POOL_LEFT)
	object_list_processor.gObjectLists = object_list_processor.gObjectListArray
	Registry.Members.src__engine__surface_load.clear_dynamic_surfaces()
end

-- from src/game/object_list_processor.c:update_terrain_objects L563-567
function object_list_processor.update_terrain_objects()
	object_list_processor.gObjectCounter = object_list_processor.update_objects_in_list(object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SPAWNER + 1])

	--! This was meant to be +=
	object_list_processor.gObjectCounter = object_list_processor.update_objects_in_list(object_list_processor.gObjectLists[ObjectListProcessorH.OBJ_LIST_SURFACE + 1])
end

-- from src/game/object_list_processor.c:update_non_terrain_objects L573-582
function object_list_processor.update_non_terrain_objects()
	local i = 2
	local listIndex = object_list_processor.sObjectListUpdateOrder[i + 1]

	while listIndex ~= -1 do
		object_list_processor.gObjectCounter += object_list_processor.update_objects_in_list(object_list_processor.gObjectLists[listIndex + 1])

		i += 1
		listIndex = object_list_processor.sObjectListUpdateOrder[i + 1]
	end
end

-- from src/game/object_list_processor.c:unload_deactivated_objects L587-600
function object_list_processor.unload_deactivated_objects()
	local i = 0
	local listIndex = object_list_processor.sObjectListUpdateOrder[i + 1]

	while listIndex ~= -1 do
		object_list_processor.unload_deactivated_objects_in_list(object_list_processor.gObjectLists[listIndex + 1])

		i += 1
		listIndex = object_list_processor.sObjectListUpdateOrder[i + 1]
	end

	-- TIME_STOP_UNKNOWN_0 was most likely intended to be used to track whether
	-- any objects had been deactivated
	object_list_processor.gTimeStopState = bit32.band(object_list_processor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_UNKNOWN_0))
end

-- from src/game/object_list_processor.c:unused_get_elapsed_time L605-620
function object_list_processor.unused_get_elapsed_time(cycleCounts: { number }, index: number): number
	-- osClockRate is the 62500000 of native/stub/os.c (os-clock-rate-value)
	const osClockRate: number = 62500000
	local cycles: number = cycleCounts[index + 1] - cycleCounts[index]

	if cycles < 0 then
		cycles = 0
	end

	local time: number = U16(TruncS32(TruncS32(cycles) * 1000000 // osClockRate / 16667.0 * 1000.0))

	if time > 999 then
		time = 999
	end

	return time
end

-- from src/game/object_list_processor.c:update_objects L626-686
function object_list_processor.update_objects(unused: number)
	-- cycleCounts: timing only, get_current_clock and get_clock_difference are 0 (replaced)
	object_list_processor.gTimeStopState = bit32.band(object_list_processor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_MARIO_OPENED_DOOR))
	object_list_processor.gNumRoomedObjectsInMarioRoom = 0
	object_list_processor.gNumRoomedObjectsNotInMarioRoom = 0
	object_list_processor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.FALSE

	-- reset_debug_objectinfo, stub_debug_5: no call (debug-print-externals)
	object_list_processor.gObjectLists = object_list_processor.gObjectListArray

	-- If time stop is not active, unload object surfaces
	Registry.Members.src__engine__surface_load.clear_dynamic_surfaces()

	-- Update spawners and objects with surfaces
	object_list_processor.update_terrain_objects()

	-- If Mario was touching a moving platform at the end of last frame, apply
	-- displacement now
	--! If the platform object unloaded and a different object took its place,
	--  displacement could be applied incorrectly
	PlatformDisplacement.apply_mario_platform_displacement()

	-- Detect which objects are intersecting
	Registry.Members.src__game__object_collision.detect_object_collisions()

	-- Update all other objects that haven't been updated yet
	object_list_processor.update_non_terrain_objects()

	-- Unload any objects that have been deactivated
	object_list_processor.unload_deactivated_objects()

	-- Check if Mario is on a platform object and save this object
	PlatformDisplacement.update_mario_platform()

	-- try_print_debug_mario_object_info: no call (debug-print-externals)

	-- If time stop was enabled this frame, activate it now so that it will
	-- take effect next frame
	if bit32.btest(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ENABLED) then
		object_list_processor.gTimeStopState = bit32.bor(object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ACTIVE)
	else
		object_list_processor.gTimeStopState = bit32.band(object_list_processor.gTimeStopState, bit32.bnot(ObjectListProcessorH.TIME_STOP_ACTIVE))
	end

	object_list_processor.gPrevFrameObjectCount = S16(object_list_processor.gObjectCounter)
end

return object_list_processor
