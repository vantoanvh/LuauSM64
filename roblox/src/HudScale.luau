--!strict
--!optimize 2

--[[
	The size of a pixel of the game's own picture on the screen: the N64 draws the HUD and the menus in 320 x 240 pixels, and the picture is
	scaled to the screen's height, so an interface that wants to look like part of it (the loading screen) paints its art in pixels of that
	size, a whole number of screen pixels so that each stays a clean square.
]]

const N64Height = 240

-- How many screen pixels one N64 pixel is on a screen of this size (at least one)
const function HudScale(Screen: Vector2): number
	return math.max(Screen.Y // N64Height, 1)
end

return HudScale
