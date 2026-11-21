--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const GameInit = require("../game_init")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const LevelUpdate = require("../level_update")
const ObjBehaviors2 = require("../obj_behaviors_2")
const Camera = require("../camera")
const IncludeSurfaceTerrainsH = require("../../../include/surface_terrains_h")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const Area = require("../area")
const BreakParticlesInc = require("./break_particles_inc")
const IncludeLevelTableH = require("../../../include/level_table_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const IncludeSm64H = require("../../../include/sm64_h")
const Memory = require("../memory")
const PlatformDisplacement = require("../platform_displacement")
const RenderingGraphNode = require("../rendering_graph_node")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const Rom = require("../../rom/rom")
const SegmentSymbols = require("../../rom/segment_symbols")

const SeqPlayerLevel = 0

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
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

-- from src/game/behaviors/bowser_inc.luau:scratch
const Scratch = {
	bowser_check_hit_mine_dist = { 0 },
	bowser_free_update_floor = {} :: { GroupsTypesHPlus3.Surface? },
	geo_update_body_rot_from_parent_mtx2 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
}

-- from src/game/behaviors/bowser.inc.c:data
const bowser_inc = {
	-- from src/game/behaviors/bowser.inc.c:sBowserDebugActions L282-299
	sBowserDebugActions = {
		IncludeObjectConstantsH.BOWSER_ACT_CHARGE_MARIO,
		IncludeObjectConstantsH.BOWSER_ACT_SPIT_FIRE_INTO_SKY,
		IncludeObjectConstantsH.BOWSER_ACT_SPIT_FIRE_ONTO_FLOOR,
		IncludeObjectConstantsH.BOWSER_ACT_HIT_MINE,
		IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP,
		IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO,
		IncludeObjectConstantsH.BOWSER_ACT_BREATH_FIRE,
		IncludeObjectConstantsH.BOWSER_ACT_DEAD,
		IncludeObjectConstantsH.BOWSER_ACT_DANCE,
		IncludeObjectConstantsH.BOWSER_ACT_TELEPORT,
		IncludeObjectConstantsH.BOWSER_ACT_QUICK_JUMP,
		IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM,
		IncludeObjectConstantsH.BOWSER_ACT_DANCE,
		IncludeObjectConstantsH.BOWSER_ACT_DANCE,
		IncludeObjectConstantsH.BOWSER_ACT_DANCE,
		IncludeObjectConstantsH.BOWSER_ACT_DANCE,
	},
	-- from src/game/behaviors/bowser.inc.c:sBowserVelYAir L773-773
	sBowserVelYAir = { 60 },
	-- from src/game/behaviors/bowser.inc.c:sBowserFVelAir L774-774
	sBowserFVelAir = { 50 },
	-- from src/game/behaviors/bowser.inc.c:sBowserDanceStepNoises L1143-1143
	sBowserDanceStepNoises = { 24, 42, 60, -1 },
	-- from src/game/behaviors/bowser.inc.c:sBowserDefeatedDialogText L1269-1269
	sBowserDefeatedDialogText = { IncludeDialogIdsH.DIALOG_119, IncludeDialogIdsH.DIALOG_120, IncludeDialogIdsH.DIALOG_121 },
	-- from src/game/behaviors/bowser.inc.c:sBowsertiltPlatformData L1425-1438
	sBowsertiltPlatformData = {
		{ flag = 1, angSpeed = 10, time = 40 },
		{ flag = 0, angSpeed = 0, time = 74 },
		{ flag = -1, angSpeed = -10, time = 114 },
		{ flag = 1, angSpeed = -20, time = 134 },
		{ flag = -1, angSpeed = 20, time = 154 },
		{ flag = 1, angSpeed = 40, time = 164 },
		{ flag = -1, angSpeed = -40, time = 174 },
		{ flag = 1, angSpeed = -80, time = 179 },
		{ flag = -1, angSpeed = 80, time = 184 },
		{ flag = 1, angSpeed = 160, time = 186 },
		{ flag = -1, angSpeed = -160, time = 186 },
		{ flag = 1, angSpeed = 0, time = 0 },
	},
	-- from src/game/behaviors/bowser.inc.c:sBowserSoundStates L1544-1572
	sBowserSoundStates = {
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 1, animFrame1 = 0, animFrame2 = -1, soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK },
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ2_BOWSER_ROAR,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ2_BOWSER_ROAR,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 20,
			animFrame2 = 40,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK,
		},
		{
			playSound = 1,
			animFrame1 = 20,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK,
		},
		{
			playSound = 1,
			animFrame1 = 20,
			animFrame2 = 40,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_TAIL_PICKUP,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_DEFEATED,
		},
		{ playSound = 1, animFrame1 = 8, animFrame2 = -1, soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK },
		{ playSound = 1, animFrame1 = 8, animFrame2 = 17, soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK },
		{
			playSound = 1,
			animFrame1 = 8,
			animFrame2 = -10,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_WALK,
		},
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 1, animFrame1 = 5, animFrame2 = -1, soundMagic = IncludeSoundsH.SOUND_OBJ_FLAME_BLOWN },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{ playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = IncludeSoundsH.NO_SOUND },
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ_BOWSER_TAIL_PICKUP,
		},
		{
			playSound = 1,
			animFrame1 = 0,
			animFrame2 = -1,
			soundMagic = IncludeSoundsH.SOUND_OBJ2_BOWSER_ROAR,
		},
	},
	-- from src/game/behaviors/bowser.inc.c:sBowserRainbowLight L1577-1577
	sBowserRainbowLight = { 0, 0, 1 },
	-- from src/game/behaviors/bowser.inc.c:sBowserHealth L1582-1582
	sBowserHealth = { 1, 1, 3 },
	BOWSER_EYES_OPEN = 0,
	BOWSER_EYES_HALF_CLOSED = 1,
	BOWSER_EYES_CLOSED = 2,
	BOWSER_EYES_LEFT = 3,
	BOWSER_EYES_FAR_LEFT = 4,
	BOWSER_EYES_RIGHT = 5,
	BOWSER_EYES_FAR_RIGHT = 6,
	BOWSER_EYES_DERP = 7,
	BOWSER_EYES_CROSS = 8,
	BOWSER_EYES_RESET = 9,
}

Registry.Register("src__game__behaviors__bowser_inc", bowser_inc)

