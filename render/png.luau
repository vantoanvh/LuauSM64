--!strict
--!optimize 2

--[[
	Minimal PNG encoder: 8-bit RGB, no filtering, zlib stream of stored (uncompressed) deflate blocks.
]]

const MaxStored = 65535
const Signature = "\137PNG\r\n\26\n"

const CrcTable = table.create(256, 0)

for Index = 0, 255 do
	local Value = Index

	for _ = 1, 8 do
		Value = if bit32.btest(Value, 1) then bit32.bxor(0xEDB88320, bit32.rshift(Value, 1)) else bit32.rshift(Value, 1)
	end

	CrcTable[Index + 1] = Value
end

const function Crc32(Data: buffer, Start: number, Length: number): number
	local Crc = 0xFFFFFFFF

	for Offset = Start, Start + Length - 1 do
		Crc = bit32.bxor(CrcTable[bit32.band(bit32.bxor(Crc, buffer.readu8(Data, Offset)), 0xFF) + 1], bit32.rshift(Crc, 8))
	end

	return bit32.bxor(Crc, 0xFFFFFFFF)
end

const function Adler32(Data: buffer, Length: number): number
	local A = 1
	local B = 0

	for Offset = 0, Length - 1 do
		A = (A + buffer.readu8(Data, Offset)) % 65521
		B = (B + A) % 65521
	end

	return B * 65536 + A
end

const function WriteU32BigEndian(Target: buffer, Offset: number, Value: number)
	buffer.writeu32(Target, Offset, bit32.byteswap(Value))
end

-- A chunk: length, type, data, crc
const function Chunk(Type: string, Data: buffer): buffer
	const Length = buffer.len(Data)
	const Result = buffer.create(12 + Length)

	WriteU32BigEndian(Result, 0, Length)
	buffer.writestring(Result, 4, Type)
	buffer.copy(Result, 8, Data, 0, Length)
	WriteU32BigEndian(Result, 8 + Length, Crc32(Result, 4, 4 + Length))

	return Result
end

-- Rgba is Width * Height pixels of 4 bytes; returns the PNG file as a string
const function Encode(Width: number, Height: number, Rgba: buffer): string
	const RowSize = Width * 3 + 1
	const RawSize = RowSize * Height
	const Raw = buffer.create(RawSize)

	for Y = 0, Height - 1 do
		for X = 0, Width - 1 do
			const Source = (Y * Width + X) * 4
			const Target = Y * RowSize + 1 + X * 3

			buffer.writeu8(Raw, Target, buffer.readu8(Rgba, Source))
			buffer.writeu8(Raw, Target + 1, buffer.readu8(Rgba, Source + 1))
			buffer.writeu8(Raw, Target + 2, buffer.readu8(Rgba, Source + 2))
		end
	end

	const Blocks = (RawSize + MaxStored - 1) // MaxStored
	const Zlib = buffer.create(2 + RawSize + Blocks * 5 + 4)
	local Cursor = 2

	buffer.writeu8(Zlib, 0, 0x78)
	buffer.writeu8(Zlib, 1, 0x01)

	for Block = 0, Blocks - 1 do
		const Start = Block * MaxStored
		const Length = math.min(MaxStored, RawSize - Start)

		buffer.writeu8(Zlib, Cursor, if Block == Blocks - 1 then 1 else 0)
		buffer.writeu16(Zlib, Cursor + 1, Length)
		buffer.writeu16(Zlib, Cursor + 3, bit32.bxor(Length, 0xFFFF))
		buffer.copy(Zlib, Cursor + 5, Raw, Start, Length)
		Cursor += 5 + Length
	end

	WriteU32BigEndian(Zlib, Cursor, Adler32(Raw, RawSize))

	const Header = buffer.create(13)

	WriteU32BigEndian(Header, 0, Width)
	WriteU32BigEndian(Header, 4, Height)
	buffer.writeu8(Header, 8, 8)
	buffer.writeu8(Header, 9, 2)

	const Ihdr = buffer.tostring(Chunk("IHDR", Header))
	const Idat = buffer.tostring(Chunk("IDAT", Zlib))
	const Iend = buffer.tostring(Chunk("IEND", buffer.create(0)))

	return `{Signature}{Ihdr}{Idat}{Iend}`
end

return Encode
