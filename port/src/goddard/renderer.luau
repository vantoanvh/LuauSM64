--!strict
--!optimize 2

--[[
	Port of src/goddard/renderer.c.
]]

const Registry = require("../../groups/registry")

const IncludePROsContH = require("../../include/PR/os_cont_h")
const IncludePROsMessageH = require("../../include/PR/os_message_h")
const IncludePROsPiH = require("../../include/PR/os_pi_h")

const DebugUtilsH = require("./debug_utils_h")
const DynlistsDynlistMarioMaster = require("./dynlists/dynlist_mario_master")
const DynlistsDynlistTestCube = require("./dynlists/dynlist_test_cube")
const DynlistsDynlistUnused = require("./dynlists/dynlist_unused")
const GdTypesH = require("./gd_types_h")
const RendererStatic = require("./renderer_static")
const RendererTypes = require("./renderer_types")
const DebugUtils = require("./debug_utils")
const Gbi = require("../rom/gbi")
const Rom = require("../rom/rom")
const GdMacrosH = require("./gd_macros_h")
const GdMemory = require("./gd_memory")
const GdMemoryH = require("./gd_memory_h")
const GdMath = require("./gd_math")
const RendererH = require("./renderer_h")
const DrawObjects = require("./draw_objects")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const GdMain = require("./gd_main")
const GdMainH = require("./gd_main_h")
const IncludePROsH = require("../../include/PR/os_h")
const Objects = require("./objects")
const Sfx = require("./sfx")
const DynlistProc = require("./dynlist_proc")
const DynlistProcH = require("./dynlist_proc_h")
const IncludeMacrosH = require("../../include/macros_h")
const IncludePlatformInfoH = require("../../include/platform_info_h")
const SfxH = require("./sfx_h")
const ShapeHelper = require("./shape_helper")
const Skin = require("./skin")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/goddard/renderer.luau:scratch
const PerspectiveNormalization = { 0 }

-- from src/goddard/renderer.c:data
const renderer = {
	MAX_GD_DLS = 1000,
	OS_MESG_SI_COMPLETE = 0x33333333,
	TABLE_END = -1,
	STD_LIST_BANK = 3,
	-- from src/goddard/renderer.c:D_801BAE60 L105-105
	D_801BAE60 = {
			{ type_ = 0, status = 0, errnum = 0 },
			{ type_ = 0, status = 0, errnum = 0 },
			{ type_ = 0, status = 0, errnum = 0 },
			{ type_ = 0, status = 0, errnum = 0 },
		},
	-- from src/goddard/renderer.c:sGdContPads L106-106
	sGdContPads = {
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
		},
	-- from src/goddard/renderer.c:sPrevFrameCont L107-107
	sPrevFrameCont = {
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
			{ button = 0, stick_x = 0, stick_y = 0, errnum = 0 },
		},
	-- from src/goddard/renderer.c:D_801BAEA0 L108-108
	D_801BAEA0 = 0,
	-- from src/goddard/renderer.c:sTimerGadgets L109-109
	sTimerGadgets = {
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
		} :: { GdTypesH.ObjGadget? },
	-- from src/goddard/renderer.c:D_801BAF28 L110-110
	D_801BAF28 = 0,
	-- from src/goddard/renderer.c:sTriangleBuf L111-111
	sTriangleBuf = {
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
	-- from src/goddard/renderer.c:unref_801bb000 L112-112
	unref_801bb000 = table.create(3, 0),
	-- from src/goddard/renderer.c:sMemBlockPoolBase L113-113
	sMemBlockPoolBase = nil :: number?,
	-- from src/goddard/renderer.c:sAllocMemory L114-114
	sAllocMemory = 0,
	-- from src/goddard/renderer.c:unref_801bb014 L115-115
	unref_801bb014 = 0,
	-- from src/goddard/renderer.c:D_801BB018 L116-116
	D_801BB018 = 0,
	-- from src/goddard/renderer.c:D_801BB01C L117-117
	D_801BB01C = 0,
	-- from src/goddard/renderer.c:sLoadedTextures L118-118
	sLoadedTextures = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil },
	-- from src/goddard/renderer.c:sTextureDisplayLists L119-119
	sTextureDisplayLists = table.create(16, 0),
	-- from src/goddard/renderer.c:sVtxCvrtTCBuf L120-120
	sVtxCvrtTCBuf = table.create(2, 0),
	-- from src/goddard/renderer.c:sCarGdDlNum L121-121
	sCarGdDlNum = 0,
	-- from src/goddard/renderer.c:sYoshiSceneGrp L122-122
	sYoshiSceneGrp = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/renderer.c:unusedDl801BB0AC L123-123
	unusedDl801BB0AC = 0,
	-- from src/goddard/renderer.c:sMarioSceneGrp L124-124
	sMarioSceneGrp = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/renderer.c:D_801BB0B4 L125-125
	D_801BB0B4 = 0,
	-- from src/goddard/renderer.c:sCarSceneGrp L126-126
	sCarSceneGrp = nil :: GdTypesH.ObjGroup?,
	-- from src/goddard/renderer.c:sVertexBufCount L127-127
	sVertexBufCount = 0,
	-- from src/goddard/renderer.c:sYoshiSceneView L128-128
	sYoshiSceneView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sTriangleBufCount L129-129
	sTriangleBufCount = 0,
	-- from src/goddard/renderer.c:sMSceneView L130-130
	sMSceneView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sVertexBufStartIndex L131-131
	sVertexBufStartIndex = 0,
	-- from src/goddard/renderer.c:sCarSceneView L132-132
	sCarSceneView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sUpdateYoshiScene L133-133
	sUpdateYoshiScene = 0,
	-- from src/goddard/renderer.c:sUpdateMarioScene L134-134
	sUpdateMarioScene = 0,
	-- from src/goddard/renderer.c:unref_801bb0dc L135-135
	unref_801bb0dc = 0,
	-- from src/goddard/renderer.c:sUpdateCarScene L136-136
	sUpdateCarScene = 0,
	-- from src/goddard/renderer.c:unref_801bb0e4 L137-137
	unref_801bb0e4 = 0,
	-- from src/goddard/renderer.c:sTextDrawPos L138-138
	sTextDrawPos = { x = 0, y = 0, z = 0 },
	-- from src/goddard/renderer.c:unref_801bb0f8 L139-139
	unref_801bb0f8 = table.create(2, 0),
	-- from src/goddard/renderer.c:sIdnMtx L140-140
	sIdnMtx = RendererStatic.sIdnMtx,
	-- from src/goddard/renderer.c:sInitIdnMat4 L141-141
	sInitIdnMat4 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
	-- from src/goddard/renderer.c:sVtxCvrtNormBuf L142-142
	sVtxCvrtNormBuf = buffer.create(3),
	-- from src/goddard/renderer.c:sAlpha L143-143
	sAlpha = 0,
	-- from src/goddard/renderer.c:sNumLights L144-144
	sNumLights = 0,
	-- from src/goddard/renderer.c:sAmbScaleColour L145-145
	sAmbScaleColour = { r = 0, g = 0, b = 0 },
	-- from src/goddard/renderer.c:sLightScaleColours L146-146
	sLightScaleColours = { { r = 0, g = 0, b = 0 }, { r = 0, g = 0, b = 0 } },
	-- from src/goddard/renderer.c:sLightDirections L147-147
	sLightDirections = { { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 } },
	-- from src/goddard/renderer.c:sLightId L148-148
	sLightId = 0,
	-- from src/goddard/renderer.c:sHilites L149-149
	sHilites = RendererStatic.sHilites,
	-- from src/goddard/renderer.c:D_801BD758 L150-150
	D_801BD758 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/renderer.c:D_801BD768 L151-151
	D_801BD768 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/renderer.c:D_801BD774 L152-152
	D_801BD774 = 0,
	-- from src/goddard/renderer.c:sMenuGadgets L153-153
	sMenuGadgets = { nil, nil, nil, nil, nil, nil, nil, nil, nil } :: { GdTypesH.GdObj? },
	-- from src/goddard/renderer.c:sDebugViews L154-154
	sDebugViews = { nil, nil } :: { GdTypesH.ObjView? },
	-- from src/goddard/renderer.c:sStaticDl L155-155
	sStaticDl = nil :: RendererTypes.GdDisplayList?,
	-- from src/goddard/renderer.c:sDynamicMainDls L156-156
	sDynamicMainDls = { nil, nil } :: { RendererTypes.GdDisplayList? },
	-- from src/goddard/renderer.c:sGdDlStash L157-157
	sGdDlStash = nil :: RendererTypes.GdDisplayList?,
	-- from src/goddard/renderer.c:sMHeadMainDls L158-158
	sMHeadMainDls = { nil, nil } :: { RendererTypes.GdDisplayList? },
	-- from src/goddard/renderer.c:sViewDls L159-159
	sViewDls = { { nil, nil }, { nil, nil }, { nil, nil } } :: { { RendererTypes.GdDisplayList? } },
	-- from src/goddard/renderer.c:sGdDLArray L160-160
	sGdDLArray = table.create(1000) :: { RendererTypes.GdDisplayList? },
	-- from src/goddard/renderer.c:sPickBufLen L161-161
	sPickBufLen = 0,
	-- from src/goddard/renderer.c:sPickBufPosition L162-162
	sPickBufPosition = 0,
	-- from src/goddard/renderer.c:sPickBuf L163-163
	sPickBuf = nil :: { number }?,
	-- from src/goddard/renderer.c:D_801BE790 L164-164
	D_801BE790 = RendererStatic.D_801BE790,
	-- from src/goddard/renderer.c:D_801BE7D0 L165-165
	D_801BE7D0 = RendererStatic.D_801BE7D0,
	-- from src/goddard/renderer.c:D_801BE830 L167-167
	D_801BE830 = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/goddard/renderer.c:D_801BE848 L168-168
	D_801BE848 = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil },
	-- from src/goddard/renderer.c:unref_801be870 L169-169
	unref_801be870 = table.create(16, 0),
	-- from src/goddard/renderer.c:D_801BE8B0 L170-170
	D_801BE8B0 = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/goddard/renderer.c:sGdDMAQueue L171-171
	sGdDMAQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/goddard/renderer.c:unref_801be8e0 L172-172
	unref_801be8e0 = table.create(25, 0),
	-- from src/goddard/renderer.c:sGdMesgBuf L173-173
	sGdMesgBuf = { nil },
	-- from src/goddard/renderer.c:unref_801be948 L174-174
	unref_801be948 = table.create(13, 0),
	-- from src/goddard/renderer.c:sGdDMACompleteMsg L175-175
	sGdDMACompleteMsg = nil,
	-- from src/goddard/renderer.c:sGdDMAReqMesg L176-176
	sGdDMAReqMesg = IncludePROsPiH.new_OSIoMesg(),
	-- from src/goddard/renderer.c:D_801BE994 L177-177
	D_801BE994 = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:unref_801a8670 L181-181
	unref_801a8670 = 0,
	-- from src/goddard/renderer.c:D_801A8674 L182-182
	D_801A8674 = 0,
	-- from src/goddard/renderer.c:unref_801a8678 L183-183
	unref_801a8678 = 0,
	-- from src/goddard/renderer.c:D_801A867C L184-184
	D_801A867C = 0,
	-- from src/goddard/renderer.c:D_801A8680 L185-185
	D_801A8680 = 0,
	-- from src/goddard/renderer.c:sTracked1FrameTime L186-186
	sTracked1FrameTime = 0.0,
	-- from src/goddard/renderer.c:sDynamicsTime L187-187
	sDynamicsTime = 0.0,
	-- from src/goddard/renderer.c:sDLGenTime L188-188
	sDLGenTime = 0.0,
	-- from src/goddard/renderer.c:sRCPTime L189-189
	sRCPTime = 0.0,
	-- from src/goddard/renderer.c:sTimeScaleFactor L190-190
	sTimeScaleFactor = 1.0,
	-- from src/goddard/renderer.c:sMemBlockPoolSize L191-191
	sMemBlockPoolSize = 1,
	-- from src/goddard/renderer.c:sMemBlockPoolUsed L192-192
	sMemBlockPoolUsed = 0,
	-- from src/goddard/renderer.c:sTextureCount L193-193
	sTextureCount = 0,
	-- from src/goddard/renderer.c:D_801A86A4 L194-194
	D_801A86A4 = nil :: DebugUtilsH.GdTimer?,
	-- from src/goddard/renderer.c:D_801A86A8 L195-195
	D_801A86A8 = nil :: DebugUtilsH.GdTimer?,
	-- from src/goddard/renderer.c:D_801A86AC L196-196
	D_801A86AC = nil :: DebugUtilsH.GdTimer?,
	-- from src/goddard/renderer.c:gGdFrameBufNum L197-197
	gGdFrameBufNum = 0,
	-- from src/goddard/renderer.c:unref_801a86B4 L198-198
	unref_801a86B4 = 0,
	-- from src/goddard/renderer.c:sHandShape L199-199
	sHandShape = nil :: GdTypesH.ObjShape?,
	-- from src/goddard/renderer.c:D_801A86BC L200-200
	D_801A86BC = 1,
	-- from src/goddard/renderer.c:D_801A86C0 L201-201
	D_801A86C0 = 0,
	-- from src/goddard/renderer.c:unref_801a86C4 L202-202
	unref_801a86C4 = 10,
	-- from src/goddard/renderer.c:sMtxParamType L203-203
	sMtxParamType = 0x01,
	-- from src/goddard/renderer.c:D_801A86CC L204-204
	D_801A86CC = { x = 1.0, y = 1.0, z = 1.0 },
	-- from src/goddard/renderer.c:sActiveView L205-205
	sActiveView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sScreenView L206-206
	sScreenView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:D_801A86E0 L207-207
	D_801A86E0 = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sHandView L208-208
	sHandView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sMenuView L209-209
	sMenuView = nil :: GdTypesH.ObjView?,
	-- from src/goddard/renderer.c:sItemsInMenu L210-210
	sItemsInMenu = 0,
	-- from src/goddard/renderer.c:sDebugViewsCount L211-211
	sDebugViewsCount = 0,
	-- from src/goddard/renderer.c:sCurrDebugViewIndex L212-212
	sCurrDebugViewIndex = 0,
	-- from src/goddard/renderer.c:unref_801a86F8 L213-213
	unref_801a86F8 = 0,
	-- from src/goddard/renderer.c:sCurrentGdDl L214-214
	sCurrentGdDl = nil :: RendererTypes.GdDisplayList?,
	-- from src/goddard/renderer.c:sGdDlCount L215-215
	sGdDlCount = 0,
	-- from src/goddard/renderer.c:gd_texture_hand_open L228-230
	gd_texture_hand_open = RendererStatic.gd_texture_hand_open,
	-- from src/goddard/renderer.c:gd_texture_hand_closed L236-238
	gd_texture_hand_closed = RendererStatic.gd_texture_hand_closed,
	-- from src/goddard/renderer.c:gd_texture_red_star_0 L240-242
	gd_texture_red_star_0 = RendererStatic.gd_texture_red_star_0,
	-- from src/goddard/renderer.c:gd_texture_red_star_1 L244-246
	gd_texture_red_star_1 = RendererStatic.gd_texture_red_star_1,
	-- from src/goddard/renderer.c:gd_texture_red_star_2 L248-250
	gd_texture_red_star_2 = RendererStatic.gd_texture_red_star_2,
	-- from src/goddard/renderer.c:gd_texture_red_star_3 L252-254
	gd_texture_red_star_3 = RendererStatic.gd_texture_red_star_3,
	-- from src/goddard/renderer.c:gd_texture_red_star_4 L256-258
	gd_texture_red_star_4 = RendererStatic.gd_texture_red_star_4,
	-- from src/goddard/renderer.c:gd_texture_red_star_5 L260-262
	gd_texture_red_star_5 = RendererStatic.gd_texture_red_star_5,
	-- from src/goddard/renderer.c:gd_texture_red_star_6 L264-266
	gd_texture_red_star_6 = RendererStatic.gd_texture_red_star_6,
	-- from src/goddard/renderer.c:gd_texture_red_star_7 L268-270
	gd_texture_red_star_7 = RendererStatic.gd_texture_red_star_7,
	-- from src/goddard/renderer.c:gd_texture_white_star_0 L272-274
	gd_texture_white_star_0 = RendererStatic.gd_texture_white_star_0,
	-- from src/goddard/renderer.c:gd_texture_white_star_1 L276-278
	gd_texture_white_star_1 = RendererStatic.gd_texture_white_star_1,
	-- from src/goddard/renderer.c:gd_texture_white_star_2 L280-282
	gd_texture_white_star_2 = RendererStatic.gd_texture_white_star_2,
	-- from src/goddard/renderer.c:gd_texture_white_star_3 L284-286
	gd_texture_white_star_3 = RendererStatic.gd_texture_white_star_3,
	-- from src/goddard/renderer.c:gd_texture_white_star_4 L288-290
	gd_texture_white_star_4 = RendererStatic.gd_texture_white_star_4,
	-- from src/goddard/renderer.c:gd_texture_white_star_5 L292-294
	gd_texture_white_star_5 = RendererStatic.gd_texture_white_star_5,
	-- from src/goddard/renderer.c:gd_texture_white_star_6 L296-298
	gd_texture_white_star_6 = RendererStatic.gd_texture_white_star_6,
	-- from src/goddard/renderer.c:gd_texture_white_star_7 L300-302
	gd_texture_white_star_7 = RendererStatic.gd_texture_white_star_7,
	-- from src/goddard/renderer.c:gd_vertex_star L304-309
	gd_vertex_star = RendererStatic.gd_vertex_star,
	-- from src/goddard/renderer.c:gd_dl_star_common L319-335
	gd_dl_star_common = RendererStatic.gd_dl_star_common,
	-- from src/goddard/renderer.c:gd_dl_red_star_0 L337-341
	gd_dl_red_star_0 = RendererStatic.gd_dl_red_star_0,
	-- from src/goddard/renderer.c:gd_dl_red_star_1 L343-347
	gd_dl_red_star_1 = RendererStatic.gd_dl_red_star_1,
	-- from src/goddard/renderer.c:gd_dl_red_star_2 L349-353
	gd_dl_red_star_2 = RendererStatic.gd_dl_red_star_2,
	-- from src/goddard/renderer.c:gd_dl_red_star_3 L355-359
	gd_dl_red_star_3 = RendererStatic.gd_dl_red_star_3,
	-- from src/goddard/renderer.c:gd_dl_red_star_4 L361-365
	gd_dl_red_star_4 = RendererStatic.gd_dl_red_star_4,
	-- from src/goddard/renderer.c:gd_dl_red_star_5 L367-371
	gd_dl_red_star_5 = RendererStatic.gd_dl_red_star_5,
	-- from src/goddard/renderer.c:gd_dl_red_star_6 L373-377
	gd_dl_red_star_6 = RendererStatic.gd_dl_red_star_6,
	-- from src/goddard/renderer.c:gd_dl_red_star_7 L379-383
	gd_dl_red_star_7 = RendererStatic.gd_dl_red_star_7,
	-- from src/goddard/renderer.c:gd_dl_silver_star_0 L385-389
	gd_dl_silver_star_0 = RendererStatic.gd_dl_silver_star_0,
	-- from src/goddard/renderer.c:gd_dl_silver_star_1 L391-395
	gd_dl_silver_star_1 = RendererStatic.gd_dl_silver_star_1,
	-- from src/goddard/renderer.c:gd_dl_silver_star_2 L397-401
	gd_dl_silver_star_2 = RendererStatic.gd_dl_silver_star_2,
	-- from src/goddard/renderer.c:gd_dl_silver_star_3 L403-407
	gd_dl_silver_star_3 = RendererStatic.gd_dl_silver_star_3,
	-- from src/goddard/renderer.c:gd_dl_silver_star_4 L409-413
	gd_dl_silver_star_4 = RendererStatic.gd_dl_silver_star_4,
	-- from src/goddard/renderer.c:gd_dl_silver_star_5 L415-419
	gd_dl_silver_star_5 = RendererStatic.gd_dl_silver_star_5,
	-- from src/goddard/renderer.c:gd_dl_silver_star_6 L421-425
	gd_dl_silver_star_6 = RendererStatic.gd_dl_silver_star_6,
	-- from src/goddard/renderer.c:gd_dl_silver_star_7 L427-431
	gd_dl_silver_star_7 = RendererStatic.gd_dl_silver_star_7,
	-- from src/goddard/renderer.c:gd_texture_sparkle_0 L471-473
	gd_texture_sparkle_0 = RendererStatic.gd_texture_sparkle_0,
	-- from src/goddard/renderer.c:gd_texture_sparkle_1 L475-477
	gd_texture_sparkle_1 = RendererStatic.gd_texture_sparkle_1,
	-- from src/goddard/renderer.c:gd_texture_sparkle_2 L479-481
	gd_texture_sparkle_2 = RendererStatic.gd_texture_sparkle_2,
	-- from src/goddard/renderer.c:gd_texture_sparkle_3 L483-485
	gd_texture_sparkle_3 = RendererStatic.gd_texture_sparkle_3,
	-- from src/goddard/renderer.c:gd_texture_sparkle_4 L487-489
	gd_texture_sparkle_4 = RendererStatic.gd_texture_sparkle_4,
	-- from src/goddard/renderer.c:gd_texture_sparkle_5 L493-495
	gd_texture_sparkle_5 = RendererStatic.gd_texture_sparkle_5,
	-- from src/goddard/renderer.c:gd_vertex_sparkle L497-502
	gd_vertex_sparkle = RendererStatic.gd_vertex_sparkle,
	-- from src/goddard/renderer.c:gd_dl_sparkle L504-522
	gd_dl_sparkle = RendererStatic.gd_dl_sparkle,
	-- from src/goddard/renderer.c:gd_dl_sparkle_red_color L524-527
	gd_dl_sparkle_red_color = RendererStatic.gd_dl_sparkle_red_color,
	-- from src/goddard/renderer.c:gd_dl_sparkle_white_color L529-532
	gd_dl_sparkle_white_color = RendererStatic.gd_dl_sparkle_white_color,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_0 L534-539
	gd_dl_red_sparkle_0 = RendererStatic.gd_dl_red_sparkle_0,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_1 L541-546
	gd_dl_red_sparkle_1 = RendererStatic.gd_dl_red_sparkle_1,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_2 L548-553
	gd_dl_red_sparkle_2 = RendererStatic.gd_dl_red_sparkle_2,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_3 L555-560
	gd_dl_red_sparkle_3 = RendererStatic.gd_dl_red_sparkle_3,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_4 L562-567
	gd_dl_red_sparkle_4 = RendererStatic.gd_dl_red_sparkle_4,
	-- from src/goddard/renderer.c:gd_dl_red_sparkle_4_dup L569-574
	gd_dl_red_sparkle_4_dup = RendererStatic.gd_dl_red_sparkle_4_dup,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_0 L576-581
	gd_dl_silver_sparkle_0 = RendererStatic.gd_dl_silver_sparkle_0,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_1 L583-588
	gd_dl_silver_sparkle_1 = RendererStatic.gd_dl_silver_sparkle_1,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_2 L590-595
	gd_dl_silver_sparkle_2 = RendererStatic.gd_dl_silver_sparkle_2,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_3 L597-602
	gd_dl_silver_sparkle_3 = RendererStatic.gd_dl_silver_sparkle_3,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_4 L604-609
	gd_dl_silver_sparkle_4 = RendererStatic.gd_dl_silver_sparkle_4,
	-- from src/goddard/renderer.c:gd_dl_silver_sparkle_4_dup L611-616
	gd_dl_silver_sparkle_4_dup = RendererStatic.gd_dl_silver_sparkle_4_dup,
	-- from src/goddard/renderer.c:gd_texture_mario_face_shine L652-654
	gd_texture_mario_face_shine = RendererStatic.gd_texture_mario_face_shine,
	-- from src/goddard/renderer.c:gd_dl_mario_face_shine L656-666
	gd_dl_mario_face_shine = RendererStatic.gd_dl_mario_face_shine,
	-- from src/goddard/renderer.c:sGdPerspTimer L695-695
	sGdPerspTimer = 1.0,
	-- from src/goddard/renderer.c:gd_dl_sprite_start_tex_block L729-740
	gd_dl_sprite_start_tex_block = RendererStatic.gd_dl_sprite_start_tex_block,
}