-- from src/game/behaviors/bowser.inc.c:bowser_tail_anchor_act_default L12-28
function bowser_inc.bowser_tail_anchor_act_default()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bowser = o.parentObj :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_tangible()
	ObjectHelpers.cur_obj_scale(1.0)

	if buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM then
		-- Bowser cannot be touched when he tilts BitFS platform
		buffer.writei32(bowser.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
	elseif ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= IncludePRUltratypesH.FALSE then
		-- When Mario collides his tail, it now gets
		-- intangible so he can grab it through
		buffer.writei32(bowser.rawData, IncludeObjectFieldsH.oIntangibleTimer, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TAIL_TOUCHED_MARIO)
	else
		buffer.writei32(bowser.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_tail_anchor_thrown L34-38
function bowser_inc.bowser_tail_anchor_thrown()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TAIL_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_tail_anchor_act_touched_mario L43-50
function bowser_inc.bowser_tail_anchor_act_touched_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	-- Return to main action when Bowser tilts BitFS platform
	if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM then
		buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TAIL_DEFAULT)
	end

	ObjectHelpers.cur_obj_become_intangible()
end

-- from src/game/behaviors/bowser.inc.c:bhv_bowser_tail_anchor_loop L61-73
function bowser_inc.bhv_bowser_tail_anchor_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bowser = o.parentObj :: GroupsTypesHPlus3.Object

	-- Call its actions
	ObjectHelpers.cur_obj_call_action_function(bowser_inc.sBowserTailAnchorActions)

	-- Position the tail
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, 90.0)

	-- Make it intangible while Bowser is dead
	if buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_DEAD then
		buffer.writei32(bowser.rawData, IncludeObjectFieldsH.oIntangibleTimer, -1)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/bowser.inc.c:bhv_bowser_flame_spawn_loop L80-115
function bowser_inc.bhv_bowser_flame_spawn_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bowser = o.parentObj :: GroupsTypesHPlus3.Object
	local animFrame: number
	const cossYaw: number = SrcEngineMathUtilH.coss(buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const sinsYaw: number = SrcEngineMathUtilH.sins(buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const data: number = Memory.segmented_to_virtual(SegmentSymbols.dBowserFlamesOrientationValues)

	-- Check for Bowser breathing animation
	if buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oSoundStateID) == IncludeObjectConstantsH.BOWSER_ANIM_BREATH then
		-- Start counting anim frames then reset it when it ends
		animFrame = TruncS32(F32(bowser.header.gfx.animInfo.animFrame + 1.0))

		if Rom.ReadS16((bowser.header.gfx.animInfo.curAnim :: number) + 8) == animFrame then
			animFrame = 0
		end

		-- Bowser is breathing, play sound and adjust flame position
		-- each animFrame based off the orientantion data
		if animFrame > 45 and animFrame < 85 then
			SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BOWSER_SPIT_FIRE)

			const posX: number = Rom.ReadS16(data + 2 * (5 * animFrame))
			const posZ: number = Rom.ReadS16(data + 2 * (5 * animFrame + 2))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(bowser.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(posZ * sinsYaw) + F32(posX * cossYaw)))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(bowser.rawData, IncludeObjectFieldsH.oPosY) + Rom.ReadS16(data + 2 * (5 * animFrame + 1)))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(bowser.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(posZ * cossYaw) - F32(posX * sinsYaw)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, Rom.ReadS16(data + 2 * (5 * animFrame + 4)) + 0xC00)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Rom.ReadS16(data + 2 * (5 * animFrame + 3)) + S16(buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

			-- Spawns the flames on a non-odd animFrame value
			if not bit32.btest(animFrame, 1) then
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvFlameMovingForwardGrowing)
			end
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bhv_bowser_body_anchor_loop L120-153
function bowser_inc.bhv_bowser_body_anchor_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	-- Copy position and angles from Bowser itself
	ObjectHelpers.obj_copy_pos_and_angle(o, parent)

	-- If Bowser is dead, set interaction type to text
	-- so that he can be ready to speak his dialog
	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_DEAD then
		-- Clear interaction type at the last sub action in BitS
		-- Fixes collision coliding after defeating him
		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_FINAL_END_OVER then
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, 0)
		else
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_TEXT)
		end
	else
		-- Do damage if Mario touches Bowser
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_DAMAGE)

		-- Make body intangible while is transparent
		-- in BitFS (Teleporting)
		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oOpacity) < 100 then
			ObjectHelpers.cur_obj_become_intangible()
		else
			ObjectHelpers.cur_obj_become_tangible()
		end
	end

	-- Make body intangible while Bowser is getting grabbed
	if buffer.readu32(parent.rawData, IncludeObjectFieldsH.oHeldState) ~= IncludeObjectConstantsH.HELD_FREE then
		ObjectHelpers.cur_obj_become_intangible()
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/bowser.inc.c:bowser_spawn_shockwave L158-165
function bowser_inc.bowser_spawn_shockwave(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
		const wave = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWSER_WAVE, BehaviorIds.bhvBowserShockWave)
		buffer.writef32(wave.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/bowser.inc.c:bowser_bounce_effects L171-180
function bowser_inc.bowser_bounce_effects(Buffer: buffer, Offset: number)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		buffer.writei32(Buffer, Offset, buffer.readi32(Buffer, Offset) + 1)

		if buffer.readi32(Buffer, Offset) < 4 then
			ObjectHelpers.cur_obj_start_cam_event(o, GroupsTypesHPlus3.CAM_EVENT_BOWSER_THROW_BOUNCE)
			BehaviorActions.spawn_mist_particles_variable(0, 0, 60.0)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOWSER_WALK)
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_anim_look_up_and_walk L186-196
function bowser_inc.bowser_set_anim_look_up_and_walk(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_LOOK_UP_START_WALK)

	if ObjectHelpers.cur_obj_check_anim_frame(21) ~= IncludePRUltratypesH.FALSE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
	end

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_anim_slow_gait L202-210
function bowser_inc.bowser_set_anim_slow_gait(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_SLOW_GAIT)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_anim_look_down_stop_walk L216-226
function bowser_inc.bowser_set_anim_look_down_stop_walk(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_LOOK_DOWN_STOP_WALK)

	if ObjectHelpers.cur_obj_check_anim_frame(20) ~= IncludePRUltratypesH.FALSE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	end

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_init_camera_actions L232-243
function bowser_inc.bowser_init_camera_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const camAct = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserCamAct)

	if camAct == IncludeObjectConstantsH.BOWSER_CAM_ACT_IDLE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WAIT)
	elseif camAct == IncludeObjectConstantsH.BOWSER_CAM_ACT_WALK then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_INTRO_WALK)
	-- Start with a big jump in BitFS to do a platform tilt
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITFS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_wait L249-253
function bowser_inc.bowser_act_wait()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_IDLE)
	bowser_inc.bowser_init_camera_actions()
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_intro_walk L259-277
function bowser_inc.bowser_act_intro_walk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	-- First look up and walk
	if subAction == 0 then
		if bowser_inc.bowser_set_anim_look_up_and_walk() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	-- Then slowly walk
	elseif subAction == 1 then
		if bowser_inc.bowser_set_anim_slow_gait() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	-- And finally stop, and set to wait mode
	elseif bowser_inc.bowser_set_anim_look_down_stop_walk() ~= IncludePRUltratypesH.FALSE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserCamAct) == IncludeObjectConstantsH.BOWSER_CAM_ACT_WALK then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserCamAct, IncludeObjectConstantsH.BOWSER_CAM_ACT_IDLE)
		end

		bowser_inc.bowser_init_camera_actions()
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_debug_actions L304-309
function bowser_inc.bowser_debug_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- DEBUG_PAGE_ENEMYINFO is 5 (gDebugInfo row 6)
	if ObjectListProcessor.gDebugInfo[6][2] ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, bowser_inc.sBowserDebugActions[bit32.band(ObjectListProcessor.gDebugInfo[6][3], 0x0F) + 1])
		ObjectListProcessor.gDebugInfo[6][2] = 0
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_bitdw_actions L314-348
function bowser_inc.bowser_bitdw_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const rand = SrcEngineBehaviorScript.random_float()

	-- Set attacks when Bowser Reacts
	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting) == IncludePRUltratypesH.FALSE then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_ANGLE_MARIO) then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
				-- nearby
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BREATH_FIRE)
			else
				-- far away
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_QUICK_JUMP)
			end
		else
			-- Keep walking
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting) + 1))
	else
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, IncludePRUltratypesH.FALSE)

		-- Set starting Bowser level actions, randomly he can also start
		-- dancing after the introduction
		if GameInit.gCurrDemoInput == nil then
			-- demo check because entry exits post JP
			if rand < 0.1 then
				-- 10% chance
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DANCE)
			else
				-- common
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_bitfs_actions L353-382
function bowser_inc.bowser_bitfs_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const rand = SrcEngineBehaviorScript.random_float()

	-- Set attacks when Bowser Reacts
	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting) == IncludePRUltratypesH.FALSE then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_ANGLE_MARIO) then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1300.0 then
				-- nearby
				if rand < 0.5 then
					-- 50% chance
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TELEPORT)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_SPIT_FIRE_ONTO_FLOOR)
				end
			else
				-- far away
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_CHARGE_MARIO)

				if 500.0 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter) < 1500.0 and rand < 0.5 then
					-- 50% chance
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP)
				end
			end
		else
			-- Keep walking
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting) + 1))
	else
		-- Keep walking
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, IncludePRUltratypesH.FALSE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_bits_action_list L387-409
function bowser_inc.bowser_bits_action_list()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const rand = SrcEngineBehaviorScript.random_float()

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_ANGLE_MARIO) then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
			-- nearby
			if rand < 0.4 then
				-- 40% chance
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_SPIT_FIRE_ONTO_FLOOR)
			elseif rand < 0.8 then
				-- 80% chance
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_SPIT_FIRE_INTO_SKY)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BREATH_FIRE)
			end
		else
			-- far away
			if rand < 0.5 then
				-- 50% chance
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_CHARGE_MARIO)
			end
		end
	else
		-- Keep walking
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_act_big_jump L415-417
function bowser_inc.bowser_set_act_big_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP)
end

