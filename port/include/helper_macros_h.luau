--!strict
--!optimize 2

--[[
	Port of include/helper_macros.h.
]]

const helper_macros_h = {}

-- from include/helper_macros.h:LIST_NEXT_ITEM L4-4
function helper_macros_h.LIST_NEXT_ITEM(curItem: number, type_: number): number
	error("stale")
end

return helper_macros_h
