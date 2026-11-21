--!strict
--!optimize 2

--[[
	Port of src/game/game_init.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludePROsMessageH = require("../../include/PR/os_message_h")

const GameInitH = require("./game_init_h")
const MemoryH = require("./memory_h")
const Memory = require("./memory")
const IncludeMacrosH = require("../../include/macros_h")
const IncludePROsContH = require("../../include/PR/os_cont_h")
const Gbi = require("../rom/gbi")
const IncludeConfigH = require("../../include/config_h")
const IncludeGfxDimensionsH = require("../../include/gfx_dimensions_h")
const Recorder = require("../rom/render_recorder")
const Rom = require("../rom/rom")
const Symbols = require("../rom/symbols")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/game_init.c:data
const game_init = {
	-- from src/game/game_init.c:gControllers L24-24
	gControllers = {
		{
			rawStickX = 0,
			rawStickY = 0,
			stickX = 0,
			stickY = 0,
			stickMag = 0,
			buttonDown = 0,
			buttonPressed = 0,
			statusData = nil,
			controllerData = nil,
		},
		{
			rawStickX = 0,
			rawStickY = 0,
			stickX = 0,
			stickY = 0,
			stickMag = 0,
			buttonDown = 0,
			buttonPressed = 0,
			statusData = nil,
			controllerData = nil,
		},
		{
			rawStickX = 0,
			rawStickY = 0,
			stickX = 0,
			stickY = 0,
			stickMag = 0,
			buttonDown = 0,
			buttonPressed = 0,
			statusData = nil,
			controllerData = nil,
		},
	} :: { GroupsTypesHPlus3.Controller },
	-- from src/game/game_init.c:gGfxSPTask L27-27
	gGfxSPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/game_init.c:gGfxPool L30-30
	gGfxPool = nil :: GameInitH.GfxPool?,
	-- from src/game/game_init.c:gControllerStatuses L33-33
	gControllerStatuses = {
		{ type_ = 0, status = 0, errnum = 0 },
		{ type_ = 0, status = 0, errnum = 0 },
		{ type_ = 0, status = 0, errnum = 0 },
		{ type_ = 0, status = 0, errnum = 0 },
	},
	-- from src/game/game_init.c:gControllerPads L34-34
	gControllerPads = {
		{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
		{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
		{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
		{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
	},
	-- from src/game/game_init.c:gControllerBits L35-35
	gControllerBits = 0,
	-- from src/game/game_init.c:gEepromProbe L36-36
	gEepromProbe = 0,
	-- from src/game/game_init.c:gGameVblankQueue L39-39
	gGameVblankQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/game_init.c:gGfxVblankQueue L40-40
	gGfxVblankQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/game_init.c:gGameMesgBuf L41-41
	gGameMesgBuf = { nil },
	-- from src/game/game_init.c:gGfxMesgBuf L42-42
	gGfxMesgBuf = { nil },
	-- from src/game/game_init.c:gGameVblankHandler L45-45
	gGameVblankHandler = { queue = nil, msg = nil } :: GroupsTypesHPlus3.VblankHandler,
	-- from src/game/game_init.c:gPhysicalFramebuffers L48-48
	gPhysicalFramebuffers = table.create(3, 0),
	-- from src/game/game_init.c:gPhysicalZBuffer L49-49
	gPhysicalZBuffer = 0,
	-- from src/game/game_init.c:gMarioAnimsMemAlloc L52-52
	gMarioAnimsMemAlloc = nil :: number?,
	-- from src/game/game_init.c:gDemoInputsMemAlloc L53-53
	gDemoInputsMemAlloc = nil :: number?,
	-- from src/game/game_init.c:gMarioAnimsBuf L54-54
	gMarioAnimsBuf = { dmaTable = nil, currentAddr = nil, bufTarget = nil } :: MemoryH.DmaHandlerList,
	-- from src/game/game_init.c:gDemoInputsBuf L55-55
	gDemoInputsBuf = { dmaTable = nil, currentAddr = nil, bufTarget = nil } :: MemoryH.DmaHandlerList,
	-- from src/game/game_init.c:sfillerGameInit L58-58
	sfillerGameInit = buffer.create(144),
	-- from src/game/game_init.c:sUnusedGameInitValue L59-59
	sUnusedGameInitValue = 0,
	-- from src/game/game_init.c:gGlobalTimer L62-62
	gGlobalTimer = 0,
	-- from src/game/game_init.c:sRenderedFramebuffer L65-65
	sRenderedFramebuffer = 0,
	-- from src/game/game_init.c:sRenderingFramebuffer L66-66
	sRenderingFramebuffer = 0,
	-- from src/game/game_init.c:gGoddardVblankCallback L69-69
	gGoddardVblankCallback = nil :: (() -> ())?,
	-- from src/game/game_init.c:gCurrDemoInput L77-77
	gCurrDemoInput = nil :: number?,
	-- from src/game/game_init.c:gDemoInputListID L78-78
	gDemoInputListID = 0,
	-- from src/game/game_init.c:gRecordedDemoInput L79-79
	gRecordedDemoInput = { timer = 0, rawStickX = 0, rawStickY = 0, buttonMask = 0 },
}

Registry.Register("src__game__game_init", game_init)

-- from src/game/game_init.c:init_rdp L87-111
function game_init.init_rdp()
	Gbi.gDPPipeSync()
	Gbi.gDPPipelineMode(Gbi.G_PM_1PRIMITIVE)

	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, 0, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT)
	Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)

	Gbi.gDPSetTextureLOD(Gbi.G_TL_TILE)
	Gbi.gDPSetTextureLUT(Gbi.G_TT_NONE)
	Gbi.gDPSetTextureDetail(Gbi.G_TD_CLAMP)
	Gbi.gDPSetTexturePersp(Gbi.G_TP_PERSP)
	Gbi.gDPSetTextureFilter(Gbi.G_TF_BILERP)
	Gbi.gDPSetTextureConvert(Gbi.G_TC_FILT)

	Gbi.gDPSetCombineKey(Gbi.G_CK_NONE)
	Gbi.gDPSetAlphaCompare(Gbi.G_AC_NONE)
	Gbi.gDPSetRenderMode(Gbi.G_RM_OPA_SURF, Gbi.G_RM_OPA_SURF2)
	Gbi.gDPSetColorDither(Gbi.G_CD_MAGICSQ)
	Gbi.gDPSetCycleType(Gbi.G_CYC_FILL)

	Gbi.gDPPipeSync()
end

-- from src/game/game_init.c:init_rsp L116-130
function game_init.init_rsp()
	Gbi.gSPClearGeometryMode(bit32.bor(Gbi.G_SHADE, Gbi.G_SHADING_SMOOTH, Gbi.G_CULL_BOTH, Gbi.G_FOG, Gbi.G_LIGHTING, Gbi.G_TEXTURE_GEN, Gbi.G_TEXTURE_GEN_LINEAR, Gbi.G_LOD))

	Gbi.gSPSetGeometryMode(bit32.bor(Gbi.G_SHADE, Gbi.G_SHADING_SMOOTH, Gbi.G_CULL_BACK, Gbi.G_LIGHTING))

	Gbi.gSPNumLights(Gbi.NUMLIGHTS_1)
	Gbi.gSPTexture(0, 0, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)

	-- gSPClipRatio(FRUSTRATIO_1) is F3DEX_GBI_2 only: the US build runs the F3D microcode
end

-- from src/game/game_init.c:init_z_buffer L135-147
function game_init.init_z_buffer()
	Gbi.gDPPipeSync()

	Gbi.gDPSetDepthSource(Gbi.G_ZS_PIXEL)
	Gbi.gDPSetDepthImage(game_init.gPhysicalZBuffer)

	Gbi.gDPSetColorImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, IncludeConfigH.SCREEN_WIDTH, game_init.gPhysicalZBuffer)
	Gbi.gDPSetFillColor(bit32.bor(bit32.lshift(Gbi.GPACK_ZDZ(Gbi.G_MAXFBZ, 0), 16), Gbi.GPACK_ZDZ(Gbi.G_MAXFBZ, 0)))

	Gbi.gDPFillRectangle(0, IncludeConfigH.BORDER_HEIGHT, IncludeConfigH.SCREEN_WIDTH - 1, IncludeConfigH.SCREEN_HEIGHT - 1 - IncludeConfigH.BORDER_HEIGHT)
end

-- from src/game/game_init.c:select_framebuffer L152-160
function game_init.select_framebuffer()
	Gbi.gDPPipeSync()

	Gbi.gDPSetCycleType(Gbi.G_CYC_1CYCLE)
	Gbi.gDPSetColorImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, IncludeConfigH.SCREEN_WIDTH, game_init.gPhysicalFramebuffers[game_init.sRenderingFramebuffer + 1])
	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, IncludeConfigH.BORDER_HEIGHT, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT)
end

-- from src/game/game_init.c:clear_framebuffer L166-180
function game_init.clear_framebuffer(color: number)
	Gbi.gDPPipeSync()

	Gbi.gDPSetRenderMode(Gbi.G_RM_OPA_SURF, Gbi.G_RM_OPA_SURF2)
	Gbi.gDPSetCycleType(Gbi.G_CYC_FILL)

	Gbi.gDPSetFillColor(color)
	Gbi.gDPFillRectangle(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(0), IncludeConfigH.BORDER_HEIGHT, IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(0) - 1, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT - 1)

	Gbi.gDPPipeSync()

	Gbi.gDPSetCycleType(Gbi.G_CYC_1CYCLE)
end

-- from src/game/game_init.c:clear_viewport L185-207
function game_init.clear_viewport(viewport: { unknown }, color: number)
	-- a Vp is { vscale, vtrans }
	const vscale = viewport[1] :: { number }
	const vtrans = viewport[2] :: { number }
	const vpUlx = S16(TruncS32((vtrans[1] - vscale[1]) / 4) + 1)
	const vpUly = S16(TruncS32((vtrans[2] - vscale[2]) / 4) + 1)
	const vpLrx = S16(TruncS32((vtrans[1] + vscale[1]) / 4) - 2)
	const vpLry = S16(TruncS32((vtrans[2] + vscale[2]) / 4) - 2)

	Gbi.gDPPipeSync()

	Gbi.gDPSetRenderMode(Gbi.G_RM_OPA_SURF, Gbi.G_RM_OPA_SURF2)
	Gbi.gDPSetCycleType(Gbi.G_CYC_FILL)

	Gbi.gDPSetFillColor(color)
	Gbi.gDPFillRectangle(vpUlx, vpUly, vpLrx, vpLry)

	Gbi.gDPPipeSync()

	Gbi.gDPSetCycleType(Gbi.G_CYC_1CYCLE)
end

-- from src/game/game_init.c:draw_screen_borders L212-228
function game_init.draw_screen_borders()
	Gbi.gDPPipeSync()

	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 0, 0, IncludeConfigH.SCREEN_WIDTH, IncludeConfigH.SCREEN_HEIGHT)
	Gbi.gDPSetRenderMode(Gbi.G_RM_OPA_SURF, Gbi.G_RM_OPA_SURF2)
	Gbi.gDPSetCycleType(Gbi.G_CYC_FILL)

	Gbi.gDPSetFillColor(bit32.bor(bit32.lshift(Gbi.GPACK_RGBA5551(0, 0, 0, 0), 16), Gbi.GPACK_RGBA5551(0, 0, 0, 0)))

	-- BORDER_HEIGHT is 8
	Gbi.gDPFillRectangle(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(0), 0, IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(0) - 1, IncludeConfigH.BORDER_HEIGHT - 1)
	Gbi.gDPFillRectangle(IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(0), IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT, IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(0) - 1, IncludeConfigH.SCREEN_HEIGHT - 1)
