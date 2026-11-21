--!strict
--!optimize 2

--[[
	Types of src/game/behaviors/door_inc.
]]

-- from src/game/behaviors/door.inc.c:DoorAction
export type DoorAction = {
	flag: number,
	action: number,
}

const door_inc_types = {}

-- from src/game/behaviors/door.inc.c:DoorAction (zero-filled constructor)
function door_inc_types.new_DoorAction(): DoorAction
	return { flag = 0, action = 0 } :: DoorAction
end

return door_inc_types
