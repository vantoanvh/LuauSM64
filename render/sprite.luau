--!strict
--!optimize 2

--[[
	Billboards, particles and shadows as sprites: a display list whose triangles all lie in one plane and that draws a texture with blending or
	an alpha cut (the trees, the dust and sparkle particles, the shadows) is painted once into an image, as the RDP would draw it, and a
	presenter shows that image on a quad.

	Paradigm
		Classify finds the plane of the triangles (model space) and the rectangle they cover in it. Paint draws the triangles into a
		framebuffer of that rectangle with the software rasterizer, which does what the RDP does per pixel (the texture addressing, the
		three point filter, the combiner, the alpha cut), with an orthographic view along the plane normal, so the image is exactly what the
		list shows face on. Every pixel the lists leave empty stays transparent.

	Design Notes
		Only draws on the alpha and transparent layers (4 and up) and decal draws are classified: opaque coplanar geometry (a flat floor) is
		the level's, not a sprite. A sprite has at most MaximumTriangles triangles, so that the quads stay what they are. The image has two
		pixels for each texel the coordinates span, at most MaximumSide on a side.
]]

const Matrix = require("./matrix")
const Raster = require("./raster")
const Scene = require("./scene")

export type Sprite = {
	Batches: { Scene.Batch },
	-- The plane in model space: a point, the unit axes of the image (U to the right, V up) and the normal
	Origin: { number },
	AxisU: { number },
	AxisV: { number },
	Normal: { number },
	-- The rectangle the triangles cover in the plane, along the axes from the origin
	MinU: number,
	MaxU: number,
	MinV: number,
	MaxV: number,
	-- The image size in pixels
	Width: number,
	Height: number,
}

-- The plane of a list: a point of it, its normal and the unit direction of its first edge
type Plane = { Origin: { number }, Normal: { number }, Edge: { number } }

const MaximumTriangles = 16
const MaximumSide = 256
const MinimumSide = 8
const PixelsPerTexel = 2
const FirstOpaqueLayer = 4
const PlaneTolerance = 0.5

const function Cross(A: { number }, B: { number }): { number }
	return { A[2] * B[3] - A[3] * B[2], A[3] * B[1] - A[1] * B[3], A[1] * B[2] - A[2] * B[1] }
end

const function Normalize(A: { number }): { number }?
	const Length = math.sqrt(A[1] * A[1] + A[2] * A[2] + A[3] * A[3])

	if Length < 1e-9 then
		return nil
	end

	return { A[1] / Length, A[2] / Length, A[3] / Length }
end

const function Dot(A: { number }, B: { number }): number
	return A[1] * B[1] + A[2] * B[2] + A[3] * B[3]
end

-- The plane of the first triangle that has an area: a point of it, its normal and the unit direction of its first edge
const function FindPlane(Batches: { Scene.Batch }): Plane?
	for _, Batch in Batches do
		for Triangle = 0, #Batch.Indices // 3 - 1 do
			const A = Batch.Indices[Triangle * 3 + 1]
			const B = Batch.Indices[Triangle * 3 + 2]
			const C = Batch.Indices[Triangle * 3 + 3]
			const P = { Batch.Positions[A * 3 - 2], Batch.Positions[A * 3 - 1], Batch.Positions[A * 3] }
			const First = { Batch.Positions[B * 3 - 2] - P[1], Batch.Positions[B * 3 - 1] - P[2], Batch.Positions[B * 3] - P[3] }
			const Second = { Batch.Positions[C * 3 - 2] - P[1], Batch.Positions[C * 3 - 1] - P[2], Batch.Positions[C * 3] - P[3] }
			const Direction = Normalize(Cross(First, Second))
			const Edge = Normalize(First)

			if Direction ~= nil and Edge ~= nil then
				return { Origin = P, Normal = Direction, Edge = Edge }
			end
		end
	end

	return nil
end

