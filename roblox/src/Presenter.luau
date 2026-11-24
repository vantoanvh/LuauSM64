--!strict
--!optimize 2

--[[
	Shows the frames the render recorder records as MeshParts, with the camera at the origin and the game's view space as the
	world, so a draw is a CFrame.

	Paradigm
		The display list of a master list entry is decoded once (render/display_list, relight mode: model space batches; a lit vertex
		keeps its normal and the lights it was lit with) into meshes and cached by what the list is and the layer it is drawn on. A frame
		only moves the cached parts: the matrix of each draw (the modelview the traversal built: model to view space) becomes the
		CFrame (rotation, position) and the Size (the scale of the matrix). The camera stands still at the origin looking down -Z,
		which is the N64 view space.
		Lighting is the RSP's, per vertex: for a lit batch every draw has a mesh of its own that stays editable, and each frame the colors of
		its vertices are the ambient light plus each directional light times the dot product of the vertex normal and the light direction
		taken through the draw's matrix (render/matrix LightCoefficient, as display_list lights a vertex). Roblox lighting plays no part:
		the place has no sun (Brightness 0) and a white ambient light, so a part shows its vertex colors times its texture as they are
		(the Neon material would run them through an emissive curve instead). The batches that are not lit carry their colors as the level
		data has them and are static.

	Owned State
		The Folder the parts live in, the decoded entries, the baked textures and the pieces shown last frame.

	Design Notes
		SM64 units are scaled by UnitScale into studs. Building a mesh yields (CreateMeshPartAsync), so entries build one after the other in a
		task of their own and are skipped by frames until they are Ready. A client may hold only a handful of EditableMeshes at once (8 in
		Studio), and a MeshPart made from one stops rendering when it is destroyed. A mesh that no longer changes is converted to opaque
		Content (AssetService:CreateDataModelContentAsync) and the MeshPart is made from that, after which the EditableMesh is destroyed:
		the part keeps its geometry and the budget is free. The textures are baked the same way. A lit batch is baked too, and each draw
		of it makes a fixed-size EditableMesh from the baked content (CreateEditableMeshAsync: fixed-size meshes cost little budget and keep
		their vertex attributes writable), which its part shows live.
		A new level or area drops every entry (the segments change what an address holds).
		A SurfaceAppearance (the cutout textures) takes no vertex colors, so a lit cutout is not lit.
]]

const AssetService = game:GetService("AssetService")
const RunService = game:GetService("RunService")

const Area = require("../../port/src/game/area")
const Level = require("./ColorCurve")
const Combiner = require("../../render/combiner")
const Cut = require("../../render/cut")
const DisplayList = require("../../render/display_list")
const Gbi = require("../../render/gbi")
const Matrix = require("../../render/matrix")
const Flatten = require("./PoolLists")
const PresentationSpace = require("./PresentationSpace")
const Recorder = require("../../port/src/rom/render_recorder")
const Rom = require("../../port/src/rom/rom")
const Scene = require("../../render/scene")
const AddShadow = require("../../render/shadow")
const Shapes = require("../../render/sprite")
const Sprites = require("./Sprites")
const Texture = require("../../render/texture")

-- A lit mesh of one draw: its editable mesh, the color id of each vertex of its batch, and what the lighting needs
type LitMesh = {
	Mesh: EditableMesh,
	Batch: Scene.Batch,
	ColorIds: { number },
	-- The distinct light sets of the batch and, per vertex, the number of its set
	Sets: { Scene.LightSet },
	SetOf: { number },
	-- The rotation of the matrix the colors were made with (nil before the first time)
	Last: { number }?,
}

-- The fog of a list as the RSP has it: the color (0..255 RGBA) and the multiplier and offset of gSPFogPosition
type Fog = { Color: { number }, Multiplier: number, Offset: number }
type TextureAlpha = { Maximum: number, HasAlpha: boolean }

-- One draw of a cached list: the MeshParts, one per batch, and the lit meshes by the number of their part
-- Last: where each part was put last (nil while it is hidden): a part whose place did not change is not moved
-- Centers: where the center of each part's mesh is from the origin of the model (in studs); the meshes are centered on themselves
-- FadeOpacity: the base opacity of parts whose fade follows the environment alpha
type Group = { Parts: { MeshPart }, Sizes: { Vector3 }, Centers: { Vector3 }, FadeOpacity: { [number]: number }, ShadeDecals: { [number]: boolean }, Last: { CFrame? }, Lit: { [number]: LitMesh } }

-- A mesh of a list the game rewrites every frame, made once and updated in place: its editable mesh and the ids of the vertices and
-- texture coordinates of the batch, in the order of the batch
type DynamicMesh = {
	Mesh: EditableMesh,
	VertexIds: { number },
	UvIds: { number },
	Indices: { number },
	Positions: { number }?,
	UVs: { number }?,
	Center: Vector3,
	Width: number,
	Height: number,
	TextureOpacity: number,
}

-- The meshes a list of the pool is shown by (Signature: how many vertices and which textures they have, which the meshes were made for)
-- Shadow enables the floor clearance and smooth texture.
type Dynamic = { Signature: string, Group: Group?, Meshes: { DynamicMesh }, Building: boolean, Dropped: boolean, Stamp: number, Shadow: boolean }

-- A batch of a list as a part: an unlit one is a MeshPart to clone, a lit one the baked mesh content each draw makes a mesh from
-- Transparency carries the mean blended alpha; the texture handles the cutout shape.
type Piece = { Part: MeshPart?, Baked: Content?, Batch: Scene.Batch?, Decoded: Texture.Texture?, Alpha: boolean, Center: Vector3, Fades: boolean, Transparency: number, ShadeDecal: boolean? }

type Entry = {
	Ready: boolean,
	Pieces: { Piece },
	HasLit: boolean,
	-- A list that draws a sprite (a tree, a particle, a shadow): the shape and where it was painted; it has no pieces
	Sprite: Shapes.Sprite?,
	Painted: Sprites.Art?,
	-- The fog the list draws with (nil when it draws without)
	Fog: Fog?,
	-- The place of the entry among those made, the draw before it in the frame that made it (the RSP keeps its state from list to list: the
	-- entry is decoded from the state that draw left) and the state the entry left for the next
	Rank: number,
	Layer: number,
	-- The level the list was decoded for (an address holds other data in another level)
	Level: number,
	Previous: Entry?,
	EndState: DisplayList.State?,
	Instances: { Group },
	-- Instances being made (a lit one takes yields)
	Pending: number,
	UseStamp: number,
	Used: number,
	Shown: number,
}

export type Presenter = {
	Folder: Folder,
	-- Painted sprites and their pooled quads for the current level
	Sprites: Sprites.Sprites,
	Entries: { [string]: Entry },
	-- The levels whose decoded entries are made ahead of time and stay
	Pinned: { [number]: boolean },
	-- The baked (opaque) content of each decoded texture
	Images: { [Texture.Texture]: Content },
	-- The SurfaceAppearance of each texture that has transparent texels (made once, cloned onto the parts)
	Appearances: { [Texture.Texture]: SurfaceAppearance },
	-- The builds waiting and whether the task that runs them is going; Generation changes when the entries are dropped
	Queue: { () -> () },
	-- The tasks running builds now (builds yield, so several go at once)
	Workers: number,
	-- The current asset of each active warm-up worker, released before gameplay.
	Preloading: { [thread]: string }?,
	-- Attract mode's opening draws, prepared while the title is idle.
	DemoPlans: { [number]: { [Entry]: number } },
	StagedDemo: number?,
	Generation: number,
	-- The lists the game rewrites every frame, by their number in the frame; the number of the frame
	Dynamics: { Dynamic },
	DynamicStamp: number,
	-- Entries made so far (their ranks)
	Created: number,
	-- The level and area the entries were decoded for
	Level: number,
	AreaIndex: number,
	-- Whether builds can use the larger budget while entering an area
	Loading: boolean,
	-- The parts and CFrames of the frame being presented
	Parts: { BasePart },
	CFrames: { CFrame },
	-- Flattened calls and their prepared instances, reused while a frame is assembled.
	CallsByPass: { { Flatten.Call } },
	PreparedEntries: { [Flatten.Call]: Entry },
	DrawNumbers: { [Flatten.Call]: number },
	UseStamp: number,
	UsedEntries: { Entry },
	ShownEntries: { Entry },
}

