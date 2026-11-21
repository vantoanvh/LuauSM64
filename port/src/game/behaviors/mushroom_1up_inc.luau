--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/mushroom_1up.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const LevelUpdate = require("../level_update")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const mushroom_1up_inc = {}

Registry.Register("src__game__behaviors__mushroom_1up_inc", mushroom_1up_inc)

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

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_interact L3-14
function mushroom_1up_inc.bhv_1up_interact()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_COLLECT_1UP, Audio.gGlobalSoundSource)
		LevelUpdate.gMarioState.numLives = S8(LevelUpdate.gMarioState.numLives + 1)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_common_init L16-21
function mushroom_1up_inc.bhv_1up_common_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, -0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.0)
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_init L23-34
function mushroom_1up_inc.bhv_1up_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	mushroom_1up_inc.bhv_1up_common_init()
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.ONE_UP_BP_BEAT_BITDW_BOWSER then
		if not bit32.btest(SaveFile.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_1, SaveFileH.SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)) then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.ONE_UP_BP_BEAT_BITFS_BOWSER then
		if not bit32.btest(SaveFile.save_file_get_flags(), bit32.bor(SaveFileH.SAVE_FLAG_HAVE_KEY_2, SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:one_up_loop_in_air L36-45
function mushroom_1up_inc.one_up_loop_in_air()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 5 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, -0x1000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) * 30.0) + 2.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) * 30.0))
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:pole_1up_move_towards_mario L47-60
function mushroom_1up_inc.pole_1up_move_towards_mario()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const sp34 = F32(gMario.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const sp30 = F32(F32(gMario.header.gfx.pos[2] + 120.0) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	const sp2C = F32(gMario.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const sp2A = S16(SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(SrcEngineMathUtilH.sqr(sp34) + SrcEngineMathUtilH.sqr(sp2C)))), sp30))

	ObjectHelpers.obj_turn_toward_object(o, gMario, 16, 0x1000)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), sp2A, 0x1000))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) * 30.0))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) * 30.0)

	mushroom_1up_inc.bhv_1up_interact()
end

-- from src/game/behaviors/mushroom_1up.inc.c:one_up_move_away_from_mario L62-75
function mushroom_1up_inc.one_up_move_away_from_mario(collisionFlags: number)
	collisionFlags = S16(TruncS32(collisionFlags))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 8.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000)
	mushroom_1up_inc.bhv_1up_interact()

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_HIT_WALL) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 3000) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_walking_loop L77-114
function mushroom_1up_inc.bhv_1up_walking_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors.object_step()
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 17 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_1UP_APPEAR, Audio.gGlobalSoundSource)
		end

		mushroom_1up_inc.one_up_loop_in_air()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 37 then
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 2.0)
		end
	elseif action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 300 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end

		mushroom_1up_inc.bhv_1up_interact()
	elseif action == 2 then
		ObjBehaviors.obj_flicker_and_disappear(o, 30)
		mushroom_1up_inc.bhv_1up_interact()
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_running_away_loop L116-150
function mushroom_1up_inc.bhv_1up_running_away_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const collisionFlags = S16(ObjBehaviors.object_step())
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 17 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_1UP_APPEAR, Audio.gGlobalSoundSource)
		end

		mushroom_1up_inc.one_up_loop_in_air()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 37 then
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 8.0)
		end
	elseif action == 1 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		mushroom_1up_inc.one_up_move_away_from_mario(collisionFlags)
	elseif action == 2 then
		ObjBehaviors.obj_flicker_and_disappear(o, 30)
		mushroom_1up_inc.bhv_1up_interact()
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/mushroom_1up.inc.c:sliding_1up_move L152-169
function mushroom_1up_inc.sliding_1up_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) + 25.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 0.98)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 40.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 5000) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_sliding_loop L171-192
function mushroom_1up_inc.bhv_1up_sliding_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		ObjBehaviors.set_object_visibility(o, 3000)
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		mushroom_1up_inc.sliding_1up_move()
	elseif action == 2 then
		ObjBehaviors.obj_flicker_and_disappear(o, 30)
		mushroom_1up_inc.bhv_1up_interact()
	end

	mushroom_1up_inc.bhv_1up_interact()
	ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_loop L194-197
function mushroom_1up_inc.bhv_1up_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	mushroom_1up_inc.bhv_1up_interact()
	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_jump_on_approach_loop L199-224
function mushroom_1up_inc.bhv_1up_jump_on_approach_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		const collisionFlags = S16(ObjBehaviors.object_step())
		mushroom_1up_inc.one_up_move_away_from_mario(collisionFlags)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
	elseif action == 2 then
		ObjBehaviors.object_step()
		mushroom_1up_inc.bhv_1up_interact()
		ObjBehaviors.obj_flicker_and_disappear(o, 30)
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_hidden_loop L226-267
function mushroom_1up_inc.bhv_1up_hidden_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_1UP_APPEAR, Audio.gGlobalSoundSource)
		end
	elseif action == 1 then
		const collisionFlags = S16(ObjBehaviors.object_step())
		mushroom_1up_inc.one_up_move_away_from_mario(collisionFlags)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
	elseif action == 2 then
		ObjBehaviors.object_step()
		mushroom_1up_inc.bhv_1up_interact()
		ObjBehaviors.obj_flicker_and_disappear(o, 30)
	elseif action == 3 then
		ObjBehaviors.object_step()
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 17 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		end

		mushroom_1up_inc.one_up_loop_in_air()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 37 then
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 8.0)
		end
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_hidden_trigger_loop L269-278
function mushroom_1up_inc.bhv_1up_hidden_trigger_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		const hidden1Up: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHidden1Up)
		if hidden1Up ~= nil then
			buffer.writei32(hidden1Up.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers, buffer.readi32(hidden1Up.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers) + 1)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_hidden_in_pole_loop L280-314
function mushroom_1up_inc.bhv_1up_hidden_in_pole_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_1UP_APPEAR, Audio.gGlobalSoundSource)
		end
	elseif action == 1 then
		mushroom_1up_inc.pole_1up_move_towards_mario()
		ObjBehaviors.object_step()
	elseif action == 3 then
		ObjBehaviors.object_step()
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 17 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		end

		mushroom_1up_inc.one_up_loop_in_air()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 37 then
			ObjectHelpers.cur_obj_become_tangible()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
		end
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_hidden_in_pole_trigger_loop L316-325
function mushroom_1up_inc.bhv_1up_hidden_in_pole_trigger_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		const hidden1Up: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHidden1UpInPole)
		if hidden1Up ~= nil then
			buffer.writei32(hidden1Up.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers, buffer.readi32(hidden1Up.rawData, IncludeObjectFieldsH.oHidden1UpNumTouchedTriggers) + 1)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/mushroom_1up.inc.c:bhv_1up_hidden_in_pole_spawner_loop L327-337
function mushroom_1up_inc.bhv_1up_hidden_in_pole_spawner_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 700) ~= 0 then
		ObjectHelpers.spawn_object_relative(2, 0, 50, 0, o, IncludeModelIdsH.MODEL_1UP, BehaviorIds.bhvHidden1UpInPole)
		for Index = 0, 1 do
			ObjectHelpers.spawn_object_relative(0, 0, S16(Index * -200), 0, o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvHidden1UpInPoleTrigger)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return mushroom_1up_inc
