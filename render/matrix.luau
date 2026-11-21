--!strict
--!optimize 2

--[[
	4x4 matrices of the renderer: a flat array of 16 numbers, row major (index row * 4 + column + 1), used on row vectors
	(v' = v * M) as the N64 does, so a translation is in the last row.
]]

export type Matrix = { number }

const function Identity(): Matrix
	return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
end

-- A Mtx of 16 s32 words (guMtxF2L: 8 words of the integer parts, then 8 of the fractions); Words is 1-based
const function FromFixed(Words: { number }): Matrix
	const Result = table.create(16, 0)

	for Row = 0, 3 do
		for Pair = 0, 1 do
			const Whole = Words[Row * 2 + Pair + 1]
			const Fraction = Words[Row * 2 + Pair + 9]
			const High = bit32.rshift(bit32.band(Whole, 0xFFFF0000), 16)
			const Low = bit32.band(Whole, 0xFFFF)

			Result[Row * 4 + Pair * 2 + 1] = (if High >= 0x8000 then High - 0x10000 else High) + bit32.rshift(bit32.band(Fraction, 0xFFFF0000), 16) / 65536
			Result[Row * 4 + Pair * 2 + 2] = (if Low >= 0x8000 then Low - 0x10000 else Low) + bit32.band(Fraction, 0xFFFF) / 65536
		end
	end

	return Result
end

-- The light direction (X, Y, Z: the signed bytes of the light) in the space of the vertex normals of a draw: the transpose of the
-- modelview 3x3 applied to it, normalized (gfx_pc.c does the same; the RSP microcode lights in model space)
const function LightCoefficient(Mv: Matrix, X: number, Y: number, Z: number): (number, number, number)
	const DirX = X / 127
	const DirY = Y / 127
	const DirZ = Z / 127
	const A = DirX * Mv[1] + DirY * Mv[2] + DirZ * Mv[3]
	const B = DirX * Mv[5] + DirY * Mv[6] + DirZ * Mv[7]
	const C = DirX * Mv[9] + DirY * Mv[10] + DirZ * Mv[11]
	const Length = math.sqrt(A * A + B * B + C * C)

	if Length == 0 then
		return 0, 0, 0
	end

	return A / Length, B / Length, C / Length
end

-- A * B (apply A first)
const function Multiply(A: Matrix, B: Matrix): Matrix
	const Result = table.create(16, 0)

	for Row = 0, 3 do
		for Column = 1, 4 do
			Result[Row * 4 + Column] = A[Row * 4 + 1] * B[Column] + A[Row * 4 + 2] * B[4 + Column] + A[Row * 4 + 3] * B[8 + Column] + A[Row * 4 + 4] * B[12 + Column]
		end
	end

	return Result
end

-- guPerspectiveF with the scale of 1: Fov in degrees
const function Perspective(Fov: number, Aspect: number, Near: number, Far: number): Matrix
	const Cotangent = 1 / math.tan(math.rad(Fov) / 2)

	return {
		Cotangent / Aspect, 0, 0, 0,
		0, Cotangent, 0, 0,
		0, 0, (Near + Far) / (Near - Far), -1,
		0, 0, 2 * Near * Far / (Near - Far), 0,
	}
end

-- guOrthoF with the scale of 1
const function Ortho(Left: number, Right: number, Bottom: number, Top: number, Near: number, Far: number): Matrix
	return {
		2 / (Right - Left), 0, 0, 0,
		0, 2 / (Top - Bottom), 0, 0,
		0, 0, -2 / (Far - Near), 0,
		-(Right + Left) / (Right - Left), -(Top + Bottom) / (Top - Bottom), -(Far + Near) / (Far - Near), 1,
	}
end

return { Identity = Identity, FromFixed = FromFixed, Multiply = Multiply, LightCoefficient = LightCoefficient, Perspective = Perspective, Ortho = Ortho }
