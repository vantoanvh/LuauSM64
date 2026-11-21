--!strict
--!optimize 2

--[[
	Port of src/game/save_file.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeCourseTableH = require("../../include/course_table_h")
const GameInit = require("./game_init")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const SaveFileH = require("./save_file_h")
const IncludeLevelTableH = require("../../include/level_table_h")
const SoundInit = require("./sound_init")

export type Eeprom = { Bytes: buffer, Dirty: boolean }

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- gSaveBuffer (buffers.c, only save_file uses it): the C struct SaveBuffer as bytes (save-buffer-bytes)
const SaveBufferSize = SaveFileH.EEPROM_SIZE
const SaveFileSize = 56
const MenuDataStart = 448
const MenuDataSize = 32
const SaveFileCapLevel = 0
const SaveFileCapArea = 1
const SaveFileCapPos = 2
const SaveFileFlags = 8
const SaveFileCourseStars = 12
const SaveFileCourseCoinScores = 37
const MenuDataCoinScoreAges = 0
const MenuDataSoundMode = 16
-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/buffers/buffers.c:gSaveBuffer
const gSaveBuffer = buffer.create(SaveBufferSize)

local Eeprom: Eeprom? = nil

-- byte offset of files[FileIndex][Slot] in gSaveBuffer
const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function SaveFileOffset(FileIndex: number, Slot: number): number
	return (FileIndex * 2 + Slot) * SaveFileSize
end

-- byte offset of menuData[Slot] in gSaveBuffer
const function MenuDataOffset(Slot: number): number
	return MenuDataStart + Slot * MenuDataSize
end

-- from src/game/save_file.c:data
const save_file = {
	MENU_DATA_MAGIC = 0x4849,
	SAVE_FILE_MAGIC = 0x4441,
	-- from src/game/save_file.c:gWarpCheckpoint L22-22
	gWarpCheckpoint = { actNum = 0, courseNum = 0, levelID = 0, areaNum = 0, warpNode = 0 },
	-- from src/game/save_file.c:gMainMenuDataModified L24-24
	gMainMenuDataModified = 0,
	-- from src/game/save_file.c:gSaveFileModified L25-25
	gSaveFileModified = 0,
	-- from src/game/save_file.c:gLastCompletedCourseNum L27-27
	gLastCompletedCourseNum = IncludeCourseTableH.COURSE_NONE,
	-- from src/game/save_file.c:gLastCompletedStarNum L28-28
	gLastCompletedStarNum = 0,
	-- from src/game/save_file.c:sUnusedGotGlobalCoinHiScore L29-29
	sUnusedGotGlobalCoinHiScore = 0,
	-- from src/game/save_file.c:gGotFileCoinHiScore L30-30
	gGotFileCoinHiScore = 0,
	-- from src/game/save_file.c:gCurrCourseStarFlags L31-31
	gCurrCourseStarFlags = 0,
	-- from src/game/save_file.c:gSpecialTripleJump L33-33
	gSpecialTripleJump = 0,
	-- from src/game/save_file.c:gLevelToCourseNumTable L38-40
	gLevelToCourseNumTable = {
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_BBH,
			IncludeCourseTableH.COURSE_CCM,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_HMC,
			IncludeCourseTableH.COURSE_SSL,
			IncludeCourseTableH.COURSE_BOB,
			IncludeCourseTableH.COURSE_SL,
			IncludeCourseTableH.COURSE_WDW,
			IncludeCourseTableH.COURSE_JRB,
			IncludeCourseTableH.COURSE_THI,
			IncludeCourseTableH.COURSE_TTC,
			IncludeCourseTableH.COURSE_RR,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_BITDW,
			IncludeCourseTableH.COURSE_VCUTM,
			IncludeCourseTableH.COURSE_BITFS,
			IncludeCourseTableH.COURSE_SA,
			IncludeCourseTableH.COURSE_BITS,
			IncludeCourseTableH.COURSE_LLL,
			IncludeCourseTableH.COURSE_DDD,
			IncludeCourseTableH.COURSE_WF,
			IncludeCourseTableH.COURSE_CAKE_END,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_PSS,
			IncludeCourseTableH.COURSE_COTMC,
			IncludeCourseTableH.COURSE_TOTWC,
			IncludeCourseTableH.COURSE_BITDW,
			IncludeCourseTableH.COURSE_WMOTR,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_BITFS,
			IncludeCourseTableH.COURSE_BITS,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_TTM,
			IncludeCourseTableH.COURSE_NONE,
			IncludeCourseTableH.COURSE_NONE,
		},
}

Registry.Register("src__game__save_file", save_file)

-- from src/game/save_file.c:stub_save_file_1 L49-51
function save_file.stub_save_file_1()
	-- UNUSED u8 filler[4] only: no code
end

function save_file.AttachEeprom(Device: Eeprom?)
	Eeprom = Device
	GameInit.gEepromProbe = if Device ~= nil then 1 else 0
end

-- from src/game/save_file.c:read_eeprom_data L59-79
function save_file.read_eeprom_data(offset: number, size: number): number
	const Device = Eeprom

	if Device ~= nil then
		buffer.copy(gSaveBuffer, offset, Device.Bytes, offset, size)
	end

	return 0
end

-- from src/game/save_file.c:write_eeprom_data L87-107
function save_file.write_eeprom_data(offset: number, size: number): number
	const Device = Eeprom

	if Device ~= nil and buffer.readstring(Device.Bytes, offset, size) ~= buffer.readstring(gSaveBuffer, offset, size) then
		buffer.copy(Device.Bytes, offset, gSaveBuffer, offset, size)
		Device.Dirty = true
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/save_file.c:calc_checksum L113-120
function save_file.calc_checksum(offset: number, size: number): number
	local chksum = 0

	for Index = 0, size - 3 do
		chksum = U16(chksum + buffer.readu8(gSaveBuffer, offset + Index))
	end

	return chksum
end

-- from src/game/save_file.c:verify_save_block_signature L125-135
function save_file.verify_save_block_signature(offset: number, size: number, magic: number): number
	magic = U16(TruncS32(magic))

	const sigOffset = offset + size - 4

	if buffer.readu16(gSaveBuffer, sigOffset) ~= magic then
		return IncludePRUltratypesH.FALSE
	end

	if buffer.readu16(gSaveBuffer, sigOffset + 2) ~= save_file.calc_checksum(offset, size) then
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/save_file.c:add_save_block_signature L140-145
function save_file.add_save_block_signature(offset: number, size: number, magic: number)
	magic = U16(TruncS32(magic))

	const sigOffset = offset + size - 4

	buffer.writeu16(gSaveBuffer, sigOffset, U16(magic))
	buffer.writeu16(gSaveBuffer, sigOffset + 2, save_file.calc_checksum(offset, size))
end

-- from src/game/save_file.c:restore_main_menu_data L150-161
function save_file.restore_main_menu_data(srcSlot: number)
	const destSlot = bit32.bxor(srcSlot, 1)

	save_file.add_save_block_signature(MenuDataOffset(srcSlot), MenuDataSize, save_file.MENU_DATA_MAGIC)
	buffer.copy(gSaveBuffer, MenuDataOffset(destSlot), gSaveBuffer, MenuDataOffset(srcSlot), MenuDataSize)
	save_file.write_eeprom_data(MenuDataOffset(destSlot), MenuDataSize)
end

-- from src/game/save_file.c:save_main_menu_data L163-176
function save_file.save_main_menu_data()
	if save_file.gMainMenuDataModified ~= 0 then
		save_file.add_save_block_signature(MenuDataOffset(0), MenuDataSize, save_file.MENU_DATA_MAGIC)
		buffer.copy(gSaveBuffer, MenuDataOffset(1), gSaveBuffer, MenuDataOffset(0), MenuDataSize)
		save_file.write_eeprom_data(MenuDataOffset(0), 2 * MenuDataSize)
		save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.FALSE)
	end
end

-- from src/game/save_file.c:wipe_main_menu_data L178-188
function save_file.wipe_main_menu_data()
	buffer.fill(gSaveBuffer, MenuDataOffset(0), 0, MenuDataSize)

	-- Set score ages for all courses to 3, 2, 1, and 0, respectively.
	buffer.writeu32(gSaveBuffer, MenuDataOffset(0) + MenuDataCoinScoreAges, 0x3FFFFFFF)
	buffer.writeu32(gSaveBuffer, MenuDataOffset(0) + MenuDataCoinScoreAges + 4, 0x2AAAAAAA)
	buffer.writeu32(gSaveBuffer, MenuDataOffset(0) + MenuDataCoinScoreAges + 8, 0x15555555)
	save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.TRUE)
	save_file.save_main_menu_data()
