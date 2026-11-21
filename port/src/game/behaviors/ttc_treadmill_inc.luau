--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_treadmill.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SegmentSymbols = require("../../rom/segment_symbols")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/ttc_treadmill.inc.c:data
const ttc_treadmill_inc = {
	-- from src/game/behaviors/ttc_treadmill.inc.c:sTTCTreadmillCollisionModels L12-15
	sTTCTreadmillCollisionModels = { 0x070152B4, 0x070153E0 },
	-- from src/game/behaviors/ttc_treadmill.inc.c:sTTCTreadmillSpeeds L17-22
	sTTCTreadmillSpeeds = { 50, 100, 0, 0 },
}

Registry.Register("src__game__behaviors__ttc_treadmill_inc", ttc_treadmill_inc)

-- from src/game/behaviors/ttc_treadmill.inc.c:bhv_ttc_treadmill_init L27-37
function ttc_treadmill_inc.bhv_ttc_treadmill_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.collisionData = Memory.segmented_to_virtual(ttc_treadmill_inc.sTTCTreadmillCollisionModels[bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.TTC_TREADMILL_BP_FLAG_MASK) + 1])

	o.ptrData[IncludeObjectFieldsH.oTTCTreadmillBigSurface + 1] = Memory.segmented_to_virtual(SegmentSymbols.ttc_movtex_tris_big_surface_treadmill)
	o.ptrData[IncludeObjectFieldsH.oTTCTreadmillSmallSurface + 1] = Memory.segmented_to_virtual(SegmentSymbols.ttc_movtex_tris_small_surface_treadmill)

	const bigSurface = o.ptrData[IncludeObjectFieldsH.oTTCTreadmillBigSurface + 1] :: number
	const smallSurface = o.ptrData[IncludeObjectFieldsH.oTTCTreadmillSmallSurface + 1] :: number

	Rom.WriteS16(smallSurface, ttc_treadmill_inc.sTTCTreadmillSpeeds[ObjectListProcessor.gTTCSpeedSetting + 1])
	Rom.WriteS16(bigSurface, Rom.ReadS16(smallSurface))

	ObjBehaviors2.sMasterTreadmill = nil
end

-- from src/game/behaviors/ttc_treadmill.inc.c:bhv_ttc_treadmill_update L42-67
function ttc_treadmill_inc.bhv_ttc_treadmill_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bigSurface = o.ptrData[IncludeObjectFieldsH.oTTCTreadmillBigSurface + 1] :: number
	const smallSurface = o.ptrData[IncludeObjectFieldsH.oTTCTreadmillSmallSurface + 1] :: number

	if ObjBehaviors2.sMasterTreadmill == o or ObjBehaviors2.sMasterTreadmill == nil then
		ObjBehaviors2.sMasterTreadmill = o
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR2)

		if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
			-- Stay still for 5 frames, then accelerate toward the target speed
			-- until it's time to switch
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCTreadmillTimeUntilSwitch) then
				-- Then stop and select new target speed and time until switch
				if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oTTCTreadmillSpeed, 0.0, 10.0) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCTreadmillTimeUntilSwitch, ObjBehaviors2.random_mod_offset(10, 20, 7))
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCTreadmillTargetSpeed, SrcEngineBehaviorScript.random_sign() * 50.0)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
				end
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
				ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oTTCTreadmillSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCTreadmillTargetSpeed), 10.0)
			end

			Rom.WriteS16(smallSurface, TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCTreadmillSpeed)))
			Rom.WriteS16(bigSurface, Rom.ReadS16(smallSurface))
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(0.084) * Rom.ReadS16(bigSurface))
end

return ttc_treadmill_inc
