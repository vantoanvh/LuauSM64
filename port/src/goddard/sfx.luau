--!strict
--!optimize 2

--[[
	Port of src/goddard/sfx.c.
]]

const SfxH = require("./sfx_h")

-- from src/goddard/sfx.c:data
const sfx = {
	-- from src/goddard/sfx.c:sCurrSfx L5-5
	sCurrSfx = 0,
	-- from src/goddard/sfx.c:sPrevSfx L6-6
	sPrevSfx = 0,
}

-- from src/goddard/sfx.c:gd_reset_sfx L11-14
function sfx.gd_reset_sfx()
	sfx.sPrevSfx = SfxH.GD_SFX_NONE
	sfx.sCurrSfx = SfxH.GD_SFX_NONE
end

-- from src/goddard/sfx.c:gd_new_sfx_to_play L20-22
function sfx.gd_new_sfx_to_play(): number
	return bit32.band(bit32.bnot(sfx.sPrevSfx), sfx.sCurrSfx)
end

-- from src/goddard/sfx.c:gd_sfx_update L27-30
function sfx.gd_sfx_update()
	sfx.sPrevSfx = sfx.sCurrSfx
	sfx.sCurrSfx = SfxH.GD_SFX_NONE
end

-- from src/goddard/sfx.c:gd_play_sfx L36-38
function sfx.gd_play_sfx(sfxId: number)
	sfx.sCurrSfx = bit32.bor(sfx.sCurrSfx, sfxId)
end

return sfx