end

-- from src/game/save_file.c:get_coin_score_age L190-192
function save_file.get_coin_score_age(fileIndex: number, courseIndex: number): number
	return bit32.band(bit32.rshift(buffer.readu32(gSaveBuffer, MenuDataOffset(0) + MenuDataCoinScoreAges + 4 * fileIndex), 2 * courseIndex), 0x3)
end

-- from src/game/save_file.c:set_coin_score_age L194-199
function save_file.set_coin_score_age(fileIndex: number, courseIndex: number, age: number)
	const mask = bit32.lshift(0x3, 2 * courseIndex)
	const ageOffset = MenuDataOffset(0) + MenuDataCoinScoreAges + 4 * fileIndex

	buffer.writeu32(gSaveBuffer, ageOffset, bit32.band(buffer.readu32(gSaveBuffer, ageOffset), bit32.bnot(mask)))
	buffer.writeu32(gSaveBuffer, ageOffset, bit32.bor(buffer.readu32(gSaveBuffer, ageOffset), bit32.lshift(age, 2 * courseIndex)))
end

-- from src/game/save_file.c:touch_coin_score_age L204-220
function save_file.touch_coin_score_age(fileIndex: number, courseIndex: number)
	const currentAge = save_file.get_coin_score_age(fileIndex, courseIndex)

	if currentAge ~= 0 then
		for Index = 0, SaveFileH.NUM_SAVE_FILES - 1 do
			const age = save_file.get_coin_score_age(Index, courseIndex)

			if age < currentAge then
				save_file.set_coin_score_age(Index, courseIndex, age + 1)
			end
		end

		save_file.set_coin_score_age(fileIndex, courseIndex, 0)
		save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.TRUE)
	end
