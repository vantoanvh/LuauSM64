--!strict
--!optimize 2

--[[
	Port of src/game/moving_texture.c: the geo callbacks that draw water, lava, mist, sand and treadmills with moving textures.

	Design Notes
		Hand written (excluded-geo-callbacks, gfx-display-list-pool): draft.sh excludes the file, script slots name the callbacks
		(NativeCalls looks them up by name in the registered modules). The quad arrays (MovtexQuad) and the vertex meshes (Movtex)
		are ROM data read and written in Memory through Rom (an s16 array is a Memory address, `p[i]` is ReadS16(p + 2 * i)); the
		callbacks write their display lists into the Gfx pool, redirect the writer into the list they allocated (Gbi.Redirect) and
		return its Memory address, which the recorder keeps as the Draw's DisplayList.
		What a presenter may cache: the lists of geo_movtex_draw_water_regions, geo_movtex_draw_nocolor, geo_movtex_draw_colored and
		geo_movtex_draw_colored_no_update are rebuilt every frame, with the texture coordinates of their vertices scrolled (quads
		rotate their texture coordinates, meshes add the speed to the s of vertex 0); the callbacks that update only return nothing.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const Gbi = require("../rom/gbi")
const MenuSymbols = require("../rom/menu_symbols")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SegmentSymbols = require("../rom/segment_symbols")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const Area = require("./area")
const Camera = require("./camera")
const ExcludedCallbacks = require("./excluded_callbacks")
const GeoMiscH = require("./geo_misc_h")
const Memory = require("./memory")
const MovtexH = require("./moving_texture_h")
const ObjectListProcessor = require("./object_list_processor")
const Paintings = require("./paintings")
const RenderingGraphNode = require("./rendering_graph_node")
const SaveFile = require("./save_file")

-- from src/game/moving_texture.c:MovtexObject
export type MovtexObject = {
	geoId: number, -- number that geo nodes have as parameter to refer to this mesh
	textureId: number, -- index into gMovtexIdToTexture
	vtx_count: number, -- amount of moving vertices
	movtexVerts: number, -- segmented address to movtex mesh with vertices
	beginDl: number, -- display list inserted before moving triangles
	endDl: number, -- display list inserted after moving triangles
	triDl: number, -- display list with the actual moving texture triangles
	r: number,
	g: number,
	b: number,
	a: number,
	layer: number, -- the drawing layer for this mesh
}

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C double to s32 conversion; like the x86-64 `cvttsd2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- The s16 words of a MovtexQuad (rot, rotspeed, scale, x1, z1, x2, z2, x3, z3, x4, z4, rotDir, alpha, textureId)
const MovtexQuadWords = 14

-- A Vtx is 16 bytes, a Gfx 8
const VtxSize = 16
const GfxSize = 8

-- from src/game/moving_texture.c:data
const moving_texture = {
	-- First entry in array is texture movement speed for both layouts
	MOVTEX_ATTR_SPEED = 0,
	-- Different layouts for vertices
	MOVTEX_LAYOUT_NOCOLOR = 0,
	MOVTEX_LAYOUT_COLORED = 1,
	-- Attributes for movtex vertices
	MOVTEX_ATTR_X = 1,
	MOVTEX_ATTR_Y = 2,
	MOVTEX_ATTR_Z = 3,
	-- For MOVTEX_LAYOUT_NOCOLOR only
	MOVTEX_ATTR_NOCOLOR_S = 4,
	MOVTEX_ATTR_NOCOLOR_T = 5,
	-- For MOVTEX_LAYOUT_COLORED only
	MOVTEX_ATTR_COLORED_R = 4,
	MOVTEX_ATTR_COLORED_G = 5,
	MOVTEX_ATTR_COLORED_B = 6,
	MOVTEX_ATTR_COLORED_S = 7,
	MOVTEX_ATTR_COLORED_T = 8,
	-- Vertex colors for rectangles. Used to give mist a tint
	MOVTEX_VTX_COLOR_DEFAULT = 0, -- no tint (white vertex colors)
	MOVTEX_VTX_COLOR_YELLOW = 1, -- used for Hazy Maze Cave toxic haze
	MOVTEX_VTX_COLOR_RED = 2, -- used for Shifting Sand Land around the Tox box maze
	-- from src/game/moving_texture.c:gMovtexCounter L107-107
	gMovtexCounter = 1,
	-- from src/game/moving_texture.c:gMovtexCounterPrev L108-108
	gMovtexCounterPrev = 0,
	-- from src/game/moving_texture.c:gMovtexVtxColor L115-115
	gMovtexVtxColor = 0,
	-- from src/game/moving_texture.c:gWDWWaterLevelSet L121-121
	gWDWWaterLevelSet = IncludePRUltratypesH.FALSE,
	-- from src/game/moving_texture.c:gMovetexLastTextureId L395-395
	gMovetexLastTextureId = 0,
	-- from src/game/moving_texture.c:gMovtexIdToTexture L131-134
	gMovtexIdToTexture = {
		MenuSymbols.texture_waterbox_water,
		MenuSymbols.texture_waterbox_mist,
		MenuSymbols.texture_waterbox_jrb_water,
		MenuSymbols.texture_waterbox_unknown_water,
		MenuSymbols.texture_waterbox_lava,
		SegmentSymbols.ssl_quicksand,
		SegmentSymbols.ssl_pyramid_sand,
		SegmentSymbols.ttc_yellow_triangle,
	},
	-- from src/game/moving_texture.c:gMovtexNonColored L193-263 (without the zero terminator)
	gMovtexNonColored = {
		-- Inside the pyramid there is a sand pathway with the 5 secrets on it
		{ geoId = MovtexH.MOVTEX_PYRAMID_SAND_PATHWAY_FRONT, textureId = MovtexH.TEX_PYRAMID_SAND_SSL, vtx_count = 8, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_sand_pathway_front, beginDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_begin, endDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_end, triDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_front_end, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		{ geoId = MovtexH.MOVTEX_PYRAMID_SAND_PATHWAY_FLOOR, textureId = MovtexH.TEX_PYRAMID_SAND_SSL, vtx_count = 8, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_sand_pathway_floor, beginDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_floor_begin, endDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_floor_end, triDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_front_end, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE_INTER },
		{ geoId = MovtexH.MOVTEX_PYRAMID_SAND_PATHWAY_SIDE, textureId = MovtexH.TEX_PYRAMID_SAND_SSL, vtx_count = 6, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_sand_pathway_side, beginDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_begin, endDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_end, triDl = SegmentSymbols.ssl_dl_pyramid_sand_pathway_side_end, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		-- The waterfall outside the castle
		{ geoId = MovtexH.MOVTEX_CASTLE_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 15, movtexVerts = SegmentSymbols.castle_grounds_movtex_tris_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.castle_grounds_dl_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		-- Bowser in the Fire Sea has lava at 3 heights, lava_floor is the lowest and lava_second_section is the highest
		{ geoId = MovtexH.MOVTEX_BITFS_LAVA_FIRST, textureId = MovtexH.TEXTURE_LAVA, vtx_count = 4, movtexVerts = SegmentSymbols.bitfs_movtex_tris_lava_first_section, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.bitfs_dl_lava_sections, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_BITFS_LAVA_SECOND, textureId = MovtexH.TEXTURE_LAVA, vtx_count = 4, movtexVerts = SegmentSymbols.bitfs_movtex_tris_lava_second_section, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.bitfs_dl_lava_sections, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT },
		{ geoId = MovtexH.MOVTEX_BITFS_LAVA_FLOOR, textureId = MovtexH.TEXTURE_LAVA, vtx_count = 9, movtexVerts = SegmentSymbols.bitfs_movtex_tris_lava_floor, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.bitfs_dl_lava_floor, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT },
		-- Lava floor in Lethal Lava Land and the lava fall in the volcano
		{ geoId = MovtexH.MOVTEX_LLL_LAVA_FLOOR, textureId = MovtexH.TEXTURE_LAVA, vtx_count = 9, movtexVerts = SegmentSymbols.lll_movtex_tris_lava_floor, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.lll_dl_lava_floor, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xC8, layer = IncludeSm64H.LAYER_TRANSPARENT },
		{ geoId = MovtexH.MOVTEX_VOLCANO_LAVA_FALL, textureId = MovtexH.TEXTURE_LAVA, vtx_count = 16, movtexVerts = SegmentSymbols.lll_movtex_tris_lavafall_volcano, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.lll_dl_lavafall_volcano, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		-- Cavern of the metal Cap: the waterfall source, the stream around the switch and the waterfall of the castle grounds
		{ geoId = MovtexH.MOVTEX_COTMC_WATER, textureId = MovtexH.TEXTURE_WATER, vtx_count = 14, movtexVerts = SegmentSymbols.cotmc_movtex_tris_water, beginDl = SegmentSymbols.cotmc_dl_water_begin, endDl = SegmentSymbols.cotmc_dl_water_end, triDl = SegmentSymbols.cotmc_dl_water, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		-- Tall, Tall mountain has water going from the top to the bottom of the mountain
		{ geoId = MovtexH.MOVTEX_TTM_BEGIN_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 6, movtexVerts = SegmentSymbols.ttm_movtex_tris_begin_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.ttm_dl_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT },
		{ geoId = MovtexH.MOVTEX_TTM_END_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 6, movtexVerts = SegmentSymbols.ttm_movtex_tris_end_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.ttm_dl_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT },
		{ geoId = MovtexH.MOVTEX_TTM_BEGIN_PUDDLE_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 4, movtexVerts = SegmentSymbols.ttm_movtex_tris_begin_puddle_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.ttm_dl_bottom_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		{ geoId = MovtexH.MOVTEX_TTM_END_PUDDLE_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 4, movtexVerts = SegmentSymbols.ttm_movtex_tris_end_puddle_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.ttm_dl_bottom_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
		{ geoId = MovtexH.MOVTEX_TTM_PUDDLE_WATERFALL, textureId = MovtexH.TEXTURE_WATER, vtx_count = 8, movtexVerts = SegmentSymbols.ttm_movtex_tris_puddle_waterfall, beginDl = Segment2Symbols.dl_waterbox_rgba16_begin, endDl = Segment2Symbols.dl_waterbox_end, triDl = SegmentSymbols.ttm_dl_puddle_waterfall, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xB4, layer = IncludeSm64H.LAYER_TRANSPARENT_INTER },
	} :: { MovtexObject },
	-- from src/game/moving_texture.c:gMovtexColored L268-285 (without the zero terminator)
	gMovtexColored = {
		{ geoId = MovtexH.MOVTEX_SSL_PYRAMID_SIDE, textureId = MovtexH.TEX_QUICKSAND_SSL, vtx_count = 12, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_quicksand, beginDl = SegmentSymbols.ssl_dl_quicksand_begin, endDl = SegmentSymbols.ssl_dl_quicksand_end, triDl = SegmentSymbols.ssl_dl_pyramid_quicksand, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_SSL_PYRAMID_CORNER, textureId = MovtexH.TEX_QUICKSAND_SSL, vtx_count = 16, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_corners_quicksand, beginDl = SegmentSymbols.ssl_dl_quicksand_begin, endDl = SegmentSymbols.ssl_dl_quicksand_end, triDl = SegmentSymbols.ssl_dl_pyramid_corners_quicksand, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_SSL_COURSE_EDGE, textureId = MovtexH.TEX_QUICKSAND_SSL, vtx_count = 15, movtexVerts = SegmentSymbols.ssl_movtex_tris_sides_quicksand, beginDl = SegmentSymbols.ssl_dl_quicksand_begin, endDl = SegmentSymbols.ssl_dl_quicksand_end, triDl = SegmentSymbols.ssl_dl_sides_quicksand, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_TREADMILL_BIG, textureId = MovtexH.TEX_YELLOW_TRI_TTC, vtx_count = 12, movtexVerts = SegmentSymbols.ttc_movtex_tris_big_surface_treadmill, beginDl = SegmentSymbols.ttc_dl_surface_treadmill_begin, endDl = SegmentSymbols.ttc_dl_surface_treadmill_end, triDl = SegmentSymbols.ttc_dl_surface_treadmill, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_TREADMILL_SMALL, textureId = MovtexH.TEX_YELLOW_TRI_TTC, vtx_count = 12, movtexVerts = SegmentSymbols.ttc_movtex_tris_small_surface_treadmill, beginDl = SegmentSymbols.ttc_dl_surface_treadmill_begin, endDl = SegmentSymbols.ttc_dl_surface_treadmill_end, triDl = SegmentSymbols.ttc_dl_surface_treadmill, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
	} :: { MovtexObject },
	-- from src/game/moving_texture.c:gMovtexColored2 L290-298 (without the zero terminator)
	gMovtexColored2 = {
		{ geoId = MovtexH.MOVTEX_SSL_SAND_PIT_OUTSIDE, textureId = MovtexH.TEX_QUICKSAND_SSL, vtx_count = 8, movtexVerts = SegmentSymbols.ssl_movtex_tris_quicksand_pit, beginDl = SegmentSymbols.ssl_dl_quicksand_pit_begin, endDl = SegmentSymbols.ssl_dl_quicksand_pit_end, triDl = SegmentSymbols.ssl_dl_quicksand_pit, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
		{ geoId = MovtexH.MOVTEX_SSL_SAND_PIT_PYRAMID, textureId = MovtexH.TEX_PYRAMID_SAND_SSL, vtx_count = 8, movtexVerts = SegmentSymbols.ssl_movtex_tris_pyramid_quicksand_pit, beginDl = SegmentSymbols.ssl_dl_pyramid_quicksand_pit_begin, endDl = SegmentSymbols.ssl_dl_pyramid_quicksand_pit_end, triDl = SegmentSymbols.ssl_dl_quicksand_pit, r = 0xFF, g = 0xFF, b = 0xFF, a = 0xFF, layer = IncludeSm64H.LAYER_OPAQUE },
	} :: { MovtexObject },
	-- from src/game/moving_texture.c:get_quad_collection_from_id L541-594 (the segmented address of the collection of an id)
	sQuadCollections = {
		[MovtexH.BBH_MOVTEX_MERRY_GO_ROUND_WATER_ENTRANCE] = SegmentSymbols.bbh_movtex_merry_go_round_water_entrance,
		[MovtexH.BBH_MOVTEX_MERRY_GO_ROUND_WATER_SIDE] = SegmentSymbols.bbh_movtex_merry_go_round_water_side,
		[MovtexH.CCM_MOVTEX_PENGUIN_PUDDLE_WATER] = SegmentSymbols.ccm_movtex_penguin_puddle_water,
		[MovtexH.INSIDE_CASTLE_MOVTEX_GREEN_ROOM_WATER] = SegmentSymbols.inside_castle_movtex_green_room_water,
		[MovtexH.INSIDE_CASTLE_MOVTEX_MOAT_WATER] = SegmentSymbols.inside_castle_movtex_moat_water,
		[MovtexH.HMC_MOVTEX_DORRIE_POOL_WATER] = SegmentSymbols.hmc_movtex_dorrie_pool_water,
		[MovtexH.HMC_MOVTEX_TOXIC_MAZE_MIST] = SegmentSymbols.hmc_movtex_toxic_maze_mist,
		[MovtexH.SSL_MOVTEX_PUDDLE_WATER] = SegmentSymbols.ssl_movtex_puddle_water,
		[MovtexH.SSL_MOVTEX_TOXBOX_QUICKSAND_MIST] = SegmentSymbols.ssl_movtex_toxbox_quicksand_mist,
		[MovtexH.SL_MOVTEX_WATER] = SegmentSymbols.sl_movtex_water,
		[MovtexH.WDW_MOVTEX_AREA1_WATER] = SegmentSymbols.wdw_movtex_area1_water,
		[MovtexH.WDW_MOVTEX_AREA2_WATER] = SegmentSymbols.wdw_movtex_area2_water,
		[MovtexH.JRB_MOVTEX_WATER] = SegmentSymbols.jrb_movtex_water,
		[MovtexH.JRB_MOVTEX_INITIAL_MIST] = SegmentSymbols.jrb_movtex_initial_mist,
		[MovtexH.JRB_MOVTEX_SUNKEN_SHIP_WATER] = SegmentSymbols.jrb_movtex_sunken_ship_water,
		[MovtexH.THI_MOVTEX_AREA1_WATER] = SegmentSymbols.thi_movtex_area1_water,
		[MovtexH.THI_MOVTEX_AREA2_WATER] = SegmentSymbols.thi_movtex_area2_water,
		[MovtexH.CASTLE_GROUNDS_MOVTEX_WATER] = SegmentSymbols.castle_grounds_movtex_water,
		[MovtexH.LLL_MOVTEX_VOLCANO_FLOOR_LAVA] = SegmentSymbols.lll_movtex_volcano_floor_lava,
		[MovtexH.DDD_MOVTEX_AREA1_WATER] = SegmentSymbols.ddd_movtex_area1_water,
		[MovtexH.DDD_MOVTEX_AREA2_WATER] = SegmentSymbols.ddd_movtex_area2_water,
		[MovtexH.WF_MOVTEX_WATER] = SegmentSymbols.wf_movtex_water,
		[MovtexH.CASTLE_COURTYARD_MOVTEX_STAR_STATUE_WATER] = SegmentSymbols.castle_courtyard_movtex_star_statue_water,
		[MovtexH.TTM_MOVTEX_PUDDLE] = SegmentSymbols.ttm_movtex_puddle,
	} :: { [number]: number },
}

Registry.Register("src__game__moving_texture", moving_texture)

-- from src/game/moving_texture.c:geo_wdw_set_initial_water_level L304-327
function moving_texture.geo_wdw_set_initial_water_level(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): unknown
	local wdwWaterHeight = 0
	const regions = ObjectListProcessor.gEnvironmentRegions

	-- Why was this global variable needed when they could just check for GEO_CONTEXT_AREA_LOAD?
	if callContext ~= GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		moving_texture.gWDWWaterLevelSet = IncludePRUltratypesH.FALSE
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER and regions ~= nil and moving_texture.gWDWWaterLevelSet == 0 then
		if Paintings.gPaintingMarioYEntry <= 1382.4 then
			wdwWaterHeight = 31
		elseif Paintings.gPaintingMarioYEntry >= 1600.0 then
			wdwWaterHeight = 2816
		else
			wdwWaterHeight = 1024
		end

		for i = 0, Rom.ReadS16(regions) - 1 do
			Rom.WriteS16(regions + 2 * (i * 6 + 6), wdwWaterHeight)
		end

		moving_texture.gWDWWaterLevelSet = IncludePRUltratypesH.TRUE
	end

	return nil
end

-- from src/game/moving_texture.c:geo_movtex_pause_control L334-343
function moving_texture.geo_movtex_pause_control(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): unknown
	if callContext ~= GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		moving_texture.gMovtexCounterPrev = S16(RenderingGraphNode.gAreaUpdateCounter - 1)
		moving_texture.gMovtexCounter = S16(RenderingGraphNode.gAreaUpdateCounter)
	else
		moving_texture.gMovtexCounterPrev = moving_texture.gMovtexCounter
		moving_texture.gMovtexCounter = S16(RenderingGraphNode.gAreaUpdateCounter)
	end

	return nil
end

-- from src/game/moving_texture.c:movtex_make_quad_vertex L354-366
function moving_texture.movtex_make_quad_vertex(verts: number, index: number, x: number, y: number, z: number, rot: number, rotOffset: number, scale: number, alpha: number)
	const s = S16(TruncS32(32.0 * (32.0 * scale - 1.0) * SrcEngineMathUtilH.sins(S16(rot + rotOffset))))
	const t = S16(TruncS32(32.0 * (32.0 * scale - 1.0) * SrcEngineMathUtilH.coss(S16(rot + rotOffset))))

	if moving_texture.gMovtexVtxColor == moving_texture.MOVTEX_VTX_COLOR_YELLOW then
		ExcludedCallbacks.make_vertex(verts, index, x, y, z, s, t, 255, 255, 0, alpha)
	elseif moving_texture.gMovtexVtxColor == moving_texture.MOVTEX_VTX_COLOR_RED then
		ExcludedCallbacks.make_vertex(verts, index, x, y, z, s, t, 255, 0, 0, alpha)
	else
		ExcludedCallbacks.make_vertex(verts, index, x, y, z, s, t, 255, 255, 255, alpha)
	end
end

-- from src/game/moving_texture.c:movtex_gen_from_quad L400-461 (quad is the Memory address of a MovtexQuad)
function moving_texture.movtex_gen_from_quad(y: number, quad: number): number?
	const rotspeed = Rom.ReadS16(quad + 2)
	const scale = Rom.ReadS16(quad + 4)
	const x1 = Rom.ReadS16(quad + 6)
	const z1 = Rom.ReadS16(quad + 8)
	const x2 = Rom.ReadS16(quad + 10)
	const z2 = Rom.ReadS16(quad + 12)
	const x3 = Rom.ReadS16(quad + 14)
	const z3 = Rom.ReadS16(quad + 16)
	const x4 = Rom.ReadS16(quad + 18)
	const z4 = Rom.ReadS16(quad + 20)
	const rotDir = Rom.ReadS16(quad + 22)
	const alpha = Rom.ReadS16(quad + 24)
	const textureId = Rom.ReadS16(quad + 26)
	const verts = Gbi.alloc_display_list(4 * VtxSize)
	local gfxHead: number? = nil

	if textureId == moving_texture.gMovetexLastTextureId then
		gfxHead = Gbi.alloc_display_list(3 * GfxSize)
	else
		gfxHead = Gbi.alloc_display_list(8 * GfxSize)
	end

	if gfxHead == nil or verts == nil then
		return nil
	end

	if moving_texture.gMovtexCounter ~= moving_texture.gMovtexCounterPrev then
		Rom.WriteS16(quad, Rom.ReadS16(quad) + rotspeed)
	end

	const rot = Rom.ReadS16(quad)

	if rotDir == MovtexH.ROTATE_CLOCKWISE then
		moving_texture.movtex_make_quad_vertex(verts, 0, x1, y, z1, rot, 0, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 1, x2, y, z2, rot, 16384, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 2, x3, y, z3, rot, -32768, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 3, x4, y, z4, rot, -16384, scale, alpha)
	else -- ROTATE_COUNTER_CLOCKWISE
		moving_texture.movtex_make_quad_vertex(verts, 0, x1, y, z1, rot, 0, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 1, x2, y, z2, rot, -16384, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 2, x3, y, z3, rot, -32768, scale, alpha)
		moving_texture.movtex_make_quad_vertex(verts, 3, x4, y, z4, rot, 16384, scale, alpha)
	end

	const outer = Gbi.Redirect(gfxHead)

	-- Only add commands to change the texture when necessary
	if textureId ~= moving_texture.gMovetexLastTextureId then
		if textureId == MovtexH.TEXTURE_MIST then -- an ia16 texture
			GeoMiscH.gLoadBlockTexture(32, 32, Gbi.G_IM_FMT_IA, moving_texture.gMovtexIdToTexture[textureId + 1])
		else -- any rgba16 texture
			GeoMiscH.gLoadBlockTexture(32, 32, Gbi.G_IM_FMT_RGBA, moving_texture.gMovtexIdToTexture[textureId + 1])
		end

		moving_texture.gMovetexLastTextureId = textureId
	end

	Gbi.gSPVertex(verts, 4, 0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_quad_verts_0123)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(outer)

	return gfxHead
end

-- from src/game/moving_texture.c:movtex_gen_from_quad_array L469-490
function moving_texture.movtex_gen_from_quad_array(y: number, quadArrSegmented: number): number?
	const quadArr = Memory.segmented_to_virtual(quadArrSegmented)
	const numLists = Rom.ReadS16(quadArr)
	const gfxHead = Gbi.alloc_display_list((numLists + 1) * GfxSize)

	if gfxHead == nil then
		return nil
	end

	const outer = Gbi.Redirect(gfxHead)

	for i = 0, numLists - 1 do
		-- quadArr is an array of s16
		const subList = moving_texture.movtex_gen_from_quad(y, quadArr + 2 * (i * MovtexQuadWords + 1))

		if subList ~= nil then
			Gbi.gSPDisplayList(subList)
		end
	end

	Gbi.gSPEndDisplayList()
	Gbi.Redirect(outer)

	return gfxHead
end

-- from src/game/moving_texture.c:movtex_gen_quads_id L500-511 (a MovtexQuadCollection is an s16 id, 2 bytes of padding and a segmented pointer)
function moving_texture.movtex_gen_quads_id(id: number, y: number, movetexQuadsSegmented: number): number?
	const collection = Memory.segmented_to_virtual(movetexQuadsSegmented)
	local i = 0

	while Rom.ReadS16(collection + i * 8) ~= -1 do
		if Rom.ReadS16(collection + i * 8) == id then
			return moving_texture.movtex_gen_from_quad_array(y, Rom.ReadU32(collection + i * 8 + 4))
		end

		i += 1
	end

	return nil
end

-- from src/game/moving_texture.c:get_quad_collection_from_id L541-594
function moving_texture.get_quad_collection_from_id(id: number): number?
	return moving_texture.sQuadCollections[id]
end

-- from src/game/moving_texture.c:movtex_change_texture_format L600-615
function moving_texture.movtex_change_texture_format(quadCollectionId: number)
	if quadCollectionId == MovtexH.HMC_MOVTEX_TOXIC_MAZE_MIST then
		Gbi.gSPDisplayList(Segment2Symbols.dl_waterbox_ia16_begin)
	elseif quadCollectionId == MovtexH.SSL_MOVTEX_TOXBOX_QUICKSAND_MIST then
		Gbi.gSPDisplayList(Segment2Symbols.dl_waterbox_ia16_begin)
	elseif quadCollectionId == MovtexH.JRB_MOVTEX_INITIAL_MIST then
		Gbi.gSPDisplayList(Segment2Symbols.dl_waterbox_ia16_begin)
	else
		Gbi.gSPDisplayList(Segment2Symbols.dl_waterbox_rgba16_begin)
	end
end

-- from src/game/moving_texture.c:geo_movtex_draw_water_regions L622-681
function moving_texture.geo_movtex_draw_water_regions(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): number?
	local gfxHead: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated
		const regions = ObjectListProcessor.gEnvironmentRegions

		moving_texture.gMovtexVtxColor = moving_texture.MOVTEX_VTX_COLOR_DEFAULT

		if regions == nil then
			return nil
		end

		const numWaterBoxes = Rom.ReadS16(regions)

		gfxHead = Gbi.alloc_display_list((numWaterBoxes + 3) * GfxSize)

		if gfxHead == nil then
			return nil
		end

		if asGenerated.parameter == MovtexH.JRB_MOVTEX_INITIAL_MIST then
			if Camera.gLakituState.goalPos[2] < 1024.0 then -- if camera under water
				return nil
			end

			-- the "Plunder in the Sunken Ship" star in JRB is collected
			if bit32.btest(SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_JRB)), bit32.lshift(1, 0)) then
				return nil
			end
		elseif asGenerated.parameter == MovtexH.HMC_MOVTEX_TOXIC_MAZE_MIST then
			moving_texture.gMovtexVtxColor = moving_texture.MOVTEX_VTX_COLOR_YELLOW
		elseif asGenerated.parameter == MovtexH.SSL_MOVTEX_TOXBOX_QUICKSAND_MIST then
			moving_texture.gMovtexVtxColor = moving_texture.MOVTEX_VTX_COLOR_RED
		end

		const quadCollection = moving_texture.get_quad_collection_from_id(asGenerated.parameter)

		if quadCollection == nil then
			return nil
		end

		asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_TRANSPARENT_INTER, 8)))

		const outer = Gbi.Redirect(gfxHead)

		moving_texture.movtex_change_texture_format(asGenerated.parameter)
		moving_texture.gMovetexLastTextureId = -1

		for i = 0, numWaterBoxes - 1 do
			const waterId = Rom.ReadS16(regions + 2 * (i * 6 + 1))
			const waterY = Rom.ReadS16(regions + 2 * (i * 6 + 6))
			const subList = moving_texture.movtex_gen_quads_id(waterId, waterY, quadCollection)

			if subList ~= nil then
				Gbi.gSPDisplayList(subList)
			end
		end

		Gbi.gSPDisplayList(Segment2Symbols.dl_waterbox_end)
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)
	end

	return gfxHead
end

-- from src/game/moving_texture.c:update_moving_texture_offset L689-703 (attr is the index of the s16 to move)
function moving_texture.update_moving_texture_offset(movtexVerts: number, attr: number)
	const movSpeed = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_SPEED)
	const curOffset = movtexVerts + 2 * attr

	if moving_texture.gMovtexCounter ~= moving_texture.gMovtexCounterPrev then
		Rom.WriteS16(curOffset, Rom.ReadS16(curOffset) + movSpeed)

		-- note that texture coordinates are 6.10 fixed point, so this does modulo 1
		if Rom.ReadS16(curOffset) >= 1024 then
			Rom.WriteS16(curOffset, Rom.ReadS16(curOffset) - 1024)
		end

		if Rom.ReadS16(curOffset) <= -1024 then
			Rom.WriteS16(curOffset, Rom.ReadS16(curOffset) + 1024)
		end
	end
end

-- from src/game/moving_texture.c:movtex_write_vertex_first L711-743
function moving_texture.movtex_write_vertex_first(vtx: number, movtexVerts: number, c: MovtexObject, attrLayout: number)
	const x = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_X)
	const y = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_Y)
	const z = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_Z)
	const alpha = c.a

	if attrLayout == moving_texture.MOVTEX_LAYOUT_NOCOLOR then
		const s = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_NOCOLOR_S)
		const t = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_NOCOLOR_T)

		ExcludedCallbacks.make_vertex(vtx, 0, x, y, z, s, t, c.r, c.g, c.b, alpha)
	elseif attrLayout == moving_texture.MOVTEX_LAYOUT_COLORED then
		const r2 = U8(Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_COLORED_R))
		const g2 = U8(Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_COLORED_G))
		const b2 = U8(Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_COLORED_B))
		const s = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_COLORED_S)
		const t = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_COLORED_T)

		ExcludedCallbacks.make_vertex(vtx, 0, x, y, z, s, t, r2, g2, b2, alpha)
	end
end

-- from src/game/moving_texture.c:movtex_write_vertex_index L750-801
function moving_texture.movtex_write_vertex_index(verts: number, index: number, movtexVerts: number, d: MovtexObject, attrLayout: number)
	const alpha = d.a

	if attrLayout == moving_texture.MOVTEX_LAYOUT_NOCOLOR then
		const x = Rom.ReadS16(movtexVerts + 2 * (index * 5 + moving_texture.MOVTEX_ATTR_X))
		const y = Rom.ReadS16(movtexVerts + 2 * (index * 5 + moving_texture.MOVTEX_ATTR_Y))
		const z = Rom.ReadS16(movtexVerts + 2 * (index * 5 + moving_texture.MOVTEX_ATTR_Z))
		const baseS = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_NOCOLOR_S)
		const baseT = Rom.ReadS16(movtexVerts + 2 * moving_texture.MOVTEX_ATTR_NOCOLOR_T)
		const offS = Rom.ReadS16(movtexVerts + 2 * (index * 5 + moving_texture.MOVTEX_ATTR_NOCOLOR_S))
		const offT = Rom.ReadS16(movtexVerts + 2 * (index * 5 + moving_texture.MOVTEX_ATTR_NOCOLOR_T))
		const s = S16(baseS + offS * 32 * 32)
		const t = S16(baseT + offT * 32 * 32)

		ExcludedCallbacks.make_vertex(verts, index, x, y, z, s, t, d.r, d.g, d.b, alpha)
	elseif attrLayout == moving_texture.MOVTEX_LAYOUT_COLORED then
		const x = Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_X))
		const y = Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_Y))
		const z = Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_Z))
		const baseS = Rom.ReadS16(movtexVerts + 2 * 7)
		const baseT = Rom.ReadS16(movtexVerts + 2 * 8)
		const offS = Rom.ReadS16(movtexVerts + 2 * (index * 8 + 7))
		const offT = Rom.ReadS16(movtexVerts + 2 * (index * 8 + 8))
		const s = S16(baseS + offS * 32 * 32)
		const t = S16(baseT + offT * 32 * 32)
		const r2 = U8(Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_COLORED_R)))
		const g2 = U8(Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_COLORED_G)))
		const b2 = U8(Rom.ReadS16(movtexVerts + 2 * (index * 8 + moving_texture.MOVTEX_ATTR_COLORED_B)))

		ExcludedCallbacks.make_vertex(verts, index, x, y, z, s, t, r2, g2, b2, alpha)
	end
end

-- from src/game/moving_texture.c:movtex_gen_list L807-829
function moving_texture.movtex_gen_list(movtexVerts: number, movtexList: MovtexObject, attrLayout: number): number?
	const verts = Gbi.alloc_display_list(movtexList.vtx_count * VtxSize)
	const gfxHead = Gbi.alloc_display_list(11 * GfxSize)

	if verts == nil or gfxHead == nil then
		return nil
	end

	moving_texture.movtex_write_vertex_first(verts, movtexVerts, movtexList, attrLayout)

	for i = 1, movtexList.vtx_count - 1 do
		moving_texture.movtex_write_vertex_index(verts, i, movtexVerts, movtexList, attrLayout)
	end

	const outer = Gbi.Redirect(gfxHead)

	Gbi.gSPDisplayList(movtexList.beginDl)
	GeoMiscH.gLoadBlockTexture(32, 32, Gbi.G_IM_FMT_RGBA, moving_texture.gMovtexIdToTexture[movtexList.textureId + 1])
	Gbi.gSPVertex(verts, movtexList.vtx_count, 0)
	Gbi.gSPDisplayList(movtexList.triDl)
	Gbi.gSPDisplayList(movtexList.endDl)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(outer)

	return gfxHead
end

-- from src/game/moving_texture.c:geo_movtex_draw_nocolor L834-857
function moving_texture.geo_movtex_draw_nocolor(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): number?
	local gfx: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated

		for _, movtexObject in moving_texture.gMovtexNonColored do
			if movtexObject.geoId == asGenerated.parameter then
				asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(movtexObject.layer, 8)))

				const movtexVerts = Memory.segmented_to_virtual(movtexObject.movtexVerts)

				moving_texture.update_moving_texture_offset(movtexVerts, moving_texture.MOVTEX_ATTR_NOCOLOR_S)
				gfx = moving_texture.movtex_gen_list(movtexVerts, movtexObject, moving_texture.MOVTEX_LAYOUT_NOCOLOR) -- no perVertex colors

				break
			end
		end
	end

	return gfx
end

-- from src/game/moving_texture.c:geo_movtex_draw_colored L862-884
function moving_texture.geo_movtex_draw_colored(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): number?
	local gfx: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated

		for _, movtexObject in moving_texture.gMovtexColored do
			if movtexObject.geoId == asGenerated.parameter then
				asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(movtexObject.layer, 8)))

				const movtexVerts = Memory.segmented_to_virtual(movtexObject.movtexVerts)

				moving_texture.update_moving_texture_offset(movtexVerts, moving_texture.MOVTEX_ATTR_COLORED_S)
				gfx = moving_texture.movtex_gen_list(movtexVerts, movtexObject, moving_texture.MOVTEX_LAYOUT_COLORED)

				break
			end
		end
	end

	return gfx
end

-- from src/game/moving_texture.c:geo_movtex_draw_colored_no_update L893-914
function moving_texture.geo_movtex_draw_colored_no_update(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): number?
	local gfx: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated

		for _, movtexObject in moving_texture.gMovtexColored do
			if movtexObject.geoId == asGenerated.parameter then
				asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(movtexObject.layer, 8)))
				gfx = moving_texture.movtex_gen_list(Memory.segmented_to_virtual(movtexObject.movtexVerts), movtexObject, moving_texture.MOVTEX_LAYOUT_COLORED)

				break
			end
		end
	end

	return gfx
end

-- from src/game/moving_texture.c:geo_movtex_draw_colored_2_no_update L920-941
function moving_texture.geo_movtex_draw_colored_2_no_update(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): number?
	local gfx: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated

		for _, movtexObject in moving_texture.gMovtexColored2 do
			if movtexObject.geoId == asGenerated.parameter then
				asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(movtexObject.layer, 8)))
				gfx = moving_texture.movtex_gen_list(Memory.segmented_to_virtual(movtexObject.movtexVerts), movtexObject, moving_texture.MOVTEX_LAYOUT_COLORED)

				break
			end
		end
	end

	return gfx
end

-- from src/game/moving_texture.c:geo_movtex_update_horizontal L955-978
function moving_texture.geo_movtex_update_horizontal(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): unknown
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const asGenerated = node :: GroupsTypesHPlus3Types.GraphNodeGenerated
		local movtexVerts: number? = nil

		if asGenerated.parameter == MovtexH.MOVTEX_SSL_SAND_PIT_OUTSIDE then
			movtexVerts = Memory.segmented_to_virtual(SegmentSymbols.ssl_movtex_tris_quicksand_pit)
		elseif asGenerated.parameter == MovtexH.MOVTEX_SSL_SAND_PIT_PYRAMID then
			movtexVerts = Memory.segmented_to_virtual(SegmentSymbols.ssl_movtex_tris_pyramid_quicksand_pit)
		elseif asGenerated.parameter == MovtexH.MOVTEX_TREADMILL_BIG then
			movtexVerts = Memory.segmented_to_virtual(SegmentSymbols.ttc_movtex_tris_big_surface_treadmill)
		elseif asGenerated.parameter == MovtexH.MOVTEX_TREADMILL_SMALL then
			movtexVerts = Memory.segmented_to_virtual(SegmentSymbols.ttc_movtex_tris_small_surface_treadmill)
		end

		if movtexVerts ~= nil then
			moving_texture.update_moving_texture_offset(movtexVerts, moving_texture.MOVTEX_ATTR_COLORED_S)
		end
	end

	return nil
end

return moving_texture
