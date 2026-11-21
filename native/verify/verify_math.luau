--!nonstrict
--!optimize 2

--[[
	Runs fixed-seed cases through the Luau port of src/engine/math_util and through the native vanilla functions
	(native/build/verify/math_driver.exe), and diffs the results.

	Run from the repository root after native/verify/build.sh: lute run native/verify/verify_math.luau
]]

const process = require("@std/process")

const Common = require("./common")
const GraphNode = require("../../port/src/engine/graph_node")
const MathUtil = require("../../port/src/engine/math_util")
const MathUtilH = require("../../port/src/engine/math_util_h")
const SurfaceCollision = require("../../port/src/engine/surface_collision")

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion of the native x86-64 build: a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- Deterministic stand-in for the surface lookup, mirrored by math_driver.c
function SurfaceCollision.find_floor(xPos: number, yPos: number, zPos: number, pfloor: { unknown }): number
	pfloor[1] = nil

	const Cell = S32(S32(TruncS32(xPos) * 3) + S32(TruncS32(zPos) * 7))

	return Common.F32(Common.F32(math.fmod(Cell, 211) - 100) + Common.F32(yPos - 150))
end

const CasesPerFunction = 300
const ReportLimit = 12

function RandomVec(Kind: string): { number }
	const Values = {}

	for Index = 1, 3 do
		Values[Index] = if Kind == "vs" then Common.RandomS16() else Common.RandomF32()
	end

	return Values
end

function RandomMat(): { { number } }
	const Rows = {}

	for Row = 1, 4 do
		Rows[Row] = {}

		for Column = 1, 4 do
			Rows[Row][Column] = Common.RandomF32()
		end
	end

	return Rows
end

function GenerateArg(Kind: string): unknown
	if Kind == "f" then
		return Common.RandomF32()
	elseif Kind == "s" then
		return Common.RandomS16()
	elseif Kind == "w" then
		return Common.RandomS32()
	elseif Kind == "m" then
		return RandomMat()
	end

	return RandomVec(Kind)
end

function ArgTokens(Kind: string, Value: unknown): { string }
	if Kind == "f" then
		return { Common.FormatF32(Value) }
	elseif Kind == "s" or Kind == "w" then
		return { Common.FormatInt(Value) }
	elseif Kind == "v" then
		return Common.FormatVec(Value, Common.FormatF32)
	elseif Kind == "vs" then
		return Common.FormatVec(Value, Common.FormatInt)
	end

	const Tokens = {}

	for Row = 1, 4 do
		for Column = 1, 4 do
			table.insert(Tokens, Common.FormatF32(Value[Row][Column]))
		end
	end

	return Tokens
end

function MatTokens(Mat: { { number } }): { string }
	return ArgTokens("m", Mat)
end

function VecTokens(Vec: { number }): { string }
	return ArgTokens("v", Vec)
end

function ShortTokens(Vec: { number }): { string }
	return ArgTokens("vs", Vec)
end

function F(Value: number): { string }
	return { Common.FormatF32(Value) }
end

function I(Value: number): { string }
	return { Common.FormatInt(Value) }
end

