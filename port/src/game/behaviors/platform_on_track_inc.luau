--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/platform_on_track.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const Memory = require("../memory")

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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/platform_on_track_inc.luau:scratch
const Scratch = {
	platform_on_track_act_move_along_track_speed = { 0 },
}

-- from src/game/behaviors/platform_on_track.inc.c:data
const platform_on_track_inc = {
	-- from src/game/behaviors/platform_on_track.inc.c:sPlatformOnTrackCollisionModels L11-16
	sPlatformOnTrackCollisionModels = {
		0x07028E50, -- rr_seg7_collision_07029038 (ROM layout)
		0x070163F8,
		0x0800D710,
		0x070157E0,
	},
	-- from src/game/behaviors/platform_on_track.inc.c:sPlatformOnTrackPaths L21-31
	sPlatformOnTrackPaths = {
		0x0702EA80, -- rr_seg7_trajectory_0702EC3C (ROM layout)
		0x0702EB04, -- rr_seg7_trajectory_0702ECC0 (ROM layout)
		0x0701669C,
		0x070159AC,
		0x0702B86C,
		0x070284DC, -- lll_seg7_trajectory_0702856C (ROM layout)
		0x070285D0, -- lll_seg7_trajectory_07028660 (ROM layout)
		0x0702EBE0, -- rr_seg7_trajectory_0702ED9C (ROM layout)
		0x0702ED24, -- rr_seg7_trajectory_0702EEE0 (ROM layout)
	},
}

Registry.Register("src__game__behaviors__platform_on_track_inc", platform_on_track_inc)

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_reset L36-40
function platform_on_track_inc.platform_on_track_reset()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_INIT)
	-- This will cause the track balls to all despawn
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex) + 99)
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_mario_not_on_platform L46-54
function platform_on_track_inc.platform_on_track_mario_not_on_platform()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_DONT_DISAPPEAR) then
		-- Once oTimer reaches 150, blink 40 times
		if ObjectHelpers.cur_obj_wait_then_blink(150, 40) ~= 0 then
			platform_on_track_inc.platform_on_track_reset()
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:bhv_platform_on_track_init L59-79
function platform_on_track_inc.bhv_platform_on_track_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		const pathIndex: number = bit32.band(U16(bit32.arshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_MASK_PATH)

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackType, bit32.rshift(bit32.band(U16(bit32.arshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_MASK_TYPE), 4))
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackType) - IncludeObjectConstantsH.PLATFORM_ON_TRACK_TYPE_SKI_LIFT))
		o.collisionData = Memory.segmented_to_virtual(platform_on_track_inc.sPlatformOnTrackCollisionModels[buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackType) + 1])
		o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackStartWaypoint + 1] = Memory.segmented_to_virtual(platform_on_track_inc.sPlatformOnTrackPaths[pathIndex + 1])
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotHMC, S16(pathIndex - 4))
		-- Weird? (marked to do in the source)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackType) == IncludeObjectConstantsH.PLATFORM_ON_TRACK_TYPE_CHECKERED then
			o.header.gfx.scale[2] = 2.0
		end
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_act_init L85-111
function platform_on_track_inc.platform_on_track_act_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const startWaypoint = o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackStartWaypoint + 1] :: number

	o.ptrData[IncludeObjectFieldsH.oPlatformOnTrackPrevWaypoint + 1] = startWaypoint
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex, 0)

	const pos = startWaypoint + 2

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, Rom.ReadS16(pos))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, Rom.ReadS16(pos + 2))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, Rom.ReadS16(pos + 4))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackDistMovedSinceLastBall, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackWasStoodOn, 0)

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
	end

	-- Spawn track balls
	for Index = 1, 5 do
		ObjBehaviors2.platform_on_track_update_pos_or_spawn_ball(Index, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_WAIT_FOR_MARIO)
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_act_wait_for_mario L116-128
function platform_on_track_inc.platform_on_track_act_wait_for_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if gMario.platform == o then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_MOVE_ALONG_TRACK)
		end
	else
		if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
			platform_on_track_inc.platform_on_track_reset()
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_act_move_along_track L134-221
function platform_on_track_inc.platform_on_track_act_move_along_track()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift) == 0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR3)
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotHMC) == 0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR1)
	end

	-- Fall after reaching the last waypoint if desired
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) == ObjectHelpersH.WAYPOINT_FLAGS_END and not bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16),IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_RETURN_TO_START) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_FALL)
	else
		-- The ski lift should pause or stop after reaching a special waypoint
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) ~= 0 and buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift) == 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) == ObjectHelpersH.WAYPOINT_FLAGS_END or buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) == ObjectHelpersH.WAYPOINT_FLAGS_PLATFORM_ON_TRACK_PAUSE then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNKNOWN4_LOWPRIO)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPrevWaypointFlags) == ObjectHelpersH.WAYPOINT_FLAGS_END then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_INIT)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_PAUSE_BRIEFLY)
				end
			end
		else
			-- The ski lift accelerates, while the others instantly start
			if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift) == 0 then
				ObjBehaviors2.obj_forward_vel_approach(10.0, F32(0.1))
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			end

			-- Spawn a new track ball if necessary
			const approached = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackDistMovedSinceLastBall, 300.0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

			if approached ~= 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackDistMovedSinceLastBall, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackDistMovedSinceLastBall) - 300.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex, U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex) + 1))
				ObjBehaviors2.platform_on_track_update_pos_or_spawn_ball(5, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
			end
		end

		ObjBehaviors2.platform_on_track_update_pos_or_spawn_ball(0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackPitch))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackYaw))

		-- Turn face yaw and compute yaw vel
		--! Both oAngleVelYaw and oAngleVelRoll aren't reset until the platform starts moving again
		if not bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16),IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_DONT_TURN_YAW) then
			const targetFaceYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000)
			local yawSpeed = S16(ObjectHelpers.abs_angle_diff(targetFaceYaw, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) // 20)
			const initialAngle = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
			Scratch.platform_on_track_act_move_along_track_speed[1] = yawSpeed
			ObjBehaviors2.clamp_s16(Scratch.platform_on_track_act_move_along_track_speed, 100, 500)
			yawSpeed = Scratch.platform_on_track_act_move_along_track_speed[1]
			ObjBehaviors2.obj_face_yaw_approach(targetFaceYaw, yawSpeed)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) - initialAngle)
		end

		-- Turn face roll and compute roll vel
		if bit32.btest(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16),IncludeObjectConstantsH.PLATFORM_ON_TRACK_BP_DONT_TURN_ROLL) then
			local rollSpeed = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))) // 20)
			const initialAngle = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
			Scratch.platform_on_track_act_move_along_track_speed[1] = rollSpeed
			ObjBehaviors2.clamp_s16(Scratch.platform_on_track_act_move_along_track_speed, 100, 500)
			rollSpeed = Scratch.platform_on_track_act_move_along_track_speed[1]
			--! If the platform is moving counterclockwise upward or clockwise downward, this will be backward
			ObjBehaviors2.obj_face_roll_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), rollSpeed)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)) - initialAngle)
		end
	end

	if gMario.platform ~= o then
		platform_on_track_inc.platform_on_track_mario_not_on_platform()
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_act_pause_briefly L226-230
function platform_on_track_inc.platform_on_track_act_pause_briefly()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_MOVE_ALONG_TRACK)
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_act_fall L236-245
function platform_on_track_inc.platform_on_track_act_fall()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_move_using_vel_and_gravity()

	if gMario.platform ~= o then
		platform_on_track_inc.platform_on_track_mario_not_on_platform()
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		--! Doesn't ensure visibility
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:platform_on_track_rock_ski_lift L250-270
function platform_on_track_inc.platform_on_track_rock_ski_lift()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local targetRoll = 0

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackSkiLiftRollVel)))

	-- Tilt away from the moving direction and toward mario
	if gMario.platform == o then
		targetRoll = TruncS32(F32(F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) * -50.0) + TruncS32(F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))) * -4.0))))
	end

	ObjBehaviors2.oscillate_toward(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, o.rawData, IncludeObjectFieldsH.oPlatformOnTrackSkiLiftRollVel, targetRoll, 5.0, 6.0, 1.5)
	ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackSkiLiftRollVel, -100.0, 100.0)
