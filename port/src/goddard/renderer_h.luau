--!strict
--!optimize 2

--[[
	Port of src/goddard/renderer.h.
]]

-- from src/goddard/renderer.h:data
const renderer_h = {
	GD_PROP_OVERLAY = 4,
	GD_PROP_LIGHTING = 11,
	GD_PROP_AMB_COLOUR = 12,
	GD_PROP_DIFUSE_COLOUR = 13,
	GD_PROP_LIGHT_DIR = 15,
	GD_PROP_CULLING = 16,
	GD_PROP_STUB17 = 17,
	GD_PROP_STUB18 = 18,
	GD_PROP_STUB19 = 19,
	GD_PROP_STUB20 = 20,
	GD_PROP_STUB21 = 21,
	GD_PROP_ZBUF_FN = 22,
	GD_SCENE_YOSHI = 0,
	GD_SCENE_YOSHI1 = 1,
	GD_SCENE_REGULAR_MARIO = 2,
	GD_SCENE_DIZZY_MARIO = 3,
	GD_SCENE_CAR = 4,
	GD_SCENE_CAR5 = 5,
}

return renderer_h
