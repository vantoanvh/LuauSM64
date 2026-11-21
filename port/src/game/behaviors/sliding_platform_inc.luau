--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sliding_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const sliding_platform_inc = {}

Registry.Register("src__game__behaviors__sliding_platform_inc", sliding_platform_inc)

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

-- from src/game/behaviors/sliding_platform.inc.c:bhv_wf_sliding_platform_init L3-23
function sliding_platform_inc.bhv_wf_sliding_platform_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 2.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_BP_MOV_VEL_10 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel, 10.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_BP_MOV_VEL_15 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel, 15.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_BP_MOV_VEL_20 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel, 20.0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, S32(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0))))
end

-- from src/game/behaviors/sliding_platform.inc.c:bhv_wf_sliding_platform_loop L25-60
function sliding_platform_inc.bhv_wf_sliding_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_WAIT then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_EXTEND)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_EXTEND then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= F32(500.0 / buffer.readf32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel)) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + 510.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_RETRACT)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_RETRACT then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= F32(500.0 / buffer.readf32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel)) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 90 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WF_SLID_BRICK_PTFM_ACT_EXTEND)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWFSlidBrickPtfmMovVel))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x8000)
		end
	end
end

return sliding_platform_inc
