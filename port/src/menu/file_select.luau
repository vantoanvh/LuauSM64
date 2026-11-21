--!strict
--!optimize 2

--[[
	Port of src/menu/file_select.c.
]]

const Registry = require("../../groups/registry")

const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeSoundsH = require("../../include/sounds_h")

const FileSelectH = require("./file_select_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const SrcGameObjectHelpers = require("../game/object_helpers")
const SrcGameObjectListProcessor = require("../game/object_list_processor")
const BehaviorIds = require("../rom/behavior_ids")
const IncludeModelIdsH = require("../../include/model_ids_h")
const SrcGameArea = require("../game/area")
const SrcGameSaveFile = require("../game/save_file")
const SrcGameSaveFileH = require("../game/save_file_h")
const SrcGameSpawnObject = require("../game/spawn_object")
const IncludePROsH = require("../../include/PR/os_h")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludeTextStringsH = require("../../include/text_strings_h")
const Gbi = require("../rom/gbi")
const MenuSymbols = require("../rom/menu_symbols")
const Audio = require("../rom/audio_recorder")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const SrcGameGameInit = require("../game/game_init")
const SrcGameMemory = require("../game/memory")
const SrcGamePrintH = require("../game/print_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

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

-- from src/menu/file_select.luau:scratch
const Scratch = {
	print_save_file_star_count_starCountText = buffer.create(4),
	print_score_file_castle_secret_stars_secretStarsText = buffer.create(20),
	print_score_file_course_coin_score_coinScoreText = buffer.create(20),
	print_score_file_star_score_starScoreText = buffer.create(19),
	-- the strings of ROM data the text printers take as a buffer (CopyRomString)
	PRINT_COURSE_NAME_AND_SCORES_courseName = buffer.create(64),
	-- TEXT_ZERO and TEXT_FILE_MARIO_A_JUST_ERASED, of which the file letter is written before they are printed
	print_save_file_scores_textFileLetter = buffer.fromstring(buffer.tostring(IncludeTextStringsH.TEXT_ZERO)),
	erase_menu_display_message_textMarioAJustErased = buffer.fromstring(buffer.tostring(IncludeTextStringsH.TEXT_FILE_MARIO_A_JUST_ERASED)),
}

-- from src/menu/file_select.c:data
const file_select = {
	FILE_SELECT_PRINT_STRING = GroupsIngameMenuPlus1.print_menu_generic_string,
	FILE_SELECT_TEXT_DL_BEGIN = MenuSymbols.dl_menu_ia8_text_begin,
	FILE_SELECT_TEXT_DL_END = MenuSymbols.dl_menu_ia8_text_end,
	-- from src/menu/file_select.c:sSoundTextX L50-50
	sSoundTextX = 0,
	NUM_BUTTONS = 32, -- MENU_BUTTON_OPTION_MAX
	-- from src/menu/file_select.c:sMainMenuButtons L64-64
	sMainMenuButtons = {
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
			nil,
		} :: { GroupsTypesHPlus3.Object? },
	-- from src/menu/file_select.c:sYesNoColor L68-68
	sYesNoColor = buffer.create(2),
	-- from src/menu/file_select.c:sSelectedButtonID L71-71
	sSelectedButtonID = FileSelectH.MENU_BUTTON_NONE,
	-- from src/menu/file_select.c:sCurrentMenuLevel L80-80
	sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN,
	-- from src/menu/file_select.c:sTextBaseAlpha L83-83
	sTextBaseAlpha = 0,
	-- from src/menu/file_select.c:sCursorPos L87-87
	sCursorPos = { 0, 0 },
	-- from src/menu/file_select.c:sCursorClickingTimer L90-90
	sCursorClickingTimer = 0,
	-- from src/menu/file_select.c:sClickPos L93-93
	sClickPos = { -10000, -10000 },
	-- from src/menu/file_select.c:sSelectedFileIndex L96-96
	sSelectedFileIndex = -1,
	-- from src/menu/file_select.c:sFadeOutText L99-99
	sFadeOutText = 0,
	-- from src/menu/file_select.c:sStatusMessageID L102-102
	sStatusMessageID = 0,
	-- from src/menu/file_select.c:sTextFadeAlpha L106-106
	sTextFadeAlpha = 0,
	-- from src/menu/file_select.c:sMainMenuTimer L112-112
	sMainMenuTimer = 0,
	-- from src/menu/file_select.c:sSoundMode L116-116
	sSoundMode = 0,
	-- from src/menu/file_select.c:sEraseYesNoHoverState L125-125
	sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NONE,
	-- from src/menu/file_select.c:sAllFilesExist L129-129
	sAllFilesExist = 0,
	-- from src/menu/file_select.c:sSelectedFileNum L133-133
	sSelectedFileNum = 0,
	-- from src/menu/file_select.c:sScoreFileCoinScoreMode L137-137
	sScoreFileCoinScoreMode = 0,
	-- from src/menu/file_select.c:textReturn L145-145
	textReturn = IncludeTextStringsH.TEXT_RETURN,
	-- from src/menu/file_select.c:textViewScore L151-151
	textViewScore = IncludeTextStringsH.TEXT_CHECK_SCORE,
	-- from src/menu/file_select.c:textCopyFileButton L157-157
	textCopyFileButton = IncludeTextStringsH.TEXT_COPY_FILE_BUTTON,
	-- from src/menu/file_select.c:textEraseFileButton L163-163
	textEraseFileButton = IncludeTextStringsH.TEXT_ERASE_FILE_BUTTON,
	-- from src/menu/file_select.c:textSoundModes L169-169
	textSoundModes = { IncludeTextStringsH.TEXT_STEREO, IncludeTextStringsH.TEXT_MONO, IncludeTextStringsH.TEXT_HEADSET },
	-- from src/menu/file_select.c:textMarioA L172-172
	textMarioA = IncludeTextStringsH.TEXT_FILE_MARIO_A,
	-- from src/menu/file_select.c:textMarioB L173-173
	textMarioB = IncludeTextStringsH.TEXT_FILE_MARIO_B,
	-- from src/menu/file_select.c:textMarioC L174-174
	textMarioC = IncludeTextStringsH.TEXT_FILE_MARIO_C,
	-- from src/menu/file_select.c:textMarioD L175-175
	textMarioD = IncludeTextStringsH.TEXT_FILE_MARIO_D,
	-- from src/menu/file_select.c:textNew L178-178
	textNew = IncludeTextStringsH.TEXT_NEW,
	-- from src/menu/file_select.c:starIcon L179-179
	starIcon = buffer.fromstring(string.char(SrcGamePrintH.GLYPH_STAR, bit32.band(SrcGamePrintH.GLYPH_SPACE, 0xFF))),
	-- from src/menu/file_select.c:xIcon L180-180
	xIcon = buffer.fromstring(string.char(SrcGamePrintH.GLYPH_MULTIPLY, bit32.band(SrcGamePrintH.GLYPH_SPACE, 0xFF))),
	-- from src/menu/file_select.c:textSelectFile L184-184
	textSelectFile = IncludeTextStringsH.TEXT_SELECT_FILE,
	-- from src/menu/file_select.c:textScore L190-190
	textScore = IncludeTextStringsH.TEXT_SCORE,
	-- from src/menu/file_select.c:textCopy L196-196
	textCopy = IncludeTextStringsH.TEXT_COPY,
	-- from src/menu/file_select.c:textErase L202-202
	textErase = IncludeTextStringsH.TEXT_ERASE,
	-- from src/menu/file_select.c:textCheckFile L212-212
	textCheckFile = IncludeTextStringsH.TEXT_CHECK_FILE,
	-- from src/menu/file_select.c:textNoSavedDataExists L218-218
	textNoSavedDataExists = IncludeTextStringsH.TEXT_NO_SAVED_DATA_EXISTS,
	-- from src/menu/file_select.c:textCopyFile L224-224
	textCopyFile = IncludeTextStringsH.TEXT_COPY_FILE,
	-- from src/menu/file_select.c:textCopyItToWhere L230-230
	textCopyItToWhere = IncludeTextStringsH.TEXT_COPY_IT_TO_WHERE,
	-- from src/menu/file_select.c:textNoSavedDataExistsCopy L236-236
	textNoSavedDataExistsCopy = IncludeTextStringsH.TEXT_NO_SAVED_DATA_EXISTS,
	-- from src/menu/file_select.c:textCopyCompleted L240-240
	textCopyCompleted = IncludeTextStringsH.TEXT_COPYING_COMPLETED,
	-- from src/menu/file_select.c:textSavedDataExists L246-246
	textSavedDataExists = IncludeTextStringsH.TEXT_SAVED_DATA_EXISTS,
	-- from src/menu/file_select.c:textNoFileToCopyFrom L252-252
	textNoFileToCopyFrom = IncludeTextStringsH.TEXT_NO_FILE_TO_COPY_FROM,
	-- from src/menu/file_select.c:textYes L258-258
	textYes = IncludeTextStringsH.TEXT_YES,
	-- from src/menu/file_select.c:textNo L264-264
	textNo = IncludeTextStringsH.TEXT_NO,
	SCORE_TIMER = 31,
	BUZZ_TIMER = 21,
	ACTION_TIMER = 31,
	MAIN_RETURN_TIMER = 31,
	SOUND_BUTTON_Y = 0,
	SAVE_FILE_SOUND = IncludeSoundsH.SOUND_MENU_STAR_SOUND_OKEY_DOKEY,
	SELECT_FILE_X = 93,
	SELECT_FILE_Y = 35,
	SCORE_X = 52,
	COPY_X = 117,
	ERASE_X = 177,
	SAVEFILE_X1 = 92,
	SAVEFILE_X2 = 209,
	MARIOTEXT_X1 = 92,
	MARIOTEXT_X2 = 207,
	MARIOTEXT_Y1 = 65,
	MARIOTEXT_Y2 = 105,
	CHECK_FILE_X = 95,
	CHECK_FILE_Y = 35,
	NOSAVE_DATA_X1 = 99,
	RETURN_X = 44,
	COPYFILE_X1 = 135,
	ERASEFILE_X1 = 231,
	SCORE_FILE_Y1 = 62,
	SCORE_FILE_Y2 = 105,
	RETURN_X_OLD = 44, -- RETURN_X
	FADEOUT_TIMER = 20,
	NOFILE_COPY_X = 119,
	COPY_FILE_X = 104,
	COPYIT_WHERE_X = 109,
	NOSAVE_DATA_X2 = 101,
	COPYCOMPLETE_X = 110,
	SAVE_EXISTS_X1 = 110,
	COPY_FILE_Y = 35,
	VIEWSCORE_X1 = 128,
	ERASEFILE_X2 = 230,
	COPY_FILE_Y1 = 62,
	COPY_FILE_Y2 = 105,
	CURSOR_X = nil --[[ TODO: x is not defined: x + 70 ]],
	MENU_ERASE_YES_MIN_X = 140,
	MENU_ERASE_YES_MAX_X = 169,
	MENU_ERASE_YES_NO_MIN_Y = 191,
	MENU_ERASE_YES_NO_MAX_Y = 210,
	MENU_ERASE_NO_MIN_X = 189,
	MENU_ERASE_NO_MAX_X = 218,
	MENU_ERASE_YES_X_OFFSET = 56,
	ERASE_FILE_X = 98,
	ERASE_FILE_Y = 35,
	NOSAVE_DATA_X3 = 100,
	MARIO_ERASED_VAR = 6,
	MARIO_ERASED_X = 100,
	SAVE_EXISTS_X2 = 100,
	VIEWSCORE_X2 = 127,
	COPYFILE_X2 = 233,
	ERASE_FILE_Y1 = 62,
	ERASE_FILE_Y2 = 105,
	SOUND_HUD_X = 88,
	SOUND_HUD_Y = 35,
	-- from src/menu/file_select.c:textStarX L2709-2709
	textStarX = IncludeTextStringsH.TEXT_STAR_X,
	-- from src/menu/file_select.c:print_score_file_course_coin_score:fileNames L2768-2771
	fileNames = { IncludeTextStringsH.TEXT_4DASHES, IncludeTextStringsH.TEXT_SCORE_MARIO_A, IncludeTextStringsH.TEXT_SCORE_MARIO_B, IncludeTextStringsH.TEXT_SCORE_MARIO_C, IncludeTextStringsH.TEXT_SCORE_MARIO_D },
	HISCORE_COIN_ICON_X = 18,
	HISCORE_COIN_TEXT_X = 34,
	HISCORE_COIN_NAMES_X = 60,
	MARIO_X = 25,
	MARIO_Y = 15,
	FILE_LETTER_X = 95,
	LEVEL_NUM_PAD = 3,
	SECRET_STARS_PAD = 6,
	LEVEL_NAME_X = 23,
	STAR_SCORE_X = 171,
	MYSCORE_X = 238,
	HISCORE_X = 231,
	MYSCORE_Y = 24,
	HISCORE_Y = 24,
}

Registry.Register("src__menu__file_select", file_select)

-- from src/menu/file_select.c:beh_yellow_background_menu_init L309-312
function file_select.beh_yellow_background_menu_init()
	const o = SrcGameObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0x8000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oMenuButtonScale, 9.0)
end

-- from src/menu/file_select.c:beh_yellow_background_menu_loop L318-320
function file_select.beh_yellow_background_menu_loop()
	SrcGameObjectHelpers.cur_obj_scale(9.0)
end

-- from src/menu/file_select.c:check_clicked_button L326-339
function file_select.check_clicked_button(x: number, y: number, depth: number): number
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	depth = F32(depth)
	const a = F32(52.4213)
	const newX = F32((x * 160.0) / F32(a * depth))
	const newY = F32((y * 120.0) / F32(F32(F32(a * 3) / 4) * depth))
	const maxX = S16(TruncS32(F32(newX + 25.0)))
	const minX = S16(TruncS32(F32(newX - 25.0)))
	const maxY = S16(TruncS32(F32(newY + 21.0)))
	const minY = S16(TruncS32(F32(newY - 21.0)))

	if file_select.sClickPos[1] < maxX and minX < file_select.sClickPos[1] and file_select.sClickPos[2] < maxY and minY < file_select.sClickPos[2] then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/menu/file_select.c:bhv_menu_button_growing_from_main_menu L344-366
function file_select.bhv_menu_button_growing_from_main_menu(button: GroupsTypesHPlus3.Object)
	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 8 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 8 and buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x800))
	end

	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX) - buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX) / 16.0)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY) - buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY) / 16.0)

	if buffer.readf32(button.rawData, IncludeObjectFieldsH.oPosZ) < buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosZ) + 17800.0 then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) + 1112.5)
	end

	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 16 then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, 0.0)
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, 0.0)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_FULLSCREEN)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_shrinking_to_main_menu L371-393
function file_select.bhv_menu_button_shrinking_to_main_menu(button: GroupsTypesHPlus3.Object)
	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 8 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 8 and buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800))
	end

	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX) + buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX) / 16.0)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY) + buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY) / 16.0)

	if buffer.readf32(button.rawData, IncludeObjectFieldsH.oPosZ) > buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosZ) then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) - 1112.5)
	end

	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 16 then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX))
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY))
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_DEFAULT)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_growing_from_submenu L398-418
function file_select.bhv_menu_button_growing_from_submenu(button: GroupsTypesHPlus3.Object)
	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 8 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 8 and buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x800))
	end

	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX) - buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX) / 16.0)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY) - buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY) / 16.0)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) - 116.25)

	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 16 then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, 0.0)
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, 0.0)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_FULLSCREEN)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_shrinking_to_submenu L423-445
function file_select.bhv_menu_button_shrinking_to_submenu(button: GroupsTypesHPlus3.Object)
	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 8 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x800))
	end

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 8 and buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 16 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800))
	end

	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX) + buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX) / 16.0)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY) + buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY) / 16.0)

	if buffer.readf32(button.rawData, IncludeObjectFieldsH.oPosZ) > buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosZ) then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) + 116.25)
	end

	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 16 then
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX))
		buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY))
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_DEFAULT)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_zoom_in_out L451-472
function file_select.bhv_menu_button_zoom_in_out(button: GroupsTypesHPlus3.Object)
	if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_MAIN then
		if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 4 then
			buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) - 20.0)
		end

		if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 4 then
			buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) + 20.0)
		end
	else
		if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) < 4 then
			buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) + 20.0)
		end

		if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) >= 4 then
			buffer.writef32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(button.rawData, IncludeObjectFieldsH.oParentRelativePosZ) - 20.0)
		end
	end

	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 8 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_DEFAULT)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_zoom_in L478-485
