--!strict
--!optimize 2

--[[
	Port of include/mario_geo_switch_case_ids.h.
]]

-- from include/mario_geo_switch_case_ids.h:data
const mario_geo_switch_case_ids_h = {
	MARIO_EYES_BLINK = 0,
	MARIO_EYES_OPEN = 1,
	MARIO_EYES_HALF_CLOSED = 2,
	MARIO_EYES_CLOSED = 3,
	MARIO_EYES_LOOK_LEFT = 4,
	MARIO_EYES_LOOK_RIGHT = 5,
	MARIO_EYES_LOOK_UP = 6,
	MARIO_EYES_LOOK_DOWN = 7,
	MARIO_EYES_DEAD = 8,
	MARIO_HAND_FISTS = 0,
	MARIO_HAND_OPEN = 1,
	MARIO_HAND_PEACE_SIGN = 2,
	MARIO_HAND_HOLDING_CAP = 3,
	MARIO_HAND_HOLDING_WING_CAP = 4,
	MARIO_HAND_RIGHT_OPEN = 5,
	MARIO_HAS_DEFAULT_CAP_ON = 0,
	MARIO_HAS_DEFAULT_CAP_OFF = 1,
	MARIO_HAS_WING_CAP_ON = 2,
	MARIO_HAS_WING_CAP_OFF = 3,
	GRAB_POS_NULL = 0,
	GRAB_POS_LIGHT_OBJ = 1,
	GRAB_POS_HEAVY_OBJ = 2,
	GRAB_POS_BOWSER = 3,
}

return mario_geo_switch_case_ids_h
