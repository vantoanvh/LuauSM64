--!strict
--!optimize 2

--[[
	Interprets Fast3D display lists straight from the ROM image in Memory and turns the triangles into Scene batches.

	Paradigm
		Not an emulator of the RDP: it keeps the state the commands set (geometry mode, other modes, combiner, colors, tiles, the
		texture and palette loads, lights, the modelview stack), transforms and lights the vertices of G_VTX into view space
		(the RSP's job), and at each G_TRI1 appends the triangle to the current batch; any state change starts a new batch.
		Texture memory is modelled by what was loaded where: a load block or tile records its source at its TMEM address, a tile
		decodes from the source of its own TMEM address (texture.luau).

	Invariants
		The segment table is the ROM reader's (the game's own at the end of the frame) with the G_MW_SEGMENT commands of the lists
		laid over it.
]]

const Gbi = require("./gbi")
const Matrix = require("./matrix")
const Rom = require("../port/src/rom/rom")
const Scene = require("./scene")
const Decode = require("./texture")

const Opcode = Gbi.Opcode

type Tile = {
	Format: number,
	Size: number,
	Line: number,
	Tmem: number,
	Palette: number,
	ClampT: number,
	MaskT: number,
	ShiftT: number,
	ClampS: number,
	MaskS: number,
	ShiftS: number,
	-- The tile size in 10.2 fixed point texels
	UlS: number,
	UlT: number,
	LrS: number,
	LrT: number,
	SizeSet: boolean,
}

type Load = { Address: number, Stride: number? }

type Light = { R: number, G: number, B: number, X: number, Y: number, Z: number }

export type State = {
	Scene: Scene.Scene,
	Batch: Scene.Batch?,
	Dirty: boolean,
	Segments: { [number]: number },
	Geometry: number,
	OtherH: number,
	OtherL: number,
	-- The scissor box in pixels of the 320x240 screen (left, top, right, bottom), nil until a list sets it
	Scissor: { number }?,
	Combine: { number },
	EnvColor: { number },
	PrimColor: { number },
	FogColor: { number },
	FogMultiplier: number,
	FogOffset: number,
	TextureOn: boolean,
	TextureTile: number,
	ScaleS: number,
	ScaleT: number,
	Tiles: { Tile },
	ImageFormat: number,
	ImageSize: number,
	ImageWidth: number,
	ImageAddress: number,
	Loads: { [number]: Load },
	Palette: { number },
	Lights: { Light },
	LightCount: number,
	ModelView: { Matrix.Matrix },
	Depth: number,
	Layer: number,
	Projection: Scene.Projection?,
	-- The projection matrix a list loaded (G_MTX_PROJECTION); the draws of the traversal use the parametric Projection above
	ProjectionMatrix: Matrix.Matrix?,
	-- The vertex cache (16 slots, 1-based): view space position, lit color, scaled texture coordinates
	VertexX: { number },
	VertexY: { number },
	VertexZ: { number },
	VertexR: { number },
	VertexG: { number },
	VertexB: { number },
	VertexA: { number },
	VertexS: { number },
	VertexT: { number },
	-- Index in the current batch of the vertex of each cache slot, nil when not appended yet
	Appended: { [number]: number },
	-- Offsets that turn the scaled texture coordinates of a vertex into texels of the tile
	UvOffsetS: number,
	UvOffsetT: number,
	UvScaleS: number,
	UvScaleT: number,
	-- Relight decode (a presenter that lights the vertices itself each frame): the batches are in the space of the matrix of the draw
	-- (model space under an identity one), and a lit vertex keeps its normal and the lights it was lit with instead of a color; its color
	-- is the one under full light (the ambient plus the first light), what the lighting gives a normal facing it
	Relight: boolean,
	-- The lights as set now, kept while they do not change (a lit vertex points at the set it was lit with)
	LightSet: Scene.LightSet?,
	VertexLightSet: { Scene.LightSet? },
	VertexNormalX: { number },
	VertexNormalY: { number },
	VertexNormalZ: { number },
	VertexLit: { boolean },
}

const VertexSize = 16
const TileCount = 8
const MaxDepth = 10
const BilerpBits = 0x3000
const ScreenWidth = 320
const ScreenHeight = 240
-- The rectangles of the 2D lists are in pixels of the screen: the orthographic projection of the 320x240 screen on the framebuffer
const ScreenProjection: Scene.Projection = { Perspective = false, Fov = 0, Near = 0, Far = 100, Scale = 1, Screen = true }
-- G_CC_DECALRGBA: the texel as it is, what the copy cycle writes
const CopyCombine = { 31, 31, 31, Gbi.CcTexel0, 7, 7, 7, Gbi.CcTexel0, 31, 31, 31, 0, 7, 7, 7, 0 }
-- The combine of a new state: the shade as it is
const ShadeCombine = { 0, 0, 0, Gbi.CcShade, 0, 0, 0, Gbi.CcShade, 0, 0, 0, Gbi.CcShade, 0, 0, 0, Gbi.CcShade }
-- The combine tables of the G_SETCOMBINE commands seen, by their two words: a combine is never changed, so states and batches share them (the
-- combiner keeps a program for each table)
const Combines: { [number]: { [number]: { number } } } = {}
-- Commands that carry nothing the picture needs: the half commands of a rectangle, the syncs, fill and the cull box
const Ignored = {
	[Opcode.RdpHalf1] = true,
	[Opcode.RdpHalf2] = true,
	[Opcode.RdpHalfCont] = true,
	[Opcode.RdpLoadSync] = true,
	[Opcode.RdpPipeSync] = true,
	[Opcode.RdpTileSync] = true,
	[Opcode.RdpFullSync] = true,
	[Opcode.CullDl] = true,
	[Opcode.SetBlendColor] = true,
	[Opcode.SetFillColor] = true,
	[Opcode.FillRect] = true,
	[Opcode.SetColorImage] = true,
	[Opcode.SetDepthImage] = true,
	[0] = true,
}

