--!strict
--!optimize 2

--[[
	Port of src/game/hud.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const HudH = require("./hud_h")
const Area = require("./area")
const Camera = require("./camera")
const GameInit = require("./game_init")
const Gbi = require("../rom/gbi")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludeGfxDimensionsH = require("../../include/gfx_dimensions_h")
const IncludeSm64H = require("../../include/sm64_h")
const LevelUpdate = require("./level_update")
const LevelUpdateH = require("./level_update_h")
const Memory = require("./memory")
const Print = require("./print")
const PrintH = require("./print_h")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SegmentSymbols = require("../rom/segment_symbols")

-- from src/game/hud.c:PowerMeterHUD
export type PowerMeterHUD = {
	animation: number,
	x: number,
	y: number,
	unused: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/hud.c:data
const hud = {
	-- from src/game/hud.c:sPowerMeterStoredHealth L32-32
	sPowerMeterStoredHealth = 0,
	-- from src/game/hud.c:sPowerMeterHUD L34-39
	sPowerMeterHUD = { animation = HudH.POWER_METER_HIDDEN, x = 140, y = 166, unused = 1.0 },
	-- from src/game/hud.c:sPowerMeterVisibleTimer L44-44
	sPowerMeterVisibleTimer = 0,
	-- from src/game/hud.c:sUnusedHUDValue1 L48-48
	sUnusedHUDValue1 = 0,
	-- from src/game/hud.c:sUnusedHUDValue2 L49-49
	sUnusedHUDValue2 = 10,
	-- from src/game/hud.c:sCameraHUDStatus L54-54
	sCameraHUDStatus = GroupsTypesHPlus3.CAM_STATUS_NONE,
	HUD_TOP_Y = 209,
	HUD_STARS_X = 78,
}

Registry.Register("src__game__hud", hud)

-- from src/game/hud.c:PowerMeterHUD (zero-filled constructor)
function hud.new_PowerMeterHUD(): PowerMeterHUD
	return { animation = 0, x = 0, y = 0, unused = 0 } :: PowerMeterHUD
end

-- from src/game/hud.c:render_hud_tex_lut L59-65
function hud.render_hud_tex_lut(x: number, y: number, texture: number)
	Gbi.gDPPipeSync()
	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, texture)
	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_load_tex_block)
	Gbi.gSPTextureRectangle(bit32.lshift(x, 2), bit32.lshift(y, 2), bit32.lshift(x + 15, 2), bit32.lshift(y + 15, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(4, 10), bit32.lshift(1, 10))
end

-- from src/game/hud.c:render_hud_small_tex_lut L70-83
function hud.render_hud_small_tex_lut(x: number, y: number, texture: number)
	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 0, 0, Gbi.G_TX_LOADTILE, 0, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD)
	Gbi.gDPTileSync()
	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 2, 0, Gbi.G_TX_RENDERTILE, 0, Gbi.G_TX_CLAMP, 3, Gbi.G_TX_NOLOD, Gbi.G_TX_CLAMP, 3, Gbi.G_TX_NOLOD)
	Gbi.gDPSetTileSize(Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(8 - 1, Gbi.G_TEXTURE_IMAGE_FRAC), bit32.lshift(8 - 1, Gbi.G_TEXTURE_IMAGE_FRAC))
	Gbi.gDPPipeSync()
	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, texture)
	Gbi.gDPLoadSync()
	Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 8 * 8 - 1, Gbi.CALC_DXT(8, Gbi.G_IM_SIZ_16b_BYTES))
	Gbi.gSPTextureRectangle(bit32.lshift(x, 2), bit32.lshift(y, 2), bit32.lshift(x + 7, 2), bit32.lshift(y + 7, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(4, 10), bit32.lshift(1, 10))
end

-- from src/game/hud.c:render_power_meter_health_segment L88-98
function hud.render_power_meter_health_segment(numHealthWedges: number)
	numHealthWedges = S16(TruncS32(numHealthWedges))
	const healthLUT = Memory.segmented_to_virtual(SegmentSymbols.power_meter_health_segments_lut)

	Gbi.gDPPipeSync()
	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Rom.ReadU32(healthLUT + 4 * (numHealthWedges - 1)))
	Gbi.gDPLoadSync()
	Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 32 * 32 - 1, Gbi.CALC_DXT(32, Gbi.G_IM_SIZ_16b_BYTES))
	Gbi.gSP1Triangle(0, 1, 2, 0)
	Gbi.gSP1Triangle(0, 2, 3, 0)
