--!strict
--!optimize 2

--[[
	Port of include/platform_info.h.
]]

-- from include/platform_info.h:data
const platform_info_h = {
	IS_64_BIT = 0,
	IS_BIG_ENDIAN = 1,
}

-- from include/platform_info.h:DOUBLE_SIZE_ON_64_BIT L13-13
function platform_info_h.DOUBLE_SIZE_ON_64_BIT(size: number): number
	-- sizeof(void *) / 4 is 2 in the 64-bit native build (sizeof-values)
	return size * 2
end

return platform_info_h
