--!strict
--!optimize 2

--[[
	Port of src/menu/intro_geo.c.

	Design Notes
		The callbacks return the Memory address of the display list they wrote into the Gfx pool (a number, which the recorder keeps
		as the Draw's DisplayList), not a table; the macros fill the list the callback redirected the writer to (Gbi.Redirect), as the
		C does through its local `dlIter`. GraphNodeMore.unk18 is the word at 0x18 of the node, which is the parameter of the
		GraphNodeGenerated the geo layout makes.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeSm64H = require("../../include/sm64_h")
const Gbi = require("../rom/gbi")
const MenuSymbols = require("../rom/menu_symbols")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SrcGameMemory = require("../game/memory")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/menu/intro_geo.c:data
const intro_geo = {
	INTRO_STEPS_ZOOM_IN = 20,
	INTRO_STEPS_HOLD_1 = 75,
	INTRO_STEPS_ZOOM_OUT = 91,
	INTRO_BACKGROUND_SUPER_MARIO = 0,
	INTRO_BACKGROUND_GAME_OVER = 1,
	-- from src/menu/intro_geo.c:sGameOverFrameCounter L33-33
	sGameOverFrameCounter = 0,
	-- from src/menu/intro_geo.c:sGameOverTableIndex L34-34
	sGameOverTableIndex = 0,
	-- from src/menu/intro_geo.c:sIntroFrameCounter L35-35
	sIntroFrameCounter = 0,
	-- from src/menu/intro_geo.c:sTmCopyrightAlpha L36-36
	sTmCopyrightAlpha = 0,
	-- from src/menu/intro_geo.c:introBackgroundDlRows L141-142
	introBackgroundDlRows = {
		MenuSymbols.title_screen_bg_dl_0A000130,
		MenuSymbols.title_screen_bg_dl_0A000148,
		MenuSymbols.title_screen_bg_dl_0A000160,
		MenuSymbols.title_screen_bg_dl_0A000178,
	},
	-- from src/menu/intro_geo.c:xCoords L145-149
	xCoords = { 0, 80, 160, 240, 0, 80, 160, 240, 0, 80, 160, 240 },
	-- from src/menu/intro_geo.c:yCoords L152-156
	yCoords = { 160, 160, 160, 160, 80, 80, 80, 80, 0, 0, 0, 0 },
	-- from src/menu/intro_geo.c:textureTables L159-159
	textureTables = { MenuSymbols.mario_title_texture_table, MenuSymbols.game_over_texture_table },
	-- from src/menu/intro_geo.c:flipOrder L251-251
	flipOrder = { 0, 1, 2, 3, 7, 11, 10, 9, 8, 4, 5, 6 },
}

Registry.Register("src__menu__intro_geo", intro_geo)

-- from src/menu/intro_geo.c:geo_intro_super_mario_64_logo L41-92
function intro_geo.geo_intro_super_mario_64_logo(state: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	local dl: number? = nil
	const scaleTable1 = SrcGameMemory.segmented_to_virtual(MenuSymbols.intro_seg7_table_0700C790)
	const scaleTable2 = SrcGameMemory.segmented_to_virtual(MenuSymbols.intro_seg7_table_0700C880)

	if state ~= 1 then
		intro_geo.sIntroFrameCounter = 0
	elseif state == 1 then
		node.flags = S16(bit32.bor(bit32.band(node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))

		const scaleMat = Gbi.alloc_display_list(64) :: number

		dl = Gbi.alloc_display_list(4 * 8) :: number

		local scaleX = 0.0
		local scaleY = 0.0
		local scaleZ = 0.0

		-- determine scale based on the frame counter
		if intro_geo.sIntroFrameCounter >= 0 and intro_geo.sIntroFrameCounter < intro_geo.INTRO_STEPS_ZOOM_IN then
			-- zooming in
			scaleX = Rom.ReadF32(scaleTable1 + intro_geo.sIntroFrameCounter * 12)
			scaleY = Rom.ReadF32(scaleTable1 + intro_geo.sIntroFrameCounter * 12 + 4)
			scaleZ = Rom.ReadF32(scaleTable1 + intro_geo.sIntroFrameCounter * 12 + 8)
		elseif intro_geo.sIntroFrameCounter >= intro_geo.INTRO_STEPS_ZOOM_IN and intro_geo.sIntroFrameCounter < intro_geo.INTRO_STEPS_HOLD_1 then
			-- holding
			scaleX = 1.0
			scaleY = 1.0
			scaleZ = 1.0
		elseif intro_geo.sIntroFrameCounter >= intro_geo.INTRO_STEPS_HOLD_1 and intro_geo.sIntroFrameCounter < intro_geo.INTRO_STEPS_ZOOM_OUT then
			-- zooming out
			scaleX = Rom.ReadF32(scaleTable2 + (intro_geo.sIntroFrameCounter - intro_geo.INTRO_STEPS_HOLD_1) * 12)
			scaleY = Rom.ReadF32(scaleTable2 + (intro_geo.sIntroFrameCounter - intro_geo.INTRO_STEPS_HOLD_1) * 12 + 4)
			scaleZ = Rom.ReadF32(scaleTable2 + (intro_geo.sIntroFrameCounter - intro_geo.INTRO_STEPS_HOLD_1) * 12 + 8)
		end

		Gbi.guScale(scaleMat, scaleX, scaleY, scaleZ)

		const outer = Gbi.Redirect(dl)

		Gbi.gSPMatrix(scaleMat, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
		Gbi.gSPDisplayList(MenuSymbols.intro_seg7_dl_logo) -- draw model
		Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)

		intro_geo.sIntroFrameCounter = S16(intro_geo.sIntroFrameCounter + 1)
	end

	return dl
end

-- from src/menu/intro_geo.c:geo_intro_tm_copyright L97-131
function intro_geo.geo_intro_tm_copyright(state: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	local dl: number? = nil

	if state ~= 1 then -- reset
		intro_geo.sTmCopyrightAlpha = 0
	elseif state == 1 then -- draw
		dl = Gbi.alloc_display_list(5 * 8) :: number

		const outer = Gbi.Redirect(dl)

		Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
		Gbi.gDPSetEnvColor(255, 255, 255, intro_geo.sTmCopyrightAlpha)

		if intro_geo.sTmCopyrightAlpha == 255 then -- opaque
			node.flags = S16(bit32.bor(bit32.band(node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_OPA_SURF, Gbi.G_RM_AA_OPA_SURF2)
		else -- blend
			node.flags = S16(bit32.bor(bit32.band(node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_TRANSPARENT, 8)))
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_XLU_SURF, Gbi.G_RM_AA_XLU_SURF2)
		end

		Gbi.gSPDisplayList(MenuSymbols.intro_seg7_dl_copyright) -- draw model
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)

		-- Once the "Super Mario 64" logo has just about zoomed fully, fade in the "TM" and copyright text
		if intro_geo.sIntroFrameCounter >= 19 then
			intro_geo.sTmCopyrightAlpha += 26

			if intro_geo.sTmCopyrightAlpha > 255 then
				intro_geo.sTmCopyrightAlpha = 255
			end
		end
	end

	return dl
end

-- from src/menu/intro_geo.c:intro_backdrop_one_image L139-178
function intro_geo.intro_backdrop_one_image(index: number, backgroundTable: { number }): number
	const mtx = Gbi.alloc_display_list(64) :: number
	const displayList = Gbi.alloc_display_list(36 * 8) :: number
	const vIntroBgTable = SrcGameMemory.segmented_to_virtual(intro_geo.textureTables[backgroundTable[index + 1] + 1])

	Gbi.guTranslate(mtx, intro_geo.xCoords[index + 1], intro_geo.yCoords[index + 1], 0.0)

	const outer = Gbi.Redirect(displayList)

	Gbi.gSPMatrix(mtx, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_PUSH))
	Gbi.gSPDisplayList(MenuSymbols.title_screen_bg_dl_0A000118)

	for i = 0, 3 do
		Gbi.gDPLoadTextureBlock(Rom.ReadU32(vIntroBgTable + i * 4), Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 80, 20, 0, Gbi.G_TX_CLAMP, Gbi.G_TX_CLAMP, 7, 6, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
		Gbi.gSPDisplayList(intro_geo.introBackgroundDlRows[i + 1])
	end

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(outer)

	return displayList
end

-- from src/menu/intro_geo.c:geo_intro_regular_backdrop L193-214
function intro_geo.geo_intro_regular_backdrop(state: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	const index = bit32.band((node :: GroupsTypesHPlus3.GraphNodeGenerated).parameter, 0xFF) -- unk18
	const backgroundTable = intro_geo.introBackgroundTables[index + 1]
	local dl: number? = nil

	if state == 1 then -- draw
		dl = Gbi.alloc_display_list(16 * 8) :: number
		node.flags = S16(bit32.bor(bit32.band(node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))

		const outer = Gbi.Redirect(dl)

		Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
		Gbi.gSPDisplayList(MenuSymbols.title_screen_bg_dl_0A000100)

		for i = 0, 11 do
			Gbi.gSPDisplayList(intro_geo.intro_backdrop_one_image(i, backgroundTable))
		end

		Gbi.gSPDisplayList(MenuSymbols.title_screen_bg_dl_0A000190)
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)
	end

	return dl
end

-- from src/menu/intro_geo.c:geo_intro_gameover_backdrop L226-273
function intro_geo.geo_intro_gameover_backdrop(state: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	local dl: number? = nil

	if state ~= 1 then -- reset
		intro_geo.sGameOverFrameCounter = 0
		intro_geo.sGameOverTableIndex = -2

		for i = 1, #intro_geo.gameOverBackgroundTable do
			intro_geo.gameOverBackgroundTable[i] = intro_geo.INTRO_BACKGROUND_GAME_OVER
		end
	else -- draw
		dl = Gbi.alloc_display_list(16 * 8) :: number

		if intro_geo.sGameOverTableIndex == -2 then
			if intro_geo.sGameOverFrameCounter == 180 then
				intro_geo.sGameOverTableIndex = S16(intro_geo.sGameOverTableIndex + 1)
				intro_geo.sGameOverFrameCounter = 0
			end
		else
			-- transition tile from "Game Over" to "Super Mario 64"
			if intro_geo.sGameOverTableIndex ~= 11 and not bit32.btest(intro_geo.sGameOverFrameCounter, 0x1) then
				intro_geo.sGameOverTableIndex = S16(intro_geo.sGameOverTableIndex + 1)
				intro_geo.gameOverBackgroundTable[intro_geo.flipOrder[intro_geo.sGameOverTableIndex + 1] + 1] = intro_geo.INTRO_BACKGROUND_SUPER_MARIO
			end
		end

		if intro_geo.sGameOverTableIndex ~= 11 then
			intro_geo.sGameOverFrameCounter = S16(intro_geo.sGameOverFrameCounter + 1)
		end

		node.flags = S16(bit32.bor(bit32.band(node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))

		-- draw all the tiles
		const outer = Gbi.Redirect(dl)

		Gbi.gSPDisplayList(Segment2Symbols.dl_proj_mtx_fullscreen)
		Gbi.gSPDisplayList(MenuSymbols.title_screen_bg_dl_0A000100)

		for j = 0, #intro_geo.gameOverBackgroundTable - 1 do
			Gbi.gSPDisplayList(intro_geo.intro_backdrop_one_image(j, intro_geo.gameOverBackgroundTable))
		end

		Gbi.gSPDisplayList(MenuSymbols.title_screen_bg_dl_0A000190)
		Gbi.gSPEndDisplayList()
		Gbi.Redirect(outer)
	end

	return dl
end

-- from src/menu/intro_geo.c:introBackgroundIndexTable L180-185
intro_geo.introBackgroundIndexTable = {
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
	intro_geo.INTRO_BACKGROUND_SUPER_MARIO,
}

-- from src/menu/intro_geo.c:introBackgroundTables L188-188
intro_geo.introBackgroundTables = { intro_geo.introBackgroundIndexTable }

-- from src/menu/intro_geo.c:gameOverBackgroundTable L216-221
intro_geo.gameOverBackgroundTable = {
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
	intro_geo.INTRO_BACKGROUND_GAME_OVER,
}

return intro_geo
