--!strict
--!optimize 2

--[[
	Port of src/game/ingame_menu.c, src/game/ingame_menu.h.
]]

const Registry = require("./registry")

const GroupsTypesHPlus3 = require("./types_h_plus3")

const IncludeConfigH = require("../include/config_h")
const IncludeDialogIdsH = require("../include/dialog_ids_h")
const IncludeGfxDimensionsH = require("../include/gfx_dimensions_h")
const IncludeSeqIdsH = require("../include/seq_ids_h")
const IncludeSoundsH = require("../include/sounds_h")
const IncludeTextStringsH = require("../include/text_strings_h")
const Audio = require("../src/rom/audio_recorder")
const Gbi = require("../src/rom/gbi")
const MenuSymbols = require("../src/rom/menu_symbols")
const Segment2Symbols = require("../src/rom/segment2_symbols")
const SrcEngineMathUtilH = require("../src/engine/math_util_h")
const SrcGamePrintH = require("../src/game/print_h")
const SrcGameGameInit = require("../src/game/game_init")
const IncludePRUltratypesH = require("../include/PR/ultratypes_h")
const SrcGameLevelUpdate = require("../src/game/level_update")
const IncludeCourseTableH = require("../include/course_table_h")
const SrcGameSaveFile = require("../src/game/save_file")
const SrcGameArea = require("../src/game/area")
const Rom = require("../src/rom/rom")
const Symbols = require("../src/rom/symbols")
const SrcGameMemory = require("../src/game/memory")

-- sizeof(Mtx)
const MatrixSize = 64

-- Segmented addresses of the display lists of other files this one draws (the names of these symbols end in their address)
-- from levels/castle_grounds/areas/1/12/model.inc.c:castle_grounds_seg7_dl_0700EA58
const castle_grounds_seg7_dl_0700EA58 = 0x0700EA58

-- from levels/castle_grounds/areas/1/13/model.inc.c:castle_grounds_seg7_us_dl_0700F2E8
const castle_grounds_seg7_us_dl_0700F2E8 = 0x0700F2E8

-- from actors/coin/model.inc.c:coin_seg3_dl_03007940
const coin_seg3_dl_03007940 = 0x03007940

-- from actors/coin/model.inc.c:coin_seg3_dl_03007968
const coin_seg3_dl_03007968 = 0x03007968

-- from actors/coin/model.inc.c:coin_seg3_dl_03007990
const coin_seg3_dl_03007990 = 0x03007990

-- from actors/coin/model.inc.c:coin_seg3_dl_030079B8
const coin_seg3_dl_030079B8 = 0x030079B8

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from groups/ingame_menu_plus1.luau:scratch
const Scratch = {
	gMenuLineNum = { 0 },
	creditStr = buffer.create(100),
	strNumCoins = buffer.create(4),
	strStarCount = buffer.create(4),
	strCourseNum = buffer.create(4),
	strVal = buffer.create(8),
	courseCompleteCoinsStr = buffer.create(4),
	castleCourseStars = buffer.create(30),
	courseName = buffer.create(128),
	actName = buffer.create(128),
	dialogStr = buffer.create(1024),
	gDialogCameraAngleIndex = { 0 },
	handle_dialog_text_and_pages_pageState = { 0 },
	handle_dialog_text_and_pages_xMatrix = { 0 },
	handle_dialog_text_and_pages_linePos = { 0 },
}

-- from src/game/ingame_menu.c:textLengths (the length, TEXT_THE_RAW and TEXT_YOU_RAW: ASCII_TO_DIALOG of 't', 'h', 'e' and of 'y', 'o', 'u', then 0x00)
const MultiTextStrings = { buffer.fromstring("\3\55\43\40\0"), buffer.fromstring("\3\60\50\56\0") }

-- from src/game/ingame_menu.c:textSymStar (GLYPH_STAR and GLYPH_SPACE, the byte 0xFF that ends a string)
const TextSymStar = buffer.fromstring(string.char(SrcGamePrintH.GLYPH_STAR, bit32.band(SrcGamePrintH.GLYPH_SPACE, 0xFF)))

-- from src/audio/external.h:SEQ_PLAYER_LEVEL
const SEQ_PLAYER_LEVEL = 0

-- from src/game/ingame_menu.c:handle_special_dialog_text:dialogBossStart
-- King Bob-omb (Start), Whomp (Start), King Bob-omb (throw him out), Eyerock (Start), Wiggler (Start)
const DialogBossStart = { IncludeDialogIdsH.DIALOG_017, IncludeDialogIdsH.DIALOG_114, IncludeDialogIdsH.DIALOG_128, IncludeDialogIdsH.DIALOG_117, IncludeDialogIdsH.DIALOG_150 }

-- from src/game/ingame_menu.c:handle_special_dialog_text:dialogRaceSound
-- Koopa the Quick (BoB), Koopa the Quick (THI), Penguin Race, Fat Penguin Race (120 stars)
const DialogRaceSound = { IncludeDialogIdsH.DIALOG_005, IncludeDialogIdsH.DIALOG_009, IncludeDialogIdsH.DIALOG_055, IncludeDialogIdsH.DIALOG_164 }

-- from src/game/ingame_menu.c:handle_special_dialog_text:dialogStarSound
-- Red Switch, Green Switch, Blue Switch, 100 coins star, Bowser Red Coin Star
const DialogStarSound = { IncludeDialogIdsH.DIALOG_010, IncludeDialogIdsH.DIALOG_011, IncludeDialogIdsH.DIALOG_012, IncludeDialogIdsH.DIALOG_013, IncludeDialogIdsH.DIALOG_014 }

-- from src/game/ingame_menu.c:handle_special_dialog_text:dialogBossStop (BUGFIX_KING_BOB_OMB_FADE_MUSIC is 1)
-- King Bob-omb (Start), Whomp (Defeated), King Bob-omb (Defeated, missing in JP), Eyerock (Defeated), Wiggler (Defeated)
const DialogBossStop = { IncludeDialogIdsH.DIALOG_017, IncludeDialogIdsH.DIALOG_115, IncludeDialogIdsH.DIALOG_116, IncludeDialogIdsH.DIALOG_118, IncludeDialogIdsH.DIALOG_152 }

-- from src/game/ingame_menu.c:data
const ingame_menu_plus1 = {
	MENU_MTX_PUSH = 1,
	MENU_MTX_NOPUSH = 2,
	MENU_SCROLL_VERTICAL = 1,
	MENU_SCROLL_HORIZONTAL = 2,
	HUD_LUT_JPMENU = 1,
	HUD_LUT_GLOBAL = 2,
	HUD_LUT_DIFF = 2, -- HUD_LUT_GLOBAL
	-- from src/game/ingame_menu.c:gMenuTextColorTransTimer L31-31
	gMenuTextColorTransTimer = 0,
	-- from src/game/ingame_menu.c:gLastDialogLineNum L32-32
	gLastDialogLineNum = 0,
	-- from src/game/ingame_menu.c:gDialogVariable L33-33
	gDialogVariable = 0,
	-- from src/game/ingame_menu.c:gMenuTextAlpha L34-34
	gMenuTextAlpha = 0,
	HUD_LUT_DIFF2 = 2, -- HUD_LUT_DIFF
	MENU_MODE_NONE = -1,
	MENU_MODE_UNUSED_0 = 0,
	MENU_MODE_RENDER_PAUSE_SCREEN = 1,
	MENU_MODE_RENDER_COURSE_COMPLETE_SCREEN = 2,
	MENU_MODE_UNUSED_3 = 3,
	-- from src/game/ingame_menu.c:gCutsceneMsgXOffset L39-39
	gCutsceneMsgXOffset = 0,
	-- from src/game/ingame_menu.c:gCutsceneMsgYOffset L40-40
	gCutsceneMsgYOffset = 0,
	-- from src/game/ingame_menu.c:gRedCoinsCollected L41-41
	gRedCoinsCollected = 0,
	MENU_STATE_0 = 0,
	MENU_STATE_1 = 1,
	MENU_STATE_2 = 2,
	MENU_STATE_3 = 3,
	MENU_STATE_DEFAULT = 0,
	MENU_STATE_DIALOG_OPENING = 0,
	MENU_STATE_DIALOG_OPEN = 1,
	MENU_STATE_DIALOG_SCROLLING = 2,
	MENU_STATE_DIALOG_CLOSING = 3,
	MENU_STATE_PAUSE_SCREEN_OPENING = 0,
	MENU_STATE_PAUSE_SCREEN_COURSE = 1,
	MENU_STATE_PAUSE_SCREEN_CASTLE = 2,
	MENU_STATE_COURSE_COMPLETE_SCREEN_OPENING = 0,
	MENU_STATE_COURSE_COMPLETE_SCREEN_OPEN = 1,
	HUD_CHAR_A_UMLAUT = 58,
	HUD_CHAR_O_UMLAUT = 59,
	HUD_CHAR_U_UMLAUT = 60,
	GLOBAL_CHAR_SPACE = 158,
	GLOBAL_CHAR_TERMINATOR = 255,
	DIALOG_PAGE_STATE_NONE = 0,
	DIALOG_PAGE_STATE_SCROLL = 1,
	DIALOG_PAGE_STATE_END = 2,
	DIALOG_MARK_NONE = 0,
	DIALOG_MARK_DAKUTEN = 1,
	DIALOG_MARK_HANDAKUTEN = 2,
	DIALOG_TYPE_ROTATE = 0,
	DIALOG_TYPE_ZOOM = 1,
	DIALOG_CHAR_SLASH = 208,
	DIALOG_CHAR_MULTI_THE = 209,
	DIALOG_CHAR_MULTI_YOU = 210,
	DIALOG_CHAR_PERIOD = 110,
	DIALOG_CHAR_COMMA = 111,
	DIALOG_CHAR_SPACE = 158,
	DIALOG_CHAR_STAR_COUNT = 224,
	DIALOG_CHAR_UMLAUT = 233,
	DIALOG_CHAR_MARK_START = 239,
	DIALOG_CHAR_DAKUTEN = 240,
	DIALOG_CHAR_PERIOD_OR_HANDAKUTEN = 241,
	DIALOG_CHAR_STAR_FILLED = 250,
	DIALOG_CHAR_STAR_OPEN = 253,
	DIALOG_CHAR_NEWLINE = 254,
	DIALOG_CHAR_TERMINATOR = 255,
	DIALOG_BOX_ANGLE_DEFAULT = 90.0,
	DIALOG_BOX_SCALE_DEFAULT = 19.0,
	-- from src/game/ingame_menu.c:gDialogCharWidths L84-113
	gDialogCharWidths = {
			7,
			7,
			7,
			7,
			7,
			7,
			7,
			7,
			7,
			7,
			6,
			6,
			6,
			6,
			6,
			6,
			6,
			6,
			5,
			6,
			6,
			5,
			8,
			8,
			6,
			6,
			6,
			6,
			6,
			5,
			6,
			6,
			8,
			7,
			6,
			6,
			6,
			5,
			5,
			6,
			5,
			5,
			6,
			5,
			4,
			5,
			5,
			3,
			7,
			5,
			5,
			5,
			6,
			5,
			5,
			5,
			5,
			5,
			7,
			7,
			5,
			5,
			4,
			4,
			8,
			6,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			8,
			8,
			8,
			8,
			7,
			7,
			6,
			7,
			7,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			4,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			5,
			6,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			7,
			5,
			10,
			5,
			9,
			8,
			4,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			5,
			7,
			7,
			6,
			6,
			8,
			0,
			8,
			10,
			6,
			4,
			10,
			0,
			0,
		},
	-- from src/game/ingame_menu.c:gDialogScrollOffsetY L119-119
	gDialogScrollOffsetY = 0,
	-- from src/game/ingame_menu.c:gDialogID L121-121
	gDialogID = IncludeDialogIdsH.DIALOG_NONE,
	-- from src/game/ingame_menu.c:gNextDialogPageStartStrIndex L122-122
	gNextDialogPageStartStrIndex = 0,
	-- from src/game/ingame_menu.c:gDialogPageStartStrIndex L123-123
	gDialogPageStartStrIndex = 0,
	-- from src/game/ingame_menu.c:gMenuLineNum L127-127
	gMenuLineNum = 1,
	-- from src/game/ingame_menu.c:gDialogWithChoice L128-128
	gDialogWithChoice = 0,
	-- from src/game/ingame_menu.c:gMenuHoldKeyIndex L129-129
	gMenuHoldKeyIndex = 0,
	-- from src/game/ingame_menu.c:gMenuHoldKeyTimer L130-130
	gMenuHoldKeyTimer = 0,
	DIALOG_RESPONSE_NONE = 0,
	DIALOG_RESPONSE_YES = 1,
	DIALOG_RESPONSE_NO = 2,
	DIALOG_RESPONSE_NOT_DEFINED = 3,
	STRING_THE = 0,
	STRING_YOU = 1,
	MAX_STRING_WIDTH = 16,
	-- from src/game/ingame_menu.c:gHudSymCoin L964-964
	gHudSymCoin = buffer.fromstring(string.char(SrcGamePrintH.GLYPH_COIN, bit32.band(SrcGamePrintH.GLYPH_SPACE, 0xFF))),
	-- from src/game/ingame_menu.c:gHudSymX L965-965
	gHudSymX = buffer.fromstring(string.char(SrcGamePrintH.GLYPH_MULTIPLY, bit32.band(SrcGamePrintH.GLYPH_SPACE, 0xFF))),
	X_VAL1 = -7.0,
	Y_VAL1 = 5.0,
	Y_VAL2 = 5.0,
	X_VAL3 = 0.0,
	Y_VAL3 = 16,
	X_VAL4_1 = 56,
	X_VAL4_2 = 9,
	Y_VAL4_1 = 2,
	Y_VAL4_2 = 16,
	X_VAL5 = 118.0,
	Y_VAL5_1 = -16,
	Y_VAL5_2 = 5,
	X_Y_VAL6 = 0.8,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn0 L1864-1864
	gEndCutsceneStrEn0 = IncludeTextStringsH.TEXT_FILE_MARIO_EXCLAMATION,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn1 L1865-1865
	gEndCutsceneStrEn1 = IncludeTextStringsH.TEXT_POWER_STARS_RESTORED,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn2 L1866-1866
	gEndCutsceneStrEn2 = IncludeTextStringsH.TEXT_THANKS_TO_YOU,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn3 L1867-1867
	gEndCutsceneStrEn3 = IncludeTextStringsH.TEXT_THANK_YOU_MARIO,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn4 L1868-1868
	gEndCutsceneStrEn4 = IncludeTextStringsH.TEXT_SOMETHING_SPECIAL,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn5 L1869-1869
	gEndCutsceneStrEn5 = IncludeTextStringsH.TEXT_LISTEN_EVERYBODY,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn6 L1870-1870
	gEndCutsceneStrEn6 = IncludeTextStringsH.TEXT_LETS_HAVE_CAKE,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn7 L1871-1871
	gEndCutsceneStrEn7 = IncludeTextStringsH.TEXT_FOR_MARIO,
	-- from src/game/ingame_menu.c:gEndCutsceneStrEn8 L1872-1872
	gEndCutsceneStrEn8 = IncludeTextStringsH.TEXT_FILE_MARIO_QUESTION,
	-- from src/game/ingame_menu.c:gCutsceneMsgFade L1941-1941
	gCutsceneMsgFade = 0,
	-- from src/game/ingame_menu.c:gCutsceneMsgIndex L1942-1942
	gCutsceneMsgIndex = -1,
	-- from src/game/ingame_menu.c:gCutsceneMsgDuration L1943-1943
	gCutsceneMsgDuration = -1,
	-- from src/game/ingame_menu.c:gCutsceneMsgTimer L1944-1944
	gCutsceneMsgTimer = 0,
	-- from src/game/ingame_menu.c:gDialogCameraAngleIndex L1945-1945
	gDialogCameraAngleIndex = GroupsTypesHPlus3.CAM_SELECTION_MARIO,
	-- from src/game/ingame_menu.c:gDialogCourseActNum L1946-1946
	gDialogCourseActNum = 1,
	DIAG_VAL1 = 16,
	DIAG_VAL2 = 240,
	DIAG_VAL3 = 132,
	DIAG_VAL4 = 5,
	PEACH_MESSAGE_TIMER = 250,
	STR_X = 38,
	STR_Y = 142,
	CRS_NUM_X1 = 100,
	TXT_COURSE_X = 63,
	TXT_STAR_X = 98,
	ACT_NAME_X = 116,
	CRS_NAME_START = 3,
	CRS_NAME_X = 117,
	SECRET_CRS_NAME_X = 94,
	MYSCORE_X = 62,
	TXT1_X = 3,
	TXT2_X = 119,
	Y_VAL7 = 2,
	X_VAL8 = 4,
	Y_VAL8 = 2,
	Y_OFFSET1 = 17,
	Y_OFFSET2 = 33,
	PAUSE_X = 123,
	-- from src/game/ingame_menu.c:gCourseCompleteCoinsEqual L2965-2965
	gCourseCompleteCoinsEqual = 0,
	-- from src/game/ingame_menu.c:gCourseCompleteScreenTimer L2966-2966
	gCourseCompleteScreenTimer = 0,
	-- from src/game/ingame_menu.c:gCourseCompleteCoins L2967-2967
	gCourseCompleteCoins = 0,
	-- from src/game/ingame_menu.c:gHudFlash L2968-2968
	gHudFlash = 0,
	TXT_HISCORE_X = 109,
	TXT_HISCORE_Y = 36,
	TXT_CONGRATS_X = 70,
	TXT_CONGRATS_Y = 67,
	HUD_PRINT_HISCORE = 0,
	HUD_PRINT_CONGRATULATIONS = 1,
	TXT_NAME_X1 = 71,
	TXT_NAME_X2 = 69, -- TXT_NAME_X1 - 2
	CRS_NUM_X2 = 104,
	CRS_NUM_X3 = 102, -- CRS_NUM_X2 - 2
	TXT_SAVECONT_Y = 0,
	TXT_SAVEQUIT_Y = 20,
	TXT_CONTNOSAVE_Y = 40,
}

