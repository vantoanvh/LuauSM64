--!strict
--!optimize 2

--[[
	Port of src/game/level_update.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeLevelTableH = require("../../include/level_table_h")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const LevelUpdateH = require("./level_update_h")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const SaveFileH = require("./save_file_h")
const SoundInit = require("./sound_init")
const Audio = require("../rom/audio_recorder")
const IncludeSeqIdsH = require("../../include/seq_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")
const SrcEngineMathUtil = require("../engine/math_util")

-- SEQ_PLAYER_LEVEL and SEQ_PLAYER_SFX of src/audio/external.h
const SeqPlayerLevel = 0
const SeqPlayerSfx = 2

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/level_update.luau:scratch
const play_mode_change_level_sTransitionTimer = { 0 }
-- from src/game/level_update.luau:scratch
const play_mode_change_area_sTransitionTimer = { 0 }

-- from src/game/level_update.c:data
const level_update = {
	PLAY_MODE_NORMAL = 0,
	PLAY_MODE_PAUSED = 2,
	PLAY_MODE_CHANGE_AREA = 3,
	PLAY_MODE_CHANGE_LEVEL = 4,
	PLAY_MODE_FRAME_ADVANCE = 5,
	WARP_TYPE_NOT_WARPING = 0,
	WARP_TYPE_CHANGE_LEVEL = 1,
	WARP_TYPE_CHANGE_AREA = 2,
	WARP_TYPE_SAME_AREA = 3,
	-- from src/game/level_update.c:credits01 L44-44
	credits01 = { "1GAME DIRECTOR", "SHIGERU MIYAMOTO" },
	-- from src/game/level_update.c:credits02 L45-45
	credits02 = { "2ASSISTANT DIRECTORS", "YOSHIAKI KOIZUMI", "TAKASHI TEZUKA" },
	-- from src/game/level_update.c:credits03 L46-46
	credits03 = { "2SYSTEM PROGRAMMERS", "YASUNARI NISHIDA", "YOSHINORI TANIMOTO" },
	-- from src/game/level_update.c:credits04 L47-47
	credits04 = { "3PROGRAMMERS", "HAJIME YAJIMA", "DAIKI IWAMOTO", "TOSHIO IWAWAKI" },
	-- from src/game/level_update.c:credits05 L79-79
	credits05 = { "4CAMERA PROGRAMMER", "MARIO FACE PROGRAMMER", "TAKUMI KAWAGOE", "GILES GODDARD" },
	-- from src/game/level_update.c:credits06 L80-80
	credits06 = { "2COURSE DIRECTORS", "YOICHI YAMADA", "YASUHISA YAMAMURA" },
	-- from src/game/level_update.c:credits07 L81-81
	credits07 = { "2COURSE DESIGNERS", "KENTA USUI", "NAOKI MORI" },
	-- from src/game/level_update.c:credits08 L82-82
	credits08 = { "3COURSE DESIGNERS", "YOSHIKI HARUHANA", "MAKOTO MIYANAGA", "KATSUHIKO KANNO" },
	-- from src/game/level_update.c:credits09 L85-85
	credits09 = { "1SOUND COMPOSER", "KOJI KONDO" },
	-- from src/game/level_update.c:credits10 L87-87
	credits10 = { "4SOUND EFFECTS", "SOUND PROGRAMMER", "YOJI INAGAKI", "HIDEAKI SHIMIZU" },
	-- from src/game/level_update.c:credits11 L88-88
	credits11 = { "23-D ANIMATORS", "YOSHIAKI KOIZUMI", "SATORU TAKIZAWA" },
	-- from src/game/level_update.c:credits12 L89-89
	credits12 = { "1ADDITIONAL GRAPHICS", "MASANAO ARIMOTO" },
	-- from src/game/level_update.c:credits13 L90-90
	credits13 = { "3TECHNICAL SUPPORT", "TAKAO SAWANO", "HIROHITO YOSHIMOTO", "HIROTO YADA" },
	-- from src/game/level_update.c:credits14 L91-91
	credits14 = { "1TECHNICAL SUPPORT", "SGI N64 PROJECT STAFF" },
	-- from src/game/level_update.c:credits15 L92-92
	credits15 = { "2PROGRESS MANAGEMENT", "KIMIYOSHI FUKUI", "KEIZO KATO" },
	-- from src/game/level_update.c:credits16 L93-93
	credits16 = { "5SCREEN TEXT WRITER", "TRANSLATION", "LESLIE SWAN", "MINA AKINO", "HIRO YAMADA" },
	-- from src/game/level_update.c:credits17 L110-110
	credits17 = { "4MARIO VOICE", "PEACH VOICE", "CHARLES MARTINET", "LESLIE SWAN" },
	-- from src/game/level_update.c:credits18 L117-117
	credits18 = { "3SPECIAL THANKS TO", "EAD STAFF", "ALL NINTENDO PERSONNEL", "MARIO CLUB STAFF" },
	-- from src/game/level_update.c:credits19 L127-127
	credits19 = { "1PRODUCER", "SHIGERU MIYAMOTO" },
	-- from src/game/level_update.c:credits20 L128-128
	credits20 = { "1EXECUTIVE PRODUCER", "HIROSHI YAMAUCHI" },
	-- from src/game/level_update.c:gMarioStates L157-157
	gMarioStates = {
			{
				unk00 = 0,
				input = 0,
				flags = 0,
				particleFlags = 0,
				action = 0,
				prevAction = 0,
				terrainSoundAddend = 0,
				actionState = 0,
				actionTimer = 0,
				actionArg = 0,
				intendedMag = 0,
				intendedYaw = 0,
				invincTimer = 0,
				framesSinceA = 0,
				framesSinceB = 0,
				wallKickTimer = 0,
				doubleJumpTimer = 0,
				faceAngle = table.create(3, 0),
				angleVel = table.create(3, 0),
				slideYaw = 0,
				twirlYaw = 0,
				pos = table.create(3, 0),
				vel = table.create(3, 0),
				forwardVel = 0,
				slideVelX = 0,
				slideVelZ = 0,
				wall = nil,
				ceil = nil,
				floor = nil,
				ceilHeight = 0,
				floorHeight = 0,
				floorAngle = 0,
				waterLevel = 0,
				interactObj = nil,
				heldObj = nil,
				usedObj = nil,
				riddenObj = nil,
				marioObj = nil,
				spawnInfo = nil,
				area = nil,
				statusForCamera = nil,
				marioBodyState = nil,
				controller = nil,
				animList = nil,
				collidedObjInteractTypes = 0,
				numCoins = 0,
				numStars = 0,
				numKeys = 0,
				numLives = 0,
				health = 0,
				unkB0 = 0,
				hurtCounter = 0,
				healCounter = 0,
				squishTimer = 0,
				fadeWarpOpacity = 0,
				capTimer = 0,
				prevNumStarsForDialog = 0,
				peakHeight = 0,
				quicksandDepth = 0,
				gettingBlownGravity = 0,
			},
		} :: { GroupsTypesHPlus3.MarioState },
	-- from src/game/level_update.c:gHudDisplay L158-158
	gHudDisplay = { lives = 0, coins = 0, stars = 0, wedges = 0, keys = 0, flags = 0, timer = 0 },
	-- from src/game/level_update.c:sCurrPlayMode L160-160
	sCurrPlayMode = 0,
	-- from src/game/level_update.c:D_80339ECA L161-161
	D_80339ECA = 0,
	-- from src/game/level_update.c:sTransitionTimer L162-162
	sTransitionTimer = 0,
	-- from src/game/level_update.c:sTransitionUpdate L163-163
	sTransitionUpdate = nil :: (({ number }) -> ())?,
	-- from src/game/level_update.c:sWarpDest L164-164
	sWarpDest = { type_ = 0, levelNum = 0, areaIdx = 0, nodeId = 0, arg = 0 },
	-- from src/game/level_update.c:D_80339EE0 L165-165
	D_80339EE0 = 0,
	-- from src/game/level_update.c:sDelayedWarpOp L166-166
	sDelayedWarpOp = 0,
	-- from src/game/level_update.c:sDelayedWarpTimer L167-167
	sDelayedWarpTimer = 0,
	-- from src/game/level_update.c:sSourceWarpNodeId L168-168
	sSourceWarpNodeId = 0,
	-- from src/game/level_update.c:sDelayedWarpArg L169-169
	sDelayedWarpArg = 0,
	-- from src/game/level_update.c:sUnusedLevelUpdateBss L170-170
	sUnusedLevelUpdateBss = 0,
	-- from src/game/level_update.c:sTimerRunning L171-171
	sTimerRunning = 0,
	-- from src/game/level_update.c:gNeverEnteredCastle L172-172
	gNeverEnteredCastle = 0,
	-- from src/game/level_update.c:unused1 L175-175
	unused1 = { 0, 0 },
	-- from src/game/level_update.c:sWarpCheckpointActive L176-176
	sWarpCheckpointActive = 0,
	-- from src/game/level_update.c:unused2 L177-177
	unused2 = buffer.create(4),
	PAINTING_WARP_INDEX_START = 0x00,
	PAINTING_WARP_INDEX_FA = 0x2A,
	PAINTING_WARP_INDEX_END = 0x2D,
}

Registry.Register("src__game__level_update", level_update)

-- from src/game/level_update.c:level_control_timer L179-203
function level_update.level_control_timer(timerOp: number): number
	if timerOp == LevelUpdateH.TIMER_CONTROL_SHOW then
		level_update.gHudDisplay.flags = S16(bit32.bor(level_update.gHudDisplay.flags, LevelUpdateH.HUD_DISPLAY_FLAG_TIMER))
		level_update.sTimerRunning = S8(IncludePRUltratypesH.FALSE)
		level_update.gHudDisplay.timer = U16(0)
	elseif timerOp == LevelUpdateH.TIMER_CONTROL_START then
		level_update.sTimerRunning = S8(IncludePRUltratypesH.TRUE)
	elseif timerOp == LevelUpdateH.TIMER_CONTROL_STOP then
		level_update.sTimerRunning = S8(IncludePRUltratypesH.FALSE)
	elseif timerOp == LevelUpdateH.TIMER_CONTROL_HIDE then
		level_update.gHudDisplay.flags = S16(bit32.band(level_update.gHudDisplay.flags, bit32.bnot(LevelUpdateH.HUD_DISPLAY_FLAG_TIMER)))
		level_update.sTimerRunning = S8(IncludePRUltratypesH.FALSE)
		level_update.gHudDisplay.timer = U16(0)
	end

	return level_update.gHudDisplay.timer
end

-- from src/game/level_update.c:pressed_pause L205-215
function level_update.pressed_pause(): number
	const dialogActive = Registry.Members.groups__ingame_menu_plus1.get_dialog_id() >= 0
	const intangible = bit32.btest(level_update.gMarioState.action, Registry.Members.include__sm64_h.ACT_FLAG_INTANGIBLE)

	if not intangible and not dialogActive and Registry.Members.src__game__area.gWarpTransition.isActive == 0 and level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_NONE and bit32.btest(Registry.Members.src__game__game_init.gPlayer1Controller.buttonPressed, Registry.Members.include__PR__os_h.START_BUTTON) then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/level_update.c:set_play_mode L217-220
function level_update.set_play_mode(playMode: number)
	playMode = S16(TruncS32(playMode))
	level_update.sCurrPlayMode = playMode
	level_update.D_80339ECA = U16(0)
end

-- from src/game/level_update.c:warp_special L222-226
function level_update.warp_special(arg: number)
	level_update.sCurrPlayMode = S16(level_update.PLAY_MODE_CHANGE_LEVEL)
	level_update.D_80339ECA = U16(0)
	level_update.D_80339EE0 = S16(arg)
end

-- from src/game/level_update.c:fade_into_special_warp L228-238
function level_update.fade_into_special_warp(arg: number, color: number)
	if color ~= 0 then
		color = 0xFF
	end

	SoundInit.fadeout_music(S16(190))
	Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x10), U8(color), U8(color), U8(color))
	level_update.level_set_transition(S16(30), nil)

	level_update.warp_special(S32(arg))
