--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/rolling_log.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const rolling_log_inc = {}

Registry.Register("src__game__behaviors__rolling_log_inc", rolling_log_inc)

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

-- from src/game/behaviors/rolling_log.inc.c:bhv_ttm_rolling_log_init L9-20
function rolling_log_inc.bhv_ttm_rolling_log_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF8, 3970.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkFC, 3654.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF4, 271037.0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 8810)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
end

-- from src/game/behaviors/rolling_log.inc.c:rolling_log_roll_log L22-66
function rolling_log_inc.rolling_log_roll_log()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if gMario.platform == o then
		const sp24 = F32(F32(F32(gMario.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) * SrcEngineMathUtilH.coss(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) - F32(F32(gMario.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)) * SrcEngineMathUtilH.sins(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
		if sp24 > 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + 0x10)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) - 0x10)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) > 0x200 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0x200)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) < -0x200 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, -0x200)
		end
	else
		if ObjBehaviors.is_point_close_to_object(o, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 100) ~= 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) ~= 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) > 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) - 0x10)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + 0x10)
				end

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) < 0x10 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) > -0x10 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
				end
			end
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) ~= 0x100 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) > 0x100 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) - 0x10)
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + 0x10)
				end

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) < 0x110 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) > 0xF0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0x100)
				end
			end
		end
	end
end

-- from src/game/behaviors/rolling_log.inc.c:bhv_rolling_log_loop L68-93
function rolling_log_inc.bhv_rolling_log_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const prevX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	const prevZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

	rolling_log_inc.rolling_log_roll_log()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) / 0x40))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF4) < F32(SrcEngineMathUtilH.sqr(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF8))) + SrcEngineMathUtilH.sqr(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPitouneUnkFC)))) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, prevX)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, prevZ)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
	if ObjBehaviors.absf_2(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch), 0x1FFF)) < 528.0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNKNOWN1_2)
	end
end

-- from src/game/behaviors/rolling_log.inc.c:volcano_act_1 L95-108
function rolling_log_inc.volcano_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oRollingLogUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oRollingLogUnkF4) + 4.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oRollingLogUnkF4))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < -0x4000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, -0x4000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oRollingLogUnkF4, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BIG_POUND)
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_LARGE, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	end
end

-- from src/game/behaviors/rolling_log.inc.c:volcano_act_3 L110-121
function rolling_log_inc.volcano_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0x90)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 200 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/rolling_log.inc.c:bhv_volcano_trap_loop L123-150
function rolling_log_inc.bhv_volcano_trap_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_POUND2)
		end
	elseif action == 1 then
		rolling_log_inc.volcano_act_1()
	elseif action == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 8 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 10.0))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 50 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNK45)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	elseif action == 3 then
		rolling_log_inc.volcano_act_3()
	end
end

-- from src/game/behaviors/rolling_log.inc.c:bhv_lll_rolling_log_init L152-163
function rolling_log_inc.bhv_lll_rolling_log_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF8, 5120.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkFC, 6016.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPitouneUnkF4, 1048576.0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x3FFF)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
end

return rolling_log_inc