-- from src/game/behaviors/bowser.inc.c:bowser_bits_actions L422-440
function bowser_inc.bowser_bits_actions()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const reacting = buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting)

	if reacting == IncludePRUltratypesH.FALSE then
		-- oBowserBitSJustJump never changes value,
		-- so its always FALSE, maybe a debug define
		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserBitSJustJump) == IncludePRUltratypesH.FALSE then
			bowser_inc.bowser_bits_action_list()
		else
			bowser_inc.bowser_set_act_big_jump()
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, IncludePRUltratypesH.TRUE)
	elseif reacting == IncludePRUltratypesH.TRUE then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, IncludePRUltratypesH.FALSE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WALK_TO_MARIO)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_reset_fallen_off_stage L446-453
function bowser_inc.bowser_reset_fallen_off_stage()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 300.0) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 2000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_idle L459-463
function bowser_inc.bowser_act_idle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_IDLE) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_default L468-485
function bowser_inc.bowser_act_default()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Set eye state
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesShut, IncludePRUltratypesH.FALSE)

	-- Set idle animation
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_IDLE)

	-- Stop him still
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)

	-- Set level specific actions
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITDW then
		bowser_inc.bowser_bitdw_actions()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITFS then
		bowser_inc.bowser_bitfs_actions()
	else
		-- BOWSER_BP_BITS
		bowser_inc.bowser_bits_actions()
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_breath_fire L492-501
function bowser_inc.bowser_act_breath_fire()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOWSER_INHALING)
	end

	-- Init animation and return to default act after it ends
	if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_BREATH) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_walk_to_mario L506-551
function bowser_inc.bowser_act_walk_to_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const angleFromMario = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))))
	local turnSpeed: number

	-- Set turning speed depending of the health
	-- Also special case for BitFS
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITFS then
		turnSpeed = 0x400
	else
		-- BOWSER_BP_BITDW or BOWSER_BP_BITS
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) >= 3 then
			turnSpeed = 0x400
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 2 then
			turnSpeed = 0x300
		else
			-- 1 health
			turnSpeed = 0x200
		end
	end

	-- UNUSED facing: the turn is still done
	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), turnSpeed)

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)

		-- Start walking
		if bowser_inc.bowser_set_anim_look_up_and_walk() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == 1 then
		-- Keep walking slowly
		if bowser_inc.bowser_set_anim_slow_gait() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)

			-- Reset fire sky status
			if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_FIRE_SKY) then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) > 4 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), bit32.bnot(IncludeObjectConstantsH.BOWSER_STATUS_FIRE_SKY))))
				end
			-- Do subaction below if angles is less than 0x2000
			elseif angleFromMario < 0x2000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			end
		end
	-- Stop walking and set to default action
	elseif bowser_inc.bowser_set_anim_look_down_stop_walk() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_teleport L556-603
function bowser_inc.bowser_act_teleport()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_TELEPORT_START then
		-- Set opacity target to invisible and become intangible
		ObjectHelpers.cur_obj_become_intangible()
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 30)

		-- Play sound effect
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_BOWSER_TELEPORT)
		end

		-- Bowser is invisible, move angle to face Mario
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_TELEPORT_MOVE then
		-- reduce timer and set velocity teleport while at it
		const bowserTimer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, bowserTimer - 1)

		if bowserTimer ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 100.0)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_TELEPORT_STOP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			-- update angle
		end

		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) > 0x4000 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 500.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_TELEPORT_STOP)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
				-- update angle
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_BOWSER_TELEPORT)
			end
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_TELEPORT_STOP then
		-- Set opacity target to visible and become tangible
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity, 255)

		-- Set to default action once visible
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 255 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
		end

		ObjectHelpers.cur_obj_become_tangible()
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_spit_fire_into_sky L608-629
function bowser_inc.bowser_act_spit_fire_into_sky()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Play animation
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_BREATH_UP)

	-- Set frames
	const animFrame = o.header.gfx.animInfo.animFrame

	-- Spawn flames in the middle of the animation
	if animFrame > 24 and animFrame < 36 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BOWSER_SPIT_FIRE)

		if animFrame == 35 then
			-- Spawns Blue flames at this frame
			ObjectHelpers.spawn_object_relative(1, 0, 400, 100, o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvBlueBowserFlame)
		else
			-- Spawns Red flames
			ObjectHelpers.spawn_object_relative(0, 0, 400, 100, o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvBlueBowserFlame)
		end
	end

	-- Return to default act once the animation is over
	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end

	-- Set fire sky status
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_FIRE_SKY)))
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_hit_mine L634-672
function bowser_inc.bowser_act_hit_mine()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Similar vel values from bowser_fly_back_dead
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -400.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 100.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter) + 0x8000)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesShut, IncludePRUltratypesH.TRUE)
		-- close eyes
	end

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	-- Play flip animation
	if subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_HIT_MINE_START then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_FLIP)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
	-- Play flip animation again, extend it and play bounce effects
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_HIT_MINE_FALL then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_FLIP)
		ObjectHelpers.cur_obj_extend_animation_if_at_end()
		bowser_inc.bowser_bounce_effects(o.rawData, IncludeObjectFieldsH.oBowserTimer)

		-- Reset vel and stand up
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) > 2 then
			ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_STAND_UP_FROM_FLIP)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	-- Play these actions once he is stand up
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_HIT_MINE_STOP then
		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			-- Makes Bowser dance at one health (in BitS)
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 1 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DANCE)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
			end

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesShut, IncludePRUltratypesH.FALSE)
			-- open eyes
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_anim_jump L678-685
function bowser_inc.bowser_set_anim_jump(): number
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_JUMP_START)

	if ObjectHelpers.cur_obj_check_anim_frame(11) ~= IncludePRUltratypesH.FALSE then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_land L691-712
