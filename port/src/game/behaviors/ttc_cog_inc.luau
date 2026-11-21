--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_cog.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/ttc_cog.inc.c:data
const ttc_cog_inc = {
	-- from src/game/behaviors/ttc_cog.inc.c:sTTCCogCollisionModels L10-13
	sTTCCogCollisionModels = { 0x07015584 --[[ ttc_seg7_collision_07015584 ]], 0x07015650 --[[ ttc_seg7_collision_07015650 ]] },
	-- from src/game/behaviors/ttc_cog.inc.c:sTTCCogDirections L18-18
	sTTCCogDirections = { 1, -1 },
	-- from src/game/behaviors/ttc_cog.inc.c:sTTCCogNormalSpeeds L23-23
	sTTCCogNormalSpeeds = { 200, 400 },
}

Registry.Register("src__game__behaviors__ttc_cog_inc", ttc_cog_inc)

-- from src/game/behaviors/ttc_cog.inc.c:bhv_ttc_cog_init L28-32
function ttc_cog_inc.bhv_ttc_cog_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.collisionData = Memory.segmented_to_virtual(ttc_cog_inc.sTTCCogCollisionModels[bit32.rshift(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.TTC_COG_BP_SHAPE_MASK), 1) + 1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCCogDir, ttc_cog_inc.sTTCCogDirections[bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), IncludeObjectConstantsH.TTC_COG_BP_DIR_MASK) + 1])
end

-- from src/game/behaviors/ttc_cog.inc.c:bhv_ttc_cog_update L37-55
function ttc_cog_inc.bhv_ttc_cog_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_SLOW or ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_FAST then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCCogSpeed, ttc_cog_inc.sTTCCogNormalSpeeds[ObjectListProcessor.gTTCSpeedSetting + 1])
	elseif ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_RANDOM then
		if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oTTCCogSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCCogTargetVel), 50.0) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCCogTargetVel, F32(F32(200.0 * (SrcEngineBehaviorScript.random_u16() % 7)) * SrcEngineBehaviorScript.random_sign()))
		end
	elseif ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_STOPPED then
		-- The cog stays still.
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S32(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCCogSpeed) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCCogDir)))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
end

return ttc_cog_inc
