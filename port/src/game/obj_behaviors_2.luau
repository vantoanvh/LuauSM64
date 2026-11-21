--!strict
--!optimize 2

--[[
	Port of src/game/obj_behaviors_2.c.
]]

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const BehaviorIds = require("../rom/behavior_ids")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const ObjectHelpers = require("./object_helpers")
const Registry = require("../../groups/registry")
const SrcEngineMathUtil = require("../engine/math_util")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const InteractionH = require("./interaction_h")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const ObjBehaviors2H = require("./obj_behaviors_2_h")
const ObjectHelpersH = require("./object_helpers_h")
const Rom = require("../rom/rom")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/obj_behaviors_2.luau:scratch
const Scratch = {
	obj_roll_to_match_yaw_turn_targetRoll = { 0 },
	obj_smooth_turn_currentSpeed = { 0 },
	obj_bounce_off_walls_edges_objects_targetYaw = { 0 },
	obj_act_squished_scale = buffer.create(4),
	obj_grow_then_shrink_scale = buffer.create(4),
}

-- from src/game/obj_behaviors_2.c:data
const obj_behaviors_2 = {
	POS_OP_SAVE_POSITION = 0,
	POS_OP_COMPUTE_VELOCITY = 1,
	POS_OP_RESTORE_POSITION = 2,
	-- from src/game/obj_behaviors_2.c:sMasterTreadmill L71-71
	sMasterTreadmill = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/obj_behaviors_2.c:sObjSavedPosX L73-73
	sObjSavedPosX = 0,
	-- from src/game/obj_behaviors_2.c:sObjSavedPosY L74-74
	sObjSavedPosY = 0,
	-- from src/game/obj_behaviors_2.c:sObjSavedPosZ L75-75
	sObjSavedPosZ = 0,
}

-- from src/game/obj_behaviors_2.c:obj_is_rendering_enabled L80-86
function obj_behaviors_2.obj_is_rendering_enabled(): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/obj_behaviors_2.c:obj_get_pitch_from_vel L88-90
function obj_behaviors_2.obj_get_pitch_from_vel(): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	return S16(-SrcEngineMathUtil.atan2s(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel), buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)))
end

-- from src/game/obj_behaviors_2.c:obj_update_race_proposition_dialog L99-110
function obj_behaviors_2.obj_update_race_proposition_dialog(dialogID: number): number
	dialogID = S16(TruncS32(dialogID))
	const dialogResponse: number = ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, bit32.bor(IncludeObjectConstantsH.DIALOG_FLAG_TURN_TO_MARIO, IncludeObjectConstantsH.DIALOG_FLAG_TIME_STOP_ENABLED), GroupsTypesHPlus3.CUTSCENE_RACE_DIALOG, dialogID)

	if dialogResponse == Registry.Members.groups__ingame_menu_plus1.DIALOG_RESPONSE_NO then
		Registry.Members.src__game__mario_actions_cutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		ObjectHelpers.disable_time_stop_including_mario()
	end

	return dialogResponse
end

-- from src/game/obj_behaviors_2.c:obj_set_dist_from_home L112-115
function obj_behaviors_2.obj_set_dist_from_home(distFromHome: number)
	distFromHome = F32(distFromHome)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const cosine: number = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const sine: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(distFromHome * cosine))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(distFromHome * sine))
end

-- from src/game/obj_behaviors_2.c:obj_is_near_to_and_facing_mario L117-123
function obj_behaviors_2.obj_is_near_to_and_facing_mario(maxDist: number, maxAngleDiff: number): number
	maxDist = F32(maxDist)
	maxAngleDiff = S16(TruncS32(maxAngleDiff))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < maxDist and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))) < maxAngleDiff then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_perform_position_op L127-147
function obj_behaviors_2.obj_perform_position_op(op: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if op == obj_behaviors_2.POS_OP_SAVE_POSITION then
		obj_behaviors_2.sObjSavedPosX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		obj_behaviors_2.sObjSavedPosY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		obj_behaviors_2.sObjSavedPosZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
	elseif op == obj_behaviors_2.POS_OP_COMPUTE_VELOCITY then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - obj_behaviors_2.sObjSavedPosX)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - obj_behaviors_2.sObjSavedPosY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - obj_behaviors_2.sObjSavedPosZ)
	elseif op == obj_behaviors_2.POS_OP_RESTORE_POSITION then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, obj_behaviors_2.sObjSavedPosX)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, obj_behaviors_2.sObjSavedPosY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, obj_behaviors_2.sObjSavedPosZ)
	end
