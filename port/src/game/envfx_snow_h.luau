--!strict
--!optimize 2

--[[
	Port of src/game/envfx_snow.h.
]]

-- from src/game/envfx_snow.h:EnvFxParticle
export type EnvFxParticle = {
	isAlive: number,
	animFrame: number,
	xPos: number,
	yPos: number,
	zPos: number,
	angleAndDist: { number }, -- [2]
	unusedBubbleVar: number,
	bubbleY: number,
	filler: buffer, -- [24]
}

-- from src/game/envfx_snow.h:data
const envfx_snow_h = {
	ENVFX_MODE_NONE = 0,
	ENVFX_SNOW_NORMAL = 1,
	ENVFX_SNOW_WATER = 2,
	ENVFX_SNOW_BLIZZARD = 3,
	ENVFX_BUBBLE_START = 10,
	ENVFX_FLOWERS = 11,
	ENVFX_LAVA_BUBBLES = 12,
	ENVFX_WHIRLPOOL_BUBBLES = 13,
	ENVFX_JETSTREAM_BUBBLES = 14,
}

-- from src/game/envfx_snow.h:EnvFxParticle (zero-filled constructor)
function envfx_snow_h.new_EnvFxParticle(): EnvFxParticle
	return {
		isAlive = 0,
		animFrame = 0,
		xPos = 0,
		yPos = 0,
		zPos = 0,
		angleAndDist = table.create(2, 0),
		unusedBubbleVar = 0,
		bubbleY = 0,
		filler = buffer.create(24),
	} :: EnvFxParticle
end

return envfx_snow_h
