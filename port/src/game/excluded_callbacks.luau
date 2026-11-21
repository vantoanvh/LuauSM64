--!strict
--!optimize 2

--[[
	The geo callbacks and behavior natives of the files that draft.sh excludes (screen_transition.c, debug.c) which script slots
	name (NativeCalls looks them up by name in the registered modules); moving_texture.c is src/game/moving_texture.

	Design Notes
		Hand written (excluded-geo-callbacks): what the C does to hashed state is ported 1:1; screen_transition.c is complete and
		writes its display lists through Gbi (gfx-display-list-pool); what only prints returns nothing (debug-print-externals).
		make_vertex of geo_misc.c is here because its drafted stub drops the vertex words (moving_texture uses it). Delete this
		module with its loader line once the draft includes the two files.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const IncludeConfigH = require("../../include/config_h")
const IncludeGfxDimensionsH = require("../../include/gfx_dimensions_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Gbi = require("../rom/gbi")
const MenuSymbols = require("../rom/menu_symbols")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const Area = require("./area")
const GeoMisc = require("./geo_misc")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/screen_transition.h:data
const ExcludedCallbacks = {
	TEX_TRANS_STAR = 0,
	TEX_TRANS_CIRCLE = 1,
	TEX_TRANS_MARIO = 2,
	TEX_TRANS_BOWSER = 3,
	TRANS_TYPE_MIRROR = 0,
	TRANS_TYPE_CLAMP = 1,
	-- from src/game/screen_transition.c:sTransitionColorFadeCount L18-18
	sTransitionColorFadeCount = table.create(4, 0),
	-- from src/game/screen_transition.c:sTransitionTextureFadeCount L19-19
	sTransitionTextureFadeCount = table.create(2, 0),
	-- from src/game/screen_transition.c:sTextureTransitionID L164-169
	sTextureTransitionID = { MenuSymbols.texture_transition_star_half, MenuSymbols.texture_transition_circle_half, MenuSymbols.texture_transition_mario, MenuSymbols.texture_transition_bowser_half },
}

Registry.Register("src__game__excluded_callbacks", ExcludedCallbacks)

-- from src/game/screen_transition.c:set_and_reset_transition_fade_timer L22-33
function ExcludedCallbacks.set_and_reset_transition_fade_timer(fadeTimer: number, transTime: number): number
	local reset = IncludePRUltratypesH.FALSE

	ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] = U8(ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] + 1)

	if ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] == transTime then
		ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] = 0
		ExcludedCallbacks.sTransitionTextureFadeCount[fadeTimer + 1] = 0
		reset = IncludePRUltratypesH.TRUE
	end

	return reset
end

-- from src/game/screen_transition.c:set_transition_color_fade_alpha L35-46
function ExcludedCallbacks.set_transition_color_fade_alpha(fadeType: number, fadeTimer: number, transTime: number): number
	local time = 0

	if fadeType == 0 then
		time = U8(TruncS32(ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] * 255.0 / (transTime - 1) + 0.5)) -- fade in
	elseif fadeType == 1 then
		time = U8(TruncS32((1.0 - F32(ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] / (transTime - 1))) * 255.0 + 0.5)) -- fade out
	end

	return time
end

-- from src/game/geo_misc.c:make_vertex L46-64 (a Vtx is 16 bytes of Memory: the position, the flag, the texture coordinates and the color)
function ExcludedCallbacks.make_vertex(vtx: number, n: number, x: number, y: number, z: number, tx: number, ty: number, r: number, g: number, b: number, a: number)
	const at = vtx + n * 16

	Rom.WriteS16(at, x)
	Rom.WriteS16(at + 2, y)
	Rom.WriteS16(at + 4, z)
	Rom.WriteS16(at + 6, 0)
	Rom.WriteS16(at + 8, tx)
	Rom.WriteS16(at + 10, ty)
	Rom.WriteU8(at + 12, r)
	Rom.WriteU8(at + 13, g)
	Rom.WriteU8(at + 14, b)
	Rom.WriteU8(at + 15, a)
end