end

-- from src/game/obj_behaviors_2.c:platform_on_track_update_pos_or_spawn_ball L149-243
function obj_behaviors_2.platform_on_track_update_pos_or_spawn_ball(ballIndex: number, x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ballIndex == 0 or bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), 0x0080) then
		const initialPrevWaypoint: number = o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackPrevWaypoint + 1] :: number
		local nextWaypoint = initialPrevWaypoint
		local prevWaypoint = initialPrevWaypoint
		local amountToMove = 0
		local dx = 0
		local dy = 0
		local dz = 0
		local distToNextWaypoint = 0

		if ballIndex ~= 0 then
			amountToMove = F32(300 * ballIndex)
		else
			obj_behaviors_2.obj_perform_position_op(obj_behaviors_2.POS_OP_SAVE_POSITION)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags, 0)
			amountToMove = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
		end

		repeat
			prevWaypoint = nextWaypoint
			nextWaypoint += 8

			if Rom.ReadS16(nextWaypoint) == ObjectHelpersH.WAYPOINT_FLAGS_END then
				if ballIndex == 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags, ObjectHelpersH.WAYPOINT_FLAGS_END)
				end

				if bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_RETURN_TO_START) then
					nextWaypoint = o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackStartWaypoint + 1] :: number
				else
					return
				end
			end

			dx = F32(Rom.ReadS16(nextWaypoint + 2) - x)
			dy = F32(Rom.ReadS16(nextWaypoint + 4) - y)
			dz = F32(Rom.ReadS16(nextWaypoint + 6) - z)

			distToNextWaypoint = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

			-- Move directly to the next waypoint, even if it's farther away than amountToMove
			amountToMove = F32(amountToMove - distToNextWaypoint)
			x = F32(x + dx)
			y = F32(y + dy)
			z = F32(z + dz)
		until not (amountToMove > 0)

		-- If we moved farther than amountToMove, move in the opposite direction
		distToNextWaypoint = F32(amountToMove / distToNextWaypoint)
		x = F32(x + F32(dx * distToNextWaypoint))
		y = F32(y + F32(dy * distToNextWaypoint))
		z = F32(z + F32(dz * distToNextWaypoint))

		if ballIndex ~= 0 then
			const trackBall: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex) + ballIndex, 0, 0, 0, o, IncludeModelIdsH.MODEL_TRAJECTORY_MARKER_BALL, BehaviorIds.bhvTrackBall)

			if trackBall ~= nil then
				buffer.writef32(trackBall.rawData, IncludeObjectFieldsH.oPosX, x)
				buffer.writef32(trackBall.rawData, IncludeObjectFieldsH.oPosY, y)
				buffer.writef32(trackBall.rawData, IncludeObjectFieldsH.oPosZ, z)
			end
		else
			if prevWaypoint ~= initialPrevWaypoint then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) == 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags, Rom.ReadS16(initialPrevWaypoint))
				end

				o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackPrevWaypoint + 1] = prevWaypoint
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, x)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, y)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, z)

			obj_behaviors_2.obj_perform_position_op(obj_behaviors_2.POS_OP_COMPUTE_VELOCITY)

			const velX: number = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX)
			const velY: number = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)
			const velZ: number = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPitch, SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(velX * velX) + F32(velZ * velZ)))), -velY))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackYaw, SrcEngineMathUtil.atan2s(velZ, velX))
		end
	end
end

-- from src/game/obj_behaviors_2.c:cur_obj_spin_all_dimensions L245-298
function obj_behaviors_2.cur_obj_spin_all_dimensions(arg0: number, arg1: number)
	arg0 = F32(arg0)
	arg1 = F32(arg1)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) == 0 then
		local val24 = 0
		local val20 = 0
		local val1C = 0
		local c = 0
		local s = 0
		local val10 = 0
		local val0C = 0
		local val08 = 0
		local val04 = 0
		local val00 = 0

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_IN_AIR) then
			val20 = 50
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < 0 then
				val1C = -arg0
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0 then
				val1C = arg0
			end

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) < 0 then
				val24 = -arg1
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) > 0 then
				val24 = arg1
			end
		end

		c = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		s = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		val08 = F32(F32(val1C * c) + F32(val20 * s))
		val0C = F32(F32(val20 * c) - F32(val1C * s))

		c = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
		s = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
		val04 = F32(F32(val24 * c) + F32(val0C * s))
		val0C = F32(F32(val0C * c) - F32(val24 * s))

		c = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		s = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		val10 = F32(F32(val04 * c) - F32(val08 * s))
		val08 = F32(F32(val08 * c) + F32(val04 * s))

		val04 = F32(F32(val24 * c) - F32(val1C * s))
		val00 = F32(F32(val1C * c) + F32(val24 * s))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - val04) + val10)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, val20 - val0C)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + val00) - val08)
	end
