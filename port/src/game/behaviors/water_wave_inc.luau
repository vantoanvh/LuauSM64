--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_wave.inc.c.
]]

const Registry = require("../../../groups/registry")
const GameInit = require("../game_init")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const water_wave_inc = {}

Registry.Register("src__game__behaviors__water_wave_inc", water_wave_inc)

-- from src/game/behaviors/water_wave.inc.c:bhv_object_water_wave_init L4-6
function water_wave_inc.bhv_object_water_wave_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
end

-- from src/game/behaviors/water_wave.inc.c:bhv_object_water_wave_loop L8-13
function water_wave_inc.bhv_object_water_wave_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const GlobalTimer = GameInit.gGlobalTimer

	if math.fmod(GlobalTimer, 16) == 0 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return water_wave_inc
