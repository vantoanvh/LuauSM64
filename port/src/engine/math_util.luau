--!strict
--!optimize 2

--[[
	Port of src/engine/math_util.c.

	Design Notes
		The C stack temporaries (Vec3f, Mat4, out pointers) are module level scratch tables: no allocation per call.
		gSplineKeyframe is the pointer of the C as { Base, Offset } (0-based offset).
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the native x86-64 reference build, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const LateralDir = { 0, 0, 0 }
const LeftDir = { 0, 0, 0 }
const ForwardDir = { 0, 0, 0 }

const Point0 = { 0, 0, 0 }
const Point1 = { 0, 0, 0 }
const Point2 = { 0, 0, 0 }
const Forward = { 0, 0, 0 }
const XColumn = { 0, 0, 0 }
const YColumn = { 0, 0, 0 }
const ZColumn = { 0, 0, 0 }
const Sp74: { GroupsTypesHPlus3Types.Surface? } = {}

const Temp = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
const Weights = { 0, 0, 0, 0 }

-- from src/engine/math_util.c:data
const math_util = {
	-- from src/engine/math_util.c:gSplineKeyframe L11-11
	gSplineKeyframe = { Base = {} :: { { number } }, Offset = 0 },
	-- from src/engine/math_util.c:gSplineKeyframeFraction L12-12
	gSplineKeyframeFraction = 0,
	-- from src/engine/math_util.c:gSplineState L13-13
	gSplineState = 0,
	CURVE_BEGIN_1 = 1,
	CURVE_BEGIN_2 = 2,
	CURVE_MIDDLE = 3,
	CURVE_END_1 = 4,
	CURVE_END_2 = 5,
}

-- from src/engine/math_util.c:vec3f_copy L28-33
function math_util.vec3f_copy(dest: { number }, src: { number }): unknown
	dest[1] = src[1]
	dest[2] = src[2]
	dest[3] = src[3]

	return dest
end

-- from src/engine/math_util.c:vec3f_set L36-41
function math_util.vec3f_set(dest: { number }, x: number, y: number, z: number): unknown
	x = F32(x)
	y = F32(y)
	z = F32(z)
	dest[1] = x
	dest[2] = y
	dest[3] = z

	return dest
end

-- from src/engine/math_util.c:vec3f_add L44-49
function math_util.vec3f_add(dest: { number }, a: { number }): unknown
	dest[1] = F32(dest[1] + a[1])
	dest[2] = F32(dest[2] + a[2])
	dest[3] = F32(dest[3] + a[3])

	return dest
end

-- from src/engine/math_util.c:vec3f_sum L52-57
function math_util.vec3f_sum(dest: { number }, a: { number }, b: { number }): unknown
	dest[1] = F32(a[1] + b[1])
	dest[2] = F32(a[2] + b[2])
	dest[3] = F32(a[3] + b[3])

	return dest
end

-- from src/engine/math_util.c:vec3s_copy L60-65
function math_util.vec3s_copy(dest: { number }, src: { number }): unknown
	dest[1] = src[1]
	dest[2] = src[2]
	dest[3] = src[3]

	return dest
end

-- from src/engine/math_util.c:vec3s_set L68-73
function math_util.vec3s_set(dest: { number }, x: number, y: number, z: number): unknown
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	dest[1] = S16(x)
	dest[2] = S16(y)
	dest[3] = S16(z)

	return dest
end

-- from src/engine/math_util.c:vec3s_add L76-81
function math_util.vec3s_add(dest: { number }, a: { number }): unknown
	dest[1] = S16(dest[1] + a[1])
	dest[2] = S16(dest[2] + a[2])
	dest[3] = S16(dest[3] + a[3])

	return dest
end

-- from src/engine/math_util.c:vec3s_sum L84-89
function math_util.vec3s_sum(dest: { number }, a: { number }, b: { number }): unknown
	dest[1] = S16(a[1] + b[1])
	dest[2] = S16(a[2] + b[2])
	dest[3] = S16(a[3] + b[3])

	return dest
end

-- from src/engine/math_util.c:vec3s_sub L92-97
function math_util.vec3s_sub(dest: { number }, a: { number }): unknown
	dest[1] = S16(dest[1] - a[1])
	dest[2] = S16(dest[2] - a[2])
	dest[3] = S16(dest[3] - a[3])

	return dest
end

-- from src/engine/math_util.c:vec3s_to_vec3f L100-105
function math_util.vec3s_to_vec3f(dest: { number }, a: { number }): unknown
	dest[1] = a[1]
	dest[2] = a[2]
	dest[3] = a[3]

	return dest
end

-- from src/engine/math_util.c:vec3f_to_vec3s L111-117
function math_util.vec3f_to_vec3s(dest: { number }, a: { number }): unknown
	-- add/subtract 0.5 in order to round to the nearest s32 instead of truncating
	dest[1] = S16(TruncS32(F32(a[1] + (if a[1] > 0 then 0.5 else -0.5))))
	dest[2] = S16(TruncS32(F32(a[2] + (if a[2] > 0 then 0.5 else -0.5))))
	dest[3] = S16(TruncS32(F32(a[3] + (if a[3] > 0 then 0.5 else -0.5))))

	return dest
end

-- from src/engine/math_util.c:find_vector_perpendicular_to_plane L124-129
function math_util.find_vector_perpendicular_to_plane(dest: { number }, a: { number }, b: { number }, c: { number }): unknown
	dest[1] = F32(F32(F32(b[2] - a[2]) * F32(c[3] - b[3])) - F32(F32(c[2] - b[2]) * F32(b[3] - a[3])))
	dest[2] = F32(F32(F32(b[3] - a[3]) * F32(c[1] - b[1])) - F32(F32(c[3] - b[3]) * F32(b[1] - a[1])))
	dest[3] = F32(F32(F32(b[1] - a[1]) * F32(c[2] - b[2])) - F32(F32(c[1] - b[1]) * F32(b[2] - a[2])))

	return dest
end

-- from src/engine/math_util.c:vec3f_cross L132-137
function math_util.vec3f_cross(dest: { number }, a: { number }, b: { number }): unknown
	dest[1] = F32(F32(a[2] * b[3]) - F32(b[2] * a[3]))
	dest[2] = F32(F32(a[3] * b[1]) - F32(b[3] * a[1]))
	dest[3] = F32(F32(a[1] * b[2]) - F32(b[1] * a[2]))

	return dest
end

-- from src/engine/math_util.c:vec3f_normalize L140-148
function math_util.vec3f_normalize(dest: { number }): unknown
	--! Possible division by zero
	const invsqrt = F32(1.0 / F32(math.sqrt(F32(F32(F32(dest[1] * dest[1]) + F32(dest[2] * dest[2])) + F32(dest[3] * dest[3])))))

	dest[1] = F32(dest[1] * invsqrt)
	dest[2] = F32(dest[2] * invsqrt)
	dest[3] = F32(dest[3] * invsqrt)

	return dest
end

-- from src/engine/math_util.c:mtxf_copy L153-161
function math_util.mtxf_copy(dest: { { number } }, src: { { number } })
	for i = 1, 4 do
		for j = 1, 4 do
			dest[i][j] = src[i][j]
		end
	end
end

-- from src/engine/math_util.c:mtxf_identity L166-176
function math_util.mtxf_identity(mtx: { { number } })
	-- initialize everything except the first and last cells to 0, then the diagonal cells to 1
	for i = 1, 4 do
		for j = 1, 4 do
			mtx[i][j] = if i == j then 1 else 0
		end
	end
end

-- from src/engine/math_util.c:mtxf_translate L181-186
function math_util.mtxf_translate(dest: { { number } }, b: { number })
	math_util.mtxf_identity(dest)
	dest[4][1] = b[1]
	dest[4][2] = b[2]
	dest[4][3] = b[3]
end

-- from src/engine/math_util.c:mtxf_lookat L194-266
function math_util.mtxf_lookat(mtx: { { number } }, from: { number }, to: { number }, roll: number)
	roll = S16(TruncS32(roll))
	local dx = F32(to[1] - from[1])
	local dz = F32(to[3] - from[3])

	local invLength = F32(-1.0 / F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz)))))
	dx = F32(dx * invLength)
	dz = F32(dz * invLength)

	local yColY = Registry.Members.src__engine__math_util_h.coss(roll)
	local xColY = F32(Registry.Members.src__engine__math_util_h.sins(roll) * dz)
	local zColY = F32(-Registry.Members.src__engine__math_util_h.sins(roll) * dx)

	local xColZ = F32(to[1] - from[1])
	local yColZ = F32(to[2] - from[2])
	local zColZ = F32(to[3] - from[3])

	invLength = F32(-1.0 / F32(math.sqrt(F32(F32(F32(xColZ * xColZ) + F32(yColZ * yColZ)) + F32(zColZ * zColZ)))))
	xColZ = F32(xColZ * invLength)
	yColZ = F32(yColZ * invLength)
	zColZ = F32(zColZ * invLength)

	local xColX = F32(F32(yColY * zColZ) - F32(zColY * yColZ))
	local yColX = F32(F32(zColY * xColZ) - F32(xColY * zColZ))
	local zColX = F32(F32(xColY * yColZ) - F32(yColY * xColZ))

	invLength = F32(1.0 / F32(math.sqrt(F32(F32(F32(xColX * xColX) + F32(yColX * yColX)) + F32(zColX * zColX)))))

	xColX = F32(xColX * invLength)
	yColX = F32(yColX * invLength)
	zColX = F32(zColX * invLength)

	xColY = F32(F32(yColZ * zColX) - F32(zColZ * yColX))
	yColY = F32(F32(zColZ * xColX) - F32(xColZ * zColX))
	zColY = F32(F32(xColZ * yColX) - F32(yColZ * xColX))

	invLength = F32(1.0 / F32(math.sqrt(F32(F32(F32(xColY * xColY) + F32(yColY * yColY)) + F32(zColY * zColY)))))
	xColY = F32(xColY * invLength)
	yColY = F32(yColY * invLength)
	zColY = F32(zColY * invLength)

	mtx[1][1] = xColX
	mtx[2][1] = yColX
	mtx[3][1] = zColX
	mtx[4][1] = F32(-F32(F32(F32(from[1] * xColX) + F32(from[2] * yColX)) + F32(from[3] * zColX)))

	mtx[1][2] = xColY
	mtx[2][2] = yColY
	mtx[3][2] = zColY
	mtx[4][2] = F32(-F32(F32(F32(from[1] * xColY) + F32(from[2] * yColY)) + F32(from[3] * zColY)))

	mtx[1][3] = xColZ
	mtx[2][3] = yColZ
	mtx[3][3] = zColZ
	mtx[4][3] = F32(-F32(F32(F32(from[1] * xColZ) + F32(from[2] * yColZ)) + F32(from[3] * zColZ)))

	mtx[1][4] = 0
	mtx[2][4] = 0
	mtx[3][4] = 0
	mtx[4][4] = 1
