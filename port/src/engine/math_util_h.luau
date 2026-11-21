--!strict
--!optimize 2

--[[
	Port of src/engine/math_util.h.
]]

const Registry = require("../../groups/registry")

const IncludeTrigTablesInc = require("../../include/trig_tables_inc")

-- The sine table literals are decimal text of f32 values: round them like the C f32 load
const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/engine/math_util.h:data
const math_util_h = {
	gCosineTable = { Base = IncludeTrigTablesInc.gSineTable, Offset = 1024 },
}

Registry.Register("src__engine__math_util_h", math_util_h)

-- from src/engine/math_util.h:sins L27-27
function math_util_h.sins(x: number): number
	return F32(Registry.Members.include__trig_tables_inc.gSineTable[bit32.rshift(U16(x), 4) + 1])
end

-- from src/engine/math_util.h:coss L28-28
function math_util_h.coss(x: number): number
	return F32(math_util_h.gCosineTable.Base[math_util_h.gCosineTable.Offset + bit32.rshift(U16(x), 4) + 1])
end

-- from src/engine/math_util.h:min L30-30
function math_util_h.min(a: number, b: number): number
	return if a <= b then a else b
end

-- from src/engine/math_util.h:max L31-31
function math_util_h.max(a: number, b: number): number
	return if a > b then a else b
end

-- from src/engine/math_util.h:sqr L33-33
function math_util_h.sqr(x: number): number
	return F32(x * x)
end

return math_util_h
