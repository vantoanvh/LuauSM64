--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowling_ball.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const Camera = require("../camera")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")
const Memory = require("../memory")
const Rom = require("../../rom/rom")
const SegmentSymbols = require("../../rom/segment_symbols")

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

-- from src/game/behaviors/bowling_ball_inc.luau:scratch
const Scratch = {
	bhv_bob_pit_bowling_ball_loop_sp1c = {} :: { SrcEngineSurfaceCollisionH.FloorGeometry? },
}

-- from src/game/behaviors/bowling_ball.inc.c:data
const bowling_ball_inc = {
	-- from src/game/behaviors/bowling_ball.inc.c:sBowlingBallHitbox L3-13
	sBowlingBallHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 0,
		radius = 100,
		height = 150,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
	-- from src/game/behaviors/bowling_ball.inc.c:sTHIHugeMetalBallTraj L15-27
	sTHIHugeMetalBallTraj = {
		0, -4786, 101, -2166,
		1, -5000, 81, -2753,
		2, -5040, 33, -3846,
		3, -4966, 38, -4966,
		4, -4013, -259, -4893,
		5, -2573, -1019, -4780,
		6, -1053, -1399, -4806,
		7, 760, -1637, -4833,
		8, 2866, -2047, -4886,
		9, 3386, -6546, -4833,
		-1,
	},
	-- from src/game/behaviors/bowling_ball.inc.c:sTHITinyMetalBallTraj L29-40
	sTHITinyMetalBallTraj = {
		0, -1476, 29, -680,
		1, -1492, 14, -1072,
		2, -1500, 3, -1331,
		3, -1374, -17, -1527,
		4, -1178, -83, -1496,
		5, -292, -424, -1425,
		6, 250, -491, -1433,
		7, 862, -613, -1449,
		8, 1058, -1960, -1449,
		-1,
	},
}

Registry.Register("src__game__behaviors__bowling_ball_inc", bowling_ball_inc)

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bowling_ball_init L42-46
function bowling_ball_inc.bhv_bowling_ball_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)
end

-- from src/game/behaviors/bowling_ball.inc.c:bowling_ball_set_hitbox L48-54
function bowling_ball_inc.bowling_ball_set_hitbox()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, bowling_ball_inc.sBowlingBallHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bowling_ball_set_waypoints L56-78
function bowling_ball_inc.bowling_ball_set_waypoints()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bhvParams2ndByte: number = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if bhvParams2ndByte == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_UPPER then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.bob_seg7_metal_ball_path0)
	elseif bhvParams2ndByte == IncludeObjectConstantsH.BBALL_BP_STYPE_TTM then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(0x070170A0)
	elseif bhvParams2ndByte == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_LOWER then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.bob_seg7_metal_ball_path1)
	elseif bhvParams2ndByte == IncludeObjectConstantsH.BBALL_BP_STYPE_THI_LARGE then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Rom.StaticS16Array("sTHIHugeMetalBallTraj", bowling_ball_inc.sTHIHugeMetalBallTraj)
	elseif bhvParams2ndByte == IncludeObjectConstantsH.BBALL_BP_STYPE_THI_SMALL then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Rom.StaticS16Array("sTHITinyMetalBallTraj", bowling_ball_inc.sTHITinyMetalBallTraj)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bowling_ball_roll_loop L80-113
function bowling_ball_inc.bhv_bowling_ball_roll_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local followStatus = 0

	bowling_ball_inc.bowling_ball_set_waypoints()
	const collisionFlags = S16(ObjBehaviors.object_step())
	-- Uninitialized parameter, but the parameter is unused in the called function
	followStatus = ObjectHelpers.cur_obj_follow_path(followStatus)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowlingBallTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowlingBallTargetYaw)), 0x400))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 70.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 70.0)
	end

	bowling_ball_inc.bowling_ball_set_hitbox()

	if followStatus == ObjectHelpersH.PATH_REACHED_END then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 7000) ~= IncludePRUltratypesH.FALSE then
			ObjectHelpers.spawn_mist_particles()
			BehaviorActions.spawn_mist_particles_variable(0, 0, 92.0)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 5.0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_POUND1_LOWPRIO)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bowling_ball_initialize_loop L115-151
function bowling_ball_inc.bhv_bowling_ball_initialize_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	bowling_ball_inc.bowling_ball_set_waypoints()
	-- Uninitialized parameter, but the parameter is unused in the called function
	ObjectHelpers.cur_obj_follow_path(0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw))

	const bhvParams = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_UPPER then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_TTM then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_LOWER then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_THI_LARGE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 25.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_THI_SMALL then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
		ObjectHelpers.cur_obj_scale(F32(0.3))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 39.0)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bowling_ball_loop L153-170
