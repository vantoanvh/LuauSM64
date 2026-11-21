--!strict
--!optimize 2

--[[
	Port of src/game/print.c.
]]

const Gbi = require("../rom/gbi")
const IncludeConfigH = require("../../include/config_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Memory = require("./memory")
const Registry = require("../../groups/registry")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")

-- from src/game/print.c:TextLabel
export type TextLabel = {
	x: number,
	y: number,
	length: number,
	buffer: buffer, -- [50]
}

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/print.luau:scratch
const Scratch = {
	parse_width_field_digits = table.create(12, 0),
	print_text_fmt_int_srcIndex = { 0 },
	print_text_fmt_int_width = { 0 },
	print_text_fmt_int_zeroPad = { 0 },
	print_text_fmt_int_len = { 0 },
	render_textrect_rectBaseX = { 0 },
	render_textrect_rectBaseY = { 0 },
}

-- from src/game/print.c:data
const print_ = {
	-- from src/game/print.c:sTextLabels L27-27
	sTextLabels = {
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	} :: { TextLabel? },
	-- from src/game/print.c:sTextLabelsCount L28-28
	sTextLabelsCount = 0,
}

-- from src/game/print.c:TextLabel (zero-filled constructor)
function print_.new_TextLabel(): TextLabel
	return { x = 0, y = 0, length = 0, buffer = buffer.create(50) } :: TextLabel
end

-- from src/game/print.c:int_pow L33-42
function print_.int_pow(n: number, exponent: number): number
	local result = 1

	for i = 0, exponent - 1 do
		result = S32(n * result)
	end

	return result
end

-- from src/game/print.c:format_integer L48-119
function print_.format_integer(n: number, base: number, dest: buffer, destOffset: number, totalLength: { number }, width: number, zeroPad: number)
	width = U8(TruncS32(width))
	zeroPad = S8(TruncS32(zeroPad))
	local numDigits = 0
	local len = 0
	local negative = IncludePRUltratypesH.FALSE
	local pad = 0

	if zeroPad == IncludePRUltratypesH.TRUE then
		pad = 48 -- '0'
	else
		pad = -1
	end

	if n ~= 0 then
		-- Formats a negative number for negative prefix.
		if n < 0 then
			n = S32(-n)
			negative = IncludePRUltratypesH.TRUE
		end

		-- Increments the number of digits until length is long enough.
		while true do
			const powBase = U32(print_.int_pow(base, numDigits))

			if powBase > U32(n) then
				break
			end

			numDigits = S32(numDigits + 1)
		end

		-- Add leading pad to fit width.
		if width > numDigits then
			len = 0

			while len < width - numDigits do
				buffer.writei8(dest, destOffset + len, pad)
				len = S32(len + 1)
			end

			-- Needs 1 length to print negative prefix.
			if negative == IncludePRUltratypesH.TRUE then
				len = S32(len - 1)
			end
		end

		-- Use 'M' prefix to indicate negative numbers.
		if negative == IncludePRUltratypesH.TRUE then
			buffer.writei8(dest, destOffset + len, 77) -- 'M'
			len = S32(len + 1)
		end

		-- Transfer the digits into the proper base.
		for i = numDigits - 1, 0, -1 do
			const powBase = U32(print_.int_pow(base, i))
			const digit = S8(U32(n) // powBase)

			if digit < 10 then
				buffer.writei8(dest, destOffset + len + (numDigits - 1) - i, S8(digit + 48)) -- '0'
			else
				buffer.writei8(dest, destOffset + len + (numDigits - 1) - i, S8(digit + 55)) -- '7'
			end

			n = S32(n - U32(digit * powBase))
		end
	else -- n is zero.
		numDigits = 1

		if width > numDigits then
			len = 0

			while len < width - numDigits do
				buffer.writei8(dest, destOffset + len, pad)
				len = S32(len + 1)
			end
		end

		buffer.writei8(dest, destOffset + len, 48) -- '0'
	end

	totalLength[1] = S32(totalLength[1] + numDigits + len)
end

-- from src/game/print.c:parse_width_field L126-160
function print_.parse_width_field(str: string, srcIndex: { number }, width: { number }, zeroPad: { number })
	const digits = Scratch.parse_width_field_digits
	local digitsLen = 0

	-- If first character is 0, then the string should be zero padded.
	if (string.byte(str, srcIndex[1] + 1) or 0) == 48 then -- '0'
		zeroPad[1] = IncludePRUltratypesH.TRUE
	end

	-- Read width digits up until the 'd' or 'x' format specifier.
	while (string.byte(str, srcIndex[1] + 1) or 0) ~= 100 and (string.byte(str, srcIndex[1] + 1) or 0) ~= 120 do -- 'd', 'x'
		digits[digitsLen + 1] = S8((string.byte(str, srcIndex[1] + 1) or 0) - 48) -- '0'

		if digits[digitsLen + 1] < 0 or digits[digitsLen + 1] >= 10 then -- not a valid digit
			width[1] = 0

			return
		end

		digitsLen = S8(digitsLen + 1)
		srcIndex[1] = S32(srcIndex[1] + 1)
	end

	-- No digits
	if digitsLen == 0 then
		return
	end

	-- Sum the digits to calculate the total width.
	for i = 0, digitsLen - 2 do
		width[1] = U8(width[1] + (digitsLen - i - 1) * 10 * digits[i + 1])
	end

	width[1] = U8(width[1] + digits[digitsLen])
end

-- from src/game/print.c:print_text_fmt_int L169-217
function print_.print_text_fmt_int(x: number, y: number, str: string, n: number)
	local zeroPad = IncludePRUltratypesH.FALSE
	local width = 0
	local base = 0
	local len = 0
	local srcIndex = 0

	-- Don't continue if there is no memory to do so.
	print_.sTextLabels[print_.sTextLabelsCount + 1] = print_.new_TextLabel()

	const label = print_.sTextLabels[print_.sTextLabelsCount + 1] :: TextLabel

	label.x = U32(x)
	label.y = U32(y)

	local c = string.byte(str, srcIndex + 1) or 0

	while c ~= 0 do
		if c == 37 then -- '%'
			srcIndex = S32(srcIndex + 1)
			Scratch.print_text_fmt_int_srcIndex[1] = srcIndex
			Scratch.print_text_fmt_int_width[1] = width
			Scratch.print_text_fmt_int_zeroPad[1] = zeroPad
			print_.parse_width_field(str, Scratch.print_text_fmt_int_srcIndex, Scratch.print_text_fmt_int_width, Scratch.print_text_fmt_int_zeroPad)
			srcIndex = Scratch.print_text_fmt_int_srcIndex[1]
			width = Scratch.print_text_fmt_int_width[1]
			zeroPad = Scratch.print_text_fmt_int_zeroPad[1]

			if (string.byte(str, srcIndex + 1) or 0) ~= 100 and (string.byte(str, srcIndex + 1) or 0) ~= 120 then -- 'd', 'x'
				break
			end

			if (string.byte(str, srcIndex + 1) or 0) == 100 then -- 'd'
				base = 10
			end

			if (string.byte(str, srcIndex + 1) or 0) == 120 then -- 'x'
				base = 16
			end

			srcIndex = S32(srcIndex + 1)
			Scratch.print_text_fmt_int_len[1] = len
			print_.format_integer(n, base, label.buffer, len, Scratch.print_text_fmt_int_len, width, zeroPad)
			len = Scratch.print_text_fmt_int_len[1]
		else -- straight copy
			buffer.writei8(label.buffer, len, c)
			len = S32(len + 1)
			srcIndex = S32(srcIndex + 1)
		end

		c = string.byte(str, srcIndex + 1) or 0
	end

	label.length = S16(len)
	print_.sTextLabelsCount = S16(print_.sTextLabelsCount + 1)
end

-- from src/game/print.c:print_text L222-248
function print_.print_text(x: number, y: number, str: string)
	local length = 0
	local srcIndex = 0

	-- Don't continue if there is no memory to do so.
	print_.sTextLabels[print_.sTextLabelsCount + 1] = print_.new_TextLabel()

	const label = print_.sTextLabels[print_.sTextLabelsCount + 1] :: TextLabel

	label.x = U32(x)
	label.y = U32(y)

	local c = string.byte(str, srcIndex + 1) or 0

	-- Set the array with the text to print while finding length.
	while c ~= 0 do
		buffer.writei8(label.buffer, length, c)
		length = S32(length + 1)
		srcIndex = S32(srcIndex + 1)
		c = string.byte(str, srcIndex + 1) or 0
	end

	label.length = S16(length)
	print_.sTextLabelsCount = S16(print_.sTextLabelsCount + 1)
end

-- from src/game/print.c:print_text_centered L253-294
function print_.print_text_centered(x: number, y: number, str: string)
	local length = 0
	local srcIndex = 0

	-- Don't continue if there is no memory to do so.
	print_.sTextLabels[print_.sTextLabelsCount + 1] = print_.new_TextLabel()

	const label = print_.sTextLabels[print_.sTextLabelsCount + 1] :: TextLabel
	local c = string.byte(str, srcIndex + 1) or 0

	-- Set the array with the text to print while finding length.
	while c ~= 0 do
		buffer.writei8(label.buffer, length, c)
		length = S32(length + 1)
		srcIndex = S32(srcIndex + 1)
		c = string.byte(str, srcIndex + 1) or 0
	end

	label.length = S16(length)
	label.x = U32(x - 12 * length // 2)
	label.y = U32(y)
	print_.sTextLabelsCount = S16(print_.sTextLabelsCount + 1)
end

-- from src/game/print.c:char_to_glyph_index L299-361
function print_.char_to_glyph_index(c: number): number
	c = S8(TruncS32(c))

	if c >= 65 and c <= 90 then -- 'A', 'Z'
		return S8(c - 55)
	end

	if c >= 97 and c <= 122 then -- 'a', 'z'
		return S8(c - 87)
	end

	if c >= 48 and c <= 57 then -- '0', '9'
		return S8(c - 48)
	end

	if c == 32 then -- ' '
		return Registry.Members.src__game__print_h.GLYPH_SPACE
	end

	if c == 33 then -- '!'
		return Registry.Members.src__game__print_h.GLYPH_EXCLAMATION_PNT -- !, JP only
	end

	if c == 35 then -- '#'
		return Registry.Members.src__game__print_h.GLYPH_TWO_EXCLAMATION -- !!, JP only
	end

	if c == 63 then -- '?'
		return Registry.Members.src__game__print_h.GLYPH_QUESTION_MARK -- ?, JP only
	end

	if c == 38 then -- '&'
		return Registry.Members.src__game__print_h.GLYPH_AMPERSAND -- &, JP only
	end

	if c == 37 then -- '%'
		return Registry.Members.src__game__print_h.GLYPH_PERCENT -- %, JP only
	end

	if c == 42 then -- '*'
		return Registry.Members.src__game__print_h.GLYPH_MULTIPLY -- x
	end

	if c == 43 then -- '+'
		return Registry.Members.src__game__print_h.GLYPH_COIN -- coin
	end

	if c == 44 then -- ','
		return Registry.Members.src__game__print_h.GLYPH_MARIO_HEAD -- Imagine I drew Mario's head
	end

	if c == 45 then -- '-'
		return Registry.Members.src__game__print_h.GLYPH_STAR -- star
	end

	if c == 46 then -- '.'
		return Registry.Members.src__game__print_h.GLYPH_PERIOD -- large shaded dot, JP only
	end

	if c == 47 then -- '/'
		return Registry.Members.src__game__print_h.GLYPH_BETA_KEY -- beta key, JP only. Reused for U-umlaut in EU.
	end

	return Registry.Members.src__game__print_h.GLYPH_SPACE
end

-- from src/game/print.c:add_glyph_texture L366-376
function print_.add_glyph_texture(glyphIndex: number)
	glyphIndex = S8(TruncS32(glyphIndex))
	const glyphs = Memory.segmented_to_virtual(Segment2Symbols.main_hud_lut)

	Gbi.gDPPipeSync()
	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Rom.ReadU32(glyphs + 4 * glyphIndex))
	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_load_tex_block)
end

-- from src/game/print.c:clip_to_bounds L382-398
function print_.clip_to_bounds(x: { number }, y: { number })
	if x[1] < Registry.Members.src__game__print_h.TEXRECT_MIN_X then
		x[1] = Registry.Members.src__game__print_h.TEXRECT_MIN_X
	end

	if x[1] > Registry.Members.src__game__print_h.TEXRECT_MAX_X then
		x[1] = Registry.Members.src__game__print_h.TEXRECT_MAX_X
	end

	if y[1] < Registry.Members.src__game__print_h.TEXRECT_MIN_Y then
		y[1] = Registry.Members.src__game__print_h.TEXRECT_MIN_Y
	end

	if y[1] > Registry.Members.src__game__print_h.TEXRECT_MAX_Y then
		y[1] = Registry.Members.src__game__print_h.TEXRECT_MAX_Y
	end
end

-- from src/game/print.c:render_textrect L408-423
function print_.render_textrect(x: number, y: number, pos: number)
	Scratch.render_textrect_rectBaseX[1] = x + pos * 12
	Scratch.render_textrect_rectBaseY[1] = 224 - y

	-- For widescreen we must allow drawing outside the usual area
	print_.clip_to_bounds(Scratch.render_textrect_rectBaseX, Scratch.render_textrect_rectBaseY)

	const rectX = Scratch.render_textrect_rectBaseX[1]
	const rectY = Scratch.render_textrect_rectBaseY[1]

	Gbi.gSPTextureRectangle(bit32.lshift(rectX, 2), bit32.lshift(rectY, 2), bit32.lshift(rectX + 15, 2), bit32.lshift(rectY + 15, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(4, 10), bit32.lshift(1, 10))
end

-- from src/game/print.c:render_text_labels L429-525
function print_.render_text_labels()
	if print_.sTextLabelsCount == 0 then
		return
	end

	const mtx = Gbi.alloc_display_list(64)

	if mtx == nil then
		print_.sTextLabelsCount = 0

		return
	end

	Gbi.guOrtho(mtx, 0.0, IncludeConfigH.SCREEN_WIDTH, 0.0, IncludeConfigH.SCREEN_HEIGHT, -10.0, 10.0, 1.0)
	Gbi.gSPPerspNormalize(0xFFFF)
	Gbi.gSPMatrix(mtx, bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_begin)

	for i = 0, print_.sTextLabelsCount - 1 do
		const label = print_.sTextLabels[i + 1] :: TextLabel

		for j = 0, label.length - 1 do
			const glyphIndex = print_.char_to_glyph_index(buffer.readi8(label.buffer, j))

			if glyphIndex ~= Registry.Members.src__game__print_h.GLYPH_SPACE then
				print_.add_glyph_texture(glyphIndex)
				print_.render_textrect(label.x, label.y, j)
			end
		end
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_hud_img_end)
	print_.sTextLabelsCount = 0
end

return print_
