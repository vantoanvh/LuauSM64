--!strict
--!optimize 2

--[[
	Port of include/level_misc_macros.h.
]]

const level_misc_macros_h = {}

-- from include/level_misc_macros.h:MACRO_OBJECT_WITH_BHV_PARAM L4-5
function level_misc_macros_h.MACRO_OBJECT_WITH_BHV_PARAM(preset: number, yaw: number, posX: number, posY: number, posZ: number, bhvParam: number): number
	error("stale")
end

-- from include/level_misc_macros.h:MACRO_OBJECT L7-8
function level_misc_macros_h.MACRO_OBJECT(preset: number, yaw: number, posX: number, posY: number, posZ: number): number
	error("stale")
end

-- from include/level_misc_macros.h:MACRO_OBJECT_END L10-11
function level_misc_macros_h.MACRO_OBJECT_END(): number
	error("stale")
end

-- from include/level_misc_macros.h:SPECIAL_OBJECT L13-14
function level_misc_macros_h.SPECIAL_OBJECT(preset: number, posX: number, posY: number, posZ: number): number
	error("stale")
end

-- from include/level_misc_macros.h:SPECIAL_OBJECT_WITH_YAW L16-17
function level_misc_macros_h.SPECIAL_OBJECT_WITH_YAW(preset: number, posX: number, posY: number, posZ: number, yaw: number): number
	error("stale")
end

-- from include/level_misc_macros.h:SPECIAL_OBJECT_WITH_YAW_AND_PARAM L19-20
function level_misc_macros_h.SPECIAL_OBJECT_WITH_YAW_AND_PARAM(preset: number, posX: number, posY: number, posZ: number, yaw: number, param: number): number
	error("stale")
end

-- from include/level_misc_macros.h:TRAJECTORY_POS L22-23
function level_misc_macros_h.TRAJECTORY_POS(trajId: number, x: number, y: number, z: number): number
	error("stale")
end

-- from include/level_misc_macros.h:TRAJECTORY_END L25-26
function level_misc_macros_h.TRAJECTORY_END(): number
	error("stale")
end

return level_misc_macros_h