end

-- from src/engine/math_util.c:mtxf_rotate_zxy_and_translate L272-299
function math_util.mtxf_rotate_zxy_and_translate(dest: { { number } }, translate: { number }, rotate: { number })
	const sx = Registry.Members.src__engine__math_util_h.sins(rotate[1])
	const cx = Registry.Members.src__engine__math_util_h.coss(rotate[1])

	const sy = Registry.Members.src__engine__math_util_h.sins(rotate[2])
	const cy = Registry.Members.src__engine__math_util_h.coss(rotate[2])

	const sz = Registry.Members.src__engine__math_util_h.sins(rotate[3])
	const cz = Registry.Members.src__engine__math_util_h.coss(rotate[3])

	dest[1][1] = F32(F32(cy * cz) + F32(F32(sx * sy) * sz))
	dest[2][1] = F32(F32(-cy * sz) + F32(F32(sx * sy) * cz))
	dest[3][1] = F32(cx * sy)
	dest[4][1] = translate[1]

	dest[1][2] = F32(cx * sz)
	dest[2][2] = F32(cx * cz)
	dest[3][2] = -sx
	dest[4][2] = translate[2]

	dest[1][3] = F32(F32(-sy * cz) + F32(F32(sx * cy) * sz))
	dest[2][3] = F32(F32(sy * sz) + F32(F32(sx * cy) * cz))
	dest[3][3] = F32(cx * cy)
	dest[4][3] = translate[3]

	dest[3][4] = 0.0
	dest[2][4] = dest[3][4]
	dest[1][4] = dest[2][4]
	dest[4][4] = 1.0
