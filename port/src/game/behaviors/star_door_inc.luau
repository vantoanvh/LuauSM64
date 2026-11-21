--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/star_door.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const star_door_inc = {}

Registry.Register("src__game__behaviors__star_door_inc", star_door_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/star_door.inc.c:star_door_update_pos L3-8
function star_door_inc.star_door_update_pos()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oLeftVel) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oLeftVel) * -SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
end

-- from src/game/behaviors/star_door.inc.c:bhv_star_door_loop L10-65
function star_door_inc.bhv_star_door_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp18 = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvStarDoor) :: GroupsTypesHPlus3.Object?

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		ObjectHelpers.cur_obj_become_tangible()

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bor(InteractionH.INT_STATUS_UNK16, InteractionH.INT_STATUS_UNK17)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end

		if Sp18 ~= nil and buffer.readi32(Sp18.rawData, IncludeObjectFieldsH.oAction) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) >= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_STAR_DOOR_OPEN)
		end

		ObjectHelpers.cur_obj_become_intangible()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oLeftVel, -8.0)
		star_door_inc.star_door_update_pos()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 and S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) >= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_STAR_DOOR_CLOSE)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oLeftVel, 8.0)
		star_door_inc.star_door_update_pos()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

return star_door_inc
