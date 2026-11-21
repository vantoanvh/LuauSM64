--!strict
--!optimize 2

--[[
	Port of src/menu/title_screen.c.
]]

const Registry = require("../../groups/registry")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludePROsH = require("../../include/PR/os_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSeqIdsH = require("../../include/seq_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Audio = require("../rom/audio_recorder")
const Rom = require("../rom/rom")
const SrcGameArea = require("../game/area")
const SrcGameGameInit = require("../game/game_init")
const SrcGameMain = require("../game/main")
const SrcGameMemory = require("../game/memory")
const SrcGamePrint = require("../game/print")
const SrcGameSoundInit = require("../game/sound_init")
const TitleScreenH = require("./title_screen_h")

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/menu/title_screen.c:data
const title_screen = {
	-- from src/menu/title_screen.c:sLevelSelectStageNames L29-31
	sLevelSelectStageNames = {
			"",
			"",
			"",
			"TERESA OBAKE",
			"YYAMA1 % YSLD1",
			"SELECT ROOM",
			"HORROR DUNGEON",
			"SABAKU % PYRMD",
			"BATTLE FIELD",
			"YUKIYAMA2",
			"POOL KAI",
			"WTDG % TINBOTU",
			"BIG WORLD",
			"CLOCK TOWER",
			"RAINBOW CRUISE",
			"MAIN MAP",
			"EXT1 YOKO SCRL",
			"EXT7 HORI MINI",
			"EXT2 TIKA LAVA",
			"EXT9 SUISOU",
			"EXT3 HEAVEN",
			"FIREB1 % INVLC",
			"WATER LAND",
			"MOUNTAIN",
			"ENDING",
			"URANIWA",
			"EXT4 MINI SLID",
			"IN THE FALL",
			"EXT6 MARIO FLY",
			"KUPPA1",
			"EXT8 BLUE SKY",
			"",
			"KUPPA2",
			"KUPPA3",
			"",
			"DONKEY % SLID2",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
		},
	-- from src/menu/title_screen.c:sDemoCountdown L35-35
	sDemoCountdown = 0,
	-- from src/menu/title_screen.c:sPlayMarioGreeting L37-37
	sPlayMarioGreeting = 1,
	-- from src/menu/title_screen.c:sPlayMarioGameOver L38-38
	sPlayMarioGameOver = 1,
	PRESS_START_DEMO_TIMER = 800,
}

Registry.Register("src__menu__title_screen", title_screen)

-- from src/menu/title_screen.c:run_level_id_or_demo L48-79
function title_screen.run_level_id_or_demo(level: number): number
	SrcGameGameInit.gCurrDemoInput = nil

	if level == IncludeLevelTableH.LEVEL_NONE then
		if SrcGameGameInit.gPlayer1Controller.buttonDown == 0 and SrcGameGameInit.gPlayer1Controller.stickMag == 0 then
			-- start the demo. 800 frames has passed while
			-- player is idle on PRESS START screen.
			title_screen.sDemoCountdown = U16(title_screen.sDemoCountdown + 1)

			if title_screen.sDemoCountdown == title_screen.PRESS_START_DEMO_TIMER then
				-- start the Mario demo animation for the demo list.
				SrcGameMemory.load_patchable_table(SrcGameGameInit.gDemoInputsBuf, SrcGameGameInit.gDemoInputListID)

				-- if the next demo sequence ID is the count limit, reset it back to
				-- the first sequence.
				SrcGameGameInit.gDemoInputListID = U16(SrcGameGameInit.gDemoInputListID + 1)

				if SrcGameGameInit.gDemoInputListID == Rom.ReadU32(SrcGameGameInit.gDemoInputsBuf.dmaTable :: number) then
					SrcGameGameInit.gDemoInputListID = 0
				end

				-- add 1 (+4) to the pointer to skip the first 4 bytes
				-- Use the first 4 bytes to store level ID,
				-- then use the rest of the values for inputs
				SrcGameGameInit.gCurrDemoInput = (SrcGameGameInit.gDemoInputsBuf.bufTarget :: number) + 4
				level = S8(Rom.ReadU8(SrcGameGameInit.gDemoInputsBuf.bufTarget :: number))
				SrcGameArea.gCurrSaveFileNum = 1
				SrcGameArea.gCurrActNum = 1
			end
		else -- activity was detected, so reset the demo countdown.
			title_screen.sDemoCountdown = 0
		end
	end

	return level
end

-- from src/menu/title_screen.c:intro_level_select L86-147
function title_screen.intro_level_select(): number
	local stageChanged = IncludePRUltratypesH.FALSE

	-- perform the ID updates per each button press.
	-- runs into a loop so after a button is pressed
	-- stageChanged goes back to FALSE
	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.A_BUTTON) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum + 1)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.B_BUTTON) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum - 1)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.U_JPAD) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum - 1)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.D_JPAD) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum + 1)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_JPAD) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum - 10)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_JPAD) then
		SrcGameArea.gCurrLevelNum = S16(SrcGameArea.gCurrLevelNum + 10)
		stageChanged = IncludePRUltratypesH.TRUE
	end

	-- if the stage was changed, play the sound for changing a stage.
	if stageChanged ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_LEVEL_SELECT_CHANGE, Audio.gGlobalSoundSource)
	end

	if SrcGameArea.gCurrLevelNum > IncludeLevelTableH.LEVEL_MAX then
		SrcGameArea.gCurrLevelNum = IncludeLevelTableH.LEVEL_MIN -- exceeded max. set to min.
	end

	if SrcGameArea.gCurrLevelNum < IncludeLevelTableH.LEVEL_MIN then
		SrcGameArea.gCurrLevelNum = IncludeLevelTableH.LEVEL_MAX -- exceeded min. set to max.
	end

	-- Use file 4 and last act as a test
	SrcGameArea.gCurrSaveFileNum = 4
	SrcGameArea.gCurrActNum = 6

	SrcGamePrint.print_text_centered(160, 80, "SELECT STAGE")
	SrcGamePrint.print_text_centered(160, 30, "PRESS START BUTTON")
	SrcGamePrint.print_text_fmt_int(40, 60, "%2d", SrcGameArea.gCurrLevelNum)
	SrcGamePrint.print_text(80, 60, title_screen.sLevelSelectStageNames[SrcGameArea.gCurrLevelNum]) -- print stage name

	-- start being pressed signals the stage to be started. that is, unless...
	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.START_BUTTON) then
		-- ... the level select quit combo is being pressed, which uses START. If this
		-- is the case, quit the menu instead.
		if SrcGameGameInit.gPlayer1Controller.buttonDown == bit32.bor(IncludePROsH.Z_TRIG, IncludePROsH.START_BUTTON, IncludePROsH.L_CBUTTONS, IncludePROsH.R_CBUTTONS) then
			SrcGameMain.gDebugLevelSelect = IncludePRUltratypesH.FALSE

			return -1
		end

		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
		return SrcGameArea.gCurrLevelNum
	end

	return 0
