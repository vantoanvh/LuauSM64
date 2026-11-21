--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_cutscene.h.
]]

-- from src/game/mario_actions_cutscene.h:data
const mario_actions_cutscene_h = {
	MARIO_DIALOG_STOP = 0,
	MARIO_DIALOG_LOOK_FRONT = 1,
	MARIO_DIALOG_LOOK_UP = 2,
	MARIO_DIALOG_LOOK_DOWN = 3,
	MARIO_DIALOG_STATUS_NONE = 0,
	MARIO_DIALOG_STATUS_START = 1,
	MARIO_DIALOG_STATUS_SPEAK = 2,
}

return mario_actions_cutscene_h