const function NewTile(): Tile
	return {
		Format = 0, Size = 0, Line = 0, Tmem = 0, Palette = 0, ClampT = 0, MaskT = 0, ShiftT = 0, ClampS = 0, MaskS = 0, ShiftS = 0,
		UlS = 0, UlT = 0, LrS = 0, LrT = 0, SizeSet = false,
	}
end

-- The RSP and RDP state init_rdp and init_rsp of game_init.c leave, before the geometry
const function New(Target: Scene.Scene): State
	const Tiles: { Tile } = {}

	for Index = 0, TileCount - 1 do
		Tiles[Index] = NewTile()
	end

	return {
		Scene = Target,
		Batch = nil,
		Dirty = true,
		Segments = {},
		Geometry = 0x0004 + 0x0200 + Gbi.CullBack + Gbi.Lighting,
		OtherH = Gbi.TexturePerspBit + bit32.lshift(2, Gbi.TextureFilterShift),
		OtherL = 0,
		Combine = ShadeCombine,
		EnvColor = { 255, 255, 255, 255 },
		PrimColor = { 255, 255, 255, 255 },
		FogColor = { 0, 0, 0, 255 },
		FogMultiplier = 0,
		FogOffset = 0,
		TextureOn = false,
		TextureTile = 0,
		ScaleS = 0,
		ScaleT = 0,
		Tiles = Tiles,
		ImageFormat = 0,
		ImageSize = 0,
		ImageWidth = 0,
		ImageAddress = 0,
		Loads = {},
		Palette = {},
		Lights = {},
		-- init_rsp: gSPNumLights(NUMLIGHTS_1), one directional light and the ambient one (the count includes the ambient light)
		LightCount = 2,
		ModelView = { Matrix.Identity() },
		Depth = 1,
		Layer = 0,
		Projection = nil,
		ProjectionMatrix = nil,
		Scissor = nil,
		VertexX = table.create(16, 0),
		VertexY = table.create(16, 0),
		VertexZ = table.create(16, 0),
		VertexR = table.create(16, 0),
		VertexG = table.create(16, 0),
		VertexB = table.create(16, 0),
		VertexA = table.create(16, 0),
		VertexS = table.create(16, 0),
		VertexT = table.create(16, 0),
		Appended = {},
		UvOffsetS = 0,
		UvOffsetT = 0,
		UvScaleS = 1,
		UvScaleT = 1,
		Relight = false,
		LightSet = nil,
		VertexLightSet = {},
		VertexNormalX = table.create(16, 0),
		VertexNormalY = table.create(16, 0),
		VertexNormalZ = table.create(16, 0),
		VertexLit = table.create(16, false),
	}
end

-- The Memory address of a segmented address under the segments the lists set
const function Resolve(State: State, Address: number): number
	const Base = State.Segments[bit32.rshift(Address, 24)]

	if Base ~= nil then
		return Base + bit32.band(Address, 0xFFFFFF)
	end

	return Rom.SegmentedToVirtual(Address)
end

const function ColorOf(Word: number): { number }
	return { bit32.rshift(Word, 24), bit32.band(bit32.rshift(Word, 16), 0xFF), bit32.band(bit32.rshift(Word, 8), 0xFF), bit32.band(Word, 0xFF) }
end

-- True when the combiner reads a texel in its color or alpha cycle(s): the inputs T0/T1 of any slot, or the texel alphas as a color factor
const function UsesTexel(Combine: { number }, TwoCycle: boolean): boolean
	for Cycle = 0, if TwoCycle then 8 else 0, 8 do
		for Slot = 1, 8 do
			const Value = Combine[Cycle + Slot]

			if Value == Gbi.CcTexel0 or Value == Gbi.CcTexel1 then
				return true
			elseif Slot == 3 and (Value == Gbi.CcTexel0Alpha or Value == Gbi.CcTexel1Alpha) then
				return true
			end
		end
	end

	return false
end

