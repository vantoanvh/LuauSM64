--!strict
--!optimize 2

--[[
	Port of src/game/mario_actions_cutscene.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeGfxDimensionsH = require("../../include/gfx_dimensions_h")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const Area = require("./area")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludeMarioAnimationIdsH = require("../../include/mario_animation_ids_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const LevelUpdate = require("./level_update")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const SaveFile = require("./save_file")
const SrcEngineMathUtil = require("../engine/math_util")
const BehaviorIds = require("../rom/behavior_ids")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const RenderingGraphNode = require("./rendering_graph_node")
const IncludeMacrosH = require("../../include/macros_h")
const GameInit = require("./game_init")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Audio = require("../rom/audio_recorder")
const IncludeSeqIdsH = require("../../include/seq_ids_h")
const LevelUpdateH = require("./level_update_h")
const SoundInit = require("./sound_init")
const InteractionH = require("./interaction_h")
const SaveFileH = require("./save_file_h")
const IncludeCourseTableH = require("../../include/course_table_h")

const SeqPlayerLevel = 0
const SeqPlayerEnv = 1
const SeqPlayerSfx = 2

const function SequenceArgs(Priority: number, SeqId: number): number
	return bit32.bor(bit32.lshift(Priority, 8), SeqId)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/mario_actions_cutscene.luau:scratch
local sSparkleGenTheta = 0
-- from src/game/mario_actions_cutscene.luau:scratch
local sSparkleGenPhi = 0
-- from src/game/mario_actions_cutscene.luau:scratch
const Translation = { 0, 0, 0 }
-- from src/game/mario_actions_cutscene.luau:scratch
const Floor: { GroupsTypesHPlus3.Surface? } = {}
-- from src/game/mario_actions_cutscene.luau:scratch
const DebugPos = { 0, 0, 0 }
-- from src/game/mario_actions_cutscene.luau:scratch
const TargetPos = { 0, 0, 0 }

-- from src/game/mario_actions_cutscene.c:data
const mario_actions_cutscene = {
	-- from src/game/mario_actions_cutscene.c:sIntroWarpPipeObj L32-32
	sIntroWarpPipeObj = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/mario_actions_cutscene.c:sEndPeachObj L33-33
	sEndPeachObj = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/mario_actions_cutscene.c:sEndRightToadObj L34-34
	sEndRightToadObj = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/mario_actions_cutscene.c:sEndLeftToadObj L35-35
	sEndLeftToadObj = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/mario_actions_cutscene.c:sEndJumboStarObj L36-36
	sEndJumboStarObj = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/mario_actions_cutscene.c:sUnused L37-37
	sUnused = 0,
	-- from src/game/mario_actions_cutscene.c:sEndPeachAnimation L38-38
	sEndPeachAnimation = 0,
	-- from src/game/mario_actions_cutscene.c:sEndToadAnims L39-39
	sEndToadAnims = table.create(2, 0),
	-- from src/game/mario_actions_cutscene.c:sEndCutsceneVp L41-41
	sEndCutsceneVp = { { 640, 480, 511, 0 }, { 640, 480, 511, 0 } },
	-- from src/game/mario_actions_cutscene.c:sDispCreditsEntry L42-42
	sDispCreditsEntry = nil :: LevelUpdateH.CreditsEntry?,
	-- from src/game/mario_actions_cutscene.c:D_8032CBE4 L45-45
	D_8032CBE4 = 0,
	-- from src/game/mario_actions_cutscene.c:D_8032CBE8 L46-46
	D_8032CBE8 = 0,
	-- from src/game/mario_actions_cutscene.c:D_8032CBEC L47-47
	D_8032CBEC = { 2, 3, 2, 1, 2, 3, 2 },
	-- from src/game/mario_actions_cutscene.c:sStarsNeededForDialog L49-49
	sStarsNeededForDialog = { 1, 3, 8, 30, 50, 70 },
	-- from src/game/mario_actions_cutscene.c:sJumboStarKeyframes L61-71
	sJumboStarKeyframes = {
			{ 20, 0, 678, -2916 },
			{ 30, 0, 680, -3500 },
			{ 40, 1000, 700, -4000 },
			{ 50, 2500, 750, -3500 },
			{ 50, 3500, 800, -2000 },
			{ 50, 4000, 850, 0 },
			{ 50, 3500, 900, 2000 },
			{ 50, 2000, 950, 3500 },
			{ 50, 0, 1000, 4000 },
			{ 50, -2000, 1050, 3500 },
			{ 50, -3500, 1100, 2000 },
			{ 50, -4000, 1150, 0 },
			{ 50, -3500, 1200, -2000 },
			{ 50, -2000, 1250, -3500 },
			{ 50, 0, 1300, -4000 },
			{ 50, 2000, 1350, -3500 },
			{ 50, 3500, 1400, -2000 },
			{ 50, 4000, 1450, 0 },
			{ 50, 3500, 1500, 2000 },
			{ 50, 2000, 1600, 3500 },
			{ 50, 0, 1700, 4000 },
			{ 50, -2000, 1800, 3500 },
			{ 50, -3500, 1900, 2000 },
			{ 30, -4000, 2000, 0 },
			{ 0, -3500, 2100, -2000 },
			{ 0, -2000, 2200, -3500 },
			{ 0, 0, 2300, -4000 },
		},
	CREDIT_TEXT_MARGIN_X = IncludeGfxDimensionsH.GFX_DIMENSIONS_ASPECT_RATIO * 21,
	TIMER_SPAWN_PIPE = 37,
	TIMER_RAISE_PIPE = 38,
	INTRO_CUTSCENE_HIDE_HUD_AND_MARIO = 0,
	INTRO_CUTSCENE_PEACH_LAKITU_SCENE = 1,
	INTRO_CUTSCENE_RAISE_PIPE = 2,
	INTRO_CUTSCENE_JUMP_OUT_OF_PIPE = 3,
	INTRO_CUTSCENE_LAND_OUTSIDE_PIPE = 4,
	INTRO_CUTSCENE_LOWER_PIPE = 5,
	INTRO_CUTSCENE_SET_MARIO_TO_IDLE = 6,
	JUMBO_STAR_CUTSCENE_FALLING = 0,
	JUMBO_STAR_CUTSCENE_TAKING_OFF = 1,
	JUMBO_STAR_CUTSCENE_FLYING = 2,
	TIMER_FADE_IN_PEACH = 276,
	TIMER_DESCEND_PEACH = 355,
	TIMER_RUN_TO_PEACH = 584,
	TIMER_SOMETHING_SPECIAL = 130,
	TIMER_PEACH_KISS = 200,
	-- from src/game/mario_actions_cutscene.c:sMarioBlinkOverride L2330-2336
	sMarioBlinkOverride = {
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_OPEN,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_OPEN,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_OPEN,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_OPEN,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
			IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED,
		},
	END_PEACH_CUTSCENE_MARIO_FALLING = 0,
	END_PEACH_CUTSCENE_MARIO_LANDING = 1,
	END_PEACH_CUTSCENE_SUMMON_JUMBO_STAR = 2,
	END_PEACH_CUTSCENE_SPAWN_PEACH = 3,
	END_PEACH_CUTSCENE_DESCEND_PEACH = 4,
	END_PEACH_CUTSCENE_RUN_TO_PEACH = 5,
	END_PEACH_CUTSCENE_DIALOG_1 = 6,
	END_PEACH_CUTSCENE_DIALOG_2 = 7,
	END_PEACH_CUTSCENE_KISS_FROM_PEACH = 8,
	END_PEACH_CUTSCENE_STAR_DANCE = 9,
	END_PEACH_CUTSCENE_DIALOG_3 = 10,
	END_PEACH_CUTSCENE_RUN_TO_CASTLE = 11,
	END_PEACH_CUTSCENE_FADE_OUT = 12,
	TIMER_CREDITS_SHOW = 61,
	TIMER_CREDITS_PROGRESS = 90,
	TIMER_CREDITS_WARP = 200,
}

Registry.Register("src__game__mario_actions_cutscene", mario_actions_cutscene)

-- from src/game/mario_actions_cutscene.c:get_credits_str_width L80-89
function mario_actions_cutscene.get_credits_str_width(str: string): number
	local length = 0

	for Index = 1, #str do
		const Char = string.byte(str, Index)

		length = S32(length + (if Char == 32 then 4 else 7))
	end

	return length
end

-- from src/game/mario_actions_cutscene.c:print_displaying_credits_entry L109-171
function mario_actions_cutscene.print_displaying_credits_entry()
	if mario_actions_cutscene.sDispCreditsEntry ~= nil then
		const strings = mario_actions_cutscene.sDispCreditsEntry.unk0C :: { string }
		local currStrPtr = 1
		const title = strings[currStrPtr]
		currStrPtr += 1
		local numLines = S16(string.byte(title, 1) - 48)
		const titleStr = string.sub(title, 2)

		local strY = S16((if bit32.btest(mario_actions_cutscene.sDispCreditsEntry.unk02, 0x20) then 28 else 172) + (if numLines == 1 then 16 else 0))

		local lineHeight = 16

		GroupsIngameMenuPlus1.dl_rgba16_begin_cutscene_msg_fade()
		GroupsIngameMenuPlus1.print_credits_str_ascii(mario_actions_cutscene.CREDIT_TEXT_X_LEFT, strY, titleStr)

		if numLines == 4 then
			GroupsIngameMenuPlus1.print_credits_str_ascii(mario_actions_cutscene.CREDIT_TEXT_X_LEFT, S16(strY + 24), strings[currStrPtr])
			currStrPtr += 1
			numLines = 2
			lineHeight = 24
		elseif numLines == 5 then
			GroupsIngameMenuPlus1.print_credits_str_ascii(mario_actions_cutscene.CREDIT_TEXT_X_LEFT, S16(strY + 16), strings[currStrPtr])
			currStrPtr += 1
			numLines = 3
		end

		while numLines > 0 do
			numLines = S16(numLines - 1)
			GroupsIngameMenuPlus1.print_credits_str_ascii(S16(mario_actions_cutscene.CREDIT_TEXT_X_RIGHT - mario_actions_cutscene.get_credits_str_width(strings[currStrPtr])), strY, strings[currStrPtr])

			strY = S16(strY + lineHeight)

			currStrPtr += 1
		end

		GroupsIngameMenuPlus1.dl_rgba16_stop_cutscene_msg_fade()
		mario_actions_cutscene.sDispCreditsEntry = nil
	end
end

-- from src/game/mario_actions_cutscene.c:bhv_end_peach_loop L173-181
function mario_actions_cutscene.bhv_end_peach_loop()
	Registry.Members.src__game__object_helpers.cur_obj_init_animation_with_sound(mario_actions_cutscene.sEndPeachAnimation)

	if Registry.Members.src__game__object_helpers.cur_obj_check_if_near_animation_end() ~= 0 then
		-- anims: 0-3, 4, 5, 6-8, 9, 10, 11
		if mario_actions_cutscene.sEndPeachAnimation < 3 or mario_actions_cutscene.sEndPeachAnimation == 6 or mario_actions_cutscene.sEndPeachAnimation == 7 then
			mario_actions_cutscene.sEndPeachAnimation = S16(mario_actions_cutscene.sEndPeachAnimation + 1)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:bhv_end_toad_loop L183-193
function mario_actions_cutscene.bhv_end_toad_loop()
	const toadAnimIndex = if buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosX) >= 0.0 then 1 else 0

	Registry.Members.src__game__object_helpers.cur_obj_init_animation_with_sound(mario_actions_cutscene.sEndToadAnims[toadAnimIndex + 1])

	if Registry.Members.src__game__object_helpers.cur_obj_check_if_near_animation_end() ~= 0 then
		-- 0-1, 2-3, 4, 5, 6, 7
		if mario_actions_cutscene.sEndToadAnims[toadAnimIndex + 1] == 0 or mario_actions_cutscene.sEndToadAnims[toadAnimIndex + 1] == 2 then
			mario_actions_cutscene.sEndToadAnims[toadAnimIndex + 1] = S16(mario_actions_cutscene.sEndToadAnims[toadAnimIndex + 1] + 1)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:geo_switch_peach_eyes L196-214
function mario_actions_cutscene.geo_switch_peach_eyes(run: number, node: GroupsTypesHPlus3.GraphNode, a2: number): number
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase

	if run == IncludePRUltratypesH.TRUE then
		if mario_actions_cutscene.D_8032CBE4 == 0 then
			const timer = S16(bit32.band(bit32.rshift(RenderingGraphNode.gAreaUpdateCounter + 0x20, 1), 0x1F))

			if timer < 7 then
				switchCase.selectedCase = S16(mario_actions_cutscene.D_8032CBE8 * 4 + mario_actions_cutscene.D_8032CBEC[timer + 1])
			else
				switchCase.selectedCase = S16(mario_actions_cutscene.D_8032CBE8 * 4 + 1)
			end
		else
			switchCase.selectedCase = S16(mario_actions_cutscene.D_8032CBE8 * 4 + mario_actions_cutscene.D_8032CBE4 - 1)
		end
	end

	return 0
end

-- from src/game/mario_actions_cutscene.c:stub_is_textbox_active L217-221
function mario_actions_cutscene.stub_is_textbox_active(arg: { number })
	if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
		arg[1] = 0
	end
end

-- from src/game/mario_actions_cutscene.c:get_star_collection_dialog L230-245
function mario_actions_cutscene.get_star_collection_dialog(m: GroupsTypesHPlus3.MarioState): number
	local dialogID = 0

	for i = 0, IncludeMacrosH.ARRAY_COUNT(mario_actions_cutscene.sStarsNeededForDialog) - 1 do
		const numStarsRequired = mario_actions_cutscene.sStarsNeededForDialog[i + 1]

		if m.prevNumStarsForDialog < numStarsRequired and m.numStars >= numStarsRequired then
			dialogID = i + IncludeDialogIdsH.DIALOG_141

			break
		end
	end

	m.prevNumStarsForDialog = m.numStars

	return dialogID
end

-- from src/game/mario_actions_cutscene.c:handle_save_menu L248-276
function mario_actions_cutscene.handle_save_menu(m: GroupsTypesHPlus3.MarioState)
	if Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 and Area.gSaveOptSelectIndex ~= GroupsTypesHPlus3.MENU_OPT_NONE then
		-- save and continue / save and quit
		if Area.gSaveOptSelectIndex == GroupsTypesHPlus3.MENU_OPT_SAVE_AND_CONTINUE or Area.gSaveOptSelectIndex == GroupsTypesHPlus3.MENU_OPT_SAVE_AND_QUIT then
			SaveFile.save_file_do_save(Area.gCurrSaveFileNum - 1)

			if Area.gSaveOptSelectIndex == GroupsTypesHPlus3.MENU_OPT_SAVE_AND_QUIT then
				LevelUpdate.fade_into_special_warp(-2, 0)
			end
		end

		-- not quitting
		if Area.gSaveOptSelectIndex ~= GroupsTypesHPlus3.MENU_OPT_SAVE_AND_QUIT then
			Registry.Members.src__game__object_helpers.disable_time_stop()
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)

			-- figure out what dialog to show, if we should
			const dialogID = mario_actions_cutscene.get_star_collection_dialog(m)

			if dialogID ~= 0 then
				Audio.play_peachs_jingle()
				Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_READING_AUTOMATIC_DIALOG, dialogID)
			else
				Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
			end
		end
	end