end

-- from src/game/level_update.c:stub_level_update_1 L240-241
function level_update.stub_level_update_1()
	-- Empty in the C source.
end

-- from src/game/level_update.c:load_level_init_text L243-274
function level_update.load_level_init_text(arg: number)
	const dialogID = buffer.readu8(Registry.Members.src__game__area.gCurrentArea.dialog, arg)
	local gotAchievement: number

	if dialogID == IncludeDialogIdsH.DIALOG_129 then
		gotAchievement = bit32.band(Registry.Members.src__game__save_file.save_file_get_flags(), SaveFileH.SAVE_FLAG_HAVE_VANISH_CAP)
	elseif dialogID == IncludeDialogIdsH.DIALOG_130 then
		gotAchievement = bit32.band(Registry.Members.src__game__save_file.save_file_get_flags(), SaveFileH.SAVE_FLAG_HAVE_METAL_CAP)
	elseif dialogID == IncludeDialogIdsH.DIALOG_131 then
		gotAchievement = bit32.band(Registry.Members.src__game__save_file.save_file_get_flags(), SaveFileH.SAVE_FLAG_HAVE_WING_CAP)
	elseif dialogID == U8(IncludeDialogIdsH.DIALOG_NONE) then
		gotAchievement = IncludePRUltratypesH.TRUE
	else
		gotAchievement = Registry.Members.src__game__save_file.save_file_get_star_flags(Registry.Members.src__game__area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Registry.Members.src__game__area.gCurrCourseNum))
	end

	if gotAchievement == 0 then
		level_update.level_set_transition(S16(-1), nil)
		Registry.Members.groups__ingame_menu_plus1.create_dialog_box(S16(dialogID))
	end
end

-- from src/game/level_update.c:init_door_warp L276-283
function level_update.init_door_warp(spawnInfo: GroupsTypesHPlus3.SpawnInfo, arg1: number)
	if bit32.btest(arg1, 0x00000002) then
		spawnInfo.startAngle[2] = S16(spawnInfo.startAngle[2] + 0x8000)
	end

	spawnInfo.startPos[1] = S16(TruncS32(F32(spawnInfo.startPos[1] + F32(300 * Registry.Members.src__engine__math_util_h.sins(spawnInfo.startAngle[2])))))
	spawnInfo.startPos[3] = S16(TruncS32(F32(spawnInfo.startPos[3] + F32(300 * Registry.Members.src__engine__math_util_h.coss(spawnInfo.startAngle[2])))))
end

-- from src/game/level_update.c:set_mario_initial_cap_powerup L285-304
function level_update.set_mario_initial_cap_powerup(m: GroupsTypesHPlus3.MarioState)
	const capCourseIndex = Registry.Members.src__game__area.gCurrCourseNum - IncludeCourseTableH.COURSE_CAP_COURSES

	if capCourseIndex == IncludeCourseTableH.COURSE_COTMC - IncludeCourseTableH.COURSE_CAP_COURSES then
		m.flags = bit32.bor(m.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_METAL_CAP, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))
		m.capTimer = U16(600)
	elseif capCourseIndex == IncludeCourseTableH.COURSE_TOTWC - IncludeCourseTableH.COURSE_CAP_COURSES then
		m.flags = bit32.bor(m.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_WING_CAP, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))
		m.capTimer = U16(1200)
	elseif capCourseIndex == IncludeCourseTableH.COURSE_VCUTM - IncludeCourseTableH.COURSE_CAP_COURSES then
		m.flags = bit32.bor(m.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_VANISH_CAP, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))
		m.capTimer = U16(600)
	end
end