function bowling_ball_inc.bhv_bowling_ball_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BBALL_ACT_INITIALIZE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BBALL_ACT_ROLL)
		bowling_ball_inc.bhv_bowling_ball_initialize_loop()
	elseif action == IncludeObjectConstantsH.BBALL_ACT_ROLL then
		bowling_ball_inc.bhv_bowling_ball_roll_loop()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.BBALL_BP_STYPE_THI_SMALL then
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_BOWLING_BALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	end

	ObjBehaviors.set_object_visibility(o, 4000)
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_generic_bowling_ball_spawner_init L172-189
function bowling_ball_inc.bhv_generic_bowling_ball_spawner_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bhvParams = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_UPPER then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerMaxSpawnDist, 7000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerSpawnOdds, 2.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_TTM then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerMaxSpawnDist, 8000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerSpawnOdds, 1.0)
	elseif bhvParams == IncludeObjectConstantsH.BBALL_BP_STYPE_BOB_LOWER then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerMaxSpawnDist, 6000.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerSpawnOdds, 2.0)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_generic_bowling_ball_spawner_loop L191-208
function bowling_ball_inc.bhv_generic_bowling_ball_spawner_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 256 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) ~= IncludePRUltratypesH.FALSE or buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < marioObj.header.gfx.pos[2] then
		return
	end

	if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), buffer.readi32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerPeriodMinus1)) == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), buffer.readf32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerMaxSpawnDist)) ~= IncludePRUltratypesH.FALSE and TruncS32(F32(SrcEngineBehaviorScript.random_float() * buffer.readf32(o.rawData, IncludeObjectFieldsH.oBBallSpawnerSpawnOdds))) == 0 then
			const bowlingBall = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWLING_BALL, BehaviorIds.bhvBowlingBall)
			buffer.writei32(bowlingBall.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		end
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_thi_bowling_ball_spawner_loop L210-227
function bowling_ball_inc.bhv_thi_bowling_ball_spawner_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 256 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 800) ~= IncludePRUltratypesH.FALSE or buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < marioObj.header.gfx.pos[2] then
		return
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) % 64 == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 12000) ~= IncludePRUltratypesH.FALSE and TruncS32(F32(SrcEngineBehaviorScript.random_float() * 1.5)) == 0 then
			const bowlingBall = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWLING_BALL, BehaviorIds.bhvBowlingBall)
			buffer.writei32(bowlingBall.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		end
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bob_pit_bowling_ball_init L229-233
function bowling_ball_inc.bhv_bob_pit_bowling_ball_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 12.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_bob_pit_bowling_ball_loop L235-248
function bowling_ball_inc.bhv_bob_pit_bowling_ball_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors.object_step()
	SrcEngineSurfaceCollision.find_floor_height_and_data(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_bob_pit_bowling_ball_loop_sp1c)

	const sp1c = Scratch.bhv_bob_pit_bowling_ball_loop_sp1c[1] :: SrcEngineSurfaceCollisionH.FloorGeometry

	if sp1c.normalX == 0 and sp1c.normalZ == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 28.0)
	end

	bowling_ball_inc.bowling_ball_set_hitbox()
	Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_BOWLING_BALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_UNKNOWN2)
	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_free_bowling_ball_init L250-259
function bowling_ball_inc.bhv_free_bowling_ball_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_free_bowling_ball_roll_loop L261-285
function bowling_ball_inc.bhv_free_bowling_ball_roll_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const collisionFlags = S16(ObjBehaviors.object_step())

	bowling_ball_inc.bowling_ball_set_hitbox()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 10.0 then
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_BOWLING_BALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_UNKNOWN2)
	end

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) and not bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_POUND1_LOWPRIO)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 6000) == IncludePRUltratypesH.FALSE then
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		ObjectHelpers.cur_obj_become_intangible()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
		bowling_ball_inc.bhv_free_bowling_ball_init()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FREE_BBALL_ACT_RESET)
	end
end

-- from src/game/behaviors/bowling_ball.inc.c:bhv_free_bowling_ball_loop L287-309
function bowling_ball_inc.bhv_free_bowling_ball_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 5.5)

	if action == IncludeObjectConstantsH.FREE_BBALL_ACT_IDLE then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 3000) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FREE_BBALL_ACT_ROLL)
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
			ObjectHelpers.cur_obj_become_tangible()
		end
	elseif action == IncludeObjectConstantsH.FREE_BBALL_ACT_ROLL then
		bowling_ball_inc.bhv_free_bowling_ball_roll_loop()
	elseif action == IncludeObjectConstantsH.FREE_BBALL_ACT_RESET then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 5000) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FREE_BBALL_ACT_IDLE)
		end
	end
end

return bowling_ball_inc
