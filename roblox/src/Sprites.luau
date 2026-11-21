--!strict
--!optimize 2

--[[
	Paints the RDP sprites and places them on pooled textured quads in the world.
	The cutout quads write depth. The blended quads share the world renderer with water and shadows.
]]

const AssetService = game:GetService("AssetService")

const Combiner = require("../../render/combiner")
const Level = require("./ColorCurve")
const Matrix = require("../../render/matrix")
const PresentationSpace = require("./PresentationSpace")
const Sprite = require("../../render/sprite")

const UnitScale = PresentationSpace.StudsPerUnit
const HiddenPosition = CFrame.new(0, -100000, 0)
const Thickness = 0.001
-- Roblox uses smooth alpha blending for a SurfaceAppearance at this part transparency.
const BlendedTransparency = 0.02
-- The lift off the surface of a sprite decal, in model units, in addition to its layer.
const DecalLift = 1.5

export type Art = {
	Image: EditableImage,
	Appearance: SurfaceAppearance,
	Transparency: number,
	Fades: boolean,
}

type SpritePool = {
	Parts: { MeshPart },
	Last: { CFrame? },
	Used: number,
	Shown: number,
}

export type Sprites = {
	Folder: Folder,
	Template: MeshPart,
	Painted: { [Art]: SpritePool },
	Parts: { BasePart },
	CFrames: { CFrame },
}

-- Studio accepts native vectors as Vector3 values. The offline type checker models them separately.
const function AsVector3(Value: vector): Vector3
	return (Value :: unknown) :: Vector3
end

-- The same unit quad is shared by every sprite. Its image runs along local +X and +Y.
const function NewTemplate(Parent: Instance): MeshPart
	const Mesh = AssetService:CreateEditableMesh()
	const BottomLeft = Mesh:AddVertex(AsVector3(vector.create(-0.5, -0.5, 0)))
	const BottomRight = Mesh:AddVertex(AsVector3(vector.create(0.5, -0.5, 0)))
	const TopRight = Mesh:AddVertex(AsVector3(vector.create(0.5, 0.5, 0)))
	const TopLeft = Mesh:AddVertex(AsVector3(vector.create(-0.5, 0.5, 0)))
	const LeftBottomUV = Mesh:AddUV(Vector2.yAxis)
	const RightBottomUV = Mesh:AddUV(Vector2.one)
	const RightTopUV = Mesh:AddUV(Vector2.xAxis)
	const LeftTopUV = Mesh:AddUV(Vector2.zero)
	const RightFace = Mesh:AddTriangle(BottomLeft, BottomRight, TopRight)
	const LeftFace = Mesh:AddTriangle(BottomLeft, TopRight, TopLeft)

	Mesh:SetFaceUVs(RightFace, { LeftBottomUV, RightBottomUV, RightTopUV })
	Mesh:SetFaceUVs(LeftFace, { LeftBottomUV, RightTopUV, LeftTopUV })

	const Result, Baked = AssetService:CreateDataModelContentAsync(Content.fromObject(Mesh))

	Mesh:Destroy()
	assert(Baked ~= nil, `SM64 sprites: could not bake the quad: {Result}`)

	const Template = AssetService:CreateMeshPartAsync(Baked)

	Template.Name = "Sprite"
	Template.Anchored = true
	Template.CanCollide = false
	Template.CanQuery = false
	Template.CanTouch = false
	Template.CastShadow = false
	Template.DoubleSided = true
	Template.Material = Enum.Material.SmoothPlastic
	Template.Color = Color3.new(1, 1, 1)
	Template.CFrame = HiddenPosition
	Template.Parent = Parent

	return Template
end

const function New(Parent: Instance, Template: MeshPart): Sprites
	const Folder = Instance.new("Folder")

	Folder.Name = "Sprites"
	Folder.Parent = Parent

	return { Folder = Folder, Template = Template, Painted = {}, Parts = {}, CFrames = {} }
end

const function Paint(Found: Sprite.Sprite): Art
	const Pixels = Sprite.Paint(Found)
	local Blended = false

	for _, Batch in Found.Batches do
		Blended = Blended or Batch.Translucent
	end

	const Transparency = if Blended then BlendedTransparency else 0
	const Batch = Found.Batches[1]
	const Fades = #Found.Batches == 1 and Batch.Translucent and not Batch.Cutout and Batch.EnvColor[4] == 255 and Combiner.UsesEnvironmentAlpha(Batch.Combine)
	const Size = Vector2.new(Found.Width, Found.Height)
	const Image = AssetService:CreateEditableImage({ Size = Size })

	for Offset = 0, buffer.len(Pixels) - 4, 4 do
		buffer.writeu8(Pixels, Offset, Level(buffer.readu8(Pixels, Offset)))
		buffer.writeu8(Pixels, Offset + 1, Level(buffer.readu8(Pixels, Offset + 1)))
		buffer.writeu8(Pixels, Offset + 2, Level(buffer.readu8(Pixels, Offset + 2)))

		if Blended then
			const Alpha = buffer.readu8(Pixels, Offset + 3)

			buffer.writeu8(Pixels, Offset + 3, math.min(math.round(Alpha / (1 - Transparency)), 255))
		end
	end

	Image:WritePixelsBuffer(Vector2.zero, Size, Pixels)

	const Appearance = AssetService:CreateSurfaceAppearanceAsync({ ColorMap = Content.fromObject(Image) })

	Appearance.AlphaMode = Enum.AlphaMode.Transparency

	return { Image = Image, Appearance = Appearance, Transparency = Transparency, Fades = Fades }