end

-- from src/game/obj_behaviors_2.c:obj_rotate_yaw_and_bounce_off_walls L300-305
function obj_behaviors_2.obj_rotate_yaw_and_bounce_off_walls(targetYaw: number, turnAmount: number)
	targetYaw = S16(TruncS32(targetYaw))
	turnAmount = S16(TruncS32(turnAmount))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		targetYaw = ObjectHelpers.cur_obj_reflect_move_angle_off_wall()
	end

	ObjectHelpers.cur_obj_rotate_yaw_toward(targetYaw, turnAmount)
end

-- from src/game/obj_behaviors_2.c:obj_get_pitch_to_home L307-309
function obj_behaviors_2.obj_get_pitch_to_home(latDistToHome: number): number
	latDistToHome = F32(latDistToHome)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	return SrcEngineMathUtil.atan2s(latDistToHome, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)))
end

-- from src/game/obj_behaviors_2.c:obj_compute_vel_from_move_pitch L311-314
function obj_behaviors_2.obj_compute_vel_from_move_pitch(speed: number)
	speed = F32(speed)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const pitch: number = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)
	const cosine: number = Registry.Members.src__engine__math_util_h.coss(pitch)
	const sine: number = Registry.Members.src__engine__math_util_h.sins(pitch)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, speed * cosine)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, speed * -sine)
end

-- from src/game/obj_behaviors_2.c:clamp_s16 L316-326
function obj_behaviors_2.clamp_s16(value: { number }, minimum: number, maximum: number): number
	minimum = S16(TruncS32(minimum))
	maximum = S16(TruncS32(maximum))
	if value[1] <= minimum then
		value[1] = minimum
	elseif value[1] >= maximum then
		value[1] = maximum
	else
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/obj_behaviors_2.c:clamp_f32 L328-338
function obj_behaviors_2.clamp_f32(Buffer: buffer, Offset: number, minimum: number, maximum: number): number
	minimum = F32(minimum)
	maximum = F32(maximum)
	if buffer.readf32(Buffer, Offset) <= minimum then
		buffer.writef32(Buffer, Offset, minimum)
	elseif buffer.readf32(Buffer, Offset) >= maximum then
		buffer.writef32(Buffer, Offset, maximum)
	else
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/obj_behaviors_2.c:cur_obj_init_anim_extend L340-343
function obj_behaviors_2.cur_obj_init_anim_extend(arg0: number)
	ObjectHelpers.cur_obj_init_animation_with_sound(arg0)
	ObjectHelpers.cur_obj_extend_animation_if_at_end()
end

-- from src/game/obj_behaviors_2.c:cur_obj_init_anim_and_check_if_end L345-348
function obj_behaviors_2.cur_obj_init_anim_and_check_if_end(arg0: number): number
	ObjectHelpers.cur_obj_init_animation_with_sound(arg0)

	return ObjectHelpers.cur_obj_check_if_near_animation_end()
end

-- from src/game/obj_behaviors_2.c:cur_obj_init_anim_check_frame L350-353
function obj_behaviors_2.cur_obj_init_anim_check_frame(arg0: number, arg1: number): number
	ObjectHelpers.cur_obj_init_animation_with_sound(arg0)

	return ObjectHelpers.cur_obj_check_anim_frame(arg1)
end

-- from src/game/obj_behaviors_2.c:cur_obj_set_anim_if_at_end L355-361
function obj_behaviors_2.cur_obj_set_anim_if_at_end(arg0: number): number
	if ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 then
		ObjectHelpers.cur_obj_init_animation_with_sound(arg0)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:cur_obj_play_sound_at_anim_range L363-376