function file_select.bhv_menu_button_zoom_in(button: GroupsTypesHPlus3.Object)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oMenuButtonScale, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonScale) + 0.0022)
	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 10 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_DEFAULT)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_zoom_out L492-499
function file_select.bhv_menu_button_zoom_out(button: GroupsTypesHPlus3.Object)
	buffer.writef32(button.rawData, IncludeObjectFieldsH.oMenuButtonScale, buffer.readf32(button.rawData, IncludeObjectFieldsH.oMenuButtonScale) - 0.0022)
	buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, S32(buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) + 1))

	if buffer.readi32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer) == 10 then
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_DEFAULT)
		buffer.writei32(button.rawData, IncludeObjectFieldsH.oMenuButtonTimer, 0)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_init L506-509
function file_select.bhv_menu_button_init()
	const o = SrcGameObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY))
end

-- from src/menu/file_select.c:bhv_menu_button_loop L516-557
function file_select.bhv_menu_button_loop()
	const o = SrcGameObjectListProcessor.gCurrentObject
	const state = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMenuButtonState)

	if state == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMenuButtonOrigPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	elseif state == FileSelectH.MENU_BUTTON_STATE_GROWING then
		if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_MAIN then
			file_select.bhv_menu_button_growing_from_main_menu(o)
		end

		if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_SUBMENU then
			file_select.bhv_menu_button_growing_from_submenu(o)
		end

		file_select.sTextBaseAlpha = 0
		file_select.sCursorClickingTimer = 4
	elseif state == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		-- Menu state: nothing to do.
	elseif state == FileSelectH.MENU_BUTTON_STATE_SHRINKING then
		if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_MAIN then
			file_select.bhv_menu_button_shrinking_to_main_menu(o)
		end

		if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_SUBMENU then
			file_select.bhv_menu_button_shrinking_to_submenu(o)
		end

		file_select.sTextBaseAlpha = 0
		file_select.sCursorClickingTimer = 4
	elseif state == FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT then
		file_select.bhv_menu_button_zoom_in_out(o)
		file_select.sCursorClickingTimer = 4
	elseif state == FileSelectH.MENU_BUTTON_STATE_ZOOM_IN then
		file_select.bhv_menu_button_zoom_in(o)
		file_select.sCursorClickingTimer = 4
	elseif state == FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT then
		file_select.bhv_menu_button_zoom_out(o)
		file_select.sCursorClickingTimer = 4
	end

	SrcGameObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMenuButtonScale))
end

-- from src/menu/file_select.c:exit_score_file_to_score_menu L562-579
function file_select.exit_score_file_to_score_menu(scoreFileButton: GroupsTypesHPlus3.Object, scoreButtonID: number)
	scoreButtonID = S8(TruncS32(scoreButtonID))
	-- Begin exit
	if buffer.readi32(scoreFileButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN and file_select.sCursorClickingTimer == 2 then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
		buffer.writei32(scoreFileButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_SHRINKING)
	end

	-- End exit
	if buffer.readi32(scoreFileButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		file_select.sSelectedButtonID = scoreButtonID

		if file_select.sCurrentMenuLevel == FileSelectH.MENU_LAYER_SUBMENU then
			file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
		end
	end
end

-- from src/menu/file_select.c:render_score_menu_buttons L585-639
function file_select.render_score_menu_buttons(scoreButton: GroupsTypesHPlus3.Object)
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_A) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	end

	const scoreFileAButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_A + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreFileAButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_B) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	end

	const scoreFileBButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_B + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreFileBButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_C) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	end

	const scoreFileCButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_C + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreFileCButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_D) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	end

	const scoreFileDButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_D + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreFileDButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Return to main menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_RETURN + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_YELLOW_FILE_BUTTON, BehaviorIds.bhvMenuButton, 711, -388, -100, 0, -0x8000, 0)

	const scoreReturnButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_RETURN + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreReturnButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to copy menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_COPY_FILE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_BLUE_COPY_BUTTON, BehaviorIds.bhvMenuButton, 0, -388, -100, 0, -0x8000, 0)

	const scoreCopyButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_COPY_FILE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreCopyButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to erase menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_ERASE_FILE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(scoreButton, IncludeModelIdsH.MODEL_MAIN_MENU_RED_ERASE_BUTTON, BehaviorIds.bhvMenuButton, -711, -388, -100, 0, -0x8000, 0)

	const scoreEraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_ERASE_FILE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreEraseButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)
end

