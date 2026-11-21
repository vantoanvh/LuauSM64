--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/spindel.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const spindel_inc = {}

Registry.Register("src__game__behaviors__spindel_inc", spindel_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/spindel.inc.c:bhv_spindel_init L3-7
function spindel_inc.bhv_spindel_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF8, 0)
end

-- from src/game/behaviors/spindel.inc.c:bhv_spindel_loop L9-84
function spindel_inc.bhv_spindel_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4) == -1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 32 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)

			return
		end
	end

	local Sp18 = 10 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4)

	if Sp18 < 0 then
		Sp18 *= -1
	end

	Sp18 -= 6

	if Sp18 < 0 then
		Sp18 = 0
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == Sp18 + 8 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4) + 1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4) == 20 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF8) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF8, 1)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF8, 0)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF4, -1)
		end
	end

	if Sp18 == 4 or Sp18 == 3 then
		Sp18 = 4
	elseif Sp18 == 2 or Sp18 == 1 then
		Sp18 = 2
	elseif Sp18 == 0 then
		Sp18 = 1
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < Sp18 * 8 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpindelUnkF8) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 20 // Sp18)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 1024 // Sp18)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, -20 // Sp18)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, -1024 // Sp18)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))

		if ObjBehaviors.absf_2(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch), 0x1fff)) < 800.0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_SPINDEL_ROLL)
		end

		local Sp1C = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) * 4) * 23.0)

		if Sp1C < 0.0 then
			Sp1C = F32(Sp1C * -1.0)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + Sp1C)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 1 == Sp18 * 8 then
			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		end
	end
end

return spindel_inc
