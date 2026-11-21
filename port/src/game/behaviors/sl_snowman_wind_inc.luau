--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sl_snowman_wind.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const StrongWindParticleInc = require("./strong_wind_particle_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const sl_snowman_wind_inc = {}

Registry.Register("src__game__behaviors__sl_snowman_wind_inc", sl_snowman_wind_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/sl_snowman_wind_inc.luau:scratch
const Scratch = {
	bhv_sl_snowman_wind_loop_tempPos = { 0, 0, 0 },
	bhv_sl_snowman_wind_loop_oPos = { 0, 0, 0 },
}

-- from src/game/behaviors/sl_snowman_wind.inc.c:bhv_sl_snowman_wind_loop L3-50
function sl_snowman_wind_inc.bhv_sl_snowman_wind_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLSnowmanWindOriginalYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	end

	-- Waiting for Mario to approach.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.SL_SNOWMAN_WIND_ACT_IDLE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, 0)

		-- Check if Mario is within 1000 units of the center of the bridge, and ready to speak.
		Scratch.bhv_sl_snowman_wind_loop_oPos[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		Scratch.bhv_sl_snowman_wind_loop_oPos[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Scratch.bhv_sl_snowman_wind_loop_oPos[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		BehaviorActions.vec3f_copy_2(Scratch.bhv_sl_snowman_wind_loop_tempPos, Scratch.bhv_sl_snowman_wind_loop_oPos)
		ObjectHelpers.obj_set_pos(o, 1100, 3328, 1164) -- Position is in the middle of the ice bridge
		if ObjectHelpers.cur_obj_can_mario_activate_textbox(1000.0, 30.0, 0x7FFF) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
		BehaviorActions.vec3f_copy_2(Scratch.bhv_sl_snowman_wind_loop_oPos, Scratch.bhv_sl_snowman_wind_loop_tempPos)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Scratch.bhv_sl_snowman_wind_loop_oPos[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Scratch.bhv_sl_snowman_wind_loop_oPos[2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Scratch.bhv_sl_snowman_wind_loop_oPos[3])

	-- Mario has come close, begin dialog.
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.SL_SNOWMAN_WIND_ACT_TALKING then
		if ObjectHelpers.cur_obj_update_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_TEXT_DEFAULT, IncludeDialogIdsH.DIALOG_153, 0) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end

	-- Blowing, spawn wind particles (SL_SNOWMAN_WIND_ACT_BLOWING)
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 and ObjectHelpers.absf(F32(buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))) < 500.0 then
		-- Point towards Mario, but only within 0x1500 angle units of the original angle.
		const marioAngleFromWindSource = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLSnowmanWindOriginalYaw))

		if marioAngleFromWindSource > 0 then
			if marioAngleFromWindSource < 0x1500 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLSnowmanWindOriginalYaw) + 0x1500)
			end
		else
			if marioAngleFromWindSource > -0x1500 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLSnowmanWindOriginalYaw) - 0x1500)
			end
		end

		-- Spawn wind and play wind sound
		StrongWindParticleInc.cur_obj_spawn_strong_wind_particles(12, 3.0, 0, 0, 0)
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BLOW_WIND)
	end
end

return sl_snowman_wind_inc