-- Starts the batch of the state as it is now: the texture of the tile (the render tile of G_TEXTURE, or the tile of a texture
-- rectangle, which always textures), the sampler, the modes
const function NewBatch(State: State, TileIndex: number, Rectangle: boolean): Scene.Batch
	const TwoCycle = bit32.extract(State.OtherH, Gbi.CycleTypeShift, 2) == Gbi.CycleTwo
	const RenderMode = State.OtherL
	const Tile = State.Tiles[TileIndex]
	local Image: Decode.Texture? = nil

	-- the copy cycle writes the texels whatever the combiner says
	const Copy = bit32.extract(State.OtherH, Gbi.CycleTypeShift, 2) == Gbi.CycleCopy

	if (Rectangle or State.TextureOn) and (Copy or UsesTexel(State.Combine, TwoCycle)) then
		const Load = State.Loads[Tile.Tmem]

		if Load ~= nil then
			const Width = if Tile.SizeSet then bit32.rshift(Tile.LrS - Tile.UlS, 2) + 1 else bit32.lshift(1, Tile.MaskS)
			const Height = if Tile.SizeSet then bit32.rshift(Tile.LrT - Tile.UlT, 2) + 1 else bit32.lshift(1, Tile.MaskT)
			const Stride = Load.Stride or Tile.Line * 8
			const LutMode = bit32.extract(State.OtherH, Gbi.TextureLutShift, 2)

			Image = Decode(Load.Address, Tile.Format, Tile.Size, Width, Height, Stride, State.Palette, Tile.Palette, LutMode)
		end
	end

	State.UvOffsetS = Tile.UlS / 4
	State.UvOffsetT = Tile.UlT / 4
	State.UvScaleS = if Tile.ShiftS == 0 then 1 elseif Tile.ShiftS <= 10 then 1 / bit32.lshift(1, Tile.ShiftS) else bit32.lshift(1, 16 - Tile.ShiftS)
	State.UvScaleT = if Tile.ShiftT == 0 then 1 elseif Tile.ShiftT <= 10 then 1 / bit32.lshift(1, Tile.ShiftT) else bit32.lshift(1, 16 - Tile.ShiftT)

	const CycleOneBlend = bit32.band(bit32.rshift(RenderMode, if TwoCycle then 24 else 26), 3) == 0 and bit32.band(bit32.rshift(RenderMode, if TwoCycle then 16 else 18), 3) == 0
	const Batch = {
		Layer = State.Layer,
		Projection = State.Projection,
		Texture = Image,
		MaskS = Tile.MaskS,
		MaskT = Tile.MaskT,
		MirrorS = bit32.btest(Tile.ClampS, 1),
		MirrorT = bit32.btest(Tile.ClampT, 1),
		ClampS = bit32.btest(Tile.ClampS, 2),
		ClampT = bit32.btest(Tile.ClampT, 2),
		Filtered = bit32.btest(State.OtherH, BilerpBits),
		Combine = State.Combine,
		TwoCycle = TwoCycle,
		EnvColor = State.EnvColor,
		PrimColor = State.PrimColor,
		FogColor = State.FogColor,
		FogMultiplier = State.FogMultiplier,
		FogOffset = State.FogOffset,
		Fog = bit32.btest(State.Geometry, Gbi.Fog) and bit32.extract(RenderMode, 30, 2) == Gbi.BlendFogColor,
		Translucent = bit32.btest(RenderMode, Gbi.ForceBlend) and CycleOneBlend,
		Cutout = bit32.btest(RenderMode, Gbi.CoverageTimesAlpha),
		DepthCompare = bit32.btest(RenderMode, Gbi.ZCompare) and bit32.btest(State.Geometry, Gbi.ZBuffer),
		DepthUpdate = bit32.btest(RenderMode, Gbi.ZUpdate) and bit32.btest(State.Geometry, Gbi.ZBuffer),
		Decal = bit32.extract(RenderMode, Gbi.ZModeShift, 2) == Gbi.ZModeDecal,
		CullBack = bit32.btest(State.Geometry, Gbi.CullBack),
		CullFront = bit32.btest(State.Geometry, Gbi.CullFront),
		Scissor = State.Scissor,
		Positions = {},
		Colors = {},
		Normals = {},
		Lights = {},
		UVs = {},
		Indices = {},
		VertexCount = 0,
	}

	table.insert(State.Scene.Batches, Batch)
	table.clear(State.Appended)
	State.Batch = Batch
	State.Dirty = false

	return Batch
end

const function AppendVertex(State: State, Batch: Scene.Batch, Slot: number): number
	const Count = Batch.VertexCount + 1
	const Positions = Batch.Positions
	const Colors = Batch.Colors
	const UVs = Batch.UVs

	Positions[Count * 3 - 2] = State.VertexX[Slot]
	Positions[Count * 3 - 1] = State.VertexY[Slot]
	Positions[Count * 3] = State.VertexZ[Slot]
	Colors[Count * 4 - 3] = State.VertexR[Slot]
	Colors[Count * 4 - 2] = State.VertexG[Slot]
	Colors[Count * 4 - 1] = State.VertexB[Slot]
	Colors[Count * 4] = State.VertexA[Slot]

	if State.VertexLit[Slot] then
		const Normals = Batch.Normals

		Normals[Count * 3 - 2] = State.VertexNormalX[Slot]
		Normals[Count * 3 - 1] = State.VertexNormalY[Slot]
		Normals[Count * 3] = State.VertexNormalZ[Slot]
		Batch.Lights[Count] = State.VertexLightSet[Slot] :: Scene.LightSet
	end

	UVs[Count * 2 - 1] = (State.VertexS[Slot] / 32 - State.UvOffsetS) * State.UvScaleS
	UVs[Count * 2] = (State.VertexT[Slot] / 32 - State.UvOffsetT) * State.UvScaleT
	Batch.VertexCount = Count
	State.Appended[Slot] = Count

	return Count