function bowser_inc.bowser_land(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		BehaviorActions.spawn_mist_particles_variable(0, 0, 60.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_JUMP_STOP)
		o.header.gfx.animInfo.animFrame = 0
		ObjectHelpers.cur_obj_start_cam_event(o, GroupsTypesHPlus3.CAM_EVENT_BOWSER_JUMP)

		-- Set status attacks in BitDW since the other levels
		-- have different attacks defined
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITDW then
			const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 850.0 then
				buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_KNOCKBACK_DMG)))
			else
				buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_STUNNED)))
			end
		end

		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_short_second_hop L717-723
function bowser_inc.bowser_short_second_hop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS and bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP) then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter) > 1000.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 60.0)
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_big_jump L728-768
function bowser_inc.bowser_act_big_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		-- Set jump animation
		if bowser_inc.bowser_set_anim_jump() ~= IncludePRUltratypesH.FALSE then
			-- Set vel depending of the stage and status
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS and bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP) then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 70.0)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 80.0)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
			bowser_inc.bowser_short_second_hop()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == 1 then
		-- Reset Bowser back on stage in BitS if he doesn't land properly
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS and bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP) then
			bowser_inc.bowser_reset_fallen_off_stage()
		end

		-- Land on stage, reset status jump and velocity
		if bowser_inc.bowser_land() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), bit32.bnot(IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)

			-- Spawn shockwave (BitS only) if is not on a platform
			bowser_inc.bowser_spawn_shockwave()

			-- Tilt platform in BitFS
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITFS then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM)
			end
		end
	-- Set to default action when the animation is over
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_quick_jump L779-799
function bowser_inc.bowser_act_quick_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const velY = bowser_inc.sBowserVelYAir[1]
	const fVel = bowser_inc.sBowserFVelAir[1]
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		-- Set fixed val positions while jumping
		if bowser_inc.bowser_set_anim_jump() ~= IncludePRUltratypesH.FALSE then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, velY)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, fVel)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	-- Lands then quickly returns to default action
	elseif subAction == 1 then
		if bowser_inc.bowser_land() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_hit_edge L804-832
