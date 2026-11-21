--!strict
--!optimize 2

--[[
	The sky of an area: the 3x3 grid of 32x32 tiles of the skybox texture (segment 0x0A) that skybox.c draws behind the world
	for the direction the camera looks, as batches of the Scene (an orthographic projection, no depth).

	Design Notes
		skybox.c is the model: the same scaled position in the 10x8 tile grid. The segment ends with 80 pointers into its 32x32 RGBA16
		tiles. Several grid cells can refer to the same tile. The ortho window of the game is mapped to
		the 320x240 window of the scene's ortho projection by a shift of the quad coordinates.
]]

const Gbi = require("./gbi")
const Rom = require("../port/src/rom/rom")
const Scene = require("./scene")
const Decode = require("./texture")

const ScreenWidth = 320
const ScreenHeight = 240
const SkyboxWidth = 4 * ScreenWidth
const SkyboxHeight = 4 * ScreenHeight
const TileWidth = ScreenWidth // 2
const TileHeight = ScreenHeight // 2
const Columns = 10
const Rows = 8
const TileSize = 32
const SkyboxSegment = 0x0A000000
const TilePointerSize = 4
const LastTexel = 31
-- The camera angle arguments of create_skybox_facing_camera: fov is always 90
const SkyboxFov = 90

-- G_CC_MODULATERGB: texel * shade (the alpha is the shade's)
const ModulateRgb = { Gbi.CcTexel0, 31, Gbi.CcShade, 31, 7, 7, 7, Gbi.CcShade, 0, 0, 0, 0, 0, 0, 0, 0 }
const Projection = { Perspective = false, Fov = 0, Near = 0, Far = 100, Scale = 1 } :: Scene.Projection
const White = { 255, 255, 255, 255 }

-- atan2s of the game: the angle of the vector from its first axis, 0x10000 to a turn
const function Atan2s(Y: number, X: number): number
	return math.atan2(X, Y) / math.pi * 0x8000
end

-- The left and top edges of the window, measured from the left and bottom edges of the 1280 x 960 skybox.
const function Window(Position: { number }, Focus: { number }): (number, number)
	const FaceX = Focus[1] - Position[1]
	const FaceY = Focus[2] - Position[2]
	const FaceZ = Focus[3] - Position[3]
	const Yaw = Atan2s(FaceZ, FaceX) % 0x10000
	const Pitch = Atan2s(math.sqrt(FaceX * FaceX + FaceZ * FaceZ), FaceY)

	local ScaledX = (ScreenWidth * 360 * Yaw / (SkyboxFov * 65536) + 0.5) // 1

	if ScaledX > SkyboxWidth then
		ScaledX -= ScaledX // SkyboxWidth * SkyboxWidth
	end

	ScaledX = SkyboxWidth - ScaledX

	const ScaledY = math.clamp((360 * (Pitch * 360 / 65535) / 90 + 0.5) // 1 + 5 * TileHeight, ScreenHeight, SkyboxHeight)

	return ScaledX, ScaledY
end

-- The lookup table follows the unique tiles, whose count varies between skyboxes.
const function TilePointers(): number
	const Base = Rom.SegmentedToVirtual(SkyboxSegment)
	const RomStart = Rom.BlockOf(Base)
	const Size = bit32.byteswap(buffer.readu32(Rom.Image, RomStart + 4))

	return Base + Size - Rows * Columns * TilePointerSize
end

const function DecodeTile(Pointers: number, Row: number, Column: number)
	const Address = Rom.SegmentedToVirtual(Rom.ReadU32(Pointers + (Row * Columns + Column) * TilePointerSize))

	return Decode(Address, Gbi.FmtRgba, Gbi.Siz16b, TileSize, TileSize, TileSize * 2, nil, 0, 0)
end

-- Adds the batches of the skybox for the camera Position looking at Focus
const function Add(Target: Scene.Scene, Position: { number }, Focus: { number })
	const ScaledX, ScaledY = Window(Position, Focus)
	const FirstColumn = ScaledX // TileWidth
	const FirstRow = (SkyboxHeight - ScaledY) // TileHeight
	const Pointers = TilePointers()

	for Row = FirstRow, math.min(FirstRow + 2, Rows - 1) do
		for Column = FirstColumn, math.min(FirstColumn + 2, Columns - 1) do
			const Left = Column * TileWidth - ScaledX - ScreenWidth // 2
			const Top = SkyboxHeight - Row * TileHeight - ScaledY + ScreenHeight // 2
			const Image = DecodeTile(Pointers, Row, Column)

			table.insert(Target.Batches, {
				Layer = 0,
				Projection = Projection,
				Texture = Image,
				MaskS = 0,
				MaskT = 0,
				MirrorS = false,
				MirrorT = false,
				ClampS = true,
				ClampT = true,
				Filtered = true,
				Combine = ModulateRgb,
				TwoCycle = false,
				EnvColor = White,
				PrimColor = White,
				FogColor = White,
				FogMultiplier = 0,
				FogOffset = 0,
				Fog = false,
				Translucent = false,
				Cutout = false,
				DepthCompare = false,
				DepthUpdate = false,
				Decal = false,
				CullBack = false,
				CullFront = false,
				Normals = {},
				Lights = {},
				Positions = { Left, Top, -1, Left, Top - TileHeight, -1, Left + TileWidth, Top - TileHeight, -1, Left + TileWidth, Top, -1 },
				Colors = table.create(16, 255),
				UVs = { 0, 0, 0, LastTexel, LastTexel, LastTexel, LastTexel, 0 },
				Indices = { 1, 2, 3, 1, 3, 4 },
				VertexCount = 4,
			})
		end
	end
end

return { Add = Add, Window = Window, TilePointers = TilePointers, DecodeTile = DecodeTile, TileSize = TileSize, Columns = Columns, Rows = Rows, TileWidth = TileWidth, TileHeight = TileHeight, ScreenWidth = ScreenWidth, ScreenHeight = ScreenHeight, SkyboxHeight = SkyboxHeight, SkyboxWidth = SkyboxWidth }
