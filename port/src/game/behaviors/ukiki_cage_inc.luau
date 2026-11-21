--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/ukiki_cage.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BreakParticlesInc = require("./break_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const ukiki_cage_inc = {}

Registry.Register("src__game__behaviors__ukiki_cage_inc", ukiki_cage_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/ukiki_cage.inc.c:bhv_ukiki_cage_star_loop L16-46
function ukiki_cage_inc.bhv_ukiki_cage_star_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.UKIKI_CAGE_STAR_ACT_IN_CAGE then
		-- Initialization to see if the star is collected (blue) or not (yellow).
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			if bit32.btest(ObjectHelpers.bit_shift_left(1), SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Area.gCurrCourseNum))) then
				ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_TRANSPARENT_STAR)
			end
		end

		ObjectHelpers.obj_copy_pos(o, o.parentObj :: GroupsTypesHPlus3.Object)
		ObjectHelpers.obj_copy_behavior_params(o, o.parentObj :: GroupsTypesHPlus3.Object)

		-- When they cage hides itself, spawn particles and the star.
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.UKIKI_CAGE_ACT_HIDE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif Action == IncludeObjectConstantsH.UKIKI_CAGE_STAR_ACT_SPAWN_STAR then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_mist_particles()
		BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, F32(0.7), 3)
		SpawnStarInc.spawn_default_star(2500, -1200, 1300)
	end

	-- Spin to look like a star.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x400))
end

-- from src/game/behaviors/ukiki_cage.inc.c:ukiki_cage_act_wait_for_ukiki L51-57
function ukiki_cage_inc.ukiki_cage_act_wait_for_ukiki()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oUkikiCageNextAction) ~= IncludeObjectConstantsH.UKIKI_CAGE_ACT_WAIT_FOR_UKIKI then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_CAGE_ACT_SPIN)
	end

	SrcEngineSurfaceLoad.load_object_collision_model()
end

-- from src/game/behaviors/ukiki_cage.inc.c:ukiki_cage_act_spin L62-69
function ukiki_cage_inc.ukiki_cage_act_spin()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oUkikiCageNextAction) ~= IncludeObjectConstantsH.UKIKI_CAGE_ACT_SPIN then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_CAGE_ACT_FALL)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x800))
	SrcEngineSurfaceLoad.load_object_collision_model()
end

-- from src/game/behaviors/ukiki_cage.inc.c:ukiki_cage_act_fall L74-81
function ukiki_cage_inc.ukiki_cage_act_fall()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_LANDED, IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.UKIKI_CAGE_ACT_HIDE)
	end
end

-- from src/game/behaviors/ukiki_cage.inc.c:ukiki_cage_act_hide L89-91
function ukiki_cage_inc.ukiki_cage_act_hide()
	ObjectHelpers.cur_obj_hide()
end

-- from src/game/behaviors/ukiki_cage.inc.c:bhv_ukiki_cage_loop L106-108
function ukiki_cage_inc.bhv_ukiki_cage_loop()
	ObjectHelpers.cur_obj_call_action_function(ukiki_cage_inc.sUkikiCageActions)
end

-- from src/game/behaviors/ukiki_cage.inc.c:sUkikiCageActions L96-101
ukiki_cage_inc.sUkikiCageActions = {
	ukiki_cage_inc.ukiki_cage_act_wait_for_ukiki,
	ukiki_cage_inc.ukiki_cage_act_spin,
	ukiki_cage_inc.ukiki_cage_act_fall,
	ukiki_cage_inc.ukiki_cage_act_hide,
}

return ukiki_cage_inc
