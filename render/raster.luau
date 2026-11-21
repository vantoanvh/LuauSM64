--!strict
--!optimize 2
--!native

--[[
	Software rasterizer: draws the batches of a Scene into an RGBA8 framebuffer with a depth buffer.

	Paradigm
		Per batch: project the view space vertices (clip space), then per triangle clip against the near plane, cull, and fill
		by edge functions over the covered span of each row. Shade colors and depth interpolate linearly in screen space, texture
		coordinates perspective correct, as the RDP does. The color combiner (combiner.luau) and the blender of the batch decide
		the pixel.

	Design Notes
		The screen is the 320x240 of the N64 scaled by Width / 320. A scratch set of vertex tables is reused for every triangle.
		Not done: coverage anti-aliasing, the second texture, LOD, the blender modes other than opaque, cutout and alpha blend,
		fog by the vertex alpha.
]]

const Combiner = require("./combiner")
const Scene = require("./scene")
const Texture = require("./texture")

const Operation = Combiner.Operation

-- StoreAlpha keeps the result of blending over a transparent framebuffer as straight RGBA.
export type Framebuffer = { Width: number, Height: number, Color: buffer, Depth: { number }, StoreAlpha: boolean }

-- Pixel bounds with an exclusive right and bottom edge.
export type Bounds = { Left: number, Top: number, Right: number, Bottom: number }

-- Scratch vertex: clip x y z w, r g b a (0..1), u v (texels), fog
type Vertex = { number }

const NearEpsilon = 1e-6
const DecalBias = 0.0003
const CutoutAlpha = 0.5
const ClippedMax = 4
const ClearDepth = 2
-- Clip space vertex fields: x y z w, r g b a, u v, fog
const CX, CY, CZ, CW, CR, CG, CB, CA, CU, CV, CF = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
-- Screen vertex fields (the same tables): x y ndc-z 1/w, r g b a, u/w v/w, fog
const SX, SY, SZ, SIW, SR, SG, SB, SA, SU, SV, SF = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
const FieldCount = 11

const function NewVertex(): Vertex
	return table.create(FieldCount, 0)
end

const Source = { NewVertex(), NewVertex(), NewVertex() }
const Clipped = { NewVertex(), NewVertex(), NewVertex(), NewVertex() }
const Screen = { NewVertex(), NewVertex(), NewVertex(), NewVertex() }

const function New(Width: number, Height: number): Framebuffer
	return { Width = Width, Height = Height, Color = buffer.create(Width * Height * 4), Depth = table.create(Width * Height, ClearDepth), StoreAlpha = false }
end

-- A framebuffer for painting a sprite: every pixel transparent, and the alpha of what is drawn is stored in it
const function NewSprite(Width: number, Height: number): Framebuffer
	return { Width = Width, Height = Height, Color = buffer.create(Width * Height * 4), Depth = table.create(Width * Height, ClearDepth), StoreAlpha = true }
end

-- Makes every pixel of a sprite framebuffer transparent again
const function ClearSprite(Target: Framebuffer, ResetDepth: boolean)
	buffer.fill(Target.Color, 0, 0)

	if ResetDepth then
		for Index = 1, Target.Width * Target.Height do
			Target.Depth[Index] = ClearDepth
		end
	end
end

const function Clear(Target: Framebuffer, R: number, G: number, B: number)
	const Packed = R + bit32.lshift(G, 8) + bit32.lshift(B, 16) + bit32.lshift(255, 24)

	for Index = 0, Target.Width * Target.Height - 1 do
		buffer.writeu32(Target.Color, Index * 4, Packed)
		Target.Depth[Index + 1] = ClearDepth
	end
end