Registry.Register("src__goddard__renderer", renderer)

-- from src/goddard/renderer.c:GD_VIRTUAL_TO_PHYSICAL L26-26
function renderer.GD_VIRTUAL_TO_PHYSICAL(addr: number): number
	return bit32.band(addr, 0x0FFFFFFF)
end

-- from src/goddard/renderer.c:GD_LOWER_24 L27-27
function renderer.GD_LOWER_24(addr: number): number
	return bit32.band(addr, 0x00FFFFFF)
end

-- from src/goddard/renderer.c:GD_LOWER_29 L28-28
function renderer.GD_LOWER_29(addr: number): number
	return bit32.band(addr, 0x1FFFFFFF)
end

-- from src/goddard/renderer.c:MTX_INTPART_PACK L35-35
function renderer.MTX_INTPART_PACK(w1: number, w2: number): number
	return bit32.bor(bit32.band(w1, 0xFFFF0000), bit32.band(bit32.arshift(w2, 16), 0xFFFF))
end

-- from src/goddard/renderer.c:MTX_FRACPART_PACK L36-36
function renderer.MTX_FRACPART_PACK(w1: number, w2: number): number
	return bit32.bor(bit32.band(bit32.lshift(w1, 16), 0xFFFF0000), bit32.band(w2, 0xFFFF))
end

-- from src/goddard/renderer.c:LOOKAT_PACK L37-37
function renderer.LOOKAT_PACK(c: number): number
	return bit32.band(TruncS32(math.min(c * 128.0, 127.0)), 0xFF)
end

-- from src/goddard/renderer.c:DL_CURRENT_VTX L69-69
function renderer.DL_CURRENT_VTX(dl: unknown): number
	const List = dl :: RendererTypes.GdDisplayList

	return (List.vtx :: number) + List.curVtxIdx * Gbi.SIZEOF_VTX
end

-- from src/goddard/renderer.c:DL_CURRENT_MTX L70-70
function renderer.DL_CURRENT_MTX(dl: unknown): number
	const List = dl :: RendererTypes.GdDisplayList

	return (List.mtx :: number) + List.curMtxIdx * Gbi.SIZEOF_MTX
end

-- from src/goddard/renderer.c:DL_CURRENT_LIGHT L71-71
function renderer.DL_CURRENT_LIGHT(dl: unknown): number
	const List = dl :: RendererTypes.GdDisplayList

	return (List.light :: number) + List.curLightIdx * Gbi.SIZEOF_LIGHTS4
end

-- from src/goddard/renderer.c:DL_CURRENT_GFX L72-72
function renderer.DL_CURRENT_GFX(dl: unknown): number
	const List = dl :: RendererTypes.GdDisplayList

	return (List.gfx :: number) + List.curGfxIdx * Gbi.SIZEOF_GFX
end

-- from src/goddard/renderer.c:DL_CURRENT_VP L73-73
function renderer.DL_CURRENT_VP(dl: unknown): number
	const List = dl :: RendererTypes.GdDisplayList

	return (List.vp :: number) + List.curVpIdx * Gbi.SIZEOF_VP
end

-- from src/goddard/renderer.c:get_alloc_mem_amt L760-762
function renderer.get_alloc_mem_amt(): number
	return renderer.sAllocMemory
end

-- from src/goddard/renderer.c:gd_get_ostime L767-769
function renderer.gd_get_ostime(): number
	return 0
end

-- from src/goddard/renderer.c:get_time_scale L771-773
function renderer.get_time_scale(): number
	return renderer.sTimeScaleFactor
end

-- from src/goddard/renderer.c:dump_disp_list L775-781
function renderer.dump_disp_list()
	error("stale")

	return
end

-- from src/goddard/renderer.c:next_gfx L786-793
function renderer.next_gfx(): number
	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	if List.curGfxIdx >= List.totalGfx then
		renderer.dump_disp_list()
		DebugUtils.fatal_printf("Gfx list overflow")
	end

	const Address = (List.gfx :: number) + List.curGfxIdx * Gbi.SIZEOF_GFX

	List.curGfxIdx += 1

	return Address
end

-- from src/goddard/renderer.c:next_light L798-805
function renderer.next_light(): number
	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	if List.curLightIdx >= List.totalLights then
		renderer.dump_disp_list()
		DebugUtils.fatal_printf("Light list overflow")
	end

	const Address = (List.light :: number) + List.curLightIdx * Gbi.SIZEOF_LIGHTS4

	List.curLightIdx += 1

	return Address
end

-- from src/goddard/renderer.c:next_mtx L810-817
function renderer.next_mtx(): number
	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	if List.curMtxIdx >= List.totalMtx then
		renderer.dump_disp_list()
		DebugUtils.fatal_printf("Mtx list overflow")
	end

	const Address = (List.mtx :: number) + List.curMtxIdx * Gbi.SIZEOF_MTX

	List.curMtxIdx += 1

	return Address
end

-- from src/goddard/renderer.c:next_vtx L822-829
function renderer.next_vtx(): number
	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	if List.curVtxIdx >= List.totalVtx then
		renderer.dump_disp_list()
		DebugUtils.fatal_printf("Vtx list overflow")
	end

	const Address = (List.vtx :: number) + List.curVtxIdx * Gbi.SIZEOF_VTX

	List.curVtxIdx += 1

	return Address
end

-- from src/goddard/renderer.c:next_vp L834-841
function renderer.next_vp(): number
	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	if List.curVpIdx >= List.totalVp then
		renderer.dump_disp_list()
		DebugUtils.fatal_printf("Vp list overflow")
	end

	const Address = (List.vp :: number) + List.curVpIdx * Gbi.SIZEOF_VP

	List.curVpIdx += 1

	return Address
end

-- from src/goddard/renderer.c:gd_sin_d L844-846
function renderer.gd_sin_d(x: number): number
	return F32(math.sin(F32(x)))
end

-- from src/goddard/renderer.c:gd_cos_d L849-851
function renderer.gd_cos_d(x: number): number
	return F32(math.cos(F32(x)))
end

-- from src/goddard/renderer.c:gd_sqrt_d L854-859
function renderer.gd_sqrt_d(x: number): number
	if x < 1.0e-7 then
		return 0.0
	end

	return F32(math.sqrt(F32(x)))
end

-- from src/goddard/renderer.c:stub_renderer_1 L864-866
function renderer.stub_renderer_1(x: number): number
	error("stale")
end

