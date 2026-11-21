--!strict
--!optimize 2

--[[
	Port of src/game/save_file.h.
]]

-- from src/game/save_file.h:SaveBlockSignature
export type SaveBlockSignature = {
	magic: number,
	chksum: number,
}

-- from src/game/save_file.h:SaveFile
export type SaveFile = {
	capLevel: number,
	capArea: number,
	capPos: { number },
	flags: number,
	courseStars: buffer, -- [25]
	courseCoinScores: buffer, -- [15]
	signature: SaveBlockSignature,
}

-- from src/game/save_file.h:MainMenuSaveData
export type MainMenuSaveData = {
	coinScoreAges: { number }, -- [4]
	soundMode: number,
	filler: buffer, -- [EEPROM_SIZE / 2 - SUBTRAHEND - NUM_SAVE_FILES * (4 + sizeof(struct SaveFile))]
	signature: SaveBlockSignature,
}

-- from src/game/save_file.h:SaveBuffer
export type SaveBuffer = {
	files: { { SaveFile } }, -- [4][2]
	menuData: { MainMenuSaveData }, -- [2]
}

-- from src/game/save_file.h:WarpCheckpoint
export type WarpCheckpoint = {
	actNum: number,
	courseNum: number,
	levelID: number,
	areaNum: number,
	warpNode: number,
}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/save_file.h:data
const save_file_h = {
	EEPROM_SIZE = 0x200,
	NUM_SAVE_FILES = 4,
	SAVE_FILE_A = 0,
	SAVE_FILE_B = 1,
	SAVE_FILE_C = 2,
	SAVE_FILE_D = 3,
	SAVE_FLAG_FILE_EXISTS = 1,
	SAVE_FLAG_HAVE_WING_CAP = 2,
	SAVE_FLAG_HAVE_METAL_CAP = 4,
	SAVE_FLAG_HAVE_VANISH_CAP = 8,
	SAVE_FLAG_HAVE_KEY_1 = 16,
	SAVE_FLAG_HAVE_KEY_2 = 32,
	SAVE_FLAG_UNLOCKED_BASEMENT_DOOR = 64,
	SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR = 128,
	SAVE_FLAG_DDD_MOVED_BACK = 256,
	SAVE_FLAG_MOAT_DRAINED = 512,
	SAVE_FLAG_UNLOCKED_PSS_DOOR = 1024,
	SAVE_FLAG_UNLOCKED_WF_DOOR = 2048,
	SAVE_FLAG_UNLOCKED_CCM_DOOR = 4096,
	SAVE_FLAG_UNLOCKED_JRB_DOOR = 8192,
	SAVE_FLAG_UNLOCKED_BITDW_DOOR = 16384,
	SAVE_FLAG_UNLOCKED_BITFS_DOOR = 32768,
	SAVE_FLAG_CAP_ON_GROUND = 65536,
	SAVE_FLAG_CAP_ON_KLEPTO = 131072,
	SAVE_FLAG_CAP_ON_UKIKI = 262144,
	SAVE_FLAG_CAP_ON_MR_BLIZZARD = 524288,
	SAVE_FLAG_UNLOCKED_50_STAR_DOOR = 1048576,
	SAVE_FLAG_COLLECTED_TOAD_STAR_1 = 16777216,
	SAVE_FLAG_COLLECTED_TOAD_STAR_2 = 33554432,
	SAVE_FLAG_COLLECTED_TOAD_STAR_3 = 67108864,
	SAVE_FLAG_COLLECTED_MIPS_STAR_1 = 134217728,
	SAVE_FLAG_COLLECTED_MIPS_STAR_2 = 268435456,
}

-- from src/game/save_file.h:SaveBlockSignature (zero-filled constructor)
function save_file_h.new_SaveBlockSignature(): SaveBlockSignature
	return { magic = 0, chksum = 0 } :: SaveBlockSignature
end

-- from src/game/save_file.h:SaveFile (zero-filled constructor)
function save_file_h.new_SaveFile(): SaveFile
	return {
		capLevel = 0,
		capArea = 0,
		capPos = table.create(3, 0),
		flags = 0,
		courseStars = buffer.create(25),
		courseCoinScores = buffer.create(15),
		signature = { magic = 0, chksum = 0 },
	} :: SaveFile
end

-- from src/game/save_file.h:MainMenuSaveData (zero-filled constructor)
function save_file_h.new_MainMenuSaveData(): MainMenuSaveData
	return {
		coinScoreAges = table.create(4, 0),
		soundMode = 0,
		filler = buffer.create(0) --[[ TODO: array size EEPROM_SIZE / 2 - SUBTRAHEND - NUM_SAVE_FILES * (4 + sizeof(struct SaveFile)) is not a number ]],
		signature = { magic = 0, chksum = 0 },
	} :: MainMenuSaveData
end

-- from src/game/save_file.h:SaveBuffer (zero-filled constructor)
function save_file_h.new_SaveBuffer(): SaveBuffer
	return {
		files = {
			{
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
			},
			{
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
			},
			{
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
			},
			{
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
				{
					capLevel = 0,
					capArea = 0,
					capPos = table.create(3, 0),
					flags = 0,
					courseStars = buffer.create(25),
					courseCoinScores = buffer.create(15),
					signature = { magic = 0, chksum = 0 },
				},
			},
		},
		menuData = {
			{
				coinScoreAges = table.create(4, 0),
				soundMode = 0,
				filler = buffer.create(0) --[[ TODO: array size EEPROM_SIZE / 2 - SUBTRAHEND - NUM_SAVE_FILES * (4 + sizeof(struct SaveFile)) is not a number ]],
				signature = { magic = 0, chksum = 0 },
			},
			{
				coinScoreAges = table.create(4, 0),
				soundMode = 0,
				filler = buffer.create(0) --[[ TODO: array size EEPROM_SIZE / 2 - SUBTRAHEND - NUM_SAVE_FILES * (4 + sizeof(struct SaveFile)) is not a number ]],
				signature = { magic = 0, chksum = 0 },
			},
		},
	} :: SaveBuffer
end

-- from src/game/save_file.h:WarpCheckpoint (zero-filled constructor)
function save_file_h.new_WarpCheckpoint(): WarpCheckpoint
	return { actNum = 0, courseNum = 0, levelID = 0, areaNum = 0, warpNode = 0 } :: WarpCheckpoint
end

-- from src/game/save_file.h:SAVE_FLAG_TO_STAR_FLAG L109-109
function save_file_h.SAVE_FLAG_TO_STAR_FLAG(cmd: number): number
	return bit32.band(bit32.rshift(cmd, 24), 0x7F)
end

-- from src/game/save_file.h:STAR_FLAG_TO_SAVE_FLAG L110-110
function save_file_h.STAR_FLAG_TO_SAVE_FLAG(cmd: number): number
	return S32(bit32.lshift(cmd, 24))
end

return save_file_h