end

const function DrawTriangle(State: State, First: number, Second: number, Third: number)
	const Batch = if State.Dirty or State.Batch == nil then NewBatch(State, State.TextureTile, false) else State.Batch :: Scene.Batch
	const Indices = Batch.Indices
	const Count = #Indices

	Indices[Count + 1] = State.Appended[First] or AppendVertex(State, Batch, First)
	Indices[Count + 2] = State.Appended[Second] or AppendVertex(State, Batch, Second)
	Indices[Count + 3] = State.Appended[Third] or AppendVertex(State, Batch, Third)
	State.Scene.Stats.Triangles += 1
end

-- G_VTX
const function LoadVertices(State: State, Word0: number, Word1: number)
	const Count = bit32.extract(Word0, 20, 4) + 1
	const First = bit32.extract(Word0, 16, 4)
	const Source = Resolve(State, Word1)
	const Mv = State.ModelView[State.Depth]
	-- a list that lights vertices has set its lights (the 2D lists of the pool clear the mode or never light)
	const Lighting = bit32.btest(State.Geometry, Gbi.Lighting) and State.Lights[State.LightCount] ~= nil
	const TextureGen = bit32.btest(State.Geometry, Gbi.TextureGen)
	const LightCount = State.LightCount - 1
	const Lights = State.Lights
	const Ambient = Lights[LightCount + 1]
	const Memory = Rom.Memory
	const CoefficientX: { number } = {}
	const CoefficientY: { number } = {}
	const CoefficientZ: { number } = {}
	local LookAtX1, LookAtX2, LookAtX3, LookAtY1, LookAtY2, LookAtY3 = 0, 0, 0, 0, 0, 0

	if Lighting and not State.Relight then
		for Index = 1, LightCount do
			const Light = Lights[Index]

			CoefficientX[Index], CoefficientY[Index], CoefficientZ[Index] = Matrix.LightCoefficient(Mv, Light.X, Light.Y, Light.Z)
		end

		if TextureGen then
			LookAtX1, LookAtX2, LookAtX3 = Matrix.LightCoefficient(Mv, 127, 0, 0)
			LookAtY1, LookAtY2, LookAtY3 = Matrix.LightCoefficient(Mv, 0, 127, 0)
		end
	end

	for Index = 0, Count - 1 do
		const Slot = First + Index + 1
		const Address = Source + Index * VertexSize
		const X = Rom.ReadS16(Address)
		const Y = Rom.ReadS16(Address + 2)
		const Z = Rom.ReadS16(Address + 4)

		State.VertexX[Slot] = X * Mv[1] + Y * Mv[5] + Z * Mv[9] + Mv[13]
		State.VertexY[Slot] = X * Mv[2] + Y * Mv[6] + Z * Mv[10] + Mv[14]
		State.VertexZ[Slot] = X * Mv[3] + Y * Mv[7] + Z * Mv[11] + Mv[15]
		State.VertexA[Slot] = buffer.readu8(Memory, Address + 15)
		State.VertexS[Slot] = Rom.ReadS16(Address + 8) * State.ScaleS // 65536
		State.VertexT[Slot] = Rom.ReadS16(Address + 10) * State.ScaleT // 65536

		State.VertexLit[Slot] = false

		if Lighting and State.Relight then
			const NormalX = buffer.readi8(Memory, Address + 12)
			const NormalY = buffer.readi8(Memory, Address + 13)
			const NormalZ = buffer.readi8(Memory, Address + 14)
			-- The color under full light: the first light and the ambient light give a normal facing the light (white while no light is set)
			const Light = if LightCount >= 1 then Lights[1] else nil

			if State.LightSet == nil then
				State.LightSet = { Ambient = Ambient, Directional = table.move(Lights, 1, LightCount, 1, {}) }
			end

			State.VertexR[Slot] = if Ambient then math.min(Ambient.R + (if Light then Light.R else 0), 255) else 255
			State.VertexG[Slot] = if Ambient then math.min(Ambient.G + (if Light then Light.G else 0), 255) else 255
			State.VertexB[Slot] = if Ambient then math.min(Ambient.B + (if Light then Light.B else 0), 255) else 255
			State.VertexNormalX[Slot] = NormalX / 127
			State.VertexNormalY[Slot] = NormalY / 127
			State.VertexNormalZ[Slot] = NormalZ / 127
			State.VertexLightSet[Slot] = State.LightSet
			State.VertexLit[Slot] = true
		elseif Lighting then
			const NormalX = buffer.readi8(Memory, Address + 12)
			const NormalY = buffer.readi8(Memory, Address + 13)
			const NormalZ = buffer.readi8(Memory, Address + 14)
			local R = Ambient.R
			local G = Ambient.G
			local B = Ambient.B

			for Light = 1, LightCount do
				const Intensity = (NormalX * CoefficientX[Light] + NormalY * CoefficientY[Light] + NormalZ * CoefficientZ[Light]) / 127

				if Intensity > 0 then
					const Directional = Lights[Light]

					R += Intensity * Directional.R
					G += Intensity * Directional.G
					B += Intensity * Directional.B
				end
			end

			State.VertexR[Slot] = math.min(R, 255)
			State.VertexG[Slot] = math.min(G, 255)
			State.VertexB[Slot] = math.min(B, 255)

			if TextureGen then
				const DotX = NormalX * LookAtX1 + NormalY * LookAtX2 + NormalZ * LookAtX3
				const DotY = NormalX * LookAtY1 + NormalY * LookAtY2 + NormalZ * LookAtY3

				State.VertexS[Slot] = (DotX / 127 + 1) / 4 * State.ScaleS
				State.VertexT[Slot] = (DotY / 127 + 1) / 4 * State.ScaleT
			end
		else
			State.VertexR[Slot] = buffer.readu8(Memory, Address + 12)
			State.VertexG[Slot] = buffer.readu8(Memory, Address + 13)
			State.VertexB[Slot] = buffer.readu8(Memory, Address + 14)
		end

		State.Appended[Slot] = nil
	end