-- from src/goddard/renderer.c:gd_printf L869-965
function renderer.gd_printf(format: string, ...: unknown)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_exit L968-972
function renderer.gd_exit(code: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_free L975-977
function renderer.gd_free(ptr: unknown)
	renderer.sAllocMemory = bit32.band(renderer.sAllocMemory - GdMemory.gd_free_mem(ptr), 0xFFFFFFFF)
end

-- from src/goddard/renderer.c:gd_allocblock L980-996
function renderer.gd_allocblock(size: number): number
	size = GdMacrosH.ALIGN(size, 8)

	if renderer.sMemBlockPoolUsed + size > renderer.sMemBlockPoolSize then
		DebugUtils.print_all_memtrackers()
		GdMemory.mem_stats()
		DebugUtils.fatal_printf("exit")
	end

	const Block = (renderer.sMemBlockPoolBase :: number) + renderer.sMemBlockPoolUsed

	renderer.sMemBlockPoolUsed = S32(renderer.sMemBlockPoolUsed + size)

	return Block
end

-- from src/goddard/renderer.c:gd_malloc L999-1015
function renderer.gd_malloc(size: number, perm: number): unknown
	perm = U8(TruncS32(perm))
	size = GdMacrosH.ALIGN(size, 8)

	const ptr = GdMemory.gd_request_mem(size, perm)

	if ptr == nil then
		return nil
	end

	renderer.sAllocMemory = bit32.band(renderer.sAllocMemory + size, 0xFFFFFFFF)

	return ptr
end

-- from src/goddard/renderer.c:gd_malloc_perm L1018-1020
function renderer.gd_malloc_perm(size: number): unknown
	return renderer.gd_malloc(size, GdMemoryH.PERM_G_MEM_BLOCK)
end

-- from src/goddard/renderer.c:gd_malloc_temp L1023-1025
function renderer.gd_malloc_temp(size: number): unknown
	return renderer.gd_malloc(size, GdMemoryH.TEMP_G_MEM_BLOCK)
end

-- from src/goddard/renderer.c:Unknown8019BC88 L1028-1030
function renderer.Unknown8019BC88(size: number, count: number): unknown
	error("stale")
end

-- from src/goddard/renderer.c:Unknown8019BCD4 L1033-1035
function renderer.Unknown8019BCD4(size: number): unknown
	error("stale")
end

-- from src/goddard/renderer.c:draw_indexed_dl L1038-1047
function renderer.draw_indexed_dl(dlNum: number, gfxIdx: number)
	const List = renderer.sGdDLArray[dlNum + 1] :: RendererTypes.GdDisplayList
	local Dl = 0

	if gfxIdx ~= 0 then
		Dl = (List.dlptr :: { number })[gfxIdx]
	else
		Dl = List.gfx :: number
	end

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPDisplayList(renderer.GD_VIRTUAL_TO_PHYSICAL(Dl))
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:branch_cur_dl_to_num L1050-1056
function renderer.branch_cur_dl_to_num(dlNum: number)
	const Dl = (renderer.sGdDLArray[dlNum + 1] :: RendererTypes.GdDisplayList).gfx :: number
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPDisplayList(renderer.GD_VIRTUAL_TO_PHYSICAL(Dl))
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:get_dl_gfx L1061-1063
function renderer.get_dl_gfx(num: number): number
	error("stale")
end

-- from src/goddard/renderer.c:setup_stars L1068-1094
function renderer.setup_stars()
	const RedStar = ShapeHelper.make_shape(0, "redstar")

	ShapeHelper.gShapeRedStar = RedStar
	RedStar.dlNums[1] = renderer.new_gddl_from(nil, 0)
	RedStar.dlNums[2] = RedStar.dlNums[1]

	const RedStarFirst = renderer.sGdDLArray[RedStar.dlNums[1] + 1] :: RendererTypes.GdDisplayList
	const RedStarSecond = renderer.sGdDLArray[RedStar.dlNums[2] + 1] :: RendererTypes.GdDisplayList

	RedStarFirst.dlptr = renderer.gd_red_star_dl_array
	RedStarSecond.dlptr = renderer.gd_red_star_dl_array

	const SilverStar = ShapeHelper.make_shape(0, "silverstar")

	ShapeHelper.gShapeSilverStar = SilverStar
	SilverStar.dlNums[1] = renderer.new_gddl_from(nil, 0)
	SilverStar.dlNums[2] = SilverStar.dlNums[1]

	const SilverStarFirst = renderer.sGdDLArray[SilverStar.dlNums[1] + 1] :: RendererTypes.GdDisplayList
	const SilverStarSecond = renderer.sGdDLArray[SilverStar.dlNums[2] + 1] :: RendererTypes.GdDisplayList

	SilverStarFirst.dlptr = renderer.gd_silver_star_dl_array
	SilverStarSecond.dlptr = renderer.gd_silver_star_dl_array

	-- make_shape names of the dl array they call are misnamed (swapped)
	-- "sspark" calls red sparkles and "rspark" calls silver sparkles
	const RedSpark = ShapeHelper.make_shape(0, "sspark")

	ShapeHelper.gShapeRedSpark = RedSpark
	RedSpark.dlNums[1] = renderer.new_gddl_from(nil, 0)
	RedSpark.dlNums[2] = RedSpark.dlNums[1]

	const RedSparkFirst = renderer.sGdDLArray[RedSpark.dlNums[1] + 1] :: RendererTypes.GdDisplayList
	const RedSparkSecond = renderer.sGdDLArray[RedSpark.dlNums[2] + 1] :: RendererTypes.GdDisplayList

	RedSparkFirst.dlptr = renderer.gd_red_sparkle_dl_array
	RedSparkSecond.dlptr = renderer.gd_red_sparkle_dl_array

	const SilverSpark = ShapeHelper.make_shape(0, "rspark")

	ShapeHelper.gShapeSilverSpark = SilverSpark
	SilverSpark.dlNums[1] = renderer.new_gddl_from(nil, 0)
	SilverSpark.dlNums[2] = SilverSpark.dlNums[1]

	const SilverSparkFirst = renderer.sGdDLArray[SilverSpark.dlNums[1] + 1] :: RendererTypes.GdDisplayList
	const SilverSparkSecond = renderer.sGdDLArray[SilverSpark.dlNums[2] + 1] :: RendererTypes.GdDisplayList

	SilverSparkFirst.dlptr = renderer.gd_silver_sparkle_dl_array
	SilverSparkSecond.dlptr = renderer.gd_silver_sparkle_dl_array
end

-- from src/goddard/renderer.c:setup_timers L1097-1128
function renderer.setup_timers()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown8019C270 L1131-1133
function renderer.Unknown8019C270(buf: buffer)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown8019C288 L1136-1141
function renderer.Unknown8019C288(stickX: number, stickY: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_add_to_heap L1144-1147
function renderer.gd_add_to_heap(addr: number, size: number)
	GdMemory.gd_add_mem_to_heap(size, addr, 1)
end

-- from src/goddard/renderer.c:gdm_init L1150-1165
function renderer.gdm_init(blockpool: number, size: number)
	-- Align downwards?
	size = bit32.band(size - 8, bit32.bnot(7))
	-- Align to next double word boundry?
	blockpool = bit32.band(blockpool + 8, bit32.bnot(7))
	renderer.sMemBlockPoolBase = blockpool
	renderer.sMemBlockPoolSize = size
	renderer.sMemBlockPoolUsed = 0
	renderer.sAllocMemory = 0
	GdMemory.init_mem_block_lists()
	Sfx.gd_reset_sfx()
end

-- from src/goddard/renderer.c:gdm_setup L1170-1186
function renderer.gdm_setup()
	renderer.sYoshiSceneGrp = nil
	renderer.sMarioSceneGrp = nil
	renderer.sUpdateYoshiScene = IncludePRUltratypesH.FALSE
	renderer.sUpdateMarioScene = IncludePRUltratypesH.FALSE
	renderer.sCarGdDlNum = 0
	renderer.gd_init()
	ShapeHelper.load_shapes2()
	renderer.reset_cur_dl_indices()
	renderer.setup_stars()
	Gbi.Redirect(nil)
end

-- from src/goddard/renderer.c:stub_renderer_2 L1189-1190
function renderer.stub_renderer_2(a0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:print_gdm_stats L1193-1199
function renderer.print_gdm_stats()
	error("stale")

	return
end

-- from src/goddard/renderer.c:make_view_withgrp L1202-1208
function renderer.make_view_withgrp(name: string, grp: GdTypesH.ObjGroup): GdTypesH.ObjView
	const View = Objects.make_view(name, bit32.bor(GdTypesH.VIEW_DRAW, GdTypesH.VIEW_ALLOC_ZBUF, GdTypesH.VIEW_MOVEMENT), 1, 0, 0, 320, 240, grp)

	Objects.make_group(2, grp.header, View.header)

	View.lights = DrawObjects.gGdLightGroup

	return View
end

-- from src/goddard/renderer.c:gdm_maketestdl L1211-1248
function renderer.gdm_maketestdl(id: number)
	if id == 0 then
		renderer.sYoshiSceneView = renderer.make_view_withgrp("yoshi_scene", renderer.sYoshiSceneGrp :: GdTypesH.ObjGroup)
	elseif id == 1 then
		Objects.reset_nets_and_gadgets(renderer.sYoshiSceneGrp :: GdTypesH.ObjGroup)
	elseif id == 2 then
		-- normal Mario head
		if renderer.sMarioSceneGrp == nil then
			ShapeHelper.load_mario_head(ShapeHelper.animate_mario_head_normal)
			-- gMarioFaceGrp set by load_mario_head
			renderer.sMarioSceneGrp = ShapeHelper.gMarioFaceGrp
			renderer.gd_setup_cursor(nil)
		end

		renderer.sMSceneView = renderer.make_view_withgrp("mscene", renderer.sMarioSceneGrp :: GdTypesH.ObjGroup)
	elseif id == 3 then
		-- game over Mario head
		if renderer.sMarioSceneGrp == nil then
			ShapeHelper.load_mario_head(ShapeHelper.animate_mario_head_gameover)
			renderer.sMarioSceneGrp = ShapeHelper.gMarioFaceGrp
			renderer.gd_setup_cursor(nil)
		end

		renderer.sMSceneView = renderer.make_view_withgrp("mscene", renderer.sMarioSceneGrp :: GdTypesH.ObjGroup)
	elseif id == 4 then
		renderer.sCarSceneView = renderer.make_view_withgrp("car_scene", renderer.sCarSceneGrp :: GdTypesH.ObjGroup)
	elseif id == 5 then
		Objects.reset_nets_and_gadgets(renderer.sCarSceneGrp :: GdTypesH.ObjGroup)
	else
		DebugUtils.fatal_printf("gdm_maketestdl(): unknown dl")
	end

	Gbi.Redirect(nil)
end

-- from src/goddard/renderer.c:set_time_scale L1251-1253
function renderer.set_time_scale(factor: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown8019C840 L1256-1259
function renderer.Unknown8019C840()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_vblank L1264-1278
function renderer.gd_vblank()
	Sfx.gd_sfx_update()

	if renderer.sUpdateYoshiScene ~= 0 then
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, Skin.convert_net_verts, renderer.sYoshiSceneGrp)
	end

	if renderer.sUpdateMarioScene ~= 0 then
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, Skin.convert_net_verts, renderer.sMarioSceneGrp)
	end

	renderer.sUpdateYoshiScene = IncludePRUltratypesH.FALSE
	renderer.sUpdateMarioScene = IncludePRUltratypesH.FALSE
	renderer.gGdFrameBufNum = S32(bit32.bxor(renderer.gGdFrameBufNum, 1))
	renderer.reset_cur_dl_indices()
	renderer.parse_p1_controller()
	renderer.update_cursor()
	Gbi.Redirect(nil)
end

-- from src/goddard/renderer.c:gd_copy_p1_contpad L1283-1295
function renderer.gd_copy_p1_contpad(p1cont: IncludePROsContH.OSContPad)
	const Dest = renderer.sGdContPads[1]

	Dest.button = p1cont.button
	Dest.stick_x = p1cont.stick_x
	Dest.stick_y = p1cont.stick_y
	Dest.errnum = p1cont.errnum

	if bit32.btest(p1cont.button, IncludePROsH.Z_TRIG) then
		-- print_all_timers is replaced: no call
	end
end

-- from src/goddard/renderer.c:gd_sfx_to_play L1298-1300
function renderer.gd_sfx_to_play(): number
	return Sfx.gd_new_sfx_to_play()
end

-- from src/goddard/renderer.c:gdm_gettestdl L1303-1379
function renderer.gdm_gettestdl(id: number): number
	local DisplayList: RendererTypes.GdDisplayList? = nil

	if id == 0 then
		if renderer.sYoshiSceneView == nil then
			DebugUtils.fatal_printf("gdm_gettestdl(): DL number %d undefined", id)
		end

		--! @bug Code treats `sYoshiSceneView` as group; not called in game though
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_VIEWS, DrawObjects.update_view, (renderer.sYoshiSceneView :: unknown) :: GdTypesH.ObjGroup)

		const SceneView = DynlistProc.d_use_obj("yoshi_scene") :: GdTypesH.ObjView

		DisplayList = renderer.sGdDLArray[SceneView.gdDlNum + 1]
		renderer.sUpdateYoshiScene = IncludePRUltratypesH.TRUE
	elseif id == 1 then
		if renderer.sYoshiSceneGrp == nil then
			DebugUtils.fatal_printf("gdm_gettestdl(): DL number %d undefined", id)
		end

		const SceneShape = DynlistProc.d_use_obj("yoshi_sh_l1") :: GdTypesH.ObjShape

		DisplayList = renderer.sGdDLArray[SceneShape.dlNums[renderer.gGdFrameBufNum + 1] + 1]
		renderer.sUpdateYoshiScene = IncludePRUltratypesH.TRUE
	elseif id == RendererH.GD_SCENE_REGULAR_MARIO or id == RendererH.GD_SCENE_DIZZY_MARIO then
		-- setup_timers is replaced: no call
		renderer.update_view_and_dl(renderer.sMSceneView :: GdTypesH.ObjView)

		if renderer.sHandView ~= nil then
			renderer.update_view_and_dl(renderer.sHandView)
		end

		renderer.sCurrentGdDl = renderer.sMHeadMainDls[renderer.gGdFrameBufNum + 1]

		const Previous = Gbi.Redirect(renderer.next_gfx())

		Gbi.gSPEndDisplayList()
		Gbi.Redirect(Previous)
		DisplayList = renderer.sCurrentGdDl
		renderer.sUpdateMarioScene = IncludePRUltratypesH.TRUE
	elseif id == 4 then
		if renderer.sCarSceneView == nil then
			DebugUtils.fatal_printf("gdm_gettestdl(): DL number %d undefined", id)
		end

		--! @bug Code treats `sCarSceneView` as group; not called in game though
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_VIEWS, DrawObjects.update_view, (renderer.sCarSceneView :: unknown) :: GdTypesH.ObjGroup)

		const SceneView = DynlistProc.d_use_obj("car_scene") :: GdTypesH.ObjView

		DisplayList = renderer.sGdDLArray[SceneView.gdDlNum + 1]
		renderer.sUpdateCarScene = IncludePRUltratypesH.TRUE
	elseif id == 5 then
		renderer.sActiveView = renderer.sScreenView
		renderer.set_gd_mtx_parameters(bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_PUSH))

		const CarNet = DynlistProc.d_use_obj("testnet2")

		renderer.sCarGdDlNum = renderer.gd_startdisplist(8)

		if renderer.sCarGdDlNum == 0 then
			DebugUtils.fatal_printf("no memory for car DL\n")
		end

		DrawObjects.apply_obj_draw_fn(CarNet)
		renderer.gd_enddlsplist_parent()
		DisplayList = renderer.sGdDLArray[renderer.sCarGdDlNum + 1]
		renderer.sUpdateCarScene = IncludePRUltratypesH.TRUE
	else
		DebugUtils.fatal_printf("gdm_gettestdl(): %d out of range", id)
	end

	if DisplayList == nil then
		DebugUtils.fatal_printf("no display list")
	end

	Gbi.Redirect(nil)

	return (DisplayList :: RendererTypes.GdDisplayList).gfx :: number
