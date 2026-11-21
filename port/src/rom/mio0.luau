--!strict
--!optimize 2
--!native

--[[
	MIO0 decompression.

	Format
		Header (big endian): "MIO0", decompressed size, offset of the compressed pairs, offset of the raw bytes (both from the
		header). The layout bits start at 0x10, most significant bit first: 1 copies one raw byte, 0 reads a 16 bit pair from the
		compressed pairs: length - 3 in the top 4 bits, distance - 1 in the low 12 bits, copied from the output written so far.
]]

-- Decompresses the block at Source[SourceOffset] into Destination[DestinationOffset]; returns the decompressed size
const function DecompressMio0(Source: buffer, SourceOffset: number, Destination: buffer, DestinationOffset: number): number
	if buffer.readstring(Source, SourceOffset, 4) ~= "MIO0" then
		error(`no MIO0 block at {SourceOffset}`)
	end

	const Size = bit32.byteswap(buffer.readu32(Source, SourceOffset + 4))
	const End = DestinationOffset + Size
	local Output = DestinationOffset
	local PairsAt = SourceOffset + bit32.byteswap(buffer.readu32(Source, SourceOffset + 8))
	local RawAt = SourceOffset + bit32.byteswap(buffer.readu32(Source, SourceOffset + 12))
	local LayoutAt = SourceOffset + 16
	local Bits = 0
	local BitsLeft = 0

	while Output < End do
		if BitsLeft == 0 then
			Bits = bit32.byteswap(buffer.readu32(Source, LayoutAt))
			LayoutAt += 4
			BitsLeft = 32
		end

		const IsRaw = bit32.btest(Bits, 0x80000000)

		Bits = bit32.lshift(Bits, 1)
		BitsLeft -= 1

		if IsRaw then
			buffer.writeu8(Destination, Output, buffer.readu8(Source, RawAt))
			RawAt += 1
			Output += 1
		else
			const Pair = bit32.rshift(bit32.byteswap(buffer.readu16(Source, PairsAt)), 16)
			const Length = bit32.rshift(Pair, 12) + 3
			const From = Output - bit32.band(Pair, 0xFFF) - 1

			PairsAt += 2

			if From + Length <= Output then
				buffer.copy(Destination, Output, Destination, From, Length)
			else
				for Index = 0, Length - 1 do
					buffer.writeu8(Destination, Output + Index, buffer.readu8(Destination, From + Index))
				end
			end

			Output += Length
		end
	end

	return Size
end

return DecompressMio0
