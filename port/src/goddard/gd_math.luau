--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_math.c.
]]

const GdTypesH = require("./gd_types_h")
const GdMacrosH = require("./gd_macros_h")
const GdMathH = require("./gd_math_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Registry = require("../../groups/registry")

const gd_math = {}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/goddard/gd_math.luau:scratch
const MultiplyResult = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/gd_math.luau:scratch
const RotationMatrix = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
-- from src/goddard/gd_math.luau:scratch
const RotationAxis = { x = 0, y = 0, z = 0 }
-- from src/goddard/gd_math.luau:scratch
const LookatDirection = { x = 0, y = 0, z = 0 }

-- from src/goddard/gd_math.c:gd_sqrt_f L15-17
function gd_math.gd_sqrt_f(val: number): number
	val = F32(val)

	const Result: number = Registry.Members.src__goddard__renderer.gd_sqrt_d(val)

	return F32(Result)
end

-- from src/goddard/gd_math.c:gd_mat4f_lookat L25-102
function gd_math.gd_mat4f_lookat(mtx: { { number } }, xFrom: number, yFrom: number, zFrom: number, xTo: number, yTo: number, zTo: number, zColY: number, yColY: number, xColY: number)
	xFrom = F32(xFrom)
	yFrom = F32(yFrom)
	zFrom = F32(zFrom)
	xTo = F32(xTo)
	yTo = F32(yTo)
	zTo = F32(zTo)
	zColY = F32(zColY)
	yColY = F32(yColY)
	xColY = F32(xColY)
	gd_math.gd_set_identity_mat4(mtx)

	local DeltaX = F32(xTo - xFrom)
	local DeltaY = F32(yTo - yFrom)
	local DeltaZ = F32(zTo - zFrom)
	const Distance = F32(F32(GdMacrosH.ABS(DeltaX) + GdMacrosH.ABS(DeltaY)) + GdMacrosH.ABS(DeltaZ))

	if Distance > 10000 or Distance < 10 then
		LookatDirection.x = DeltaX
		LookatDirection.y = DeltaY
		LookatDirection.z = DeltaZ
		gd_math.gd_normalize_vec3f(LookatDirection)
		DeltaX = F32(LookatDirection.x * 10000)
		DeltaY = F32(LookatDirection.y * 10000)
		DeltaZ = F32(LookatDirection.z * 10000)
	end

	const BackLengthInverse = F32(-1 / gd_math.gd_sqrt_f(F32(F32(GdMacrosH.SQ(DeltaX) + GdMacrosH.SQ(DeltaY)) + GdMacrosH.SQ(DeltaZ))))
	const BackX = F32(DeltaX * BackLengthInverse)
	const BackY = F32(DeltaY * BackLengthInverse)
	const BackZ = F32(DeltaZ * BackLengthInverse)

	local RightX = F32(F32(yColY * BackZ) - F32(xColY * BackY))
	local RightY = F32(F32(xColY * BackX) - F32(zColY * BackZ))
	local RightZ = F32(F32(zColY * BackY) - F32(yColY * BackX))
	const RightLengthInverse = F32(1 / gd_math.gd_sqrt_f(F32(F32(GdMacrosH.SQ(RightX) + GdMacrosH.SQ(RightY)) + GdMacrosH.SQ(RightZ))))

	RightX = F32(RightX * RightLengthInverse)
	RightY = F32(RightY * RightLengthInverse)
	RightZ = F32(RightZ * RightLengthInverse)

	local UpX = F32(F32(BackY * RightZ) - F32(BackZ * RightY))
	local UpY = F32(F32(BackZ * RightX) - F32(BackX * RightZ))
	local UpZ = F32(F32(BackX * RightY) - F32(BackY * RightX))
	const UpLengthInverse = F32(1 / gd_math.gd_sqrt_f(F32(F32(GdMacrosH.SQ(UpX) + GdMacrosH.SQ(UpY)) + GdMacrosH.SQ(UpZ))))

	UpX = F32(UpX * UpLengthInverse)
	UpY = F32(UpY * UpLengthInverse)
	UpZ = F32(UpZ * UpLengthInverse)

	mtx[1][1] = RightX
	mtx[2][1] = RightY
	mtx[3][1] = RightZ
	mtx[4][1] = -F32(F32(F32(xFrom * RightX) + F32(yFrom * RightY)) + F32(zFrom * RightZ))

	mtx[1][2] = UpX
	mtx[2][2] = UpY
	mtx[3][2] = UpZ
	mtx[4][2] = -F32(F32(F32(xFrom * UpX) + F32(yFrom * UpY)) + F32(zFrom * UpZ))

	mtx[1][3] = BackX
	mtx[2][3] = BackY
	mtx[3][3] = BackZ
	mtx[4][3] = -F32(F32(F32(xFrom * BackX) + F32(yFrom * BackY)) + F32(zFrom * BackZ))

	mtx[1][4] = 0
	mtx[2][4] = 0
	mtx[3][4] = 0
	mtx[4][4] = 1
end

-- from src/goddard/gd_math.c:gd_scale_mat4f_by_vec3f L107-117
function gd_math.gd_scale_mat4f_by_vec3f(mtx: { { number } }, vec: GdTypesH.GdVec3f)
	for Column = 1, 3 do
		mtx[1][Column] = F32(mtx[1][Column] * vec.x)
		mtx[2][Column] = F32(mtx[2][Column] * vec.y)
		mtx[3][Column] = F32(mtx[3][Column] * vec.z)
	end
end

-- from src/goddard/gd_math.c:gd_rot_mat_about_vec L122-132
function gd_math.gd_rot_mat_about_vec(mtx: { { number } }, vec: GdTypesH.GdVec3f)
	if vec.x ~= 0 then
		gd_math.gd_absrot_mat4(mtx, GdMathH.GD_X_AXIS, vec.x)
	end

	if vec.y ~= 0 then
		gd_math.gd_absrot_mat4(mtx, GdMathH.GD_Y_AXIS, vec.y)
	end

	if vec.z ~= 0 then
		gd_math.gd_absrot_mat4(mtx, GdMathH.GD_Z_AXIS, vec.z)
	end
end

-- from src/goddard/gd_math.c:gd_add_vec3f_to_mat4f_offset L138-149
function gd_math.gd_add_vec3f_to_mat4f_offset(mtx: { { number } }, vec: GdTypesH.GdVec3f)
	mtx[4][1] = F32(mtx[4][1] + vec.x)
	mtx[4][2] = F32(mtx[4][2] + vec.y)
	mtx[4][3] = F32(mtx[4][3] + vec.z)
end

-- from src/goddard/gd_math.c:gd_create_origin_lookat L160-222
function gd_math.gd_create_origin_lookat(mtx: { { number } }, vec: GdTypesH.GdVec3f, roll: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_clamp_f32 L227-235
function gd_math.gd_clamp_f32(a: number, b: number): number
	a = F32(a)
	b = F32(b)

	if b < a then
		a = b
	elseif a < -b then
		a = -b
	end

	return a
end

-- from src/goddard/gd_math.c:gd_clamp_vec3f L240-258
function gd_math.gd_clamp_vec3f(vec: GdTypesH.GdVec3f, limit: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_rot_2d_vec L263-273
function gd_math.gd_rot_2d_vec(deg: number, x: { number }, y: { number })
	deg = F32(deg)

	const Radians = F32(deg / GdMacrosH.DEG_PER_RAD)
	const FirstCosine: number = Registry.Members.src__goddard__renderer.gd_cos_d(Radians)
	const FirstSine: number = Registry.Members.src__goddard__renderer.gd_sin_d(Radians)

	-- Trig values are rounded by sinf and cosf, then promoted to double for these expressions.
	const X = F32(x[1] * FirstCosine - y[1] * FirstSine)
	const SecondSine: number = Registry.Members.src__goddard__renderer.gd_sin_d(Radians)
	const SecondCosine: number = Registry.Members.src__goddard__renderer.gd_cos_d(Radians)
	const Y = F32(x[1] * SecondSine + y[1] * SecondCosine)

	x[1] = X
	y[1] = Y
end

-- from src/goddard/gd_math.c:gd_rot_mat_about_row L278-288
function gd_math.gd_rot_mat_about_row(mat: { { number } }, row: number, ang: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_absrot_mat4 L294-320
function gd_math.gd_absrot_mat4(mtx: { { number } }, axisnum: number, ang: number)
	ang = F32(ang)

	if axisnum == GdMathH.GD_X_AXIS then
		RotationAxis.x = 1
		RotationAxis.y = 0
		RotationAxis.z = 0
	elseif axisnum == GdMathH.GD_Y_AXIS then
		RotationAxis.x = 0
		RotationAxis.y = 1
		RotationAxis.z = 0
	elseif axisnum == GdMathH.GD_Z_AXIS then
		RotationAxis.x = 0
		RotationAxis.y = 0
		RotationAxis.z = 1
	else
		error("absrot_matrix4(): Bad axis num")
	end

	gd_math.gd_create_rot_mat_angular(RotationMatrix, RotationAxis, F32(ang / 2))
	gd_math.gd_mult_mat4f(mtx, RotationMatrix, mtx)
end

-- from src/goddard/gd_math.c:gd_vec3f_magnitude L323-325
function gd_math.gd_vec3f_magnitude(vec: GdTypesH.GdVec3f): number
	return gd_math.gd_sqrt_f(F32(F32(GdMacrosH.SQ(vec.x) + GdMacrosH.SQ(vec.y)) + GdMacrosH.SQ(vec.z)))
end

-- from src/goddard/gd_math.c:gd_normalize_vec3f L330-350
function gd_math.gd_normalize_vec3f(vec: GdTypesH.GdVec3f): number
	const SquaredMagnitude = F32(F32(GdMacrosH.SQ(vec.x) + GdMacrosH.SQ(vec.y)) + GdMacrosH.SQ(vec.z))

	if SquaredMagnitude == 0 then
		return IncludePRUltratypesH.FALSE
	end

	const Magnitude = gd_math.gd_sqrt_f(SquaredMagnitude)

	if Magnitude == 0 then
		vec.x = 0
		vec.y = 0
		vec.z = 0

		return IncludePRUltratypesH.FALSE
	end

	vec.x = F32(vec.x / Magnitude)
	vec.y = F32(vec.y / Magnitude)
	vec.z = F32(vec.z / Magnitude)

	return IncludePRUltratypesH.TRUE
end

-- from src/goddard/gd_math.c:gd_cross_vec3f L355-365
function gd_math.gd_cross_vec3f(a: GdTypesH.GdVec3f, b: GdTypesH.GdVec3f, dst: GdTypesH.GdVec3f)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_dot_vec3f L370-372
function gd_math.gd_dot_vec3f(a: GdTypesH.GdVec3f, b: GdTypesH.GdVec3f): number
	error("stale")
end

-- from src/goddard/gd_math.c:gd_invert_elements_mat4f L377-386
function gd_math.gd_invert_elements_mat4f(src: { { number } }, dst: { { number } })
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_inverse_mat4f L392-409
function gd_math.gd_inverse_mat4f(src: { { number } }, dst: { { number } })
	gd_math.gd_adjunct_mat4f(src, dst)

	const Determinant = gd_math.gd_mat4f_det(dst)

	if GdMacrosH.ABS(Determinant) < 1e-5 then
		error("Non-singular matrix, no inverse!\n")
	end

	for Row = 1, 4 do
		for Column = 1, 4 do
			dst[Row][Column] = F32(dst[Row][Column] / Determinant)
		end
	end
end

-- from src/goddard/gd_math.c:gd_adjunct_mat4f L414-466
function gd_math.gd_adjunct_mat4f(src: { { number } }, dst: { { number } })
	-- Snapshot the inputs because src and dst may be the same matrix.
	const M11, M12, M13, M14 = src[1][1], src[1][2], src[1][3], src[1][4]
	const M21, M22, M23, M24 = src[2][1], src[2][2], src[2][3], src[2][4]
	const M31, M32, M33, M34 = src[3][1], src[3][2], src[3][3], src[3][4]
	const M41, M42, M43, M44 = src[4][1], src[4][2], src[4][3], src[4][4]

	dst[1][1] = gd_math.gd_3x3_det(M22, M32, M42, M23, M33, M43, M24, M34, M44)
	dst[2][1] = -gd_math.gd_3x3_det(M21, M31, M41, M23, M33, M43, M24, M34, M44)
	dst[3][1] = gd_math.gd_3x3_det(M21, M31, M41, M22, M32, M42, M24, M34, M44)
	dst[4][1] = -gd_math.gd_3x3_det(M21, M31, M41, M22, M32, M42, M23, M33, M43)

	dst[1][2] = -gd_math.gd_3x3_det(M12, M32, M42, M13, M33, M43, M14, M34, M44)
	dst[2][2] = gd_math.gd_3x3_det(M11, M31, M41, M13, M33, M43, M14, M34, M44)
	dst[3][2] = -gd_math.gd_3x3_det(M11, M31, M41, M12, M32, M42, M14, M34, M44)
	dst[4][2] = gd_math.gd_3x3_det(M11, M31, M41, M12, M32, M42, M13, M33, M43)

	dst[1][3] = gd_math.gd_3x3_det(M12, M22, M42, M13, M23, M43, M14, M24, M44)
	dst[2][3] = -gd_math.gd_3x3_det(M11, M21, M41, M13, M23, M43, M14, M24, M44)
	dst[3][3] = gd_math.gd_3x3_det(M11, M21, M41, M12, M22, M42, M14, M24, M44)
	dst[4][3] = -gd_math.gd_3x3_det(M11, M21, M41, M12, M22, M42, M13, M23, M43)

	dst[1][4] = -gd_math.gd_3x3_det(M12, M22, M32, M13, M23, M33, M14, M24, M34)
	dst[2][4] = gd_math.gd_3x3_det(M11, M21, M31, M13, M23, M33, M14, M24, M34)
	dst[3][4] = -gd_math.gd_3x3_det(M11, M21, M31, M12, M22, M32, M14, M24, M34)
	dst[4][4] = gd_math.gd_3x3_det(M11, M21, M31, M12, M22, M32, M13, M23, M33)
end

-- from src/goddard/gd_math.c:gd_mat4f_det L471-510
function gd_math.gd_mat4f_det(mtx: { { number } }): number
	const M11, M12, M13, M14 = mtx[1][1], mtx[1][2], mtx[1][3], mtx[1][4]
	const M21, M22, M23, M24 = mtx[2][1], mtx[2][2], mtx[2][3], mtx[2][4]
	const M31, M32, M33, M34 = mtx[3][1], mtx[3][2], mtx[3][3], mtx[3][4]
	const M41, M42, M43, M44 = mtx[4][1], mtx[4][2], mtx[4][3], mtx[4][4]

	const First = F32(M11 * gd_math.gd_3x3_det(M22, M32, M42, M23, M33, M43, M24, M34, M44))
	const Second = F32(M12 * gd_math.gd_3x3_det(M21, M31, M41, M23, M33, M43, M24, M34, M44))
	const Third = F32(M13 * gd_math.gd_3x3_det(M21, M31, M41, M22, M32, M42, M24, M34, M44))
	const Fourth = F32(M14 * gd_math.gd_3x3_det(M21, M31, M41, M22, M32, M42, M23, M33, M43))

	return F32(F32(F32(First - Second) + Third) - Fourth)
end

-- from src/goddard/gd_math.c:gd_3x3_det L516-525
function gd_math.gd_3x3_det(r0c0: number, r0c1: number, r0c2: number, r1c0: number, r1c1: number, r1c2: number, r2c0: number, r2c1: number, r2c2: number): number
	r0c0 = F32(r0c0)
	r0c1 = F32(r0c1)
	r0c2 = F32(r0c2)
	r1c0 = F32(r1c0)
	r1c1 = F32(r1c1)
	r1c2 = F32(r1c2)
	r2c0 = F32(r2c0)
	r2c1 = F32(r2c1)
	r2c2 = F32(r2c2)

	const First = F32(r0c0 * gd_math.gd_2x2_det(r1c1, r1c2, r2c1, r2c2))
	const Second = F32(r1c0 * gd_math.gd_2x2_det(r0c1, r0c2, r2c1, r2c2))
	const Third = F32(r2c0 * gd_math.gd_2x2_det(r0c1, r0c2, r1c1, r1c2))

	return F32(F32(First - Second) + Third)
end

-- from src/goddard/gd_math.c:gd_2x2_det L531-535
function gd_math.gd_2x2_det(a: number, b: number, c: number, d: number): number
	a = F32(a)
	b = F32(b)
	c = F32(c)
	d = F32(d)

	return F32(F32(a * d) - F32(b * c))
end

-- from src/goddard/gd_math.c:gd_create_neg_vec_zero_first_mat_row L542-554
function gd_math.gd_create_neg_vec_zero_first_mat_row(mtx: { { number } }, vec: GdTypesH.GdVec3f, x: number, y: number, z: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_broken_quat_to_vec3f L560-594
function gd_math.gd_broken_quat_to_vec3f(quat: { number }, vec: GdTypesH.GdVec3f, zHalf: number, i: number, run: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_quat_rotation L600-620
function gd_math.gd_quat_rotation(quat: { number }, unused: number, c: number, s: number, i: number, sign: number)
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_shift_mat_up L625-647
function gd_math.gd_shift_mat_up(mtx: { { number } })
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_create_quat_rot_mat L660-695
function gd_math.gd_create_quat_rot_mat(quat: { number }, unused: number, mtx: { { number } })
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_create_rot_matrix L709-738
function gd_math.gd_create_rot_matrix(mtx: { { number } }, vec: GdTypesH.GdVec3f, s: number, c: number)
	s = F32(s)
	c = F32(c)

	const OneMinusCos = F32(1 - c)
	const X = vec.x
	const Y = vec.y
	const Z = vec.z

	mtx[1][1] = F32(F32(F32(OneMinusCos * X) * X) + c)
	mtx[1][2] = F32(F32(F32(OneMinusCos * X) * Y) + F32(s * Z))
	mtx[1][3] = F32(F32(F32(OneMinusCos * X) * Z) - F32(s * Y))
	mtx[1][4] = 0

	mtx[2][1] = F32(F32(F32(OneMinusCos * X) * Y) - F32(s * Z))
	mtx[2][2] = F32(F32(F32(OneMinusCos * Y) * Y) + c)
	mtx[2][3] = F32(F32(F32(OneMinusCos * Y) * Z) + F32(s * X))
	mtx[2][4] = 0

	mtx[3][1] = F32(F32(F32(OneMinusCos * X) * Z) + F32(s * Y))
	mtx[3][2] = F32(F32(F32(OneMinusCos * Y) * Z) - F32(s * X))
	mtx[3][3] = F32(F32(F32(OneMinusCos * Z) * Z) + c)
	mtx[3][4] = 0

	mtx[4][1] = 0
	mtx[4][2] = 0
	mtx[4][3] = 0
	mtx[4][4] = 1
end

-- from src/goddard/gd_math.c:gd_create_rot_mat_angular L743-751
function gd_math.gd_create_rot_mat_angular(mtx: { { number } }, vec: GdTypesH.GdVec3f, ang: number)
	ang = F32(ang)

	const Angle = ang / (GdMacrosH.DEG_PER_RAD / 2)
	const Sine: number = Registry.Members.src__goddard__renderer.gd_sin_d(Angle)
	const Cosine: number = Registry.Members.src__goddard__renderer.gd_cos_d(Angle)

	gd_math.gd_create_rot_matrix(mtx, vec, F32(Sine), F32(Cosine))
end

-- from src/goddard/gd_math.c:gd_set_identity_mat4 L756-773
function gd_math.gd_set_identity_mat4(mtx: { { number } })
	for Row = 1, 4 do
		for Column = 1, 4 do
			mtx[Row][Column] = if Row == Column then 1 else 0
		end
	end
end

-- from src/goddard/gd_math.c:gd_copy_mat4f L778-795
function gd_math.gd_copy_mat4f(src: { { number } }, dst: { { number } })
	for Row = 1, 4 do
		for Column = 1, 4 do
			dst[Row][Column] = src[Row][Column]
		end
	end
end

-- from src/goddard/gd_math.c:gd_rotate_and_translate_vec3f L801-814
function gd_math.gd_rotate_and_translate_vec3f(vec: GdTypesH.GdVec3f, mtx: { { number } })
	const X = F32(F32(F32(mtx[1][1] * vec.x) + F32(mtx[2][1] * vec.y)) + F32(mtx[3][1] * vec.z))
	const Y = F32(F32(F32(mtx[1][2] * vec.x) + F32(mtx[2][2] * vec.y)) + F32(mtx[3][2] * vec.z))
	const Z = F32(F32(F32(mtx[1][3] * vec.x) + F32(mtx[2][3] * vec.y)) + F32(mtx[3][3] * vec.z))

	vec.x = F32(X + mtx[4][1])
	vec.y = F32(Y + mtx[4][2])
	vec.z = F32(Z + mtx[4][3])
end

-- from src/goddard/gd_math.c:gd_mat4f_mult_vec3f L819-829
function gd_math.gd_mat4f_mult_vec3f(vec: GdTypesH.GdVec3f, mtx: { { number } })
	const X = F32(F32(F32(mtx[1][1] * vec.x) + F32(mtx[2][1] * vec.y)) + F32(mtx[3][1] * vec.z))
	const Y = F32(F32(F32(mtx[1][2] * vec.x) + F32(mtx[2][2] * vec.y)) + F32(mtx[3][2] * vec.z))
	const Z = F32(F32(F32(mtx[1][3] * vec.x) + F32(mtx[2][3] * vec.y)) + F32(mtx[3][3] * vec.z))

	vec.x = X
	vec.y = Y
	vec.z = Z
end

-- from src/goddard/gd_math.c:MAT4_DOT_PROD L831-837
function gd_math.MAT4_DOT_PROD(A: { { number } }, B: { { number } }, R: { { number } }, row: number, col: number)
	const Row = row + 1
	const Column = col + 1

	R[Row][Column] = F32(A[Row][1] * B[1][Column])
	R[Row][Column] = F32(R[Row][Column] + F32(A[Row][2] * B[2][Column]))
	R[Row][Column] = F32(R[Row][Column] + F32(A[Row][3] * B[3][Column]))
	R[Row][Column] = F32(R[Row][Column] + F32(A[Row][4] * B[4][Column]))
end

-- from src/goddard/gd_math.c:MAT4_MULTIPLY L839-857
function gd_math.MAT4_MULTIPLY(A: { { number } }, B: { { number } }, R: { { number } })
	gd_math.MAT4_DOT_PROD(A, B, R, 0, 0)
	gd_math.MAT4_DOT_PROD(A, B, R, 0, 1)
	gd_math.MAT4_DOT_PROD(A, B, R, 0, 2)
	gd_math.MAT4_DOT_PROD(A, B, R, 0, 3)
	gd_math.MAT4_DOT_PROD(A, B, R, 1, 0)
	gd_math.MAT4_DOT_PROD(A, B, R, 1, 1)
	gd_math.MAT4_DOT_PROD(A, B, R, 1, 2)
	gd_math.MAT4_DOT_PROD(A, B, R, 1, 3)
	gd_math.MAT4_DOT_PROD(A, B, R, 2, 0)
	gd_math.MAT4_DOT_PROD(A, B, R, 2, 1)
	gd_math.MAT4_DOT_PROD(A, B, R, 2, 2)
	gd_math.MAT4_DOT_PROD(A, B, R, 2, 3)
	gd_math.MAT4_DOT_PROD(A, B, R, 3, 0)
	gd_math.MAT4_DOT_PROD(A, B, R, 3, 1)
	gd_math.MAT4_DOT_PROD(A, B, R, 3, 2)
	gd_math.MAT4_DOT_PROD(A, B, R, 3, 3)
end

-- from src/goddard/gd_math.c:gd_mult_mat4f L862-867
function gd_math.gd_mult_mat4f(mA: { { number } }, mB: { { number } }, dst: { { number } })
	gd_math.MAT4_MULTIPLY(mA, mB, MultiplyResult)
	gd_math.gd_copy_mat4f(MultiplyResult, dst)
end

-- from src/goddard/gd_math.c:gd_print_vec L877-882
function gd_math.gd_print_vec(prefix: string, vec: GdTypesH.GdVec3f)
	-- printf is compiled out.
end

-- from src/goddard/gd_math.c:gd_print_bounding_box L889-896
function gd_math.gd_print_bounding_box(prefix: string, p: GdTypesH.GdBoundingBox)
	-- printf is compiled out.
end

-- from src/goddard/gd_math.c:gd_print_mtx L904-914
function gd_math.gd_print_mtx(prefix: string, mtx: { { number } })
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_print_quat L919-927
function gd_math.gd_print_quat(prefix: string, f: { number })
	error("stale")

	return
end

-- from src/goddard/gd_math.c:gd_rot_mat_offset L933-965
function gd_math.gd_rot_mat_offset(dst: { { number } }, x: number, y: number, z: number, copy: number)
	error("stale")

	return
end

return gd_math
