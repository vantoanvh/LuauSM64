--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/piranha_bubbles.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const piranha_bubbles_inc = {}

Registry.Register("src__game__behaviors__piranha_bubbles_inc", piranha_bubbles_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/piranha_bubbles.inc.c:bhv_piranha_plant_waking_bubbles_loop L14-21
function piranha_bubbles_inc.bhv_piranha_plant_waking_bubbles_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 10.0) + 5.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 10.0) + 5.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/piranha_bubbles.inc.c:bhv_piranha_plant_bubble_loop L30-105
function piranha_bubbles_inc.bhv_piranha_plant_bubble_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	local scale = 0.0
	const animFrame = parent.header.gfx.animInfo.animFrame
	const curAnim = parent.header.gfx.animInfo.curAnim :: number
	const loopEnd = Rom.ReadS16(curAnim + 8)
	const lastFrame = loopEnd - 2

	ObjectHelpers.cur_obj_set_pos_relative(parent, 0, 72.0, 180.0)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PIRANHA_PLANT_BUBBLE_ACT_IDLE then
		ObjectHelpers.cur_obj_disable_rendering()
		scale = 0.0

		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PIRANHA_PLANT_ACT_SLEEPING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.PIRANHA_PLANT_BUBBLE_ACT_GROW_SHRINK_LOOP then
		if buffer.readf32(parent.rawData, IncludeObjectFieldsH.oDistanceToMario) < buffer.readf32(parent.rawData, IncludeObjectFieldsH.oDrawingDistance) then
			ObjectHelpers.cur_obj_enable_rendering()

			if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PIRANHA_PLANT_ACT_SLEEPING then
				-- Shrink until the frame before halfway, grow from the frame after halfway.
				const doneShrinkingFrame = F32(F32(lastFrame / 2.0) - 4.0)
				const beginGrowingFrame = F32(F32(lastFrame / 2.0) + 4.0)

				if animFrame < doneShrinkingFrame then
					scale = F32(F32(SrcEngineMathUtilH.coss(F32(F32(animFrame / doneShrinkingFrame) * 0x4000)) * 4.0) + 1.0)
				elseif animFrame > beginGrowingFrame then
					scale = F32(F32(SrcEngineMathUtilH.sins(F32(F32(F32(animFrame - F32(F32(lastFrame / 2.0) + 4.0)) / beginGrowingFrame) * 0x4000)) * 4.0) + 1.0)
				else
					scale = 1.0
				end
			else
				-- Piranha Plant is no longer sleeping.
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			end
		else
			ObjectHelpers.cur_obj_disable_rendering()
		end
	elseif action == IncludeObjectConstantsH.PIRANHA_PLANT_BUBBLE_ACT_BURST then
		ObjectHelpers.cur_obj_disable_rendering()
		scale = 0.0

		-- Spawn 15 small bubbles to make it look like this bubble burst.
		for Index = 1, 15 do
			ObjectHelpers.try_to_spawn_object(0, 1.0, o, IncludeModelIdsH.MODEL_BUBBLE, BehaviorIds.bhvPiranhaPlantWakingBubbles)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PIRANHA_PLANT_BUBBLE_ACT_IDLE)
		scale = 1.0
	end

	ObjectHelpers.cur_obj_scale(scale)
end

return piranha_bubbles_inc