end

-- from src/engine/math_util.c:mtxf_rotate_xyz_and_translate L305-334
function math_util.mtxf_rotate_xyz_and_translate(dest: { { number } }, b: { number }, c: { number })
	const sx = Registry.Members.src__engine__math_util_h.sins(c[1])
	const cx = Registry.Members.src__engine__math_util_h.coss(c[1])

	const sy = Registry.Members.src__engine__math_util_h.sins(c[2])
	const cy = Registry.Members.src__engine__math_util_h.coss(c[2])

	const sz = Registry.Members.src__engine__math_util_h.sins(c[3])
	const cz = Registry.Members.src__engine__math_util_h.coss(c[3])

	dest[1][1] = F32(cy * cz)
	dest[1][2] = F32(cy * sz)
	dest[1][3] = -sy
	dest[1][4] = 0

	dest[2][1] = F32(F32(F32(sx * sy) * cz) - F32(cx * sz))
	dest[2][2] = F32(F32(F32(sx * sy) * sz) + F32(cx * cz))
	dest[2][3] = F32(sx * cy)
	dest[2][4] = 0

	dest[3][1] = F32(F32(F32(cx * sy) * cz) + F32(sx * sz))
	dest[3][2] = F32(F32(F32(cx * sy) * sz) - F32(sx * cz))
	dest[3][3] = F32(cx * cy)
	dest[3][4] = 0

	dest[4][1] = b[1]
	dest[4][2] = b[2]
	dest[4][3] = b[3]
	dest[4][4] = 1
