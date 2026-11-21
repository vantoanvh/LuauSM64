--!strict
--!optimize 2

--[[
	Port of include/PR/os_tlb.h.
]]

-- from include/PR/os_tlb.h:data
const os_tlb_h = {
	OS_PM_4K = 0x0000000,
	OS_PM_16K = 0x0006000,
	OS_PM_64K = 0x001e000,
	OS_PM_256K = 0x007e000,
	OS_PM_1M = 0x01fe000,
	OS_PM_4M = 0x07fe000,
	OS_PM_16M = 0x1ffe000,
}

return os_tlb_h
