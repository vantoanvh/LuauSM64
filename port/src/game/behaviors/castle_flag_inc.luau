--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/castle_flag.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const castle_flag_inc = {}

Registry.Register("src__game__behaviors__castle_flag_inc", castle_flag_inc)

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

-- from src/game/behaviors/castle_flag.inc.c:bhv_castle_flag_init L3-5
function castle_flag_inc.bhv_castle_flag_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 28.0)))
end

return castle_flag_inc