end

-- from src/goddard/renderer.c:gdm_getpos L1382-1396
function renderer.gdm_getpos(id: number, dst: GdTypesH.GdVec3f)
	error("stale")

	return
end

-- from src/goddard/renderer.c:clamp_coords_to_active_view L1401-1415
function renderer.clamp_coords_to_active_view(x: { number }, y: { number })
	error("stale")

	return
end

-- from src/goddard/renderer.c:fatal_no_dl_mem L1418-1420
function renderer.fatal_no_dl_mem()
	error("stale")

	return
end

-- from src/goddard/renderer.c:alloc_displaylist L1423-1439
function renderer.alloc_displaylist(id: number): RendererTypes.GdDisplayList?
	const List = RendererTypes.new_GdDisplayList()

	List.number = renderer.sGdDlCount
	renderer.sGdDlCount += 1

	if renderer.sGdDlCount >= renderer.MAX_GD_DLS then
		error(string.format("alloc_displaylist() too many display lists %d (MAX %d)", renderer.sGdDlCount + 1, renderer.MAX_GD_DLS))
	end

	renderer.sGdDLArray[List.number + 1] = List
	List.id = id

	return List
end

-- from src/goddard/renderer.c:cpy_remaining_gddl L1442-1458
function renderer.cpy_remaining_gddl(dst: RendererTypes.GdDisplayList, src: RendererTypes.GdDisplayList)
	dst.vtx = renderer.DL_CURRENT_VTX(src)
	dst.mtx = renderer.DL_CURRENT_MTX(src)
	dst.light = renderer.DL_CURRENT_LIGHT(src)
	dst.gfx = renderer.DL_CURRENT_GFX(src)
	dst.vp = renderer.DL_CURRENT_VP(src)
	dst.totalVtx = src.totalVtx - src.curVtxIdx
	dst.totalMtx = src.totalMtx - src.curMtxIdx
	dst.totalLights = src.totalLights - src.curLightIdx
	dst.totalGfx = src.totalGfx - src.curGfxIdx
	dst.totalVp = src.totalVp - src.curVpIdx
	dst.curVtxIdx = 0
	dst.curMtxIdx = 0
	dst.curLightIdx = 0
	dst.curGfxIdx = 0
	dst.curVpIdx = 0
end

-- from src/goddard/renderer.c:create_child_gdl L1461-1473
function renderer.create_child_gdl(id: number, srcDl: RendererTypes.GdDisplayList): RendererTypes.GdDisplayList
	const List = renderer.alloc_displaylist(id) :: RendererTypes.GdDisplayList

	List.parent = srcDl
	renderer.cpy_remaining_gddl(List, srcDl)

	return List
end

-- from src/goddard/renderer.c:new_gd_dl L1476-1528
function renderer.new_gd_dl(id: number, gfxs: number, verts: number, mtxs: number, lights: number, vps: number): RendererTypes.GdDisplayList
	const List = renderer.alloc_displaylist(id) :: RendererTypes.GdDisplayList

	List.parent = nil

	if verts == 0 then
		verts = 1
	end

	List.curVtxIdx = 0
	List.totalVtx = verts
	List.vtx = renderer.gd_malloc_perm(verts * Gbi.SIZEOF_VTX) :: number?

	if List.vtx == nil then
		error("Out of DL mem\n")
	end

	if mtxs == 0 then
		mtxs = 1
	end

	List.curMtxIdx = 0
	List.totalMtx = mtxs
	List.mtx = renderer.gd_malloc_perm(mtxs * Gbi.SIZEOF_MTX) :: number?

	if List.mtx == nil then
		error("Out of DL mem\n")
	end

	if lights == 0 then
		lights = 1
	end

	List.curLightIdx = 0
	List.totalLights = lights
	List.light = renderer.gd_malloc_perm(lights * Gbi.SIZEOF_LIGHTS4) :: number?

	if List.light == nil then
		error("Out of DL mem\n")
	end

	if gfxs == 0 then
		gfxs = 1
	end

	List.curGfxIdx = 0
	List.totalGfx = gfxs
	List.gfx = renderer.gd_malloc_perm(gfxs * Gbi.SIZEOF_GFX) :: number?

	if List.gfx == nil then
		error("Out of DL mem\n")
	end

	if vps == 0 then
		vps = 1
	end

	List.curVpIdx = 0
	List.totalVp = vps
	List.vp = renderer.gd_malloc_perm(vps * Gbi.SIZEOF_VP) :: number?

	if List.vp == nil then
		error("Out of DL mem\n")
	end

	List.dlptr = nil

	return List
end

