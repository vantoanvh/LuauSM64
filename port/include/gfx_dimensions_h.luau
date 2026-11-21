--!strict
--!optimize 2

--[[
	Port of include/gfx_dimensions.h.
]]

const IncludeConfigH = require("./config_h")

-- from include/gfx_dimensions.h:data
const gfx_dimensions_h = {
	GFX_DIMENSIONS_ASPECT_RATIO = 4.0 / 3.0,
}

-- from include/gfx_dimensions.h:GFX_DIMENSIONS_FROM_LEFT_EDGE L30-30
function gfx_dimensions_h.GFX_DIMENSIONS_FROM_LEFT_EDGE(v: number): number
	return v
end

-- from include/gfx_dimensions.h:GFX_DIMENSIONS_FROM_RIGHT_EDGE L31-31
function gfx_dimensions_h.GFX_DIMENSIONS_FROM_RIGHT_EDGE(v: number): number
	return IncludeConfigH.SCREEN_WIDTH - v
end

-- from include/gfx_dimensions.h:GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE L32-32
function gfx_dimensions_h.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(v: number): number
	return v
end

-- from include/gfx_dimensions.h:GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE L33-33
function gfx_dimensions_h.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(v: number): number
	return IncludeConfigH.SCREEN_WIDTH - v
end

gfx_dimensions_h.GFX_DIMENSIONS_FULL_RADIUS = 240 * (if gfx_dimensions_h.GFX_DIMENSIONS_ASPECT_RATIO > 1 then gfx_dimensions_h.GFX_DIMENSIONS_ASPECT_RATIO else 1) -- (SCREEN_HEIGHT * (GFX_DIMENSIONS_ASPECT_RATIO > 1 ? GFX_DIMENSIONS_ASPECT_RATIO : 1))

return gfx_dimensions_h
