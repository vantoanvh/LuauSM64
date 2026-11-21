--!strict
--!optimize 2
--!native

--[[
	Decodes N64 texture data (RGBA16/32, IA4/8/16, I4/8, CI4/8 with a TLUT) from the ROM image in Memory into RGBA8 and caches the
	result by what it was decoded from.

	Design Notes
		A Texture is Width x Height pixels in Pixels, 4 bytes each (R, G, B, A), row after row; the consumers (the rasterizer, an
		EditableImage) read it as is. Alpha of an I texture is its intensity, as the RDP converts it.
]]

const Gbi = require("./gbi")
const Rom = require("../port/src/rom/rom")

export type Texture = { Width: number, Height: number, Pixels: buffer }

-- TextureLut modes (G_TT_*)
const LutIa16 = 3
const TlutBase = 256
const PaletteSize = 16

const Cache: { [string]: Texture } = {}
const Expand5 = table.create(32, 0)

for Value = 0, 31 do
	Expand5[Value + 1] = bit32.bor(bit32.lshift(Value, 3), bit32.rshift(Value, 2))
end

-- Packs bytes into the u32 whose little endian bytes are R, G, B, A
const function Pack(R: number, G: number, B: number, A: number): number
	return R + bit32.lshift(G, 8) + bit32.lshift(B, 16) + bit32.lshift(A, 24)
end

const function Rgba16(Value: number): number
	return Pack(
		Expand5[bit32.rshift(Value, 11) + 1],
		Expand5[bit32.band(bit32.rshift(Value, 6), 31) + 1],
		Expand5[bit32.band(bit32.rshift(Value, 1), 31) + 1],
		if bit32.btest(Value, 1) then 255 else 0
	)
end

const function Ia16(Value: number): number
	const Intensity = bit32.rshift(Value, 8)

	return Pack(Intensity, Intensity, Intensity, bit32.band(Value, 0xFF))
end

const function Intensity(Value: number, Alpha: number): number
	return Pack(Value, Value, Value, Alpha)
end

-- The packed color of the texel at column X of the row at address Row
const function Texel(Format: number, Size: number, Row: number, X: number, Palette: { number }?, PaletteBase: number, LutMode: number): number
	const Memory = Rom.Memory

	if Size == Gbi.Siz16b then
		const Value = Rom.ReadU16(Row + X * 2)

		if Format == Gbi.FmtIa then
			return Ia16(Value)
		end

		return Rgba16(Value)
	elseif Size == Gbi.Siz32b then
		return buffer.readu32(Memory, Row + X * 4)
	elseif Size == Gbi.Siz8b then
		const Value = buffer.readu8(Memory, Row + X)

		if Format == Gbi.FmtCi then
			const Entry = (Palette :: { number })[TlutBase + Value] or 0

			return if LutMode == LutIa16 then Ia16(Entry) else Rgba16(Entry)
		elseif Format == Gbi.FmtIa then
			const Level = bit32.rshift(Value, 4) * 17

			return Intensity(Level, bit32.band(Value, 15) * 17)
		end

		return Intensity(Value, Value)
	end

	const Packed = buffer.readu8(Memory, Row + bit32.rshift(X, 1))
	const Nibble = if bit32.btest(X, 1) then bit32.band(Packed, 15) else bit32.rshift(Packed, 4)

	if Format == Gbi.FmtCi then
		const Entry = (Palette :: { number })[PaletteBase + Nibble] or 0

		return if LutMode == LutIa16 then Ia16(Entry) else Rgba16(Entry)
	elseif Format == Gbi.FmtIa then
		const Level = bit32.rshift(Nibble, 1)

		return Intensity(bit32.bor(bit32.lshift(Level, 5), bit32.lshift(Level, 2), bit32.rshift(Level, 1)), if bit32.btest(Nibble, 1) then 255 else 0)
	end

	return Intensity(Nibble * 17, Nibble * 17)
end

-- A checksum of the bytes of the texture rows (and of the palette a CI texture reads), so that a texture whose bytes changed at the
-- same address (the level changed) is decoded again
const function Checksum(Address: number, Length: number, Palette: { number }?, PaletteBase: number, PaletteEntries: number): number
	local Sum = 0
	const WordsEnd = Address + Length - Length % 4

	for Offset = Address, WordsEnd - 4, 4 do
		Sum = (Sum * 31 + buffer.readu32(Rom.Memory, Offset)) % 0x100000000
	end

	for Offset = WordsEnd, Address + Length - 1 do
		Sum = (Sum * 31 + buffer.readu8(Rom.Memory, Offset)) % 0x100000000
	end

	if Palette ~= nil then
		for Index = PaletteBase, PaletteBase + PaletteEntries - 1 do
			Sum = (Sum * 31 + (Palette[Index] or 0)) % 0x100000000
		end
	end

	return Sum
end

-- Decodes the Width x Height texture at the Memory Address; Stride is the bytes of a row in memory. A CI texture reads Palette (the
-- raw u16 TLUT entries by TMEM word index, as G_LOADTLUT filled them), CI4 from palette number PaletteNumber, with the format LutMode
-- (G_TT_RGBA16 or G_TT_IA16). The result is cached by the parameters and the bytes it was decoded from.
const function Decode(
	Address: number,
	Format: number,
	Size: number,
	Width: number,
	Height: number,
	Stride: number,
	Palette: { number }?,
	PaletteNumber: number,
	LutMode: number
): Texture
	const PaletteBase = if Size == Gbi.Siz8b then TlutBase else TlutBase + PaletteNumber * PaletteSize
	const PaletteEntries = if Format ~= Gbi.FmtCi then 0 elseif Size == Gbi.Siz8b then 256 else PaletteSize
	const Key = `{Address}:{Format}:{Size}:{Width}:{Height}:{Stride}:{PaletteNumber}:{LutMode}:{Checksum(Address, Stride * Height, Palette, PaletteBase, PaletteEntries)}`
	const Cached = Cache[Key]

	if Cached ~= nil then
		return Cached
	end

	const Pixels = buffer.create(Width * Height * 4)

	for Y = 0, Height - 1 do
		const Row = Address + Y * Stride

		for X = 0, Width - 1 do
			buffer.writeu32(Pixels, (Y * Width + X) * 4, Texel(Format, Size, Row, X, Palette, PaletteBase, LutMode))
		end
	end

	const Result = { Width = Width, Height = Height, Pixels = Pixels }

	Cache[Key] = Result

	return Result
end

return Decode
