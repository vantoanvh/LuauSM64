--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/rotating_platform.inc.c.
]]

const SegmentSymbols = require("../../rom/segment_symbols")
const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

-- from src/game/behaviors/rotating_platform.inc.c:RotatingPlatformData
export type RotatingPlatformData = {
	unused: number,
	scale: number,
	collisionData: number?,
	collisionDistance: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/rotating_platform.inc.c:data
const rotating_platform_inc = {
	-- from src/game/behaviors/rotating_platform.inc.c:sRotatingPlatformData L13-16
	sRotatingPlatformData = {
		{
			unused = 0,
			scale = 100,
			collisionData = SegmentSymbols.wf_seg7_collision_rotating_platform,
			collisionDistance = 2000,
		},
		{
			unused = 0,
			scale = 150,
			collisionData = 0x070186B4,
			collisionDistance = 1000,
		},
	},
}

Registry.Register("src__game__behaviors__rotating_platform_inc", rotating_platform_inc)

-- from src/game/behaviors/rotating_platform.inc.c:RotatingPlatformData (zero-filled constructor)
function rotating_platform_inc.new_RotatingPlatformData(): RotatingPlatformData
	return { unused = 0, scale = 0, collisionData = nil, collisionDistance = 0 } :: RotatingPlatformData
end

-- from src/game/behaviors/rotating_platform.inc.c:bhv_wf_rotating_wooden_platform_loop L18-32
function rotating_platform_inc.bhv_wf_rotating_wooden_platform_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WF_ROTATING_WOODEN_PLATFORM_ACT_IDLE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	else
		-- WF_ROTATING_WOODEN_PLATFORM_ACT_ROTATING
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x100)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 126 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WF_ROTATING_WOODEN_PLATFORM_ACT_IDLE)
		end
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR2)
	end

	ObjectHelpers.cur_obj_rotate_face_angle_using_vel()
end

-- from src/game/behaviors/rotating_platform.inc.c:bhv_rotating_platform_loop L34-43
function rotating_platform_inc.bhv_rotating_platform_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bhvParams1stByte: number = S8(bit32.arshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.obj_set_collision_data(o, rotating_platform_inc.sRotatingPlatformData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1].collisionData)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionDistance, rotating_platform_inc.sRotatingPlatformData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1].collisionDistance)
		ObjectHelpers.cur_obj_scale(F32(rotating_platform_inc.sRotatingPlatformData[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1].scale * F32(0.01)))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S32(bit32.lshift(bhvParams1stByte, 4)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
end

return rotating_platform_inc
