--!strict
--!optimize 2

--[[
	The Fast3D display list writer: the gSP*, gDP* and gu* macros of include/PR/gbi.h (the F3D_OLD encoding of the US build) write
	8 byte commands into the Gfx pool of Rom.Memory, and the renderer runs the list the game built (render/display_list.luau).

	Paradigm
		The C passes the next command as the first argument (`gSPDisplayList(gDisplayListHead++, dl)`); here the pool owns that
		cursor: Head is gDisplayListHead, every macro writes at it and advances it by the commands it wrote (three for
		gSPTextureRectangle, which the C advances by evaluating `gDisplayListHead++` three times in the macro). The macros keep the
		name and the argument order of the C without the packet. Matrices are Mtx blocks of the pool (alloc_display_list takes them from
		its end, as the C does) that guTranslate, guScale, guRotate and guOrtho fill with the fixed point words of guMtxF2L.
		Commands are written big endian, as a list in the ROM is, so the renderer reads both alike. The other structures a command
		points to (Vtx, Mtx, Vp, Light, Lights4, LookAt, Hilite) are blocks of Memory too, in the layout of the N64 with big endian
		words; the SIZEOF_* constants are their sizes (a Gfx is 8 bytes, the two words of a command).

	Owned State
		Head and End: the command cursor and the lowest address allocated from the end of the pool. The game resets them every frame
		(select_gfx_pool); a frame that needs more than the pool of the N64 (GFX_POOL_SIZE commands) fails as the native build does.

	Design Notes
		G_* constants have the values of the F3D_OLD branch of gbi.h (other modes are shifted to their place in the word, as there).
		The addresses a command carries are the ones the C writes: a segmented address of a ROM list or texture, or the Memory address
		of a list or matrix of the pool (segment 0).
		The gu* matrix functions compute in f32 as the C does (each operation rounded; sinf and cosf as the double result rounded to
		f32, the way native/goddard/README.md replaces them) and end in guMtxF2L, whose float to s32 conversion gives INT_MIN outside
		the s32 range, as the x86-64 build and its oracle do.
]]

const Rom = require("./rom")
const Symbols = require("./symbols")

const Gbi = {
	Head = Symbols.GfxPool,
	End = Symbols.GfxPool + Symbols.GfxPoolSize,
	Target = nil :: number?,
}

