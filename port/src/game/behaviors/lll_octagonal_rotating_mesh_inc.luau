--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/lll_octagonal_rotating_mesh.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:data
const lll_octagonal_rotating_mesh_inc = {
	-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:D_8032F860 L3-4
	D_8032F860 = {
		2,
		30,
		0x4000,
		0,
		1,
		220,
		900,
		30,
		1,
		30,
		0,
		-30,
		2,
		30,
		-0x4000,
		0,
		1,
		220,
		900,
		30,
		1,
		30,
		0,
		-30,
		3,
		0,
	},
	-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:D_8032F894 L5-6
	D_8032F894 = {
		4,
		0,
		0,
		0,
		1,
		475,
		900,
		30,
		1,
		30,
		0,
		-30,
		2,
		30,
		-32768,
		0,
		1,
		475,
		900,
		30,
		1,
		30,
		0,
		-30,
		3,
		0,
	},
}

Registry.Register("src__game__behaviors__lll_octagonal_rotating_mesh_inc", lll_octagonal_rotating_mesh_inc)

-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:lll_octagonal_mesh_move L9-44
function lll_octagonal_rotating_mesh_inc.lll_octagonal_mesh_move(a0: { number }, a1: number): number
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const key = a0[a1 + 1]

	if key == 4 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, a0[a1 + 3])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, a0[a1 + 4] / 100.0)

		if ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
			a1 += 4
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif key == 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, a0[a1 + 3])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, a0[a1 + 4] / 100.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > a0[a1 + 2] then
			a1 += 4
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif key == 1 then
		ObjectHelpers.approach_f32_signed(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(a0[a1 + 3] / 100.0), F32(a0[a1 + 4] / 100.0))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > a0[a1 + 2] then
			a1 += 4
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif key == 3 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		a1 = 0
	end

	return a1
end

-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:lll_octagonal_mesh_find_y_offset L46-68
function lll_octagonal_rotating_mesh_inc.lll_octagonal_mesh_find_y_offset(Buffer: buffer, a0Offset: number, a1Offset: number, a2: number, a3: number): number
	if ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
		if buffer.readi32(Buffer, a0Offset) < 0x4000 then
			buffer.writei32(Buffer, a0Offset, S32(buffer.readi32(Buffer, a0Offset) + a2))
		else
			buffer.writei32(Buffer, a0Offset, 0x4000)
		end
	else
		if buffer.readi32(Buffer, a0Offset) > 0 then
			buffer.writei32(Buffer, a0Offset, S32(buffer.readi32(Buffer, a0Offset) - a2))
		else
			buffer.writei32(Buffer, a0Offset, 0)
		end
	end

	buffer.writef32(Buffer, a1Offset, SrcEngineMathUtilH.sins(buffer.readi32(Buffer, a0Offset)) * a3)

	if buffer.readi32(Buffer, a0Offset) == 0 or buffer.readi32(Buffer, a0Offset) == 0x4000 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:bhv_lll_moving_octagonal_mesh_platform_loop L70-89
function lll_octagonal_rotating_mesh_inc.bhv_lll_moving_octagonal_mesh_platform_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF8, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF8, lll_octagonal_rotating_mesh_inc.lll_octagonal_mesh_move(lll_octagonal_rotating_mesh_inc.D_8032F8C8[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1], buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF8)))
	end

	-- print_debug_top_down_objectinfo(...): debug print, dropped

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if lll_octagonal_rotating_mesh_inc.lll_octagonal_mesh_find_y_offset(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnk104, IncludeObjectFieldsH.oHorizontalMovementUnk108, 0x400, -80) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF4) + 0x800))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnk100, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnk100) - SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnkF4)) * 2)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnk100) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY)) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHorizontalMovementUnk108))
end

-- from src/game/behaviors/lll_octagonal_rotating_mesh.inc.c:D_8032F8C8 L7-7
lll_octagonal_rotating_mesh_inc.D_8032F8C8 = { lll_octagonal_rotating_mesh_inc.D_8032F860, lll_octagonal_rotating_mesh_inc.D_8032F894 }

return lll_octagonal_rotating_mesh_inc