end

-- from src/engine/math_util.c:mtxf_billboard L342-365
function math_util.mtxf_billboard(dest: { { number } }, mtx: { { number } }, position: { number }, angle: number)
	angle = S16(TruncS32(angle))
	dest[1][1] = Registry.Members.src__engine__math_util_h.coss(angle)
	dest[1][2] = Registry.Members.src__engine__math_util_h.sins(angle)
	dest[1][3] = 0
	dest[1][4] = 0

	dest[2][1] = -dest[1][2]
	dest[2][2] = dest[1][1]
	dest[2][3] = 0
	dest[2][4] = 0

	dest[3][1] = 0
	dest[3][2] = 0
	dest[3][3] = 1
	dest[3][4] = 0

	dest[4][1] = F32(F32(F32(F32(mtx[1][1] * position[1]) + F32(mtx[2][1] * position[2])) + F32(mtx[3][1] * position[3])) + mtx[4][1])
	dest[4][2] = F32(F32(F32(F32(mtx[1][2] * position[1]) + F32(mtx[2][2] * position[2])) + F32(mtx[3][2] * position[3])) + mtx[4][2])
	dest[4][3] = F32(F32(F32(F32(mtx[1][3] * position[1]) + F32(mtx[2][3] * position[2])) + F32(mtx[3][3] * position[3])) + mtx[4][3])
	dest[4][4] = 1
end

-- from src/engine/math_util.c:mtxf_align_terrain_normal L374-407
function math_util.mtxf_align_terrain_normal(dest: { { number } }, upDir: { number }, pos: { number }, yaw: number)
	yaw = S16(TruncS32(yaw))
	math_util.vec3f_set(LateralDir, Registry.Members.src__engine__math_util_h.sins(yaw), 0, Registry.Members.src__engine__math_util_h.coss(yaw))
	math_util.vec3f_normalize(upDir)

	math_util.vec3f_cross(LeftDir, upDir, LateralDir)
	math_util.vec3f_normalize(LeftDir)

	math_util.vec3f_cross(ForwardDir, LeftDir, upDir)
	math_util.vec3f_normalize(ForwardDir)

	dest[1][1] = LeftDir[1]
	dest[1][2] = LeftDir[2]
	dest[1][3] = LeftDir[3]
	dest[4][1] = pos[1]

	dest[2][1] = upDir[1]
	dest[2][2] = upDir[2]
	dest[2][3] = upDir[3]
	dest[4][2] = pos[2]

	dest[3][1] = ForwardDir[1]
	dest[3][2] = ForwardDir[2]
	dest[3][3] = ForwardDir[3]
	dest[4][3] = pos[3]

	dest[1][4] = 0.0
	dest[2][4] = 0.0
	dest[3][4] = 0.0
	dest[4][4] = 1.0
end