end

-- from src/game/game_init.c:make_viewport_clip_rect L234-241
function game_init.make_viewport_clip_rect(viewport: { unknown })
	-- a Vp is { vscale, vtrans }
	const vscale = viewport[1] :: { number }
	const vtrans = viewport[2] :: { number }
	const vpUlx = S16(TruncS32((vtrans[1] - vscale[1]) / 4) + 1)
	const vpPly = S16(TruncS32((vtrans[2] - vscale[2]) / 4) + 1)
	const vpLrx = S16(TruncS32((vtrans[1] + vscale[1]) / 4) - 1)
	const vpLry = S16(TruncS32((vtrans[2] + vscale[2]) / 4) - 1)

	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, vpUlx, vpPly, vpLrx, vpLry)
end

-- from src/game/game_init.c:create_gfx_task_structure L247-269
function game_init.create_gfx_task_structure()
	-- The OSTask fields (microcode and DRAM stack pointers, the data size) are the RSP's input: SPTask has none of them and nothing reads
	-- them. The commands of the frame are the range of the Gfx pool from its start to Gbi.Head, which display_and_vsync hands to the recorder
	-- (gfx-display-list-pool).
end

-- from src/game/game_init.c:init_rcp L274-280
function game_init.init_rcp()
	Memory.move_segment_table_to_dmem()
	game_init.init_rdp()
	game_init.init_rsp()
	game_init.init_z_buffer()
	game_init.select_framebuffer()
