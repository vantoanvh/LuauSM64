--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/flamethrower.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const flamethrower_inc = {}

Registry.Register("src__game__behaviors__flamethrower_inc", flamethrower_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/flamethrower.inc.c:bhv_flamethrower_flame_loop L3-48
function flamethrower_inc.bhv_flamethrower_flame_loop()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10)))
		ObjectHelpers.obj_translate_xyz_random(o, 10)
	end

	local scale = 0
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 2 then
		scale = F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) - 6)) / 100 + 2)
	else
		scale = F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * (buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) - 20) / 100 + 1)
	end

	local sp18 = 0
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 3 then
		o.hitboxHeight = 200
		o.hitboxDownOffset = 150
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -28)

		ObjectHelpers.cur_obj_update_floor_height()

		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(25 * scale)) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) + F32(25 * scale))
		end

		sp18 = TruncS32(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFlameThowerFlameUnk110) / 1.2)
	else
		sp18 = buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFlameThowerFlameUnk110)
	end

	ObjectHelpers.cur_obj_scale(scale)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 4 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))
	else
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > sp18 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/flamethrower.inc.c:bhv_flamethrower_loop L50-93
function flamethrower_inc.bhv_flamethrower_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if (Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_BBH or ObjectListProcessor.gMarioOnMerryGoRound == IncludePRUltratypesH.TRUE) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		local model = IncludeModelIdsH.MODEL_RED_FLAME
		local flameVel = 95

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 1 then
			model = IncludeModelIdsH.MODEL_BLUE_FLAME
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 2 then
			flameVel = 50
		end

		local sp34 = 1

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 60 then
			sp34 = 15
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 74 then
			sp34 = 75 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) -- Range: [15..2]
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFlameThowerUnk110, sp34)

		const flame = ObjectHelpers.spawn_object_relative(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)), 0, 0, 0, o, model, BehaviorIds.bhvFlamethrowerFlame)
		buffer.writef32(flame.rawData, IncludeObjectFieldsH.oForwardVel, flameVel)

		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BLOW_FIRE)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/flamethrower.inc.c:bhv_rr_rotating_bridge_platform_loop L95-100
function flamethrower_inc.bhv_rr_rotating_bridge_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x80)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, -0x80)

	flamethrower_inc.bhv_flamethrower_loop()
end

return flamethrower_inc
