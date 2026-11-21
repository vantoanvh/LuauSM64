--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_math.h.
]]

-- from src/goddard/gd_math.h:Row4
export type Row4 = {
	c0: number,
	c1: number,
	c2: number,
	c3: number,
}

-- from src/goddard/gd_math.h:InvMat4
export type InvMat4 = {
	r0: Row4, -- first member: this table itself
	c0: number,
	c1: number,
	c2: number,
	c3: number,
	r1: Row4,
	r2: Row4,
	r3: Row4,
}

-- from src/goddard/gd_math.h:data
const gd_math_h = {
	GD_X_AXIS = 0,
	GD_Y_AXIS = 1,
	GD_Z_AXIS = 2,
}

-- from src/goddard/gd_math.h:Row4 (zero-filled constructor)
function gd_math_h.new_Row4(): Row4
	return { c0 = 0, c1 = 0, c2 = 0, c3 = 0 } :: Row4
end

-- from src/goddard/gd_math.h:InvMat4 (zero-filled constructor)
function gd_math_h.new_InvMat4(): InvMat4
	const Result = {
		c0 = 0,
		c1 = 0,
		c2 = 0,
		c3 = 0,
		r1 = { c0 = 0, c1 = 0, c2 = 0, c3 = 0 },
		r2 = { c0 = 0, c1 = 0, c2 = 0, c3 = 0 },
		r3 = { c0 = 0, c1 = 0, c2 = 0, c3 = 0 },
		r0 = nil :: unknown,
	} :: InvMat4

	Result.r0 = Result

	return Result
end

return gd_math_h
