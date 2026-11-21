--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/arrow_lift.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectListProcessor = require("../object_list_processor")

const arrow_lift_inc = {}

Registry.Register("src__game__behaviors__arrow_lift_inc", arrow_lift_inc)

-- from src/game/behaviors/arrow_lift.inc.c:arrow_lift_move_away L16-35
function arrow_lift_inc.arrow_lift_move_away(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local status = IncludeObjectConstantsH.ARROW_LIFT_NOT_DONE_MOVING

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 12)

	-- Cumulative displacement is used to keep track of how far the platform
	-- has travelled, so that it can stop.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement, buffer.readf32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

	-- Stop the platform after moving 384 units.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement) > 384 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement, 384)
		status = IncludeObjectConstantsH.ARROW_LIFT_DONE_MOVING
	end

	ObjBehaviors.obj_move_xyz_using_fvel_and_yaw(o)

	return status
end

-- from src/game/behaviors/arrow_lift.inc.c:arrow_lift_move_back L40-57
function arrow_lift_inc.arrow_lift_move_back(): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local status = IncludeObjectConstantsH.ARROW_LIFT_NOT_DONE_MOVING

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 12)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement, buffer.readf32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

	-- Stop the platform after returning back to its original position.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement) < 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oArrowLiftDisplacement, 0)
		status = IncludeObjectConstantsH.ARROW_LIFT_DONE_MOVING
	end

	ObjBehaviors.obj_move_xyz_using_fvel_and_yaw(o)

	return status
end

-- from src/game/behaviors/arrow_lift.inc.c:bhv_arrow_lift_loop L62-91
function arrow_lift_inc.bhv_arrow_lift_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.ARROW_LIFT_ACT_IDLE then
		-- Wait 61 frames before moving.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.ARROW_LIFT_ACT_MOVING_AWAY)
			end
		end
	elseif action == IncludeObjectConstantsH.ARROW_LIFT_ACT_MOVING_AWAY then
		if arrow_lift_inc.arrow_lift_move_away() == IncludeObjectConstantsH.ARROW_LIFT_DONE_MOVING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.ARROW_LIFT_ACT_MOVING_BACK)
		end
	elseif action == IncludeObjectConstantsH.ARROW_LIFT_ACT_MOVING_BACK then
		-- Wait 61 frames before moving (after stopping after moving forwards).
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			if arrow_lift_inc.arrow_lift_move_back() == IncludeObjectConstantsH.ARROW_LIFT_DONE_MOVING then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.ARROW_LIFT_ACT_IDLE)
			end
		end
	end
end

return arrow_lift_inc