function bowser_inc.bowser_act_hit_edge()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Reset speed and timer
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
	end

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		-- Move on the edge
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_EDGE_MOVE)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) > 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == 1 then
		-- Stop moving on the edge
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_EDGE_STOP)

		-- Turn around once the animation ends
		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TURN_FROM_EDGE)
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_spit_fire_onto_floor L837-858
function bowser_inc.bowser_act_spit_fire_onto_floor()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Set fixed rand value if Mario is low health
	if LevelUpdate.gHudDisplay.wedges < 4 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserRandSplitFloor, 3)
	else
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserRandSplitFloor, S16(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 3.0) + 1.0))))
	end

	-- Play animation and split fire at a specific frame
	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_BREATH_QUICK)

	if ObjectHelpers.cur_obj_check_anim_frame(5) ~= IncludePRUltratypesH.FALSE then
		ObjBehaviors2.obj_spit_fire(0, 200, 180, 7.0, IncludeModelIdsH.MODEL_RED_FLAME, 30.0, 10.0, 0x1000)
	end

	-- Use subaction as a timer when the animation is over
	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
	end

	-- Return to default act once we get past rand value
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) >= buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserRandSplitFloor) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_turn_on_timer L864-885
function bowser_inc.bowser_turn_on_timer(time: number, yaw: number): number
	yaw = S16(TruncS32(yaw))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == 0 then
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_LOOK_UP_START_WALK) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == 1 then
		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_LOOK_DOWN_STOP_WALK) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	else
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_IDLE)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + yaw)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= time then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_turn_from_edge L890-894
function bowser_inc.bowser_act_turn_from_edge()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bowser_inc.bowser_turn_on_timer(63, 0x200) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_charge_mario L899-973
function bowser_inc.bowser_act_charge_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local time: number

	-- Reset Speed to prepare charge
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	end

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_START then
		-- Start running
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)

		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_RUN_START) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_RUN)
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_RUN then
		-- Set speed to run
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50.0)

		if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_RUN) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)

			-- Split if 6 timer frames has passed
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) >= 6 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_SLIP)
			end

			-- Slip if Mario has a differentiable angle and 2 timer frames has passed
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) >= 2 then
				if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) > 0x2000 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_SLIP)
				end
			end
		end

		-- Rotate to Mario
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_SLIP then
		-- Spawn smoke puff while slipping
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_RUN_SLIP)
		ObjectHelpers.spawn_object_relative_with_scale(0, 100, -50, 0, 3.0, o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2)
		ObjectHelpers.spawn_object_relative_with_scale(0, -100, -50, 0, 3.0, o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke2)

		-- End Charge once Bowser stops running
		if ObjectHelpers.approach_f32_signed(o.rawData, IncludeObjectFieldsH.oForwardVel, 0, -1.0) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_END)
		end

		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_CHARGE_END then
		-- Stop running
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_RUN_STOP)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			-- Set time delay to go to default action
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
				time = 10
			else
				time = 30
			end

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) > time then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
		end

		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	end

	-- Bowser is close to falling so set hit edge action
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_HIT_EDGE)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_check_hit_mine L978-989
function bowser_inc.bowser_check_hit_mine(): number
	const mine = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvBowserBomb, Scratch.bowser_check_hit_mine_dist)

	if mine ~= nil and Scratch.bowser_check_hit_mine_dist[1] < 800.0 then
		buffer.writei32(mine.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(mine.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_HIT_MINE)))
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_thrown L994-1023
function bowser_inc.bowser_act_thrown()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Keep Bowser's timer at 0 unless he lands
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		-- Play shake animations and do bounce effects
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_SHAKING)
		bowser_inc.bowser_bounce_effects(o.rawData, IncludeObjectFieldsH.oBowserTimer)

		-- Reset speed when he moves on ground
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			-- stops this current subaction
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	-- Stand up and after play, set to default act
	elseif ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_STAND_UP) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end

	-- Hit mine check, reduce health and set specific action depending of it
	if bowser_inc.bowser_check_hit_mine() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) <= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEAD)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_HIT_MINE)
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_set_goal_invisible L1028-1035
function bowser_inc.bowser_set_goal_invisible()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity, 0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 1000.0)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_jump_onto_stage L1040-1138
function bowser_inc.bowser_act_jump_onto_stage()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const floor = o.ptrData[IncludeObjectFieldsH.oFloor + 1] :: GroupsTypesHPlus3.Surface?

	-- Set dynamic floor check (Object platforms)
	const onDynamicFloor = if floor ~= nil and bit32.btest(floor.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_DYNAMIC) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE

	-- Set status Jump
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP)))

	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	-- Stops Bowser and makes him invisible
	if subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_JUMP_ON_STAGE_IDLE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x800)

		if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch), 0xFFFF) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end

		bowser_inc.bowser_set_goal_invisible()
	-- Start jump animation and make him visible after an animation frame
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_JUMP_ON_STAGE_START then
		ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_JUMP_START)

		if ObjectHelpers.cur_obj_check_anim_frame(11) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 150.0)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity, 255)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		else
			bowser_inc.bowser_set_goal_invisible()
		end
	-- Approach him back on stage
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_JUMP_ON_STAGE_LAND then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oDragStrength, 0.0)

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter) < 2500.0 then
				if ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))) < 100.0 then
					ObjectHelpers.approach_f32_signed(o.rawData, IncludeObjectFieldsH.oForwardVel, 0, -5.0)
				else
					ObjectHelpers.cur_obj_forward_vel_approach_upward(150.0, 2.0)
				end
			else
				ObjectHelpers.cur_obj_forward_vel_approach_upward(150.0, 2.0)
			end
		end

		-- Land on stage
		if bowser_inc.bowser_land() ~= IncludePRUltratypesH.FALSE then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oDragStrength, 10.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)

			-- Spawn shockwave (BitS only) if is not on a platform
			if onDynamicFloor == IncludePRUltratypesH.FALSE then
				bowser_inc.bowser_spawn_shockwave()
			-- If is on a dynamic floor in BitS, then jump
			-- because of the falling platform
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP)
			end

			-- If is on a dynamic floor in BitFS, then tilt platform
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITFS then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM)
			end
		end

		-- Reset him back on stage if he still didn't landed yet
		-- Post-JP made this check as a separate function
		bowser_inc.bowser_reset_fallen_off_stage()
	-- Bowser landed, so reset action after he's done jumping
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_JUMP_ON_STAGE_STOP then
		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), bit32.bnot(IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP))))
			ObjectHelpers.cur_obj_extend_animation_if_at_end()
		end
	end

	-- print_debug_bottom_up("sp %d", o->oForwardVel) is debug text output: replaced (no-op)
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_dance L1148-1157
function bowser_inc.bowser_act_dance()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Play a stomp sound effect on certain frames
	if ObjectHelpers.is_item_in_array(S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)), bowser_inc.sBowserDanceStepNoises) ~= IncludePRUltratypesH.FALSE then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOWSER_WALK)
	end

	-- Play dance animation and after that return to default action
	if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_DANCE) ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_spawn_collectable L1163-1171
function bowser_inc.bowser_spawn_collectable()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	local focus: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
		focus = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvGrandStar)
	else
		focus = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWSER_KEY, BehaviorIds.bhvBowserKey)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_BOWSER_KEY)
	end

	Camera.gSecondCameraFocus = focus
	buffer.writei32(focus.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
end

-- from src/game/behaviors/bowser.inc.c:bowser_fly_back_dead L1176-1188
function bowser_inc.bowser_fly_back_dead()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_FLIP_DOWN)

	-- More knockback in BitS
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -400.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -200.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 100.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter) + 0x8000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)
	-- BOWSER_SUB_ACT_DEAD_BOUNCE
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_bounce L1193-1203
function bowser_inc.bowser_dead_bounce()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- close eyes
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesShut, IncludePRUltratypesH.TRUE)
	bowser_inc.bowser_bounce_effects(o.rawData, IncludeObjectFieldsH.oBowserTimer)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOWSER_WALK)
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		-- BOWSER_SUB_ACT_DEAD_WAIT
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_wait_for_mario L1209-1219
function bowser_inc.bowser_dead_wait_for_mario(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local ret = IncludePRUltratypesH.FALSE

	ObjectHelpers.cur_obj_become_intangible()

	if ObjectHelpers.cur_obj_init_animation_and_check_if_near_end(IncludeObjectConstantsH.BOWSER_ANIM_LAY_DOWN) ~= IncludePRUltratypesH.FALSE and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 700.0 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) > 0x6000 then
		ret = IncludePRUltratypesH.TRUE
	end

	ObjectHelpers.cur_obj_extend_animation_if_at_end()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)

	return ret
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_twirl_up L1225-1254
function bowser_inc.bowser_dead_twirl_up(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local ret = IncludePRUltratypesH.FALSE

	-- Set angle rotation once he has low X scale value
	if o.header.gfx.scale[1] < 0.8 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) + 0x80)
	end

	-- Slowly scale down his X and Z value
	if o.header.gfx.scale[1] > 0.2 then
		o.header.gfx.scale[1] = F32(o.header.gfx.scale[1] - 0.02)
		o.header.gfx.scale[3] = F32(o.header.gfx.scale[3] - 0.02)
	else
		-- Now scale down his Y value (and send Bowser up)
		o.header.gfx.scale[2] = F32(o.header.gfx.scale[2] - 0.01)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
	end

	-- At half Y scale value, he is high enough, so we are done
	if o.header.gfx.scale[2] < 0.5 then
		ret = IncludePRUltratypesH.TRUE
	end

	-- Copy angle rotation to moving rotation
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))

	-- Slowly fade out
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) >= 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 2)
	end

	return ret
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_hide L1259-1264
function bowser_inc.bowser_dead_hide()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_scale(0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_default_stage_ending L1275-1304
function bowser_inc.bowser_dead_default_stage_ending(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local ret = IncludePRUltratypesH.FALSE

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) < 2 then
		-- Lower music volume
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) == 0 then
			Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
		end

		-- Play Bowser defeated dialog
		if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, bit32.bor(IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED), bowser_inc.sBowserDefeatedDialogText[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1], 0) ~= IncludePRUltratypesH.FALSE then
			-- Dialog is done, fade out music and play explode sound effect
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_BOWSER_EXPLODE)
			Audio.seq_player_unlower_volume(SeqPlayerLevel, 60)
			Audio.seq_player_fade_out(SeqPlayerLevel, 1)
		end
	-- Hide Bowser and spawn collectable once done twirling
	elseif bowser_inc.bowser_dead_twirl_up() ~= IncludePRUltratypesH.FALSE then
		bowser_inc.bowser_dead_hide()
		BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_YELLOW_COIN, 1.0, 0)
		bowser_inc.bowser_spawn_collectable()
		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		ret = IncludePRUltratypesH.TRUE
	end

	return ret