end

const function LoadMatrix(State: State, Word0: number, Word1: number)
	const Flags = bit32.extract(Word0, 16, 8)
	const Address = Resolve(State, Word1)
	const Words = table.create(16, 0)

	for Index = 1, 16 do
		Words[Index] = Rom.ReadS32(Address + (Index - 1) * 4)
	end

	const Loaded = Matrix.FromFixed(Words)

	if bit32.btest(Flags, Gbi.MtxProjection) then
		const Current = State.ProjectionMatrix

		State.ProjectionMatrix = if bit32.btest(Flags, Gbi.MtxLoad) or Current == nil then Loaded else Matrix.Multiply(Loaded, Current)
		State.Projection = { Perspective = false, Fov = 0, Near = 0, Far = 100, Scale = 1, Screen = true, Matrix = State.ProjectionMatrix }
		State.Dirty = true

		return
	end

	if bit32.btest(Flags, Gbi.MtxPush) and State.Depth < MaxDepth then
		State.Depth += 1
		State.ModelView[State.Depth] = State.ModelView[State.Depth - 1]
	end

	State.ModelView[State.Depth] = if bit32.btest(Flags, Gbi.MtxLoad) then Loaded else Matrix.Multiply(Loaded, State.ModelView[State.Depth])
	State.Dirty = true
end

const function MoveMem(State: State, Word0: number, Word1: number)
	const Index = bit32.extract(Word0, 16, 8)

	if Index < Gbi.MoveMemLight0 or Index >= Gbi.MoveMemLight0 + 16 then
		return
	end

	const Address = Resolve(State, Word1)
	const Number = (Index - Gbi.MoveMemLight0) // 2 + 1

	State.Lights[Number] = {
		R = Rom.ReadU8(Address),
		G = Rom.ReadU8(Address + 1),
		B = Rom.ReadU8(Address + 2),
		X = Rom.ReadS8(Address + 8),
		Y = Rom.ReadS8(Address + 9),
		Z = Rom.ReadS8(Address + 10),
	}
	State.LightSet = nil
end

const function ToS16(Value: number): number
	return if Value >= 0x8000 then Value - 0x10000 else Value
end