-- from src/menu/file_select.c:check_score_menu_clicked_buttons L650-700
function file_select.check_score_menu_clicked_buttons(scoreButton: GroupsTypesHPlus3.Object)
	if buffer.readi32(scoreButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		-- Configure score menu button group
		for buttonID = FileSelectH.MENU_BUTTON_SCORE_MIN, FileSelectH.MENU_BUTTON_SCORE_MAX - 1 do
			const buttonObject = file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object
			const buttonX = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosX)))
			const buttonY = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosY)))

			if file_select.check_clicked_button(buttonX, buttonY, 22.0) == IncludePRUltratypesH.TRUE and file_select.sMainMenuTimer >= file_select.SCORE_TIMER then
				-- If menu button clicked, select it
				if buttonID == FileSelectH.MENU_BUTTON_SCORE_RETURN or buttonID == FileSelectH.MENU_BUTTON_SCORE_COPY_FILE or buttonID == FileSelectH.MENU_BUTTON_SCORE_ERASE_FILE then
					Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
					buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)
					file_select.sSelectedButtonID = S8(buttonID)
				else
					-- Check if a save file is clicked
					if file_select.sMainMenuTimer >= file_select.SCORE_TIMER then
						-- If clicked in a existing save file, select it too see it's score
						if SrcGameSaveFile.save_file_exists(buttonID - FileSelectH.MENU_BUTTON_SCORE_MIN) == IncludePRUltratypesH.TRUE then
							Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
							buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
							file_select.sSelectedButtonID = S8(buttonID)
						else
							-- If clicked in a non-existing save file, play buzz sound
							Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
							buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)

							if file_select.sMainMenuTimer >= file_select.SCORE_TIMER then
								file_select.sFadeOutText = IncludePRUltratypesH.TRUE
								file_select.sMainMenuTimer = 0
							end
						end
					end
				end

				file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_SUBMENU

				break
			end
		end
	end
end

-- from src/menu/file_select.c:render_copy_menu_buttons L708-760
function file_select.render_copy_menu_buttons(copyButton: GroupsTypesHPlus3.Object)
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_A) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	end

	const copyFileAButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_A + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyFileAButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_B) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	end

	const copyFileBButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_B + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyFileBButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_C) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	end

	const copyFileCButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_C + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyFileCButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_D) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	end

	const copyFileDButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_D + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyFileDButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Return to main menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_RETURN + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_YELLOW_FILE_BUTTON, BehaviorIds.bhvMenuButton, 711, -388, -100, 0, -0x8000, 0)

	const copyReturnButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_RETURN + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyReturnButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to scire menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_CHECK_SCORE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_GREEN_SCORE_BUTTON, BehaviorIds.bhvMenuButton, 0, -388, -100, 0, -0x8000, 0)

	const copyCheckScoreButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_CHECK_SCORE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyCheckScoreButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to erase menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_ERASE_FILE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(copyButton, IncludeModelIdsH.MODEL_MAIN_MENU_RED_ERASE_BUTTON, BehaviorIds.bhvMenuButton, -711, -388, -100, 0, -0x8000, 0)

	const copyEraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_ERASE_FILE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyEraseButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)
end

-- from src/menu/file_select.c:copy_action_file_button L771-837
function file_select.copy_action_file_button(copyButton: GroupsTypesHPlus3.Object, copyFileButtonID: number)
	const phase = buffer.readi32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase)

	if phase == FileSelectH.COPY_PHASE_MAIN then
		if file_select.sAllFilesExist == IncludePRUltratypesH.TRUE then
			return
		end

		if SrcGameSaveFile.save_file_exists(copyFileButtonID - FileSelectH.MENU_BUTTON_COPY_MIN) == IncludePRUltratypesH.TRUE then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
			const copiedButton = file_select.sMainMenuButtons[copyFileButtonID + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(copiedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN)
			file_select.sSelectedFileIndex = S8(copyFileButtonID - FileSelectH.MENU_BUTTON_COPY_MIN)
			buffer.writei32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.COPY_PHASE_COPY_WHERE)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
			file_select.sMainMenuTimer = 0
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
			const buzzedButton = file_select.sMainMenuButtons[copyFileButtonID + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(buzzedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)

			if file_select.sMainMenuTimer >= file_select.BUZZ_TIMER then
				file_select.sFadeOutText = IncludePRUltratypesH.TRUE
				file_select.sMainMenuTimer = 0
			end
		end
	elseif phase == FileSelectH.COPY_PHASE_COPY_WHERE then
		const targetButton = file_select.sMainMenuButtons[copyFileButtonID + 1] :: GroupsTypesHPlus3.Object

		buffer.writei32(targetButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)

		if SrcGameSaveFile.save_file_exists(copyFileButtonID - FileSelectH.MENU_BUTTON_COPY_MIN) == IncludePRUltratypesH.FALSE then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
			buffer.writei32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.COPY_PHASE_COPY_COMPLETE)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
			file_select.sMainMenuTimer = 0
			SrcGameSaveFile.save_file_copy(file_select.sSelectedFileIndex, copyFileButtonID - FileSelectH.MENU_BUTTON_COPY_MIN)
			targetButton.header.gfx.sharedChild = SrcGameArea.gLoadedGraphNodes[IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE + 1]

			const sourceButton = file_select.sMainMenuButtons[copyFileButtonID - FileSelectH.MENU_BUTTON_COPY_MIN + 1] :: GroupsTypesHPlus3.Object

			sourceButton.header.gfx.sharedChild = SrcGameArea.gLoadedGraphNodes[IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE + 1]
		else
			-- If clicked in a existing save file, play buzz sound
			if copyFileButtonID == FileSelectH.MENU_BUTTON_COPY_FILE_A + file_select.sSelectedFileIndex then
				Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
				const selectedButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_FILE_A + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

				buffer.writei32(selectedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT)
				buffer.writei32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.COPY_PHASE_MAIN)
				file_select.sFadeOutText = IncludePRUltratypesH.TRUE

				return
			end

			if file_select.sMainMenuTimer >= file_select.BUZZ_TIMER then
				file_select.sFadeOutText = IncludePRUltratypesH.TRUE
				file_select.sMainMenuTimer = 0
			end
		end
	end
end

-- from src/menu/file_select.c:check_copy_menu_clicked_buttons L850-891
function file_select.check_copy_menu_clicked_buttons(copyButton: GroupsTypesHPlus3.Object)
	if buffer.readi32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		-- Configure copy menu button group
		for buttonID = FileSelectH.MENU_BUTTON_COPY_MIN, FileSelectH.MENU_BUTTON_COPY_MAX - 1 do
			const buttonObject = file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object
			const buttonX = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosX)))
			const buttonY = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosY)))

			if file_select.check_clicked_button(buttonX, buttonY, 22.0) == IncludePRUltratypesH.TRUE then
				-- If menu button clicked, select it
				if buttonID == FileSelectH.MENU_BUTTON_COPY_RETURN or buttonID == FileSelectH.MENU_BUTTON_COPY_CHECK_SCORE or buttonID == FileSelectH.MENU_BUTTON_COPY_ERASE_FILE then
					if buffer.readi32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase) == FileSelectH.COPY_PHASE_MAIN then
						Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
						buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)
						file_select.sSelectedButtonID = S8(buttonID)
					end
				else
					-- Check if a file button is clicked to play a copy action
					if buffer.readi32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT and file_select.sMainMenuTimer >= file_select.ACTION_TIMER then
						file_select.copy_action_file_button(copyButton, buttonID)
					end
				end

				file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_SUBMENU

				break
			end
		end

		-- After copy is complete, return to main copy phase
		if buffer.readi32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase) == FileSelectH.COPY_PHASE_COPY_COMPLETE and file_select.sMainMenuTimer >= file_select.MAIN_RETURN_TIMER then
			buffer.writei32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.COPY_PHASE_MAIN)

			const selectedCopyButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_MIN + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(selectedCopyButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT)
		end
	end
end

-- from src/menu/file_select.c:render_erase_menu_buttons L897-951
function file_select.render_erase_menu_buttons(eraseButton: GroupsTypesHPlus3.Object)
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_A) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 311, -100, 0, -0x8000, 0)
	end

	const eraseFileAButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_A + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseFileAButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_B) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 311, -100, 0, -0x8000, 0)
	end

	const eraseFileBButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_B + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseFileBButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_C) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, 711, 0, -100, 0, -0x8000, 0)
	end

	const eraseFileCButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_C + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseFileCButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_D) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON, BehaviorIds.bhvMenuButton, -166, 0, -100, 0, -0x8000, 0)
	end

	const eraseFileDButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_FILE_D + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseFileDButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Return to main menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_RETURN + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_YELLOW_FILE_BUTTON, BehaviorIds.bhvMenuButton, 711, -388, -100, 0, -0x8000, 0)

	const eraseReturnButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_RETURN + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseReturnButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to score menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_CHECK_SCORE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_GREEN_SCORE_BUTTON, BehaviorIds.bhvMenuButton, 0, -388, -100, 0, -0x8000, 0)

	const eraseCheckScoreButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_CHECK_SCORE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseCheckScoreButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Switch to copy menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_COPY_FILE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(eraseButton, IncludeModelIdsH.MODEL_MAIN_MENU_BLUE_COPY_BUTTON, BehaviorIds.bhvMenuButton, -711, -388, -100, 0, -0x8000, 0)

	const eraseCopyButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_COPY_FILE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseCopyButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)
end

-- from src/menu/file_select.c:erase_action_file_button L956-1000
function file_select.erase_action_file_button(eraseButton: GroupsTypesHPlus3.Object, eraseFileButtonID: number)
	const phase = buffer.readi32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase)

	if phase == FileSelectH.ERASE_PHASE_MAIN then
		if SrcGameSaveFile.save_file_exists(eraseFileButtonID - FileSelectH.MENU_BUTTON_ERASE_MIN) == IncludePRUltratypesH.TRUE then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
			const erasedButton = file_select.sMainMenuButtons[eraseFileButtonID + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(erasedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN)
			file_select.sSelectedFileIndex = S8(eraseFileButtonID - FileSelectH.MENU_BUTTON_ERASE_MIN)
			buffer.writei32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.ERASE_PHASE_PROMPT)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
			file_select.sMainMenuTimer = 0
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
			const buzzedButton = file_select.sMainMenuButtons[eraseFileButtonID + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(buzzedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)

			if file_select.sMainMenuTimer >= file_select.BUZZ_TIMER then
				file_select.sFadeOutText = IncludePRUltratypesH.TRUE
				file_select.sMainMenuTimer = 0
			end
		end
	elseif phase == FileSelectH.ERASE_PHASE_PROMPT then
		if eraseFileButtonID == FileSelectH.MENU_BUTTON_ERASE_MIN + file_select.sSelectedFileIndex then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
			const promptedButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_MIN + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(promptedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT)
			buffer.writei32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.ERASE_PHASE_MAIN)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end
	end
end

-- from src/menu/file_select.c:check_erase_menu_clicked_buttons L1007-1046
function file_select.check_erase_menu_clicked_buttons(eraseButton: GroupsTypesHPlus3.Object)
	if buffer.readi32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		-- Configure erase menu button group
		for buttonID = FileSelectH.MENU_BUTTON_ERASE_MIN, FileSelectH.MENU_BUTTON_ERASE_MAX - 1 do
			const buttonObject = file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object
			const buttonX = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosX)))
			const buttonY = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosY)))

			if file_select.check_clicked_button(buttonX, buttonY, 22.0) == IncludePRUltratypesH.TRUE then
				-- If menu button clicked, select it
				if buttonID == FileSelectH.MENU_BUTTON_ERASE_RETURN or buttonID == FileSelectH.MENU_BUTTON_ERASE_CHECK_SCORE or buttonID == FileSelectH.MENU_BUTTON_ERASE_COPY_FILE then
					if buffer.readi32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase) == FileSelectH.ERASE_PHASE_MAIN then
						Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
						buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)
						file_select.sSelectedButtonID = S8(buttonID)
					end
				else
					-- Check if a file button is clicked to play an erase action
					if file_select.sMainMenuTimer >= file_select.ACTION_TIMER then
						file_select.erase_action_file_button(eraseButton, buttonID)
					end
				end

				file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_SUBMENU

				break
			end
		end

		-- After erase is complete, return to main erase phase
		if buffer.readi32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase) == FileSelectH.ERASE_PHASE_MARIO_ERASED and file_select.sMainMenuTimer >= file_select.MAIN_RETURN_TIMER then
			buffer.writei32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.ERASE_PHASE_MAIN)

			const selectedEraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_MIN + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(selectedEraseButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT)
		end
	end