-- from src/engine/math_util.c:mtxf_align_terrain_triangle L417-481
function math_util.mtxf_align_terrain_triangle(mtx: { { number } }, pos: { number }, yaw: number, radius: number)
	yaw = S16(TruncS32(yaw))
	radius = F32(radius)
	const minY = F32(-radius * 3)

	Point0[1] = F32(pos[1] + F32(radius * Registry.Members.src__engine__math_util_h.sins(S16(yaw + 0x2AAA))))
	Point0[3] = F32(pos[3] + F32(radius * Registry.Members.src__engine__math_util_h.coss(S16(yaw + 0x2AAA))))
	Point1[1] = F32(pos[1] + F32(radius * Registry.Members.src__engine__math_util_h.sins(S16(yaw + 0x8000))))
	Point1[3] = F32(pos[3] + F32(radius * Registry.Members.src__engine__math_util_h.coss(S16(yaw + 0x8000))))
	Point2[1] = F32(pos[1] + F32(radius * Registry.Members.src__engine__math_util_h.sins(S16(yaw + 0xD555))))
	Point2[3] = F32(pos[3] + F32(radius * Registry.Members.src__engine__math_util_h.coss(S16(yaw + 0xD555))))

	Point0[2] = Registry.Members.src__engine__surface_collision.find_floor(Point0[1], F32(pos[2] + 150), Point0[3], Sp74)
	Point1[2] = Registry.Members.src__engine__surface_collision.find_floor(Point1[1], F32(pos[2] + 150), Point1[3], Sp74)
	Point2[2] = Registry.Members.src__engine__surface_collision.find_floor(Point2[1], F32(pos[2] + 150), Point2[3], Sp74)

	if F32(Point0[2] - pos[2]) < minY then
		Point0[2] = pos[2]
	end

	if F32(Point1[2] - pos[2]) < minY then
		Point1[2] = pos[2]
	end

	if F32(Point2[2] - pos[2]) < minY then
		Point2[2] = pos[2]
	end

	const avgY = F32(F32(F32(Point0[2] + Point1[2]) + Point2[2]) / 3)

	math_util.vec3f_set(Forward,Registry.Members.src__engine__math_util_h.sins(yaw), 0, Registry.Members.src__engine__math_util_h.coss(yaw))
	math_util.find_vector_perpendicular_to_plane(YColumn, Point0, Point1, Point2)
	math_util.vec3f_normalize(YColumn)
	math_util.vec3f_cross(XColumn, YColumn, Forward)
	math_util.vec3f_normalize(XColumn)
	math_util.vec3f_cross(ZColumn, XColumn, YColumn)
	math_util.vec3f_normalize(ZColumn)

	mtx[1][1] = XColumn[1]
	mtx[1][2] = XColumn[2]
	mtx[1][3] = XColumn[3]
	mtx[4][1] = pos[1]

	mtx[2][1] = YColumn[1]
	mtx[2][2] = YColumn[2]
	mtx[2][3] = YColumn[3]
	mtx[4][2] = if avgY < pos[2] then pos[2] else avgY

	mtx[3][1] = ZColumn[1]
	mtx[3][2] = ZColumn[2]
	mtx[3][3] = ZColumn[3]
	mtx[4][3] = pos[3]

	mtx[1][4] = 0
	mtx[2][4] = 0
	mtx[3][4] = 0
	mtx[4][4] = 1
end

-- from src/engine/math_util.c:mtxf_mul L491-533
function math_util.mtxf_mul(dest: { { number } }, a: { { number } }, b: { { number } })
	-- column 0
	local entry0 = a[1][1]
	local entry1 = a[1][2]
	local entry2 = a[1][3]
	Temp[1][1] = F32(F32(F32(entry0 * b[1][1]) + F32(entry1 * b[2][1])) + F32(entry2 * b[3][1]))
	Temp[1][2] = F32(F32(F32(entry0 * b[1][2]) + F32(entry1 * b[2][2])) + F32(entry2 * b[3][2]))
	Temp[1][3] = F32(F32(F32(entry0 * b[1][3]) + F32(entry1 * b[2][3])) + F32(entry2 * b[3][3]))

	-- column 1
	entry0 = a[2][1]
	entry1 = a[2][2]
	entry2 = a[2][3]
	Temp[2][1] = F32(F32(F32(entry0 * b[1][1]) + F32(entry1 * b[2][1])) + F32(entry2 * b[3][1]))
	Temp[2][2] = F32(F32(F32(entry0 * b[1][2]) + F32(entry1 * b[2][2])) + F32(entry2 * b[3][2]))
	Temp[2][3] = F32(F32(F32(entry0 * b[1][3]) + F32(entry1 * b[2][3])) + F32(entry2 * b[3][3]))

	-- column 2
	entry0 = a[3][1]
	entry1 = a[3][2]
	entry2 = a[3][3]
	Temp[3][1] = F32(F32(F32(entry0 * b[1][1]) + F32(entry1 * b[2][1])) + F32(entry2 * b[3][1]))
	Temp[3][2] = F32(F32(F32(entry0 * b[1][2]) + F32(entry1 * b[2][2])) + F32(entry2 * b[3][2]))
	Temp[3][3] = F32(F32(F32(entry0 * b[1][3]) + F32(entry1 * b[2][3])) + F32(entry2 * b[3][3]))

	-- column 3
	entry0 = a[4][1]
	entry1 = a[4][2]
	entry2 = a[4][3]
	Temp[4][1] = F32(F32(F32(F32(entry0 * b[1][1]) + F32(entry1 * b[2][1])) + F32(entry2 * b[3][1])) + b[4][1])
	Temp[4][2] = F32(F32(F32(F32(entry0 * b[1][2]) + F32(entry1 * b[2][2])) + F32(entry2 * b[3][2])) + b[4][2])
	Temp[4][3] = F32(F32(F32(F32(entry0 * b[1][3]) + F32(entry1 * b[2][3])) + F32(entry2 * b[3][3])) + b[4][3])

	Temp[3][4] = 0
	Temp[2][4] = Temp[3][4]
	Temp[1][4] = Temp[2][4]
	Temp[4][4] = 1

	math_util.mtxf_copy(dest, Temp)