function obj_behaviors_2.cur_obj_play_sound_at_anim_range(arg0: number, arg1: number, sound: number): number
	arg0 = S8(TruncS32(arg0))
	arg1 = S8(TruncS32(arg1))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	local val04 = TruncS32(o.header.gfx.animInfo.animAccel / 0x10000)

	if val04 <= 0 then
		val04 = 1
	end

	if ObjectHelpers.cur_obj_check_anim_frame_in_range(arg0, val04) ~= 0 or ObjectHelpers.cur_obj_check_anim_frame_in_range(arg1, val04) ~= 0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(sound)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_turn_pitch_toward_mario L378-386
function obj_behaviors_2.obj_turn_pitch_toward_mario(targetOffsetY: number, turnAmount: number): number
	targetOffsetY = F32(targetOffsetY)
	turnAmount = S16(TruncS32(turnAmount))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - targetOffsetY)
	const targetPitch: number = ObjectHelpers.obj_turn_toward_object(o, marioObj, IncludeObjectFieldsH.O_MOVE_ANGLE_PITCH_INDEX, turnAmount)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + targetOffsetY)

	return targetPitch
end

-- from src/game/obj_behaviors_2.c:approach_f32_ptr L388-400
function obj_behaviors_2.approach_f32_ptr(Buffer: buffer, Offset: number, target: number, delta: number): number
	target = F32(target)
	delta = F32(delta)
	if buffer.readf32(Buffer, Offset) > target then
		delta = -delta
	end

	buffer.writef32(Buffer, Offset, buffer.readf32(Buffer, Offset) + delta)

	if F32(F32(buffer.readf32(Buffer, Offset) - target) * delta) >= 0 then
		buffer.writef32(Buffer, Offset, target)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_forward_vel_approach L402-404
function obj_behaviors_2.obj_forward_vel_approach(target: number, delta: number): number
	target = F32(target)
	delta = F32(delta)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	return obj_behaviors_2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oForwardVel, target, delta)
end

-- from src/game/obj_behaviors_2.c:obj_y_vel_approach L406-408
function obj_behaviors_2.obj_y_vel_approach(target: number, delta: number): number
	target = F32(target)
	delta = F32(delta)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	return obj_behaviors_2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oVelY, target, delta)
end

-- from src/game/obj_behaviors_2.c:obj_move_pitch_approach L410-418
function obj_behaviors_2.obj_move_pitch_approach(target: number, delta: number): number
	target = S16(TruncS32(target))
	delta = S16(TruncS32(delta))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), target, delta))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) == target then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_face_pitch_approach L420-428
function obj_behaviors_2.obj_face_pitch_approach(targetPitch: number, deltaPitch: number): number
	targetPitch = S16(TruncS32(targetPitch))
	deltaPitch = S16(TruncS32(deltaPitch))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)), targetPitch, deltaPitch))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) == targetPitch then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_face_yaw_approach L430-438
function obj_behaviors_2.obj_face_yaw_approach(targetYaw: number, deltaYaw: number): number
	targetYaw = S16(TruncS32(targetYaw))
	deltaYaw = S16(TruncS32(deltaYaw))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), targetYaw, deltaYaw))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) == targetYaw then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_face_roll_approach L440-448
function obj_behaviors_2.obj_face_roll_approach(targetRoll: number, deltaRoll: number): number
	targetRoll = S16(TruncS32(targetRoll))
	deltaRoll = S16(TruncS32(deltaRoll))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)), targetRoll, deltaRoll))

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)) == targetRoll then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_smooth_turn L450-463
function obj_behaviors_2.obj_smooth_turn(angleVel: { number }, angle: { number }, targetAngle: number, targetSpeedProportion: number, accel: number, minSpeed: number, maxSpeed: number): number
	targetAngle = S16(TruncS32(targetAngle))
	targetSpeedProportion = F32(targetSpeedProportion)
	accel = S16(TruncS32(accel))
	minSpeed = S16(TruncS32(minSpeed))
	maxSpeed = S16(TruncS32(maxSpeed))
	const currentAngle: number = S16(angle[1])

	angleVel[1] = ObjectHelpers.approach_s16_symmetric(angleVel[1], S16(TruncS32(F32((targetAngle - currentAngle) * targetSpeedProportion))), accel)

	Scratch.obj_smooth_turn_currentSpeed[1] = S16(ObjectHelpers.absi(angleVel[1]))
	obj_behaviors_2.clamp_s16(Scratch.obj_smooth_turn_currentSpeed, minSpeed, maxSpeed)

	angle[1] = ObjectHelpers.approach_s16_symmetric(S16(angle[1]), targetAngle, Scratch.obj_smooth_turn_currentSpeed[1])

	if S16(angle[1]) == targetAngle then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_roll_to_match_yaw_turn L465-469