end

-- from src/menu/file_select.c:render_sound_mode_menu_buttons L1060-1096
function file_select.render_sound_mode_menu_buttons(soundModeButton: GroupsTypesHPlus3.Object)
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_STEREO + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(soundModeButton, IncludeModelIdsH.MODEL_MAIN_MENU_GENERIC_BUTTON, BehaviorIds.bhvMenuButton, 533, file_select.SOUND_BUTTON_Y, -100, 0, -0x8000, 0)

	const stereoButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_STEREO + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(stereoButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_MONO + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(soundModeButton, IncludeModelIdsH.MODEL_MAIN_MENU_GENERIC_BUTTON, BehaviorIds.bhvMenuButton, 0, file_select.SOUND_BUTTON_Y, -100, 0, -0x8000, 0)

	const monoButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_MONO + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(monoButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_HEADSET + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(soundModeButton, IncludeModelIdsH.MODEL_MAIN_MENU_GENERIC_BUTTON, BehaviorIds.bhvMenuButton, -533, file_select.SOUND_BUTTON_Y, -100, 0, -0x8000, 0)

	const headsetButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_HEADSET + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(headsetButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 0.11111111)

	-- Zoom in current selection
	const selectedButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_OPTION_MIN + file_select.sSoundMode + 1] :: GroupsTypesHPlus3.Object

	buffer.writei32(selectedButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN)
end

-- from src/menu/file_select.c:check_sound_mode_menu_clicked_buttons L1103-1155
function file_select.check_sound_mode_menu_clicked_buttons(soundModeButton: GroupsTypesHPlus3.Object)
	if buffer.readi32(soundModeButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		-- Configure sound mode menu button group
		for buttonID = FileSelectH.MENU_BUTTON_OPTION_MIN, FileSelectH.MENU_BUTTON_OPTION_MAX - 1 do
			const buttonObject = file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object
			const buttonX = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosX)))
			const buttonY = S16(TruncS32(buffer.readf32(buttonObject.rawData, IncludeObjectFieldsH.oPosY)))

			if file_select.check_clicked_button(buttonX, buttonY, 22.0) == IncludePRUltratypesH.TRUE then
				-- If sound mode button clicked, select it and define sound mode
				-- The check will always be true because of the group configured above (In JP & US)
				if buttonID == FileSelectH.MENU_BUTTON_STEREO or buttonID == FileSelectH.MENU_BUTTON_MONO or buttonID == FileSelectH.MENU_BUTTON_HEADSET then
					if buffer.readi32(soundModeButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase) == FileSelectH.SOUND_MODE_PHASE_MAIN then
						Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
						buffer.writei32(buttonObject.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_IN_OUT)
						file_select.sSelectedButtonID = S8(buttonID)
						file_select.sSoundMode = S8(buttonID - FileSelectH.MENU_BUTTON_OPTION_MIN)
						SrcGameSaveFile.save_file_set_sound_mode(file_select.sSoundMode)
					end
				end

				file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_SUBMENU

				break
			end
		end
	end
end

-- from src/menu/file_select.c:load_main_menu_save_file L1161-1165
function file_select.load_main_menu_save_file(fileButton: GroupsTypesHPlus3.Object, fileNum: number)
	if buffer.readi32(fileButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		file_select.sSelectedFileNum = S8(fileNum)
	end
end

-- from src/menu/file_select.c:return_to_main_menu L1171-1206
function file_select.return_to_main_menu(prevMenuButtonID: number, sourceButton: GroupsTypesHPlus3.Object)
	prevMenuButtonID = S16(TruncS32(prevMenuButtonID))
	const prevButton = file_select.sMainMenuButtons[prevMenuButtonID + 1] :: GroupsTypesHPlus3.Object

	-- If the source button is in default state and the previous menu in full screen,
	-- play zoom out sound and shrink previous menu
	if buffer.readi32(sourceButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT and buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
		buffer.writei32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_SHRINKING)
		file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
	end

	-- If the previous button is in default state, return back to the main menu
	if buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_NONE

		-- Hide buttons of corresponding button menu groups
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_SCORE then
			for buttonID = FileSelectH.MENU_BUTTON_SCORE_MIN, FileSelectH.MENU_BUTTON_SCORE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_COPY then
			for buttonID = FileSelectH.MENU_BUTTON_COPY_MIN, FileSelectH.MENU_BUTTON_COPY_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_ERASE then
			for buttonID = FileSelectH.MENU_BUTTON_ERASE_MIN, FileSelectH.MENU_BUTTON_ERASE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_SOUND_MODE then
			for buttonID = FileSelectH.MENU_BUTTON_OPTION_MIN, FileSelectH.MENU_BUTTON_OPTION_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end
	end
end

-- from src/menu/file_select.c:load_score_menu_from_submenu L1211-1246
function file_select.load_score_menu_from_submenu(prevMenuButtonID: number, sourceButton: GroupsTypesHPlus3.Object)
	prevMenuButtonID = S16(TruncS32(prevMenuButtonID))
	const prevButton = file_select.sMainMenuButtons[prevMenuButtonID + 1] :: GroupsTypesHPlus3.Object

	-- If the source button is in default state and the previous menu in full screen,
	-- play zoom out sound and shrink previous menu
	if buffer.readi32(sourceButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT and buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
		buffer.writei32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_SHRINKING)
		file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
	end

	-- If the previous button is in default state
	if buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		-- Hide buttons of corresponding button menu groups
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_SCORE then
			for buttonID = FileSelectH.MENU_BUTTON_SCORE_MIN, FileSelectH.MENU_BUTTON_SCORE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_COPY then
			for buttonID = FileSelectH.MENU_BUTTON_COPY_MIN, FileSelectH.MENU_BUTTON_COPY_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_ERASE then
			for buttonID = FileSelectH.MENU_BUTTON_ERASE_MIN, FileSelectH.MENU_BUTTON_ERASE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		-- Play zoom in sound, select score menu and render it's buttons
		file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_SCORE
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		const scoreButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE + 1] :: GroupsTypesHPlus3.Object

		buffer.writei32(scoreButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
		file_select.render_score_menu_buttons(scoreButton)
	end
end

-- from src/menu/file_select.c:load_copy_menu_from_submenu L1251-1286
function file_select.load_copy_menu_from_submenu(prevMenuButtonID: number, sourceButton: GroupsTypesHPlus3.Object)
	prevMenuButtonID = S16(TruncS32(prevMenuButtonID))
	const prevButton = file_select.sMainMenuButtons[prevMenuButtonID + 1] :: GroupsTypesHPlus3.Object

	-- If the source button is in default state and the previous menu in full screen,
	-- play zoom out sound and shrink previous menu
	if buffer.readi32(sourceButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT and buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
		buffer.writei32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_SHRINKING)
		file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
	end

	-- If the previous button is in default state
	if buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		-- Hide buttons of corresponding button menu groups
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_SCORE then
			for buttonID = FileSelectH.MENU_BUTTON_SCORE_MIN, FileSelectH.MENU_BUTTON_SCORE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		-- Not possible, this is checking if the copy menu was opened from the copy menu!
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_COPY then
			for buttonID = FileSelectH.MENU_BUTTON_COPY_MIN, FileSelectH.MENU_BUTTON_COPY_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_ERASE then
			for buttonID = FileSelectH.MENU_BUTTON_ERASE_MIN, FileSelectH.MENU_BUTTON_ERASE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		-- Play zoom in sound, select copy menu and render it's buttons
		file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_COPY
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		const copyButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] :: GroupsTypesHPlus3.Object

		buffer.writei32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
		file_select.render_copy_menu_buttons(copyButton)
	end
end

-- from src/menu/file_select.c:load_erase_menu_from_submenu L1291-1326
function file_select.load_erase_menu_from_submenu(prevMenuButtonID: number, sourceButton: GroupsTypesHPlus3.Object)
	prevMenuButtonID = S16(TruncS32(prevMenuButtonID))
	const prevButton = file_select.sMainMenuButtons[prevMenuButtonID + 1] :: GroupsTypesHPlus3.Object

	-- If the source button is in default state and the previous menu in full screen,
	-- play zoom out sound and shrink previous menu
	if buffer.readi32(sourceButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT and buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_FULLSCREEN then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
		buffer.writei32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_SHRINKING)
		file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
	end

	-- If the previous button is in default state
	if buffer.readi32(prevButton.rawData, IncludeObjectFieldsH.oMenuButtonState) == FileSelectH.MENU_BUTTON_STATE_DEFAULT then
		-- Hide buttons of corresponding button menu groups
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_SCORE then
			for buttonID = FileSelectH.MENU_BUTTON_SCORE_MIN, FileSelectH.MENU_BUTTON_SCORE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		if prevMenuButtonID == FileSelectH.MENU_BUTTON_COPY then
			for buttonID = FileSelectH.MENU_BUTTON_COPY_MIN, FileSelectH.MENU_BUTTON_COPY_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		-- Not possible, this is checking if the erase menu was opened from the erase menu!
		if prevMenuButtonID == FileSelectH.MENU_BUTTON_ERASE then
			for buttonID = FileSelectH.MENU_BUTTON_ERASE_MIN, FileSelectH.MENU_BUTTON_ERASE_MAX - 1 do
				SrcGameSpawnObject.mark_obj_for_deletion(file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object)
			end
		end

		-- Play zoom in sound, select erase menu and render it's buttons
		file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_ERASE
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		const eraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object

		buffer.writei32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
		file_select.render_erase_menu_buttons(eraseButton)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_manager_init L1335-1395
