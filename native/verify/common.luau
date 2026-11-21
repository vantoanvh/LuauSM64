--!nonstrict
--!optimize 2

--[[
	Shared pieces of the port checks: the fixed-seed generator, the token format of the case and result files, and the diff of
	a result file against the native one.

	Token format
		f32: 8 hex digits of the bit pattern, "nan" for any NaN, "!<value>" when the Luau value is not exactly an f32 (a missed rounding).
		integers: decimal.
]]

const fs = require("@std/fs")
const process = require("@std/process")

const Scratch = buffer.create(4)

const Common = {
	State = 1,
}

function Common.Seed(Seed: number)
	Common.State = Seed
end

-- 32 random bits, a linear congruential generator whose products stay exact in a double
function Common.Next(): number
	Common.State = (Common.State * 1664525 + 1013904223) % 4294967296

	return Common.State
end

-- Integer in [Low, High]; the high bits of the generator, as the low ones are weak
function Common.Range(Low: number, High: number): number
	return Low + (Common.Next() // 4096) % (High - Low + 1)
end

function Common.F32(Value: number): number
	buffer.writef32(Scratch, 0, Value)

	return buffer.readf32(Scratch, 0)
end

const SpecialFloats = { 0, -0.0, 1, -1, 0.5, -0.5, 150, -150, 65536, -65536, 32767, -32768, 8191.5, 1e-30, -1e-30, 3e38, -3e38 }
const SpecialInts = { 0, 1, -1, 2, 32767, -32768, 32766, -32767, 0x4000, -0x4000, 0x8000, 0xFFFF, 0x10000, 0x2AAA }

function Common.RandomF32(): number
	if Common.Range(0, 99) < 12 then
		return Common.F32(SpecialFloats[Common.Range(1, #SpecialFloats)])
	end

	const Unit = Common.Next() / 2147483648 - 1

	return Common.F32(Unit * 10 ^ Common.Range(-2, 5))
end

function Common.RandomS16(): number
	if Common.Range(0, 99) < 10 then
		const Value = SpecialInts[Common.Range(1, #SpecialInts)]

		return if Value > 32767 then Value - 65536 else Value
	end

	return Common.Range(-32768, 32767)
end

-- A C int: past the s16 range, up to the s32 extremes
function Common.RandomS32(): number
	const Pick = Common.Range(0, 99)

	if Pick < 10 then
		return SpecialInts[Common.Range(1, #SpecialInts)]
	elseif Pick < 20 then
		return if Common.Range(0, 1) == 0 then 2147483647 else -2147483648
	end

	return Common.Range(-100000, 100000)
end

function Common.FormatF32(Value: number): string
	if Value ~= Value then
		return "nan"
	end

	buffer.writef32(Scratch, 0, Value)

	if buffer.readf32(Scratch, 0) ~= Value then
		return `!{Value}`
	end

	return string.format("%08x", buffer.readu32(Scratch, 0))
end

function Common.FormatVec(Values: { number }, FormatValue: (number) -> string): { string }
	const Tokens = {}

	for Index, Value in Values do
		Tokens[Index] = FormatValue(Value)
	end

	return Tokens
end

function Common.FormatInt(Value: number): string
	return string.format("%d", Value)
end

-- Runs the native driver on the case lines; returns its result lines
function Common.RunNative(Driver: string, CaseLines: { string }): { string }
	const CasePath = `{process.cwd()}/native/build/verify/cases.txt`

	fs.writeStringToFile(CasePath, table.concat(CaseLines, "\n") .. "\n")

	const Result = process.run({ Driver, CasePath })

	if not Result.ok then
		error(`native driver failed: {Result.stderr}`)
	end

	const Output = string.gsub(Result.stdout, "\r", "")

	return string.split(Output, "\n")
end

-- Compares result lines of the port with the native ones; returns the mismatch count per name and prints the first mismatches
function Common.Diff(CaseLines: { string }, PortLines: { string }, NativeLines: { string }, ReportLimit: number): ({ [string]: number }, { [string]: number })
	const Mismatches: { [string]: number } = {}
	const Totals: { [string]: number } = {}
	local Reported = 0

	for Index, PortLine in PortLines do
		const Name = string.match(PortLine, "^(%S+)") :: string

		Totals[Name] = (Totals[Name] or 0) + 1

		if PortLine ~= NativeLines[Index] then
			Mismatches[Name] = (Mismatches[Name] or 0) + 1

			if Reported < ReportLimit then
				Reported += 1
				print(`MISMATCH line {Index}`)
				print(`  case:   {CaseLines[Index]}`)
				print(`  native: {NativeLines[Index]}`)
				print(`  port:   {PortLine}`)
			end
		end
	end

	return Mismatches, Totals
end

return Common
