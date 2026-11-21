--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_floating_wood_piece.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const lll_floating_wood_piece_inc = {}

Registry.Register("src__game__behaviors__lll_floating_wood_piece_inc", lll_floating_wood_piece_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/lll_floating_wood_piece.inc.c:bhv_lll_wood_piece_loop L3-14
function lll_floating_wood_piece_inc.bhv_lll_wood_piece_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 100.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer)) * 3.0))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer) + 0x400))

	if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == 2 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/lll_floating_wood_piece.inc.c:bhv_lll_floating_wood_bridge_loop L16-42
function lll_floating_wood_piece_inc.bhv_lll_floating_wood_bridge_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2500.0 then
			for i = 1, 3 do
				const sp3C = ObjectHelpers.spawn_object_relative(0, (i - 2) * 300, 0, 0, o, IncludeModelIdsH.MODEL_LLL_WOOD_BRIDGE, BehaviorIds.bhvLLLWoodPiece)
				buffer.writei32(sp3C.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer, i * 0x1000)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2600.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	elseif action == 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

return lll_floating_wood_piece_inc
