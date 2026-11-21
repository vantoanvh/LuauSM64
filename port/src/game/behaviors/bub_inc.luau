--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bub.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const bub_inc = {}

Registry.Register("src__game__behaviors__bub_inc", bub_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/bub.inc.c:bub_spawner_act_0 L7-16
function bub_inc.bub_spawner_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const count = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBirdChirpChirpUnkF4)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
		for i = 0, count - 1 do
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BUB, BehaviorIds.bhvBub)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/bub.inc.c:bub_spawner_act_1 L18-22
function bub_inc.bub_spawner_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if F32(buffer.readf32(marioObject.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) > 2000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/bub.inc.c:bub_spawner_act_2 L24-26
function bub_inc.bub_spawner_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
end

-- from src/game/behaviors/bub.inc.c:bub_spawner_act_3 L28-30
function bub_inc.bub_spawner_act_3()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
end

-- from src/game/behaviors/bub.inc.c:bhv_bub_spawner_loop L39-41
function bub_inc.bhv_bub_spawner_loop()
	ObjectHelpers.cur_obj_call_action_function(bub_inc.sBirdChirpChirpActions)
end

-- from src/game/behaviors/bub.inc.c:bub_move_vertically L43-50
function bub_inc.bub_move_vertically(a0: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const Sp1C = buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY)

	if F32(F32(Sp1C - 100.0) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnk104)) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(F32(Sp1C + 1000.0) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnk104)) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, ObjectHelpers.approach_f32_symmetric(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF8), a0))
	else
		-- Empty in the C source.
	end
end

-- from src/game/behaviors/bub.inc.c:bub_act_0 L52-56
function bub_inc.bub_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkFC, SrcEngineBehaviorScript.random_float() * 100.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnk104, SrcEngineBehaviorScript.random_float() * 300.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
end

-- from src/game/behaviors/bub.inc.c:bub_act_1 L58-101
function bub_inc.bub_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 2) + 2)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnk108, SrcEngineBehaviorScript.random_float())
	end

	local dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF4) - 50.0) then
		if dy < 0.0 then
			dy = F32(0.0 - dy)
		end

		if dy < 500.0 then
			bub_inc.bub_move_vertically(1)
		else
			bub_inc.bub_move_vertically(4)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF4) - 50.0)

		if dy > 300.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 1.0)
		end
	end

	if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 800.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
	end

	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x100)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 200.0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnk108) < 0.5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/bub.inc.c:bub_act_2 L103-151
function bub_inc.bub_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 20 then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvSmallParticleSnow)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_MOVING_WATER)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) == 0.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 6.0)
	end

	local dy = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF4) - 50.0) then
		if dy < 0.0 then
			dy = F32(0.0 - dy)
		end

		if dy < 500.0 then
			bub_inc.bub_move_vertically(2)
		else
			bub_inc.bub_move_vertically(4)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF4) - 50.0)

		if dy > 300.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 1.0)
		end
	end

	if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 800.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
	end

	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x8000), 0x400)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 200 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 600.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/bub.inc.c:bhv_bub_loop L159-171
function bub_inc.bhv_bub_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF4, SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkF8, buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheepCheepUnkFC))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 30.0)

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(bub_inc.sCheepCheepActions)
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == 2 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/bub.inc.c:sBirdChirpChirpActions L32-37
bub_inc.sBirdChirpChirpActions = {
	bub_inc.bub_spawner_act_0,
	bub_inc.bub_spawner_act_1,
	bub_inc.bub_spawner_act_2,
	bub_inc.bub_spawner_act_3,
}

-- from src/game/behaviors/bub.inc.c:sCheepCheepActions L153-157
bub_inc.sCheepCheepActions = { bub_inc.bub_act_0, bub_inc.bub_act_1, bub_inc.bub_act_2 }

return bub_inc
