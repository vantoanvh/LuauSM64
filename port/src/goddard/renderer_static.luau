--!strict
--!optimize 2

--[[
	The data of src/goddard/renderer.c that the linker places in the program and that Gbi commands point to: the textures of the hand,
	the stars and the sparkles, their vertices and display lists, and the zero filled hilites, look at vectors and identity matrix.
	renderer.luau keeps each symbol as the Memory address of its block, as the C names the array.

	Paradigm
		One block of Memory (Symbols.GoddardData) is filled when the module loads: the textures are copied from the ROM image (they
		are ROM data of the program, the US offsets of reference/assets.json), the vertices are written big endian, the display lists
		are written with the Gbi macros into their own block (Gbi.Redirect), so that gSPDisplayList(next_gfx(), &gd_dl_xxx) is the
		Memory address of a list the renderer reads like any other. Every block is 8 byte aligned, as ALIGNED8 makes the C arrays.

	Design Notes
		Only what Goddard reaches is here: the display lists and vertices that only unused functions read (gd_rsp_init, gd_rdp_init,
		gd_dl_unused_mesh), the dummy aligners and the unused vertices of the C are not written.
		The Hilite, LookAt and Mtx blocks of the C bss are zero filled by Rom.Load and written by the renderer.
]]

const Gbi = require("../rom/gbi")
const Rom = require("../rom/rom")
const Symbols = require("../rom/symbols")

const BlockEnd = Symbols.GoddardData + Symbols.GoddardDataSize

const WrapNoMirror = bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR)

local Cursor = Symbols.GoddardData
local ListEnd = 0

-- The next block of the data block, Size bytes aligned to 8
const function Allocate(Size: number): number
	const Address = Cursor

	Cursor += bit32.band(Size + 7, 0xFFFFFFF8)

	if Cursor > BlockEnd then
		error("the Goddard data does not fit its block of Memory")
	end

	return Address
end

-- A texture array: the Size bytes of the ROM at RomStart
const function Texture(RomStart: number, Size: number): number
	const Address = Allocate(Size)

	buffer.copy(Rom.Memory, Address, Rom.Image, RomStart, Size)

	return Address
end

-- Vtx_t at Address: ob[3], flag, tc[2] and cn[4] (the normal and the alpha)
const function WriteVertex(Address: number, X: number, Y: number, Z: number, S: number, T: number, Nx: number, Ny: number, Nz: number, A: number)
	Rom.WriteS16(Address, X)
	Rom.WriteS16(Address + 2, Y)
	Rom.WriteS16(Address + 4, Z)
	Rom.WriteS16(Address + 6, 0)
	Rom.WriteS16(Address + 8, S)
	Rom.WriteS16(Address + 10, T)
	Rom.WriteU8(Address + 12, Nx)
	Rom.WriteU8(Address + 13, Ny)
	Rom.WriteU8(Address + 14, Nz)
	Rom.WriteU8(Address + 15, A)
end

-- The four vertices of a quad Width wide and Height high, centered on x = 0 with its lower edge at y = 0 and its normal out of the
-- screen; its lower corners have the texture coordinate T and its right corners S, the others 0
const function Quad(Width: number, Height: number, S: number, T: number): number
	const Address = Allocate(4 * Gbi.SIZEOF_VTX)

	WriteVertex(Address, -Width // 2, 0, 0, 0, T, 0, 0, 0x7F, 0)
	WriteVertex(Address + Gbi.SIZEOF_VTX, Width // 2, 0, 0, S, T, 0, 0, 0x7F, 0)
	WriteVertex(Address + 2 * Gbi.SIZEOF_VTX, Width // 2, Height, 0, S, 0, 0, 0, 0x7F, 0)
	WriteVertex(Address + 3 * Gbi.SIZEOF_VTX, -Width // 2, Height, 0, 0, 0, 0, 0, 0x7F, 0)

	return Address
end

-- Starts a display list of Count commands: the Gbi macros called until EndList write it
const function BeginList(Count: number): number
	const Address = Allocate(Count * Gbi.SIZEOF_GFX)

	Gbi.Redirect(Address)
	ListEnd = Address + Count * Gbi.SIZEOF_GFX

	return Address
end

const function EndList()
	if Gbi.Target ~= ListEnd then
		error("a display list of Goddard has another length than its block")
	end

	Gbi.Redirect(nil)
end

-- The tiles of the 32x32 RGBA16 textures of the stars and the sparkles: the load tile, the load of the block, then the render tile
const function LoadStarTexture(Mode: number, Mask: number)
	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 0, 0, Gbi.G_TX_LOADTILE, 0, Mode, Mask, Gbi.G_TX_NOLOD, Mode, Mask, Gbi.G_TX_NOLOD)
	Gbi.gDPLoadSync()
	Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 32 * 32 - 1, Gbi.CALC_DXT(32, Gbi.G_IM_SIZ_16b_BYTES))
	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 8, 0, Gbi.G_TX_RENDERTILE, 0, Mode, Mask, Gbi.G_TX_NOLOD, Mode, Mask, Gbi.G_TX_NOLOD)
	Gbi.gDPSetTileSize(0, 0, 0, bit32.lshift(32 - 1, Gbi.G_TEXTURE_IMAGE_FRAC), bit32.lshift(32 - 1, Gbi.G_TEXTURE_IMAGE_FRAC))
end

-- A star or sparkle list: sync, the list of its color if it has one, the texture, then the branch to the list that draws it
const function TextureList(Color: number?, Image: number, Draw: number): number
	const Address = BeginList(if Color == nil then 3 else 4)

	Gbi.gDPPipeSync()

	if Color ~= nil then
		Gbi.gSPDisplayList(Color)
	end

	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Image)
	Gbi.gSPBranchList(Draw)
	EndList()

	return Address