function obj_behaviors_2.obj_roll_to_match_yaw_turn(targetYaw: number, maxRoll: number, rollSpeed: number)
	targetYaw = S16(TruncS32(targetYaw))
	maxRoll = S16(TruncS32(maxRoll))
	rollSpeed = S16(TruncS32(rollSpeed))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	Scratch.obj_roll_to_match_yaw_turn_targetRoll[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - targetYaw)
	obj_behaviors_2.clamp_s16(Scratch.obj_roll_to_match_yaw_turn_targetRoll, S16(-maxRoll), maxRoll)
	obj_behaviors_2.obj_face_roll_approach(Scratch.obj_roll_to_match_yaw_turn_targetRoll[1], rollSpeed)
end

-- from src/game/obj_behaviors_2.c:random_linear_offset L471-473
function obj_behaviors_2.random_linear_offset(base: number, range: number): number
	base = S16(TruncS32(base))
	range = S16(TruncS32(range))
	return S16(base + S16(TruncS32(F32(range * SrcEngineBehaviorScript.random_float()))))
end

-- from src/game/obj_behaviors_2.c:random_mod_offset L475-477
function obj_behaviors_2.random_mod_offset(base: number, step: number, mod: number): number
	base = S16(TruncS32(base))
	step = S16(TruncS32(step))
	mod = S16(TruncS32(mod))
	return S16(base + step * math.fmod(SrcEngineBehaviorScript.random_u16(), mod))
end

-- from src/game/obj_behaviors_2.c:obj_random_fixed_turn L479-481
function obj_behaviors_2.obj_random_fixed_turn(delta: number): number
	delta = S16(TruncS32(delta))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	return S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + S16(SrcEngineBehaviorScript.random_sign()) * delta)
end

-- from src/game/obj_behaviors_2.c:obj_grow_then_shrink L490-507
function obj_behaviors_2.obj_grow_then_shrink(scaleVel: { number }, shootFireScale: number, endScale: number): number
	shootFireScale = F32(shootFireScale)
	endScale = F32(endScale)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 2 then
		o.header.gfx.scale[1] = F32(o.header.gfx.scale[1] + scaleVel[1])

		scaleVel[1] = F32(scaleVel[1] - F32(0.01))
		if scaleVel[1] > F32(-0.03) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		buffer.writef32(Scratch.obj_grow_then_shrink_scale, 0, o.header.gfx.scale[1])
		const approached: number = obj_behaviors_2.approach_f32_ptr(Scratch.obj_grow_then_shrink_scale, 0, endScale, F32(0.05))
		o.header.gfx.scale[1] = buffer.readf32(Scratch.obj_grow_then_shrink_scale, 0)

		if approached ~= 0 then
			return -1
		elseif scaleVel[1] ~= 0 and o.header.gfx.scale[1] < shootFireScale then
			scaleVel[1] = 0
			return 1
		end
	end

	return 0
end

-- from src/game/obj_behaviors_2.c:oscillate_toward L509-532
function obj_behaviors_2.oscillate_toward(ValueBuffer: buffer, ValueOffset: number, VelBuffer: buffer, VelOffset: number, target: number, velCloseToZero: number, accel: number, slowdown: number): number
	velCloseToZero = F32(velCloseToZero)
	accel = F32(accel)
	slowdown = F32(slowdown)
	const startValue: number = buffer.readi32(ValueBuffer, ValueOffset)
	buffer.writei32(ValueBuffer, ValueOffset, S32(buffer.readi32(ValueBuffer, ValueOffset) + TruncS32(buffer.readf32(VelBuffer, VelOffset))))

	if buffer.readi32(ValueBuffer, ValueOffset) == target or (S32((buffer.readi32(ValueBuffer, ValueOffset) - target) * (startValue - target)) < 0 and buffer.readf32(VelBuffer, VelOffset) > -velCloseToZero and buffer.readf32(VelBuffer, VelOffset) < velCloseToZero) then
		buffer.writei32(ValueBuffer, ValueOffset, target)
		buffer.writef32(VelBuffer, VelOffset, 0)
		return IncludePRUltratypesH.TRUE
	else
		if buffer.readi32(ValueBuffer, ValueOffset) >= target then
			accel = -accel
		end

		if F32(buffer.readf32(VelBuffer, VelOffset) * accel) < 0 then
			accel = F32(accel * slowdown)
		end

		buffer.writef32(VelBuffer, VelOffset, buffer.readf32(VelBuffer, VelOffset) + accel)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_update_blinking L534-547
