--!strict
--!optimize 2

--[[
	Port of include/PR/os_cont.h.
]]

-- from include/PR/os_cont.h:OSContStatus
export type OSContStatus = {
	type_: number,
	status: number,
	errnum: number,
}

-- from include/PR/os_cont.h:OSContPad
export type OSContPad = {
	button: number,
	stick_x: number,
	stick_y: number,
	errnum: number,
}

-- from include/PR/os_cont.h:OSContRamIo
export type OSContRamIo = {
	address: unknown,
	databuffer: buffer, -- [32]
	addressCrc: number,
	dataCrc: number,
	errnum: number,
}

-- from include/PR/os_cont.h:data
const os_cont_h = {
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
	CONT_TYPE_VOICE = 0x0100,
	CONT_CARD_ON = 0x01,
	CONT_CARD_PULL = 0x02,
	CONT_ADDR_CRC_ER = 0x04,
	CONT_EEPROM_BUSY = 0x80,
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
	CONT_ERR_NO_CONTROLLER = 1, -- PFS_ERR_NOPACK
	CONT_ERR_INVALID = 5, -- PFS_ERR_INVALID
	CONT_ERR_DEVICE = 11, -- PFS_ERR_DEVICE
	CONT_ERR_NOT_READY = 12,
	CONT_ERR_VOICE_MEMORY = 13,
	CONT_ERR_VOICE_WORD = 14,
	CONT_ERR_VOICE_NO_RESPONSE = 15,
}

-- from include/PR/os_cont.h:OSContStatus (zero-filled constructor)
function os_cont_h.new_OSContStatus(): OSContStatus
	return { type_ = 0, status = 0, errnum = 0 } :: OSContStatus
end

-- from include/PR/os_cont.h:OSContPad (zero-filled constructor)
function os_cont_h.new_OSContPad(): OSContPad
	return { button = 0, stick_x = 0, stick_y = 0, errnum = 0 } :: OSContPad
end

-- from include/PR/os_cont.h:OSContRamIo (zero-filled constructor)
function os_cont_h.new_OSContRamIo(): OSContRamIo
	return { address = nil, databuffer = buffer.create(32), addressCrc = 0, dataCrc = 0, errnum = 0 } :: OSContRamIo
end

os_cont_h.A_BUTTON = os_cont_h.CONT_A

os_cont_h.B_BUTTON = os_cont_h.CONT_B

os_cont_h.L_TRIG = os_cont_h.CONT_L

os_cont_h.R_TRIG = os_cont_h.CONT_R

os_cont_h.Z_TRIG = os_cont_h.CONT_G

os_cont_h.START_BUTTON = os_cont_h.CONT_START

os_cont_h.U_JPAD = os_cont_h.CONT_UP

os_cont_h.L_JPAD = os_cont_h.CONT_LEFT

os_cont_h.R_JPAD = os_cont_h.CONT_RIGHT

os_cont_h.D_JPAD = os_cont_h.CONT_DOWN

os_cont_h.U_CBUTTONS = os_cont_h.CONT_E

os_cont_h.L_CBUTTONS = os_cont_h.CONT_C

os_cont_h.R_CBUTTONS = os_cont_h.CONT_F

os_cont_h.D_CBUTTONS = os_cont_h.CONT_D

os_cont_h.CONT_ERR_CONTRFAIL = os_cont_h.CONT_OVERRUN_ERROR

return os_cont_h