-- from src/game/level_update.c:set_mario_initial_action L306-365
function level_update.set_mario_initial_action(m: GroupsTypesHPlus3.MarioState, spawnType: number, actionArg: number)
	if spawnType == LevelUpdateH.MARIO_SPAWN_DOOR_WARP then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_WARP_DOOR_SPAWN, actionArg)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_UNKNOWN_02 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_UNKNOWN_03 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_EMERGE_FROM_PIPE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_TELEPORT then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_TELEPORT_FADE_IN, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_INSTANT_ACTIVE then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_AIRBORNE then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPAWN_NO_SPIN_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_HARD_AIR_KNOCKBACK then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_HARD_BACKWARD_AIR_KB, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE_CIRCLE then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPAWN_SPIN_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_DEATH then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_FALLING_DEATH_EXIT, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPAWN_SPIN_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_FLYING then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_FLYING, 2)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_SWIMMING then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_WATER_IDLE, 1)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_PAINTING_STAR_COLLECT then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_EXIT_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_PAINTING_DEATH then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_DEATH_EXIT, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_AIRBORNE_STAR_COLLECT then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_FALLING_EXIT_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_AIRBORNE_DEATH then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_UNUSED_DEATH_EXIT, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_LAUNCH_STAR_COLLECT then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPECIAL_EXIT_AIRBORNE, 0)
	elseif spawnType == LevelUpdateH.MARIO_SPAWN_LAUNCH_DEATH then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPECIAL_DEATH_EXIT, 0)
	end

	level_update.set_mario_initial_cap_powerup(m)
end

-- from src/game/level_update.c:init_mario_after_warp L367-460
function level_update.init_mario_after_warp()
	const spawnNode = Registry.Members.src__game__area.area_get_warp_node(level_update.sWarpDest.nodeId) :: GroupsTypesHPlus3.ObjectWarpNode
	const marioSpawnType = Registry.Members.src__game__area.get_mario_spawn_type((spawnNode.object :: GroupsTypesHPlus3.Object))

	if level_update.gMarioState.action ~= Registry.Members.include__sm64_h.ACT_UNINITIALIZED then
		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startPos[1] = S16(TruncS32(buffer.readf32((spawnNode.object :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosX)))
		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startPos[2] = S16(TruncS32(buffer.readf32((spawnNode.object :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY)))
		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startPos[3] = S16(TruncS32(buffer.readf32((spawnNode.object :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosZ)))

		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startAngle[1] = S16(0)
		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startAngle[2] = S16(buffer.readi32((spawnNode.object :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		Registry.Members.src__game__area.gPlayerSpawnInfos[1].startAngle[3] = S16(0)

		if marioSpawnType == LevelUpdateH.MARIO_SPAWN_DOOR_WARP then
			level_update.init_door_warp(Registry.Members.src__game__area.gPlayerSpawnInfos[1], level_update.sWarpDest.arg)
		end

		if level_update.sWarpDest.type_ == level_update.WARP_TYPE_CHANGE_LEVEL or level_update.sWarpDest.type_ == level_update.WARP_TYPE_CHANGE_AREA then
			Registry.Members.src__game__area.gPlayerSpawnInfos[1].areaIndex = S8(level_update.sWarpDest.areaIdx)
			Registry.Members.src__game__area.load_mario_area()
		end

		Registry.Members.src__game__mario.init_mario()
		level_update.set_mario_initial_action(level_update.gMarioState, marioSpawnType, level_update.sWarpDest.arg)

		level_update.gMarioState.interactObj = spawnNode.object
		level_update.gMarioState.usedObj = spawnNode.object
	end

	Registry.Members.src__game__camera.reset_camera(Registry.Members.src__game__area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera)
	level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_NOT_WARPING)
	level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_NONE)

	if marioSpawnType == LevelUpdateH.MARIO_SPAWN_UNKNOWN_03 then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_STAR), S16(0x10), U8(0x00), U8(0x00), U8(0x00))
	elseif marioSpawnType == LevelUpdateH.MARIO_SPAWN_DOOR_WARP then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_CIRCLE), S16(0x10), U8(0x00), U8(0x00), U8(0x00))
	elseif marioSpawnType == LevelUpdateH.MARIO_SPAWN_TELEPORT then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR), S16(0x14), U8(0xFF), U8(0xFF), U8(0xFF))
	elseif marioSpawnType == LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR), S16(0x1A), U8(0xFF), U8(0xFF), U8(0xFF))
	elseif marioSpawnType == LevelUpdateH.MARIO_SPAWN_SPIN_AIRBORNE_CIRCLE then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_CIRCLE), S16(0x10), U8(0x00), U8(0x00), U8(0x00))
	elseif marioSpawnType == LevelUpdateH.MARIO_SPAWN_UNKNOWN_27 then
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR), S16(0x10), U8(0x00), U8(0x00), U8(0x00))
	else
		Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_STAR), S16(0x10), U8(0x00), U8(0x00), U8(0x00))
	end

	if Registry.Members.src__game__game_init.gCurrDemoInput == nil then
		SoundInit.set_background_music(Registry.Members.src__game__area.gCurrentArea.musicParam, Registry.Members.src__game__area.gCurrentArea.musicParam2, S16(0))

		if bit32.btest(level_update.gMarioState.flags, Registry.Members.include__sm64_h.MARIO_METAL_CAP) then
			SoundInit.play_cap_music(bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_EVENT_METAL_CAP)
		end

		if bit32.btest(level_update.gMarioState.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_VANISH_CAP, Registry.Members.include__sm64_h.MARIO_WING_CAP)) then
			SoundInit.play_cap_music(bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_EVENT_POWERUP)
		end

		-- BUGFIX_KOOPA_RACE_MUSIC: get_current_background_music() reports silence (0), so it differs from the slide sequence.
		if Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOB and level_update.sTimerRunning ~= 0 then
			Audio.play_music(SeqPlayerLevel, bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_LEVEL_SLIDE, 0)
		end

		if level_update.sWarpDest.levelNum == IncludeLevelTableH.LEVEL_CASTLE and level_update.sWarpDest.areaIdx == 1 and (level_update.sWarpDest.nodeId == 31 or level_update.sWarpDest.nodeId == 32) then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_MARIO_CASTLE_WARP, Audio.gGlobalSoundSource)
		end

		if level_update.sWarpDest.levelNum == IncludeLevelTableH.LEVEL_CASTLE_GROUNDS and level_update.sWarpDest.areaIdx == 1 and (level_update.sWarpDest.nodeId == 7 or level_update.sWarpDest.nodeId == 10 or level_update.sWarpDest.nodeId == 20 or level_update.sWarpDest.nodeId == 30) then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_MARIO_CASTLE_WARP, Audio.gGlobalSoundSource)
		end
	end
end

-- from src/game/level_update.c:warp_area L463-473
function level_update.warp_area()
	if level_update.sWarpDest.type_ ~= level_update.WARP_TYPE_NOT_WARPING then
		if level_update.sWarpDest.type_ == level_update.WARP_TYPE_CHANGE_AREA then
			level_update.level_control_timer(LevelUpdateH.TIMER_CONTROL_HIDE)
			Registry.Members.src__game__area.unload_mario_area()
			Registry.Members.src__game__area.load_area(level_update.sWarpDest.areaIdx)
		end

		level_update.init_mario_after_warp()
	end
end

-- from src/game/level_update.c:warp_level L476-483
function level_update.warp_level()
	Registry.Members.src__game__area.gCurrLevelNum = level_update.sWarpDest.levelNum

	level_update.level_control_timer(LevelUpdateH.TIMER_CONTROL_HIDE)

	Registry.Members.src__game__area.load_area(level_update.sWarpDest.areaIdx)
	level_update.init_mario_after_warp()
end

