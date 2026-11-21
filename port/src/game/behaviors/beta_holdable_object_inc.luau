--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_holdable_object.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const beta_holdable_object_inc = {}

Registry.Register("src__game__behaviors__beta_holdable_object_inc", beta_holdable_object_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/beta_holdable_object.inc.c:bhv_beta_holdable_object_init L14-18
function beta_holdable_object_inc.bhv_beta_holdable_object_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, F32(0.8))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, F32(1.3))
end

-- from src/game/behaviors/beta_holdable_object.inc.c:beta_holdable_object_drop L23-33
function beta_holdable_object_inc.beta_holdable_object_drop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Re-enable rendering
	ObjectHelpers.cur_obj_enable_rendering()

	ObjectHelpers.cur_obj_get_dropped()

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
end

-- from src/game/behaviors/beta_holdable_object.inc.c:beta_holdable_object_throw L38-52
function beta_holdable_object_inc.beta_holdable_object_throw()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- cur_obj_enable_rendering_2 just calls cur_obj_enable_rendering and does
	-- nothing else; it's useless here. Maybe it originally did more?
	ObjectHelpers.cur_obj_enable_rendering_2()
	ObjectHelpers.cur_obj_enable_rendering()

	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, IncludeObjectConstantsH.HELD_FREE)

	-- This flag is never set, why is it cleared?
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))

	-- Set initial velocity
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
end

-- from src/game/behaviors/beta_holdable_object.inc.c:bhv_beta_holdable_object_loop L59-79
function beta_holdable_object_inc.bhv_beta_holdable_object_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		-- Apply standard physics
		ObjBehaviors.object_step()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		-- Disable rendering to hide the object while it's held
		ObjectHelpers.cur_obj_disable_rendering()
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		beta_holdable_object_inc.beta_holdable_object_throw()
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		beta_holdable_object_inc.beta_holdable_object_drop()
	end
end

return beta_holdable_object_inc
