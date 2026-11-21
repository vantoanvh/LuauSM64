--!strict
--!optimize 2

--[[
	Port of include/PR/os.h.
]]

const Registry = require("../../groups/registry")

const OsMessageH = require("./os_message_h")
const OsPiH = require("./os_pi_h")
const OsThreadH = require("./os_thread_h")

-- from include/PR/os.h:OSDevMgr
export type OSDevMgr = {
	active: number,
	thread: OsThreadH.OSThread_s?,
	cmdQueue: OsMessageH.OSMesgQueue_s?,
	evtQueue: OsMessageH.OSMesgQueue_s?,
	acsQueue: OsMessageH.OSMesgQueue_s?,
	dma: ((number, number, number) -> number)?,
	edma: ((OsPiH.OSPiHandle_s, number, number, number) -> number)?,
}

-- from include/PR/os.h:OSProf
export type OSProf = {
	histo_base: { number }?,
	histo_size: number,
	text_start: { number }?,
	text_end: { number }?,
}

-- from include/PR/os.h:data
const os_h = {
	OS_STATE_STOPPED = 1,
	OS_STATE_RUNNABLE = 2,
	OS_STATE_RUNNING = 4,
	OS_STATE_WAITING = 8,
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
	OS_PRIORITY_MAX = 255,
	OS_PRIORITY_VIMGR = 254,
	OS_PRIORITY_RMON = 250,
	OS_PRIORITY_RMONSPIN = 200,
	OS_PRIORITY_PIMGR = 150,
	OS_PRIORITY_SIMGR = 140,
	OS_PRIORITY_APPMAX = 127,
	OS_PRIORITY_IDLE = 0,
	OS_READ = 0,
	OS_WRITE = 1,
	OS_OTHERS = 2,
	OS_MESG_TYPE_BASE = 10,
	OS_MESG_TYPE_LOOPBACK = 10, -- (OS_MESG_TYPE_BASE+0)
	OS_MESG_TYPE_DMAREAD = 11, -- (OS_MESG_TYPE_BASE+1)
	OS_MESG_TYPE_DMAWRITE = 12, -- (OS_MESG_TYPE_BASE+2)
	OS_MESG_TYPE_VRETRACE = 13, -- (OS_MESG_TYPE_BASE+3)
	OS_MESG_TYPE_COUNTER = 14, -- (OS_MESG_TYPE_BASE+4)
	OS_MESG_TYPE_EDMAREAD = 15, -- (OS_MESG_TYPE_BASE+5)
	OS_MESG_TYPE_EDMAWRITE = 16, -- (OS_MESG_TYPE_BASE+6)
	OS_MESG_PRI_NORMAL = 0,
	OS_MESG_PRI_HIGH = 1,
	OS_PM_4K = 0x0000000,
	OS_PM_16K = 0x0006000,
	OS_PM_64K = 0x001e000,
	OS_PM_256K = 0x007e000,
	OS_PM_1M = 0x01fe000,
	OS_PM_4M = 0x07fe000,
	OS_PM_16M = 0x1ffe000,
	OS_PIM_STACKSIZE = 4096,
	OS_VIM_STACKSIZE = 4096,
	OS_SIM_STACKSIZE = 4096,
	OS_MIN_STACKSIZE = 72,
	OS_TV_PAL = 0,
	OS_TV_NTSC = 1,
	OS_TV_MPAL = 2,
	OS_VI_NTSC_LPN1 = 0,
	OS_VI_NTSC_LPF1 = 1,
	OS_VI_NTSC_LAN1 = 2,
	OS_VI_NTSC_LAF1 = 3,
	OS_VI_NTSC_LPN2 = 4,
	OS_VI_NTSC_LPF2 = 5,
	OS_VI_NTSC_LAN2 = 6,
	OS_VI_NTSC_LAF2 = 7,
	OS_VI_NTSC_HPN1 = 8,
	OS_VI_NTSC_HPF1 = 9,
	OS_VI_NTSC_HAN1 = 10,
	OS_VI_NTSC_HAF1 = 11,
	OS_VI_NTSC_HPN2 = 12,
	OS_VI_NTSC_HPF2 = 13,
	OS_VI_PAL_LPN1 = 14,
	OS_VI_PAL_LPF1 = 15,
	OS_VI_PAL_LAN1 = 16,
	OS_VI_PAL_LAF1 = 17,
	OS_VI_PAL_LPN2 = 18,
	OS_VI_PAL_LPF2 = 19,
	OS_VI_PAL_LAN2 = 20,
	OS_VI_PAL_LAF2 = 21,
	OS_VI_PAL_HPN1 = 22,
	OS_VI_PAL_HPF1 = 23,
	OS_VI_PAL_HAN1 = 24,
	OS_VI_PAL_HAF1 = 25,
	OS_VI_PAL_HPN2 = 26,
	OS_VI_PAL_HPF2 = 27,
	OS_VI_MPAL_LPN1 = 28,
	OS_VI_MPAL_LPF1 = 29,
	OS_VI_MPAL_LAN1 = 30,
	OS_VI_MPAL_LAF1 = 31,
	OS_VI_MPAL_LPN2 = 32,
	OS_VI_MPAL_LPF2 = 33,
	OS_VI_MPAL_LAN2 = 34,
	OS_VI_MPAL_LAF2 = 35,
	OS_VI_MPAL_HPN1 = 36,
	OS_VI_MPAL_HPF1 = 37,
	OS_VI_MPAL_HAN1 = 38,
	OS_VI_MPAL_HAF1 = 39,
	OS_VI_MPAL_HPN2 = 40,
	OS_VI_MPAL_HPF2 = 41,
	OS_VI_GAMMA_ON = 0x0001,
	OS_VI_GAMMA_OFF = 0x0002,
	OS_VI_GAMMA_DITHER_ON = 0x0004,
	OS_VI_GAMMA_DITHER_OFF = 0x0008,
	OS_VI_DIVOT_ON = 0x0010,
	OS_VI_DIVOT_OFF = 0x0020,
	OS_VI_DITHER_FILTER_ON = 0x0040,
	OS_VI_DITHER_FILTER_OFF = 0x0080,
	OS_VI_BIT_NONINTERLACE = 0x0001,
	OS_VI_BIT_INTERLACE = 0x0002,
	OS_VI_BIT_NORMALINTERLACE = 0x0004,
	OS_VI_BIT_DEFLICKINTERLACE = 0x0008,
	OS_VI_BIT_ANTIALIAS = 0x0010,
	OS_VI_BIT_POINTSAMPLE = 0x0020,
	OS_VI_BIT_16PIXEL = 0x0040,
	OS_VI_BIT_32PIXEL = 0x0080,
	OS_VI_BIT_LORES = 0x0100,
	OS_VI_BIT_HIRES = 0x0200,
	OS_VI_BIT_NTSC = 0x0400,
	OS_VI_BIT_PAL = 0x0800,
	LEO_BLOCK_MODE = 1,
	LEO_TRACK_MODE = 2,
	LEO_SECTOR_MODE = 3,
	MAXCONTROLLERS = 4,
	CONT_NO_RESPONSE_ERROR = 0x8,
	CONT_OVERRUN_ERROR = 0x4,
	CONT_ABSOLUTE = 0x0001,
	CONT_RELATIVE = 0x0002,
	CONT_JOYPORT = 0x0004,
	CONT_EEPROM = 0x8000,
	CONT_EEP16K = 0x4000,
	CONT_TYPE_MASK = 0x1f07,
	CONT_TYPE_NORMAL = 0x0005,
	CONT_TYPE_MOUSE = 0x0002,
	CONT_CARD_ON = 0x01,
	CONT_CARD_PULL = 0x02,
	CONT_ADDR_CRC_ER = 0x04,
	CONT_EEPROM_BUSY = 0x80,
	EEPROM_TYPE_4K = 0x01,
	EEPROM_TYPE_16K = 0x02,
	CONT_A = 0x8000,
	CONT_B = 0x4000,
	CONT_G = 0x2000,
	CONT_START = 0x1000,
	CONT_UP = 0x0800,
	CONT_DOWN = 0x0400,
	CONT_LEFT = 0x0200,
	CONT_RIGHT = 0x0100,
	CONT_L = 0x0020,
	CONT_R = 0x0010,
	CONT_E = 0x0008,
	CONT_D = 0x0004,
	CONT_C = 0x0002,
	CONT_F = 0x0001,
	EEPROM_MAXBLOCKS = 64,
	EEP16K_MAXBLOCKS = 256,
	EEPROM_BLOCK_SIZE = 8,
	PI_DOMAIN1 = 0,
	PI_DOMAIN2 = 1,
	PROF_MIN_INTERVAL = 50,
	BOOT_ADDRESS_ULTRA = 0x80000400,
	BOOT_ADDRESS_COSIM = 0x80002000,
	BOOT_ADDRESS_EMU = 0x20010000,
	BOOT_ADDRESS_INDY = 0x88100000,
	OS_APP_NMI_BUFSIZE = 64,
	OS_CLOCK_RATE = 62500000,
	OS_CPU_COUNTER = 46875000, -- (OS_CLOCK_RATE*3/4)
}

