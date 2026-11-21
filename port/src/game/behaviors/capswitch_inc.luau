--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/capswitch.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const Area = require("../area")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const BreakParticlesInc = require("./break_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SpawnSound = require("../spawn_sound")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/capswitch.inc.c:data
const capswitch_inc = {
	-- from src/game/behaviors/capswitch.inc.c:sCapSwitchText L3-3
	sCapSwitchText = { IncludeDialogIdsH.DIALOG_010, IncludeDialogIdsH.DIALOG_011, IncludeDialogIdsH.DIALOG_012 },
}

Registry.Register("src__game__behaviors__capswitch_inc", capswitch_inc)

-- from src/game/behaviors/capswitch.inc.c:cap_switch_act_0 L5-22
function capswitch_inc.cap_switch_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
	ObjectHelpers.cur_obj_scale(0.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 71.0)

	ObjectHelpers.spawn_object_relative_with_scale(0, 0, -71, 0, 0.5, o, IncludeModelIdsH.MODEL_CAP_SWITCH_BASE, BehaviorIds.bhvCapSwitchBase)

	if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_UNKNOWN_32 then
		if bit32.btest(SaveFile.save_file_get_flags(), BehaviorActions.sCapSaveFlags[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
			o.header.gfx.scale[2] = F32(0.1)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/capswitch.inc.c:cap_switch_act_1 L24-30
function capswitch_inc.cap_switch_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectHelpers.cur_obj_is_mario_on_platform() ~= 0 then
		SaveFile.save_file_set_flags(BehaviorActions.sCapSaveFlags[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1])
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_ACTIVATE_CAP_SWITCH)
	end
end

-- from src/game/behaviors/capswitch.inc.c:cap_switch_act_2 L32-53
function capswitch_inc.cap_switch_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 5 then
		ObjectHelpers.cur_obj_scale_over_time(2, 4, 0.5, F32(0.1))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 4 then
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
			ObjectHelpers.spawn_mist_particles()
			BreakParticlesInc.spawn_triangle_break_particles(60, IncludeModelIdsH.MODEL_CARTOON_STAR, F32(0.3), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))
		end
	else
		-- The dialog flags of this cutscene are not defined in this function: the cutscene itself calls the dialog.
		const dialogResponse = ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT, bit32.bor(IncludeObjectConstantsH.DIALOG_FLAG_TEXT_RESPONSE, IncludeObjectConstantsH.DIALOG_FLAG_UNK_CAPSWITCH), GroupsTypesHPlus3.CUTSCENE_CAP_SWITCH_PRESS, 0)

		if dialogResponse ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	end
end

-- from src/game/behaviors/capswitch.inc.c:cap_switch_act_3 L56-57
function capswitch_inc.cap_switch_act_3()
	-- Empty in the C source.
end

-- from src/game/behaviors/capswitch.inc.c:bhv_cap_switch_loop L66-68
function capswitch_inc.bhv_cap_switch_loop()
	ObjectHelpers.cur_obj_call_action_function(capswitch_inc.sCapSwitchActions)
end

-- from src/game/behaviors/capswitch.inc.c:sCapSwitchActions L59-64
capswitch_inc.sCapSwitchActions = {
	capswitch_inc.cap_switch_act_0,
	capswitch_inc.cap_switch_act_1,
	capswitch_inc.cap_switch_act_2,
	capswitch_inc.cap_switch_act_3,
}

return capswitch_inc
