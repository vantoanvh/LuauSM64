--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/intro_lakitu.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroundParticlesInc = require("./ground_particles_inc")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/intro_lakitu_inc.luau:scratch
const Scratch = {
	intro_lakitu_set_offset_from_camera_dist = { 0 },
	intro_lakitu_set_offset_from_camera_focusPitch = { 0 },
	intro_lakitu_set_offset_from_camera_focusYaw = { 0 },
	intro_lakitu_set_offset_from_camera_offsetPitch = { 0 },
	intro_lakitu_set_offset_from_camera_offsetYaw = { 0 },
	intro_lakitu_set_focus_origin = { 0, 0, 0 },
	intro_lakitu_set_focus_dist = { 0 },
	intro_lakitu_set_focus_pitch = { 0 },
	intro_lakitu_set_focus_yaw = { 0 },
	intro_lakitu_set_pos_and_focus_newFocus = { 0, 0, 0 },
	intro_lakitu_set_pos_and_focus_newOffset = { 0, 0, 0 },
	intro_lakitu_set_pos_and_focus_splineSegment = { 0 },
	intro_lakitu_set_pos_and_focus_progress = { 0 },
	bhv_intro_lakitu_loop_sp64 = { 0, 0, 0 },
	bhv_intro_lakitu_loop_sp58 = { 0, 0, 0 },
	bhv_intro_lakitu_loop_sp4C = { 0, 0, 0 },
}

-- from src/game/behaviors/intro_lakitu.inc.c:data
const intro_lakitu_inc = {
	TIMER1 = 720,
	TIMER2 = 98,
}

Registry.Register("src__game__behaviors__intro_lakitu_inc", intro_lakitu_inc)

-- from src/game/behaviors/intro_lakitu.inc.c:intro_lakitu_set_offset_from_camera L12-24
function intro_lakitu_inc.intro_lakitu_set_offset_from_camera(obj: GroupsTypesHPlus3.Object, offset: { number })
	const gCamera = Camera.gCamera :: GroupsTypesHPlus3.Camera

	SrcEngineMathUtil.vec3f_add(offset, gCamera.pos)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(gCamera.pos, gCamera.focus, Scratch.intro_lakitu_set_offset_from_camera_dist, Scratch.intro_lakitu_set_offset_from_camera_focusPitch, Scratch.intro_lakitu_set_offset_from_camera_focusYaw)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(gCamera.pos, offset, Scratch.intro_lakitu_set_offset_from_camera_dist, Scratch.intro_lakitu_set_offset_from_camera_offsetPitch, Scratch.intro_lakitu_set_offset_from_camera_offsetYaw)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(gCamera.pos, offset, Scratch.intro_lakitu_set_offset_from_camera_dist[1], S16(Scratch.intro_lakitu_set_offset_from_camera_focusPitch[1] + Scratch.intro_lakitu_set_offset_from_camera_offsetPitch[1]), S16(Scratch.intro_lakitu_set_offset_from_camera_focusYaw[1] + Scratch.intro_lakitu_set_offset_from_camera_offsetYaw[1]))
	Camera.vec3f_to_object_pos(obj, offset)
end

-- from src/game/behaviors/intro_lakitu.inc.c:intro_lakitu_set_focus L26-39
function intro_lakitu_inc.intro_lakitu_set_focus(obj: GroupsTypesHPlus3.Object, newFocus: { number })
	SrcEngineMathUtil.vec3f_set(Scratch.intro_lakitu_set_focus_origin, 0.0, 0.0, 0.0)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.intro_lakitu_set_focus_origin, newFocus, Scratch.intro_lakitu_set_focus_dist, Scratch.intro_lakitu_set_focus_pitch, Scratch.intro_lakitu_set_focus_yaw)

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAnglePitch, Scratch.intro_lakitu_set_focus_pitch[1])
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oFaceAngleYaw, Scratch.intro_lakitu_set_focus_yaw[1])
end

-- from src/game/behaviors/intro_lakitu.inc.c:intro_lakitu_set_pos_and_focus L45-64
function intro_lakitu_inc.intro_lakitu_set_pos_and_focus(obj: GroupsTypesHPlus3.Object, offset: { GroupsTypesHPlus3.CutsceneSplinePoint }, focus: { GroupsTypesHPlus3.CutsceneSplinePoint }): number
	local splineFinished = 0
	local finished = false

	Scratch.intro_lakitu_set_pos_and_focus_splineSegment[1] = S16(TruncS32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegment)))
	Scratch.intro_lakitu_set_pos_and_focus_progress[1] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegmentProgress)

	finished = Camera.move_point_along_spline(Scratch.intro_lakitu_set_pos_and_focus_newFocus, offset, Scratch.intro_lakitu_set_pos_and_focus_splineSegment, Scratch.intro_lakitu_set_pos_and_focus_progress) == 1
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegmentProgress, Scratch.intro_lakitu_set_pos_and_focus_progress[1])

	if not finished then
		finished = Camera.move_point_along_spline(Scratch.intro_lakitu_set_pos_and_focus_newOffset, focus, Scratch.intro_lakitu_set_pos_and_focus_splineSegment, Scratch.intro_lakitu_set_pos_and_focus_progress) == 1
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegmentProgress, Scratch.intro_lakitu_set_pos_and_focus_progress[1])
	end

	if finished then
		splineFinished += 1
	end

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegment, Scratch.intro_lakitu_set_pos_and_focus_splineSegment[1])

	intro_lakitu_inc.intro_lakitu_set_offset_from_camera(obj, Scratch.intro_lakitu_set_pos_and_focus_newOffset)
	intro_lakitu_inc.intro_lakitu_set_focus(obj, Scratch.intro_lakitu_set_pos_and_focus_newFocus)

	return splineFinished
