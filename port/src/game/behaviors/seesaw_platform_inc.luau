--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/seesaw_platform.inc.c.
]]

const SegmentSymbols = require("../../rom/segment_symbols")
const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const Memory = require("../memory")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end


-- from src/game/behaviors/seesaw_platform.inc.c:data
const seesaw_platform_inc = {
	-- from src/game/behaviors/seesaw_platform.inc.c:sSeesawPlatformCollisionModels L9-18
	sSeesawPlatformCollisionModels = {
		0x0700F70C,
		0x0701ADD8,
		0x0701AE5C,
		SegmentSymbols.bob_seg7_collision_bridge,
		0x07015928,
		0x07029568, -- rr_seg7_collision_07029750 (ROM layout)
		0x07029670, -- rr_seg7_collision_07029858 (ROM layout)
		0x0700AC44,
	},
}

Registry.Register("src__game__behaviors__seesaw_platform_inc", seesaw_platform_inc)

-- from src/game/behaviors/seesaw_platform.inc.c:bhv_seesaw_platform_init L23-31
function seesaw_platform_inc.bhv_seesaw_platform_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.collisionData = Memory.segmented_to_virtual(seesaw_platform_inc.sSeesawPlatformCollisionModels[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1])

	-- The S-shaped seesaw platform in BitS is large, so increase its collision
	-- distance
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 2 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCollisionDistance, 2000.0)
	end
end

-- from src/game/behaviors/seesaw_platform.inc.c:bhv_seesaw_platform_update L36-68
function seesaw_platform_inc.bhv_seesaw_platform_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel)))

	if ObjectHelpers.absf(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel)) > 10.0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_BOAT_ROCKING1)
	end

	if gMario.platform == o then
		-- Rotate toward mario
		local rotation = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

		-- Deceleration is faster than acceleration
		if F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel) * rotation) < 0 then
			rotation = F32(rotation * F32(0.04))
		else
			rotation = F32(rotation * F32(0.02))
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel) + rotation)
		ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel, -50.0, 50.0)
	else
		-- Rotate back to 0
		ObjBehaviors2.oscillate_toward(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, o.rawData, IncludeObjectFieldsH.oSeesawPlatformPitchVel, 0.0, 6.0, 3.0, 3.0)
	end
end

return seesaw_platform_inc