end

-- from src/game/behaviors/bowser.inc.c:bowser_dead_final_stage_ending L1310-1347
function bowser_inc.bowser_dead_final_stage_ending(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local ret = IncludePRUltratypesH.FALSE
	local dialogID: number

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) < 2 then
		-- Set dialog whenever you have 120 stars or not
		if LevelUpdate.gHudDisplay.stars < 120 then
			dialogID = IncludeDialogIdsH.DIALOG_121
		else
			dialogID = IncludeDialogIdsH.DIALOG_163
		end

		-- Lower music volume
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) == 0 then
			Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
		end

		-- Play Bowser defeated dialog
		if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, bit32.bor(IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED), dialogID, 0) ~= IncludePRUltratypesH.FALSE then
			-- Dialog is done, fade out music and spawn grand star
			ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BOWSER_NO_SHADOW)
			Audio.seq_player_unlower_volume(SeqPlayerLevel, 60)
			Audio.seq_player_fade_out(SeqPlayerLevel, 1)
			bowser_inc.bowser_spawn_collectable()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserTimer) + 1)
		end
	-- Slowly fade him out
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) > 4 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 4)
	else
		-- And at last, hide him
		bowser_inc.bowser_dead_hide()
		ret = IncludePRUltratypesH.TRUE
	end

	return ret
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_dead L1353-1396
function bowser_inc.bowser_act_dead()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const subAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

	if subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_FLY_BACK then
		bowser_inc.bowser_fly_back_dead()
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_BOUNCE then
		bowser_inc.bowser_dead_bounce()
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_WAIT then
		-- Check if Mario is close to Bowser
		if bowser_inc.bowser_dead_wait_for_mario() ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserTimer, 0)

			-- Set different (final) subaction in BitS
			-- Non-BitS Bowser uses default subaction and sets dithering
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BOWSER_BP_BITS then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_FINAL_END)
			else
				o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_DITHERED_ALPHA))
				-- BOWSER_SUB_ACT_DEAD_DEFAULT_END
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
			end
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_DEFAULT_END then
		if bowser_inc.bowser_dead_default_stage_ending() ~= IncludePRUltratypesH.FALSE then
			-- BOWSER_SUB_ACT_DEAD_DEFAULT_END_OVER
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_DEFAULT_END_OVER then
		-- Nothing to do: the ending is over.
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_FINAL_END then
		if bowser_inc.bowser_dead_final_stage_ending() ~= IncludePRUltratypesH.FALSE then
			-- BOWSER_SUB_ACT_DEAD_FINAL_END_OVER
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	elseif subAction == IncludeObjectConstantsH.BOWSER_SUB_ACT_DEAD_FINAL_END_OVER then
		-- Nothing to do: the ending is over.
	end
end

-- from src/game/behaviors/bowser.inc.c:bowser_tilt_platform L1401-1405
function bowser_inc.bowser_tilt_platform(platform: GroupsTypesHPlus3.Object, angSpeed: number)
	angSpeed = S16(TruncS32(angSpeed))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const angle = S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter) + 0x8000)

	buffer.writei32(platform.rawData, IncludeObjectFieldsH.oAngleVelPitch, TruncS32(F32(SrcEngineMathUtilH.coss(angle) * angSpeed)))
	buffer.writei32(platform.rawData, IncludeObjectFieldsH.oAngleVelRoll, TruncS32(F32(-SrcEngineMathUtilH.sins(angle) * angSpeed)))
end

-- from src/game/behaviors/bowser.inc.c:bowser_act_tilt_lava_platform L1443-1491
function bowser_inc.bowser_act_tilt_lava_platform()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const platform: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvTiltingBowserLavaPlatform)

	-- If there's not platform, return to default action
	if platform == nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
	else
		local i = 0
		local isNotTilting = IncludePRUltratypesH.TRUE

		-- Active platform tilting if the timer is not 0
		while bowser_inc.sBowsertiltPlatformData[i + 1].time ~= 0 do
			-- Move if the time values is more than the timer
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < bowser_inc.sBowsertiltPlatformData[i + 1].time then
				-- Set angle speed
				local angSpeed = bowser_inc.sBowsertiltPlatformData[i + 1].angSpeed

				-- Move angle behind Bowser
				if bowser_inc.sBowsertiltPlatformData[i + 1].flag > 0 then
					angSpeed = S16((bowser_inc.sBowsertiltPlatformData[i + 1].time - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - 1) * angSpeed)
				else
					-- Move angle in front of Bowser
					angSpeed = S16((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - bowser_inc.sBowsertiltPlatformData[i].time) * angSpeed)
				end

				-- Set angle values to the platform
				bowser_inc.bowser_tilt_platform(platform, angSpeed)

				-- Play sound effect
				if angSpeed ~= 0 then
					Audio.play_sound(IncludeSoundsH.SOUND_ENV_MOVING_BIG_PLATFORM, platform.header.gfx.cameraToObject)
				end

				isNotTilting = IncludePRUltratypesH.FALSE
				break
			end

			i += 1
		end

		-- If Bowser is done tilting, reset platform angles
		-- and set Bowser to default action
		if isNotTilting == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_DEFAULT)
			buffer.writei32(platform.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
			buffer.writei32(platform.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0)
			buffer.writei32(platform.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
			buffer.writei32(platform.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		end
	end

	-- Extend "idle" animation
	ObjectHelpers.cur_obj_extend_animation_if_at_end()
end

-- from src/game/behaviors/bowser.inc.c:bowser_check_fallen_off_stage L1496-1513
function bowser_inc.bowser_check_fallen_off_stage(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action ~= IncludeObjectConstantsH.BOWSER_ACT_JUMP_ONTO_STAGE and action ~= IncludeObjectConstantsH.BOWSER_ACT_TILT_LAVA_PLATFORM then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 1000.0) then
			return IncludePRUltratypesH.TRUE
		end

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			-- Check for Fire Sea
			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oFloorType) == IncludeSurfaceTerrainsH.SURFACE_BURNING then
				return IncludePRUltratypesH.TRUE
			end

			-- Check for Dark World - Sky
			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oFloorType) == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
				return IncludePRUltratypesH.TRUE
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/bowser.inc.c:bowser_free_update L1587-1615
function bowser_inc.bowser_free_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const platform = o.platform

	-- Platform displacement check (for BitFS)
	if platform ~= nil then
		PlatformDisplacement.apply_platform_displacement(IncludePRUltratypesH.FALSE, platform)
	end

	-- Reset grabbed status
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus, IncludeObjectConstantsH.BOWSER_GRAB_STATUS_NONE)

	-- Update positions and actions (default action)
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(bowser_inc.sBowserActions)
	ObjectHelpers.cur_obj_move_standard(-78)

	-- Jump on stage if Bowser has fallen off
	if bowser_inc.bowser_check_fallen_off_stage() ~= IncludePRUltratypesH.FALSE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_JUMP_ONTO_STAGE)
	end

	-- Check floor height and platform
	SrcEngineSurfaceCollision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bowser_free_update_floor)
	const floor = Scratch.bowser_free_update_floor[1]

	if floor ~= nil and floor.object ~= nil then
		o.platform = floor.object
	else
		o.platform = nil
	end

	-- Sound states for Bowser Animations
	SpawnSound.exec_anim_sound_state(bowser_inc.sBowserSoundStates)
