--!strict
--!optimize 2

--[[
	Cuts the triangles of a batch where the texture addressing clamps or mirrors, so that a presenter whose textures only repeat (a Roblox
	MeshPart) draws the same picture.

	Paradigm
		The RDP clamps or mirrors the texture coordinate of each pixel. A mesh textured by a repeating texture cannot, and moving the
		coordinates of the corners of a triangle bends it. So a triangle that crosses an edge of the texture (0 or its size) is cut along the
		edge (the corners' attributes interpolate linearly, exactly as the hardware interpolates them) and each piece gets its own
		coordinates: a clamped piece outside the texture takes the coordinate of the edge texel along that axis (the other axis goes on as it
		was), a mirrored piece in an odd cell is reflected. A piece inside the texture is untouched.

	Design Notes
		The pieces do not share vertices: three new vertices per triangle. Only batches with a texture and a clamped or mirrored axis are cut.
		A texel is a unit of the coordinates of the batch; a clamped coordinate stops half a texel inside the edge, where a repeating texture
		samples the edge texel without reaching the other side. A span of more than MaximumCells mirrored cells is not cut.
]]

const Scene = require("./scene")

-- A corner while cutting: x y z, r g b a, nx ny nz, u v
const X, Y, Z, R, G, B, A, NX, NY, NZ, U, V = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
const FieldCount = 12
const MaximumCells = 16
const Epsilon = 1e-9

type Corner = { number }

const function Lerp(From: Corner, To: Corner, Fraction: number): Corner
	const Result = table.create(FieldCount, 0)

	for Field = 1, FieldCount do
		Result[Field] = From[Field] + (To[Field] - From[Field]) * Fraction
	end

	return Result
end

-- The part of the polygon where Field is at least Low (Keep above) or at most High
const function Clip(Polygon: { Corner }, Field: number, Limit: number, KeepAbove: boolean): { Corner }
	const Result: { Corner } = {}
	const Count = #Polygon

	for Index = 1, Count do
		const Current = Polygon[Index]
		const Next = Polygon[Index % Count + 1]
		const CurrentInside = if KeepAbove then Current[Field] >= Limit else Current[Field] <= Limit
		const NextInside = if KeepAbove then Next[Field] >= Limit else Next[Field] <= Limit

		if CurrentInside then
			table.insert(Result, table.clone(Current))
		end

		if CurrentInside ~= NextInside then
			table.insert(Result, Lerp(Current, Next, (Limit - Current[Field]) / (Next[Field] - Current[Field])))
		end
	end

	return Result
end

const function Range(Polygon: { Corner }, Field: number): (number, number)
	local Low, High = math.huge, -math.huge

	for _, Corner in Polygon do
		Low = math.min(Low, Corner[Field])
		High = math.max(High, Corner[Field])
	end

	return Low, High
end

-- The pieces of a polygon cut along one axis (Field U or V) of a texture Size texels wide on it: clamped, or mirrored
const function CutAxis(Polygon: { Corner }, Field: number, Size: number, Clamped: boolean, Pieces: { { Corner } })
	const Low, High = Range(Polygon, Field)

	-- the cells [Low, High] touches: for a clamp the outside below, the texture, the outside above
	local First, Last = 0, 0

	if Clamped then
		First = if Low < 0 then -1 else 0
		Last = if High > Size then 1 else 0
	else
		First = Low // Size
		Last = math.ceil(High / Size) - 1

		if Last - First + 1 > MaximumCells then
			table.insert(Pieces, Polygon)

			return
		end
	end

	if First == Last then
		-- one cell: only its transform (a clamped inside cell or an even mirrored one changes nothing)
		const Transformed: { Corner } = {}

		for _, Corner in Polygon do
			const Copy = table.clone(Corner)

			if Clamped then
				if First < 0 then
					Copy[Field] = 0.5
				elseif First > 0 then
					Copy[Field] = Size - 0.5
				end
			else
				Copy[Field] = if First % 2 == 0 then Copy[Field] - First * Size else (First + 1) * Size - Copy[Field]
			end

			table.insert(Transformed, Copy)
		end

		table.insert(Pieces, Transformed)

		return
	end

	for Cell = First, Last do
		local Piece = Polygon
		local From, To = Cell * Size, (Cell + 1) * Size

		if Clamped then
			From = if Cell < 0 then -math.huge elseif Cell == 0 then 0 else Size
			To = if Cell < 0 then 0 elseif Cell == 0 then Size else math.huge
		end

		if From > -math.huge then
			Piece = Clip(Piece, Field, From, true)
		end

		if To < math.huge and #Piece >= 3 then
			Piece = Clip(Piece, Field, To, false)
		end

		if #Piece < 3 then
			continue
		end

		const PieceLow, PieceHigh = Range(Piece, Field)

		-- a sliver on the edge of the cell has no area along this axis
		if PieceHigh - PieceLow < Epsilon and High - Low >= Epsilon then
			continue
		end

		for _, Corner in Piece do
			if Clamped then
				if Cell < 0 then
					Corner[Field] = 0.5
				elseif Cell > 0 then
					Corner[Field] = Size - 0.5
				end
			else
				Corner[Field] = if Cell % 2 == 0 then Corner[Field] - Cell * Size else (Cell + 1) * Size - Corner[Field]
			end
		end

		table.insert(Pieces, Piece)
	end
end

-- The batch with its triangles cut where its texture clamps or mirrors; the batch itself when it needs no cut
const function Cut(Batch: Scene.Batch): Scene.Batch
	const Texture = Batch.Texture

	if Texture == nil or not (Batch.ClampS or Batch.MirrorS or Batch.ClampT or Batch.MirrorT) then
		return Batch
	end

	const Lit = #Batch.Normals > 0
	const Result = table.clone(Batch)
	const Positions: { number } = {}
	const Colors: { number } = {}
	const Normals: { number } = {}
	const UVs: { number } = {}
	const Indices: { number } = {}
	const Lights: { [number]: Scene.LightSet } = {}
	local Count = 0

	for Triangle = 0, #Batch.Indices // 3 - 1 do
		const Polygon: { Corner } = {}
		local Set: Scene.LightSet? = nil

		for Corner = 1, 3 do
			const Vertex = Batch.Indices[Triangle * 3 + Corner]
			const Point = table.create(FieldCount, 0)

			Point[X], Point[Y], Point[Z] = Batch.Positions[Vertex * 3 - 2], Batch.Positions[Vertex * 3 - 1], Batch.Positions[Vertex * 3]
			Point[R], Point[G], Point[B], Point[A] = Batch.Colors[Vertex * 4 - 3], Batch.Colors[Vertex * 4 - 2], Batch.Colors[Vertex * 4 - 1], Batch.Colors[Vertex * 4]

			if Lit then
				Point[NX], Point[NY], Point[NZ] = Batch.Normals[Vertex * 3 - 2], Batch.Normals[Vertex * 3 - 1], Batch.Normals[Vertex * 3]
				Set = Set or Batch.Lights[Vertex]
			end

			Point[U], Point[V] = Batch.UVs[Vertex * 2 - 1], Batch.UVs[Vertex * 2]
			table.insert(Polygon, Point)
		end

		local Pieces = { Polygon }

		for _, Axis in { { U, Texture.Width, Batch.ClampS, Batch.MirrorS }, { V, Texture.Height, Batch.ClampT, Batch.MirrorT } } do
			if Axis[3] or Axis[4] then
				const Next: { { Corner } } = {}

				for _, Piece in Pieces do
					CutAxis(Piece, Axis[1] :: number, Axis[2] :: number, Axis[3] :: boolean, Next)
				end

				Pieces = Next
			end
		end

		for _, Piece in Pieces do
			for Fan = 2, #Piece - 1 do
				for _, Corner in { Piece[1], Piece[Fan], Piece[Fan + 1] } do
					Count += 1
					Positions[Count * 3 - 2], Positions[Count * 3 - 1], Positions[Count * 3] = Corner[X], Corner[Y], Corner[Z]
					Colors[Count * 4 - 3], Colors[Count * 4 - 2], Colors[Count * 4 - 1], Colors[Count * 4] = Corner[R], Corner[G], Corner[B], Corner[A]
					UVs[Count * 2 - 1], UVs[Count * 2] = Corner[U], Corner[V]
					Indices[Count] = Count

					if Lit then
						Normals[Count * 3 - 2], Normals[Count * 3 - 1], Normals[Count * 3] = Corner[NX], Corner[NY], Corner[NZ]
						Lights[Count] = Set :: Scene.LightSet
					end
				end
			end
		end
	end

	Result.Positions = Positions
	Result.Colors = Colors
	Result.Normals = Normals
	Result.UVs = UVs
	Result.Indices = Indices
	Result.Lights = Lights
	Result.VertexCount = Count

	return Result
end

return Cut