-- from include/PR/gbi.h:data
Gbi.G_IM_FMT_RGBA = 0
Gbi.G_IM_FMT_YUV = 1
Gbi.G_IM_FMT_CI = 2
Gbi.G_IM_FMT_IA = 3
Gbi.G_IM_FMT_I = 4
Gbi.G_IM_SIZ_4b = 0
Gbi.G_IM_SIZ_8b = 1
Gbi.G_IM_SIZ_16b = 2
Gbi.G_IM_SIZ_32b = 3
Gbi.G_IM_SIZ_4b_BYTES = 0
Gbi.G_IM_SIZ_8b_BYTES = 1
Gbi.G_IM_SIZ_16b_BYTES = 2
Gbi.G_IM_SIZ_32b_BYTES = 4
Gbi.G_TX_RENDERTILE = 0
Gbi.G_TX_LOADTILE = 7
Gbi.G_TX_WRAP = 0
Gbi.G_TX_NOMIRROR = 0
Gbi.G_TX_MIRROR = 1
Gbi.G_TX_CLAMP = 2
Gbi.G_TX_NOMASK = 0
Gbi.G_TX_NOLOD = 0
Gbi.G_TX_DXT_FRAC = 11
Gbi.G_TX_LDBLK_MAX_TXL = 4095
Gbi.G_TEXTURE_IMAGE_FRAC = 2
Gbi.G_MTX_MODELVIEW = 0x00
Gbi.G_MTX_PROJECTION = 0x01
Gbi.G_MTX_MUL = 0x00
Gbi.G_MTX_LOAD = 0x02
Gbi.G_MTX_NOPUSH = 0x00
Gbi.G_MTX_PUSH = 0x04
Gbi.G_SC_NON_INTERLACE = 0
Gbi.G_ON = 1
Gbi.G_OFF = 0
Gbi.G_ZBUFFER = 0x00000001
Gbi.G_SHADE = 0x00000004
Gbi.G_CULL_FRONT = 0x00001000
Gbi.G_CULL_BACK = 0x00002000
Gbi.G_FOG = 0x00010000
Gbi.G_LIGHTING = 0x00020000
Gbi.G_TEXTURE_GEN = 0x00040000
Gbi.G_TEXTURE_GEN_LINEAR = 0x00080000
Gbi.G_CYC_1CYCLE = 0
Gbi.G_CYC_2CYCLE = bit32.lshift(1, 20)
Gbi.G_CYC_COPY = bit32.lshift(2, 20)
Gbi.G_CYC_FILL = bit32.lshift(3, 20)
Gbi.G_TP_NONE = 0
Gbi.G_TP_PERSP = bit32.lshift(1, 19)
Gbi.G_TF_POINT = 0
Gbi.G_TF_BILERP = bit32.lshift(2, 12)
Gbi.G_AC_NONE = 0
Gbi.G_AC_THRESHOLD = 1
Gbi.G_AC_DITHER = 3
-- The render modes of the display lists the game writes itself (RM_TEX_EDGE and RM_AA_ZB_OPA_SURF of the first and the second cycle)
Gbi.G_RM_TEX_EDGE = bit32.bor(0x1000, 0x2000, 0x4000, 0x8, bit32.lshift(3, 26), bit32.lshift(2, 18))
Gbi.G_RM_TEX_EDGE2 = bit32.bor(0x1000, 0x2000, 0x4000, 0x8, bit32.lshift(3, 24), bit32.lshift(2, 16))
Gbi.G_RM_AA_ZB_OPA_SURF = bit32.bor(0x8, 0x10, 0x20, 0x40, 0x2000, bit32.lshift(1, 22), bit32.lshift(1, 18))
Gbi.G_RM_AA_ZB_OPA_SURF2 = bit32.bor(0x8, 0x10, 0x20, 0x40, 0x2000, bit32.lshift(1, 20), bit32.lshift(1, 16))
-- The other render modes of the rendering setup and the 2D lists (RM_OPA_SURF, RM_AA_OPA_SURF and RM_AA_XLU_SURF of the first and the second cycle)
Gbi.G_RM_OPA_SURF = bit32.bor(0x4000, bit32.lshift(3, 26), bit32.lshift(2, 18))
Gbi.G_RM_OPA_SURF2 = bit32.bor(0x4000, bit32.lshift(3, 24), bit32.lshift(2, 16))
Gbi.G_RM_AA_OPA_SURF = bit32.bor(0x8, 0x40, 0x2000, bit32.lshift(1, 22), bit32.lshift(1, 18))
Gbi.G_RM_AA_OPA_SURF2 = bit32.bor(0x8, 0x40, 0x2000, bit32.lshift(1, 20), bit32.lshift(1, 16))
Gbi.G_RM_AA_XLU_SURF = bit32.bor(0x8, 0x40, 0x100, 0x80, 0x4000, bit32.lshift(1, 22))
Gbi.G_RM_AA_XLU_SURF2 = bit32.bor(0x8, 0x40, 0x100, 0x80, 0x4000, bit32.lshift(1, 20))
-- The render modes of the Goddard views and textured quads (RM_AA_ZB_OPA_INTER, RM_AA_ZB_XLU_SURF and RM_AA_ZB_TEX_EDGE of the first
-- and the second cycle; G_RM_NOOP2 is RM_NOOP(2), no bits)
Gbi.G_RM_AA_ZB_OPA_INTER = bit32.bor(0x8, 0x10, 0x20, 0x40, 0x2000, 0x400, bit32.lshift(1, 22), bit32.lshift(1, 18))
Gbi.G_RM_AA_ZB_XLU_SURF = bit32.bor(0x8, 0x10, 0x40, 0x100, 0x80, 0x4000, 0x800, bit32.lshift(1, 22))
Gbi.G_RM_AA_ZB_XLU_SURF2 = bit32.bor(0x8, 0x10, 0x40, 0x100, 0x80, 0x4000, 0x800, bit32.lshift(1, 20))
Gbi.G_RM_AA_ZB_TEX_EDGE = bit32.bor(0x8, 0x10, 0x20, 0x40, 0x1000, 0x2000, bit32.lshift(1, 22), bit32.lshift(1, 18))
Gbi.G_RM_NOOP2 = 0
-- The color combiner modes, as the inputs of (A - B) * C + D for the color then for the alpha (a b c d Aa Ab Ac Ad), with the G_CCMUX_*
-- and G_ACMUX_* values the C pastes for the names (0 is G_CCMUX_0 = 31 for the color and G_ACMUX_0 = 7 for the alpha, SHADE 4, TEXEL0 1)
Gbi.G_CC_SHADE = { 31, 31, 31, 4, 7, 7, 7, 4 }
Gbi.G_CC_MODULATEIDECALA = { 1, 31, 4, 31, 7, 7, 7, 1 }
Gbi.G_CC_DECALRGBA = { 31, 31, 31, 1, 7, 7, 7, 1 }
Gbi.G_CC_MODULATERGBA_PRIM = { 1, 31, 3, 31, 1, 7, 3, 7 }
Gbi.G_CC_HILITERGBA = { 3, 4, 1, 4, 3, 4, 1, 4 }
Gbi.G_SHADING_SMOOTH = 0x00000200
Gbi.G_CULL_BOTH = 0x00003000
Gbi.G_LOD = 0x00100000
Gbi.NUMLIGHTS_1 = 1
Gbi.NUMLIGHTS_2 = 2
Gbi.LIGHT_1 = 1
Gbi.LIGHT_2 = 2
Gbi.G_PM_1PRIMITIVE = bit32.lshift(1, 23)
Gbi.G_TL_TILE = 0
Gbi.G_TT_NONE = 0
Gbi.G_TD_CLAMP = 0
Gbi.G_TC_FILT = bit32.lshift(6, 9)
Gbi.G_CK_NONE = 0
Gbi.G_CD_MAGICSQ = 0
Gbi.G_ZS_PIXEL = 0
Gbi.G_MAXFBZ = 0x3FFF
-- The sizes of the structures a command points to: a Light is 16 bytes (col, colc and dir with their padding), Lights4 an 8 byte
-- ambient light and four lights, LookAt two lights, Hilite four s32 (x1, y1, x2, y2), Mtx the integer and the fraction half
Gbi.SIZEOF_GFX = 8
Gbi.SIZEOF_VTX = 16
Gbi.SIZEOF_MTX = 64
Gbi.SIZEOF_VP = 16
Gbi.SIZEOF_LIGHT = 16
Gbi.SIZEOF_LIGHTS4 = 72
Gbi.SIZEOF_LOOKAT = 32
Gbi.SIZEOF_HILITE = 16
-- The G_MOVEMEM indices of the viewport, the two look at vectors and the first light (F3D_OLD)
Gbi.G_MV_VIEWPORT = 0x80
Gbi.G_MV_LOOKATY = 0x82
Gbi.G_MV_LOOKATX = 0x84
Gbi.G_MV_L0 = 0x86
Gbi.G_DL_NOPUSH = 1

