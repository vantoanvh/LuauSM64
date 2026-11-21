--!strict
--!optimize 2
--!native

--[[
	What is behind the world: the skybox of the area, its fill color, or the flat picture a list in an orthographic pass draws (the
	backdrops of the title and the game over screens).

	Paradigm
		The ROM panorama is projected onto the six faces of a Roblox Sky. The native sky is behind the world without receiving its fog.
		Each panorama is decoded before the draw's ROM segments can change, then baked off the render thread and cached by ROM address.
		The draws of an orthographic pass are screen space pictures: the software rasterizer paints them into an image the size of the
		screen (render/builder), which is painted again only when the Gfx pool differs from the last frame's.

	Owned State
	The native sky and cached cube faces, and the flat backdrop part and image.
]]

const AssetService = game:GetService("AssetService")
const Lighting = game:GetService("Lighting")

const Build = require("../../render/builder")
const Gbi = require("../../render/gbi")
const Level = require("./ColorCurve")
const PresentationSpace = require("./PresentationSpace")
const Raster = require("../../render/raster")
const Recorder = require("../../port/src/rom/render_recorder")
const Rom = require("../../port/src/rom/rom")
const Skybox = require("../../render/skybox")
const Symbols = require("../../port/src/rom/symbols")

-- The flat backdrop sits beyond the game's farthest world projection.
const Distance = 30000 * PresentationSpace.StudsPerUnit
const CanvasSize = Vector2.new(640, 480)
const TileSize = Skybox.TileSize
const PanoramaColumns = Skybox.Columns - 2
const PanoramaWidth = PanoramaColumns * TileSize
const PanoramaHeight = Skybox.Rows * TileSize
const FaceSize = 128
const FaceDimensions = Vector2.new(FaceSize, FaceSize)
const Origin = { 0, 0, 0 }
const Right = vector.create(1, 0, 0)
const Up = vector.create(0, 1, 0)
const Back = vector.create(0, 0, 1)
type FaceAxis = { Direction: vector, Right: vector, Up: vector }

-- Roblox names the lateral faces from outside the cube and rotates the polar faces.
const FaceAxes = {
	{ Direction = -Back, Right = Right, Up = Up },
	{ Direction = Back, Right = -Right, Up = Up },
	{ Direction = Right, Right = Back, Up = Up },
	{ Direction = -Right, Right = -Back, Up = Up },
	{ Direction = Up, Right = -Back, Up = Right },
	{ Direction = -Up, Right = -Back, Up = -Right },
} :: { FaceAxis }
-- Pixels of the skybox for each texel of the panorama
const PixelsAcrossTexel = Skybox.TileWidth / TileSize
const PixelsDownTexel = Skybox.TileHeight / TileSize
-- Texels the screen spans
const WindowWidth = Skybox.ScreenWidth / PixelsAcrossTexel
const WindowHeight = Skybox.ScreenHeight / PixelsDownTexel
-- Pixels of the flat picture for each pixel of the N64's 320 x 240
const FlatScale = 1
const FlatWidth = 320 * FlatScale
const FlatHeight = 240 * FlatScale
-- The most commands of a list the signature of a picture reads, and the deepest list in a list
const MaximumCommands = 512
const MaximumDepth = 3

type Panorama = { Faces: { Content }?, Failure: string? }
const SamplesByFace: { buffer } = {}

export type Backdrop = {
	Part: Part,
	Label: ImageLabel,
	Cube: Sky,
	Panoramas: { [number]: Panorama },
	Active: Panorama?,
	Flat: EditableImage,
	-- The Gfx pool the flat picture shows
	Painted: string,
	-- What the label shows now: "panorama", "flat" or "fill"
	Mode: string,
}

const function New(): Backdrop
	const Part = Instance.new("Part")
	const Gui = Instance.new("SurfaceGui")
	const Label = Instance.new("ImageLabel")
	const Cube = Instance.new("Sky")

	Cube.Name = "SM64Sky"
	Cube.CelestialBodiesShown = false

	Part.Name = "Sky"
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.CastShadow = false
	Part.Transparency = 1
	Gui.Face = Enum.NormalId.Back
	Gui.LightInfluence = 0
	Gui.Brightness = 1
	Gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	Gui.CanvasSize = CanvasSize
	Gui.Adornee = Part
	Label.Size = UDim2.fromScale(1, 1)
	Label.BorderSizePixel = 0
	Label.BackgroundTransparency = 1
	Label.Parent = Gui
	Gui.Parent = Part
	Part.Parent = workspace

	return {
		Part = Part,
		Label = Label,
		Cube = Cube,
		Panoramas = {},
		Active = nil,
		Flat = AssetService:CreateEditableImage({ Size = Vector2.new(FlatWidth, FlatHeight) }),
		Painted = "",
		Mode = "fill",
	}
end