end

-- from src/game/hud.c:render_dl_power_meter L104-124
function hud.render_dl_power_meter(numHealthWedges: number)
	numHealthWedges = S16(TruncS32(numHealthWedges))
	const mtx = Gbi.alloc_display_list(64)

	if mtx == nil then
		return
	end

	Gbi.guTranslate(mtx, F32(hud.sPowerMeterHUD.x), F32(hud.sPowerMeterHUD.y), 0)
	Gbi.gSPMatrix(mtx, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	Gbi.gSPDisplayList(SegmentSymbols.dl_power_meter_base)

	if numHealthWedges ~= 0 then
		Gbi.gSPDisplayList(SegmentSymbols.dl_power_meter_health_segments_begin)
		hud.render_power_meter_health_segment(numHealthWedges)
		Gbi.gSPDisplayList(SegmentSymbols.dl_power_meter_health_segments_end)
	end

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/hud.c:animate_power_meter_emphasized L130-140
function hud.animate_power_meter_emphasized()
	const hudDisplayFlags = S16(LevelUpdate.gHudDisplay.flags)

	if not bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_EMPHASIZE_POWER) then
		if hud.sPowerMeterVisibleTimer == 45.0 then
			hud.sPowerMeterHUD.animation = HudH.POWER_METER_DEEMPHASIZING
		end
	else
		hud.sPowerMeterVisibleTimer = 0
	end
end

-- from src/game/hud.c:animate_power_meter_deemphasizing L146-167
function hud.animate_power_meter_deemphasizing()
	local speed = 5

	if hud.sPowerMeterHUD.y > 180 then
		speed = 3
	end

	if hud.sPowerMeterHUD.y > 190 then
		speed = 2
	end

	if hud.sPowerMeterHUD.y > 195 then
		speed = 1
	end

	hud.sPowerMeterHUD.y = S16(hud.sPowerMeterHUD.y + speed)

	if hud.sPowerMeterHUD.y > 200 then
		hud.sPowerMeterHUD.y = 200
		hud.sPowerMeterHUD.animation = HudH.POWER_METER_VISIBLE
	end
end

-- from src/game/hud.c:animate_power_meter_hiding L173-179
function hud.animate_power_meter_hiding()
	hud.sPowerMeterHUD.y = S16(hud.sPowerMeterHUD.y + 20)

	if hud.sPowerMeterHUD.y > 300 then
		hud.sPowerMeterHUD.animation = HudH.POWER_METER_HIDDEN
		hud.sPowerMeterVisibleTimer = 0
	end
end

-- from src/game/hud.c:handle_power_meter_actions L184-214
function hud.handle_power_meter_actions(numHealthWedges: number)
	numHealthWedges = S16(TruncS32(numHealthWedges))
	-- Show power meter if health is not full, less than 8
	if numHealthWedges < 8 and hud.sPowerMeterStoredHealth == 8 and hud.sPowerMeterHUD.animation == HudH.POWER_METER_HIDDEN then
		hud.sPowerMeterHUD.animation = HudH.POWER_METER_EMPHASIZED
		hud.sPowerMeterHUD.y = 166
	end

	-- Show power meter if health is full, has 8
	if numHealthWedges == 8 and hud.sPowerMeterStoredHealth == 7 then
		hud.sPowerMeterVisibleTimer = 0
	end

	-- After health is full, hide power meter
	if numHealthWedges == 8 and hud.sPowerMeterVisibleTimer > 45.0 then
		hud.sPowerMeterHUD.animation = HudH.POWER_METER_HIDING
	end

	-- Update to match health value
	hud.sPowerMeterStoredHealth = numHealthWedges

	-- If Mario is swimming, keep power meter visible
	if bit32.btest(Camera.gPlayerCameraState[1].action, IncludeSm64H.ACT_FLAG_SWIMMING) then
		if hud.sPowerMeterHUD.animation == HudH.POWER_METER_HIDDEN or hud.sPowerMeterHUD.animation == HudH.POWER_METER_EMPHASIZED then
			hud.sPowerMeterHUD.animation = HudH.POWER_METER_DEEMPHASIZING
			hud.sPowerMeterHUD.y = 166
		end

		hud.sPowerMeterVisibleTimer = 0
	end