-- Studs per SM64 unit
const UnitScale = PresentationSpace.StudsPerUnit
-- The builds that run at once
const MaximumWorkers = 4
-- The seconds of a frame the builds may take before they wait for the next frame: little while the game runs, much while it waits for them
const BuildBudget = 0.006
const LoadingBudget = 0.03
const HiddenPosition = CFrame.new(0, -100000, 0)
-- The first slot of the dynamic meshes that are shadows and the number of slots per shadow type.
const ShadowSlot = 10000
const ShadowsOfSize = 100
const ShadowLift = 0.05
const DefaultViewport = { X = 160, Y = 120, HalfWidth = 160, HalfHeight = 120 }
-- The entries of the matrix that rotate and scale (the rest is the translation): what the lighting depends on
const RotationEntries = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
-- Coplanar surfaces of the level data lie over each other and the N64 shows the one drawn last, where Roblox's depth test would flicker
-- between them. The game draws its layers in order (opaque, decals, cutouts, blended: each over the ones before), so a piece is lifted off
-- its surface along its normals, in model units, the more the higher its layer (LayerLift), the later it is in its list (OrderLift) and the
-- later its list was made (RankLift), and a decal or blended piece (the shadows) more (BlendLift). The lift is part of the mesh, so
-- a part that does not move stays where it is.
-- (a layer is a step the order and the rank together do not reach, and a decal or blended piece is above everything of its layer)
const LayerLift = 1
const OrderLift = 0.02
const RankLift = 0.004
const BlendLift = 1.5
const MaximumLayer = 7
const MaximumOrder = 16
const MaximumRank = 100
-- The face texture and shade use the same triangles. Keep their separation
-- through the distant LODs, where the depth buffer has less precision.
const MinimumShadeDecalBias = 2.5 * UnitScale
const MaximumShadeDecalBias = 8 * UnitScale
const ShadeDecalDepthFraction = 1 / 512
-- The projection of a list built before it is drawn: a perspective one, as every list of the world has

-- When the frame the builds run in began
local FrameStart = os.clock()

RunService.PostSimulation:Connect(function()
	FrameStart = os.clock()
end)

-- Lets the next frame run when the builds have had their share of this one
const function Cooperate(Self: Presenter)
	if os.clock() - FrameStart > (if Self.Loading then LoadingBudget else BuildBudget) then
		task.wait()
	end
end

const function New(): Presenter
	const Folder = Instance.new("Folder")

	Folder.Name = "SM64"
	Folder.Parent = workspace

	-- Unlit Roblox lighting: no sun, a white ambient light, no reflections, so surfaces show their own colors
	const Lit = game:GetService("Lighting")

	Lit.Brightness = 0
	Lit.ClockTime = 14
	Lit.GeographicLatitude = 0
	Lit.GlobalShadows = false
	Lit.Ambient = Color3.new(1, 1, 1)
	Lit.OutdoorAmbient = Color3.new(1, 1, 1)
	Lit.EnvironmentDiffuseScale = 0
	Lit.EnvironmentSpecularScale = 0
	Lit.ExposureCompensation = 0

	-- the Retro tonemapper, and a bloom that glows nothing (its threshold is above any color); the warm-up makes a presenter too, so an
	-- effect that is there is used
	const Grade = Lit:FindFirstChildOfClass("ColorGradingEffect") or Instance.new("ColorGradingEffect")
	const Bloom = Lit:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")

	Grade.TonemapperPreset = Enum.TonemapperPreset.Retro
	Grade.Enabled = true
	Grade.Parent = Lit
	Bloom.Intensity = 0
	Bloom.Size = 0
	Bloom.Threshold = 4
	Bloom.Enabled = true
	Bloom.Parent = Lit

	const SpriteTemplate = Sprites.NewTemplate(Folder)

	return { Folder = Folder, Sprites = Sprites.New(Folder, SpriteTemplate), Entries = {}, Pinned = {}, Images = {}, Appearances = {}, Queue = {}, Workers = 0, Preloading = {}, DemoPlans = {}, StagedDemo = nil, Generation = 0, Dynamics = {}, DynamicStamp = 0, Created = 0, Level = -1, AreaIndex = -1, Loading = false, Parts = {}, CFrames = {}, CallsByPass = {}, PreparedEntries = {}, DrawNumbers = {}, UseStamp = 0, UsedEntries = {}, ShownEntries = {} }
end

-- The editable meshes this client holds now (the budget of a client is memory: the count says how many it had when it ran out)
local LiveMeshes = 0

-- An empty editable mesh; a client past its budget gets none, which is an error here with the count of the meshes held
const function CreateMesh(): EditableMesh
	const Mesh = AssetService:CreateEditableMesh()

	if Mesh == nil then
		error(`SM64 presenter: no memory budget for another EditableMesh, {LiveMeshes} are held`)
	end

	LiveMeshes += 1

	return Mesh
end

-- A fixed-size editable mesh of baked content
const function CreateMeshFrom(Baked: Content): EditableMesh
	const Mesh = AssetService:CreateEditableMeshAsync(Baked)

	if Mesh == nil then
		error(`SM64 presenter: no memory budget for another EditableMesh, {LiveMeshes} are held`)
	end

	LiveMeshes += 1

	return Mesh
end

const function DestroyMesh(Mesh: EditableMesh)
	Mesh:Destroy()
	LiveMeshes -= 1
end

-- Converts an editable asset that no longer changes to opaque content, which keeps the data without the budget of the editable (yields)
const function Bake(Editable: EditableMesh | EditableImage): Content
	const Result, Baked = AssetService:CreateDataModelContentAsync(Content.fromObject(Editable))

	if Baked == nil then
		error(`SM64 presenter: could not bake an editable asset: {Result}`)
	end

	return Baked
end

const AlphaByTexture: { [Texture.Texture]: TextureAlpha } = {}

const function AlphaOf(Decoded: Texture.Texture): TextureAlpha
	const Cached = AlphaByTexture[Decoded]

	if Cached ~= nil then
		return Cached
	end

	local Maximum = 0
	local HasAlpha = false

	for Offset = 3, Decoded.Width * Decoded.Height * 4 - 1, 4 do
		const Alpha = buffer.readu8(Decoded.Pixels, Offset)

		Maximum = math.max(Maximum, Alpha)
		HasAlpha = HasAlpha or Alpha ~= 255

		if HasAlpha and Maximum == 255 then
			break
		end
	end

	const Result = { Maximum = Maximum, HasAlpha = HasAlpha }

	AlphaByTexture[Decoded] = Result

	return Result
end

-- Texturize normalizes cutout texels to the most opaque one. Apply that original opacity to the part with the shade alpha.
const function TextureOpacity(Batch: Scene.Batch): number
	return if Batch.Translucent and Batch.Texture ~= nil then AlphaOf(Batch.Texture).Maximum / 255 else 1
end

-- The pixels of a decoded texture through the color curve: Roblox filters a texture bilinearly, as the N64 does (its 3-point filter), so the
-- texels are not enlarged
const function Pixels(Decoded: Texture.Texture): buffer
	const Width = Decoded.Width
	const Height = Decoded.Height
	const Result = buffer.create(Width * Height * 4)
	-- The most opaque texel becomes opaque. TextureOpacity supplies the original factor.
	const AlphaScale = 255 / math.max(AlphaOf(Decoded).Maximum, 1)

	for Y = 0, Height - 1 do
		for X = 0, Width - 1 do
			-- the color channels go through the curve of Roblox's display
			const Offset = (Y * Width + X) * 4
			const Texel = Level(buffer.readu8(Decoded.Pixels, Offset))
				+ bit32.lshift(Level(buffer.readu8(Decoded.Pixels, Offset + 1)), 8)
				+ bit32.lshift(Level(buffer.readu8(Decoded.Pixels, Offset + 2)), 16)
				+ bit32.lshift(math.min(math.round(buffer.readu8(Decoded.Pixels, Offset + 3) * AlphaScale), 255), 24)

			buffer.writeu32(Result, Offset, Texel)
		end
	end

	return Result
end

-- The editable image of a decoded texture, through the color curve
const function MakeImage(Decoded: Texture.Texture): EditableImage
	const Image = AssetService:CreateEditableImage({ Size = Vector2.new(Decoded.Width, Decoded.Height) })

	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Decoded.Width, Decoded.Height), Pixels(Decoded))

	return Image
end