end

-- from src/game/save_file.c:touch_high_score_ages L225-231
function save_file.touch_high_score_ages(fileIndex: number)
	for Index = IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN), IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) do
		save_file.touch_coin_score_age(fileIndex, Index)
	end
end

-- from src/game/save_file.c:restore_save_file_data L236-250
function save_file.restore_save_file_data(fileIndex: number, srcSlot: number)
	const destSlot = bit32.bxor(srcSlot, 1)

	save_file.add_save_block_signature(SaveFileOffset(fileIndex, srcSlot), SaveFileSize, save_file.SAVE_FILE_MAGIC)
	buffer.copy(gSaveBuffer, SaveFileOffset(fileIndex, destSlot), gSaveBuffer, SaveFileOffset(fileIndex, srcSlot), SaveFileSize)
	save_file.write_eeprom_data(SaveFileOffset(fileIndex, destSlot), SaveFileSize)
end

-- from src/game/save_file.c:save_file_do_save L252-269
function save_file.save_file_do_save(fileIndex: number)
	if save_file.gSaveFileModified ~= 0 then
		save_file.add_save_block_signature(SaveFileOffset(fileIndex, 0), SaveFileSize, save_file.SAVE_FILE_MAGIC)
		buffer.copy(gSaveBuffer, SaveFileOffset(fileIndex, 1), gSaveBuffer, SaveFileOffset(fileIndex, 0), SaveFileSize)
		save_file.write_eeprom_data(SaveFileOffset(fileIndex, 0), 2 * SaveFileSize)
		save_file.gSaveFileModified = S8(IncludePRUltratypesH.FALSE)
	end

	save_file.save_main_menu_data()
end

-- from src/game/save_file.c:save_file_erase L271-277
function save_file.save_file_erase(fileIndex: number)
	save_file.touch_high_score_ages(fileIndex)
	buffer.fill(gSaveBuffer, SaveFileOffset(fileIndex, 0), 0, SaveFileSize)
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
	save_file.save_file_do_save(fileIndex)
end