-- from src/goddard/renderer.c:gd_rsp_init L1531-1534
function renderer.gd_rsp_init()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_rdp_init L1537-1540
function renderer.gd_rdp_init()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_draw_rect L1543-1556
function renderer.gd_draw_rect(ulx: number, uly: number, lrx: number, lry: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_draw_border_rect L1559-1581
function renderer.gd_draw_border_rect(ulx: number, uly: number, lrx: number, lry: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_dl_set_fill L1584-1595
function renderer.gd_dl_set_fill(colour: GdTypesH.GdColour)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_dl_set_z_buffer_area L1598-1600
function renderer.gd_dl_set_z_buffer_area()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_set_color_fb L1603-1606
function renderer.gd_set_color_fb()
	error("stale")

	return
end

-- from src/goddard/renderer.c:reset_cur_dl_indices L1609-1617
function renderer.reset_cur_dl_indices()
	const Head = renderer.sMHeadMainDls[renderer.gGdFrameBufNum + 1] :: RendererTypes.GdDisplayList

	Head.curGfxIdx = 0
	renderer.sCurrentGdDl = renderer.sDynamicMainDls[renderer.gGdFrameBufNum + 1]

	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	List.curVtxIdx = 0
	List.curMtxIdx = 0
	List.curLightIdx = 0
	List.curGfxIdx = 0
	List.curVpIdx = 0
end

-- from src/goddard/renderer.c:begin_gddl L1620-1627
function renderer.begin_gddl(num: number)
	const List = renderer.sGdDLArray[num + 1] :: RendererTypes.GdDisplayList

	renderer.sCurrentGdDl = List
	List.curVtxIdx = 0
	List.curMtxIdx = 0
	List.curLightIdx = 0
	List.curGfxIdx = 0
	List.curVpIdx = 0
end

-- from src/goddard/renderer.c:stash_current_gddl L1630-1632
function renderer.stash_current_gddl()
	renderer.sGdDlStash = renderer.sCurrentGdDl
end

-- from src/goddard/renderer.c:pop_gddl_stash L1635-1637
function renderer.pop_gddl_stash()
	renderer.sCurrentGdDl = renderer.sGdDlStash
end

-- from src/goddard/renderer.c:gd_startdisplist L1640-1663
function renderer.gd_startdisplist(memarea: number): number
	renderer.D_801BB018 = 0
	renderer.D_801BB01C = 1

	if memarea == 7 then
		renderer.sCurrentGdDl = renderer.create_child_gdl(0, renderer.sStaticDl :: RendererTypes.GdDisplayList)
	elseif memarea == 8 then
		const View = renderer.sActiveView :: GdTypesH.ObjView

		if View.id > 2 then
			DebugUtils.fatal_printf("gd_startdisplist(): Too many views to display")
		end

		renderer.sCurrentGdDl = renderer.sViewDls[View.id + 1][renderer.gGdFrameBufNum + 1]

		const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

		renderer.cpy_remaining_gddl(List, List.parent :: RendererTypes.GdDisplayList)
	else
		DebugUtils.fatal_printf("gd_startdisplist(): Unknown memory area")
	end

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gDPPipeSync()
	Gbi.Redirect(Previous)

	return (renderer.sCurrentGdDl :: RendererTypes.GdDisplayList).number
end

-- from src/goddard/renderer.c:gd_enddlsplist L1666-1669
function renderer.gd_enddlsplist()
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gDPPipeSync()
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:gd_enddlsplist_parent L1672-1687
function renderer.gd_enddlsplist_parent(): number
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gDPPipeSync()
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Previous)

	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList
	const Parent = List.parent

	if Parent ~= nil then
		Parent.curVtxIdx += List.curVtxIdx
		Parent.curMtxIdx += List.curMtxIdx
		Parent.curLightIdx += List.curLightIdx
		Parent.curGfxIdx += List.curGfxIdx
		Parent.curVpIdx += List.curVpIdx
	end

	return List.curGfxIdx
end

-- from src/goddard/renderer.c:Unknown8019EBCC L1690-1692
function renderer.Unknown8019EBCC(num: number, gfxptr: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:new_gddl_from L1695-1701
function renderer.new_gddl_from(dl: number?, arg1: number): number
	const List = renderer.new_gd_dl(0, 0, 0, 0, 0, 0)

	List.gfx = renderer.GD_LOWER_24(dl or 0) + renderer.D_801BAF28

	return List.number
end

-- from src/goddard/renderer.c:Unknown8019EC88 L1704-1710
function renderer.Unknown8019EC88(dl: number, arg1: number): number
	error("stale")
end

-- from src/goddard/renderer.c:mat4_to_mtx L1713-1735
function renderer.mat4_to_mtx(src: { { number } }, dst: number)
	for Row = 0, 3 do
		for Pair = 0, 1 do
			const First = TruncS32(F32(src[Row + 1][Pair * 2 + 1] * 65536.0))
			const Second = TruncS32(F32(src[Row + 1][Pair * 2 + 2] * 65536.0))
			const Offset = (Row * 2 + Pair) * 4

			Rom.WriteU32(dst + Offset, renderer.MTX_INTPART_PACK(First, Second))
			Rom.WriteU32(dst + 32 + Offset, renderer.MTX_FRACPART_PACK(First, Second))
		end
	end
end

-- from src/goddard/renderer.c:gd_dl_mul_matrix L1740-1744
function renderer.gd_dl_mul_matrix(mtx: { { number } })
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_dl_load_matrix L1749-1754
function renderer.gd_dl_load_matrix(mtx: { { number } })
	const Address = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	renderer.mat4_to_mtx(mtx, Address)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPMatrix(Address, bit32.bor(renderer.sMtxParamType, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	Gbi.Redirect(Previous)
	renderer.next_mtx()
end

-- from src/goddard/renderer.c:gd_dl_load_identity_matrix L1760-1762
function renderer.gd_dl_load_identity_matrix()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_dl_push_matrix L1768-1770
function renderer.gd_dl_push_matrix()
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPMatrix(renderer.sIdnMtx, bit32.bor(renderer.sMtxParamType, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:gd_dl_pop_matrix L1775-1777
function renderer.gd_dl_pop_matrix()
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPPopMatrix(renderer.sMtxParamType)
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:gd_dl_mul_trans_matrix L1782-1786
function renderer.gd_dl_mul_trans_matrix(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)

	const Address = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guTranslate(Address, x, y, z)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPMatrix(Address, bit32.bor(renderer.sMtxParamType, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	Gbi.Redirect(Previous)
	renderer.next_mtx()
end

-- from src/goddard/renderer.c:gd_dl_load_trans_matrix L1791-1796
function renderer.gd_dl_load_trans_matrix(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)

	const Address = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guTranslate(Address, x, y, z)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPMatrix(Address, bit32.bor(renderer.sMtxParamType, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	Gbi.Redirect(Previous)
	renderer.next_mtx()
end

-- from src/goddard/renderer.c:gd_dl_scale L1801-1811
function renderer.gd_dl_scale(x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_8019F2C4 L1814-1820
function renderer.func_8019F2C4(arg0: number, arg1: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_dl_lookat L1823-1896
function renderer.gd_dl_lookat(cam: GdTypesH.ObjCamera, arg1: number, arg2: number, arg3: number, arg4: number, arg5: number, arg6: number, arg7: number)
	arg1 = F32(arg1)
	arg2 = F32(arg2)
	arg3 = F32(arg3)
	arg4 = F32(arg4)
	arg5 = F32(arg5)
	arg6 = F32(arg6)
	arg7 = F32(arg7 * GdMacrosH.RAD_PER_DEG)

	GdMath.gd_mat4f_lookat(cam.unkE8, arg1, arg2, arg3, arg4, arg5, arg6, renderer.gd_sin_d(arg7), renderer.gd_cos_d(arg7), 0.0)
	renderer.mat4_to_mtx(cam.unkE8, renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl))

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPMatrix(renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl), bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))

	const Matrix = cam.unkE8
	const LookAtRotated = renderer.D_801BE7D0 + renderer.gGdFrameBufNum * Gbi.SIZEOF_LOOKAT

	Rom.WriteU8(LookAtRotated + 8, renderer.LOOKAT_PACK(Matrix[1][1]))
	Rom.WriteU8(LookAtRotated + 9, renderer.LOOKAT_PACK(Matrix[2][1]))
	Rom.WriteU8(LookAtRotated + 10, renderer.LOOKAT_PACK(Matrix[3][1]))
	Rom.WriteU8(LookAtRotated + 24, renderer.LOOKAT_PACK(Matrix[1][2]))
	Rom.WriteU8(LookAtRotated + 25, renderer.LOOKAT_PACK(Matrix[2][2]))
	Rom.WriteU8(LookAtRotated + 26, renderer.LOOKAT_PACK(Matrix[3][2]))
	Rom.WriteU8(LookAtRotated, 0)
	Rom.WriteU8(LookAtRotated + 1, 0)
	Rom.WriteU8(LookAtRotated + 2, 0)
	Rom.WriteU8(LookAtRotated + 3, 0)
	Rom.WriteU8(LookAtRotated + 4, 0)
	Rom.WriteU8(LookAtRotated + 5, 0)
	Rom.WriteU8(LookAtRotated + 6, 0)
	Rom.WriteU8(LookAtRotated + 7, 0)
	Rom.WriteU8(LookAtRotated + 16, 0)
	Rom.WriteU8(LookAtRotated + 17, 0x80)
	Rom.WriteU8(LookAtRotated + 18, 0)
	Rom.WriteU8(LookAtRotated + 19, 0)
	Rom.WriteU8(LookAtRotated + 20, 0)
	Rom.WriteU8(LookAtRotated + 21, 0x80)
	Rom.WriteU8(LookAtRotated + 22, 0)
	Rom.WriteU8(LookAtRotated + 23, 0)

	const LookAtFixed = renderer.D_801BE790

	Rom.WriteU8(LookAtFixed + 8, 1)
	Rom.WriteU8(LookAtFixed + 9, 0)
	Rom.WriteU8(LookAtFixed + 10, 0)
	Rom.WriteU8(LookAtFixed + 24, 0)
	Rom.WriteU8(LookAtFixed + 25, 1)
	Rom.WriteU8(LookAtFixed + 26, 0)
	Rom.WriteU8(LookAtFixed, 0)
	Rom.WriteU8(LookAtFixed + 1, 0)
	Rom.WriteU8(LookAtFixed + 2, 0)
	Rom.WriteU8(LookAtFixed + 3, 0)
	Rom.WriteU8(LookAtFixed + 4, 0)
	Rom.WriteU8(LookAtFixed + 5, 0)
	Rom.WriteU8(LookAtFixed + 6, 0)
	Rom.WriteU8(LookAtFixed + 7, 0)
	Rom.WriteU8(LookAtFixed + 16, 0)
	Rom.WriteU8(LookAtFixed + 17, 0x80)
	Rom.WriteU8(LookAtFixed + 18, 0)
	Rom.WriteU8(LookAtFixed + 19, 0)
	Rom.WriteU8(LookAtFixed + 20, 0)
	Rom.WriteU8(LookAtFixed + 21, 0x80)
	Rom.WriteU8(LookAtFixed + 22, 0)
	Rom.WriteU8(LookAtFixed + 23, 0)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPLookAt(renderer.D_801BE7D0 + renderer.gGdFrameBufNum * Gbi.SIZEOF_LOOKAT)
	renderer.next_gfx()
	Gbi.Redirect(Previous)
	renderer.next_mtx()
end

-- from src/goddard/renderer.c:check_tri_display L1899-1908
function renderer.check_tri_display(vtxcount: number)
	renderer.D_801A86C0 = (renderer.sCurrentGdDl :: RendererTypes.GdDisplayList).curVtxIdx
	renderer.D_801BB0B4 = 0

	if vtxcount ~= 3 then
		DebugUtils.fatal_printf("cant display no tris\n")
	end

	if renderer.D_801BB018 ~= 0 or renderer.D_801BB01C ~= 0 then
		-- Empty in the C source.
	end
end

-- from src/goddard/renderer.c:gd_dl_make_vertex L1914-1948
function renderer.gd_dl_make_vertex(x: number, y: number, z: number, alpha: number): number?
	x = F32(x)
	y = F32(y)
	z = F32(z)
	alpha = F32(alpha)

	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList
	const Vertices = List.vtx :: number

	-- Add the vertex index to the buffer if it doesn't already exist
	for Index = renderer.sVertexBufStartIndex, renderer.sVertexBufStartIndex + renderer.sVertexBufCount - 1 do
		const Address = Vertices + Index * Gbi.SIZEOF_VTX

		if Rom.ReadS16(Address) == S16(TruncS32(x)) then
			if Rom.ReadS16(Address + 2) == S16(TruncS32(y)) then
				if Rom.ReadS16(Address + 4) == S16(TruncS32(z)) then
					renderer.sTriangleBuf[renderer.sTriangleBufCount + 1][renderer.D_801BB0B4 + 1] = S16(Index)
					renderer.D_801BB0B4 += 1

					return nil
				end
			end
		end
	end

	renderer.sVertexBufCount += 1
	renderer.sTriangleBuf[renderer.sTriangleBufCount + 1][renderer.D_801BB0B4 + 1] = S16(List.curVtxIdx)
	renderer.D_801BB0B4 += 1

	const Vertex = renderer.DL_CURRENT_VTX(List)

	Rom.WriteS16(Vertex, S16(TruncS32(x)))
	Rom.WriteS16(Vertex + 2, S16(TruncS32(y)))
	Rom.WriteS16(Vertex + 4, S16(TruncS32(z)))
	Rom.WriteS16(Vertex + 6, 0)
	Rom.WriteS16(Vertex + 8, renderer.sVtxCvrtTCBuf[1])
	Rom.WriteS16(Vertex + 10, renderer.sVtxCvrtTCBuf[2])
	Rom.WriteU8(Vertex + 12, buffer.readi8(renderer.sVtxCvrtNormBuf, 0))
	Rom.WriteU8(Vertex + 13, buffer.readi8(renderer.sVtxCvrtNormBuf, 1))
	Rom.WriteU8(Vertex + 14, buffer.readi8(renderer.sVtxCvrtNormBuf, 2))
	Rom.WriteU8(Vertex + 15, U8(TruncS32(F32(alpha * 255.0))))
	renderer.next_vtx()

	return Vertex
end

-- from src/goddard/renderer.c:func_8019FEF0 L1951-1958
function renderer.func_8019FEF0()
	renderer.sTriangleBufCount += 1

	if renderer.sVertexBufCount >= 12 then
		renderer.gd_dl_flush_vertices()
		renderer.func_801A0038()
	end

	renderer.D_801BB018 = 0
end

-- from src/goddard/renderer.c:gd_dl_make_triangle L1963-1973
function renderer.gd_dl_make_triangle(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, x3: number, y3: number, z3: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A0038 L1976-1980
function renderer.func_801A0038()
	renderer.sVertexBufCount = 0
	renderer.sTriangleBufCount = 0
	renderer.sVertexBufStartIndex = (renderer.sCurrentGdDl :: RendererTypes.GdDisplayList).curVtxIdx
end

-- from src/goddard/renderer.c:gd_dl_flush_vertices L1983-2001
function renderer.gd_dl_flush_vertices()
	if renderer.sVertexBufCount ~= 0 then
		const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList
		const Previous = Gbi.Redirect(renderer.next_gfx())

		Gbi.gSPVertex((List.vtx :: number) + renderer.sVertexBufStartIndex * Gbi.SIZEOF_VTX, renderer.sVertexBufCount, 0)

		for Index = 0, renderer.sTriangleBufCount - 1 do
			const Triangle = renderer.sTriangleBuf[Index + 1]

			Gbi.Redirect(renderer.next_gfx())
			Gbi.gSP1Triangle(Triangle[1] - renderer.sVertexBufStartIndex, Triangle[2] - renderer.sVertexBufStartIndex, Triangle[3] - renderer.sVertexBufStartIndex, 0)
		end

		Gbi.Redirect(Previous)
	end

	renderer.func_801A0038()
end

-- from src/goddard/renderer.c:func_801A01EC L2006-2011
function renderer.func_801A01EC()
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A025C L2016-2019
function renderer.func_801A025C()
	error("stale")

	return
end

-- from src/goddard/renderer.c:set_render_alpha L2022-2025
function renderer.set_render_alpha(alpha: number)
	alpha = F32(alpha)
	renderer.sAlpha = S16(TruncS32(F32(alpha * 255.0)))
	renderer.update_render_mode()
end

-- from src/goddard/renderer.c:set_light_id L2029-2031
function renderer.set_light_id(index: number)
	renderer.sLightId = index
end

-- from src/goddard/renderer.c:set_light_num L2034-2036
function renderer.set_light_num(n: number)
	renderer.sNumLights = n
end

-- from src/goddard/renderer.c:create_mtl_gddl L2039-2055
function renderer.create_mtl_gddl(mtlType: number): number
	const Blue = GdTypesH.new_GdColour()

	Blue.r = 0.0
	Blue.g = 0.0
	Blue.b = 1.0

	const DlNum = renderer.gd_startdisplist(7)

	renderer.gd_dl_material_lighting(DlNum, Blue, GdTypesH.GD_MTL_TEX_OFF)
	renderer.gd_enddlsplist_parent()

	const List = renderer.sCurrentGdDl :: RendererTypes.GdDisplayList

	List.totalVtx = List.curVtxIdx
	List.totalMtx = List.curMtxIdx
	List.totalLights = List.curLightIdx
	List.totalGfx = List.curGfxIdx
	List.totalVp = List.curVpIdx

	return DlNum
end

-- from src/goddard/renderer.c:branch_to_gddl L2058-2060
function renderer.branch_to_gddl(dlNum: number)
	renderer.branch_cur_dl_to_num(dlNum)
end

-- from src/goddard/renderer.c:gd_dl_hilite L2064-2108
function renderer.gd_dl_hilite(idx: number, cam: GdTypesH.ObjCamera, arg2: GdTypesH.GdVec3f, arg3: GdTypesH.GdVec3f, arg4: GdTypesH.GdVec3f, colour: GdTypesH.GdColour)
	const ScaleX = 32.0
	const ScaleY = 32.0

	if idx >= 0xC8 then
		DebugUtils.fatal_printf("too many hilites")
	end

	const Hilite = renderer.sHilites + idx * Gbi.SIZEOF_HILITE
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gDPSetPrimColor(0, 0, TruncS32(F32(colour.r * 255.0)), TruncS32(F32(colour.g * 255.0)), TruncS32(F32(colour.b * 255.0)), 255)
	Gbi.Redirect(Previous)

	local VecZ = F32(cam.unkE8[1][3] + arg4.x)
	local VecY = F32(cam.unkE8[2][3] + arg4.y)
	local VecX = F32(cam.unkE8[3][3] + arg4.z)
	local Length = F32(math.sqrt(F32(F32(GdMacrosH.SQ(VecZ) + GdMacrosH.SQ(VecY)) + GdMacrosH.SQ(VecX))))

	if Length > 0.1 then
		Length = F32(1.0 / Length)
		VecZ = F32(VecZ * Length)
		VecY = F32(VecY * Length)
		VecX = F32(VecX * Length)

		const SumX = F32(F32(F32(VecZ * cam.unkE8[1][1]) + F32(VecY * cam.unkE8[2][1])) + F32(VecX * cam.unkE8[3][1]))
		const SumY = F32(F32(F32(VecZ * cam.unkE8[1][2]) + F32(VecY * cam.unkE8[2][2])) + F32(VecX * cam.unkE8[3][2]))

		Rom.WriteU32(Hilite, TruncS32(F32(F32(F32(SumX * ScaleX) * 2.0) + F32(ScaleX * 4.0))))
		Rom.WriteU32(Hilite + 4, TruncS32(F32(F32(F32(SumY * ScaleY) * 2.0) + F32(ScaleY * 4.0))))
	else
		Rom.WriteU32(Hilite, TruncS32(F32(ScaleX * 2.0)))
		Rom.WriteU32(Hilite + 4, TruncS32(F32(ScaleY * 2.0)))
	end
end

-- from src/goddard/renderer.c:gd_dl_material_lighting L2113-2219
function renderer.gd_dl_material_lighting(id: number, colour: GdTypesH.GdColour, material: number): number
	local NumLights = renderer.sNumLights

	if id > 0 then
		renderer.begin_gddl(id)
	end

	if material == GdTypesH.GD_MTL_TEX_OFF then
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.FALSE)
		NumLights = Gbi.NUMLIGHTS_2
	elseif material == GdTypesH.GD_MTL_STUB_DL then
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.TRUE)
	elseif material == GdTypesH.GD_MTL_SHINE_DL then
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.TRUE)

		if id >= 200 then
			DebugUtils.fatal_printf("too many hilites")
		end

		const Previous = Gbi.Redirect(renderer.next_gfx())

		Gbi.gDPSetHilite1Tile(Gbi.G_TX_RENDERTILE, renderer.sHilites + id * Gbi.SIZEOF_HILITE, 32, 32)
		Gbi.Redirect(Previous)
	elseif material == GdTypesH.GD_MTL_BREAK then
		-- Empty in the C source.
	else
		renderer.gddl_is_loading_stub_dl(IncludePRUltratypesH.FALSE)
		renderer.gddl_is_loading_shine_dl(IncludePRUltratypesH.FALSE)

		const Light = renderer.DL_CURRENT_LIGHT(renderer.sCurrentGdDl)

		Rom.WriteU8(Light, U8(TruncS32(F32(colour.r * 255.0))))
		Rom.WriteU8(Light + 1, U8(TruncS32(F32(colour.g * 255.0))))
		Rom.WriteU8(Light + 2, U8(TruncS32(F32(colour.b * 255.0))))

		Rom.WriteU8(Light + 4, Rom.ReadU8(Light))
		Rom.WriteU8(Light + 5, Rom.ReadU8(Light + 1))
		Rom.WriteU8(Light + 6, Rom.ReadU8(Light + 2))
		Rom.WriteU8(Light + 8, 0)
		Rom.WriteU8(Light + 9, 0)
		Rom.WriteU8(Light + 10, 0)

		Rom.WriteU8(Light + 12, 0)
		Rom.WriteU8(Light + 13, 0)
		Rom.WriteU8(Light + 14, 0)

		const Previous = Gbi.Redirect(renderer.next_gfx())

		Gbi.gSPNumLights(Gbi.NUMLIGHTS_1)
		Gbi.Redirect(renderer.next_gfx())
		Gbi.gSPLight(Light + 8, Gbi.LIGHT_1)
		Gbi.Redirect(renderer.next_gfx())
		Gbi.gSPLight(Light, Gbi.LIGHT_2)
		Gbi.Redirect(Previous)
		renderer.next_light()

		if id > 0 then
			renderer.gd_enddlsplist()
		end

		return 0
	end

	local ScaledR = TruncS32(F32(F32(colour.r * renderer.sAmbScaleColour.r) * 255.0))
	local ScaledG = TruncS32(F32(F32(colour.g * renderer.sAmbScaleColour.g) * 255.0))
	local ScaledB = TruncS32(F32(F32(colour.b * renderer.sAmbScaleColour.b) * 255.0))
	const Light = renderer.DL_CURRENT_LIGHT(renderer.sCurrentGdDl)

	Rom.WriteU8(Light, U8(ScaledR))
	Rom.WriteU8(Light + 1, U8(ScaledG))
	Rom.WriteU8(Light + 2, U8(ScaledB))

	Rom.WriteU8(Light + 4, U8(ScaledR))
	Rom.WriteU8(Light + 5, U8(ScaledG))
	Rom.WriteU8(Light + 6, U8(ScaledB))

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPNumLights(NumLights)

	local LightIndex = 0

	while LightIndex < NumLights do
		ScaledR = TruncS32(F32(F32(colour.r * renderer.sLightScaleColours[LightIndex + 1].r) * 255.0))
		ScaledG = TruncS32(F32(F32(colour.g * renderer.sLightScaleColours[LightIndex + 1].g) * 255.0))
		ScaledB = TruncS32(F32(F32(colour.b * renderer.sLightScaleColours[LightIndex + 1].b) * 255.0))

		const Directional = renderer.DL_CURRENT_LIGHT(renderer.sCurrentGdDl) + 8 + LightIndex * Gbi.SIZEOF_LIGHT

		Rom.WriteU8(Directional, U8(ScaledR))
		Rom.WriteU8(Directional + 1, U8(ScaledG))
		Rom.WriteU8(Directional + 2, U8(ScaledB))
		Rom.WriteU8(Directional + 4, U8(ScaledR))
		Rom.WriteU8(Directional + 5, U8(ScaledG))
		Rom.WriteU8(Directional + 6, U8(ScaledB))

		const DirX = S8(renderer.sLightDirections[LightIndex + 1].x)
		const DirY = S8(renderer.sLightDirections[LightIndex + 1].y)
		const DirZ = S8(renderer.sLightDirections[LightIndex + 1].z)

		Rom.WriteU8(Directional + 8, DirX)
		Rom.WriteU8(Directional + 9, DirY)
		Rom.WriteU8(Directional + 10, DirZ)
		Gbi.Redirect(renderer.next_gfx())
		Gbi.gSPLight(Directional, LightIndex + 1)
		LightIndex += 1
	end

	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPLight(renderer.DL_CURRENT_LIGHT(renderer.sCurrentGdDl), LightIndex + 1)
	Gbi.Redirect(Previous)
	renderer.next_light()
	renderer.gd_enddlsplist()

	return 0
end

-- from src/goddard/renderer.c:set_Vtx_norm_buf_1 L2222-2226
function renderer.set_Vtx_norm_buf_1(norm: GdTypesH.GdVec3f)
	error("stale")

	return
end

-- from src/goddard/renderer.c:set_Vtx_norm_buf_2 L2229-2237
function renderer.set_Vtx_norm_buf_2(norm: GdTypesH.GdVec3f)
	buffer.writei8(renderer.sVtxCvrtNormBuf, 0, S8(TruncS32(F32(norm.x * 127.0))))
	buffer.writei8(renderer.sVtxCvrtNormBuf, 1, S8(TruncS32(F32(norm.y * 127.0))))
	buffer.writei8(renderer.sVtxCvrtNormBuf, 2, S8(TruncS32(F32(norm.z * 127.0))))
end

-- from src/goddard/renderer.c:set_gd_mtx_parameters L2240-2249
function renderer.set_gd_mtx_parameters(params: number)
	if params == bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH) then
		renderer.sMtxParamType = Gbi.G_MTX_PROJECTION
	elseif params == bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_PUSH) then
		renderer.sMtxParamType = Gbi.G_MTX_MODELVIEW
	end
end

-- from src/goddard/renderer.c:gd_dl_viewport L2254-2271
function renderer.gd_dl_viewport()
	const Viewport = renderer.DL_CURRENT_VP(renderer.sCurrentGdDl)
	const View = renderer.sActiveView :: GdTypesH.ObjView
	const ScaleX = F32(View.lowerRight.x * 2.0)
	const ScaleY = F32(View.lowerRight.y * 2.0)

	Rom.WriteS16(Viewport, TruncS32(ScaleX))
	Rom.WriteS16(Viewport + 2, TruncS32(ScaleY))
	Rom.WriteS16(Viewport + 4, 0x1FF)
	Rom.WriteS16(Viewport + 6, 0)
	Rom.WriteS16(Viewport + 8, TruncS32(F32(F32(View.upperLeft.x * 4.0) + ScaleX)))
	Rom.WriteS16(Viewport + 10, TruncS32(F32(F32(View.upperLeft.y * 4.0) + ScaleY)))
	Rom.WriteS16(Viewport + 12, 0x1FF)
	Rom.WriteS16(Viewport + 14, 0)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPViewport(Viewport)
	Gbi.Redirect(Previous)
	renderer.next_vp()
end

-- from src/goddard/renderer.c:update_render_mode L2274-2288
function renderer.update_render_mode()
	const View = renderer.sActiveView :: GdTypesH.ObjView
	const Previous = Gbi.Redirect(renderer.next_gfx())

	if bit32.btest(View.flags, GdTypesH.VIEW_ALLOC_ZBUF) then
		if renderer.sAlpha ~= 0xFF then
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_XLU_SURF, Gbi.G_RM_AA_ZB_XLU_SURF2)
		else
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_INTER, Gbi.G_RM_NOOP2)
		end
	else
		if renderer.sAlpha ~= 0xFF then
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_XLU_SURF, Gbi.G_RM_AA_XLU_SURF2)
		else
			Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_INTER, Gbi.G_RM_NOOP2)
		end
	end

	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:Unknown801A1B30 L2291-2299
function renderer.Unknown801A1B30()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A1E70 L2302-2315
function renderer.Unknown801A1E70()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_set_one_cycle L2318-2321
function renderer.gd_set_one_cycle()
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_3 L2324-2326
function renderer.stub_renderer_3()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gddl_is_loading_stub_dl L2329-2330
function renderer.gddl_is_loading_stub_dl(dlLoad: number)
	-- Empty in the C source.
end

-- from src/goddard/renderer.c:gddl_is_loading_shine_dl L2333-2340
function renderer.gddl_is_loading_shine_dl(dlLoad: number)
	const Previous = Gbi.Redirect(renderer.next_gfx())

	if dlLoad ~= 0 then
		Gbi.gSPDisplayList(renderer.gd_dl_mario_face_shine)
	else
		Gbi.gSPTexture(0x8000, 0x8000, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
		Gbi.Redirect(renderer.next_gfx())
		Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)
	end

	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:start_view_dl L2343-2391
function renderer.start_view_dl(view: GdTypesH.ObjView)
	const Parent = view.parent :: GdTypesH.ObjView
	local ulx = 0.0
	local uly = 0.0
	local lrx = 0.0
	local lry = 0.0

	if view.upperLeft.x < Parent.upperLeft.x then
		ulx = Parent.upperLeft.x
	else
		ulx = view.upperLeft.x
	end

	if F32(view.upperLeft.x + view.lowerRight.x) > F32(Parent.upperLeft.x + Parent.lowerRight.x) then
		lrx = F32(Parent.upperLeft.x + Parent.lowerRight.x)
	else
		lrx = F32(view.upperLeft.x + view.lowerRight.x)
	end

	if view.upperLeft.y < Parent.upperLeft.y then
		uly = Parent.upperLeft.y
	else
		uly = view.upperLeft.y
	end

	if F32(view.upperLeft.y + view.lowerRight.y) > F32(Parent.upperLeft.y + Parent.lowerRight.y) then
		lry = F32(Parent.upperLeft.y + Parent.lowerRight.y)
	else
		lry = F32(view.upperLeft.y + view.lowerRight.y)
	end

	if ulx >= lrx then
		ulx = F32(lrx - 1.0)
	end

	if uly >= lry then
		uly = F32(lry - 1.0)
	end

	local Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, ulx, uly, lrx, lry)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPClearGeometryMode(0xFFFFFFFF)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPSetGeometryMode(bit32.bor(Gbi.G_LIGHTING, Gbi.G_CULL_BACK, Gbi.G_SHADING_SMOOTH, Gbi.G_SHADE))

	if bit32.btest(view.flags, GdTypesH.VIEW_ALLOC_ZBUF) then
		Gbi.Redirect(renderer.next_gfx())
		Gbi.gSPSetGeometryMode(Gbi.G_ZBUFFER)
	end

	Gbi.Redirect(Previous)
	renderer.gd_dl_viewport()
	renderer.update_render_mode()
	Previous = Gbi.Redirect(renderer.next_gfx())
	Gbi.gDPPipeSync()
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:parse_p1_controller L2394-2512
function renderer.parse_p1_controller()
	const Ctrl = GdMain.gGdCtrl
	const Previous = Ctrl.prevFrame :: GdMainH.GdControl

	-- Copy current inputs to previous
	Previous.unk00 = Ctrl.unk00
	Previous.dleft = Ctrl.dleft
	Previous.dright = Ctrl.dright
	Previous.dup = Ctrl.dup
	Previous.ddown = Ctrl.ddown
	Previous.cleft = Ctrl.cleft
	Previous.cright = Ctrl.cright
	Previous.cup = Ctrl.cup
	Previous.cdown = Ctrl.cdown
	Previous.unk28 = Ctrl.unk28
	Previous.unk2C = Ctrl.unk2C
	Previous.unk30 = Ctrl.unk30
	Previous.btnA = Ctrl.btnA
	Previous.btnB = Ctrl.btnB
	Previous.trgL = Ctrl.trgL
	Previous.trgR = Ctrl.trgR
	Previous.unk4C = Ctrl.unk4C
	Previous.unk50 = Ctrl.unk50
	Previous.newStartPress = Ctrl.newStartPress
	Previous.stickXf = Ctrl.stickXf
	Previous.stickYf = Ctrl.stickYf
	Previous.unk88 = Ctrl.unk88
	Previous.unkA0 = Ctrl.unkA0
	Previous.unkAC = Ctrl.unkAC
	Previous.dragStartX = Ctrl.dragStartX
	Previous.dragStartY = Ctrl.dragStartY
	Previous.stickDeltaX = Ctrl.stickDeltaX
	Previous.stickDeltaY = Ctrl.stickDeltaY
	Previous.stickX = Ctrl.stickX
	Previous.stickY = Ctrl.stickY
	Previous.csrX = Ctrl.csrX
	Previous.csrY = Ctrl.csrY
	Previous.dragging = Ctrl.dragging
	Previous.unkD8b40 = Ctrl.unkD8b40
	Previous.unkD8b20 = Ctrl.unkD8b20
	Previous.startedDragging = Ctrl.startedDragging
	Previous.unkD8b08 = Ctrl.unkD8b08
	Previous.unkD8b04 = Ctrl.unkD8b04
	Previous.AbtnPressWait = Ctrl.AbtnPressWait
	Previous.dragStartFrame = Ctrl.dragStartFrame
	Previous.currFrame = Ctrl.currFrame
	Previous.prevFrame = Ctrl.prevFrame

	Ctrl.ddown = 0
	Ctrl.dup = 0
	Ctrl.unk4C = 0
	Ctrl.unk50 = 0

	const CurrInputs = renderer.sGdContPads[1]
	const PrevInputs = renderer.sPrevFrameCont[1]

	-- stick values
	Ctrl.stickXf = F32(CurrInputs.stick_x)
	Ctrl.stickYf = F32(CurrInputs.stick_y)
	Ctrl.stickDeltaX = Ctrl.stickX
	Ctrl.stickDeltaY = Ctrl.stickY
	Ctrl.stickX = CurrInputs.stick_x
	Ctrl.stickY = CurrInputs.stick_y
	Ctrl.stickDeltaX = S32(Ctrl.stickDeltaX - Ctrl.stickX)
	Ctrl.stickDeltaY = S32(Ctrl.stickDeltaY - Ctrl.stickY)

	-- button values (as bools)
	Ctrl.trgL = if bit32.btest(CurrInputs.button, IncludePROsH.L_TRIG) then 1 else 0
	Ctrl.trgR = if bit32.btest(CurrInputs.button, IncludePROsH.R_TRIG) then 1 else 0
	Ctrl.btnA = if bit32.btest(CurrInputs.button, IncludePROsH.A_BUTTON) then 1 else 0
	Ctrl.btnB = if bit32.btest(CurrInputs.button, IncludePROsH.B_BUTTON) then 1 else 0
	Ctrl.cleft = if bit32.btest(CurrInputs.button, IncludePROsH.L_CBUTTONS) then 1 else 0
	Ctrl.cright = if bit32.btest(CurrInputs.button, IncludePROsH.R_CBUTTONS) then 1 else 0
	Ctrl.cup = if bit32.btest(CurrInputs.button, IncludePROsH.U_CBUTTONS) then 1 else 0
	Ctrl.cdown = if bit32.btest(CurrInputs.button, IncludePROsH.D_CBUTTONS) then 1 else 0

	-- but not these buttons??
	Ctrl.dleft = bit32.band(CurrInputs.button, IncludePROsH.L_JPAD)
	Ctrl.dright = bit32.band(CurrInputs.button, IncludePROsH.R_JPAD)
	Ctrl.dup = bit32.band(CurrInputs.button, IncludePROsH.U_JPAD)
	Ctrl.ddown = bit32.band(CurrInputs.button, IncludePROsH.D_JPAD)

	if Ctrl.btnA ~= 0 and Ctrl.dragging == 0 then
		Ctrl.startedDragging = IncludePRUltratypesH.TRUE
	else
		Ctrl.startedDragging = IncludePRUltratypesH.FALSE
	end

	-- toggle if A is pressed? or is this just some seed for an rng?
	Ctrl.dragging = U8(bit32.band(Ctrl.btnA, 1))
	Ctrl.unkD8b40 = IncludePRUltratypesH.FALSE
	Ctrl.unkD8b20 = IncludePRUltratypesH.FALSE
	Ctrl.AbtnPressWait = IncludePRUltratypesH.FALSE

	if Ctrl.startedDragging ~= 0 then
		Ctrl.dragStartX = Ctrl.csrX
		Ctrl.dragStartY = Ctrl.csrY

		if bit32.band(Ctrl.currFrame - Ctrl.dragStartFrame, 0xFFFFFFFF) < 10 then
			Ctrl.AbtnPressWait = IncludePRUltratypesH.TRUE
		end
	end

	if Ctrl.dragging ~= 0 then
		Ctrl.dragStartFrame = Ctrl.currFrame
	end

	Ctrl.currFrame = bit32.band(Ctrl.currFrame + 1, 0xFFFFFFFF)

	if bit32.btest(CurrInputs.button, IncludePROsH.START_BUTTON) and not bit32.btest(PrevInputs.button, IncludePROsH.START_BUTTON) then
		Ctrl.newStartPress = S32(bit32.bxor(Ctrl.newStartPress, 1))
	end

	if bit32.btest(CurrInputs.button, IncludePROsH.Z_TRIG) and not bit32.btest(PrevInputs.button, IncludePROsH.Z_TRIG) then
		renderer.sCurrDebugViewIndex += 1
	end

	if renderer.sCurrDebugViewIndex > renderer.sDebugViewsCount then
		renderer.sCurrDebugViewIndex = 0
	elseif renderer.sCurrDebugViewIndex < 0 then
		renderer.sCurrDebugViewIndex = renderer.sDebugViewsCount
	end

	if renderer.sCurrDebugViewIndex ~= 0 then
		DebugUtils.deactivate_timing()
	else
		-- activate_timing is replaced: no call
	end

	for Index = 0, renderer.sDebugViewsCount - 1 do
		const DebugView = renderer.sDebugViews[Index + 1] :: GdTypesH.ObjView

		DebugView.flags = bit32.band(DebugView.flags, bit32.bnot(GdTypesH.VIEW_UPDATE))
	end

	if renderer.sCurrDebugViewIndex ~= 0 then
		const DebugView = renderer.sDebugViews[renderer.sCurrDebugViewIndex] :: GdTypesH.ObjView

		DebugView.flags = bit32.bor(DebugView.flags, GdTypesH.VIEW_UPDATE)
	end

	-- deadzone checks
	if GdMacrosH.ABS(Ctrl.stickX) >= 6 then
		Ctrl.csrX = TruncS32(Ctrl.csrX + Ctrl.stickX * 0.1)
	end

	if GdMacrosH.ABS(Ctrl.stickY) >= 6 then
		Ctrl.csrY = TruncS32(Ctrl.csrY - Ctrl.stickY * 0.1)
	end

	-- clamp cursor position within screen view bounds
	const Screen = (renderer.sScreenView :: GdTypesH.ObjView).parent :: GdTypesH.ObjView

	if Ctrl.csrX < F32(Screen.upperLeft.x + 16.0) then
		Ctrl.csrX = TruncS32(F32(Screen.upperLeft.x + 16.0))
	end

	if Ctrl.csrX > F32(F32(Screen.upperLeft.x + Screen.lowerRight.x) - 48.0) then
		Ctrl.csrX = TruncS32(F32(F32(Screen.upperLeft.x + Screen.lowerRight.x) - 48.0))
	end

	if Ctrl.csrY < F32(Screen.upperLeft.y + 16.0) then
		Ctrl.csrY = TruncS32(F32(Screen.upperLeft.y + 16.0))
	end

	if Ctrl.csrY > F32(F32(Screen.upperLeft.y + Screen.lowerRight.y) - 32.0) then
		Ctrl.csrY = TruncS32(F32(F32(Screen.upperLeft.y + Screen.lowerRight.y) - 32.0))
	end

	PrevInputs.button = CurrInputs.button
	PrevInputs.stick_x = CurrInputs.stick_x
	PrevInputs.stick_y = CurrInputs.stick_y
	PrevInputs.errnum = CurrInputs.errnum
