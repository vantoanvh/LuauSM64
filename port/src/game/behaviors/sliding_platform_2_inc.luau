--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sliding_platform_2.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/sliding_platform_2.inc.c:data
const sliding_platform_2_inc = {
	-- from src/game/behaviors/sliding_platform_2.inc.c:sSlidingPlatform2CollisionData L3-12
	sSlidingPlatform2CollisionData = {
		0x0701A9A0 --[[ bits_seg7_collision_0701A9A0 ]],
		0x0701AA0C --[[ bits_seg7_collision_0701AA0C ]],
		0x07015714 --[[ bitfs_seg7_collision_07015714 ]],
		0x07015768 --[[ bitfs_seg7_collision_07015768 ]],
		0x07029410 --[[ rr_seg7_collision_070295F8 (ROM layout) ]],
		0x07029494 --[[ rr_seg7_collision_0702967C (ROM layout) ]],
		nil, -- NULL
		0x0700F688 --[[ bitdw_seg7_collision_0700F688 ]],
	},
}

Registry.Register("src__game__behaviors__sliding_platform_2_inc", sliding_platform_2_inc)

-- from src/game/behaviors/sliding_platform_2.inc.c:bhv_sliding_plat_2_init L14-33
function sliding_platform_2_inc.bhv_sliding_plat_2_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const collisionDataIndex = bit32.rshift(bit32.band(U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), 0x0380), 7)
	const collisionModel = sliding_platform_2_inc.sSlidingPlatform2CollisionData[collisionDataIndex + 1]

	if collisionModel == nil then
		o.collisionData = nil
	else
		o.collisionData = Memory.segmented_to_virtual(collisionModel)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformPathLength, 50.0 * bit32.band(U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), 0x003F))

	if collisionDataIndex < 5 or collisionDataIndex > 6 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformVel, 15.0)

		if bit32.btest(U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), 0x0040) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformVel, 10.0)

		if bit32.btest(U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)), 0x0040) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDirection, -1.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDirection, 1.0)
		end
	end
end

-- from src/game/behaviors/sliding_platform_2.inc.c:bhv_sliding_plat_2_loop L35-53
function sliding_platform_2_inc.bhv_sliding_plat_2_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDistance, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDistance) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformVel))

		const Clamped: number = ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDistance, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformPathLength), 0.0)


		if Clamped ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformVel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformVel))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end

	ObjBehaviors2.obj_perform_position_op(0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDirection) ~= 0.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDistance) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDirection)))
	else
		ObjBehaviors2.obj_set_dist_from_home(buffer.readf32(o.rawData, IncludeObjectFieldsH.oBackAndForthPlatformDistance))
	end

	ObjBehaviors2.obj_perform_position_op(1)
end

return sliding_platform_2_inc
