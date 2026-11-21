--!strict
--!optimize 2

--[[
	Port of src/engine/geo_layout.h.
]]

const Registry = require("../../groups/registry")

const Rom = require("../rom/rom")

-- from src/engine/geo_layout.h:data
const geo_layout_h = {
	GEO_CMD_FLAGS_RESET = 0,
	GEO_CMD_FLAGS_SET = 1,
	GEO_CMD_FLAGS_CLEAR = 2,
	-- Geo scripts are ROM resident in the 32-bit word layout (D5): sizeof(void *) is 4
	CMD_SIZE_SHIFT = 0,
}

-- from src/engine/geo_layout.h:CMD_PROCESS_OFFSET L15-15
function geo_layout_h.CMD_PROCESS_OFFSET(offset: number): number
	return bit32.bor(bit32.band(offset, 3), bit32.lshift(bit32.band(offset, bit32.bnot(3)), geo_layout_h.CMD_SIZE_SHIFT))
end

-- from src/engine/geo_layout.h:cur_geo_cmd_u8 L17-18
function geo_layout_h.cur_geo_cmd_u8(offset: number): number
	return Rom.ReadU8(Registry.Members.src__engine__geo_layout.gGeoLayoutCommand + geo_layout_h.CMD_PROCESS_OFFSET(offset))
end

-- from src/engine/geo_layout.h:cur_geo_cmd_s16 L20-21
function geo_layout_h.cur_geo_cmd_s16(offset: number): number
	return Rom.ReadS16(Registry.Members.src__engine__geo_layout.gGeoLayoutCommand + geo_layout_h.CMD_PROCESS_OFFSET(offset))
end

-- from src/engine/geo_layout.h:cur_geo_cmd_s32 L23-24
function geo_layout_h.cur_geo_cmd_s32(offset: number): number
	return Rom.ReadS32(Registry.Members.src__engine__geo_layout.gGeoLayoutCommand + geo_layout_h.CMD_PROCESS_OFFSET(offset))
end

-- from src/engine/geo_layout.h:cur_geo_cmd_u32 L26-27
function geo_layout_h.cur_geo_cmd_u32(offset: number): number
	return Rom.ReadU32(Registry.Members.src__engine__geo_layout.gGeoLayoutCommand + geo_layout_h.CMD_PROCESS_OFFSET(offset))
end

-- from src/engine/geo_layout.h:cur_geo_cmd_ptr L29-30
function geo_layout_h.cur_geo_cmd_ptr(offset: number): number
	return Rom.ReadU32(Registry.Members.src__engine__geo_layout.gGeoLayoutCommand + geo_layout_h.CMD_PROCESS_OFFSET(offset))
end

return geo_layout_h
