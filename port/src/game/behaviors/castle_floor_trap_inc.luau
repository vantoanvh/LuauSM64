--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/castle_floor_trap.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const castle_floor_trap_inc = {}

Registry.Register("src__game__behaviors__castle_floor_trap_inc", castle_floor_trap_inc)

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_floor_trap_in_castle_loop L3-8
function castle_floor_trap_inc.bhv_floor_trap_in_castle_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_TRAP_TURN)))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_init L10-15
function castle_floor_trap_inc.bhv_castle_floor_trap_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.spawn_object_relative(0, -358, 0, 0, o, IncludeModelIdsH.MODEL_CASTLE_BOWSER_TRAP, BehaviorIds.bhvFloorTrapInCastle)
	const Sp2C = ObjectHelpers.spawn_object_relative(0, 358, 0, 0, o, IncludeModelIdsH.MODEL_CASTLE_BOWSER_TRAP, BehaviorIds.bhvFloorTrapInCastle)

	buffer.writei32(Sp2C.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(Sp2C.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_open_detect L17-27
function castle_floor_trap_inc.bhv_castle_floor_trap_open_detect()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_SPECIAL_EXIT_AIRBORNE or LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_SPECIAL_DEATH_EXIT then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0x400)

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_TRAP_TURN) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_open L29-41
function castle_floor_trap_inc.bhv_castle_floor_trap_open()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CASTLE_TRAP_OPEN)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) - 0x100))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll)))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) < -0x4000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -0x4000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_close_detect L43-47
function castle_floor_trap_inc.bhv_castle_floor_trap_close_detect()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_close L49-57
function castle_floor_trap_inc.bhv_castle_floor_trap_close()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x400))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_TRAP_TURN))))
	end
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_rotate L59-61
function castle_floor_trap_inc.bhv_castle_floor_trap_rotate()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -0x3C00)
end

-- from src/game/behaviors/castle_floor_trap.inc.c:bhv_castle_floor_trap_loop L63-83
function castle_floor_trap_inc.bhv_castle_floor_trap_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		castle_floor_trap_inc.bhv_castle_floor_trap_open_detect()
	elseif action == 1 then
		castle_floor_trap_inc.bhv_castle_floor_trap_open()
	elseif action == 2 then
		castle_floor_trap_inc.bhv_castle_floor_trap_close_detect()
	elseif action == 3 then
		castle_floor_trap_inc.bhv_castle_floor_trap_close()
	elseif action == 4 then
		castle_floor_trap_inc.bhv_castle_floor_trap_rotate()
	end
end

return castle_floor_trap_inc