end

-- from src/game/game_init.c:end_master_display_list L285-295
function game_init.end_master_display_list()
	game_init.draw_screen_borders()
	-- draw_profiler (gShowProfiler is FALSE): no call

	Gbi.gDPFullSync()
	Gbi.gSPEndDisplayList()

	game_init.create_gfx_task_structure()
end

-- from src/game/game_init.c:draw_reset_bars L300-325
function game_init.draw_reset_bars()
	if Registry.Members.src__game__main.gResetTimer ~= 0 and Registry.Members.src__game__main.gNmiResetBarsTimer < 15 then
		-- framebuffer row writes: display output, dropped (framebuffer-pixel-writes-dropped)
		Registry.Members.src__game__main.gNmiResetBarsTimer = S8(Registry.Members.src__game__main.gNmiResetBarsTimer + 1)
	end

	-- osWritebackDCacheAll(), osRecvMesg(&gGameVblankQueue, ...) twice: replaced by no-op
end

-- from src/game/game_init.c:render_init L330-343
function game_init.render_init()
	-- gGfxPool and gGfxSPTask name the pool buffers of src/buffers/buffers.c; the Gfx pool is Gbi's (gfx-display-list-pool), whose
	-- cursor is gDisplayListHead and its end gGfxPoolEnd
	Gbi.Reset()
	game_init.init_rcp()
	game_init.clear_framebuffer(0)
	game_init.end_master_display_list()
	-- exec_display_list(&gGfxPool->spTask): display list output, dropped (gfx-display-lists)

	game_init.sRenderingFramebuffer = U16(game_init.sRenderingFramebuffer + 1)
	game_init.gGlobalTimer = U32(game_init.gGlobalTimer + 1)