function obj_behaviors_2.obj_update_blinking(Buffer: buffer, Offset: number, baseCycleLength: number, cycleLengthRange: number, blinkLength: number)
	baseCycleLength = S16(TruncS32(baseCycleLength))
	cycleLengthRange = S16(TruncS32(cycleLengthRange))
	blinkLength = S16(TruncS32(blinkLength))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(Buffer, Offset) ~= 0 then
		buffer.writei32(Buffer, Offset, buffer.readi32(Buffer, Offset) - 1)
	else
		buffer.writei32(Buffer, Offset, obj_behaviors_2.random_linear_offset(baseCycleLength, cycleLengthRange))
	end

	if buffer.readi32(Buffer, Offset) > blinkLength then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	end
end

-- from src/game/obj_behaviors_2.c:obj_resolve_object_collisions L549-593
function obj_behaviors_2.obj_resolve_object_collisions(targetYaw: { number }?): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if o.numCollidedObjs ~= 0 then
		const otherObject: GroupsTypesHPlus3.Object = o.collidedObjs[1] :: GroupsTypesHPlus3.Object
		const marioObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

		if otherObject ~= marioObj then
			const dx = F32(buffer.readf32(otherObject.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
			const dz = F32(buffer.readf32(otherObject.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			-- Source bug kept: atan2s(dx, dz), it should be atan2s(dz, dx)
			const angle: number = SrcEngineMathUtil.atan2s(dx, dz)

			const radius = o.hitboxRadius
			const otherRadius = otherObject.hitboxRadius
			const relativeRadius = F32(radius / F32(radius + otherRadius))

			const newCenterX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(dx * relativeRadius))
			const newCenterZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(dz * relativeRadius))

			const cosine: number = Registry.Members.src__engine__math_util_h.coss(angle)
			const sine: number = Registry.Members.src__engine__math_util_h.sins(angle)

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, newCenterX - F32(radius * cosine))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, newCenterZ - F32(radius * sine))

			buffer.writef32(otherObject.rawData, IncludeObjectFieldsH.oPosX, newCenterX + F32(otherRadius * cosine))
			buffer.writef32(otherObject.rawData, IncludeObjectFieldsH.oPosZ, newCenterZ + F32(otherRadius * sine))

			if targetYaw ~= nil and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), angle) < 0x4000 then
				-- Bounce off object (or it would, if the above atan2s bug were fixed)
				targetYaw[1] = S16(angle - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + angle + 0x8000)
				return IncludePRUltratypesH.TRUE
			end
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_bounce_off_walls_edges_objects L595-605
function obj_behaviors_2.obj_bounce_off_walls_edges_objects(Buffer: buffer, Offset: number): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const targetYaw: { number } = Scratch.obj_bounce_off_walls_edges_objects_targetYaw
	local turning: number = IncludePRUltratypesH.TRUE

	targetYaw[1] = buffer.readi32(Buffer, Offset)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		targetYaw[1] = ObjectHelpers.cur_obj_reflect_move_angle_off_wall()
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_EDGE) then
		targetYaw[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)
	elseif obj_behaviors_2.obj_resolve_object_collisions(targetYaw) == 0 then
		turning = IncludePRUltratypesH.FALSE
	end

	buffer.writei32(Buffer, Offset, targetYaw[1])

	return turning
end

-- from src/game/obj_behaviors_2.c:obj_resolve_collisions_and_turn L607-615
function obj_behaviors_2.obj_resolve_collisions_and_turn(targetYaw: number, turnSpeed: number): number
	targetYaw = S16(TruncS32(targetYaw))
	turnSpeed = S16(TruncS32(turnSpeed))
	obj_behaviors_2.obj_resolve_object_collisions(nil)

	if ObjectHelpers.cur_obj_rotate_yaw_toward(targetYaw, turnSpeed) ~= 0 then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/obj_behaviors_2.c:obj_die_if_health_non_positive L617-642