-- Argument kinds: f f32, s s16, w wide int, v Vec3f, vs Vec3s, m Mat4. Run returns the result tokens.
const Cases = {
	{
			Name = "vec3f_copy", Kinds = { "v", "v" }, Run = function(A)
	MathUtil.vec3f_copy(A[1], A[2])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_set", Kinds = { "v", "f", "f", "f" }, Run = function(A)
	MathUtil.vec3f_set(A[1], A[2], A[3], A[4])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_add", Kinds = { "v", "v" }, Run = function(A)
	MathUtil.vec3f_add(A[1], A[2])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_sum", Kinds = { "v", "v", "v" }, Run = function(A)
	MathUtil.vec3f_sum(A[1], A[2], A[3])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3s_copy", Kinds = { "vs", "vs" }, Run = function(A)
	MathUtil.vec3s_copy(A[1], A[2])

	return ShortTokens(A[1])
		end },
	{
			Name = "vec3s_set", Kinds = { "vs", "w", "w", "w" }, Run = function(A)
	MathUtil.vec3s_set(A[1], A[2], A[3], A[4])

	return ShortTokens(A[1])
		end },
	{
			Name = "vec3s_add", Kinds = { "vs", "vs" }, Run = function(A)
	MathUtil.vec3s_add(A[1], A[2])

	return ShortTokens(A[1])
		end },
	{
			Name = "vec3s_sum", Kinds = { "vs", "vs", "vs" }, Run = function(A)
	MathUtil.vec3s_sum(A[1], A[2], A[3])

	return ShortTokens(A[1])
		end },
	{
			Name = "vec3s_sub", Kinds = { "vs", "vs" }, Run = function(A)
	MathUtil.vec3s_sub(A[1], A[2])

	return ShortTokens(A[1])
		end },
	{
			Name = "vec3s_to_vec3f", Kinds = { "v", "vs" }, Run = function(A)
	MathUtil.vec3s_to_vec3f(A[1], A[2])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_to_vec3s", Kinds = { "vs", "v" }, Run = function(A)
	MathUtil.vec3f_to_vec3s(A[1], A[2])

	return ShortTokens(A[1])
		end },
	{
			Name = "find_vector_perpendicular_to_plane", Kinds = { "v", "v", "v", "v" }, Run = function(A)
	MathUtil.find_vector_perpendicular_to_plane(A[1], A[2], A[3], A[4])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_cross", Kinds = { "v", "v", "v" }, Run = function(A)
	MathUtil.vec3f_cross(A[1], A[2], A[3])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_normalize", Kinds = { "v" }, Run = function(A)
	MathUtil.vec3f_normalize(A[1])

	return VecTokens(A[1])
		end },
	{
			Name = "mtxf_copy", Kinds = { "m", "m" }, Run = function(A)
	MathUtil.mtxf_copy(A[1], A[2])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_identity", Kinds = { "m" }, Run = function(A)
	MathUtil.mtxf_identity(A[1])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_translate", Kinds = { "m", "v" }, Run = function(A)
	MathUtil.mtxf_translate(A[1], A[2])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_lookat", Kinds = { "m", "v", "v", "w" }, Run = function(A)
	MathUtil.mtxf_lookat(A[1], A[2], A[3], A[4])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_rotate_zxy_and_translate", Kinds = { "m", "v", "vs" }, Run = function(A)
	MathUtil.mtxf_rotate_zxy_and_translate(A[1], A[2], A[3])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_rotate_xyz_and_translate", Kinds = { "m", "v", "vs" }, Run = function(A)
	MathUtil.mtxf_rotate_xyz_and_translate(A[1], A[2], A[3])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_billboard", Kinds = { "m", "m", "v", "w" }, Run = function(A)
	MathUtil.mtxf_billboard(A[1], A[2], A[3], A[4])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_align_terrain_normal",
			Kinds = { "m", "v", "v", "w" },
			Run = function(A)
	MathUtil.mtxf_align_terrain_normal(A[1], A[2], A[3], A[4])

	const Tokens = MatTokens(A[1])

	table.move(VecTokens(A[2]), 1, 3, #Tokens + 1, Tokens)

	return Tokens
end,
		},
	{
			Name = "mtxf_align_terrain_triangle", Kinds = { "m", "v", "w", "f" }, Run = function(A)
	MathUtil.mtxf_align_terrain_triangle(A[1], A[2], A[3], A[4])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_mul", Kinds = { "m", "m", "m" }, Run = function(A)
	MathUtil.mtxf_mul(A[1], A[2], A[3])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_scale_vec3f", Kinds = { "m", "m", "v" }, Run = function(A)
	MathUtil.mtxf_scale_vec3f(A[1], A[2], A[3])

	return MatTokens(A[1])
		end },
	{
			Name = "mtxf_mul_vec3s", Kinds = { "m", "vs" }, Run = function(A)
	MathUtil.mtxf_mul_vec3s(A[1], A[2])

	return ShortTokens(A[2])
		end },
	{
			Name = "mtxf_to_mtx",
			Kinds = { "m" },
			Run = function(A)
	const Dest = table.create(16, 0)

	MathUtil.mtxf_to_mtx(Dest, A[1])

	return Common.FormatVec(Dest, Common.FormatInt)
end,
		},
	{
			Name = "mtxf_rotate_xy",
			Kinds = { "w" },
			Run = function(A)
	const Dest = table.create(16, 0)

	MathUtil.mtxf_rotate_xy(Dest, A[1])

	return Common.FormatVec(Dest, Common.FormatInt)
end,
		},
	{
			Name = "get_pos_from_transform_mtx", Kinds = { "v", "m", "m" }, Run = function(A)
	MathUtil.get_pos_from_transform_mtx(A[1], A[2], A[3])

	return VecTokens(A[1])
		end },
	{
			Name = "vec3f_get_dist_and_angle",
			Kinds = { "v", "v" },
			Run = function(A)
	const Dist = { 0 }
	const Pitch = { 0 }
	const Yaw = { 0 }

	MathUtil.vec3f_get_dist_and_angle(A[1], A[2], Dist, Pitch, Yaw)

	return { Common.FormatF32(Dist[1]), Common.FormatInt(Pitch[1]), Common.FormatInt(Yaw[1]) }
end,
		},
	{
			Name = "vec3f_set_dist_and_angle", Kinds = { "v", "v", "f", "w", "w" }, Run = function(A)
	MathUtil.vec3f_set_dist_and_angle(A[1], A[2], A[3], A[4], A[5])

	return VecTokens(A[2])
		end },
	{
			Name = "approach_s32", Kinds = { "w", "w", "w", "w" }, Run = function(A)
	return I(MathUtil.approach_s32(A[1], A[2], A[3], A[4]))
		end },
	{
			Name = "approach_f32", Kinds = { "f", "f", "f", "f" }, Run = function(A)
	return F(MathUtil.approach_f32(A[1], A[2], A[3], A[4]))
		end },
	{
			Name = "atan2_lookup", Kinds = { "lookup" }, Run = function(A)
	return I(MathUtil.atan2_lookup(A[1][1], A[1][2]))
		end },
	{
			Name = "atan2s", Kinds = { "angle" }, Run = function(A)
	return I(MathUtil.atan2s(A[1][1], A[1][2]))
		end },
	{
			Name = "atan2f", Kinds = { "angle" }, Run = function(A)
	return F(MathUtil.atan2f(A[1][1], A[1][2]))
		end },
	{
			Name = "sins", Kinds = { "w" }, Run = function(A)
	return F(MathUtilH.sins(A[1]))
		end },
	{
			Name = "coss", Kinds = { "w" }, Run = function(A)
	return F(MathUtilH.coss(A[1]))
		end },
	{
			Name = "spline_get_weights",
			Kinds = { "state", "unit" },
			Run = function(A)
	const Weights = { 0, 0, 0, 0 }

	MathUtil.gSplineState = A[1]
	MathUtil.spline_get_weights(Weights, A[2], 0)

	return VecTokens(Weights)
end,
		},
	{
			Name = "spline",
			Kinds = { "keyframes" },
			Run = function(A)
	const Keyframes = {}
	const Result = { 0, 0, 0 }
	const Tokens = {}

	for Index = 1, 64 do
		Keyframes[Index] = A[1][Index] or { 0, 0, 0, 0 }
	end

	MathUtil.anim_spline_init(Keyframes)

	for Poll = 1, 300 do
		const Ended = MathUtil.anim_spline_poll(Result)

		table.move(VecTokens(Result), 1, 3, #Tokens + 1, Tokens)
		table.insert(Tokens, Common.FormatInt(Ended))

		if Ended ~= 0 then
			break
		end
	end

	return Tokens
end,
		},
}

-- Arguments that need more than a random value of their kind
function GenerateSpecial(Kind: string): ({ unknown }, { string })
	if Kind == "lookup" or Kind == "angle" then
		-- lookup: 0 <= y <= x, the domain atan2s gives it; angle: any finite pair, often equal magnitudes
		const First = Common.RandomF32()
		const Second = if Common.Range(0, 3) == 0 then First else Common.RandomF32()
		const Y = if Kind == "lookup" then math.min(math.abs(First), math.abs(Second)) else First
		const X = if Kind == "lookup" then math.max(math.abs(First), math.abs(Second)) else if Common.Range(0, 1) == 0 then Second else -Second

		return { { Y, X } }, { Common.FormatF32(Y), Common.FormatF32(X) }
	elseif Kind == "state" then
		const State = Common.Range(1, 5)

		return { State }, { Common.FormatInt(State) }
	elseif Kind == "unit" then
		const Value = if Common.Range(0, 3) == 0 then Common.RandomF32() else Common.F32(Common.Next() / 4294967296)

		return { Value }, { Common.FormatF32(Value) }
	end

	-- keyframes: speed, x, y, z, ending in three frames of speed 0
	const Speeds = { 100, 125, 250, 333, 500, 1000, 77 }
	const Count = Common.Range(1, 5) + 3
	const Keyframes = {}
	const Tokens = { Common.FormatInt(Count) }

	for Index = 1, Count do
		Keyframes[Index] = { if Index > Count - 3 then 0 else Speeds[Common.Range(1, #Speeds)], Common.RandomS16(), Common.RandomS16(), Common.RandomS16() }
		table.move(Common.FormatVec(Keyframes[Index], Common.FormatInt), 1, 4, #Tokens + 1, Tokens)
	end

	return { Keyframes }, Tokens
end

Common.Seed(64)

const CaseLines = {}
const PortLines = {}

for _, Case in Cases do
	for _ = 1, CasesPerFunction do
		const Args = {}
		const Tokens = {}

		for _, Kind in Case.Kinds do
			if Kind == "lookup" or Kind == "angle" or Kind == "state" or Kind == "unit" or Kind == "keyframes" then
				const Values, ArgumentTokens = GenerateSpecial(Kind)

				table.insert(Args, Values[1])
				table.move(ArgumentTokens, 1, #ArgumentTokens, #Tokens + 1, Tokens)
			else
				const Value = GenerateArg(Kind)
				const ArgumentTokens = ArgTokens(Kind, Value)

				table.insert(Args, Value)
				table.move(ArgumentTokens, 1, #ArgumentTokens, #Tokens + 1, Tokens)
			end
		end

		table.insert(CaseLines, `{Case.Name} {table.concat(Tokens, " ")}`)
		table.insert(PortLines, `{Case.Name} {table.concat(Case.Run(Args), " ")}`)
	end
end

const NativeLines = Common.RunNative(`{process.cwd()}/native/build/verify/math_driver.exe`, CaseLines)
const Mismatches, Totals = Common.Diff(CaseLines, PortLines, NativeLines, ReportLimit)

local TotalMismatches = 0

for _, Case in Cases do
	const Count = Mismatches[Case.Name] or 0

	TotalMismatches += Count
	print(`{Case.Name}: {Count} / {Totals[Case.Name]} mismatches`)
end

print(`total mismatches: {TotalMismatches} / {#PortLines}`)