-- Capture the panorama while this frame's segment is still loaded.
const function ReadPanorama(Pointers: number): buffer
	const Pixels = buffer.create(PanoramaWidth * PanoramaHeight * 4)

	for Row = 0, Skybox.Rows - 1 do
		for Column = 0, PanoramaColumns - 1 do
			const Tile = Skybox.DecodeTile(Pointers, Row, Column)

			for Line = 0, TileSize - 1 do
				const Offset = ((Row * TileSize + Line) * PanoramaWidth + Column * TileSize) * 4

				buffer.copy(Pixels, Offset, Tile.Pixels, Line * TileSize * 4, TileSize * 4)
			end
		end
	end

	return Pixels
end

-- The sample positions depend on cube geometry, so every panorama uses the same offsets.
const function FaceSamples(Index: number, Axes: FaceAxis): buffer
	const Cached = SamplesByFace[Index]

	if Cached ~= nil then
		return Cached
	end

	const Samples = buffer.create(FaceSize * FaceSize * 4)
	const Focus = { 0, 0, 0 }

	for Row = 0, FaceSize - 1 do
		const Scanline = Axes.Direction + Axes.Up * (1 - (Row + 0.5) * 2 / FaceSize)

		for Column = 0, FaceSize - 1 do
			const Ray = Scanline + Axes.Right * ((Column + 0.5) * 2 / FaceSize - 1)

			Focus[1], Focus[2], Focus[3] = Ray.x, Ray.y, Ray.z

			-- Use the texel at the center of the original window for a ray looking in this direction.
			const Left, Top = Skybox.Window(Origin, Focus)
			const X = (Left / PixelsAcrossTexel + WindowWidth / 2) // 1 % PanoramaWidth
			const Y = ((Skybox.SkyboxHeight - Top) / PixelsDownTexel + WindowHeight / 2) // 1

			buffer.writeu32(Samples, (Row * FaceSize + Column) * 4, (Y * PanoramaWidth + X) * 4)
		end
	end

	SamplesByFace[Index] = Samples

	return Samples
end

const function BakePanorama(Pixels: buffer): { Content }
	const Faces: { Content } = {}
	const FacePixels = buffer.create(FaceSize * FaceSize * 4)

	for Index, Axes in FaceAxes do
		const Samples = FaceSamples(Index, Axes)

		for Offset = 0, buffer.len(Samples) - 4, 4 do
			const Texel = buffer.readu32(Pixels, buffer.readu32(Samples, Offset))
			const Red = Level(bit32.extract(Texel, 0, 8))
			const Green = Level(bit32.extract(Texel, 8, 8))
			const Blue = Level(bit32.extract(Texel, 16, 8))

			buffer.writeu32(FacePixels, Offset, bit32.bor(Red, bit32.lshift(Green, 8), bit32.lshift(Blue, 16), 0xFF000000))
		end

		const Image = AssetService:CreateEditableImage({ Size = FaceDimensions })

		Image:WritePixelsBuffer(Vector2.zero, FaceDimensions, FacePixels)

		const Result, Baked = AssetService:CreateDataModelContentAsync(Content.fromObject(Image))

		Image:Destroy()

		assert(Result == Enum.CreateContentResult.Success, `Cannot bake skybox face: {Result}`)
		Faces[Index] = Baked
	end

	return Faces
end

const function Prepare(Self: Backdrop, Frame: Recorder.Frame): boolean
	const Background = Frame.Backgrounds[1]

	if Background == nil or Background.Skybox == nil then
		return true
	end

	const Pointers = Skybox.TilePointers()
	const RomStart = Rom.BlockOf(Pointers)
	local Found = Self.Panoramas[RomStart]

	if Found == nil then
		const Pending = { Faces = nil :: { Content }?, Failure = nil :: string? }
		const Pixels = ReadPanorama(Pointers)

		Self.Panoramas[RomStart] = Pending
		Found = Pending

		task.defer(function()
			const Success, Result = pcall(BakePanorama, Pixels)

			if Success then
				Pending.Faces = Result
			else
				Pending.Failure = tostring(Result)
			end
		end)
	end

	assert(Found.Failure == nil, Found.Failure)

	return Found.Faces ~= nil
end

-- Appends the commands of a list in the pool, and of the lists in the pool it calls, to Parts
const function Commands(Address: number, Depth: number, Parts: { string })
	local Cursor = Address

	for _ = 1, MaximumCommands do
		const Word0 = Rom.ReadU32(Cursor)
		const Word1 = Rom.ReadU32(Cursor + 4)
		const Op = bit32.rshift(Word0, 24)

		table.insert(Parts, buffer.readstring(Rom.Memory, Cursor, 8))
		Cursor += 8

		if Op == Gbi.Opcode.EndDl then
			return
		elseif Op == Gbi.Opcode.Dl then
			if Word1 >= Symbols.GfxPool and Word1 < Symbols.GfxPool + Symbols.GfxPoolSize and Depth < MaximumDepth then
				Commands(Word1, Depth + 1, Parts)
			end

			if bit32.extract(Word0, 16, 8) ~= 0 then
				return
			end
		end
	end