function obj_behaviors_2.obj_die_if_health_non_positive()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) <= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oDeathSound) == 0 then
			ObjectHelpers.spawn_mist_particles_with_sound(IncludeSoundsH.SOUND_OBJ_DEFAULT_DEATH)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oDeathSound) > 0 then
			ObjectHelpers.spawn_mist_particles_with_sound(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDeathSound))
		else
			ObjectHelpers.spawn_mist_particles()
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins) < 0 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BLUE_COIN, BehaviorIds.bhvSpawnedBlueCoin)
		else
			ObjectHelpers.obj_spawn_loot_yellow_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20.0)
		end

		-- This doesn't do anything
		ObjectHelpers.obj_spawn_loot_yellow_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) < 0 then
			ObjectHelpers.cur_obj_hide()
			ObjectHelpers.cur_obj_become_intangible()
		else
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end
end

-- from src/game/obj_behaviors_2.c:obj_unused_die L644-647
function obj_behaviors_2.obj_unused_die()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 0)
	obj_behaviors_2.obj_die_if_health_non_positive()
end

-- from src/game/obj_behaviors_2.c:obj_set_knockback_action L649-667
function obj_behaviors_2.obj_set_knockback_action(attackType: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

	if attackType == InteractionH.ATTACK_KICK_OR_TRIP or attackType == InteractionH.ATTACK_FAST_ATTACK then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.OBJ_ACT_VERTICAL_KNOCKBACK)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.OBJ_ACT_HORIZONTAL_KNOCKBACK)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
	end

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.obj_angle_to_object(marioObj, o))
end

-- from src/game/obj_behaviors_2.c:obj_set_squished_action L669-672
function obj_behaviors_2.obj_set_squished_action()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_STOMPED)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.OBJ_ACT_SQUISHED)
end

-- from src/game/obj_behaviors_2.c:obj_die_if_above_lava_and_health_non_positive L674-693
function obj_behaviors_2.obj_die_if_above_lava_and_health_non_positive(): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_UNDERWATER_ON_GROUND) then
		const waterLevel: number = Registry.Members.src__engine__surface_collision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oBuoyancy)) > 0 or F32(waterLevel - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) < 150 then
			return IncludePRUltratypesH.FALSE
		end
	elseif not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ABOVE_LAVA) then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER) then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius) < 200 then
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DIVING_INTO_WATER)
			else
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DIVING_IN_WATER)
			end
		end

		return IncludePRUltratypesH.FALSE
	end

	obj_behaviors_2.obj_die_if_health_non_positive()

	return IncludePRUltratypesH.TRUE
end

-- from src/game/obj_behaviors_2.c:obj_handle_attacks L695-758
function obj_behaviors_2.obj_handle_attacks(hitbox: GroupsTypesHPlus3.ObjectHitbox, attackedMarioAction: number, attackHandlers: { number }): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, hitbox)

	if obj_behaviors_2.obj_die_if_above_lava_and_health_non_positive() ~= 0 then
		return 1
	elseif bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACKED_MARIO) then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= attackedMarioAction then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, attackedMarioAction)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		else
			const attackType: number = S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACK_MASK))
			const handler: number = attackHandlers[attackType]

			if handler == ObjBehaviors2H.ATTACK_HANDLER_DIE_IF_HEALTH_NON_POSITIVE then
				obj_behaviors_2.obj_die_if_health_non_positive()
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK then
				obj_behaviors_2.obj_set_knockback_action(attackType)
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SQUISHED then
				obj_behaviors_2.obj_set_squished_action()
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_KOOPA_LOSE_SHELL then
				Registry.Members.src__game__behaviors__koopa_inc.shelled_koopa_attack_handler(attackType)
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SET_SPEED_TO_ZERO then
				Registry.Members.src__game__behaviors__klepto_inc.obj_set_speed_to_zero()
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_WIGGLER_JUMPED_ON then
				Registry.Members.src__game__behaviors__wiggler_inc.wiggler_jumped_on_attack_handler()
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_HUGE_GOOMBA_WEAKLY_ATTACKED then
				Registry.Members.src__game__behaviors__goomba_inc.huge_goomba_weakly_attacked()
			elseif handler == ObjBehaviors2H.ATTACK_HANDLER_SQUISHED_WITH_BLUE_COIN then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, -1)
				obj_behaviors_2.obj_set_squished_action()
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			return attackType
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	return 0
end

-- from src/game/obj_behaviors_2.c:obj_act_knockback L760-775
function obj_behaviors_2.obj_act_knockback(baseScale: number)
	baseScale = F32(baseScale)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if o.header.gfx.animInfo.curAnim ~= nil then
		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	end

	-- Dies immediately if above lava
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER, IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL, IncludeObjectConstantsH.OBJ_MOVE_ABOVE_LAVA)) or (buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.OBJ_ACT_VERTICAL_KNOCKBACK and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 9) then
		obj_behaviors_2.obj_die_if_health_non_positive()
	end

	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/obj_behaviors_2.c:obj_act_squished L777-796