const function MoveWord(State: State, Word0: number, Word1: number)
	const Index = bit32.band(Word0, 0xFF)

	if Index == Gbi.MoveWordNumLight then
		State.LightCount = (Word1 - 0x80000000) // 32
		State.LightSet = nil
	elseif Index == Gbi.MoveWordSegment then
		State.Segments[bit32.extract(Word0, 8, 16) // 4] = Word1
	elseif Index == Gbi.MoveWordFog then
		State.FogMultiplier = ToS16(bit32.rshift(Word1, 16))
		State.FogOffset = ToS16(bit32.band(Word1, 0xFFFF))
		State.Dirty = true
	end
end

const function SetOtherMode(State: State, Word0: number, Word1: number, High: boolean)
	const Shift = bit32.extract(Word0, 8, 8)
	const Length = bit32.band(Word0, 0xFF)
	const Mask = bit32.lshift(bit32.lshift(1, Length) - 1, Shift)

	if High then
		State.OtherH = bit32.bor(bit32.band(State.OtherH, bit32.bnot(Mask)), bit32.band(Word1, Mask))
	else
		State.OtherL = bit32.bor(bit32.band(State.OtherL, bit32.bnot(Mask)), bit32.band(Word1, Mask))
	end

	State.Dirty = true
end

const function SetTile(State: State, Word0: number, Word1: number)
	const Tile = State.Tiles[bit32.extract(Word1, 24, 3)]

	Tile.Format = bit32.extract(Word0, 21, 3)
	Tile.Size = bit32.extract(Word0, 19, 2)
	Tile.Line = bit32.extract(Word0, 9, 9)
	Tile.Tmem = bit32.extract(Word0, 0, 9)
	Tile.Palette = bit32.extract(Word1, 20, 4)
	Tile.ClampT = bit32.extract(Word1, 18, 2)
	Tile.MaskT = bit32.extract(Word1, 14, 4)
	Tile.ShiftT = bit32.extract(Word1, 10, 4)
	Tile.ClampS = bit32.extract(Word1, 8, 2)
	Tile.MaskS = bit32.extract(Word1, 4, 4)
	Tile.ShiftS = bit32.extract(Word1, 0, 4)
	State.Dirty = true
end

const function SetTileSize(State: State, Word0: number, Word1: number)
	const Tile = State.Tiles[bit32.extract(Word1, 24, 3)]

	Tile.UlS = bit32.extract(Word0, 12, 12)
	Tile.UlT = bit32.extract(Word0, 0, 12)
	Tile.LrS = bit32.extract(Word1, 12, 12)
	Tile.LrT = bit32.extract(Word1, 0, 12)
	Tile.SizeSet = true
	State.Dirty = true
end

const function SetTextureImage(State: State, Word0: number, Word1: number)
	State.ImageFormat = bit32.extract(Word0, 21, 3)
	State.ImageSize = bit32.extract(Word0, 19, 2)
	State.ImageWidth = bit32.extract(Word0, 0, 12) + 1
	State.ImageAddress = Resolve(State, Word1)
end

const function LoadBlock(State: State, Word0: number, Word1: number)
	State.Loads[State.Tiles[bit32.extract(Word1, 24, 3)].Tmem] = { Address = State.ImageAddress, Stride = nil }
	State.Dirty = true
end

-- A rectangle of the image: its source is the first texel, with the stride of the image rows
const function LoadTile(State: State, Word0: number, Word1: number)
	const Tile = State.Tiles[bit32.extract(Word1, 24, 3)]
	const Column = bit32.rshift(bit32.extract(Word0, 12, 12), 2)
	const Row = bit32.rshift(bit32.extract(Word0, 0, 12), 2)
	const Stride = if State.ImageSize == Gbi.Siz4b then State.ImageWidth // 2 else State.ImageWidth * bit32.lshift(1, State.ImageSize - 1)
	const Offset = if State.ImageSize == Gbi.Siz4b then Row * Stride + Column // 2 else Row * Stride + Column * bit32.lshift(1, State.ImageSize - 1)

	State.Loads[Tile.Tmem] = { Address = State.ImageAddress + Offset, Stride = Stride }
	State.Dirty = true
end

const function LoadTlut(State: State, Word0: number, Word1: number)
	const Tile = State.Tiles[bit32.extract(Word1, 24, 3)]
	const Count = bit32.extract(Word1, 14, 10) + 1

	for Index = 0, Count - 1 do
		State.Palette[Tile.Tmem + Index] = Rom.ReadU16(State.ImageAddress + Index * 2)
	end

	State.Dirty = true
end

const function SetTexture(State: State, Word0: number, Word1: number)
	State.TextureOn = bit32.btest(Word0, 0xFF)
	State.TextureTile = bit32.extract(Word0, 8, 3)
	State.ScaleS = bit32.rshift(Word1, 16)
	State.ScaleT = bit32.band(Word1, 0xFFFF)
	State.Dirty = true
end

const function SetCombine(State: State, Word0: number, Word1: number)
	const ByWord1 = Combines[Word0] or {}
	const Known = ByWord1[Word1]

	State.Dirty = true

	if Known ~= nil then
		State.Combine = Known

		return
	end

	const Made = {
		bit32.extract(Word0, 20, 4),
		bit32.extract(Word1, 28, 4),
		bit32.extract(Word0, 15, 5),
		bit32.extract(Word1, 15, 3),
		bit32.extract(Word0, 12, 3),
		bit32.extract(Word1, 12, 3),
		bit32.extract(Word0, 9, 3),
		bit32.extract(Word1, 9, 3),
		bit32.extract(Word0, 5, 4),
		bit32.extract(Word1, 24, 4),
		bit32.extract(Word0, 0, 5),
		bit32.extract(Word1, 6, 3),
		bit32.extract(Word1, 21, 3),
		bit32.extract(Word1, 3, 3),
		bit32.extract(Word1, 18, 3),
		bit32.extract(Word1, 0, 3),
	}

	ByWord1[Word1] = Made
	Combines[Word0] = ByWord1
	State.Combine = Made
end

-- G_SETSCISSOR: the box is in 10.2 fixed point pixels
const function SetScissor(State: State, Word0: number, Word1: number)
	State.Scissor = { bit32.extract(Word0, 12, 12) / 4, bit32.extract(Word0, 0, 12) / 4, bit32.extract(Word1, 12, 12) / 4, bit32.extract(Word1, 0, 12) / 4 }
	State.Dirty = true
end

-- G_TEXRECT and G_TEXRECTFLIP (the two half commands after it carry the first texture coordinate and the steps): a quad of the
-- screen textured with the tile. The copy cycle writes texels, counts 4 of them to a pixel in its steps and includes the last
-- row and column; a flipped rectangle steps S down and T across
const function TextureRectangle(State: State, Word0: number, Word1: number, CoordinateWord: number, StepWord: number, Flip: boolean)
	const Copy = bit32.extract(State.OtherH, Gbi.CycleTypeShift, 2) == Gbi.CycleCopy
	const Left = bit32.extract(Word1, 12, 12) / 4
	const Top = bit32.extract(Word1, 0, 12) / 4
	const Right = bit32.extract(Word0, 12, 12) / 4 + (if Copy then 1 else 0)
	const Bottom = bit32.extract(Word0, 0, 12) / 4 + (if Copy then 1 else 0)
	const Batch = NewBatch(State, bit32.extract(Word1, 24, 3), true)
	const Width = Right - Left
	const Height = Bottom - Top
	const S = ToS16(bit32.rshift(CoordinateWord, 16)) / 32 - State.UvOffsetS
	const T = ToS16(bit32.band(CoordinateWord, 0xFFFF)) / 32 - State.UvOffsetT
	const StepS = ToS16(bit32.rshift(StepWord, 16)) / (if Copy then 4096 else 1024)
	const StepT = ToS16(bit32.band(StepWord, 0xFFFF)) / 1024
	-- The texture coordinate change from the left to the right edge and from the top to the bottom edge
	const AcrossS = if Flip then 0 else StepS * Width
	const AcrossT = if Flip then StepT * Width else 0
	const DownS = if Flip then StepS * Height else 0
	const DownT = if Flip then 0 else StepT * Height
	const X0 = Left - ScreenWidth / 2
	const X1 = Right - ScreenWidth / 2
	const Y0 = ScreenHeight / 2 - Top
	const Y1 = ScreenHeight / 2 - Bottom

	Batch.Projection = ScreenProjection
	Batch.Filtered = Batch.Filtered and not Copy
	Batch.Fog = false
	Batch.DepthCompare = false
	Batch.DepthUpdate = false
	Batch.Decal = false
	Batch.CullBack = false
	Batch.CullFront = false

	if Copy then
		Batch.Combine = CopyCombine
		Batch.Translucent = false
		Batch.Cutout = bit32.band(State.OtherL, 3) ~= 0
	end

	Batch.Positions = { X0, Y0, -1, X0, Y1, -1, X1, Y1, -1, X1, Y0, -1 }
	Batch.Colors = table.create(16, 255)
	Batch.UVs = { S, T, S + DownS, T + DownT, S + AcrossS + DownS, T + AcrossT + DownT, S + AcrossS, T + AcrossT }
	Batch.Indices = { 1, 2, 3, 1, 3, 4 }
	Batch.VertexCount = 4
	State.Scene.Stats.Triangles += 2
	-- The next triangle starts a batch of its own
	State.Batch = nil
	State.Dirty = true
end

-- Commands that set state; the others (triangles, vertices, matrices, control flow) have their own paths below
const Handlers = {
	[Opcode.Vtx] = LoadVertices,
	[Opcode.Mtx] = LoadMatrix,
	[Opcode.MoveMem] = MoveMem,
	[Opcode.MoveWord] = MoveWord,
	[Opcode.Texture] = SetTexture,
	[Opcode.SetTile] = SetTile,
	[Opcode.SetTileSize] = SetTileSize,
	[Opcode.SetTextureImage] = SetTextureImage,
	[Opcode.LoadBlock] = LoadBlock,
	[Opcode.LoadTile] = LoadTile,
	[Opcode.LoadTlut] = LoadTlut,
	[Opcode.SetCombine] = SetCombine,
}

-- Executes the list at the segmented Address until its G_ENDDL (a branch list continues in place) or, for a Limit, the command at
-- the Memory address Limit
const function Execute(State: State, Address: number, Level: number, Limit: number)
	local Cursor = Resolve(State, Address)
	const Stats = State.Scene.Stats

	if Level > MaxDepth * 2 then
		return
	end

	while Cursor < Limit do
		const Word0 = Rom.ReadU32(Cursor)
		const Word1 = Rom.ReadU32(Cursor + 4)
		const Op = bit32.rshift(Word0, 24)

		Cursor += 8
		Stats.Commands += 1

		if Op == Opcode.Tri1 then
			DrawTriangle(State, bit32.extract(Word1, 16, 8) // 10 + 1, bit32.extract(Word1, 8, 8) // 10 + 1, bit32.extract(Word1, 0, 8) // 10 + 1)
		elseif Op == Opcode.EndDl then
			return
		elseif Op == Opcode.Dl then
			if bit32.extract(Word0, 16, 8) == 0 then
				Execute(State, Word1, Level + 1, math.huge)
			else
				Cursor = Resolve(State, Word1)
			end
		elseif Handlers[Op] ~= nil then
			Handlers[Op](State, Word0, Word1)
		elseif Op == Opcode.SetGeometryMode then
			State.Geometry = bit32.bor(State.Geometry, Word1)
			State.Dirty = true
		elseif Op == Opcode.ClearGeometryMode then
			State.Geometry = bit32.band(State.Geometry, bit32.bnot(Word1))
			State.Dirty = true
		elseif Op == Opcode.SetOtherModeH then
			SetOtherMode(State, Word0, Word1, true)
		elseif Op == Opcode.SetOtherModeL then
			SetOtherMode(State, Word0, Word1, false)
		elseif Op == Opcode.PopMtx then
			State.Depth = math.max(State.Depth - 1, 1)
		elseif Op == Opcode.TexRect or Op == Opcode.TexRectFlip then
			TextureRectangle(State, Word0, Word1, Rom.ReadU32(Cursor + 4), Rom.ReadU32(Cursor + 12), Op == Opcode.TexRectFlip)
			Cursor += 16
		elseif Op == Opcode.SetScissor then
			SetScissor(State, Word0, Word1)
		elseif Op == Opcode.SetEnvColor then
			State.EnvColor = ColorOf(Word1)
			State.Dirty = true
		elseif Op == Opcode.SetPrimColor then
			State.PrimColor = ColorOf(Word1)
			State.Dirty = true
		elseif Op == Opcode.SetFogColor then
			State.FogColor = ColorOf(Word1)
			State.Dirty = true
		elseif not Ignored[Op] then
			Stats.Unhandled[Op] = (Stats.Unhandled[Op] or 0) + 1
		end
	end
end

-- Runs one master list entry: the display list under the modelview Mtx the traversal made for it, on the layer's render mode
const function Draw(State: State, Address: number, ModelView: Matrix.Matrix, Layer: number, ZBuffer: boolean, Projection: Scene.Projection?)
	State.ModelView[1] = ModelView
	State.Depth = 1
	State.Layer = Layer
	State.Projection = Projection
	State.OtherL = Gbi.LayerRenderModes[if ZBuffer then 2 else 1][Layer + 1]
	State.Geometry = if ZBuffer then bit32.bor(State.Geometry, Gbi.ZBuffer) else bit32.band(State.Geometry, bit32.bnot(Gbi.ZBuffer))
	State.Dirty = true
	Execute(State, Address, 0, math.huge)
end

-- Runs the commands the game wrote into the pool from Start to End (a Memory address, not segmented) on the screen: the 2D picture
-- of the HUD, text and menus over the geometry. The state carries over from the draws before, as it does on the RDP
const function Run(State: State, Start: number, End: number)
	State.ModelView[1] = Matrix.Identity()
	State.Depth = 1
	State.Layer = Gbi.LayerCount - 1
	State.Projection = nil
	State.ProjectionMatrix = nil
	State.Scissor = nil
	State.Dirty = true
	Execute(State, Start, 0, End)
end

-- A state that continues from the one a list left (the RSP and RDP keep their state from list to list, so a list may rely on the lights,
-- colors, textures or modes set by the one before it): the same settings, tables of its own, and the batches go to Target
const function Fork(Source: State, Target: Scene.Scene): State
	const Copy = table.clone(Source)
	const Tiles: { Tile } = {}

	for Index = 0, TileCount - 1 do
		Tiles[Index] = table.clone(Source.Tiles[Index])
	end

	Copy.Scene = Target
	Copy.Batch = nil
	Copy.Dirty = true
	Copy.Appended = {}
	Copy.Segments = table.clone(Source.Segments)
	Copy.Combine = Source.Combine
	Copy.EnvColor = table.clone(Source.EnvColor)
	Copy.PrimColor = table.clone(Source.PrimColor)
	Copy.FogColor = table.clone(Source.FogColor)
	Copy.Tiles = Tiles
	Copy.Loads = table.clone(Source.Loads)
	Copy.Palette = table.clone(Source.Palette)
	Copy.Lights = table.clone(Source.Lights)
	Copy.ModelView = { Matrix.Identity() }
	Copy.Scissor = if Source.Scissor then table.clone(Source.Scissor) else nil
	Copy.VertexX = table.clone(Source.VertexX)
	Copy.VertexY = table.clone(Source.VertexY)
	Copy.VertexZ = table.clone(Source.VertexZ)
	Copy.VertexR = table.clone(Source.VertexR)
	Copy.VertexG = table.clone(Source.VertexG)
	Copy.VertexB = table.clone(Source.VertexB)
	Copy.VertexA = table.clone(Source.VertexA)
	Copy.VertexS = table.clone(Source.VertexS)
	Copy.VertexT = table.clone(Source.VertexT)
	Copy.VertexNormalX = table.clone(Source.VertexNormalX)
	Copy.VertexNormalY = table.clone(Source.VertexNormalY)
	Copy.VertexNormalZ = table.clone(Source.VertexNormalZ)
	Copy.VertexLit = table.clone(Source.VertexLit)
	Copy.VertexLightSet = table.clone(Source.VertexLightSet)

	return Copy
end

return { New = New, Fork = Fork, Draw = Draw, Run = Run }
