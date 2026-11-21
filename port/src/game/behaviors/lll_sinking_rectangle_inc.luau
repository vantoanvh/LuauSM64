--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_sinking_rectangle.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const lll_sinking_rectangle_inc = {}

Registry.Register("src__game__behaviors__lll_sinking_rectangle_inc", lll_sinking_rectangle_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/lll_sinking_rectangle.inc.c:sinking_rectangular_plat_actions L3-18
function lll_sinking_rectangle_inc.sinking_rectangular_plat_actions(a0: number, a1: number)
	a0 = F32(a0)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
	elseif action == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer)) * a0))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer) + a1))
	elseif action == 2 then
		-- Nothing to do.
	end
end

-- from src/game/behaviors/lll_sinking_rectangle.inc.c:bhv_lll_sinking_rectangular_platform_loop L20-30
function lll_sinking_rectangle_inc.bhv_lll_sinking_rectangular_platform_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) ~= 0 then
		lll_sinking_rectangle_inc.sinking_rectangular_plat_actions(F32(0.4), 0x100)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer)) * 0x200))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oLLLWoodPieceOscillationTimer) + 0x100))
	end
end

-- from src/game/behaviors/lll_sinking_rectangle.inc.c:bhv_lll_sinking_square_platforms_loop L32-37
function lll_sinking_rectangle_inc.bhv_lll_sinking_square_platforms_loop()
	lll_sinking_rectangle_inc.sinking_rectangular_plat_actions(0.5, 0x100)
end

return lll_sinking_rectangle_inc