Registry.Register("groups__ingame_menu_plus1", ingame_menu_plus1)

-- A string of Rom.Memory (a course name, an act name, the text of a dialog) copied into Destination, the buffer the print functions
-- read in place of a `const u8 *`: the copy ends with the byte 0xFF that ends the string
function ingame_menu_plus1.CopyRomString(Destination: buffer, Address: number)
	local Length = 0

	while Rom.ReadU8(Address + Length) ~= ingame_menu_plus1.DIALOG_CHAR_TERMINATOR do
		Length += 1
	end

	buffer.copy(Destination, 0, Rom.Memory, Address, Length + 1)
end

-- from src/game/ingame_menu.c:create_dl_identity_matrix L133-151
function ingame_menu_plus1.create_dl_identity_matrix()
	const matrix = Gbi.alloc_display_list(MatrixSize)

	if matrix == nil then
		return
	end

	Gbi.guMtxIdent(matrix)
	Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
	Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_LOAD, Gbi.G_MTX_NOPUSH))
end

-- from src/game/ingame_menu.c:create_dl_translation_matrix L153-169
function ingame_menu_plus1.create_dl_translation_matrix(pushOp: number, x: number, y: number, z: number)
	const matrix = Gbi.alloc_display_list(MatrixSize)

	if matrix == nil then
		return
	end

	Gbi.guTranslate(matrix, F32(x), F32(y), F32(z))

	if pushOp == ingame_menu_plus1.MENU_MTX_PUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	end

	if pushOp == ingame_menu_plus1.MENU_MTX_NOPUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	end
end

-- from src/game/ingame_menu.c:create_dl_rotation_matrix L171-187
function ingame_menu_plus1.create_dl_rotation_matrix(pushOp: number, a: number, x: number, y: number, z: number)
	const matrix = Gbi.alloc_display_list(MatrixSize)

	if matrix == nil then
		return
	end

	Gbi.guRotate(matrix, F32(a), F32(x), F32(y), F32(z))

	if pushOp == ingame_menu_plus1.MENU_MTX_PUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	end

	if pushOp == ingame_menu_plus1.MENU_MTX_NOPUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	end
end

-- from src/game/ingame_menu.c:create_dl_scale_matrix L189-205
function ingame_menu_plus1.create_dl_scale_matrix(pushOp: number, x: number, y: number, z: number)
	const matrix = Gbi.alloc_display_list(MatrixSize)

	if matrix == nil then
		return
	end

	Gbi.guScale(matrix, F32(x), F32(y), F32(z))

	if pushOp == ingame_menu_plus1.MENU_MTX_PUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	end

	if pushOp == ingame_menu_plus1.MENU_MTX_NOPUSH then
		Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	end
end

-- from src/game/ingame_menu.c:create_dl_ortho_matrix L207-222
function ingame_menu_plus1.create_dl_ortho_matrix()
	const matrix = Gbi.alloc_display_list(MatrixSize)

	if matrix == nil then
		return
	end

	ingame_menu_plus1.create_dl_identity_matrix()

	Gbi.guOrtho(matrix, 0.0, IncludeConfigH.SCREEN_WIDTH, 0.0, IncludeConfigH.SCREEN_HEIGHT, -10.0, 10.0, 1.0)

	-- Should produce G_RDPHALF_1 in Fast3D
	Gbi.gSPPerspNormalize(0xFFFF)

	Gbi.gSPMatrix(matrix, bit32.bor(Gbi.G_MTX_PROJECTION, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
end

-- from src/game/ingame_menu.c:alloc_ia8_text_from_i1 L254-282
function ingame_menu_plus1.alloc_ia8_text_from_i1(in_: number, width: number, height: number): number?
	width = S16(TruncS32(width))
	height = S16(TruncS32(height))
	local outPos = 0
	const out = Gbi.alloc_display_list(width * height)

	if out == nil then
		return nil
	end

	for inPos = 0, (width * height) // 16 - 1 do
		local bitMask = 0x8000

		while bitMask ~= 0 do
			if bit32.btest(Rom.ReadU16(in_ + inPos * 2), bitMask) then
				Rom.WriteU8(out + outPos, 0xFF)
			else
				Rom.WriteU8(out + outPos, 0x00)
			end

			bitMask //= 2
			outPos = S16(outPos + 1)
		end
	end

	return out
end

-- from src/game/ingame_menu.c:render_generic_char L288-310
function ingame_menu_plus1.render_generic_char(c: number)
	const fontLUT = SrcGameMemory.segmented_to_virtual(Segment2Symbols.main_font_lut)
	const packedTexture = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(fontLUT + 4 * c))

	Gbi.gDPPipeSync()
	Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_16b, 1, packedTexture)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_tex_settings)
end

-- from src/game/ingame_menu.c:render_multi_text_string L395-416
function ingame_menu_plus1.render_multi_text_string(multiTextID: number)
	const textLengths = MultiTextStrings[multiTextID + 1]

	for i = 0, buffer.readu8(textLengths, 0) - 1 do
		const strChar = buffer.readu8(textLengths, 1 + i)

		ingame_menu_plus1.render_generic_char(strChar)
		ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[strChar + 1], 0.0, 0.0)
	end
end