-- from src/game/screen_transition.c:vertex_transition_color L48-62
function ExcludedCallbacks.vertex_transition_color(transData: GroupsTypesHPlus3Types.WarpTransitionData, alpha: number): number?
	const verts = Gbi.alloc_display_list(4 * 16)
	const r = transData.red
	const g = transData.green
	const b = transData.blue

	if verts ~= nil then
		ExcludedCallbacks.make_vertex(verts, 0, IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_LEFT_EDGE(0), 0, -1, 0, 0, r, g, b, alpha)
		ExcludedCallbacks.make_vertex(verts, 1, IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_RIGHT_EDGE(0), 0, -1, 0, 0, r, g, b, alpha)
		ExcludedCallbacks.make_vertex(verts, 2, IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_RIGHT_EDGE(0), IncludeConfigH.SCREEN_HEIGHT, -1, 0, 0, r, g, b, alpha)
		ExcludedCallbacks.make_vertex(verts, 3, IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_LEFT_EDGE(0), IncludeConfigH.SCREEN_HEIGHT, -1, 0, 0, r, g, b, alpha)
	end

	return verts
end

-- from src/game/screen_transition.c:dl_transition_color L64-77
function ExcludedCallbacks.dl_transition_color(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData, alpha: number): number
	const verts = ExcludedCallbacks.vertex_transition_color(transData, alpha)

	if verts ~= nil then
		Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
		Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)
		Gbi.gDPSetRenderMode(Gbi.G_RM_AA_XLU_SURF, Gbi.G_RM_AA_XLU_SURF2)
		Gbi.gSPVertex(verts, 4, 0)
		Gbi.gSPDisplayList(Segment2Symbols.dl_draw_quad_verts_0123)
		Gbi.gSPDisplayList(Segment2Symbols.dl_screen_transition_end)
	end

	return ExcludedCallbacks.set_and_reset_transition_fade_timer(fadeTimer, transTime)
end