function file_select.bhv_menu_button_manager_init()
	const o = SrcGameObjectListProcessor.gCurrentObject

	-- File A
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_A) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE, BehaviorIds.bhvMenuButton, -6400, 2800, 0, 0, 0, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_A + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE, BehaviorIds.bhvMenuButton, -6400, 2800, 0, 0, 0, 0)
	end

	const playFileAButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_A + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(playFileAButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- File B
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_B) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE, BehaviorIds.bhvMenuButton, 1500, 2800, 0, 0, 0, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_B + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE, BehaviorIds.bhvMenuButton, 1500, 2800, 0, 0, 0, 0)
	end

	const playFileBButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_B + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(playFileBButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- File C
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_C) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE, BehaviorIds.bhvMenuButton, -6400, 0, 0, 0, 0, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_C + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE, BehaviorIds.bhvMenuButton, -6400, 0, 0, 0, 0, 0)
	end

	const playFileCButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_C + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(playFileCButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- File D
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_D) == IncludePRUltratypesH.TRUE then
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_SAVE_BUTTON_FADE, BehaviorIds.bhvMenuButton, 1500, 0, 0, 0, 0, 0)
	else
		file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_D + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE, BehaviorIds.bhvMenuButton, 1500, 0, 0, 0, 0, 0)
	end

	const playFileDButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_D + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(playFileDButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- Score menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_GREEN_SCORE_BUTTON, BehaviorIds.bhvMenuButton, -6400, -3500, 0, 0, 0, 0)

	const scoreMenuButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(scoreMenuButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- Copy menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_BLUE_COPY_BUTTON, BehaviorIds.bhvMenuButton, -2134, -3500, 0, 0, 0, 0)

	const copyMenuButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(copyMenuButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- Erase menu button
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_RED_ERASE_BUTTON, BehaviorIds.bhvMenuButton, 2134, -3500, 0, 0, 0, 0)

	const eraseMenuButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(eraseMenuButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	-- Sound mode menu button (Option Mode in EU)
	file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SOUND_MODE + 1] = SrcGameObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_MAIN_MENU_PURPLE_SOUND_BUTTON, BehaviorIds.bhvMenuButton, 6400, -3500, 0, 0, 0, 0)

	const soundModeMenuButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SOUND_MODE + 1] :: GroupsTypesHPlus3.Object

	buffer.writef32(soundModeMenuButton.rawData, IncludeObjectFieldsH.oMenuButtonScale, 1.0)

	file_select.sTextBaseAlpha = 0
end

-- from src/menu/file_select.c:check_main_menu_clicked_buttons L1407-1505
function file_select.check_main_menu_clicked_buttons()
	const soundModeButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SOUND_MODE + 1] :: GroupsTypesHPlus3.Object

	-- Sound mode menu is handled separately because the button ID for it
	-- is not grouped with the IDs of the other submenus.
	if file_select.check_clicked_button(S16(TruncS32(buffer.readf32(soundModeButton.rawData, IncludeObjectFieldsH.oPosX))), S16(TruncS32(buffer.readf32(soundModeButton.rawData, IncludeObjectFieldsH.oPosY))), 200.0) == IncludePRUltratypesH.TRUE then
		buffer.writei32(soundModeButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
		file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_SOUND_MODE
	else
		-- Main Menu buttons
		-- Configure Main Menu button group
		for buttonID = FileSelectH.MENU_BUTTON_MAIN_MIN, FileSelectH.MENU_BUTTON_MAIN_MAX - 1 do
			const mainButton = file_select.sMainMenuButtons[buttonID + 1] :: GroupsTypesHPlus3.Object
			const buttonX = S16(TruncS32(buffer.readf32(mainButton.rawData, IncludeObjectFieldsH.oPosX)))
			const buttonY = S16(TruncS32(buffer.readf32(mainButton.rawData, IncludeObjectFieldsH.oPosY)))

			if file_select.check_clicked_button(buttonX, buttonY, 200.0) == IncludePRUltratypesH.TRUE then
				-- If menu button clicked, select it
				buffer.writei32(mainButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_GROWING)
				file_select.sSelectedButtonID = S8(buttonID)

				break
			end
		end
	end

	-- Play sound of the save file clicked
	if file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_A or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_B or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_C or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_D then
		Audio.play_sound(file_select.SAVE_FILE_SOUND, Audio.gGlobalSoundSource)
	elseif file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SCORE then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		file_select.render_score_menu_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE + 1] :: GroupsTypesHPlus3.Object)
	elseif file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_COPY then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		file_select.render_copy_menu_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] :: GroupsTypesHPlus3.Object)
	elseif file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_ERASE then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		file_select.render_erase_menu_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object)
	elseif file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SOUND_MODE then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
		file_select.render_sound_mode_menu_buttons(soundModeButton)
	end
end

-- from src/menu/file_select.c:bhv_menu_button_manager_loop L1515-1631
function file_select.bhv_menu_button_manager_loop()
	const selectedButtonID = file_select.sSelectedButtonID

	if selectedButtonID == FileSelectH.MENU_BUTTON_NONE then
		file_select.check_main_menu_clicked_buttons()
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_A then
		file_select.load_main_menu_save_file(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_A + 1] :: GroupsTypesHPlus3.Object, 1)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_B then
		file_select.load_main_menu_save_file(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_B + 1] :: GroupsTypesHPlus3.Object, 2)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_C then
		file_select.load_main_menu_save_file(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_C + 1] :: GroupsTypesHPlus3.Object, 3)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_PLAY_FILE_D then
		file_select.load_main_menu_save_file(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_PLAY_FILE_D + 1] :: GroupsTypesHPlus3.Object, 4)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE then
		file_select.check_score_menu_clicked_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_COPY then
		file_select.check_copy_menu_clicked_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_ERASE then
		file_select.check_erase_menu_clicked_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_A then
		file_select.exit_score_file_to_score_menu(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_A + 1] :: GroupsTypesHPlus3.Object, FileSelectH.MENU_BUTTON_SCORE)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_B then
		file_select.exit_score_file_to_score_menu(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_B + 1] :: GroupsTypesHPlus3.Object, FileSelectH.MENU_BUTTON_SCORE)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_C then
		file_select.exit_score_file_to_score_menu(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_C + 1] :: GroupsTypesHPlus3.Object, FileSelectH.MENU_BUTTON_SCORE)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_D then
		file_select.exit_score_file_to_score_menu(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_FILE_D + 1] :: GroupsTypesHPlus3.Object, FileSelectH.MENU_BUTTON_SCORE)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_RETURN then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_SCORE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_RETURN + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_COPY_FILE then
		file_select.load_copy_menu_from_submenu(FileSelectH.MENU_BUTTON_SCORE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_COPY_FILE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_ERASE_FILE then
		file_select.load_erase_menu_from_submenu(FileSelectH.MENU_BUTTON_SCORE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SCORE_ERASE_FILE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_COPY_RETURN then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_COPY, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_RETURN + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_COPY_CHECK_SCORE then
		file_select.load_score_menu_from_submenu(FileSelectH.MENU_BUTTON_COPY, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_CHECK_SCORE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_COPY_ERASE_FILE then
		file_select.load_erase_menu_from_submenu(FileSelectH.MENU_BUTTON_COPY, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY_ERASE_FILE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_ERASE_RETURN then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_ERASE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_RETURN + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_ERASE_CHECK_SCORE then
		file_select.load_score_menu_from_submenu(FileSelectH.MENU_BUTTON_ERASE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_CHECK_SCORE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_ERASE_COPY_FILE then
		file_select.load_copy_menu_from_submenu(FileSelectH.MENU_BUTTON_ERASE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_COPY_FILE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SOUND_MODE then
		file_select.check_sound_mode_menu_clicked_buttons(file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_SOUND_MODE + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_STEREO then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_SOUND_MODE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_STEREO + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_MONO then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_SOUND_MODE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_MONO + 1] :: GroupsTypesHPlus3.Object)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_HEADSET then
		file_select.return_to_main_menu(FileSelectH.MENU_BUTTON_SOUND_MODE, file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_HEADSET + 1] :: GroupsTypesHPlus3.Object)
	end

	file_select.sClickPos[1] = -10000
	file_select.sClickPos[2] = -10000
end

-- from src/menu/file_select.c:handle_cursor_button_input L1637-1673
function file_select.handle_cursor_button_input()
	if file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_A or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_B or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_C or file_select.sSelectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_D then
		-- If scoring a file, pressing A just changes the coin score mode.
		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(IncludePROsH.B_BUTTON, IncludePROsH.START_BUTTON)) then
			file_select.sClickPos[1] = S16(TruncS32(file_select.sCursorPos[1]))
			file_select.sClickPos[2] = S16(TruncS32(file_select.sCursorPos[2]))
			file_select.sCursorClickingTimer = 1
		elseif bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, IncludePROsH.A_BUTTON) then
			file_select.sScoreFileCoinScoreMode = S8(1 - file_select.sScoreFileCoinScoreMode)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
		end
	else
		-- If cursor is clicked
		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(IncludePROsH.A_BUTTON, IncludePROsH.B_BUTTON, IncludePROsH.START_BUTTON)) then
			file_select.sClickPos[1] = S16(TruncS32(file_select.sCursorPos[1]))
			file_select.sClickPos[2] = S16(TruncS32(file_select.sCursorPos[2]))
			file_select.sCursorClickingTimer = 1
		end
	end
end

-- from src/menu/file_select.c:handle_controller_cursor_input L1678-1712
function file_select.handle_controller_cursor_input()
	local rawStickX = SrcGameGameInit.gPlayer3Controller.rawStickX
	local rawStickY = SrcGameGameInit.gPlayer3Controller.rawStickY

	-- Handle deadzone
	if rawStickY > -2 and rawStickY < 2 then
		rawStickY = 0
	end

	if rawStickX > -2 and rawStickX < 2 then
		rawStickX = 0
	end

	-- Move cursor
	file_select.sCursorPos[1] = F32(file_select.sCursorPos[1] + TruncS32(rawStickX / 8))
	file_select.sCursorPos[2] = F32(file_select.sCursorPos[2] + TruncS32(rawStickY / 8))

	-- Stop cursor from going offscreen
	if file_select.sCursorPos[1] > 132.0 then
		file_select.sCursorPos[1] = 132.0
	end

	if file_select.sCursorPos[1] < -132.0 then
		file_select.sCursorPos[1] = -132.0
	end

	if file_select.sCursorPos[2] > 90.0 then
		file_select.sCursorPos[2] = 90.0
	end

	if file_select.sCursorPos[2] < -90.0 then
		file_select.sCursorPos[2] = -90.0
	end

	if file_select.sCursorClickingTimer == 0 then
		file_select.handle_cursor_button_input()
	end
end

-- from src/menu/file_select.c:print_menu_cursor L1719-1739
function file_select.print_menu_cursor()
	file_select.handle_controller_cursor_input()
	GroupsIngameMenuPlus1.create_dl_translation_matrix(GroupsIngameMenuPlus1.MENU_MTX_PUSH, F32(F32(file_select.sCursorPos[1] + 160.0) - 5.0), F32(F32(file_select.sCursorPos[2] + 120.0) - 25.0), 0.0)

	-- Get the right graphic to use for the cursor.
	if file_select.sCursorClickingTimer == 0 then
		-- Idle
		Gbi.gSPDisplayList(MenuSymbols.dl_menu_idle_hand)
	end

	if file_select.sCursorClickingTimer ~= 0 then
		-- Grabbing
		Gbi.gSPDisplayList(MenuSymbols.dl_menu_grabbing_hand)
	end

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	if file_select.sCursorClickingTimer ~= 0 then
		file_select.sCursorClickingTimer = S16(file_select.sCursorClickingTimer + 1)

		if file_select.sCursorClickingTimer == 5 then
			file_select.sCursorClickingTimer = 0
		end
	end
end

-- from src/menu/file_select.c:print_hud_lut_string_fade L1744-1749
function file_select.print_hud_lut_string_fade(hudLUT: number, x: number, y: number, text: buffer)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha - file_select.sTextFadeAlpha)
	GroupsIngameMenuPlus1.print_hud_lut_string(hudLUT, x, y, text)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)