-- from src/game/save_file.c:save_file_copy L280-289
function save_file.save_file_copy(srcFileIndex: number, destFileIndex: number)
	save_file.touch_high_score_ages(destFileIndex)
	buffer.copy(gSaveBuffer, SaveFileOffset(destFileIndex, 0), gSaveBuffer, SaveFileOffset(srcFileIndex, 0), SaveFileSize)
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
	save_file.save_file_do_save(destFileIndex)
end

-- from src/game/save_file.c:save_file_load_all L291-334
function save_file.save_file_load_all()
	save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.FALSE)
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.FALSE)
	buffer.fill(gSaveBuffer, 0, 0, SaveBufferSize)
	save_file.read_eeprom_data(0, SaveBufferSize)

	-- Verify the main menu data and create a backup copy if only one of the slots is valid.
	local validSlots = save_file.verify_save_block_signature(MenuDataOffset(0), MenuDataSize, save_file.MENU_DATA_MAGIC)

	validSlots = bit32.bor(validSlots, bit32.lshift(save_file.verify_save_block_signature(MenuDataOffset(1), MenuDataSize, save_file.MENU_DATA_MAGIC), 1))

	if validSlots == 0 then
		save_file.wipe_main_menu_data()
	elseif validSlots == 1 then
		save_file.restore_main_menu_data(0)
	elseif validSlots == 2 then
		save_file.restore_main_menu_data(1)
	end

	for File = 0, SaveFileH.NUM_SAVE_FILES - 1 do
		-- Verify the save file and create a backup copy if only one of the slots is valid.
		validSlots = save_file.verify_save_block_signature(SaveFileOffset(File, 0), SaveFileSize, save_file.SAVE_FILE_MAGIC)
		validSlots = bit32.bor(validSlots, bit32.lshift(save_file.verify_save_block_signature(SaveFileOffset(File, 1), SaveFileSize, save_file.SAVE_FILE_MAGIC), 1))

		if validSlots == 0 then
			save_file.save_file_erase(File)
		elseif validSlots == 1 then
			save_file.restore_save_file_data(File, 0)
		elseif validSlots == 2 then
			save_file.restore_save_file_data(File, 1)
		end
	end

	save_file.stub_save_file_1()
end

-- from src/game/save_file.c:save_file_reload L341-351
function save_file.save_file_reload()
	buffer.copy(gSaveBuffer, SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0), gSaveBuffer, SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 1), SaveFileSize)
	buffer.copy(gSaveBuffer, MenuDataOffset(0), gSaveBuffer, MenuDataOffset(1), MenuDataSize)

	save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.FALSE)
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.FALSE)
end

-- from src/game/save_file.c:save_file_collect_star_or_key L357-409
function save_file.save_file_collect_star_or_key(coinScore: number, starIndex: number)
	coinScore = S16(TruncS32(coinScore))
	starIndex = S16(TruncS32(starIndex))

	const fileIndex = Registry.Members.src__game__area.gCurrSaveFileNum - 1
	const courseIndex = IncludeCourseTableH.COURSE_NUM_TO_INDEX(Registry.Members.src__game__area.gCurrCourseNum)
	const starFlag = bit32.lshift(1, starIndex)

	save_file.gLastCompletedCourseNum = U8(courseIndex + 1)
	save_file.gLastCompletedStarNum = U8(starIndex + 1)
	save_file.sUnusedGotGlobalCoinHiScore = S8(IncludePRUltratypesH.FALSE)
	save_file.gGotFileCoinHiScore = U8(IncludePRUltratypesH.FALSE)

	if courseIndex >= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN) and courseIndex <= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) then
		-- Compares the coin score as a 16 bit value, but only writes the 8 bit truncation (kept).
		if coinScore > U16(save_file.save_file_get_max_coin_score(courseIndex)) then
			save_file.sUnusedGotGlobalCoinHiScore = S8(IncludePRUltratypesH.TRUE)
		end

		if coinScore > save_file.save_file_get_course_coin_score(fileIndex, courseIndex) then
			buffer.writeu8(gSaveBuffer, SaveFileOffset(fileIndex, 0) + SaveFileCourseCoinScores + courseIndex, U8(coinScore))
			save_file.touch_coin_score_age(fileIndex, courseIndex)
			save_file.gGotFileCoinHiScore = U8(IncludePRUltratypesH.TRUE)
			save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
		end
	end

	if Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_1 then
		if not bit32.btest(save_file.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_1, SaveFileH.SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)) then
			save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_HAVE_KEY_1)
		end
	elseif Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
		if not bit32.btest(save_file.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_2, SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) then
			save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_HAVE_KEY_2)
		end
	elseif Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_3 then
		-- break: nothing to do
	else
		if not bit32.btest(save_file.save_file_get_star_flags(fileIndex, courseIndex), starFlag) then
			save_file.save_file_set_star_flags(fileIndex, courseIndex, starFlag)
		end
	end
