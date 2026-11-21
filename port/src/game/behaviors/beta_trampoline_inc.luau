--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_trampoline.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const MarioStep = require("../mario_step")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const beta_trampoline_inc = {}

Registry.Register("src__game__behaviors__beta_trampoline_inc", beta_trampoline_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/beta_trampoline.inc.c:bhv_beta_trampoline_spring_loop L19-47
function beta_trampoline_inc.bhv_beta_trampoline_spring_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	-- Update to be 75 units under the trampoline top
	ObjectHelpers.obj_copy_pos_and_angle(o, parent)
	ObjectHelpers.obj_copy_graph_y_offset(o, parent)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 75.0)

	-- If the trampoline top is above its original position,
	-- scale the spring by (the displacement)/10 + 1.
	-- For this to work correctly, the arbitrary value of 10
	-- must be replaced with 150 (the height of the trampoline).
	-- Note that all of the numbers in this if/else block are doubles.
	local yDisplacement = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	local yScale: number

	if yDisplacement >= 0 then
		yScale = F32(yDisplacement / 10.0 + 1.0)
	else
		-- Otherwise (if the trampoline is compressed),
		-- scale by 1 - (the displacement)/500.
		-- For this to work correctly, the arbitrary value of 500
		-- must be replaced with 150 (the height of the trampoline),
		-- as with the above code.
		yDisplacement = -yDisplacement
		yScale = F32(1.0 - yDisplacement / 500.0)
	end

	-- Scale the spring
	ObjectHelpers.obj_scale_xyz(o, 1.0, yScale, 1.0)
end

-- from src/game/behaviors/beta_trampoline.inc.c:bhv_beta_trampoline_top_loop L56-88
function beta_trampoline_inc.bhv_beta_trampoline_top_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_TRAMPOLINE)

	-- When initialized, spawn the rest of the trampoline
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		local trampolinePart = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_TRAMPOLINE_CENTER, BehaviorIds.bhvBetaTrampolineSpring)
		buffer.writef32(trampolinePart.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(trampolinePart.rawData, IncludeObjectFieldsH.oPosY) - 75.0)

		trampolinePart = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_TRAMPOLINE_BASE, BehaviorIds.bhvStaticObject)
		buffer.writef32(trampolinePart.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(trampolinePart.rawData, IncludeObjectFieldsH.oPosY) - 150.0)
	end

	-- Update o->oBetaTrampolineMarioOnTrampoline, and reset
	-- the trampoline's position if Mario's not on it.
	-- Since the trampoline never moves, this doesn't do anything.
	-- Maybe they intended to decrease the trampoline's position
	-- when Mario's on it in this if statement?
	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBetaTrampolineMarioOnTrampoline, IncludePRUltratypesH.TRUE)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBetaTrampolineMarioOnTrampoline, IncludePRUltratypesH.FALSE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	end

	-- This function is from mario_step.c, and is empty.
	-- It was probably intended to be used to "let the game know"
	-- that the trampoline is currently in use. This potential
	-- trampoline infrastructure is found in mario_step.c. See
	-- that file for more details.
	MarioStep.stub_mario_step_2()
end

return beta_trampoline_inc