end

-- from src/engine/math_util.c:mtxf_scale_vec3f L538-547
function math_util.mtxf_scale_vec3f(dest: { { number } }, mtx: { { number } }, s: { number })
	for i = 1, 4 do
		dest[1][i] = F32(mtx[1][i] * s[1])
		dest[2][i] = F32(mtx[2][i] * s[2])
		dest[3][i] = F32(mtx[3][i] * s[3])
		dest[4][i] = mtx[4][i]
	end
end

-- from src/engine/math_util.c:mtxf_mul_vec3s L554-562
function math_util.mtxf_mul_vec3s(mtx: { { number } }, b: { number })
	const x = b[1]
	const y = b[2]
	const z = b[3]

	b[1] = S16(TruncS32(F32(F32(F32(F32(x * mtx[1][1]) + F32(y * mtx[2][1])) + F32(z * mtx[3][1])) + mtx[4][1])))
	b[2] = S16(TruncS32(F32(F32(F32(F32(x * mtx[1][2]) + F32(y * mtx[2][2])) + F32(z * mtx[3][2])) + mtx[4][2])))
	b[3] = S16(TruncS32(F32(F32(F32(F32(x * mtx[1][3]) + F32(y * mtx[2][3])) + F32(z * mtx[3][3])) + mtx[4][3])))
end

-- from src/engine/math_util.c:mtxf_to_mtx L573-591
function math_util.mtxf_to_mtx(dest: { unknown }, src: { { number } })
	-- guMtxF2L (lib/src/guMtxF2L.c) inlined: dest holds the 16 s32 words of the N64 fixed point matrix, integer parts of two columns beside fraction parts in the second half
	for r = 0, 3 do
		for c = 0, 1 do
			const tmp1 = TruncS32(F32(src[r + 1][2 * c + 1] * 65536.0))
			const tmp2 = TruncS32(F32(src[r + 1][2 * c + 2] * 65536.0))

			dest[r * 2 + c + 1] = S32(bit32.bor(bit32.band(tmp1, 0xFFFF0000), bit32.band(bit32.arshift(tmp2, 0x10), 0xFFFF)))
			dest[r * 2 + c + 9] = S32(bit32.bor(bit32.band(bit32.lshift(tmp1, 0x10), 0xFFFF0000), bit32.band(tmp2, 0xFFFF)))
		end
	end
end

-- from src/engine/math_util.c:mtxf_rotate_xy L596-605
function math_util.mtxf_rotate_xy(mtx: { unknown }, angle: number)
	angle = S16(TruncS32(angle))
	math_util.mtxf_identity(Temp)
	Temp[1][1] = Registry.Members.src__engine__math_util_h.coss(angle)
	Temp[1][2] = Registry.Members.src__engine__math_util_h.sins(angle)
	Temp[2][1] = -Temp[1][2]
	Temp[2][2] = Temp[1][1]
	math_util.mtxf_to_mtx(mtx, Temp)
end

-- from src/engine/math_util.c:get_pos_from_transform_mtx L615-626
function math_util.get_pos_from_transform_mtx(dest: { number }, objMtx: { { number } }, camMtx: { { number } })
	const camX = F32(F32(F32(camMtx[4][1] * camMtx[1][1]) + F32(camMtx[4][2] * camMtx[1][2])) + F32(camMtx[4][3] * camMtx[1][3]))
	const camY = F32(F32(F32(camMtx[4][1] * camMtx[2][1]) + F32(camMtx[4][2] * camMtx[2][2])) + F32(camMtx[4][3] * camMtx[2][3]))
	const camZ = F32(F32(F32(camMtx[4][1] * camMtx[3][1]) + F32(camMtx[4][2] * camMtx[3][2])) + F32(camMtx[4][3] * camMtx[3][3]))

	dest[1] = F32(F32(F32(F32(objMtx[4][1] * camMtx[1][1]) + F32(objMtx[4][2] * camMtx[1][2])) + F32(objMtx[4][3] * camMtx[1][3])) - camX)
	dest[2] = F32(F32(F32(F32(objMtx[4][1] * camMtx[2][1]) + F32(objMtx[4][2] * camMtx[2][2])) + F32(objMtx[4][3] * camMtx[2][3])) - camY)
	dest[3] = F32(F32(F32(F32(objMtx[4][1] * camMtx[3][1]) + F32(objMtx[4][2] * camMtx[3][2])) + F32(objMtx[4][3] * camMtx[3][3])) - camZ)