end

-- from src/game/save_file.c:save_file_exists L411-413
function save_file.save_file_exists(fileIndex: number): number
	return if bit32.btest(buffer.readu32(gSaveBuffer, SaveFileOffset(fileIndex, 0) + SaveFileFlags), SaveFileH.SAVE_FLAG_FILE_EXISTS) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/save_file.c:save_file_get_max_coin_score L420-439
function save_file.save_file_get_max_coin_score(courseIndex: number): number
	local maxCoinScore = -1
	local maxScoreAge = -1
	local maxScoreFileNum = 0

	for FileIndex = 0, SaveFileH.NUM_SAVE_FILES - 1 do
		if save_file.save_file_get_star_flags(FileIndex, courseIndex) ~= 0 then
			const coinScore = save_file.save_file_get_course_coin_score(FileIndex, courseIndex)
			const scoreAge = save_file.get_coin_score_age(FileIndex, courseIndex)

			if coinScore > maxCoinScore or (coinScore == maxCoinScore and scoreAge > maxScoreAge) then
				maxCoinScore = coinScore
				maxScoreAge = scoreAge
				maxScoreFileNum = FileIndex + 1
			end
		end
	end

	return bit32.lshift(maxScoreFileNum, 16) + Registry.Members.src__engine__math_util_h.max(maxCoinScore, 0)
end

-- from src/game/save_file.c:save_file_get_course_star_count L441-453
function save_file.save_file_get_course_star_count(fileIndex: number, courseIndex: number): number
	local count = 0
	local flag = U8(1)
	const starFlags = U8(save_file.save_file_get_star_flags(fileIndex, courseIndex))

	for Index = 0, 6 do
		if bit32.btest(starFlags, flag) then
			count += 1
		end

		flag = U8(bit32.lshift(flag, 1))
	end

	return count
end

-- from src/game/save_file.c:save_file_get_total_star_count L455-465
function save_file.save_file_get_total_star_count(fileIndex: number, minCourse: number, maxCourse: number): number
	local count = 0

	for CourseIndex = minCourse, maxCourse do
		count += save_file.save_file_get_course_star_count(fileIndex, CourseIndex)
	end

	-- Add castle secret star count.
	return save_file.save_file_get_course_star_count(fileIndex, IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_NONE)) + count
end

-- from src/game/save_file.c:save_file_set_flags L467-470
function save_file.save_file_set_flags(flags: number)
	const fileOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0)

	buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.bor(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), bit32.bor(flags, SaveFileH.SAVE_FLAG_FILE_EXISTS)))
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
end

-- from src/game/save_file.c:save_file_clear_flags L472-476
function save_file.save_file_clear_flags(flags: number)
	const fileOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0)

	buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.band(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), bit32.bnot(flags)))
	buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.bor(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), SaveFileH.SAVE_FLAG_FILE_EXISTS))
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
end

-- from src/game/save_file.c:save_file_get_flags L478-483
function save_file.save_file_get_flags(): number
	if Registry.Members.src__game__area.gCurrCreditsEntry ~= nil or GameInit.gCurrDemoInput ~= nil then
		return 0
	end

	return buffer.readu32(gSaveBuffer, SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0) + SaveFileFlags)
end

