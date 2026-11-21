--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/switch_hidden_objects.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const BreakParticlesInc = require("./break_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

-- from src/game/behaviors/switch_hidden_objects.inc.c:data
const switch_hidden_objects_inc = {
	-- from src/game/behaviors/switch_hidden_objects.inc.c:sBreakableBoxHitbox L3-13
	sBreakableBoxHitbox = {
		interactType = InteractionH.INTERACT_BREAKABLE,
		downOffset = 20,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 150,
		height = 200,
		hurtboxRadius = 150,
		hurtboxHeight = 200,
	},
}

Registry.Register("src__game__behaviors__switch_hidden_objects_inc", switch_hidden_objects_inc)

-- from src/game/behaviors/switch_hidden_objects.inc.c:breakable_box_init L15-33
function switch_hidden_objects_inc.breakable_box_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] = nil
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BREAKABLE_BOX_BP_NO_COINS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BREAKABLE_BOX_BP_3_COINS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 3)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BREAKABLE_BOX_BP_5_COINS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 5)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.BREAKABLE_BOX_BP_GIANT then
		ObjectHelpers.cur_obj_scale(1.5)
	end
end

-- from src/game/behaviors/switch_hidden_objects.inc.c:hidden_breakable_box_actions L35-80
function switch_hidden_objects_inc.hidden_breakable_box_actions()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, switch_hidden_objects_inc.sBreakableBoxHitbox)
	ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BREAKABLE_BOX_SMALL)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_INACTIVE then
		ObjectHelpers.cur_obj_disable_rendering()
		ObjectHelpers.cur_obj_become_intangible()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			switch_hidden_objects_inc.breakable_box_init()
		end

		if o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] == nil then
			o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvFloorSwitchHiddenObjects)
		end

		const PurpleSwitch = o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] :: GroupsTypesHPlus3.Object?

		if PurpleSwitch ~= nil then
			if buffer.readi32(PurpleSwitch.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
				ObjectHelpers.cur_obj_enable_rendering()
				ObjectHelpers.cur_obj_unhide()
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_ACTIVE then
		ObjectHelpers.cur_obj_become_tangible()

		if ObjectHelpers.cur_obj_wait_then_blink(360, 20) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_INACTIVE)
		end

		if ObjectHelpers.cur_obj_was_attacked_or_ground_pounded() ~= 0 then
			ObjectHelpers.spawn_mist_particles()
			BreakParticlesInc.spawn_triangle_break_particles(30, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3.0, 4)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BREAK_BOX)
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	else
		ObjectHelpers.cur_obj_become_intangible()
		ObjectHelpers.cur_obj_disable_rendering()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

		const PurpleSwitch = o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] :: GroupsTypesHPlus3.Object?

		if PurpleSwitch ~= nil then
			if buffer.readi32(PurpleSwitch.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_IDLE then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_INACTIVE)
			end
		end
	end
end

-- from src/game/behaviors/switch_hidden_objects.inc.c:hidden_wdw_platform_actions L82-108
function switch_hidden_objects_inc.hidden_wdw_platform_actions()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_collision_data(o, 0x07018528)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_INACTIVE then
		ObjectHelpers.cur_obj_disable_rendering()
		ObjectHelpers.cur_obj_become_intangible()

		if o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] == nil then
			o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvFloorSwitchHiddenObjects)
		end

		const PurpleSwitch = o.ptrData[IncludeObjectFieldsH.oHiddenObjectPurpleSwitch + 1] :: GroupsTypesHPlus3.Object?

		if PurpleSwitch ~= nil then
			if buffer.readi32(PurpleSwitch.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.PURPLE_SWITCH_ACT_TICKING then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
				ObjectHelpers.cur_obj_enable_rendering()
				ObjectHelpers.cur_obj_unhide()
			end
		end
	else
		ObjectHelpers.cur_obj_become_tangible()

		if ObjectHelpers.cur_obj_wait_then_blink(360, 20) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HIDDEN_OBJECT_ACT_INACTIVE)
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

-- from src/game/behaviors/switch_hidden_objects.inc.c:bhv_hidden_object_loop L110-116
function switch_hidden_objects_inc.bhv_hidden_object_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.HIDDEN_OBJECT_BP_BREAKABLE_BOX then
		switch_hidden_objects_inc.hidden_breakable_box_actions()
	else
		switch_hidden_objects_inc.hidden_wdw_platform_actions()
	end
end

return switch_hidden_objects_inc
