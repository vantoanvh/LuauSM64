--!strict
--!optimize 2

--[[
	Port of src/game/envfx_bubbles.h.
]]

-- from src/game/envfx_bubbles.h:data
const envfx_bubbles_h = {
	ENVFX_STATE_UNUSED = 0,
	ENVFX_STATE_SRC_X = 1,
	ENVFX_STATE_SRC_Y = 2,
	ENVFX_STATE_SRC_Z = 3,
	ENVFX_STATE_DEST_X = 4,
	ENVFX_STATE_DEST_Y = 5,
	ENVFX_STATE_DEST_Z = 6,
	ENVFX_STATE_PARTICLECOUNT = 7,
	ENVFX_STATE_PITCH = 8,
	ENVFX_STATE_YAW = 9,
}

return envfx_bubbles_h