-- from src/game/screen_transition.c:render_fade_transition_from_color L79-83
function ExcludedCallbacks.render_fade_transition_from_color(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	const alpha = ExcludedCallbacks.set_transition_color_fade_alpha(1, fadeTimer, transTime)

	return ExcludedCallbacks.dl_transition_color(fadeTimer, transTime, transData, alpha)
end

-- from src/game/screen_transition.c:render_fade_transition_into_color L85-89
function ExcludedCallbacks.render_fade_transition_into_color(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	const alpha = ExcludedCallbacks.set_transition_color_fade_alpha(0, fadeTimer, transTime)

	return ExcludedCallbacks.dl_transition_color(fadeTimer, transTime, transData, alpha)
end

-- from src/game/screen_transition.c:calc_tex_transition_radius L91-97
function ExcludedCallbacks.calc_tex_transition_radius(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	const texRadius = F32(transData.endTexRadius - transData.startTexRadius)
	const radiusTime = F32(F32(ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] * texRadius) / (transTime - 1))
	const result = F32(transData.startTexRadius + radiusTime)

	return S16(TruncS32(result + 0.5))
end

-- from src/game/screen_transition.c:calc_tex_transition_time L99-108
function ExcludedCallbacks.calc_tex_transition_time(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	const startX = transData.startTexX
	const startY = transData.startTexY
	const endX = transData.endTexX
	const endY = transData.endTexY
	const sqrtfXY = F32(math.sqrt(F32(F32(F32(startX - endX) * F32(startX - endX)) + F32(F32(startY - endY) * F32(startY - endY)))))

	return F32(F32(ExcludedCallbacks.sTransitionColorFadeCount[fadeTimer + 1] * sqrtfXY) / (transTime - 1))
end

-- from src/game/screen_transition.c:convert_tex_transition_angle_to_pos L110-115
function ExcludedCallbacks.convert_tex_transition_angle_to_pos(transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	const x = F32(transData.endTexX - transData.startTexX)
	const y = F32(transData.endTexY - transData.startTexY)

	return SrcEngineMathUtil.atan2s(x, y)
end

-- from src/game/screen_transition.c:center_tex_transition_x L117-121
function ExcludedCallbacks.center_tex_transition_x(transData: GroupsTypesHPlus3Types.WarpTransitionData, texTransTime: number, texTransPos: number): number
	const x = F32(transData.startTexX + F32(SrcEngineMathUtilH.coss(texTransPos) * texTransTime))

	return S16(TruncS32(x + 0.5))
end

-- from src/game/screen_transition.c:center_tex_transition_y L123-127
function ExcludedCallbacks.center_tex_transition_y(transData: GroupsTypesHPlus3Types.WarpTransitionData, texTransTime: number, texTransPos: number): number
	const y = F32(transData.startTexY + F32(SrcEngineMathUtilH.sins(texTransPos) * texTransTime))

	return S16(TruncS32(y + 0.5))
end

-- from src/game/screen_transition.c:make_tex_transition_vertex L129-140
function ExcludedCallbacks.make_tex_transition_vertex(verts: number, n: number, fadeTimer: number, transData: GroupsTypesHPlus3Types.WarpTransitionData, centerTransX: number, centerTransY: number, texRadius1: number, texRadius2: number, tx: number, ty: number)
	const r = transData.red
	const g = transData.green
	const b = transData.blue
	const zeroTimer = ExcludedCallbacks.sTransitionTextureFadeCount[fadeTimer + 1]
	const centerX = F32(F32(F32(texRadius1 * SrcEngineMathUtilH.coss(zeroTimer)) - F32(texRadius2 * SrcEngineMathUtilH.sins(zeroTimer))) + centerTransX)
	const centerY = F32(F32(F32(texRadius1 * SrcEngineMathUtilH.sins(zeroTimer)) + F32(texRadius2 * SrcEngineMathUtilH.coss(zeroTimer))) + centerTransY)
	const x = GeoMisc.round_float(centerX)
	const y = GeoMisc.round_float(centerY)

	ExcludedCallbacks.make_vertex(verts, n, x, y, -1, tx * 32, ty * 32, r, g, b, 255)
end

-- from src/game/screen_transition.c:load_tex_transition_vertex L142-162
function ExcludedCallbacks.load_tex_transition_vertex(verts: number, fadeTimer: number, transData: GroupsTypesHPlus3Types.WarpTransitionData, centerTransX: number, centerTransY: number, texTransRadius: number, transTexType: number)
	if transTexType == ExcludedCallbacks.TRANS_TYPE_MIRROR then
		ExcludedCallbacks.make_tex_transition_vertex(verts, 0, fadeTimer, transData, centerTransX, centerTransY, -texTransRadius, -texTransRadius, -31, 63)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 1, fadeTimer, transData, centerTransX, centerTransY, texTransRadius, -texTransRadius, 31, 63)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 2, fadeTimer, transData, centerTransX, centerTransY, texTransRadius, texTransRadius, 31, 0)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 3, fadeTimer, transData, centerTransX, centerTransY, -texTransRadius, texTransRadius, -31, 0)
	elseif transTexType == ExcludedCallbacks.TRANS_TYPE_CLAMP then
		ExcludedCallbacks.make_tex_transition_vertex(verts, 0, fadeTimer, transData, centerTransX, centerTransY, -texTransRadius, -texTransRadius, 0, 63)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 1, fadeTimer, transData, centerTransX, centerTransY, texTransRadius, -texTransRadius, 63, 63)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 2, fadeTimer, transData, centerTransX, centerTransY, texTransRadius, texTransRadius, 63, 0)
		ExcludedCallbacks.make_tex_transition_vertex(verts, 3, fadeTimer, transData, centerTransX, centerTransY, -texTransRadius, texTransRadius, 0, 0)
	end

	ExcludedCallbacks.make_tex_transition_vertex(verts, 4, fadeTimer, transData, centerTransX, centerTransY, -2000, -2000, 0, 0)
	ExcludedCallbacks.make_tex_transition_vertex(verts, 5, fadeTimer, transData, centerTransX, centerTransY, 2000, -2000, 0, 0)
	ExcludedCallbacks.make_tex_transition_vertex(verts, 6, fadeTimer, transData, centerTransX, centerTransY, 2000, 2000, 0, 0)
	ExcludedCallbacks.make_tex_transition_vertex(verts, 7, fadeTimer, transData, centerTransX, centerTransY, -2000, 2000, 0, 0)
