--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ttc_pit_block.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

-- from src/game/behaviors/ttc_pit_block.inc.c:TTCPitBlockProperties
export type TTCPitBlockProperties = {
	speed: number,
	waitTime: number,
}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/ttc_pit_block.inc.c:data
const ttc_pit_block_inc = {
	-- from src/game/behaviors/ttc_pit_block.inc.c:sTTCPitBlockCollisionModels L10-13
	sTTCPitBlockCollisionModels = { 0x07015754 --[[ ttc_seg7_collision_07015754 ]], 0x070157D8 --[[ ttc_seg7_collision_070157D8 ]] },
	-- from src/game/behaviors/ttc_pit_block.inc.c:sTTCPitBlockProperties L29-34
	sTTCPitBlockProperties = {
		{ { speed = 11, waitTime = 20 }, { speed = -9, waitTime = 30 } },
		{ { speed = 18, waitTime = 15 }, { speed = -11, waitTime = 15 } },
		{ { speed = 11, waitTime = 20 }, { speed = -9, waitTime = -1 } },
		{ { speed = 0, waitTime = 0 }, { speed = 0, waitTime = 0 } },
	},
}

Registry.Register("src__game__behaviors__ttc_pit_block_inc", ttc_pit_block_inc)

-- from src/game/behaviors/ttc_pit_block.inc.c:TTCPitBlockProperties (zero-filled constructor)
function ttc_pit_block_inc.new_TTCPitBlockProperties(): TTCPitBlockProperties
	return { speed = 0, waitTime = 0 } :: TTCPitBlockProperties
end

-- from src/game/behaviors/ttc_pit_block.inc.c:bhv_ttc_pit_block_init L39-47
function ttc_pit_block_inc.bhv_ttc_pit_block_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.collisionData = Memory.segmented_to_virtual(ttc_pit_block_inc.sTTCPitBlockCollisionModels[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockPeakY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 330.0)

	if ObjectListProcessor.gTTCSpeedSetting == IncludeObjectConstantsH.TTC_SPEED_STOPPED then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 330.0)
	end
end

-- from src/game/behaviors/ttc_pit_block.inc.c:bhv_ttc_pit_block_update L53-71
function ttc_pit_block_inc.bhv_ttc_pit_block_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockWaitTime) then
		-- Forward vel and gravity are zero, so this just does posY += velY
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

		if ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockPeakY)) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockDir, S32(bit32.bxor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockDir), 0x01)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockWaitTime, ttc_pit_block_inc.sTTCPitBlockProperties[ObjectListProcessor.gTTCSpeedSetting + 1][bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockDir), 0x01) + 1].waitTime)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockWaitTime) < 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockWaitTime, ObjBehaviors2.random_mod_offset(10, 20, 6))
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, ttc_pit_block_inc.sTTCPitBlockProperties[ObjectListProcessor.gTTCSpeedSetting + 1][buffer.readi32(o.rawData, IncludeObjectFieldsH.oTTCPitBlockDir) + 1].speed)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end
end

return ttc_pit_block_inc
