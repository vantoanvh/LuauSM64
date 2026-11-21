--!strict
--!optimize 2

--[[
	Port of src/game/mario_misc.c.
]]

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const Camera = require("./camera")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSoundsH = require("../../include/sounds_h")
const InteractionH = require("./interaction_h")
const LevelUpdate = require("./level_update")
const ObjectHelpers = require("./object_helpers")
const Registry = require("../../groups/registry")
const RenderingGraphNode = require("./rendering_graph_node")
const SrcEngineGraphNode = require("../engine/graph_node")
const SrcEngineMathUtil = require("../engine/math_util")
const SrcEngineMathUtilH = require("../engine/math_util_h")
const IncludeMarioGeoSwitchCaseIdsH = require("../../include/mario_geo_switch_case_ids_h")
const Area = require("./area")
const IncludeCourseTableH = require("../../include/course_table_h")
const SaveFile = require("./save_file")
const SaveFileH = require("./save_file_h")
const BehaviorsSparkleSpawnStarInc = require("./behaviors/sparkle_spawn_star_inc")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const Memory = require("./memory")
const SoundInit = require("./sound_init")
const GameInit = require("./game_init")
const GoddardRenderer = require("../goddard/renderer")

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/mario_misc.luau:scratch
local sMarioAttackAnimCounter = 0

-- from src/game/mario_misc.c:data
const mario_misc = {
	TOAD_STAR_1_REQUIREMENT = 12,
	TOAD_STAR_2_REQUIREMENT = 25,
	TOAD_STAR_3_REQUIREMENT = 35,
	TOAD_STAR_1_DIALOG = 82, -- DIALOG_082
	TOAD_STAR_2_DIALOG = 76, -- DIALOG_076
	TOAD_STAR_3_DIALOG = 83, -- DIALOG_083
	TOAD_STAR_1_DIALOG_AFTER = 154, -- DIALOG_154
	TOAD_STAR_2_DIALOG_AFTER = 155, -- DIALOG_155
	TOAD_STAR_3_DIALOG_AFTER = 156, -- DIALOG_156
	TOAD_MESSAGE_FADED = 0,
	TOAD_MESSAGE_OPAQUE = 1,
	TOAD_MESSAGE_OPACIFYING = 2,
	TOAD_MESSAGE_FADING = 3,
	TOAD_MESSAGE_TALKING = 4,
	UNLOCK_DOOR_STAR_RISING = 0,
	UNLOCK_DOOR_STAR_WAITING = 1,
	UNLOCK_DOOR_STAR_SPAWNING_PARTICLES = 2,
	UNLOCK_DOOR_STAR_DONE = 3,
	-- from src/game/mario_misc.c:gMarioBlinkAnimation L59-59
	gMarioBlinkAnimation = { 1, 2, 1, 0, 1, 2, 1 },
	-- from src/game/mario_misc.c:gMarioAttackScaleAnimation L69-71
	gMarioAttackScaleAnimation = { 10, 12, 16, 24, 10, 10, 10, 14, 20, 30, 10, 10, 10, 16, 20, 26, 26, 20 },
	-- from src/game/mario_misc.c:gBodyStates L73-73
	gBodyStates = {
		{
			action = 0,
			capState = 0,
			eyeState = 0,
			handState = 0,
			wingFlutter = 0,
			modelState = 0,
			grabPos = 0,
			punchState = 0,
			torsoAngle = table.create(3, 0),
			headAngle = table.create(3, 0),
			heldObjLastPosition = table.create(3, 0),
			filler = buffer.create(4),
		},
		{
			action = 0,
			capState = 0,
			eyeState = 0,
			handState = 0,
			wingFlutter = 0,
			modelState = 0,
			grabPos = 0,
			punchState = 0,
			torsoAngle = table.create(3, 0),
			headAngle = table.create(3, 0),
			heldObjLastPosition = table.create(3, 0),
			filler = buffer.create(4),
		},
	},
	-- from src/game/mario_misc.c:gMirrorMario L74-74
	gMirrorMario = GroupsTypesHPlus3.new_Object(),
	MIRROR_X = 4331.53,
}