-- from src/game/level_update.c:warp_credits L485-528
function level_update.warp_credits()
	local marioAction = 0

	if level_update.sWarpDest.nodeId == LevelUpdateH.WARP_NODE_CREDITS_START then
		marioAction = Registry.Members.include__sm64_h.ACT_END_PEACH_CUTSCENE
	elseif level_update.sWarpDest.nodeId == LevelUpdateH.WARP_NODE_CREDITS_NEXT then
		marioAction = Registry.Members.include__sm64_h.ACT_CREDITS_CUTSCENE
	elseif level_update.sWarpDest.nodeId == LevelUpdateH.WARP_NODE_CREDITS_END then
		marioAction = Registry.Members.include__sm64_h.ACT_END_WAVING_CUTSCENE
	end

	Registry.Members.src__game__area.gCurrLevelNum = level_update.sWarpDest.levelNum

	Registry.Members.src__game__area.load_area(level_update.sWarpDest.areaIdx)

	SrcEngineMathUtil.vec3s_set(Registry.Members.src__game__area.gPlayerSpawnInfos[1].startPos, Registry.Members.src__game__area.gCurrCreditsEntry.marioPos[1], Registry.Members.src__game__area.gCurrCreditsEntry.marioPos[2], Registry.Members.src__game__area.gCurrCreditsEntry.marioPos[3])

	SrcEngineMathUtil.vec3s_set(Registry.Members.src__game__area.gPlayerSpawnInfos[1].startAngle, S16(0), S16(bit32.lshift(Registry.Members.src__game__area.gCurrCreditsEntry.marioAngle, 8)), S16(0))

	Registry.Members.src__game__area.gPlayerSpawnInfos[1].areaIndex = S8(level_update.sWarpDest.areaIdx)

	Registry.Members.src__game__area.load_mario_area()
	Registry.Members.src__game__mario.init_mario()

	Registry.Members.src__game__mario.set_mario_action(level_update.gMarioState, marioAction, 0)

	Registry.Members.src__game__camera.reset_camera(Registry.Members.src__game__area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera)

	level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_NOT_WARPING)
	level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_NONE)

	Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR), S16(0x14), U8(0x00), U8(0x00), U8(0x00))

	if Registry.Members.src__game__area.gCurrCreditsEntry == nil or Registry.Members.src__game__area.gCurrCreditsEntry == level_update.sCreditsSequence[1] then
		SoundInit.set_background_music(Registry.Members.src__game__area.gCurrentArea.musicParam, Registry.Members.src__game__area.gCurrentArea.musicParam2, S16(0))
	end
end

-- from src/game/level_update.c:check_instant_warp L530-565
function level_update.check_instant_warp()
	if Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE and Registry.Members.src__game__save_file.save_file_get_total_star_count(Registry.Members.src__game__area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MIN), IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_MAX)) >= 70 then
		return
	end

	const floor = level_update.gMarioState.floor

	if floor ~= nil then
		const index = floor.type_ - IncludeSurfaceTerrainsH.SURFACE_INSTANT_WARP_1B

		if index >= GroupsTypesHPlus3.INSTANT_WARP_INDEX_START and index < GroupsTypesHPlus3.INSTANT_WARP_INDEX_STOP and Registry.Members.src__game__area.gCurrentArea.instantWarps ~= nil then
			const warp = (Registry.Members.src__game__area.gCurrentArea.instantWarps :: { GroupsTypesHPlus3.InstantWarp })[index + 1]

			if warp.id ~= 0 then
				level_update.gMarioState.pos[1] = F32(level_update.gMarioState.pos[1] + warp.displacement[1])
				level_update.gMarioState.pos[2] = F32(level_update.gMarioState.pos[2] + warp.displacement[2])
				level_update.gMarioState.pos[3] = F32(level_update.gMarioState.pos[3] + warp.displacement[3])

				buffer.writef32((level_update.gMarioState.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosX, level_update.gMarioState.pos[1])
				buffer.writef32((level_update.gMarioState.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY, level_update.gMarioState.pos[2])
				buffer.writef32((level_update.gMarioState.marioObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosZ, level_update.gMarioState.pos[3])

				const cameraAngle = ((level_update.gMarioState.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera).yaw

				Registry.Members.src__game__area.change_area(warp.area)
				level_update.gMarioState.area = Registry.Members.src__game__area.gCurrentArea
				Registry.Members.src__game__camera.warp_camera(warp.displacement[1], warp.displacement[2], warp.displacement[3])

				const camera = (level_update.gMarioState.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera

				camera.yaw = cameraAngle
			end
		end
	end
end

-- from src/game/level_update.c:music_changed_through_warp L567-610
function level_update.music_changed_through_warp(arg: number): number
	arg = S16(TruncS32(arg))
	const warpNode = Registry.Members.src__game__area.area_get_warp_node(arg) :: GroupsTypesHPlus3.ObjectWarpNode
	const levelNum = S16(bit32.band(warpNode.node.destLevel, 0x7F))
	const destArea = S16(warpNode.node.destArea)
	local val4 = S16(IncludePRUltratypesH.TRUE)

	if levelNum == IncludeLevelTableH.LEVEL_BOB and levelNum == Registry.Members.src__game__area.gCurrLevelNum and destArea == Registry.Members.src__game__area.gCurrAreaIndex then
		-- sp2C = get_current_background_music(): the audio reports silence (0), which is neither powerup sequence, so val4 stays TRUE.
	else
		const val8: number = Registry.Members.src__game__area.gAreas[destArea + 1].musicParam
		const val6: number = Registry.Members.src__game__area.gAreas[destArea + 1].musicParam2

		val4 = S16(if levelNum == Registry.Members.src__game__area.gCurrLevelNum and val8 == Registry.Members.src__game__area.gCurrentArea.musicParam and val6 == Registry.Members.src__game__area.gCurrentArea.musicParam2 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE)

		-- get_current_background_music() reports silence (0), so it differs from val6 whenever val6 is not 0.
		if 0 ~= val6 then
			val4 = S16(IncludePRUltratypesH.FALSE)
		end
	end

	return val4
end

-- from src/game/level_update.c:initiate_warp L615-630
function level_update.initiate_warp(destLevel: number, destArea: number, destWarpNode: number, arg3: number)
	destLevel = S16(TruncS32(destLevel))
	destArea = S16(TruncS32(destArea))
	destWarpNode = S16(TruncS32(destWarpNode))
	if destWarpNode >= LevelUpdateH.WARP_NODE_CREDITS_MIN then
		level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_CHANGE_LEVEL)
	elseif destLevel ~= Registry.Members.src__game__area.gCurrLevelNum then
		level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_CHANGE_LEVEL)
	elseif destArea ~= Registry.Members.src__game__area.gCurrentArea.index then
		level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_CHANGE_AREA)
	else
		level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_SAME_AREA)
	end

	level_update.sWarpDest.levelNum = U8(destLevel)
	level_update.sWarpDest.areaIdx = U8(destArea)
	level_update.sWarpDest.nodeId = U8(destWarpNode)
	level_update.sWarpDest.arg = U32(arg3)
end

-- from src/game/level_update.c:get_painting_warp_node L641-653
function level_update.get_painting_warp_node(): GroupsTypesHPlus3.WarpNode?
	local warpNode: GroupsTypesHPlus3.WarpNode? = nil
	const paintingIndex = (level_update.gMarioState.floor :: GroupsTypesHPlus3.Surface).type_ - IncludeSurfaceTerrainsH.SURFACE_PAINTING_WARP_D3

	if paintingIndex >= level_update.PAINTING_WARP_INDEX_START and paintingIndex < level_update.PAINTING_WARP_INDEX_END then
		if paintingIndex < level_update.PAINTING_WARP_INDEX_FA or F32(level_update.gMarioState.pos[2] - level_update.gMarioState.floorHeight) < 80 then
			warpNode = (Registry.Members.src__game__area.gCurrentArea.paintingWarpNodes :: { GroupsTypesHPlus3.WarpNode })[paintingIndex + 1]
		end
	end

	return warpNode
end

-- from src/game/level_update.c:initiate_painting_warp L658-692
function level_update.initiate_painting_warp()
	if Registry.Members.src__game__area.gCurrentArea.paintingWarpNodes ~= nil and level_update.gMarioState.floor ~= nil then
		const pWarpNode = level_update.get_painting_warp_node()

		if pWarpNode ~= nil then
			if bit32.btest(level_update.gMarioState.action, Registry.Members.include__sm64_h.ACT_FLAG_INTANGIBLE) then
				SoundInit.play_painting_eject_sound()
			elseif pWarpNode.id ~= 0 then
				const warpNode = pWarpNode

				if not bit32.btest(warpNode.destLevel, 0x80) then
					level_update.sWarpCheckpointActive = S8(Registry.Members.src__game__save_file.check_warp_checkpoint(warpNode))
				end

				level_update.initiate_warp(S16(bit32.band(warpNode.destLevel, 0x7F)), warpNode.destArea, warpNode.destNode, 0)
				Registry.Members.src__game__save_file.check_if_should_set_warp_checkpoint(warpNode)

				Registry.Members.src__game__area.play_transition_after_delay(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(30), U8(255), U8(255), U8(255), S16(45))
				level_update.level_set_transition(S16(74), level_update.basic_update)

				Registry.Members.src__game__mario.set_mario_action(level_update.gMarioState, Registry.Members.include__sm64_h.ACT_DISAPPEARED, 0)

				const marioObj = level_update.gMarioState.marioObj :: GroupsTypesHPlus3.Object

				marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

				Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
				SoundInit.fadeout_music(S16(398))
			end
		end
	end
end

-- from src/game/level_update.c:level_trigger_warp L699-814
function level_update.level_trigger_warp(m: GroupsTypesHPlus3.MarioState, warpOp: number): number
	local val04 = true

	if level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_NONE then
		m.invincTimer = S16(-1)
		level_update.sDelayedWarpArg = S32(0)
		level_update.sDelayedWarpOp = S16(warpOp)

		if warpOp == LevelUpdateH.WARP_OP_DEMO_NEXT or warpOp == LevelUpdateH.WARP_OP_DEMO_END then
			level_update.sDelayedWarpTimer = S16(20)
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_SUCCESS)
			Registry.Members.src__game__area.gSavedCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
			val04 = false
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_STAR), S16(0x14), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_CREDITS_END then
			level_update.sDelayedWarpTimer = S16(60)
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_SUCCESS)
			val04 = false
			Registry.Members.src__game__area.gSavedCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x3C), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_STAR_EXIT then
			level_update.sDelayedWarpTimer = S16(32)
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_SUCCESS)
			Registry.Members.src__game__area.gSavedCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_MARIO), S16(0x20), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_DEATH then
			if m.numLives == 0 then
				level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_GAME_OVER)
			end

			level_update.sDelayedWarpTimer = S16(48)
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_DEATH)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_BOWSER), S16(0x30), U8(0x00), U8(0x00), U8(0x00))
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_BOWSER_LAUGH, Audio.gGlobalSoundSource)
		elseif warpOp == LevelUpdateH.WARP_OP_WARP_FLOOR then
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_WARP_FLOOR)

			if Registry.Members.src__game__area.area_get_warp_node(level_update.sSourceWarpNodeId) == nil then
				if m.numLives == 0 then
					level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_GAME_OVER)
				else
					level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_DEATH)
				end
			end

			level_update.sDelayedWarpTimer = S16(20)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_CIRCLE), S16(0x14), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_UNKNOWN_01 then
			level_update.sDelayedWarpTimer = S16(30)
			level_update.sSourceWarpNodeId = S16(LevelUpdateH.WARP_NODE_TOTWC)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x1E), U8(0xFF), U8(0xFF), U8(0xFF))
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
		elseif warpOp == LevelUpdateH.WARP_OP_UNKNOWN_02 then
			level_update.sDelayedWarpTimer = S16(30)
			level_update.sSourceWarpNodeId = S16(bit32.rshift(bit32.band(buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams), 0x00FF0000), 16))
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x1E), U8(0xFF), U8(0xFF), U8(0xFF))
		elseif warpOp == LevelUpdateH.WARP_OP_TELEPORT then
			level_update.sDelayedWarpTimer = S16(20)
			level_update.sSourceWarpNodeId = S16(bit32.rshift(bit32.band(buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams), 0x00FF0000), 16))
			val04 = level_update.music_changed_through_warp(level_update.sSourceWarpNodeId) == 0
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x14), U8(0xFF), U8(0xFF), U8(0xFF))
		elseif warpOp == LevelUpdateH.WARP_OP_WARP_DOOR then
			level_update.sDelayedWarpTimer = S16(20)
			level_update.sDelayedWarpArg = S32(m.actionArg)
			level_update.sSourceWarpNodeId = S16(bit32.rshift(bit32.band(buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams), 0x00FF0000), 16))
			val04 = level_update.music_changed_through_warp(level_update.sSourceWarpNodeId) == 0
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_CIRCLE), S16(0x14), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_WARP_OBJECT then
			level_update.sDelayedWarpTimer = S16(20)
			level_update.sSourceWarpNodeId = S16(bit32.rshift(bit32.band(buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams), 0x00FF0000), 16))
			val04 = level_update.music_changed_through_warp(level_update.sSourceWarpNodeId) == 0
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_STAR), S16(0x14), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_CREDITS_START then
			level_update.sDelayedWarpTimer = S16(30)
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x1E), U8(0x00), U8(0x00), U8(0x00))
		elseif warpOp == LevelUpdateH.WARP_OP_CREDITS_NEXT then
			if Registry.Members.src__game__area.gCurrCreditsEntry == level_update.sCreditsSequence[1] then
				level_update.sDelayedWarpTimer = S16(60)
				Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x3C), U8(0x00), U8(0x00), U8(0x00))
			else
				level_update.sDelayedWarpTimer = S16(20)
				Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR), S16(0x14), U8(0x00), U8(0x00), U8(0x00))
			end

			val04 = false
		end

		if val04 and Registry.Members.src__game__game_init.gCurrDemoInput == nil then
			SoundInit.fadeout_music(S16(TruncS32(3 * level_update.sDelayedWarpTimer / 2) * 8 - 2))
		end
	end

	return level_update.sDelayedWarpTimer
