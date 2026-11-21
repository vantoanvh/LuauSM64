--!strict
--!optimize 2

--[[
	Port of src/goddard/debug_utils.c.
]]

const Registry = require("../../groups/registry")

const DebugUtilsH = require("./debug_utils_h")
const DrawObjectsH = require("./draw_objects_h")

-- from src/goddard/debug_utils.c:UnkBufThing
export type UnkBufThing = {
	size: number,
	name: buffer, -- [64]
}

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/goddard/debug_utils.luau:scratch
const function CStringByte(Text: string | buffer, Offset: number): number
	if type(Text) == "string" then
		return string.byte(Text, Offset + 1) or 0
	end

	return if Offset < buffer.len(Text) then buffer.readu8(Text, Offset) else 0
end

-- from src/goddard/debug_utils.c:data
const debug_utils = {
	-- from src/goddard/debug_utils.c:sNumRoutinesInStack L17-17
	sNumRoutinesInStack = 0,
	-- from src/goddard/debug_utils.c:sTimerGadgetColours L18-26
	sTimerGadgetColours = {
		DrawObjectsH.COLOUR_RED,
		DrawObjectsH.COLOUR_WHITE,
		DrawObjectsH.COLOUR_GREEN,
		DrawObjectsH.COLOUR_BLUE,
		DrawObjectsH.COLOUR_GRAY,
		DrawObjectsH.COLOUR_YELLOW,
		DrawObjectsH.COLOUR_PINK,
	},
	-- from src/goddard/debug_utils.c:sNumActiveMemTrackers L27-27
	sNumActiveMemTrackers = 0,
	-- from src/goddard/debug_utils.c:sPrimarySeed L28-28
	sPrimarySeed = 0x12345678,
	-- from src/goddard/debug_utils.c:sSecondarySeed L29-29
	sSecondarySeed = 0x58374895,
	-- from src/goddard/debug_utils.c:gGdStreamBuffer L32-32
	gGdStreamBuffer = nil :: buffer?,
	-- from src/goddard/debug_utils.c:sRoutineNames L33-33
	sRoutineNames = {
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	} :: { buffer },
	-- from src/goddard/debug_utils.c:sTimingActive L34-34
	sTimingActive = 0,
	-- from src/goddard/debug_utils.c:sTimers L35-35
	sTimers = {
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
		{
			start = 0,
			end_ = 0,
			total = 0,
			unused = 0,
			scaledTotal = 0,
			prevScaledTotal = 0,
			name = nil,
			gadgetColourNum = 0,
			resetCount = 0,
		},
	} :: { DebugUtilsH.GdTimer },
	-- from src/goddard/debug_utils.c:sMemTrackers L36-36
	sMemTrackers = {
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
		{ name = nil, begin = 0, end_ = 0, total = 0 },
	} :: { DebugUtilsH.MemTracker },
	-- from src/goddard/debug_utils.c:sActiveMemTrackers L37-37
	sActiveMemTrackers = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil } :: { DebugUtilsH.MemTracker? },
	-- from src/goddard/debug_utils.c:sHexNumerals L630-630
	sHexNumerals = { "0123456789ABCDEF" },
	-- from src/goddard/debug_utils.c:sPadNumPrint L645-645
	sPadNumPrint = 0,
}

Registry.Register("src__goddard__debug_utils", debug_utils)

-- from src/goddard/debug_utils.c:UnkBufThing (zero-filled constructor)
function debug_utils.new_UnkBufThing(): UnkBufThing
	return { size = 0, name = buffer.create(64) } :: UnkBufThing
end

-- from src/goddard/debug_utils.c:new_memtracker L56-73
function debug_utils.new_memtracker(name: string): DebugUtilsH.MemTracker?
	error("stale")
end

-- from src/goddard/debug_utils.c:get_memtracker L79-91
function debug_utils.get_memtracker(name: string): DebugUtilsH.MemTracker?
	error("stale")
end

-- from src/goddard/debug_utils.c:start_memtracker L96-115
function debug_utils.start_memtracker(name: string): DebugUtilsH.MemTracker?
	error("stale")
end

-- from src/goddard/debug_utils.c:print_most_recent_memtracker_name L118-120
function debug_utils.print_most_recent_memtracker_name()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:stop_memtracker L125-141
function debug_utils.stop_memtracker(name: string): number
	error("stale")
end

-- from src/goddard/debug_utils.c:remove_all_memtrackers L146-159
function debug_utils.remove_all_memtrackers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:get_memtracker_by_index L164-166
function debug_utils.get_memtracker_by_index(index: number): DebugUtilsH.MemTracker
	error("stale")
end

-- from src/goddard/debug_utils.c:print_all_memtrackers L171-179
function debug_utils.print_all_memtrackers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:print_all_timers L192-202
function debug_utils.print_all_timers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:deactivate_timing L205-207
function debug_utils.deactivate_timing()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:activate_timing L210-212
function debug_utils.activate_timing()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:remove_all_timers L217-230
function debug_utils.remove_all_timers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:new_timer L235-248
function debug_utils.new_timer(name: string): DebugUtilsH.GdTimer?
	error("stale")