-- from src/game/ingame_menu.c:print_generic_string L440-616
function ingame_menu_plus1.print_generic_string(x: number, y: number, str: buffer)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local mark = ingame_menu_plus1.DIALOG_MARK_NONE
	local strPos = 0
	local lineNum = 1

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x, y, 0.0)

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.DIALOG_CHAR_TERMINATOR do
		const strChar = buffer.readu8(str, strPos)

		if strChar == ingame_menu_plus1.DIALOG_CHAR_DAKUTEN then
			mark = ingame_menu_plus1.DIALOG_MARK_DAKUTEN
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_PERIOD_OR_HANDAKUTEN then
			mark = ingame_menu_plus1.DIALOG_MARK_HANDAKUTEN
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_NEWLINE then
			Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x, y - lineNum * ingame_menu_plus1.MAX_STRING_WIDTH, 0.0)
			lineNum = U8(lineNum + 1)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_PERIOD then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, -2.0, -5.0, 0.0)
			ingame_menu_plus1.render_generic_char(ingame_menu_plus1.DIALOG_CHAR_PERIOD_OR_HANDAKUTEN)
			Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_SLASH then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[ingame_menu_plus1.DIALOG_CHAR_SPACE + 1] * 2, 0.0, 0.0)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_MULTI_THE then
			ingame_menu_plus1.render_multi_text_string(ingame_menu_plus1.STRING_THE)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_MULTI_YOU then
			ingame_menu_plus1.render_multi_text_string(ingame_menu_plus1.STRING_YOU)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_SPACE then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.CHAR_WIDTH_SPACE, 0.0, 0.0)
		else
			ingame_menu_plus1.render_generic_char(strChar)

			if mark ~= ingame_menu_plus1.DIALOG_MARK_NONE then
				ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, 5.0, 5.0, 0.0)
				ingame_menu_plus1.render_generic_char(ingame_menu_plus1.DIALOG_CHAR_MARK_START + mark)
				Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
				mark = ingame_menu_plus1.DIALOG_MARK_NONE
			end

			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[strChar + 1], 0.0, 0.0)
		end

		strPos = S32(strPos + 1)
	end

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:print_hud_lut_string L636-724
function ingame_menu_plus1.print_hud_lut_string(hudLUT: number, x: number, y: number, str: buffer)
	hudLUT = S8(TruncS32(hudLUT))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local strPos = 0
	const hudLUT1 = SrcGameMemory.segmented_to_virtual(MenuSymbols.menu_hud_lut) -- Japanese Menu HUD Color font
	const hudLUT2 = SrcGameMemory.segmented_to_virtual(Segment2Symbols.main_hud_lut) -- 0-9 A-Z HUD Color Font
	local curX = U32(x)
	const curY = U32(y)
	local xStride = 0 -- X separation

	if hudLUT == ingame_menu_plus1.HUD_LUT_JPMENU then
		xStride = 16
	else -- HUD_LUT_GLOBAL
		xStride = 12 --? Shindou uses this.
	end

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.GLOBAL_CHAR_TERMINATOR do
		const strChar = buffer.readu8(str, strPos)

		if strChar == ingame_menu_plus1.GLOBAL_CHAR_SPACE then
			curX = U32(curX + 8)
		else
			Gbi.gDPPipeSync()

			if hudLUT == ingame_menu_plus1.HUD_LUT_JPMENU then
				Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Rom.ReadU32(hudLUT1 + 4 * strChar))
			end

			if hudLUT == ingame_menu_plus1.HUD_LUT_GLOBAL then
				Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Rom.ReadU32(hudLUT2 + 4 * strChar))
			end

			Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_load_tex_block)
			Gbi.gSPTextureRectangle(bit32.lshift(curX, 2), bit32.lshift(curY, 2), bit32.lshift(curX + 16, 2), bit32.lshift(curY + 16, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(1, 10), bit32.lshift(1, 10))
			curX = U32(curX + xStride)
		end

		strPos = S32(strPos + 1)
	end
end

-- from src/game/ingame_menu.c:print_menu_generic_string L742-801
function ingame_menu_plus1.print_menu_generic_string(x: number, y: number, str: buffer)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local mark = ingame_menu_plus1.DIALOG_MARK_NONE
	local strPos = 0
	local curX = U32(x)
	const curY = U32(y)
	const fontLUT = SrcGameMemory.segmented_to_virtual(MenuSymbols.menu_font_lut)

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.DIALOG_CHAR_TERMINATOR do
		const strChar = buffer.readu8(str, strPos)

		if strChar == ingame_menu_plus1.DIALOG_CHAR_DAKUTEN then
			mark = ingame_menu_plus1.DIALOG_MARK_DAKUTEN
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_PERIOD_OR_HANDAKUTEN then
			mark = ingame_menu_plus1.DIALOG_MARK_HANDAKUTEN
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_SPACE then
			curX = U32(curX + 4)
		else
			Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 1, Rom.ReadU32(fontLUT + 4 * strChar))
			Gbi.gDPLoadSync()
			Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 8 * 8 - 1, Gbi.CALC_DXT(8, Gbi.G_IM_SIZ_8b_BYTES))
			Gbi.gSPTextureRectangle(bit32.lshift(curX, 2), bit32.lshift(curY, 2), bit32.lshift(curX + 8, 2), bit32.lshift(curY + 8, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(1, 10), bit32.lshift(1, 10))

			if mark ~= ingame_menu_plus1.DIALOG_MARK_NONE then
				Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_IA, Gbi.G_IM_SIZ_8b, 1, Rom.ReadU32(fontLUT + 4 * (ingame_menu_plus1.DIALOG_CHAR_MARK_START + mark)))
				Gbi.gDPLoadSync()
				Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 8 * 8 - 1, Gbi.CALC_DXT(8, Gbi.G_IM_SIZ_8b_BYTES))
				Gbi.gSPTextureRectangle(bit32.lshift(curX + 6, 2), bit32.lshift(curY - 7, 2), bit32.lshift(curX + 6 + 8, 2), bit32.lshift(curY - 7 + 8, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(1, 10), bit32.lshift(1, 10))

				mark = ingame_menu_plus1.DIALOG_MARK_NONE
			end

			curX = U32(curX + ingame_menu_plus1.gDialogCharWidths[strChar + 1])
		end

		strPos = S32(strPos + 1)
	end
end

-- from src/game/ingame_menu.c:print_credits_string L803-833
function ingame_menu_plus1.print_credits_string(x: number, y: number, str: buffer)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local strPos = 0
	const fontLUT = SrcGameMemory.segmented_to_virtual(Segment2Symbols.main_credits_font_lut)
	local curX = U32(x)
	const curY = U32(y)

	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 0, 0, Gbi.G_TX_LOADTILE, 0, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD, bit32.bor(Gbi.G_TX_WRAP, Gbi.G_TX_NOMIRROR), Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD)
	Gbi.gDPTileSync()
	Gbi.gDPSetTile(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 2, 0, Gbi.G_TX_RENDERTILE, 0, Gbi.G_TX_CLAMP, 3, Gbi.G_TX_NOLOD, Gbi.G_TX_CLAMP, 3, Gbi.G_TX_NOLOD)
	Gbi.gDPSetTileSize(Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(8 - 1, Gbi.G_TEXTURE_IMAGE_FRAC), bit32.lshift(8 - 1, Gbi.G_TEXTURE_IMAGE_FRAC))

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.GLOBAL_CHAR_TERMINATOR do
		const strChar = buffer.readu8(str, strPos)

		if strChar == ingame_menu_plus1.GLOBAL_CHAR_SPACE then
			curX = U32(curX + 4)
		else
			Gbi.gDPPipeSync()
			Gbi.gDPSetTextureImage(Gbi.G_IM_FMT_RGBA, Gbi.G_IM_SIZ_16b, 1, Rom.ReadU32(fontLUT + 4 * strChar))
			Gbi.gDPLoadSync()
			Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, 8 * 8 - 1, Gbi.CALC_DXT(8, Gbi.G_IM_SIZ_16b_BYTES))
			Gbi.gSPTextureRectangle(bit32.lshift(curX, 2), bit32.lshift(curY, 2), bit32.lshift(curX + 8, 2), bit32.lshift(curY + 8, 2), Gbi.G_TX_RENDERTILE, 0, 0, bit32.lshift(1, 10), bit32.lshift(1, 10))
			curX = U32(curX + 7)
		end

		strPos = S32(strPos + 1)
	end
end

-- from src/game/ingame_menu.c:handle_menu_scrolling L835-886
function ingame_menu_plus1.handle_menu_scrolling(scrollDirection: number, currentIndex: { number }, minIndex: number, maxIndex: number)
	scrollDirection = S8(TruncS32(scrollDirection))
	minIndex = S8(TruncS32(minIndex))
	maxIndex = S8(TruncS32(maxIndex))
	local index = 0

	if scrollDirection == ingame_menu_plus1.MENU_SCROLL_VERTICAL then
		if SrcGameGameInit.gPlayer3Controller.rawStickY > 60 then
			index = U8(index + 1)
		end

		if SrcGameGameInit.gPlayer3Controller.rawStickY < -60 then
			index = U8(index + 2)
		end
	elseif scrollDirection == ingame_menu_plus1.MENU_SCROLL_HORIZONTAL then
		if SrcGameGameInit.gPlayer3Controller.rawStickX > 60 then
			index = U8(index + 2)
		end

		if SrcGameGameInit.gPlayer3Controller.rawStickX < -60 then
			index = U8(index + 1)
		end
	end

	if bit32.band(bit32.bxor(index, ingame_menu_plus1.gMenuHoldKeyIndex), index) == 2 then
		if currentIndex[1] == maxIndex then
			-- Probably originally a >=, but later replaced with an == and an else statement.
			currentIndex[1] = maxIndex
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CHANGE_SELECT, Audio.gGlobalSoundSource)
			currentIndex[1] = S8(currentIndex[1] + 1)
		end
	end

	if bit32.band(bit32.bxor(index, ingame_menu_plus1.gMenuHoldKeyIndex), index) == 1 then
		if currentIndex[1] == minIndex then
			-- Same applies to here as above
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_CHANGE_SELECT, Audio.gGlobalSoundSource)
			currentIndex[1] = S8(currentIndex[1] - 1)
		end
	end

	if ingame_menu_plus1.gMenuHoldKeyTimer == 10 then
		ingame_menu_plus1.gMenuHoldKeyTimer = 8
		ingame_menu_plus1.gMenuHoldKeyIndex = 0
	else
		ingame_menu_plus1.gMenuHoldKeyTimer = U8(ingame_menu_plus1.gMenuHoldKeyTimer + 1)
		ingame_menu_plus1.gMenuHoldKeyIndex = index
	end

	if bit32.band(index, 3) == 0 then
		ingame_menu_plus1.gMenuHoldKeyTimer = 0
	end
end

-- from src/game/ingame_menu.c:get_str_x_pos_from_center L891-914
function ingame_menu_plus1.get_str_x_pos_from_center(centerPos: number, str: buffer, scale: number): number
	centerPos = S16(TruncS32(centerPos))
	scale = F32(scale)
	local strPos = 0
	local spacesWidth = 0.0

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.DIALOG_CHAR_TERMINATOR do
		spacesWidth = F32(spacesWidth + ingame_menu_plus1.gDialogCharWidths[buffer.readu8(str, strPos) + 1])
		strPos = S16(strPos + 1)
	end

	-- return the x position of where the string starts as half the string's
	-- length from the position of the provided center.
	return S16(centerPos - S16(TruncS32(spacesWidth / 2.0)))
end

-- from src/game/ingame_menu.c:get_string_width L940-961
function ingame_menu_plus1.get_string_width(str: buffer): number
	local strPos = 0
	local width = 0

	while buffer.readu8(str, strPos) ~= ingame_menu_plus1.DIALOG_CHAR_TERMINATOR do
		width = S16(width + ingame_menu_plus1.gDialogCharWidths[buffer.readu8(str, strPos) + 1])
		strPos = S16(strPos + 1)
	end

	return width
end

-- from src/game/ingame_menu.c:print_hud_my_score_coins L967-983
function ingame_menu_plus1.print_hud_my_score_coins(useCourseCoinScore: number, fileIndex: number, courseIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	courseIndex = S8(TruncS32(courseIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local numCoins = 0

	if useCourseCoinScore == 0 then
		numCoins = S16(U16(SrcGameSaveFile.save_file_get_max_coin_score(courseIndex)))
	else
		numCoins = S16(SrcGameSaveFile.save_file_get_course_coin_score(fileIndex, courseIndex))
	end

	if numCoins ~= 0 then
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x, y, ingame_menu_plus1.gHudSymCoin)
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 16, y, ingame_menu_plus1.gHudSymX)
		ingame_menu_plus1.int_to_str(numCoins, Scratch.strNumCoins)
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 32, y, Scratch.strNumCoins)
	end
end

-- from src/game/ingame_menu.c:print_hud_my_score_stars L985-1000
function ingame_menu_plus1.print_hud_my_score_stars(fileIndex: number, courseIndex: number, x: number, y: number)
	fileIndex = S8(TruncS32(fileIndex))
	courseIndex = S8(TruncS32(courseIndex))
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	const starCount = S16(SrcGameSaveFile.save_file_get_course_star_count(fileIndex, courseIndex))

	if starCount ~= 0 then
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x, y, TextSymStar)
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 16, y, ingame_menu_plus1.gHudSymX)
		ingame_menu_plus1.int_to_str(starCount, Scratch.strStarCount)
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 32, y, Scratch.strStarCount)
	end
end

-- from src/game/ingame_menu.c:int_to_str L1002-1029
function ingame_menu_plus1.int_to_str(num: number, dst: buffer)
	if num > 999 then
		buffer.writeu8(dst, 0, 0x00)
		buffer.writeu8(dst, 1, ingame_menu_plus1.DIALOG_CHAR_TERMINATOR)

		return
	end

	const digit1 = TruncS32(num / 100)
	const digit2 = TruncS32((num - digit1 * 100) / 10)
	const digit3 = (num - digit1 * 100) - digit2 * 10

	local pos = 0

	if digit1 ~= 0 then
		buffer.writeu8(dst, pos, U8(digit1))
		pos = S8(pos + 1)
	end

	if digit2 ~= 0 or digit1 ~= 0 then
		buffer.writeu8(dst, pos, U8(digit2))
		pos = S8(pos + 1)
	end

	buffer.writeu8(dst, pos, U8(digit3))
	pos = S8(pos + 1)
	buffer.writeu8(dst, pos, ingame_menu_plus1.DIALOG_CHAR_TERMINATOR)
end

-- from src/game/ingame_menu.c:get_dialog_id L1075-1077
function ingame_menu_plus1.get_dialog_id(): number
	return ingame_menu_plus1.gDialogID
end

-- from src/game/ingame_menu.c:create_dialog_box L1079-1084
function ingame_menu_plus1.create_dialog_box(dialog: number)
	dialog = S16(TruncS32(dialog))
	if ingame_menu_plus1.gDialogID == IncludeDialogIdsH.DIALOG_NONE then
		ingame_menu_plus1.gDialogID = dialog
		ingame_menu_plus1.gDialogBoxType = ingame_menu_plus1.DIALOG_TYPE_ROTATE
	end
end

-- from src/game/ingame_menu.c:create_dialog_box_with_var L1086-1092
function ingame_menu_plus1.create_dialog_box_with_var(dialog: number, dialogVar: number)
	dialog = S16(TruncS32(dialog))
	if ingame_menu_plus1.gDialogID == IncludeDialogIdsH.DIALOG_NONE then
		ingame_menu_plus1.gDialogID = dialog
		ingame_menu_plus1.gDialogVariable = dialogVar
		ingame_menu_plus1.gDialogBoxType = ingame_menu_plus1.DIALOG_TYPE_ROTATE
	end
end

-- from src/game/ingame_menu.c:create_dialog_inverted_box L1094-1099
function ingame_menu_plus1.create_dialog_inverted_box(dialog: number)
	dialog = S16(TruncS32(dialog))
	if ingame_menu_plus1.gDialogID == IncludeDialogIdsH.DIALOG_NONE then
		ingame_menu_plus1.gDialogID = dialog
		ingame_menu_plus1.gDialogBoxType = ingame_menu_plus1.DIALOG_TYPE_ZOOM
	end
end

-- from src/game/ingame_menu.c:create_dialog_box_with_response L1101-1107
function ingame_menu_plus1.create_dialog_box_with_response(dialog: number)
	dialog = S16(TruncS32(dialog))
	if ingame_menu_plus1.gDialogID == IncludeDialogIdsH.DIALOG_NONE then
		ingame_menu_plus1.gDialogID = dialog
		ingame_menu_plus1.gDialogBoxType = ingame_menu_plus1.DIALOG_TYPE_ROTATE
		ingame_menu_plus1.gDialogWithChoice = IncludePRUltratypesH.TRUE
	end
