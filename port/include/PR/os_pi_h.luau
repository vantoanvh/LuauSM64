--!strict
--!optimize 2

--[[
	Port of include/PR/os_pi.h.
]]

const OsMessageH = require("./os_message_h")

-- from include/PR/os_pi.h:__OSBlockInfo
export type __OSBlockInfo = {
	errStatus: number,
	dramAddr: unknown,
	C2Addr: unknown,
	sectorSize: number,
	C1ErrNum: number,
	C1ErrSector: { number }, -- [4]
}

-- from include/PR/os_pi.h:__OSTranxInfo
export type __OSTranxInfo = {
	cmdType: number,
	transferMode: number,
	blockNum: number,
	sectorNum: number,
	devAddr: number,
	bmCtlShadow: number,
	seqCtlShadow: number,
	block: { __OSBlockInfo }, -- [2]
}

-- from include/PR/os_pi.h:OSPiHandle_s
export type OSPiHandle_s = {
	next: OSPiHandle_s?,
	type_: number,
	latency: number,
	pageSize: number,
	relDuration: number,
	pulse: number,
	domain: number,
	baseAddress: number,
	speed: number,
	transferInfo: __OSTranxInfo,
}

-- from include/PR/os_pi.h:OSPiInfo
export type OSPiInfo = {
	type_: number,
	address: number,
}

-- from include/PR/os_pi.h:OSIoMesgHdr
export type OSIoMesgHdr = {
	type_: number,
	pri: number,
	status: number,
	retQueue: OsMessageH.OSMesgQueue_s?,
}

-- from include/PR/os_pi.h:OSIoMesg
export type OSIoMesg = {
	hdr: OSIoMesgHdr, -- first member: this table itself
	type_: number,
	pri: number,
	status: number,
	retQueue: OsMessageH.OSMesgQueue_s?,
	dramAddr: unknown,
	devAddr: number,
	size: number,
}

-- from include/PR/os_pi.h:data
const os_pi_h = {
	OS_READ = 0,
	OS_WRITE = 1,
	OS_MESG_PRI_NORMAL = 0,
	OS_MESG_PRI_HIGH = 1,
}

-- from include/PR/os_pi.h:__OSBlockInfo (zero-filled constructor)
function os_pi_h.new___OSBlockInfo(): __OSBlockInfo
	return {
		errStatus = 0,
		dramAddr = nil,
		C2Addr = nil,
		sectorSize = 0,
		C1ErrNum = 0,
		C1ErrSector = table.create(4, 0),
	} :: __OSBlockInfo
end

-- from include/PR/os_pi.h:__OSTranxInfo (zero-filled constructor)
function os_pi_h.new___OSTranxInfo(): __OSTranxInfo
	return {
		cmdType = 0,
		transferMode = 0,
		blockNum = 0,
		sectorNum = 0,
		devAddr = 0,
		bmCtlShadow = 0,
		seqCtlShadow = 0,
		block = {
			{
				errStatus = 0,
				dramAddr = nil,
				C2Addr = nil,
				sectorSize = 0,
				C1ErrNum = 0,
				C1ErrSector = table.create(4, 0),
			},
			{
				errStatus = 0,
				dramAddr = nil,
				C2Addr = nil,
				sectorSize = 0,
				C1ErrNum = 0,
				C1ErrSector = table.create(4, 0),
			},
		},
	} :: __OSTranxInfo
end

-- from include/PR/os_pi.h:OSPiHandle_s (zero-filled constructor)
function os_pi_h.new_OSPiHandle_s(): OSPiHandle_s
	return {
		next = nil,
		type_ = 0,
		latency = 0,
		pageSize = 0,
		relDuration = 0,
		pulse = 0,
		domain = 0,
		baseAddress = 0,
		speed = 0,
		transferInfo = {
			cmdType = 0,
			transferMode = 0,
			blockNum = 0,
			sectorNum = 0,
			devAddr = 0,
			bmCtlShadow = 0,
			seqCtlShadow = 0,
			block = {
				{
					errStatus = 0,
					dramAddr = nil,
					C2Addr = nil,
					sectorSize = 0,
					C1ErrNum = 0,
					C1ErrSector = table.create(4, 0),
				},
				{
					errStatus = 0,
					dramAddr = nil,
					C2Addr = nil,
					sectorSize = 0,
					C1ErrNum = 0,
					C1ErrSector = table.create(4, 0),
				},
			},
		},
	} :: OSPiHandle_s
end

-- from include/PR/os_pi.h:OSPiInfo (zero-filled constructor)
function os_pi_h.new_OSPiInfo(): OSPiInfo
	return { type_ = 0, address = 0 } :: OSPiInfo
end

-- from include/PR/os_pi.h:OSIoMesgHdr (zero-filled constructor)
function os_pi_h.new_OSIoMesgHdr(): OSIoMesgHdr
	return { type_ = 0, pri = 0, status = 0, retQueue = nil } :: OSIoMesgHdr
end

-- from include/PR/os_pi.h:OSIoMesg (zero-filled constructor)
function os_pi_h.new_OSIoMesg(): OSIoMesg
	const Result = {
		type_ = 0,
		pri = 0,
		status = 0,
		retQueue = nil,
		dramAddr = nil,
		devAddr = 0,
		size = 0,
		hdr = nil :: unknown,
	} :: OSIoMesg

	Result.hdr = Result

	return Result
end

return os_pi_h
