--!strict
--!optimize 2

--[[
	Types of src/game/behaviors/goomba_inc.
]]

-- from src/game/behaviors/goomba.inc.c:GoombaProperties
export type GoombaProperties = {
	scale: number,
	deathSound: number,
	drawDistance: number,
	damage: number,
}

const goomba_inc_types = {}

-- from src/game/behaviors/goomba.inc.c:GoombaProperties (zero-filled constructor)
function goomba_inc_types.new_GoombaProperties(): GoombaProperties
	return { scale = 0, deathSound = 0, drawDistance = 0, damage = 0 } :: GoombaProperties
end

return goomba_inc_types