end

-- from src/game/ingame_menu.c:reset_dialog_render_state L1109-1124
function ingame_menu_plus1.reset_dialog_render_state()
	SrcGameLevelUpdate.level_set_transition(0, nil)

	if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ZOOM then
		Registry.Members.src__game__camera.trigger_cutscene_dialog(2)
	end

	ingame_menu_plus1.gDialogBoxScale = ingame_menu_plus1.DIALOG_BOX_SCALE_DEFAULT
	ingame_menu_plus1.gDialogBoxAngle = ingame_menu_plus1.DIALOG_BOX_ANGLE_DEFAULT
	ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT
	ingame_menu_plus1.gDialogID = IncludeDialogIdsH.DIALOG_NONE
	ingame_menu_plus1.gDialogPageStartStrIndex = 0
	ingame_menu_plus1.gDialogWithChoice = IncludePRUltratypesH.FALSE
	ingame_menu_plus1.gNextDialogPageStartStrIndex = 0
	ingame_menu_plus1.gDialogResponse = ingame_menu_plus1.DIALOG_RESPONSE_NONE
end

-- from src/game/ingame_menu.c:render_dialog_box_type L1136-1171
function ingame_menu_plus1.render_dialog_box_type(dialog: number, linesPerBox: number)
	linesPerBox = S8(TruncS32(linesPerBox))

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, Rom.ReadS16(dialog + 6), Rom.ReadS16(dialog + 8), 0)

	if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ROTATE then -- Renders a dialog black box with zoom and rotation
		if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPENING or ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_CLOSING then
			ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 1.0 / ingame_menu_plus1.gDialogBoxScale, 1.0 / ingame_menu_plus1.gDialogBoxScale, 1.0)
			-- convert the speed into angle
			ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, F32(ingame_menu_plus1.gDialogBoxAngle * 4.0), 0, 0, 1.0)
		end

		Gbi.gDPSetEnvColor(0, 0, 0, 150)
	elseif ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ZOOM then -- Renders a dialog white box with zoom
		if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPENING or ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_CLOSING then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 65.0 - (65.0 / ingame_menu_plus1.gDialogBoxScale), (40.0 / ingame_menu_plus1.gDialogBoxScale) - 40, 0)
			ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 1.0 / ingame_menu_plus1.gDialogBoxScale, 1.0 / ingame_menu_plus1.gDialogBoxScale, 1.0)
		end

		Gbi.gDPSetEnvColor(255, 255, 255, 150)
	end

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, ingame_menu_plus1.X_VAL1, ingame_menu_plus1.Y_VAL1, 0)
	ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 1.1, F32(linesPerBox / ingame_menu_plus1.Y_VAL2) + 0.1, 1.0)

	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_text_bg_box)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:change_and_flash_dialog_text_color_lines L1173-1196
function ingame_menu_plus1.change_and_flash_dialog_text_color_lines(colorMode: number, lineNum: number)
	colorMode = S8(TruncS32(colorMode))
	lineNum = S8(TruncS32(lineNum))

	if colorMode == 1 then -- unused
		if lineNum == 1 then
			Gbi.gDPSetEnvColor(255, 255, 255, 255)
		else
			if lineNum == ingame_menu_plus1.gMenuLineNum then
				const color = U8(TruncS32(F32(F32(SrcEngineMathUtilH.sins(ingame_menu_plus1.gMenuTextColorTransTimer) * 50.0) + 200.0)))

				Gbi.gDPSetEnvColor(color, color, color, 255)
			else
				Gbi.gDPSetEnvColor(200, 200, 200, 255)
			end
		end
	else
		if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ZOOM then
			Gbi.gDPSetEnvColor(0, 0, 0, 255)
		end
	end
end

-- from src/game/ingame_menu.c:handle_dialog_scroll_page_state L1232-1251
function ingame_menu_plus1.handle_dialog_scroll_page_state(lineNum: number, totalLines: number, pageState: { number }, xMatrix: { number }, linePos: { number })
	lineNum = S8(TruncS32(lineNum))
	totalLines = S8(TruncS32(totalLines))
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	if lineNum == totalLines then
		pageState[1] = ingame_menu_plus1.DIALOG_PAGE_STATE_SCROLL

		return
	end

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, ingame_menu_plus1.X_VAL3, 2 - lineNum * ingame_menu_plus1.Y_VAL3, 0)

	linePos[1] = 0
	xMatrix[1] = 1
end

-- from src/game/ingame_menu.c:render_star_count_dialog_text L1272-1326
function ingame_menu_plus1.render_star_count_dialog_text(xMatrix: { number }, linePos: { number })
	const tensDigit = S8(TruncS32(ingame_menu_plus1.gDialogVariable / 10))
	const onesDigit = S8(ingame_menu_plus1.gDialogVariable - tensDigit * 10) -- remainder

	if tensDigit ~= 0 then
		if xMatrix[1] ~= 1 then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[ingame_menu_plus1.DIALOG_CHAR_SPACE + 1] * xMatrix[1], 0, 0)
		end

		ingame_menu_plus1.render_generic_char(tensDigit)
		ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[tensDigit + 1], 0, 0)
		xMatrix[1] = 1
		linePos[1] = S16(linePos[1] + 1)
	end

	if xMatrix[1] ~= 1 then
		ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[ingame_menu_plus1.DIALOG_CHAR_SPACE + 1] * (xMatrix[1] - 1), 0, 0)
	end

	ingame_menu_plus1.render_generic_char(onesDigit)
	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[onesDigit + 1], 0, 0)
	linePos[1] = S16(linePos[1] + 1)
	xMatrix[1] = 1
end

-- from src/game/ingame_menu.c:render_multi_text_string_lines L1332-1363
function ingame_menu_plus1.render_multi_text_string_lines(multiTextId: number, lineNum: number, linePos: { number }, linesPerBox: number, xMatrix: number, lowerBound: number)
	const textLengths = MultiTextStrings[multiTextId + 1]

	if lineNum >= lowerBound and lineNum <= lowerBound + linesPerBox then
		if linePos[1] ~= 0 or xMatrix ~= 1 then
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[ingame_menu_plus1.DIALOG_CHAR_SPACE + 1] * (xMatrix - 1), 0, 0)
		end

		for i = 0, buffer.readu8(textLengths, 0) - 1 do
			const strChar = buffer.readu8(textLengths, 1 + i)

			ingame_menu_plus1.render_generic_char(strChar)
			ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[strChar + 1], 0, 0)
		end
	end

	-- linePos += textLengths[multiTextId].str[0] advances the C's local pointer only, so the caller never sees it.
end

-- from src/game/ingame_menu.c:ensure_nonnegative L1380-1386
function ingame_menu_plus1.ensure_nonnegative(value: number): number
	value = S16(TruncS32(value))
	if value < 0 then
		value = 0
	end

	return value
end

-- from src/game/ingame_menu.c:handle_dialog_text_and_pages L1391-1726
function ingame_menu_plus1.handle_dialog_text_and_pages(colorMode: number, dialog: number, lowerBound: number)
	colorMode = S8(TruncS32(colorMode))
	lowerBound = S8(TruncS32(lowerBound))
	const str = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(dialog + 12))
	local lineNum = 1
	local totalLines = 0
	local pageState = ingame_menu_plus1.DIALOG_PAGE_STATE_NONE
	local xMatrix = 1
	const linesPerBox = Rom.ReadS8(dialog + 4)
	local strIndex = 0
	local linePos = 0

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_SCROLLING then
		-- If scrolling, consider the number of lines for both
		-- the current page and the page being scrolled to.
		totalLines = S8(linesPerBox * 2 + 1)
	else
		totalLines = S8(linesPerBox + 1)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

	strIndex = ingame_menu_plus1.gDialogPageStartStrIndex

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_SCROLLING then
		ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 0, F32(ingame_menu_plus1.gDialogScrollOffsetY), 0)
	end

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, ingame_menu_plus1.X_VAL3, 2 - lineNum * ingame_menu_plus1.Y_VAL3, 0)

	while pageState == ingame_menu_plus1.DIALOG_PAGE_STATE_NONE do
		ingame_menu_plus1.change_and_flash_dialog_text_color_lines(colorMode, lineNum)

		const strChar = Rom.ReadU8(str + strIndex)

		if strChar == ingame_menu_plus1.DIALOG_CHAR_TERMINATOR then
			pageState = ingame_menu_plus1.DIALOG_PAGE_STATE_END
			Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_NEWLINE then
			lineNum = S8(lineNum + 1)
			Scratch.handle_dialog_text_and_pages_pageState[1] = pageState
			Scratch.handle_dialog_text_and_pages_xMatrix[1] = xMatrix
			Scratch.handle_dialog_text_and_pages_linePos[1] = linePos
			ingame_menu_plus1.handle_dialog_scroll_page_state(lineNum, totalLines, Scratch.handle_dialog_text_and_pages_pageState, Scratch.handle_dialog_text_and_pages_xMatrix, Scratch.handle_dialog_text_and_pages_linePos)
			pageState = Scratch.handle_dialog_text_and_pages_pageState[1]
			xMatrix = Scratch.handle_dialog_text_and_pages_xMatrix[1]
			linePos = Scratch.handle_dialog_text_and_pages_linePos[1]
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_DAKUTEN or strChar == ingame_menu_plus1.DIALOG_CHAR_PERIOD_OR_HANDAKUTEN then
			-- mark = DIALOG_MARK_DAKUTEN / DIALOG_MARK_HANDAKUTEN: only used in JP and SH.
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_SPACE then
			xMatrix = S8(xMatrix + 1)
			linePos = S16(linePos + 1)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_SLASH then
			xMatrix = S8(xMatrix + 2)
			linePos = S16(linePos + 2)
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_MULTI_THE then
			Scratch.handle_dialog_text_and_pages_linePos[1] = linePos
			ingame_menu_plus1.render_multi_text_string_lines(ingame_menu_plus1.STRING_THE, lineNum, Scratch.handle_dialog_text_and_pages_linePos, linesPerBox, xMatrix, lowerBound)
			xMatrix = 1
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_MULTI_YOU then
			Scratch.handle_dialog_text_and_pages_linePos[1] = linePos
			ingame_menu_plus1.render_multi_text_string_lines(ingame_menu_plus1.STRING_YOU, lineNum, Scratch.handle_dialog_text_and_pages_linePos, linesPerBox, xMatrix, lowerBound)
			xMatrix = 1
		elseif strChar == ingame_menu_plus1.DIALOG_CHAR_STAR_COUNT then
			Scratch.handle_dialog_text_and_pages_xMatrix[1] = xMatrix
			Scratch.handle_dialog_text_and_pages_linePos[1] = linePos
			ingame_menu_plus1.render_star_count_dialog_text(Scratch.handle_dialog_text_and_pages_xMatrix, Scratch.handle_dialog_text_and_pages_linePos)
			xMatrix = Scratch.handle_dialog_text_and_pages_xMatrix[1]
			linePos = Scratch.handle_dialog_text_and_pages_linePos[1]
		else -- any other character
			if lineNum >= lowerBound and lineNum <= lowerBound + linesPerBox then
				if linePos ~= 0 or xMatrix ~= 1 then
					ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[ingame_menu_plus1.DIALOG_CHAR_SPACE + 1] * (xMatrix - 1), 0, 0)
				end

				ingame_menu_plus1.render_generic_char(strChar)
				ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.gDialogCharWidths[strChar + 1], 0, 0)
				xMatrix = 1
				linePos = S16(linePos + 1)
			end
		end

		strIndex = S16(strIndex + 1)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPEN then
		if pageState == ingame_menu_plus1.DIALOG_PAGE_STATE_END then
			ingame_menu_plus1.gNextDialogPageStartStrIndex = -1
		else
			ingame_menu_plus1.gNextDialogPageStartStrIndex = strIndex
		end
	end

	ingame_menu_plus1.gLastDialogLineNum = lineNum
end

-- from src/game/ingame_menu.c:render_dialog_triangle_choice L1745-1759
function ingame_menu_plus1.render_dialog_triangle_choice()
	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPEN then
		Scratch.gMenuLineNum[1] = ingame_menu_plus1.gMenuLineNum
		ingame_menu_plus1.handle_menu_scrolling(ingame_menu_plus1.MENU_SCROLL_HORIZONTAL, Scratch.gMenuLineNum, 1, 2)
		ingame_menu_plus1.gMenuLineNum = Scratch.gMenuLineNum[1]
	end

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, (ingame_menu_plus1.gMenuLineNum - 1) * ingame_menu_plus1.X_VAL4_1 + ingame_menu_plus1.X_VAL4_2, ingame_menu_plus1.Y_VAL4_1 - ingame_menu_plus1.gLastDialogLineNum * ingame_menu_plus1.Y_VAL4_2, 0)

	if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ROTATE then -- White Text
		Gbi.gDPSetEnvColor(255, 255, 255, 255)
	else -- Black Text
		Gbi.gDPSetEnvColor(0, 0, 0, 255)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
end