end

-- The textures, in the order of the C
const GdTextureHandOpen = Texture(2461056, 2048)
const GdTextureHandClosed = Texture(2463112, 2048)
const GdTextureRedStar0 = Texture(2465160, 2048)
const GdTextureRedStar1 = Texture(2467208, 2048)
const GdTextureRedStar2 = Texture(2469256, 2048)
const GdTextureRedStar3 = Texture(2471304, 2048)
const GdTextureRedStar4 = Texture(2473352, 2048)
const GdTextureRedStar5 = Texture(2475400, 2048)
const GdTextureRedStar6 = Texture(2477448, 2048)
const GdTextureRedStar7 = Texture(2479496, 2048)
const GdTextureWhiteStar0 = Texture(2481544, 2048)
const GdTextureWhiteStar1 = Texture(2483592, 2048)
const GdTextureWhiteStar2 = Texture(2485640, 2048)
const GdTextureWhiteStar3 = Texture(2487688, 2048)
const GdTextureWhiteStar4 = Texture(2489736, 2048)
const GdTextureWhiteStar5 = Texture(2491784, 2048)
const GdTextureWhiteStar6 = Texture(2493832, 2048)
const GdTextureWhiteStar7 = Texture(2495880, 2048)
const GdTextureSparkle0 = Texture(2498696, 2048)
const GdTextureSparkle1 = Texture(2500744, 2048)
const GdTextureSparkle2 = Texture(2502792, 2048)
const GdTextureSparkle3 = Texture(2504840, 2048)
const GdTextureSparkle4 = Texture(2506888, 2048)
const GdTextureSparkle5 = Texture(2508936, 2048)
const GdTextureMarioFaceShine = Texture(2511696, 1024)

const GdVertexStar = Quad(128, 128, 992, 992)
const GdVertexSparkle = Quad(64, 64, 1984, 1984)

-- The list the stars branch to
const GdDlStarCommon = BeginList(16)

Gbi.gDPSetCombineMode(Gbi.G_CC_DECALRGBA, Gbi.G_CC_DECALRGBA)
Gbi.gSPClearGeometryMode(bit32.bor(Gbi.G_TEXTURE_GEN, Gbi.G_TEXTURE_GEN_LINEAR))
Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_TEX_EDGE, Gbi.G_RM_NOOP2)
Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
LoadStarTexture(Gbi.G_TX_CLAMP, 5)
Gbi.gSPVertex(GdVertexStar, 4, 0)
Gbi.gSP2Triangles(0, 1, 2, 0, 0, 2, 3, 0)
Gbi.gSPTexture(0xFFFF, 0xFFFF, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)
Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_INTER, Gbi.G_RM_NOOP2)
Gbi.gSPEndDisplayList()
EndList()

-- The list the sparkles branch to
const GdDlSparkle = BeginList(16)