end

-- from src/menu/title_screen.c:intro_regular L152-186
function title_screen.intro_regular(): number
	local level = IncludeLevelTableH.LEVEL_NONE

	-- When the game stars, gGlobalTimer is less than 129 frames,
	-- so Mario greets the player. After that, he will always say
	-- "press start to play" when it goes back to the title screen
	-- (using SAVE AND QUIT)
	if title_screen.sPlayMarioGreeting == IncludePRUltratypesH.TRUE then
		if SrcGameGameInit.gGlobalTimer < 129 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HELLO, Audio.gGlobalSoundSource)
		else
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_PRESS_START_TO_PLAY, Audio.gGlobalSoundSource)
		end

		title_screen.sPlayMarioGreeting = IncludePRUltratypesH.FALSE
	end

	SrcGameArea.print_intro_text()

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.START_BUTTON) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)

		-- calls level ID 100 (or 101 adding level select bool value)
		-- defined in level_intro_mario_head_regular JUMP_IF commands
		-- 100 is File Select - 101 is Level Select
		level = 100 + SrcGameMain.gDebugLevelSelect

		title_screen.sPlayMarioGreeting = IncludePRUltratypesH.TRUE
	end

	return title_screen.run_level_id_or_demo(level)
end

-- from src/menu/title_screen.c:intro_game_over L191-216
function title_screen.intro_game_over(): number
	local level = IncludeLevelTableH.LEVEL_NONE

	if title_screen.sPlayMarioGameOver == IncludePRUltratypesH.TRUE then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_GAME_OVER, Audio.gGlobalSoundSource)
		title_screen.sPlayMarioGameOver = IncludePRUltratypesH.FALSE
	end

	SrcGameArea.print_intro_text()

	if bit32.btest(SrcGameGameInit.gPlayer1Controller.buttonPressed, IncludePROsH.START_BUTTON) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)

		-- same criteria as intro_regular
		level = 100 + SrcGameMain.gDebugLevelSelect

		title_screen.sPlayMarioGameOver = IncludePRUltratypesH.TRUE
	end

	return title_screen.run_level_id_or_demo(level)
end

-- from src/menu/title_screen.c:intro_play_its_a_me_mario L221-225
function title_screen.intro_play_its_a_me_mario(): number
	SrcGameSoundInit.set_background_music(0, IncludeSeqIdsH.SEQ_SOUND_PLAYER, 0)
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_COIN_ITS_A_ME_MARIO, Audio.gGlobalSoundSource)
	return 1
end

-- from src/menu/title_screen.c:lvl_intro_update L231-249
function title_screen.lvl_intro_update(arg: number, unusedArg: number): number
	arg = S16(TruncS32(arg))
	local retVar = 0

	if arg == TitleScreenH.LVL_INTRO_PLAY_ITS_A_ME_MARIO then
		retVar = title_screen.intro_play_its_a_me_mario()
	elseif arg == TitleScreenH.LVL_INTRO_REGULAR then
		retVar = title_screen.intro_regular()
	elseif arg == TitleScreenH.LVL_INTRO_GAME_OVER then
		retVar = title_screen.intro_game_over()
	elseif arg == TitleScreenH.LVL_INTRO_LEVEL_SELECT then
		retVar = title_screen.intro_level_select()
	end

	return retVar
end

return title_screen
