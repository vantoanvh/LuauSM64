--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/animated_floor_switch.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

-- from src/game/behaviors/animated_floor_switch.inc.c:Struct80331A54
export type Struct80331A54 = {
	collision: number?,
	model: number,
}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/animated_floor_switch.inc.c:data
const animated_floor_switch_inc = {
	-- from src/game/behaviors/animated_floor_switch.inc.c:D_80331A54 L8-30
	D_80331A54 = {
		{
			{
				collision = 0x0701B734 --[[ bits_seg7_collision_0701B734 ]],
				model = IncludeModelIdsH.MODEL_BITS_STAIRCASE_FRAME4,
			},
			{
				collision = 0x0701B59C --[[ bits_seg7_collision_0701B59C ]],
				model = IncludeModelIdsH.MODEL_BITS_STAIRCASE_FRAME3,
			},
			{
				collision = 0x0701B404 --[[ bits_seg7_collision_0701B404 ]],
				model = IncludeModelIdsH.MODEL_BITS_STAIRCASE_FRAME2,
			},
			{
				collision = 0x0701B26C --[[ bits_seg7_collision_0701B26C ]],
				model = IncludeModelIdsH.MODEL_BITS_STAIRCASE_FRAME1,
			},
			{
				collision = 0x0701B0D4 --[[ bits_seg7_collision_0701B0D4 ]],
				model = IncludeModelIdsH.MODEL_BITS_STAIRCASE,
			},
		},
		{
			{
				collision = 0x0700FD9C --[[ bitdw_seg7_collision_0700FD9C ]],
				model = IncludeModelIdsH.MODEL_BITDW_STAIRCASE,
			},
			{
				collision = 0x0700FC7C --[[ bitdw_seg7_collision_0700FC7C ]],
				model = IncludeModelIdsH.MODEL_BITDW_STAIRCASE_FRAME1,
			},
			{
				collision = 0x0700FB5C --[[ bitdw_seg7_collision_0700FB5C ]],
				model = IncludeModelIdsH.MODEL_BITDW_STAIRCASE_FRAME2,
			},
			{
				collision = 0x0700FA3C --[[ bitdw_seg7_collision_0700FA3C ]],
				model = IncludeModelIdsH.MODEL_BITDW_STAIRCASE_FRAME3,
			},
			{
				collision = 0x0700F91C --[[ bitdw_seg7_collision_0700F91C ]],
				model = IncludeModelIdsH.MODEL_BITDW_STAIRCASE_FRAME4,
			},
		},
		{
			{
				collision = 0x0702A4CC --[[ rr_seg7_collision_0702A6B4 (ROM layout) ]],
				model = IncludeModelIdsH.MODEL_RR_TRICKY_TRIANGLES_FRAME4,
			},
			{
				collision = 0x0702A144 --[[ rr_seg7_collision_0702A32C (ROM layout) ]],
				model = IncludeModelIdsH.MODEL_RR_TRICKY_TRIANGLES_FRAME3,
			},
			{
				collision = 0x07029DBC --[[ rr_seg7_collision_07029FA4 (ROM layout) ]],
				model = IncludeModelIdsH.MODEL_RR_TRICKY_TRIANGLES_FRAME2,
			},
			{
				collision = 0x07029A34 --[[ rr_seg7_collision_07029C1C (ROM layout) ]],
				model = IncludeModelIdsH.MODEL_RR_TRICKY_TRIANGLES_FRAME1,
			},
			{
				collision = 0x0702973C --[[ rr_seg7_collision_07029924 (ROM layout) ]],
				model = IncludeModelIdsH.MODEL_RR_TRICKY_TRIANGLES,
			},
		},
	},
	-- from src/game/behaviors/animated_floor_switch.inc.c:D_80331ACC L32-32
	D_80331ACC = { 250, 200, 200 },
}

Registry.Register("src__game__behaviors__animated_floor_switch_inc", animated_floor_switch_inc)

-- from src/game/behaviors/animated_floor_switch.inc.c:Struct80331A54 (zero-filled constructor)
function animated_floor_switch_inc.new_Struct80331A54(): Struct80331A54
	return { collision = nil, model = 0 } :: Struct80331A54
end

-- from src/game/behaviors/animated_floor_switch.inc.c:bhv_animates_on_floor_switch_press_init L34-36
function animated_floor_switch_inc.bhv_animates_on_floor_switch_press_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.parentObj = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvFloorSwitchAnimatesObject)
end

-- from src/game/behaviors/animated_floor_switch.inc.c:bhv_animates_on_floor_switch_press_loop L38-77
function animated_floor_switch_inc.bhv_animates_on_floor_switch_press_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnk100) ~= 0 then
		if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnk100, 0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkFC) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4, animated_floor_switch_inc.D_80331ACC[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1])
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4, 0)
		end
	elseif buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkFC, S32(bit32.bxor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkFC), 1)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnk100, 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4) ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4) < 60 then
			SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_SLOW)
		else
			SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_GENERAL2_SWITCH_TICK_FAST)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4) - 1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF4) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkFC, 0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8) < 9 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8) + 1)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8) - 2)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8) < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkFC, 1)
		end
	end

	const switchFrame = animated_floor_switch_inc.D_80331A54[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1][buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloorSwitchPressAnimationUnkF8) // 2 + 1]

	o.collisionData = Memory.segmented_to_virtual(switchFrame.collision :: number)

	ObjectHelpers.cur_obj_set_model(switchFrame.model)
end

return animated_floor_switch_inc