end

-- from src/game/mario_actions_cutscene.c:spawn_obj_at_mario_rel_yaw L283-292
function mario_actions_cutscene.spawn_obj_at_mario_rel_yaw(m: GroupsTypesHPlus3.MarioState, model: number, behavior: number, relYaw: number): GroupsTypesHPlus3.Object
	relYaw = S16(TruncS32(relYaw))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object(m.marioObj :: GroupsTypesHPlus3.Object, model, behavior)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(m.faceAngle[2] + relYaw))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, m.pos[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, m.pos[2])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, m.pos[3])

	return o
end

-- from src/game/mario_actions_cutscene.c:cutscene_take_cap_off L299-303
function mario_actions_cutscene.cutscene_take_cap_off(m: GroupsTypesHPlus3.MarioState)
	m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))
	m.flags = bit32.bor(m.flags, Registry.Members.include__sm64_h.MARIO_CAP_IN_HAND)
	Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN43D, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
end

-- from src/game/mario_actions_cutscene.c:cutscene_put_cap_on L310-314
function mario_actions_cutscene.cutscene_put_cap_on(m: GroupsTypesHPlus3.MarioState)
	m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_CAP_IN_HAND))
	m.flags = bit32.bor(m.flags, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD)
	Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN43E, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
end

-- from src/game/mario_actions_cutscene.c:mario_ready_to_speak L325-337
function mario_actions_cutscene.mario_ready_to_speak(): number
	const actionGroup = bit32.band(LevelUpdate.gMarioState.action, Registry.Members.include__sm64_h.ACT_GROUP_MASK)
	local isReadyToSpeak = IncludePRUltratypesH.FALSE

	if (LevelUpdate.gMarioState.action == Registry.Members.include__sm64_h.ACT_WAITING_FOR_DIALOG or actionGroup == Registry.Members.include__sm64_h.ACT_GROUP_STATIONARY or actionGroup == Registry.Members.include__sm64_h.ACT_GROUP_MOVING)
		and not bit32.btest(LevelUpdate.gMarioState.action, bit32.bor(Registry.Members.include__sm64_h.ACT_FLAG_RIDING_SHELL, Registry.Members.include__sm64_h.ACT_FLAG_INVULNERABLE))
		and LevelUpdate.gMarioState.action ~= Registry.Members.include__sm64_h.ACT_FIRST_PERSON then
		isReadyToSpeak = IncludePRUltratypesH.TRUE
	end

	return isReadyToSpeak
end

-- from src/game/mario_actions_cutscene.c:set_mario_npc_dialog L345-367
function mario_actions_cutscene.set_mario_npc_dialog(actionArg: number): number
	local dialogState = MarioActionsCutsceneH.MARIO_DIALOG_STATUS_NONE

	-- in dialog
	if LevelUpdate.gMarioState.action == Registry.Members.include__sm64_h.ACT_READING_NPC_DIALOG then
		if LevelUpdate.gMarioState.actionState < 8 then
			dialogState = MarioActionsCutsceneH.MARIO_DIALOG_STATUS_START
		end

		if LevelUpdate.gMarioState.actionState == 8 then
			if actionArg == MarioActionsCutsceneH.MARIO_DIALOG_STOP then
				LevelUpdate.gMarioState.actionState = U16(LevelUpdate.gMarioState.actionState + 1)
			else
				dialogState = MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK
			end
		end
	elseif actionArg ~= 0 and mario_actions_cutscene.mario_ready_to_speak() ~= 0 then
		LevelUpdate.gMarioState.usedObj = Registry.Members.src__game__object_list_processor.gCurrentObject
		Registry.Members.src__game__mario.set_mario_action(LevelUpdate.gMarioState, Registry.Members.include__sm64_h.ACT_READING_NPC_DIALOG, actionArg)
		dialogState = MarioActionsCutsceneH.MARIO_DIALOG_STATUS_START
	end

	return dialogState
end

-- from src/game/mario_actions_cutscene.c:act_reading_npc_dialog L378-418
function mario_actions_cutscene.act_reading_npc_dialog(m: GroupsTypesHPlus3.MarioState): number
	local headTurnAmount = 0

	if m.actionArg == MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP then
		headTurnAmount = -1024
	end

	if m.actionArg == MarioActionsCutsceneH.MARIO_DIALOG_LOOK_DOWN then
		headTurnAmount = 384
	end

	if m.actionState < 8 then
		-- turn to NPC
		const angleToNPC = S16(Registry.Members.src__game__interaction.mario_obj_angle_to_object(m, m.usedObj :: GroupsTypesHPlus3.Object))

		m.faceAngle[2] = S16(angleToNPC - SrcEngineMathUtil.approach_s32(S16(angleToNPC - m.faceAngle[2]), 0, 2048, 2048))

		-- turn head to npc
		m.actionTimer = U16(m.actionTimer + headTurnAmount)

		-- set animation
		Registry.Members.src__game__mario.set_mario_animation(m, if m.heldObj == nil then IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON else IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
	elseif m.actionState >= 9 and m.actionState < 17 then
		-- look back from facing NPC
		m.actionTimer = U16(m.actionTimer - headTurnAmount)
	elseif m.actionState == 23 then
		if bit32.btest(m.flags, Registry.Members.include__sm64_h.MARIO_CAP_IN_HAND) then
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_PUTTING_ON_CAP, 0)
		else
			Registry.Members.src__game__mario.set_mario_action(m, if m.heldObj == nil then Registry.Members.include__sm64_h.ACT_IDLE else Registry.Members.include__sm64_h.ACT_HOLD_IDLE, 0)
		end
	end

	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.angle, 0, m.faceAngle[2], 0)
	SrcEngineMathUtil.vec3s_set((m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState).headAngle, S16(m.actionTimer), 0, 0)

	if m.actionState ~= 8 then
		m.actionState = U16(m.actionState + 1)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_waiting_for_dialog L421-427
function mario_actions_cutscene.act_waiting_for_dialog(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.set_mario_animation(m, if m.heldObj == nil then IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON else IncludeMarioAnimationIdsH.MARIO_ANIM_IDLE_WITH_LIGHT_OBJ)
	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.angle, 0, m.faceAngle[2], 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_disappeared L430-441
function mario_actions_cutscene.act_disappeared(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_A_POSE)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

	if m.actionArg ~= 0 then
		m.actionArg = U32(m.actionArg - 1)

		if bit32.band(m.actionArg, 0xFFFF) == 0 then
			LevelUpdate.level_trigger_warp(m, bit32.rshift(m.actionArg, 16))
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_reading_automatic_dialog L443-494
function mario_actions_cutscene.act_reading_automatic_dialog(m: GroupsTypesHPlus3.MarioState): number
	m.actionState = U16(m.actionState + 1)

	if m.actionState == 2 then
		Registry.Members.src__game__object_helpers.enable_time_stop()
	end

	if m.actionState < 9 then
		Registry.Members.src__game__mario.set_mario_animation(m, if m.prevAction == Registry.Members.include__sm64_h.ACT_STAR_DANCE_WATER then IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_IDLE else IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)
		-- always look up for automatic dialogs
		m.actionTimer = U16(m.actionTimer - 1024)
	else
		-- set Mario dialog
		if m.actionState == 9 then
			const actionArg = m.actionArg
			const actionArgHigh: number = Registry.Members.include__sm64_h.GET_HIGH_U16_OF_32(actionArg)
			const actionArgLow: number = Registry.Members.include__sm64_h.GET_LOW_U16_OF_32(actionArg)

			if actionArgHigh == 0 then
				GroupsIngameMenuPlus1.create_dialog_box(actionArgLow)
			else
				GroupsIngameMenuPlus1.create_dialog_box_with_var(actionArgHigh, actionArgLow)
			end
		-- wait until dialog is done
		elseif m.actionState == 10 then
			if GroupsIngameMenuPlus1.get_dialog_id() >= 0 then
				m.actionState = U16(m.actionState - 1)
			end
		-- look back down
		elseif m.actionState < 19 then
			m.actionTimer = U16(m.actionTimer + 1024)
		-- finished action
		elseif m.actionState == 25 then
			Registry.Members.src__game__object_helpers.disable_time_stop()

			if LevelUpdate.gNeverEnteredCastle ~= 0 then
				LevelUpdate.gNeverEnteredCastle = 0
				SoundInit.play_cutscene_music(SequenceArgs(0, IncludeSeqIdsH.SEQ_LEVEL_INSIDE_CASTLE))
			end

			if m.prevAction == Registry.Members.include__sm64_h.ACT_STAR_DANCE_WATER then
				Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_WATER_IDLE, 0) -- 100c star?
			else
				-- make Mario walk into door after star dialog
				Registry.Members.src__game__mario.set_mario_action(m, if m.prevAction == Registry.Members.include__sm64_h.ACT_UNLOCKING_STAR_DOOR then Registry.Members.include__sm64_h.ACT_WALKING else Registry.Members.include__sm64_h.ACT_IDLE, 0)
			end
		end
	end

	-- apply head turn
	SrcEngineMathUtil.vec3s_set((m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState).headAngle, S16(m.actionTimer), 0, 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_reading_sign L496-534
function mario_actions_cutscene.act_reading_sign(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_READ_SIGN, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)

	if m.actionState == 0 then
		Registry.Members.src__game__camera.trigger_cutscene_dialog(1)
		Registry.Members.src__game__object_helpers.enable_time_stop()
		-- reading sign
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)
		m.actionState = 1
		-- intentional fall through
	end

	-- turn toward sign, create the text box
	if m.actionState == 1 then
		m.faceAngle[2] = S16(m.faceAngle[2] + TruncS32(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleUnk108) / 11))
		m.pos[1] = F32(m.pos[1] + F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX) / 11.0))
		m.pos[3] = F32(m.pos[3] + F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ) / 11.0))

		const actionTimer = m.actionTimer

		m.actionTimer = U16(m.actionTimer + 1)

		if actionTimer == 10 then
			GroupsIngameMenuPlus1.create_dialog_inverted_box(buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
			m.actionState = 2
		end
	elseif m.actionState == 2 then
		-- in dialog: dialog finished
		if Registry.Members.src__game__camera.gCamera.cutscene == 0 then
			Registry.Members.src__game__object_helpers.disable_time_stop()
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
		end
	end

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_debug_free_move L536-588
function mario_actions_cutscene.act_debug_free_move(m: GroupsTypesHPlus3.MarioState): number
	local speed = if bit32.btest(GameInit.gPlayer1Controller.buttonDown, Registry.Members.include__PR__os_h.B_BUTTON) then 4 else 1

	if bit32.btest(GameInit.gPlayer1Controller.buttonDown, Registry.Members.include__PR__os_h.L_TRIG) then
		speed = F32(0.01)
	end

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_A_POSE)
	SrcEngineMathUtil.vec3f_copy(DebugPos, m.pos)

	if bit32.btest(GameInit.gPlayer1Controller.buttonDown, Registry.Members.include__PR__os_h.U_JPAD) then
		DebugPos[2] = F32(DebugPos[2] + F32(16.0 * speed))
	end

	if bit32.btest(GameInit.gPlayer1Controller.buttonDown, Registry.Members.include__PR__os_h.D_JPAD) then
		DebugPos[2] = F32(DebugPos[2] - F32(16.0 * speed))
	end

	if m.intendedMag > 0 then
		const sinYaw: number = Registry.Members.src__engine__math_util_h.sins(m.intendedYaw)
		const cosYaw: number = Registry.Members.src__engine__math_util_h.coss(m.intendedYaw)

		DebugPos[1] = F32(DebugPos[1] + F32(F32(32.0 * speed) * sinYaw))
		DebugPos[3] = F32(DebugPos[3] + F32(F32(32.0 * speed) * cosYaw))
	end

	Registry.Members.src__game__mario.resolve_and_return_wall_collisions(DebugPos, 60.0, 50.0)

	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(DebugPos[1], DebugPos[2], DebugPos[3], Floor)
	const surf = Floor[1]

	if surf ~= nil then
		if DebugPos[2] < floorHeight then
			DebugPos[2] = floorHeight
		end

		SrcEngineMathUtil.vec3f_copy(m.pos, DebugPos)
	end

	m.faceAngle[2] = m.intendedYaw
	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.angle, 0, m.faceAngle[2], 0)

	if GameInit.gPlayer1Controller.buttonPressed == Registry.Members.include__PR__os_h.A_BUTTON then
		const action = if m.pos[2] <= m.waterLevel - 100 then Registry.Members.include__sm64_h.ACT_WATER_IDLE else Registry.Members.include__sm64_h.ACT_IDLE

		Registry.Members.src__game__mario.set_mario_action(m, action, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:general_star_dance_handler L590-638
function mario_actions_cutscene.general_star_dance_handler(m: GroupsTypesHPlus3.MarioState, isInWater: number)
	if m.actionState == 0 then
		m.actionTimer = U16(m.actionTimer + 1)

		if m.actionTimer == 1 then
			Registry.Members.src__game__object_helpers.spawn_object(m.marioObj :: GroupsTypesHPlus3.Object, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvCelebrationStar)
			SoundInit.disable_background_sound()

			if bit32.btest(m.actionArg, 1) then
				Audio.play_course_clear()
			else
				if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_1 or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
					Audio.play_music(SeqPlayerEnv, SequenceArgs(15, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_COLLECT_KEY), 0)
				else
					Audio.play_music(SeqPlayerEnv, SequenceArgs(15, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_COLLECT_STAR), 0)
				end
			end
		elseif m.actionTimer == 42 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		elseif m.actionTimer == 80 then
			if not bit32.btest(m.actionArg, 1) then
				LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_STAR_EXIT)
			else
				Registry.Members.src__game__object_helpers.enable_time_stop()
				GroupsIngameMenuPlus1.create_dialog_box_with_response(if SaveFile.gLastCompletedStarNum == 7 then IncludeDialogIdsH.DIALOG_013 else IncludeDialogIdsH.DIALOG_014)
				m.actionState = 1
			end
		end
	elseif m.actionState == 1 and GroupsIngameMenuPlus1.gDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
		if GroupsIngameMenuPlus1.gDialogResponse == GroupsIngameMenuPlus1.DIALOG_RESPONSE_YES then
			SaveFile.save_file_do_save(Area.gCurrSaveFileNum - 1)
		end

		m.actionState = 2
	elseif m.actionState == 2 and Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		Registry.Members.src__game__object_helpers.disable_time_stop()
		SoundInit.enable_background_sound()

		const dialogID = mario_actions_cutscene.get_star_collection_dialog(m)

		if dialogID ~= 0 then
			-- look up for dialog
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_READING_AUTOMATIC_DIALOG, dialogID)
		else
			Registry.Members.src__game__mario.set_mario_action(m, if isInWater ~= 0 then Registry.Members.include__sm64_h.ACT_WATER_IDLE else Registry.Members.include__sm64_h.ACT_IDLE, 0)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:act_star_dance L640-650