end

-- from src/engine/math_util.c:vec3f_get_dist_and_angle L633-641
function math_util.vec3f_get_dist_and_angle(from: { number }, to: { number }, dist: { number }, pitch: { number }, yaw: { number })
	const x = F32(to[1] - from[1])
	const y = F32(to[2] - from[2])
	const z = F32(to[3] - from[3])

	dist[1] = F32(math.sqrt(F32(F32(F32(x * x) + F32(y * y)) + F32(z * z))))
	pitch[1] = math_util.atan2s(F32(math.sqrt(F32(F32(x * x) + F32(z * z)))), y)
	yaw[1] = math_util.atan2s(z, x)
end

-- from src/engine/math_util.c:vec3f_set_dist_and_angle L647-651
function math_util.vec3f_set_dist_and_angle(from: { number }, to: { number }, dist: number, pitch: number, yaw: number)
	dist = F32(dist)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	to[1] = F32(from[1] + F32(F32(dist * Registry.Members.src__engine__math_util_h.coss(pitch)) * Registry.Members.src__engine__math_util_h.sins(yaw)))
	to[2] = F32(from[2] + F32(dist * Registry.Members.src__engine__math_util_h.sins(pitch)))
	to[3] = F32(from[3] + F32(F32(dist * Registry.Members.src__engine__math_util_h.coss(pitch)) * Registry.Members.src__engine__math_util_h.coss(yaw)))
end

-- from src/engine/math_util.c:approach_s32 L657-673
function math_util.approach_s32(current: number, target: number, inc: number, dec: number): number
	--! If target is close to the max or min s32, then it's possible to overflow
	-- past it without stopping.

	if current < target then
		current = S32(current + inc)

		if current > target then
			current = target
		end
	else
		current = S32(current - dec)

		if current < target then
			current = target
		end
	end

	return current
end

-- from src/engine/math_util.c:approach_f32 L679-692
function math_util.approach_f32(current: number, target: number, inc: number, dec: number): number
	current = F32(current)
	target = F32(target)
	inc = F32(inc)
	dec = F32(dec)
	if current < target then
		current = F32(current + inc)

		if current > target then
			current = target
		end
	else
		current = F32(current - dec)

		if current < target then
			current = target
		end
	end

	return current
end

-- from src/engine/math_util.c:atan2_lookup L698-707
function math_util.atan2_lookup(y: number, x: number): number
	y = F32(y)
	x = F32(x)
	local ret: number

	if x == 0 then
		ret = U16(Registry.Members.include__trig_tables_inc.gArctanTable[1])
	else
		ret = U16(Registry.Members.include__trig_tables_inc.gArctanTable[TruncS32(F32(F32(F32(y / x) * 1024) + 0.5)) + 1])
	end

	return ret
end

-- from src/engine/math_util.c:atan2s L713-749
function math_util.atan2s(y: number, x: number): number
	y = F32(y)
	x = F32(x)
	local ret: number

	if x >= 0 then
		if y >= 0 then
			if y >= x then
				ret = math_util.atan2_lookup(x, y)
			else
				ret = U16(0x4000 - math_util.atan2_lookup(y, x))
			end
		else
			y = -y

			if y < x then
				ret = U16(0x4000 + math_util.atan2_lookup(y, x))
			else
				ret = U16(0x8000 - math_util.atan2_lookup(x, y))
			end
		end
	else
		x = -x

		if y < 0 then
			y = -y

			if y >= x then
				ret = U16(0x8000 + math_util.atan2_lookup(x, y))
			else
				ret = U16(0xC000 - math_util.atan2_lookup(y, x))
			end
		else
			if y < x then
				ret = U16(0xC000 + math_util.atan2_lookup(y, x))
			else
				ret = U16(-math_util.atan2_lookup(x, y))
			end
		end
	end

	return S16(ret)
end

-- from src/engine/math_util.c:atan2f L754-756
function math_util.atan2f(y: number, x: number): number
	y = F32(y)
	x = F32(x)
	return F32(math_util.atan2s(y, x) * math.pi / 0x8000)
end

