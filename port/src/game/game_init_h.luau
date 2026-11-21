--!strict
--!optimize 2

--[[
	Port of src/game/game_init.h.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

-- from src/game/game_init.h:GfxPool
export type GfxPool = {
	buffer: { unknown }, -- [6400]
	spTask: GroupsTypesHPlus3.SPTask,
}

-- from src/game/game_init.h:DemoInput
export type DemoInput = {
	timer: number,
	rawStickX: number,
	rawStickY: number,
	buttonMask: number,
}

-- from src/game/game_init.h:data
const game_init_h = {
	GFX_POOL_SIZE = 6400,
}

Registry.Register("src__game__game_init_h", game_init_h)

-- from src/game/game_init.h:GfxPool (zero-filled constructor)
function game_init_h.new_GfxPool(): GfxPool
	return { buffer = table.create(6400, 0), spTask = { task = 0, msgqueue = nil, msg = nil, state = 0 } } :: GfxPool
end

-- from src/game/game_init.h:DemoInput (zero-filled constructor)
function game_init_h.new_DemoInput(): DemoInput
	return { timer = 0, rawStickX = 0, rawStickY = 0, buttonMask = 0 } :: DemoInput
end

return game_init_h
