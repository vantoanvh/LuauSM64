--!strict
--!optimize 2

--[[
	Types of src/game/ingame_menu, src/game/ingame_menu_h.
]]

-- from src/game/ingame_menu.c:MultiTextEntry
export type MultiTextEntry = {
	str: buffer, -- [5]
}

-- from src/game/ingame_menu.h:DialogEntry
export type DialogEntry = {
	unused: number,
	linesPerBox: number,
	leftOffset: number,
	width: number,
	str: number?,
}

const ingame_menu_plus1_types = {}

-- from src/game/ingame_menu.c:MultiTextEntry (zero-filled constructor)
function ingame_menu_plus1_types.new_MultiTextEntry(): MultiTextEntry
	return { str = buffer.create(5) } :: MultiTextEntry
end

-- from src/game/ingame_menu.h:DialogEntry (zero-filled constructor)
function ingame_menu_plus1_types.new_DialogEntry(): DialogEntry
	return { unused = 0, linesPerBox = 0, leftOffset = 0, width = 0, str = nil } :: DialogEntry
end

return ingame_menu_plus1_types
