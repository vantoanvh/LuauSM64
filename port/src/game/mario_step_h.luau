--!strict
--!optimize 2

--[[
	Port of src/game/mario_step.h.
]]

-- from src/game/mario_step.h:BullyCollisionData
export type BullyCollisionData = {
	conversionRatio: number,
	radius: number,
	posX: number,
	posZ: number,
	velX: number,
	velZ: number,
}

const mario_step_h = {}

-- from src/game/mario_step.h:BullyCollisionData (zero-filled constructor)
function mario_step_h.new_BullyCollisionData(): BullyCollisionData
	return { conversionRatio = 0, radius = 0, posX = 0, posZ = 0, velX = 0, velZ = 0 } :: BullyCollisionData
end

return mario_step_h