-- The opcodes of the F3D_OLD microcode; the renderer reads them (render/gbi.luau)
const Opcode = {
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
	RdpHalf1 = 0xB4,
	RdpHalf2 = 0xB3,
	RdpHalfCont = 0xB2,
	TexRectFlip = 0xE5,
	TexRect = 0xE4,
	RdpLoadSync = 0xE6,
	RdpPipeSync = 0xE7,
	RdpTileSync = 0xE8,
	RdpFullSync = 0xE9,
	SetScissor = 0xED,
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
	SetDepthImage = 0xFE,
	SetColorImage = 0xFF,
}

Gbi.Opcode = Opcode

-- Writes one command at the cursor (the main list, or the list a callback redirected it to) and advances it
const function Write(Word0: number, Word1: number)
	const Target = Gbi.Target

	if Target == nil then
		if Gbi.Head + 8 > Gbi.End then
			error("out of display list memory")
		end

		Rom.WriteU32(Gbi.Head, Word0)
		Rom.WriteU32(Gbi.Head + 4, Word1)
		Gbi.Head += 8
	else
		Rom.WriteU32(Target, Word0)
		Rom.WriteU32(Target + 4, Word1)
		Gbi.Target = Target + 8
	end
end

-- G_SETOTHERMODE_L/H: Length bits at Shift of the mode word are Data
const function SetOtherMode(Command: number, Shift: number, Length: number, Data: number)
	Write(bit32.bor(bit32.lshift(Command, 24), bit32.lshift(Shift, 8), Length), Data)
end

-- The words of a command whose second word is a color
const function WriteColor(Command: number, R: number, G: number, B: number, A: number)
	Write(bit32.lshift(Command, 24), bit32.bor(bit32.lshift(bit32.band(R, 0xFF), 24), bit32.lshift(bit32.band(G, 0xFF), 16), bit32.lshift(bit32.band(B, 0xFF), 8), bit32.band(A, 0xFF)))
end

-- The float matrix the gu* functions build before guMtxF2L converts it, Matrix[row][column] 1-based (they run one after the other)
const Matrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }

-- A C float: the double rounded to f32, as the C rounds every operation on floats
const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range (or NaN) gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- GU_PI / 180.0f stored in the f32 `pi_180` of guRotateF
const PiOver180 = F32(3.1415926 / 180.0)

-- guMtxIdentF into Matrix
const function IdentityF()
	for Row = 1, 4 do
		const Values = Matrix[Row]

		for Column = 1, 4 do
			Values[Column] = if Row == Column then 1 else 0
		end
	end
end

-- `m[row][col] *= scale` of guOrthoF and guPerspectiveF
const function ScaleF(Scale: number)
	for Row = 1, 4 do
		const Values = Matrix[Row]

		for Column = 1, 4 do
			Values[Column] = F32(Values[Column] * Scale)
		end
	end
end

-- _SHIFTL: the low Width bits of Value at Shift
const function ShiftLeft(Value: number, Shift: number, Width: number): number
	return bit32.lshift(bit32.band(Value, bit32.lshift(1, Width) - 1), Shift)
end

