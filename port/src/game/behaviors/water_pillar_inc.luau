--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_pillar.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SpawnSound = require("../spawn_sound")
const Rom = require("../../rom/rom")
const Audio = require("../../rom/audio_recorder")

const water_pillar_inc = {}

Registry.Register("src__game__behaviors__water_pillar_inc", water_pillar_inc)

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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/water_pillar.inc.c:water_level_pillar_undrained L3-60
function water_pillar_inc.water_level_pillar_undrained()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == 0 then
		if ObjectHelpers.cur_obj_is_mario_ground_pounding_platform() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
			ObjectHelpers.spawn_mist_particles()
		end
	elseif Action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 4 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 20)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif Action == 2 then
		const OtherWaterPillar = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvWaterLevelPillar)

		if OtherWaterPillar ~= nil then
			if buffer.readi32(OtherWaterPillar.rawData, IncludeObjectFieldsH.oAction) < 2 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
			end
		end
	elseif Action == 3 then
		const OtherWaterPillar = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvWaterLevelPillar)

		if OtherWaterPillar ~= nil then
			if buffer.readi32(OtherWaterPillar.rawData, IncludeObjectFieldsH.oAction) > 1 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
				SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_MOAT_DRAINED)
				Audio.play_puzzle_jingle()
			end
		end
	elseif Action == 4 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER_DRAIN)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 300 then
			ObjectListProcessor.gEnvironmentLevels[3] = S32(TruncS32(ObjectHelpers.approach_f32_symmetric(ObjectListProcessor.gEnvironmentLevels[3], -2450, 5)))
			ObjectListProcessor.gEnvironmentLevels[1] = S32(TruncS32(ObjectHelpers.approach_f32_symmetric(ObjectListProcessor.gEnvironmentLevels[1], -2450, 5)))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	end
end

-- from src/game/behaviors/water_pillar.inc.c:water_level_pillar_drained L62-68
function water_pillar_inc.water_level_pillar_drained()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 80)
		ObjectListProcessor.gEnvironmentLevels[3] = -2450
		ObjectListProcessor.gEnvironmentLevels[1] = -2450
	end
end

-- from src/game/behaviors/water_pillar.inc.c:bhv_water_level_pillar_init L70-74
function water_pillar_inc.bhv_water_level_pillar_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_MOAT_DRAINED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterLevelPillarDrained, IncludePRUltratypesH.TRUE)
	end
end

-- from src/game/behaviors/water_pillar.inc.c:bhv_water_level_pillar_loop L76-84
function water_pillar_inc.bhv_water_level_pillar_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const EnvironmentRegions = ObjectListProcessor.gEnvironmentRegions :: number

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterLevelPillarDrained) ~= 0 then
		water_pillar_inc.water_level_pillar_drained()
	else
		water_pillar_inc.water_level_pillar_undrained()
	end

	Rom.WriteS16(EnvironmentRegions + 2 * 18, S16(ObjectListProcessor.gEnvironmentLevels[3]))
	Rom.WriteS16(EnvironmentRegions + 2 * 6, S16(ObjectListProcessor.gEnvironmentLevels[1]))
end

return water_pillar_inc