function mario_actions_cutscene.act_star_dance(m: GroupsTypesHPlus3.MarioState): number
	const area = m.area :: GroupsTypesHPlus3.Area
	const camera = area.camera :: GroupsTypesHPlus3.Camera

	m.faceAngle[2] = camera.yaw

	Registry.Members.src__game__mario.set_mario_animation(m, if m.actionState == 2 then IncludeMarioAnimationIdsH.MARIO_ANIM_RETURN_FROM_STAR_DANCE else IncludeMarioAnimationIdsH.MARIO_ANIM_STAR_DANCE)
	mario_actions_cutscene.general_star_dance_handler(m, 0)

	if m.actionState ~= 2 and m.actionTimer >= 40 then
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_PEACE_SIGN
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_star_dance_water L652-663
function mario_actions_cutscene.act_star_dance_water(m: GroupsTypesHPlus3.MarioState): number
	const area = m.area :: GroupsTypesHPlus3.Area
	const camera = area.camera :: GroupsTypesHPlus3.Camera

	m.faceAngle[2] = camera.yaw

	Registry.Members.src__game__mario.set_mario_animation(m, if m.actionState == 2 then IncludeMarioAnimationIdsH.MARIO_ANIM_RETURN_FROM_WATER_STAR_DANCE else IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_STAR_DANCE)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	mario_actions_cutscene.general_star_dance_handler(m, 1)

	if m.actionState ~= 2 and m.actionTimer >= 62 then
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_PEACE_SIGN
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_fall_after_star_grab L665-678
function mario_actions_cutscene.act_fall_after_star_grab(m: GroupsTypesHPlus3.MarioState): number
	if m.pos[2] < m.waterLevel - 130 then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN430, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_WATER_SPLASH)

		const actionResult: number = Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_STAR_DANCE_WATER, m.actionArg)

		return actionResult
	end

	if Registry.Members.src__game__mario_step.perform_air_step(m, 1) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
		Registry.Members.src__game__mario.set_mario_action(m, if bit32.btest(m.actionArg, 1) then Registry.Members.include__sm64_h.ACT_STAR_DANCE_NO_EXIT else Registry.Members.include__sm64_h.ACT_STAR_DANCE_EXIT, m.actionArg)
	end

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:common_death_handler L680-688
function mario_actions_cutscene.common_death_handler(m: GroupsTypesHPlus3.MarioState, animation: number, frameToDeathWarp: number): number
	const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, animation)

	if animFrame == frameToDeathWarp then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
	end

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_DEAD

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return animFrame
end

-- from src/game/mario_actions_cutscene.c:act_standing_death L690-701
function mario_actions_cutscene.act_standing_death(m: GroupsTypesHPlus3.MarioState): number
	if bit32.btest(m.input, Registry.Members.include__sm64_h.INPUT_IN_POISON_GAS) then
		const actionResult: number = Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SUFFOCATION, 0)

		return actionResult
	end

	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	mario_actions_cutscene.common_death_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DYING_FALL_OVER, 80)

	if (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame == 77 then
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_electrocution L703-707
function mario_actions_cutscene.act_electrocution(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	mario_actions_cutscene.common_death_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_ELECTROCUTION, 43)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_suffocation L709-713
function mario_actions_cutscene.act_suffocation(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	mario_actions_cutscene.common_death_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SUFFOCATING, 86)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_death_on_back L715-721
function mario_actions_cutscene.act_death_on_back(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)

	if mario_actions_cutscene.common_death_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DYING_ON_BACK, 54) == 40 then
		Registry.Members.src__game__mario.play_mario_heavy_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_death_on_stomach L723-729
function mario_actions_cutscene.act_death_on_stomach(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)

	if mario_actions_cutscene.common_death_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DYING_ON_STOMACH, 37) == 37 then
		Registry.Members.src__game__mario.play_mario_heavy_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_quicksand_death L731-749
function mario_actions_cutscene.act_quicksand_death(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DYING_IN_QUICKSAND)
		Registry.Members.src__game__mario.set_anim_to_frame(m, 60)
		m.actionState = 1
	end

	if m.actionState == 1 then
		if m.quicksandDepth >= 100.0 then
			Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAAAOOOW, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
		end

		m.quicksandDepth = F32(m.quicksandDepth + 5.0)

		if m.quicksandDepth >= 180.0 then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
			m.actionState = 2
		end
	end

	Registry.Members.src__game__mario_step.stationary_ground_step(m)
	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_QUICKSAND_DEATH, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_eaten_by_bubba L751-760
function mario_actions_cutscene.act_eaten_by_bubba(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_DYING, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_A_POSE)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

	m.health = 0xFF

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 60 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:launch_mario_until_land L764-773
function mario_actions_cutscene.launch_mario_until_land(m: GroupsTypesHPlus3.MarioState, endAction: number, animation: number, forwardVel: number): number
	forwardVel = F32(forwardVel)
	Registry.Members.src__game__mario.mario_set_forward_vel(m, forwardVel)
	Registry.Members.src__game__mario.set_mario_animation(m, animation)

	const airStepLanded = if Registry.Members.src__game__mario_step.perform_air_step(m, 0) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then 1 else 0

	if airStepLanded ~= 0 then
		Registry.Members.src__game__mario.set_mario_action(m, endAction, 0)
	end

	return airStepLanded
end

-- from src/game/mario_actions_cutscene.c:act_unlocking_key_door L775-815
function mario_actions_cutscene.act_unlocking_key_door(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object

	m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	const cosYaw: number = Registry.Members.src__engine__math_util_h.coss(m.faceAngle[2])
	const sinYaw: number = Registry.Members.src__engine__math_util_h.sins(m.faceAngle[2])

	m.pos[1] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX) + F32(cosYaw * 75.0))
	m.pos[3] = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ) + F32(sinYaw * 75.0))

	if bit32.btest(m.actionArg, 2) then
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
	end

	if m.actionTimer == 0 then
		mario_actions_cutscene.spawn_obj_at_mario_rel_yaw(m, IncludeModelIdsH.MODEL_BOWSER_KEY_CUTSCENE, BehaviorIds.bhvBowserKeyUnlockDoor, 0)
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_UNLOCK_DOOR)
	end

	const animFrame = (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.animInfo.animFrame

	if animFrame == 79 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_DOOR_INSERT_KEY, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif animFrame == 111 then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_DOOR_TURN_KEY, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	Registry.Members.src__game__mario.update_mario_pos_for_anim(m)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		if buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 24 == 1 then
			SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)
			SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_HAVE_KEY_2)
		else
			SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)
			SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_HAVE_KEY_1)
		end

		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_WALKING, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_unlocking_star_door L817-856
function mario_actions_cutscene.act_unlocking_star_door(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.actionState == 0 then
		m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		if bit32.btest(m.actionArg, 2) then
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		end

		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX, m.pos[1])
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ, m.pos[3])
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SUMMON_STAR)
		m.actionState = U16(m.actionState + 1)
	elseif m.actionState == 1 then
		if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
			Registry.Members.src__game__object_helpers.spawn_object(marioObj, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvUnlockDoorStar)
			m.actionState = U16(m.actionState + 1)
		end
	elseif m.actionState == 2 then
		const actionTimer = m.actionTimer

		m.actionTimer = U16(m.actionTimer + 1)

		if actionTimer == 70 then
			Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RETURN_STAR_APPROACH_DOOR)
			m.actionState = U16(m.actionState + 1)
		end
	elseif m.actionState == 3 then
		if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
			const doorSaveFileFlag: number = Registry.Members.src__game__interaction.get_door_save_file_flag(usedObj)

			SaveFile.save_file_set_flags(doorSaveFileFlag)
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_READING_AUTOMATIC_DIALOG, IncludeDialogIdsH.DIALOG_038)
		end
	end

	m.pos[1] = buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX)
	m.pos[3] = buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ)

	Registry.Members.src__game__mario.update_mario_pos_for_anim(m)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_entering_star_door L858-917
function mario_actions_cutscene.act_entering_star_door(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 0 then
		const interactObj = m.interactObj :: GroupsTypesHPlus3.Object

		buffer.writei32(interactObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_UNK16)

		-- ~30 degrees / 1/12 rot
		local targetAngle = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x1555)

		if bit32.btest(m.actionArg, 2) then
			targetAngle = S16(targetAngle + 0x5556) -- ~120 degrees / 1/3 rot (total 150d / 5/12)
		end

		-- targetDX and targetDZ are the offsets to add to Mario's position to
		-- have Mario stand 150 units in front of the door
		const sinTarget: number = Registry.Members.src__engine__math_util_h.sins(targetAngle)
		const cosTarget: number = Registry.Members.src__engine__math_util_h.coss(targetAngle)

		const targetDX = F32(F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX) + F32(150.0 * sinTarget)) - m.pos[1])
		const targetDZ = F32(F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ) + F32(150.0 * cosTarget)) - m.pos[3])

		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX, targetDX / 20.0)
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ, targetDZ / 20.0)

		m.faceAngle[2] = SrcEngineMathUtil.atan2s(targetDZ, targetDX)
	end

	-- set Mario's animation
	if m.actionTimer < 15 then
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

	-- go through door? for 20 frames
	elseif m.actionTimer < 35 then
		m.pos[1] = F32(m.pos[1] + buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX))
		m.pos[3] = F32(m.pos[3] + buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ))

		Registry.Members.src__game__mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING, 0x00028000)
	else
		m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		if bit32.btest(m.actionArg, 2) then
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		end

		const sinYaw: number = Registry.Members.src__engine__math_util_h.sins(m.faceAngle[2])
		const cosYaw: number = Registry.Members.src__engine__math_util_h.coss(m.faceAngle[2])

		m.pos[1] = F32(m.pos[1] + F32(12.0 * sinYaw))
		m.pos[3] = F32(m.pos[3] + F32(12.0 * cosYaw))

		Registry.Members.src__game__mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WALKING, 0x00028000)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if m.actionTimer == 48 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_going_through_door L919-949