Gbi.gDPSetCombineMode(Gbi.G_CC_MODULATERGBA_PRIM, Gbi.G_CC_MODULATERGBA_PRIM)
Gbi.gSPClearGeometryMode(bit32.bor(Gbi.G_TEXTURE_GEN, Gbi.G_TEXTURE_GEN_LINEAR))
Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_TEX_EDGE, Gbi.G_RM_NOOP2)
Gbi.gSPTexture(0x8000, 0x8000, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
LoadStarTexture(WrapNoMirror, Gbi.G_TX_NOMASK)
Gbi.gSPVertex(GdVertexSparkle, 4, 0)
Gbi.gSP2Triangles(0, 1, 2, 0, 0, 2, 3, 0)
Gbi.gSPTexture(0x0001, 0x0001, 0, Gbi.G_TX_RENDERTILE, Gbi.G_OFF)
Gbi.gDPSetCombineMode(Gbi.G_CC_SHADE, Gbi.G_CC_SHADE)
Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_INTER, Gbi.G_RM_NOOP2)
Gbi.gSPEndDisplayList()
EndList()

const GdDlSparkleRedColor = BeginList(2)

Gbi.gDPSetPrimColor(0, 0, 255, 0, 0, 255)
Gbi.gSPEndDisplayList()
EndList()

const GdDlSparkleWhiteColor = BeginList(2)

Gbi.gDPSetPrimColor(0, 0, 255, 255, 255, 255)
Gbi.gSPEndDisplayList()
EndList()

const GdDlMarioFaceShine = BeginList(14)

Gbi.gSPSetGeometryMode(Gbi.G_TEXTURE_GEN)
Gbi.gSPTexture(0x07C0, 0x07C0, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
Gbi.gDPSetTexturePersp(Gbi.G_TP_PERSP)
Gbi.gDPSetTextureFilter(Gbi.G_TF_BILERP)
Gbi.gDPSetCombineMode(Gbi.G_CC_HILITERGBA, Gbi.G_CC_HILITERGBA)
Gbi.gDPLoadTextureBlock(GdTextureMarioFaceShine, Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 32, 32, 0, WrapNoMirror, WrapNoMirror, 5, 5, Gbi.G_TX_NOLOD, Gbi.G_TX_NOLOD)
Gbi.gDPPipeSync()
Gbi.gSPEndDisplayList()
EndList()

const GdDlSpriteStartTexBlock = BeginList(10)

Gbi.gDPPipeSync()
Gbi.gDPSetCycleType(Gbi.G_CYC_1CYCLE)
Gbi.gSPTexture(0x8000, 0x8000, 0, Gbi.G_TX_RENDERTILE, Gbi.G_ON)
Gbi.gDPSetAlphaCompare(Gbi.G_AC_THRESHOLD)
Gbi.gDPSetBlendColor(0, 0, 0, 1)
Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_TEX_EDGE, Gbi.G_RM_NOOP2)
Gbi.gDPSetCombineMode(Gbi.G_CC_DECALRGBA, Gbi.G_CC_DECALRGBA)
Gbi.gDPSetTextureFilter(Gbi.G_TF_BILERP)
Gbi.gDPSetTexturePersp(Gbi.G_TP_NONE)
Gbi.gSPEndDisplayList()
EndList()

