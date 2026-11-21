--!strict
--!optimize 2

--[[
	Port of include/behavior_data.h.
]]

const behavior_data_h = {}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from include/behavior_data.h:BPARAM1 L6-6
function behavior_data_h.BPARAM1(param: number): number
	return S32(bit32.lshift(bit32.band(param, 0xFF), 24))
end

-- from include/behavior_data.h:BPARAM2 L7-7
function behavior_data_h.BPARAM2(param: number): number
	return bit32.lshift(bit32.band(param, 0xFF), 16)
end

-- from include/behavior_data.h:BPARAM3 L8-8
function behavior_data_h.BPARAM3(param: number): number
	return bit32.lshift(bit32.band(param, 0xFF), 8)
end

-- from include/behavior_data.h:BPARAM4 L9-9
function behavior_data_h.BPARAM4(param: number): number
	return bit32.lshift(bit32.band(param, 0xFF), 0)
end

return behavior_data_h
