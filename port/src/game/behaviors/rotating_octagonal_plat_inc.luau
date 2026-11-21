--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/rotating_octagonal_plat.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")
const Memory = require("../memory")

-- from src/game/behaviors/rotating_octagonal_plat.inc.c:data
const rotating_octagonal_plat_inc = {
	-- from src/game/behaviors/rotating_octagonal_plat.inc.c:sOctagonalPlatformCollision L3-6
	sOctagonalPlatformCollision = { 0x0701AA84, 0x07029320 }, -- rr_seg7_collision_07029508 (ROM layout)
	-- from src/game/behaviors/rotating_octagonal_plat.inc.c:sOctagonalPlatformAngularVelocities L8-8
	sOctagonalPlatformAngularVelocities = { 300, -300, 600, -600 },
}

Registry.Register("src__game__behaviors__rotating_octagonal_plat_inc", rotating_octagonal_plat_inc)

-- from src/game/behaviors/rotating_octagonal_plat.inc.c:bhv_rotating_octagonal_plat_init L10-13
function rotating_octagonal_plat_inc.bhv_rotating_octagonal_plat_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.collisionData = Memory.segmented_to_virtual(rotating_octagonal_plat_inc.sOctagonalPlatformCollision[bit32.band(bit32.arshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16), 0xFF) + 1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, rotating_octagonal_plat_inc.sOctagonalPlatformAngularVelocities[bit32.band(bit32.arshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF) + 1])
end

-- from src/game/behaviors/rotating_octagonal_plat.inc.c:bhv_rotating_octagonal_plat_loop L15-17
function rotating_octagonal_plat_inc.bhv_rotating_octagonal_plat_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
end

return rotating_octagonal_plat_inc
