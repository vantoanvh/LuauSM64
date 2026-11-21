--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/mips.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const InteractionH = require("../interaction_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SparkleSpawnStarInc = require("./sparkle_spawn_star_inc")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjectHelpersH = require("../object_helpers_h")
const Rom = require("../../rom/rom")
const SegmentSymbols = require("../../rom/segment_symbols")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const mips_inc = {}

Registry.Register("src__game__behaviors__mips_inc", mips_inc)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_init L10-45
function mips_inc.bhv_mips_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const starFlags = U8(SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_NONE)))

	if SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1) >= 15 and not bit32.btest(starFlags, SaveFileH.SAVE_FLAG_TO_STAR_FLAG(SaveFileH.SAVE_FLAG_COLLECTED_MIPS_STAR_1)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.MIPS_BP_15_STARS)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMipsForwardVelocity, 40.0)
	elseif SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1) >= 50 and not bit32.btest(starFlags, SaveFileH.SAVE_FLAG_TO_STAR_FLAG(SaveFileH.SAVE_FLAG_COLLECTED_MIPS_STAR_2)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, IncludeObjectConstantsH.MIPS_BP_50_STARS)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMipsForwardVelocity, 45.0)
	else
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, InteractionH.INT_SUBTYPE_HOLDABLE_NPC)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 15.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.89)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.2)

	ObjectHelpers.cur_obj_init_animation(0)
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_find_furthest_waypoint_to_mario L51-81
function mips_inc.bhv_mips_find_furthest_waypoint_to_mario(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local furthestWaypointIndex = -1
	local furthestWaypointDistance = F32(-10000.0)
	const pathBase: number = Memory.segmented_to_virtual(SegmentSymbols.inside_castle_seg7_trajectory_mips)

	-- For each waypoint in MIPS path...
	for i = 0, 10 - 1 do
		const waypoint: number = Memory.segmented_to_virtual(Rom.ReadU32(pathBase + 4 * i))
		const x: number = Rom.ReadS16(waypoint + 2)
		const y: number = Rom.ReadS16(waypoint + 4)
		const z: number = Rom.ReadS16(waypoint + 6)

		-- Is the waypoint within 800 units of MIPS?
		if ObjBehaviors.is_point_close_to_object(o, x, y, z, 800) ~= 0 then
			-- Is this further from Mario than the last waypoint?
			const distanceToMario: number = F32(SrcEngineMathUtilH.sqr(F32(x - marioObject.header.gfx.pos[1])) + SrcEngineMathUtilH.sqr(F32(z - marioObject.header.gfx.pos[3])))

			if furthestWaypointDistance < distanceToMario then
				furthestWaypointIndex = i
				furthestWaypointDistance = distanceToMario
			end
		end
	end

	-- Set MIPS' next waypoint to be the closest waypoint to Mario.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMipsStartWaypointIndex, furthestWaypointIndex)

	return S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMipsStartWaypointIndex))
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_act_wait_for_nearby_mario L86-104
function mips_inc.bhv_mips_act_wait_for_nearby_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	ObjBehaviors.object_step()

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 500) ~= 0 then
		if mips_inc.bhv_mips_find_furthest_waypoint_to_mario() == -1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_WAIT_FOR_ANIMATION_DONE)
		else
			ObjectHelpers.cur_obj_init_animation(1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_FOLLOW_PATH)
		end
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_act_follow_path L109-148
function mips_inc.bhv_mips_act_follow_path()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local collisionFlags = 0

	-- Retrieve current waypoint.
	const pathBase: number = Memory.segmented_to_virtual(SegmentSymbols.inside_castle_seg7_trajectory_mips)
	const waypoint: number = Memory.segmented_to_virtual(Rom.ReadU32(pathBase + 4 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMipsStartWaypointIndex)))
	local followStatus = 0

	-- Set start waypoint and follow the path from there.
	o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = waypoint

	--! Uninitialized parameter, but the parameter is unused in the called function
	followStatus = ObjectHelpers.cur_obj_follow_path(followStatus)

	-- Update velocity and angle and do movement.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMipsForwardVelocity))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw))
	collisionFlags = S16(ObjBehaviors.object_step())

	-- If we are at the end of the path, do idle animation and wait for Mario.
	if followStatus == ObjectHelpersH.PATH_REACHED_END then
		ObjectHelpers.cur_obj_init_animation(0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_WAIT_FOR_NEARBY_MARIO)
	end

	-- Play sounds during walk animation.
	if ObjectHelpers.cur_obj_check_if_near_animation_end() == IncludePRUltratypesH.TRUE and bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_UNDERWATER) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MIPS_RABBIT_WATER)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvShallowWaterSplash)
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() == IncludePRUltratypesH.TRUE then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MIPS_RABBIT)
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_act_wait_for_animation_done L153-158
function mips_inc.bhv_mips_act_wait_for_animation_done()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_check_if_near_animation_end() == IncludePRUltratypesH.TRUE then
		ObjectHelpers.cur_obj_init_animation(0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_IDLE)
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_act_fall_down L163-179
function mips_inc.bhv_mips_act_fall_down()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const collisionFlags = S16(ObjBehaviors.object_step())

	o.header.gfx.animInfo.animFrame = 0

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) == ObjBehaviors.OBJ_COL_FLAG_GROUNDED then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_WAIT_FOR_ANIMATION_DONE)

		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

		if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_UNDERWATER) then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvShallowWaterSplash)
		end
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_act_idle L184-195
function mips_inc.bhv_mips_act_idle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	ObjBehaviors.object_step()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMipsStarStatus) == IncludeObjectConstantsH.MIPS_STAR_STATUS_SHOULD_SPAWN_STAR then
		SparkleSpawnStarInc.bhv_spawn_star_no_level_exit(IncludeObjectConstantsH.STAR_INDEX_ACT_4 + buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMipsStarStatus, IncludeObjectConstantsH.MIPS_STAR_STATUS_ALREADY_SPAWNED_STAR)
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_free L200-222
function mips_inc.bhv_mips_free()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MIPS_ACT_WAIT_FOR_NEARBY_MARIO then
		mips_inc.bhv_mips_act_wait_for_nearby_mario()
	elseif action == IncludeObjectConstantsH.MIPS_ACT_FOLLOW_PATH then
		mips_inc.bhv_mips_act_follow_path()
	elseif action == IncludeObjectConstantsH.MIPS_ACT_WAIT_FOR_ANIMATION_DONE then
		mips_inc.bhv_mips_act_wait_for_animation_done()
	elseif action == IncludeObjectConstantsH.MIPS_ACT_FALL_DOWN then
		mips_inc.bhv_mips_act_fall_down()
	elseif action == IncludeObjectConstantsH.MIPS_ACT_IDLE then
		mips_inc.bhv_mips_act_idle()
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_held L227-254
function mips_inc.bhv_mips_held()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
	ObjectHelpers.cur_obj_init_animation(4)
	ObjectHelpers.cur_obj_set_pos_relative(ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object, 0, 60.0, 100.0)
	ObjectHelpers.cur_obj_become_intangible()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMipsStarStatus) == IncludeObjectConstantsH.MIPS_STAR_STATUS_HAVENT_SPAWNED_STAR then
		local dialogID = IncludeDialogIdsH.DIALOG_162

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.MIPS_BP_15_STARS then
			dialogID = IncludeDialogIdsH.DIALOG_084
		end

		if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP))

			if Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, dialogID) ~= 0 then
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DROP_IMMEDIATELY)))
				o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_INITIATED_TIME_STOP)))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMipsStarStatus, IncludeObjectConstantsH.MIPS_STAR_STATUS_SHOULD_SPAWN_STAR)
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
			end
		end
	end
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_dropped L259-267
function mips_inc.bhv_mips_dropped()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_get_dropped()
	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	ObjectHelpers.cur_obj_init_animation(0)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)
	ObjectHelpers.cur_obj_become_tangible()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_IDLE)
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_thrown L272-282
function mips_inc.bhv_mips_thrown()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_enable_rendering_2()
	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))
	ObjectHelpers.cur_obj_init_animation(2)
	ObjectHelpers.cur_obj_become_tangible()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MIPS_ACT_FALL_DOWN)
end

-- from src/game/behaviors/mips.inc.c:bhv_mips_loop L287-306
function mips_inc.bhv_mips_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	-- Determine what to do based on MIPS held status.
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		mips_inc.bhv_mips_free()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		mips_inc.bhv_mips_held()
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		mips_inc.bhv_mips_thrown()
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		mips_inc.bhv_mips_dropped()
	end
end

return mips_inc
