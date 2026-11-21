--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_macros.h.
]]

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/goddard/gd_macros.h:data
const gd_macros_h = {
	DEG_PER_RAD = 57.29577950560105,
}

-- from src/goddard/gd_macros.h:ABS L13-13
function gd_macros_h.ABS(val: number): number
	if val < 0 then
		return -val
	end

	return val
end

-- from src/goddard/gd_macros.h:SQ L14-14
function gd_macros_h.SQ(val: number): number
	return F32(val * val)
end

-- from src/goddard/gd_macros.h:ALIGN L15-15
function gd_macros_h.ALIGN(VAL_: number, ALIGNMENT_: number): number
	return bit32.band(VAL_ + ALIGNMENT_ - 1, bit32.bnot(ALIGNMENT_ - 1))
end

gd_macros_h.RAD_PER_DEG = 1.0 / gd_macros_h.DEG_PER_RAD

return gd_macros_h
