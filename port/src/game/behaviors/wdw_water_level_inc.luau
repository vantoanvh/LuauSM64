--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/wdw_water_level.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const wdw_water_level_inc = {}

Registry.Register("src__game__behaviors__wdw_water_level_inc", wdw_water_level_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/wdw_water_level.inc.c:bhv_init_changing_water_level_loop L4-15
function wdw_water_level_inc.bhv_init_changing_water_level_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const EnvironmentRegions = ObjectListProcessor.gEnvironmentRegions :: number

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if ObjectListProcessor.gEnvironmentRegions ~= nil then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
		ObjectListProcessor.gEnvironmentLevels[1] = Rom.ReadS16(EnvironmentRegions + 2 * 6)
	else
		Rom.WriteS16(EnvironmentRegions + 2 * 6, S16(TruncS32(F32(ObjectListProcessor.gEnvironmentLevels[1] + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterLevelTriggerUnkF4)) * 20)))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterLevelTriggerUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterLevelTriggerUnkF4) + 0x200))
	end
end

-- from src/game/behaviors/wdw_water_level.inc.c:bhv_water_level_diamond_loop L17-73
function wdw_water_level_inc.bhv_water_level_diamond_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if ObjectListProcessor.gEnvironmentRegions ~= nil then
		const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if Action == IncludeObjectConstantsH.WATER_LEVEL_DIAMOND_ACT_INIT then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterLevelTriggerTargetWaterLevel, S32(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
				-- Sets to WATER_LEVEL_DIAMOND_ACT_IDLE
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
			end
		elseif Action == IncludeObjectConstantsH.WATER_LEVEL_DIAMOND_ACT_IDLE then
			if ObjectHelpers.obj_check_if_collided_with_object(o, MarioObject) ~= 0 and ObjectListProcessor.gWDWWaterLevelChanging == IncludePRUltratypesH.FALSE then
				-- Sets to WATER_LEVEL_DIAMOND_ACT_CHANGE_WATER_LEVEL
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
				ObjectListProcessor.gWDWWaterLevelChanging = IncludePRUltratypesH.TRUE
			end
		elseif Action == IncludeObjectConstantsH.WATER_LEVEL_DIAMOND_ACT_CHANGE_WATER_LEVEL then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)

			const TargetWaterLevel = buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterLevelTriggerTargetWaterLevel)

			ObjectListProcessor.gEnvironmentLevels[1] = S32(TruncS32(ObjectHelpers.approach_f32_symmetric(ObjectListProcessor.gEnvironmentLevels[1], TargetWaterLevel, 10)))

			if ObjectListProcessor.gEnvironmentLevels[1] == TargetWaterLevel then
				if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) == 0 then
					-- Sets to WATER_LEVEL_DIAMOND_ACT_IDLE_SPINNING
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x800)
				end
			else
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_WATER_LEVEL_TRIG)
				else
					if ObjectListProcessor.gEnvironmentLevels[1] > TargetWaterLevel then
						SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER_DRAIN)
					else
						-- same as above
						SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER_DRAIN)
					end
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x800)
			end
		elseif Action == IncludeObjectConstantsH.WATER_LEVEL_DIAMOND_ACT_IDLE_SPINNING then
			if ObjectHelpers.obj_check_if_collided_with_object(o, MarioObject) == 0 then
				ObjectListProcessor.gWDWWaterLevelChanging = IncludePRUltratypesH.FALSE
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_LEVEL_DIAMOND_ACT_IDLE)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
			end
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	end
end

return wdw_water_level_inc
