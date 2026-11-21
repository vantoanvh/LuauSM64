--!strict
--!optimize 2

--[[
	Types of src/game/behaviors/bowser_inc.
]]

-- from src/game/behaviors/bowser.inc.c:BowserTiltPlatformInfo
export type BowserTiltPlatformInfo = {
	flag: number,
	angSpeed: number,
	time: number,
}

const bowser_inc_types = {}

-- from src/game/behaviors/bowser.inc.c:BowserTiltPlatformInfo (zero-filled constructor)
function bowser_inc_types.new_BowserTiltPlatformInfo(): BowserTiltPlatformInfo
	return { flag = 0, angSpeed = 0, time = 0 } :: BowserTiltPlatformInfo
end

return bowser_inc_types