end

-- The picture of the orthographic passes of a frame, painted when their lists differ from the last frame's
const function ShowFlat(Self: Backdrop, Passes: { Recorder.Pass }, Frame: Recorder.Frame)
	const Parts: { string } = {}

	for _, Pass in Passes do
		for _, Draw in Pass.Draws do
			if type(Draw.DisplayList) == "number" then
				table.insert(Parts, tostring(Draw.DisplayList))
				Commands(Draw.DisplayList :: number, 1, Parts)
			end
		end
	end

	const Pool = table.concat(Parts)

	if Self.Mode ~= "flat" then
		Self.Mode = "flat"
		Self.Painted = ""
		Self.Label.ImageContent = Content.none
		Self.Label.BackgroundTransparency = 1
		Self.Label.ImageContent = Content.fromObject(Self.Flat)
		Self.Label.ImageRectOffset = Vector2.zero
		Self.Label.ImageRectSize = Vector2.new(FlatWidth, FlatHeight)
	end

	if Pool == Self.Painted then
		return
	end

	Self.Painted = Pool

	const Drawn = Build({ Viewport = Frame.Viewport, Passes = Passes, Backgrounds = {}, Overlay = nil })
	const Target = Raster.New(FlatWidth, FlatHeight)

	Raster.Clear(Target, Drawn.ClearColor[1], Drawn.ClearColor[2], Drawn.ClearColor[3])
	Raster.DrawScene(Target, Drawn)

	for Offset = 0, FlatWidth * FlatHeight * 4 - 4, 4 do
		buffer.writeu8(Target.Color, Offset, Level(buffer.readu8(Target.Color, Offset)))
		buffer.writeu8(Target.Color, Offset + 1, Level(buffer.readu8(Target.Color, Offset + 1)))
		buffer.writeu8(Target.Color, Offset + 2, Level(buffer.readu8(Target.Color, Offset + 2)))
	end

	Self.Flat:WritePixelsBuffer(Vector2.zero, Vector2.new(FlatWidth, FlatHeight), Target.Color)
end

-- Shows the background of a recorded frame
const function Present(Self: Backdrop, Frame: Recorder.Frame)
	const Background = Frame.Backgrounds[1]
	const Flat: { Recorder.Pass } = {}

	for _, Pass in Frame.Passes do
		if #Pass.Draws > 0 and PresentationSpace.ClassifyPass(Pass) == "background" then
			table.insert(Flat, Pass)
		end
	end

	if #Flat == 0 and Background ~= nil and Background.Skybox ~= nil then
		const Found = Self.Panoramas[Rom.BlockOf(Skybox.TilePointers())]

		if Self.Active ~= Found then
			const Faces = Found.Faces :: { Content }
			const Cube = Self.Cube

			Cube.SkyboxFrontContent = Faces[1]
			Cube.SkyboxBackContent = Faces[2]
			Cube.SkyboxLeftContent = Faces[3]
			Cube.SkyboxRightContent = Faces[4]
			Cube.SkyboxUpContent = Faces[5]
			Cube.SkyboxDownContent = Faces[6]
			Cube.Parent = Lighting
			Self.Active = Found
		end

		Self.Label.Visible = false
		Self.Mode = "panorama"

		return
	end

	if Self.Active ~= nil then
		Self.Cube.Parent = nil
		Self.Active = nil
	end

	Self.Label.Visible = true

	const Camera = workspace.CurrentCamera :: Camera
	-- the picture of the game is the 4:3 area of the window: the part covers it
	const Window = Camera.ViewportSize
	const Height = 2 * Distance * math.tan(math.rad(Camera.FieldOfView / 2)) * math.min(Window.Y, Window.X * 3 / 4) / Window.Y

	Self.Part.Size = (vector.create(Height * 4 / 3, Height, 1) :: unknown) :: Vector3
	Self.Part.CFrame = Camera.CFrame * CFrame.new(0, 0, -Distance)

	if #Flat > 0 then
		ShowFlat(Self, Flat, Frame)

		return
	end

	-- the fill color is RGBA5551
	const Pixel = if Background ~= nil then Background.Fill % 0x10000 else 1

	Self.Mode = "fill"
	Self.Label.ImageContent = Content.none
	Self.Label.BackgroundTransparency = 0
	Self.Label.BackgroundColor3 = Color3.fromRGB(
		Level(bit32.rshift(Pixel, 11) * 255 // 31),
		Level(bit32.band(bit32.rshift(Pixel, 6), 31) * 255 // 31),
		Level(bit32.band(bit32.rshift(Pixel, 1), 31) * 255 // 31)
	)
end

return { New = New, Prepare = Prepare, Present = Present }