-- from src/game/ingame_menu.c:render_dialog_triangle_next L1783-1802
function ingame_menu_plus1.render_dialog_triangle_next(linesPerBox: number)
	linesPerBox = S8(TruncS32(linesPerBox))
	if bit32.btest(SrcGameGameInit.gGlobalTimer, 8) then
		return
	end

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, ingame_menu_plus1.X_VAL5, linesPerBox * ingame_menu_plus1.Y_VAL5_1 + ingame_menu_plus1.Y_VAL5_2, 0)
	ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, ingame_menu_plus1.X_Y_VAL6, ingame_menu_plus1.X_Y_VAL6, 1.0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, -90.0, 0, 0, 1.0)

	if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ROTATE then -- White Text
		Gbi.gDPSetEnvColor(255, 255, 255, 255)
	else -- Black Text
		Gbi.gDPSetEnvColor(0, 0, 0, 255)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:handle_special_dialog_text L1804-1849
function ingame_menu_plus1.handle_special_dialog_text(dialogID: number)
	for _, bossDialog in DialogBossStart do
		if bossDialog == dialogID then
			Audio.seq_player_unlower_volume(SEQ_PLAYER_LEVEL, 60)
			Audio.play_music(SEQ_PLAYER_LEVEL, bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS), 0)

			return
		end
	end

	for _, raceDialog in DialogRaceSound do
		if raceDialog == dialogID and ingame_menu_plus1.gMenuLineNum == ingame_menu_plus1.DIALOG_RESPONSE_YES then
			Audio.play_race_fanfare()
			return
		end
	end

	for _, starDialog in DialogStarSound do
		if starDialog == dialogID and ingame_menu_plus1.gMenuLineNum == ingame_menu_plus1.DIALOG_RESPONSE_YES then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)

			return
		end
	end

	for _, stopDialog in DialogBossStop do
		if stopDialog == dialogID then
			Audio.seq_player_fade_out(SEQ_PLAYER_LEVEL, 1)

			return
		end
	end
end

-- from src/game/ingame_menu.c:render_dialog_entries L1964-2153
function ingame_menu_plus1.render_dialog_entries()
	local lowerBound = 0
	const dialogTable = SrcGameMemory.segmented_to_virtual(Symbols.Seg2DialogTable)
	const dialog = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(dialogTable + 4 * ingame_menu_plus1.gDialogID))

	-- if the dialog entry is invalid, set the ID to DIALOG_NONE.
	if dialog == SrcGameMemory.segmented_to_virtual(0) then
		ingame_menu_plus1.gDialogID = IncludeDialogIdsH.DIALOG_NONE

		return
	end

	const linesPerBox = Rom.ReadS8(dialog + 4)

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPENING then
		if ingame_menu_plus1.gDialogBoxAngle == ingame_menu_plus1.DIALOG_BOX_ANGLE_DEFAULT then
			Audio.play_dialog_sound(ingame_menu_plus1.gDialogID)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_MESSAGE_APPEAR, Audio.gGlobalSoundSource)
		end

		if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ROTATE then
			ingame_menu_plus1.gDialogBoxAngle = F32(ingame_menu_plus1.gDialogBoxAngle - 7.5)
			ingame_menu_plus1.gDialogBoxScale = F32(ingame_menu_plus1.gDialogBoxScale - 1.5)
		else
			ingame_menu_plus1.gDialogBoxAngle = F32(ingame_menu_plus1.gDialogBoxAngle - 10.0)
			ingame_menu_plus1.gDialogBoxScale = F32(ingame_menu_plus1.gDialogBoxScale - 2.0)
		end

		if ingame_menu_plus1.gDialogBoxAngle == 0.0 then
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DIALOG_OPEN
			ingame_menu_plus1.gMenuLineNum = 1
		end

		lowerBound = 1
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPEN then
		ingame_menu_plus1.gDialogBoxAngle = 0.0

		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, Registry.Members.include__PR__os_h.A_BUTTON) or bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, Registry.Members.include__PR__os_h.B_BUTTON) then
			if ingame_menu_plus1.gNextDialogPageStartStrIndex == -1 then
				ingame_menu_plus1.handle_special_dialog_text(ingame_menu_plus1.gDialogID)
				ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DIALOG_CLOSING
			else
				ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DIALOG_SCROLLING
				Audio.play_sound(IncludeSoundsH.SOUND_MENU_MESSAGE_NEXT_PAGE, Audio.gGlobalSoundSource)
			end
		end

		lowerBound = 1
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_SCROLLING then
		ingame_menu_plus1.gDialogScrollOffsetY = S16(ingame_menu_plus1.gDialogScrollOffsetY + linesPerBox * 2)

		if ingame_menu_plus1.gDialogScrollOffsetY >= linesPerBox * ingame_menu_plus1.DIAG_VAL1 then
			ingame_menu_plus1.gDialogPageStartStrIndex = ingame_menu_plus1.gNextDialogPageStartStrIndex
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DIALOG_OPEN
			ingame_menu_plus1.gDialogScrollOffsetY = 0
		end

		lowerBound = S8(TruncS32(ingame_menu_plus1.gDialogScrollOffsetY / ingame_menu_plus1.DIAG_VAL1) + 1)
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_CLOSING then
		if ingame_menu_plus1.gDialogBoxAngle == 20.0 then
			SrcGameLevelUpdate.level_set_transition(0, nil)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_MESSAGE_DISAPPEAR, Audio.gGlobalSoundSource)

			if ingame_menu_plus1.gDialogBoxType == ingame_menu_plus1.DIALOG_TYPE_ZOOM then
				Registry.Members.src__game__camera.trigger_cutscene_dialog(2)
			end

			ingame_menu_plus1.gDialogResponse = ingame_menu_plus1.gMenuLineNum
		end

		ingame_menu_plus1.gDialogBoxAngle = F32(ingame_menu_plus1.gDialogBoxAngle + 10.0)
		ingame_menu_plus1.gDialogBoxScale = F32(ingame_menu_plus1.gDialogBoxScale + 2.0)

		if ingame_menu_plus1.gDialogBoxAngle == ingame_menu_plus1.DIALOG_BOX_ANGLE_DEFAULT then
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT
			ingame_menu_plus1.gDialogID = IncludeDialogIdsH.DIALOG_NONE
			ingame_menu_plus1.gDialogPageStartStrIndex = 0
			ingame_menu_plus1.gDialogWithChoice = IncludePRUltratypesH.FALSE
			ingame_menu_plus1.gNextDialogPageStartStrIndex = 0
			ingame_menu_plus1.gDialogResponse = ingame_menu_plus1.DIALOG_RESPONSE_NONE
		end

		lowerBound = 1
	end

	ingame_menu_plus1.render_dialog_box_type(dialog, linesPerBox)

	Gbi.gDPSetScissor(
		Gbi.G_SC_NON_INTERLACE,
		ingame_menu_plus1.ensure_nonnegative(Rom.ReadS16(dialog + 6)),
		ingame_menu_plus1.ensure_nonnegative(ingame_menu_plus1.DIAG_VAL2 - Rom.ReadS16(dialog + 8)),
		ingame_menu_plus1.ensure_nonnegative(Rom.ReadS16(dialog + 6) + ingame_menu_plus1.DIAG_VAL3),
		ingame_menu_plus1.ensure_nonnegative((240 - Rom.ReadS16(dialog + 8)) + linesPerBox * 80 // ingame_menu_plus1.DIAG_VAL4)
	)

	ingame_menu_plus1.handle_dialog_text_and_pages(0, dialog, lowerBound)

	if ingame_menu_plus1.gNextDialogPageStartStrIndex == -1 and ingame_menu_plus1.gDialogWithChoice == IncludePRUltratypesH.TRUE then
		ingame_menu_plus1.render_dialog_triangle_choice()
	end

	Gbi.gDPSetScissor(Gbi.G_SC_NON_INTERLACE, 2, 2, IncludeConfigH.SCREEN_WIDTH - IncludeConfigH.BORDER_HEIGHT // 2, IncludeConfigH.SCREEN_HEIGHT - IncludeConfigH.BORDER_HEIGHT // 2)

	if ingame_menu_plus1.gNextDialogPageStartStrIndex ~= -1 and ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_DIALOG_OPEN then
		ingame_menu_plus1.render_dialog_triangle_next(linesPerBox)
	end
end

-- from src/game/ingame_menu.c:set_menu_mode L2156-2160
function ingame_menu_plus1.set_menu_mode(mode: number)
	mode = S16(TruncS32(mode))
	if ingame_menu_plus1.gMenuMode == ingame_menu_plus1.MENU_MODE_NONE then
		ingame_menu_plus1.gMenuMode = mode
	end
end

-- from src/game/ingame_menu.c:reset_cutscene_msg_fade L2162-2164
function ingame_menu_plus1.reset_cutscene_msg_fade()
	ingame_menu_plus1.gCutsceneMsgFade = 0
end

-- from src/game/ingame_menu.c:dl_rgba16_begin_cutscene_msg_fade L2166-2169
function ingame_menu_plus1.dl_rgba16_begin_cutscene_msg_fade()
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gCutsceneMsgFade)
end

-- from src/game/ingame_menu.c:dl_rgba16_stop_cutscene_msg_fade L2171-2179
function ingame_menu_plus1.dl_rgba16_stop_cutscene_msg_fade()
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	if ingame_menu_plus1.gCutsceneMsgFade < 250 then
		ingame_menu_plus1.gCutsceneMsgFade = U16(ingame_menu_plus1.gCutsceneMsgFade + 25)
	else
		ingame_menu_plus1.gCutsceneMsgFade = 255
	end
end

-- from src/game/ingame_menu.c:ascii_to_credits_char L2181-2211
function ingame_menu_plus1.ascii_to_credits_char(c: number): number
	c = U8(TruncS32(c))
	-- 'A' to 'Z' (65 to 90) map to 10 to 35.
	if c >= 65 and c <= 90 then
		return U8(c - (65 - 0xA))
	end

	-- remap lower to upper case: 'a' to 'z' (97 to 122)
	if c >= 97 and c <= 122 then
		return U8(c - (97 - 0xA))
	end

	if c == 32 then
		return ingame_menu_plus1.GLOBAL_CHAR_SPACE
	end

	if c == 46 then
		return 0x24
	end

	if c == 51 then
		return ingame_menu_plus1.ASCII_TO_DIALOG(51)
	end

	if c == 52 then
		return ingame_menu_plus1.ASCII_TO_DIALOG(52)
	end

	if c == 54 then
		return ingame_menu_plus1.ASCII_TO_DIALOG(54)
	end

	return ingame_menu_plus1.GLOBAL_CHAR_SPACE
end

-- from src/game/ingame_menu.c:print_credits_str_ascii L2213-2226
function ingame_menu_plus1.print_credits_str_ascii(x: number, y: number, str: string)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	local pos = 0
	local c = string.byte(str, pos + 1) or 0

	while c ~= 0 do
		buffer.writeu8(Scratch.creditStr, pos, ingame_menu_plus1.ascii_to_credits_char(c))
		pos += 1
		c = string.byte(str, pos + 1) or 0
	end

	buffer.writeu8(Scratch.creditStr, pos, ingame_menu_plus1.GLOBAL_CHAR_TERMINATOR)

	ingame_menu_plus1.print_credits_string(x, y, Scratch.creditStr)
end

-- from src/game/ingame_menu.c:set_cutscene_message L2228-2238
function ingame_menu_plus1.set_cutscene_message(xOffset: number, yOffset: number, msgIndex: number, msgDuration: number)
	xOffset = S16(TruncS32(xOffset))
	yOffset = S16(TruncS32(yOffset))
	msgIndex = S16(TruncS32(msgIndex))
	msgDuration = S16(TruncS32(msgDuration))
	-- is message done printing?
	if ingame_menu_plus1.gCutsceneMsgIndex == -1 then
		ingame_menu_plus1.gCutsceneMsgIndex = msgIndex
		ingame_menu_plus1.gCutsceneMsgDuration = msgDuration
		ingame_menu_plus1.gCutsceneMsgTimer = 0
		ingame_menu_plus1.gCutsceneMsgXOffset = xOffset
		ingame_menu_plus1.gCutsceneMsgYOffset = yOffset
		ingame_menu_plus1.gCutsceneMsgFade = 0
	end
end

-- from src/game/ingame_menu.c:do_cutscene_handler L2240-2302
function ingame_menu_plus1.do_cutscene_handler()
	-- is a cutscene playing? do not perform this handler's actions if so.
	if ingame_menu_plus1.gCutsceneMsgIndex == -1 then
		return
	end

	ingame_menu_plus1.create_dl_ortho_matrix()

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gCutsceneMsgFade)

	-- get the x coordinate of where the cutscene string starts.
	const msgStr = ingame_menu_plus1.gEndCutsceneStringsEn[ingame_menu_plus1.gCutsceneMsgIndex + 1]
	const x = ingame_menu_plus1.get_str_x_pos_from_center(ingame_menu_plus1.gCutsceneMsgXOffset, msgStr, 10.0)

	ingame_menu_plus1.print_generic_string(x, 240 - ingame_menu_plus1.gCutsceneMsgYOffset, msgStr)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	-- if the timing variable is less than 5, increment
	-- the fade until we are at full opacity.
	if ingame_menu_plus1.gCutsceneMsgTimer < 5 then
		ingame_menu_plus1.gCutsceneMsgFade = U16(ingame_menu_plus1.gCutsceneMsgFade + 50)
	end

	-- if the cutscene frame length + the fade-in counter is
	-- less than the timer, it means we have exceeded the
	-- time that the message is supposed to remain on
	-- screen. if (message_duration = 50) and (msg_timer = 55)
	-- then after the first 5 frames, the message will remain
	-- on screen for another 50 frames until it starts fading.
	if ingame_menu_plus1.gCutsceneMsgDuration + 5 < ingame_menu_plus1.gCutsceneMsgTimer then
		ingame_menu_plus1.gCutsceneMsgFade = U16(ingame_menu_plus1.gCutsceneMsgFade - 50)
	end

	-- like the first check, it takes 5 frames to fade out, so
	-- perform a + 10 to account for the earlier check (10-5=5).
	if ingame_menu_plus1.gCutsceneMsgDuration + 10 < ingame_menu_plus1.gCutsceneMsgTimer then
		ingame_menu_plus1.gCutsceneMsgIndex = -1
		ingame_menu_plus1.gCutsceneMsgFade = 0
		ingame_menu_plus1.gCutsceneMsgTimer = 0

		return
	end

	ingame_menu_plus1.gCutsceneMsgTimer = S16(ingame_menu_plus1.gCutsceneMsgTimer + 1)