-- from src/game/save_file.c:save_file_get_star_flags L489-499
function save_file.save_file_get_star_flags(fileIndex: number, courseIndex: number): number
	local starFlags: number

	if courseIndex == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_NONE) then
		starFlags = SaveFileH.SAVE_FLAG_TO_STAR_FLAG(buffer.readu32(gSaveBuffer, SaveFileOffset(fileIndex, 0) + SaveFileFlags))
	else
		starFlags = bit32.band(buffer.readu8(gSaveBuffer, SaveFileOffset(fileIndex, 0) + SaveFileCourseStars + courseIndex), 0x7F)
	end

	return starFlags
end

-- from src/game/save_file.c:save_file_set_star_flags L505-514
function save_file.save_file_set_star_flags(fileIndex: number, courseIndex: number, starFlags: number)
	const fileOffset = SaveFileOffset(fileIndex, 0)

	if courseIndex == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_NONE) then
		buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.bor(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), SaveFileH.STAR_FLAG_TO_SAVE_FLAG(starFlags)))
	else
		buffer.writeu8(gSaveBuffer, fileOffset + SaveFileCourseStars + courseIndex, U8(bit32.bor(buffer.readu8(gSaveBuffer, fileOffset + SaveFileCourseStars + courseIndex), starFlags)))
	end

	buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.bor(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), SaveFileH.SAVE_FLAG_FILE_EXISTS))
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
end

-- from src/game/save_file.c:save_file_get_course_coin_score L516-518
function save_file.save_file_get_course_coin_score(fileIndex: number, courseIndex: number): number
	return buffer.readu8(gSaveBuffer, SaveFileOffset(fileIndex, 0) + SaveFileCourseCoinScores + courseIndex)
end

-- from src/game/save_file.c:save_file_is_cannon_unlocked L523-525
function save_file.save_file_is_cannon_unlocked(): number
	const starsOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0) + SaveFileCourseStars + Registry.Members.src__game__area.gCurrCourseNum

	return if bit32.btest(buffer.readu8(gSaveBuffer, starsOffset), 0x80) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/save_file.c:save_file_set_cannon_unlocked L530-534
function save_file.save_file_set_cannon_unlocked()
	const fileOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0)
	const starsOffset = fileOffset + SaveFileCourseStars + Registry.Members.src__game__area.gCurrCourseNum

	buffer.writeu8(gSaveBuffer, starsOffset, U8(bit32.bor(buffer.readu8(gSaveBuffer, starsOffset), 0x80)))
	buffer.writeu32(gSaveBuffer, fileOffset + SaveFileFlags, bit32.bor(buffer.readu32(gSaveBuffer, fileOffset + SaveFileFlags), SaveFileH.SAVE_FLAG_FILE_EXISTS))
	save_file.gSaveFileModified = S8(IncludePRUltratypesH.TRUE)
end

-- from src/game/save_file.c:save_file_set_cap_pos L536-543
function save_file.save_file_set_cap_pos(x: number, y: number, z: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))

	const fileOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0)

	buffer.writeu8(gSaveBuffer, fileOffset + SaveFileCapLevel, U8(Registry.Members.src__game__area.gCurrLevelNum))
	buffer.writeu8(gSaveBuffer, fileOffset + SaveFileCapArea, U8(Registry.Members.src__game__area.gCurrAreaIndex))
	buffer.writei16(gSaveBuffer, fileOffset + SaveFileCapPos, x)
	buffer.writei16(gSaveBuffer, fileOffset + SaveFileCapPos + 2, y)
	buffer.writei16(gSaveBuffer, fileOffset + SaveFileCapPos + 4, z)
	save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_GROUND)
end

-- from src/game/save_file.c:save_file_get_cap_pos L545-555
function save_file.save_file_get_cap_pos(capPos: { number }): number
	const fileOffset = SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0)
	const flags = save_file.save_file_get_flags()

	if buffer.readu8(gSaveBuffer, fileOffset + SaveFileCapLevel) == Registry.Members.src__game__area.gCurrLevelNum and buffer.readu8(gSaveBuffer, fileOffset + SaveFileCapArea) == Registry.Members.src__game__area.gCurrAreaIndex and bit32.btest(flags, SaveFileH.SAVE_FLAG_CAP_ON_GROUND) then
		capPos[1] = buffer.readi16(gSaveBuffer, fileOffset + SaveFileCapPos)
		capPos[2] = buffer.readi16(gSaveBuffer, fileOffset + SaveFileCapPos + 2)
		capPos[3] = buffer.readi16(gSaveBuffer, fileOffset + SaveFileCapPos + 4)

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/save_file.c:save_file_set_sound_mode L557-563
function save_file.save_file_set_sound_mode(mode: number)
	mode = U16(TruncS32(mode))
	SoundInit.set_sound_mode(mode)
	buffer.writeu16(gSaveBuffer, MenuDataOffset(0) + MenuDataSoundMode, mode)
	save_file.gMainMenuDataModified = S8(IncludePRUltratypesH.TRUE)
	save_file.save_main_menu_data()