end

-- from src/goddard/renderer.c:stub_renderer_4 L2514-2522
function renderer.stub_renderer_4(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A32F4 L2527-2529
function renderer.Unknown801A32F4(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A3324 L2532-2539
function renderer.func_801A3324(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	renderer.D_801BD768.x = x
	renderer.D_801BD768.y = y
	renderer.D_801BD768.z = z
	renderer.D_801BD758.x = x
	renderer.D_801BD758.y = y
	renderer.D_801BD758.z = z
end

-- from src/goddard/renderer.c:func_801A3370 L2542-2547
function renderer.func_801A3370(x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A33F8 L2552-2558
function renderer.Unknown801A33F8(x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A347C L2563-2568
function renderer.Unknown801A347C(x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:border_active_view L2571-2577
function renderer.border_active_view()
	const View = renderer.sActiveView :: GdTypesH.ObjView

	if bit32.btest(View.flags, GdTypesH.VIEW_BORDERED) then
		renderer.gd_dl_set_fill(DrawObjects.gd_get_colour(1) :: GdTypesH.GdColour)
		renderer.gd_draw_border_rect(0.0, 0.0, F32(View.lowerRight.x - 1.0), F32(View.lowerRight.y - 1.0))
	end
end

-- from src/goddard/renderer.c:gd_shading L2580-2589
function renderer.gd_shading(model: number)
	if model == 9 then
		-- Empty in the C source.
	elseif model == 10 then
		-- Empty in the C source.
	else
		DebugUtils.fatal_printf("gd_shading(): Unknown shading model")
	end
end

-- from src/goddard/renderer.c:gd_getproperty L2592-2604
function renderer.gd_getproperty(prop: number, arg1: unknown): number
	local got = IncludePRUltratypesH.FALSE

	if prop == 3 then
		got = IncludePRUltratypesH.TRUE
	else
		DebugUtils.fatal_printf("gd_getproperty(): Unkown property")
	end

	return got
end

-- from src/goddard/renderer.c:gd_setproperty L2607-2686
function renderer.gd_setproperty(prop: number, f1: number, f2: number, f3: number)
	f1 = F32(f1)
	f2 = F32(f2)
	f3 = F32(f3)

	local parm = 0

	if prop == RendererH.GD_PROP_LIGHTING then
		parm = TruncS32(f1)

		if parm == 1 then
			const Previous = Gbi.Redirect(renderer.next_gfx())

			Gbi.gSPSetGeometryMode(Gbi.G_LIGHTING)
			Gbi.Redirect(Previous)
		elseif parm == 0 then
			const Previous = Gbi.Redirect(renderer.next_gfx())

			Gbi.gSPClearGeometryMode(Gbi.G_LIGHTING)
			Gbi.Redirect(Previous)
		end
	elseif prop == RendererH.GD_PROP_AMB_COLOUR then
		renderer.sAmbScaleColour.r = f1
		renderer.sAmbScaleColour.g = f2
		renderer.sAmbScaleColour.b = f3
	elseif prop == RendererH.GD_PROP_LIGHT_DIR then
		renderer.sLightDirections[renderer.sLightId + 1].x = TruncS32(F32(f1 * 120.0))
		renderer.sLightDirections[renderer.sLightId + 1].y = TruncS32(F32(f2 * 120.0))
		renderer.sLightDirections[renderer.sLightId + 1].z = TruncS32(F32(f3 * 120.0))
	elseif prop == RendererH.GD_PROP_DIFUSE_COLOUR then
		renderer.sLightScaleColours[renderer.sLightId + 1].r = f1
		renderer.sLightScaleColours[renderer.sLightId + 1].g = f2
		renderer.sLightScaleColours[renderer.sLightId + 1].b = f3
	elseif prop == RendererH.GD_PROP_CULLING then
		parm = TruncS32(f1)

		if parm == 1 then
			const Previous = Gbi.Redirect(renderer.next_gfx())

			Gbi.gSPSetGeometryMode(Gbi.G_CULL_BACK)
			Gbi.Redirect(Previous)
		elseif parm == 0 then
			const Previous = Gbi.Redirect(renderer.next_gfx())

			Gbi.gSPClearGeometryMode(Gbi.G_CULL_BACK)
			Gbi.Redirect(Previous)
		end
	elseif prop == RendererH.GD_PROP_OVERLAY then
		parm = TruncS32(f1)

		if parm == 1 then
			-- Empty in the C source.
		elseif parm == 0 then
			-- Empty in the C source.
		else
			DebugUtils.fatal_printf("Bad GD_OVERLAY parm")
		end
	elseif prop == RendererH.GD_PROP_ZBUF_FN then
		parm = TruncS32(f1)

		if parm == 23 then
			-- Empty in the C source.
		elseif parm == 24 then
			-- Empty in the C source.
		elseif parm == 25 then
			-- Empty in the C source.
		else
			DebugUtils.fatal_printf("Bad zbuf function")
		end
	elseif prop == RendererH.GD_PROP_STUB17 then
		-- Empty in the C source.
	elseif prop == RendererH.GD_PROP_STUB18 then
		-- Empty in the C source.
	elseif prop == RendererH.GD_PROP_STUB19 then
		-- Empty in the C source.
	elseif prop == RendererH.GD_PROP_STUB20 then
		-- Empty in the C source.
	elseif prop == RendererH.GD_PROP_STUB21 then
		-- Empty in the C source.
	else
		DebugUtils.fatal_printf("gd_setproperty(): Unkown property")
	end
end

-- from src/goddard/renderer.c:stub_renderer_5 L2689-2690
function renderer.stub_renderer_5()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_create_ortho_matrix L2693-2711
function renderer.gd_create_ortho_matrix(l: number, r: number, b: number, t: number, n: number, f: number)
	l = F32(l)
	r = F32(r)
	b = F32(b)
	t = F32(t)
	n = F32(n)
	f = F32(f)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPPerspNormalize(0xFFFF)

	const OrthoMatrix = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guOrtho(OrthoMatrix, l, r, b, t, n, f, 1.0)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPMatrix(renderer.GD_LOWER_29(OrthoMatrix), bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	renderer.next_mtx()

	const RotationMatrix = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guRotate(RotationMatrix, 0.0, 0.0, 0.0, 1.0)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPMatrix(renderer.GD_LOWER_29(RotationMatrix), bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	renderer.func_801A3324(0.0, 0.0, 0.0)
	renderer.next_mtx()
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:gd_create_perspective_matrix L2714-2736
function renderer.gd_create_perspective_matrix(fovy: number, aspect: number, near: number, far: number)
	fovy = F32(fovy)
	aspect = F32(aspect)
	near = F32(near)
	far = F32(far)
	renderer.sGdPerspTimer = F32(renderer.sGdPerspTimer + 0.1)

	const ProjectionMatrix = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guPerspective(ProjectionMatrix, PerspectiveNormalization, fovy, aspect, near, far, 1.0)

	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPPerspNormalize(PerspectiveNormalization[1])
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPMatrix(renderer.GD_LOWER_29(ProjectionMatrix), bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	renderer.next_mtx()

	const RotationMatrix = renderer.DL_CURRENT_MTX(renderer.sCurrentGdDl)

	Gbi.guRotate(RotationMatrix, 0.0, 0.0, 0.0, 1.0)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPMatrix(renderer.GD_LOWER_29(RotationMatrix), bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	renderer.func_801A3324(0.0, 0.0, 0.0)
	renderer.next_mtx()
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:setup_view_buffers L2739-2803
function renderer.setup_view_buffers(name: string, view: GdTypesH.ObjView, ulx: number, uly: number, lrx: number, lry: number): number
	const Screen = renderer.sScreenView :: GdTypesH.ObjView

	if bit32.btest(view.flags, bit32.bor(GdTypesH.VIEW_Z_BUF, GdTypesH.VIEW_COLOUR_BUF)) and not bit32.btest(view.flags, GdTypesH.VIEW_UNK_1000) then
		const Size = bit32.band(math.modf(F32(F32(F32(2.0 * view.lowerRight.x) * view.lowerRight.y) + 64.0)), 0xFFFFFFFF)

		if bit32.btest(view.flags, GdTypesH.VIEW_COLOUR_BUF) then
			const First = renderer.gd_malloc(Size, 0x20) :: number?
			const Second = if bit32.btest(view.flags, GdTypesH.VIEW_2_COL_BUF) then renderer.gd_malloc(Size, 0x20) :: number? else First

			if First == nil or Second == nil then
				error("Not enough DRAM for colour buffers\n")
			end

			view.colourBufs[1] = GdMacrosH.ALIGN(First, 64)
			view.colourBufs[2] = GdMacrosH.ALIGN(Second, 64)
			view.parent = view
		else
			view.parent = Screen
		end

		if bit32.btest(view.flags, GdTypesH.VIEW_Z_BUF) then
			if bit32.btest(view.flags, GdTypesH.VIEW_ALLOC_ZBUF) then
				const Depth = renderer.gd_malloc(Size, 0x40) :: number?

				if Depth == nil then
					error("Not enough DRAM for Z buffer\n")
				end

				view.zbuf = GdMacrosH.ALIGN(Depth, 64)
			end
		else
			view.zbuf = Screen.zbuf
		end
	else
		view.parent = Screen
	end

	view.gdDlNum = 0
	view.unk74 = 0

	if bit32.btest(view.flags, GdTypesH.VIEW_DEFAULT_PARENT) then
		view.parent = renderer.D_801A86E0
	end

	return 0
end

-- from src/goddard/renderer.c:gd_init_controllers L2806-2818
function renderer.gd_init_controllers()
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_6 L2821-2822
function renderer.stub_renderer_6(obj: GdTypesH.GdObj)
	error("stale")

	return
end

-- from src/goddard/renderer.c:defpup L2833-2838
function renderer.defpup(menufmt: string, ...: unknown): number
	error("stale")
end

-- from src/goddard/renderer.c:menu_cb_control_type L2848-2849
function renderer.menu_cb_control_type(itemId: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:menu_cb_recalibrate_controller L2855-2856
function renderer.menu_cb_recalibrate_controller(itemId: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A4438 L2859-2863
function renderer.func_801A4438(x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_gentexture L2866-2901
function renderer.gd_gentexture(texture: unknown, fmt: number, size: number, arg3: number, arg4: number): number
	error("stale")
end

-- from src/goddard/renderer.c:load_texture_from_file L2906-2938
function renderer.load_texture_from_file(file: string, fmt: number, size: number, arg3: number, arg4: number): unknown
	error("stale")
end

-- from src/goddard/renderer.c:Unknown801A47B8 L2941-2945
function renderer.Unknown801A47B8(v: GdTypesH.ObjView)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_7 L2947-2948
function renderer.stub_renderer_7()
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_8 L2951-2952
function renderer.stub_renderer_8(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A4808 L2957-2963
function renderer.func_801A4808()
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A4848 L2966-2973
function renderer.func_801A4848(linkDl: number)
	const List = renderer.sCurrentGdDl

	renderer.sCurrentGdDl = renderer.sMHeadMainDls[renderer.gGdFrameBufNum + 1]
	renderer.branch_cur_dl_to_num(linkDl)
	renderer.sCurrentGdDl = List
end

-- from src/goddard/renderer.c:stub_renderer_9 L2978-2979
function renderer.stub_renderer_9()
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_10 L2982-2983
function renderer.stub_renderer_10(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_draw_label_text L2986-2990
function renderer.stub_draw_label_text(s: string)
	error("stale")

	return
end

-- from src/goddard/renderer.c:set_active_view L2993-2995
function renderer.set_active_view(v: GdTypesH.ObjView)
	renderer.sActiveView = v
end

-- from src/goddard/renderer.c:stub_renderer_11 L2997-2998
function renderer.stub_renderer_11()
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A4918 L3003-3024
function renderer.func_801A4918()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A4B04 L3027-3040
function renderer.Unknown801A4B04()
	error("stale")

	return
end

-- from src/goddard/renderer.c:update_cursor L3043-3082
function renderer.update_cursor()
	const HandView = renderer.sHandView

	if HandView == nil then
		return
	end

	const Ctrl = GdMain.gGdCtrl

	if bit32.band(Ctrl.currFrame - Ctrl.dragStartFrame, 0xFFFFFFFF) < 300 then
		HandView.flags = bit32.bor(HandView.flags, GdTypesH.VIEW_UPDATE)
		-- by playing the sfx every frame, it will only play once as it
		-- never leaves the "sfx played last frame" buffer
		Sfx.gd_play_sfx(SfxH.GD_SFX_HAND_APPEAR)
	else
		HandView.flags = bit32.band(HandView.flags, bit32.bnot(GdTypesH.VIEW_UPDATE))
		Sfx.gd_play_sfx(SfxH.GD_SFX_HAND_DISAPPEAR)
	end

	HandView.upperLeft.x = F32(Ctrl.csrX)
	HandView.upperLeft.y = F32(Ctrl.csrY)

	-- Make hand display list
	renderer.begin_gddl((renderer.sHandShape :: GdTypesH.ObjShape).dlNums[renderer.gGdFrameBufNum + 1])

	if Ctrl.dragging ~= 0 then
		renderer.gd_put_sprite(renderer.gd_texture_hand_closed, TruncS32(HandView.upperLeft.x), TruncS32(HandView.upperLeft.y), 0x20, 0x20)
	else
		renderer.gd_put_sprite(renderer.gd_texture_hand_open, TruncS32(HandView.upperLeft.x), TruncS32(HandView.upperLeft.y), 0x20, 0x20)
	end

	renderer.gd_enddlsplist_parent()

	const Parent = HandView.parent :: GdTypesH.ObjView

	if HandView.upperLeft.x < Parent.upperLeft.x then
		HandView.upperLeft.x = Parent.upperLeft.x
	end

	if HandView.upperLeft.x > F32(Parent.upperLeft.x + Parent.lowerRight.x) then
		HandView.upperLeft.x = F32(Parent.upperLeft.x + Parent.lowerRight.x)
	end

	if HandView.upperLeft.y < Parent.upperLeft.y then
		HandView.upperLeft.y = Parent.upperLeft.y
	end

	if HandView.upperLeft.y > F32(Parent.upperLeft.y + Parent.lowerRight.y) then
		HandView.upperLeft.y = F32(Parent.upperLeft.y + Parent.lowerRight.y)
	end
end

-- from src/goddard/renderer.c:Unknown801A4F58 L3085-3122
function renderer.Unknown801A4F58()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Proc801A5110 L3125-3129
function renderer.Proc801A5110(view: GdTypesH.ObjView)
	error("stale")

	return
end

-- from src/goddard/renderer.c:update_view_and_dl L3132-3144
function renderer.update_view_and_dl(view: GdTypesH.ObjView)
	const prevFlags = view.flags

	DrawObjects.update_view(view)

	if bit32.btest(prevFlags, GdTypesH.VIEW_UPDATE) then
		renderer.sCurrentGdDl = renderer.sMHeadMainDls[renderer.gGdFrameBufNum + 1]

		if view.gdDlNum ~= 0 then
			renderer.func_801A4848(view.gdDlNum)
		end
	end
end

-- from src/goddard/renderer.c:func_801A520C L3149-3176
function renderer.func_801A520C()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A5344 L3181-3195
function renderer.Unknown801A5344()
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_init L3198-3285
function renderer.gd_init()
	local Index = S32(bit32.band(renderer.sMemBlockPoolSize - IncludePlatformInfoH.DOUBLE_SIZE_ON_64_BIT(0x3E800), 0xFFFFFFFF))
	const Data = renderer.gd_allocblock(Index)

	GdMemory.gd_add_mem_to_heap(Index, Data, 0x10)
	renderer.sAlpha = S16(0xFF)
	renderer.D_801A867C = 0
	renderer.D_801A8680 = 0
	renderer.sTextureCount = 0
	renderer.gGdFrameBufNum = 0
	renderer.D_801A86BC = 1
	renderer.sItemsInMenu = 0
	renderer.sDebugViewsCount = 0
	renderer.sCurrDebugViewIndex = 0
	renderer.sGdDlCount = 0
	renderer.D_801A8674 = 0
	renderer.sLightId = 0
	renderer.sAmbScaleColour.r = 0.0
	renderer.sAmbScaleColour.g = 0.0
	renderer.sAmbScaleColour.b = 0.0

	Index = 0

	while Index < IncludeMacrosH.ARRAY_COUNT(renderer.sLightScaleColours) do
		renderer.sLightScaleColours[Index + 1].r = 1.0
		renderer.sLightScaleColours[Index + 1].g = 0.0
		renderer.sLightScaleColours[Index + 1].b = 0.0
		renderer.sLightDirections[Index + 1].x = 0
		renderer.sLightDirections[Index + 1].y = 120
		renderer.sLightDirections[Index + 1].z = 0
		Index += 1
	end

	renderer.sNumLights = Gbi.NUMLIGHTS_2
	GdMath.gd_set_identity_mat4(renderer.sInitIdnMat4)
	renderer.mat4_to_mtx(renderer.sInitIdnMat4, renderer.sIdnMtx)
	Objects.null_obj_lists()

	renderer.sStaticDl = renderer.new_gd_dl(0, 1900, 4000, 1, 300, 8)

	renderer.sDynamicMainDls[1] = renderer.new_gd_dl(1, 600, 10, 200, 10, 3)
	renderer.sDynamicMainDls[2] = renderer.new_gd_dl(1, 600, 10, 200, 10, 3)

	renderer.sMHeadMainDls[1] = renderer.new_gd_dl(1, 100, 0, 0, 0, 0)
	renderer.sMHeadMainDls[2] = renderer.new_gd_dl(1, 100, 0, 0, 0, 0)

	Index = 0

	while Index < IncludeMacrosH.ARRAY_COUNT(renderer.sViewDls) do
		renderer.sViewDls[Index + 1][1] = renderer.create_child_gdl(1, renderer.sDynamicMainDls[1] :: RendererTypes.GdDisplayList)
		renderer.sViewDls[Index + 1][2] = renderer.create_child_gdl(1, renderer.sDynamicMainDls[2] :: RendererTypes.GdDisplayList)
		Index += 1
	end

	const ScreenView = Objects.make_view("screenview2", bit32.bor(GdTypesH.VIEW_2_COL_BUF, GdTypesH.VIEW_UNK_1000, GdTypesH.VIEW_COLOUR_BUF, GdTypesH.VIEW_Z_BUF), 0, 0, 0, 320, 240, nil)

	renderer.sScreenView = ScreenView
	ScreenView.colour.r = 0.0
	ScreenView.colour.g = 0.0
	ScreenView.colour.b = 0.0
	ScreenView.parent = ScreenView
	ScreenView.flags = bit32.band(ScreenView.flags, bit32.bnot(GdTypesH.VIEW_UPDATE))
	renderer.sActiveView = ScreenView

	-- Zero out controller inputs
	const Ctrl = GdMain.gGdCtrl

	Ctrl.unk00 = 0
	Ctrl.dleft = 0
	Ctrl.dright = 0
	Ctrl.dup = 0
	Ctrl.ddown = 0
	Ctrl.cleft = 0
	Ctrl.cright = 0
	Ctrl.cup = 0
	Ctrl.cdown = 0
	Ctrl.unk28 = nil
	Ctrl.unk2C = nil
	Ctrl.unk30 = nil
	Ctrl.btnA = 0
	Ctrl.btnB = 0
	Ctrl.trgL = 0
	Ctrl.trgR = 0
	Ctrl.unk4C = 0
	Ctrl.unk50 = 0
	Ctrl.newStartPress = 0
	Ctrl.stickXf = 0
	Ctrl.stickYf = 0
	Ctrl.unk88 = 0
	Ctrl.unkA0 = 0
	Ctrl.unkAC = 0
	Ctrl.dragStartX = 0
	Ctrl.dragStartY = 0
	Ctrl.stickDeltaX = 0
	Ctrl.stickDeltaY = 0
	Ctrl.stickX = 0
	Ctrl.stickY = 0
	Ctrl.csrX = 0
	Ctrl.csrY = 0
	Ctrl.dragging = 0
	Ctrl.unkD8b40 = 0
	Ctrl.unkD8b20 = 0
	Ctrl.startedDragging = 0
	Ctrl.unkD8b08 = 0
	Ctrl.unkD8b04 = 0
	Ctrl.AbtnPressWait = 0
	Ctrl.dragStartFrame = 0
	Ctrl.currFrame = 0
	Ctrl.prevFrame = nil

	Ctrl.unk88 = 1.0
	Ctrl.unkA0 = -45.0
	Ctrl.unkAC = 45.0
	Ctrl.unk00 = 2
	Ctrl.newStartPress = IncludePRUltratypesH.FALSE
	Ctrl.prevFrame = GdMain.gGdCtrlPrev
	Ctrl.csrX = 160
	Ctrl.csrY = 120
	Ctrl.dragStartFrame = U32(-1000)
	renderer.unusedDl801BB0AC = renderer.create_mtl_gddl(4)
end

-- from src/goddard/renderer.c:reverse_string L3290-3301
function renderer.reverse_string(str: string, len: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_12 L3304-3305
function renderer.stub_renderer_12(arg0: buffer)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_13 L3308-3309
function renderer.stub_renderer_13(arg0: unknown)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_14 L3312-3313
function renderer.stub_renderer_14(arg0: buffer)
	error("stale")

	return
end

-- from src/goddard/renderer.c:init_pick_buf L3321-3327
function renderer.init_pick_buf(buf: { number }, len: number)
	buf[1] = 0
	buf[2] = 0
	renderer.sPickBufLen = len
	renderer.sPickBuf = buf
	renderer.sPickBufPosition = 0
end

-- from src/goddard/renderer.c:store_in_pickbuf L3333-3335
function renderer.store_in_pickbuf(data: number)
	data = S16(TruncS32(data))

	const Buffer = renderer.sPickBuf :: { number }

	Buffer[renderer.sPickBufPosition + 1] = data
	renderer.sPickBufPosition += 1
end

-- from src/goddard/renderer.c:get_cur_pickbuf_offset L3341-3343
function renderer.get_cur_pickbuf_offset(arg0: { number }): number
	return TruncS32(renderer.sPickBufPosition / 3)
end

-- from src/goddard/renderer.c:stub_renderer_15 L3346-3347
function renderer.stub_renderer_15(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_16 L3350-3351
function renderer.stub_renderer_16(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_17 L3354-3355
function renderer.stub_renderer_17()
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A5AB8 L3358-3360
function renderer.Unknown801A5AB8(texnum: number): unknown
	error("stale")
end

-- from src/goddard/renderer.c:Unknown801A5AE0 L3363-3369
function renderer.Unknown801A5AE0(arg0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:set_vtx_tc_buf L3372-3375
function renderer.set_vtx_tc_buf(tcS: number, tcT: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:add_debug_view L3378-3380
function renderer.add_debug_view(view: GdTypesH.ObjView)
	error("stale")

	return
end

-- from src/goddard/renderer.c:cvrt_val_to_kb L3383-3388
function renderer.cvrt_val_to_kb(dst: GdTypesH.ObjVarVal, src: GdTypesH.ObjVarVal): GdTypesH.ObjVarVal
	error("stale")
end

-- from src/goddard/renderer.c:Unknown801A5C80 L3391-3410
function renderer.Unknown801A5C80(parentGroup: GdTypesH.ObjGroup?)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A5D90 L3413-3475
function renderer.Unknown801A5D90(arg0: GdTypesH.ObjGroup)
	error("stale")

	return
end

-- from src/goddard/renderer.c:Unknown801A5FF8 L3478-3529
function renderer.Unknown801A5FF8(arg0: GdTypesH.ObjGroup)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_put_sprite L3532-3550
function renderer.gd_put_sprite(sprite: number, x: number, y: number, wx: number, wy: number)
	const Previous = Gbi.Redirect(renderer.next_gfx())

	Gbi.gSPDisplayList(renderer.gd_dl_sprite_start_tex_block)

	for Row = 0, wy - 1, 32 do
		for Column = 0, wx - 1, 32 do
			Gbi.Redirect(renderer.next_gfx())
			Gbi.gDPLoadTextureBlock(sprite + (Row * 32 + Column) * 2, Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 32, 32, 0, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), Gbi.G_TX_NOMASK, Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
			renderer.next_gfx()
			renderer.next_gfx()
			renderer.next_gfx()
			renderer.next_gfx()
			renderer.next_gfx()
			renderer.next_gfx()
			Gbi.Redirect(renderer.next_gfx())
			Gbi.gSPTextureRectangle(bit32.lshift(x, 2), bit32.lshift(y + Row, 2), bit32.lshift(x + 32, 2), bit32.lshift(y + Row + 32, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(1, 10), bit32.lshift(1, 10))
			renderer.next_gfx()
			renderer.next_gfx()
		end
	end

	Gbi.Redirect(renderer.next_gfx())
	Gbi.gDPPipeSync()
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gDPSetCycleType(Gbi.G_CYC_1CYCLE)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_INTER, Gbi.G_RM_NOOP2)
	Gbi.Redirect(renderer.next_gfx())
	Gbi.gSPTexture(0x8000, 0x8000, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
	Gbi.Redirect(Previous)
end

-- from src/goddard/renderer.c:gd_setup_cursor L3553-3582
function renderer.gd_setup_cursor(parentgrp: GdTypesH.ObjGroup?)
	const HandShape = ShapeHelper.make_shape(0, "mouse")

	renderer.sHandShape = HandShape
	HandShape.dlNums[1] = renderer.gd_startdisplist(7)
	renderer.gd_put_sprite(renderer.gd_texture_hand_open, 100, 100, 32, 32)
	renderer.gd_enddlsplist_parent()
	HandShape.dlNums[2] = renderer.gd_startdisplist(7)
	renderer.gd_put_sprite(renderer.gd_texture_hand_open, 100, 100, 32, 32)
	renderer.gd_enddlsplist_parent()

	DynlistProc.d_start_group("mouseg")
	DynlistProc.d_makeobj(DynlistProcH.D_NET, DynlistProcH.AsDynName(0))
	DynlistProc.d_set_init_pos(0.0, 0.0, 0.0)
	DynlistProc.d_set_type(3)
	DynlistProc.d_set_shapeptrptr({ Base = renderer, Key = "sHandShape" })
	DynlistProc.d_end_group("mouseg")

	const MouseGroup = DynlistProc.d_use_obj("mouseg") :: GdTypesH.ObjGroup
	const MouseView = Objects.make_view("mouseview", bit32.bor(GdTypesH.VIEW_2_COL_BUF, GdTypesH.VIEW_ALLOC_ZBUF, GdTypesH.VIEW_1_CYCLE, GdTypesH.VIEW_MOVEMENT, GdTypesH.VIEW_DRAW), 2, 0, 0, 32, 32, MouseGroup)

	MouseView.flags = bit32.band(MouseView.flags, bit32.bnot(GdTypesH.VIEW_UPDATE))
	renderer.sHandView = MouseView

	if parentgrp ~= nil then
		Objects.addto_group(parentgrp, MouseGroup.header)
	end
end

-- from src/goddard/renderer.c:view_proc_print_timers L3588-3594
function renderer.view_proc_print_timers(self: GdTypesH.ObjView)
	error("stale")

	return
end

-- from src/goddard/renderer.c:make_timer_gadgets L3597-3715
function renderer.make_timer_gadgets()
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_18 L3718-3719
function renderer.stub_renderer_18(a0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_19 L3722-3723
function renderer.stub_renderer_19(a0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:gd_block_dma L3729-3743
function renderer.gd_block_dma(romAddr: number, vAddr: unknown, size: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:load_dynlist L3748-3818
function renderer.load_dynlist(dynlist: { GdTypesH.DynList }): GdTypesH.GdObj
	return DynlistProc.proc_dynlist(dynlist)
end

-- from src/goddard/renderer.c:stub_renderer_20 L3828-3829
function renderer.stub_renderer_20(a0: number)
	error("stale")

	return
end

-- from src/goddard/renderer.c:func_801A71CC L3834-3927
function renderer.func_801A71CC(net: GdTypesH.ObjNet)
	error("stale")

	return
end

-- from src/goddard/renderer.c:stub_renderer_21 L3930-3931
function renderer.stub_renderer_21()
	error("stale")

	return
end

-- from src/goddard/renderer.c:sDynLists L216-221
renderer.sDynLists = {
	{ flag = renderer.STD_LIST_BANK, list = DynlistsDynlistTestCube.dynlist_test_cube },
	{ flag = renderer.STD_LIST_BANK, list = DynlistsDynlistUnused.dynlist_spot_shape },
	{ flag = renderer.STD_LIST_BANK, list = DynlistsDynlistMarioMaster.dynlist_mario_master },
	{ flag = renderer.TABLE_END, list = nil },
}

-- from src/goddard/renderer.c:gd_red_star_dl_array L433-450
renderer.gd_red_star_dl_array = {
	renderer.gd_dl_red_star_0,
	renderer.gd_dl_red_star_0,
	renderer.gd_dl_red_star_1,
	renderer.gd_dl_red_star_1,
	renderer.gd_dl_red_star_2,
	renderer.gd_dl_red_star_2,
	renderer.gd_dl_red_star_3,
	renderer.gd_dl_red_star_3,
	renderer.gd_dl_red_star_4,
	renderer.gd_dl_red_star_4,
	renderer.gd_dl_red_star_5,
	renderer.gd_dl_red_star_5,
	renderer.gd_dl_red_star_6,
	renderer.gd_dl_red_star_6,
	renderer.gd_dl_red_star_7,
	renderer.gd_dl_red_star_7,
}

-- from src/goddard/renderer.c:gd_silver_star_dl_array L452-469
renderer.gd_silver_star_dl_array = {
	renderer.gd_dl_silver_star_0,
	renderer.gd_dl_silver_star_0,
	renderer.gd_dl_silver_star_1,
	renderer.gd_dl_silver_star_1,
	renderer.gd_dl_silver_star_2,
	renderer.gd_dl_silver_star_2,
	renderer.gd_dl_silver_star_3,
	renderer.gd_dl_silver_star_3,
	renderer.gd_dl_silver_star_4,
	renderer.gd_dl_silver_star_4,
	renderer.gd_dl_silver_star_5,
	renderer.gd_dl_silver_star_5,
	renderer.gd_dl_silver_star_6,
	renderer.gd_dl_silver_star_6,
	renderer.gd_dl_silver_star_7,
	renderer.gd_dl_silver_star_7,
}

-- from src/goddard/renderer.c:gd_red_sparkle_dl_array L618-631
renderer.gd_red_sparkle_dl_array = {
	renderer.gd_dl_red_sparkle_4,
	renderer.gd_dl_red_sparkle_4,
	renderer.gd_dl_red_sparkle_3,
	renderer.gd_dl_red_sparkle_3,
	renderer.gd_dl_red_sparkle_2,
	renderer.gd_dl_red_sparkle_2,
	renderer.gd_dl_red_sparkle_1,
	renderer.gd_dl_red_sparkle_1,
	renderer.gd_dl_red_sparkle_0,
	renderer.gd_dl_red_sparkle_0,
	renderer.gd_dl_red_sparkle_4_dup,
	renderer.gd_dl_red_sparkle_4_dup,
}

-- from src/goddard/renderer.c:gd_silver_sparkle_dl_array L633-646
renderer.gd_silver_sparkle_dl_array = {
	renderer.gd_dl_silver_sparkle_4,
	renderer.gd_dl_silver_sparkle_4,
	renderer.gd_dl_silver_sparkle_3,
	renderer.gd_dl_silver_sparkle_3,
	renderer.gd_dl_silver_sparkle_2,
	renderer.gd_dl_silver_sparkle_2,
	renderer.gd_dl_silver_sparkle_1,
	renderer.gd_dl_silver_sparkle_1,
	renderer.gd_dl_silver_sparkle_0,
	renderer.gd_dl_silver_sparkle_0,
	renderer.gd_dl_silver_sparkle_4_dup,
	renderer.gd_dl_silver_sparkle_4_dup,
}

return renderer
