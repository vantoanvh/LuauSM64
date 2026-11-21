--!strict
--!optimize 2

--[[
	Port of include/PR/os_exception.h.
]]

-- from include/PR/os_exception.h:data
const os_exception_h = {
	OS_FLAG_CPU_BREAK = 1,
	OS_FLAG_FAULT = 2,
	OS_IM_NONE = 0x00000001,
	OS_IM_SW1 = 0x00000501,
	OS_IM_SW2 = 0x00000601,
	OS_IM_CART = 0x00000c01,
	OS_IM_PRENMI = 0x00001401,
	OS_IM_RDBWRITE = 0x00002401,
	OS_IM_RDBREAD = 0x00004401,
	OS_IM_COUNTER = 0x00008401,
	OS_IM_CPU = 0x0000ff01,
	OS_IM_SP = 0x00010401,
	OS_IM_SI = 0x00020401,
	OS_IM_AI = 0x00040401,
	OS_IM_VI = 0x00080401,
	OS_IM_PI = 0x00100401,
	OS_IM_DP = 0x00200401,
	OS_IM_ALL = 0x003fff01,
	RCP_IMASK = 0x003f0000,
	RCP_IMASKSHIFT = 16,
}

return os_exception_h
