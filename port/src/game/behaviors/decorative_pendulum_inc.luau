--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/decorative_pendulum.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const decorative_pendulum_inc = {}

Registry.Register("src__game__behaviors__decorative_pendulum_inc", decorative_pendulum_inc)

-- from src/game/behaviors/decorative_pendulum.inc.c:bhv_decorative_pendulum_init L7-10
function decorative_pendulum_inc.bhv_decorative_pendulum_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0x100)
	ObjectHelpers.bhv_init_room()
end

-- from src/game/behaviors/decorative_pendulum.inc.c:bhv_decorative_pendulum_loop L16-34
function decorative_pendulum_inc.bhv_decorative_pendulum_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) - 0x08)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) + 0x08)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll))

	-- This if-statement is true twice in the span of 5 frames when oAngleVelRoll takes values in {0x10, 0x08, 0x00, -0x08, -0x10}.
	-- This means the sound we hear when the pendulum hits its upswing is actually one sound played twice in rapid succession.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) == 0x10 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) == -0x10 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BIG_CLOCK)
	end
end

return decorative_pendulum_inc
