--!strict
--!optimize 2

--[[
	Types of src/game/camera.
]]

-- from src/game/camera.c:UnusedDanceInfo
export type UnusedDanceInfo = {
	point: { number },
	distTarget: number,
	distMultiplier: number,
}

const camera_types = {}

-- from src/game/camera.c:UnusedDanceInfo (zero-filled constructor)
function camera_types.new_UnusedDanceInfo(): UnusedDanceInfo
	return { point = table.create(3, 0), distTarget = 0, distMultiplier = 0 } :: UnusedDanceInfo
end

return camera_types