-- The wrapped texel index along an axis
const function Wrap(Index: number, Size: number, Mask: number, Mirror: boolean, Clamp: boolean): number
	if Clamp then
		return if Index < 0 then 0 elseif Index >= Size then Size - 1 else Index
	end

	const Period = if Mask > 0 then bit32.lshift(1, Mask) else Size

	if Mirror then
		local Folded = Index % (Period * 2)

		if Folded >= Period then
			Folded = Period * 2 - 1 - Folded
		end

		return if Folded >= Size then Size - 1 else Folded
	end

	const Wrapped = Index % Period

	return if Wrapped >= Size then Size - 1 else Wrapped
end

-- Samples the texture at texel coordinates (0..1 channels): the N64 three point filter, or the nearest texel
const function Sample(Image: Texture.Texture, Batch: Scene.Batch, U: number, V: number): (number, number, number, number)
	const Pixels = Image.Pixels
	const Width = Image.Width
	const Height = Image.Height

	if not Batch.Filtered then
		const Column = Wrap(U // 1, Width, Batch.MaskS, Batch.MirrorS, Batch.ClampS)
		const Row = Wrap(V // 1, Height, Batch.MaskT, Batch.MirrorT, Batch.ClampT)
		const Texel = buffer.readu32(Pixels, (Row * Width + Column) * 4)

		return bit32.band(Texel, 255) / 255, bit32.band(bit32.rshift(Texel, 8), 255) / 255, bit32.band(bit32.rshift(Texel, 16), 255) / 255, bit32.rshift(Texel, 24) / 255
	end

	const ShiftedU = U - 0.5
	const ShiftedV = V - 0.5
	const X = ShiftedU // 1
	const Y = ShiftedV // 1
	const FractionX = ShiftedU - X
	const FractionY = ShiftedV - Y
	const Left = Wrap(X, Width, Batch.MaskS, Batch.MirrorS, Batch.ClampS)
	const Right = Wrap(X + 1, Width, Batch.MaskS, Batch.MirrorS, Batch.ClampS)
	const Top = Wrap(Y, Height, Batch.MaskT, Batch.MirrorT, Batch.ClampT) * Width
	const Bottom = Wrap(Y + 1, Height, Batch.MaskT, Batch.MirrorT, Batch.ClampT) * Width
	const Next = buffer.readu32(Pixels, (Top + Right) * 4)
	const Below = buffer.readu32(Pixels, (Bottom + Left) * 4)
	local Base: number
	local WeightNext: number
	local WeightBelow: number
	local WeightBase: number

	if FractionX + FractionY < 1 then
		Base = buffer.readu32(Pixels, (Top + Left) * 4)
		WeightBase = 1 - FractionX - FractionY
		WeightNext = FractionX
		WeightBelow = FractionY
	else
		Base = buffer.readu32(Pixels, (Bottom + Right) * 4)
		WeightBase = FractionX + FractionY - 1
		WeightNext = 1 - FractionY
		WeightBelow = 1 - FractionX
	end

	const Scale = 1 / 255

	return (bit32.band(Base, 255) * WeightBase + bit32.band(Next, 255) * WeightNext + bit32.band(Below, 255) * WeightBelow) * Scale,
		(bit32.band(bit32.rshift(Base, 8), 255) * WeightBase + bit32.band(bit32.rshift(Next, 8), 255) * WeightNext + bit32.band(bit32.rshift(Below, 8), 255) * WeightBelow) * Scale,
		(bit32.band(bit32.rshift(Base, 16), 255) * WeightBase + bit32.band(bit32.rshift(Next, 16), 255) * WeightNext + bit32.band(bit32.rshift(Below, 16), 255) * WeightBelow) * Scale,
		(bit32.rshift(Base, 24) * WeightBase + bit32.rshift(Next, 24) * WeightNext + bit32.rshift(Below, 24) * WeightBelow) * Scale
end

-- Fills one screen space triangle with the state of the batch
const function Fill(Target: Framebuffer, Batch: Scene.Batch, A: Vertex, B: Vertex, C: Vertex, Program: Combiner.Program, Bounds: Bounds?)
	const Width = Target.Width
	const Height = Target.Height
	const Area = (B[SX] - A[SX]) * (C[SY] - A[SY]) - (C[SX] - A[SX]) * (B[SY] - A[SY])

	if Area == 0 then
		return
	end

	-- Front faces are counter clockwise in NDC, clockwise on the screen (y down): a negative area
	if (Area < 0 and Batch.CullFront) or (Area > 0 and Batch.CullBack) then
		return
	end

	const MinX = math.max(math.min(A[SX], B[SX], C[SX]) // 1, 0)
	const MaxX = math.min(-(-math.max(A[SX], B[SX], C[SX]) // 1), Width - 1)
	const MinY = math.max(math.min(A[SY], B[SY], C[SY]) // 1, 0)
	const MaxY = math.min(-(-math.max(A[SY], B[SY], C[SY]) // 1), Height - 1)

	if MinX > MaxX or MinY > MaxY then
		return
	end

	if Bounds ~= nil then
		Bounds.Left = math.min(Bounds.Left, MinX)
		Bounds.Top = math.min(Bounds.Top, MinY)
		Bounds.Right = math.max(Bounds.Right, MaxX + 1)
		Bounds.Bottom = math.max(Bounds.Bottom, MaxY + 1)
	end

	const InverseArea = 1 / Area
	-- Edge function steps: the weight of A is the edge BC, of B the edge CA, of C the edge AB
	const StepAX = -(C[SY] - B[SY]) * InverseArea
	const StepAY = (C[SX] - B[SX]) * InverseArea
	const StepBX = -(A[SY] - C[SY]) * InverseArea
	const StepBY = (A[SX] - C[SX]) * InverseArea
	const StepCX = -(B[SY] - A[SY]) * InverseArea
	const StepCY = (B[SX] - A[SX]) * InverseArea
	const Color = Target.Color
	const Depth = Target.Depth
	const Image = Batch.Texture
	const DepthCompare = Batch.DepthCompare
	const DepthUpdate = Batch.DepthUpdate
	const Bias = if Batch.Decal then DecalBias else 0
	const Translucent = Batch.Translucent
	const Cutout = Batch.Cutout
	const ColorKind = Program.ColorKind
	const AlphaKind = Program.AlphaKind
	const TwoCycle = Batch.TwoCycle and Program.SecondCycle
	const Fast = not TwoCycle
		and ColorKind ~= Operation.General and ColorKind ~= Operation.PassThrough
		and AlphaKind ~= Operation.General and AlphaKind ~= Operation.PassThrough
	const ShadeColor = not Fast or ColorKind == Operation.Shade or ColorKind == Operation.TexelShade
	const ShadeAlpha = not Fast or AlphaKind == Operation.Shade or AlphaKind == Operation.TexelShade
	const TextureColor = ColorKind == Operation.Texel or ColorKind == Operation.TexelShade or ColorKind == Operation.TexelEnvironment
	const TextureAlpha = AlphaKind == Operation.Texel or AlphaKind == Operation.TexelShade or AlphaKind == Operation.TexelEnvironment
	const EnvironmentColor = ColorKind == Operation.Environment or ColorKind == Operation.TexelEnvironment
	const EnvironmentAlpha = AlphaKind == Operation.Environment or AlphaKind == Operation.TexelEnvironment
	const Env = Batch.EnvColor
	const ConstantR = if EnvironmentColor then Env[1] / 255 else 1
	const ConstantG = if EnvironmentColor then Env[2] / 255 else 1
	const ConstantB = if EnvironmentColor then Env[3] / 255 else 1
	const ConstantA = if EnvironmentAlpha then Env[4] / 255 else 1
	const AZ, BZ, CornerZ = A[SZ], B[SZ], C[SZ]
	const AIW, BIW, CIW = A[SIW], B[SIW], C[SIW]
	const AR, BR, CornerR = A[SR], B[SR], C[SR]
	const AG, BG, CornerG = A[SG], B[SG], C[SG]
	const AB, BB, CornerB = A[SB], B[SB], C[SB]
	const AA, BA, CornerA = A[SA], B[SA], C[SA]
	const AU, BU, CornerU = A[SU], B[SU], C[SU]
	const AV, BV, CornerV = A[SV], B[SV], C[SV]
	const AF, BF, CornerF = A[SF], B[SF], C[SF]
	const Fog = Batch.Fog
	const StoreAlpha = Target.StoreAlpha
	const FogR = Batch.FogColor[1]
	const FogG = Batch.FogColor[2]
	const FogB = Batch.FogColor[3]
	-- The weights at the center of the first pixel of the box
	const StartX = MinX + 0.5
	const StartY = MinY + 0.5
	local RowA = ((B[SX] - StartX) * (C[SY] - StartY) - (C[SX] - StartX) * (B[SY] - StartY)) * InverseArea
	local RowB = ((C[SX] - StartX) * (A[SY] - StartY) - (A[SX] - StartX) * (C[SY] - StartY)) * InverseArea
	local RowC = ((A[SX] - StartX) * (B[SY] - StartY) - (B[SX] - StartX) * (A[SY] - StartY)) * InverseArea

	for Y = MinY, MaxY do
		-- Include only the top and left edges so triangles sharing an edge blend a pixel once.
		local First = 0
		local Last = MaxX - MinX
		local Empty = false

		for Edge = 1, 3 do
			const Row = if Edge == 1 then RowA elseif Edge == 2 then RowB else RowC
			const Step = if Edge == 1 then StepAX elseif Edge == 2 then StepBX else StepCX

			if Step > 0 then
				First = math.max(First, math.ceil(-Row / Step))
			elseif Step < 0 then
				Last = math.min(Last, math.ceil(-Row / Step) - 1)
			elseif Row < 0 or (Row == 0 and (if Edge == 1 then StepAY elseif Edge == 2 then StepBY else StepCY) < 0) then
				Empty = true
			end
		end

		if not Empty and First <= Last then
			local WeightA = RowA + StepAX * First
			local WeightB = RowB + StepBX * First
			local WeightC = RowC + StepCX * First

			for X = MinX + First, MinX + Last do
				const Z = WeightA * AZ + WeightB * BZ + WeightC * CornerZ
				const Index = Y * Width + X + 1

				if Z >= -1 and Z <= 1 and (not DepthCompare or Z <= Depth[Index] + Bias) then
					local TexelR, TexelG, TexelB, TexelA = 1, 1, 1, 1

					if Image ~= nil then
						const Scale = 1 / (WeightA * AIW + WeightB * BIW + WeightC * CIW)

						TexelR, TexelG, TexelB, TexelA = Sample(Image, Batch, (WeightA * AU + WeightB * BU + WeightC * CornerU) * Scale, (WeightA * AV + WeightB * BV + WeightC * CornerV) * Scale)
					end

					const FactorR = if ShadeColor then WeightA * AR + WeightB * BR + WeightC * CornerR else ConstantR
					const FactorG = if ShadeColor then WeightA * AG + WeightB * BG + WeightC * CornerG else ConstantG
					const FactorB = if ShadeColor then WeightA * AB + WeightB * BB + WeightC * CornerB else ConstantB
					const FactorA = if ShadeAlpha then WeightA * AA + WeightB * BA + WeightC * CornerA else ConstantA
					local R, G, Blue, Alpha

					if Fast then
						if TextureColor then
							R, G, Blue = TexelR * FactorR, TexelG * FactorG, TexelB * FactorB
						else
							R, G, Blue = FactorR, FactorG, FactorB
						end

						Alpha = if TextureAlpha then TexelA * FactorA else FactorA
					else
						R, G, Blue, Alpha = Combiner.Run(Program, TwoCycle, TexelR, TexelG, TexelB, TexelA, FactorR, FactorG, FactorB, FactorA)
					end

					if not (Cutout and Alpha < CutoutAlpha) and not (Translucent and Alpha <= 0) then
						local Red = R * 255 + 0.5
						local Green = G * 255 + 0.5
						local Bluish = Blue * 255 + 0.5

						if Fog then
							const Amount = WeightA * AF + WeightB * BF + WeightC * CornerF

							Red += (FogR - Red) * Amount
							Green += (FogG - Green) * Amount
							Bluish += (FogB - Bluish) * Amount
						end

						local OutputAlpha = 255

						if Translucent and Alpha < 1 then
							const Below = buffer.readu32(Color, (Index - 1) * 4)
							const BelowAlpha = if StoreAlpha then bit32.rshift(Below, 24) / 255 else 1
							const Uncovered = BelowAlpha * (1 - Alpha)
							const BlendedAlpha = Alpha + Uncovered
							const SourceWeight = Alpha / BlendedAlpha

							Red = math.lerp(bit32.band(Below, 255), Red, SourceWeight)
							Green = math.lerp(bit32.extract(Below, 8, 8), Green, SourceWeight)
							Bluish = math.lerp(bit32.extract(Below, 16, 8), Bluish, SourceWeight)
							OutputAlpha = math.round(BlendedAlpha * 255)
						end

						buffer.writeu32(Color, (Index - 1) * 4, bit32.bor(math.min(Red // 1, 255), bit32.lshift(math.min(Green // 1, 255), 8), bit32.lshift(math.min(Bluish // 1, 255), 16), bit32.lshift(OutputAlpha, 24)))

						if DepthUpdate then
							Depth[Index] = Z
						end
					end
				end

				WeightA += StepAX
				WeightB += StepBX
				WeightC += StepCX
			end
		end

		RowA += StepAY
		RowB += StepBY
		RowC += StepCY
	end
end

-- Interpolates the vertex where an edge crosses the near plane (z = -w) into Out
const function CrossNear(Out: Vertex, From: Vertex, To: Vertex)
	const DistanceFrom = From[CZ] + From[CW]
	const DistanceTo = To[CZ] + To[CW]
	const T = DistanceFrom / (DistanceFrom - DistanceTo)

	for Field = 1, FieldCount do
		Out[Field] = From[Field] + (To[Field] - From[Field]) * T
	end
end

-- Projects a clip space vertex to the screen into Out; Center is the screen center x, y and half size x, y
const function ToScreen(Out: Vertex, From: Vertex, Center: { number })
	const InverseW = 1 / From[CW]

	Out[SX] = Center[1] + From[CX] * InverseW * Center[3]
	Out[SY] = Center[2] - From[CY] * InverseW * Center[4]
	Out[SZ] = From[CZ] * InverseW
	Out[SIW] = InverseW
	Out[SR] = From[CR]
	Out[SG] = From[CG]
	Out[SB] = From[CB]
	Out[SA] = From[CA]
	Out[SU] = From[CU] * InverseW
	Out[SV] = From[CV] * InverseW
	Out[SF] = From[CF]
end

const function IsInFront(Vertex: Vertex): boolean
	return Vertex[CZ] >= -Vertex[CW] and Vertex[CW] > NearEpsilon
end

-- Draws one batch with the projection matrix; Center is the screen center x, y and half size x, y in framebuffer pixels
const function DrawBatch(Target: Framebuffer, Batch: Scene.Batch, Projection: { number }, Center: { number }, Bounds: Bounds?)
	const Positions = Batch.Positions
	const Colors = Batch.Colors
	const UVs = Batch.UVs
	const Indices = Batch.Indices
	const Program = Combiner.Compile(Batch.Combine)

	Combiner.SetConstants(Batch.PrimColor, Batch.EnvColor)

	for Triangle = 0, #Indices // 3 - 1 do
		local Inside = 0

		for Corner = 1, 3 do
			const Index = Indices[Triangle * 3 + Corner]
			const X = Positions[Index * 3 - 2]
			const Y = Positions[Index * 3 - 1]
			const Z = Positions[Index * 3]
			const Out = Source[Corner]

			Out[CX] = X * Projection[1] + Y * Projection[5] + Z * Projection[9] + Projection[13]
			Out[CY] = X * Projection[2] + Y * Projection[6] + Z * Projection[10] + Projection[14]
			Out[CZ] = X * Projection[3] + Y * Projection[7] + Z * Projection[11] + Projection[15]
			Out[CW] = X * Projection[4] + Y * Projection[8] + Z * Projection[12] + Projection[16]
			Out[CR] = Colors[Index * 4 - 3] / 255
			Out[CG] = Colors[Index * 4 - 2] / 255
			Out[CB] = Colors[Index * 4 - 1] / 255
			Out[CA] = Colors[Index * 4] / 255
			Out[CU] = UVs[Index * 2 - 1]
			Out[CV] = UVs[Index * 2]
			Out[CF] = if Batch.Fog then math.clamp(Out[CZ] / Out[CW] * Batch.FogMultiplier + Batch.FogOffset, 0, 255) / 255 else 0

			if IsInFront(Out) then
				Inside += 1
			end
		end

		if Inside == 3 then
			ToScreen(Screen[1], Source[1], Center)
			ToScreen(Screen[2], Source[2], Center)
			ToScreen(Screen[3], Source[3], Center)
			Fill(Target, Batch, Screen[1], Screen[2], Screen[3], Program, Bounds)
		elseif Inside > 0 then
			-- Sutherland-Hodgman against the near plane
			local Count = 0

			for Corner = 1, 3 do
				const Current = Source[Corner]
				const Next = Source[Corner % 3 + 1]
				const CurrentInside = IsInFront(Current)

				if CurrentInside then
					Count += 1
					table.move(Current, 1, FieldCount, 1, Clipped[Count])
				end

				if CurrentInside ~= IsInFront(Next) then
					Count += 1
					CrossNear(Clipped[Count], Current, Next)
				end
			end

			for Corner = 1, Count do
				ToScreen(Screen[Corner], Clipped[Corner], Center)
			end

			Fill(Target, Batch, Screen[1], Screen[2], Screen[3], Program, Bounds)

			if Count == ClippedMax then
				Fill(Target, Batch, Screen[1], Screen[3], Screen[4], Program, Bounds)
			end
		end
	end
end

-- Draws a range of batches over the framebuffer, accumulating their bounds when requested.
const function DrawScene(Target: Framebuffer, Drawn: Scene.Scene, First: number?, Last: number?, Bounds: Bounds?)
	const FirstBatch = First or 1
	const LastBatch = Last or #Drawn.Batches

	if FirstBatch > LastBatch then
		return
	end

	const Viewport = Drawn.Viewport
	const Scale = Target.Width / 320
	const Center = { Viewport.X * Scale, Viewport.Y * Scale, Viewport.HalfWidth * Scale, Viewport.HalfHeight * Scale }
	const ScreenCenter = { 160 * Scale, 120 * Scale, 160 * Scale, 120 * Scale }
	const Aspect = Viewport.HalfWidth / Viewport.HalfHeight
	local LastProjection: Scene.Projection? = nil
	local Matrix: { number } = {}

	for Index = FirstBatch, LastBatch do
		const Batch = Drawn.Batches[Index]

		if Batch.Projection ~= nil and Batch.VertexCount > 0 then
			if Batch.Projection ~= LastProjection then
				Matrix = Scene.ProjectionMatrix(Batch.Projection, Aspect)
				LastProjection = Batch.Projection
			end

			DrawBatch(Target, Batch, Matrix, if Batch.Projection.Matrix ~= nil then ScreenCenter else Center, Bounds)
		end
	end
end

return { New = New, NewSprite = NewSprite, ClearSprite = ClearSprite, Clear = Clear, DrawBatch = DrawBatch, DrawScene = DrawScene, Sample = Sample }
