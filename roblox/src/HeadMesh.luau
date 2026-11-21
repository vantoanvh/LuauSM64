--!strict
--!optimize 2
--!native

--[[
	Draws the scene engine's opaque head batches in the menu viewport. The game
	continues to supply the projection, topology, skin deformation and vertex lighting.
]]

const AssetService = game:GetService("AssetService")

const Combiner = require("../../render/combiner")
const Raster = require("../../render/raster")
const Scene = require("../../render/scene")

const FieldOfView = 45
const HalfHeight = math.tan(math.rad(FieldOfView) / 2)
const HalfWidth = HalfHeight * 4 / 3
const StudsPerUnit = 0.01

type Geometry = {
	Positions: { vector },
	Colors: { Color3 },
	Indices: { number },
	Near: { number },
	Far: { number },
}

type LiveMesh = {
	Mesh: EditableMesh,
	Part: MeshPart?,
	Vertices: { number },
	Colors: { number },
	Faces: { number },
	Indices: { number },
	LastPositions: { vector },
	LastColors: { Color3 },
	Center: vector,
}

export type HeadMesh = {
	Viewport: ViewportFrame,
	Geometry: Geometry,
	Live: LiveMesh?,
	Drawing: boolean,
	ClipInput: { number },
	ClipOutput: { number },
}

const function New(Parent: Frame): HeadMesh
	const Viewport = Instance.new("ViewportFrame")
	const Camera = Instance.new("Camera")

	Camera.CFrame = CFrame.identity
	Camera.FieldOfView = FieldOfView
	Camera.Parent = Viewport
	Viewport.Name = "HeadViewport"
	Viewport.Size = UDim2.fromScale(1, 1)
	Viewport.BackgroundTransparency = 1
	Viewport.Ambient = Color3.new(1, 1, 1)
	Viewport.LightColor = Color3.new(0, 0, 0)
	Viewport.CurrentCamera = Camera
	Viewport.ZIndex = 2
	Viewport.Visible = false
	Viewport.Parent = Parent

	return {
		Viewport = Viewport,
		Geometry = { Positions = {}, Colors = {}, Indices = {}, Near = {}, Far = {} },
		Live = nil,
		Drawing = false,
		ClipInput = {},
		ClipOutput = {},
	}
end

const function IsBody(Batch: Scene.Batch): boolean
	const Projection = Batch.Projection
	const Matrix = if Projection ~= nil then Projection.Matrix else nil

	return Matrix ~= nil and Matrix[12] ~= 0 and Batch.DepthCompare and Batch.DepthUpdate
		and not Batch.Cutout and not Batch.Translucent
end

const function AsVector3(Value: vector): Vector3
	return (Value :: unknown) :: Vector3
end

-- Convert the recorded homogeneous projection into the viewport camera's view space.
const function Project(Geometry: Geometry, Batch: Scene.Batch): boolean
	const Matrix = ((Batch.Projection :: Scene.Projection).Matrix :: { number })
	const Positions = Batch.Positions
	const Colors = Batch.Colors
	const UVs = Batch.UVs
	const Texture = Batch.Texture
	const Program = Combiner.Compile(Batch.Combine)
	const TwoCycle = Batch.TwoCycle and Program.SecondCycle
	local NeedsClip = false

	Combiner.SetConstants(Batch.PrimColor, Batch.EnvColor)

	for Index = 1, Batch.VertexCount do
		const X, Y, Z = Positions[Index * 3 - 2], Positions[Index * 3 - 1], Positions[Index * 3]
		const ClipX = X * Matrix[1] + Y * Matrix[5] + Z * Matrix[9] + Matrix[13]
		const ClipY = X * Matrix[2] + Y * Matrix[6] + Z * Matrix[10] + Matrix[14]
		const ClipZ = X * Matrix[3] + Y * Matrix[7] + Z * Matrix[11] + Matrix[15]
		const ClipW = X * Matrix[4] + Y * Matrix[8] + Z * Matrix[12] + Matrix[16]
		local TexelR, TexelG, TexelB, TexelA = 1, 1, 1, 1

		if Texture ~= nil then
			TexelR, TexelG, TexelB, TexelA = Raster.Sample(Texture, Batch, UVs[Index * 2 - 1], UVs[Index * 2])
		end

		const R, G, B = Combiner.Run(Program, TwoCycle, TexelR, TexelG, TexelB, TexelA, Colors[Index * 4 - 3] / 255, Colors[Index * 4 - 2] / 255, Colors[Index * 4 - 1] / 255, Colors[Index * 4] / 255)

		table.insert(Geometry.Positions, vector.create(ClipX * HalfWidth, ClipY * HalfHeight, -ClipW) * StudsPerUnit)
		table.insert(Geometry.Colors, Color3.new(R, G, B))
		table.insert(Geometry.Near, ClipW + ClipZ)
		table.insert(Geometry.Far, ClipW - ClipZ)
		NeedsClip = NeedsClip or ClipW < math.abs(ClipZ)
	end

	return NeedsClip
