--!strict
--!optimize 2

--[[
	Port of src/game/geo_misc.h.
]]

const Gbi = require("../rom/gbi")

-- from src/game/geo_misc.h:data
const geo_misc_h = {
	FLYING_CARPET_IDLE = 0,
	FLYING_CARPET_MOVING_WITHOUT_MARIO = 1,
	FLYING_CARPET_MOVING_WITH_MARIO = 2,
}

-- from src/game/geo_misc.h:gLoadBlockTexture L30-38
function geo_misc_h.gLoadBlockTexture(width: number, height: number, format: number, image: number)
	Gbi.gDPSetTextureImage(format, Gbi.G_IM_SIZ_16b, 1, image)
	Gbi.gDPTileSync()
	Gbi.gDPSetTile(format, Gbi.G_IM_SIZ_16b, 0, 0, Gbi.G_TX_LOADTILE, 0, Gbi.G_TX_NOMIRROR, Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD, Gbi.G_TX_NOMIRROR, Gbi.G_TX_NOMASK, Gbi.G_TX_NOLOD)
	Gbi.gDPLoadSync()
	Gbi.gDPLoadBlock(Gbi.G_TX_LOADTILE, 0, 0, width * height - 1, Gbi.CALC_DXT(width, Gbi.G_IM_SIZ_16b_BYTES))
end

return geo_misc_h
