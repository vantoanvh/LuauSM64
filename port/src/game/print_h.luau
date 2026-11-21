--!strict
--!optimize 2

--[[
	Port of src/game/print.h.
]]

const Registry = require("../../groups/registry")

-- from src/game/print.h:data
const print_h = {
	TEXRECT_MIN_X = 10,
	TEXRECT_MAX_X = 300,
	TEXRECT_MIN_Y = 5,
	TEXRECT_MAX_Y = 220,
	GLYPH_SPACE = -1,
	GLYPH_U = 30,
	GLYPH_EXCLAMATION_PNT = 36,
	GLYPH_TWO_EXCLAMATION = 37,
	GLYPH_QUESTION_MARK = 38,
	GLYPH_AMPERSAND = 39,
	GLYPH_PERCENT = 40,
	GLYPH_MULTIPLY = 50,
	GLYPH_COIN = 51,
	GLYPH_MARIO_HEAD = 52,
	GLYPH_STAR = 53,
	GLYPH_PERIOD = 54,
	GLYPH_BETA_KEY = 55,
	GLYPH_APOSTROPHE = 56,
	GLYPH_DOUBLE_QUOTE = 57,
	GLYPH_UMLAUT = 58,
}

Registry.Register("src__game__print_h", print_h)

return print_h