Registry.Register("src__game__mario_misc", mario_misc)

-- from src/game/mario_misc.c:geo_draw_mario_head_goddard L85-101
function mario_misc.geo_draw_mario_head_goddard(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): number?
	local gfx: number? = nil
	local sfx = 0
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const controllerData = GameInit.gPlayer1Controller.controllerData

		if controllerData ~= nil and Area.gWarpTransition.isActive == IncludePRUltratypesH.FALSE then
			GoddardRenderer.gd_copy_p1_contpad(controllerData)
		end

		-- PHYSICAL_TO_VIRTUAL is the identity on a Memory address (goddard-os-externals)
		gfx = GoddardRenderer.gdm_gettestdl(asGenerated.parameter)
		GameInit.gGoddardVblankCallback = GoddardRenderer.gd_vblank
		sfx = S16(GoddardRenderer.gd_sfx_to_play())
		SoundInit.play_menu_sounds(sfx)
	end

	return gfx
end

-- from src/game/mario_misc.c:toad_message_faded L103-110
function mario_misc.toad_message_faded()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oDistanceToMario) > 700.0 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageRecentlyTalked, IncludePRUltratypesH.FALSE)
	end

	if buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageRecentlyTalked) == 0 and buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oDistanceToMario) < 600.0 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_OPACIFYING)
	end
end

-- from src/game/mario_misc.c:toad_message_opaque L112-123
function mario_misc.toad_message_opaque()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oDistanceToMario) > 700.0 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_FADING)
	elseif buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageRecentlyTalked) == 0 then
		buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_NPC)

		if bit32.btest(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_TALKING)
		end
	end
end

-- from src/game/mario_misc.c:toad_message_talking L125-145
function mario_misc.toad_message_talking()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_DOWN, IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, GroupsTypesHPlus3.CUTSCENE_DIALOG, buffer.readu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID)) ~= 0 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageRecentlyTalked, IncludePRUltratypesH.TRUE)
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_FADING)

		const DialogID = buffer.readu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID)

		if DialogID == mario_misc.TOAD_STAR_1_DIALOG then
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID, mario_misc.TOAD_STAR_1_DIALOG_AFTER)
			BehaviorsSparkleSpawnStarInc.bhv_spawn_star_no_level_exit(IncludeObjectConstantsH.STAR_INDEX_ACT_1)
		elseif DialogID == mario_misc.TOAD_STAR_2_DIALOG then
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID, mario_misc.TOAD_STAR_2_DIALOG_AFTER)
			BehaviorsSparkleSpawnStarInc.bhv_spawn_star_no_level_exit(IncludeObjectConstantsH.STAR_INDEX_ACT_2)
		elseif DialogID == mario_misc.TOAD_STAR_3_DIALOG then
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID, mario_misc.TOAD_STAR_3_DIALOG_AFTER)
			BehaviorsSparkleSpawnStarInc.bhv_spawn_star_no_level_exit(IncludeObjectConstantsH.STAR_INDEX_ACT_3)
		end
	end
end

-- from src/game/mario_misc.c:toad_message_opacifying L147-151
function mario_misc.toad_message_opacifying()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Opacity = S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oOpacity) + 6)

	buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oOpacity, Opacity)

	if Opacity == 255 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_OPAQUE)
	end
end

-- from src/game/mario_misc.c:toad_message_fading L153-157
function mario_misc.toad_message_fading()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Opacity = S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oOpacity) - 6)

	buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oOpacity, Opacity)

	if Opacity == 81 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_FADED)
	end
end