end

-- from src/menu/file_select.c:print_generic_string_fade L1754-1759
function file_select.print_generic_string_fade(x: number, y: number, text: buffer)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha - file_select.sTextFadeAlpha)
	GroupsIngameMenuPlus1.print_generic_string(x, y, text)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/menu/file_select.c:update_text_fade_out L1764-1777
function file_select.update_text_fade_out(): number
	if file_select.sFadeOutText == IncludePRUltratypesH.TRUE then
		file_select.sTextFadeAlpha = U8(file_select.sTextFadeAlpha + 50)

		if file_select.sTextFadeAlpha == 250 then
			file_select.sFadeOutText = IncludePRUltratypesH.FALSE

			return IncludePRUltratypesH.TRUE
		end
	else
		if file_select.sTextFadeAlpha > 0 then
			file_select.sTextFadeAlpha = U8(file_select.sTextFadeAlpha - 50)
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/menu/file_select.c:print_save_file_star_count L1783-1809
function file_select.print_save_file_star_count(fileIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local offset = 0

	if SrcGameSaveFile.save_file_exists(fileIndex) == IncludePRUltratypesH.TRUE then
		const starCount = S16(SrcGameSaveFile.save_file_get_total_star_count(fileIndex, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1))

		-- Print star icon
		GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, x, y, file_select.starIcon)

		-- If star count is less than 100, print x icon and move
		-- the star count text one digit to the right.
		if starCount < 100 then
			GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, x + 16, y, file_select.xIcon)
			offset = 16
		end

		-- Print star count
		GroupsIngameMenuPlus1.int_to_str(starCount, Scratch.print_save_file_star_count_starCountText)
		GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, x + (offset + 16), y, Scratch.print_save_file_star_count_starCountText)
	else
		-- Print "new" text
		GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, x, y, file_select.textNew)
	end
end

-- from src/menu/file_select.c:print_main_menu_strings L1870-1909
function file_select.print_main_menu_strings()
	-- Print "SELECT FILE" text
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_DIFF2, file_select.SELECT_FILE_X, file_select.SELECT_FILE_Y, file_select.textSelectFile)

	-- Print file star counts
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_A, file_select.SAVEFILE_X1, 78)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_B, file_select.SAVEFILE_X2, 78)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_C, file_select.SAVEFILE_X1, 118)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_D, file_select.SAVEFILE_X2, 118)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print menu names
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(file_select.SCORE_X, 39, file_select.textScore)
	GroupsIngameMenuPlus1.print_generic_string(file_select.COPY_X, 39, file_select.textCopy)
	GroupsIngameMenuPlus1.print_generic_string(file_select.ERASE_X, 39, file_select.textErase)
	file_select.sSoundTextX = GroupsIngameMenuPlus1.get_str_x_pos_from_center(254, file_select.textSoundModes[file_select.sSoundMode + 1], 10.0)
	GroupsIngameMenuPlus1.print_generic_string(file_select.sSoundTextX, 39, file_select.textSoundModes[file_select.sSoundMode + 1])
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	-- Print file names
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_BEGIN)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.FILE_SELECT_PRINT_STRING(file_select.MARIOTEXT_X1, file_select.MARIOTEXT_Y1, file_select.textMarioA)
	file_select.FILE_SELECT_PRINT_STRING(file_select.MARIOTEXT_X2, file_select.MARIOTEXT_Y1, file_select.textMarioB)
	file_select.FILE_SELECT_PRINT_STRING(file_select.MARIOTEXT_X1, file_select.MARIOTEXT_Y2, file_select.textMarioC)
	file_select.FILE_SELECT_PRINT_STRING(file_select.MARIOTEXT_X2, file_select.MARIOTEXT_Y2, file_select.textMarioD)
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_END)
end

-- from src/menu/file_select.c:score_menu_display_message L1965-1984
function file_select.score_menu_display_message(messageID: number)
	messageID = S8(TruncS32(messageID))

	if messageID == FileSelectH.SCORE_MSG_CHECK_FILE then
		file_select.print_hud_lut_string_fade(GroupsIngameMenuPlus1.HUD_LUT_DIFF, file_select.CHECK_FILE_X, file_select.CHECK_FILE_Y, file_select.textCheckFile)
	elseif messageID == FileSelectH.SCORE_MSG_NOSAVE_DATA then
		file_select.print_generic_string_fade(file_select.NOSAVE_DATA_X1, 190, file_select.textNoSavedDataExists)
	end
end

-- from src/menu/file_select.c:print_score_menu_strings L2025-2084
function file_select.print_score_menu_strings()
	-- Update and print the message at the top of the menu.
	if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER then
		file_select.sFadeOutText = IncludePRUltratypesH.TRUE
	end

	if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
		if file_select.sStatusMessageID == FileSelectH.SCORE_MSG_CHECK_FILE then
			file_select.sStatusMessageID = FileSelectH.SCORE_MSG_NOSAVE_DATA
		else
			file_select.sStatusMessageID = FileSelectH.SCORE_MSG_CHECK_FILE
		end
	end

	-- Print messageID called above
	file_select.score_menu_display_message(file_select.sStatusMessageID)

	-- Print file star counts
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_A, 90, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_B, 211, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_C, 90, 119)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_D, 211, 119)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print menu names
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(file_select.RETURN_X, 35, file_select.textReturn)
	GroupsIngameMenuPlus1.print_generic_string(file_select.COPYFILE_X1, 35, file_select.textCopyFileButton)
	GroupsIngameMenuPlus1.print_generic_string(file_select.ERASEFILE_X1, 35, file_select.textEraseFileButton)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	-- Print file names
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_BEGIN)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.SCORE_FILE_Y1, file_select.textMarioA)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.SCORE_FILE_Y1, file_select.textMarioB)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.SCORE_FILE_Y2, file_select.textMarioC)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.SCORE_FILE_Y2, file_select.textMarioD)
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_END)
end

-- from src/menu/file_select.c:copy_menu_display_message L2123-2169
function file_select.copy_menu_display_message(messageID: number)
	messageID = S8(TruncS32(messageID))

	if messageID == FileSelectH.COPY_MSG_MAIN_TEXT then
		if file_select.sAllFilesExist == IncludePRUltratypesH.TRUE then
			file_select.print_generic_string_fade(file_select.NOFILE_COPY_X, 190, file_select.textNoFileToCopyFrom)
		else
			file_select.print_hud_lut_string_fade(GroupsIngameMenuPlus1.HUD_LUT_DIFF, file_select.COPY_FILE_X, file_select.COPY_FILE_Y, file_select.textCopyFile)
		end
	elseif messageID == FileSelectH.COPY_MSG_COPY_WHERE then
		file_select.print_generic_string_fade(file_select.COPYIT_WHERE_X, 190, file_select.textCopyItToWhere)
	elseif messageID == FileSelectH.COPY_MSG_NOSAVE_EXISTS then
		file_select.print_generic_string_fade(file_select.NOSAVE_DATA_X2, 190, file_select.textNoSavedDataExistsCopy)
	elseif messageID == FileSelectH.COPY_MSG_COPY_COMPLETE then
		file_select.print_generic_string_fade(file_select.COPYCOMPLETE_X, 190, file_select.textCopyCompleted)
	elseif messageID == FileSelectH.COPY_MSG_SAVE_EXISTS then
		file_select.print_generic_string_fade(file_select.SAVE_EXISTS_X1, 190, file_select.textSavedDataExists)
	end
end

-- from src/menu/file_select.c:copy_menu_update_message L2174-2214
function file_select.copy_menu_update_message()
	const copyButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_COPY + 1] :: GroupsTypesHPlus3.Object
	const phase = buffer.readi32(copyButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase)

	if phase == FileSelectH.COPY_PHASE_MAIN then
		if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER then
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end

		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID == FileSelectH.COPY_MSG_MAIN_TEXT then
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_NOSAVE_EXISTS
			else
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_MAIN_TEXT
			end
		end
	elseif phase == FileSelectH.COPY_PHASE_COPY_WHERE then
		if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER and file_select.sStatusMessageID == FileSelectH.COPY_MSG_SAVE_EXISTS then
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end

		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID ~= FileSelectH.COPY_MSG_COPY_WHERE then
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_COPY_WHERE
			else
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_SAVE_EXISTS
			end
		end
	elseif phase == FileSelectH.COPY_PHASE_COPY_COMPLETE then
		if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER then
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end

		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID ~= FileSelectH.COPY_MSG_COPY_COMPLETE then
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_COPY_COMPLETE
			else
				file_select.sStatusMessageID = FileSelectH.COPY_MSG_MAIN_TEXT
			end
		end
	end
end

-- from src/menu/file_select.c:print_copy_menu_strings L2244-2292
function file_select.print_copy_menu_strings()
	file_select.copy_menu_update_message()

	-- Print messageID called inside a copy_menu_update_message case
	file_select.copy_menu_display_message(file_select.sStatusMessageID)

	-- Print file star counts
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_A, 90, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_B, 211, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_C, 90, 119)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_D, 211, 119)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print menu names
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(file_select.RETURN_X, 35, file_select.textReturn)
	GroupsIngameMenuPlus1.print_generic_string(file_select.VIEWSCORE_X1, 35, file_select.textViewScore)
	GroupsIngameMenuPlus1.print_generic_string(file_select.ERASEFILE_X2, 35, file_select.textEraseFileButton)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	-- Print file names
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_BEGIN)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.COPY_FILE_Y1, file_select.textMarioA)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.COPY_FILE_Y1, file_select.textMarioB)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.COPY_FILE_Y2, file_select.textMarioC)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.COPY_FILE_Y2, file_select.textMarioD)
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_END)
end