end

-- from src/game/behaviors/platform_on_track.inc.c:bhv_platform_on_track_update L275-305
function platform_on_track_inc.bhv_platform_on_track_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_INIT then
		platform_on_track_inc.platform_on_track_act_init()
	elseif action == IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_WAIT_FOR_MARIO then
		platform_on_track_inc.platform_on_track_act_wait_for_mario()
	elseif action == IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_MOVE_ALONG_TRACK then
		platform_on_track_inc.platform_on_track_act_move_along_track()
	elseif action == IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_PAUSE_BRIEFLY then
		platform_on_track_inc.platform_on_track_act_pause_briefly()
	elseif action == IncludeObjectConstantsH.PLATFORM_ON_TRACK_ACT_FALL then
		platform_on_track_inc.platform_on_track_act_fall()
	end

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackIsNotSkiLift) == 0 then
		platform_on_track_inc.platform_on_track_rock_ski_lift()
	elseif buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackType) == IncludeObjectConstantsH.PLATFORM_ON_TRACK_TYPE_CARPET then
		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackWasStoodOn) == 0 and gMario.platform == o then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackOffsetY, -8.0)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackWasStoodOn, IncludePRUltratypesH.TRUE)
		end

		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackOffsetY, 0.0, 0.5)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformOnTrackOffsetY))
	end
end

-- from src/game/behaviors/platform_on_track.inc.c:bhv_track_ball_update L310-317
function platform_on_track_inc.bhv_track_ball_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	-- Despawn after the elevator passes this ball
	const relativeIndex = S16(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)) - S16(buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPlatformOnTrackBaseBallIndex)) - 1)

	if relativeIndex < 1 or relativeIndex > 5 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return platform_on_track_inc