end

-- from src/game/level_update.c:initiate_delayed_warp L819-886
function level_update.initiate_delayed_warp()
	if level_update.sDelayedWarpOp ~= LevelUpdateH.WARP_OP_NONE then
		level_update.sDelayedWarpTimer = S16(level_update.sDelayedWarpTimer - 1)

		if level_update.sDelayedWarpTimer == 0 then
			Registry.Members.groups__ingame_menu_plus1.reset_dialog_render_state()

			if Registry.Members.src__game__main.gDebugLevelSelect ~= 0 and bit32.btest(level_update.sDelayedWarpOp, LevelUpdateH.WARP_OP_TRIGGERS_LEVEL_SELECT) then
				level_update.warp_special(-9)
			elseif Registry.Members.src__game__game_init.gCurrDemoInput ~= nil then
				if level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_DEMO_END then
					level_update.warp_special(-8)
				else
					level_update.warp_special(-2)
				end
			else
				if level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_GAME_OVER then
					Registry.Members.src__game__save_file.save_file_reload()
					level_update.warp_special(-3)
				elseif level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_CREDITS_END then
					level_update.warp_special(-1)
					Audio.sound_banks_enable(SeqPlayerSfx, bit32.band(IncludeSoundsH.SOUND_BANKS_ALL, bit32.bnot(IncludeSoundsH.SOUND_BANKS_DISABLED_AFTER_CREDITS)))
				elseif level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_DEMO_NEXT then
					level_update.warp_special(-2)
				elseif level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_CREDITS_START then
					Registry.Members.src__game__area.gCurrCreditsEntry = level_update.sCreditsSequence[1]
					level_update.initiate_warp(Registry.Members.src__game__area.gCurrCreditsEntry.levelNum, Registry.Members.src__game__area.gCurrCreditsEntry.areaIndex, S16(LevelUpdateH.WARP_NODE_CREDITS_START), 0)
				elseif level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_CREDITS_NEXT then
					Audio.sound_banks_disable(SeqPlayerSfx, IncludeSoundsH.SOUND_BANKS_ALL)
					local creditsIndex = 0

					for Index, Entry in level_update.sCreditsSequence do
						if Entry == Registry.Members.src__game__area.gCurrCreditsEntry then
							creditsIndex = Index

							break
						end
					end

					Registry.Members.src__game__area.gCurrCreditsEntry = level_update.sCreditsSequence[creditsIndex + 1]
					Registry.Members.src__game__area.gCurrActNum = S16(bit32.band(Registry.Members.src__game__area.gCurrCreditsEntry.unk02, 0x07))

					local destWarpNode: number

					if level_update.sCreditsSequence[creditsIndex + 2].levelNum == IncludeLevelTableH.LEVEL_NONE then
						destWarpNode = LevelUpdateH.WARP_NODE_CREDITS_END
					else
						destWarpNode = LevelUpdateH.WARP_NODE_CREDITS_NEXT
					end

					level_update.initiate_warp(Registry.Members.src__game__area.gCurrCreditsEntry.levelNum, Registry.Members.src__game__area.gCurrCreditsEntry.areaIndex, S16(destWarpNode), 0)
				else
					const warpNode = Registry.Members.src__game__area.area_get_warp_node(level_update.sSourceWarpNodeId) :: GroupsTypesHPlus3.ObjectWarpNode

					level_update.initiate_warp(S16(bit32.band(warpNode.node.destLevel, 0x7F)), warpNode.node.destArea, warpNode.node.destNode, level_update.sDelayedWarpArg)

					Registry.Members.src__game__save_file.check_if_should_set_warp_checkpoint(warpNode.node)

					if level_update.sWarpDest.type_ ~= level_update.WARP_TYPE_CHANGE_LEVEL then
						level_update.level_set_transition(S16(2), nil)
					end
				end
			end
		end
	end