function obj_behaviors_2.obj_act_squished(baseScale: number)
	baseScale = F32(baseScale)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const targetScaleY = F32(baseScale * F32(0.3))

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if o.header.gfx.animInfo.curAnim ~= nil then
		ObjectHelpers.cur_obj_extend_animation_if_at_end()
	end

	buffer.writef32(Scratch.obj_act_squished_scale, 0, o.header.gfx.scale[2])
	const approached: number = obj_behaviors_2.approach_f32_ptr(Scratch.obj_act_squished_scale, 0, targetScaleY, F32(baseScale * F32(0.14)))
	o.header.gfx.scale[2] = buffer.readf32(Scratch.obj_act_squished_scale, 0)

	if approached ~= 0 then
		const scaleValue = F32(F32(baseScale * 2) - o.header.gfx.scale[2])
		o.header.gfx.scale[3] = scaleValue
		o.header.gfx.scale[1] = scaleValue

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
			obj_behaviors_2.obj_die_if_health_non_positive()
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/obj_behaviors_2.c:obj_update_standard_actions L798-817
function obj_behaviors_2.obj_update_standard_actions(scale: number): number
	scale = F32(scale)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) < 100 then
		return IncludePRUltratypesH.TRUE
	end

	ObjectHelpers.cur_obj_become_intangible()

	const action: number = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.OBJ_ACT_HORIZONTAL_KNOCKBACK or action == IncludeObjectConstantsH.OBJ_ACT_VERTICAL_KNOCKBACK then
		obj_behaviors_2.obj_act_knockback(scale)
	elseif action == IncludeObjectConstantsH.OBJ_ACT_SQUISHED then
		obj_behaviors_2.obj_act_squished(scale)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:obj_check_attacks L819-843
function obj_behaviors_2.obj_check_attacks(hitbox: GroupsTypesHPlus3.ObjectHitbox, attackedMarioAction: number): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, hitbox)

	if obj_behaviors_2.obj_die_if_above_lava_and_health_non_positive() ~= 0 then
		return 1
	elseif bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACKED_MARIO) then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= attackedMarioAction then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, attackedMarioAction)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		else
			const attackType: number = S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_ATTACK_MASK))

			obj_behaviors_2.obj_die_if_health_non_positive()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			return attackType
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

	return 0
end

-- from src/game/obj_behaviors_2.c:obj_move_for_one_second L845-856
function obj_behaviors_2.obj_move_for_one_second(endAction: number): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_extend_animation_if_at_end()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, endAction)
		return IncludePRUltratypesH.TRUE
	end

	ObjectHelpers.cur_obj_move_standard(-78)

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors_2.c:treat_far_home_as_mario L876-895
function obj_behaviors_2.treat_far_home_as_mario(threshold: number)
	threshold = F32(threshold)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	local dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	local dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	local dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	local distance = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

	if distance > threshold then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, SrcEngineMathUtil.atan2s(dz, dx))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, 25000.0)
	else
		const marioObj: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

		dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosX))
		dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY))
		dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosZ))
		distance = F32(math.sqrt(F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))))

		if distance > threshold then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, 20000.0)
		end
	end
end

-- from src/game/obj_behaviors_2.c:obj_spit_fire L938-949
function obj_behaviors_2.obj_spit_fire(relativePosX: number, relativePosY: number, relativePosZ: number, scale: number, model: number, startSpeed: number, endSpeed: number, movePitch: number)
	relativePosX = S16(TruncS32(relativePosX))
	relativePosY = S16(TruncS32(relativePosY))
	relativePosZ = S16(TruncS32(relativePosZ))
	scale = F32(scale)
	startSpeed = F32(startSpeed)
	endSpeed = F32(endSpeed)
	movePitch = S16(TruncS32(movePitch))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const obj: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative_with_scale(1, relativePosX, relativePosY, relativePosZ, scale, o, model, BehaviorIds.bhvSmallPiranhaFlame)

	if obj ~= nil then
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameStartSpeed, startSpeed)
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameEndSpeed, endSpeed)
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oSmallPiranhaFlameModel, model)
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAnglePitch, movePitch)
	end
end

return obj_behaviors_2
