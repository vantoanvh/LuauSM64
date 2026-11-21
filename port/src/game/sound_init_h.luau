--!strict
--!optimize 2

--[[
	Port of src/game/sound_init.h.
]]

const Registry = require("../../groups/registry")

-- from src/game/sound_init.h:data
const sound_init_h = {
	SOUND_MENU_FLAG_HANDAPPEAR = 0x01,
	SOUND_MENU_FLAG_HANDISAPPEAR = 0x02,
	SOUND_MENU_FLAG_UNKNOWN1 = 0x04,
	SOUND_MENU_FLAG_PINCHMARIOFACE = 0x08,
	SOUND_MENU_FLAG_PINCHMARIOFACE2 = 0x10,
	SOUND_MENU_FLAG_LETGOMARIOFACE = 0x20,
	SOUND_MENU_FLAG_CAMERAZOOMIN = 0x40,
	SOUND_MENU_FLAG_CAMERAZOOMOUT = 0x80,
	SOUND_MENU_MODE_STEREO = 0,
	SOUND_MENU_MODE_MONO = 1,
	SOUND_MENU_MODE_HEADSET = 2,
}

Registry.Register("src__game__sound_init_h", sound_init_h)

return sound_init_h
