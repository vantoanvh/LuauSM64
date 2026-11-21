--!strict
--!optimize 2

--[[
	Port of include/PR/os_time.h.
]]

const OsMessageH = require("./os_message_h")

-- from include/PR/os_time.h:OSTimer_str
export type OSTimer_str = {
	next: OSTimer_str?,
	prev: OSTimer_str?,
	interval: number,
	remaining: number,
	mq: OsMessageH.OSMesgQueue_s?,
	msg: unknown,
}

const os_time_h = {}

-- from include/PR/os_time.h:OSTimer_str (zero-filled constructor)
function os_time_h.new_OSTimer_str(): OSTimer_str
	return { next = nil, prev = nil, interval = 0, remaining = 0, mq = nil, msg = nil } :: OSTimer_str
end

return os_time_h
