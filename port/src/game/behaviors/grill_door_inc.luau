--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/grill_door.inc.c.
]]

const SegmentSymbols = require("../../rom/segment_symbols")
const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const Audio = require("../../rom/audio_recorder")

-- from src/game/behaviors/grill_door.inc.c:OpenableGrill
export type OpenableGrill = {
	halfWidth: number,
	modelID: number,
	collision: { number }?,
}

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/grill_door.inc.c:data
const grill_door_inc = {
	-- from src/game/behaviors/grill_door.inc.c:gOpenableGrills L9-12
	gOpenableGrills = {
		{
			halfWidth = 320,
			modelID = IncludeModelIdsH.MODEL_BOB_BARS_GRILLS,
			collision = SegmentSymbols.bob_seg7_collision_gate,
		},
		{
			halfWidth = 410,
			modelID = IncludeModelIdsH.MODEL_HMC_RED_GRILLS,
			collision = 0x0702B65C,
		},
	},
}

Registry.Register("src__game__behaviors__grill_door_inc", grill_door_inc)

-- from src/game/behaviors/grill_door.inc.c:OpenableGrill (zero-filled constructor)
function grill_door_inc.new_OpenableGrill(): OpenableGrill
	return { halfWidth = 0, modelID = 0, collision = nil } :: OpenableGrill
end

-- from src/game/behaviors/grill_door.inc.c:bhv_openable_cage_door_loop L14-26
function grill_door_inc.bhv_openable_cage_door_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

		if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oOpenableGrillUnk88) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 64 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 0x100))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	end
end

-- from src/game/behaviors/grill_door.inc.c:bhv_openable_grill_loop L28-72
function grill_door_inc.bhv_openable_grill_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		const grillIdx = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)
		local obj = ObjectHelpers.spawn_object_relative(-1, grill_door_inc.gOpenableGrills[grillIdx + 1].halfWidth, 0, 0, o, grill_door_inc.gOpenableGrills[grillIdx + 1].modelID, BehaviorIds.bhvOpenableCageDoor)

		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
		ObjectHelpers.obj_set_collision_data(obj, grill_door_inc.gOpenableGrills[grillIdx + 1].collision)

		obj = ObjectHelpers.spawn_object_relative(1, S16(-grill_door_inc.gOpenableGrills[grillIdx + 1].halfWidth), 0, 0, o, grill_door_inc.gOpenableGrills[grillIdx + 1].modelID, BehaviorIds.bhvOpenableCageDoor)
		ObjectHelpers.obj_set_collision_data(obj, grill_door_inc.gOpenableGrills[grillIdx + 1].collision)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
	elseif action == 1 then
		const nearestSwitch: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvFloorSwitchGrills)

		o.ptrData[IncludeObjectFieldsH.oOpenableGrillPurpleSwitch + 1] = nearestSwitch

		if nearestSwitch ~= nil then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 2 then
		const obj = o.ptrData[IncludeObjectFieldsH.oOpenableGrillPurpleSwitch + 1] :: GroupsTypesHPlus3.Object

		if buffer.readi32(obj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpenableGrillUnk88, 2)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CAGE_OPEN)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.OPENABLE_GRILL_BP_BOB then
				Audio.play_puzzle_jingle()
			end
		end
	elseif action == 3 then
		-- Nothing to do.
	end
end

return grill_door_inc
