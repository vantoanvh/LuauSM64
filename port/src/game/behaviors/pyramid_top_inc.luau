--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pyramid_top.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const Audio = require("../../rom/audio_recorder")

const pyramid_top_inc = {}

Registry.Register("src__game__behaviors__pyramid_top_inc", pyramid_top_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_init L17-26
function pyramid_top_inc.bhv_pyramid_top_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvPyramidPillarTouchDetector, 1789, 1024, 764, 0, 0, 0)
	ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvPyramidPillarTouchDetector, 1789, 896, -2579, 0, 0, 0)
	ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvPyramidPillarTouchDetector, -5883, 1024, -2579, 0, 0, 0)
	ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvPyramidPillarTouchDetector, -5883, 1024, 764, 0, 0, 0)
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_spinning L32-65
function pyramid_top_inc.bhv_pyramid_top_spinning()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Sway horizontally (no source comment on its purpose)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x4000) * 40.0))

	-- At first, move upward smoothly without rotating.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 60 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + ObjBehaviors.absf_2(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x2000) * 10.0)))
	else
		-- Then, rotate at an accelerating rate, and move upward at a constant rate.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) + 0x100)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) > 0x1800 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x1800)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 5.0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	end

	-- Every frame until 90 frames have passed, generate a pyramid fragment
	-- with a random velocity and angle.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 90 then
		const pyramidFragment = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_DIRT_ANIMATION, BehaviorIds.bhvPyramidTopFragment)
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 10.0) + 20.0)
		buffer.writei32(pyramidFragment.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oPyramidTopFragmentsScale, 0.8)
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oGravity, SrcEngineBehaviorScript.random_float() + 2.0)
	end

	-- After enough time, transition to the exploding state.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_TOP_ACT_EXPLODE)
	end
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_explode L70-88
function pyramid_top_inc.bhv_pyramid_top_explode()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	BehaviorActions.spawn_mist_particles_variable(0, 0, 690.0)

	-- Generate 30 pyramid fragments with random properties.
	for Index = 1, 30 do
		const pyramidFragment = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_DIRT_ANIMATION, BehaviorIds.bhvPyramidTopFragment)
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 50) + 80)
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 80) + 20)
		buffer.writei32(pyramidFragment.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oPyramidTopFragmentsScale, 3)
		buffer.writef32(pyramidFragment.rawData, IncludeObjectFieldsH.oGravity, F32(SrcEngineBehaviorScript.random_float() * 2) + 5)
	end

	-- Deactivate the pyramid top.
	o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_loop L90-115
function pyramid_top_inc.bhv_pyramid_top_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.PYRAMID_TOP_ACT_CHECK_IF_SOLVED then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPyramidTopPillarsTouched) == 4 then
			Audio.play_puzzle_jingle()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.PYRAMID_TOP_ACT_SPINNING)
		end
	elseif action == IncludeObjectConstantsH.PYRAMID_TOP_ACT_SPINNING then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_PYRAMID_TOP_SPIN)
		end

		pyramid_top_inc.bhv_pyramid_top_spinning()
	elseif action == IncludeObjectConstantsH.PYRAMID_TOP_ACT_EXPLODE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL2_PYRAMID_TOP_EXPLOSION)
		end

		pyramid_top_inc.bhv_pyramid_top_explode()
	end
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_fragment_init L120-125
function pyramid_top_inc.bhv_pyramid_top_fragment_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 3)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPyramidTopFragmentsScale))
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_top_fragment_loop L131-139
function pyramid_top_inc.bhv_pyramid_top_fragment_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjBehaviors.object_step()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x1000)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/pyramid_top.inc.c:bhv_pyramid_pillar_touch_detector_loop L145-152
function pyramid_top_inc.bhv_pyramid_pillar_touch_detector_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_become_tangible()
	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		-- Increase the pyramid top's count of pillars touched.
		const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
		buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oPyramidTopPillarsTouched, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPyramidTopPillarsTouched) + 1)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return pyramid_top_inc