end

-- from src/game/level_update.c:update_hud_values L888-945
function level_update.update_hud_values()
	if Registry.Members.src__game__area.gCurrCreditsEntry == nil then
		const numHealthWedges = S16(if level_update.gMarioState.health > 0 then level_update.gMarioState.health // 256 else 0)

		if Registry.Members.src__game__area.gCurrCourseNum >= IncludeCourseTableH.COURSE_MIN then
			level_update.gHudDisplay.flags = S16(bit32.bor(level_update.gHudDisplay.flags, LevelUpdateH.HUD_DISPLAY_FLAG_COIN_COUNT))
		else
			level_update.gHudDisplay.flags = S16(bit32.band(level_update.gHudDisplay.flags, bit32.bnot(LevelUpdateH.HUD_DISPLAY_FLAG_COIN_COUNT)))
		end

		if level_update.gHudDisplay.coins < level_update.gMarioState.numCoins then
			if bit32.btest(Registry.Members.src__game__game_init.gGlobalTimer, 1) then
				local coinSound = 0

				if bit32.btest(level_update.gMarioState.action, bit32.bor(Registry.Members.include__sm64_h.ACT_FLAG_SWIMMING, Registry.Members.include__sm64_h.ACT_FLAG_METAL_WATER)) then
					coinSound = IncludeSoundsH.SOUND_GENERAL_COIN_WATER
				else
					coinSound = IncludeSoundsH.SOUND_GENERAL_COIN
				end

				level_update.gHudDisplay.coins = S16(level_update.gHudDisplay.coins + 1)
				Audio.play_sound(coinSound, (level_update.gMarioState.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end
		end

		if level_update.gMarioState.numLives > 100 then
			level_update.gMarioState.numLives = S8(100)
		end

		if level_update.gMarioState.numCoins > 999 then
			level_update.gMarioState.numCoins = 999
		end

		-- BUGFIX_MAX_LIVES
		if level_update.gHudDisplay.coins > 999 then
			level_update.gHudDisplay.coins = 999
		end

		level_update.gHudDisplay.stars = level_update.gMarioState.numStars
		level_update.gHudDisplay.lives = level_update.gMarioState.numLives
		level_update.gHudDisplay.keys = level_update.gMarioState.numKeys

		if numHealthWedges > level_update.gHudDisplay.wedges then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_POWER_METER, Audio.gGlobalSoundSource)
		end

		level_update.gHudDisplay.wedges = numHealthWedges

		if level_update.gMarioState.hurtCounter > 0 then
			level_update.gHudDisplay.flags = S16(bit32.bor(level_update.gHudDisplay.flags, LevelUpdateH.HUD_DISPLAY_FLAG_EMPHASIZE_POWER))
		else
			level_update.gHudDisplay.flags = S16(bit32.band(level_update.gHudDisplay.flags, bit32.bnot(LevelUpdateH.HUD_DISPLAY_FLAG_EMPHASIZE_POWER)))
		end
	end
end

-- from src/game/level_update.c:basic_update L953-960
function level_update.basic_update(arg: { number })
	Registry.Members.src__game__area.area_update_objects()
	level_update.update_hud_values()

	if Registry.Members.src__game__area.gCurrentArea ~= nil then
		Registry.Members.src__game__camera.update_camera(Registry.Members.src__game__area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera)
	end
end

-- from src/game/level_update.c:play_mode_normal L962-1009
function level_update.play_mode_normal(): number
	if Registry.Members.src__game__game_init.gCurrDemoInput ~= nil then
		Registry.Members.src__game__area.print_intro_text()

		if bit32.btest(Registry.Members.src__game__game_init.gPlayer1Controller.buttonPressed, Registry.Members.include__sm64_h.END_DEMO) then
			level_update.level_trigger_warp(level_update.gMarioState, if Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_PSS then LevelUpdateH.WARP_OP_DEMO_END else LevelUpdateH.WARP_OP_DEMO_NEXT)
		elseif Registry.Members.src__game__area.gWarpTransition.isActive == 0 and level_update.sDelayedWarpOp == LevelUpdateH.WARP_OP_NONE and bit32.btest(Registry.Members.src__game__game_init.gPlayer1Controller.buttonPressed, Registry.Members.include__PR__os_h.START_BUTTON) then
			level_update.level_trigger_warp(level_update.gMarioState, LevelUpdateH.WARP_OP_DEMO_NEXT)
		end
	end

	level_update.warp_area()
	level_update.check_instant_warp()

	if level_update.sTimerRunning ~= 0 and level_update.gHudDisplay.timer < 17999 then
		level_update.gHudDisplay.timer = U16(level_update.gHudDisplay.timer + 1)
	end

	Registry.Members.src__game__area.area_update_objects()
	level_update.update_hud_values()

	if Registry.Members.src__game__area.gCurrentArea ~= nil then
		Registry.Members.src__game__camera.update_camera(Registry.Members.src__game__area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera)
	end

	level_update.initiate_painting_warp()
	level_update.initiate_delayed_warp()

	-- If either initiate_painting_warp or initiate_delayed_warp initiated a
	-- warp, change play mode accordingly.
	if level_update.sCurrPlayMode == level_update.PLAY_MODE_NORMAL then
		if level_update.sWarpDest.type_ == level_update.WARP_TYPE_CHANGE_LEVEL then
			level_update.set_play_mode(level_update.PLAY_MODE_CHANGE_LEVEL)
		elseif level_update.sTransitionTimer ~= 0 then
			level_update.set_play_mode(level_update.PLAY_MODE_CHANGE_AREA)
		elseif level_update.pressed_pause() ~= 0 then
			SoundInit.lower_background_noise(1)

			Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.bor(Registry.Members.src__game__camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN))
			level_update.set_play_mode(level_update.PLAY_MODE_PAUSED)
		end
	end

	return 0
end

-- from src/game/level_update.c:play_mode_paused L1011-1031
function level_update.play_mode_paused(): number
	if Registry.Members.src__game__area.gMenuOptSelectIndex == GroupsTypesHPlus3.MENU_OPT_NONE then
		Registry.Members.groups__ingame_menu_plus1.set_menu_mode(Registry.Members.groups__ingame_menu_plus1.MENU_MODE_RENDER_PAUSE_SCREEN)
	elseif Registry.Members.src__game__area.gMenuOptSelectIndex == GroupsTypesHPlus3.MENU_OPT_DEFAULT then
		SoundInit.raise_background_noise(1)
		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.band(Registry.Members.src__game__camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN)))
		level_update.set_play_mode(level_update.PLAY_MODE_NORMAL)
	else
		if Registry.Members.src__game__main.gDebugLevelSelect ~= 0 then
			level_update.fade_into_special_warp(U32(-9), 1)
		else
			level_update.initiate_warp(S16(IncludeLevelTableH.LEVEL_CASTLE), S16(1), S16(0x1F), 0)
			level_update.fade_into_special_warp(0, 0)
			Registry.Members.src__game__area.gSavedCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
		end

		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.band(Registry.Members.src__game__camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN)))
	end

	return 0
end