end

-- from src/game/behaviors/bowser.inc.c:bowser_held_update L1620-1650
function bowser_inc.bowser_held_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- Reset fire sky status and make him intangible
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), bit32.bnot(IncludeObjectConstantsH.BOWSER_STATUS_FIRE_SKY))))
	ObjectHelpers.cur_obj_become_intangible()

	const grabbedStatus = buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus)

	-- Play pickup sound, start grabbed animation, and set throw action
	-- Throw action won't be played until he's actually released
	if grabbedStatus == IncludeObjectConstantsH.BOWSER_GRAB_STATUS_NONE then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BOWSER_TAIL_PICKUP)
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(IncludeObjectConstantsH.BOWSER_ANIM_GRABBED, IncludeObjectConstantsH.BOWSER_ACT_THROWN)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus, grabbedStatus + 1)
	-- After the grabbed animation ends, play shaking animation in a loop
	elseif grabbedStatus == IncludeObjectConstantsH.BOWSER_GRAB_STATUS_GRABBED then
		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= IncludePRUltratypesH.FALSE then
			ObjectHelpers.cur_obj_init_animation_with_sound(IncludeObjectConstantsH.BOWSER_ANIM_SHAKING)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus) + 1))
		end
	elseif grabbedStatus == IncludeObjectConstantsH.BOWSER_GRAB_STATUS_HOLDING then
		-- Nothing to do while he is held.
	end

	-- Reset move flags
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)

	-- Copy angle values from Mario
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserHeldAnglePitch, S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAnglePitch)))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserHeldAngleVelYaw, S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
end

-- from src/game/behaviors/bowser.inc.c:bowser_thrown_dropped_update L1655-1684
function bowser_inc.bowser_thrown_dropped_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Reset grabbed status
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserGrabbedStatus, IncludeObjectConstantsH.BOWSER_GRAB_STATUS_NONE)

	-- Set throw action and vel values
	ObjectHelpers.cur_obj_get_thrown_or_placed(1.0, 1.0, IncludeObjectConstantsH.BOWSER_ACT_THROWN)

	-- Set swing speed based of angle
	local swingSpd = F32(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserHeldAngleVelYaw) / 3000.0 * 70.0)

	-- If less than 0, reduce speed
	if swingSpd < 0.0 then
		swingSpd = -swingSpd
	end

	-- If more than 90, increase speed
	if swingSpd > 90.0 then
		swingSpd = F32(swingSpd * 2.5)
	end

	-- Set distance speed when throwing
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineMathUtilH.coss(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserHeldAnglePitch)) * swingSpd)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -SrcEngineMathUtilH.sins(buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserHeldAnglePitch)) * swingSpd)

	ObjectHelpers.cur_obj_become_intangible()

	-- Reset timer and subactions
	const tail = o.prevObj :: GroupsTypesHPlus3.Object
	buffer.writei32(tail.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_TAIL_THROWN)
	buffer.writei32(tail.rawData, IncludeObjectFieldsH.oTimer, 0)
	-- Tail doesn't have sub actions
	buffer.writei32(tail.rawData, IncludeObjectFieldsH.oSubAction, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
end

-- from src/game/behaviors/bowser.inc.c:bhv_bowser_loop L1689-1754
function bowser_inc.bhv_bowser_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const posX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	const posZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

	-- Set distance/angle values
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter, F32(math.sqrt(F32(F32(posX * posX) + F32(posZ * posZ)))))
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter, SrcEngineMathUtil.atan2s(0.0 - posZ, 0.0 - posX))
	const angleToMario = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))))
	const angleToCenter = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserAngleToCenter)))

	-- Reset Status
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), bit32.bnot(0xFF))))

	-- Set bitflag status for distance/angle values
	-- Only the first one is used
	if angleToMario < 0x2000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_ANGLE_MARIO)))
	end

	if angleToCenter < 0x3800 then
		-- unused
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_ANGLE_CENTER)))
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserDistToCenter) < 1000.0 then
		-- unused
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_DIST_CENTER)))
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 850.0 then
		-- unused
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserStatus, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_DIST_MARIO)))
	end

	-- Update Held state actions
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		bowser_inc.bowser_free_update()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		bowser_inc.bowser_held_update()
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		bowser_inc.bowser_thrown_dropped_update()
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		bowser_inc.bowser_thrown_dropped_update()
	end

	-- Adjust model to the floor
	ObjectHelpers.cur_obj_align_gfx_with_floor()

	-- Adjust opacity (when not dead)
	-- Mostly for the teleport action in BitFS
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.BOWSER_ACT_DEAD then
		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity) ~= buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
			-- increase opacity when oBowserTargetOpacity is 255
			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) + 20)

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) > 255 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
				end
			-- reduce opacity when oBowserTargetOpacity is 0
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 20)

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
				end
			end
		end
	end
end

-- from src/game/behaviors/bowser.inc.c:bhv_bowser_init L1759-1786
function bowser_inc.bhv_bowser_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local level: number

	-- Set "reaction" value
	-- It goes true when Bowser is a non-walking state
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserIsReacting, IncludePRUltratypesH.TRUE)

	-- Set no transparency opacity
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserTargetOpacity, 255)

	-- Set Bowser B-param depending of the stage
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
		level = IncludeObjectConstantsH.BOWSER_BP_BITFS
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_3 then
		level = IncludeObjectConstantsH.BOWSER_BP_BITS
	else
		-- LEVEL_BOWSER_1
		level = IncludeObjectConstantsH.BOWSER_BP_BITDW
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, level)

	-- Set health and rainbow light depending of the level
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserRainbowLight, bowser_inc.sBowserRainbowLight[level + 1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, bowser_inc.sBowserHealth[level + 1])

	-- Start camera event, this event is not defined so maybe
	-- the "start arena" cutscene was originally called this way
	ObjectHelpers.cur_obj_start_cam_event(o, GroupsTypesHPlus3.CAM_EVENT_BOWSER_INIT)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_ACT_WAIT)

	-- Set eyes status
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesTimer, 0)
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oBowserEyesShut, IncludePRUltratypesH.FALSE)
end

