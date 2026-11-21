--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/horizontal_grindel.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const horizontal_grindel_inc = {}

Registry.Register("src__game__behaviors__horizontal_grindel_inc", horizontal_grindel_inc)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/horizontal_grindel.inc.c:bhv_horizontal_grindel_init L3-5
function horizontal_grindel_inc.bhv_horizontal_grindel_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
end

-- from src/game/behaviors/horizontal_grindel.inc.c:bhv_horizontal_grindel_update L7-49
function horizontal_grindel_inc.bhv_horizontal_grindel_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelOnGround) == IncludePRUltratypesH.FALSE then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_THWOMP)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelOnGround, IncludePRUltratypesH.TRUE)

			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelDistToHome, ObjectHelpers.cur_obj_lateral_dist_to_home())
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end

		if ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelTargetYaw)), 0x400) ~= 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelDistToHome) > 300.0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelTargetYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelTargetYaw) + 0x8000))
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelDistToHome, 0.0)
				else
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_KING_BOBOMB_JUMP)

					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 11.0)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 70.0)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
					buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
				end
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHorizontalGrindelOnGround, IncludePRUltratypesH.FALSE)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -16.0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000))

	ObjectHelpers.cur_obj_move_standard(78)
end

return horizontal_grindel_inc