end

-- from src/game/screen_transition.c:render_textured_transition L172-210
function ExcludedCallbacks.render_textured_transition(fadeTimer: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData, texID: number, transTexType: number): number
	const texTransTime = ExcludedCallbacks.calc_tex_transition_time(fadeTimer, transTime, transData)
	const texTransPos = ExcludedCallbacks.convert_tex_transition_angle_to_pos(transData)
	const centerTransX = ExcludedCallbacks.center_tex_transition_x(transData, texTransTime, texTransPos)
	const centerTransY = ExcludedCallbacks.center_tex_transition_y(transData, texTransTime, texTransPos)
	const texTransRadius = ExcludedCallbacks.calc_tex_transition_radius(fadeTimer, transTime, transData)
	const verts = Gbi.alloc_display_list(8 * 16)

	if verts ~= nil then
		ExcludedCallbacks.load_tex_transition_vertex(verts, fadeTimer, transData, centerTransX, centerTransY, texTransRadius, transTexType)
		Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
		Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)
		Gbi.gDPSetRenderMode(Gbi.G_RM_AA_OPA_SURF, Gbi.G_RM_AA_OPA_SURF2)
		Gbi.gSPVertex(verts, 8, 0)
		Gbi.gSPDisplayList(Segment2Symbols.dl_transition_draw_filled_region)
		Gbi.gDPPipeSync()
		Gbi.gDPSetCombineMode(Gbi.G_CC_MODULATEIDECALA, Gbi.G_CC_MODULATEIDECALA)
		Gbi.gDPSetRenderMode(Gbi.G_RM_AA_XLU_SURF, Gbi.G_RM_AA_XLU_SURF2)
		Gbi.gDPSetTextureFilter(Gbi.G_TF_BILERP)

		if transTexType == ExcludedCallbacks.TRANS_TYPE_MIRROR then
			Gbi.gDPLoadTextureBlock(ExcludedCallbacks.sTextureTransitionID[texID + 1], Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 32, 64, 0, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_MIRROR), bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_MIRROR), 5, 6, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
		elseif transTexType == ExcludedCallbacks.TRANS_TYPE_CLAMP then
			Gbi.gDPLoadTextureBlock(ExcludedCallbacks.sTextureTransitionID[texID + 1], Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 64, 64, 0, Gbi.G_TX_CLAMP, Gbi.G_TX_CLAMP, 6, 6, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
		end

		Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
		Gbi.gSPVertex(verts, 4, 0)
		Gbi.gSPDisplayList(Segment2Symbols.dl_draw_quad_verts_0123)
		Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
		Gbi.gSPDisplayList(Segment2Symbols.dl_screen_transition_end)
		ExcludedCallbacks.sTransitionTextureFadeCount[fadeTimer + 1] = U16(ExcludedCallbacks.sTransitionTextureFadeCount[fadeTimer + 1] + transData.texTimer)
	end

	return ExcludedCallbacks.set_and_reset_transition_fade_timer(fadeTimer, transTime)
end

-- from src/game/screen_transition.c:render_screen_transition L212-249 (a transType without a transition gives 0, as AVOID_UB does)
function ExcludedCallbacks.render_screen_transition(fadeTimer: number, transType: number, transTime: number, transData: GroupsTypesHPlus3Types.WarpTransitionData): number
	fadeTimer = S8(TruncS32(fadeTimer))
	transType = S8(TruncS32(transType))
	transTime = U8(TruncS32(transTime))

	if transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR then
		return ExcludedCallbacks.render_fade_transition_from_color(fadeTimer, transTime, transData)
	elseif transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR then
		return ExcludedCallbacks.render_fade_transition_into_color(fadeTimer, transTime, transData)
	elseif transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_STAR or transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_STAR then
		return ExcludedCallbacks.render_textured_transition(fadeTimer, S8(transTime), transData, ExcludedCallbacks.TEX_TRANS_STAR, ExcludedCallbacks.TRANS_TYPE_MIRROR)
	elseif transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_CIRCLE or transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_CIRCLE then
		return ExcludedCallbacks.render_textured_transition(fadeTimer, S8(transTime), transData, ExcludedCallbacks.TEX_TRANS_CIRCLE, ExcludedCallbacks.TRANS_TYPE_MIRROR)
	elseif transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_MARIO or transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_MARIO then
		return ExcludedCallbacks.render_textured_transition(fadeTimer, S8(transTime), transData, ExcludedCallbacks.TEX_TRANS_MARIO, ExcludedCallbacks.TRANS_TYPE_CLAMP)
	elseif transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_BOWSER or transType == GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_BOWSER then
		return ExcludedCallbacks.render_textured_transition(fadeTimer, S8(transTime), transData, ExcludedCallbacks.TEX_TRANS_BOWSER, ExcludedCallbacks.TRANS_TYPE_MIRROR)
	end

	return 0
end

-- from src/game/screen_transition.c:render_cannon_circle_base L252-292
function ExcludedCallbacks.render_cannon_circle_base(): number?
	const verts = Gbi.alloc_display_list(4 * 16)
	const dlist = Gbi.alloc_display_list(16 * 8)

	if verts == nil or dlist == nil then
		return nil
	end

	ExcludedCallbacks.make_vertex(verts, 0, 0, 0, -1, -1152, 1824, 0, 0, 0, 255)
	ExcludedCallbacks.make_vertex(verts, 1, IncludeConfigH.SCREEN_WIDTH, 0, -1, 1152, 1824, 0, 0, 0, 255)
	ExcludedCallbacks.make_vertex(verts, 2, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT, -1, 1152, 192, 0, 0, 0, 255)
	ExcludedCallbacks.make_vertex(verts, 3, 0, IncludeConfigH.SCREEN_HEIGHT, -1, -1152, 192, 0, 0, 0, 255)

	const outer = Gbi.Redirect(dlist)

	Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
	Gbi.gDPSetCombineMode(Gbi.G_CC_MODULATEIDECALA, Gbi.G_CC_MODULATEIDECALA)
	Gbi.gDPSetTextureFilter(Gbi.G_TF_BILERP)
	Gbi.gDPLoadTextureBlock(ExcludedCallbacks.sTextureTransitionID[ExcludedCallbacks.TEX_TRANS_CIRCLE + 1], Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 32, 64, 0, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_MIRROR), bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_MIRROR), 5, 6, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
	Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
	Gbi.gSPVertex(verts, 4, 0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_quad_verts_0123)
	Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
	Gbi.gSPDisplayList(Segment2Symbols.dl_screen_transition_end)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(outer)

	return dlist