function mario_actions_cutscene.act_going_through_door(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object

	if m.actionTimer == 0 then
		const interactObj = m.interactObj :: GroupsTypesHPlus3.Object

		if bit32.btest(m.actionArg, 1) then
			buffer.writei32(interactObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_UNK16)
			Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PULL_DOOR_WALK_IN)
		else
			buffer.writei32(interactObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_UNK17)
			Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PUSH_DOOR_WALK_IN)
		end
	end

	m.faceAngle[2] = S16(buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	m.pos[1] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX)
	m.pos[3] = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ)

	Registry.Members.src__game__mario.update_mario_pos_for_anim(m)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if bit32.btest(m.actionArg, 4) then
		if m.actionTimer == 16 then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_WARP_DOOR)
		end
	elseif Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		if bit32.btest(m.actionArg, 2) then
			m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		end

		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_warp_door_spawn L951-969
function mario_actions_cutscene.act_warp_door_spawn(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object

	if m.actionState == 0 then
		m.actionState = 1

		if bit32.btest(m.actionArg, 1) then
			buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_UNK18)
		else
			buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_UNK19)
		end
	elseif buffer.readi32(usedObj.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if LevelUpdate.gNeverEnteredCastle == IncludePRUltratypesH.TRUE and Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE then
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_READING_AUTOMATIC_DIALOG, IncludeDialogIdsH.DIALOG_021)
		else
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
		end
	end

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_emerge_from_pipe L971-996
function mario_actions_cutscene.act_emerge_from_pipe(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer < 11 then
		marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

		return IncludePRUltratypesH.FALSE
	end

	marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))

	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_YAHOO, Registry.Members.include__sm64_h.MARIO_MARIO_SOUND_PLAYED)

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_THI then
		if Area.gCurrAreaIndex == 2 then
			Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MENU_EXIT_PIPE, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
		else
			Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MENU_ENTER_PIPE, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
		end
	end

	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_JUMP_LAND_STOP, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP, 8.0) ~= 0 then
		Registry.Members.src__game__mario.mario_set_forward_vel(m, 0.0)
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_spawn_spin_airborne L998-1028
function mario_actions_cutscene.act_spawn_spin_airborne(m: GroupsTypesHPlus3.MarioState): number
	-- entered water, exit action
	if m.pos[2] < m.waterLevel - 100 then
		LevelUpdate.load_level_init_text(0)

		const plungeResult: number = Registry.Members.src__game__mario.set_water_plunge_action(m)

		return plungeResult
	end

	-- updates all velocity variables based on m->forwardVel
	Registry.Members.src__game__mario.mario_set_forward_vel(m, m.forwardVel)

	-- landed on floor, play spawn land animation
	if Registry.Members.src__game__mario_step.perform_air_step(m, 0.0) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_SPAWN_SPIN_LANDING, 0)
	end

	-- is 300 units above floor, spin and play woosh sounds
	if m.actionState == 0 and F32(m.pos[2] - m.floorHeight) > 300.0 then
		if Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING) == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	-- under 300 units above floor, enter freefall animation
	else
		m.actionState = 1
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_spawn_spin_landing L1030-1038
function mario_actions_cutscene.act_spawn_spin_landing(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND)

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		LevelUpdate.load_level_init_text(0)
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_exit_airborne L1050-1060
function mario_actions_cutscene.act_exit_airborne(m: GroupsTypesHPlus3.MarioState): number
	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if 15 < actionTimer and mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_EXIT_LAND_SAVE_DIALOG, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, -32.0) ~= 0 then
		-- heal Mario
		m.healCounter = 31
	end

	-- rotate him to face away from the entrance
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_SPARKLES)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_falling_exit_airborne L1062-1071
function mario_actions_cutscene.act_falling_exit_airborne(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_EXIT_LAND_SAVE_DIALOG, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, 0.0) ~= 0 then
		-- heal Mario
		m.healCounter = 31
	end

	-- rotate Mario to face away from the entrance
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_SPARKLES)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_exit_land_save_dialog L1073-1154
function mario_actions_cutscene.act_exit_land_save_dialog(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario_step.stationary_ground_step(m)
	Registry.Members.src__game__mario.play_mario_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)

	if m.actionState == 0 then
		Registry.Members.src__game__mario.set_mario_animation(m, if m.actionArg == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND else IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP)

		if Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 then
			if SaveFile.gLastCompletedCourseNum ~= IncludeCourseTableH.COURSE_BITDW and SaveFile.gLastCompletedCourseNum ~= IncludeCourseTableH.COURSE_BITFS then
				Registry.Members.src__game__object_helpers.enable_time_stop()
			end

			GroupsIngameMenuPlus1.set_menu_mode(GroupsIngameMenuPlus1.MENU_MODE_RENDER_COURSE_COMPLETE_SCREEN)
			Area.gSaveOptSelectIndex = GroupsTypesHPlus3.MENU_OPT_NONE

			m.actionState = 3 -- star exit with cap
			if not bit32.btest(m.flags, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD) then
				m.actionState = 2 -- star exit without cap
			end

			if SaveFile.gLastCompletedCourseNum == IncludeCourseTableH.COURSE_BITDW or SaveFile.gLastCompletedCourseNum == IncludeCourseTableH.COURSE_BITFS then
				m.actionState = 1 -- key exit
			end
		end
	-- key exit
	elseif m.actionState == 1 then
		const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_THROW_CATCH_KEY)

		-- switch on animFrame with fallthrough: -1 -> 67 -> 83 -> 111
		if animFrame == -1 then
			mario_actions_cutscene.spawn_obj_at_mario_rel_yaw(m, IncludeModelIdsH.MODEL_BOWSER_KEY_CUTSCENE, BehaviorIds.bhvBowserKeyCourseExit, -32768)
		end

		if animFrame == -1 or animFrame == 67 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_KEY_SWISH, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		if animFrame == -1 or animFrame == 67 or animFrame == 83 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_PAT_BACK, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		if animFrame == -1 or animFrame == 67 or animFrame == 83 or animFrame == 111 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN45C, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		mario_actions_cutscene.handle_save_menu(m)
	-- exit without cap
	elseif m.actionState == 2 then
		const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_MISSING_CAP)
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		if (animFrame >= 18 and animFrame < 55) or (animFrame >= 112 and animFrame < 134) then
			marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_OPEN
		end

		if not (animFrame < 109) and animFrame < 154 then
			marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
		end

		mario_actions_cutscene.handle_save_menu(m)
	-- exit with cap
	elseif m.actionState == 3 then
		const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_TAKE_CAP_OFF_THEN_ON)

		if animFrame == 12 then
			mario_actions_cutscene.cutscene_take_cap_off(m)
		elseif animFrame == 37 or animFrame == 53 then
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_BRUSH_HAIR, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		elseif animFrame == 82 then
			mario_actions_cutscene.cutscene_put_cap_on(m)
		end

		mario_actions_cutscene.handle_save_menu(m)
	end

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_death_exit L1156-1174
function mario_actions_cutscene.act_death_exit(m: GroupsTypesHPlus3.MarioState): number
	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if 15 < actionTimer and mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_DEATH_EXIT_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, -32.0) ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.numLives = S8(m.numLives - 1)
		-- restore 7.75 units of health
		m.healCounter = 31
	end

	-- one unit of health
	m.health = 0x0100

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_unused_death_exit L1176-1190
function mario_actions_cutscene.act_unused_death_exit(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_FREEFALL_LAND_STOP, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, 0.0) ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.numLives = S8(m.numLives - 1)
		-- restore 7.75 units of health
		m.healCounter = 31
	end

	-- one unit of health
	m.health = 0x0100

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_falling_death_exit L1192-1209
function mario_actions_cutscene.act_falling_death_exit(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_DEATH_EXIT_LAND, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, 0.0) ~= 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		m.numLives = S8(m.numLives - 1)
		-- restore 7.75 units of health
		m.healCounter = 31
	end

	-- one unit of health
	m.health = 0x0100

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_special_exit_airborne L1212-1235
function mario_actions_cutscene.act_special_exit_airborne(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_YAHOO, Registry.Members.include__sm64_h.MARIO_MARIO_SOUND_PLAYED)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer < 11 then
		marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

		return IncludePRUltratypesH.FALSE
	end

	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_EXIT_LAND_SAVE_DIALOG, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP, -24.0) ~= 0 then
		-- heal Mario
		m.healCounter = 31
		m.actionArg = 1
	end

	m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_SPARKLES)
	-- rotate Mario to face away from the entrance
	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	-- show Mario
	marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_special_death_exit L1237-1258
function mario_actions_cutscene.act_special_death_exit(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer < 11 then
		marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

		return IncludePRUltratypesH.FALSE
	end

	if mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_HARD_BACKWARD_GROUND_KB, IncludeMarioAnimationIdsH.MARIO_ANIM_BACKWARD_AIR_KB, -24.0) ~= 0 then
		m.numLives = S8(m.numLives - 1)
		m.healCounter = 31
	end

	-- show Mario
	marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
	-- one unit of health
	m.health = 0x0100

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_spawn_no_spin_airborne L1260-1266
function mario_actions_cutscene.act_spawn_no_spin_airborne(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_cutscene.launch_mario_until_land(m, Registry.Members.include__sm64_h.ACT_SPAWN_NO_SPIN_LANDING, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL, 0.0)

	if m.pos[2] < m.waterLevel - 100 then
		Registry.Members.src__game__mario.set_water_plunge_action(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_spawn_no_spin_landing L1268-1277
function mario_actions_cutscene.act_spawn_no_spin_landing(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_mario_landing_sound_once(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		LevelUpdate.load_level_init_text(0)
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_bbh_enter_spin L1279-1361
function mario_actions_cutscene.act_bbh_enter_spin(m: GroupsTypesHPlus3.MarioState): number
	const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
	const cageDX = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX) - m.pos[1])
	const cageDZ = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ) - m.pos[3])
	const cageDist = F32(math.sqrt(F32(F32(cageDX * cageDX) + F32(cageDZ * cageDZ))))

	local forwardVel = 0.0

	if cageDist > 20.0 then
		forwardVel = 10.0
	else
		forwardVel = F32(cageDist / 2.0)
	end

	if forwardVel < 0.5 then
		forwardVel = 0.0
	end

	if m.actionState == 0 then
		const floorDist = F32(512.0 - F32(m.pos[2] - m.floorHeight))

		m.vel[2] = if floorDist > 0 then F32(F32(math.sqrt(F32(F32(4.0 * floorDist) + 1.0))) - 1.0) else 2.0

		m.actionState = 1
		m.actionTimer = 100
	end

	if m.actionState == 1 then
		m.faceAngle[2] = SrcEngineMathUtil.atan2s(cageDZ, cageDX)
			Registry.Members.src__game__mario.mario_set_forward_vel(m, forwardVel)

			if Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FORWARD_SPINNING) == 0 then
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_SPIN, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			end

		m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_UNKNOWN_08))
		Registry.Members.src__game__mario_step.perform_air_step(m, 0)

		if m.vel[2] <= 0 then
			m.actionState = 2
		end
	elseif m.actionState == 2 or m.actionState == 3 then
		m.faceAngle[2] = SrcEngineMathUtil.atan2s(cageDZ, cageDX)
		Registry.Members.src__game__mario.mario_set_forward_vel(m, forwardVel)
		m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_UNKNOWN_08))

		if Registry.Members.src__game__mario_step.perform_air_step(m, 0) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_UNKNOWN_02)
			m.actionState = 4
		end

		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		if m.actionState == 2 then
			if marioObj.header.gfx.animInfo.animFrame == 0 then
				m.actionState = 3
			end
		else
			Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_SHRINK_INTO_BBH, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
			Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DIVE)
			marioObj.header.gfx.angle[1] = SrcEngineMathUtil.atan2s(m.forwardVel, -m.vel[2])
		end

		m.squishTimer = 0xFF

		if m.actionTimer >= 11 then
			m.actionTimer = U16(m.actionTimer - 6)

			const scale = F32(m.actionTimer / 100.0)

			SrcEngineMathUtil.vec3f_set(marioObj.header.gfx.scale, scale, scale, scale)
		end
	elseif m.actionState == 4 then
		Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_bbh_enter_jump L1363-1393
