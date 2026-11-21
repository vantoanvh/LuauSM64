--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pyramid_elevator.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const pyramid_elevator_inc = {}

Registry.Register("src__game__behaviors__pyramid_elevator_inc", pyramid_elevator_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/pyramid_elevator.inc.c:bhv_pyramid_elevator_init L13-21
function pyramid_elevator_inc.bhv_pyramid_elevator_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	for Index = 0, 10 - 1 do
		const ball = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_TRAJECTORY_MARKER_BALL, BehaviorIds.bhvPyramidElevatorTrajectoryMarkerBall)
		buffer.writef32(ball.rawData, IncludeObjectFieldsH.oPosY, 4600 - Index * 460)
	end
end

-- from src/game/behaviors/pyramid_elevator.inc.c:bhv_pyramid_elevator_loop L23-71
function pyramid_elevator_inc.bhv_pyramid_elevator_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_IDLE then
		if gMario.platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_START_MOVING)
		end
	elseif action == IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_START_MOVING then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 10.0))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 8 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_CONSTANT_VELOCITY)
		end
	elseif action == IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_CONSTANT_VELOCITY then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -10.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < 128.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 128.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_AT_BOTTOM)
		end
	elseif action == IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_AT_BOTTOM then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 10.0) + 128.0)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 8 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 128.0)
		end
	end
end

-- from src/game/behaviors/pyramid_elevator.inc.c:bhv_pyramid_elevator_trajectory_marker_ball_loop L77-88
function pyramid_elevator_inc.bhv_pyramid_elevator_trajectory_marker_ball_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_scale(F32(0.15))
	const elevator: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvPyramidElevator)

	if elevator ~= nil then
		if buffer.readi32(elevator.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.PYRAMID_ELEVATOR_ACT_IDLE then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

return pyramid_elevator_inc