end

-- Clip against one homogeneous depth plane. Side planes are handled by the viewport.
const function Clip(Geometry: Geometry, Input: { number }, Output: { number }, Plane: { number })
	table.clear(Output)

	for Index, Current in Input do
		const Next = Input[Index % #Input + 1]
		const Distance = Plane[Current]
		const NextDistance = Plane[Next]

		if Distance >= 0 then
			table.insert(Output, Current)
		end

		if (Distance < 0 and NextDistance > 0) or (Distance > 0 and NextDistance < 0) then
			const Weight = Distance / (Distance - NextDistance)

			const Position = Geometry.Positions[Current]

			table.insert(Geometry.Positions, Position + (Geometry.Positions[Next] - Position) * Weight)
			table.insert(Geometry.Colors, Geometry.Colors[Current]:Lerp(Geometry.Colors[Next], Weight))
			table.insert(Geometry.Near, math.lerp(Geometry.Near[Current], Geometry.Near[Next], Weight))
			table.insert(Geometry.Far, math.lerp(Geometry.Far[Current], Geometry.Far[Next], Weight))
			table.insert(Output, #Geometry.Positions)
		end
	end
end

const function AddFaces(Self: HeadMesh, Batch: Scene.Batch, FirstVertex: number, NeedsClip: boolean)
	const Geometry = Self.Geometry
	const Input = Self.ClipInput
	const Output = Self.ClipOutput

	if Batch.CullFront and Batch.CullBack then
		return
	end

	if not NeedsClip and Batch.CullBack then
		for _, Vertex in Batch.Indices do
			table.insert(Geometry.Indices, FirstVertex + Vertex)
		end

		return
	end

	for Index = 1, #Batch.Indices, 3 do
		const A = FirstVertex + Batch.Indices[Index]
		const B = FirstVertex + Batch.Indices[Index + 1]
		const C = FirstVertex + Batch.Indices[Index + 2]

		if NeedsClip and (math.max(Geometry.Near[A], Geometry.Near[B], Geometry.Near[C]) < 0
			or math.max(Geometry.Far[A], Geometry.Far[B], Geometry.Far[C]) < 0) then
			continue
		end

		local Polygon = Input

		Input[1], Input[2], Input[3] = A, B, C

		if NeedsClip and math.min(Geometry.Near[A], Geometry.Near[B], Geometry.Near[C]) < 0 then
			Clip(Geometry, Input, Output, Geometry.Near)
			Polygon = Output
		end

		if NeedsClip and math.min(Geometry.Far[A], Geometry.Far[B], Geometry.Far[C]) < 0 then
			const Clipped = if Polygon == Input then Output else Input

			Clip(Geometry, Polygon, Clipped, Geometry.Far)
			Polygon = Clipped
		end

		for Corner = 2, #Polygon - 1 do
			const First, Second, Third = Polygon[1], Polygon[Corner], Polygon[Corner + 1]

			if not Batch.CullFront then
				table.insert(Geometry.Indices, First)
				table.insert(Geometry.Indices, Second)
				table.insert(Geometry.Indices, Third)
			end

			if not Batch.CullBack then
				table.insert(Geometry.Indices, First)
				table.insert(Geometry.Indices, Third)
				table.insert(Geometry.Indices, Second)
			end
		end

		-- Input can hold a clipped polygon when both planes cut a face.
		table.clear(Input)
	end
end

const function UpdateMesh(Live: LiveMesh, Geometry: Geometry)
	const Mesh = Live.Mesh
	const Indices = Geometry.Indices
	local Rebuild = #Live.Vertices ~= #Geometry.Positions or #Live.Indices ~= #Indices

	if not Rebuild then
		for Index, Vertex in Indices do
			if Live.Indices[Index] ~= Vertex then
				Rebuild = true

				break
			end
		end
	end

	local Low = vector.one * math.huge
	local High = -Low

	for _, Position in Geometry.Positions do
		Low = vector.min(Low, Position)
		High = vector.max(High, Position)
	end

	const Center = (Low + High) * 0.5

	if Rebuild then
		for _, Face in Live.Faces do
			Mesh:RemoveFace(Face)
		end

		Mesh:RemoveUnused()
		table.clear(Live.Vertices)
		table.clear(Live.Colors)
		table.clear(Live.Faces)
		table.clear(Live.LastPositions)
		table.clear(Live.LastColors)
		table.clear(Live.Indices)
		table.move(Indices, 1, #Indices, 1, Live.Indices)

		for Index, Position in Geometry.Positions do
			Live.Vertices[Index] = Mesh:AddVertex(AsVector3(Position - Center))
			Live.Colors[Index] = Mesh:AddColor(Geometry.Colors[Index], 1)
			Live.LastPositions[Index] = Position - Center
			Live.LastColors[Index] = Geometry.Colors[Index]
		end

		const Normal = Mesh:AddNormal(Vector3.zAxis)

		for Index = 1, #Indices, 3 do
			const A, B, C = Indices[Index], Indices[Index + 1], Indices[Index + 2]
			const Face = Mesh:AddTriangle(Live.Vertices[A], Live.Vertices[B], Live.Vertices[C])

			Mesh:SetFaceColors(Face, { Live.Colors[A], Live.Colors[B], Live.Colors[C] })
			Mesh:SetFaceNormals(Face, { Normal, Normal, Normal })
			table.insert(Live.Faces, Face)
		end
	else
		for Index, Position in Geometry.Positions do
			const LocalPosition = Position - Center
			const Color = Geometry.Colors[Index]

			if Live.LastPositions[Index] ~= LocalPosition then
				Mesh:SetPosition(Live.Vertices[Index], AsVector3(LocalPosition))
				Live.LastPositions[Index] = LocalPosition
			end

			if Live.LastColors[Index] ~= Color then
				Mesh:SetColor(Live.Colors[Index], Color)
				Live.LastColors[Index] = Color
			end
		end
	end

	Live.Center = Center

	if Live.Part ~= nil then
		Live.Part.CFrame = CFrame.new(AsVector3(Center))
	end
end

const function BuildPart(Self: HeadMesh, Live: LiveMesh)
	const Success, Result = pcall(function(): MeshPart
		return AssetService:CreateMeshPartAsync(Content.fromObject(Live.Mesh))
	end)

	if not Success then
		Live.Mesh:Destroy()

		if Self.Live == Live then
			Self.Live = nil
			warn(`Head viewport: {Result}`)
		end

		return
	end

	if Self.Live ~= Live then
		Result:Destroy()
		Live.Mesh:Destroy()

		return
	end

	Result.Name = "Head"
	Result.Anchored = true
	Result.CanCollide = false
	Result.CastShadow = false
	Result.CFrame = CFrame.new(AsVector3(Live.Center))
	Result.Color = Color3.new(1, 1, 1)
	Result.Parent = Self.Viewport
	Live.Part = Result
	Self.Viewport.Visible = Self.Drawing
end

const function Present(Self: HeadMesh, Batches: { Scene.Batch }, First: number, Last: number)
	const Live = Self.Live
	const Geometry = Self.Geometry

	if First == 0 then
		Self.Viewport.Visible = false
		Self.Drawing = false
		Self.Live = nil

		if Live ~= nil and Live.Part ~= nil then
			Live.Part:Destroy()
			Live.Mesh:Destroy()
		end

		return
	end

	table.clear(Geometry.Positions)
	table.clear(Geometry.Colors)
	table.clear(Geometry.Indices)
	table.clear(Geometry.Near)
	table.clear(Geometry.Far)

	for Index = First, Last do
		const Batch = Batches[Index]
		const FirstVertex = #Geometry.Positions

		const NeedsClip = Project(Geometry, Batch)

		AddFaces(Self, Batch, FirstVertex, NeedsClip)
	end

	Self.Drawing = #Geometry.Indices > 0
	Self.Viewport.Visible = Self.Drawing and Live ~= nil and Live.Part ~= nil

	if Live ~= nil then
		if Self.Drawing then
			UpdateMesh(Live, Geometry)
		end

		return
	end

	const Mesh = AssetService:CreateEditableMesh()

	if Mesh == nil then
		return
	end

	-- Build the hidden part while the head is still outside the intro's far plane.
	if not Self.Drawing then
		local FirstVertex = 0

		for Index = First, Last do
			const Batch = Batches[Index]

			AddFaces(Self, Batch, FirstVertex, false)
			FirstVertex += Batch.VertexCount
		end
	end

	const Created = {
		Mesh = Mesh,
		Part = nil,
		Vertices = {},
		Colors = {},
		Faces = {},
		Indices = {},
		LastPositions = {},
		LastColors = {},
		Center = vector.zero,
	} :: LiveMesh

	Self.Live = Created
	UpdateMesh(Created, Geometry)
	task.spawn(BuildPart, Self, Created)
end

return { New = New, IsBody = IsBody, Present = Present }
