--!strict
--!optimize 2

--[[
	Port of include/PR/os_message.h.
]]

const Registry = require("../../groups/registry")

const OsThreadH = require("./os_thread_h")

-- from include/PR/os_message.h:OSMesgQueue_s
export type OSMesgQueue_s = {
	mtqueue: OsThreadH.OSThread_s?,
	fullqueue: OsThreadH.OSThread_s?,
	validCount: number,
	first: number,
	msgCount: number,
	msg: unknown,
}

-- from include/PR/os_message.h:data
const os_message_h = {
	OS_NUM_EVENTS = 15,
	OS_EVENT_SW1 = 0,
	OS_EVENT_SW2 = 1,
	OS_EVENT_CART = 2,
	OS_EVENT_COUNTER = 3,
	OS_EVENT_SP = 4,
	OS_EVENT_SI = 5,
	OS_EVENT_AI = 6,
	OS_EVENT_VI = 7,
	OS_EVENT_PI = 8,
	OS_EVENT_DP = 9,
	OS_EVENT_CPU_BREAK = 10,
	OS_EVENT_SP_BREAK = 11,
	OS_EVENT_FAULT = 12,
	OS_EVENT_THREADSTATUS = 13,
	OS_EVENT_PRENMI = 14,
	OS_MESG_NOBLOCK = 0,
	OS_MESG_BLOCK = 1,
}

Registry.Register("include__PR__os_message_h", os_message_h)

-- from include/PR/os_message.h:OSMesgQueue_s (zero-filled constructor)
function os_message_h.new_OSMesgQueue_s(): OSMesgQueue_s
	return { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: OSMesgQueue_s
end

-- from include/PR/os_message.h:MQ_GET_COUNT L139-139
function os_message_h.MQ_GET_COUNT(mq: unknown): number
	error("stale")
end

-- from include/PR/os_message.h:MQ_IS_EMPTY L142-142
function os_message_h.MQ_IS_EMPTY(mq: number): number
	error("stale")
end

-- from include/PR/os_message.h:MQ_IS_FULL L143-143
function os_message_h.MQ_IS_FULL(mq: unknown): number
	error("stale")
end

return os_message_h