-- from src/game/level_update.c:play_mode_frame_advance L1037-1050
function level_update.play_mode_frame_advance(): number
	if bit32.btest(Registry.Members.src__game__game_init.gPlayer1Controller.buttonPressed, Registry.Members.include__PR__os_h.D_JPAD) then
		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.band(Registry.Members.src__game__camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN)))
		level_update.play_mode_normal()
	elseif bit32.btest(Registry.Members.src__game__game_init.gPlayer1Controller.buttonPressed, Registry.Members.include__PR__os_h.START_BUTTON) then
		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.band(Registry.Members.src__game__camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN)))
		SoundInit.raise_background_noise(1)
		level_update.set_play_mode(level_update.PLAY_MODE_NORMAL)
	else
		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.bor(Registry.Members.src__game__camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN))
	end

	return 0
end

-- from src/game/level_update.c:level_set_transition L1057-1060
function level_update.level_set_transition(length: number, updateFunction: (({ number }) -> ())?)
	length = S16(TruncS32(length))
	level_update.sTransitionTimer = length
	level_update.sTransitionUpdate = updateFunction
end

-- from src/game/level_update.c:play_mode_change_area L1065-1084
function level_update.play_mode_change_area(): number
	-- sTransitionUpdate == (void (*)(s16 *)) -1 is never true: function-pointer-minus-one-compare
	if level_update.sTransitionUpdate ~= nil then
		play_mode_change_area_sTransitionTimer[1] = level_update.sTransitionTimer
		level_update.sTransitionUpdate(play_mode_change_area_sTransitionTimer)
		level_update.sTransitionTimer = play_mode_change_area_sTransitionTimer[1]
	end

	if level_update.sTransitionTimer > 0 then
		level_update.sTransitionTimer = S16(level_update.sTransitionTimer - 1)
	end

	if level_update.sTransitionTimer == 0 then
		level_update.sTransitionUpdate = nil
		level_update.set_play_mode(level_update.PLAY_MODE_NORMAL)
	end

	return 0
end

-- from src/game/level_update.c:play_mode_change_level L1089-1107
function level_update.play_mode_change_level(): number
	if level_update.sTransitionUpdate ~= nil then
		play_mode_change_level_sTransitionTimer[1] = level_update.sTransitionTimer
		level_update.sTransitionUpdate(play_mode_change_level_sTransitionTimer)
		level_update.sTransitionTimer = play_mode_change_level_sTransitionTimer[1]
	end

	level_update.sTransitionTimer = S16(level_update.sTransitionTimer - 1)

	if level_update.sTransitionTimer == -1 then
		level_update.gHudDisplay.flags = S16(LevelUpdateH.HUD_DISPLAY_NONE)
		level_update.sTransitionTimer = S16(0)
		level_update.sTransitionUpdate = nil

		if level_update.sWarpDest.type_ ~= level_update.WARP_TYPE_NOT_WARPING then
			return level_update.sWarpDest.levelNum
		else
			return level_update.D_80339EE0
		end
	end

	return 0
end

-- from src/game/level_update.c:play_mode_unused L1112-1124
function level_update.play_mode_unused(): number
	level_update.sTransitionTimer = S16(level_update.sTransitionTimer - 1)

	if level_update.sTransitionTimer == -1 then
		level_update.gHudDisplay.flags = S16(LevelUpdateH.HUD_DISPLAY_NONE)

		if level_update.sWarpDest.type_ ~= level_update.WARP_TYPE_NOT_WARPING then
			return level_update.sWarpDest.levelNum
		else
			return level_update.D_80339EE0
		end
	end

	return 0
end

-- from src/game/level_update.c:update_level L1126-1153
function level_update.update_level(): number
	local changeLevel = 0

	if level_update.sCurrPlayMode == level_update.PLAY_MODE_NORMAL then
		changeLevel = level_update.play_mode_normal()
	elseif level_update.sCurrPlayMode == level_update.PLAY_MODE_PAUSED then
		changeLevel = level_update.play_mode_paused()
	elseif level_update.sCurrPlayMode == level_update.PLAY_MODE_CHANGE_AREA then
		changeLevel = level_update.play_mode_change_area()
	elseif level_update.sCurrPlayMode == level_update.PLAY_MODE_CHANGE_LEVEL then
		changeLevel = level_update.play_mode_change_level()
	elseif level_update.sCurrPlayMode == level_update.PLAY_MODE_FRAME_ADVANCE then
		changeLevel = level_update.play_mode_frame_advance()
	end

	if changeLevel ~= 0 then
		SoundInit.reset_volume()
		SoundInit.enable_background_sound()
	end

	return changeLevel
end

-- from src/game/level_update.c:init_level L1155-1216
function level_update.init_level(): number
	local val4 = IncludePRUltratypesH.FALSE

	level_update.set_play_mode(level_update.PLAY_MODE_NORMAL)

	level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_NONE)
	level_update.sTransitionTimer = S16(0)
	level_update.D_80339EE0 = S16(0)
	level_update.gHudDisplay.flags = S16(if Registry.Members.src__game__area.gCurrCreditsEntry == nil then LevelUpdateH.HUD_DISPLAY_DEFAULT else LevelUpdateH.HUD_DISPLAY_NONE)
	level_update.sTimerRunning = S8(IncludePRUltratypesH.FALSE)

	if level_update.sWarpDest.type_ ~= level_update.WARP_TYPE_NOT_WARPING then
		if level_update.sWarpDest.nodeId >= LevelUpdateH.WARP_NODE_CREDITS_MIN then
			level_update.warp_credits()
		else
			level_update.warp_level()
		end
	else
		if Registry.Members.src__game__area.gPlayerSpawnInfos[1].areaIndex >= 0 then
			Registry.Members.src__game__area.load_mario_area()
			Registry.Members.src__game__mario.init_mario()
		end

		if Registry.Members.src__game__area.gCurrentArea ~= nil then
			Registry.Members.src__game__camera.reset_camera(Registry.Members.src__game__area.gCurrentArea.camera :: GroupsTypesHPlus3.Camera)

			if Registry.Members.src__game__game_init.gCurrDemoInput ~= nil then
				Registry.Members.src__game__mario.set_mario_action(level_update.gMarioState, Registry.Members.include__sm64_h.ACT_IDLE, 0)
			elseif Registry.Members.src__game__main.gDebugLevelSelect == 0 then
				if level_update.gMarioState.action ~= Registry.Members.include__sm64_h.ACT_UNINITIALIZED then
					if Registry.Members.src__game__save_file.save_file_exists(Registry.Members.src__game__area.gCurrSaveFileNum - 1) ~= 0 then
						Registry.Members.src__game__mario.set_mario_action(level_update.gMarioState, Registry.Members.include__sm64_h.ACT_IDLE, 0)
					else
						Registry.Members.src__game__mario.set_mario_action(level_update.gMarioState, Registry.Members.include__sm64_h.ACT_INTRO_CUTSCENE, 0)
						val4 = IncludePRUltratypesH.TRUE
					end
				end
			end
		end

		if val4 ~= 0 then
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR), S16(0x5A), U8(0xFF), U8(0xFF), U8(0xFF))
		else
			Registry.Members.src__game__area.play_transition(S16(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_STAR), S16(0x10), U8(0xFF), U8(0xFF), U8(0xFF))
		end

		if Registry.Members.src__game__game_init.gCurrDemoInput == nil then
			SoundInit.set_background_music(Registry.Members.src__game__area.gCurrentArea.musicParam, Registry.Members.src__game__area.gCurrentArea.musicParam2, S16(0))
		end
	end

	if level_update.gMarioState.action == Registry.Members.include__sm64_h.ACT_INTRO_CUTSCENE then
		Audio.sound_banks_disable(SeqPlayerSfx, IncludeSoundsH.SOUND_BANKS_DISABLED_DURING_INTRO_CUTSCENE)
	end

	return 1
end

-- from src/game/level_update.c:lvl_init_or_update L1221-1234
function level_update.lvl_init_or_update(initOrUpdate: number, unused: number): number
	initOrUpdate = S16(TruncS32(initOrUpdate))
	local result = 0

	if initOrUpdate == 0 then
		result = level_update.init_level()
	elseif initOrUpdate == 1 then
		result = level_update.update_level()
	end

	return result
end