end

-- from src/game/ingame_menu.c:print_peach_letter_message L2319-2388
function ingame_menu_plus1.print_peach_letter_message()
	const dialogTable = SrcGameMemory.segmented_to_virtual(Symbols.Seg2DialogTable)
	const dialog = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(dialogTable + 4 * ingame_menu_plus1.gDialogID))

	ingame_menu_plus1.CopyRomString(Scratch.dialogStr, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(dialog + 12)))

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, 97.0, 118.0, 0)

	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gCutsceneMsgFade)
	Gbi.gSPDisplayList(castle_grounds_seg7_dl_0700EA58)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(20, 20, 20, ingame_menu_plus1.gCutsceneMsgFade)

	ingame_menu_plus1.print_generic_string(ingame_menu_plus1.STR_X, ingame_menu_plus1.STR_Y, Scratch.dialogStr)
	Gbi.gDPSetEnvColor(255, 255, 255, 255)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
	Gbi.gDPSetEnvColor(200, 80, 120, ingame_menu_plus1.gCutsceneMsgFade)
	Gbi.gSPDisplayList(castle_grounds_seg7_us_dl_0700F2E8)

	-- at the start/end of message, reset the fade.
	if ingame_menu_plus1.gCutsceneMsgTimer == 0 then
		ingame_menu_plus1.gCutsceneMsgFade = 0
	end

	-- we're less than 20 increments, so increase the fade.
	if ingame_menu_plus1.gCutsceneMsgTimer < 20 then
		ingame_menu_plus1.gCutsceneMsgFade = U16(ingame_menu_plus1.gCutsceneMsgFade + 10)
	end

	-- we're after PEACH_MESSAGE_TIMER increments, so decrease the fade.
	if ingame_menu_plus1.gCutsceneMsgTimer > ingame_menu_plus1.PEACH_MESSAGE_TIMER then
		ingame_menu_plus1.gCutsceneMsgFade = U16(ingame_menu_plus1.gCutsceneMsgFade - 10)
	end

	-- 20 increments after the start of the decrease, we're
	-- back where we are, so reset everything at the end.
	if ingame_menu_plus1.gCutsceneMsgTimer > ingame_menu_plus1.PEACH_MESSAGE_TIMER + 20 then
		ingame_menu_plus1.gCutsceneMsgIndex = -1
		ingame_menu_plus1.gCutsceneMsgFade = 0
		ingame_menu_plus1.gDialogID = IncludeDialogIdsH.DIALOG_NONE
		ingame_menu_plus1.gCutsceneMsgTimer = 0

		return
	end

	ingame_menu_plus1.gCutsceneMsgTimer = S16(ingame_menu_plus1.gCutsceneMsgTimer + 1)
end

-- from src/game/ingame_menu.c:render_hud_cannon_reticle L2394-2418
function ingame_menu_plus1.render_hud_cannon_reticle()
	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, 160.0, 120.0, 0)

	Gbi.gDPSetEnvColor(50, 50, 50, 180)
	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, -20.0, -8.0, 0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, 20.0, 8.0, 0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 180.0, 0, 0, 1.0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, 8.0, -20.0, 0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 90.0, 0, 0, 1.0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, -8.0, 20.0, 0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, -90.0, 0, 0, 1.0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:reset_red_coins_collected L2420-2422
function ingame_menu_plus1.reset_red_coins_collected()
	ingame_menu_plus1.gRedCoinsCollected = S8(0)
end

-- from src/game/ingame_menu.c:change_dialog_camera_angle L2424-2430
function ingame_menu_plus1.change_dialog_camera_angle()
	const camSelection: number = Registry.Members.src__game__camera.cam_select_alt_mode(0)

	if camSelection == GroupsTypesHPlus3.CAM_SELECTION_MARIO then
		ingame_menu_plus1.gDialogCameraAngleIndex = GroupsTypesHPlus3.CAM_SELECTION_MARIO
	else
		ingame_menu_plus1.gDialogCameraAngleIndex = GroupsTypesHPlus3.CAM_SELECTION_FIXED
	end
end

-- from src/game/ingame_menu.c:shade_screen L2432-2447
function ingame_menu_plus1.shade_screen()
	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_LEFT_EDGE(0), IncludeConfigH.SCREEN_HEIGHT, 0)

	-- This is a bit weird. It reuses the dialog text box (width 130, height -80),
	-- so scale to at least fit the screen.
	ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 2.6, 3.4, 1.0)

	Gbi.gDPSetEnvColor(0, 0, 0, 110)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_text_bg_box)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:print_animated_red_coin L2449-2473
function ingame_menu_plus1.print_animated_red_coin(x: number, y: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	const globalTimer = SrcGameGameInit.gGlobalTimer

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x, y, 0)
	ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 0.2, 0.2, 1.0)
	Gbi.gDPSetRenderMode(Gbi.G_RM_TEX_EDGE, Gbi.G_RM_TEX_EDGE2)

	const frame = bit32.band(globalTimer, 6)

	if frame == 0 then
		Gbi.gSPDisplayList(coin_seg3_dl_03007940)
	elseif frame == 2 then
		Gbi.gSPDisplayList(coin_seg3_dl_03007968)
	elseif frame == 4 then
		Gbi.gSPDisplayList(coin_seg3_dl_03007990)
	elseif frame == 6 then
		Gbi.gSPDisplayList(coin_seg3_dl_030079B8)
	end

	Gbi.gDPSetRenderMode(Gbi.G_RM_AA_ZB_OPA_SURF, Gbi.G_RM_AA_ZB_OPA_SURF2)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:render_pause_red_coins L2475-2481
function ingame_menu_plus1.render_pause_red_coins()
	for x = 0, ingame_menu_plus1.gRedCoinsCollected - 1 do
		ingame_menu_plus1.print_animated_red_coin(IncludeGfxDimensionsH.GFX_DIMENSIONS_FROM_RIGHT_EDGE(30) - x * 20, 16)
	end
end

-- from src/game/ingame_menu.c:render_pause_my_score_coins L2526-2619
function ingame_menu_plus1.render_pause_my_score_coins()
	const courseNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_course_name_table)
	const actNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_act_name_table)
	const courseIndex = U8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum))
	const starFlags = U8(SrcGameSaveFile.save_file_get_star_flags(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	if courseIndex <= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) then
		ingame_menu_plus1.print_hud_my_score_coins(1, SrcGameArea.gCurrSaveFileNum - 1, courseIndex, 178, 103)
		ingame_menu_plus1.print_hud_my_score_stars(SrcGameArea.gCurrSaveFileNum - 1, courseIndex, 118, 103)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	if courseIndex <= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) and SrcGameSaveFile.save_file_get_course_star_count(SrcGameArea.gCurrSaveFileNum - 1, courseIndex) ~= 0 then
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.MYSCORE_X, 121, IncludeTextStringsH.TEXT_MY_SCORE)
	end

	-- courseName[CRS_NAME_START] is the only part of the name the C prints
	ingame_menu_plus1.CopyRomString(Scratch.courseName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(courseNameTbl + 4 * courseIndex)) + ingame_menu_plus1.CRS_NAME_START)

	if courseIndex <= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) then
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.TXT_COURSE_X, 157, IncludeTextStringsH.TEXT_COURSE)
		ingame_menu_plus1.INT_TO_STR_DIFF(SrcGameArea.gCurrCourseNum, Scratch.strCourseNum)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.CRS_NUM_X1, 157, Scratch.strCourseNum)

		ingame_menu_plus1.CopyRomString(Scratch.actName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(actNameTbl + 4 * (IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum) * 6 + ingame_menu_plus1.gDialogCourseActNum - 1))))

		if bit32.btest(starFlags, bit32.lshift(1, ingame_menu_plus1.gDialogCourseActNum - 1)) then
			ingame_menu_plus1.print_generic_string(ingame_menu_plus1.TXT_STAR_X, 140, IncludeTextStringsH.TEXT_STAR_DIFF)
		else
			ingame_menu_plus1.print_generic_string(ingame_menu_plus1.TXT_STAR_X, 140, IncludeTextStringsH.TEXT_UNFILLED_STAR)
		end

		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.ACT_NAME_X, 140, Scratch.actName)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.CRS_NAME_X, 157, Scratch.courseName)
	else
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.SECRET_CRS_NAME_X, 157, Scratch.courseName)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/game/ingame_menu.c:render_pause_camera_options L2631-2679
function ingame_menu_plus1.render_pause_camera_options(x: number, y: number, index: { number }, xIndex: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	xIndex = S16(TruncS32(xIndex))
	ingame_menu_plus1.handle_menu_scrolling(ingame_menu_plus1.MENU_SCROLL_HORIZONTAL, index, 1, 2)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	ingame_menu_plus1.print_generic_string(x + 14, y + 2, IncludeTextStringsH.TEXT_LAKITU_MARIO)
	ingame_menu_plus1.print_generic_string(x + ingame_menu_plus1.TXT1_X, y - 13, IncludeTextStringsH.TEXT_NORMAL_UPCLOSE)
	ingame_menu_plus1.print_generic_string(x + 124, y + 2, IncludeTextStringsH.TEXT_LAKITU_STOP)
	ingame_menu_plus1.print_generic_string(x + ingame_menu_plus1.TXT2_X, y - 13, IncludeTextStringsH.TEXT_NORMAL_FIXED)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x + (index[1] - 1) * xIndex, y + ingame_menu_plus1.Y_VAL7, 0)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	if index[1] == GroupsTypesHPlus3.CAM_SELECTION_MARIO then
		Registry.Members.src__game__camera.cam_select_alt_mode(GroupsTypesHPlus3.CAM_SELECTION_MARIO)
	elseif index[1] == GroupsTypesHPlus3.CAM_SELECTION_FIXED then
		Registry.Members.src__game__camera.cam_select_alt_mode(GroupsTypesHPlus3.CAM_SELECTION_FIXED)
	end
end

-- from src/game/ingame_menu.c:render_pause_course_options L2698-2743
function ingame_menu_plus1.render_pause_course_options(x: number, y: number, index: { number }, yIndex: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	yIndex = S16(TruncS32(yIndex))
	ingame_menu_plus1.handle_menu_scrolling(ingame_menu_plus1.MENU_SCROLL_VERTICAL, index, 1, 3)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	ingame_menu_plus1.print_generic_string(x + 10, y - 2, IncludeTextStringsH.TEXT_CONTINUE)
	ingame_menu_plus1.print_generic_string(x + 10, y - ingame_menu_plus1.Y_OFFSET1, IncludeTextStringsH.TEXT_EXIT_COURSE)

	if index[1] ~= GroupsTypesHPlus3.MENU_OPT_CAMERA_ANGLE_R then
		ingame_menu_plus1.print_generic_string(x + 10, y - ingame_menu_plus1.Y_OFFSET2, IncludeTextStringsH.TEXT_CAMERA_ANGLE_R)
		Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

		ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x - ingame_menu_plus1.X_VAL8, (y - (index[1] - 1) * yIndex) - ingame_menu_plus1.Y_VAL8, 0)

		Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
		Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
		Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	end

	if index[1] == GroupsTypesHPlus3.MENU_OPT_CAMERA_ANGLE_R then
		Scratch.gDialogCameraAngleIndex[1] = ingame_menu_plus1.gDialogCameraAngleIndex
		ingame_menu_plus1.render_pause_camera_options(S16(x - 42), S16(y - 42), Scratch.gDialogCameraAngleIndex, 110)
		ingame_menu_plus1.gDialogCameraAngleIndex = Scratch.gDialogCameraAngleIndex[1]
	end
end

-- from src/game/ingame_menu.c:render_pause_castle_menu_box L2745-2762
function ingame_menu_plus1.render_pause_castle_menu_box(x: number, y: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x - 78, y - 32, 0)
	ingame_menu_plus1.create_dl_scale_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 1.2, 0.8, 1.0)
	Gbi.gDPSetEnvColor(0, 0, 0, 105)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_text_bg_box)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x + 6, y - 28, 0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 90.0, 0, 0, 1.0)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x - 9, y - 101, 0)
	ingame_menu_plus1.create_dl_rotation_matrix(ingame_menu_plus1.MENU_MTX_NOPUSH, 270.0, 0, 0, 1.0)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:highlight_last_course_complete_stars L2764-2778