end

const function Begin(Self: Sprites)
	table.clear(Self.Parts)
	table.clear(Self.CFrames)

	for _, Painted in Self.Painted do
		Painted.Used = 0
	end
end

-- Places the painted quad at the center and axes of the sprite's projected rectangle in view space.
const function Place(Self: Sprites, Found: Sprite.Sprite, Art: Art, Mv: Matrix.Matrix, Camera: CFrame, EnvAlpha: number)
	const CenterU = (Found.MinU + Found.MaxU) / 2
	const CenterV = (Found.MinV + Found.MaxV) / 2
	const X = Found.Origin[1] + Found.AxisU[1] * CenterU + Found.AxisV[1] * CenterV
	const Y = Found.Origin[2] + Found.AxisU[2] * CenterU + Found.AxisV[2] * CenterV
	const Z = Found.Origin[3] + Found.AxisU[3] * CenterU + Found.AxisV[3] * CenterV
	const Position = vector.create(
		X * Mv[1] + Y * Mv[5] + Z * Mv[9] + Mv[13],
		X * Mv[2] + Y * Mv[6] + Z * Mv[10] + Mv[14],
		X * Mv[3] + Y * Mv[7] + Z * Mv[11] + Mv[15]
	)
	const AlongU = vector.create(
		Found.AxisU[1] * Mv[1] + Found.AxisU[2] * Mv[5] + Found.AxisU[3] * Mv[9],
		Found.AxisU[1] * Mv[2] + Found.AxisU[2] * Mv[6] + Found.AxisU[3] * Mv[10],
		Found.AxisU[1] * Mv[3] + Found.AxisU[2] * Mv[7] + Found.AxisU[3] * Mv[11]
	)
	const AlongV = vector.create(
		Found.AxisV[1] * Mv[1] + Found.AxisV[2] * Mv[5] + Found.AxisV[3] * Mv[9],
		Found.AxisV[1] * Mv[2] + Found.AxisV[2] * Mv[6] + Found.AxisV[3] * Mv[10],
		Found.AxisV[1] * Mv[3] + Found.AxisV[2] * Mv[7] + Found.AxisV[3] * Mv[11]
	)
	const Width = vector.magnitude(AlongU) * (Found.MaxU - Found.MinU) * UnitScale
	const Height = vector.magnitude(AlongV) * (Found.MaxV - Found.MinV) * UnitScale

	if Width < Thickness or Height < Thickness then
		return
	end

	const Right = vector.normalize(AlongU)
	const Up = vector.normalize(AlongV)
	const Batch = Found.Batches[1]
	local Center = Position

	if Batch.Decal then
		const Normal = vector.cross(Right, Up)
		const Side = if vector.dot(Normal, -Position) >= 0 then 1 else -1

		Center += Normal * Side * (Batch.Layer + DecalLift)
	end

	const Painted = Self.Painted[Art] or { Parts = {}, Last = {}, Used = 0, Shown = 0 } :: SpritePool
	const Slot = Painted.Used + 1
	const Existing = Painted.Parts[Slot]
	local Part: MeshPart

	Self.Painted[Art] = Painted

	if Existing == nil then
		Part = Self.Template:Clone() :: MeshPart
		Art.Appearance:Clone().Parent = Part
		Part.Parent = Self.Folder
		Painted.Parts[Slot] = Part
	else
		Part = Existing
	end

	Painted.Used = Slot

	const Transparency = if Art.Fades then 1 - (1 - Art.Transparency) * EnvAlpha / 255 else Art.Transparency

	if Part.Transparency ~= Transparency then
		Part.Transparency = Transparency
	end

	const Size = AsVector3(vector.create(Width, Height, Thickness))
	const Frame = Camera * CFrame.fromMatrix(AsVector3(Center * UnitScale), AsVector3(Right), AsVector3(Up))

	if Part.Size ~= Size then
		Part.Size = Size
	end

	if Painted.Last[Slot] ~= Frame then
		Painted.Last[Slot] = Frame
		table.insert(Self.Parts, Part)
		table.insert(Self.CFrames, Frame)
	end
end

const function Flush(Self: Sprites)
	for _, Painted in Self.Painted do
		for Slot = Painted.Used + 1, Painted.Shown do
			Painted.Parts[Slot].CFrame = HiddenPosition
			Painted.Last[Slot] = nil
		end

		Painted.Shown = Painted.Used
	end

	if #Self.Parts > 0 then
		workspace:BulkMoveTo(Self.Parts, Self.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

const function Destroy(Self: Sprites)
	Self.Folder:Destroy()
	table.clear(Self.Painted)
end

return { NewTemplate = NewTemplate, New = New, Paint = Paint, Begin = Begin, Place = Place, Flush = Flush, Destroy = Destroy }