-- from src/menu/file_select.c:print_erase_menu_prompt L2335-2409
function file_select.print_erase_menu_prompt(x: number, y: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	const colorTransTimer = S16(bit32.lshift(SrcGameGameInit.gGlobalTimer, 12))
	const cursorX = S16(TruncS32(F32(file_select.sCursorPos[1] + (x + 70))))
	const cursorY = S16(TruncS32(F32(file_select.sCursorPos[2] + 120.0)))

	if cursorX < file_select.MENU_ERASE_YES_MAX_X and cursorX >= file_select.MENU_ERASE_YES_MIN_X and cursorY < file_select.MENU_ERASE_YES_NO_MAX_Y and cursorY >= file_select.MENU_ERASE_YES_NO_MIN_Y then
		-- Fade "YES" string color but keep "NO" gray
		buffer.writeu8(file_select.sYesNoColor, 0, U8(TruncS32(F32(F32(SrcEngineMathUtilH.sins(colorTransTimer) * 50.0) + 205.0))))
		buffer.writeu8(file_select.sYesNoColor, 1, 150)
		file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_YES
	elseif cursorX < file_select.MENU_ERASE_NO_MAX_X and cursorX >= file_select.MENU_ERASE_NO_MIN_X and cursorY < file_select.MENU_ERASE_YES_NO_MAX_Y and cursorY >= file_select.MENU_ERASE_YES_NO_MIN_Y then
		-- Fade "NO" string color but keep "YES" gray
		buffer.writeu8(file_select.sYesNoColor, 0, 150)
		buffer.writeu8(file_select.sYesNoColor, 1, U8(TruncS32(F32(F32(SrcEngineMathUtilH.sins(colorTransTimer) * 50.0) + 205.0))))
		file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NO
	else
		-- Don't fade both strings and keep them gray
		buffer.writeu8(file_select.sYesNoColor, 0, 150)
		buffer.writeu8(file_select.sYesNoColor, 1, 150)
		file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NONE
	end

	-- If the cursor is clicked...
	if file_select.sCursorClickingTimer == 2 then
		-- ..and is hovering "YES", delete file
		if file_select.sEraseYesNoHoverState == FileSelectH.MENU_ERASE_HOVER_YES then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, Audio.gGlobalSoundSource)
			const eraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.ERASE_PHASE_MARIO_ERASED)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
			file_select.sMainMenuTimer = 0
			SrcGameSaveFile.save_file_erase(file_select.sSelectedFileIndex)

			const erasedButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_MIN + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			erasedButton.header.gfx.sharedChild = SrcGameArea.gLoadedGraphNodes[IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE + 1]

			const selectedButton = file_select.sMainMenuButtons[file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			selectedButton.header.gfx.sharedChild = SrcGameArea.gLoadedGraphNodes[IncludeModelIdsH.MODEL_MAIN_MENU_MARIO_NEW_BUTTON_FADE + 1]
			file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NONE
			-- ..and is hovering "NO", return back to main phase
		elseif file_select.sEraseYesNoHoverState == FileSelectH.MENU_ERASE_HOVER_NO then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_FILE_SELECT, Audio.gGlobalSoundSource)
			const noButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE_MIN + file_select.sSelectedFileIndex + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(noButton.rawData, IncludeObjectFieldsH.oMenuButtonState, FileSelectH.MENU_BUTTON_STATE_ZOOM_OUT)

			const mainEraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object

			buffer.writei32(mainEraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase, FileSelectH.ERASE_PHASE_MAIN)
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
			file_select.sMainMenuTimer = 0
			file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NONE
		end
	end

	-- Print "YES NO" strings
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(buffer.readu8(file_select.sYesNoColor, 0), buffer.readu8(file_select.sYesNoColor, 0), buffer.readu8(file_select.sYesNoColor, 0), file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(x + file_select.MENU_ERASE_YES_X_OFFSET, y, file_select.textYes)
	Gbi.gDPSetEnvColor(buffer.readu8(file_select.sYesNoColor, 1), buffer.readu8(file_select.sYesNoColor, 1), buffer.readu8(file_select.sYesNoColor, 1), file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(x + 98, y, file_select.textNo)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/menu/file_select.c:erase_menu_display_message L2452-2496
function file_select.erase_menu_display_message(messageID: number)
	messageID = S8(TruncS32(messageID))

	if messageID == FileSelectH.ERASE_MSG_MAIN_TEXT then
		file_select.print_hud_lut_string_fade(GroupsIngameMenuPlus1.HUD_LUT_DIFF, file_select.ERASE_FILE_X, file_select.ERASE_FILE_Y, IncludeTextStringsH.TEXT_ERASE_FILE)
	elseif messageID == FileSelectH.ERASE_MSG_PROMPT then
		file_select.print_generic_string_fade(90, 190, IncludeTextStringsH.TEXT_SURE)
		file_select.print_erase_menu_prompt(90, 190) -- YES NO, has functions for it too
	elseif messageID == FileSelectH.ERASE_MSG_NOSAVE_EXISTS then
		file_select.print_generic_string_fade(file_select.NOSAVE_DATA_X3, 190, IncludeTextStringsH.TEXT_NO_SAVED_DATA_EXISTS)
	elseif messageID == FileSelectH.ERASE_MSG_MARIO_ERASED then
		buffer.writeu8(Scratch.erase_menu_display_message_textMarioAJustErased, file_select.MARIO_ERASED_VAR, U8(file_select.sSelectedFileIndex + 10))
		file_select.print_generic_string_fade(file_select.MARIO_ERASED_X, 190, Scratch.erase_menu_display_message_textMarioAJustErased)
	elseif messageID == FileSelectH.ERASE_MSG_SAVE_EXISTS then -- unused
		file_select.print_generic_string_fade(file_select.SAVE_EXISTS_X2, 190, IncludeTextStringsH.TEXT_SAVED_DATA_EXISTS)
	end
end

-- from src/menu/file_select.c:erase_menu_update_message L2501-2538
function file_select.erase_menu_update_message()
	const eraseButton = file_select.sMainMenuButtons[FileSelectH.MENU_BUTTON_ERASE + 1] :: GroupsTypesHPlus3.Object
	const phase = buffer.readi32(eraseButton.rawData, IncludeObjectFieldsH.oMenuButtonActionPhase)

	if phase == FileSelectH.ERASE_PHASE_MAIN then
		if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER and file_select.sStatusMessageID == FileSelectH.ERASE_MSG_NOSAVE_EXISTS then
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end

		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID == FileSelectH.ERASE_MSG_MAIN_TEXT then
				file_select.sStatusMessageID = FileSelectH.ERASE_MSG_NOSAVE_EXISTS
			else
				file_select.sStatusMessageID = FileSelectH.ERASE_MSG_MAIN_TEXT
			end
		end
	elseif phase == FileSelectH.ERASE_PHASE_PROMPT then
		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID ~= FileSelectH.ERASE_MSG_PROMPT then
				file_select.sStatusMessageID = FileSelectH.ERASE_MSG_PROMPT
			end

			file_select.sCursorPos[1] = 43.0
			file_select.sCursorPos[2] = 80.0
		end
	elseif phase == FileSelectH.ERASE_PHASE_MARIO_ERASED then
		if file_select.sMainMenuTimer == file_select.FADEOUT_TIMER then
			file_select.sFadeOutText = IncludePRUltratypesH.TRUE
		end

		if file_select.update_text_fade_out() == IncludePRUltratypesH.TRUE then
			if file_select.sStatusMessageID ~= FileSelectH.ERASE_MSG_MARIO_ERASED then
				file_select.sStatusMessageID = FileSelectH.ERASE_MSG_MARIO_ERASED
			else
				file_select.sStatusMessageID = FileSelectH.ERASE_MSG_MAIN_TEXT
			end
		end
	end
end

-- from src/menu/file_select.c:print_erase_menu_strings L2560-2612
function file_select.print_erase_menu_strings()
	file_select.erase_menu_update_message()

	-- Print messageID called inside a erase_menu_update_message case
	file_select.erase_menu_display_message(file_select.sStatusMessageID)

	-- Print file star counts
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_A, 90, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_B, 211, 76)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_C, 90, 119)
	file_select.print_save_file_star_count(SrcGameSaveFileH.SAVE_FILE_D, 211, 119)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print menu names
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_generic_string(file_select.RETURN_X_OLD, 35, file_select.textReturn)
	GroupsIngameMenuPlus1.print_generic_string(file_select.VIEWSCORE_X2, 35, file_select.textViewScore)
	GroupsIngameMenuPlus1.print_generic_string(file_select.COPYFILE_X2, 35, file_select.textCopyFileButton)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	-- Print file names
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_BEGIN)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.ERASE_FILE_Y1, file_select.textMarioA)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.ERASE_FILE_Y1, file_select.textMarioB)
	file_select.FILE_SELECT_PRINT_STRING(89, file_select.ERASE_FILE_Y2, file_select.textMarioC)
	file_select.FILE_SELECT_PRINT_STRING(211, file_select.ERASE_FILE_Y2, file_select.textMarioD)
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_END)
end

-- from src/menu/file_select.c:print_sound_mode_menu_strings L2630-2706
function file_select.print_sound_mode_menu_strings()
	-- Print "SOUND SELECT" text
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_DIFF, file_select.SOUND_HUD_X, file_select.SOUND_HUD_Y, IncludeTextStringsH.TEXT_SOUND_SELECT)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

	-- Print sound mode names
	for mode = 0, 2 do
		if file_select.sSoundMode == mode then
			Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
		else
			Gbi.gDPSetEnvColor(0, 0, 0, file_select.sTextBaseAlpha)
		end

		-- Mode names are centered correctly on US and Shindou
		const textX = GroupsIngameMenuPlus1.get_str_x_pos_from_center(mode * 74 + 87, file_select.textSoundModes[mode + 1], 10.0)

		GroupsIngameMenuPlus1.print_generic_string(textX, 87, file_select.textSoundModes[mode + 1])
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/menu/file_select.c:print_score_file_castle_secret_stars L2715-2735
function file_select.print_score_file_castle_secret_stars(fileIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))

	-- Print "[star] x"
	file_select.FILE_SELECT_PRINT_STRING(x, y, file_select.textStarX)

	-- Print number of castle secret stars
	GroupsIngameMenuPlus1.INT_TO_STR_DIFF(SrcGameSaveFile.save_file_get_total_star_count(fileIndex, IncludeCourseTableH.COURSE_BONUS_STAGES - 1, IncludeCourseTableH.COURSE_MAX - 1), Scratch.print_score_file_castle_secret_stars_secretStarsText)
	file_select.FILE_SELECT_PRINT_STRING(x + 16, y, Scratch.print_score_file_castle_secret_stars_secretStarsText)
end