end

-- from src/game/game_init.c:select_gfx_pool L348-354
function game_init.select_gfx_pool()
	-- gGfxPool and gGfxSPTask name the pool buffers of src/buffers/buffers.c; the Gfx pool is Gbi's (gfx-display-list-pool), whose
	-- cursor is gDisplayListHead and its end gGfxPoolEnd
	Gbi.Reset()
end

-- from src/game/game_init.c:display_and_vsync L363-383
function game_init.display_and_vsync()
	-- profiler_log_thread5_time(BEFORE_DISPLAY_LISTS), osRecvMesg(&gGfxVblankQueue, ...): replaced by no-op

	if game_init.gGoddardVblankCallback ~= nil then
		game_init.gGoddardVblankCallback()
		game_init.gGoddardVblankCallback = nil
	end

	if Recorder.Enabled then
		Recorder.Overlay(Symbols.GfxPool, Gbi.Head)
	end

	-- exec_display_list(&gGfxPool->spTask): display list output, dropped (gfx-display-lists)
	-- profiler_log_thread5_time(AFTER_DISPLAY_LISTS), osRecvMesg(&gGameVblankQueue, ...), osViSwapBuffer(...), profiler_log_thread5_time(THREAD5_END), osRecvMesg(&gGameVblankQueue, ...): replaced by no-op

	game_init.sRenderedFramebuffer = U16(game_init.sRenderedFramebuffer + 1)

	if game_init.sRenderedFramebuffer == 3 then
		game_init.sRenderedFramebuffer = U16(0)
	end

	game_init.sRenderingFramebuffer = U16(game_init.sRenderingFramebuffer + 1)

	if game_init.sRenderingFramebuffer == 3 then
		game_init.sRenderingFramebuffer = U16(0)
	end

	game_init.gGlobalTimer = U32(game_init.gGlobalTimer + 1)
end