end

-- from src/goddard/debug_utils.c:get_timer L253-265
function debug_utils.get_timer(timerName: string): DebugUtilsH.GdTimer?
	error("stale")
end

-- from src/goddard/debug_utils.c:get_timer_checked L271-280
function debug_utils.get_timer_checked(timerName: string): DebugUtilsH.GdTimer?
	error("stale")
end

-- from src/goddard/debug_utils.c:get_timernum L285-291
function debug_utils.get_timernum(index: number): DebugUtilsH.GdTimer
	error("stale")
end

-- from src/goddard/debug_utils.c:split_timer_ptr L294-308
function debug_utils.split_timer_ptr(timer: DebugUtilsH.GdTimer)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:split_all_timers L311-321
function debug_utils.split_all_timers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:start_all_timers L326-341
function debug_utils.start_all_timers()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:start_timer L346-366
function debug_utils.start_timer(name: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:restart_timer L371-389
function debug_utils.restart_timer(name: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:split_timer L395-404
function debug_utils.split_timer(name: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:stop_timer L409-424
function debug_utils.stop_timer(name: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:get_scaled_timer_total L429-433
function debug_utils.get_scaled_timer_total(name: string): number
	error("stale")
end

-- from src/goddard/debug_utils.c:get_timer_total L438-442
function debug_utils.get_timer_total(name: string): number
	error("stale")
end

-- from src/goddard/debug_utils.c:fatal_print L453-455
function debug_utils.fatal_print(str: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:print_stack_trace L460-466
function debug_utils.print_stack_trace()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:fatal_printf L471-520
function debug_utils.fatal_printf(fmt: string, ...: unknown)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:imin L526-533
function debug_utils.imin(routine: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:imout L539-553
function debug_utils.imout()
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:gd_rand_float L559-583
function debug_utils.gd_rand_float(): number
	for Index = 1, 4 do
		if bit32.btest(debug_utils.sPrimarySeed, 0x80000000) then
			debug_utils.sPrimarySeed = bit32.bor(bit32.lshift(debug_utils.sPrimarySeed, 1), 1)
		else
			debug_utils.sPrimarySeed = bit32.lshift(debug_utils.sPrimarySeed, 1)
		end
	end

	debug_utils.sPrimarySeed = U32(debug_utils.sPrimarySeed + 4)

	const Time: number = Registry.Members.src__goddard__renderer.gd_get_ostime()

	debug_utils.sPrimarySeed = bit32.bxor(debug_utils.sPrimarySeed, Time)

	if bit32.btest(debug_utils.sPrimarySeed, 1) then
		debug_utils.sPrimarySeed, debug_utils.sSecondarySeed = debug_utils.sSecondarySeed, debug_utils.sPrimarySeed
	end

	return F32(bit32.band(debug_utils.sPrimarySeed, 0xFFFF) / 65535.0)
end

-- from src/goddard/debug_utils.c:gd_atoi L588-621
function debug_utils.gd_atoi(str: string): number
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_lazy_atof L626-628
function debug_utils.gd_lazy_atof(str: string, unk: { number }): number
	error("stale")
end

-- from src/goddard/debug_utils.c:format_number_hex L633-643
function debug_utils.format_number_hex(str: string, val: number): string
	error("stale")
end

-- from src/goddard/debug_utils.c:format_number_decimal L649-688
function debug_utils.format_number_decimal(str: string, val: number, padnum: number): string
	if val == 0 then
		return `{str}0`
	end

	if val < 0 then
		val = S32(-val)
		str = `{str}-`
	end

	while padnum > 0 do
		if padnum <= val then
			debug_utils.sPadNumPrint = 1

			local Digit = 0

			while Digit < 9 do
				val -= padnum

				if val < 0 then
					val += padnum
					break
				end

				Digit += 1
			end

			str = `{str}{string.char(Digit + 48)}`
		elseif debug_utils.sPadNumPrint ~= 0 then
			str = `{str}0`
		end

		padnum //= 10
	end

	return str
end

-- from src/goddard/debug_utils.c:int_sci_notation L691-699
function debug_utils.int_sci_notation(base: number, significand: number): number
	for Index = 1, significand - 1 do
		base = S32(base * 10)
	end

	return base
end

-- from src/goddard/debug_utils.c:sprint_val_withspecifiers L702-741
function debug_utils.sprint_val_withspecifiers(str: string, val: DebugUtilsH.PrintVal, specifiers: string): string
	local FractionPrecision = 6
	local IntegerPrecision = 6
	local Offset = 0
	local Specifier = CStringByte(specifiers, Offset)

	while Specifier ~= 0 do
		Offset += 1

		if Specifier == string.byte("d") then
			debug_utils.sPadNumPrint = 0
			str = debug_utils.format_number_decimal(str, val.i, 1000000000)
		elseif Specifier == string.byte("x") then
			debug_utils.sPadNumPrint = 1
			str = `{str}{string.format("%08X", U32(val.i))}`
		elseif Specifier == string.byte("f") then
			const Value = F32(val.f)
			const Integer = TruncS32(Value)
			const Fraction = TruncS32(F32(F32(Value - F32(Integer)) * F32(debug_utils.int_sci_notation(10, FractionPrecision))))

			debug_utils.sPadNumPrint = 0
			str = debug_utils.format_number_decimal(str, Integer, debug_utils.int_sci_notation(10, IntegerPrecision))
			str = `{str}.`
			debug_utils.sPadNumPrint = 1
			str = debug_utils.format_number_decimal(str, Fraction, debug_utils.int_sci_notation(10, FractionPrecision - 1))
		elseif Specifier >= 48 and Specifier <= 57 then
			IntegerPrecision = Specifier - 48

			const Separator = CStringByte(specifiers, Offset)

			Offset += 1

			if Separator ~= 0 then
				FractionPrecision = CStringByte(specifiers, Offset) - 48
				Offset += 1
			end
		else
			str = `{str}<BAD TYPE>`
		end

		Specifier = CStringByte(specifiers, Offset)
	end

	return str
end

-- from src/goddard/debug_utils.c:gd_strcpy L744-748
function debug_utils.gd_strcpy(dst: buffer, src: string | buffer)
	const Length = debug_utils.gd_strlen(src)

	assert(Length < buffer.len(dst), "Goddard string exceeds its destination buffer")

	for Offset = 0, Length - 1 do
		buffer.writeu8(dst, Offset, CStringByte(src, Offset))
	end

	buffer.writeu8(dst, Length, 0)
end

-- from src/goddard/debug_utils.c:ascii_to_uppercase L751-760
function debug_utils.ascii_to_uppercase(str: string)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:gd_strdup L763-774
function debug_utils.gd_strdup(src: string): string?
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_strlen L777-785
function debug_utils.gd_strlen(str: string | buffer): number
	local Length = 0

	while CStringByte(str, Length) ~= 0 do
		Length += 1
	end

	return Length
end

-- from src/goddard/debug_utils.c:gd_strcat L788-801
function debug_utils.gd_strcat(dst: string | buffer, src: string | buffer): string
	const DestinationLength = debug_utils.gd_strlen(dst)
	const SourceLength = debug_utils.gd_strlen(src)
	const Source = if type(src) == "string" then string.sub(src, 1, SourceLength) else buffer.readstring(src, 0, SourceLength)

	if type(dst) == "string" then
		return `{string.sub(dst, 1, DestinationLength)}{Source}`
	end

	const Length = DestinationLength + SourceLength

	assert(Length < buffer.len(dst), "Goddard string exceeds its destination buffer")

	buffer.writestring(dst, DestinationLength, Source)
	buffer.writeu8(dst, Length, 0)

	return buffer.readstring(dst, 0, Length)
end

-- from src/goddard/debug_utils.c:gd_str_not_equal L805-813
function debug_utils.gd_str_not_equal(str1: string | buffer, str2: string | buffer): number
	local Offset = 0
	local Left = CStringByte(str1, Offset)
	local Right = CStringByte(str2, Offset)

	while Left ~= 0 and Right ~= 0 do
		if Left ~= Right then
			return 1
		end

		Offset += 1
		Left = CStringByte(str1, Offset)
		Right = CStringByte(str2, Offset)
	end

	return if Left ~= 0 or Right ~= 0 then 1 else 0
end

-- from src/goddard/debug_utils.c:gd_str_contains L816-826
function debug_utils.gd_str_contains(str1: string, str2: string): number
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_feof L829-831
function debug_utils.gd_feof(f: DebugUtilsH.GdFile): number
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_set_feof L834-836
function debug_utils.gd_set_feof(f: DebugUtilsH.GdFile)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:gd_fopen L839-892
function debug_utils.gd_fopen(filename: string, mode: string): DebugUtilsH.GdFile?
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_fread L895-914
function debug_utils.gd_fread(buf: buffer, bytes: number, count: number, f: DebugUtilsH.GdFile): number
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_fclose L917-919
function debug_utils.gd_fclose(f: DebugUtilsH.GdFile)
	error("stale")
	return
end

-- from src/goddard/debug_utils.c:gd_get_file_size L922-924
function debug_utils.gd_get_file_size(f: DebugUtilsH.GdFile): number
	error("stale")
end

-- from src/goddard/debug_utils.c:is_newline L927-929
function debug_utils.is_newline(c: number): number
	error("stale")
end

-- from src/goddard/debug_utils.c:gd_fread_line L932-958
function debug_utils.gd_fread_line(buf: string, size: number, f: DebugUtilsH.GdFile): number
	error("stale")
end

return debug_utils
