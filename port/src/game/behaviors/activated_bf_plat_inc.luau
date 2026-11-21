--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/activated_bf_plat.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectListProcessor = require("../object_list_processor")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/activated_bf_plat.inc.c:data
const activated_bf_plat_inc = {
	-- from src/game/behaviors/activated_bf_plat.inc.c:sActivatedBackAndForthPlatformCollisionModels L20-24
	sActivatedBackAndForthPlatformCollisionModels = {
		0x0701AD54 --[[ bits_seg7_collision_0701AD54 ]],
		0x070157E0 --[[ bitfs_seg7_collision_070157E0 ]],
		0x07015124 --[[ bitfs_seg7_collision_07015124 ]],
	},
}

Registry.Register("src__game__behaviors__activated_bf_plat_inc", activated_bf_plat_inc)

-- from src/game/behaviors/activated_bf_plat.inc.c:bhv_activated_back_and_forth_platform_init L29-59
function activated_bf_plat_inc.bhv_activated_back_and_forth_platform_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Equivalent to the first behavior param byte & 3 (last 2 bits of the byte).
	const platformType = bit32.rshift(bit32.band(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), IncludeObjectConstantsH.ACTIVATED_BF_PLAT_BP_MASK_TYPE), 8)

	-- The BitS arrow platform should flip 180 degrees (0x8000 angle units), but
	-- there is no reason for the other platforms to flip.
	if platformType ~= IncludeObjectConstantsH.ACTIVATED_BF_PLAT_TYPE_BITS_ARROW_PLAT then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformFlipRotation, 0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformFlipRotation, 0x8000)
	end

	o.collisionData = Memory.segmented_to_virtual(activated_bf_plat_inc.sActivatedBackAndForthPlatformCollisionModels[platformType + 1])

	-- Max distance the platform should move.
	-- Equivalent to 50 * (oBhvParams2ndByte & 0x7F), i.e. 50 * (oBhvParams2ndByte % 128).
	-- The maximum possible value of this is 50 * 127 = 6350.
	-- It's 50 * 97 = 4850 in BitS and 50 * 31 = 1550 in BitFS.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformMaxOffset, 50.0 * bit32.band(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), 0x007F))

	if platformType == IncludeObjectConstantsH.ACTIVATED_BF_PLAT_TYPE_BITFS_ELEVATOR then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformMaxOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformMaxOffset) - 12.0)
	end

	-- Truthy/falsy value that determines the direction of movement.
	-- Equivalent to oBhvParams2ndByte & 0x80, i.e. the most significant bit of oBhvParams2ndByte.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVertical, bit32.band(U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 16), 0x0080))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformStartYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
end

-- from src/game/behaviors/activated_bf_plat.inc.c:bhv_activated_back_and_forth_platform_update L64-147
function activated_bf_plat_inc.bhv_activated_back_and_forth_platform_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- oVelY is used for vertical platforms' movement and also for
	-- horizontal platforms' dipping up/down when Mario gets on/off them
	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -6.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 6.0)
	end

	-- If the platform's velocity is set...
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel) ~= 0 then
		-- ...wait until the countdown is 0 before moving.
		-- Since there's a 1 frame "lag" after the countdown is set to 20,
		-- and one more frame of "lag" after it finally reaches 0 here,
		-- Mario actually has to wait 22 frames before the platform starts moving.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformCountdown) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformCountdown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformCountdown) - 1)
		else
			-- After the wait period is over, we start moving, by adding the velocity
			-- to the positional offset.
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformOffset) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel))

			-- clamp_f32 returns whether the value needed to be clamped.
			-- So if the offset got out of bounds (i.e. platform has reached an end of its path),
			-- or Mario is over 3000 units away, the platform will reset the wait timer and flip around.
			if ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformOffset, 0.0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformMaxOffset)) ~= 0
				-- The platform will not reset if Mario goes far away and it's travelling backwards
				or (buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel) > 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 3000.0) then
				-- Reset the wait timer
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformCountdown, 20)

				-- oVelY is only negative if Mario is on the platform,
				-- so if Mario is on the platform or the platform is going forwards when it resets,
				-- the platform will reverse directions. Otherwise, it will stop.
				-- This means that if Mario touches the platform initially, then gets off,
				-- it will do a full round trip then stop (assuming Mario stays within 3000 units).
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel) > 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel))
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel, 0.0)
				end

				-- Make the platform face the opposite way if it should.
				-- This is for the BitS arrow platform, which has an indicated direction.
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformFlipRotation))
			end
		end
	else
		-- oVelY is only negative if Mario is on the platform
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVel, 10.0)
		end

		-- Set waiting countdown to 20 frames
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformCountdown, 20)
	end

	-- Save the object's current position to a safe location.
	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_SAVE_POSITION)

	-- Update the object's position.
	-- If the platform moves vertically...
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformVertical) ~= IncludePRUltratypesH.FALSE then
		-- ...set its position to its original position + the offset.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformOffset))
	else
		-- Otherwise, dip down 20 units if Mario gets on the horizontal platform, and undo if he gets
		-- off.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
		ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 20.0), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))

		-- Update the position using the object's home (original position), facing angle, and offset.
		-- This has to be done manually when the platform is vertical because only the yaw is used
		-- by this function; it doesn't update the Y position.
		ObjBehaviors2.obj_set_dist_from_home(-buffer.readf32(o.rawData, IncludeObjectFieldsH.oActivatedBackAndForthPlatformOffset))
	end

	-- Compute the object's velocity using the old saved position.
	ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_COMPUTE_VELOCITY)
end

return activated_bf_plat_inc