-- from src/game/game_init.c:record_demo L392-420
function game_init.record_demo()
	const buttonDown = game_init.gPlayer1Controller.buttonDown
	const buttonMask = U8(bit32.bor(bit32.rshift(bit32.band(buttonDown, bit32.bor(Registry.Members.include__PR__os_h.A_BUTTON, Registry.Members.include__PR__os_h.B_BUTTON, Registry.Members.include__PR__os_h.Z_TRIG, Registry.Members.include__PR__os_h.START_BUTTON)), 8), bit32.band(buttonDown, bit32.bor(Registry.Members.include__PR__os_h.U_CBUTTONS, Registry.Members.include__PR__os_h.D_CBUTTONS, Registry.Members.include__PR__os_h.L_CBUTTONS, Registry.Members.include__PR__os_h.R_CBUTTONS))))
	local rawStickX = S8(game_init.gPlayer1Controller.rawStickX)
	local rawStickY = S8(game_init.gPlayer1Controller.rawStickY)

	if rawStickX > -8 and rawStickX < 8 then
		rawStickX = S8(0)
	end

	if rawStickY > -8 and rawStickY < 8 then
		rawStickY = S8(0)
	end

	if game_init.gRecordedDemoInput.timer == 0xFF or buttonMask ~= game_init.gRecordedDemoInput.buttonMask or rawStickX ~= game_init.gRecordedDemoInput.rawStickX or rawStickY ~= game_init.gRecordedDemoInput.rawStickY then
		game_init.gRecordedDemoInput.timer = U8(0)
		game_init.gRecordedDemoInput.buttonMask = buttonMask
		game_init.gRecordedDemoInput.rawStickX = rawStickX
		game_init.gRecordedDemoInput.rawStickY = rawStickY
	end

	game_init.gRecordedDemoInput.timer = U8(game_init.gRecordedDemoInput.timer + 1)
end

-- from src/game/game_init.c:adjust_analog_stick L425-460
function game_init.adjust_analog_stick(controller: GroupsTypesHPlus3.Controller)
	controller.stickX = 0
	controller.stickY = 0

	if controller.rawStickX <= -8 then
		controller.stickX = controller.rawStickX + 6
	end

	if controller.rawStickX >= 8 then
		controller.stickX = controller.rawStickX - 6
	end

	if controller.rawStickY <= -8 then
		controller.stickY = controller.rawStickY + 6
	end

	if controller.rawStickY >= 8 then
		controller.stickY = controller.rawStickY - 6
	end

	controller.stickMag = F32(math.sqrt(F32(F32(controller.stickX * controller.stickX) + F32(controller.stickY * controller.stickY))))

	if controller.stickMag > 64 then
		controller.stickX = F32(controller.stickX * F32(64 / controller.stickMag))
		controller.stickY = F32(controller.stickY * F32(64 / controller.stickMag))
		controller.stickMag = 64
	end
end

-- from src/game/game_init.c:run_demo_inputs L465-517
function game_init.run_demo_inputs()
	const ValidButtons: number = Registry.Members.include__sm64_h.VALID_BUTTONS
	const EndDemo: number = Registry.Members.include__sm64_h.END_DEMO
	const StartButton: number = Registry.Members.include__PR__os_h.START_BUTTON
	const pad1 = game_init.gControllers[1].controllerData :: IncludePROsContH.OSContPad
	const pad2 = game_init.gControllers[2].controllerData

	-- Eliminate the unused bits.
	pad1.button = U16(bit32.band(pad1.button, ValidButtons))

	-- Check if a demo inputs list exists and if so,
	-- run the active demo input list.
	if game_init.gCurrDemoInput ~= nil then
		const demoInput = game_init.gCurrDemoInput

		-- Clear player 2's inputs if they exist. Player 2's controller
		-- cannot be used to influence a demo. At some point, Nintendo
		-- may have planned for there to be a demo where 2 players moved
		-- around instead of just one, so clearing player 2's influence from
		-- the demo had to have been necessary to perform this. Co-op mode, perhaps?
		if pad2 ~= nil then
			pad2.stick_x = 0
			pad2.stick_y = 0
			pad2.button = 0
		end

		-- The timer variable being 0 at the current input means the demo is over.
		-- Set the button to the END_DEMO mask to end the demo.
		if Rom.ReadU8(demoInput) == 0 then
			pad1.stick_x = 0
			pad1.stick_y = 0
			pad1.button = EndDemo
		else
			-- Backup the start button if it is pressed, since we don't want the
			-- demo input to override the mask where start may have been pressed.
			const startPushed = U16(bit32.band(pad1.button, StartButton))

			-- Perform the demo inputs by assigning the current button mask and the stick inputs.
			pad1.stick_x = Rom.ReadS8(demoInput + 1)
			pad1.stick_y = Rom.ReadS8(demoInput + 2)

			-- To assign the demo input, the button information is stored in
			-- an 8-bit mask rather than a 16-bit mask. this is because only
			-- A, B, Z, Start, and the C-Buttons are used in a demo, as bits
			-- in that order. In order to assign the mask, we need to take the
			-- upper 4 bits (A, B, Z, and Start) and shift then left by 8 to
			-- match the correct input mask. We then add this to the masked
			-- lower 4 bits to get the correct button mask.
			pad1.button = U16(bit32.lshift(bit32.band(Rom.ReadU8(demoInput + 3), 0xF0), 8) + bit32.band(Rom.ReadU8(demoInput + 3), 0xF))

			-- If start was pushed, put it into the demo sequence being input to end the demo.
			pad1.button = U16(bit32.bor(pad1.button, startPushed))

			-- Run the current demo input's timer down. if it hits 0, advance the demo input list.
			Rom.WriteU8(demoInput, Rom.ReadU8(demoInput) - 1)
			if Rom.ReadU8(demoInput) == 0 then
				game_init.gCurrDemoInput = demoInput + 4
			end
		end
	end
