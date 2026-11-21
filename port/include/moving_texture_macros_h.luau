--!strict
--!optimize 2

--[[
	Port of include/moving_texture_macros.h.
]]

-- from include/moving_texture_macros.h:data
const moving_texture_macros_h = {
	TEXTURE_WATER = 0,
	TEXTURE_MIST = 1,
	TEXTURE_JRB_WATER = 2,
	TEXTURE_UNK_WATER = 3,
	TEXTURE_LAVA = 4,
	TEX_QUICKSAND_SSL = 5,
	TEX_PYRAMID_SAND_SSL = 6,
	TEX_YELLOW_TRI_TTC = 7,
	ROTATE_CLOCKWISE = 0,
	ROTATE_COUNTER_CLOCKWISE = 1,
}

-- from include/moving_texture_macros.h:MOV_TEX_INIT_LOAD L21-22
function moving_texture_macros_h.MOV_TEX_INIT_LOAD(amount: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_4_BOX_TRIS L25-26
function moving_texture_macros_h.MOV_TEX_4_BOX_TRIS(x: number, z: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_DEFINE L29-30
function moving_texture_macros_h.MOV_TEX_DEFINE(text: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_SPD L33-34
function moving_texture_macros_h.MOV_TEX_SPD(speed: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ROT_SPEED L37-38
function moving_texture_macros_h.MOV_TEX_ROT_SPEED(rotspeed: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ROT_SCALE L41-42
function moving_texture_macros_h.MOV_TEX_ROT_SCALE(rotscale: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ROT L45-46
function moving_texture_macros_h.MOV_TEX_ROT(rot: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ALPHA L49-50
function moving_texture_macros_h.MOV_TEX_ALPHA(alpha: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_TRIS L53-54
function moving_texture_macros_h.MOV_TEX_TRIS(x: number, y: number, z: number, param1: number, param2: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ROT_TRIS L57-58
function moving_texture_macros_h.MOV_TEX_ROT_TRIS(x: number, y: number, z: number, rotx: number, roty: number, rotz: number, param1: number, param2: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_LIGHT_TRIS L61-62
function moving_texture_macros_h.MOV_TEX_LIGHT_TRIS(x: number, y: number, z: number, light: number, param1: number, param2: number): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_END L65-66
function moving_texture_macros_h.MOV_TEX_END(): number
	error("stale")
end

-- from include/moving_texture_macros.h:MOV_TEX_ROT_END L69-70
function moving_texture_macros_h.MOV_TEX_ROT_END(): number
	error("stale")
end

return moving_texture_macros_h