function mario_actions_cutscene.act_bbh_enter_jump(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_mario_action_sound(m, if bit32.btest(m.flags, Registry.Members.include__sm64_h.MARIO_METAL_CAP) then IncludeSoundsH.SOUND_ACTION_METAL_JUMP else IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 1)
	Registry.Members.src__game__mario.play_mario_jump_sound(m)

	if m.actionState == 0 then
		const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
		const cageDX = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosX) - m.pos[1])
		const cageDZ = F32(buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosZ) - m.pos[3])
		const cageDist = F32(math.sqrt(F32(F32(cageDX * cageDX) + F32(cageDZ * cageDZ))))

		m.vel[2] = 60.0
		m.faceAngle[2] = SrcEngineMathUtil.atan2s(cageDZ, cageDX)
		Registry.Members.src__game__mario.mario_set_forward_vel(m, F32(cageDist / 20.0))

		m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_UNKNOWN_08))
		m.actionState = 1
	end

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_DOUBLE_JUMP_RISE)
	Registry.Members.src__game__mario_step.perform_air_step(m, 0)

	if m.vel[2] <= 0.0 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_BBH_ENTER_SPIN, 0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_teleport_fade_out L1395-1420
function mario_actions_cutscene.act_teleport_fade_out(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_TELEPORT, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	Registry.Members.src__game__mario.set_mario_animation(m, if m.prevAction == Registry.Members.include__sm64_h.ACT_CROUCHING then IncludeMarioAnimationIdsH.MARIO_ANIM_CROUCHING else IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

	m.flags = bit32.bor(m.flags, Registry.Members.include__sm64_h.MARIO_TELEPORTING)

	if m.actionTimer < 32 then
		m.fadeWarpOpacity = U8(bit32.lshift(-m.actionTimer, 3) + 0xF8)
	end

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 20 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_TELEPORT)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_teleport_fade_in L1422-1455
function mario_actions_cutscene.act_teleport_fade_in(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_TELEPORT, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

	if m.actionTimer < 32 then
		m.flags = bit32.bor(m.flags, Registry.Members.include__sm64_h.MARIO_TELEPORTING)
		m.fadeWarpOpacity = U8(bit32.lshift(m.actionTimer, 3))
	else
		m.flags = bit32.band(m.flags, bit32.bnot(Registry.Members.include__sm64_h.MARIO_TELEPORTING))
	end

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 32 then
		if m.pos[2] < m.waterLevel - 100 then
			-- Check if the camera is not underwater.
			const area = m.area :: GroupsTypesHPlus3.Area
			const camera = area.camera :: GroupsTypesHPlus3.Camera

			if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
				Registry.Members.src__game__camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE, 1)
			end

			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_WATER_IDLE, 0)
		else
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
		end
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_shocked L1457-1482
function mario_actions_cutscene.act_shocked(m: GroupsTypesHPlus3.MarioState): number
	Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_WAAAOOOW, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)
	Audio.play_sound(IncludeSoundsH.SOUND_MOVING_SHOCKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	Registry.Members.src__game__camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_SHOCK)

	if Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SHOCKED) == 0 then
		m.actionTimer = U16(m.actionTimer + 1)
		m.flags = bit32.bor(m.flags, Registry.Members.include__sm64_h.MARIO_METAL_SHOCK)
	end

	if m.actionArg == 0 then
		Registry.Members.src__game__mario.mario_set_forward_vel(m, 0.0)

		if Registry.Members.src__game__mario_step.perform_air_step(m, 1) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
			Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
			m.actionArg = 1
		end
	else
		if m.actionTimer >= 6 then
			m.invincTimer = 30
			Registry.Members.src__game__mario.set_mario_action(m, if m.health < 0x0100 then Registry.Members.include__sm64_h.ACT_ELECTROCUTION else Registry.Members.include__sm64_h.ACT_IDLE, 0)
		end

		Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_squished L1484-1584
function mario_actions_cutscene.act_squished(m: GroupsTypesHPlus3.MarioState): number
	local spaceUnderCeil = F32(m.ceilHeight - m.floorHeight)

	if spaceUnderCeil < 0 then
		spaceUnderCeil = 0.0
	end

	if m.actionState == 0 then
		if spaceUnderCeil > 160.0 then
			m.squishTimer = 0

			const actionResult: number = Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)

			return actionResult
		end

		m.squishTimer = 0xFF

		if spaceUnderCeil >= F32(10.1) then
			-- Mario becomes a pancake
			const squishAmount = F32(spaceUnderCeil / 160.0)

			SrcEngineMathUtil.vec3f_set((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.scale, F32(2.0 - squishAmount), squishAmount, F32(2.0 - squishAmount))
		else
			if not bit32.btest(m.flags, Registry.Members.include__sm64_h.MARIO_METAL_CAP) and m.invincTimer == 0 then
				-- cap on: 3 units; cap off: 4.5 units
				m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD) then 12 else 18))
				Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_ATTACKED, Registry.Members.include__sm64_h.MARIO_MARIO_SOUND_PLAYED)
			end

			-- Both of the 1.8's are floats; the 0.05 is an f32 literal.
			SrcEngineMathUtil.vec3f_set((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.scale, F32(1.8), F32(0.05), F32(1.8))

			m.actionState = 1
		end
	elseif m.actionState == 1 then
		if spaceUnderCeil >= 30.0 then
			m.actionState = 2
		end
	elseif m.actionState == 2 then
		m.actionTimer = U16(m.actionTimer + 1)

		if m.actionTimer >= 15 then
			-- 1 unit of health
			if m.health < 0x0100 then
				LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
				-- woosh, he's gone!
				Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_DISAPPEARED, 0)
			elseif m.hurtCounter == 0 then
				-- un-squish animation
				m.squishTimer = 30
				Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
			end
		end
	end

	-- steep floor
	local surfAngle = 0
	local underSteepSurf = IncludePRUltratypesH.FALSE

	if m.floor ~= nil and m.floor.normal.y < 0.5 then
		surfAngle = SrcEngineMathUtil.atan2s(m.floor.normal.z, m.floor.normal.x)
		underSteepSurf = IncludePRUltratypesH.TRUE
	end

	-- steep ceiling
	if m.ceil ~= nil and -0.5 < m.ceil.normal.y then
		surfAngle = SrcEngineMathUtil.atan2s(m.ceil.normal.z, m.ceil.normal.x)
		underSteepSurf = IncludePRUltratypesH.TRUE
	end

	if underSteepSurf ~= 0 then
		const sinSurf: number = Registry.Members.src__engine__math_util_h.sins(surfAngle)
		const cosSurf: number = Registry.Members.src__engine__math_util_h.coss(surfAngle)

		m.vel[1] = F32(sinSurf * 10.0)
		m.vel[3] = F32(cosSurf * 10.0)
		m.vel[2] = 0

		-- check if there's no floor 10 units away from the surface
		if Registry.Members.src__game__mario_step.perform_ground_step(m) == Registry.Members.include__sm64_h.GROUND_STEP_LEFT_GROUND then
			-- instant un-squish
			m.squishTimer = 0
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)

			return IncludePRUltratypesH.FALSE
		end
	end

	-- squished for more than 10 seconds, so kill Mario
	const actionArg = m.actionArg

	m.actionArg = U32(m.actionArg + 1)

	if actionArg > 300 then
		-- 0 units of health
		m.health = 0x00FF
		m.hurtCounter = 0
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_DEATH)
		-- woosh, he's gone!
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_DISAPPEARED, 0)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_A_POSE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_putting_on_cap L1586-1604
function mario_actions_cutscene.act_putting_on_cap(m: GroupsTypesHPlus3.MarioState): number
	const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_PUT_CAP_ON)

	if animFrame == 0 then
		Registry.Members.src__game__object_helpers.enable_time_stop()
	end

	if animFrame == 28 then
		mario_actions_cutscene.cutscene_put_cap_on(m)
	end

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
		Registry.Members.src__game__object_helpers.disable_time_stop()
	end

	Registry.Members.src__game__mario_step.stationary_ground_step(m)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:stuck_in_ground_handler L1606-1634
function mario_actions_cutscene.stuck_in_ground_handler(m: GroupsTypesHPlus3.MarioState, animation: number, unstuckFrame: number, target2: number, target3: number, endAction: number)
	local animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, animation)

	if bit32.btest(m.input, Registry.Members.include__sm64_h.INPUT_A_PRESSED) then
		m.actionTimer = U16(m.actionTimer + 1)

		if m.actionTimer >= 5 and animFrame < unstuckFrame - 1 then
			animFrame = unstuckFrame - 1
			Registry.Members.src__game__mario.set_anim_to_frame(m, animFrame)
		end
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if animFrame == -1 then
		Registry.Members.src__game__mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_STUCK_IN_GROUND, 1)
	elseif animFrame == unstuckFrame then
		Registry.Members.src__game__mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_UNSTUCK_FROM_GROUND, 1)
	elseif animFrame == target2 or animFrame == target3 then
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
	end

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		Registry.Members.src__game__mario.set_mario_action(m, endAction, 0)
	end
end

-- from src/game/mario_actions_cutscene.c:act_head_stuck_in_ground L1636-1639
function mario_actions_cutscene.act_head_stuck_in_ground(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_cutscene.stuck_in_ground_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_HEAD_STUCK_IN_GROUND, 96, 105, 135, Registry.Members.include__sm64_h.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_butt_stuck_in_ground L1641-1644
function mario_actions_cutscene.act_butt_stuck_in_ground(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_cutscene.stuck_in_ground_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_BOTTOM_STUCK_IN_GROUND, 127, 136, -2, Registry.Members.include__sm64_h.ACT_GROUND_POUND_LAND)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_feet_stuck_in_ground L1646-1649
function mario_actions_cutscene.act_feet_stuck_in_ground(m: GroupsTypesHPlus3.MarioState): number
	mario_actions_cutscene.stuck_in_ground_handler(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LEGS_STUCK_IN_GROUND, 116, 129, -2, Registry.Members.include__sm64_h.ACT_IDLE)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:advance_cutscene_step L1656-1660
function mario_actions_cutscene.advance_cutscene_step(m: GroupsTypesHPlus3.MarioState)
	m.actionState = 0
	m.actionTimer = 0
	m.actionArg = U32(m.actionArg + 1)
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_hide_hud_and_mario L1662-1667
function mario_actions_cutscene.intro_cutscene_hide_hud_and_mario(m: GroupsTypesHPlus3.MarioState)
	LevelUpdate.gHudDisplay.flags = LevelUpdateH.HUD_DISPLAY_NONE

	const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

	statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_START_INTRO

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.node.flags = S16(bit32.band(marioObj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))

	mario_actions_cutscene.advance_cutscene_step(m)
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_peach_lakitu_scene L1675-1684
function mario_actions_cutscene.intro_cutscene_peach_lakitu_scene(m: GroupsTypesHPlus3.MarioState)
	if S16((m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState).cameraEvent) ~= GroupsTypesHPlus3.CAM_EVENT_START_INTRO then
		const actionTimer = m.actionTimer

		m.actionTimer = U16(m.actionTimer + 1)

		if actionTimer == mario_actions_cutscene.TIMER_SPAWN_PIPE then
			const introWarpPipeObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_CASTLE_GROUNDS_WARP_PIPE, BehaviorIds.bhvStaticObject, -1328, 60, 4664, 0, 180, 0)

			mario_actions_cutscene.sIntroWarpPipeObj = introWarpPipeObj

			mario_actions_cutscene.advance_cutscene_step(m)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_raise_pipe L1693-1704
function mario_actions_cutscene.intro_cutscene_raise_pipe(m: GroupsTypesHPlus3.MarioState)
	const introWarpPipeObj = mario_actions_cutscene.sIntroWarpPipeObj :: GroupsTypesHPlus3.Object
	const newPosY: number = Registry.Members.src__game__camera.camera_approach_f32_symmetric(buffer.readf32(introWarpPipeObj.rawData, IncludeObjectFieldsH.oPosY), 260.0, 10.0)

	buffer.writef32(introWarpPipeObj.rawData, IncludeObjectFieldsH.oPosY, newPosY)

	if m.actionTimer == 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_EXIT_PIPE, (mario_actions_cutscene.sIntroWarpPipeObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == mario_actions_cutscene.TIMER_RAISE_PIPE then
		m.vel[2] = 60.0
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_jump_out_of_pipe L1707-1737
function mario_actions_cutscene.intro_cutscene_jump_out_of_pipe(m: GroupsTypesHPlus3.MarioState)
	if m.actionTimer == 25 then
		LevelUpdate.gHudDisplay.flags = LevelUpdateH.HUD_DISPLAY_DEFAULT
	end

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer >= 118 then
		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

		marioObj.header.gfx.node.flags = S16(bit32.bor(marioObj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))

		Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_MARIO_YAHOO, Registry.Members.include__sm64_h.MARIO_MARIO_SOUND_PLAYED)
		Registry.Members.src__game__mario.play_sound_if_no_flag(m, IncludeSoundsH.SOUND_ACTION_HIT_3, Registry.Members.include__sm64_h.MARIO_ACTION_SOUND_PLAYED)

		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_SINGLE_JUMP)
		Registry.Members.src__game__mario.mario_set_forward_vel(m, 10.0)

		if Registry.Members.src__game__mario_step.perform_air_step(m, 0) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
			Audio.sound_banks_enable(SeqPlayerSfx, IncludeSoundsH.SOUND_BANKS_DISABLED_DURING_INTRO_CUTSCENE)
			Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)

			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HAHA, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

			mario_actions_cutscene.advance_cutscene_step(m)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_land_outside_pipe L1739-1747