Registry.Register("include__PR__os_h", os_h)

-- from include/PR/os.h:OSDevMgr (zero-filled constructor)
function os_h.new_OSDevMgr(): OSDevMgr
	return { active = 0, thread = nil, cmdQueue = nil, evtQueue = nil, acsQueue = nil, dma = nil, edma = nil } :: OSDevMgr
end

-- from include/PR/os.h:OSProf (zero-filled constructor)
function os_h.new_OSProf(): OSProf
	return { histo_base = nil, histo_size = 0, text_start = nil, text_end = nil } :: OSProf
end

-- from include/PR/os.h:MQ_GET_COUNT L384-384
function os_h.MQ_GET_COUNT(mq: unknown): number
	error("stale")
end

-- from include/PR/os.h:MQ_IS_EMPTY L387-387
function os_h.MQ_IS_EMPTY(mq: number): number
	error("stale")
end

-- from include/PR/os.h:MQ_IS_FULL L388-388
function os_h.MQ_IS_FULL(mq: unknown): number
	error("stale")
end

-- from include/PR/os.h:OS_NSEC_TO_CYCLES L401-401
function os_h.OS_NSEC_TO_CYCLES(n: number): number
	error("stale")
end

-- from include/PR/os.h:OS_USEC_TO_CYCLES L402-402
function os_h.OS_USEC_TO_CYCLES(n: number): number
	error("stale")
