--!strict
--!optimize 2

--[[
	Port of include/macros.h.
]]

const macros_h = {}

-- from include/macros.h:GLOBAL_ASM L7-7
function macros_h.GLOBAL_ASM()
	error("stale")
end

-- from include/macros.h:ARRAY_COUNT L16-16
function macros_h.ARRAY_COUNT(arr: unknown): number
	return #(arr :: { unknown })
end

-- from include/macros.h:GLUE L18-18
function macros_h.GLUE(a: unknown, b: unknown): number
	error("stale")
end

-- from include/macros.h:GLUE2 L19-19
function macros_h.GLUE2(a: number, b: number): number
	error("stale")
end

-- from include/macros.h:STATIC_ASSERT L45-45
function macros_h.STATIC_ASSERT(cond: number, msg: number): number
	error("stale")
end

-- from include/macros.h:VIRTUAL_TO_PHYSICAL L64-64
function macros_h.VIRTUAL_TO_PHYSICAL(addr: number): number
	return bit32.band(addr, 0x1FFFFFFF)
end

-- from include/macros.h:PHYSICAL_TO_VIRTUAL L67-67
function macros_h.PHYSICAL_TO_VIRTUAL(addr: number): number
	return bit32.bor(addr, 0x80000000)
end

-- from include/macros.h:VIRTUAL_TO_PHYSICAL2 L70-70
function macros_h.VIRTUAL_TO_PHYSICAL2(addr: number): number
	return addr - 0x80000000
end

-- from include/macros.h:CN_DEBUG_PRINTF L82-82
function macros_h.CN_DEBUG_PRINTF(args: string)
	-- Expands to nothing in the US build
	return
end

return macros_h
