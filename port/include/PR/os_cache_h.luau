--!strict
--!optimize 2

--[[
	Port of include/PR/os_cache.h.
]]

const os_cache_h = {}

-- from include/PR/os_cache.h:OS_DCACHE_ROUNDUP_ADDR L65-65
function os_cache_h.OS_DCACHE_ROUNDUP_ADDR(x: number): number
	error("stale")
end

-- from include/PR/os_cache.h:OS_DCACHE_ROUNDUP_SIZE L66-66
function os_cache_h.OS_DCACHE_ROUNDUP_SIZE(x: number): number
	error("stale")
end

return os_cache_h