-- Each field is the Memory address of the static of renderer.c of that name; the lists of the stars and the sparkles are written as
-- the table is built
-- from src/goddard/renderer.c:data
return {
	gd_texture_hand_open = GdTextureHandOpen,
	gd_texture_hand_closed = GdTextureHandClosed,
	gd_texture_red_star_0 = GdTextureRedStar0,
	gd_texture_red_star_1 = GdTextureRedStar1,
	gd_texture_red_star_2 = GdTextureRedStar2,
	gd_texture_red_star_3 = GdTextureRedStar3,
	gd_texture_red_star_4 = GdTextureRedStar4,
	gd_texture_red_star_5 = GdTextureRedStar5,
	gd_texture_red_star_6 = GdTextureRedStar6,
	gd_texture_red_star_7 = GdTextureRedStar7,
	gd_texture_white_star_0 = GdTextureWhiteStar0,
	gd_texture_white_star_1 = GdTextureWhiteStar1,
	gd_texture_white_star_2 = GdTextureWhiteStar2,
	gd_texture_white_star_3 = GdTextureWhiteStar3,
	gd_texture_white_star_4 = GdTextureWhiteStar4,
	gd_texture_white_star_5 = GdTextureWhiteStar5,
	gd_texture_white_star_6 = GdTextureWhiteStar6,
	gd_texture_white_star_7 = GdTextureWhiteStar7,
	gd_texture_sparkle_0 = GdTextureSparkle0,
	gd_texture_sparkle_1 = GdTextureSparkle1,
	gd_texture_sparkle_2 = GdTextureSparkle2,
	gd_texture_sparkle_3 = GdTextureSparkle3,
	gd_texture_sparkle_4 = GdTextureSparkle4,
	gd_texture_sparkle_5 = GdTextureSparkle5,
	gd_texture_mario_face_shine = GdTextureMarioFaceShine,
	gd_vertex_star = GdVertexStar,
	gd_vertex_sparkle = GdVertexSparkle,
	gd_dl_star_common = GdDlStarCommon,
	gd_dl_sparkle = GdDlSparkle,
	gd_dl_sparkle_red_color = GdDlSparkleRedColor,
	gd_dl_sparkle_white_color = GdDlSparkleWhiteColor,
	gd_dl_red_star_0 = TextureList(nil, GdTextureRedStar0, GdDlStarCommon),
	gd_dl_red_star_1 = TextureList(nil, GdTextureRedStar1, GdDlStarCommon),
	gd_dl_red_star_2 = TextureList(nil, GdTextureRedStar2, GdDlStarCommon),
	gd_dl_red_star_3 = TextureList(nil, GdTextureRedStar3, GdDlStarCommon),
	gd_dl_red_star_4 = TextureList(nil, GdTextureRedStar4, GdDlStarCommon),
	gd_dl_red_star_5 = TextureList(nil, GdTextureRedStar5, GdDlStarCommon),
	gd_dl_red_star_6 = TextureList(nil, GdTextureRedStar6, GdDlStarCommon),
	gd_dl_red_star_7 = TextureList(nil, GdTextureRedStar7, GdDlStarCommon),
	gd_dl_silver_star_0 = TextureList(nil, GdTextureWhiteStar0, GdDlStarCommon),
	gd_dl_silver_star_1 = TextureList(nil, GdTextureWhiteStar1, GdDlStarCommon),
	gd_dl_silver_star_2 = TextureList(nil, GdTextureWhiteStar2, GdDlStarCommon),
	gd_dl_silver_star_3 = TextureList(nil, GdTextureWhiteStar3, GdDlStarCommon),
	gd_dl_silver_star_4 = TextureList(nil, GdTextureWhiteStar4, GdDlStarCommon),
	gd_dl_silver_star_5 = TextureList(nil, GdTextureWhiteStar5, GdDlStarCommon),
	gd_dl_silver_star_6 = TextureList(nil, GdTextureWhiteStar6, GdDlStarCommon),
	gd_dl_silver_star_7 = TextureList(nil, GdTextureWhiteStar7, GdDlStarCommon),
	-- The C ends the sparkles on texture 4 twice (the texture 5 its comment asks for is never used)
	gd_dl_red_sparkle_0 = TextureList(GdDlSparkleRedColor, GdTextureSparkle0, GdDlSparkle),
	gd_dl_red_sparkle_1 = TextureList(GdDlSparkleRedColor, GdTextureSparkle1, GdDlSparkle),
	gd_dl_red_sparkle_2 = TextureList(GdDlSparkleRedColor, GdTextureSparkle2, GdDlSparkle),
	gd_dl_red_sparkle_3 = TextureList(GdDlSparkleRedColor, GdTextureSparkle3, GdDlSparkle),
	gd_dl_red_sparkle_4 = TextureList(GdDlSparkleRedColor, GdTextureSparkle4, GdDlSparkle),
	gd_dl_red_sparkle_4_dup = TextureList(GdDlSparkleRedColor, GdTextureSparkle4, GdDlSparkle),
	gd_dl_silver_sparkle_0 = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle0, GdDlSparkle),
	gd_dl_silver_sparkle_1 = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle1, GdDlSparkle),
	gd_dl_silver_sparkle_2 = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle2, GdDlSparkle),
	gd_dl_silver_sparkle_3 = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle3, GdDlSparkle),
	gd_dl_silver_sparkle_4 = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle4, GdDlSparkle),
	gd_dl_silver_sparkle_4_dup = TextureList(GdDlSparkleWhiteColor, GdTextureSparkle4, GdDlSparkle),
	gd_dl_mario_face_shine = GdDlMarioFaceShine,
	gd_dl_sprite_start_tex_block = GdDlSpriteStartTexBlock,
	-- The bss of renderer.c that display list commands point to (zero filled: Rom.Load clears Memory)
	sHilites = Allocate(600 * Gbi.SIZEOF_HILITE),
	D_801BE790 = Allocate(2 * Gbi.SIZEOF_LOOKAT),
	D_801BE7D0 = Allocate(3 * Gbi.SIZEOF_LOOKAT),
	sIdnMtx = Allocate(Gbi.SIZEOF_MTX),
}