end

-- from src/game/behaviors/intro_lakitu.inc.c:bhv_intro_lakitu_loop L74-249
function intro_lakitu_inc.bhv_intro_lakitu_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gCamera = Camera.gCamera :: GroupsTypesHPlus3.Camera
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		ObjectHelpers.cur_obj_disable_rendering()

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegment, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituSplineSegmentProgress, 0.0)
		o.ptrData[IncludeObjectFieldsH.oIntroLakituCloud + 1] = ObjectHelpers.spawn_object_relative_with_scale(IncludeObjectConstantsH.CLOUD_BP_LAKITU_CLOUD, 0, 0, 0, 2.0, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvCloud)

		if gCamera.cutscene == GroupsTypesHPlus3.CUTSCENE_END_WAVING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 100)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == 1 then
		ObjectHelpers.cur_obj_enable_rendering()

		if Camera.gCutsceneTimer > 350 and Camera.gCutsceneTimer < 458 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, gCamera.pos[1])
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, gCamera.pos[2] + 500.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, gCamera.pos[3])
		end

		if Camera.gCutsceneTimer > 52 then
			SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_LAKITU_FLY_HIGHPRIO)
		end

		if intro_lakitu_inc.intro_lakitu_set_pos_and_focus(o, Camera.gIntroLakituStartToPipeOffsetFromCamera, Camera.gIntroLakituStartToPipeFocus) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

		if timer == 534 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_ACTION_FLYING_FAST)
		elseif timer == 581 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_ACTION_INTRO_UNK45E)
		elseif timer == 73 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1))
		elseif timer == 74 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) - 1))
		elseif timer == 82 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1))
		elseif timer == 84 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) - 1))
		end
	elseif action == 2 then
		if Camera.gCutsceneTimer > intro_lakitu_inc.TIMER1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk100, 1400.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk104, -4096.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108, 2048.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C, -200.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x8000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x800)
		end

		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_LAKITU_FLY_HIGHPRIO)
	elseif action == 3 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_LAKITU_FLY_HIGHPRIO)

		SrcEngineMathUtil.vec3f_set(Scratch.bhv_intro_lakitu_loop_sp58, -1128.0, 560.0, 4664.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x200))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk100, Camera.approach_f32_asymptotic(buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk100), 100.0, F32(0.03)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, SrcEngineMathUtil.atan2s(200.0, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 400.0)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, Camera.approach_s16_asymptotic(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000), 4))
		SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.bhv_intro_lakitu_loop_sp58, Scratch.bhv_intro_lakitu_loop_sp4C, buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk100), 0, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
		Scratch.bhv_intro_lakitu_loop_sp4C[2] = F32(Scratch.bhv_intro_lakitu_loop_sp4C[2] + F32(150.0 * SrcEngineMathUtilH.coss(S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk104))))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk104, buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk104) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108, Camera.approach_f32_asymptotic(buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108), 512.0, F32(0.05)))
		Scratch.bhv_intro_lakitu_loop_sp4C[1] = F32(Scratch.bhv_intro_lakitu_loop_sp4C[1] + buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C, Camera.approach_f32_asymptotic(buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C), 0.0, F32(0.05)))
		Camera.vec3f_to_object_pos(o, Scratch.bhv_intro_lakitu_loop_sp4C)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 31 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 158.0)
			GroundParticlesInc.spawn_mist_from_global()
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 158.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == intro_lakitu_inc.TIMER2 then
			ObjectHelpers.obj_mark_for_deletion(o)
			ObjectHelpers.obj_mark_for_deletion(o.ptrData[IncludeObjectFieldsH.oIntroLakituCloud + 1] :: GroupsTypesHPlus3.Object)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 14 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_ACTION_INTRO_UNK45F)
		end
	elseif action == 100 then
		ObjectHelpers.cur_obj_enable_rendering()

		SrcEngineMathUtil.vec3f_set(Scratch.bhv_intro_lakitu_loop_sp64, -100.0, 100.0, 300.0)
		Camera.offset_rotated(Scratch.bhv_intro_lakitu_loop_sp4C, gCamera.pos, Scratch.bhv_intro_lakitu_loop_sp64, Camera.sMarioCamState.faceAngle)
		Camera.vec3f_to_object_pos(o, Scratch.bhv_intro_lakitu_loop_sp4C)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x1000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0x9000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) / 2))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
	elseif action == 101 then
		Camera.object_pos_to_vec3f(Scratch.bhv_intro_lakitu_loop_sp4C, o)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Camera.approach_f32_asymptotic(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel), -10.0, F32(0.05)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x78))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + 0x40))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, Camera.camera_approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), Camera.calculate_yaw(Scratch.bhv_intro_lakitu_loop_sp4C, gCamera.pos), 0x200))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 105 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0xE00)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)

		ObjectHelpers.cur_obj_set_pos_via_transform()
	elseif action == 102 then
		Camera.object_pos_to_vec3f(Scratch.bhv_intro_lakitu_loop_sp4C, o)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Camera.approach_f32_asymptotic(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel), 60.0, F32(0.05)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, Camera.camera_approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), Camera.calculate_yaw(Scratch.bhv_intro_lakitu_loop_sp4C, gCamera.pos), 0x200))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 62 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Camera.approach_s16_asymptotic(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), 0x1800, 0x1E))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, Camera.camera_approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), -0x2000, 0x5A))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)

		ObjectHelpers.cur_obj_set_pos_via_transform()
	end
end

return intro_lakitu_inc