-- Gives a part the texture of a decoded one (made the first time; yields). The texel alpha counts only for a cutout or blended batch (Alpha):
-- an opaque draw of the RDP ignores it (Mario's face and the plate of a sign have texels of alpha 0 that it shows as they are). The
-- texture of an opaque draw is baked and set as the TextureContent, which ignores alpha; the alpha of a cutout (trees, fences) needs a live
-- EditableImage under a SurfaceAppearance with the Transparency alpha mode, the only way a MeshPart takes the alpha of a texture.
const function Texturize(Self: Presenter, Part: MeshPart, Decoded: Texture.Texture, Alpha: boolean)
	const Preloading = Self.Preloading

	if Alpha and AlphaOf(Decoded).HasAlpha then
		local Appearance = Self.Appearances[Decoded]

		if Appearance == nil then
			if Preloading ~= nil then
				Preloading[coroutine.running()] = `Preparing {Decoded.Width} × {Decoded.Height} texture with transparency`
			end

			Appearance = AssetService:CreateSurfaceAppearanceAsync({ ColorMap = Content.fromObject(MakeImage(Decoded)) })
			Appearance.AlphaMode = Enum.AlphaMode.Transparency
			Self.Appearances[Decoded] = Appearance
		end

		Appearance:Clone().Parent = Part

		return
	end

	local Baked = Self.Images[Decoded]

	if Baked == nil then
		if Preloading ~= nil then
			Preloading[coroutine.running()] = `Preparing {Decoded.Width} × {Decoded.Height} texture`
		end

		const Image = MakeImage(Decoded)

		Baked = Bake(Image)
		Image:Destroy()
		Self.Images[Decoded] = Baked
	end

	Part.TextureContent = Baked
end

-- The properties every part of the scene has
const function Prepare(Part: MeshPart)
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.CastShadow = false
	Part.DoubleSided = true
	Part.Material = Enum.Material.SmoothPlastic
	-- the color of a part multiplies its vertex colors and its texture: the default gray would take a third of the light
	Part.Color = Color3.new(1, 1, 1)
	Part.CFrame = HiddenPosition
end

-- Studio accepts native vectors as Vector3 values. The offline type checker models them separately.
const function AsVector3(Value: vector): Vector3
	return (Value :: unknown) :: Vector3
end

-- The vertex normals of a batch from its triangles (the winding is the front face), for a batch that has none
const function FaceNormals(Batch: Scene.Batch): { number }
	const Positions = Batch.Positions
	const Sums: { number } = table.create(Batch.VertexCount * 3, 0)
	const Indices = Batch.Indices

	for Triangle = 0, #Indices // 3 - 1 do
		const A, B, C = Indices[Triangle * 3 + 1], Indices[Triangle * 3 + 2], Indices[Triangle * 3 + 3]
		const Base = vector.create(Positions[A * 3 - 2], Positions[A * 3 - 1], Positions[A * 3])
		const Normal = vector.cross(
			vector.create(Positions[B * 3 - 2], Positions[B * 3 - 1], Positions[B * 3]) - Base,
			vector.create(Positions[C * 3 - 2], Positions[C * 3 - 1], Positions[C * 3]) - Base
		)

		for _, Vertex in { A, B, C } do
			Sums[Vertex * 3 - 2] += Normal.x
			Sums[Vertex * 3 - 1] += Normal.y
			Sums[Vertex * 3] += Normal.z
		end
	end

	for Vertex = 1, Batch.VertexCount do
		const Length = math.sqrt(Sums[Vertex * 3 - 2] ^ 2 + Sums[Vertex * 3 - 1] ^ 2 + Sums[Vertex * 3] ^ 2)

		if Length > 0 then
			Sums[Vertex * 3 - 2] /= Length
			Sums[Vertex * 3 - 1] /= Length
			Sums[Vertex * 3] /= Length
		end
	end

	return Sums
end

-- Texture coordinates of a vertex of a batch the mirror fold has to cut: x y z, r g b a, s t (and the normal when the batch has one)
const FieldS = 8
const FieldT = 9

-- The part of a polygon (a list of such vertices) where Sign times the field is not negative; the edges across zero are cut there
const function KeepSide(Polygon: { { number } }, Field: number, Sign: number): { { number } }
	const Kept: { { number } } = {}

	for Index, Vertex in Polygon do
		const Next = Polygon[Index % #Polygon + 1]
		const Here = Vertex[Field] * Sign
		const There = Next[Field] * Sign

		if Here >= 0 then
			table.insert(Kept, Vertex)
		end

		if (Here > 0 and There < 0) or (Here < 0 and There > 0) then
			const Fraction = Here / (Here - There)
			const Cut = table.create(#Vertex, 0)

			for Number = 1, #Vertex do
				Cut[Number] = Vertex[Number] + (Next[Number] - Vertex[Number]) * Fraction
			end

			Cut[Field] = 0
			table.insert(Kept, Cut)
		end
	end

	return Kept
end

-- The batch with its triangles cut where its texture coordinates cross zero along an axis the texture is mirrored on, and the coordinates
-- folded over zero: the N64 mirrors a texture over its edge, which a mesh cannot (it repeats); the blob shadow is a quarter circle mirrored
-- across the center of its quad. The coordinates must lie within one texture of zero. A lit batch is left as it is
const function Unfold(Batch: Scene.Batch): Scene.Batch
	const Decoded = Batch.Texture

	if Decoded == nil or not (Batch.MirrorS or Batch.MirrorT) or #Batch.Normals > 0 then
		return Batch
	end

	local LowS, HighS, LowT, HighT = math.huge, -math.huge, math.huge, -math.huge

	for Index = 1, Batch.VertexCount do
		const S = Batch.UVs[Index * 2 - 1] / Decoded.Width
		const T = Batch.UVs[Index * 2] / Decoded.Height

		LowS, HighS, LowT, HighT = math.min(LowS, S), math.max(HighS, S), math.min(LowT, T), math.max(HighT, T)
	end

	const FoldS = Batch.MirrorS and LowS < -0.0001 and LowS >= -1.0001 and HighS <= 1.0001
	const FoldT = Batch.MirrorT and LowT < -0.0001 and LowT >= -1.0001 and HighT <= 1.0001

	if not (FoldS or FoldT) then
		return Batch
	end

	const Unfolded = table.clone(Batch)
	const Positions: { number } = {}
	const Colors: { number } = {}
	const UVs: { number } = {}
	const Indices: { number } = {}
	local Count = 0

	for Triangle = 0, #Batch.Indices // 3 - 1 do
		const TriangleVertices: { { number } } = {}
		local Pieces = { TriangleVertices }

		for Corner = 1, 3 do
			const Index = Batch.Indices[Triangle * 3 + Corner]

			table.insert(Pieces[1], {
				Batch.Positions[Index * 3 - 2], Batch.Positions[Index * 3 - 1], Batch.Positions[Index * 3],
				Batch.Colors[Index * 4 - 3], Batch.Colors[Index * 4 - 2], Batch.Colors[Index * 4 - 1], Batch.Colors[Index * 4],
				Batch.UVs[Index * 2 - 1], Batch.UVs[Index * 2],
			})
		end

		for Axis = 1, 2 do
			const Field = if Axis == 1 then FieldS else FieldT

			if if Axis == 1 then FoldS else FoldT then
				const Cut: { { { number } } } = {}

				for _, Polygon in Pieces do
					for _, Sign in { -1, 1 } do
						const Side = KeepSide(Polygon, Field, Sign)

						if #Side >= 3 then
							table.insert(Cut, Side)
						end
					end
				end

				Pieces = Cut
			end
		end

		for _, Polygon in Pieces do
			-- a fan of triangles
			for Corner = 2, #Polygon - 1 do
				for _, Vertex in { Polygon[1], Polygon[Corner], Polygon[Corner + 1] } do
					Count += 1
					table.move(Vertex, 1, 3, Count * 3 - 2, Positions)
					table.move(Vertex, 4, 7, Count * 4 - 3, Colors)
					-- a fold stays half a texel inside the texture: on its edge Roblox filters with the texels on the far side, which leaves a
					-- thin line along the fold
					UVs[Count * 2 - 1] = if FoldS then math.clamp(math.abs(Vertex[FieldS]), 0.5, Decoded.Width - 0.5) else Vertex[FieldS]
					UVs[Count * 2] = if FoldT then math.clamp(math.abs(Vertex[FieldT]), 0.5, Decoded.Height - 0.5) else Vertex[FieldT]
					table.insert(Indices, Count)
				end
			end
		end
	end

	Unfolded.Positions = Positions
	Unfolded.Colors = Colors
	Unfolded.UVs = UVs
	Unfolded.Indices = Indices
	Unfolded.Lights = {}
	Unfolded.VertexCount = Count

	return Unfolded
end

-- The editable mesh of a batch
-- Lift: how far, in model units, a vertex with a normal moves along it. A decal lies on the surface under it (the eyes on the face): the RDP
-- shows the decal, Roblox flickers between surfaces at one depth and hides one that lies a little under the other, so the decal is lifted off.
const function BuildMesh(Batch: Scene.Batch, Lift: number): (EditableMesh, Vector3, number)
	const Mesh = CreateMesh()
	const Positions = Batch.Positions
	const Normals = if Lift > 0 and #Batch.Normals == 0 then FaceNormals(Batch) else Batch.Normals
	const Colors = Batch.Colors
	const UVs = Batch.UVs
	const Decoded = Batch.Texture
	const Width = if Decoded then Decoded.Width else 1
	const Height = if Decoded then Decoded.Height else 1
	const Vertices: { number } = table.create(Batch.VertexCount, 0)
	const ColorIds: { number } = table.create(Batch.VertexCount, 0)
	const UvIds: { number } = table.create(Batch.VertexCount, 0)
	-- a blended batch has the alpha its combiner makes of the shade alpha and the constants (the red of an exclamation box is the environment
	-- alpha); an opaque draw ignores it in the RDP (the cap and the overalls of Mario have 0) and Roblox would show it as transparency
	const Program = Combiner.Compile(Batch.Combine)
	const TwoCycle = Batch.TwoCycle and Program.SecondCycle

	Combiner.SetConstants(Batch.PrimColor, Batch.EnvColor)

	-- the vertices, lifted, and the center of their box: the mesh is built around its own center, whatever the origin of the model is
	const Places: { vector } = {}
	local Low = vector.one * math.huge
	local High = -Low

	for Index = 1, Batch.VertexCount do
		const NormalX = Normals[Index * 3 - 2]
		const Moved = if NormalX ~= nil and Lift > 0 then vector.create(NormalX, Normals[Index * 3 - 1], Normals[Index * 3]) * Lift else vector.zero
		const Place = (vector.create(Positions[Index * 3 - 2], Positions[Index * 3 - 1], Positions[Index * 3]) + Moved) * UnitScale

		Places[Index] = Place
		Low = vector.min(Low, Place)
		High = vector.max(High, Place)
	end

	const Center = (Low + High) / 2
	local AlphaSum = 0

	for Index = 1, Batch.VertexCount do
		Vertices[Index] = Mesh:AddVertex(AsVector3(Places[Index] - Center))

		local Alpha = 1

		if Batch.Translucent then
			-- the texel is opaque here: a texture's own alpha is the SurfaceAppearance's
			Alpha = select(4, Combiner.Run(Program, TwoCycle, 1, 1, 1, 1, 1, 1, 1, Colors[Index * 4] / 255))
		end

		ColorIds[Index] = Mesh:AddColor(Color3.fromRGB(Level(Colors[Index * 4 - 3]), Level(Colors[Index * 4 - 2]), Level(Colors[Index * 4 - 1])), 1)
		AlphaSum += Alpha

		UvIds[Index] = Mesh:AddUV(Vector2.new(UVs[Index * 2 - 1] / Width, UVs[Index * 2] / Height))
	end

	const Normal = Mesh:AddNormal(Vector3.zAxis)
	const Indices = Batch.Indices

	for Triangle = 0, #Indices // 3 - 1 do
		const A = Indices[Triangle * 3 + 1]
		const B = Indices[Triangle * 3 + 2]
		const C = Indices[Triangle * 3 + 3]
		const Face = Mesh:AddTriangle(Vertices[A], Vertices[B], Vertices[C])

		Mesh:SetFaceColors(Face, { ColorIds[A], ColorIds[B], ColorIds[C] })
		Mesh:SetFaceUVs(Face, { UvIds[A], UvIds[B], UvIds[C] })
		Mesh:SetFaceNormals(Face, { Normal, Normal, Normal })
	end

	return Mesh, AsVector3(Center), AlphaSum / math.max(Batch.VertexCount, 1)
end

-- Roblox's fog for the fog of a list under a projection. The RSP fades a vertex by its depth after the projection, scaled to 0..1000 (s):
-- from position Min (no fog) to Max (all fog), the multiplier being 128000 / (Max - Min) and the offset (500 - Min) * 256 / (Max - Min);
-- for a perspective projection with near and far planes N and F, s / 1000 = F * (d - N) / (d * (F - N)) at the distance d, so the distance of a
-- position is d = F * N / (F - s * (F - N)).
const function SetFog(Fog: Fog?, Projection: Scene.Projection?)
	const Lit = game:GetService("Lighting")

	if Fog == nil or Projection == nil or not Projection.Perspective or Fog.Multiplier == 0 then
		Lit.FogEnd = 100000
		Lit.FogStart = 99999

		return
	end

	const Span = 128000 / Fog.Multiplier
	const Minimum = 500 - Fog.Offset * Span / 256
	const Maximum = Minimum + Span
	const Near = Projection.Near
	const Far = Projection.Far

	const function Distance(Position: number): number
		const Depth = math.clamp(Position / 1000, 0, 0.9999)

		return Far * Near / (Far - Depth * (Far - Near))
	end

	Lit.FogStart = Distance(Minimum) * UnitScale
	Lit.FogEnd = Distance(Maximum) * UnitScale
	Lit.FogColor = Color3.fromRGB(Level(Fog.Color[1]), Level(Fog.Color[2]), Level(Fog.Color[3]))
end

-- The piece of a batch (yields): a static part, or for a lit batch (Lit) the baked mesh
const function BuildPiece(Self: Presenter, Batch: Scene.Batch, Lit: boolean, Lift: number): Piece
	const Mesh, Center, MeanAlpha = BuildMesh(Batch, Lift)
	const Baked = Bake(Mesh)

	DestroyMesh(Mesh)

	-- a blended piece whose alpha is the environment alpha (255 when the list itself sets none) fades as the game changes that color
	const Fades = Batch.Translucent and Combiner.UsesEnvironmentAlpha(Batch.Combine) and Batch.EnvColor[4] == 255
	const Transparency = 1 - MeanAlpha * TextureOpacity(Batch)

	if Lit then
		return { Part = nil, Baked = Baked, Batch = Batch, Decoded = Batch.Texture, Alpha = Batch.Cutout or Batch.Translucent, Center = Center, Fades = Fades, Transparency = Transparency }
	end

	const Part = AssetService:CreateMeshPartAsync(Baked)

	Prepare(Part)

	if Batch.Texture ~= nil then
		Texturize(Self, Part, Batch.Texture, Batch.Cutout or Batch.Translucent)
	end

	Part.Transparency = Transparency

	return { Part = Part, Baked = nil, Batch = nil, Decoded = nil, Alpha = false, Center = Center, Fades = Fades, Transparency = Transparency }
end

-- Whether the combiner of a batch blends the texture over the shade by its own alpha ((TEXEL0 - SHADE) * TEXEL0_ALPHA + SHADE): the face of
-- Mario (the eyes, the mustache, the ear, the emblem of the cap) is drawn so, over the skin the shading gives
const function BlendsOverShade(Batch: Scene.Batch): boolean
	return Batch.Texture ~= nil and Batch.Combine[1] == Gbi.CcTexel0 and Batch.Combine[2] == Gbi.CcShade and Batch.Combine[3] == Gbi.CcTexel0Alpha and Batch.Combine[4] == Gbi.CcShade
end

-- The pieces of a batch (yields). A texture that clamps or mirrors is drawn by cutting the triangles at its edges (render/cut), as Roblox
-- only repeats. A batch that blends its texture over the shade is two pieces, as the old Roblox port draws such decals: the triangles
-- with the shade alone (lit as any), and the bare texture over them with the alpha cut. Show separates the coplanar meshes in depth.
const function BuildPieces(Self: Presenter, Original: Scene.Batch, Order: number, Rank: number): { Piece }
	const Batch = Cut(Original)
	-- an opaque piece of the first layer is not lifted: its edges meet the edges of its neighbors
	const Lift = if Batch.Layer <= 1 and not (Batch.Decal or Batch.Translucent or Batch.Cutout)
		then 0
		else math.min(Batch.Layer, MaximumLayer) * LayerLift
			+ math.min(Order, MaximumOrder) * OrderLift
			+ math.min(Rank, MaximumRank) * RankLift
			+ (if Batch.Decal or Batch.Translucent then BlendLift else 0)

	if not BlendsOverShade(Batch) then
		return { BuildPiece(Self, Batch, #Batch.Normals > 0, Lift) }
	end

	const Shade = table.clone(Batch)
	const Decal = table.clone(Batch)

	Shade.Texture = nil
	Decal.Cutout = true

	const Surface = BuildPiece(Self, Shade, #Batch.Normals > 0, Lift)
	const Overlay = BuildPiece(Self, Decal, false, Lift)

	Overlay.ShadeDecal = true

	return { Surface, Overlay }
end

-- The batches of one list that are drawn alike (the same texture, lit or not, blending) as one batch: a mesh per batch would be thousands of
-- meshes for a level
const function MergeBatches(Batches: { Scene.Batch }, KeepBlendedSeparate: boolean): { Scene.Batch }
	const Merged: { Scene.Batch } = {}
	const ByKey: { [string]: Scene.Batch } = {}
	const TextureIds: { [Texture.Texture]: number } = {}
	local NextTexture = 0

	for _, Batch in Batches do
		if #Batch.Indices == 0 then
			continue
		end

		-- Roblox sorts a transparent mesh by its part. Keep separate water surfaces at their own depths.
		if KeepBlendedSeparate and Batch.Translucent then
			table.insert(Merged, Batch)

			continue
		end

		local TextureId = 0

		if Batch.Texture ~= nil then
			TextureId = TextureIds[Batch.Texture] or NextTexture + 1

			if TextureIds[Batch.Texture] == nil then
				NextTexture += 1
				TextureIds[Batch.Texture] = TextureId
			end
		end

		const Key = `{TextureId}:{#Batch.Normals > 0}:{Batch.Translucent}:{Batch.Cutout}:{Batch.Decal}:{Batch.Layer}:{Batch.ClampS}:{Batch.ClampT}:{Batch.MirrorS}:{Batch.MirrorT}:{Batch.Combine[1]}{Batch.Combine[2]}{Batch.Combine[3]}{Batch.Combine[4]}`
		local Target = ByKey[Key]

		if Target == nil then
			Target = table.clone(Batch)
			Target.Positions = table.clone(Batch.Positions)
			Target.Colors = table.clone(Batch.Colors)
			Target.Normals = table.clone(Batch.Normals)
			Target.Lights = table.clone(Batch.Lights)
			Target.UVs = table.clone(Batch.UVs)
			Target.Indices = table.clone(Batch.Indices)
			ByKey[Key] = Target
			table.insert(Merged, Target)
		else
			const Offset = Target.VertexCount
			const Base = #Target.Indices

			table.move(Batch.Positions, 1, Batch.VertexCount * 3, Offset * 3 + 1, Target.Positions)
			table.move(Batch.Colors, 1, Batch.VertexCount * 4, Offset * 4 + 1, Target.Colors)
			table.move(Batch.Normals, 1, #Batch.Normals, Offset * 3 + 1, Target.Normals)
			table.move(Batch.UVs, 1, Batch.VertexCount * 2, Offset * 2 + 1, Target.UVs)

			for Index, Set in Batch.Lights do
				Target.Lights[Offset + Index] = Set
			end

			for Index, Vertex in Batch.Indices do
				Target.Indices[Base + Index] = Vertex + Offset
			end

			Target.VertexCount = Offset + Batch.VertexCount
		end
	end

	for Index, Batch in Merged do
		Merged[Index] = Unfold(Batch)
	end

	return Merged
end

-- Decodes a display list into the pieces of an entry, off the frame (yields)
const function Build(Self: Presenter, Entry: Entry, Address: number, Layer: number, Pass: Recorder.Pass)
	const Target = Scene.New(DefaultViewport)
	const Predecessor = Entry.Previous
	const State = if Predecessor ~= nil and Predecessor.EndState ~= nil then DisplayList.Fork(Predecessor.EndState, Target) else DisplayList.New(Target)
	const Generation = Self.Generation
	const Preloading = Self.Preloading

	if Preloading ~= nil then
		Preloading[coroutine.running()] = string.format("Decoding display list 0x%08X", Address)
	end

	State.Relight = true

	DisplayList.Draw(State, Address, Matrix.Identity(), Layer, Pass.ZBuffer, Pass.Projection)

	-- what the next list continues from, without the batches of this one
	State.Batch = nil
	State.Scene = Scene.New(DefaultViewport)
	Entry.EndState = State

	const Found = Shapes.Classify(Target.Batches)

	if Found ~= nil then
		Entry.Sprite = Found
		Entry.Ready = true

		return
	end

	for _, Merged in MergeBatches(Target.Batches, false) do
		if Preloading ~= nil then
			const Triangles = #Merged.Indices // 3
			const Unit = if Triangles == 1 then "triangle" else "triangles"

			Preloading[coroutine.running()] = string.format("Building mesh · %d %s · 0x%08X", Triangles, Unit, Address)
		end

		Cooperate(Self)

		const Made = BuildPieces(Self, Merged, #Entry.Pieces + 1, Entry.Rank)

		-- the entries were dropped while this one was building
		if Self.Generation ~= Generation then
			for _, Piece in Made do
				if Piece.Part ~= nil then
					Piece.Part:Destroy()
				end
			end

			return
		end

		for _, Piece in Made do
			table.insert(Entry.Pieces, Piece)
			Entry.HasLit = Entry.HasLit or Piece.Batch ~= nil
		end

		if Merged.Fog and Entry.Fog == nil then
			Entry.Fog = { Color = Merged.FogColor, Multiplier = Merged.FogMultiplier, Offset = Merged.FogOffset }
		end

		Self.Folder:SetAttribute("Vertices", ((Self.Folder:GetAttribute("Vertices") :: number?) or 0) + Merged.VertexCount)
	end

	Entry.Ready = true
end

-- Runs the waiting builds in a few tasks (a build yields; only a few EditableMeshes may exist at once)
const function Drain(Self: Presenter)
	while Self.Workers < MaximumWorkers and #Self.Queue > Self.Workers do
		Self.Workers += 1

		task.defer(function()
			while #Self.Queue > 0 do
				const Job = table.remove(Self.Queue, 1) :: () -> ()
				const Generation = Self.Generation

				Cooperate(Self)

				if Self.Generation == Generation then
					xpcall(Job, function(Message: unknown)
						task.defer(error, debug.traceback(tostring(Message), 2), 0)
					end)

					const Preloading = Self.Preloading

					if Preloading ~= nil then
						Preloading[coroutine.running()] = nil
					end
				end
			end

			Self.Workers -= 1
		end)
	end
end

-- The lit mesh of a draw of a lit piece (yields): a fixed-size mesh from the baked content, with the color id of every vertex of the batch
const function MakeLitMesh(Piece: Piece): (LitMesh, MeshPart)
	const Batch = Piece.Batch :: Scene.Batch
	const Mesh = CreateMeshFrom(Piece.Baked :: Content)
	const ColorIds: { number } = table.create(Batch.VertexCount, 0)
	const Indices = Batch.Indices

	-- the faces come in the order of the triangles and the colors of a face in the order of its corners
	for Triangle, Face in Mesh:GetFaces() do
		const FaceColors = Mesh:GetFaceColors(Face)

		for Corner = 1, 3 do
			ColorIds[Indices[(Triangle - 1) * 3 + Corner]] = FaceColors[Corner]
		end
	end

	const Sets: { Scene.LightSet } = {}
	const SetNumbers: { [Scene.LightSet]: number } = {}
	const SetOf: { number } = {}

	for Index, Set in Batch.Lights do
		local Number = SetNumbers[Set]

		if Number == nil then
			table.insert(Sets, Set)
			Number = #Sets
			SetNumbers[Set] = Number
		end

		SetOf[Index] = Number
	end

	return { Mesh = Mesh, Batch = Batch, ColorIds = ColorIds, Sets = Sets, SetOf = SetOf, Last = nil }, AssetService:CreateMeshPartAsync(Content.fromObject(Mesh))
end

-- Colors the vertices of a lit mesh as the RSP lights them under the matrix of the draw: the ambient light plus, for each directional
-- light, its color times the dot product of the vertex normal and the light direction in model space when that is positive
const function Relight(Lit: LitMesh, Mv: Matrix.Matrix)
	const Last = Lit.Last

	if Last ~= nil then
		local Same = true

		for Index, Entry in RotationEntries do
			if Last[Index] ~= Mv[Entry] then
				Same = false

				break
			end
		end

		if Same then
			return
		end
	end

	const Rotation = Last or table.create(#RotationEntries, 0)

	for Index, Entry in RotationEntries do
		Rotation[Index] = Mv[Entry]
	end

	Lit.Last = Rotation

	-- the direction of each directional light of each set in model space
	const Coefficients: { { number } } = {}

	for Number, Set in Lit.Sets do
		const Directions: { number } = {}

		for Index, Light in Set.Directional do
			Directions[Index * 3 - 2], Directions[Index * 3 - 1], Directions[Index * 3] = Matrix.LightCoefficient(Mv, Light.X, Light.Y, Light.Z)
		end

		Coefficients[Number] = Directions
	end

	const Normals = Lit.Batch.Normals
	const Mesh = Lit.Mesh

	for Index, Number in Lit.SetOf do
		const Set = Lit.Sets[Number]
		const Directions = Coefficients[Number]
		const NormalX = Normals[Index * 3 - 2]
		const NormalY = Normals[Index * 3 - 1]
		const NormalZ = Normals[Index * 3]
		const Ambient = Set.Ambient
		local R = if Ambient then Ambient.R else 255
		local G = if Ambient then Ambient.G else 255
		local B = if Ambient then Ambient.B else 255

		for Light, Directional in Set.Directional do
			const Intensity = NormalX * Directions[Light * 3 - 2] + NormalY * Directions[Light * 3 - 1] + NormalZ * Directions[Light * 3]

			if Intensity > 0 then
				R += Intensity * Directional.R
				G += Intensity * Directional.G
				B += Intensity * Directional.B
			end
		end

		Mesh:SetColor(Lit.ColorIds[Index], Color3.fromRGB(Level(math.min(R, 255)), Level(math.min(G, 255)), Level(math.min(B, 255))))
	end
end

-- Destroys the instances of an entry (the parts of its draws and the editable meshes of its lit ones, which hold budget); the entry keeps its
-- pieces and makes instances again when it is drawn
const function DestroyInstances(Entry: Entry)
	for _, Group in Entry.Instances do
		for _, Part in Group.Parts do
			Part:Destroy()
		end

		for _, Lit in Group.Lit do
			DestroyMesh(Lit.Mesh)
		end
	end

	Entry.Instances = {}

	if Entry.Painted ~= nil then
		Entry.Painted.Appearance:Destroy()
		Entry.Painted.Image:Destroy()
		Entry.Painted = nil
	end

	Entry.Pending = 0
	Entry.Used = 0
	Entry.Shown = 0
end

-- Destroys entries and their parts
const function DestroyEntries(Entries: { [string]: Entry })
	for _, Entry in Entries do
		for _, Piece in Entry.Pieces do
			if Piece.Part ~= nil then
				Piece.Part:Destroy()
			end
		end

		DestroyInstances(Entry)
	end
end

-- The CFrame and the scale of a modelview matrix (row vectors: the rows are the images of the axes, the last one the translation)
const function Place(Mv: Matrix.Matrix): (CFrame, Vector3)
	const Right = vector.create(Mv[1], Mv[2], Mv[3])
	const Up = vector.create(Mv[5], Mv[6], Mv[7])
	const Back = vector.create(Mv[9], Mv[10], Mv[11])
	const ScaleX = vector.magnitude(Right)
	const ScaleY = vector.magnitude(Up)
	const ScaleZ = vector.magnitude(Back)

	if ScaleX == 0 or ScaleY == 0 or ScaleZ == 0 then
		return HiddenPosition, AsVector3(vector.one)
	end

	return CFrame.fromMatrix(
		AsVector3(vector.create(Mv[13], Mv[14], Mv[15]) * UnitScale),
		AsVector3(Right / ScaleX),
		AsVector3(Up / ScaleY),
		AsVector3(Back / ScaleZ)
		), AsVector3(vector.create(ScaleX, ScaleY, ScaleZ))
end

-- The CFrame of the camera in the world from the camera matrix of a pass (row vectors: the world to the view space): the rows of the inverse
-- rotation are the world directions of the axes of the view space, and the origin of the view space is at minus the translation through it
const function CameraFrame(View: { number }): CFrame
	const Right = vector.create(View[1], View[5], View[9])
	const Up = vector.create(View[2], View[6], View[10])
	const Back = vector.create(View[3], View[7], View[11])

	return CFrame.fromMatrix(AsVector3(-(Right * View[13] + Up * View[14] + Back * View[15]) * UnitScale), AsVector3(Right), AsVector3(Up), AsVector3(Back))
end

-- Moves the parts of the instance to the matrix (of the view space the camera makes) and lights its lit meshes; a part already there stays
const function Show(Self: Presenter, Group: Group, Mv: Matrix.Matrix, Camera: CFrame, EnvAlpha: number, Lift: number)
	const Frame, Scale = Place(Mv)

	for Index, Part in Group.Parts do
		local Size = Group.Sizes[Index] * Scale
		local World = if Frame == HiddenPosition then HiddenPosition else Camera * Frame * CFrame.new(Group.Centers[Index] * Scale)

		if Frame ~= HiddenPosition then
			if Group.ShadeDecals[Index] then
				-- Move and shrink by the same factor about the camera. Each vertex stays on its original view ray.
				const Offset = World.Position - Camera.Position
				const Depth = Camera.LookVector:Dot(Offset)
				const Bias = math.clamp(Depth * ShadeDecalDepthFraction, MinimumShadeDecalBias, MaximumShadeDecalBias)

				if Depth > Bias then
					const Fraction = Bias / Depth

					World -= Offset * Fraction
					Size *= 1 - Fraction
				end
			end

			if Lift > 0 then
				World += AsVector3(vector.create(0, Lift, 0))
			end
		end

		if Part.Size ~= Size then
			Part.Size = Size
		end

		const FadeOpacity = Group.FadeOpacity[Index]

		if FadeOpacity ~= nil then
			const Transparency = 1 - FadeOpacity * EnvAlpha / 255

			if Part.Transparency ~= Transparency then
				Part.Transparency = Transparency
			end
		end

		if Group.Last[Index] ~= World then
			Group.Last[Index] = World
			table.insert(Self.Parts, Part)
			table.insert(Self.CFrames, World)
		end
	end

	for _, Lit in Group.Lit do
		Relight(Lit, Mv)
	end
end

-- A new draw of an entry: a clone of its static parts and, for each lit piece, a lit mesh and part of its own (yields)
const function MakeInstance(Self: Presenter, Entry: Entry): Group?
	const Generation = Self.Generation
	const Group = { Parts = {}, Sizes = {}, Centers = {}, FadeOpacity = {}, ShadeDecals = {}, Last = {}, Lit = {} } :: Group

	for _, Piece in Entry.Pieces do
		local Part: MeshPart

		if Piece.Part ~= nil then
			Part = Piece.Part:Clone() :: MeshPart
		else
			const Lit, Made = MakeLitMesh(Piece)

			Part = Made
			Prepare(Part)
			Part.Transparency = Piece.Transparency

			if Piece.Decoded ~= nil then
				Texturize(Self, Part, Piece.Decoded, Piece.Alpha)
			end

			Group.Lit[#Group.Parts + 1] = Lit
		end

		-- an instance made ahead of its first draw waits out of sight
		Part.CFrame = HiddenPosition
		Part.Parent = Self.Folder
		table.insert(Group.Parts, Part)
		table.insert(Group.Sizes, Part.Size)
		table.insert(Group.Centers, Piece.Center)

		if Piece.Fades then
			Group.FadeOpacity[#Group.Parts] = 1 - Piece.Transparency
		end

		if Piece.ShadeDecal then
			Group.ShadeDecals[#Group.Parts] = true
		end
	end

	-- the entries were dropped while this one was made
	if Self.Generation ~= Generation then
		for _, Part in Group.Parts do
			Part:Destroy()
		end

		for _, Lit in Group.Lit do
			DestroyMesh(Lit.Mesh)
		end

		return nil
	end

	return Group
end

-- Has a lit entry make another instance in the queue (its parts take a while to make: a part missing for a few frames flickers)
const function QueueInstance(Self: Presenter, Entry: Entry)
	Entry.Pending += 1

	const Generation = Self.Generation

	table.insert(Self.Queue, function()
		const Made = MakeInstance(Self, Entry)

		-- the instances were dropped with the level before, and the count with them
		if Self.Generation ~= Generation then
			return
		end

		Entry.Pending -= 1

		if Made ~= nil then
			table.insert(Entry.Instances, Made)
		end
	end)
	Drain(Self)
end

const function QueueSprite(Self: Presenter, Entry: Entry, Found: Shapes.Sprite)
	const Generation = Self.Generation

	Entry.Pending += 1
	table.insert(Self.Queue, function()
		const Painted = Sprites.Paint(Found)

		if Self.Generation ~= Generation then
			Painted.Appearance:Destroy()
			Painted.Image:Destroy()

			return
		end

		Entry.Painted = Painted
		Entry.Pending -= 1
	end)
	Drain(Self)
end

-- The entry of a list (made and queued to build the first time; yields in its build)
const function Request(Self: Presenter, Key: string, Address: number, Layer: number, Pass: Recorder.Pass, Previous: Entry?): Entry
	Self.Created += 1

	const Started = { Ready = false, Pieces = {}, HasLit = false, Rank = Self.Created, Layer = Layer, Level = Self.Level, Previous = Previous, EndState = nil, Instances = {}, Pending = 0, UseStamp = 0, Used = 0, Shown = 0 } :: Entry

	Self.Entries[Key] = Started
	table.insert(Self.Queue, function()
		Build(Self, Started, Address, Layer, Pass)
	end)
	Drain(Self)

	return Started
end

-- Destroys the meshes of lists the game rewrites every frame
const function DestroyDynamics(Dynamics: { Dynamic })
	for _, Dyn in Dynamics do
		if Dyn.Group ~= nil then
			for _, Part in Dyn.Group.Parts do
				Part:Destroy()
			end
		end

		for _, Made in Dyn.Meshes do
			DestroyMesh(Made.Mesh)
		end
	end
end

-- The number of a texture, for the signature of a list
const TextureNumbers: { [Texture.Texture]: number } = {}
local TextureCount = 0

const function SignatureOf(Batches: { Scene.Batch }): string
	const Parts: { string } = {}

	for _, Batch in Batches do
		local Number = 0

		if Batch.Texture ~= nil then
			Number = TextureNumbers[Batch.Texture] or TextureCount + 1

			if TextureNumbers[Batch.Texture] == nil then
				TextureCount += 1
				TextureNumbers[Batch.Texture] = Number
			end
		end

		table.insert(Parts, `{Batch.VertexCount}:{#Batch.Indices}:{Number}:{Batch.Translucent}:{Batch.Cutout}:{Batch.Layer}`)
	end

	return table.concat(Parts, "|")
end

-- Makes the meshes of a list (yields): each batch a fixed-size editable mesh from the baked one, and a part showing it
const function BuildDynamic(Self: Presenter, Dyn: Dynamic, Batches: { Scene.Batch }, Signature: string)
	const Generation = Self.Generation
	const Group = { Parts = {}, Sizes = {}, Centers = {}, FadeOpacity = {}, ShadeDecals = {}, Last = {}, Lit = {} } :: Group
	const Meshes: { DynamicMesh } = {}

	for _, Batch in Batches do
		Cooperate(Self)

		const Mesh, Center, MeanAlpha = BuildMesh(Batch, 0)
		const Baked = Bake(Mesh)

		DestroyMesh(Mesh)

		const Live = CreateMeshFrom(Baked)
		const VertexIds: { number } = {}
		const UvIds: { number } = {}
		const Indices = Batch.Indices

		-- the faces come in the order of the triangles and the corners of a face in the order of the indices
		for Triangle, Face in Live:GetFaces() do
			const FaceVertices = Live:GetFaceVertices(Face)
			const FaceUvs = Live:GetFaceUVs(Face)

			for Corner = 1, 3 do
				const Vertex = Indices[(Triangle - 1) * 3 + Corner]

				VertexIds[Vertex] = FaceVertices[Corner]
				UvIds[Vertex] = FaceUvs[Corner]
			end
		end

		const Part = AssetService:CreateMeshPartAsync(Content.fromObject(Live))
		const Opacity = TextureOpacity(Batch)

		Prepare(Part)

		if Batch.Texture ~= nil then
			Texturize(Self, Part, Batch.Texture, Batch.Cutout or Batch.Translucent)
		end

		Part.Transparency = 1 - MeanAlpha * Opacity

		Part.Parent = Self.Folder
		table.insert(Group.Parts, Part)
		table.insert(Group.Sizes, Part.Size)
		table.insert(Group.Centers, Center)
		table.insert(Meshes, {
			Mesh = Live,
			VertexIds = VertexIds,
			UvIds = UvIds,
			Indices = Batch.Indices,
			Positions = nil,
			UVs = nil,
			Center = Center,
			Width = if Batch.Texture then Batch.Texture.Width else 1,
			Height = if Batch.Texture then Batch.Texture.Height else 1,
			TextureOpacity = Opacity,
		})
	end

	-- the lists were dropped while these were made
	if Self.Generation ~= Generation or Dyn.Dropped then
		DestroyDynamics({ { Signature = "", Group = Group, Meshes = Meshes, Building = false, Dropped = true, Stamp = 0, Shadow = false } })

		return
	end

	Dyn.Group = Group
	Dyn.Meshes = Meshes
	Dyn.Signature = Signature
	Dyn.Building = false
end

-- The mean alpha a blended batch has (what BuildMesh gives its parts), from the alpha of its vertices and the combiner
const function MeanAlphaOf(Batch: Scene.Batch): number
	if not Batch.Translucent then
		return 1
	end

	const Program = Combiner.Compile(Batch.Combine)
	const TwoCycle = Batch.TwoCycle and Program.SecondCycle
	local Sum = 0

	Combiner.SetConstants(Batch.PrimColor, Batch.EnvColor)

	for Index = 1, Batch.VertexCount do
		Sum += select(4, Combiner.Run(Program, TwoCycle, 1, 1, 1, 1, 1, 1, 1, Batch.Colors[Index * 4] / 255))
	end

	return Sum / math.max(Batch.VertexCount, 1)
end

const function SameValues(Previous: { number }?, Current: { number }): boolean
	if Previous == Current then
		return true
	end

	if Previous == nil or #Previous ~= #Current then
		return false
	end

	for Index, Value in Current do
		if Previous[Index] ~= Value then
			return false
		end
	end

	return true
end

-- Moves the vertices and the texture coordinates of the meshes of a list to what the game wrote this frame. The mesh is built around the
-- center of its box and its part sits there (Roblox hides a part whose box is out of view, whatever its vertices are): the center moves with
-- the vertices, as a shadow that was first made high above the floor has to follow the floor
const function UpdateDynamic(Dyn: Dynamic, Batches: { Scene.Batch })
	for Index, Batch in Batches do
		const Made = Dyn.Meshes[Index]
		const Positions = Batch.Positions
		const UVs = Batch.UVs

		if not SameValues(Made.Positions, Positions) then
			local Low = vector.one * math.huge
			local High = -Low

			for Vertex = 1, Batch.VertexCount do
				const Place = vector.create(Positions[Vertex * 3 - 2], Positions[Vertex * 3 - 1], Positions[Vertex * 3]) * UnitScale

				Low = vector.min(Low, Place)
				High = vector.max(High, Place)
			end

			const Center = (Low + High) / 2

			Made.Center = AsVector3(Center)
			Made.Positions = Positions

			if Dyn.Group ~= nil then
				Dyn.Group.Centers[Index] = Made.Center
			end

			for Vertex = 1, Batch.VertexCount do
				const Place = vector.create(Positions[Vertex * 3 - 2], Positions[Vertex * 3 - 1], Positions[Vertex * 3]) * UnitScale

				Made.Mesh:SetPosition(Made.VertexIds[Vertex], AsVector3(Place - Center))
			end
		end

		const PreviousUVs = Made.UVs

		for Vertex = 1, Batch.VertexCount do
			const U = UVs[Vertex * 2 - 1]
			const V = UVs[Vertex * 2]

			if PreviousUVs == nil or PreviousUVs[Vertex * 2 - 1] ~= U or PreviousUVs[Vertex * 2] ~= V then
				Made.Mesh:SetUV(Made.UvIds[Vertex], Vector2.new(U / Made.Width, V / Made.Height))
			end
		end

		Made.UVs = UVs

		if Batch.Translucent and Dyn.Group ~= nil then
			const Part = Dyn.Group.Parts[Index]
			const Transparency = 1 - MeanAlphaOf(Batch) * Made.TextureOpacity

			if Part.Transparency ~= Transparency then
				Part.Transparency = Transparency
			end
		end
	end
end

-- Shows the batches of a list the game rewrites every frame, under the matrix Mv (Slot: its number among such lists): its meshes are updated
-- in place when they still fit the batches, made again when they do not
const function ShowBatches(Self: Presenter, Slot: number, Batches: { Scene.Batch }, Mv: Matrix.Matrix, EnvAlpha: number, Camera: CFrame, Shadow: boolean)
	local Found = Self.Dynamics[Slot]

	if Found == nil then
		const Made = { Signature = "", Group = nil, Meshes = {}, Building = false, Dropped = false, Stamp = 0, Shadow = Shadow } :: Dynamic

		Self.Dynamics[Slot] = Made
		Found = Made
	end

	const Dyn: Dynamic = Found

	if #Batches == 0 then
		return
	end

	Dyn.Stamp = Self.DynamicStamp

	const Signature = SignatureOf(Batches)
	local Matches = Dyn.Group ~= nil and Dyn.Signature == Signature

	if Matches then
		for Index, Batch in Batches do
			if not SameValues(Dyn.Meshes[Index].Indices, Batch.Indices) then
				Matches = false

				break
			end
		end
	end

	if Matches and Dyn.Group ~= nil then
		UpdateDynamic(Dyn, Batches)
		Show(Self, Dyn.Group, Mv, Camera, EnvAlpha, if Shadow then ShadowLift else 0)
	elseif not Dyn.Building then
		Dyn.Building = true

		-- the meshes that no longer fit go
		DestroyDynamics({ Dyn })
		Dyn.Group = nil
		Dyn.Meshes = {}
		table.insert(Self.Queue, function()
			BuildDynamic(Self, Dyn, Batches, Signature)
		end)
		Drain(Self)
	end
end

-- Shows a list of the pool the game rewrites every frame (water, mist, the ripple of a painting): decoded again from the pool
const function ShowDynamic(Self: Presenter, Draw: Flatten.Call, Pass: Recorder.Pass, Previous: Entry?, Slot: number, Camera: CFrame)
	const Target = Scene.New(DefaultViewport)
	const State = if Previous ~= nil and Previous.EndState ~= nil then DisplayList.Fork(Previous.EndState, Target) else DisplayList.New(Target)

	DisplayList.Draw(State, Draw.Address, Matrix.Identity(), Draw.Layer, Pass.ZBuffer, Pass.Projection)
	ShowBatches(Self, Slot, MergeBatches(Target.Batches, true), Draw.Mv, Draw.EnvAlpha, Camera, false)
end

-- Shows the blob shadow under an object. The game computes its vertices from the floor under the object every frame, so it is a dynamic
-- mesh like the water, put a little above the floor. A shadow takes the next mesh of its type (Counts: how many of each type the frame has
-- had): objects come and go in the order of the list of the game, and a mesh made for one shape has to be made again for another
const function ShowShadow(Self: Presenter, Shade: Recorder.Shadow, Pass: Recorder.Pass, Counts: { [number]: number }, Camera: CFrame)
	const Target = Scene.New(DefaultViewport)

	-- the vertices are relative to the position of the shadow, which the matrix of the shadow carries
	if AddShadow(DisplayList.New(Target), Shade, Pass.ZBuffer, Pass.Projection, Matrix.Identity()) then
		const Batches = MergeBatches(Target.Batches, false)

		if #Batches > 0 then
			const Number = (Counts[Shade.Type] or 0) + 1

			Counts[Shade.Type] = Number
			ShowBatches(Self, ShadowSlot + Shade.Type * ShadowsOfSize + Number, Batches, Shade.ModelView, 255, Camera, true)
		end
	end
end

-- Whether the game is in another level or area than the entries were made in
const function IsNewArea(Self: Presenter): boolean
	return Area.gCurrLevelNum ~= Self.Level or Area.gCurrAreaIndex ~= Self.AreaIndex
end

-- The areas of a level share its segments and entries. Other levels retain the pieces built in warm-up and release their instance meshes.
const function EnterArea(Self: Presenter)
	-- a list still being made for the area before is dropped when it is done
	for _, Dyn in Self.Dynamics do
		Dyn.Dropped = true
	end

	DestroyDynamics(Self.Dynamics)
	Self.Dynamics = {}

	if Area.gCurrLevelNum ~= Self.Level then
		const Doomed: { [string]: Entry } = {}

		for Key, Entry in Self.Entries do
			if not Self.Pinned[Entry.Level] then
				Doomed[Key] = Entry
				Self.Entries[Key] = nil
			end
		end

		-- the levels made ahead of time keep their baked pieces but not the editable meshes of their draws: a client has budget for those of one level
		for _, Entry in Self.Entries do
			if Entry.Level ~= Area.gCurrLevelNum then
				DestroyInstances(Entry)
			else
				Entry.Pending = 0
			end
		end

		DestroyEntries(Doomed)

		const SpriteTemplate = Self.Sprites.Template

		Sprites.Destroy(Self.Sprites)
		Self.Sprites = Sprites.New(Self.Folder, SpriteTemplate)
		table.clear(Self.Queue)
		Self.Generation += 1
		Self.StagedDemo = nil
	end

	Self.Level = Area.gCurrLevelNum
	Self.AreaIndex = Area.gCurrAreaIndex
	Self.Loading = true
end

-- Makes the entries of the lists a frame of the game draws, without showing them: the game is run through its menus before the player sees
-- anything. The decoded entries of these levels stay for the session.
const function Warm(Self: Presenter, Frame: Recorder.Frame, Demo: number?)
	Self.Pinned[Area.gCurrLevelNum] = true

	if IsNewArea(Self) then
		EnterArea(Self)
	end

	local Previous: Entry? = nil
	const Counts = if Demo ~= nil then {} :: { [Entry]: number } else nil

	for _, Pass in Frame.Passes do
		if PresentationSpace.ClassifyPass(Pass) ~= "world" then
			continue
		end

		for _, Draw in Flatten(Pass.Draws, false) do
			if Draw.Dynamic then
				continue
			end

			const Key = `{Self.Level}:{Rom.SegmentedToVirtual(Draw.Address)}:{Draw.Layer}:{if Pass.ZBuffer then 1 else 0}`

			const Entry = Self.Entries[Key] or Request(Self, Key, Draw.Address, Draw.Layer, Pass, Previous)

			if Counts ~= nil then
				Counts[Entry] = (Counts[Entry] or 0) + 1
			end

			Previous = Entry
		end
	end

	if Demo ~= nil and Counts ~= nil and next(Counts) ~= nil then
		const Plan = Self.DemoPlans[Demo] or {}

		for Entry, Count in Counts do
			Plan[Entry] = math.max(Plan[Entry] or 0, Count)
		end

		Self.DemoPlans[Demo] = Plan
	end
end

const function StageDemo(Self: Presenter, Demo: number)
	const Plan = Self.DemoPlans[Demo]

	if Plan == nil or Self.StagedDemo == Demo then
		return
	end

	Self.StagedDemo = Demo

	-- The title has no world instances in view, so release the previous scene's editable budget.
	for _, Entry in Self.Entries do
		if Entry.Level == Self.Level and Plan[Entry] == nil then
			DestroyInstances(Entry)
		end
	end

	for Entry, Count in Plan do
		if Entry.Sprite ~= nil then
			if Entry.Painted == nil and Entry.Pending == 0 then
				QueueSprite(Self, Entry, Entry.Sprite)
			end
		elseif Entry.HasLit then
			for _ = #Entry.Instances + Entry.Pending + 1, Count do
				QueueInstance(Self, Entry)
			end
		end
	end
end

-- Whether every build asked for is done
const function Idle(Self: Presenter): boolean
	return #Self.Queue == 0 and Self.Workers == 0
end

-- The builds that wait or run
const function Backlog(Self: Presenter): number
	return #Self.Queue + Self.Workers
end

const function PreloadAsset(Self: Presenter): string?
	const Preloading = Self.Preloading

	if Preloading ~= nil then
		const Worker = next(Preloading)

		return if Worker ~= nil then Preloading[Worker] else nil
	end

	return nil
end

-- Ends the warm-up: the game starts from its beginning, over the entries made
const function EndWarm(Self: Presenter)
	Self.Loading = false
	Self.Preloading = nil
end

-- Capture the calls of the next frame once, while its ROM and Gfx pool are still current.
const function Capture(Self: Presenter, Frame: Recorder.Frame)
	if IsNewArea(Self) then
		EnterArea(Self)
	end

	table.clear(Self.CallsByPass)
	table.clear(Self.PreparedEntries)
	table.clear(Self.DrawNumbers)
	table.clear(Self.UsedEntries)
	Self.UseStamp += 1

	local Previous: Entry? = nil

	for PassIndex, Pass in Frame.Passes do
		if PresentationSpace.ClassifyPass(Pass) ~= "world" then
			continue
		end

		const Calls = Flatten(Pass.Draws, true)

		Self.CallsByPass[PassIndex] = Calls

		for _, Draw in Calls do
			if Draw.Dynamic then
				continue
			end

			const Key = `{Self.Level}:{Rom.SegmentedToVirtual(Draw.Address)}:{Draw.Layer}:{if Pass.ZBuffer then 1 else 0}`
			const Entry = Self.Entries[Key] or Request(Self, Key, Draw.Address, Draw.Layer, Pass, Previous)

			if Entry.UseStamp ~= Self.UseStamp then
				Entry.UseStamp = Self.UseStamp
				Entry.Used = 0
				table.insert(Self.UsedEntries, Entry)
			end

			Entry.Used += 1
			Self.DrawNumbers[Draw] = Entry.Used
			Self.PreparedEntries[Draw] = Entry
			Previous = Entry
		end
	end
end

-- Prepare every instance the captured frame needs before replacing the current picture.
const function Ready(Self: Presenter): boolean
	local Waiting = 0

	for _, Entry in Self.UsedEntries do
		if not Entry.Ready then
			Waiting += Entry.Used
		elseif Entry.Sprite ~= nil then
			if Entry.Painted == nil then
				if Entry.Pending == 0 then
					QueueSprite(Self, Entry, Entry.Sprite)
				end

				Waiting += Entry.Used
			end
		else
			if Entry.HasLit then
				for _ = #Entry.Instances + Entry.Pending + 1, Entry.Used do
					QueueInstance(Self, Entry)
				end
			else
				for _ = #Entry.Instances + 1, Entry.Used do
					const Group = MakeInstance(Self, Entry)

					if Group ~= nil then
						table.insert(Entry.Instances, Group)
					end
				end
			end

			Waiting += math.max(Entry.Used - #Entry.Instances, 0)
		end
	end

	Self.Folder:SetAttribute("Waiting", Waiting)

	return Waiting == 0 or Idle(Self)
end

const function Present(Self: Presenter, Frame: Recorder.Frame)
	Self.Loading = false
	table.clear(Self.Parts)
	table.clear(Self.CFrames)
	Sprites.Begin(Self.Sprites)

	local Fov = 0
	-- where the camera of the game stands in the world: the parts are put in the world by it, and the Roblox camera is there
	local Pose = CFrame.identity

	Self.DynamicStamp += 1

	local Slot = 0
	const Shadows: { [number]: number } = {}
	local Focus = Pose

	for _, Pass in Frame.Passes do
		if Pass.View ~= nil then
			Pose = CameraFrame(Pass.View)

			const Background = Frame.Backgrounds[1]

			if Background ~= nil then
				const Target = Background.Focus
				const TargetPosition = vector.create(Target[1], Target[2], Target[3]) * UnitScale

				Focus = CFrame.new((TargetPosition :: unknown) :: Vector3)
			else
				Focus = Pose
			end

			break
		end
	end

	-- the entry of the draw before this one, which this one continues from
	local Previous: Entry? = nil
	local FogOfFrame: Fog? = nil
	local FogProjection: Scene.Projection? = nil

	for PassIndex, Pass in Frame.Passes do
		if Pass.Projection ~= nil and Pass.Projection.Perspective then
			Fov = Pass.Projection.Fov
		end

		if PresentationSpace.ClassifyPass(Pass) ~= "world" then
			continue
		end

		for _, Draw in Self.CallsByPass[PassIndex] do
			if Draw.Dynamic then
				Slot += 1
				ShowDynamic(Self, Draw, Pass, Previous, Slot, Pose)

				continue
			end

			const Entry = Self.PreparedEntries[Draw]

			if Entry.Ready then
				if Entry.Fog ~= nil then
					FogOfFrame = Entry.Fog
					FogProjection = Pass.Projection
				end

				const Mv = Draw.Mv

				if Entry.Sprite ~= nil then
					if Entry.Painted ~= nil then
						Sprites.Place(Self.Sprites, Entry.Sprite, Entry.Painted, Mv, Pose, Draw.EnvAlpha)
					end
				else
					const Group = Entry.Instances[Self.DrawNumbers[Draw]]

					if Group ~= nil then
						Show(Self, Group, Mv, Pose, Draw.EnvAlpha, 0)
					end
				end
			end

			Previous = Entry
		end

		for _, Shade in Pass.Shadows do
			ShowShadow(Self, Shade, Pass, Shadows, Pose)
		end
	end

	-- Instances shown last frame and not now go away
	for _, Entry in Self.ShownEntries do
		const Used = if Entry.UseStamp == Self.UseStamp then Entry.Used else 0

		for Index = Used + 1, Entry.Shown do
			const Group = Entry.Instances[Index]

			if Group ~= nil then
				for _, Part in Group.Parts do
					Part.CFrame = HiddenPosition
				end

				table.clear(Group.Last)
			end
		end

		Entry.Shown = 0
	end

	for _, Entry in Self.UsedEntries do
		Entry.Shown = math.min(Entry.Used, #Entry.Instances)
	end

	Self.UsedEntries, Self.ShownEntries = Self.ShownEntries, Self.UsedEntries

	workspace:BulkMoveTo(Self.Parts, Self.CFrames, Enum.BulkMoveMode.FireCFrameChanged)

	-- lists not drawn this frame go away
	for _, Dyn in Self.Dynamics do
		if Dyn.Stamp ~= Self.DynamicStamp and Dyn.Group ~= nil then
			for _, Part in Dyn.Group.Parts do
				Part.CFrame = HiddenPosition
			end

			table.clear(Dyn.Group.Last)
		end
	end

	Self.Folder:SetAttribute("Parts", #Self.Parts)
	Sprites.Flush(Self.Sprites)
	SetFog(FogOfFrame, FogProjection)

	-- the camera of the game
	const Camera = workspace.CurrentCamera :: Camera

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = Pose
	Camera.Focus = Focus

	if Fov > 0 then
		-- the game's field of view is that of the 4:3 area of the window (roblox/src/Overlay shows black bars around it); Roblox's is that of
		-- the whole window height
		const Window = Camera.ViewportSize
		const AreaHeight = math.min(Window.Y, Window.X * 3 / 4)

		Camera.FieldOfView = math.deg(2 * math.atan(math.tan(math.rad(Fov) / 2) * Window.Y / AreaHeight))
	end
end

return { New = New, Capture = Capture, Ready = Ready, Present = Present, Warm = Warm, StageDemo = StageDemo, Idle = Idle, Backlog = Backlog, PreloadAsset = PreloadAsset, EndWarm = EndWarm }