-- The texel size dependent values of gDPLoadTextureBlock, indexed by G_IM_SIZ_* + 1 (siz##_LOAD_BLOCK, _INCR, _SHIFT, _BYTES, _LINE_BYTES)
const LoadBlockSize = { 2, 2, 2, 3 }
const LoadBlockIncrement = { 3, 1, 0, 0 }
const LoadBlockShift = { 2, 1, 0, 0 }
const TexelBytes = { 0, 1, 2, 4 }
const LineBytes = { 0, 1, 2, 2 }

-- Starts a frame's list: the pool is empty
function Gbi.Reset()
	Gbi.Head = Symbols.GfxPool
	Gbi.End = Symbols.GfxPool + Symbols.GfxPoolSize
	Gbi.Target = nil
end

-- Points the writer at Target, a block of alloc_display_list, so that the macros fill that list as the C does through a local
-- `dlIter` (nil: the main list again); returns the target it replaced, which Redirect restores once the list is written. The
-- main cursor Head stays where it is, so a list may be built while another one is, as intro_geo.c does.
function Gbi.Redirect(Target: number?): number?
	const Previous = Gbi.Target

	Gbi.Target = Target

	return Previous
end

-- from src/game/memory.c:alloc_display_list L535-545 (a Memory block of the pool, taken from its end; nil when the pool is full)
function Gbi.alloc_display_list(Size: number): number?
	const Block = Gbi.End - bit32.band(Size + 7, 0xFFFFFFF8)

	if Block < Gbi.Head then
		return nil
	end

	Gbi.End = Block

	return Block
end

-- from include/PR/gbi.h:CALC_DXT
function Gbi.CALC_DXT(Width: number, BytesPerTexel: number): number
	const BytesPerLine = Width * BytesPerTexel // 8

	return (bit32.lshift(1, Gbi.G_TX_DXT_FRAC) + BytesPerLine - 1) // BytesPerLine
end

-- from include/PR/gbi.h:gSPDisplayList
function Gbi.gSPDisplayList(Dl: number)
	Write(bit32.lshift(Opcode.Dl, 24), Dl)
end

-- from include/PR/gbi.h:gSPBranchList (a G_DL that does not push: the list ends with the branched one)
function Gbi.gSPBranchList(Dl: number)
	Write(bit32.bor(bit32.lshift(Opcode.Dl, 24), bit32.lshift(Gbi.G_DL_NOPUSH, 16)), Dl)
end

-- from include/PR/gbi.h:gSPEndDisplayList
function Gbi.gSPEndDisplayList()
	Write(bit32.lshift(Opcode.EndDl, 24), 0)
end

-- from include/PR/gbi.h:gSPMatrix (Mtx is the Memory address of the matrix)
function Gbi.gSPMatrix(Mtx: number, Flags: number)
	Write(bit32.bor(bit32.lshift(Opcode.Mtx, 24), bit32.lshift(Flags, 16), 64), Mtx)
end

-- from include/PR/gbi.h:gSPPopMatrix
function Gbi.gSPPopMatrix(Which: number)
	Write(bit32.lshift(Opcode.PopMtx, 24), Which)
end

-- from include/PR/gbi.h:gSPPerspNormalize
function Gbi.gSPPerspNormalize(Scale: number)
	Write(bit32.lshift(Opcode.RdpHalf1, 24), Scale)
end

-- from include/PR/gbi.h:gSPSetGeometryMode
function Gbi.gSPSetGeometryMode(Bits: number)
	Write(bit32.lshift(Opcode.SetGeometryMode, 24), Bits)
end

-- from include/PR/gbi.h:gSPClearGeometryMode
function Gbi.gSPClearGeometryMode(Bits: number)
	Write(bit32.lshift(Opcode.ClearGeometryMode, 24), Bits)
end

-- from include/PR/gbi.h:gSPTexture
function Gbi.gSPTexture(S: number, T: number, Level: number, Tile: number, On: number)
	Write(bit32.bor(bit32.lshift(Opcode.Texture, 24), bit32.lshift(Level, 11), bit32.lshift(Tile, 8), On), bit32.bor(bit32.lshift(S, 16), bit32.band(T, 0xFFFF)))
end

-- from include/PR/gbi.h:gSP1Triangle
function Gbi.gSP1Triangle(V0: number, V1: number, V2: number, Flag: number)
	Write(bit32.lshift(Opcode.Tri1, 24), bit32.bor(bit32.lshift(Flag, 24), bit32.lshift(V0 * 10, 16), bit32.lshift(V1 * 10, 8), V2 * 10))
end

-- from include/PR/gbi.h:gSPTextureRectangle (the rectangle and the texture coordinates, then the two half commands the RDP reads)
function Gbi.gSPTextureRectangle(Xl: number, Yl: number, Xh: number, Yh: number, Tile: number, S: number, T: number, Dsdx: number, Dtdy: number)
	Write(bit32.bor(bit32.lshift(Opcode.TexRect, 24), bit32.lshift(bit32.band(Xh, 0xFFF), 12), bit32.band(Yh, 0xFFF)), bit32.bor(bit32.lshift(Tile, 24), bit32.lshift(bit32.band(Xl, 0xFFF), 12), bit32.band(Yl, 0xFFF)))
	Write(bit32.lshift(Opcode.RdpHalf2, 24), bit32.bor(bit32.lshift(bit32.band(S, 0xFFFF), 16), bit32.band(T, 0xFFFF)))
	Write(bit32.lshift(Opcode.RdpHalfCont, 24), bit32.bor(bit32.lshift(bit32.band(Dsdx, 0xFFFF), 16), bit32.band(Dtdy, 0xFFFF)))
end

-- from include/PR/gbi.h:gSPTextureRectangleFlip
function Gbi.gSPTextureRectangleFlip(Xl: number, Yl: number, Xh: number, Yh: number, Tile: number, S: number, T: number, Dsdx: number, Dtdy: number)
	Write(bit32.bor(bit32.lshift(Opcode.TexRectFlip, 24), bit32.lshift(bit32.band(Xh, 0xFFF), 12), bit32.band(Yh, 0xFFF)), bit32.bor(bit32.lshift(Tile, 24), bit32.lshift(bit32.band(Xl, 0xFFF), 12), bit32.band(Yl, 0xFFF)))
	Write(bit32.lshift(Opcode.RdpHalf2, 24), bit32.bor(bit32.lshift(bit32.band(S, 0xFFFF), 16), bit32.band(T, 0xFFFF)))
	Write(bit32.lshift(Opcode.RdpHalfCont, 24), bit32.bor(bit32.lshift(bit32.band(Dsdx, 0xFFFF), 16), bit32.band(Dtdy, 0xFFFF)))
end

-- from include/PR/gbi.h:gDPPipeSync
function Gbi.gDPPipeSync()
	Write(bit32.lshift(Opcode.RdpPipeSync, 24), 0)
end

-- from include/PR/gbi.h:gDPTileSync
function Gbi.gDPTileSync()
	Write(bit32.lshift(Opcode.RdpTileSync, 24), 0)
end

-- from include/PR/gbi.h:gDPLoadSync
function Gbi.gDPLoadSync()
	Write(bit32.lshift(Opcode.RdpLoadSync, 24), 0)
end

-- from include/PR/gbi.h:gDPFullSync
function Gbi.gDPFullSync()
	Write(bit32.lshift(Opcode.RdpFullSync, 24), 0)
end

-- from include/PR/gbi.h:gDPSetEnvColor
function Gbi.gDPSetEnvColor(R: number, G: number, B: number, A: number)
	WriteColor(Opcode.SetEnvColor, R, G, B, A)
end

-- from include/PR/gbi.h:gDPSetBlendColor
function Gbi.gDPSetBlendColor(R: number, G: number, B: number, A: number)
	WriteColor(Opcode.SetBlendColor, R, G, B, A)
end

-- from include/PR/gbi.h:gDPSetPrimColor
function Gbi.gDPSetPrimColor(MinLevel: number, LodFraction: number, R: number, G: number, B: number, A: number)
	Write(bit32.bor(bit32.lshift(Opcode.SetPrimColor, 24), bit32.lshift(MinLevel, 8), LodFraction), bit32.bor(bit32.lshift(bit32.band(R, 0xFF), 24), bit32.lshift(bit32.band(G, 0xFF), 16), bit32.lshift(bit32.band(B, 0xFF), 8), bit32.band(A, 0xFF)))
end

-- from include/PR/gbi.h:gDPSetScissor (the corners are in pixels, the command holds them in 10.2 fixed point)
function Gbi.gDPSetScissor(Mode: number, Ulx: number, Uly: number, Lrx: number, Lry: number)
	Write(bit32.bor(bit32.lshift(Opcode.SetScissor, 24), bit32.lshift(bit32.band(Ulx * 4, 0xFFF), 12), bit32.band(Uly * 4, 0xFFF)), bit32.bor(bit32.lshift(bit32.band(Mode, 3), 24), bit32.lshift(bit32.band(Lrx * 4, 0xFFF), 12), bit32.band(Lry * 4, 0xFFF)))
end

-- from include/PR/gbi.h:gDPSetTextureImage
function Gbi.gDPSetTextureImage(Format: number, Size: number, Width: number, Image: number)
	Write(bit32.bor(bit32.lshift(Opcode.SetTextureImage, 24), bit32.lshift(Format, 21), bit32.lshift(Size, 19), Width - 1), Image)
end

-- from include/PR/gbi.h:gDPSetTile
function Gbi.gDPSetTile(Format: number, Size: number, Line: number, Tmem: number, Tile: number, Palette: number, Cmt: number, Maskt: number, Shiftt: number, Cms: number, Masks: number, Shifts: number)
	Write(
		bit32.bor(bit32.lshift(Opcode.SetTile, 24), bit32.lshift(Format, 21), bit32.lshift(Size, 19), bit32.lshift(Line, 9), Tmem),
		bit32.bor(bit32.lshift(Tile, 24), bit32.lshift(Palette, 20), bit32.lshift(Cmt, 18), bit32.lshift(Maskt, 14), bit32.lshift(Shiftt, 10), bit32.lshift(Cms, 8), bit32.lshift(Masks, 4), Shifts)
	)
end

-- from include/PR/gbi.h:gDPSetTileSize
function Gbi.gDPSetTileSize(Tile: number, Uls: number, Ult: number, Lrs: number, Lrt: number)
	Write(bit32.bor(bit32.lshift(Opcode.SetTileSize, 24), ShiftLeft(Uls, 12, 12), ShiftLeft(Ult, 0, 12)), bit32.bor(ShiftLeft(Tile, 24, 3), ShiftLeft(Lrs, 12, 12), ShiftLeft(Lrt, 0, 12)))
end

-- from include/PR/gbi.h:gDPSetHilite1Tile (Hilite is the Memory address of the Hilite: x1 at +0 and y1 at +4, big endian s32)
function Gbi.gDPSetHilite1Tile(Tile: number, Hilite: number, Width: number, Height: number)
	const X1 = Rom.ReadS32(Hilite)
	const Y1 = Rom.ReadS32(Hilite + 4)

	Gbi.gDPSetTileSize(Tile, bit32.band(X1, 0xFFF), bit32.band(Y1, 0xFFF), bit32.band((Width - 1) * 4 + X1, 0xFFF), bit32.band((Height - 1) * 4 + Y1, 0xFFF))
end

-- from include/PR/gbi.h:gDPLoadBlock
function Gbi.gDPLoadBlock(Tile: number, Uls: number, Ult: number, Lrs: number, Dxt: number)
	Write(bit32.bor(bit32.lshift(Opcode.LoadBlock, 24), bit32.lshift(Uls, 12), Ult), bit32.bor(bit32.lshift(Tile, 24), bit32.lshift(math.min(Lrs, Gbi.G_TX_LDBLK_MAX_TXL), 12), Dxt))
end

-- from include/PR/gbi.h:gDPSetCycleType
function Gbi.gDPSetCycleType(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 20, 2, Type)
end

-- from include/PR/gbi.h:gDPSetTexturePersp
function Gbi.gDPSetTexturePersp(Persp: number)
	SetOtherMode(Opcode.SetOtherModeH, 19, 1, Persp)
end

-- from include/PR/gbi.h:gDPSetTextureFilter
function Gbi.gDPSetTextureFilter(Filter: number)
	SetOtherMode(Opcode.SetOtherModeH, 12, 2, Filter)
end

-- from include/PR/gbi.h:gDPSetAlphaCompare
function Gbi.gDPSetAlphaCompare(Compare: number)
	SetOtherMode(Opcode.SetOtherModeL, 0, 2, Compare)
end

-- from include/PR/gbi.h:gDPSetRenderMode (Cycle1 and Cycle2 are the words of the two cycles)
function Gbi.gDPSetRenderMode(Cycle1: number, Cycle2: number)
	SetOtherMode(Opcode.SetOtherModeL, 3, 29, bit32.bor(Cycle1, Cycle2))
end

-- from lib/src/guTranslateF.c:guTranslate
function Gbi.guTranslate(Mtx: number, X: number, Y: number, Z: number)
	IdentityF()
	Matrix[4][1] = F32(X)
	Matrix[4][2] = F32(Y)
	Matrix[4][3] = F32(Z)
	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from lib/src/guScaleF.c:guScale
function Gbi.guScale(Mtx: number, X: number, Y: number, Z: number)
	IdentityF()
	Matrix[1][1] = F32(X)
	Matrix[2][2] = F32(Y)
	Matrix[3][3] = F32(Z)
	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from lib/src/guRotateF.c:guRotate (an angle in degrees around the axis X Y Z; guNormalize of the axis first)
function Gbi.guRotate(Mtx: number, Angle: number, X: number, Y: number, Z: number)
	const Scale = F32(1 / F32(math.sqrt(F32(F32(F32(F32(X) * F32(X)) + F32(F32(Y) * F32(Y))) + F32(F32(Z) * F32(Z))))))
	const Nx = F32(F32(X) * Scale)
	const Ny = F32(F32(Y) * Scale)
	const Nz = F32(F32(Z) * Scale)
	const Radians = F32(F32(Angle) * PiOver180)
	const SinA = F32(math.sin(Radians))
	const CosA = F32(math.cos(Radians))
	const T = F32(1 - CosA)
	const Ab = F32(F32(Nx * Ny) * T)
	const Bc = F32(F32(Ny * Nz) * T)
	const Ca = F32(F32(Nz * Nx) * T)
	const Xx = F32(Nx * Nx)
	const Yy = F32(Ny * Ny)
	const Zz = F32(Nz * Nz)
	const XSin = F32(Nx * SinA)
	const YSin = F32(Ny * SinA)
	const ZSin = F32(Nz * SinA)

	IdentityF()
	Matrix[1][1] = F32(Xx + F32(CosA * F32(1 - Xx)))
	Matrix[3][2] = F32(Bc - XSin)
	Matrix[2][3] = F32(Bc + XSin)
	Matrix[2][2] = F32(Yy + F32(CosA * F32(1 - Yy)))
	Matrix[3][1] = F32(Ca + YSin)
	Matrix[1][3] = F32(Ca - YSin)
	Matrix[3][3] = F32(Zz + F32(CosA * F32(1 - Zz)))
	Matrix[2][1] = F32(Ab - ZSin)
	Matrix[1][2] = F32(Ab + ZSin)
	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from lib/src/guOrthoF.c:guOrtho
function Gbi.guOrtho(Mtx: number, Left: number, Right: number, Bottom: number, Top: number, Near: number, Far: number, Scale: number)
	const Width = F32(F32(Right) - F32(Left))
	const Height = F32(F32(Top) - F32(Bottom))
	const Depth = F32(F32(Far) - F32(Near))

	IdentityF()
	Matrix[1][1] = F32(2 / Width)
	Matrix[2][2] = F32(2 / Height)
	Matrix[3][3] = F32(-2 / Depth)
	Matrix[4][1] = F32(-F32(F32(Right) + F32(Left)) / Width)
	Matrix[4][2] = F32(-F32(F32(Top) + F32(Bottom)) / Height)
	Matrix[4][3] = F32(-F32(F32(Far) + F32(Near)) / Depth)
	Matrix[4][4] = 1
	ScaleF(F32(Scale))
	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from lib/src/guPerspectiveF.c:guPerspective (PerspNorm is the one element table of the u16 the C writes through a pointer, or nil)
function Gbi.guPerspective(Mtx: number, PerspNorm: { number }?, Fovy: number, Aspect: number, Near: number, Far: number, Scale: number)
	const Angle = F32(F32(Fovy) * (3.1415926 / 180.0))
	const Half = F32(Angle / 2)
	const Yscale = F32(F32(math.cos(Half)) / F32(math.sin(Half)))
	const Sum = F32(F32(Near) + F32(Far))
	const Difference = F32(F32(Near) - F32(Far))

	IdentityF()
	Matrix[1][1] = F32(Yscale / F32(Aspect))
	Matrix[2][2] = Yscale
	Matrix[3][3] = F32(Sum / Difference)
	Matrix[3][4] = -1
	Matrix[4][3] = F32(F32(F32(2 * F32(Near)) * F32(Far)) / Difference)
	Matrix[4][4] = 0
	ScaleF(F32(Scale))

	if PerspNorm ~= nil then
		if Sum <= 2.0 then
			PerspNorm[1] = 65535
		else
			PerspNorm[1] = bit32.band(TruncS32(131072 / Sum), 0xFFFF)

			if PerspNorm[1] <= 0 then
				PerspNorm[1] = 1
			end
		end
	end

	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from lib/src/guMtxF2L.c:guMtxF2L (Mf[row][column] is the 4x4 float matrix, 1-based; Mtx the Memory address of the Mtx: the integer
-- parts of two columns in a word, their fractions in the same word of the second half)
function Gbi.guMtxF2L(Mf: { { number } }, Mtx: number)
	for Row = 0, 3 do
		const Values = Mf[Row + 1]

		for Pair = 0, 1 do
			const Tmp1 = TruncS32(F32(Values[Pair * 2 + 1] * 65536))
			const Tmp2 = TruncS32(F32(Values[Pair * 2 + 2] * 65536))

			Rom.WriteU32(Mtx + (Row * 2 + Pair) * 4, bit32.bor(bit32.band(Tmp1, 0xFFFF0000), bit32.band(bit32.arshift(Tmp2, 16), 0xFFFF)))
			Rom.WriteU32(Mtx + 32 + (Row * 2 + Pair) * 4, bit32.bor(bit32.band(bit32.lshift(Tmp1, 16), 0xFFFF0000), bit32.band(Tmp2, 0xFFFF)))
		end
	end
end

-- from lib/src/guMtxF2L.c:guMtxIdent
function Gbi.guMtxIdent(Mtx: number)
	IdentityF()
	Gbi.guMtxF2L(Matrix, Mtx)
end

-- from include/PR/gbi.h:gSPVertex (Vertices is the Memory address of the Vtx array; V0 the slot of the first vertex)
function Gbi.gSPVertex(Vertices: number, Count: number, V0: number)
	Write(bit32.bor(bit32.lshift(Opcode.Vtx, 24), bit32.lshift(bit32.band(bit32.bor(bit32.lshift(Count - 1, 4), V0), 0xFF), 16), 16 * Count), Vertices)
end

-- from include/PR/gbi.h:gSP2Triangles (the F3D microcode has no G_TRI2: two G_TRI1)
function Gbi.gSP2Triangles(V00: number, V01: number, V02: number, Flag0: number, V10: number, V11: number, V12: number, Flag1: number)
	Gbi.gSP1Triangle(V00, V01, V02, Flag0)
	Gbi.gSP1Triangle(V10, V11, V12, Flag1)
end

-- from include/PR/gbi.h:gSPNumLights (gMoveWd of G_MW_NUMLIGHT at G_MWO_NUMLIGHT)
function Gbi.gSPNumLights(Count: number)
	Write(bit32.bor(bit32.lshift(Opcode.MoveWord, 24), 0x02), (Count + 1) * 32 + 0x80000000)
end

-- from include/PR/gbi.h:gSPLight (Light is the Memory address of the Light or of the ambient light, N the slot LIGHT_1 to LIGHT_8)
function Gbi.gSPLight(Light: number, N: number)
	Write(bit32.bor(bit32.lshift(Opcode.MoveMem, 24), bit32.lshift((N - 1) * 2 + Gbi.G_MV_L0, 16), Gbi.SIZEOF_LIGHT), Light)
end

-- from include/PR/gbi.h:gSPLookAt (LookAt is the Memory address of the two lights: the x vector, then the y vector 16 bytes on)
function Gbi.gSPLookAt(LookAt: number)
	Write(bit32.bor(bit32.lshift(Opcode.MoveMem, 24), bit32.lshift(Gbi.G_MV_LOOKATX, 16), Gbi.SIZEOF_LIGHT), LookAt)
	Write(bit32.bor(bit32.lshift(Opcode.MoveMem, 24), bit32.lshift(Gbi.G_MV_LOOKATY, 16), Gbi.SIZEOF_LIGHT), LookAt + Gbi.SIZEOF_LIGHT)
end

-- from include/PR/gbi.h:gSPViewport (Vp is the Memory address of the Vp: vscale then vtrans, four big endian s16 each)
function Gbi.gSPViewport(Vp: number)
	Write(bit32.bor(bit32.lshift(Opcode.MoveMem, 24), bit32.lshift(Gbi.G_MV_VIEWPORT, 16), Gbi.SIZEOF_VP), Vp)
end

-- from include/PR/gbi.h:gDPPipelineMode
function Gbi.gDPPipelineMode(Mode: number)
	SetOtherMode(Opcode.SetOtherModeH, 23, 1, Mode)
end

-- from include/PR/gbi.h:gDPSetTextureLOD
function Gbi.gDPSetTextureLOD(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 16, 1, Type)
end

-- from include/PR/gbi.h:gDPSetTextureLUT
function Gbi.gDPSetTextureLUT(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 14, 2, Type)
end

-- from include/PR/gbi.h:gDPSetTextureDetail
function Gbi.gDPSetTextureDetail(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 17, 2, Type)
end

-- from include/PR/gbi.h:gDPSetTextureConvert
function Gbi.gDPSetTextureConvert(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 9, 3, Type)
end

-- from include/PR/gbi.h:gDPSetCombineKey
function Gbi.gDPSetCombineKey(Type: number)
	SetOtherMode(Opcode.SetOtherModeH, 8, 1, Type)
end

-- from include/PR/gbi.h:gDPSetColorDither
function Gbi.gDPSetColorDither(Mode: number)
	SetOtherMode(Opcode.SetOtherModeH, 6, 2, Mode)
end

-- from include/PR/gbi.h:gDPSetDepthSource
function Gbi.gDPSetDepthSource(Source: number)
	SetOtherMode(Opcode.SetOtherModeL, 2, 1, Source)
end

-- from include/PR/gbi.h:gDPSetDepthImage
function Gbi.gDPSetDepthImage(Image: number)
	Write(bit32.lshift(Opcode.SetDepthImage, 24), Image)
end

-- from include/PR/gbi.h:gDPSetColorImage
function Gbi.gDPSetColorImage(Format: number, Size: number, Width: number, Image: number)
	Write(bit32.bor(bit32.lshift(Opcode.SetColorImage, 24), bit32.lshift(Format, 21), bit32.lshift(Size, 19), ShiftLeft(Width - 1, 0, 12)), Image)
end

-- from include/PR/gbi.h:gDPSetFillColor
function Gbi.gDPSetFillColor(Color: number)
	Write(bit32.lshift(Opcode.SetFillColor, 24), bit32.band(Color, 0xFFFFFFFF))
end

-- from include/PR/gbi.h:gDPFillRectangle
function Gbi.gDPFillRectangle(Ulx: number, Uly: number, Lrx: number, Lry: number)
	Write(bit32.bor(bit32.lshift(Opcode.FillRect, 24), ShiftLeft(Lrx, 14, 10), ShiftLeft(Lry, 2, 10)), bit32.bor(ShiftLeft(Ulx, 14, 10), ShiftLeft(Uly, 2, 10)))
end

-- from include/PR/gbi.h:gDPSetCombineLERP (the mux values of both cycles, resolved as the G_CC_* constants are)
function Gbi.gDPSetCombineLERP(A0: number, B0: number, C0: number, D0: number, Aa0: number, Ab0: number, Ac0: number, Ad0: number, A1: number, B1: number, C1: number, D1: number, Aa1: number, Ab1: number, Ac1: number, Ad1: number)
	Write(
		bit32.bor(bit32.lshift(Opcode.SetCombine, 24), ShiftLeft(A0, 20, 4), ShiftLeft(C0, 15, 5), ShiftLeft(Aa0, 12, 3), ShiftLeft(Ac0, 9, 3), ShiftLeft(A1, 5, 4), ShiftLeft(C1, 0, 5)),
		bit32.bor(ShiftLeft(B0, 28, 4), ShiftLeft(D0, 15, 3), ShiftLeft(Ab0, 12, 3), ShiftLeft(Ad0, 9, 3), ShiftLeft(B1, 24, 4), ShiftLeft(Aa1, 21, 3), ShiftLeft(Ac1, 18, 3), ShiftLeft(D1, 6, 3), ShiftLeft(Ab1, 3, 3), ShiftLeft(Ad1, 0, 3))
	)
end

-- from include/PR/gbi.h:gDPSetCombineMode (the G_CC_* constants of the first and the second cycle)
function Gbi.gDPSetCombineMode(Mode1: { number }, Mode2: { number })
	Gbi.gDPSetCombineLERP(Mode1[1], Mode1[2], Mode1[3], Mode1[4], Mode1[5], Mode1[6], Mode1[7], Mode1[8], Mode2[1], Mode2[2], Mode2[3], Mode2[4], Mode2[5], Mode2[6], Mode2[7], Mode2[8])
end

-- from include/PR/gbi.h:gDPLoadTextureBlock
function Gbi.gDPLoadTextureBlock(Image: number, Format: number, Size: number, Width: number, Height: number, Palette: number, Cms: number, Cmt: number, Masks: number, Maskt: number, Shifts: number, Shiftt: number)
	Gbi.gDPSetTextureImage(Format, LoadBlockSize[Size + 1], 1, Image)
	Gbi.gDPSetTile(Format, LoadBlockSize[Size + 1], 0, 0, Gbi.G_TX_LOADTILE, 0, Cmt, Maskt, Shiftt, Cms, Masks, Shifts)
	Gbi.gDPLoadSync()
	Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, bit32.rshift(Width * Height + LoadBlockIncrement[Size + 1], LoadBlockShift[Size + 1]) - 1, Gbi.CALC_DXT(Width, TexelBytes[Size + 1]))
	Gbi.gDPPipeSync()
	Gbi.gDPSetTile(Format, Size, bit32.rshift(Width * LineBytes[Size + 1] + 7, 3), 0, Gbi.G_TX_RENDERTILE, Palette, Cmt, Maskt, Shiftt, Cms, Masks, Shifts)
	Gbi.gDPSetTileSize(Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(Width - 1, Gbi.G_TEXTURE_IMAGE_FRAC), bit32.lshift(Height - 1, Gbi.G_TEXTURE_IMAGE_FRAC))
end

-- from include/PR/gbi.h:GPACK_RGBA5551
function Gbi.GPACK_RGBA5551(R: number, G: number, B: number, A: number): number
	return bit32.bor(bit32.band(bit32.lshift(R, 8), 0xF800), bit32.band(bit32.lshift(G, 3), 0x7C0), bit32.band(bit32.rshift(B, 2), 0x3E), bit32.band(A, 0x1))
end

-- from include/PR/gbi.h:GPACK_ZDZ
function Gbi.GPACK_ZDZ(Z: number, Dz: number): number
	return bit32.bor(bit32.lshift(Z, 2), Dz)
end

return Gbi