end

-- from include/PR/os.h:OS_CYCLES_TO_NSEC L403-403
function os_h.OS_CYCLES_TO_NSEC(c: number): number
	error("stale")
end

-- from include/PR/os.h:OS_CYCLES_TO_USEC L404-404
function os_h.OS_CYCLES_TO_USEC(c: number): number
	error("stale")
end

-- from include/PR/os.h:OS_DCACHE_ROUNDUP_ADDR L518-518
function os_h.OS_DCACHE_ROUNDUP_ADDR(x: number): number
	error("stale")
end

-- from include/PR/os.h:OS_DCACHE_ROUNDUP_SIZE L519-519
function os_h.OS_DCACHE_ROUNDUP_SIZE(x: number): number
	error("stale")
end

-- from include/PR/os.h:OS_K0_TO_PHYSICAL L534-534
function os_h.OS_K0_TO_PHYSICAL(x: number): number
	error("stale")
end

-- from include/PR/os.h:OS_K1_TO_PHYSICAL L535-535
function os_h.OS_K1_TO_PHYSICAL(x: number): number
	error("stale")
end

-- from include/PR/os.h:OS_PHYSICAL_TO_K0 L537-537
function os_h.OS_PHYSICAL_TO_K0(x: number): number
	error("stale")
end

-- from include/PR/os.h:OS_PHYSICAL_TO_K1 L538-538
function os_h.OS_PHYSICAL_TO_K1(x: number): number
	error("stale")
end

os_h.A_BUTTON = os_h.CONT_A

os_h.B_BUTTON = os_h.CONT_B

os_h.L_TRIG = os_h.CONT_L

os_h.R_TRIG = os_h.CONT_R

os_h.Z_TRIG = os_h.CONT_G

os_h.START_BUTTON = os_h.CONT_START

os_h.U_JPAD = os_h.CONT_UP

os_h.L_JPAD = os_h.CONT_LEFT

os_h.R_JPAD = os_h.CONT_RIGHT

os_h.D_JPAD = os_h.CONT_DOWN

os_h.U_CBUTTONS = os_h.CONT_E

os_h.L_CBUTTONS = os_h.CONT_C

os_h.R_CBUTTONS = os_h.CONT_F

os_h.D_CBUTTONS = os_h.CONT_D

return os_h