-- The sprite a list draws, or nil when it is anything else
const function Classify(Batches: { Scene.Batch }): Sprite?
	local Triangles = 0
	local Qualifies = false

	for _, Batch in Batches do
		if #Batch.Indices > 0 then
			Triangles += #Batch.Indices // 3

			if Batch.Texture == nil or Triangles > MaximumTriangles then
				return nil
			end

			if Batch.Layer >= FirstOpaqueLayer or Batch.Decal then
				Qualifies = true
			end
		end
	end

	if Triangles == 0 or not Qualifies then
		return nil
	end

	const Plane = FindPlane(Batches)

	if Plane == nil then
		return nil
	end

	const Origin = Plane.Origin
	const Normal = Plane.Normal
	const AxisU = Plane.Edge

	const AxisV = Cross(Normal, AxisU)
	local MinU: number = math.huge
	local MaxU: number = -math.huge
	local MinV: number = math.huge
	local MaxV: number = -math.huge
	local MinTexelU: number = math.huge
	local MaxTexelU: number = -math.huge

	for _, Batch in Batches do
		for Vertex = 1, Batch.VertexCount do
			const Offset = { Batch.Positions[Vertex * 3 - 2] - Origin[1], Batch.Positions[Vertex * 3 - 1] - Origin[2], Batch.Positions[Vertex * 3] - Origin[3] }

			if math.abs(Dot(Offset, Normal)) > PlaneTolerance then
				return nil
			end

			const U = Dot(Offset, AxisU)
			const V = Dot(Offset, AxisV)

			MinU = math.min(MinU, U)
			MaxU = math.max(MaxU, U)
			MinV = math.min(MinV, V)
			MaxV = math.max(MaxV, V)
			MinTexelU = math.min(MinTexelU, Batch.UVs[Vertex * 2 - 1])
			MaxTexelU = math.max(MaxTexelU, Batch.UVs[Vertex * 2 - 1])
		end
	end

	const WidthUnits = MaxU - MinU
	const HeightUnits = MaxV - MinV

	if WidthUnits < 1e-6 or HeightUnits < 1e-6 then
		return nil
	end

	const Width = math.clamp(math.round((MaxTexelU - MinTexelU) * PixelsPerTexel), MinimumSide, MaximumSide)
	const Height = math.clamp(math.round(Width * HeightUnits / WidthUnits), MinimumSide, MaximumSide)

	return {
		Batches = Batches,
		Origin = Origin,
		AxisU = AxisU,
		AxisV = AxisV,
		Normal = Normal,
		MinU = MinU,
		MaxU = MaxU,
		MinV = MinV,
		MaxV = MaxV,
		Width = Width,
		Height = Height,
	}
end

-- The RGBA pixels (row after row from the top, 4 bytes each) of the sprite
const function Paint(Sprite: Sprite): buffer
	const Target = Raster.NewSprite(Sprite.Width, Sprite.Height)
	const WidthUnits = Sprite.MaxU - Sprite.MinU
	const HeightUnits = Sprite.MaxV - Sprite.MinV
	-- orthographic: the rectangle fills the framebuffer, the plane is at depth 0 (clip z 0, w 1)
	const Projection = Matrix.Identity()

	Projection[1] = 2 / WidthUnits
	Projection[13] = -(Sprite.MinU + Sprite.MaxU) / WidthUnits
	Projection[6] = 2 / HeightUnits
	Projection[14] = -(Sprite.MinV + Sprite.MaxV) / HeightUnits
	Projection[11] = 0
	Projection[16] = 1

	const Center = { Sprite.Width / 2, Sprite.Height / 2, Sprite.Width / 2, Sprite.Height / 2 }

	for _, Batch in Sprite.Batches do
		if #Batch.Indices == 0 then
			continue
		end

		const Flat = table.clone(Batch)
		const Positions: { number } = table.create(Batch.VertexCount * 3, 0)

		for Vertex = 1, Batch.VertexCount do
			const Offset = {
				Batch.Positions[Vertex * 3 - 2] - Sprite.Origin[1],
				Batch.Positions[Vertex * 3 - 1] - Sprite.Origin[2],
				Batch.Positions[Vertex * 3] - Sprite.Origin[3],
			}

			Positions[Vertex * 3 - 2] = Dot(Offset, Sprite.AxisU)
			Positions[Vertex * 3 - 1] = Dot(Offset, Sprite.AxisV)
			Positions[Vertex * 3] = 0
		end

		Flat.Positions = Positions
		Flat.CullBack = false
		Flat.CullFront = false
		Flat.DepthCompare = false
		Flat.DepthUpdate = false
		Flat.Decal = false
		Flat.Fog = false
		Raster.DrawBatch(Target, Flat, Projection, Center)
	end

	return Target.Color
end

return { Classify = Classify, Paint = Paint }