end

-- from src/game/save_file.c:save_file_get_sound_mode L565-567
function save_file.save_file_get_sound_mode(): number
	return buffer.readu16(gSaveBuffer, MenuDataOffset(0) + MenuDataSoundMode)
end

-- from src/game/save_file.c:save_file_move_cap_to_default_location L569-584
function save_file.save_file_move_cap_to_default_location()
	if bit32.btest(save_file.save_file_get_flags(), SaveFileH.SAVE_FLAG_CAP_ON_GROUND) then
		const capLevel = buffer.readu8(gSaveBuffer, SaveFileOffset(Registry.Members.src__game__area.gCurrSaveFileNum - 1, 0) + SaveFileCapLevel)

		if capLevel == IncludeLevelTableH.LEVEL_SSL then
			save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO)
		elseif capLevel == IncludeLevelTableH.LEVEL_SL then
			save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_MR_BLIZZARD)
		elseif capLevel == IncludeLevelTableH.LEVEL_TTM then
			save_file.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_UKIKI)
		end

		save_file.save_file_clear_flags(SaveFileH.SAVE_FLAG_CAP_ON_GROUND)
	end
end

-- from src/game/save_file.c:disable_warp_checkpoint L598-601
function save_file.disable_warp_checkpoint()
	-- check_warp_checkpoint() checks to see if gWarpCheckpoint.courseNum != COURSE_NONE
	save_file.gWarpCheckpoint.courseNum = U8(IncludeCourseTableH.COURSE_NONE)
end

-- from src/game/save_file.c:check_if_should_set_warp_checkpoint L607-616
function save_file.check_if_should_set_warp_checkpoint(warpNode: GroupsTypesHPlus3.WarpNode)
	if bit32.btest(warpNode.destLevel, 0x80) then
		-- Overwrite the warp checkpoint variables.
		save_file.gWarpCheckpoint.actNum = U8(Registry.Members.src__game__area.gCurrActNum)
		save_file.gWarpCheckpoint.courseNum = U8(Registry.Members.src__game__area.gCurrCourseNum)
		save_file.gWarpCheckpoint.levelID = U8(bit32.band(warpNode.destLevel, 0x7F))
		save_file.gWarpCheckpoint.areaNum = warpNode.destArea
		save_file.gWarpCheckpoint.warpNode = warpNode.destNode
	end
end

-- from src/game/save_file.c:check_warp_checkpoint L623-640
function save_file.check_warp_checkpoint(warpNode: GroupsTypesHPlus3.WarpNode): number
	local warpCheckpointActive = S16(IncludePRUltratypesH.FALSE)
	const currCourseNum = save_file.gLevelToCourseNumTable[bit32.band(warpNode.destLevel, 0x7F)]

	-- gSavedCourseNum is only used in this function.
	if save_file.gWarpCheckpoint.courseNum ~= IncludeCourseTableH.COURSE_NONE and Registry.Members.src__game__area.gSavedCourseNum == currCourseNum and save_file.gWarpCheckpoint.actNum == Registry.Members.src__game__area.gCurrActNum then
		warpNode.destLevel = save_file.gWarpCheckpoint.levelID
		warpNode.destArea = save_file.gWarpCheckpoint.areaNum
		warpNode.destNode = save_file.gWarpCheckpoint.warpNode
		warpCheckpointActive = S16(IncludePRUltratypesH.TRUE)
	else
		-- Disable the warp checkpoint just in case the other 2 conditions failed?
		save_file.gWarpCheckpoint.courseNum = U8(IncludeCourseTableH.COURSE_NONE)
	end

	return warpCheckpointActive
end

return save_file