-- from src/game/level_update.c:lvl_init_from_save_file L1236-1271
function level_update.lvl_init_from_save_file(arg0: number, levelNum: number): number
	arg0 = S16(TruncS32(arg0))
	level_update.sWarpDest.type_ = U8(level_update.WARP_TYPE_NOT_WARPING)
	level_update.sDelayedWarpOp = S16(LevelUpdateH.WARP_OP_NONE)
	level_update.gNeverEnteredCastle = S8(if Registry.Members.src__game__save_file.save_file_exists(Registry.Members.src__game__area.gCurrSaveFileNum - 1) == 0 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE)

	Registry.Members.src__game__area.gCurrLevelNum = S16(levelNum)
	Registry.Members.src__game__area.gCurrCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
	Registry.Members.src__game__area.gSavedCourseNum = S16(IncludeCourseTableH.COURSE_NONE)
	Registry.Members.src__game__area.gCurrCreditsEntry = nil
	Registry.Members.src__game__save_file.gSpecialTripleJump = U8(IncludePRUltratypesH.FALSE)

	Registry.Members.src__game__mario.init_mario_from_save_file()
	Registry.Members.src__game__save_file.disable_warp_checkpoint()
	Registry.Members.src__game__save_file.save_file_move_cap_to_default_location()
	Registry.Members.src__game__camera.select_mario_cam_mode()
	Registry.Members.src__game__obj_behaviors.set_yoshi_as_not_dead()

	return levelNum
end

-- from src/game/level_update.c:lvl_set_current_level L1273-1307
function level_update.lvl_set_current_level(arg0: number, levelNum: number): number
	arg0 = S16(TruncS32(arg0))
	const warpCheckpointActive = level_update.sWarpCheckpointActive

	level_update.sWarpCheckpointActive = S8(IncludePRUltratypesH.FALSE)
	Registry.Members.src__game__area.gCurrLevelNum = S16(levelNum)
	Registry.Members.src__game__area.gCurrCourseNum = Registry.Members.src__game__save_file.gLevelToCourseNumTable[levelNum]

	if Registry.Members.src__game__game_init.gCurrDemoInput ~= nil or Registry.Members.src__game__area.gCurrCreditsEntry ~= nil or Registry.Members.src__game__area.gCurrCourseNum == IncludeCourseTableH.COURSE_NONE then
		return 0
	end

	if Registry.Members.src__game__area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_BOWSER_1 and Registry.Members.src__game__area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_BOWSER_2 and Registry.Members.src__game__area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_BOWSER_3 then
		level_update.gMarioState.numCoins = S16(0)
		level_update.gHudDisplay.coins = S16(0)
		Registry.Members.src__game__save_file.gCurrCourseStarFlags = U8(Registry.Members.src__game__save_file.save_file_get_star_flags(Registry.Members.src__game__area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Registry.Members.src__game__area.gCurrCourseNum)))
	end

	if Registry.Members.src__game__area.gSavedCourseNum ~= Registry.Members.src__game__area.gCurrCourseNum then
		Registry.Members.src__game__area.gSavedCourseNum = Registry.Members.src__game__area.gCurrCourseNum
		-- nop_change_course(): replaced by no-op
		Registry.Members.src__game__save_file.disable_warp_checkpoint()
	end

	if Registry.Members.src__game__area.gCurrCourseNum > IncludeCourseTableH.COURSE_STAGES_MAX or warpCheckpointActive ~= 0 then
		return 0
	end

	if Registry.Members.src__game__main.gDebugLevelSelect ~= 0 and Registry.Members.src__game__main.gShowProfiler == 0 then
		return 0
	end

	return 1
end

-- from src/game/level_update.c:lvl_play_the_end_screen_sound L1312-1315
function level_update.lvl_play_the_end_screen_sound(arg0: number, arg1: number): number
	arg0 = S16(TruncS32(arg0))
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_THANK_YOU_PLAYING_MY_GAME, Audio.gGlobalSoundSource)
	return 1
end

-- from src/game/level_update.c:sCreditsSequence L131-155
level_update.sCreditsSequence = {
	{
			levelNum = IncludeLevelTableH.LEVEL_CASTLE_GROUNDS,
			areaIndex = 1,
			unk02 = 1,
			marioAngle = -128,
			marioPos = { 0, 8000, 0 },
			unk0C = nil,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_BOB,
			areaIndex = 1,
			unk02 = 1,
			marioAngle = 117,
			marioPos = { 713, 3918, -3889 },
			unk0C = level_update.credits01,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_WF,
			areaIndex = 1,
			unk02 = 50,
			marioAngle = 46,
			marioPos = { 347, 5376, 326 },
			unk0C = level_update.credits02,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_JRB,
			areaIndex = 1,
			unk02 = 18,
			marioAngle = 22,
			marioPos = { 3800, -4840, 2727 },
			unk0C = level_update.credits03,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_CCM,
			areaIndex = 2,
			unk02 = 34,
			marioAngle = 25,
			marioPos = { -5464, 6656, -6575 },
			unk0C = level_update.credits04,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_BBH,
			areaIndex = 1,
			unk02 = 1,
			marioAngle = 60,
			marioPos = { 257, 1922, 2580 },
			unk0C = level_update.credits05,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_HMC,
			areaIndex = 1,
			unk02 = 241,
			marioAngle = 123,
			marioPos = { -6469, 1616, -6054 },
			unk0C = level_update.credits06,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_THI,
			areaIndex = 3,
			unk02 = 17,
			marioAngle = -32,
			marioPos = { 508, 1024, 1942 },
			unk0C = level_update.credits07,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_LLL,
			areaIndex = 2,
			unk02 = 33,
			marioAngle = 124,
			marioPos = { -73, 82, -1467 },
			unk0C = level_update.credits08,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_SSL,
			areaIndex = 1,
			unk02 = 65,
			marioAngle = 98,
			marioPos = { -5906, 1024, -2576 },
			unk0C = level_update.credits09,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_DDD,
			areaIndex = 1,
			unk02 = 50,
			marioAngle = 47,
			marioPos = { -4884, -4607, -272 },
			unk0C = level_update.credits10,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_SL,
			areaIndex = 1,
			unk02 = 17,
			marioAngle = -34,
			marioPos = { 1925, 3328, 563 },
			unk0C = level_update.credits11,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_WDW,
			areaIndex = 1,
			unk02 = 33,
			marioAngle = 105,
			marioPos = { -537, 1850, 1818 },
			unk0C = level_update.credits12,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_TTM,
			areaIndex = 1,
			unk02 = 2,
			marioAngle = -33,
			marioPos = { 2613, 313, 1074 },
			unk0C = level_update.credits13,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_THI,
			areaIndex = 1,
			unk02 = 51,
			marioAngle = 54,
			marioPos = { -2609, 512, 856 },
			unk0C = level_update.credits14,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_TTC,
			areaIndex = 1,
			unk02 = 17,
			marioAngle = -72,
			marioPos = { -1304, -71, -967 },
			unk0C = level_update.credits15,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_RR,
			areaIndex = 1,
			unk02 = 33,
			marioAngle = 64,
			marioPos = { 1565, 1024, -148 },
			unk0C = level_update.credits16,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_SA,
			areaIndex = 1,
			unk02 = 1,
			marioAngle = 24,
			marioPos = { -1050, -1330, -1559 },
			unk0C = level_update.credits17,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_COTMC,
			areaIndex = 1,
			unk02 = 49,
			marioAngle = -16,
			marioPos = { -254, 415, -6045 },
			unk0C = level_update.credits18,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_DDD,
			areaIndex = 2,
			unk02 = 145,
			marioAngle = -64,
			marioPos = { 3948, 1185, -104 },
			unk0C = level_update.credits19,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_CCM,
			areaIndex = 1,
			unk02 = 33,
			marioAngle = 31,
			marioPos = { 3169, -4607, 5240 },
			unk0C = level_update.credits20,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_CASTLE_GROUNDS,
			areaIndex = 1,
			unk02 = 1,
			marioAngle = -128,
			marioPos = { 0, 906, -1200 },
			unk0C = nil,
		},
	{
			levelNum = IncludeLevelTableH.LEVEL_NONE,
			areaIndex = 0,
			unk02 = 1,
			marioAngle = 0,
			marioPos = { 0, 0, 0 },
			unk0C = nil,
		},
}

-- from src/game/level_update.c:gMarioState L174-174
level_update.gMarioState = level_update.gMarioStates[1]

return level_update