function mario_actions_cutscene.intro_cutscene_land_outside_pipe(m: GroupsTypesHPlus3.MarioState)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_LAND_FROM_SINGLE_JUMP)

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_lower_pipe L1749-1762
function mario_actions_cutscene.intro_cutscene_lower_pipe(m: GroupsTypesHPlus3.MarioState)
	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 0 then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_ENTER_PIPE, (mario_actions_cutscene.sIntroWarpPipeObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)
	end

	const introWarpPipeObj = mario_actions_cutscene.sIntroWarpPipeObj :: GroupsTypesHPlus3.Object

	buffer.writef32(introWarpPipeObj.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(introWarpPipeObj.rawData, IncludeObjectFieldsH.oPosY) - 5.0))

	if buffer.readf32(introWarpPipeObj.rawData, IncludeObjectFieldsH.oPosY) <= 50.0 then
		Registry.Members.src__game__object_helpers.obj_mark_for_deletion(introWarpPipeObj)
		mario_actions_cutscene.advance_cutscene_step(m)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
end

-- from src/game/mario_actions_cutscene.c:intro_cutscene_set_mario_to_idle L1764-1771
function mario_actions_cutscene.intro_cutscene_set_mario_to_idle(m: GroupsTypesHPlus3.MarioState)
	if Registry.Members.src__game__camera.gCamera.cutscene == 0 then
		Registry.Members.src__game__camera.gCameraMovementFlags = S16(bit32.band(Registry.Members.src__game__camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE)))
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_IDLE, 0)
	end

	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
end

-- from src/game/mario_actions_cutscene.c:act_intro_cutscene L1783-1808
function mario_actions_cutscene.act_intro_cutscene(m: GroupsTypesHPlus3.MarioState): number
	if m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_HIDE_HUD_AND_MARIO then
		mario_actions_cutscene.intro_cutscene_hide_hud_and_mario(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_PEACH_LAKITU_SCENE then
		mario_actions_cutscene.intro_cutscene_peach_lakitu_scene(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_RAISE_PIPE then
		mario_actions_cutscene.intro_cutscene_raise_pipe(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_JUMP_OUT_OF_PIPE then
		mario_actions_cutscene.intro_cutscene_jump_out_of_pipe(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_LAND_OUTSIDE_PIPE then
		mario_actions_cutscene.intro_cutscene_land_outside_pipe(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_LOWER_PIPE then
		mario_actions_cutscene.intro_cutscene_lower_pipe(m)
	elseif m.actionArg == mario_actions_cutscene.INTRO_CUTSCENE_SET_MARIO_TO_IDLE then
		mario_actions_cutscene.intro_cutscene_set_mario_to_idle(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:jumbo_star_cutscene_falling L1811-1835
function mario_actions_cutscene.jumbo_star_cutscene_falling(m: GroupsTypesHPlus3.MarioState)
	if m.actionState == 0 then
		m.input = U16(bit32.bor(m.input, Registry.Members.include__sm64_h.INPUT_A_DOWN))
		m.flags = bit32.bor(m.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_WING_CAP, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))

		m.faceAngle[2] = -0x8000
		m.pos[1] = 0.0
		m.pos[3] = 0.0

		Registry.Members.src__game__mario.mario_set_forward_vel(m, 0.0)
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)

		if Registry.Members.src__game__mario_step.perform_air_step(m, 1) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
			SoundInit.play_cutscene_music(SequenceArgs(15, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_VICTORY))
			Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
			m.actionState = U16(m.actionState + 1)
		end
	else
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND)

		if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
			const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

			statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_START_GRAND_STAR
			mario_actions_cutscene.advance_cutscene_step(m)
		end
	end
end

-- from src/game/mario_actions_cutscene.c:jumbo_star_cutscene_taking_off L1838-1888
function mario_actions_cutscene.jumbo_star_cutscene_taking_off(m: GroupsTypesHPlus3.MarioState): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.actionState == 0 then
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FINAL_BOWSER_RAISE_HAND_SPIN)
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY, 0.0)

		if Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 then
			Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
			m.actionState = U16(m.actionState + 1)
		end
	else
		const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FINAL_BOWSER_WING_CAP_TAKE_OFF)

		if animFrame == 3 or animFrame == 28 or animFrame == 60 then
			Registry.Members.src__game__mario.play_sound_and_spawn_particles(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_JUMP, 1)
		end

		if animFrame >= 3 then
			buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY, F32(buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY) - 32.0))
		end

		if animFrame == 3 then
			-- gAudioRandom is 0 in the port (native stub value): (gAudioRandom % 3 << 16) is 0
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAH_WAH_HOO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		elseif animFrame == 28 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HOOHOO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		elseif animFrame == 60 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_YAHOO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_SPARKLES)

		if Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 then
			mario_actions_cutscene.advance_cutscene_step(m)
		end
	end

	SrcEngineMathUtil.vec3f_set(m.pos, 0.0, 307.0, buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY))
	Registry.Members.src__game__mario.update_mario_pos_for_anim(m)
	SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
	SrcEngineMathUtil.vec3s_set(marioObj.header.gfx.angle, 0, m.faceAngle[2], 0)

	-- not sure why they did this, probably was from being used to action functions
	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:jumbo_star_cutscene_flying L1891-1939
function mario_actions_cutscene.jumbo_star_cutscene_flying(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WING_CAP_FLY)
		SrcEngineMathUtil.anim_spline_init(mario_actions_cutscene.sJumboStarKeyframes)
		m.actionState = U16(m.actionState + 1)
	end

	if m.actionState == 1 then
		if SrcEngineMathUtil.anim_spline_poll(TargetPos) ~= 0 then
			-- does this twice
			Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_FREEFALL, 0)
			m.actionState = U16(m.actionState + 1)
		else
			const targetDX = F32(TargetPos[1] - m.pos[1])
			const targetDY = F32(TargetPos[2] - m.pos[2])
			const targetDZ = F32(TargetPos[3] - m.pos[3])
			const targetHyp = F32(math.sqrt(F32(F32(targetDX * targetDX) + F32(targetDZ * targetDZ))))
			const targetAngle = SrcEngineMathUtil.atan2s(targetDZ, targetDX)

			SrcEngineMathUtil.vec3f_copy(m.pos, TargetPos)

			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

			marioObj.header.gfx.angle[1] = S16(-SrcEngineMathUtil.atan2s(targetHyp, targetDY))
			marioObj.header.gfx.angle[2] = targetAngle
			marioObj.header.gfx.angle[3] = S16(S16(m.faceAngle[2] - targetAngle) * 20)
			m.faceAngle[2] = targetAngle
		end
	elseif m.actionState == 2 then
		Registry.Members.src__game__mario.set_mario_action(m, Registry.Members.include__sm64_h.ACT_FREEFALL, 0)
	end

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_RIGHT_OPEN

	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.pos, m.pos)
	m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_SPARKLES)

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 500 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_CREDITS_START)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_jumbo_star_cutscene L1943-1956
function mario_actions_cutscene.act_jumbo_star_cutscene(m: GroupsTypesHPlus3.MarioState): number
	if m.actionArg == mario_actions_cutscene.JUMBO_STAR_CUTSCENE_FALLING then
		mario_actions_cutscene.jumbo_star_cutscene_falling(m)
	elseif m.actionArg == mario_actions_cutscene.JUMBO_STAR_CUTSCENE_TAKING_OFF then
		mario_actions_cutscene.jumbo_star_cutscene_taking_off(m)
	elseif m.actionArg == mario_actions_cutscene.JUMBO_STAR_CUTSCENE_FLYING then
		mario_actions_cutscene.jumbo_star_cutscene_flying(m)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:generate_yellow_sparkles L1958-1979
function mario_actions_cutscene.generate_yellow_sparkles(x: number, y: number, z: number, radius: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	radius = F32(radius)
	const cosTheta: number = Registry.Members.src__engine__math_util_h.coss(sSparkleGenTheta)
	const sinTheta: number = Registry.Members.src__engine__math_util_h.sins(sSparkleGenTheta)
	const cosPhi: number = Registry.Members.src__engine__math_util_h.coss(sSparkleGenPhi)
	const sinPhi: number = Registry.Members.src__engine__math_util_h.sins(sSparkleGenPhi)

	local offsetX = S16(TruncS32(F32(F32(radius * cosTheta) * sinPhi)))
	const offsetY = S16(TruncS32(F32(radius * sinTheta)))
	const offsetZ = S16(TruncS32(F32(F32(radius * cosTheta) * cosPhi)))

	Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn, x + offsetX, y + offsetY, z + offsetZ, 0, 0, 0)

	-- Source bug kept: all three lines assign offsetX.
	offsetX = S16(TruncS32(offsetX * 4 / 3))
	offsetX = S16(TruncS32(offsetY * 4 / 3))
	offsetX = S16(TruncS32(offsetZ * 4 / 3))

	Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn, x - offsetX, y - offsetY, z - offsetZ, 0, 0, 0)

	sSparkleGenTheta = S32(sSparkleGenTheta + 0x3800)
	sSparkleGenPhi = S32(sSparkleGenPhi + 0x6000)
end