function ingame_menu_plus1.highlight_last_course_complete_stars()
	local completedCourseIndex = 0

	if SrcGameSaveFile.gLastCompletedCourseNum == IncludeCourseTableH.COURSE_NONE then
		completedCourseIndex = 0
	else
		completedCourseIndex = U8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameSaveFile.gLastCompletedCourseNum))

		if completedCourseIndex >= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES) then
			completedCourseIndex = U8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES))
		end
	end

	ingame_menu_plus1.gMenuLineNum = S8(completedCourseIndex)
end

-- from src/game/ingame_menu.c:print_hud_pause_colorful_str L2788-2797
function ingame_menu_plus1.print_hud_pause_colorful_str()
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, ingame_menu_plus1.PAUSE_X, 81, IncludeTextStringsH.TEXT_PAUSE)

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)
end

-- from src/game/ingame_menu.c:render_pause_castle_course_stars L2799-2868
function ingame_menu_plus1.render_pause_castle_course_stars(x: number, y: number, fileIndex: number, courseIndex: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	fileIndex = S16(TruncS32(fileIndex))
	courseIndex = S16(TruncS32(courseIndex))
	local hasStar = 0
	const str = Scratch.castleCourseStars
	const starFlags = U8(SrcGameSaveFile.save_file_get_star_flags(fileIndex, courseIndex))
	local starCount = U16(SrcGameSaveFile.save_file_get_course_star_count(fileIndex, courseIndex))
	local nextStar = 0

	if bit32.btest(starFlags, bit32.lshift(1, 6)) then
		starCount = U16(starCount - 1)
		ingame_menu_plus1.print_generic_string(x + 89, y - 5, IncludeTextStringsH.TEXT_STAR)
	end

	while hasStar ~= starCount do
		if bit32.btest(starFlags, bit32.lshift(1, nextStar)) then
			buffer.writeu8(str, nextStar * 2, ingame_menu_plus1.DIALOG_CHAR_STAR_FILLED)
			hasStar = S16(hasStar + 1)
		else
			buffer.writeu8(str, nextStar * 2, ingame_menu_plus1.DIALOG_CHAR_STAR_OPEN)
		end

		buffer.writeu8(str, nextStar * 2 + 1, ingame_menu_plus1.DIALOG_CHAR_SPACE)
		nextStar = U16(nextStar + 1)
	end

	if starCount == nextStar and starCount ~= 6 then
		buffer.writeu8(str, nextStar * 2, ingame_menu_plus1.DIALOG_CHAR_STAR_OPEN)
		buffer.writeu8(str, nextStar * 2 + 1, ingame_menu_plus1.DIALOG_CHAR_SPACE)
		nextStar = U16(nextStar + 1)
	end

	buffer.writeu8(str, nextStar * 2, ingame_menu_plus1.DIALOG_CHAR_TERMINATOR)

	ingame_menu_plus1.print_generic_string(x + 14, y + 13, str)
end

-- from src/game/ingame_menu.c:render_pause_castle_main_strings L2870-2963
function ingame_menu_plus1.render_pause_castle_main_strings(x: number, y: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	const prevCourseIndex = ingame_menu_plus1.gMenuLineNum

	Scratch.gMenuLineNum[1] = ingame_menu_plus1.gMenuLineNum
	ingame_menu_plus1.handle_menu_scrolling(ingame_menu_plus1.MENU_SCROLL_VERTICAL, Scratch.gMenuLineNum, S8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN) - 1), S8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES) + 1))
	ingame_menu_plus1.gMenuLineNum = Scratch.gMenuLineNum[1]

	if ingame_menu_plus1.gMenuLineNum == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES) + 1 then
		ingame_menu_plus1.gMenuLineNum = S8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN))
	end

	if ingame_menu_plus1.gMenuLineNum == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN) - 1 then
		ingame_menu_plus1.gMenuLineNum = S8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES))
	end

	if ingame_menu_plus1.gMenuLineNum ~= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES) then
		while SrcGameSaveFile.save_file_get_course_star_count(SrcGameArea.gCurrSaveFileNum - 1, ingame_menu_plus1.gMenuLineNum) == 0 do
			if ingame_menu_plus1.gMenuLineNum >= prevCourseIndex then
				ingame_menu_plus1.gMenuLineNum = S8(ingame_menu_plus1.gMenuLineNum + 1)
			else
				ingame_menu_plus1.gMenuLineNum = S8(ingame_menu_plus1.gMenuLineNum - 1)
			end

			if ingame_menu_plus1.gMenuLineNum == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) + 1 or ingame_menu_plus1.gMenuLineNum == IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN) - 1 then
				ingame_menu_plus1.gMenuLineNum = S8(IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_BONUS_STAGES))

				break
			end
		end
	end

	const courseNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_course_name_table)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	if ingame_menu_plus1.gMenuLineNum <= IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_STAGES_MAX) then -- Main courses
		ingame_menu_plus1.CopyRomString(Scratch.courseName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(courseNameTbl + 4 * ingame_menu_plus1.gMenuLineNum)))
		ingame_menu_plus1.render_pause_castle_course_stars(x, y, SrcGameArea.gCurrSaveFileNum - 1, ingame_menu_plus1.gMenuLineNum)
		ingame_menu_plus1.print_generic_string(x + 34, y - 5, IncludeTextStringsH.TEXT_COIN_X)
		ingame_menu_plus1.INT_TO_STR_DIFF(SrcGameSaveFile.save_file_get_course_coin_score(SrcGameArea.gCurrSaveFileNum - 1, ingame_menu_plus1.gMenuLineNum), Scratch.strVal)
		ingame_menu_plus1.print_generic_string(x + 54, y - 5, Scratch.strVal)
	else -- Castle secret stars
		ingame_menu_plus1.CopyRomString(Scratch.courseName, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(courseNameTbl + 4 * IncludeCourseTableH.COURSE_MAX)))
		ingame_menu_plus1.print_generic_string(x + 40, y + 13, IncludeTextStringsH.TEXT_STAR_X)
		ingame_menu_plus1.INT_TO_STR_DIFF(SrcGameSaveFile.save_file_get_total_star_count(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_BONUS_STAGES - 1, IncludeCourseTableH.COURSE_MAX - 1), Scratch.strVal)
		ingame_menu_plus1.print_generic_string(x + 60, y + 13, Scratch.strVal)
	end

	ingame_menu_plus1.print_generic_string(x - 9, y + 30, Scratch.courseName)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/game/ingame_menu.c:render_pause_screen L2970-3052
function ingame_menu_plus1.render_pause_screen(): number
	local index = 0

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_PAUSE_SCREEN_OPENING then
		ingame_menu_plus1.gMenuLineNum = GroupsTypesHPlus3.MENU_OPT_DEFAULT
		ingame_menu_plus1.gMenuTextAlpha = 0
		SrcGameLevelUpdate.level_set_transition(-1, nil)
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_PAUSE, Audio.gGlobalSoundSource)

		if SrcGameArea.gCurrCourseNum >= IncludeCourseTableH.COURSE_MIN and SrcGameArea.gCurrCourseNum <= IncludeCourseTableH.COURSE_MAX then
			ingame_menu_plus1.change_dialog_camera_angle()
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_PAUSE_SCREEN_COURSE
		else
			ingame_menu_plus1.highlight_last_course_complete_stars()
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_PAUSE_SCREEN_CASTLE
		end
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_PAUSE_SCREEN_COURSE then
		ingame_menu_plus1.shade_screen()
		ingame_menu_plus1.render_pause_my_score_coins()
		ingame_menu_plus1.render_pause_red_coins()

		if bit32.btest(SrcGameLevelUpdate.gMarioStates[1].action, Registry.Members.include__sm64_h.ACT_FLAG_PAUSE_EXIT) then
			Scratch.gMenuLineNum[1] = ingame_menu_plus1.gMenuLineNum
			ingame_menu_plus1.render_pause_course_options(99, 93, Scratch.gMenuLineNum, 15)
			ingame_menu_plus1.gMenuLineNum = Scratch.gMenuLineNum[1]
		end

		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(Registry.Members.include__PR__os_h.A_BUTTON, Registry.Members.include__PR__os_h.START_BUTTON)) then
			SrcGameLevelUpdate.level_set_transition(0, nil)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_PAUSE_2, Audio.gGlobalSoundSource)
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT
			ingame_menu_plus1.gMenuMode = ingame_menu_plus1.MENU_MODE_NONE

			if ingame_menu_plus1.gMenuLineNum == GroupsTypesHPlus3.MENU_OPT_EXIT_COURSE then
				index = ingame_menu_plus1.gMenuLineNum
			else
				index = GroupsTypesHPlus3.MENU_OPT_DEFAULT
			end

			return index
		end
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_PAUSE_SCREEN_CASTLE then
		ingame_menu_plus1.shade_screen()
		ingame_menu_plus1.print_hud_pause_colorful_str()
		ingame_menu_plus1.render_pause_castle_menu_box(160, 143)
		ingame_menu_plus1.render_pause_castle_main_strings(104, 60)

		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(Registry.Members.include__PR__os_h.A_BUTTON, Registry.Members.include__PR__os_h.START_BUTTON)) then
			SrcGameLevelUpdate.level_set_transition(0, nil)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_PAUSE_2, Audio.gGlobalSoundSource)
			ingame_menu_plus1.gMenuMode = ingame_menu_plus1.MENU_MODE_NONE
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT

			return GroupsTypesHPlus3.MENU_OPT_DEFAULT
		end
	end

	if ingame_menu_plus1.gMenuTextAlpha < 250 then
		ingame_menu_plus1.gMenuTextAlpha = U16(ingame_menu_plus1.gMenuTextAlpha + 25)
	end

	return GroupsTypesHPlus3.MENU_OPT_NONE
end

-- from src/game/ingame_menu.c:print_hud_course_complete_string L3084-3113
function ingame_menu_plus1.print_hud_course_complete_string(str: number)
	str = S8(TruncS32(str))
	const color = U8(TruncS32(F32(F32(SrcEngineMathUtilH.sins(ingame_menu_plus1.gMenuTextColorTransTimer) * 50.0) + 200.0)))

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(color, color, color, 255)

	if str == ingame_menu_plus1.HUD_PRINT_HISCORE then
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, ingame_menu_plus1.TXT_HISCORE_X, ingame_menu_plus1.TXT_HISCORE_Y, IncludeTextStringsH.TEXT_HUD_HI_SCORE)
	else -- HUD_PRINT_CONGRATULATIONS
		ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, ingame_menu_plus1.TXT_CONGRATS_X, ingame_menu_plus1.TXT_CONGRATS_Y, IncludeTextStringsH.TEXT_HUD_CONGRATULATIONS)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)
end

-- from src/game/ingame_menu.c:print_hud_course_complete_coins L3115-3153
function ingame_menu_plus1.print_hud_course_complete_coins(x: number, y: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, 255)

	ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x, y, ingame_menu_plus1.gHudSymCoin)
	ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 16, y, ingame_menu_plus1.gHudSymX)

	ingame_menu_plus1.int_to_str(ingame_menu_plus1.gCourseCompleteCoins, Scratch.courseCompleteCoinsStr)
	ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, x + 32, y, Scratch.courseCompleteCoinsStr)

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	if ingame_menu_plus1.gCourseCompleteCoins >= SrcGameLevelUpdate.gHudDisplay.coins then
		ingame_menu_plus1.gCourseCompleteCoinsEqual = IncludePRUltratypesH.TRUE
		ingame_menu_plus1.gCourseCompleteCoins = SrcGameLevelUpdate.gHudDisplay.coins

		if SrcGameSaveFile.gGotFileCoinHiScore ~= 0 then
			ingame_menu_plus1.print_hud_course_complete_string(ingame_menu_plus1.HUD_PRINT_HISCORE)
		end
	else
		if bit32.btest(ingame_menu_plus1.gCourseCompleteScreenTimer, 1) or SrcGameLevelUpdate.gHudDisplay.coins > 70 then
			ingame_menu_plus1.gCourseCompleteCoins = S32(ingame_menu_plus1.gCourseCompleteCoins + 1)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_YOSHI_GAIN_LIVES, Audio.gGlobalSoundSource)

			if ingame_menu_plus1.gCourseCompleteCoins == 50 or ingame_menu_plus1.gCourseCompleteCoins == 100 or ingame_menu_plus1.gCourseCompleteCoins == 150 then
				Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_COLLECT_1UP, Audio.gGlobalSoundSource)
				SrcGameLevelUpdate.gMarioState.numLives = S8(SrcGameLevelUpdate.gMarioState.numLives + 1)
			end
		end

		if ingame_menu_plus1.gCourseCompleteCoins == SrcGameLevelUpdate.gHudDisplay.coins and SrcGameSaveFile.gGotFileCoinHiScore ~= 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_MARIO_CASTLE_WARP2, Audio.gGlobalSoundSource)
		end
	end
end

