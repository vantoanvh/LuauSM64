--!strict
--!optimize 2

--[[
	Port of include/segments.h.
]]

const Registry = require("../groups/registry")

-- from include/segments.h:data
const segments_h = {
	SEG_START = 0x8005C000,
	SEG_FRAMEBUFFERS_SIZE = 460800, -- (2 * SCREEN_WIDTH * SCREEN_HEIGHT * 3)
	SEG_GODDARD_POOL_OFFSET = 0x52000,
	SEG_GODDARD = 2148986880, -- (SEG_POOL_END - SEG_GODDARD_POOL_OFFSET)
	RDRAM_END = 0x80400000,
	SEG_POOL_START = 2147860480, -- SEG_START
	SEG_POOL_SIZE = 0x165000,
	SEG_POOL_END = 2149322752, -- (SEG_POOL_START + SEG_POOL_SIZE)
	SEG_BUFFERS = 2149322752, -- SEG_POOL_END
	SEG_ENGINE = 0x80378800,
	SEG_FRAMEBUFFERS = 2151217152, -- (RDRAM_END - SEG_FRAMEBUFFERS_SIZE)
}

Registry.Register("include__segments_h", segments_h)

return segments_h
