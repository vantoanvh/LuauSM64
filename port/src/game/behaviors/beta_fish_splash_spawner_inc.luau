--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_fish_splash_spawner.inc.c.
]]

const Registry = require("../../../groups/registry")

const beta_fish_splash_spawner_inc = {}

Registry.Register("src__game__behaviors__beta_fish_splash_spawner_inc", beta_fish_splash_spawner_inc)

-- from src/game/behaviors/beta_fish_splash_spawner.inc.c:bhv_beta_fish_splash_spawner_loop L15-18
function beta_fish_splash_spawner_inc.bhv_beta_fish_splash_spawner_loop()
	-- The waterLevel local is UNUSED in the C source: find_water_level has no effect, so its read is dropped.
end

return beta_fish_splash_spawner_inc
