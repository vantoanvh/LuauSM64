--!strict
--!optimize 2

--[[
	The Fast3D ("f3d_old", the US build) display list encoding the decoder reads: opcodes, geometry mode bits, other mode fields,
	render mode bits, tile and combiner constants. Values are those of reference/include/PR/gbi.h.

	Design Notes
		LayerRenderModes holds the G_RM_* words rendering_graph_node.c puts in renderModeTable_1Cycle, one per layer (the port's
		tables hold placeholders, the master list is rendered by the renderer).
]]

const Gbi = {
	Opcode = {
		Mtx = 0x01,
		MoveMem = 0x03,
		Vtx = 0x04,
		Dl = 0x06,
		Tri1 = 0xBF,
		CullDl = 0xBE,
		PopMtx = 0xBD,
		MoveWord = 0xBC,
		Texture = 0xBB,
		SetOtherModeH = 0xBA,
		SetOtherModeL = 0xB9,
		EndDl = 0xB8,
		SetGeometryMode = 0xB7,
		ClearGeometryMode = 0xB6,
		TexRectFlip = 0xE5,
		TexRect = 0xE4,
		SetCombine = 0xFC,
		SetEnvColor = 0xFB,
		SetPrimColor = 0xFA,
		SetBlendColor = 0xF9,
		SetFogColor = 0xF8,
		SetFillColor = 0xF7,
		FillRect = 0xF6,
		SetTile = 0xF5,
		LoadTile = 0xF4,
		LoadBlock = 0xF3,
		SetTileSize = 0xF2,
		LoadTlut = 0xF0,
		SetTextureImage = 0xFD,
		SetColorImage = 0xFF,
		SetDepthImage = 0xFE,
		SetScissor = 0xED,
		RdpFullSync = 0xE9,
		RdpTileSync = 0xE8,
		RdpPipeSync = 0xE7,
		RdpLoadSync = 0xE6,
		RdpHalf1 = 0xB4,
		RdpHalf2 = 0xB3,
		RdpHalfCont = 0xB2,
	},

	-- G_MTX parameter bits
	MtxProjection = 0x01,
	MtxLoad = 0x02,
	MtxPush = 0x04,

	-- G_MOVEMEM indices; the lights are G_MV_L0 + 2 * n
	MoveMemViewport = 0x80,
	MoveMemLight0 = 0x86,

	-- G_MOVEWORD indices
	MoveWordNumLight = 0x02,
	MoveWordSegment = 0x06,
	MoveWordFog = 0x08,

	-- Geometry mode bits
	ZBuffer = 0x00000001,
	CullFront = 0x00001000,
	CullBack = 0x00002000,
	Fog = 0x00010000,
	Lighting = 0x00020000,
	TextureGen = 0x00040000,

	-- Other mode high word fields (bit shift, width mask)
	TextureFilterShift = 12,
	TextureLutShift = 14,
	TexturePerspBit = 0x80000,
	CycleTypeShift = 20,
	CycleTwo = 1,
	CycleCopy = 2,
	CycleFill = 3,

	-- Texture formats and sizes
	FmtRgba = 0,
	FmtYuv = 1,
	FmtCi = 2,
	FmtIa = 3,
	FmtI = 4,
	Siz4b = 0,
	Siz8b = 1,
	Siz16b = 2,
	Siz32b = 3,

	-- Render mode bits (other mode low word)
	ZCompare = 0x10,
	ZUpdate = 0x20,
	ZModeShift = 10,
	ZModeDecal = 3,
	CoverageTimesAlpha = 0x1000,
	ForceBlend = 0x4000,
	-- The first cycle blender input color selecting the fog color (G_BL_CLR_FOG)
	BlendFogColor = 3,

	-- Color combiner inputs (G_CCMUX_*)
	CcCombined = 0,
	CcTexel0 = 1,
	CcTexel1 = 2,
	CcPrimitive = 3,
	CcShade = 4,
	CcEnvironment = 5,
	CcOne = 6,
	CcCombinedAlpha = 7,
	CcTexel0Alpha = 8,
	CcTexel1Alpha = 9,
	CcPrimitiveAlpha = 10,
	CcShadeAlpha = 11,
	CcEnvAlpha = 12,
	CcLodFraction = 13,
	CcPrimLodFraction = 14,

	-- The master list layers (GFX_NUM_MASTER_LISTS)
	LayerCount = 8,
}

-- GBL_c1 and GBL_c2: the blender selects of the first and the second cycle of a render mode
const function Blender(M1A: number, M1B: number, M2A: number, M2B: number): number
	return bit32.lshift(M1A, 30) + bit32.lshift(M1B, 26) + bit32.lshift(M2A, 22) + bit32.lshift(M2B, 18)
end

-- The G_RM_* modes of renderModeTable_1Cycle: [1] without and [2] with the z-buffer, 8 layers each
const AaEn = 0x8
const ImRd = 0x40
const ClrOnCvg = 0x80
const CvgDstClamp = 0
const CvgDstWrap = 0x100
const ZModeInter = 0x400
const ZModeXlu = 0x800
const ZModeDec = 0xC00
const AlphaCvgSel = 0x2000
const OpaqueBlender = Blender(0, 0, 1, 1)
const XluBlender = Blender(0, 0, 1, 0)
const Zb = Gbi.ZCompare
const Zu = Gbi.ZUpdate
const Cx = Gbi.CoverageTimesAlpha
const Fb = Gbi.ForceBlend

const AaOpaSurf = AaEn + ImRd + CvgDstClamp + AlphaCvgSel + OpaqueBlender
const AaXluSurf = AaEn + ImRd + CvgDstWrap + ClrOnCvg + Fb + XluBlender
const AaTexEdge = AaEn + ImRd + CvgDstClamp + Cx + AlphaCvgSel + OpaqueBlender
const AaZbOpaSurf = AaOpaSurf + Zb + Zu
const AaZbOpaDecal = AaEn + Zb + ImRd + CvgDstWrap + AlphaCvgSel + ZModeDec + OpaqueBlender
const AaZbOpaInter = AaOpaSurf + Zb + Zu + ZModeInter
const AaZbTexEdge = AaTexEdge + Zb + Zu
const AaZbXluSurf = AaEn + Zb + ImRd + CvgDstWrap + ClrOnCvg + Fb + ZModeXlu + XluBlender
const AaZbXluDecal = AaEn + Zb + ImRd + CvgDstWrap + ClrOnCvg + Fb + ZModeDec + XluBlender
const AaZbXluInter = AaEn + Zb + ImRd + CvgDstWrap + ClrOnCvg + Fb + ZModeInter + XluBlender

Gbi.LayerRenderModes = {
	{
		CvgDstClamp + Fb + Blender(0, 3, 0, 2),
		AaOpaSurf,
		AaOpaSurf,
		AaOpaSurf,
		AaTexEdge,
		AaXluSurf,
		AaXluSurf,
		AaXluSurf,
	},
	{
		Zb + Zu + 0x200 + AlphaCvgSel + OpaqueBlender,
		AaZbOpaSurf,
		AaZbOpaDecal,
		AaZbOpaInter,
		AaZbTexEdge,
		AaZbXluSurf,
		AaZbXluDecal,
		AaZbXluInter,
	},
}

return Gbi