-- from src/game/ingame_menu.c:play_star_fanfare_and_flash_hud L3155-3160
function ingame_menu_plus1.play_star_fanfare_and_flash_hud(arg: number, starFlag: number)
	starFlag = U8(TruncS32(starFlag))
	if ingame_menu_plus1.gCourseCompleteCoins == SrcGameLevelUpdate.gHudDisplay.coins and not bit32.btest(SrcGameSaveFile.gCurrCourseStarFlags, starFlag) and ingame_menu_plus1.gHudFlash == 0 then
		Audio.play_star_fanfare()
		ingame_menu_plus1.gHudFlash = S8(arg)
	end
end

-- from src/game/ingame_menu.c:render_course_complete_lvl_info_and_hud_str L3182-3308
function ingame_menu_plus1.render_course_complete_lvl_info_and_hud_str()
	const actNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_act_name_table)
	const courseNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_course_name_table)
	const name = Scratch.actName

	if SrcGameSaveFile.gLastCompletedCourseNum <= IncludeCourseTableH.COURSE_STAGES_MAX then
		ingame_menu_plus1.print_hud_course_complete_coins(118, 103)
		ingame_menu_plus1.play_star_fanfare_and_flash_hud(1, U8(bit32.lshift(1, SrcGameSaveFile.gLastCompletedStarNum - 1)))

		if SrcGameSaveFile.gLastCompletedStarNum == 7 then
			ingame_menu_plus1.CopyRomString(name, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(actNameTbl + 4 * (IncludeCourseTableH.COURSE_STAGES_MAX * 6 + 1))))
		else
			ingame_menu_plus1.CopyRomString(name, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(actNameTbl + 4 * (IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameSaveFile.gLastCompletedCourseNum) * 6 + SrcGameSaveFile.gLastCompletedStarNum - 1))))
		end

		-- Print course number
		Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

		ingame_menu_plus1.INT_TO_STR_DIFF(SrcGameSaveFile.gLastCompletedCourseNum, Scratch.strCourseNum)

		Gbi.gDPSetEnvColor(0, 0, 0, ingame_menu_plus1.gMenuTextAlpha)
		ingame_menu_plus1.print_generic_string(65, 165, IncludeTextStringsH.TEXT_COURSE)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.CRS_NUM_X2, 165, Scratch.strCourseNum)

		Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
		ingame_menu_plus1.print_generic_string(63, 167, IncludeTextStringsH.TEXT_COURSE)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.CRS_NUM_X3, 167, Scratch.strCourseNum)

		Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
	elseif SrcGameSaveFile.gLastCompletedCourseNum == IncludeCourseTableH.COURSE_BITDW or SrcGameSaveFile.gLastCompletedCourseNum == IncludeCourseTableH.COURSE_BITFS then
		ingame_menu_plus1.CopyRomString(name, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(courseNameTbl + 4 * IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameSaveFile.gLastCompletedCourseNum))))

		-- Print course name and clear text
		Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

		Gbi.gDPSetEnvColor(0, 0, 0, ingame_menu_plus1.gMenuTextAlpha)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.TXT_NAME_X1, 130, name)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.get_string_width(name) + 81, 130, IncludeTextStringsH.TEXT_CLEAR)

		Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.TXT_NAME_X2, 132, name)
		ingame_menu_plus1.print_generic_string(ingame_menu_plus1.get_string_width(name) + 81 - 2, 132, IncludeTextStringsH.TEXT_CLEAR)

		Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

		ingame_menu_plus1.print_hud_course_complete_string(ingame_menu_plus1.HUD_PRINT_CONGRATULATIONS)
		ingame_menu_plus1.print_hud_course_complete_coins(118, 111)
		ingame_menu_plus1.play_star_fanfare_and_flash_hud(2, 0)

		return
	else -- Castle secret stars
		ingame_menu_plus1.CopyRomString(name, SrcGameMemory.segmented_to_virtual(Rom.ReadU32(actNameTbl + 4 * (IncludeCourseTableH.COURSE_STAGES_MAX * 6))))

		ingame_menu_plus1.print_hud_course_complete_coins(118, 103)
		ingame_menu_plus1.play_star_fanfare_and_flash_hud(1, U8(bit32.lshift(1, SrcGameSaveFile.gLastCompletedStarNum - 1)))
	end

	-- Print star glyph
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)

	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
	ingame_menu_plus1.print_hud_lut_string(ingame_menu_plus1.HUD_LUT_GLOBAL, 55, 77, TextSymStar)

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	-- Print act name and catch text
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)

	Gbi.gDPSetEnvColor(0, 0, 0, ingame_menu_plus1.gMenuTextAlpha)
	ingame_menu_plus1.print_generic_string(76, 145, name)

	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
	ingame_menu_plus1.print_generic_string(74, 147, name)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
end

-- from src/game/ingame_menu.c:render_save_confirmation L3332-3375
function ingame_menu_plus1.render_save_confirmation(x: number, y: number, index: { number }, yOffset: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	yOffset = S16(TruncS32(yOffset))
	ingame_menu_plus1.handle_menu_scrolling(ingame_menu_plus1.MENU_SCROLL_VERTICAL, index, 1, 3)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)

	ingame_menu_plus1.print_generic_string(x + 12, y + ingame_menu_plus1.TXT_SAVECONT_Y, IncludeTextStringsH.TEXT_SAVE_AND_CONTINUE)
	ingame_menu_plus1.print_generic_string(x + 12, y - ingame_menu_plus1.TXT_SAVEQUIT_Y, IncludeTextStringsH.TEXT_SAVE_AND_QUIT)
	ingame_menu_plus1.print_generic_string(x + 12, y - ingame_menu_plus1.TXT_CONTNOSAVE_Y, IncludeTextStringsH.TEXT_CONTINUE_WITHOUT_SAVING)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)

	ingame_menu_plus1.create_dl_translation_matrix(ingame_menu_plus1.MENU_MTX_PUSH, x, y - (index[1] - 1) * yOffset, 0)

	Gbi.gDPSetEnvColor(255, 255, 255, ingame_menu_plus1.gMenuTextAlpha)
	Gbi.gSPDisplayList(Segment2Symbols.dl_draw_triangle)

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
end

-- from src/game/ingame_menu.c:render_course_complete_screen L3377-3432
function ingame_menu_plus1.render_course_complete_screen(): number
	local index = 0

	if ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_COURSE_COMPLETE_SCREEN_OPENING then
		ingame_menu_plus1.render_course_complete_lvl_info_and_hud_str()

		if ingame_menu_plus1.gCourseCompleteScreenTimer > 100 and ingame_menu_plus1.gCourseCompleteCoinsEqual == IncludePRUltratypesH.TRUE then
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_COURSE_COMPLETE_SCREEN_OPEN
			SrcGameLevelUpdate.level_set_transition(-1, nil)
			ingame_menu_plus1.gMenuTextAlpha = 0
			ingame_menu_plus1.gMenuLineNum = GroupsTypesHPlus3.MENU_OPT_DEFAULT
		end
	elseif ingame_menu_plus1.gMenuState == ingame_menu_plus1.MENU_STATE_COURSE_COMPLETE_SCREEN_OPEN then
		ingame_menu_plus1.shade_screen()
		ingame_menu_plus1.render_course_complete_lvl_info_and_hud_str()

		Scratch.gMenuLineNum[1] = ingame_menu_plus1.gMenuLineNum
		ingame_menu_plus1.render_save_confirmation(100, 86, Scratch.gMenuLineNum, 20)
		ingame_menu_plus1.gMenuLineNum = Scratch.gMenuLineNum[1]

		if ingame_menu_plus1.gCourseCompleteScreenTimer > 110 and bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(Registry.Members.include__PR__os_h.A_BUTTON, Registry.Members.include__PR__os_h.START_BUTTON)) then
			SrcGameLevelUpdate.level_set_transition(0, nil)
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
			ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT
			ingame_menu_plus1.gMenuMode = ingame_menu_plus1.MENU_MODE_NONE
			index = ingame_menu_plus1.gMenuLineNum
			ingame_menu_plus1.gCourseCompleteScreenTimer = 0
			ingame_menu_plus1.gCourseCompleteCoins = 0
			ingame_menu_plus1.gCourseCompleteCoinsEqual = IncludePRUltratypesH.FALSE
			ingame_menu_plus1.gHudFlash = 0

			return index
		end
	end

	if ingame_menu_plus1.gMenuTextAlpha < 250 then
		ingame_menu_plus1.gMenuTextAlpha = U16(ingame_menu_plus1.gMenuTextAlpha + 25)
	end

	ingame_menu_plus1.gCourseCompleteScreenTimer = S32(ingame_menu_plus1.gCourseCompleteScreenTimer + 1)

	return GroupsTypesHPlus3.MENU_OPT_NONE
end

-- from src/game/ingame_menu.c:render_menus_and_dialogs L3434-3468
function ingame_menu_plus1.render_menus_and_dialogs(): number
	local index = GroupsTypesHPlus3.MENU_OPT_NONE

	ingame_menu_plus1.create_dl_ortho_matrix()

	if ingame_menu_plus1.gMenuMode ~= ingame_menu_plus1.MENU_MODE_NONE then
		if ingame_menu_plus1.gMenuMode == ingame_menu_plus1.MENU_MODE_UNUSED_0 then
			index = ingame_menu_plus1.render_pause_screen()
		elseif ingame_menu_plus1.gMenuMode == ingame_menu_plus1.MENU_MODE_RENDER_PAUSE_SCREEN then
			index = ingame_menu_plus1.render_pause_screen()
		elseif ingame_menu_plus1.gMenuMode == ingame_menu_plus1.MENU_MODE_RENDER_COURSE_COMPLETE_SCREEN then
			index = ingame_menu_plus1.render_course_complete_screen()
		elseif ingame_menu_plus1.gMenuMode == ingame_menu_plus1.MENU_MODE_UNUSED_3 then
			index = ingame_menu_plus1.render_course_complete_screen()
		end

		ingame_menu_plus1.gMenuTextColorTransTimer = U16(S16(ingame_menu_plus1.gMenuTextColorTransTimer) + 0x1000)
	elseif ingame_menu_plus1.gDialogID ~= IncludeDialogIdsH.DIALOG_NONE then
		-- The Peach "Dear Mario" message needs to be repositioned separately
		if ingame_menu_plus1.gDialogID == IncludeDialogIdsH.DIALOG_020 then
			ingame_menu_plus1.print_peach_letter_message()

			return index
		end

		ingame_menu_plus1.render_dialog_entries()
		ingame_menu_plus1.gMenuTextColorTransTimer = U16(S16(ingame_menu_plus1.gMenuTextColorTransTimer) + 0x1000)
	end

	return index
end

-- from src/game/ingame_menu.h:ASCII_TO_DIALOG L6-9
function ingame_menu_plus1.ASCII_TO_DIALOG(asc: number): number
	-- '0' to '9' is 48 to 57, 'A' to 'Z' is 65 to 90, 'a' to 'z' is 97 to 122.
	if asc >= 48 and asc <= 57 then
		return asc - 48
	end

	if asc >= 65 and asc <= 90 then
		return asc - 65 + 0x0A
	end

	if asc >= 97 and asc <= 122 then
		return asc - 97 + 0x24
	end

	return 0x00
end

-- from src/game/ingame_menu.h:SPECIAL_CHAR L132-132
function ingame_menu_plus1.SPECIAL_CHAR(x: number): number
	return x
end

-- from src/game/ingame_menu.c:gMenuState L116-116
ingame_menu_plus1.gMenuState = ingame_menu_plus1.MENU_STATE_DEFAULT

-- from src/game/ingame_menu.c:gDialogBoxAngle L117-117
ingame_menu_plus1.gDialogBoxAngle = ingame_menu_plus1.DIALOG_BOX_ANGLE_DEFAULT

-- from src/game/ingame_menu.c:gDialogBoxScale L118-118
ingame_menu_plus1.gDialogBoxScale = ingame_menu_plus1.DIALOG_BOX_SCALE_DEFAULT

-- from src/game/ingame_menu.c:gDialogBoxType L120-120
ingame_menu_plus1.gDialogBoxType = ingame_menu_plus1.DIALOG_TYPE_ROTATE

-- from src/game/ingame_menu.c:gDialogResponse L131-131
ingame_menu_plus1.gDialogResponse = ingame_menu_plus1.DIALOG_RESPONSE_NONE

ingame_menu_plus1.INT_TO_STR_DIFF = ingame_menu_plus1.int_to_str

ingame_menu_plus1.CHAR_WIDTH_SPACE = ingame_menu_plus1.gDialogCharWidths[159] -- gDialogCharWidths[DIALOG_CHAR_SPACE]

-- from src/game/ingame_menu.c:gMenuMode L1851-1851
ingame_menu_plus1.gMenuMode = ingame_menu_plus1.MENU_MODE_NONE

-- from src/game/ingame_menu.c:gEndCutsceneStringsEn L1875-1891
ingame_menu_plus1.gEndCutsceneStringsEn = {
	ingame_menu_plus1.gEndCutsceneStrEn0,
	ingame_menu_plus1.gEndCutsceneStrEn1,
	ingame_menu_plus1.gEndCutsceneStrEn2,
	ingame_menu_plus1.gEndCutsceneStrEn3,
	ingame_menu_plus1.gEndCutsceneStrEn4,
	ingame_menu_plus1.gEndCutsceneStrEn5,
	ingame_menu_plus1.gEndCutsceneStrEn6,
	ingame_menu_plus1.gEndCutsceneStrEn7,
	ingame_menu_plus1.gEndCutsceneStrEn8,
}

return ingame_menu_plus1
