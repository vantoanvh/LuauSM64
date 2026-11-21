--!strict
--!optimize 2

--[[
	Port of src/game/area.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const BehaviorIds = require("../rom/behavior_ids")
const Memory = require("./memory")
const IncludeLevelTableH = require("../../include/level_table_h")

const LevelUpdateH = require("./level_update_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeConfigH = require("../../include/config_h")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludeGfxDimensionsH = require("../../include/gfx_dimensions_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const GameInit = require("./game_init")
const Gbi = require("../rom/gbi")
const Audio = require("../rom/audio_recorder")
const Print = require("./print")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/area.c:data
const area = {
	-- from src/game/area.c:gPlayerSpawnInfos L26-26
	gPlayerSpawnInfos = {
			{
				startPos = table.create(3, 0),
				startAngle = table.create(3, 0),
				areaIndex = 0,
				activeAreaIndex = 0,
				behaviorArg = 0,
				behaviorScript = nil,
				model = nil,
				next = nil,
			},
		} :: { GroupsTypesHPlus3Types.SpawnInfo },
	-- from src/game/area.c:D_8033A160 L27-27
	D_8033A160 = {
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
		} :: { GroupsTypesHPlus3Types.GraphNode? },
	-- from src/game/area.c:gAreaData L28-28
	gAreaData = {
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
			{
				index = 0,
				flags = 0,
				terrainType = 0,
				unk04 = nil,
				terrainData = nil,
				surfaceRooms = nil,
				macroObjects = nil,
				warpNodes = nil,
				paintingWarpNodes = nil,
				instantWarps = nil,
				objectSpawnInfos = nil,
				camera = nil,
				unused = nil,
				whirlpools = { nil, nil },
				dialog = buffer.create(2),
				musicParam = 0,
				musicParam2 = 0,
			},
		} :: { GroupsTypesHPlus3Types.Area },
	-- from src/game/area.c:gWarpTransition L30-30
	gWarpTransition = {
			isActive = 0,
			type_ = 0,
			time = 0,
			pauseRendering = 0,
			data = {
				red = 0,
				green = 0,
				blue = 0,
				startTexRadius = 0,
				endTexRadius = 0,
				startTexX = 0,
				startTexY = 0,
				endTexX = 0,
				endTexY = 0,
				texTimer = 0,
			},
		},
	-- from src/game/area.c:gCurrCourseNum L32-32
	gCurrCourseNum = 0,
	-- from src/game/area.c:gCurrActNum L33-33
	gCurrActNum = 0,
	-- from src/game/area.c:gCurrAreaIndex L34-34
	gCurrAreaIndex = 0,
	-- from src/game/area.c:gSavedCourseNum L35-35
	gSavedCourseNum = 0,
	-- from src/game/area.c:gMenuOptSelectIndex L36-36
	gMenuOptSelectIndex = 0,
	-- from src/game/area.c:gSaveOptSelectIndex L37-37
	gSaveOptSelectIndex = 0,
	-- from src/game/area.c:gCurrentArea L42-42
	gCurrentArea = nil :: GroupsTypesHPlus3Types.Area?,
	-- from src/game/area.c:gCurrCreditsEntry L43-43
	gCurrCreditsEntry = nil,
	-- from src/game/area.c:D_8032CE74 L44-44
	D_8032CE74 = nil :: { unknown }?,
	-- from src/game/area.c:D_8032CE78 L45-45
	D_8032CE78 = nil :: { unknown }?,
	-- from src/game/area.c:gWarpTransDelay L46-46
	gWarpTransDelay = 0,
	-- from src/game/area.c:gFBSetColor L47-47
	gFBSetColor = 0,
	-- from src/game/area.c:gWarpTransFBSetColor L48-48
	gWarpTransFBSetColor = 0,
	-- from src/game/area.c:gWarpTransRed L49-49
	gWarpTransRed = 0,
	-- from src/game/area.c:gWarpTransGreen L50-50
	gWarpTransGreen = 0,
	-- from src/game/area.c:gWarpTransBlue L51-51
	gWarpTransBlue = 0,
	-- from src/game/area.c:gCurrSaveFileNum L52-52
	gCurrSaveFileNum = 1,
	-- from src/game/area.c:gCurrLevelNum L53-53
	gCurrLevelNum = IncludeLevelTableH.LEVEL_MIN,
	-- from src/game/area.c:sWarpBhvSpawnTable L62-68
	sWarpBhvSpawnTable = {
			BehaviorIds.bhvDoorWarp,
			BehaviorIds.bhvStar,
			BehaviorIds.bhvExitPodiumWarp,
			BehaviorIds.bhvWarp,
			BehaviorIds.bhvWarpPipe,
			BehaviorIds.bhvFadingWarp,
			BehaviorIds.bhvInstantActiveWarp,
			BehaviorIds.bhvAirborneWarp,
			BehaviorIds.bhvHardAirKnockBackWarp,
			BehaviorIds.bhvSpinAirborneCircleWarp,
			BehaviorIds.bhvDeathWarp,
			BehaviorIds.bhvSpinAirborneWarp,
			BehaviorIds.bhvFlyingWarp,
			BehaviorIds.bhvSwimmingWarp,
			BehaviorIds.bhvPaintingStarCollectWarp,
			BehaviorIds.bhvPaintingDeathWarp,
			BehaviorIds.bhvAirborneStarCollectWarp,
			BehaviorIds.bhvAirborneDeathWarp,
			BehaviorIds.bhvLaunchStarCollectWarp,
			BehaviorIds.bhvLaunchDeathWarp,
		},
	-- from src/game/area.c:sSpawnTypeFromWarpBhv L70-76
	sSpawnTypeFromWarpBhv = {
			LevelUpdateH.MARIO_SPAWN_DOOR_WARP,
			LevelUpdateH.MARIO_SPAWN_UNKNOWN_02,
			LevelUpdateH.MARIO_SPAWN_UNKNOWN_03,
			LevelUpdateH.MARIO_SPAWN_UNKNOWN_03,
			LevelUpdateH.MARIO_SPAWN_UNKNOWN_03,
			LevelUpdateH.MARIO_SPAWN_TELEPORT,
			LevelUpdateH.MARIO_SPAWN_INSTANT_ACTIVE,
			LevelUpdateH.MARIO_SPAWN_AIRBORNE,
			LevelUpdateH.MARIO_SPAWN_HARD_AIR_KNOCKBACK,
			LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE_CIRCLE,
			LevelUpdateH.MARIO_SPAWN_DEATH,
			LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE,
			LevelUpdateH.MARIO_SPAWN_FLYING,
			LevelUpdateH.MARIO_SPAWN_SWIMMING,
			LevelUpdateH.MARIO_SPAWN_PAINTING_STAR_COLLECT,
			LevelUpdateH.MARIO_SPAWN_PAINTING_DEATH,
			LevelUpdateH.MARIO_SPAWN_AIRBORNE_STAR_COLLECT,
			LevelUpdateH.MARIO_SPAWN_AIRBORNE_DEATH,
			LevelUpdateH.MARIO_SPAWN_LAUNCH_STAR_COLLECT,
			LevelUpdateH.MARIO_SPAWN_LAUNCH_DEATH,
		},
	-- from src/game/area.c:D_8032CF00 L78-81
	D_8032CF00 = { { 640, 480, 511, 0 }, { 640, 480, 511, 0 } },
}

Registry.Register("src__game__area", area)

-- from src/game/area.c:override_viewport_and_clip L91-97
function area.override_viewport_and_clip(a: { unknown }?, b: { unknown }?, c: number, d: number, e: number)
	c = U8(TruncS32(c))
	d = U8(TruncS32(d))
	e = U8(TruncS32(e))
	const sp6 = U16(bit32.bor(bit32.lshift(bit32.rshift(c, 3), 11), bit32.lshift(bit32.rshift(d, 3), 6), bit32.lshift(bit32.rshift(e, 3), 1), 1))

	area.gFBSetColor = bit32.bor(bit32.lshift(sp6, 16), sp6)
	area.D_8032CE74 = a
	area.D_8032CE78 = b
end

-- from src/game/area.c:set_warp_transition_rgb L99-106
function area.set_warp_transition_rgb(red: number, green: number, blue: number)
	red = U8(TruncS32(red))
	green = U8(TruncS32(green))
	blue = U8(TruncS32(blue))
	const warpTransitionRGBA16 = U16(bit32.bor(bit32.lshift(bit32.rshift(red, 3), 11), bit32.lshift(bit32.rshift(green, 3), 6), bit32.lshift(bit32.rshift(blue, 3), 1), 1))

	area.gWarpTransFBSetColor = bit32.bor(bit32.lshift(warpTransitionRGBA16, 16), warpTransitionRGBA16)
	area.gWarpTransRed = red
	area.gWarpTransGreen = green
	area.gWarpTransBlue = blue
end

-- from src/game/area.c:print_intro_text L108-135
function area.print_intro_text()
	if bit32.band(Registry.Members.src__game__game_init.gGlobalTimer, 31) < 20 then
		if Registry.Members.src__game__game_init.gControllerBits == 0 then
			Print.print_text_centered(IncludeConfigH.SCREEN_WIDTH / 2, 20, "NO CONTROLLER")
		else
			Print.print_text_centered(60, 38, "PRESS")
			Print.print_text_centered(60, 20, "START")
		end
	end
end

-- from src/game/area.c:get_mario_spawn_type L137-147
function area.get_mario_spawn_type(o: GroupsTypesHPlus3Types.Object): number
	const behavior = Memory.virtual_to_segmented(0x13, o.behavior :: number)

	for i = 1, 20 do
		if behavior == area.sWarpBhvSpawnTable[i] then
			return area.sSpawnTypeFromWarpBhv[i]
		end
	end

	return 0
end

-- from src/game/area.c:area_get_warp_node L149-158
function area.area_get_warp_node(id: number): GroupsTypesHPlus3Types.ObjectWarpNode?
	id = U8(TruncS32(id))
	local node = (area.gCurrentArea :: GroupsTypesHPlus3Types.Area).warpNodes

	while node ~= nil do
		if node.node.id == id then
			break
		end

		node = node.next
	end

	return node
end

-- from src/game/area.c:area_get_warp_node_from_params L160-164
function area.area_get_warp_node_from_params(o: GroupsTypesHPlus3Types.Object): GroupsTypesHPlus3Types.ObjectWarpNode?
	const id = bit32.rshift(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oBhvParams), 0x00FF0000), 16)

	return area.area_get_warp_node(id)
end

-- from src/game/area.c:load_obj_warp_nodes L166-181
function area.load_obj_warp_nodes()
	local sp20 = Registry.Members.src__engine__geo_layout.gObjParentGraphNode.children :: GroupsTypesHPlus3Types.Object

	repeat
		const sp1C = sp20

		if sp1C.activeFlags ~= IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED and area.get_mario_spawn_type(sp1C) ~= 0 then
			const sp24 = area.area_get_warp_node_from_params(sp1C)

			if sp24 ~= nil then
				sp24.object = sp1C
			end
		end

		sp20 = sp20.header.gfx.node.next :: GroupsTypesHPlus3Types.Object
	until not (sp20 ~= Registry.Members.src__engine__geo_layout.gObjParentGraphNode.children)
end

-- from src/game/area.c:clear_areas L183-212
function area.clear_areas()
	area.gCurrentArea = nil
	area.gWarpTransition.isActive = IncludePRUltratypesH.FALSE
	area.gWarpTransition.pauseRendering = IncludePRUltratypesH.FALSE
	area.gMarioSpawnInfo.areaIndex = -1

	for i = 0, 7 do
		area.gAreaData[i + 1].index = S8(i)
		area.gAreaData[i + 1].flags = 0
		area.gAreaData[i + 1].terrainType = 0
		area.gAreaData[i + 1].unk04 = nil
		area.gAreaData[i + 1].terrainData = nil
		area.gAreaData[i + 1].surfaceRooms = nil
		area.gAreaData[i + 1].macroObjects = nil
		area.gAreaData[i + 1].warpNodes = nil
		area.gAreaData[i + 1].paintingWarpNodes = nil
		area.gAreaData[i + 1].instantWarps = nil
		area.gAreaData[i + 1].objectSpawnInfos = nil
		area.gAreaData[i + 1].camera = nil
		area.gAreaData[i + 1].unused = nil
		area.gAreaData[i + 1].whirlpools[1] = nil
		area.gAreaData[i + 1].whirlpools[2] = nil
		buffer.writeu8(area.gAreaData[i + 1].dialog, 0, U8(IncludeDialogIdsH.DIALOG_NONE))
		buffer.writeu8(area.gAreaData[i + 1].dialog, 1, U8(IncludeDialogIdsH.DIALOG_NONE))
		area.gAreaData[i + 1].musicParam = 0
		area.gAreaData[i + 1].musicParam2 = 0
	end
end

-- from src/game/area.c:clear_area_graph_nodes L214-229
function area.clear_area_graph_nodes()
	if area.gCurrentArea ~= nil then
		Registry.Members.src__engine__graph_node.geo_call_global_function_nodes((area.gCurrentArea :: GroupsTypesHPlus3Types.Area).unk04 :: GroupsTypesHPlus3Types.GraphNodeRoot, GroupsTypesHPlus3.GEO_CONTEXT_AREA_UNLOAD)
		area.gCurrentArea = nil
		area.gWarpTransition.isActive = IncludePRUltratypesH.FALSE
	end

	for i = 0, 7 do
		if area.gAreaData[i + 1].unk04 ~= nil then
			Registry.Members.src__engine__graph_node.geo_call_global_function_nodes(area.gAreaData[i + 1].unk04 :: GroupsTypesHPlus3Types.GraphNodeRoot, GroupsTypesHPlus3.GEO_CONTEXT_AREA_INIT)
			area.gAreaData[i + 1].unk04 = nil
		end
	end
end

-- from src/game/area.c:load_area L231-248
function area.load_area(index: number)
	if area.gCurrentArea == nil and area.gAreaData[index + 1].unk04 ~= nil then
		area.gCurrentArea = area.gAreaData[index + 1]
		area.gCurrAreaIndex = area.gAreaData[index + 1].index

		if area.gAreaData[index + 1].terrainData ~= nil then
			Registry.Members.src__engine__surface_load.load_area_terrain(index, area.gAreaData[index + 1].terrainData :: number, area.gAreaData[index + 1].surfaceRooms, area.gAreaData[index + 1].macroObjects)
		end

		if area.gAreaData[index + 1].objectSpawnInfos ~= nil then
			Registry.Members.src__game__object_list_processor.spawn_objects_from_info(0, area.gAreaData[index + 1].objectSpawnInfos)
		end

		area.load_obj_warp_nodes()
		Registry.Members.src__engine__graph_node.geo_call_global_function_nodes(area.gAreaData[index + 1].unk04 :: GroupsTypesHPlus3Types.GraphNodeRoot, GroupsTypesHPlus3.GEO_CONTEXT_AREA_LOAD)
	end
end

-- from src/game/area.c:unload_area L250-259
function area.unload_area()
	if area.gCurrentArea ~= nil then
		const currentArea = area.gCurrentArea :: GroupsTypesHPlus3Types.Area

		Registry.Members.src__game__object_list_processor.unload_objects_from_area(0, currentArea.index)
		Registry.Members.src__engine__graph_node.geo_call_global_function_nodes(currentArea.unk04 :: GroupsTypesHPlus3Types.GraphNodeRoot, GroupsTypesHPlus3.GEO_CONTEXT_AREA_UNLOAD)

		currentArea.flags = 0
		area.gCurrentArea = nil
		area.gWarpTransition.isActive = IncludePRUltratypesH.FALSE
	end
end

-- from src/game/area.c:load_mario_area L261-269
function area.load_mario_area()
	Audio.stop_sounds_in_continuous_banks()
	area.load_area(area.gMarioSpawnInfo.areaIndex)

	if (area.gCurrentArea :: GroupsTypesHPlus3Types.Area).index == area.gMarioSpawnInfo.areaIndex then
		(area.gCurrentArea :: GroupsTypesHPlus3Types.Area).flags = S8(bit32.bor((area.gCurrentArea :: GroupsTypesHPlus3Types.Area).flags, 0x01))
		Registry.Members.src__game__object_list_processor.spawn_objects_from_info(0, area.gMarioSpawnInfo)
	end
end

-- from src/game/area.c:unload_mario_area L271-280
function area.unload_mario_area()
	if area.gCurrentArea ~= nil and bit32.btest((area.gCurrentArea :: GroupsTypesHPlus3Types.Area).flags, 0x01) then
		const currentArea = area.gCurrentArea :: GroupsTypesHPlus3Types.Area

		Registry.Members.src__game__object_list_processor.unload_objects_from_area(0, area.gMarioSpawnInfo.activeAreaIndex)
		currentArea.flags = S8(bit32.band(currentArea.flags, bit32.bnot(0x01)))

		if currentArea.flags == 0 then
			area.unload_area()
		end
	end
end

-- from src/game/area.c:change_area L282-296
function area.change_area(index: number)
	const areaFlags = (area.gCurrentArea :: GroupsTypesHPlus3Types.Area).flags

	if area.gCurrAreaIndex ~= index then
		area.unload_area()
		area.load_area(index)

		const currentArea = area.gCurrentArea :: GroupsTypesHPlus3Types.Area

		currentArea.flags = S8(areaFlags)
		buffer.writeu32(Registry.Members.src__game__object_list_processor.gMarioObject.rawData, IncludeObjectFieldsH.oActiveParticleFlags, 0)
	end

	if bit32.btest(areaFlags, 0x01) then
		Registry.Members.src__game__object_list_processor.gMarioObject.header.gfx.areaIndex = S8(index)
		area.gMarioSpawnInfo.areaIndex = S8(index)
	end
end

-- from src/game/area.c:area_update_objects L298-301
function area.area_update_objects()
	Registry.Members.src__game__rendering_graph_node.gAreaUpdateCounter = U16(Registry.Members.src__game__rendering_graph_node.gAreaUpdateCounter + 1)
	Registry.Members.src__game__object_list_processor.update_objects(0)
end

-- from src/game/area.c:play_transition L307-356
function area.play_transition(transType: number, time: number, red: number, green: number, blue: number)
	transType = S16(TruncS32(transType))
	time = S16(TruncS32(time))
	red = U8(TruncS32(red))
	green = U8(TruncS32(green))
	blue = U8(TruncS32(blue))
	area.gWarpTransition.isActive = IncludePRUltratypesH.TRUE
	area.gWarpTransition.type_ = U8(transType)
	area.gWarpTransition.time = U8(time)
	area.gWarpTransition.pauseRendering = IncludePRUltratypesH.FALSE

	-- The lowest bit of transType determines if the transition is fading in or out.
	if bit32.btest(transType, 1) then
		area.set_warp_transition_rgb(red, green, blue)
	else
		red = area.gWarpTransRed
		green = area.gWarpTransGreen
		blue = area.gWarpTransBlue
	end

	if transType < 8 then -- if transition is RGB
		area.gWarpTransition.data.red = red
		area.gWarpTransition.data.green = green
		area.gWarpTransition.data.blue = blue
	else -- if transition is textured
		area.gWarpTransition.data.red = red
		area.gWarpTransition.data.green = green
		area.gWarpTransition.data.blue = blue

		-- Start and end textured transitions are both centred on the screen.
		area.gWarpTransition.data.startTexX = S16(IncludeConfigH.SCREEN_WIDTH // 2)
		area.gWarpTransition.data.startTexY = S16(IncludeConfigH.SCREEN_HEIGHT // 2)
		area.gWarpTransition.data.endTexX = S16(IncludeConfigH.SCREEN_WIDTH // 2)
		area.gWarpTransition.data.endTexY = S16(IncludeConfigH.SCREEN_HEIGHT // 2)

		area.gWarpTransition.data.texTimer = 0

		if bit32.btest(transType, 1) then -- Is the image fading in?
			area.gWarpTransition.data.startTexRadius = IncludeGfxDimensionsH.GFX_DIMENSIONS_FULL_RADIUS

			if transType >= 0x0F then
				area.gWarpTransition.data.endTexRadius = 16
			else
				area.gWarpTransition.data.endTexRadius = 0
			end
		else -- The image is fading out. (Reverses start & end circles)
			if transType >= 0x0E then
				area.gWarpTransition.data.startTexRadius = 16
			else
				area.gWarpTransition.data.startTexRadius = 0
			end

			area.gWarpTransition.data.endTexRadius = IncludeGfxDimensionsH.GFX_DIMENSIONS_FULL_RADIUS
		end
	end
end

-- from src/game/area.c:play_transition_after_delay L363-366
function area.play_transition_after_delay(transType: number, time: number, red: number, green: number, blue: number, delay: number)
	transType = S16(TruncS32(transType))
	time = S16(TruncS32(time))
	red = U8(TruncS32(red))
	green = U8(TruncS32(green))
	blue = U8(TruncS32(blue))
	delay = S16(TruncS32(delay))
	area.gWarpTransDelay = delay
	area.play_transition(transType, time, red, green, blue)
end

-- from src/game/area.c:render_game L368-423
function area.render_game()
	if area.gCurrentArea ~= nil and area.gWarpTransition.pauseRendering == 0 then
		Registry.Members.src__game__rendering_graph_node.geo_process_root((area.gCurrentArea :: GroupsTypesHPlus3Types.Area).unk04 :: GroupsTypesHPlus3Types.GraphNodeRoot, area.D_8032CE74, area.D_8032CE78, area.gFBSetColor)

		-- gSPViewport(&D_8032CF00): no call, the renderer draws the commands after the geo traversal on the full screen (gfx-display-list-pool)
		Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, IncludeConfigH.BORDER_HEIGHT, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT)
		Registry.Members.src__game__hud.render_hud()

		Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, 0, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT)
		Print.render_text_labels()
		Registry.Members.groups__ingame_menu_plus1.do_cutscene_handler()
		Registry.Members.src__game__mario_actions_cutscene.print_displaying_credits_entry()

		Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, IncludeConfigH.BORDER_HEIGHT, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT)
		area.gMenuOptSelectIndex = Registry.Members.groups__ingame_menu_plus1.render_menus_and_dialogs()

		if area.gMenuOptSelectIndex ~= GroupsTypesHPlus3.MENU_OPT_NONE then
			area.gSaveOptSelectIndex = area.gMenuOptSelectIndex
		end

		if area.D_8032CE78 ~= nil then
			GameInit.make_viewport_clip_rect(area.D_8032CE78)
		else
			Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, IncludeConfigH.BORDER_HEIGHT, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT)
		end

		if area.gWarpTransition.isActive ~= 0 then
			if area.gWarpTransDelay == 0 then
				area.gWarpTransition.isActive = if Registry.Members.src__game__excluded_callbacks.render_screen_transition(0, area.gWarpTransition.type_, area.gWarpTransition.time, area.gWarpTransition.data) == 0 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE

				if area.gWarpTransition.isActive == 0 then
					if bit32.btest(area.gWarpTransition.type_, 1) then
						area.gWarpTransition.pauseRendering = IncludePRUltratypesH.TRUE
					else
						area.set_warp_transition_rgb(0, 0, 0)
					end
				end
			else
				area.gWarpTransDelay = S16(area.gWarpTransDelay - 1)
			end
		end
	else
		Print.render_text_labels()

		if area.D_8032CE78 ~= nil then
			GameInit.clear_viewport(area.D_8032CE78, area.gWarpTransFBSetColor)
		else
			GameInit.clear_framebuffer(area.gWarpTransFBSetColor)
		end
	end

	area.D_8032CE74 = nil
	area.D_8032CE78 = nil
end

-- from src/game/area.c:gMarioSpawnInfo L39-39
area.gMarioSpawnInfo = area.gPlayerSpawnInfos[1]

-- from src/game/area.c:gLoadedGraphNodes L40-40
area.gLoadedGraphNodes = area.D_8033A160

-- from src/game/area.c:gAreas L41-41
area.gAreas = area.gAreaData

return area