end

-- from src/game/game_init.c:read_controller_inputs L522-568
function game_init.read_controller_inputs()
	error("stale")
end

-- from src/game/game_init.c:init_controllers L573-605
function game_init.init_controllers()
	error("stale")
end

-- from src/game/game_init.c:setup_game_memory L613-638
function game_init.setup_game_memory()
	-- Setup general Segment 0
	Memory.set_segment_base_addr(0, 0x80000000)
	-- Create Mesg Queues: osCreateMesgQueue is dropped (replaced.txt)
	-- Setup z buffer and framebuffer
	game_init.gPhysicalZBuffer = IncludeMacrosH.VIRTUAL_TO_PHYSICAL(Symbols.ZBuffer)
	game_init.gPhysicalFramebuffers[1] = IncludeMacrosH.VIRTUAL_TO_PHYSICAL(Symbols.Framebuffer0)
	game_init.gPhysicalFramebuffers[2] = IncludeMacrosH.VIRTUAL_TO_PHYSICAL(Symbols.Framebuffer1)
	game_init.gPhysicalFramebuffers[3] = IncludeMacrosH.VIRTUAL_TO_PHYSICAL(Symbols.Framebuffer2)
	-- Setup Mario Animations
	game_init.gMarioAnimsMemAlloc = Memory.main_pool_alloc(0x4000, MemoryH.MEMORY_POOL_LEFT)
	Memory.set_segment_base_addr(17, game_init.gMarioAnimsMemAlloc :: number)
	Memory.setup_dma_table_list(game_init.gMarioAnimsBuf, Symbols.MarioAnims, game_init.gMarioAnimsMemAlloc :: number)
	-- Setup Demo Inputs List
	game_init.gDemoInputsMemAlloc = Memory.main_pool_alloc(0x800, MemoryH.MEMORY_POOL_LEFT)
	Memory.set_segment_base_addr(24, game_init.gDemoInputsMemAlloc :: number)
	Memory.setup_dma_table_list(game_init.gDemoInputsBuf, Symbols.DemoInputs, game_init.gDemoInputsMemAlloc :: number)
	-- Setup Level Script Entry
	Memory.load_segment(0x10, Symbols.EntrySegmentRomStart, Symbols.EntrySegmentRomEnd, MemoryH.MEMORY_POOL_LEFT)
	-- Setup Segment 2 (Fonts, Text, etc)
	Memory.load_segment_decompress(2, Symbols.Segment2Mio0SegmentRomStart, Symbols.Segment2Mio0SegmentRomEnd)
end

-- from src/game/game_init.c:thread5_game_loop L643-703
function game_init.thread5_game_loop(arg: unknown)
	error("stale")
end

-- from src/game/game_init.c:gPlayer1Controller L72-72
game_init.gPlayer1Controller = game_init.gControllers[1]

-- from src/game/game_init.c:gPlayer2Controller L73-73
game_init.gPlayer2Controller = game_init.gControllers[2]

-- from src/game/game_init.c:gPlayer3Controller L74-74
game_init.gPlayer3Controller = game_init.gControllers[3]

return game_init