-- from src/game/mario_misc.c:bhv_toad_message_loop L159-180
function mario_misc.bhv_toad_message_loop()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(currentObject.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oInteractionSubtype, 0)

		const State = buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState)

		if State == mario_misc.TOAD_MESSAGE_FADED then
			mario_misc.toad_message_faded()
		elseif State == mario_misc.TOAD_MESSAGE_OPAQUE then
			mario_misc.toad_message_opaque()
		elseif State == mario_misc.TOAD_MESSAGE_OPACIFYING then
			mario_misc.toad_message_opacifying()
		elseif State == mario_misc.TOAD_MESSAGE_FADING then
			mario_misc.toad_message_fading()
		elseif State == mario_misc.TOAD_MESSAGE_TALKING then
			mario_misc.toad_message_talking()
		end
	end
end

-- from src/game/mario_misc.c:bhv_toad_message_init L182-217
function mario_misc.bhv_toad_message_init()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const SaveFlags = SaveFile.save_file_get_flags()
	const StarCount = SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1)
	local DialogID = bit32.band(bit32.rshift(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF)
	local EnoughStars = IncludePRUltratypesH.TRUE

	if DialogID == mario_misc.TOAD_STAR_1_DIALOG then
		EnoughStars = if StarCount >= mario_misc.TOAD_STAR_1_REQUIREMENT then 1 else 0

		if bit32.btest(SaveFlags, SaveFileH.SAVE_FLAG_COLLECTED_TOAD_STAR_1) then
			DialogID = mario_misc.TOAD_STAR_1_DIALOG_AFTER
		end
	elseif DialogID == mario_misc.TOAD_STAR_2_DIALOG then
		EnoughStars = if StarCount >= mario_misc.TOAD_STAR_2_REQUIREMENT then 1 else 0

		if bit32.btest(SaveFlags, SaveFileH.SAVE_FLAG_COLLECTED_TOAD_STAR_2) then
			DialogID = mario_misc.TOAD_STAR_2_DIALOG_AFTER
		end
	elseif DialogID == mario_misc.TOAD_STAR_3_DIALOG then
		EnoughStars = if StarCount >= mario_misc.TOAD_STAR_3_REQUIREMENT then 1 else 0

		if bit32.btest(SaveFlags, SaveFileH.SAVE_FLAG_COLLECTED_TOAD_STAR_3) then
			DialogID = mario_misc.TOAD_STAR_3_DIALOG_AFTER
		end
	end

	if EnoughStars ~= 0 then
		buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageDialogID, DialogID)
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageRecentlyTalked, IncludePRUltratypesH.FALSE)
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oToadMessageState, mario_misc.TOAD_MESSAGE_FADED)
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oOpacity, 81)
	else
		ObjectHelpers.obj_mark_for_deletion(currentObject)
	end
end

-- from src/game/mario_misc.c:star_door_unlock_spawn_particles L219-228
function mario_misc.star_door_unlock_spawn_particles(angleOffset: number)
	angleOffset = S16(TruncS32(angleOffset))
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sparkleParticle: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object(currentObject, 0, BehaviorIds.bhvSparkleSpawn)
	const SinValue = SrcEngineMathUtilH.sins(S16(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) * 0x2800 + angleOffset))
	const CosValue = SrcEngineMathUtilH.coss(S16(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) * 0x2800 + angleOffset))

	buffer.writef32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosX) + F32(100.0 * SinValue))
	buffer.writef32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosZ) + F32(100.0 * CosValue))
	buffer.writef32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(sparkleParticle.rawData, IncludeObjectFieldsH.oPosY) - F32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) * 10.0))
end

-- from src/game/mario_misc.c:bhv_unlock_door_star_init L230-239
function mario_misc.bhv_unlock_door_star_init()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarState, mario_misc.UNLOCK_DOOR_STAR_RISING)
	buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, 0)
	buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel, 0x1000)

	const SinValue = SrcEngineMathUtilH.sins(LevelUpdate.gMarioState.faceAngle[2] - 0x4000)
	const CosValue = SrcEngineMathUtilH.coss(LevelUpdate.gMarioState.faceAngle[2] - 0x4000)

	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosX) + F32(30.0 * SinValue))
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosY) + 160.0)
	buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosZ) + F32(30.0 * CosValue))
	buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x7800)
	ObjectHelpers.obj_scale(currentObject, 0.5)