-- from src/game/mario_actions_cutscene.c:end_obj_set_visual_pos L1983-1997
function mario_actions_cutscene.end_obj_set_visual_pos(o: GroupsTypesHPlus3.Object): number
	Registry.Members.src__game__mario.find_mario_anim_flags_and_translation(o, o.header.gfx.angle[2], Translation)

	const sp20 = F32(o.header.gfx.pos[1] + Translation[1])
	const sp1C = F32(o.header.gfx.pos[2] + 10.0)
	const sp18 = F32(o.header.gfx.pos[3] + Translation[3])

	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(sp20, sp1C, sp18, Floor)

	return floorHeight
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_mario_falling L2000-2015
function mario_actions_cutscene.end_peach_cutscene_mario_falling(m: GroupsTypesHPlus3.MarioState)
	if m.actionTimer == 1 then
		const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

		statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_START_ENDING
	end

	m.input = U16(bit32.bor(m.input, Registry.Members.include__sm64_h.INPUT_A_DOWN))
	m.flags = bit32.bor(m.flags, bit32.bor(Registry.Members.include__sm64_h.MARIO_WING_CAP, Registry.Members.include__sm64_h.MARIO_CAP_ON_HEAD))

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_FALL)
	Registry.Members.src__game__mario.mario_set_forward_vel(m, 0.0)

	if Registry.Members.src__game__mario_step.perform_air_step(m, 0) == Registry.Members.include__sm64_h.AIR_STEP_LANDED then
		Registry.Members.src__game__mario.play_mario_landing_sound(m, IncludeSoundsH.SOUND_ACTION_TERRAIN_LANDING)
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_mario_landing L2018-2031
function mario_actions_cutscene.end_peach_cutscene_mario_landing(m: GroupsTypesHPlus3.MarioState)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_GENERAL_LAND)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
		-- make wing cap run out
		m.capTimer = 60

		const endJumboStarObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvStaticObject, 0, 2528, -1800, 0, 0, 0)

		mario_actions_cutscene.sEndJumboStarObj = endJumboStarObj
		Registry.Members.src__game__object_helpers.obj_scale(endJumboStarObj, 3.0)
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_summon_jumbo_star L2034-2051
function mario_actions_cutscene.end_peach_cutscene_summon_jumbo_star(m: GroupsTypesHPlus3.MarioState)
	Registry.Members.src__game__mario.set_mario_animation(m, if m.actionState == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_RAISE_HAND else IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_LOWER_HAND)

	if m.actionState == 0 and Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 then
		m.actionState = U16(m.actionState + 1)
	end

	if m.actionTimer == 90 then
		SoundInit.play_cutscene_music(SequenceArgs(0, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_ENDING))
	end

	if m.actionTimer == 255 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end

	const endJumboStarObj = mario_actions_cutscene.sEndJumboStarObj :: GroupsTypesHPlus3.Object

	buffer.writei32(endJumboStarObj.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(endJumboStarObj.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x400))

	mario_actions_cutscene.generate_yellow_sparkles(0, 2528, -1800, 250.0)
	Audio.play_sound(IncludeSoundsH.SOUND_AIR_PEACH_TWINKLE, (mario_actions_cutscene.sEndJumboStarObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_spawn_peach L2065-2113
function mario_actions_cutscene.end_peach_cutscene_spawn_peach(m: GroupsTypesHPlus3.MarioState)
	if m.actionTimer == 1 then
		Area.play_transition(GroupsTypesHPlus3.WARP_TRANSITION_FADE_INTO_COLOR, 14, 255, 255, 255)
	end

	if m.actionTimer == 2 then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, Audio.gGlobalSoundSource)
	end

	if m.actionTimer == 44 then
		Area.play_transition(GroupsTypesHPlus3.WARP_TRANSITION_FADE_FROM_COLOR, 192, 255, 255, 255)
	end

	if m.actionTimer == 40 then
		Registry.Members.src__game__object_helpers.obj_mark_for_deletion(mario_actions_cutscene.sEndJumboStarObj :: GroupsTypesHPlus3.Object)

		const endPeachObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_PEACH, BehaviorIds.bhvEndPeach, 0, 2428, -1300, 0, 0, 0)

		mario_actions_cutscene.sEndPeachObj = endPeachObj
		Registry.Members.src__game__camera.gCutsceneFocus = endPeachObj

		const endRightToadObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_TOAD, BehaviorIds.bhvEndToad, 200, 906, -1290, 0, 0, 0)

		mario_actions_cutscene.sEndRightToadObj = endRightToadObj

		const endLeftToadObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_TOAD, BehaviorIds.bhvEndToad, -200, 906, -1290, 0, 0, 0)

		mario_actions_cutscene.sEndLeftToadObj = endLeftToadObj

		buffer.writei32(endPeachObj.rawData, IncludeObjectFieldsH.oOpacity, 127)
		buffer.writei32(endRightToadObj.rawData, IncludeObjectFieldsH.oOpacity, 255)
		buffer.writei32(endLeftToadObj.rawData, IncludeObjectFieldsH.oOpacity, 255)

		mario_actions_cutscene.D_8032CBE4 = 4
		mario_actions_cutscene.sEndPeachAnimation = 4

		mario_actions_cutscene.sEndToadAnims[1] = 4
		mario_actions_cutscene.sEndToadAnims[2] = 5
	end

	if m.actionTimer >= mario_actions_cutscene.TIMER_FADE_IN_PEACH then
		const endPeachObj = mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object
		const newOpacity: number = Registry.Members.src__game__camera.camera_approach_f32_symmetric(buffer.readi32(endPeachObj.rawData, IncludeObjectFieldsH.oOpacity), 255.0, 2.0)

		buffer.writei32(endPeachObj.rawData, IncludeObjectFieldsH.oOpacity, TruncS32(newOpacity))
	end

	if m.actionTimer >= 40 then
		mario_actions_cutscene.generate_yellow_sparkles(0, 2628, -1300, 150.0)
	end

	if m.actionTimer == mario_actions_cutscene.TIMER_DESCEND_PEACH then
		mario_actions_cutscene.advance_cutscene_step(m)
	end

	if m.actionTimer >= 40 then
		Audio.play_sound(IncludeSoundsH.SOUND_AIR_PEACH_TWINKLE, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_descend_peach L2122-2145
function mario_actions_cutscene.end_peach_cutscene_descend_peach(m: GroupsTypesHPlus3.MarioState)
	const endPeachObj = mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object

	mario_actions_cutscene.generate_yellow_sparkles(0, S16(TruncS32(buffer.readf32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY))), -1300, 150.0)

	if buffer.readf32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY) >= 1300.0 then
		if m.actionState < 60 then
			m.actionState = U16(m.actionState + 5)
		end
	else
		if m.actionState >= 27 then
			m.actionState = U16(m.actionState - 2)
		end

		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_RETURN_FROM_LOOK_UP)
	end

	const newPosY = F32(buffer.readf32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY) - TruncS32(m.actionState / 10))

	buffer.writef32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY, newPosY)

	if newPosY <= 907.0 then
		buffer.writef32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY, 906.0)
	end

	Audio.play_sound(IncludeSoundsH.SOUND_AIR_PEACH_TWINKLE, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

	if m.actionTimer >= mario_actions_cutscene.TIMER_RUN_TO_PEACH then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_run_to_peach L2150-2169
function mario_actions_cutscene.end_peach_cutscene_run_to_peach(m: GroupsTypesHPlus3.MarioState)
	if m.actionTimer == 22 then
		mario_actions_cutscene.sEndPeachAnimation = 5
	end

	m.pos[3] = F32(m.pos[3] - 20.0)

	if m.pos[3] <= -1181.0 then
		m.pos[3] = -1180.0
		mario_actions_cutscene.advance_cutscene_step(m)
	end

	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(m.pos[1], m.pos[2], m.pos[3], Floor)

	m.pos[2] = floorHeight

	Registry.Members.src__game__mario.set_mario_anim_with_accel(m, IncludeMarioAnimationIdsH.MARIO_ANIM_RUNNING, 0x00080000)
	Registry.Members.src__game__mario_actions_moving.play_step_sound(m, 9, 45)

	SrcEngineMathUtil.vec3f_copy((m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.pos, m.pos)
	m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_DUST)
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_dialog_1 L2174-2262
function mario_actions_cutscene.end_peach_cutscene_dialog_1(m: GroupsTypesHPlus3.MarioState)
	const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, if m.actionState == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_TAKE_OFF_CAP else IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_LOOK_UP)

	if m.actionState == 0 then
		if animFrame == 8 then
			mario_actions_cutscene.cutscene_take_cap_off(m)
		end

		if Registry.Members.src__game__mario.is_anim_at_end(m) ~= 0 then
			m.actionState = U16(m.actionState + 1)
		end
	end

	if m.actionTimer == 80 then
		mario_actions_cutscene.sEndPeachAnimation = 6
	elseif m.actionTimer == 81 then
		mario_actions_cutscene.D_8032CBE4 = 3
	elseif m.actionTimer == 145 then
		mario_actions_cutscene.D_8032CBE4 = 2
	elseif m.actionTimer == 228 then
		mario_actions_cutscene.D_8032CBE4 = 1
		mario_actions_cutscene.D_8032CBE8 = 1
	elseif m.actionTimer == 230 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 0, 30)
		Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_MARIO, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == 275 then
		mario_actions_cutscene.D_8032CBE4 = 0
		mario_actions_cutscene.D_8032CBE8 = 0
	elseif m.actionTimer == 290 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 1, 60)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_POWER_OF_THE_STARS, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == 480 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_dialog_2 L2279-2324
function mario_actions_cutscene.end_peach_cutscene_dialog_2(m: GroupsTypesHPlus3.MarioState)
	mario_actions_cutscene.sEndPeachAnimation = 9

	if m.actionTimer == 29 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 2, 30)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_THANKS_TO_YOU, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == 45 then
		mario_actions_cutscene.D_8032CBE8 = 1
	elseif m.actionTimer == 75 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 3, 30)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_THANK_YOU_MARIO, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == mario_actions_cutscene.TIMER_SOMETHING_SPECIAL then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 4, 40)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_SOMETHING_SPECIAL, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == mario_actions_cutscene.TIMER_PEACH_KISS then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_kiss_from_peach L2338-2379
function mario_actions_cutscene.end_peach_cutscene_kiss_from_peach(m: GroupsTypesHPlus3.MarioState)
	mario_actions_cutscene.sEndPeachAnimation = 10

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	if m.actionTimer >= 90 then
		marioBodyState.eyeState = if m.actionTimer < 110 then mario_actions_cutscene.sMarioBlinkOverride[m.actionTimer - 90 + 1] else IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
	end

	if m.actionTimer == 8 then
		mario_actions_cutscene.D_8032CBE8 = 0
	elseif m.actionTimer == 10 then
		mario_actions_cutscene.D_8032CBE4 = 3
	elseif m.actionTimer == 50 then
		mario_actions_cutscene.D_8032CBE4 = 4
	elseif m.actionTimer == 75 then
		marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
	elseif m.actionTimer == 76 then
		marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_CLOSED
	elseif m.actionTimer == 100 then
		mario_actions_cutscene.D_8032CBE4 = 3
	elseif m.actionTimer == 136 then
		mario_actions_cutscene.D_8032CBE4 = 0
	elseif m.actionTimer == 140 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_star_dance L2381-2426
function mario_actions_cutscene.end_peach_cutscene_star_dance(m: GroupsTypesHPlus3.MarioState)
	const animFrame: number = Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_PEACE_SIGN)
	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	if animFrame == 77 then
		mario_actions_cutscene.cutscene_put_cap_on(m)
	end

	if animFrame == 88 then
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if animFrame >= 98 then
		marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_PEACE_SIGN
	end

	if m.actionTimer < 52 then
		marioBodyState.eyeState = IncludeMarioGeoSwitchCaseIdsH.MARIO_EYES_HALF_CLOSED
	end

	if m.actionTimer == 70 then
		mario_actions_cutscene.D_8032CBE4 = 1
	elseif m.actionTimer == 86 then
		mario_actions_cutscene.D_8032CBE4 = 2
	elseif m.actionTimer == 90 then
		mario_actions_cutscene.D_8032CBE4 = 3
	elseif m.actionTimer == 120 then
		mario_actions_cutscene.D_8032CBE4 = 0
	elseif m.actionTimer == 140 then
		Audio.seq_player_unlower_volume(SeqPlayerLevel, 60)
		SoundInit.play_cutscene_music(SequenceArgs(15, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_CREDITS))
	elseif m.actionTimer == 142 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_dialog_3 L2432-2466
function mario_actions_cutscene.end_peach_cutscene_dialog_3(m: GroupsTypesHPlus3.MarioState)
	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

	const endPeachObj = mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object
	const endRightToadObj = mario_actions_cutscene.sEndRightToadObj :: GroupsTypesHPlus3.Object
	const endLeftToadObj = mario_actions_cutscene.sEndLeftToadObj :: GroupsTypesHPlus3.Object

	buffer.writef32(endPeachObj.rawData, IncludeObjectFieldsH.oPosY, mario_actions_cutscene.end_obj_set_visual_pos(endPeachObj))
	buffer.writef32(endRightToadObj.rawData, IncludeObjectFieldsH.oPosY, mario_actions_cutscene.end_obj_set_visual_pos(endRightToadObj))
	buffer.writef32(endLeftToadObj.rawData, IncludeObjectFieldsH.oPosY, mario_actions_cutscene.end_obj_set_visual_pos(endLeftToadObj))

	if m.actionTimer == 1 then
		mario_actions_cutscene.sEndPeachAnimation = 0
		mario_actions_cutscene.sEndToadAnims[1] = 0
		mario_actions_cutscene.sEndToadAnims[2] = 2
		mario_actions_cutscene.D_8032CBE8 = 1
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 5, 30)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_BAKE_A_CAKE, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	elseif m.actionTimer == 55 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 6, 40)
	elseif m.actionTimer == 130 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 7, 50)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_FOR_MARIO, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if m.actionTimer == 350 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_run_to_castle L2469-2488