-- from src/menu/file_select.c:print_score_file_course_coin_score L2750-2801
function file_select.print_score_file_course_coin_score(fileIndex: number, courseIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	courseIndex = S16(TruncS32(courseIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	const stars = U8(SrcGameSaveFile.save_file_get_star_flags(fileIndex, courseIndex))

	-- MYSCORE
	if file_select.sScoreFileCoinScoreMode == 0 then
		-- Print "[coin] x"
		file_select.FILE_SELECT_PRINT_STRING(x + 25, y, IncludeTextStringsH.TEXT_COIN_X)

		-- Print coin score
		GroupsIngameMenuPlus1.INT_TO_STR_DIFF(SrcGameSaveFile.save_file_get_course_coin_score(fileIndex, courseIndex), Scratch.print_score_file_course_coin_score_coinScoreText)
		file_select.FILE_SELECT_PRINT_STRING(x + 41, y, Scratch.print_score_file_course_coin_score_coinScoreText)

		-- If collected, print 100 coin star
		if bit32.btest(stars, bit32.lshift(1, 6)) then
			file_select.FILE_SELECT_PRINT_STRING(x + 70, y, IncludeTextStringsH.TEXT_STAR)
		end
	else
		-- HISCORE
		-- Print "[coin] x"
		file_select.FILE_SELECT_PRINT_STRING(x + file_select.HISCORE_COIN_ICON_X, y, IncludeTextStringsH.TEXT_COIN_X)

		-- Print coin highscore
		GroupsIngameMenuPlus1.INT_TO_STR_DIFF(bit32.band(U16(SrcGameSaveFile.save_file_get_max_coin_score(courseIndex)), 0xFFFF), Scratch.print_score_file_course_coin_score_coinScoreText)
		file_select.FILE_SELECT_PRINT_STRING(x + file_select.HISCORE_COIN_TEXT_X, y, Scratch.print_score_file_course_coin_score_coinScoreText)

		-- Print coin highscore file
		file_select.FILE_SELECT_PRINT_STRING(x + file_select.HISCORE_COIN_NAMES_X, y, file_select.fileNames[bit32.band(bit32.rshift(SrcGameSaveFile.save_file_get_max_coin_score(courseIndex), 16), 0xFFFF) + 1])
	end
end

-- from src/menu/file_select.c:print_score_file_star_score L2806-2840
function file_select.print_score_file_star_score(fileIndex: number, courseIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	courseIndex = S16(TruncS32(courseIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local i = 0
	const stars = U8(SrcGameSaveFile.save_file_get_star_flags(fileIndex, courseIndex))
	local starCount = S8(SrcGameSaveFile.save_file_get_course_star_count(fileIndex, courseIndex))

	-- Don't count 100 coin star
	if bit32.btest(stars, bit32.lshift(1, 6)) then
		starCount = S8(starCount - 1)
	end

	-- Add 1 star character for every star collected
	while i < starCount do
		buffer.writeu8(Scratch.print_score_file_star_score_starScoreText, i, GroupsIngameMenuPlus1.DIALOG_CHAR_STAR_FILLED)
		i = S16(i + 1)
	end

	-- Terminating byte
	buffer.writeu8(Scratch.print_score_file_star_score_starScoreText, i, GroupsIngameMenuPlus1.DIALOG_CHAR_TERMINATOR)
	file_select.FILE_SELECT_PRINT_STRING(x, y, Scratch.print_score_file_star_score_starScoreText)
end

-- from src/menu/file_select.c:PRINT_COURSE_NAME_CN L2893-2895
function file_select.PRINT_COURSE_NAME_CN(courseIndex: number, shift: number)
	error("stale")
	return
end

-- from src/menu/file_select.c:PRINT_COURSE_SCORES_CN L2897-2899
function file_select.PRINT_COURSE_SCORES_CN(courseIndex: number, shift: number)
	error("stale")
	return
end

-- from src/menu/file_select.c:PRINT_COURSE_NAME_AND_SCORES L2901-2905 (a macro of print_save_file_scores, whose fileIndex and levelNameTable it reads)
function file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex: number, levelNameTable: number, courseIndex: number, pad: number)
	GroupsIngameMenuPlus1.CopyRomString(Scratch.PRINT_COURSE_NAME_AND_SCORES_courseName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(levelNameTable + 4 * (courseIndex - 1))))
	file_select.FILE_SELECT_PRINT_STRING(file_select.LEVEL_NAME_X + pad * file_select.LEVEL_NUM_PAD, 23 + 12 * courseIndex, Scratch.PRINT_COURSE_NAME_AND_SCORES_courseName)
	file_select.print_score_file_star_score(fileIndex, courseIndex - 1, file_select.STAR_SCORE_X, 23 + 12 * courseIndex)
	file_select.print_score_file_course_coin_score(fileIndex, courseIndex - 1, 213, 23 + 12 * courseIndex)
end

-- from src/menu/file_select.c:print_save_file_scores L2910-3045
function file_select.print_save_file_scores(fileIndex: number)
	fileIndex = S8(TruncS32(fileIndex))
	const textFileLetter = Scratch.print_save_file_scores_textFileLetter
	const levelNameTable = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_course_name_table)

	-- get letter of file selected
	buffer.writeu8(textFileLetter, 0, U8(fileIndex + GroupsIngameMenuPlus1.ASCII_TO_DIALOG(65)))

	-- Print file name at top
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)
	GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_DIFF, file_select.MARIO_X, file_select.MARIO_Y, IncludeTextStringsH.TEXT_MARIO)
	GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, file_select.FILE_LETTER_X, 15, textFileLetter)

	-- Print save file star count at top
	file_select.print_save_file_star_count(fileIndex, 124, 15)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print course scores
	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_BEGIN)
	Gbi.gDPSetEnvColor(255, 255, 255, file_select.sTextBaseAlpha)

	--! Huge print list, for loops exist for a reason!
	-- Course values are indexed, from Bob-omb Battlefield to Rainbow Ride
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_BOB, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_WF, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_JRB, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_CCM, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_BBH, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_HMC, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_LLL, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_SSL, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_DDD, 1)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_SL, 0)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_WDW, 0)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_TTM, 0)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_THI, 0)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_TTC, 0)
	file_select.PRINT_COURSE_NAME_AND_SCORES(fileIndex, levelNameTable, IncludeCourseTableH.COURSE_RR, 0)

	-- Print castle secret stars text
	GroupsIngameMenuPlus1.CopyRomString(Scratch.PRINT_COURSE_NAME_AND_SCORES_courseName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(levelNameTable + 4 * 25)))
	file_select.FILE_SELECT_PRINT_STRING(file_select.LEVEL_NAME_X + file_select.SECRET_STARS_PAD, 23 + 12 * 16, Scratch.PRINT_COURSE_NAME_AND_SCORES_courseName)

	-- Print castle secret stars score
	file_select.print_score_file_castle_secret_stars(fileIndex, file_select.STAR_SCORE_X, 23 + 12 * 16)

	-- Print current coin score mode
	if file_select.sScoreFileCoinScoreMode == 0 then
		file_select.FILE_SELECT_PRINT_STRING(file_select.MYSCORE_X, file_select.MYSCORE_Y, IncludeTextStringsH.TEXT_MY_SCORE)
	else
		file_select.FILE_SELECT_PRINT_STRING(file_select.HISCORE_X, file_select.HISCORE_Y, IncludeTextStringsH.TEXT_HI_SCORE)
	end

	Gbi.gSPDisplayList(file_select.FILE_SELECT_TEXT_DL_END)
end

-- from src/menu/file_select.c:print_file_select_strings L3055-3110
function file_select.print_file_select_strings()
	GroupsIngameMenuPlus1.create_dl_ortho_matrix()

	const selectedButtonID = file_select.sSelectedButtonID

	if selectedButtonID == FileSelectH.MENU_BUTTON_NONE then
		file_select.print_main_menu_strings()
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE then
		file_select.print_score_menu_strings()
		file_select.sScoreFileCoinScoreMode = 0
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_COPY then
		file_select.print_copy_menu_strings()
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_ERASE then
		file_select.print_erase_menu_strings()
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_A then
		file_select.print_save_file_scores(SrcGameSaveFileH.SAVE_FILE_A)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_B then
		file_select.print_save_file_scores(SrcGameSaveFileH.SAVE_FILE_B)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_C then
		file_select.print_save_file_scores(SrcGameSaveFileH.SAVE_FILE_C)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SCORE_FILE_D then
		file_select.print_save_file_scores(SrcGameSaveFileH.SAVE_FILE_D)
	elseif selectedButtonID == FileSelectH.MENU_BUTTON_SOUND_MODE then
		file_select.print_sound_mode_menu_strings()
	end

	-- If all 4 save file exists, define true to sAllFilesExist to prevent more copies in copy menu
	if SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_A) == IncludePRUltratypesH.TRUE and SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_B) == IncludePRUltratypesH.TRUE and SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_C) == IncludePRUltratypesH.TRUE and SrcGameSaveFile.save_file_exists(SrcGameSaveFileH.SAVE_FILE_D) == IncludePRUltratypesH.TRUE then
		file_select.sAllFilesExist = IncludePRUltratypesH.TRUE
	else
		file_select.sAllFilesExist = IncludePRUltratypesH.FALSE
	end

	-- Timers for menu alpha text and the main menu itself
	if file_select.sTextBaseAlpha < 250 then
		file_select.sTextBaseAlpha = U8(file_select.sTextBaseAlpha + 10)
	end

	if file_select.sMainMenuTimer < 1000 then
		file_select.sMainMenuTimer = S16(file_select.sMainMenuTimer + 1)
	end
end

-- from src/menu/file_select.c:geo_file_select_strings_and_menu_cursor L3115-3121
function file_select.geo_file_select_strings_and_menu_cursor(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		file_select.print_file_select_strings()
		file_select.print_menu_cursor()
	end

	return nil
end

-- from src/menu/file_select.c:lvl_init_menu_values_and_cursor_pos L3128-3183
function file_select.lvl_init_menu_values_and_cursor_pos(arg: number, unused: number): number
	file_select.sSelectedButtonID = FileSelectH.MENU_BUTTON_NONE
	file_select.sCurrentMenuLevel = FileSelectH.MENU_LAYER_MAIN
	file_select.sTextBaseAlpha = 0

	-- Place the cursor over the save file that was being played.
	-- gCurrSaveFileNum is 1 by default when the game boots, as such
	-- the cursor will point on Mario A save file.
	if SrcGameArea.gCurrSaveFileNum == 1 then
		file_select.sCursorPos[1] = -94.0
		file_select.sCursorPos[2] = 46.0
	elseif SrcGameArea.gCurrSaveFileNum == 2 then
		file_select.sCursorPos[1] = 24.0
		file_select.sCursorPos[2] = 46.0
	elseif SrcGameArea.gCurrSaveFileNum == 3 then
		file_select.sCursorPos[1] = -94.0
		file_select.sCursorPos[2] = 5.0
	elseif SrcGameArea.gCurrSaveFileNum == 4 then
		file_select.sCursorPos[1] = 24.0
		file_select.sCursorPos[2] = 5.0
	end

	file_select.sClickPos[1] = -10000
	file_select.sClickPos[2] = -10000
	file_select.sCursorClickingTimer = 0
	file_select.sSelectedFileNum = 0
	file_select.sSelectedFileIndex = FileSelectH.MENU_BUTTON_NONE
	file_select.sFadeOutText = IncludePRUltratypesH.FALSE
	file_select.sStatusMessageID = 0
	file_select.sTextFadeAlpha = 0
	file_select.sMainMenuTimer = 0
	file_select.sEraseYesNoHoverState = FileSelectH.MENU_ERASE_HOVER_NONE
	file_select.sSoundMode = S8(SrcGameSaveFile.save_file_get_sound_mode())

	return 0
end

-- from src/menu/file_select.c:lvl_update_obj_and_load_file_selected L3190-3193
function file_select.lvl_update_obj_and_load_file_selected(arg: number, unused: number): number
	SrcGameArea.area_update_objects()

	return file_select.sSelectedFileNum
end

return file_select