end

-- from src/game/mario_misc.c:bhv_unlock_door_star_loop L241-297
function mario_misc.bhv_unlock_door_star_loop()
	const currentObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const PrevYaw = S16(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel) < 0x2400 then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel, S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel) + 0x60))
	end

	const State = buffer.readu32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarState)

	if State == mario_misc.UNLOCK_DOOR_STAR_RISING then
		buffer.writef32(currentObject.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(currentObject.rawData, IncludeObjectFieldsH.oPosY) + F32(3.4))
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel)))
		ObjectHelpers.obj_scale(currentObject, F32(F32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) / 50.0) + 0.5))

		const Timer = S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) + 1)

		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, Timer)

		if Timer == 30 then
			buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, 0)
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarState, U32(State + 1))
		end
	elseif State == mario_misc.UNLOCK_DOOR_STAR_WAITING then
		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarYawVel)))

		const Timer = S32(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer) + 1)

		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, Timer)

		if Timer == 30 then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, currentObject.header.gfx.cameraToObject)
			ObjectHelpers.cur_obj_hide()
			buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, 0)
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarState, U32(State + 1))
		end
	elseif State == mario_misc.UNLOCK_DOOR_STAR_SPAWNING_PARTICLES then
		mario_misc.star_door_unlock_spawn_particles(0)
		mario_misc.star_door_unlock_spawn_particles(S16(0x8000))

		const OldTimer = buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer)

		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, S32(OldTimer + 1))

		if OldTimer == 20 then
			buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, 0)
			buffer.writeu32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarState, U32(State + 1))
		end
	elseif State == mario_misc.UNLOCK_DOOR_STAR_DONE then
		const OldTimer = buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer)

		buffer.writei32(currentObject.rawData, IncludeObjectFieldsH.oUnlockDoorStarTimer, S32(OldTimer + 1))

		if OldTimer == 50 then
			ObjectHelpers.obj_mark_for_deletion(currentObject)
		end
	end

	if PrevYaw > S16(buffer.readi32(currentObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_SHORT_STAR, currentObject.header.gfx.cameraToObject)
	end
end

-- from src/game/mario_misc.c:make_gfx_mario_alpha L302-319
function mario_misc.make_gfx_mario_alpha(node: GroupsTypesHPlus3.GraphNodeGenerated, alpha: number): { unknown }?
	alpha = S16(TruncS32(alpha))
	local gfxHead: { unknown }? = nil

	if alpha == 255 then
		node.node.flags = S16(bit32.bor(bit32.band(node.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))
		gfxHead = Memory.alloc_display_list(2 * 8) :: { unknown }
	else
		node.node.flags = S16(bit32.bor(bit32.band(node.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_TRANSPARENT, 8)))
		gfxHead = Memory.alloc_display_list(3 * 8) :: { unknown }
		-- gDPSetAlphaCompare: no call (gfx-display-lists-noop)
	end

	-- gDPSetEnvColor, gSPEndDisplayList: no call (gfx-display-lists-noop)
	return gfxHead
end

-- from src/game/mario_misc.c:geo_mirror_mario_set_alpha L324-337
function mario_misc.geo_mirror_mario_set_alpha(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	local Display: { unknown }? = nil
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const bodyState = mario_misc.gBodyStates[asGenerated.parameter + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const Alpha = S16(if bit32.btest(bodyState.modelState, 0x100) then bit32.band(bodyState.modelState, 0xFF) else 255)

		Display = mario_misc.make_gfx_mario_alpha(asGenerated, Alpha)
	end

	return Display
end

-- from src/game/mario_misc.c:geo_switch_mario_stand_run L344-353
function mario_misc.geo_switch_mario_stand_run(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { { number } } }): { unknown }?
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
	const bodyState = mario_misc.gBodyStates[switchCase.numCases + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		switchCase.selectedCase = if bit32.btest(bodyState.action, IncludeSm64H.ACT_FLAG_STATIONARY) then 0 else 1
	end

	return nil
end

-- from src/game/mario_misc.c:geo_switch_mario_eyes L358-376
function mario_misc.geo_switch_mario_eyes(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
	const bodyState = mario_misc.gBodyStates[switchCase.numCases + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if bodyState.eyeState == 0 then
			const BlinkFrame = S16(bit32.band((switchCase.numCases * 32 + RenderingGraphNode.gAreaUpdateCounter) // 2, 0x1F))

			if BlinkFrame < 7 then
				switchCase.selectedCase = mario_misc.gMarioBlinkAnimation[BlinkFrame + 1]
			else
				switchCase.selectedCase = 0
			end
		else
			switchCase.selectedCase = S16(bodyState.eyeState - 1)
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_mario_tilt_torso L381-398
function mario_misc.geo_mario_tilt_torso(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const bodyState = mario_misc.gBodyStates[asGenerated.parameter + 1]
	const action = bodyState.action

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const rotNode = node.next :: GroupsTypesHPlus3.GraphNodeRotation

		if action ~= IncludeSm64H.ACT_BUTT_SLIDE and action ~= IncludeSm64H.ACT_HOLD_BUTT_SLIDE and action ~= IncludeSm64H.ACT_WALKING and action ~= IncludeSm64H.ACT_RIDING_SHELL_GROUND then
			SrcEngineMathUtil.vec3s_copy(bodyState.torsoAngle, SrcEngineGraphNode.gVec3sZero)
		end

		rotNode.rotation[1] = bodyState.torsoAngle[2]
		rotNode.rotation[2] = bodyState.torsoAngle[3]
		rotNode.rotation[3] = bodyState.torsoAngle[1]
	end

	return nil
end

-- from src/game/mario_misc.c:geo_mario_head_rotation L403-425
function mario_misc.geo_mario_head_rotation(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const bodyState = mario_misc.gBodyStates[asGenerated.parameter + 1]
	const action = bodyState.action

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const rotNode = node.next :: GroupsTypesHPlus3.GraphNodeRotation
		const cameraConfig = (RenderingGraphNode.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera).config
		const camera = cameraConfig.camera :: GroupsTypesHPlus3.Camera

		if camera.mode == GroupsTypesHPlus3.CAMERA_MODE_C_UP then
			rotNode.rotation[1] = Camera.gPlayerCameraState[1].headRotation[2]
			rotNode.rotation[3] = Camera.gPlayerCameraState[1].headRotation[1]
		elseif bit32.btest(action, IncludeSm64H.ACT_FLAG_WATER_OR_TEXT) then
			rotNode.rotation[1] = bodyState.headAngle[2]
			rotNode.rotation[2] = bodyState.headAngle[3]
			rotNode.rotation[3] = bodyState.headAngle[1]
		else
			SrcEngineMathUtil.vec3s_set(bodyState.headAngle, 0, 0, 0)
			SrcEngineMathUtil.vec3s_set(rotNode.rotation, 0, 0, 0)
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_switch_mario_hand L431-450
function mario_misc.geo_switch_mario_hand(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
	const bodyState = mario_misc.gBodyStates[1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if bodyState.handState == IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_FISTS then
			switchCase.selectedCase = if bit32.btest(bodyState.action, IncludeSm64H.ACT_FLAG_SWIMMING_OR_FLYING) then 1 else 0
		else
			if switchCase.numCases == 0 then
				switchCase.selectedCase = if bodyState.handState < 5 then bodyState.handState else IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_OPEN
			else
				switchCase.selectedCase = if bodyState.handState < 2 then bodyState.handState else IncludeMarioGeoSwitchCaseIdsH.MARIO_HAND_FISTS
			end
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_mario_hand_foot_scaler L460-479
function mario_misc.geo_mario_hand_foot_scaler(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const scaleNode = node.next :: GroupsTypesHPlus3.GraphNodeScale
	const bodyState = mario_misc.gBodyStates[1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		scaleNode.scale = 1.0

		if asGenerated.parameter == bodyState.punchState // 64 then
			if sMarioAttackAnimCounter ~= RenderingGraphNode.gAreaUpdateCounter and bit32.band(bodyState.punchState, 0x3F) > 0 then
				bodyState.punchState = U8(bodyState.punchState - 1)
				sMarioAttackAnimCounter = S16(RenderingGraphNode.gAreaUpdateCounter)
			end

			scaleNode.scale = F32(mario_misc.gMarioAttackScaleAnimation[asGenerated.parameter * 6 + bit32.band(bodyState.punchState, 0x3F) + 1] / 10.0)
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_switch_mario_cap_effect L484-492
function mario_misc.geo_switch_mario_cap_effect(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
	const bodyState = mario_misc.gBodyStates[switchCase.numCases + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		switchCase.selectedCase = S16(bodyState.modelState // 256)
	end

	return nil
end

-- from src/game/mario_misc.c:geo_switch_mario_cap_on_off L498-517
function mario_misc.geo_switch_mario_cap_on_off(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	local Next = node.next :: GroupsTypesHPlus3.GraphNode
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase
	const bodyState = mario_misc.gBodyStates[switchCase.numCases + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		switchCase.selectedCase = bit32.band(bodyState.capState, 1)

		while Next ~= node do
			if Next.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_TRANSLATION_ROTATION then
				if bit32.btest(bodyState.capState, 2) then
					Next.flags = S16(bit32.bor(Next.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
				else
					Next.flags = S16(bit32.band(Next.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
				end
			end

			Next = Next.next :: GroupsTypesHPlus3.GraphNode
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_mario_rotate_wing_cap_wings L523-542
function mario_misc.geo_mario_rotate_wing_cap_wings(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	local RotX: number

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const rotNode = node.next :: GroupsTypesHPlus3.GraphNodeRotation

		if mario_misc.gBodyStates[(asGenerated.parameter // 2) + 1].wingFlutter == 0 then
			const Cosine = SrcEngineMathUtilH.coss(bit32.lshift(bit32.band(RenderingGraphNode.gAreaUpdateCounter, 0xF), 12))
			RotX = S16(TruncS32(F32(F32(Cosine + 1.0) * 4096.0)))
		else
			const Cosine = SrcEngineMathUtilH.coss(bit32.lshift(bit32.band(RenderingGraphNode.gAreaUpdateCounter, 7), 13))
			RotX = S16(TruncS32(F32(F32(Cosine + 1.0) * 6144.0)))
		end

		if bit32.band(asGenerated.parameter, 1) == 0 then
			rotNode.rotation[1] = S16(-RotX)
		else
			rotNode.rotation[1] = RotX
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_switch_mario_hand_grab_pos L547-580
function mario_misc.geo_switch_mario_hand_grab_pos(callContext: number, b: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	const heldObj = b :: GroupsTypesHPlus3.GraphNodeHeldObject
	const curTransform = mtx
	const marioState = LevelUpdate.gMarioStates[heldObj.playerIndex + 1]

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		heldObj.objNode = nil

		if marioState.heldObj ~= nil then
			heldObj.objNode = marioState.heldObj
			const GrabPos = (marioState.marioBodyState :: GroupsTypesHPlus3.MarioBodyState).grabPos

			if GrabPos == IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_LIGHT_OBJ then
				if bit32.btest(marioState.action, IncludeSm64H.ACT_FLAG_THROWING) then
					SrcEngineMathUtil.vec3s_set(heldObj.translation, 50, 0, 0)
				else
					SrcEngineMathUtil.vec3s_set(heldObj.translation, 50, 0, 110)
				end
			elseif GrabPos == IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_HEAVY_OBJ then
				SrcEngineMathUtil.vec3s_set(heldObj.translation, 145, -173, 180)
			elseif GrabPos == IncludeMarioGeoSwitchCaseIdsH.GRAB_POS_BOWSER then
				SrcEngineMathUtil.vec3s_set(heldObj.translation, 80, -270, 1260)
			end
		end
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_HELD_OBJ then
		const CameraMatrix = ((RenderingGraphNode.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera).matrixPtr :: { { { number } } })[1]

		SrcEngineMathUtil.get_pos_from_transform_mtx((marioState.marioBodyState :: GroupsTypesHPlus3.MarioBodyState).heldObjLastPosition, curTransform, CameraMatrix)
	end

	return nil
end

-- from src/game/mario_misc.c:geo_render_mirror_mario L589-624
function mario_misc.geo_render_mirror_mario(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const mario = LevelUpdate.gMarioStates[1].marioObj :: GroupsTypesHPlus3.Object
	const mirror = mario_misc.gMirrorMario

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_CREATE then
		SrcEngineGraphNode.init_graph_node_object(nil, mirror, nil, SrcEngineGraphNode.gVec3fZero, SrcEngineGraphNode.gVec3sZero, SrcEngineGraphNode.gVec3fOne)
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_AREA_LOAD then
		SrcEngineGraphNode.geo_add_child(node, mirror.node)
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_AREA_UNLOAD then
		SrcEngineGraphNode.geo_remove_child(mirror.node)
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if mario.header.gfx.pos[1] > 1700.0 then
			mirror.sharedChild = mario.header.gfx.sharedChild
			mirror.areaIndex = mario.header.gfx.areaIndex
			SrcEngineMathUtil.vec3s_copy(mirror.angle, mario.header.gfx.angle)
			SrcEngineMathUtil.vec3f_copy(mirror.pos, mario.header.gfx.pos)
			SrcEngineMathUtil.vec3f_copy(mirror.scale, mario.header.gfx.scale)
			mirror.animInfo.animID = mario.header.gfx.animInfo.animID
			mirror.animInfo.animYTrans = mario.header.gfx.animInfo.animYTrans
			mirror.animInfo.curAnim = mario.header.gfx.animInfo.curAnim
			mirror.animInfo.animFrame = mario.header.gfx.animInfo.animFrame
			mirror.animInfo.animTimer = mario.header.gfx.animInfo.animTimer
			mirror.animInfo.animFrameAccelAssist = mario.header.gfx.animInfo.animFrameAccelAssist
			mirror.animInfo.animAccel = mario.header.gfx.animInfo.animAccel

			const MirroredX = F32(mario_misc.MIRROR_X - mirror.pos[1])

			mirror.pos[1] = F32(MirroredX + mario_misc.MIRROR_X)
			mirror.angle[2] = S16(-mirror.angle[2])
			mirror.scale[1] = F32(mirror.scale[1] * -1.0)
			mirror.node.flags = S16(bit32.bor(mirror.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
		else
			mirror.node.flags = S16(bit32.band(mirror.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
		end
	end

	return nil
end

-- from src/game/mario_misc.c:geo_mirror_mario_backface_culling L630-650
function mario_misc.geo_mirror_mario_backface_culling(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	const asGenerated = node :: GroupsTypesHPlus3.GraphNodeGenerated
	local gfx: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER and RenderingGraphNode.gCurGraphNodeObject == mario_misc.gMirrorMario then
		gfx = Memory.alloc_display_list(3 * 8) :: { unknown }

		-- gSPClearGeometryMode, gSPSetGeometryMode, gSPEndDisplayList: no call (gfx-display-lists-noop)
		asGenerated.node.flags = S16(bit32.bor(bit32.band(asGenerated.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))
	end

	return gfx
end

return mario_misc
