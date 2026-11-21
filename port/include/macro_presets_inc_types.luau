--!strict
--!optimize 2

--[[
	Types of include/macro_presets_inc.
]]

-- from include/macro_presets.inc.c:MacroPreset
export type MacroPreset = {
	behavior: number?,
	model: number,
	param: number,
}

const macro_presets_inc_types = {}

-- from include/macro_presets.inc.c:MacroPreset (zero-filled constructor)
function macro_presets_inc_types.new_MacroPreset(): MacroPreset
	return { behavior = nil, model = 0, param = 0 } :: MacroPreset
end

return macro_presets_inc_types
