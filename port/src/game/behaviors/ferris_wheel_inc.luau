--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ferris_wheel.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

-- from src/game/behaviors/ferris_wheel.inc.c:FerrisWheelProperties
export type FerrisWheelProperties = {
	axleCollision: number?,
	platformCollision: number?,
	platformModel: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/ferris_wheel.inc.c:data
const ferris_wheel_inc = {
	-- from src/game/behaviors/ferris_wheel.inc.c:sFerrisWheelProperties L20-23
	sFerrisWheelProperties = {
		{
			axleCollision = 0x0701ACAC,
			platformCollision = 0x0701AC28,
			platformModel = IncludeModelIdsH.MODEL_BITS_BLUE_PLATFORM,
		},
		{
			axleCollision = 0x0700F7F0,
			platformCollision = 0x0700F898,
			platformModel = IncludeModelIdsH.MODEL_BITDW_BLUE_PLATFORM,
		},
	},
}

Registry.Register("src__game__behaviors__ferris_wheel_inc", ferris_wheel_inc)

-- from src/game/behaviors/ferris_wheel.inc.c:FerrisWheelProperties (zero-filled constructor)
function ferris_wheel_inc.new_FerrisWheelProperties(): FerrisWheelProperties
	return { axleCollision = nil, platformCollision = nil, platformModel = 0 } :: FerrisWheelProperties
end

-- from src/game/behaviors/ferris_wheel.inc.c:bhv_ferris_wheel_axle_init L30-47
function ferris_wheel_inc.bhv_ferris_wheel_axle_init()
	const o = ObjectListProcessor.gCurrentObject
	const properties = ferris_wheel_inc.sFerrisWheelProperties[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]

	o.collisionData = Memory.segmented_to_virtual(properties.axleCollision :: number)

	for i = 0, 3 do
		const platform: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative(S16(i), 0, 0, 0, o, properties.platformModel, BehaviorIds.bhvFerrisWheelPlatform)

		if platform ~= nil then
			platform.collisionData = Memory.segmented_to_virtual(properties.platformCollision :: number)
		end
	end
end

-- from src/game/behaviors/ferris_wheel.inc.c:bhv_ferris_wheel_platform_update L53-71
function ferris_wheel_inc.bhv_ferris_wheel_platform_update()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_SAVE_POSITION)

	const offsetAngle = S16(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 0x4000)
	const offsetXZ = F32(400 * SrcEngineMathUtilH.coss(offsetAngle))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX) + F32(offsetXZ * SrcEngineMathUtilH.sins(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))) + F32(300 * SrcEngineMathUtilH.coss(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY) + F32(400 * SrcEngineMathUtilH.sins(offsetAngle)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ) + F32(offsetXZ * SrcEngineMathUtilH.coss(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))) + F32(300 * SrcEngineMathUtilH.sins(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_COMPUTE_VELOCITY)
end

return ferris_wheel_inc
