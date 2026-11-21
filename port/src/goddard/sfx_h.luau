--!strict
--!optimize 2

--[[
	Port of src/goddard/sfx.h.
]]

-- from src/goddard/sfx.h:data
const sfx_h = {
	GD_SFX_NONE = 0,
	GD_SFX_HAND_APPEAR = 1,
	GD_SFX_HAND_DISAPPEAR = 2,
	GD_SFX_UNUSED_COIN = 4,
	GD_SFX_PINCH_FACE = 8,
	GD_SFX_PINCH_FACE_2 = 16,
	GD_SFX_LET_GO_FACE = 32,
	GD_SFX_CAM_ZOOM_IN = 64,
	GD_SFX_CAM_ZOOM_OUT = 128,
}

return sfx_h
