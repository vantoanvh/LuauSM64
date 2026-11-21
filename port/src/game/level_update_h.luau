--!strict
--!optimize 2

--[[
	Port of src/game/level_update.h.
]]

-- from src/game/level_update.h:CreditsEntry
export type CreditsEntry = {
	levelNum: number,
	areaIndex: number,
	unk02: number,
	marioAngle: number,
	marioPos: { number },
	unk0C: { string }?,
}

-- from src/game/level_update.h:WarpDest
export type WarpDest = {
	type_: number,
	levelNum: number,
	areaIdx: number,
	nodeId: number,
	arg: number,
}

-- from src/game/level_update.h:HudDisplay
export type HudDisplay = {
	lives: number,
	coins: number,
	stars: number,
	wedges: number,
	keys: number,
	flags: number,
	timer: number,
}

-- from src/game/level_update.h:data
const level_update_h = {
	TIMER_CONTROL_SHOW = 0,
	TIMER_CONTROL_START = 1,
	TIMER_CONTROL_STOP = 2,
	TIMER_CONTROL_HIDE = 3,
	WARP_OP_NONE = 0x00,
	WARP_OP_UNKNOWN_01 = 0x01,
	WARP_OP_UNKNOWN_02 = 0x02,
	WARP_OP_WARP_DOOR = 0x03,
	WARP_OP_WARP_OBJECT = 0x04,
	WARP_OP_TELEPORT = 0x05,
	WARP_OP_STAR_EXIT = 0x11,
	WARP_OP_DEATH = 0x12,
	WARP_OP_WARP_FLOOR = 0x13,
	WARP_OP_GAME_OVER = 0x14,
	WARP_OP_CREDITS_END = 0x15,
	WARP_OP_DEMO_NEXT = 0x16,
	WARP_OP_CREDITS_START = 0x17,
	WARP_OP_CREDITS_NEXT = 0x18,
	WARP_OP_DEMO_END = 0x19,
	WARP_OP_TRIGGERS_LEVEL_SELECT = 0x10,
	MARIO_SPAWN_DOOR_WARP = 0x01,
	MARIO_SPAWN_UNKNOWN_02 = 0x02,
	MARIO_SPAWN_UNKNOWN_03 = 0x03,
	MARIO_SPAWN_TELEPORT = 0x04,
	MARIO_SPAWN_INSTANT_ACTIVE = 0x10,
	MARIO_SPAWN_SWIMMING = 0x11,
	MARIO_SPAWN_AIRBORNE = 0x12,
	MARIO_SPAWN_HARD_AIR_KNOCKBACK = 0x13,
	MARIO_SPAWN_SPIN_AIRBORNE_CIRCLE = 0x14,
	MARIO_SPAWN_DEATH = 0x15,
	MARIO_SPAWN_SPIN_AIRBORNE = 0x16,
	MARIO_SPAWN_FLYING = 0x17,
	MARIO_SPAWN_PAINTING_STAR_COLLECT = 0x20,
	MARIO_SPAWN_PAINTING_DEATH = 0x21,
	MARIO_SPAWN_AIRBORNE_STAR_COLLECT = 0x22,
	MARIO_SPAWN_AIRBORNE_DEATH = 0x23,
	MARIO_SPAWN_LAUNCH_STAR_COLLECT = 0x24,
	MARIO_SPAWN_LAUNCH_DEATH = 0x25,
	MARIO_SPAWN_UNKNOWN_27 = 0x27,
	WARP_NODE_00 = 0,
	WARP_NODE_01 = 1,
	WARP_NODE_02 = 2,
	WARP_NODE_03 = 3,
	WARP_NODE_04 = 4,
	WARP_NODE_05 = 5,
	WARP_NODE_06 = 6,
	WARP_NODE_07 = 7,
	WARP_NODE_08 = 8,
	WARP_NODE_09 = 9,
	WARP_NODE_0A = 10,
	WARP_NODE_0B = 11,
	WARP_NODE_0C = 12,
	WARP_NODE_0D = 13,
	WARP_NODE_0E = 14,
	WARP_NODE_0F = 15,
	WARP_NODE_10 = 16,
	WARP_NODE_11 = 17,
	WARP_NODE_14 = 20,
	WARP_NODE_15 = 21,
	WARP_NODE_16 = 22,
	WARP_NODE_17 = 23,
	WARP_NODE_18 = 24,
	WARP_NODE_19 = 25,
	WARP_NODE_1A = 26,
	WARP_NODE_1B = 27,
	WARP_NODE_1C = 28,
	WARP_NODE_1D = 29,
	WARP_NODE_1E = 30,
	WARP_NODE_1F = 31,
	WARP_NODE_20 = 32,
	WARP_NODE_21 = 33,
	WARP_NODE_22 = 34,
	WARP_NODE_23 = 35,
	WARP_NODE_24 = 36,
	WARP_NODE_25 = 37,
	WARP_NODE_26 = 38,
	WARP_NODE_27 = 39,
	WARP_NODE_28 = 40,
	WARP_NODE_29 = 41,
	WARP_NODE_2A = 42,
	WARP_NODE_32 = 50,
	WARP_NODE_33 = 51,
	WARP_NODE_34 = 52,
	WARP_NODE_35 = 53,
	WARP_NODE_36 = 54,
	WARP_NODE_37 = 55,
	WARP_NODE_38 = 56,
	WARP_NODE_3A = 58,
	WARP_NODE_64 = 100,
	WARP_NODE_65 = 101,
	WARP_NODE_66 = 102,
	WARP_NODE_67 = 103,
	WARP_NODE_68 = 104,
	WARP_NODE_69 = 105,
	WARP_NODE_6B = 107,
	WARP_NODE_6C = 108,
	WARP_NODE_6D = 109,
	WARP_NODE_SUCCESS = 240,
	WARP_NODE_DEATH = 241,
	WARP_NODE_TOTWC = 242,
	WARP_NODE_WARP_FLOOR = 243,
	WARP_NODE_CREDITS_START = 248,
	WARP_NODE_CREDITS_MIN = 248,
	WARP_NODE_CREDITS_NEXT = 249,
	WARP_NODE_CREDITS_END = 250,
	HUD_DISPLAY_FLAG_LIVES = 1,
	HUD_DISPLAY_FLAG_COIN_COUNT = 2,
	HUD_DISPLAY_FLAG_STAR_COUNT = 4,
	HUD_DISPLAY_FLAG_CAMERA_AND_POWER = 8,
	HUD_DISPLAY_FLAG_KEYS = 16,
	HUD_DISPLAY_FLAG_UNKNOWN_0020 = 32,
	HUD_DISPLAY_FLAG_TIMER = 64,
	HUD_DISPLAY_FLAG_EMPHASIZE_POWER = 32768,
	HUD_DISPLAY_NONE = 0,
	HUD_DISPLAY_DEFAULT = 63,
}

-- from src/game/level_update.h:CreditsEntry (zero-filled constructor)
function level_update_h.new_CreditsEntry(): CreditsEntry
	return {
		levelNum = 0,
		areaIndex = 0,
		unk02 = 0,
		marioAngle = 0,
		marioPos = table.create(3, 0),
		unk0C = nil,
	} :: CreditsEntry
end

-- from src/game/level_update.h:WarpDest (zero-filled constructor)
function level_update_h.new_WarpDest(): WarpDest
	return { type_ = 0, levelNum = 0, areaIdx = 0, nodeId = 0, arg = 0 } :: WarpDest
end

-- from src/game/level_update.h:HudDisplay (zero-filled constructor)
function level_update_h.new_HudDisplay(): HudDisplay
	return { lives = 0, coins = 0, stars = 0, wedges = 0, keys = 0, flags = 0, timer = 0 } :: HudDisplay
end

return level_update_h