end

-- from src/game/screen_transition.c:geo_cannon_circle_base L294-304
function ExcludedCallbacks.geo_cannon_circle_base(callContext: number, node: GroupsTypesHPlus3Types.GraphNode, mtx: unknown): unknown
	const graphNode = node :: GroupsTypesHPlus3Types.GraphNodeGenerated
	const currentArea = Area.gCurrentArea
	local dlist: number? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER and currentArea ~= nil and (currentArea.camera :: GroupsTypesHPlus3Types.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON then
		graphNode.node.flags = S16(bit32.bor(bit32.band(graphNode.node.flags, 0xFF), 0x500))
		dlist = ExcludedCallbacks.render_cannon_circle_base()
	end

	return dlist
end

-- from src/game/debug.c:try_print_debug_mario_level_info L447-464
function ExcludedCallbacks.try_print_debug_mario_level_info()
	-- sDebugPage is DEBUG_PAGE_MIN (DEBUG_PAGE_OBJECTINFO): prints nothing (debug-print-externals)
end

-- from src/game/debug.c:try_do_mario_debug_object_spawn L473-489
function ExcludedCallbacks.try_do_mario_debug_object_spawn()
	-- needs sDebugPage == DEBUG_PAGE_STAGEINFO: never (excluded-geo-callbacks)
end

return ExcludedCallbacks
