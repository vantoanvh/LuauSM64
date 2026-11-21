--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/celebration_star.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const celebration_star_inc = {}

Registry.Register("src__game__behaviors__celebration_star_inc", celebration_star_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/celebration_star.inc.c:bhv_celebration_star_init L3-29
function celebration_star_inc.bhv_celebration_star_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, marioObject.header.gfx.pos[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, marioObject.header.gfx.pos[2] + 30.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, marioObject.header.gfx.pos[3])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(marioObject.header.gfx.angle[2] + 0x8000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation, 100)

	-- BUGFIX_STAR_BOWSER_KEY: the celebration star is a key after Bowser in the first two Bowser levels
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_1 or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
		o.header.gfx.sharedChild = Area.gLoadedGraphNodes[IncludeModelIdsH.MODEL_BOWSER_KEY + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0xC000)
		ObjectHelpers.cur_obj_scale(F32(0.1))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCelebStarUnkF4, 1)
	else
		o.header.gfx.sharedChild = Area.gLoadedGraphNodes[IncludeModelIdsH.MODEL_STAR + 1]
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		ObjectHelpers.cur_obj_scale(F32(0.4))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCelebStarUnkF4, 0)
	end
end

-- from src/game/behaviors/celebration_star.inc.c:celeb_star_act_spin_around_mario L31-48
function celebration_star_inc.celeb_star_act_spin_around_mario()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * (buffer.readi32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation) // 2)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * (buffer.readi32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation) // 2)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x2000))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 40 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CELEB_STAR_ACT_FACE_CAMERA)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 35 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvCelebrationStarSparkle)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation) + 1))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCelebStarDiameterOfRotation) - 20))
	end
end

-- from src/game/behaviors/celebration_star.inc.c:celeb_star_act_face_camera L50-69
function celebration_star_inc.celeb_star_act_face_camera()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCelebStarUnkF4) == 0 then
			ObjectHelpers.cur_obj_scale(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 10.0))
		else
			ObjectHelpers.cur_obj_scale(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 30.0))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, marioObject.header.gfx.angle[2])
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 59 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/celebration_star.inc.c:bhv_celebration_star_loop L71-81
function celebration_star_inc.bhv_celebration_star_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.CELEB_STAR_ACT_SPIN_AROUND_MARIO then
		celebration_star_inc.celeb_star_act_spin_around_mario()
	elseif action == IncludeObjectConstantsH.CELEB_STAR_ACT_FACE_CAMERA then
		celebration_star_inc.celeb_star_act_face_camera()
	end
end

-- from src/game/behaviors/celebration_star.inc.c:bhv_celebration_star_sparkle_loop L83-89
function celebration_star_inc.bhv_celebration_star_sparkle_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 15.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 12 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/celebration_star.inc.c:bhv_star_key_collection_puff_spawner_loop L91-94
function celebration_star_inc.bhv_star_key_collection_puff_spawner_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	BehaviorActions.spawn_mist_particles_variable(0, 10, 30.0)
	o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

return celebration_star_inc
