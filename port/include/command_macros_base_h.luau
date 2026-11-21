--!strict
--!optimize 2

--[[
	Port of include/command_macros_base.h.
]]

const command_macros_base_h = {}

-- from include/command_macros_base.h:CMD_BBBB L19-19
function command_macros_base_h.CMD_BBBB(a: number, b: number, c: number, d: number): number
	error("stale")
end

-- from include/command_macros_base.h:CMD_BBH L20-20
function command_macros_base_h.CMD_BBH(a: number, b: number, c: number): number
	error("stale")
end

-- from include/command_macros_base.h:CMD_HH L21-21
function command_macros_base_h.CMD_HH(a: number, b: number): number
	error("stale")
end

-- from include/command_macros_base.h:CMD_W L22-22
function command_macros_base_h.CMD_W(a: number): number
	error("stale")
end

-- from include/command_macros_base.h:CMD_PTR L24-24
function command_macros_base_h.CMD_PTR(a: number): number
	error("stale")
end

-- from include/command_macros_base.h:CMD_HHHHHH L26-26
function command_macros_base_h.CMD_HHHHHH(a: number, b: number, c: number, d: number, e: number, f: number): number
	error("stale")
end

return command_macros_base_h