-- from src/engine/math_util.c:spline_get_weights L788-827
function math_util.spline_get_weights(result: { number }, t: number, c: number)
	t = F32(t)
	const tinv = F32(1 - t)
	const tinv2 = F32(tinv * tinv)
	const tinv3 = F32(tinv2 * tinv)
	const t2 = F32(t * t)
	const t3 = F32(t2 * t)

	if math_util.gSplineState == math_util.CURVE_BEGIN_1 then
		result[1] = tinv3
		result[2] = F32(F32(F32(t3 * 1.75) - F32(t2 * 4.5)) + F32(t * 3.0))
		result[3] = F32(F32(-t3 * F32(11 / 12)) + F32(t2 * 1.5))
		result[4] = F32(t3 * F32(1 / 6))
	elseif math_util.gSplineState == math_util.CURVE_BEGIN_2 then
		result[1] = F32(tinv3 * 0.25)
		result[2] = F32(F32(F32(F32(t3 * F32(7 / 12)) - F32(t2 * 1.25)) + F32(t * 0.25)) + F32(7 / 12))
		result[3] = F32(F32(F32(F32(-t3 * 0.5) + F32(t2 * 0.5)) + F32(t * 0.5)) + F32(1 / 6))
		result[4] = F32(t3 * F32(1 / 6))
	elseif math_util.gSplineState == math_util.CURVE_MIDDLE then
		result[1] = F32(tinv3 * F32(1 / 6))
		result[2] = F32(F32(F32(t3 * 0.5) - t2) + F32(4 / 6))
		result[3] = F32(F32(F32(F32(-t3 * 0.5) + F32(t2 * 0.5)) + F32(t * 0.5)) + F32(1 / 6))
		result[4] = F32(t3 * F32(1 / 6))
	elseif math_util.gSplineState == math_util.CURVE_END_1 then
		result[1] = F32(tinv3 * F32(1 / 6))
		result[2] = F32(F32(F32(F32(-tinv3 * 0.5) + F32(tinv2 * 0.5)) + F32(tinv * 0.5)) + F32(1 / 6))
		result[3] = F32(F32(F32(F32(tinv3 * F32(7 / 12)) - F32(tinv2 * 1.25)) + F32(tinv * 0.25)) + F32(7 / 12))
		result[4] = F32(t3 * 0.25)
	elseif math_util.gSplineState == math_util.CURVE_END_2 then
		result[1] = F32(tinv3 * F32(1 / 6))
		result[2] = F32(F32(-tinv3 * F32(11 / 12)) + F32(tinv2 * 1.5))
		result[3] = F32(F32(F32(tinv3 * 1.75) - F32(tinv2 * 4.5)) + F32(tinv * 3.0))
		result[4] = t3
	end
end

-- from src/engine/math_util.c:anim_spline_init L837-841
function math_util.anim_spline_init(keyFrames: { { number } })
	math_util.gSplineKeyframe.Base = keyFrames
	math_util.gSplineKeyframe.Offset = 0
	math_util.gSplineKeyframeFraction = 0
	math_util.gSplineState = 1
end

-- from src/engine/math_util.c:anim_spline_poll L848-880
function math_util.anim_spline_poll(result: { number }): number
	local hasEnded = 0

	math_util.vec3f_copy(result, Registry.Members.src__engine__graph_node.gVec3fZero)
	math_util.spline_get_weights(Weights, math_util.gSplineKeyframeFraction, math_util.gSplineState)

	for i = 0, 3 do
		const keyFrame = math_util.gSplineKeyframe.Base[math_util.gSplineKeyframe.Offset + i + 1]

		result[1] = F32(result[1] + F32(Weights[i + 1] * keyFrame[2]))
		result[2] = F32(result[2] + F32(Weights[i + 1] * keyFrame[3]))
		result[3] = F32(result[3] + F32(Weights[i + 1] * keyFrame[4]))
	end

	math_util.gSplineKeyframeFraction = F32(math_util.gSplineKeyframeFraction + F32(math_util.gSplineKeyframe.Base[math_util.gSplineKeyframe.Offset + 1][1] / 1000))

	if math_util.gSplineKeyframeFraction >= 1 then
		math_util.gSplineKeyframe.Offset += 1
		math_util.gSplineKeyframeFraction = F32(math_util.gSplineKeyframeFraction - 1)

		if math_util.gSplineState == math_util.CURVE_END_2 then
			hasEnded = 1
		elseif math_util.gSplineState == math_util.CURVE_MIDDLE then
			if math_util.gSplineKeyframe.Base[math_util.gSplineKeyframe.Offset + 3][1] == 0 then
				math_util.gSplineState = math_util.CURVE_END_1
			end
		else
			math_util.gSplineState += 1
		end
	end

	return hasEnded
end

return math_util