end

-- from src/game/hud.c:render_hud_power_meter L221-249
function hud.render_hud_power_meter()
	const shownHealthWedges = S16(LevelUpdate.gHudDisplay.wedges)

	if hud.sPowerMeterHUD.animation ~= HudH.POWER_METER_HIDING then
		hud.handle_power_meter_actions(shownHealthWedges)
	end

	if hud.sPowerMeterHUD.animation == HudH.POWER_METER_HIDDEN then
		return
	end

	if hud.sPowerMeterHUD.animation == HudH.POWER_METER_EMPHASIZED then
		hud.animate_power_meter_emphasized()
	elseif hud.sPowerMeterHUD.animation == HudH.POWER_METER_DEEMPHASIZING then
		hud.animate_power_meter_deemphasizing()
	elseif hud.sPowerMeterHUD.animation == HudH.POWER_METER_HIDING then
		hud.animate_power_meter_hiding()
	end

	hud.render_dl_power_meter(shownHealthWedges)
	hud.sPowerMeterVisibleTimer = S32(hud.sPowerMeterVisibleTimer + 1)
end

-- from src/game/hud.c:render_hud_mario_lives L260-264
function hud.render_hud_mario_lives()
	Print.print_text(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(22), hud.HUD_TOP_Y, ",") -- 'Mario Head' glyph
	Print.print_text(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(38), hud.HUD_TOP_Y, "*") -- 'X' glyph
	Print.print_text_fmt_int(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(54), hud.HUD_TOP_Y, "%d", LevelUpdate.gHudDisplay.lives)
end

-- from src/game/hud.c:render_hud_coins L269-273
function hud.render_hud_coins()
	Print.print_text(168, hud.HUD_TOP_Y, "+") -- 'Coin' glyph
	Print.print_text(184, hud.HUD_TOP_Y, "*") -- 'X' glyph
	Print.print_text_fmt_int(198, hud.HUD_TOP_Y, "%d", LevelUpdate.gHudDisplay.coins)
end

-- from src/game/hud.c:render_hud_stars L285-302
function hud.render_hud_stars()
	local showX = 0

	if GroupsIngameMenuPlus1.gHudFlash == 1 and bit32.btest(GameInit.gGlobalTimer, 8) then
		return
	end

	if LevelUpdate.gHudDisplay.stars < 100 then
		showX = 1
	end

	Print.print_text(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(hud.HUD_STARS_X), hud.HUD_TOP_Y, "-") -- 'Star' glyph

	if showX == 1 then
		Print.print_text(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(hud.HUD_STARS_X) + 16, hud.HUD_TOP_Y, "*") -- 'X' glyph
	end

	Print.print_text_fmt_int(showX * 14 + IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(hud.HUD_STARS_X - 16), hud.HUD_TOP_Y, "%d", LevelUpdate.gHudDisplay.stars)
end

-- from src/game/hud.c:render_hud_keys L308-314
function hud.render_hud_keys()
	for i = 0, LevelUpdate.gHudDisplay.keys - 1 do
		Print.print_text(i * 16 + 220, 142, "/") -- unused glyph - beta key
	end
end