-- from src/game/behaviors/bowser.inc.c:geo_update_body_rot_from_parent L1788-1800
function bowser_inc.geo_update_body_rot_from_parent(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const prevObj = obj.prevObj

		if prevObj ~= nil then
			ObjectHelpers.create_transformation_from_matrices(Scratch.geo_update_body_rot_from_parent_mtx2, mtx, (Registry.Members.src__game__rendering_graph_node.gCurGraphNodeCamera.matrixPtr :: { { { number } } })[1])
			ObjectHelpers.obj_update_pos_from_parent_transformation(Scratch.geo_update_body_rot_from_parent_mtx2, prevObj)
			ObjectHelpers.obj_set_gfx_pos_from_pos(prevObj)
		end
	end

	return nil
end

-- from src/game/behaviors/bowser.inc.c:bowser_open_eye_switch L1821-1910
function bowser_inc.bowser_open_eye_switch(obj: GroupsTypesHPlus3.Object, switchCase: GroupsTypesHPlus3.GraphNodeSwitchCase)
	const angleFromMario = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleToMario))))
	const eyeCase = switchCase.selectedCase

	if eyeCase == bowser_inc.BOWSER_EYES_OPEN then
		-- Mario is in Bowser's field of view
		if angleFromMario > 0x2000 then
			if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) > 0 then
				switchCase.selectedCase = bowser_inc.BOWSER_EYES_RIGHT
			end

			if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) < 0 then
				switchCase.selectedCase = bowser_inc.BOWSER_EYES_LEFT
			end
		end

		-- Half close, start blinking
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 50 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_HALF_CLOSED
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_HALF_CLOSED then
		-- Close, blinking
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 2 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_CLOSED
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_CLOSED then
		-- Reset blinking
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 2 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_RESET
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_RESET then
		-- Open, no longer blinking
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 2 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_OPEN
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_RIGHT then
		-- Look more on the right if angle didn't change
		-- Otherwise, look at the center (open)
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 2 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_FAR_RIGHT
			if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) <= 0 then
				switchCase.selectedCase = bowser_inc.BOWSER_EYES_OPEN
			end
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_FAR_RIGHT then
		-- Look close right if angle was drastically changed
		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) <= 0 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_RIGHT
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_LEFT then
		-- Look more on the left if angle didn't change
		-- Otherwise, look at the center (open)
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) > 2 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_FAR_LEFT
			if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) >= 0 then
				switchCase.selectedCase = bowser_inc.BOWSER_EYES_OPEN
			end
		end
	elseif eyeCase == bowser_inc.BOWSER_EYES_FAR_LEFT then
		-- Look close left if angle was drastically changed
		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAngleVelYaw) >= 0 then
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_LEFT
		end
	else
		switchCase.selectedCase = bowser_inc.BOWSER_EYES_OPEN
	end

	-- Reset timer if eye case has changed
	if switchCase.selectedCase ~= eyeCase then
		buffer.writei16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer, -1)
	end
end

-- from src/game/behaviors/bowser.inc.c:geo_switch_bowser_eyes L1917-1941
function bowser_inc.geo_switch_bowser_eyes(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { { number } } }): { unknown }?
	local obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
	const switchCase = node :: GroupsTypesHPlus3.GraphNodeSwitchCase

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if RenderingGraphNode.gCurGraphNodeHeldObject ~= nil then
			obj = RenderingGraphNode.gCurGraphNodeHeldObject.objNode :: GroupsTypesHPlus3.Object
		end

		const eyeShut = buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesShut)

		if eyeShut == IncludePRUltratypesH.FALSE then
			-- eyes open, handle eye looking direction
			bowser_inc.bowser_open_eye_switch(obj, switchCase)
		elseif eyeShut == IncludePRUltratypesH.TRUE then
			-- eyes closed, blinking
			switchCase.selectedCase = bowser_inc.BOWSER_EYES_CLOSED
		end

		buffer.writei16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer, S16(buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserEyesTimer) + 1))
	end

	return nil
end

-- from src/game/behaviors/bowser.inc.c:geo_bits_bowser_coloring L1946-1976
function bowser_inc.geo_bits_bowser_coloring(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: number): { unknown }?
	local gfxHead: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		local obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const graphNode = node :: GroupsTypesHPlus3.GraphNodeGenerated

		if RenderingGraphNode.gCurGraphNodeHeldObject ~= nil then
			obj = RenderingGraphNode.gCurGraphNodeHeldObject.objNode :: GroupsTypesHPlus3.Object
		end

		-- Set layers if object is transparent or not
		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oOpacity) == 255 then
			graphNode.fnNode.node.flags = S16(bit32.bor(bit32.band(graphNode.fnNode.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))
		else
			graphNode.fnNode.node.flags = S16(bit32.bor(bit32.band(graphNode.fnNode.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_TRANSPARENT, 8)))
		end

		-- 2 Gfx of 8 bytes: the display list is not drawn
		gfxHead = Memory.alloc_display_list(16) :: { unknown }

		-- If TRUE, clear lighting to give rainbow color
		if buffer.readi16(obj.rawData, IncludeObjectFieldsH.oBowserRainbowLight) ~= 0 then
			-- gSPClearGeometryMode(gfx++, G_LIGHTING) is a display list command: dropped
		end

		-- gSPEndDisplayList(gfx) is a display list command: dropped
	end

	return gfxHead
end

-- from src/game/behaviors/bowser.inc.c:sBowserTailAnchorActions L52-56
bowser_inc.sBowserTailAnchorActions = {
	bowser_inc.bowser_tail_anchor_act_default,
	bowser_inc.bowser_tail_anchor_thrown,
	bowser_inc.bowser_tail_anchor_act_touched_mario,
}

-- from src/game/behaviors/bowser.inc.c:sBowserActions L1518-1539
bowser_inc.sBowserActions = {
	bowser_inc.bowser_act_default,
	bowser_inc.bowser_act_thrown,
	bowser_inc.bowser_act_jump_onto_stage,
	bowser_inc.bowser_act_dance,
	bowser_inc.bowser_act_dead,
	bowser_inc.bowser_act_wait,
	bowser_inc.bowser_act_intro_walk,
	bowser_inc.bowser_act_charge_mario,
	bowser_inc.bowser_act_spit_fire_into_sky,
	bowser_inc.bowser_act_spit_fire_onto_floor,
	bowser_inc.bowser_act_hit_edge,
	bowser_inc.bowser_act_turn_from_edge,
	bowser_inc.bowser_act_hit_mine,
	bowser_inc.bowser_act_big_jump,
	bowser_inc.bowser_act_walk_to_mario,
	bowser_inc.bowser_act_breath_fire,
	bowser_inc.bowser_act_teleport,
	bowser_inc.bowser_act_quick_jump,
	bowser_inc.bowser_act_idle,
	bowser_inc.bowser_act_tilt_lava_platform,
}

return bowser_inc
