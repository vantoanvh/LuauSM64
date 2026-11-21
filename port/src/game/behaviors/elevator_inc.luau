--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/elevator.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/elevator.inc.c:data
const elevator_inc = {
	-- from src/game/behaviors/elevator.inc.c:sElevatorHeights L3-11
	sElevatorHeights = { -51, 0, 0, -461, 0, 0, -512, 0, 0, -2611, 0, 0, -2360, 0, 0, 214, 0, 0, -50, 1945, 1 },
}

Registry.Register("src__game__behaviors__elevator_inc", elevator_inc)

-- from src/game/behaviors/elevator.inc.c:elevator_starting_shake L13-16
function elevator_inc.elevator_starting_shake()
	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_POUND1)
	ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
end

-- from src/game/behaviors/elevator.inc.c:elevator_act_0 L18-39
function elevator_inc.elevator_act_0()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 2 then
		if mario.platform == o then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC) then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			end
		end
	elseif buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC) or buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8))
		if mario.platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4))
		if mario.platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/elevator.inc.c:elevator_act_1 L41-58
function elevator_inc.elevator_act_1()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR1)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
		elevator_inc.elevator_starting_shake()
	end
	ObjectHelpers.approach_f32_signed(o.rawData, IncludeObjectFieldsH.oVelY, 10, 2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 2 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		elseif buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	end
end

-- from src/game/behaviors/elevator.inc.c:elevator_act_2 L60-79
function elevator_inc.elevator_act_2()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR1)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
		elevator_inc.elevator_starting_shake()
	end
	ObjectHelpers.approach_f32_signed(o.rawData, IncludeObjectFieldsH.oVelY, -10, -2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100) == 2 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		elseif buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	end
end

-- from src/game/behaviors/elevator.inc.c:elevator_act_4 L81-90
function elevator_inc.elevator_act_4()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_METAL_POUND)
	end
	if ObjectHelpers.mario_is_in_air_action() == 0 and ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/elevator.inc.c:elevator_act_3 L92-101
function elevator_inc.elevator_act_3()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_METAL_POUND)
	end
	if ObjectHelpers.mario_is_in_air_action() == 0 and ObjectHelpers.cur_obj_is_mario_on_platform() == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/elevator.inc.c:bhv_elevator_init L103-116
function elevator_inc.bhv_elevator_init()
	const o = ObjectListProcessor.gCurrentObject

	const sp1C = elevator_inc.sElevatorHeights[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 3 + 3]
	if sp1C == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4, elevator_inc.sElevatorHeights[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 3 + 1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8)) / 2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100, ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvRRElevatorPlatform))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4, elevator_inc.sElevatorHeights[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 3 + 1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8, elevator_inc.sElevatorHeights[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 3 + 2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oElevatorUnkFC, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF4) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oElevatorUnkF8)) / 2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oElevatorUnk100, 2)
	end
end

-- from src/game/behaviors/elevator.inc.c:bhv_elevator_loop L126-128
function elevator_inc.bhv_elevator_loop()
	ObjectHelpers.cur_obj_call_action_function(elevator_inc.sElevatorActions)
end

-- from src/game/behaviors/elevator.inc.c:sElevatorActions L118-124
elevator_inc.sElevatorActions = {
	elevator_inc.elevator_act_0,
	elevator_inc.elevator_act_1,
	elevator_inc.elevator_act_2,
	elevator_inc.elevator_act_3,
	elevator_inc.elevator_act_4,
}

return elevator_inc