-- from src/game/hud.c:render_hud_timer L319-357
function hud.render_hud_timer()
	const hudLUT = Memory.segmented_to_virtual(Segment2Symbols.main_hud_lut)
	const timerValFrames = U16(LevelUpdate.gHudDisplay.timer)
	const timerMins = U16(timerValFrames // (30 * 60))
	const timerSecs = U16((timerValFrames - timerMins * 1800) // 30)
	const timerFracSecs = U16(U16(timerValFrames - timerMins * 1800 - timerSecs * 30) // 3)

	Print.print_text(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(150), 185, "TIME")

	Print.print_text_fmt_int(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(91), 185, "%0d", timerMins)
	Print.print_text_fmt_int(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(71), 185, "%02d", timerSecs)
	Print.print_text_fmt_int(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(37), 185, "%d", timerFracSecs)

	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_begin)
	hud.render_hud_tex_lut(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(81), 32, Rom.ReadU32(hudLUT + 4 * PrintH.GLYPH_APOSTROPHE))
	hud.render_hud_tex_lut(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(46), 32, Rom.ReadU32(hudLUT + 4 * PrintH.GLYPH_DOUBLE_QUOTE))
	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_end)
end

-- from src/game/hud.c:set_hud_camera_status L363-365
function hud.set_hud_camera_status(status: number)
	status = S16(TruncS32(status))
	hud.sCameraHUDStatus = S16(status)
end

-- from src/game/hud.c:render_hud_camera_status L371-405
function hud.render_hud_camera_status()
	const cameraLUT = Memory.segmented_to_virtual(Segment2Symbols.main_hud_camera_lut)
	const x = IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(54)
	const y = 205

	if hud.sCameraHUDStatus == GroupsTypesHPlus3.CAM_STATUS_NONE then
		return
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_begin)
	hud.render_hud_tex_lut(x, y, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_CAMERA))

	const mode = bit32.band(hud.sCameraHUDStatus, GroupsTypesHPlus3.CAM_STATUS_MODE_GROUP)

	if mode == GroupsTypesHPlus3.CAM_STATUS_MARIO then
		hud.render_hud_tex_lut(x + 16, y, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_MARIO_HEAD))
	elseif mode == GroupsTypesHPlus3.CAM_STATUS_LAKITU then
		hud.render_hud_tex_lut(x + 16, y, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_LAKITU_HEAD))
	elseif mode == GroupsTypesHPlus3.CAM_STATUS_FIXED then
		hud.render_hud_tex_lut(x + 16, y, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_FIXED))
	end

	const cMode = bit32.band(hud.sCameraHUDStatus, GroupsTypesHPlus3.CAM_STATUS_C_MODE_GROUP)

	if cMode == GroupsTypesHPlus3.CAM_STATUS_C_DOWN then
		hud.render_hud_small_tex_lut(x + 4, y + 16, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_ARROW_DOWN))
	elseif cMode == GroupsTypesHPlus3.CAM_STATUS_C_UP then
		hud.render_hud_small_tex_lut(x + 4, y - 8, Rom.ReadU32(cameraLUT + 4 * HudH.GLYPH_CAM_ARROW_UP))
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_end)
end

-- from src/game/hud.c:render_hud L411-465
function hud.render_hud()
	const hudDisplayFlags = S16(LevelUpdate.gHudDisplay.flags)

	if hudDisplayFlags == LevelUpdateH.HUD_DISPLAY_NONE then
		hud.sPowerMeterHUD.animation = HudH.POWER_METER_HIDDEN
		hud.sPowerMeterStoredHealth = 8
		hud.sPowerMeterVisibleTimer = 0
	else
		GroupsIngameMenuPlus1.create_dl_ortho_matrix()

		if Area.gCurrentArea ~= nil and (Area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON then
			GroupsIngameMenuPlus1.render_hud_cannon_reticle()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_LIVES) then
			hud.render_hud_mario_lives()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_COIN_COUNT) then
			hud.render_hud_coins()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_STAR_COUNT) then
			hud.render_hud_stars()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_KEYS) then
			hud.render_hud_keys()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_CAMERA_AND_POWER) then
			hud.render_hud_power_meter()
			hud.render_hud_camera_status()
		end

		if bit32.btest(hudDisplayFlags, LevelUpdateH.HUD_DISPLAY_FLAG_TIMER) then
			hud.render_hud_timer()
		end
	end
end

return hud
