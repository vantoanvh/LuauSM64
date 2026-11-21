--!strict
--!optimize 2

--[[
	Port of include/PR/os_vi.h.
]]

const OsMessageH = require("./os_message_h")

-- from include/PR/os_vi.h:OSViCommonRegs
export type OSViCommonRegs = {
	ctrl: number,
	width: number,
	burst: number,
	vSync: number,
	hSync: number,
	leap: number,
	hStart: number,
	xScale: number,
	vCurrent: number,
}

-- from include/PR/os_vi.h:OSViFieldRegs
export type OSViFieldRegs = {
	origin: number,
	yScale: number,
	vStart: number,
	vBurst: number,
	vIntr: number,
}

-- from include/PR/os_vi.h:OSViMode
export type OSViMode = {
	type_: number,
	comRegs: OSViCommonRegs,
	fldRegs: { OSViFieldRegs }, -- [2]
}

-- from include/PR/os_vi.h:OSViContext
export type OSViContext = {
	unk00: number,
	retraceCount: number,
	buffer: unknown,
	modep: OSViMode?,
	features: number,
	mq: OsMessageH.OSMesgQueue_s?,
	msg: unknown,
	unk18: number,
	unk1c: number,
	unk20: number,
	unk24: number,
	unk28: number,
	unk2c: number,
}

-- from include/PR/os_vi.h:data
const os_vi_h = {
	VI_STATE_01 = 0x01,
	VI_STATE_XSCALE_UPDATED = 0x02,
	VI_STATE_YSCALE_UPDATED = 0x04,
	VI_STATE_08 = 0x08,
	VI_STATE_10 = 0x10,
	VI_STATE_BLACK = 0x20,
	VI_STATE_REPEATLINE = 0x40,
	VI_STATE_FADE = 0x80,
	OS_VI_GAMMA_ON = 0x0001,
	OS_VI_GAMMA_OFF = 0x0002,
	OS_VI_GAMMA_DITHER_ON = 0x0004,
	OS_VI_GAMMA_DITHER_OFF = 0x0008,
	OS_VI_DIVOT_ON = 0x0010,
	OS_VI_DIVOT_OFF = 0x0020,
	OS_VI_DITHER_FILTER_ON = 0x0040,
	OS_VI_DITHER_FILTER_OFF = 0x0080,
	OS_VI_GAMMA = 0x08,
	OS_VI_GAMMA_DITHER = 0x04,
	OS_VI_DIVOT = 0x10,
	OS_VI_DITHER_FILTER = 0x10000,
	OS_VI_UNK200 = 0x200,
	OS_VI_UNK100 = 0x100,
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
}

-- from include/PR/os_vi.h:OSViCommonRegs (zero-filled constructor)
function os_vi_h.new_OSViCommonRegs(): OSViCommonRegs
	return {
		ctrl = 0,
		width = 0,
		burst = 0,
		vSync = 0,
		hSync = 0,
		leap = 0,
		hStart = 0,
		xScale = 0,
		vCurrent = 0,
	} :: OSViCommonRegs
end

-- from include/PR/os_vi.h:OSViFieldRegs (zero-filled constructor)
function os_vi_h.new_OSViFieldRegs(): OSViFieldRegs
	return { origin = 0, yScale = 0, vStart = 0, vBurst = 0, vIntr = 0 } :: OSViFieldRegs
end

-- from include/PR/os_vi.h:OSViMode (zero-filled constructor)
function os_vi_h.new_OSViMode(): OSViMode
	return {
		type_ = 0,
		comRegs = {
			ctrl = 0,
			width = 0,
			burst = 0,
			vSync = 0,
			hSync = 0,
			leap = 0,
			hStart = 0,
			xScale = 0,
			vCurrent = 0,
		},
		fldRegs = {
			{ origin = 0, yScale = 0, vStart = 0, vBurst = 0, vIntr = 0 },
			{ origin = 0, yScale = 0, vStart = 0, vBurst = 0, vIntr = 0 },
		},
	} :: OSViMode
end

-- from include/PR/os_vi.h:OSViContext (zero-filled constructor)
function os_vi_h.new_OSViContext(): OSViContext
	return {
		unk00 = 0,
		retraceCount = 0,
		buffer = nil,
		modep = nil,
		features = 0,
		mq = nil,
		msg = nil,
		unk18 = 0,
		unk1c = 0,
		unk20 = 0,
		unk24 = 0,
		unk28 = 0,
		unk2c = 0,
	} :: OSViContext
end

return os_vi_h
