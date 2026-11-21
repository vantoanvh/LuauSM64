--!strict
--!optimize 2

--[[
	Port of include/PR/os_pfs.h.
]]

const OsH = require("./os_h")
const OsMessageH = require("./os_message_h")

-- from include/PR/os_pfs.h:OSPfs
export type OSPfs = {
	status: number,
	queue: OsMessageH.OSMesgQueue_s?,
	channel: number,
	id: buffer, -- [32]
	label: buffer, -- [32]
	version: number,
	dir_size: number,
	inode_table: number,
	minode_table: number,
	dir_table: number,
	inode_start_page: number,
	banks: number,
	activebank: number,
}

-- from include/PR/os_pfs.h:OSPfsState
export type OSPfsState = {
	file_size: number,
	game_code: number,
	company_code: number,
	ext_name: buffer, -- [4]
	game_name: buffer, -- [16]
}

-- from include/PR/os_pfs.h:data
const os_pfs_h = {
	OS_PFS_VERSION = 0x0200,
	OS_PFS_VERSION_HI = 2, -- (OS_PFS_VERSION >> 8)
	OS_PFS_VERSION_LO = 0, -- (OS_PFS_VERSION & 255)
	PFS_FILE_NAME_LEN = 16,
	PFS_FILE_EXT_LEN = 4,
	BLOCKSIZE = 32,
	PFS_ONE_PAGE = 8,
	PFS_MAX_BANKS = 62,
	PFS_READ = 0,
	PFS_WRITE = 1,
	PFS_CREATE = 2,
	PFS_INITIALIZED = 0x1,
	PFS_CORRUPTED = 0x2,
	PFS_ERR_NOPACK = 1,
	PFS_ERR_NEW_PACK = 2,
	PFS_ERR_INCONSISTENT = 3,
	PFS_ERR_CONTRFAIL = OsH.CONT_OVERRUN_ERROR,
	PFS_ERR_INVALID = 5,
	PFS_ERR_BAD_DATA = 6,
	PFS_DATA_FULL = 7,
	PFS_DIR_FULL = 8,
	PFS_ERR_EXIST = 9,
	PFS_ERR_ID_FATAL = 10,
	PFS_ERR_DEVICE = 11,
}

-- from include/PR/os_pfs.h:OSPfs (zero-filled constructor)
function os_pfs_h.new_OSPfs(): OSPfs
	return {
		status = 0,
		queue = nil,
		channel = 0,
		id = buffer.create(32),
		label = buffer.create(32),
		version = 0,
		dir_size = 0,
		inode_table = 0,
		minode_table = 0,
		dir_table = 0,
		inode_start_page = 0,
		banks = 0,
		activebank = 0,
	} :: OSPfs
end

-- from include/PR/os_pfs.h:OSPfsState (zero-filled constructor)
function os_pfs_h.new_OSPfsState(): OSPfsState
	return {
		file_size = 0,
		game_code = 0,
		company_code = 0,
		ext_name = buffer.create(4),
		game_name = buffer.create(16),
	} :: OSPfsState
end

return os_pfs_h
