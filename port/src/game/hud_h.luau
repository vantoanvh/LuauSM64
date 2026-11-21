--!strict
--!optimize 2

--[[
	Port of src/game/hud.h.
]]

-- from src/game/hud.h:data
const hud_h = {
	POWER_METER_HIDDEN = 0,
	POWER_METER_EMPHASIZED = 1,
	POWER_METER_DEEMPHASIZING = 2,
	POWER_METER_HIDING = 3,
	POWER_METER_VISIBLE = 4,
	GLYPH_CAM_CAMERA = 0,
	GLYPH_CAM_MARIO_HEAD = 1,
	GLYPH_CAM_LAKITU_HEAD = 2,
	GLYPH_CAM_FIXED = 3,
	GLYPH_CAM_ARROW_UP = 4,
	GLYPH_CAM_ARROW_DOWN = 5,
}

return hud_h