function mario_actions_cutscene.end_peach_cutscene_run_to_castle(m: GroupsTypesHPlus3.MarioState)
	Registry.Members.src__game__mario.set_mario_animation(m, if m.actionState == 0 then IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_START_WALK_LOOK_UP else IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_LOOK_BACK_THEN_RUN)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.pos[2] = mario_actions_cutscene.end_obj_set_visual_pos(marioObj)

	if m.actionState == 0 and Registry.Members.src__game__mario.is_anim_past_end(m) ~= 0 then
		m.actionState = 1
	end

	if m.actionTimer == 95 then
		GroupsIngameMenuPlus1.set_cutscene_message(160, 227, 0, 40)
		Audio.play_sound(IncludeSoundsH.SOUND_PEACH_MARIO2, (mario_actions_cutscene.sEndPeachObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end

	if m.actionTimer == 389 then
		mario_actions_cutscene.advance_cutscene_step(m)
	end
end

-- from src/game/mario_actions_cutscene.c:end_peach_cutscene_fade_out L2490-2496
function mario_actions_cutscene.end_peach_cutscene_fade_out(m: GroupsTypesHPlus3.MarioState)
	if m.actionState == 0 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_CREDITS_NEXT)
		Registry.Members.src__game__paintings.gPaintingMarioYEntry = 1500 -- ensure medium water level in WDW credits cutscene
		m.actionState = 1
	end
end

-- from src/game/mario_actions_cutscene.c:act_end_peach_cutscene L2514-2566
function mario_actions_cutscene.act_end_peach_cutscene(m: GroupsTypesHPlus3.MarioState): number
	if m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_MARIO_FALLING then
		mario_actions_cutscene.end_peach_cutscene_mario_falling(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_MARIO_LANDING then
		mario_actions_cutscene.end_peach_cutscene_mario_landing(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_SUMMON_JUMBO_STAR then
		mario_actions_cutscene.end_peach_cutscene_summon_jumbo_star(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_SPAWN_PEACH then
		mario_actions_cutscene.end_peach_cutscene_spawn_peach(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_DESCEND_PEACH then
		mario_actions_cutscene.end_peach_cutscene_descend_peach(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_RUN_TO_PEACH then
		mario_actions_cutscene.end_peach_cutscene_run_to_peach(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_DIALOG_1 then
		mario_actions_cutscene.end_peach_cutscene_dialog_1(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_DIALOG_2 then
		mario_actions_cutscene.end_peach_cutscene_dialog_2(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_KISS_FROM_PEACH then
		mario_actions_cutscene.end_peach_cutscene_kiss_from_peach(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_STAR_DANCE then
		mario_actions_cutscene.end_peach_cutscene_star_dance(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_DIALOG_3 then
		mario_actions_cutscene.end_peach_cutscene_dialog_3(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_RUN_TO_CASTLE then
		mario_actions_cutscene.end_peach_cutscene_run_to_castle(m)
	elseif m.actionArg == mario_actions_cutscene.END_PEACH_CUTSCENE_FADE_OUT then
		mario_actions_cutscene.end_peach_cutscene_fade_out(m)
	end

	m.actionTimer = U16(m.actionTimer + 1)

	mario_actions_cutscene.sEndCutsceneVp[1][1] = 640
	mario_actions_cutscene.sEndCutsceneVp[1][2] = 360
	mario_actions_cutscene.sEndCutsceneVp[2][1] = 640
	mario_actions_cutscene.sEndCutsceneVp[2][2] = 480
	Area.override_viewport_and_clip(nil, mario_actions_cutscene.sEndCutsceneVp :: { unknown }, 0, 0, 0)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_credits_cutscene L2582-2637
function mario_actions_cutscene.act_credits_cutscene(m: GroupsTypesHPlus3.MarioState): number
	const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

	statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_START_CREDITS

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	-- checks if Mario is underwater (JRB, DDD, SA, etc.)
	if m.pos[2] < m.waterLevel - 100 then
		const area = m.area :: GroupsTypesHPlus3.Area
		const camera = area.camera :: GroupsTypesHPlus3.Camera

		if camera.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
			Registry.Members.src__game__camera.set_camera_mode(camera, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
		end

		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_WATER_IDLE)
		SrcEngineMathUtil.vec3f_copy(marioObj.header.gfx.pos, m.pos)
		-- will copy over roll and pitch, if set
		SrcEngineMathUtil.vec3s_copy(marioObj.header.gfx.angle, m.faceAngle)
		m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_BUBBLE)
	else
		Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_FIRST_PERSON)

		if m.actionTimer > 0 then
			Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)
		end
	end

	const creditsEntry = Registry.Members.src__game__area.gCurrCreditsEntry :: LevelUpdateH.CreditsEntry

	if m.actionTimer >= mario_actions_cutscene.TIMER_CREDITS_SHOW then
		if m.actionState < 40 then
			m.actionState = U16(m.actionState + 2)
		end

		const width = TruncS32(m.actionState * 640 / 100)
		const height = TruncS32(m.actionState * 480 / 100)

		mario_actions_cutscene.sEndCutsceneVp[1][1] = S16(640 - width)
		mario_actions_cutscene.sEndCutsceneVp[1][2] = S16(480 - height)
		mario_actions_cutscene.sEndCutsceneVp[2][1] = S16(TruncS32((if bit32.btest(creditsEntry.unk02, 0x10) then width else -width) * 56 / 100) + 640)
		mario_actions_cutscene.sEndCutsceneVp[2][2] = S16(TruncS32((if bit32.btest(creditsEntry.unk02, 0x20) then height else -height) * 66 / 100) + 480)

		Area.override_viewport_and_clip(mario_actions_cutscene.sEndCutsceneVp :: { unknown }, nil, 0, 0, 0)
	end

	if m.actionTimer == mario_actions_cutscene.TIMER_CREDITS_PROGRESS then
		GroupsIngameMenuPlus1.reset_cutscene_msg_fade()
	end

	if m.actionTimer >= mario_actions_cutscene.TIMER_CREDITS_PROGRESS then
		mario_actions_cutscene.sDispCreditsEntry = creditsEntry
	end

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == mario_actions_cutscene.TIMER_CREDITS_WARP then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_CREDITS_NEXT)
	end

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + bit32.lshift(bit32.band(creditsEntry.unk02, 0xC0), 8))

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:act_end_waving_cutscene L2639-2675
function mario_actions_cutscene.act_end_waving_cutscene(m: GroupsTypesHPlus3.MarioState): number
	if m.actionState == 0 then
		const statusForCamera = m.statusForCamera :: GroupsTypesHPlus3.PlayerCameraState

		statusForCamera.cameraEvent = GroupsTypesHPlus3.CAM_EVENT_START_END_WAVING

		const endPeachObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_PEACH, BehaviorIds.bhvEndPeach, 60, 906, -1180, 0, 0, 0)

		mario_actions_cutscene.sEndPeachObj = endPeachObj

		const endRightToadObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_TOAD, BehaviorIds.bhvEndToad, 180, 906, -1170, 0, 0, 0)

		mario_actions_cutscene.sEndRightToadObj = endRightToadObj

		const endLeftToadObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object_abs_with_rot(Registry.Members.src__game__object_list_processor.gCurrentObject, 0, IncludeModelIdsH.MODEL_TOAD, BehaviorIds.bhvEndToad, -180, 906, -1170, 0, 0, 0)

		mario_actions_cutscene.sEndLeftToadObj = endLeftToadObj

		buffer.writei32(endPeachObj.rawData, IncludeObjectFieldsH.oOpacity, 255)
		buffer.writei32(endRightToadObj.rawData, IncludeObjectFieldsH.oOpacity, 255)
		buffer.writei32(endLeftToadObj.rawData, IncludeObjectFieldsH.oOpacity, 255)

		mario_actions_cutscene.sEndPeachAnimation = 11
		mario_actions_cutscene.sEndToadAnims[1] = 6
		mario_actions_cutscene.sEndToadAnims[2] = 7

		m.actionState = 1
	end

	Registry.Members.src__game__mario.set_mario_animation(m, IncludeMarioAnimationIdsH.MARIO_ANIM_CREDITS_WAVING)
	Registry.Members.src__game__mario_step.stop_and_set_height_to_floor(m)

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	marioObj.header.gfx.angle[2] = S16(marioObj.header.gfx.angle[2] + 0x8000)
	marioObj.header.gfx.pos[1] = F32(marioObj.header.gfx.pos[1] - 60.0)

	const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

	marioBodyState.handState = IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_RIGHT_OPEN

	const actionTimer = m.actionTimer

	m.actionTimer = U16(m.actionTimer + 1)

	if actionTimer == 300 then
		LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_CREDITS_END)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:check_for_instant_quicksand L2677-2684
function mario_actions_cutscene.check_for_instant_quicksand(m: GroupsTypesHPlus3.MarioState): number
	const floor = m.floor :: GroupsTypesHPlus3.Surface

	if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_INSTANT_QUICKSAND and bit32.btest(m.action, Registry.Members.include__sm64_h.ACT_FLAG_INVULNERABLE) and m.action ~= Registry.Members.include__sm64_h.ACT_QUICKSAND_DEATH then
		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

		const actionResult: number = Registry.Members.src__game__mario.drop_and_set_mario_action(m, Registry.Members.include__sm64_h.ACT_QUICKSAND_DEATH, 0)

		return actionResult
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/mario_actions_cutscene.c:mario_execute_cutscene_action L2686-2754
function mario_actions_cutscene.mario_execute_cutscene_action(m: GroupsTypesHPlus3.MarioState): number
	if mario_actions_cutscene.check_for_instant_quicksand(m) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	local cancel = 0

	if m.action == Registry.Members.include__sm64_h.ACT_DISAPPEARED then
		cancel = mario_actions_cutscene.act_disappeared(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_INTRO_CUTSCENE then
		cancel = mario_actions_cutscene.act_intro_cutscene(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_STAR_DANCE_EXIT then
		cancel = mario_actions_cutscene.act_star_dance(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_STAR_DANCE_NO_EXIT then
		cancel = mario_actions_cutscene.act_star_dance(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_STAR_DANCE_WATER then
		cancel = mario_actions_cutscene.act_star_dance_water(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_FALL_AFTER_STAR_GRAB then
		cancel = mario_actions_cutscene.act_fall_after_star_grab(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_READING_AUTOMATIC_DIALOG then
		cancel = mario_actions_cutscene.act_reading_automatic_dialog(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_READING_NPC_DIALOG then
		cancel = mario_actions_cutscene.act_reading_npc_dialog(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_DEBUG_FREE_MOVE then
		cancel = mario_actions_cutscene.act_debug_free_move(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_READING_SIGN then
		cancel = mario_actions_cutscene.act_reading_sign(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_JUMBO_STAR_CUTSCENE then
		cancel = mario_actions_cutscene.act_jumbo_star_cutscene(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_WAITING_FOR_DIALOG then
		cancel = mario_actions_cutscene.act_waiting_for_dialog(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_STANDING_DEATH then
		cancel = mario_actions_cutscene.act_standing_death(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_QUICKSAND_DEATH then
		cancel = mario_actions_cutscene.act_quicksand_death(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_ELECTROCUTION then
		cancel = mario_actions_cutscene.act_electrocution(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SUFFOCATION then
		cancel = mario_actions_cutscene.act_suffocation(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_DEATH_ON_STOMACH then
		cancel = mario_actions_cutscene.act_death_on_stomach(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_DEATH_ON_BACK then
		cancel = mario_actions_cutscene.act_death_on_back(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_EATEN_BY_BUBBA then
		cancel = mario_actions_cutscene.act_eaten_by_bubba(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_END_PEACH_CUTSCENE then
		cancel = mario_actions_cutscene.act_end_peach_cutscene(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_CREDITS_CUTSCENE then
		cancel = mario_actions_cutscene.act_credits_cutscene(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_END_WAVING_CUTSCENE then
		cancel = mario_actions_cutscene.act_end_waving_cutscene(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_PULLING_DOOR or m.action == Registry.Members.include__sm64_h.ACT_PUSHING_DOOR then
		cancel = mario_actions_cutscene.act_going_through_door(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_WARP_DOOR_SPAWN then
		cancel = mario_actions_cutscene.act_warp_door_spawn(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_EMERGE_FROM_PIPE then
		cancel = mario_actions_cutscene.act_emerge_from_pipe(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPAWN_SPIN_AIRBORNE then
		cancel = mario_actions_cutscene.act_spawn_spin_airborne(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPAWN_SPIN_LANDING then
		cancel = mario_actions_cutscene.act_spawn_spin_landing(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_EXIT_AIRBORNE then
		cancel = mario_actions_cutscene.act_exit_airborne(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_EXIT_LAND_SAVE_DIALOG then
		cancel = mario_actions_cutscene.act_exit_land_save_dialog(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_DEATH_EXIT then
		cancel = mario_actions_cutscene.act_death_exit(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_UNUSED_DEATH_EXIT then
		cancel = mario_actions_cutscene.act_unused_death_exit(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_FALLING_DEATH_EXIT then
		cancel = mario_actions_cutscene.act_falling_death_exit(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPECIAL_EXIT_AIRBORNE then
		cancel = mario_actions_cutscene.act_special_exit_airborne(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPECIAL_DEATH_EXIT then
		cancel = mario_actions_cutscene.act_special_death_exit(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_FALLING_EXIT_AIRBORNE then
		cancel = mario_actions_cutscene.act_falling_exit_airborne(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_UNLOCKING_KEY_DOOR then
		cancel = mario_actions_cutscene.act_unlocking_key_door(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_UNLOCKING_STAR_DOOR then
		cancel = mario_actions_cutscene.act_unlocking_star_door(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_ENTERING_STAR_DOOR then
		cancel = mario_actions_cutscene.act_entering_star_door(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPAWN_NO_SPIN_AIRBORNE then
		cancel = mario_actions_cutscene.act_spawn_no_spin_airborne(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SPAWN_NO_SPIN_LANDING then
		cancel = mario_actions_cutscene.act_spawn_no_spin_landing(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_BBH_ENTER_JUMP then
		cancel = mario_actions_cutscene.act_bbh_enter_jump(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_BBH_ENTER_SPIN then
		cancel = mario_actions_cutscene.act_bbh_enter_spin(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_TELEPORT_FADE_OUT then
		cancel = mario_actions_cutscene.act_teleport_fade_out(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_TELEPORT_FADE_IN then
		cancel = mario_actions_cutscene.act_teleport_fade_in(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SHOCKED then
		cancel = mario_actions_cutscene.act_shocked(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_SQUISHED then
		cancel = mario_actions_cutscene.act_squished(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_HEAD_STUCK_IN_GROUND then
		cancel = mario_actions_cutscene.act_head_stuck_in_ground(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_BUTT_STUCK_IN_GROUND then
		cancel = mario_actions_cutscene.act_butt_stuck_in_ground(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_FEET_STUCK_IN_GROUND then
		cancel = mario_actions_cutscene.act_feet_stuck_in_ground(m)
	elseif m.action == Registry.Members.include__sm64_h.ACT_PUTTING_ON_CAP then
		cancel = mario_actions_cutscene.act_putting_on_cap(m)
	end

	if cancel == 0 and bit32.btest(m.input, Registry.Members.include__sm64_h.INPUT_IN_WATER) then
		m.particleFlags = bit32.bor(m.particleFlags, Registry.Members.include__sm64_h.PARTICLE_IDLE_WATER_WAVE)
	end

	return cancel
end

mario_actions_cutscene.CREDIT_TEXT_X_LEFT = IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_LEFT_EDGE(mario_actions_cutscene.CREDIT_TEXT_MARGIN_X)

mario_actions_cutscene.CREDIT_TEXT_X_RIGHT = IncludeGfxDimensionsH.GFX_DIMENSIONS_RECT_FROM_RIGHT_EDGE(mario_actions_cutscene.CREDIT_TEXT_MARGIN_X)

return mario_actions_cutscene
