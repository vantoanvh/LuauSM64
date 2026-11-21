--!strict
--!optimize 2

--[[
	Port of src/game/camera.c.
]]

const Registry = require("../../groups/registry")

const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludePROsH = require("../../include/PR/os_h")

const MemoryH = require("./memory_h")
const ObjectListProcessor = require("./object_list_processor")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const SrcEngineMathUtil = require("../engine/math_util")
const IncludeSm64H = require("../../include/sm64_h")
const LevelUpdate = require("./level_update")
const GameInit = require("./game_init")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const Area = require("./area")
const IncludeCourseTableH = require("../../include/course_table_h")
const SaveFile = require("./save_file")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const MarioActionsCutscene = require("./mario_actions_cutscene")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const ObjectHelpers = require("./object_helpers")
const ObjectListProcessorH = require("./object_list_processor_h")
const PaintingsH = require("./paintings_h")
const Audio = require("../rom/audio_recorder")
const IncludeSeqIdsH = require("../../include/seq_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/camera.luau:scratch
const Scratch = {
	focus_on_mario_marioPos = table.create(3, 0),
	set_pos_to_mario_marioPos = table.create(3, 0),
	set_pos_to_mario_posDist = { 0 },
	set_pos_to_mario_posPitch = { 0 },
	set_pos_to_mario_posYaw = { 0 },
	set_pos_to_mario_focDist = { 0 },
	set_pos_to_mario_focPitch = { 0 },
	set_pos_to_mario_focYaw = { 0 },
	rotate_in_xz_tempVec = table.create(3, 0) :: { number },
	rotate_in_yz_tempVec = table.create(3, 0) :: { number },
	is_range_behind_surface_checkDist = { 0 },
	is_range_behind_surface_checkPitch = { 0 },
	is_range_behind_surface_checkYaw = { 0 },
	is_range_behind_surface_checkPos = table.create(3, 0) :: { number },
	reduce_by_dist_from_camera_pos = table.create(3, 0),
	reduce_by_dist_from_camera_dist = { 0 },
	reduce_by_dist_from_camera_pitch = { 0 },
	reduce_by_dist_from_camera_yaw = { 0 },
	reduce_by_dist_from_camera_goalPitch = { 0 },
	reduce_by_dist_from_camera_goalYaw = { 0 },
	obj_rotate_towards_point_oPos = table.create(3, 0),
	obj_rotate_towards_point_dist = { 0 },
	obj_rotate_towards_point_pitch = { 0 },
	obj_rotate_towards_point_yaw = { 0 },
	move_point_along_spline_controlPoints = { table.create(3, 0), table.create(3, 0), table.create(3, 0), table.create(3, 0) },
	look_down_slopes_floor = {} :: { GroupsTypesHPlus3.Surface? },
	scale_along_line_tempVec = table.create(3, 0) :: { number },
	resolve_geometry_collisions_x = { 0 },
	resolve_geometry_collisions_y = { 0 },
	resolve_geometry_collisions_z = { 0 },
	resolve_geometry_collisions_surf = {} :: { GroupsTypesHPlus3.Surface? },
	set_pitch_shake_from_point_pos = table.create(3, 0),
	set_pitch_shake_from_point_dist = { 0 },
	set_pitch_shake_from_point_dummyPitch = { 0 },
	set_pitch_shake_from_point_dummyYaw = { 0 },
	pan_ahead_of_player_pan = table.create(3, 0),
	pan_ahead_of_player_dist = { 0 },
	pan_ahead_of_player_pitch = { 0 },
	pan_ahead_of_player_yaw = { 0 },
	pan_ahead_of_player_sPanDistance = { 0 },
	update_radial_camera_posY = { 0 },
	update_radial_camera_focusY = { 0 },
	set_camera_mode_dist = { 0 },
	set_camera_mode_pitch = { 0 },
	set_camera_mode_yaw = { 0 },
	clamp_pitch_dist = { 0 },
	clamp_pitch_pitch = { 0 },
	clamp_pitch_yaw = { 0 },
	is_pos_in_bounds_rel = table.create(3, 0) :: { number },
	update_8_directions_camera_posY = { 0 },
	update_8_directions_camera_focusY = { 0 },
	exit_c_up_surface = {} :: { GroupsTypesHPlus3.Surface? },
	exit_c_up_checkFoc = table.create(3, 0),
	exit_c_up_curPos = table.create(3, 0),
	exit_c_up_curPosX = { 0 },
	exit_c_up_curPosY = { 0 },
	exit_c_up_curPosZ = { 0 },
	exit_c_up_curDist = { 0 },
	exit_c_up_curPitch = { 0 },
	exit_c_up_curYaw = { 0 },
	find_mario_floor_and_ceil_surf = {} :: { GroupsTypesHPlus3.Surface? },
	is_within_100_units_of_mario_pos = table.create(3, 0),
	set_or_approach_vec3f_asymptotic_ref = { 0 },
	shake_camera_handheld_shakeOffset = table.create(3, 0) :: { number },
	shake_camera_handheld_shakeSpline = { table.create(3, 0), table.create(3, 0), table.create(3, 0), table.create(3, 0) },
	shake_camera_handheld_ref = { 0 },
	shake_camera_handheld_dist = { 0 },
	shake_camera_handheld_pitch = { 0 },
	shake_camera_handheld_yaw = { 0 },
	shake_camera_pitch_ref = { 0 },
	shake_camera_pitch_dist = { 0 },
	shake_camera_pitch_pitch = { 0 },
	shake_camera_pitch_yaw = { 0 },
	shake_camera_roll_ref = { 0 },
	shake_camera_yaw_ref = { 0 },
	shake_camera_yaw_dist = { 0 },
	shake_camera_yaw_pitch = { 0 },
	shake_camera_yaw_yaw = { 0 },
	approach_vec3f_asymptotic_current = { 0 },
	approach_vec3s_asymptotic_current = { 0 },
	warp_camera_displacement = table.create(3, 0),
	update_fixed_camera_focusFloorOff = { 0 },
	update_fixed_camera_distCamToFocus = { 0 },
	update_fixed_camera_faceAngle0 = { 0 },
	update_fixed_camera_faceAngle1 = { 0 },
	update_fixed_camera_pitch = { 0 },
	update_fixed_camera_yaw = { 0 },
	update_fixed_camera_ceiling = {} :: { GroupsTypesHPlus3.Surface? },
	update_fixed_camera_basePos = table.create(3, 0) :: { number },
	update_fixed_camera_posY = { 0 },
	cam_hmc_enter_maze_dist = { 0 },
	cam_hmc_enter_maze_pitch = { 0 },
	cam_hmc_enter_maze_yaw = { 0 },
	init_camera_floor = {} :: { GroupsTypesHPlus3.Surface? },
	init_camera_marioOffset = table.create(3, 0),
	set_focus_rel_mario_focFloorYOff = { 0 },
	offset_rotated_coords_to = table.create(3, 0),
	cam_castle_look_upstairs_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cam_castle_basement_look_downstairs_floor = {} :: { GroupsTypesHPlus3.Surface? },
	player2_rotate_cam_sCreditsPlayer2Yaw = { 0 },
	player2_rotate_cam_sCreditsPlayer2Pitch = { 0 },
	player2_rotate_cam_distCamToFocus = { 0 },
	player2_rotate_cam_pitch = { 0 },
	player2_rotate_cam_yaw = { 0 },
	pan_camera_distCamToFocus = { 0 },
	pan_camera_pitch = { 0 },
	pan_camera_yaw = { 0 },
	rotate_and_move_vec3f_dist = { 0 },
	rotate_and_move_vec3f_pitch = { 0 },
	rotate_and_move_vec3f_yaw = { 0 },
	cutscene_ending_fly_up_to_window_sCutsceneSplineSegment = { 0 },
	cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_ending_peach_descent_lower_focus_point = { 0 },
	cutscene_ending_mario_to_peach_sCutsceneSplineSegment = { 0 },
	cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_ending_look_up_at_castle_sCutsceneSplineSegment = { 0 },
	cutscene_ending_look_up_at_castle_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_ending_look_at_sky_sCutsceneSplineSegment = { 0 },
	cutscene_ending_look_at_sky_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_ending_kiss_here_we_go_pos = table.create(3, 0),
	cutscene_ending_kiss_here_we_go_foc = table.create(3, 0),
	cutscene_grand_star_front_of_mario_goalDist = { 0 },
	cutscene_grand_star_front_of_mario_goalPitch = { 0 },
	cutscene_grand_star_front_of_mario_goalYaw = { 0 },
	cutscene_grand_star_front_of_mario_dist = { 0 },
	cutscene_grand_star_front_of_mario_pitch = { 0 },
	cutscene_grand_star_front_of_mario_yaw = { 0 },
	cutscene_grand_star_accel_cvar2_value = { 0 },
	cutscene_grand_star_approach_mario_value = { 0 },
	cutscene_grand_star_focus_mario_foc = table.create(3, 0),
	cutscene_grand_star_fly_move_to_mario_posOff = table.create(3, 0),
	cutscene_grand_star_fly_move_to_mario_value = { 0 },
	cutscene_grand_star_fly_mario_offscreen_point = { 0 },
	cutscene_grand_star_fly_app_cvars_point = { 0 },
	cutscene_grand_star_fly_app_cvars_goalPos = table.create(3, 0),
	cutscene_grand_star_fly_app_cvars_goalFoc = table.create(3, 0),
	cutscene_grand_star_fly_app_cvars_dist = { 0 },
	cutscene_grand_star_fly_app_cvars_pitch = { 0 },
	cutscene_grand_star_fly_app_cvars_yaw = { 0 },
	focus_in_front_of_mario_goalFocus = table.create(3, 0),
	focus_in_front_of_mario_offset = table.create(3, 0),
	cutscene_dance_move_to_mario_dist = { 0 },
	cutscene_dance_move_to_mario_pitch = { 0 },
	cutscene_dance_move_to_mario_yaw = { 0 },
	star_dance_bound_yaw_dummyPitch = { 0 },
	star_dance_bound_yaw_yaw = { 0 },
	star_dance_bound_yaw_distCamToMario = { 0 },
	cutscene_dance_closeup_focus_mario_marioPos = table.create(3, 0),
	cutscene_dance_closeup_fly_above_pitch = { 0 },
	cutscene_dance_closeup_fly_above_yaw = { 0 },
	cutscene_dance_closeup_fly_above_dist = { 0 },
	cutscene_dance_closeup_fly_closer_pitch = { 0 },
	cutscene_dance_closeup_fly_closer_yaw = { 0 },
	cutscene_dance_closeup_fly_closer_dist = { 0 },
	cutscene_dance_fly_away_approach_mario_dist = { 0 },
	cutscene_dance_fly_away_approach_mario_pitch = { 0 },
	cutscene_dance_fly_away_approach_mario_yaw = { 0 },
	cutscene_dance_fly_away_focus_mario_marioPos = table.create(3, 0),
	cutscene_dance_fly_away_start_areaCenter = table.create(3, 0),
	cutscene_star_spawn_focus_star_starPos = table.create(3, 0),
	cutscene_bowser_arena_focus_sine_point = { 0 },
	cutscene_bowser_arena_adjust_offsets_angle = { 0 },
	cutscene_bowser_arena_adjust_offsets_point = { 0 },
	cutscene_bowser_arena_pan_left_point = { 0 },
	cutscene_goto_cvar_pos_nextDist = { 0 },
	cutscene_goto_cvar_pos_nextPitch = { 0 },
	cutscene_goto_cvar_pos_nextYaw = { 0 },
	cutscene_goto_cvar_pos_cannonDist = { 0 },
	cutscene_goto_cvar_pos_cannonPitch = { 0 },
	cutscene_goto_cvar_pos_cannonYaw = { 0 },
	cutscene_goto_cvar_pos_curDist = { 0 },
	cutscene_goto_cvar_pos_curPitch = { 0 },
	cutscene_goto_cvar_pos_curYaw = { 0 },
	water_death_move_to_mario_side_dist = { 0 },
	water_death_move_to_mario_side_pitch = { 0 },
	water_death_move_to_mario_side_yaw = { 0 },
	cutscene_death_stomach_start_offset = table.create(3, 0),
	cutscene_bbh_death_start_dir = table.create(3, 0),
	cutscene_prepare_cannon_fly_to_cannon_angle = { 0 },
	cutscene_suffocation_fly_away_target = table.create(3, 0),
	cutscene_suffocation_fly_away_offset = table.create(3, 0),
	cutscene_suffocation_rotate_dist = { 0 },
	cutscene_suffocation_rotate_pitch = { 0 },
	cutscene_suffocation_rotate_yaw = { 0 },
	cutscene_dialog_move_mario_shoulder_dist = { 0 },
	cutscene_dialog_move_mario_shoulder_pitch = { 0 },
	cutscene_dialog_move_mario_shoulder_yaw = { 0 },
	cutscene_dialog_move_mario_shoulder_focus = table.create(3, 0),
	cutscene_dialog_move_mario_shoulder_pos = table.create(3, 0),
	cutscene_dialog_move_mario_shoulder_posY = { 0 },
	unused_cam_to_mario_dir = table.create(3, 0),
	cutscene_non_painting_set_cam_pos_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_exit_bowser_succ_focus_left_value = { 0 },
	cutscene_pyramid_top_explode_warp_dist = { 0 },
	cutscene_pyramid_top_explode_warp_pitch = { 0 },
	cutscene_pyramid_top_explode_warp_yaw = { 0 },
	cutscene_pyramid_top_explode_closeup_dist = { 0 },
	cutscene_pyramid_top_explode_closeup_pitch = { 0 },
	cutscene_pyramid_top_explode_closeup_yaw = { 0 },
	cutscene_cap_switch_press_rotate_around_mario_dist = { 0 },
	cutscene_cap_switch_press_rotate_around_mario_pitch = { 0 },
	cutscene_cap_switch_press_rotate_around_mario_yaw = { 0 },
	cutscene_cap_switch_press_approach_mario_dist = { 0 },
	cutscene_cap_switch_press_approach_mario_pitch = { 0 },
	cutscene_cap_switch_press_approach_mario_yaw = { 0 },
	cutscene_cap_switch_press_approach_mario_focus = { 0 },
	cutscene_cap_switch_press_pan_left_angle = { 0 },
	cutscene_unlock_key_door_start_posOff = table.create(3, 0),
	cutscene_unlock_key_door_start_focusOff = table.create(3, 0),
	cutscene_unlock_key_door_focus_lock_point = { 0 },
	cutscene_intro_peach_follow_pipe_spline_segment = { 0 },
	cutscene_intro_peach_follow_pipe_spline_progress = { 0 },
	cutscene_intro_peach_mario_appears_value = { 0 },
	cutscene_end_waving_sCutsceneSplineSegment = { 0 },
	cutscene_end_waving_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_sliding_doors_open_start_dist = { 0 },
	cutscene_sliding_doors_open_start_pitch = { 0 },
	cutscene_sliding_doors_open_start_yaw = { 0 },
	cutscene_sliding_doors_go_under_doorway_point = { 0 },
	cutscene_sliding_doors_fly_back_up_point = { 0 },
	cutscene_sliding_doors_follow_mario_pos = table.create(3, 0),
	cutscene_sliding_doors_follow_mario_point = { 0 },
	cutscene_enter_painting_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_enter_painting_highFloor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_enter_painting_paintingPos = table.create(3, 0),
	cutscene_enter_painting_focus = table.create(3, 0),
	cutscene_enter_painting_focusOffset = table.create(3, 0),
	cutscene_enter_painting_paintingAngle = table.create(3, 0),
	cutscene_exit_painting_start_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_exit_painting_move_to_mario_pos = table.create(3, 0),
	cutscene_exit_painting_move_to_mario_value = { 0 },
	cutscene_exit_painting_move_to_floor_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_exit_painting_move_to_floor_floorHeight = table.create(3, 0),
	cutscene_exit_painting_move_to_floor_value = { 0 },
	cutscene_unused_exit_start_offset = table.create(3, 0),
	cutscene_unused_exit_start_marioAngle = table.create(3, 0),
	cutscene_unused_exit_focus_mario_focus = table.create(3, 0),
	cutscene_enter_cannon_raise_angle = { 0 },
	cutscene_enter_cannon_raise_floor = {} :: { GroupsTypesHPlus3.Surface? },
	cutscene_enter_cannon_raise_cannonFocus = table.create(3, 0),
	cutscene_enter_cannon_raise_cannonAngle = table.create(3, 0),
	cutscene_enter_cannon_start_dist = { 0 },
	cutscene_enter_cannon_start_pitch = { 0 },
	cutscene_enter_cannon_start_yaw = { 0 },
	cutscene_door_follow_mario_dist = { 0 },
	cutscene_door_follow_mario_pitch = { 0 },
	cutscene_door_follow_mario_yaw = { 0 },
	shake_camera_fov_shakeAmplitude = { 0 },
	approach_fov_20_fov = { 0 },
	zoom_fov_30_fov = { 0 },
	fov_default_fov = { 0 },
	unused_approach_fov_30_fov = { 0 },
	approach_fov_30_fov = { 0 },
	approach_fov_60_fov = { 0 },
	approach_fov_80_fov = { 0 },
	set_yaw_shake_from_point_pos = table.create(3, 0),
	set_yaw_shake_from_point_dist = { 0 },
	set_yaw_shake_from_point_dummyPitch = { 0 },
	set_yaw_shake_from_point_dummyYaw = { 0 },
	mode_8_directions_camera_pos = table.create(3, 0),
	update_outward_radial_camera_posY = { 0 },
	update_outward_radial_camera_focusY = { 0 },
	mode_outward_radial_camera_pos = table.create(3, 0),
	set_camera_height_surface = {} :: { GroupsTypesHPlus3.Surface? },
	offset_yaw_outward_radial_yaw = { 0 },
	offset_yaw_outward_radial_areaCenter = table.create(3, 0),
	is_surf_within_bounding_box_sx = table.create(3, 0),
	is_surf_within_bounding_box_sy = table.create(3, 0),
	is_surf_within_bounding_box_sz = table.create(3, 0),
	rotate_camera_around_walls_colData = SrcEngineSurfaceCollisionH.new_WallCollisionData(),
	rotate_camera_around_walls_dummyDist = { 0 },
	rotate_camera_around_walls_dummyPitch = { 0 },
	rotate_camera_around_walls_yawFromMario = { 0 },
	rotate_camera_around_walls_coarseRadius = { 0 },
	rotate_camera_around_walls_fineRadius = { 0 },
	update_parallel_tracking_camera_path = { table.create(3, 0), table.create(3, 0) },
	update_parallel_tracking_camera_marioOffset = table.create(3, 0),
	update_parallel_tracking_camera_camOffset = table.create(3, 0),
	update_parallel_tracking_camera_focOffset = table.create(3, 0),
	update_parallel_tracking_camera_pathPitch = { 0 },
	update_parallel_tracking_camera_pathYaw = { 0 },
	update_parallel_tracking_camera_camParDist = { 0 },
	update_parallel_tracking_camera_pathLength = { 0 },
	update_parallel_tracking_camera_marioFloorDist = { 0 },
	update_parallel_tracking_camera_marioPos = table.create(3, 0),
	update_parallel_tracking_camera_pathAngle = table.create(3, 0),
	update_parallel_tracking_camera_oldPos = table.create(3, 0),
	update_parallel_tracking_camera_prevPathPos = table.create(3, 0),
	update_parallel_tracking_camera_nextPathPos = table.create(3, 0),
	update_parallel_tracking_camera_prevPitch = { 0 },
	update_parallel_tracking_camera_nextPitch = { 0 },
	update_parallel_tracking_camera_prevYaw = { 0 },
	update_parallel_tracking_camera_nextYaw = { 0 },
	update_parallel_tracking_camera_transOff = { 0 },
	update_boss_fight_camera_floor = {} :: { GroupsTypesHPlus3.Surface? },
	update_boss_fight_camera_secondFocus = table.create(3, 0),
	update_boss_fight_camera_holdFocOffset = table.create(3, 0),
	mode_parallel_tracking_camera_dummy = { 0 },
	radial_camera_move_avoidYaw = { 0 },
	radial_camera_move_sModeOffsetYaw = { 0 },
	mode_radial_camera_pos = table.create(3, 0),
	update_behind_mario_camera_dist = { 0 },
	update_behind_mario_camera_pitch = { 0 },
	update_behind_mario_camera_yaw = { 0 },
	update_behind_mario_camera_ref = { 0 },
	mode_behind_mario_floor = {} :: { GroupsTypesHPlus3.Surface? },
	mode_behind_mario_newPos = table.create(3, 0),
	mode_behind_mario_oldPos = table.create(3, 0),
	mode_behind_mario_distCamToFocus = { 0 },
	mode_behind_mario_camPitch = { 0 },
	mode_behind_mario_camYaw = { 0 },
	update_slide_camera_floor = {} :: { GroupsTypesHPlus3.Surface? },
	update_slide_camera_pos = table.create(3, 0),
	update_slide_camera_distCamToFocus = { 0 },
	update_slide_camera_camPitch = { 0 },
	update_slide_camera_camYaw = { 0 },
	update_slide_camera_posY = { 0 },
	set_camera_mode_radial_focus = table.create(3, 0),
	intro_peach_move_camera_start_to_pipe_offset = table.create(3, 0),
	intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment = { 0 },
	intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress = { 0 },
	cutscene_star_spawn_update_boss_fight_pos = table.create(3, 0),
	cutscene_star_spawn_update_boss_fight_focus = table.create(3, 0),
	collide_with_walls_collisionData = SrcEngineSurfaceCollisionH.new_WallCollisionData(),
	collide_with_walls_newPos = { table.create(3, 0), table.create(3, 0), table.create(3, 0), table.create(3, 0) },
	update_default_camera_tempPos = table.create(3, 0),
	update_default_camera_cPos = table.create(3, 0),
	update_default_camera_cFloor = {} :: { GroupsTypesHPlus3.Surface? },
	update_default_camera_tempFloor = {} :: { GroupsTypesHPlus3.Surface? },
	update_default_camera_ceil = {} :: { GroupsTypesHPlus3.Surface? },
	update_default_camera_dist = { 0 },
	update_default_camera_avoidYaw = { 0 },
	update_default_camera_pitch = { 0 },
	update_default_camera_yaw = { 0 },
	update_default_camera_posHeight = { 0 },
	update_default_camera_focHeight = { 0 },
	update_default_camera_tempPitch = { 0 },
	update_default_camera_tempYaw = { 0 },
	update_default_camera_xzDist = { 0 },
	update_default_camera_sCSideButtonYaw = { 0 },
	update_spiral_stairs_camera_focPitch = { 0 },
	update_spiral_stairs_camera_focYaw = { 0 },
	update_spiral_stairs_camera_posPitch = { 0 },
	update_spiral_stairs_camera_posYaw = { 0 },
	update_spiral_stairs_camera_cPos = table.create(3, 0),
	update_spiral_stairs_camera_checkPos = table.create(3, 0),
	update_spiral_stairs_camera_floor = {} :: { GroupsTypesHPlus3.Surface? },
	update_spiral_stairs_camera_dist = { 0 },
	update_spiral_stairs_camera_focusHeight = { 0 },
	update_spiral_stairs_camera_focusY = { 0 },
	mode_c_up_camera_ref = { 0 },
	cutscene_door_move_behind_mario_camOffset = table.create(3, 0),
	cutscene_door_move_behind_mario_doorRotation = { 0 },
	next_lakitu_state_nextPos = table.create(3, 0),
	next_lakitu_state_nextFoc = table.create(3, 0),
	next_lakitu_state_startPos = table.create(3, 0),
	next_lakitu_state_startFoc = table.create(3, 0),
	next_lakitu_state_goalDist = { 0 },
	next_lakitu_state_goalPitch = { 0 },
	next_lakitu_state_goalYaw = { 0 },
	next_lakitu_state_refDist = { 0 },
	next_lakitu_state_refPitch = { 0 },
	next_lakitu_state_refYaw = { 0 },
	next_lakitu_state_ref = { 0 },
	next_lakitu_state_floor = {} :: { GroupsTypesHPlus3.Surface? },
	next_lakitu_state_x = { 0 },
	next_lakitu_state_y = { 0 },
	next_lakitu_state_z = { 0 },
	cutscene_ending_mario_fall_focus_mario_offset = table.create(3, 0),
	cutscene_prepare_cannon_fly_back_value = { 0 },
	update_lakitu_floor = {} :: { GroupsTypesHPlus3.Surface? },
	update_lakitu_newPos = table.create(3, 0),
	update_lakitu_newFoc = table.create(3, 0),
	update_lakitu_yaw = { 0 },
	update_lakitu_speed = { 0 },
	update_lakitu_dist = { 0 },
	update_lakitu_pitch = { 0 },
	update_lakitu_oldYaw = { 0 },
	update_lakitu_roll = { 0 },
	cutscene_credits_segment = { 0 },
	cutscene_credits_progress = { 0 },
	cutscene_ending_peach_appears_pos = { 0 },
	cutscene_ending_peach_appears_focus = { 0 },
	cutscene_ending_follow_peach_descent_segment = { 0 },
	cutscene_ending_follow_peach_descent_progress = { 0 },
	cutscene_ending_peach_descent_back_to_mario_pos = table.create(3, 0),
	cutscene_ending_peach_descent_back_to_mario_segment = { 0 },
	cutscene_ending_peach_descent_back_to_mario_progress = { 0 },
	cutscene_ending_peach_descent_back_to_mario_posY = { 0 },
	cutscene_red_coin_star_focus_xz_value = { 0 },
	cutscene_red_coin_star_focus_y_value = { 0 },
	cutscene_red_coin_star_warp_dist = { 0 },
	cutscene_red_coin_star_warp_pitch = { 0 },
	cutscene_red_coin_star_warp_yaw = { 0 },
	cutscene_cap_switch_press_dist = { 0 },
	cutscene_cap_switch_press_pitch = { 0 },
	cutscene_cap_switch_press_yaw = { 0 },
	cam_bbh_fall_into_pool_dir = table.create(3, 0),
	zoom_out_if_paused_and_outside_dist = { 0 },
	zoom_out_if_paused_and_outside_pitch = { 0 },
	zoom_out_if_paused_and_outside_yaw = { 0 },
	camera_course_processing_center = table.create(3, 0),
	camera_course_processing_bounds = table.create(3, 0),
	camera_course_processing_mode = buffer.create(1),
}

-- from src/game/camera.c:data
const camera = {
	CBUTTON_MASK = bit32.bor(bit32.bor(bit32.bor(IncludePROsH.U_CBUTTONS, IncludePROsH.D_CBUTTONS), IncludePROsH.L_CBUTTONS), IncludePROsH.R_CBUTTONS),
	-- from src/game/camera.c:sOldPosition L82-82
	sOldPosition = table.create(3, 0),
	-- from src/game/camera.c:sOldFocus L86-86
	sOldFocus = table.create(3, 0),
	-- from src/game/camera.c:gPlayerCameraState L91-91
	gPlayerCameraState = {
		{
			action = 0,
			pos = table.create(3, 0),
			faceAngle = table.create(3, 0),
			headRotation = table.create(3, 0),
			unused = 0,
			cameraEvent = 0,
			usedObj = nil,
		},
		{
			action = 0,
			pos = table.create(3, 0),
			faceAngle = table.create(3, 0),
			headRotation = table.create(3, 0),
			unused = 0,
			cameraEvent = 0,
			usedObj = nil,
		},
	} :: { GroupsTypesHPlus3.PlayerCameraState },
	-- from src/game/camera.c:sPlayer2FocusOffset L95-95
	sPlayer2FocusOffset = table.create(3, 0),
	-- from src/game/camera.c:sCreditsPlayer2Pitch L99-99
	sCreditsPlayer2Pitch = 0,
	-- from src/game/camera.c:sCreditsPlayer2Yaw L103-103
	sCreditsPlayer2Yaw = 0,
	-- from src/game/camera.c:sFramesPaused L107-107
	sFramesPaused = 0,
	-- from src/game/camera.c:gLakituState L175-175
	gLakituState = {
		curFocus = table.create(3, 0),
		curPos = table.create(3, 0),
		goalFocus = table.create(3, 0),
		goalPos = table.create(3, 0),
		filler1 = buffer.create(12),
		mode = 0,
		defMode = 0,
		filler2 = buffer.create(10),
		focusDistance = 0,
		oldPitch = 0,
		oldYaw = 0,
		oldRoll = 0,
		shakeMagnitude = table.create(3, 0),
		shakePitchPhase = 0,
		shakePitchVel = 0,
		shakePitchDecay = 0,
		unusedVec1 = table.create(3, 0),
		unusedVec2 = table.create(3, 0),
		filler3 = buffer.create(8),
		roll = 0,
		yaw = 0,
		nextYaw = 0,
		focus = table.create(3, 0),
		pos = table.create(3, 0),
		shakeRollPhase = 0,
		shakeRollVel = 0,
		shakeRollDecay = 0,
		shakeYawPhase = 0,
		shakeYawVel = 0,
		shakeYawDecay = 0,
		focHSpeed = 0,
		focVSpeed = 0,
		posHSpeed = 0,
		posVSpeed = 0,
		keyDanceRoll = 0,
		lastFrameAction = 0,
		unused = 0,
	},
	-- from src/game/camera.c:sFOVState L176-176
	sFOVState = {
		fovFunc = 0,
		fov = 0,
		fovOffset = 0,
		unusedIsSleeping = 0,
		shakeAmplitude = 0,
		shakePhase = 0,
		shakeSpeed = 0,
		decay = 0,
	},
	-- from src/game/camera.c:sModeTransition L177-177
	sModeTransition = {
		posPitch = 0,
		posYaw = 0,
		posDist = 0,
		focPitch = 0,
		focYaw = 0,
		focDist = 0,
		framesLeft = 0,
		marioPos = table.create(3, 0),
		unused = 0,
	},
	-- from src/game/camera.c:sMarioGeometry L178-178
	sMarioGeometry = {
		currFloor = nil,
		currFloorHeight = 0,
		currFloorType = 0,
		currCeil = nil,
		currCeilType = 0,
		currCeilHeight = 0,
		prevFloor = nil,
		prevFloorHeight = 0,
		prevFloorType = 0,
		prevCeil = nil,
		prevCeilHeight = 0,
		prevCeilType = 0,
		waterHeight = 0,
	} :: GroupsTypesHPlus3.PlayerGeometry,
	-- from src/game/camera.c:gCamera L179-179
	gCamera = nil :: GroupsTypesHPlus3.Camera?,
	-- from src/game/camera.c:unusedFreeRoamWallYaw L180-180
	unusedFreeRoamWallYaw = 0,
	-- from src/game/camera.c:sAvoidYawVel L181-181
	sAvoidYawVel = 0,
	-- from src/game/camera.c:sCameraYawAfterDoorCutscene L182-182
	sCameraYawAfterDoorCutscene = 0,
	-- from src/game/camera.c:sCurCreditsSplinePos L186-186
	sCurCreditsSplinePos = {
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
	},
	-- from src/game/camera.c:sCurCreditsSplineFocus L191-191
	sCurCreditsSplineFocus = {
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
		{ index = 0, speed = 0, point = table.create(3, 0) },
	},
	-- from src/game/camera.c:unusedSplinePitch L193-193
	unusedSplinePitch = 0,
	-- from src/game/camera.c:unusedSplineYaw L194-194
	unusedSplineYaw = 0,
	-- from src/game/camera.c:sCutsceneSplineSegmentProgress L200-200
	sCutsceneSplineSegmentProgress = 0,
	-- from src/game/camera.c:sCutsceneSplineSegment L205-205
	sCutsceneSplineSegment = 0,
	-- from src/game/camera.c:unused8033B6E8 L206-206
	unused8033B6E8 = 0,
	-- from src/game/camera.c:sHandheldShakeSpline L209-209
	sHandheldShakeSpline = {
		{ index = 0, unused = 0, point = table.create(3, 0) },
		{ index = 0, unused = 0, point = table.create(3, 0) },
		{ index = 0, unused = 0, point = table.create(3, 0) },
		{ index = 0, unused = 0, point = table.create(3, 0) },
	},
	-- from src/game/camera.c:sHandheldShakeMag L210-210
	sHandheldShakeMag = 0,
	-- from src/game/camera.c:sHandheldShakeTimer L211-211
	sHandheldShakeTimer = 0,
	-- from src/game/camera.c:sHandheldShakeInc L212-212
	sHandheldShakeInc = 0,
	-- from src/game/camera.c:sHandheldShakePitch L213-213
	sHandheldShakePitch = 0,
	-- from src/game/camera.c:sHandheldShakeYaw L214-214
	sHandheldShakeYaw = 0,
	-- from src/game/camera.c:sHandheldShakeRoll L215-215
	sHandheldShakeRoll = 0,
	-- from src/game/camera.c:gCutsceneObjSpawn L220-220
	gCutsceneObjSpawn = 0,
	-- from src/game/camera.c:gObjCutsceneDone L225-225
	gObjCutsceneDone = 0,
	-- from src/game/camera.c:unused8033B30C L227-227
	unused8033B30C = 0,
	-- from src/game/camera.c:unused8033B310 L228-228
	unused8033B310 = 0,
	-- from src/game/camera.c:sSelectionFlags L233-233
	sSelectionFlags = 0,
	-- from src/game/camera.c:gCameraMovementFlags L238-238
	gCameraMovementFlags = 0,
	-- from src/game/camera.c:unused8033B316 L239-239
	unused8033B316 = 0,
	-- from src/game/camera.c:sStatusFlags L246-246
	sStatusFlags = 0,
	-- from src/game/camera.c:s2ndRotateFlags L251-251
	s2ndRotateFlags = 0,
	-- from src/game/camera.c:unused8033B31A L252-252
	unused8033B31A = 0,
	-- from src/game/camera.c:sCameraSoundFlags L256-256
	sCameraSoundFlags = 0,
	-- from src/game/camera.c:sCButtonsPressed L260-260
	sCButtonsPressed = 0,
	-- from src/game/camera.c:sCutsceneDialogID L264-264
	sCutsceneDialogID = 0,
	-- from src/game/camera.c:sCutsceneShot L268-268
	sCutsceneShot = 0,
	-- from src/game/camera.c:gCutsceneTimer L272-272
	gCutsceneTimer = 0,
	-- from src/game/camera.c:unused8033B3E8 L273-273
	unused8033B3E8 = 0,
	-- from src/game/camera.c:sAreaYaw L280-280
	sAreaYaw = 0,
	-- from src/game/camera.c:sAreaYawChange L285-285
	sAreaYawChange = 0,
	-- from src/game/camera.c:sLakituDist L290-290
	sLakituDist = 0,
	-- from src/game/camera.c:sLakituPitch L295-295
	sLakituPitch = 0,
	-- from src/game/camera.c:sZoomAmount L300-300
	sZoomAmount = 0,
	-- from src/game/camera.c:sCSideButtonYaw L302-302
	sCSideButtonYaw = 0,
	-- from src/game/camera.c:sBehindMarioSoundTimer L307-307
	sBehindMarioSoundTimer = 0,
	-- from src/game/camera.c:sZeroZoomDist L312-312
	sZeroZoomDist = 0,
	-- from src/game/camera.c:sCUpCameraPitch L317-317
	sCUpCameraPitch = 0,
	-- from src/game/camera.c:sModeOffsetYaw L321-321
	sModeOffsetYaw = 0,
	-- from src/game/camera.c:sSpiralStairsYawOffset L328-328
	sSpiralStairsYawOffset = 0,
	-- from src/game/camera.c:s8DirModeBaseYaw L333-333
	s8DirModeBaseYaw = 0,
	-- from src/game/camera.c:s8DirModeYawOffset L337-337
	s8DirModeYawOffset = 0,
	-- from src/game/camera.c:sPanDistance L342-342
	sPanDistance = 0,
	-- from src/game/camera.c:sCannonYOffset L348-348
	sCannonYOffset = 0,
	-- from src/game/camera.c:sCutsceneVars L354-354
	sCutsceneVars = {
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
		{
			unused1 = 0,
			point = table.create(3, 0),
			unusedPoint = table.create(3, 0),
			angle = table.create(3, 0),
			unused2 = 0,
		},
	},
	-- from src/game/camera.c:sModeInfo L355-355
	sModeInfo = {
		newMode = 0,
		lastMode = 0,
		max = 0,
		frame = 0,
		transitionStart = { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 },
		transitionEnd = { focus = table.create(3, 0), pos = table.create(3, 0), dist = 0, pitch = 0, yaw = 0 },
	},
	-- from src/game/camera.c:sCastleEntranceOffset L359-359
	sCastleEntranceOffset = table.create(3, 0),
	-- from src/game/camera.c:sParTrackIndex L364-364
	sParTrackIndex = 0,
	-- from src/game/camera.c:sParTrackPath L369-369
	sParTrackPath = nil :: { GroupsTypesHPlus3.ParallelTrackingPoint }?,
	-- from src/game/camera.c:sParTrackTransOff L378-378
	sParTrackTransOff = { pos = table.create(3, 0), focus = table.create(3, 0), panDist = 0, cannonYOffset = 0 },
	-- from src/game/camera.c:sCameraStoreCUp L383-383
	sCameraStoreCUp = { pos = table.create(3, 0), focus = table.create(3, 0), panDist = 0, cannonYOffset = 0 },
	-- from src/game/camera.c:sCameraStoreCutscene L388-388
	sCameraStoreCutscene = { pos = table.create(3, 0), focus = table.create(3, 0), panDist = 0, cannonYOffset = 0 },
	-- from src/game/camera.c:unused8032CFC0 L391-391
	unused8032CFC0 = 0,
	-- from src/game/camera.c:gCutsceneFocus L392-392
	gCutsceneFocus = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/camera.c:unused8032CFC8 L394-394
	unused8032CFC8 = 0,
	-- from src/game/camera.c:unused8032CFCC L395-395
	unused8032CFCC = 0,
	-- from src/game/camera.c:gSecondCameraFocus L400-400
	gSecondCameraFocus = nil :: GroupsTypesHPlus3.Object?,
	-- from src/game/camera.c:sYawSpeed L405-405
	sYawSpeed = 0x400,
	-- from src/game/camera.c:gCurrLevelArea L406-406
	gCurrLevelArea = 0,
	-- from src/game/camera.c:gPrevLevel L407-407
	gPrevLevel = 0,
	-- from src/game/camera.c:unused8032CFE0 L409-409
	unused8032CFE0 = 1000.0,
	-- from src/game/camera.c:unused8032CFE4 L410-410
	unused8032CFE4 = 800.0,
	-- from src/game/camera.c:unused8032CFE8 L411-411
	unused8032CFE8 = 0,
	-- from src/game/camera.c:gCameraZoomDist L412-412
	gCameraZoomDist = 800.0,
	-- from src/game/camera.c:sObjectCutscene L417-417
	sObjectCutscene = 0,
	-- from src/game/camera.c:gRecentCutscene L424-424
	gRecentCutscene = 0,
	-- from src/game/camera.c:sFramesSinceCutsceneEnded L430-430
	sFramesSinceCutsceneEnded = 0,
	-- from src/game/camera.c:sCutsceneDialogResponse L438-438
	sCutsceneDialogResponse = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE,
	-- from src/game/camera.c:unused8032D008 L441-441
	unused8032D008 = 0,
	-- from src/game/camera.c:sFixedModeBasePosition L442-442
	sFixedModeBasePosition = { 646.0, 143.0, -1513.0 },
	-- from src/game/camera.c:sUnusedModeBasePosition_2 L443-443
	sUnusedModeBasePosition_2 = { 646.0, 143.0, -1513.0 },
	-- from src/game/camera.c:sUnusedModeBasePosition_3 L444-444
	sUnusedModeBasePosition_3 = { 646.0, 143.0, -1513.0 },
	-- from src/game/camera.c:sUnusedModeBasePosition_4 L445-445
	sUnusedModeBasePosition_4 = { 646.0, 143.0, -1513.0 },
	-- from src/game/camera.c:sUnusedModeBasePosition_5 L446-446
	sUnusedModeBasePosition_5 = { 646.0, 143.0, -1513.0 },
	-- from src/game/camera.c:unused8032D0A8 L1658-1658
	unused8032D0A8 = { 14, 1, 2, 4 },
	-- from src/game/camera.c:unused8032D0B0 L1659-1659
	unused8032D0B0 = { 16, 9, 17, 0 },
	-- from src/game/camera.c:sDanceCutsceneTable L1667-1670
	sDanceCutsceneTable = {
		GroupsTypesHPlus3.CUTSCENE_DANCE_FLY_AWAY,
		GroupsTypesHPlus3.CUTSCENE_DANCE_ROTATE,
		GroupsTypesHPlus3.CUTSCENE_DANCE_CLOSEUP,
		GroupsTypesHPlus3.CUTSCENE_KEY_DANCE,
		GroupsTypesHPlus3.CUTSCENE_DANCE_DEFAULT,
		0,
		0,
		0,
		0,
		1,
	},
	-- from src/game/camera.c:unusedDanceInfo1 L1681-1683
	unusedDanceInfo1 = { point = { -3026.0, 912.0, -2148.0 }, distTarget = 600.0, distMultiplier = 0.30000001192092896 },
	-- from src/game/camera.c:unusedDanceType L1685-1685
	unusedDanceType = 0,
	-- from src/game/camera.c:unusedDanceInfo2 L1687-1689
	unusedDanceInfo2 = { point = { -4676.0, 917.0, -3802.0 }, distTarget = 600.0, distMultiplier = 0.30000001192092896 },
	-- from src/game/camera.c:sBBHLibraryParTrackPath L1696-1700
	sBBHLibraryParTrackPath = {
		{ startOfPath = 1, pos = { -929.0, 1619.0, -1490.0 }, distThresh = 50.0, zoom = 0.0 },
		{ startOfPath = 0, pos = { -2118.0, 1619.0, -1490.0 }, distThresh = 50.0, zoom = 0.0 },
		{ startOfPath = 0, pos = { 0.0, 0.0, 0.0 }, distThresh = 0.0, zoom = 0.0 },
	},
	NULL_TRIGGER = {
		area = 0,
		event = nil,
		centerX = 0,
		centerY = 0,
		centerZ = 0,
		boundsX = 0,
		boundsY = 0,
		boundsZ = 0,
		boundsYaw = 0,
	} :: GroupsTypesHPlus3.CameraTrigger,
	-- from src/game/camera.c:sIntroStartToPipePosition L6386-6395
	sIntroStartToPipePosition = {
		{ index = 0, speed = 0, point = { 2122, 8762, 9114 } },
		{ index = 0, speed = 0, point = { 2122, 8762, 9114 } },
		{ index = 1, speed = 0, point = { 2122, 7916, 9114 } },
		{ index = 1, speed = 0, point = { 2122, 7916, 9114 } },
		{ index = 2, speed = 0, point = { 957, 5166, 8613 } },
		{ index = 3, speed = 0, point = { 589, 4338, 7727 } },
		{ index = 4, speed = 0, point = { 690, 3366, 6267 } },
		{ index = 5, speed = 0, point = { -1600, 2151, 4955 } },
		{ index = 6, speed = 0, point = { -1557, 232, 1283 } },
		{ index = 7, speed = 0, point = { -6962, -295, 2729 } },
		{ index = 8, speed = 0, point = { -6979, 131, 3246 } },
		{ index = 9, speed = 0, point = { -6360, -283, 4044 } },
		{ index = 0, speed = 0, point = { -5695, -334, 5264 } },
		{ index = 1, speed = 0, point = { -5568, -319, 7933 } },
		{ index = 2, speed = 0, point = { -3848, -200, 6278 } },
		{ index = 3, speed = 0, point = { -965, -263, 6092 } },
		{ index = 4, speed = 0, point = { 1607, 2465, 6329 } },
		{ index = 5, speed = 0, point = { 2824, 180, 3548 } },
		{ index = 6, speed = 0, point = { 1236, 136, 945 } },
		{ index = 0, speed = 0, point = { 448, 136, 564 } },
		{ index = 0, speed = 0, point = { 448, 136, 564 } },
		{ index = 0, speed = 0, point = { 448, 136, 564 } },
		{ index = -1, speed = 0, point = { 448, 136, 564 } },
	},
	-- from src/game/camera.c:sIntroStartToPipeFocus L6397-6410
	sIntroStartToPipeFocus = {
		{ index = 0, speed = 50, point = { 1753, 29800, 8999 } },
		{ index = 0, speed = 50, point = { 1753, 29800, 8999 } },
		{ index = 1, speed = 50, point = { 1753, 8580, 8999 } },
		{ index = 1, speed = 100, point = { 1753, 8580, 8999 } },
		{ index = 2, speed = 50, point = { 520, 5400, 8674 } },
		{ index = 3, speed = 50, point = { 122, 4437, 7875 } },
		{ index = 4, speed = 50, point = { 316, 3333, 6538 } },
		{ index = 5, speed = 36, point = { -1526, 2189, 5448 } },
		{ index = 6, speed = 50, point = { -1517, 452, 1731 } },
		{ index = 7, speed = 50, point = { -6659, -181, 3109 } },
		{ index = 8, speed = 17, point = { -6649, 183, 3618 } },
		{ index = 9, speed = 20, point = { -6009, -214, 4395 } },
		{ index = 0, speed = 50, point = { -5258, -175, 5449 } },
		{ index = 1, speed = 36, point = { -5158, -266, 7651 } },
		{ index = 2, speed = 26, point = { -3351, -192, 6222 } },
		{ index = 3, speed = 25, point = { -483, -137, 6060 } },
		{ index = 4, speed = 100, point = { 1833, 2211, 5962 } },
		{ index = 5, speed = 26, point = { 3022, 207, 3090 } },
		{ index = 6, speed = 20, point = { 1250, 197, 449 } },
		{ index = 7, speed = 50, point = { 248, 191, 227 } },
		{ index = 7, speed = 0, point = { 48, 191, 227 } },
		{ index = 7, speed = 0, point = { 48, 191, 227 } },
		{ index = -1, speed = 0, point = { 48, 191, 227 } },
	},
	-- from src/game/camera.c:sIntroPipeToDialogPosition L6417-6423
	sIntroPipeToDialogPosition = {
		{ index = 0, speed = 0, point = { -785, 625, 4527 } },
		{ index = 1, speed = 0, point = { -785, 625, 4527 } },
		{ index = 2, speed = 0, point = { -1286, 644, 4376 } },
		{ index = 3, speed = 0, point = { -1286, 623, 4387 } },
		{ index = 4, speed = 0, point = { -1286, 388, 3963 } },
		{ index = 5, speed = 0, point = { -1286, 358, 4093 } },
		{ index = 6, speed = 0, point = { -1386, 354, 4159 } },
		{ index = 7, speed = 0, point = { -1477, 306, 4223 } },
		{ index = 8, speed = 0, point = { -1540, 299, 4378 } },
		{ index = 9, speed = 0, point = { -1473, 316, 4574 } },
		{ index = 0, speed = 0, point = { -1328, 485, 5017 } },
		{ index = 0, speed = 0, point = { -1328, 485, 5017 } },
		{ index = 0, speed = 0, point = { -1328, 485, 5017 } },
		{ index = -1, speed = 0, point = { -1328, 485, 5017 } },
	},
	-- from src/game/camera.c:sIntroPipeToDialogFocus L6437-6443
	sIntroPipeToDialogFocus = {
		{ index = 0, speed = 20, point = { -1248, 450, 4596 } },
		{ index = 1, speed = 59, point = { -1258, 485, 4606 } },
		{ index = 2, speed = 59, point = { -1379, 344, 4769 } },
		{ index = 3, speed = 20, point = { -1335, 366, 4815 } },
		{ index = 4, speed = 23, point = { -1315, 370, 4450 } },
		{ index = 5, speed = 40, point = { -1322, 333, 4591 } },
		{ index = 6, speed = 25, point = { -1185, 329, 4616 } },
		{ index = 7, speed = 21, point = { -1059, 380, 4487 } },
		{ index = 8, speed = 14, point = { -1086, 421, 4206 } },
		{ index = 9, speed = 21, point = { -1321, 346, 4098 } },
		{ index = 0, speed = 0, point = { -1328, 385, 4354 } },
		{ index = 0, speed = 0, point = { -1328, 385, 4354 } },
		{ index = 0, speed = 0, point = { -1328, 385, 4354 } },
		{ index = -1, speed = 0, point = { -1328, 385, 4354 } },
	},
	-- from src/game/camera.c:sEndingFlyToWindowPos L6446-6451
	sEndingFlyToWindowPos = {
		{ index = 0, speed = 0, point = { -86, 876, 640 } },
		{ index = 1, speed = 0, point = { -86, 876, 610 } },
		{ index = 2, speed = 0, point = { -66, 945, 393 } },
		{ index = 3, speed = 0, point = { -80, 976, 272 } },
		{ index = 4, speed = 0, point = { -66, 1306, -36 } },
		{ index = 5, speed = 0, point = { -70, 1869, -149 } },
		{ index = 6, speed = 0, point = { -10, 2093, -146 } },
		{ index = 7, speed = 0, point = { -10, 2530, -248 } },
		{ index = 8, speed = 0, point = { -10, 2530, -263 } },
		{ index = 9, speed = 0, point = { -10, 2530, -273 } },
	},
	-- from src/game/camera.c:sEndingFlyToWindowFocus L6453-6458
	sEndingFlyToWindowFocus = {
		{ index = 0, speed = 50, point = { -33, 889, -7 } },
		{ index = 1, speed = 35, point = { -33, 889, -7 } },
		{ index = 2, speed = 31, point = { -17, 1070, -193 } },
		{ index = 3, speed = 25, point = { -65, 1182, -272 } },
		{ index = 4, speed = 20, point = { -64, 1559, -542 } },
		{ index = 5, speed = 25, point = { -68, 2029, -677 } },
		{ index = 6, speed = 25, point = { -9, 2204, -673 } },
		{ index = 7, speed = 25, point = { -8, 2529, -772 } },
		{ index = 8, speed = 0, point = { -8, 2529, -772 } },
		{ index = 9, speed = 0, point = { -8, 2529, -772 } },
		{ index = -1, speed = 0, point = { -8, 2529, -772 } },
	},
	-- from src/game/camera.c:sEndingPeachDescentCamPos L6460-6468
	sEndingPeachDescentCamPos = {
		{ index = 0, speed = 50, point = { 1, 120, -1150 } },
		{ index = 1, speed = 50, point = { 1, 120, -1150 } },
		{ index = 2, speed = 40, point = { 118, 121, -1199 } },
		{ index = 3, speed = 40, point = { 147, 74, -1306 } },
		{ index = 4, speed = 40, point = { 162, 95, -1416 } },
		{ index = 5, speed = 40, point = { 25, 111, -1555 } },
		{ index = 6, speed = 40, point = { -188, 154, -1439 } },
		{ index = 7, speed = 40, point = { -203, 181, -1242 } },
		{ index = 8, speed = 40, point = { 7, 191, -1057 } },
		{ index = 9, speed = 40, point = { 262, 273, -1326 } },
		{ index = 0, speed = 40, point = { -4, 272, -1627 } },
		{ index = 1, speed = 35, point = { -331, 206, -1287 } },
		{ index = 2, speed = 30, point = { -65, 219, -877 } },
		{ index = 3, speed = 25, point = { 6, 216, -569 } },
		{ index = 4, speed = 25, point = { -8, 157, 40 } },
		{ index = 5, speed = 25, point = { -4, 106, 200 } },
		{ index = 6, speed = 25, point = { -6, 72, 574 } },
		{ index = 7, speed = 0, point = { -6, 72, 574 } },
		{ index = 8, speed = 0, point = { -6, 72, 574 } },
		{ index = -1, speed = 0, point = { -6, 72, 574 } },
	},
	-- from src/game/camera.c:sEndingMarioToPeachPos L6470-6474
	sEndingMarioToPeachPos = {
		{ index = 0, speed = 0, point = { -130, 1111, -1815 } },
		{ index = 1, speed = 0, point = { -131, 1052, -1820 } },
		{ index = 2, speed = 0, point = { -271, 1008, -1651 } },
		{ index = 3, speed = 0, point = { -439, 1043, -1398 } },
		{ index = 4, speed = 0, point = { -433, 1040, -1120 } },
		{ index = 5, speed = 0, point = { -417, 1040, -1076 } },
		{ index = 6, speed = 0, point = { -417, 1040, -1076 } },
		{ index = 7, speed = 0, point = { -417, 1040, -1076 } },
		{ index = -1, speed = 0, point = { -417, 1040, -1076 } },
	},
	-- from src/game/camera.c:sEndingMarioToPeachFocus L6476-6480
	sEndingMarioToPeachFocus = {
		{ index = 0, speed = 50, point = { -37, 1020, -1332 } },
		{ index = 1, speed = 20, point = { -36, 1012, -1330 } },
		{ index = 2, speed = 20, point = { -24, 1006, -1215 } },
		{ index = 3, speed = 20, point = { 28, 1002, -1224 } },
		{ index = 4, speed = 24, point = { 45, 1013, -1262 } },
		{ index = 5, speed = 35, point = { 34, 1000, -1287 } },
		{ index = 6, speed = 0, point = { 34, 1000, -1287 } },
		{ index = 7, speed = 0, point = { 34, 1000, -1287 } },
		{ index = -1, speed = 0, point = { 34, 1000, -1287 } },
	},
	-- from src/game/camera.c:sEndingLookUpAtCastle L6482-6486
	sEndingLookUpAtCastle = {
		{ index = 0, speed = 50, point = { 200, 1066, -1414 } },
		{ index = 0, speed = 50, point = { 200, 1066, -1414 } },
		{ index = 0, speed = 30, point = { 198, 1078, -1412 } },
		{ index = 0, speed = 33, point = { 15, 1231, -1474 } },
		{ index = 0, speed = 39, point = { -94, 1381, -1368 } },
		{ index = 0, speed = 0, point = { -92, 1374, -1379 } },
		{ index = 0, speed = 0, point = { -92, 1374, -1379 } },
		{ index = -1, speed = 0, point = { -92, 1374, -1379 } },
	},
	-- from src/game/camera.c:sEndingLookAtSkyFocus L6488-6496
	sEndingLookAtSkyFocus = {
		{ index = 0, speed = 50, point = { 484, 1368, -888 } },
		{ index = 0, speed = 72, point = { 479, 1372, -892 } },
		{ index = 0, speed = 50, point = { 351, 1817, -918 } },
		{ index = 0, speed = 50, point = { 351, 1922, -598 } },
		{ index = 0, speed = 0, point = { 636, 2027, -415 } },
		{ index = 0, speed = 0, point = { 636, 2027, -415 } },
		{ index = -1, speed = 0, point = { 636, 2027, -415 } },
	},
	-- from src/game/camera.c:gIntroLakituStartToPipeFocus L9684-9697
	gIntroLakituStartToPipeFocus = {
		{ index = 0, speed = 32, point = { 58, -250, 346 } },
		{ index = 1, speed = 50, point = { -159, -382, 224 } },
		{ index = 2, speed = 37, point = { 0, -277, 237 } },
		{ index = 3, speed = 15, point = { 1, -44, 245 } },
		{ index = 4, speed = 35, point = { 0, -89, 228 } },
		{ index = 5, speed = 15, point = { 28, 3, 259 } },
		{ index = 6, speed = 25, point = { -38, -201, 371 } },
		{ index = 7, speed = 20, point = { -642, 118, 652 } },
		{ index = 8, speed = 25, point = { 103, -90, 861 } },
		{ index = 9, speed = 25, point = { 294, 145, 579 } },
		{ index = 10, speed = 30, point = { 220, -42, 500 } },
		{ index = 11, speed = 20, point = { 10, -134, 200 } },
		{ index = 12, speed = 20, point = { -143, -145, 351 } },
		{ index = 13, speed = 14, point = { -256, -65, 528 } },
		{ index = 14, speed = 20, point = { -251, -52, 459 } },
		{ index = 15, speed = 25, point = { -382, 520, 395 } },
		{ index = 16, speed = 25, point = { -341, 240, 653 } },
		{ index = 17, speed = 5, point = { -262, 700, 143 } },
		{ index = 18, speed = 15, point = { -760, 32, 27 } },
		{ index = 19, speed = 20, point = { -756, -6, -26 } },
		{ index = 20, speed = 20, point = { -613, 5, 424 } },
		{ index = 21, speed = 20, point = { -22, -100, 312 } },
		{ index = 22, speed = 25, point = { 212, 80, 61 } },
		{ index = 23, speed = 20, point = { 230, -28, 230 } },
		{ index = 24, speed = 35, point = { -83, -51, 303 } },
		{ index = 25, speed = 17, point = { 126, 90, 640 } },
		{ index = 26, speed = 9, point = { 158, 95, 763 } },
		{ index = 27, speed = 8, point = { 113, -25, 1033 } },
		{ index = 28, speed = 20, point = { 57, -53, 1291 } },
		{ index = 29, speed = 15, point = { 73, -34, 1350 } },
		{ index = 30, speed = 7, point = { 0, 96, 1400 } },
		{ index = 31, speed = 8, point = { -59, 269, 1450 } },
		{ index = 32, speed = 15, point = { 57, 1705, 1500 } },
		{ index = 0, speed = 15, point = { -227, 511, 1550 } },
		{ index = -1, speed = 15, point = { -227, 511, 1600 } },
	},
	-- from src/game/camera.c:gIntroLakituStartToPipeOffsetFromCamera L9699-9712
	gIntroLakituStartToPipeOffsetFromCamera = {
		{ index = 0, speed = 0, point = { -46, 87, -15 } },
		{ index = 1, speed = 0, point = { -38, 91, -11 } },
		{ index = 2, speed = 0, point = { -31, 93, -13 } },
		{ index = 3, speed = 0, point = { -50, 84, -16 } },
		{ index = 4, speed = 0, point = { -52, 83, -17 } },
		{ index = 5, speed = 0, point = { -10, 99, 3 } },
		{ index = 6, speed = 0, point = { -54, 83, -10 } },
		{ index = 7, speed = 0, point = { -31, 85, -40 } },
		{ index = 8, speed = 0, point = { -34, 91, 19 } },
		{ index = 9, speed = 0, point = { -9, 95, 28 } },
		{ index = 10, speed = 0, point = { 17, 72, 66 } },
		{ index = 11, speed = 0, point = { 88, -7, 45 } },
		{ index = 12, speed = 0, point = { 96, -6, -26 } },
		{ index = 13, speed = 0, point = { 56, -1, -82 } },
		{ index = 14, speed = 0, point = { 40, 65, -63 } },
		{ index = 15, speed = 0, point = { -26, -3, -96 } },
		{ index = 16, speed = 0, point = { 92, 82, 19 } },
		{ index = 17, speed = 0, point = { 92, 32, 19 } },
		{ index = 18, speed = 0, point = { 92, 32, 19 } },
		{ index = 19, speed = 0, point = { 92, 102, 19 } },
		{ index = 20, speed = 0, point = { -69, 59, -70 } },
		{ index = 21, speed = 0, point = { -77, 109, -61 } },
		{ index = 22, speed = 0, point = { -87, 59, -46 } },
		{ index = 23, speed = 0, point = { -99, -3, 11 } },
		{ index = 24, speed = 0, point = { -99, -11, 5 } },
		{ index = 25, speed = 0, point = { -97, -6, 19 } },
		{ index = 26, speed = 0, point = { -97, 22, -7 } },
		{ index = 27, speed = 0, point = { -98, -11, -13 } },
		{ index = 28, speed = 0, point = { -97, -11, 19 } },
		{ index = 29, speed = 0, point = { -91, -11, 38 } },
		{ index = 30, speed = 0, point = { -76, -11, 63 } },
		{ index = 31, speed = 0, point = { -13, 33, 93 } },
		{ index = 32, speed = 0, point = { 51, -11, 84 } },
		{ index = 33, speed = 0, point = { 51, -11, 84 } },
		{ index = -1, speed = 0, point = { 51, -11, 84 } },
	},
	-- from src/game/camera.c:gEndWavingPos L9714-9718
	gEndWavingPos = {
		{ index = 0, speed = 0, point = { -5, 975, -917 } },
		{ index = 0, speed = 0, point = { -5, 975, -917 } },
		{ index = 0, speed = 0, point = { -5, 975, -917 } },
		{ index = 0, speed = 0, point = { -76, 1067, 742 } },
		{ index = 0, speed = 0, point = { -105, 1576, 3240 } },
		{ index = 0, speed = 0, point = { -177, 1709, 5586 } },
		{ index = 0, speed = 0, point = { -177, 1709, 5586 } },
		{ index = 0, speed = 0, point = { -177, 1709, 5586 } },
		{ index = 0, speed = 0, point = { -177, 1709, 5586 } },
	},
	-- from src/game/camera.c:gEndWavingFocus L9720-9724
	gEndWavingFocus = {
		{ index = 0, speed = 50, point = { 18, 1013, -1415 } },
		{ index = 0, speed = 100, point = { 17, 1037, -1412 } },
		{ index = 0, speed = 100, point = { 16, 1061, -1408 } },
		{ index = 0, speed = 100, point = { -54, 1053, 243 } },
		{ index = 0, speed = 100, point = { -84, 1575, 2740 } },
		{ index = 0, speed = 50, point = { -156, 1718, 5086 } },
		{ index = 0, speed = 0, point = { -156, 1718, 5086 } },
		{ index = 0, speed = 0, point = { -156, 1718, 5086 } },
		{ index = 0, speed = 0, point = { -156, 1718, 5086 } },
	},
	-- from src/game/camera.c:sDanceCutsceneIndexTable L10788-10791
	sDanceCutsceneIndexTable = {
		{ 0x44, 0x44, 0x44, 0x04 },
		{ 0x00, 0x20, 0x22, 0x04 },
		{ 0x00, 0x00, 0x02, 0x04 },
		{ 0x22, 0x22, 0x22, 0x04 },
		{ 0x00, 0x22, 0x00, 0x04 },
		{ 0x22, 0x22, 0x22, 0x04 },
		{ 0x22, 0x22, 0x22, 0x04 },
		{ 0x12, 0x12, 0x12, 0x04 },
		{ 0x02, 0x22, 0x22, 0x04 },
		{ 0x22, 0x22, 0x22, 0x04 },
		{ 0x20, 0x20, 0x20, 0x04 },
		{ 0x22, 0x01, 0x22, 0x04 },
		{ 0x00, 0x00, 0x00, 0x04 },
		{ 0x11, 0x11, 0x12, 0x04 },
		{ 0x22, 0x22, 0x22, 0x04 },
		{ 0x00, 0x00, 0x00, 0x04 },
		{ 0x43, 0x44, 0x44, 0x04 },
		{ 0x43, 0x44, 0x44, 0x04 },
		{ 0x43, 0x44, 0x44, 0x04 },
		{ 0x42, 0x44, 0x44, 0x04 },
		{ 0x44, 0x44, 0x44, 0x04 },
		{ 0x40, 0x44, 0x44, 0x04 },
		{ 0x42, 0x44, 0x44, 0x04 },
		{ 0x40, 0x44, 0x44, 0x04 },
		{ 0x42, 0x44, 0x44, 0x04 },
		{ 0x44, 0x44, 0x44, 0x04 },
		{ 0x44, 0x44, 0x44, 0x04 },
	},
	-- from src/game/camera.c:sZoomOutAreaMasks L10809-10830
	sZoomOutAreaMasks = { 0, 0, 16, 0, 17, 17, 48, 16, 17, 16, 16, 1, 1, 0, 16, 17, 16, 1, 1, 0 },
	-- from src/game/camera.c:sBoBCreditsSplinePositions L10839-10845
	sBoBCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { 5984, 3255, 4975 } },
		{ index = 2, speed = 0, point = { 4423, 3315, 1888 } },
		{ index = 3, speed = 0, point = { 776, 2740, -1825 } },
		{ index = 4, speed = 0, point = { -146, 3894, -3167 } },
		{ index = -1, speed = 0, point = { 741, 4387, -5474 } },
	},
	-- from src/game/camera.c:sBoBCreditsSplineFocus L10847-10853
	sBoBCreditsSplineFocus = {
		{ index = 0, speed = 30, point = { 5817, 3306, 4507 } },
		{ index = 0, speed = 40, point = { 4025, 3378, 1593 } },
		{ index = 0, speed = 50, point = { 1088, 2652, -2205 } },
		{ index = 0, speed = 60, point = { 205, 3959, -3517 } },
		{ index = -1, speed = 60, point = { 1231, 4400, -5649 } },
	},
	-- from src/game/camera.c:sWFCreditsSplinePositions L10855-10861
	sWFCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -301, 1399, 2643 } },
		{ index = 0, speed = 0, point = { -182, 2374, 4572 } },
		{ index = 0, speed = 0, point = { 4696, 3864, 413 } },
		{ index = 0, speed = 0, point = { 1738, 4891, -1516 } },
		{ index = -1, speed = 0, point = { 1783, 4891, -1516 } },
	},
	-- from src/game/camera.c:sWFCreditsSplineFocus L10863-10869
	sWFCreditsSplineFocus = {
		{ index = 1, speed = 30, point = { -249, 1484, 2153 } },
		{ index = 2, speed = 40, point = { -200, 2470, 4082 } },
		{ index = 3, speed = 40, point = { 4200, 3916, 370 } },
		{ index = 4, speed = 40, point = { 1523, 4976, -1072 } },
		{ index = -1, speed = 40, point = { 1523, 4976, -1072 } },
	},
	-- from src/game/camera.c:sJRBCreditsSplinePositions L10871-10877
	sJRBCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 5538, -4272, 2376 } },
		{ index = 0, speed = 0, point = { 5997, -3303, 2261 } },
		{ index = 0, speed = 0, point = { 6345, -3255, 2179 } },
		{ index = 0, speed = 0, point = { 6345, -3255, 2179 } },
		{ index = -1, speed = 0, point = { 6694, -3203, 2116 } },
	},
	-- from src/game/camera.c:sJRBCreditsSplineFocus L10879-10885
	sJRBCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { 5261, -4683, 2443 } },
		{ index = 0, speed = 50, point = { 5726, -3675, 2456 } },
		{ index = 0, speed = 50, point = { 6268, -2817, 2409 } },
		{ index = 0, speed = 50, point = { 6596, -2866, 2369 } },
		{ index = -1, speed = 50, point = { 7186, -3153, 2041 } },
	},
	-- from src/game/camera.c:sCCMSlideCreditsSplinePositions L10887-10893
	sCCMSlideCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -6324, 6745, -5626 } },
		{ index = 1, speed = 0, point = { -6324, 6745, -5626 } },
		{ index = 2, speed = 0, point = { -6108, 6762, -5770 } },
		{ index = 3, speed = 0, point = { -5771, 6787, -5962 } },
		{ index = -1, speed = 0, point = { -5672, 6790, -5979 } },
	},
	-- from src/game/camera.c:sCCMSlideCreditsSplineFocus L10895-10901
	sCCMSlideCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -5911, 6758, -5908 } },
		{ index = 1, speed = 50, point = { -5911, 6758, -5908 } },
		{ index = 2, speed = 50, point = { -5652, 6814, -5968 } },
		{ index = 3, speed = 50, point = { -5277, 6801, -6043 } },
		{ index = -1, speed = 50, point = { -5179, 6804, -6060 } },
	},
	-- from src/game/camera.c:sBBHCreditsSplinePositions L10903-10908
	sBBHCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { 1088, 341, 2447 } },
		{ index = 2, speed = 0, point = { 1338, 610, 2808 } },
		{ index = 3, speed = 0, point = { 2267, 1612, 2966 } },
		{ index = -1, speed = 0, point = { 2296, 1913, 2990 } },
	},
	-- from src/game/camera.c:sBBHCreditsSplineFocus L10910-10915
	sBBHCreditsSplineFocus = {
		{ index = 1, speed = 50, point = { 1160, 263, 1958 } },
		{ index = 2, speed = 50, point = { 1034, 472, 2436 } },
		{ index = 3, speed = 50, point = { 1915, 1833, 2688 } },
		{ index = -1, speed = 50, point = { 2134, 2316, 2742 } },
	},
	-- from src/game/camera.c:sHMCCreditsSplinePositions L10917-10923
	sHMCCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { -5952, 1807, -5882 } },
		{ index = 2, speed = 0, point = { -5623, 1749, -4863 } },
		{ index = 3, speed = 0, point = { -5472, 1955, -2520 } },
		{ index = 4, speed = 0, point = { -5544, 1187, -1085 } },
		{ index = -1, speed = 0, point = { -5547, 391, -721 } },
	},
	-- from src/game/camera.c:sHMCCreditsSplineFocus L10925-10931
	sHMCCreditsSplineFocus = {
		{ index = 1, speed = 210, point = { -5952, 1884, -6376 } },
		{ index = 2, speed = 58, point = { -5891, 1711, -5283 } },
		{ index = 3, speed = 30, point = { -5595, 1699, -2108 } },
		{ index = 4, speed = 31, point = { -5546, 794, -777 } },
		{ index = -1, speed = 31, point = { -5548, -85, -572 } },
	},
	-- from src/game/camera.c:sTHIWigglerCreditsSplinePositions L10933-10937
	sTHIWigglerCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { -1411, 2474, -1276 } },
		{ index = 2, speed = 0, point = { -1606, 2479, -434 } },
		{ index = -1, speed = 0, point = { -1170, 2122, 1337 } },
	},
	-- from src/game/camera.c:sTHIWigglerCreditsSplineFocus L10939-10943
	sTHIWigglerCreditsSplineFocus = {
		{ index = 1, speed = 50, point = { -1053, 2512, -928 } },
		{ index = 2, speed = 50, point = { -1234, 2377, -114 } },
		{ index = -1, speed = 50, point = { -758, 2147, 1054 } },
	},
	-- from src/game/camera.c:sVolcanoCreditsSplinePositions L10945-10952
	sVolcanoCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -1445, 1094, 1617 } },
		{ index = 0, speed = 0, point = { -1509, 649, 871 } },
		{ index = 0, speed = 0, point = { -1133, 420, -248 } },
		{ index = 0, speed = 0, point = { -778, 359, -1052 } },
		{ index = 0, speed = 0, point = { -565, 260, -1730 } },
		{ index = -1, speed = 0, point = { 1274, 473, -275 } },
	},
	-- from src/game/camera.c:sVolcanoCreditsSplineFocus L10954-10961
	sVolcanoCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -1500, 757, 1251 } },
		{ index = 0, speed = 50, point = { -1401, 439, 431 } },
		{ index = 0, speed = 50, point = { -749, 270, -532 } },
		{ index = 0, speed = 50, point = { -396, 270, -1363 } },
		{ index = 0, speed = 50, point = { -321, 143, -2151 } },
		{ index = -1, speed = 50, point = { 1002, 460, -694 } },
	},
	-- from src/game/camera.c:sSSLCreditsSplinePositions L10963-10970
	sSSLCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -4262, 4658, -5015 } },
		{ index = 0, speed = 0, point = { -3274, 2963, -4661 } },
		{ index = 0, speed = 0, point = { -2568, 812, -6528 } },
		{ index = 0, speed = 0, point = { -414, 660, -7232 } },
		{ index = 0, speed = 0, point = { 1466, 660, -6898 } },
		{ index = -1, speed = 0, point = { 2724, 660, -6298 } },
	},
	-- from src/game/camera.c:sSSLCreditsSplineFocus L10972-10979
	sSSLCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -4083, 4277, -4745 } },
		{ index = 0, speed = 50, point = { -2975, 2574, -4759 } },
		{ index = 0, speed = 50, point = { -2343, 736, -6088 } },
		{ index = 0, speed = 50, point = { -535, 572, -6755 } },
		{ index = 0, speed = 50, point = { 1311, 597, -6427 } },
		{ index = -1, speed = 50, point = { 2448, 612, -5884 } },
	},
	-- from src/game/camera.c:sDDDCreditsSplinePositions L10981-10989
	sDDDCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -874, -4933, 366 } },
		{ index = 0, speed = 0, point = { -1463, -4782, 963 } },
		{ index = 0, speed = 0, point = { -1893, -4684, 1303 } },
		{ index = 0, speed = 0, point = { -2818, -4503, 1583 } },
		{ index = 0, speed = 0, point = { -4095, -2924, 730 } },
		{ index = 0, speed = 0, point = { -4737, -1594, -63 } },
		{ index = -1, speed = 0, point = { -4681, -1084, -623 } },
	},
	-- from src/game/camera.c:sDDDCreditsSplineFocus L10991-10999
	sDDDCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -1276, -4683, 622 } },
		{ index = 0, speed = 50, point = { -1858, -4407, 1097 } },
		{ index = 0, speed = 50, point = { -2324, -4332, 1318 } },
		{ index = 0, speed = 50, point = { -3138, -4048, 1434 } },
		{ index = 0, speed = 50, point = { -4353, -2444, 533 } },
		{ index = 0, speed = 50, point = { -4807, -1169, -436 } },
		{ index = -1, speed = 50, point = { -4665, -664, -1007 } },
	},
	-- from src/game/camera.c:sSLCreditsSplinePositions L11001-11006
	sSLCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 939, 6654, 6196 } },
		{ index = 0, speed = 0, point = { 1873, 5160, 3714 } },
		{ index = 0, speed = 0, point = { 3120, 3564, 1314 } },
		{ index = -1, speed = 0, point = { 2881, 4231, 573 } },
	},
	-- from src/game/camera.c:sSLCreditsSplineFocus L11008-11013
	sSLCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { 875, 6411, 5763 } },
		{ index = 0, speed = 50, point = { 1659, 4951, 3313 } },
		{ index = 0, speed = 50, point = { 2630, 3565, 1215 } },
		{ index = -1, speed = 50, point = { 2417, 4056, 639 } },
	},
	-- from src/game/camera.c:sWDWCreditsSplinePositions L11015-11020
	sWDWCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 3927, 2573, 3685 } },
		{ index = 0, speed = 0, point = { 2389, 2054, 1210 } },
		{ index = 0, speed = 0, point = { 2309, 2069, 22 } },
		{ index = -1, speed = 0, point = { 2122, 2271, -979 } },
	},
	-- from src/game/camera.c:sWDWCreditsSplineFocus L11022-11027
	sWDWCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { 3637, 2460, 3294 } },
		{ index = 0, speed = 50, point = { 1984, 2067, 918 } },
		{ index = 0, speed = 50, point = { 1941, 2255, -261 } },
		{ index = -1, speed = 50, point = { 1779, 2587, -1158 } },
	},
	-- from src/game/camera.c:sTTMCreditsSplinePositions L11029-11036
	sTTMCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 386, 2535, 644 } },
		{ index = 0, speed = 0, point = { 1105, 2576, 918 } },
		{ index = 0, speed = 0, point = { 3565, 2261, 2098 } },
		{ index = 0, speed = 0, point = { 6715, -2791, 4554 } },
		{ index = 0, speed = 0, point = { 3917, -3130, 3656 } },
		{ index = -1, speed = 0, point = { 3917, -3130, 3656 } },
	},
	-- from src/game/camera.c:sTTMCreditsSplineFocus L11038-11045
	sTTMCreditsSplineFocus = {
		{ index = 1, speed = 50, point = { 751, 2434, 318 } },
		{ index = 2, speed = 50, point = { 768, 2382, 603 } },
		{ index = 3, speed = 60, point = { 3115, 2086, 1969 } },
		{ index = 4, speed = 30, point = { 6370, -3108, 4727 } },
		{ index = 5, speed = 50, point = { 4172, -3385, 4001 } },
		{ index = -1, speed = 50, point = { 4172, -3385, 4001 } },
	},
	-- from src/game/camera.c:sTHIHugeCreditsSplinePositions L11047-11055
	sTHIHugeCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 6990, -1000, -4858 } },
		{ index = 0, speed = 0, point = { 7886, -1055, 2878 } },
		{ index = 0, speed = 0, point = { 1952, -1481, 10920 } },
		{ index = 0, speed = 0, point = { -1684, -219, 2819 } },
		{ index = 0, speed = 0, point = { -2427, -131, 2755 } },
		{ index = 0, speed = 0, point = { -3246, 416, 3286 } },
		{ index = -1, speed = 0, point = { -3246, 416, 3286 } },
	},
	-- from src/game/camera.c:sTHIHugeCreditsSplineFocus L11057-11065
	sTHIHugeCreditsSplineFocus = {
		{ index = 1, speed = 70, point = { 7022, -965, -5356 } },
		{ index = 2, speed = 40, point = { 7799, -915, 2405 } },
		{ index = 3, speed = 60, point = { 1878, -1137, 10568 } },
		{ index = 4, speed = 50, point = { -1931, -308, 2394 } },
		{ index = 5, speed = 50, point = { -2066, -386, 2521 } },
		{ index = 6, speed = 50, point = { -2875, 182, 3045 } },
		{ index = -1, speed = 50, point = { -2875, 182, 3045 } },
	},
	-- from src/game/camera.c:sTTCCreditsSplinePositions L11067-11072
	sTTCCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { -1724, 277, -994 } },
		{ index = 2, speed = 0, point = { -1720, 456, -995 } },
		{ index = 3, speed = 0, point = { -1655, 810, -1014 } },
		{ index = -1, speed = 0, point = { -1753, 883, -1009 } },
	},
	-- from src/game/camera.c:sTTCCreditsSplineFocus L11074-11079
	sTTCCreditsSplineFocus = {
		{ index = 1, speed = 50, point = { -1554, 742, -1063 } },
		{ index = 2, speed = 50, point = { -1245, 571, -1102 } },
		{ index = 3, speed = 50, point = { -1220, 603, -1151 } },
		{ index = -1, speed = 50, point = { -1412, 520, -1053 } },
	},
	-- from src/game/camera.c:sRRCreditsSplinePositions L11081-11086
	sRRCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -1818, 4036, 97 } },
		{ index = 0, speed = 0, point = { -575, 3460, -505 } },
		{ index = 0, speed = 0, point = { 1191, 3611, -1134 } },
		{ index = -1, speed = 0, point = { 2701, 3777, -3686 } },
	},
	-- from src/game/camera.c:sRRCreditsSplineFocus L11088-11093
	sRRCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -1376, 3885, -81 } },
		{ index = 0, speed = 50, point = { -146, 3343, -734 } },
		{ index = 0, speed = 50, point = { 1570, 3446, -1415 } },
		{ index = -1, speed = 50, point = { 2794, 3627, -3218 } },
	},
	-- from src/game/camera.c:sSACreditsSplinePositions L11095-11101
	sSACreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -295, -396, -585 } },
		{ index = 1, speed = 0, point = { -295, -396, -585 } },
		{ index = 2, speed = 0, point = { -292, -856, -573 } },
		{ index = 3, speed = 0, point = { -312, -856, -541 } },
		{ index = -1, speed = 0, point = { 175, -856, -654 } },
	},
	-- from src/game/camera.c:sSACreditsSplineFocus L11103-11109
	sSACreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -175, -594, -142 } },
		{ index = 1, speed = 50, point = { -175, -594, -142 } },
		{ index = 2, speed = 50, point = { -195, -956, -92 } },
		{ index = 3, speed = 50, point = { -572, -956, -150 } },
		{ index = -1, speed = 50, point = { -307, -956, -537 } },
	},
	-- from src/game/camera.c:sCotMCCreditsSplinePositions L11111-11117
	sCotMCCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { -296, 495, 1607 } },
		{ index = 0, speed = 0, point = { -430, 541, 654 } },
		{ index = 0, speed = 0, point = { -466, 601, -359 } },
		{ index = 0, speed = 0, point = { -217, 433, -1549 } },
		{ index = -1, speed = 0, point = { -95, 366, -2922 } },
	},
	-- from src/game/camera.c:sCotMCCreditsSplineFocus L11119-11125
	sCotMCCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { -176, 483, 2092 } },
		{ index = 0, speed = 50, point = { -122, 392, 1019 } },
		{ index = 0, speed = 50, point = { -268, 450, -792 } },
		{ index = 0, speed = 50, point = { -172, 399, -2046 } },
		{ index = -1, speed = 50, point = { -51, 355, -3420 } },
	},
	-- from src/game/camera.c:sDDDSubCreditsSplinePositions L11127-11133
	sDDDSubCreditsSplinePositions = {
		{ index = 0, speed = 0, point = { 4656, 2171, 5028 } },
		{ index = 0, speed = 0, point = { 4548, 1182, 4596 } },
		{ index = 0, speed = 0, point = { 5007, 813, 3257 } },
		{ index = 0, speed = 0, point = { 5681, 648, 1060 } },
		{ index = -1, speed = 0, point = { 4644, 774, 113 } },
	},
	-- from src/game/camera.c:sDDDSubCreditsSplineFocus L11135-11141
	sDDDSubCreditsSplineFocus = {
		{ index = 0, speed = 50, point = { 4512, 2183, 4549 } },
		{ index = 0, speed = 50, point = { 4327, 838, 4308 } },
		{ index = 0, speed = 50, point = { 4774, 749, 2819 } },
		{ index = 0, speed = 50, point = { 5279, 660, 763 } },
		{ index = -1, speed = 50, point = { 4194, 885, -75 } },
	},
	-- from src/game/camera.c:sCCMOutsideCreditsSplinePositions L11143-11148
	sCCMOutsideCreditsSplinePositions = {
		{ index = 1, speed = 0, point = { 1427, -1387, 5409 } },
		{ index = 2, speed = 0, point = { -1646, -1536, 4526 } },
		{ index = 3, speed = 0, point = { -3852, -1448, 3913 } },
		{ index = -1, speed = 0, point = { -5199, -1366, 1886 } },
	},
	-- from src/game/camera.c:sCCMOutsideCreditsSplineFocus L11150-11155
	sCCMOutsideCreditsSplineFocus = {
		{ index = 1, speed = 50, point = { 958, -1481, 5262 } },
		{ index = 2, speed = 50, point = { -2123, -1600, 4391 } },
		{ index = 3, speed = 50, point = { -3957, -1401, 3426 } },
		{ index = -1, speed = 50, point = { -4730, -1215, 1795 } },
	},
	o = ObjectListProcessor.gCurrentObject,
}

Registry.Register("src__game__camera", camera)

-- from src/game/camera.c:set_camera_shake_from_hit L493-565
function camera.set_camera_shake_from_hit(shake: number)
	shake = S16(TruncS32(shake))
	if shake == GroupsTypesHPlus3.SHAKE_ATTACK then
		-- Makes the camera stop for a bit
		camera.gLakituState.focHSpeed = 0
		camera.gLakituState.posHSpeed = 0
	elseif shake == GroupsTypesHPlus3.SHAKE_FALL_DAMAGE then
		camera.set_camera_pitch_shake(0x60, 0x3, S16(0x8000))
		camera.set_camera_roll_shake(0x60, 0x3, S16(0x8000))
	elseif shake == GroupsTypesHPlus3.SHAKE_GROUND_POUND then
		camera.set_camera_pitch_shake(0x60, 0xC, S16(0x8000))
	elseif shake == GroupsTypesHPlus3.SHAKE_SMALL_DAMAGE then
		if bit32.btest(camera.sMarioCamState.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
			camera.set_camera_yaw_shake(0x200, 0x10, 0x1000)
			camera.set_camera_roll_shake(0x400, 0x20, 0x1000)
			camera.set_fov_shake(0x100, 0x30, S16(0x8000))
		else
			camera.set_camera_yaw_shake(0x80, 0x8, 0x4000)
			camera.set_camera_roll_shake(0x80, 0x8, 0x4000)
			camera.set_fov_shake(0x100, 0x30, S16(0x8000))
		end

		camera.gLakituState.focHSpeed = 0
		camera.gLakituState.posHSpeed = 0
	elseif shake == GroupsTypesHPlus3.SHAKE_MED_DAMAGE then
		if bit32.btest(camera.sMarioCamState.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
			camera.set_camera_yaw_shake(0x400, 0x20, 0x1000)
			camera.set_camera_roll_shake(0x600, 0x30, 0x1000)
			camera.set_fov_shake(0x180, 0x40, S16(0x8000))
		else
			camera.set_camera_yaw_shake(0x100, 0x10, 0x4000)
			camera.set_camera_roll_shake(0x100, 0x10, 0x4000)
			camera.set_fov_shake(0x180, 0x40, S16(0x8000))
		end

		camera.gLakituState.focHSpeed = 0
		camera.gLakituState.posHSpeed = 0
	elseif shake == GroupsTypesHPlus3.SHAKE_LARGE_DAMAGE then
		if bit32.btest(camera.sMarioCamState.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
			camera.set_camera_yaw_shake(0x600, 0x30, 0x1000)
			camera.set_camera_roll_shake(0x800, 0x40, 0x1000)
			camera.set_fov_shake(0x200, 0x50, S16(0x8000))
		else
			camera.set_camera_yaw_shake(0x180, 0x20, 0x4000)
			camera.set_camera_roll_shake(0x200, 0x20, 0x4000)
			camera.set_fov_shake(0x200, 0x50, S16(0x8000))
		end

		camera.gLakituState.focHSpeed = 0
		camera.gLakituState.posHSpeed = 0
	elseif shake == GroupsTypesHPlus3.SHAKE_HIT_FROM_BELOW then
		camera.gLakituState.focHSpeed = F32(0.07)
		camera.gLakituState.posHSpeed = F32(0.07)
	elseif shake == GroupsTypesHPlus3.SHAKE_SHOCK then
		camera.set_camera_pitch_shake(S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 64))), 0x8, S16(0x8000))
		camera.set_camera_yaw_shake(S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 64))), 0x8, S16(0x8000))
	end
end

-- from src/game/camera.c:set_environmental_camera_shake L570-609
function camera.set_environmental_camera_shake(shake: number)
	shake = S16(TruncS32(shake))
	if shake == GroupsTypesHPlus3.SHAKE_ENV_EXPLOSION then
		camera.set_camera_pitch_shake(0x60, 0x8, 0x4000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_BOWSER_THROW_BOUNCE then
		camera.set_camera_pitch_shake(0xC0, 0x8, 0x4000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_BOWSER_JUMP then
		camera.set_camera_pitch_shake(0x100, 0x8, 0x3000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_UNUSED_6 then
		camera.set_camera_roll_shake(0x80, 0x10, 0x3000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_UNUSED_7 then
		camera.set_camera_pitch_shake(0x20, 0x8, S16(0x8000))
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_PYRAMID_EXPLODE then
		camera.set_camera_pitch_shake(0x40, 0x8, S16(0x8000))
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_JRB_SHIP_DRAIN then
		camera.set_camera_pitch_shake(0x20, 0x8, S16(0x8000))
		camera.set_camera_roll_shake(0x400, 0x10, 0x100)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_FALLING_BITS_PLAT then
		camera.set_camera_pitch_shake(0x40, 0x2, S16(0x8000))
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_UNUSED_5 then
		camera.set_camera_yaw_shake(-0x200, 0x80, 0x200)
	end
end

-- from src/game/camera.c:set_camera_shake_from_point L614-635
function camera.set_camera_shake_from_point(shake: number, posX: number, posY: number, posZ: number)
	shake = S16(TruncS32(shake))
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	if shake == GroupsTypesHPlus3.SHAKE_POS_BOWLING_BALL then
		camera.set_pitch_shake_from_point(0x28, 0x8, 0x4000, 2000, posX, posY, posZ)
	elseif shake == GroupsTypesHPlus3.SHAKE_POS_SMALL then
		camera.set_pitch_shake_from_point(0x80, 0x8, 0x4000, 4000, posX, posY, posZ)
		camera.set_fov_shake_from_point_preset(GroupsTypesHPlus3.SHAKE_FOV_SMALL, posX, posY, posZ)
	elseif shake == GroupsTypesHPlus3.SHAKE_POS_MEDIUM then
		camera.set_pitch_shake_from_point(0xC0, 0x8, 0x4000, 6000, posX, posY, posZ)
		camera.set_fov_shake_from_point_preset(GroupsTypesHPlus3.SHAKE_FOV_MEDIUM, posX, posY, posZ)
	elseif shake == GroupsTypesHPlus3.SHAKE_POS_LARGE then
		camera.set_pitch_shake_from_point(0x100, 0x8, 0x3000, 8000, posX, posY, posZ)
		camera.set_fov_shake_from_point_preset(GroupsTypesHPlus3.SHAKE_FOV_LARGE, posX, posY, posZ)
	end
end

-- from src/game/camera.c:unused_set_camera_pitch_shake_env L640-654
function camera.unused_set_camera_pitch_shake_env(shake: number)
	shake = S16(TruncS32(shake))
	if shake == GroupsTypesHPlus3.SHAKE_ENV_EXPLOSION then
		camera.set_camera_pitch_shake(0x60, 0x8, 0x4000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_BOWSER_THROW_BOUNCE then
		camera.set_camera_pitch_shake(0xC0, 0x8, 0x4000)
	elseif shake == GroupsTypesHPlus3.SHAKE_ENV_BOWSER_JUMP then
		camera.set_camera_pitch_shake(0x100, 0x8, 0x3000)
	end
end

-- from src/game/camera.c:calc_y_to_curr_floor L668-706
function camera.calc_y_to_curr_floor(posOff: { number }, posMul: number, posBound: number, focOff: { number }, focMul: number, focBound: number)
	posMul = F32(posMul)
	posBound = F32(posBound)
	focMul = F32(focMul)
	focBound = F32(focBound)
	local floorHeight = camera.sMarioGeometry.currFloorHeight

	if not bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
		--! @bug this should use sMarioGeometry.waterHeight
		const waterHeight: number = Registry.Members.src__engine__surface_collision.find_water_level(camera.sMarioCamState.pos[1], camera.sMarioCamState.pos[3])
		if floorHeight < waterHeight then
			floorHeight = waterHeight
		end
	end

	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_ON_POLE) then
		const usedObj = LevelUpdate.gMarioStates[1].usedObj :: GroupsTypesHPlus3.Object
		const usedObjPosY = buffer.readf32(usedObj.rawData, IncludeObjectFieldsH.oPosY)
		if camera.sMarioGeometry.currFloorHeight >= usedObjPosY and camera.sMarioCamState.pos[2] < F32(F32(F32(0.7) * usedObj.hitboxHeight) + usedObjPosY) then
			posBound = 1200
		end
	end

	posOff[1] = F32(F32(floorHeight - camera.sMarioCamState.pos[2]) * posMul)

	if posOff[1] > posBound then
		posOff[1] = posBound
	end

	if posOff[1] < -posBound then
		posOff[1] = -posBound
	end

	focOff[1] = F32(F32(floorHeight - camera.sMarioCamState.pos[2]) * focMul)

	if focOff[1] > focBound then
		focOff[1] = focBound
	end

	if focOff[1] < -focBound then
		focOff[1] = -focBound
	end
end

-- from src/game/camera.c:focus_on_mario L708-720
function camera.focus_on_mario(focus: { number }, pos: { number }, posYOff: number, focYOff: number, dist: number, pitch: number, yaw: number)
	posYOff = F32(posYOff)
	focYOff = F32(focYOff)
	dist = F32(dist)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	Scratch.focus_on_mario_marioPos[1] = camera.sMarioCamState.pos[1]
	Scratch.focus_on_mario_marioPos[2] = F32(camera.sMarioCamState.pos[2] + posYOff)
	Scratch.focus_on_mario_marioPos[3] = camera.sMarioCamState.pos[3]

	SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.focus_on_mario_marioPos, pos, dist, S16(pitch + camera.sLakituPitch), yaw)

	focus[1] = camera.sMarioCamState.pos[1]
	focus[2] = F32(camera.sMarioCamState.pos[2] + focYOff)
	focus[3] = camera.sMarioCamState.pos[3]
end

-- from src/game/camera.c:set_pos_to_mario L722-743
function camera.set_pos_to_mario(foc: { number }, pos: { number }, yOff: number, focYOff: number, dist: number, pitch: number, yaw: number)
	yOff = F32(yOff)
	focYOff = F32(focYOff)
	dist = F32(dist)
	pitch = S16(TruncS32(pitch))
	yaw = S16(TruncS32(yaw))
	SrcEngineMathUtil.vec3f_copy(Scratch.set_pos_to_mario_marioPos, camera.sMarioCamState.pos)
	Scratch.set_pos_to_mario_marioPos[2] = F32(Scratch.set_pos_to_mario_marioPos[2] + yOff)

	SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.set_pos_to_mario_marioPos, pos, dist, S16(pitch + camera.sLakituPitch), yaw)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(pos, camera.sMarioCamState.pos, Scratch.set_pos_to_mario_posDist, Scratch.set_pos_to_mario_posPitch, Scratch.set_pos_to_mario_posYaw)

	--! Useless get and set
	SrcEngineMathUtil.vec3f_get_dist_and_angle(pos, foc, Scratch.set_pos_to_mario_focDist, Scratch.set_pos_to_mario_focPitch, Scratch.set_pos_to_mario_focYaw)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(pos, foc, Scratch.set_pos_to_mario_focDist[1], Scratch.set_pos_to_mario_focPitch[1], Scratch.set_pos_to_mario_focYaw[1])

	foc[2] = F32(camera.sMarioCamState.pos[2] + focYOff)
end

-- from src/game/camera.c:set_camera_height L748-802
function camera.set_camera_height(c: GroupsTypesHPlus3.Camera, goalHeight: number)
	goalHeight = F32(goalHeight)
	const baseOff = 125
	const camCeilResult: number = Registry.Members.src__engine__surface_collision.find_ceil(c.pos[1], F32(camera.gLakituState.goalPos[2] - 50), c.pos[3], Scratch.set_camera_height_surface)
	local camCeilHeight = camCeilResult

	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_HANGING) then
		const marioCeilHeight = camera.sMarioGeometry.currCeilHeight
		local marioFloorHeight = camera.sMarioGeometry.currFloorHeight

		if marioFloorHeight < F32(marioCeilHeight - 400) then
			marioFloorHeight = F32(marioCeilHeight - 400)
		end

		goalHeight = F32(marioFloorHeight + F32(F32(marioCeilHeight - marioFloorHeight) * F32(0.4)))

		if F32(camera.sMarioCamState.pos[2] - 400) > goalHeight then
			goalHeight = F32(camera.sMarioCamState.pos[2] - 400)
		end

		camera.approach_camera_height(c, goalHeight, 5)
	else
		const camFloorResult: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], F32(c.pos[2] + 100), c.pos[3], Scratch.set_camera_height_surface)
		local camFloorHeight = F32(camFloorResult + baseOff)
		const marioFloorHeight = F32(baseOff + camera.sMarioGeometry.currFloorHeight)

		if camFloorHeight < marioFloorHeight then
			camFloorHeight = marioFloorHeight
		end
		if goalHeight < camFloorHeight then
			goalHeight = camFloorHeight
			c.pos[2] = goalHeight
		end
		-- Warp camera to goalHeight if further than 1000 and Mario is stuck in the ground
		if camera.sMarioCamState.action == IncludeSm64H.ACT_BUTT_STUCK_IN_GROUND or camera.sMarioCamState.action == IncludeSm64H.ACT_HEAD_STUCK_IN_GROUND or camera.sMarioCamState.action == IncludeSm64H.ACT_FEET_STUCK_IN_GROUND then
			if GroupsTypesHPlus3.ABS(F32(c.pos[2] - goalHeight)) > 1000 then
				c.pos[2] = goalHeight
			end
		end
		camera.approach_camera_height(c, goalHeight, 20)
		if camCeilHeight ~= SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT then
			camCeilHeight = F32(camCeilHeight - baseOff)
			if (c.pos[2] > camCeilHeight and F32(camera.sMarioGeometry.currFloorHeight + baseOff) < camCeilHeight) or (camera.sMarioGeometry.currCeilHeight ~= SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT and camera.sMarioGeometry.currCeilHeight > camCeilHeight and c.pos[2] > camCeilHeight) then
				c.pos[2] = camCeilHeight
			end
		end
	end
end

-- from src/game/camera.c:look_down_slopes L807-830
function camera.look_down_slopes(camYaw: number): number
	camYaw = S16(TruncS32(camYaw))
	local pitch = 0x05B0
	-- x and z offsets towards the camera
	const xOff = F32(camera.sMarioCamState.pos[1] + F32(Registry.Members.src__engine__math_util_h.sins(camYaw) * 40))
	const zOff = F32(camera.sMarioCamState.pos[3] + F32(Registry.Members.src__engine__math_util_h.coss(camYaw) * 40))
	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(xOff, camera.sMarioCamState.pos[2], zOff, Scratch.look_down_slopes_floor)
	const floorDY = F32(floorHeight - camera.sMarioCamState.pos[2])
	const floor = Scratch.look_down_slopes_floor[1]

	if floor ~= nil then
		if floor.type_ ~= IncludeSurfaceTerrainsH.SURFACE_WALL_MISC and floorDY > 0 then
			if floor.normal.z == 0 and floorDY < 100 then
				pitch = 0x05B0
			else
				-- Add the slope's angle of declination to the pitch
				pitch = S16(pitch + SrcEngineMathUtil.atan2s(40, floorDY))
			end
		end
	end

	return pitch
end

-- from src/game/camera.c:pan_ahead_of_player L841-879
function camera.pan_ahead_of_player(c: GroupsTypesHPlus3.Camera)
	Scratch.pan_ahead_of_player_pan[1] = 0
	Scratch.pan_ahead_of_player_pan[2] = 0
	Scratch.pan_ahead_of_player_pan[3] = 0

	-- Get distance and angle from camera to Mario.
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, camera.sMarioCamState.pos, Scratch.pan_ahead_of_player_dist, Scratch.pan_ahead_of_player_pitch, Scratch.pan_ahead_of_player_yaw)

	-- The camera will pan ahead up to about 30% of the camera's distance to Mario.
	Scratch.pan_ahead_of_player_pan[3] = F32(Registry.Members.src__engine__math_util_h.sins(0xC00) * Scratch.pan_ahead_of_player_dist[1])

	camera.rotate_in_xz(Scratch.pan_ahead_of_player_pan, Scratch.pan_ahead_of_player_pan, camera.sMarioCamState.faceAngle[2])
	-- rotate in the opposite direction
	Scratch.pan_ahead_of_player_yaw[1] = S16(-Scratch.pan_ahead_of_player_yaw[1])
	camera.rotate_in_xz(Scratch.pan_ahead_of_player_pan, Scratch.pan_ahead_of_player_pan, Scratch.pan_ahead_of_player_yaw[1])
	-- Only pan left or right
	Scratch.pan_ahead_of_player_pan[3] = 0

	-- If Mario is long jumping, or on a flag pole (but not at the top), then pan in the opposite direction
	if camera.sMarioCamState.action == IncludeSm64H.ACT_LONG_JUMP or (camera.sMarioCamState.action ~= IncludeSm64H.ACT_TOP_OF_POLE and bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_ON_POLE)) then
		Scratch.pan_ahead_of_player_pan[1] = -Scratch.pan_ahead_of_player_pan[1]
	end

	-- Slowly make the actual pan, sPanDistance, approach the calculated pan
	-- If Mario is sleeping, then don't pan
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SLEEPING) then
		Scratch.pan_ahead_of_player_sPanDistance[1] = camera.sPanDistance
		camera.approach_f32_asymptotic_bool(Scratch.pan_ahead_of_player_sPanDistance, 0, F32(0.025))
		camera.sPanDistance = Scratch.pan_ahead_of_player_sPanDistance[1]
	else
		Scratch.pan_ahead_of_player_sPanDistance[1] = camera.sPanDistance
		camera.approach_f32_asymptotic_bool(Scratch.pan_ahead_of_player_sPanDistance, Scratch.pan_ahead_of_player_pan[1], F32(0.025))
		camera.sPanDistance = Scratch.pan_ahead_of_player_sPanDistance[1]
	end

	-- Now apply the pan. It's a dir vector to the left or right, rotated by the camera's yaw to Mario
	Scratch.pan_ahead_of_player_pan[1] = camera.sPanDistance
	Scratch.pan_ahead_of_player_yaw[1] = S16(-Scratch.pan_ahead_of_player_yaw[1])
	camera.rotate_in_xz(Scratch.pan_ahead_of_player_pan, Scratch.pan_ahead_of_player_pan, Scratch.pan_ahead_of_player_yaw[1])
	SrcEngineMathUtil.vec3f_add(c.focus, Scratch.pan_ahead_of_player_pan)
end

-- from src/game/camera.c:find_in_bounds_yaw_wdw_bob_thi L881-897
function camera.find_in_bounds_yaw_wdw_bob_thi(pos: { number }, origin: { number }, yaw: number): number
	yaw = S16(TruncS32(yaw))
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_MAIN then
		yaw = S16(camera.clamp_positions_and_find_yaw(pos, origin, 4508, -3739, 4508, -3739))
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BOB then
		yaw = S16(camera.clamp_positions_and_find_yaw(pos, origin, 8000, -8000, 7050, -8000))
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_HUGE then
		yaw = S16(camera.clamp_positions_and_find_yaw(pos, origin, 8192, -8192, 8192, -8192))
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_TINY then
		yaw = S16(camera.clamp_positions_and_find_yaw(pos, origin, 2458, -2458, 2458, -2458))
	end
	return yaw
end

-- from src/game/camera.c:update_radial_camera L902-920
function camera.update_radial_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const cenDistX = F32(camera.sMarioCamState.pos[1] - c.areaCenX)
	const cenDistZ = F32(camera.sMarioCamState.pos[3] - c.areaCenZ)
	local camYaw = S16(SrcEngineMathUtil.atan2s(cenDistZ, cenDistX) + camera.sModeOffsetYaw)
	const pitch = camera.look_down_slopes(camYaw)
	const yOff = 125
	const baseDist = 1000

	camera.sAreaYaw = S16(camYaw - camera.sModeOffsetYaw)
	camera.calc_y_to_curr_floor(Scratch.update_radial_camera_posY, 1, 200, Scratch.update_radial_camera_focusY, F32(0.9), 200)
	camera.focus_on_mario(focus, pos, F32(Scratch.update_radial_camera_posY[1] + yOff), F32(Scratch.update_radial_camera_focusY[1] + yOff), F32(camera.sLakituDist + baseDist), pitch, camYaw)
	camYaw = camera.find_in_bounds_yaw_wdw_bob_thi(pos, focus, camYaw)

	return camYaw
end

-- from src/game/camera.c:update_8_directions_camera L925-945
function camera.update_8_directions_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	local camYaw = S16(camera.s8DirModeBaseYaw + camera.s8DirModeYawOffset)
	const pitch = camera.look_down_slopes(camYaw)
	const yOff = 125
	const baseDist = 1000

	camera.sAreaYaw = camYaw
	camera.calc_y_to_curr_floor(Scratch.update_8_directions_camera_posY, 1, 200, Scratch.update_8_directions_camera_focusY, F32(0.9), 200)
	camera.focus_on_mario(focus, pos, F32(Scratch.update_8_directions_camera_posY[1] + yOff), F32(Scratch.update_8_directions_camera_focusY[1] + yOff), F32(camera.sLakituDist + baseDist), pitch, camYaw)
	camera.pan_ahead_of_player(c)
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_DDD_SUB then
		camYaw = S16(camera.clamp_positions_and_find_yaw(pos, focus, 6839, 995, 5994, -3945))
	end

	return camYaw
end

-- from src/game/camera.c:radial_camera_move L952-1082
function camera.radial_camera_move(c: GroupsTypesHPlus3.Camera)
	const maxAreaYaw = S16(GroupsTypesHPlus3.DEGREES(60))
	const minAreaYaw = S16(GroupsTypesHPlus3.DEGREES(-60))
	local rotateSpeed = 0x1000
	local areaDistX = F32(camera.sMarioCamState.pos[1] - c.areaCenX)
	local areaDistZ = F32(camera.sMarioCamState.pos[3] - c.areaCenZ)

	-- How much the camera's yaw changed
	local yawOffset = S16(camera.calculate_yaw(camera.sMarioCamState.pos, c.pos) - SrcEngineMathUtil.atan2s(areaDistZ, areaDistX))

	if yawOffset > maxAreaYaw then
		yawOffset = maxAreaYaw
	end
	if yawOffset < minAreaYaw then
		yawOffset = minAreaYaw
	end

	-- Check if Mario stepped on a surface that rotates the camera. For example, when Mario enters the
	-- gate in BoB, the camera turns right to face up the hill path
	if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE) then
		if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_MIDDLE and camera.sMarioGeometry.prevFloorType ~= IncludeSurfaceTerrainsH.SURFACE_CAMERA_MIDDLE then
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, bit32.bor(GroupsTypesHPlus3.CAM_MOVE_RETURN_TO_MIDDLE, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE)))
		end
		if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_ROTATE_RIGHT and camera.sMarioGeometry.prevFloorType ~= IncludeSurfaceTerrainsH.SURFACE_CAMERA_ROTATE_RIGHT then
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE)))
		end
		if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_ROTATE_LEFT and camera.sMarioGeometry.prevFloorType ~= IncludeSurfaceTerrainsH.SURFACE_CAMERA_ROTATE_LEFT then
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE)))
		end
	end

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE) then
		rotateSpeed = 0x200
	end

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL then
		areaDistX = -areaDistX
		areaDistZ = -areaDistZ
	end

	-- Avoid obstructing walls
	const avoidStatus = camera.rotate_camera_around_walls(c, c.pos, Scratch.radial_camera_move_avoidYaw, 0x400)
	if avoidStatus == 3 then
		if Scratch.radial_camera_move_avoidYaw[1] - SrcEngineMathUtil.atan2s(areaDistZ, areaDistX) + GroupsTypesHPlus3.DEGREES(90) < 0 then
			Scratch.radial_camera_move_avoidYaw[1] = S16(Scratch.radial_camera_move_avoidYaw[1] + GroupsTypesHPlus3.DEGREES(180))
		end

		-- We want to change sModeOffsetYaw so that the player is no longer obstructed by the wall.
		-- So, we make avoidYaw relative to the yaw around the area center
		Scratch.radial_camera_move_avoidYaw[1] = S16(Scratch.radial_camera_move_avoidYaw[1] - SrcEngineMathUtil.atan2s(areaDistZ, areaDistX))

		-- Bound avoid yaw to radial mode constraints
		if Scratch.radial_camera_move_avoidYaw[1] > GroupsTypesHPlus3.DEGREES(105) then
			Scratch.radial_camera_move_avoidYaw[1] = S16(GroupsTypesHPlus3.DEGREES(105))
		end
		if Scratch.radial_camera_move_avoidYaw[1] < GroupsTypesHPlus3.DEGREES(-105) then
			Scratch.radial_camera_move_avoidYaw[1] = S16(GroupsTypesHPlus3.DEGREES(-105))
		end
	end

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_RETURN_TO_MIDDLE) then
		Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
		const returnResult = camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, 0, rotateSpeed)
		camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
		if returnResult == 0 then
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_RETURN_TO_MIDDLE)))
		end
	else
		-- Prevent the player from rotating into obstructing walls
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) and avoidStatus == 3 and Scratch.radial_camera_move_avoidYaw[1] + 0x10 < camera.sModeOffsetYaw then
			camera.sModeOffsetYaw = Scratch.radial_camera_move_avoidYaw[1]
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
		end
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) and avoidStatus == 3 and Scratch.radial_camera_move_avoidYaw[1] - 0x10 > camera.sModeOffsetYaw then
			camera.sModeOffsetYaw = Scratch.radial_camera_move_avoidYaw[1]
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
		end

		-- If it's the first time rotating, just rotate to +-60 degrees
		if not bit32.btest(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) and bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) then
			Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
			const firstRightResult = camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, maxAreaYaw, rotateSpeed)
			camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
			if firstRightResult == 0 then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
			end
		end
		if not bit32.btest(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) and bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) then
			Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
			const firstLeftResult = camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, minAreaYaw, rotateSpeed)
			camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
			if firstLeftResult == 0 then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
			end
		end

		-- If it's the second time rotating, rotate all the way to +-105 degrees.
		if bit32.btest(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) and bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) then
			Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
			const secondRightResult = camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, S16(GroupsTypesHPlus3.DEGREES(105)), rotateSpeed)
			camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
			if secondRightResult == 0 then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
				camera.s2ndRotateFlags = S16(bit32.band(camera.s2ndRotateFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT)))
			end
		end
		if bit32.btest(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) and bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) then
			Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
			const secondLeftResult = camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, S16(GroupsTypesHPlus3.DEGREES(-105)), rotateSpeed)
			camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
			if secondLeftResult == 0 then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE))))
				camera.s2ndRotateFlags = S16(bit32.band(camera.s2ndRotateFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT)))
			end
		end
	end
	if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE) then
		-- If not rotating, rotate away from walls obscuring Mario from view
		if avoidStatus == 3 then
			Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
			camera.approach_s16_asymptotic_bool(Scratch.radial_camera_move_sModeOffsetYaw, Scratch.radial_camera_move_avoidYaw[1], 10)
			camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
		else
			if c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
				-- sModeOffsetYaw only updates when Mario is moving
				rotateSpeed = S16(TruncS32(F32(F32(LevelUpdate.gMarioStates[1].forwardVel / 32) * 128)))
				Scratch.radial_camera_move_sModeOffsetYaw[1] = camera.sModeOffsetYaw
				camera.camera_approach_s16_symmetric_bool(Scratch.radial_camera_move_sModeOffsetYaw, yawOffset, rotateSpeed)
				camera.sModeOffsetYaw = Scratch.radial_camera_move_sModeOffsetYaw[1]
			end
			if c.mode == GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL then
				camera.sModeOffsetYaw = S16(camera.offset_yaw_outward_radial(c, SrcEngineMathUtil.atan2s(areaDistZ, areaDistX)))
			end
		end
	end

	-- Bound sModeOffsetYaw within (-120, 120) degrees
	if camera.sModeOffsetYaw > 0x5554 then
		camera.sModeOffsetYaw = 0x5554
	end
	if camera.sModeOffsetYaw < -0x5554 then
		camera.sModeOffsetYaw = -0x5554
	end
end

-- from src/game/camera.c:lakitu_zoom L1088-1120
function camera.lakitu_zoom(rangeDist: number, rangePitch: number)
	rangeDist = F32(rangeDist)
	rangePitch = S16(TruncS32(rangePitch))
	if camera.sLakituDist < 0 then
		camera.sLakituDist = S16(camera.sLakituDist + 30)
		if camera.sLakituDist > 0 then
			camera.sLakituDist = 0
		end
	elseif rangeDist < camera.sLakituDist then
		camera.sLakituDist = S16(camera.sLakituDist - 30)
		if camera.sLakituDist < rangeDist then
			camera.sLakituDist = S16(TruncS32(rangeDist))
		end
	elseif bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
		camera.sLakituDist = S16(camera.sLakituDist + 30)
		if camera.sLakituDist > rangeDist then
			camera.sLakituDist = S16(TruncS32(rangeDist))
		end
	else
		camera.sLakituDist = S16(camera.sLakituDist - 30)
		if camera.sLakituDist < 0 then
			camera.sLakituDist = 0
		end
	end

	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_PYRAMID and (camera.gCamera :: GroupsTypesHPlus3.Camera).mode == GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL then
		rangePitch = S16(math.modf(rangePitch / 2))
	end

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
		camera.sLakituPitch = S16(camera.sLakituPitch + (math.modf(rangePitch / 13)))
		if camera.sLakituPitch > rangePitch then
			camera.sLakituPitch = rangePitch
		end
	else
		camera.sLakituPitch = S16(camera.sLakituPitch - (math.modf(rangePitch / 13)))
		if camera.sLakituPitch < 0 then
			camera.sLakituPitch = 0
		end
	end
end

-- from src/game/camera.c:radial_camera_input_default L1122-1124
function camera.radial_camera_input_default(c: GroupsTypesHPlus3.Camera)
	camera.radial_camera_input(c, 0)
end

-- from src/game/camera.c:update_yaw_and_dist_from_c_up L1130-1137
function camera.update_yaw_and_dist_from_c_up(c: GroupsTypesHPlus3.Camera)
	const dist = 1000

	camera.sModeOffsetYaw = S16(camera.sModeInfo.transitionStart.yaw - camera.sAreaYaw)
	camera.sLakituDist = S16(TruncS32(F32(camera.sModeInfo.transitionStart.dist - dist)))
	-- No longer in C-Up
	camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVING_INTO_MODE)))
end

-- from src/game/camera.c:mode_radial_camera L1142-1167
function camera.mode_radial_camera(c: GroupsTypesHPlus3.Camera)
	const oldAreaYaw = camera.sAreaYaw

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVING_INTO_MODE) then
		camera.update_yaw_and_dist_from_c_up(c)
	end

	camera.radial_camera_input_default(c)
	camera.radial_camera_move(c)

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
		camera.lakitu_zoom(400, 0x900)
	end
	c.nextYaw = S16(camera.update_radial_camera(c, c.focus, Scratch.mode_radial_camera_pos))
	c.pos[1] = Scratch.mode_radial_camera_pos[1]
	c.pos[3] = Scratch.mode_radial_camera_pos[3]
	camera.sAreaYawChange = S16(camera.sAreaYaw - oldAreaYaw)
	if camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
		Scratch.mode_radial_camera_pos[2] = F32(Scratch.mode_radial_camera_pos[2] + 500)
	end
	camera.set_camera_height(c, Scratch.mode_radial_camera_pos[2])
	camera.pan_ahead_of_player(c)
end

-- from src/game/camera.c:mode_8_directions_camera L1172-1194
function camera.mode_8_directions_camera(c: GroupsTypesHPlus3.Camera)
	const oldAreaYaw = camera.sAreaYaw

	camera.radial_camera_input(c, 0)

	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_CBUTTONS) then
		camera.s8DirModeYawOffset = S16(camera.s8DirModeYawOffset + GroupsTypesHPlus3.DEGREES(45))
		camera.play_sound_cbutton_side()
	end
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_CBUTTONS) then
		camera.s8DirModeYawOffset = S16(camera.s8DirModeYawOffset - GroupsTypesHPlus3.DEGREES(45))
		camera.play_sound_cbutton_side()
	end

	camera.lakitu_zoom(400, 0x900)
	c.nextYaw = S16(camera.update_8_directions_camera(c, c.focus, Scratch.mode_8_directions_camera_pos))
	c.pos[1] = Scratch.mode_8_directions_camera_pos[1]
	c.pos[3] = Scratch.mode_8_directions_camera_pos[3]
	camera.sAreaYawChange = S16(camera.sAreaYaw - oldAreaYaw)
	camera.set_camera_height(c, Scratch.mode_8_directions_camera_pos[2])
end

-- from src/game/camera.c:update_outward_radial_camera L1200-1216
function camera.update_outward_radial_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const xDistFocToMario = F32(camera.sMarioCamState.pos[1] - c.areaCenX)
	const zDistFocToMario = F32(camera.sMarioCamState.pos[3] - c.areaCenZ)
	const camYaw = S16(SrcEngineMathUtil.atan2s(zDistFocToMario, xDistFocToMario) + camera.sModeOffsetYaw + GroupsTypesHPlus3.DEGREES(180))
	const pitch = camera.look_down_slopes(camYaw)
	const baseDist = 1000
	-- A base offset of 125.f is ~= Mario's eye height
	const yOff = 125

	camera.sAreaYaw = S16(camYaw - camera.sModeOffsetYaw - GroupsTypesHPlus3.DEGREES(180))
	camera.calc_y_to_curr_floor(Scratch.update_outward_radial_camera_posY, 1, 200, Scratch.update_outward_radial_camera_focusY, F32(0.9), 200)
	camera.focus_on_mario(focus, pos, F32(Scratch.update_outward_radial_camera_posY[1] + yOff), F32(Scratch.update_outward_radial_camera_focusY[1] + yOff), F32(camera.sLakituDist + baseDist), pitch, camYaw)

	return camYaw
end

-- from src/game/camera.c:mode_outward_radial_camera L1221-1240
function camera.mode_outward_radial_camera(c: GroupsTypesHPlus3.Camera)
	const oldAreaYaw = camera.sAreaYaw

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVING_INTO_MODE) then
		camera.update_yaw_and_dist_from_c_up(c)
	end
	camera.radial_camera_input_default(c)
	camera.radial_camera_move(c)
	camera.lakitu_zoom(400, 0x900)
	c.nextYaw = S16(camera.update_outward_radial_camera(c, c.focus, Scratch.mode_outward_radial_camera_pos))
	c.pos[1] = Scratch.mode_outward_radial_camera_pos[1]
	c.pos[3] = Scratch.mode_outward_radial_camera_pos[3]
	camera.sAreaYawChange = S16(camera.sAreaYaw - oldAreaYaw)
	if camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
		Scratch.mode_outward_radial_camera_pos[2] = F32(Scratch.mode_outward_radial_camera_pos[2] + 500)
	end
	camera.set_camera_height(c, Scratch.mode_outward_radial_camera_pos[2])
	camera.pan_ahead_of_player(c)
end

-- from src/game/camera.c:update_parallel_tracking_camera L1251-1435
function camera.update_parallel_tracking_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const sParTrackPath = camera.sParTrackPath :: { GroupsTypesHPlus3.ParallelTrackingPoint }
	local distToNext: number
	local distToPrev: number
	const parScale = 0.5

	-- Store camera pos, for changing between paths
	SrcEngineMathUtil.vec3f_copy(Scratch.update_parallel_tracking_camera_oldPos, pos)

	SrcEngineMathUtil.vec3f_copy(Scratch.update_parallel_tracking_camera_path[1], sParTrackPath[camera.sParTrackIndex + 1].pos)
	SrcEngineMathUtil.vec3f_copy(Scratch.update_parallel_tracking_camera_path[2], sParTrackPath[camera.sParTrackIndex + 2].pos)

	const distThresh = sParTrackPath[camera.sParTrackIndex + 1].distThresh
	const zoom = sParTrackPath[camera.sParTrackIndex + 1].zoom
	camera.calc_y_to_curr_floor(Scratch.update_parallel_tracking_camera_marioFloorDist, 1, 200, Scratch.update_parallel_tracking_camera_marioFloorDist, F32(0.9), 200)

	Scratch.update_parallel_tracking_camera_marioPos[1] = camera.sMarioCamState.pos[1]
	-- Mario's y pos + ~Mario's height + Mario's height above the floor
	Scratch.update_parallel_tracking_camera_marioPos[2] = F32(F32(camera.sMarioCamState.pos[2] + 150) + Scratch.update_parallel_tracking_camera_marioFloorDist[1])
	Scratch.update_parallel_tracking_camera_marioPos[3] = camera.sMarioCamState.pos[3]

	-- Calculate middle of the path (parScale is 0.5f)
	const parMidPoint0 = F32(Scratch.update_parallel_tracking_camera_path[1][1] + F32(F32(Scratch.update_parallel_tracking_camera_path[2][1] - Scratch.update_parallel_tracking_camera_path[1][1]) * parScale))
	const parMidPoint1 = F32(Scratch.update_parallel_tracking_camera_path[1][2] + F32(F32(Scratch.update_parallel_tracking_camera_path[2][2] - Scratch.update_parallel_tracking_camera_path[1][2]) * parScale))
	const parMidPoint2 = F32(Scratch.update_parallel_tracking_camera_path[1][3] + F32(F32(Scratch.update_parallel_tracking_camera_path[2][3] - Scratch.update_parallel_tracking_camera_path[1][3]) * parScale))

	-- Get direction of path
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.update_parallel_tracking_camera_path[1], Scratch.update_parallel_tracking_camera_path[2], Scratch.update_parallel_tracking_camera_pathLength, Scratch.update_parallel_tracking_camera_pathPitch, Scratch.update_parallel_tracking_camera_pathYaw)

	Scratch.update_parallel_tracking_camera_marioOffset[1] = F32(Scratch.update_parallel_tracking_camera_marioPos[1] - parMidPoint0)
	Scratch.update_parallel_tracking_camera_marioOffset[2] = F32(Scratch.update_parallel_tracking_camera_marioPos[2] - parMidPoint1)
	Scratch.update_parallel_tracking_camera_marioOffset[3] = F32(Scratch.update_parallel_tracking_camera_marioPos[3] - parMidPoint2)

	-- Make marioOffset point from the midpoint -> the start of the path
	-- Rotating by -yaw then -pitch moves the hor dist from the midpoint into marioOffset's z coordinate
	-- marioOffset[0] = the (perpendicular) horizontal distance from the path
	-- marioOffset[1] = the vertical distance from the path
	-- marioOffset[2] = the (parallel) horizontal distance from the path's midpoint
	Scratch.update_parallel_tracking_camera_pathYaw[1] = S16(-Scratch.update_parallel_tracking_camera_pathYaw[1])
	camera.rotate_in_xz(Scratch.update_parallel_tracking_camera_marioOffset, Scratch.update_parallel_tracking_camera_marioOffset, Scratch.update_parallel_tracking_camera_pathYaw[1])
	Scratch.update_parallel_tracking_camera_pathYaw[1] = S16(-Scratch.update_parallel_tracking_camera_pathYaw[1])
	Scratch.update_parallel_tracking_camera_pathPitch[1] = S16(-Scratch.update_parallel_tracking_camera_pathPitch[1])
	camera.rotate_in_yz(Scratch.update_parallel_tracking_camera_marioOffset, Scratch.update_parallel_tracking_camera_marioOffset, Scratch.update_parallel_tracking_camera_pathPitch[1])
	Scratch.update_parallel_tracking_camera_pathPitch[1] = S16(-Scratch.update_parallel_tracking_camera_pathPitch[1])
	SrcEngineMathUtil.vec3f_copy(Scratch.update_parallel_tracking_camera_focOffset, Scratch.update_parallel_tracking_camera_marioOffset)

	-- OK
	Scratch.update_parallel_tracking_camera_focOffset[1] = F32(-Scratch.update_parallel_tracking_camera_focOffset[1] * 0)
	Scratch.update_parallel_tracking_camera_focOffset[2] = F32(Scratch.update_parallel_tracking_camera_focOffset[2] * 0)

	-- Repeat above calcs with camOffset
	Scratch.update_parallel_tracking_camera_camOffset[1] = F32(pos[1] - parMidPoint0)
	Scratch.update_parallel_tracking_camera_camOffset[2] = F32(pos[2] - parMidPoint1)
	Scratch.update_parallel_tracking_camera_camOffset[3] = F32(pos[3] - parMidPoint2)
	Scratch.update_parallel_tracking_camera_pathYaw[1] = S16(-Scratch.update_parallel_tracking_camera_pathYaw[1])
	camera.rotate_in_xz(Scratch.update_parallel_tracking_camera_camOffset, Scratch.update_parallel_tracking_camera_camOffset, Scratch.update_parallel_tracking_camera_pathYaw[1])
	Scratch.update_parallel_tracking_camera_pathYaw[1] = S16(-Scratch.update_parallel_tracking_camera_pathYaw[1])
	Scratch.update_parallel_tracking_camera_pathPitch[1] = S16(-Scratch.update_parallel_tracking_camera_pathPitch[1])
	camera.rotate_in_yz(Scratch.update_parallel_tracking_camera_camOffset, Scratch.update_parallel_tracking_camera_camOffset, Scratch.update_parallel_tracking_camera_pathPitch[1])
	Scratch.update_parallel_tracking_camera_pathPitch[1] = S16(-Scratch.update_parallel_tracking_camera_pathPitch[1])

	-- If Mario is distThresh units away from the camera along the path, move the camera
	-- When distThresh != 0, it causes Mario to move slightly towards the camera when running sideways
	-- Set each ParallelTrackingPoint's distThresh to 0 to make Mario truly run parallel to the path
	if Scratch.update_parallel_tracking_camera_marioOffset[3] > Scratch.update_parallel_tracking_camera_camOffset[3] then
		if F32(Scratch.update_parallel_tracking_camera_marioOffset[3] - Scratch.update_parallel_tracking_camera_camOffset[3]) > distThresh then
			Scratch.update_parallel_tracking_camera_camOffset[3] = F32(Scratch.update_parallel_tracking_camera_marioOffset[3] - distThresh)
		end
	else
		if F32(Scratch.update_parallel_tracking_camera_marioOffset[3] - Scratch.update_parallel_tracking_camera_camOffset[3]) < -distThresh then
			Scratch.update_parallel_tracking_camera_camOffset[3] = F32(Scratch.update_parallel_tracking_camera_marioOffset[3] + distThresh)
		end
	end

	-- If zoom != 0.0, the camera will move zoom% closer to Mario
	Scratch.update_parallel_tracking_camera_marioOffset[1] = F32(-Scratch.update_parallel_tracking_camera_marioOffset[1] * zoom)
	Scratch.update_parallel_tracking_camera_marioOffset[2] = F32(Scratch.update_parallel_tracking_camera_marioOffset[2] * zoom)
	Scratch.update_parallel_tracking_camera_marioOffset[3] = Scratch.update_parallel_tracking_camera_camOffset[3]

	-- Does nothing because focOffset[0] is always 0
	Scratch.update_parallel_tracking_camera_focOffset[1] = F32(Scratch.update_parallel_tracking_camera_focOffset[1] * F32(0.3))
	-- Does nothing because focOffset[1] is always 0
	Scratch.update_parallel_tracking_camera_focOffset[2] = F32(Scratch.update_parallel_tracking_camera_focOffset[2] * F32(0.3))

	Scratch.update_parallel_tracking_camera_pathAngle[1] = Scratch.update_parallel_tracking_camera_pathPitch[1]
	Scratch.update_parallel_tracking_camera_pathAngle[2] = Scratch.update_parallel_tracking_camera_pathYaw[1] -- No effect

	-- make marioOffset[2] == distance from the start of the path
	Scratch.update_parallel_tracking_camera_marioOffset[3] = F32(F32(Scratch.update_parallel_tracking_camera_pathLength[1] / 2) - Scratch.update_parallel_tracking_camera_marioOffset[3])

	Scratch.update_parallel_tracking_camera_pathAngle[2] = S16(Scratch.update_parallel_tracking_camera_pathYaw[1] + GroupsTypesHPlus3.DEGREES(180))
	Scratch.update_parallel_tracking_camera_pathAngle[3] = 0

	-- Rotate the offset in the direction of the path again
	camera.offset_rotated(pos, Scratch.update_parallel_tracking_camera_path[1], Scratch.update_parallel_tracking_camera_marioOffset, Scratch.update_parallel_tracking_camera_pathAngle)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.update_parallel_tracking_camera_path[1], c.pos, Scratch.update_parallel_tracking_camera_camParDist, Scratch.update_parallel_tracking_camera_pathPitch, Scratch.update_parallel_tracking_camera_pathYaw)

	-- Adjust the focus. Does nothing, focus is set to Mario at the end
	Scratch.update_parallel_tracking_camera_focOffset[3] = F32(F32(Scratch.update_parallel_tracking_camera_pathLength[1] / 2) - Scratch.update_parallel_tracking_camera_focOffset[3])
	camera.offset_rotated(c.focus, Scratch.update_parallel_tracking_camera_path[1], Scratch.update_parallel_tracking_camera_focOffset, Scratch.update_parallel_tracking_camera_pathAngle)

	-- Changing paths, update the stored position offset
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CHANGED_PARTRACK_INDEX) then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_CHANGED_PARTRACK_INDEX)))
		camera.sParTrackTransOff.pos[1] = F32(Scratch.update_parallel_tracking_camera_oldPos[1] - c.pos[1])
		camera.sParTrackTransOff.pos[2] = F32(Scratch.update_parallel_tracking_camera_oldPos[2] - c.pos[2])
		camera.sParTrackTransOff.pos[3] = F32(Scratch.update_parallel_tracking_camera_oldPos[3] - c.pos[3])
	end
	-- Slowly transition to the next path
	Scratch.update_parallel_tracking_camera_transOff[1] = camera.sParTrackTransOff.pos[1]
	camera.approach_f32_asymptotic_bool(Scratch.update_parallel_tracking_camera_transOff, 0, F32(0.025))
	camera.sParTrackTransOff.pos[1] = Scratch.update_parallel_tracking_camera_transOff[1]
	Scratch.update_parallel_tracking_camera_transOff[1] = camera.sParTrackTransOff.pos[2]
	camera.approach_f32_asymptotic_bool(Scratch.update_parallel_tracking_camera_transOff, 0, F32(0.025))
	camera.sParTrackTransOff.pos[2] = Scratch.update_parallel_tracking_camera_transOff[1]
	Scratch.update_parallel_tracking_camera_transOff[1] = camera.sParTrackTransOff.pos[3]
	camera.approach_f32_asymptotic_bool(Scratch.update_parallel_tracking_camera_transOff, 0, F32(0.025))
	camera.sParTrackTransOff.pos[3] = Scratch.update_parallel_tracking_camera_transOff[1]
	SrcEngineMathUtil.vec3f_add(c.pos, camera.sParTrackTransOff.pos)

	-- Check if the camera should go to the next path
	if sParTrackPath[camera.sParTrackIndex + 2].startOfPath ~= 0 then
		-- get Mario's distance to the next path
		camera.calculate_angles(sParTrackPath[camera.sParTrackIndex + 2].pos, sParTrackPath[camera.sParTrackIndex + 3].pos, Scratch.update_parallel_tracking_camera_nextPitch, Scratch.update_parallel_tracking_camera_nextYaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(sParTrackPath[camera.sParTrackIndex + 2].pos, Scratch.update_parallel_tracking_camera_nextPathPos, 400, Scratch.update_parallel_tracking_camera_nextPitch[1], Scratch.update_parallel_tracking_camera_nextYaw[1])
		distToPrev = camera.calc_abs_dist(Scratch.update_parallel_tracking_camera_marioPos, Scratch.update_parallel_tracking_camera_nextPathPos)

		-- get Mario's distance to the previous path
		camera.calculate_angles(sParTrackPath[camera.sParTrackIndex + 2].pos, sParTrackPath[camera.sParTrackIndex + 1].pos, Scratch.update_parallel_tracking_camera_prevPitch, Scratch.update_parallel_tracking_camera_prevYaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(sParTrackPath[camera.sParTrackIndex + 2].pos, Scratch.update_parallel_tracking_camera_prevPathPos, 400, Scratch.update_parallel_tracking_camera_prevPitch[1], Scratch.update_parallel_tracking_camera_prevYaw[1])
		distToNext = camera.calc_abs_dist(Scratch.update_parallel_tracking_camera_marioPos, Scratch.update_parallel_tracking_camera_prevPathPos)
		if distToPrev < distToNext then
			camera.sParTrackIndex = U32(camera.sParTrackIndex + 1)
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CHANGED_PARTRACK_INDEX))
		end
	end

	-- Check if the camera should go to the previous path
	if camera.sParTrackIndex ~= 0 then
		-- get Mario's distance to the next path
		camera.calculate_angles(sParTrackPath[camera.sParTrackIndex + 1].pos, sParTrackPath[camera.sParTrackIndex + 2].pos, Scratch.update_parallel_tracking_camera_nextPitch, Scratch.update_parallel_tracking_camera_nextYaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(sParTrackPath[camera.sParTrackIndex + 1].pos, Scratch.update_parallel_tracking_camera_nextPathPos, 700, Scratch.update_parallel_tracking_camera_nextPitch[1], Scratch.update_parallel_tracking_camera_nextYaw[1])
		distToPrev = camera.calc_abs_dist(Scratch.update_parallel_tracking_camera_marioPos, Scratch.update_parallel_tracking_camera_nextPathPos)

		-- get Mario's distance to the previous path
		camera.calculate_angles(sParTrackPath[camera.sParTrackIndex + 1].pos, sParTrackPath[camera.sParTrackIndex].pos, Scratch.update_parallel_tracking_camera_prevPitch, Scratch.update_parallel_tracking_camera_prevYaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(sParTrackPath[camera.sParTrackIndex + 1].pos, Scratch.update_parallel_tracking_camera_prevPathPos, 700, Scratch.update_parallel_tracking_camera_prevPitch[1], Scratch.update_parallel_tracking_camera_prevYaw[1])
		distToNext = camera.calc_abs_dist(Scratch.update_parallel_tracking_camera_marioPos, Scratch.update_parallel_tracking_camera_prevPathPos)
		if distToPrev > distToNext then
			camera.sParTrackIndex = U32(camera.sParTrackIndex - 1)
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CHANGED_PARTRACK_INDEX))
		end
	end

	-- Update the camera focus and return the camera's yaw
	SrcEngineMathUtil.vec3f_copy(focus, Scratch.update_parallel_tracking_camera_marioPos)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(focus, pos, Scratch.update_parallel_tracking_camera_camParDist, Scratch.update_parallel_tracking_camera_pathPitch, Scratch.update_parallel_tracking_camera_pathYaw)
	return Scratch.update_parallel_tracking_camera_pathYaw[1]
end

-- from src/game/camera.c:update_fixed_camera L1440-1526
function camera.update_fixed_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	local goalHeight: number
	local ceilHeight: number
	local heightOffset = 0
	local scaleToMario = 0.5

	camera.play_camera_buzz_if_c_sideways()

	-- Don't move closer to Mario in these areas
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_RR then
		scaleToMario = 0
		heightOffset = 0
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CASTLE_LOBBY then
		scaleToMario = F32(0.3)
		heightOffset = 0
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BBH then
		scaleToMario = 0
		heightOffset = 0
	end

	camera.handle_c_button_movement(c)
	camera.play_camera_buzz_if_cdown()

	camera.calc_y_to_curr_floor(Scratch.update_fixed_camera_focusFloorOff, 1, 200, Scratch.update_fixed_camera_focusFloorOff, F32(0.9), 200)
	SrcEngineMathUtil.vec3f_copy(focus, camera.sMarioCamState.pos)
	focus[2] = F32(focus[2] + F32(Scratch.update_fixed_camera_focusFloorOff[1] + 125))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(focus, c.pos, Scratch.update_fixed_camera_distCamToFocus, Scratch.update_fixed_camera_faceAngle0, Scratch.update_fixed_camera_faceAngle1)

	SrcEngineMathUtil.vec3f_copy(Scratch.update_fixed_camera_basePos, camera.sFixedModeBasePosition)
	SrcEngineMathUtil.vec3f_add(Scratch.update_fixed_camera_basePos, camera.sCastleEntranceOffset)

	if camera.sMarioGeometry.currFloorType ~= IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE and camera.sMarioGeometry.currFloorHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		goalHeight = F32(F32(camera.sMarioGeometry.currFloorHeight + Scratch.update_fixed_camera_basePos[2]) + heightOffset)
	else
		goalHeight = camera.gLakituState.goalPos[2]
	end

	if 300 > Scratch.update_fixed_camera_distCamToFocus[1] then
		goalHeight = F32(goalHeight + F32(300 - Scratch.update_fixed_camera_distCamToFocus[1]))
	end

	ceilHeight = Registry.Members.src__engine__surface_collision.find_ceil(c.pos[1], F32(goalHeight - 100), c.pos[3], Scratch.update_fixed_camera_ceiling)
	if ceilHeight ~= SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT then
		ceilHeight = F32(ceilHeight - 125)
		if goalHeight > ceilHeight then
			goalHeight = ceilHeight
		end
	end

	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT) then
		Scratch.update_fixed_camera_posY[1] = c.pos[2]
		camera.camera_approach_f32_symmetric_bool(Scratch.update_fixed_camera_posY, goalHeight, 15)
		c.pos[2] = Scratch.update_fixed_camera_posY[1]
	else
		if goalHeight < F32(camera.sMarioCamState.pos[2] - 500) then
			goalHeight = F32(camera.sMarioCamState.pos[2] - 500)
		end
		c.pos[2] = goalHeight
	end

	c.pos[1] = F32(Scratch.update_fixed_camera_basePos[1] + F32(F32(camera.sMarioCamState.pos[1] - Scratch.update_fixed_camera_basePos[1]) * scaleToMario))
	c.pos[3] = F32(Scratch.update_fixed_camera_basePos[3] + F32(F32(camera.sMarioCamState.pos[3] - Scratch.update_fixed_camera_basePos[3]) * scaleToMario))

	if scaleToMario ~= 0 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.update_fixed_camera_distCamToFocus, Scratch.update_fixed_camera_pitch, Scratch.update_fixed_camera_yaw)
		if Scratch.update_fixed_camera_distCamToFocus[1] > 1000 then
			Scratch.update_fixed_camera_distCamToFocus[1] = 1000
			SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, Scratch.update_fixed_camera_distCamToFocus[1], Scratch.update_fixed_camera_pitch[1], Scratch.update_fixed_camera_yaw[1])
		end
	end

	return Scratch.update_fixed_camera_faceAngle1[1]
end

-- from src/game/camera.c:update_boss_fight_camera L1531-1655
function camera.update_boss_fight_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	local focusDistance: number
	local heldState: number
	local nx: number
	local ny: number
	local nz: number
	local oo: number
	local yaw: number

	Scratch.update_boss_fight_camera_holdFocOffset[1] = 0
	Scratch.update_boss_fight_camera_holdFocOffset[2] = -150
	Scratch.update_boss_fight_camera_holdFocOffset[3] = -125

	camera.handle_c_button_movement(c)

	-- Start camera shakes if bowser jumps or gets thrown.
	if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_BOWSER_JUMP then
		camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_BOWSER_JUMP)
		camera.sMarioCamState.cameraEvent = 0
	end
	if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_BOWSER_THROW_BOUNCE then
		camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_BOWSER_THROW_BOUNCE)
		camera.sMarioCamState.cameraEvent = 0
	end

	yaw = S16(camera.sModeOffsetYaw + GroupsTypesHPlus3.DEGREES(45))
	-- Get boss's position and whether Mario is holding it.
	const o = camera.gSecondCameraFocus
	if o ~= nil then
		camera.object_pos_to_vec3f(Scratch.update_boss_fight_camera_secondFocus, o)
		heldState = S16(buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState))
	else
		-- If no boss is there, just rotate around the area's center point.
		Scratch.update_boss_fight_camera_secondFocus[1] = c.areaCenX
		Scratch.update_boss_fight_camera_secondFocus[2] = camera.sMarioCamState.pos[2]
		Scratch.update_boss_fight_camera_secondFocus[3] = c.areaCenZ
		heldState = 0
	end

	focusDistance = F32(camera.calc_abs_dist(camera.sMarioCamState.pos, Scratch.update_boss_fight_camera_secondFocus) * F32(1.6))
	if focusDistance < 800 then
		focusDistance = 800
	end
	if focusDistance > 5000 then
		focusDistance = 5000
	end

	-- If holding the boss, add a slight offset to secondFocus so that the spinning is more pronounced.
	if heldState == 1 then
		camera.offset_rotated(Scratch.update_boss_fight_camera_secondFocus, camera.sMarioCamState.pos, Scratch.update_boss_fight_camera_holdFocOffset, camera.sMarioCamState.faceAngle)
	end

	-- Set the camera focus to the average of Mario and secondFocus
	focus[1] = F32(F32(camera.sMarioCamState.pos[1] + Scratch.update_boss_fight_camera_secondFocus[1]) / 2)
	focus[2] = F32(F32(F32(camera.sMarioCamState.pos[2] + Scratch.update_boss_fight_camera_secondFocus[2]) / 2) + 125)
	focus[3] = F32(F32(camera.sMarioCamState.pos[3] + Scratch.update_boss_fight_camera_secondFocus[3]) / 2)

	-- Calculate the camera's position as an offset from the focus
	-- When C-Down is not active, this
	SrcEngineMathUtil.vec3f_set_dist_and_angle(focus, pos, focusDistance, 0x1000, yaw)
	-- Find the floor of the arena
	pos[2] = Registry.Members.src__engine__surface_collision.find_floor(c.areaCenX, SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT, c.areaCenZ, Scratch.update_boss_fight_camera_floor)
	const floor = Scratch.update_boss_fight_camera_floor[1]
	if floor ~= nil then
		nx = floor.normal.x
		ny = floor.normal.y
		nz = floor.normal.z
		oo = floor.originOffset
		pos[2] = F32(300 - F32(F32(F32(F32(nx * pos[1]) + F32(nz * pos[3])) + oo) / ny))
		if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BOB then
			pos[2] = F32(pos[2] + 125)
			-- fall through, makes the BoB boss fight camera move up twice as high as it should
			pos[2] = F32(pos[2] + 125)
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WF then
			pos[2] = F32(pos[2] + 125)
		end
	end

	-- Must be same line to match on -O2
	-- Prevent the camera from going to the ground in the outside boss fight
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BBH then
		pos[2] = 2047
	end

	-- Rotate from C-Button input
	if camera.sCSideButtonYaw < 0 then
		camera.sModeOffsetYaw = S16(camera.sModeOffsetYaw + 0x200)
		camera.sCSideButtonYaw = S16(camera.sCSideButtonYaw + 0x100)
		if camera.sCSideButtonYaw > 0 then
			camera.sCSideButtonYaw = 0
		end
	end
	if camera.sCSideButtonYaw > 0 then
		camera.sModeOffsetYaw = S16(camera.sModeOffsetYaw - 0x200)
		camera.sCSideButtonYaw = S16(camera.sCSideButtonYaw - 0x100)
		if camera.sCSideButtonYaw < 0 then
			camera.sCSideButtonYaw = 0
		end
	end

	focus[2] = F32(F32(F32(camera.sMarioCamState.pos[2] + Scratch.update_boss_fight_camera_secondFocus[2]) / 2) + 100)
	if heldState == 1 then
		const angleVel = LevelUpdate.gMarioStates[1].angleVel[2]
		const Sin: number = Registry.Members.src__engine__math_util_h.sins(if angleVel > 0 then angleVel else -angleVel)
		focus[2] = F32(focus[2] + F32(300 * Sin))
	end

	-- Unnecessary conditional, focusDistance is already bounded to 800
	if focusDistance < 400 then
		focusDistance = 400
	end

	-- Set C-Down distance and pitch.
	-- C-Down will essentially double the distance from the center.
	-- sLakituPitch approaches 33.75 degrees.
	camera.lakitu_zoom(focusDistance, 0x1800)

	-- Move the camera position back as sLakituDist and sLakituPitch increase.
	-- This doesn't zoom out of bounds because pos is set above each frame.
	-- The constant 0x1000 doubles the pitch from the center when sLakituPitch is 0
	-- When Lakitu is fully zoomed out, the pitch comes to 0x3800, or 78.75 degrees, up from the focus.
	SrcEngineMathUtil.vec3f_set_dist_and_angle(pos, pos, camera.sLakituDist, S16(camera.sLakituPitch + 0x1000), yaw)

	return yaw
end

-- from src/game/camera.c:unused_update_mode_5_camera L1702-1706
function camera.unused_update_mode_5_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	return 0
end

-- from src/game/camera.c:stub_camera_1 L1708-1709
function camera.stub_camera_1(unused: number)
	-- Empty in the C source.
end

-- from src/game/camera.c:mode_boss_fight_camera L1711-1713
function camera.mode_boss_fight_camera(c: GroupsTypesHPlus3.Camera)
	c.nextYaw = S16(camera.update_boss_fight_camera(c, c.focus, c.pos))
end

-- from src/game/camera.c:mode_parallel_tracking_camera L1720-1727
function camera.mode_parallel_tracking_camera(c: GroupsTypesHPlus3.Camera)
	camera.radial_camera_input(c, 0)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	c.nextYaw = S16(camera.update_parallel_tracking_camera(c, c.focus, c.pos))
	camera.camera_approach_s16_symmetric_bool(Scratch.mode_parallel_tracking_camera_dummy, 0, 0x0400)
end

-- from src/game/camera.c:mode_fixed_camera L1732-1744
function camera.mode_fixed_camera(c: GroupsTypesHPlus3.Camera)
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BBH then
		camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_BBH)
	else
		camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_APP_45)
	end
	c.nextYaw = S16(camera.update_fixed_camera(c, c.focus, c.pos))
	c.yaw = c.nextYaw
	camera.pan_ahead_of_player(c)
	SrcEngineMathUtil.vec3f_set(camera.sCastleEntranceOffset, 0, 0, 0)
end

-- from src/game/camera.c:update_behind_mario_camera L1751-1892
function camera.update_behind_mario_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	local goalPitch = S16(-camera.sMarioCamState.faceAngle[1])
	const marioYaw = S16(camera.sMarioCamState.faceAngle[2] + GroupsTypesHPlus3.DEGREES(180))
	local goalYawOff = 0
	local yawSpeed: number
	local pitchInc = 32
	local maxDist = 800
	local focYOff = 125

	-- Zoom in when Mario R_TRIG mode is active
	if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		maxDist = 350
		focYOff = 120
	end
	if not bit32.btest(camera.sMarioCamState.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
		pitchInc = 128
	end

	-- Focus on Mario
	SrcEngineMathUtil.vec3f_copy(focus, camera.sMarioCamState.pos)
	c.focus[2] = F32(c.focus[2] + focYOff)
	-- @bug unnecessary
	Scratch.update_behind_mario_camera_dist[1] = camera.calc_abs_dist(focus, pos)
	-- @bug unnecessary
	Scratch.update_behind_mario_camera_pitch[1] = camera.calculate_pitch(focus, pos)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(focus, pos, Scratch.update_behind_mario_camera_dist, Scratch.update_behind_mario_camera_pitch, Scratch.update_behind_mario_camera_yaw)
	if Scratch.update_behind_mario_camera_dist[1] > maxDist then
		Scratch.update_behind_mario_camera_dist[1] = maxDist
	end
	local absPitch = Scratch.update_behind_mario_camera_pitch[1]
	if absPitch < 0 then
		absPitch = S16(-absPitch)
	end

	-- Determine the yaw speed based on absPitch. A higher absPitch (further away from looking straight)
	-- translates to a slower speed
	-- Note: Pitch is always within +- 90 degrees or +-0x4000, and 0x4000 / 0x200 = 32
	yawSpeed = S16(32 - (math.modf(absPitch / 0x200)))
	if yawSpeed < 1 then
		yawSpeed = 1
	end
	if yawSpeed > 32 then
		yawSpeed = 32
	end

	if camera.sCSideButtonYaw ~= 0 then
		Scratch.update_behind_mario_camera_ref[1] = camera.sCSideButtonYaw
		camera.camera_approach_s16_symmetric_bool(Scratch.update_behind_mario_camera_ref, 0, 1)
		camera.sCSideButtonYaw = Scratch.update_behind_mario_camera_ref[1]
		yawSpeed = 8
	end
	if camera.sBehindMarioSoundTimer ~= 0 then
		goalPitch = 0
		Scratch.update_behind_mario_camera_ref[1] = camera.sBehindMarioSoundTimer
		camera.camera_approach_s16_symmetric_bool(Scratch.update_behind_mario_camera_ref, 0, 1)
		camera.sBehindMarioSoundTimer = Scratch.update_behind_mario_camera_ref[1]
		pitchInc = 0x800
	end

	if camera.sBehindMarioSoundTimer == 28 then
		if camera.sCSideButtonYaw < 5 or camera.sCSideButtonYaw > 28 then
			camera.play_sound_cbutton_up()
		end
	end
	if camera.sCSideButtonYaw == 28 then
		if camera.sBehindMarioSoundTimer < 5 or camera.sBehindMarioSoundTimer > 28 then
			camera.play_sound_cbutton_up()
		end
	end

	-- C-Button input. Note: Camera rotates in the opposite direction of the button (airplane controls)
	-- @bug C-Right and C-Up take precedence due to the way input is handled here

	-- Rotate right
	if bit32.btest(camera.sCButtonsPressed, IncludePROsH.L_CBUTTONS) then
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_CBUTTONS) then
			camera.play_sound_cbutton_side()
		end
		if Scratch.update_behind_mario_camera_dist[1] < maxDist then
			camera.camera_approach_f32_symmetric_bool(Scratch.update_behind_mario_camera_dist, maxDist, 5)
		end
		goalYawOff = -0x3FF8
		camera.sCSideButtonYaw = 30
		yawSpeed = 2
	end
	-- Rotate left
	if bit32.btest(camera.sCButtonsPressed, IncludePROsH.R_CBUTTONS) then
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_CBUTTONS) then
			camera.play_sound_cbutton_side()
		end
		if Scratch.update_behind_mario_camera_dist[1] < maxDist then
			camera.camera_approach_f32_symmetric_bool(Scratch.update_behind_mario_camera_dist, maxDist, 5)
		end
		goalYawOff = 0x3FF8
		camera.sCSideButtonYaw = 30
		yawSpeed = 2
	end
	-- Rotate up
	if bit32.btest(camera.sCButtonsPressed, IncludePROsH.D_CBUTTONS) then
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, bit32.bor(IncludePROsH.U_CBUTTONS, IncludePROsH.D_CBUTTONS)) then
			camera.play_sound_cbutton_side()
		end
		if Scratch.update_behind_mario_camera_dist[1] < maxDist then
			camera.camera_approach_f32_symmetric_bool(Scratch.update_behind_mario_camera_dist, maxDist, 5)
		end
		goalPitch = -0x3000
		camera.sBehindMarioSoundTimer = 30
		pitchInc = 0x800
	end
	-- Rotate down
	if bit32.btest(camera.sCButtonsPressed, IncludePROsH.U_CBUTTONS) then
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, bit32.bor(IncludePROsH.U_CBUTTONS, IncludePROsH.D_CBUTTONS)) then
			camera.play_sound_cbutton_side()
		end
		if Scratch.update_behind_mario_camera_dist[1] < maxDist then
			camera.camera_approach_f32_symmetric_bool(Scratch.update_behind_mario_camera_dist, maxDist, 5)
		end
		goalPitch = 0x3000
		camera.sBehindMarioSoundTimer = 30
		pitchInc = 0x800
	end

	camera.approach_s16_asymptotic_bool(Scratch.update_behind_mario_camera_yaw, S16(marioYaw + goalYawOff), yawSpeed)
	camera.camera_approach_s16_symmetric_bool(Scratch.update_behind_mario_camera_pitch, goalPitch, pitchInc)
	if Scratch.update_behind_mario_camera_dist[1] < 300 then
		Scratch.update_behind_mario_camera_dist[1] = 300
	end
	SrcEngineMathUtil.vec3f_set_dist_and_angle(focus, pos, Scratch.update_behind_mario_camera_dist[1], Scratch.update_behind_mario_camera_pitch[1], Scratch.update_behind_mario_camera_yaw[1])
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_MAIN then
		Scratch.update_behind_mario_camera_yaw[1] = S16(camera.clamp_positions_and_find_yaw(pos, focus, 4508, -3739, 4508, -3739))
	end
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_HUGE then
		Scratch.update_behind_mario_camera_yaw[1] = S16(camera.clamp_positions_and_find_yaw(pos, focus, 8192, -8192, 8192, -8192))
	end
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_TINY then
		Scratch.update_behind_mario_camera_yaw[1] = S16(camera.clamp_positions_and_find_yaw(pos, focus, 2458, -2458, 2458, -2458))
	end

	return Scratch.update_behind_mario_camera_yaw[1]
end

-- from src/game/camera.c:mode_behind_mario L1897-1943
function camera.mode_behind_mario(c: GroupsTypesHPlus3.Camera): number
	local floorHeight: number
	const marioState = LevelUpdate.gMarioStates[1]

	SrcEngineMathUtil.vec3f_copy(Scratch.mode_behind_mario_oldPos, c.pos)
	camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVING_INTO_MODE)))
	SrcEngineMathUtil.vec3f_copy(Scratch.mode_behind_mario_newPos, c.pos)
	const yaw = S16(camera.update_behind_mario_camera(c, c.focus, Scratch.mode_behind_mario_newPos))
	c.pos[1] = Scratch.mode_behind_mario_newPos[1]
	c.pos[3] = Scratch.mode_behind_mario_newPos[3]

	-- Keep the camera above the water surface if swimming
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
		floorHeight = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], c.pos[2], c.pos[3], Scratch.mode_behind_mario_floor)
		Scratch.mode_behind_mario_newPos[2] = marioState.waterLevel + 120
		floorHeight = F32(floorHeight + 120)
		if Scratch.mode_behind_mario_newPos[2] < floorHeight then
			Scratch.mode_behind_mario_newPos[2] = floorHeight
		end
	end
	camera.approach_camera_height(c, Scratch.mode_behind_mario_newPos[2], 50)
	const WaterLevel: number = Registry.Members.src__engine__surface_collision.find_water_level(c.pos[1], c.pos[3])
	const waterHeight = F32(WaterLevel + 100)
	if c.pos[2] <= waterHeight then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_SUBMERGED))
	else
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_SUBMERGED)))
	end

	camera.resolve_geometry_collisions(c.pos, Scratch.mode_behind_mario_oldPos)
	-- Prevent camera getting too far away
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.mode_behind_mario_distCamToFocus, Scratch.mode_behind_mario_camPitch, Scratch.mode_behind_mario_camYaw)
	if Scratch.mode_behind_mario_distCamToFocus[1] > 800 then
		Scratch.mode_behind_mario_distCamToFocus[1] = 800
		SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, Scratch.mode_behind_mario_distCamToFocus[1], Scratch.mode_behind_mario_camPitch[1], Scratch.mode_behind_mario_camYaw[1])
	end
	camera.pan_ahead_of_player(c)

	return yaw
end

-- from src/game/camera.c:update_slide_camera L1950-2024
function camera.update_slide_camera(c: GroupsTypesHPlus3.Camera): number
	local maxCamDist: number
	local goalPitch = 0x1555
	const goalYaw = S16(camera.sMarioCamState.faceAngle[2] + GroupsTypesHPlus3.DEGREES(180))

	-- Zoom in when inside the CCM shortcut
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CCM_SLIDE_SHORTCUT) then
		camera.sLakituDist = S16(TruncS32(SrcEngineMathUtil.approach_f32(camera.sLakituDist, -600, 20, 20)))
	else
		camera.sLakituDist = S16(TruncS32(SrcEngineMathUtil.approach_f32(camera.sLakituDist, 0, 20, 20)))
	end

	-- No C-Button input in this mode, notify the player with a buzzer
	camera.play_camera_buzz_if_cbutton()

	-- Focus on Mario
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	c.focus[2] = F32(c.focus[2] + 50)

	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.update_slide_camera_distCamToFocus, Scratch.update_slide_camera_camPitch, Scratch.update_slide_camera_camYaw)
	maxCamDist = 800

	-- In hoot mode, zoom further out and rotate faster
	if camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
		maxCamDist = 1000
		goalPitch = 0x2800
		camera.camera_approach_s16_symmetric_bool(Scratch.update_slide_camera_camYaw, goalYaw, 0x100)
	else
		camera.camera_approach_s16_symmetric_bool(Scratch.update_slide_camera_camYaw, goalYaw, 0x80)
	end
	camera.camera_approach_s16_symmetric_bool(Scratch.update_slide_camera_camPitch, goalPitch, 0x100)

	-- Hoot mode
	if camera.sMarioCamState.action ~= IncludeSm64H.ACT_RIDING_HOOT and camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
		SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, Scratch.update_slide_camera_pos, F32(maxCamDist + camera.sLakituDist), Scratch.update_slide_camera_camPitch[1], Scratch.update_slide_camera_camYaw[1])
		c.pos[1] = Scratch.update_slide_camera_pos[1]
		c.pos[3] = Scratch.update_slide_camera_pos[3]
		Scratch.update_slide_camera_posY[1] = c.pos[2]
		camera.camera_approach_f32_symmetric_bool(Scratch.update_slide_camera_posY, c.focus[2], 30)
		c.pos[2] = Scratch.update_slide_camera_posY[1]
		SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, c.focus, Scratch.update_slide_camera_distCamToFocus, Scratch.update_slide_camera_camPitch, Scratch.update_slide_camera_camYaw)
		local pitchScale = F32(F32(F32(Scratch.update_slide_camera_distCamToFocus[1] - maxCamDist) + camera.sLakituDist) / 10000)
		if pitchScale > 1 then
			pitchScale = 1
		end
		Scratch.update_slide_camera_camPitch[1] = S16(TruncS32(F32(Scratch.update_slide_camera_camPitch[1] + F32(0x1000 * pitchScale))))
		SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, c.focus, Scratch.update_slide_camera_distCamToFocus[1], Scratch.update_slide_camera_camPitch[1], Scratch.update_slide_camera_camYaw[1])

	-- Slide mode
	else
		SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, F32(maxCamDist + camera.sLakituDist), Scratch.update_slide_camera_camPitch[1], Scratch.update_slide_camera_camYaw[1])
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT))

		-- Stay above the slide floor
		const FloorY: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], F32(c.pos[2] + 200), c.pos[3], Scratch.update_slide_camera_floor)
		const floorHeight = F32(FloorY + 125)
		if c.pos[2] < floorHeight then
			c.pos[2] = floorHeight
		end
		-- Stay closer than maxCamDist
		SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.update_slide_camera_distCamToFocus, Scratch.update_slide_camera_camPitch, Scratch.update_slide_camera_camYaw)
		if Scratch.update_slide_camera_distCamToFocus[1] > F32(maxCamDist + camera.sLakituDist) then
			Scratch.update_slide_camera_distCamToFocus[1] = F32(maxCamDist + camera.sLakituDist)
			SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, Scratch.update_slide_camera_distCamToFocus[1], Scratch.update_slide_camera_camPitch[1], Scratch.update_slide_camera_camYaw[1])
		end
	end

	Scratch.update_slide_camera_camYaw[1] = camera.calculate_yaw(c.focus, c.pos)
	return Scratch.update_slide_camera_camYaw[1]
end

-- from src/game/camera.c:mode_behind_mario_camera L2026-2028
function camera.mode_behind_mario_camera(c: GroupsTypesHPlus3.Camera)
	c.nextYaw = S16(camera.mode_behind_mario(c))
end

-- from src/game/camera.c:nop_update_water_camera L2030-2034
function camera.nop_update_water_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	return 0
end

-- from src/game/camera.c:mode_water_surface_camera L2039-2041
function camera.mode_water_surface_camera(c: GroupsTypesHPlus3.Camera)
	c.nextYaw = S16(camera.mode_behind_mario(c))
end

-- from src/game/camera.c:update_mario_camera L2046-2051
function camera.update_mario_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const yaw = S16(camera.sMarioCamState.faceAngle[2] + camera.sModeOffsetYaw + GroupsTypesHPlus3.DEGREES(180))
	camera.focus_on_mario(focus, pos, 125, 125, camera.gCameraZoomDist, 0x05B0, yaw)

	return camera.sMarioCamState.faceAngle[2]
end

-- from src/game/camera.c:update_default_camera L2058-2379
function camera.update_default_camera(c: GroupsTypesHPlus3.Camera): number
	local yawVel = 0
	local avoidStatus = 0
	local closeToMario = 0
	local nextYawVel = 0
	local zoomDist = 0
	const yawGoal = S16(camera.sMarioCamState.faceAngle[2] + GroupsTypesHPlus3.DEGREES(180))
	const ceilResult: number = Registry.Members.src__engine__surface_collision.find_ceil(camera.gLakituState.goalPos[1], camera.gLakituState.goalPos[2], camera.gLakituState.goalPos[3], Scratch.update_default_camera_ceil)
	local ceilHeight = ceilResult

	camera.handle_c_button_movement(c)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.update_default_camera_dist, Scratch.update_default_camera_pitch, Scratch.update_default_camera_yaw)

	-- If C-Down is active, determine what distance the camera should be from Mario
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
		-- ! In Mario mode, the camera is zoomed out further than in Lakitu mode (1400 vs 1200)
		if camera.set_cam_angle(0) == GroupsTypesHPlus3.CAM_ANGLE_MARIO then
			zoomDist = F32(camera.gCameraZoomDist + 1050)
		else
			zoomDist = F32(camera.gCameraZoomDist + 400)
		end
	else
		zoomDist = camera.gCameraZoomDist
	end

	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_HANGING) or camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
		zoomDist = F32(zoomDist * F32(0.8))
		camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_HANG_OWL)
	end

	-- If not zooming out, only allow dist to decrease
	if camera.sZoomAmount == 0 then
		if Scratch.update_default_camera_dist[1] > zoomDist then
			Scratch.update_default_camera_dist[1] = F32(Scratch.update_default_camera_dist[1] - 50)
			if Scratch.update_default_camera_dist[1] < zoomDist then
				Scratch.update_default_camera_dist[1] = zoomDist
			end
		end
	else
		camera.sZoomAmount = F32(camera.sZoomAmount - 30)
		if camera.sZoomAmount < 0 then
			camera.sZoomAmount = 0
		end
		if Scratch.update_default_camera_dist[1] > zoomDist then
			Scratch.update_default_camera_dist[1] = F32(Scratch.update_default_camera_dist[1] - 30)
			if Scratch.update_default_camera_dist[1] < zoomDist then
				Scratch.update_default_camera_dist[1] = zoomDist
			end
		end
		if Scratch.update_default_camera_dist[1] < zoomDist then
			Scratch.update_default_camera_dist[1] = F32(Scratch.update_default_camera_dist[1] + 30)
			if Scratch.update_default_camera_dist[1] > zoomDist then
				Scratch.update_default_camera_dist[1] = zoomDist
			end
		end
	end

	-- Determine how fast to rotate the camera
	if camera.sCSideButtonYaw == 0 then
		if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
			nextYawVel = 0xC0
		else
			nextYawVel = 0x100
		end
		if GameInit.gPlayer1Controller.stickX ~= 0 or GameInit.gPlayer1Controller.stickY ~= 0 then
			nextYawVel = 0x20
		end
	else
		if camera.sCSideButtonYaw < 0 then
			Scratch.update_default_camera_yaw[1] = S16(Scratch.update_default_camera_yaw[1] + 0x200)
		end
		if camera.sCSideButtonYaw > 0 then
			Scratch.update_default_camera_yaw[1] = S16(Scratch.update_default_camera_yaw[1] - 0x200)
		end
		Scratch.update_default_camera_sCSideButtonYaw[1] = camera.sCSideButtonYaw
		camera.camera_approach_s16_symmetric_bool(Scratch.update_default_camera_sCSideButtonYaw, 0, 0x100)
		camera.sCSideButtonYaw = Scratch.update_default_camera_sCSideButtonYaw[1]
		nextYawVel = 0
	end
	camera.sYawSpeed = 0x400
	Scratch.update_default_camera_xzDist[1] = camera.calc_hor_dist(camera.sMarioCamState.pos, c.pos)

	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BEHIND_MARIO_POST_DOOR) then
		if Scratch.update_default_camera_xzDist[1] >= 250 then
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BEHIND_MARIO_POST_DOOR)))
		end
		if GroupsTypesHPlus3.ABS(TruncS32((camera.sMarioCamState.faceAngle[2] - Scratch.update_default_camera_yaw[1]) / 2)) < 0x1800 then
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BEHIND_MARIO_POST_DOOR)))
			Scratch.update_default_camera_yaw[1] = S16(camera.sCameraYawAfterDoorCutscene + GroupsTypesHPlus3.DEGREES(180))
			Scratch.update_default_camera_dist[1] = 800
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT))
		end
	elseif Scratch.update_default_camera_xzDist[1] < 250 then
		-- Turn rapidly if very close to Mario
		c.pos[1] = F32(c.pos[1] + F32(F32(250 - Scratch.update_default_camera_xzDist[1]) * Registry.Members.src__engine__math_util_h.sins(Scratch.update_default_camera_yaw[1])))
		c.pos[3] = F32(c.pos[3] + F32(F32(250 - Scratch.update_default_camera_xzDist[1]) * Registry.Members.src__engine__math_util_h.coss(Scratch.update_default_camera_yaw[1])))
		if camera.sCSideButtonYaw == 0 then
			nextYawVel = 0x1000
			camera.sYawSpeed = 0
			SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.update_default_camera_dist, Scratch.update_default_camera_pitch, Scratch.update_default_camera_yaw)
		end
		closeToMario = S32(bit32.bor(closeToMario, 1))
	end

	if -16 < GameInit.gPlayer1Controller.stickY then
		c.yaw = Scratch.update_default_camera_yaw[1]
	end

	camera.calc_y_to_curr_floor(Scratch.update_default_camera_posHeight, 1, 200, Scratch.update_default_camera_focHeight, F32(0.9), 200)
	SrcEngineMathUtil.vec3f_copy(Scratch.update_default_camera_cPos, c.pos)
	avoidStatus = camera.rotate_camera_around_walls(c, Scratch.update_default_camera_cPos, Scratch.update_default_camera_avoidYaw, 0x600)
	-- If a wall is blocking the view of Mario, then rotate in the calculated direction
	if avoidStatus == 3 then
		camera.unusedFreeRoamWallYaw = Scratch.update_default_camera_avoidYaw[1]
		camera.sAvoidYawVel = Scratch.update_default_camera_yaw[1]
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_COLLIDED_WITH_WALL))
		-- ! Does nothing
		SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, Scratch.update_default_camera_cPos, Scratch.update_default_camera_xzDist, Scratch.update_default_camera_tempPitch, Scratch.update_default_camera_tempYaw)
		-- Rotate to avoid the wall
		camera.approach_s16_asymptotic_bool(Scratch.update_default_camera_yaw, Scratch.update_default_camera_avoidYaw[1], 10)
		-- ! Does nothing
		SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, Scratch.update_default_camera_cPos, Scratch.update_default_camera_xzDist[1], Scratch.update_default_camera_tempPitch[1], Scratch.update_default_camera_tempYaw[1])
		camera.sAvoidYawVel = S16(TruncS32((camera.sAvoidYawVel - Scratch.update_default_camera_yaw[1]) / 0x100))
	else
		if LevelUpdate.gMarioStates[1].forwardVel == 0 then
			if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_COLLIDED_WITH_WALL) then
				local yawDir = 0
				if TruncS32((yawGoal - Scratch.update_default_camera_yaw[1]) / 0x100) >= 0 then
					yawDir = -1
				else
					yawDir = 1
				end
				if (camera.sAvoidYawVel > 0 and yawDir > 0) or (camera.sAvoidYawVel < 0 and yawDir < 0) then
					yawVel = nextYawVel
				end
			else
				yawVel = nextYawVel
			end
		else
			if nextYawVel == 0x1000 then
				yawVel = nextYawVel
			end
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_COLLIDED_WITH_WALL)))
		end

		-- If a wall is near the camera, turn twice as fast
		if avoidStatus ~= 0 then
			yawVel = S16(yawVel + yawVel)
		end
		-- ...Unless the camera already rotated from being close to Mario
		if bit32.btest(closeToMario, 1) and avoidStatus ~= 0 then
			yawVel = 0
		end
		if yawVel ~= 0 and GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
			camera.camera_approach_s16_symmetric_bool(Scratch.update_default_camera_yaw, yawGoal, yawVel)
		end
	end

	-- Only zoom out if not obstructed by walls and Lakitu hasn't collided with any
	if avoidStatus == 0 and not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_COLLIDED_WITH_WALL) then
		camera.approach_f32_asymptotic_bool(Scratch.update_default_camera_dist, F32(zoomDist - 100), F32(0.05))
	end
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, Scratch.update_default_camera_cPos, Scratch.update_default_camera_dist[1], Scratch.update_default_camera_pitch[1], Scratch.update_default_camera_yaw[1])
	Scratch.update_default_camera_cPos[2] = F32(Scratch.update_default_camera_cPos[2] + F32(Scratch.update_default_camera_posHeight[1] + 125))

	-- Move the camera away from walls and set the collision flag
	if camera.collide_with_walls(Scratch.update_default_camera_cPos, 10, 80) ~= 0 then
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_COLLIDED_WITH_WALL))
	end

	c.focus[1] = camera.sMarioCamState.pos[1]
	c.focus[2] = F32(F32(camera.sMarioCamState.pos[2] + 125) + Scratch.update_default_camera_focHeight[1])
	c.focus[3] = camera.sMarioCamState.pos[3]

	local marioFloorHeight = F32(125 + camera.sMarioGeometry.currFloorHeight)
	local marioFloor = camera.sMarioGeometry.currFloor
	const camFloorResult: number = Registry.Members.src__engine__surface_collision.find_floor(Scratch.update_default_camera_cPos[1], F32(Scratch.update_default_camera_cPos[2] + 50), Scratch.update_default_camera_cPos[3], Scratch.update_default_camera_cFloor)
	local camFloorHeight = F32(camFloorResult + 125)
	local scale = F32(0.1)
	while scale < 1 do
		camera.scale_along_line(Scratch.update_default_camera_tempPos, Scratch.update_default_camera_cPos, camera.sMarioCamState.pos, scale)
		const tempFloorResult: number = Registry.Members.src__engine__surface_collision.find_floor(Scratch.update_default_camera_tempPos[1], Scratch.update_default_camera_tempPos[2], Scratch.update_default_camera_tempPos[3], Scratch.update_default_camera_tempFloor)
		const tempFloorHeight = F32(tempFloorResult + 125)
		if Scratch.update_default_camera_tempFloor[1] ~= nil and tempFloorHeight > marioFloorHeight then
			marioFloorHeight = tempFloorHeight
			marioFloor = Scratch.update_default_camera_tempFloor[1]
		end
		scale = F32(scale + F32(0.2))
	end

	-- Lower the camera in Mario mode
	if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		marioFloorHeight = F32(marioFloorHeight - 35)
		camFloorHeight = F32(camFloorHeight - 35)
		c.focus[2] = F32(c.focus[2] - 25)
	end

	-- If there's water below the camera, decide whether to keep the camera above the water surface
	local waterHeight: number = Registry.Members.src__engine__surface_collision.find_water_level(Scratch.update_default_camera_cPos[1], Scratch.update_default_camera_cPos[3])
	if waterHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		waterHeight = F32(waterHeight + 125)
		const distFromWater = F32(waterHeight - marioFloorHeight)
		if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_METAL_BELOW_WATER) then
			if distFromWater > 800 and bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_METAL_BELOW_WATER))
			end
		else
			if distFromWater < 400 or not bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_METAL_BELOW_WATER)))
			end
		end
		-- If not wearing the metal cap, always stay above
		if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_METAL_BELOW_WATER) and camFloorHeight < waterHeight then
			camFloorHeight = waterHeight
		end
	else
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_METAL_BELOW_WATER)))
	end

	Scratch.update_default_camera_cPos[2] = camFloorHeight
	SrcEngineMathUtil.vec3f_copy(Scratch.update_default_camera_tempPos, Scratch.update_default_camera_cPos)
	Scratch.update_default_camera_tempPos[2] = F32(Scratch.update_default_camera_tempPos[2] - 125)
	if marioFloor ~= nil and camFloorHeight <= marioFloorHeight then
		avoidStatus = camera.is_range_behind_surface(c.focus, Scratch.update_default_camera_tempPos, marioFloor, 0, -1)
		if avoidStatus ~= 1 and ceilHeight > marioFloorHeight then
			camFloorHeight = marioFloorHeight
		end
	end

	Scratch.update_default_camera_posHeight[1] = 0
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
			Scratch.update_default_camera_posHeight[1] = 375
			if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_PYRAMID then
				Scratch.update_default_camera_posHeight[1] = F32(Scratch.update_default_camera_posHeight[1] / 2)
			end
		else
			Scratch.update_default_camera_posHeight[1] = 100
		end
	end
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) and bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		Scratch.update_default_camera_posHeight[1] = 610
		if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_PYRAMID or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE then
			Scratch.update_default_camera_posHeight[1] = F32(Scratch.update_default_camera_posHeight[1] / 2)
		end
	end

	-- Make Lakitu fly above the gas
	local gasHeight: number = Registry.Members.src__engine__surface_collision.find_poison_gas_level(Scratch.update_default_camera_cPos[1], Scratch.update_default_camera_cPos[3])
	if gasHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		gasHeight = F32(gasHeight + 130)
		if gasHeight > c.pos[2] then
			c.pos[2] = gasHeight
		end
	end

	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_HANGING) or camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
		camFloorHeight = F32(camera.sMarioCamState.pos[2] + 400)
		if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
			camFloorHeight = F32(camFloorHeight - 100)
		end
		ceilHeight = SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT
		SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	end

	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_ON_POLE) then
		camFloorHeight = F32(buffer.readf32((LevelUpdate.gMarioStates[1].usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) + 125)
		if F32(camera.sMarioCamState.pos[2] - 100) > camFloorHeight then
			camFloorHeight = F32(camera.sMarioCamState.pos[2] - 100)
		end
		ceilHeight = SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT
		SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	end
	if camFloorHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		camFloorHeight = F32(camFloorHeight + Scratch.update_default_camera_posHeight[1])
		camera.approach_camera_height(c, camFloorHeight, 20)
	end
	c.pos[1] = Scratch.update_default_camera_cPos[1]
	c.pos[3] = Scratch.update_default_camera_cPos[3]
	Scratch.update_default_camera_cPos[1] = camera.gLakituState.goalPos[1]
	Scratch.update_default_camera_cPos[2] = c.pos[2]
	Scratch.update_default_camera_cPos[3] = camera.gLakituState.goalPos[3]
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.update_default_camera_cPos, c.pos, Scratch.update_default_camera_dist, Scratch.update_default_camera_tempPitch, Scratch.update_default_camera_tempYaw)
	-- Prevent the camera from lagging behind too much
	if Scratch.update_default_camera_dist[1] > 50 then
		Scratch.update_default_camera_dist[1] = 50
		SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.update_default_camera_cPos, c.pos, Scratch.update_default_camera_dist[1], Scratch.update_default_camera_tempPitch[1], Scratch.update_default_camera_tempYaw[1])
	end
	if camera.sMarioGeometry.currFloorType ~= IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.update_default_camera_dist, Scratch.update_default_camera_tempPitch, Scratch.update_default_camera_tempYaw)
		if Scratch.update_default_camera_dist[1] > zoomDist then
			Scratch.update_default_camera_dist[1] = zoomDist
			SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, Scratch.update_default_camera_dist[1], Scratch.update_default_camera_tempPitch[1], Scratch.update_default_camera_tempYaw[1])
		end
	end
	if ceilHeight ~= SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT then
		ceilHeight = F32(ceilHeight - 150)
		if c.pos[2] > ceilHeight then
			avoidStatus = camera.is_range_behind_surface(c.pos, camera.sMarioCamState.pos, Scratch.update_default_camera_ceil[1], 0, -1)
			if avoidStatus == 1 then
				c.pos[2] = ceilHeight
			end
		end
	end
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_TOWN then
		Scratch.update_default_camera_yaw[1] = camera.clamp_positions_and_find_yaw(c.pos, c.focus, 2254, -3789, 3790, -2253)
	end
	return Scratch.update_default_camera_yaw[1]
end

-- from src/game/camera.c:mode_default_camera L2385-2389
function camera.mode_default_camera(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	c.nextYaw = camera.update_default_camera(c)
	camera.pan_ahead_of_player(c)
end

-- from src/game/camera.c:mode_lakitu_camera L2394-2397
function camera.mode_lakitu_camera(c: GroupsTypesHPlus3.Camera)
	camera.gCameraZoomDist = 800
	camera.mode_default_camera(c)
end

-- from src/game/camera.c:mode_mario_camera L2402-2405
function camera.mode_mario_camera(c: GroupsTypesHPlus3.Camera)
	camera.gCameraZoomDist = 350
	camera.mode_default_camera(c)
end

-- from src/game/camera.c:update_spiral_stairs_camera L2410-2480
function camera.update_spiral_stairs_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	camera.handle_c_button_movement(c)
	-- Set base pos to the center of the staircase
	SrcEngineMathUtil.vec3f_set(camera.sFixedModeBasePosition, -1280, 614, 1740)

	-- Focus on Mario, and move the focus up the staircase with him
	camera.calc_y_to_curr_floor(Scratch.update_spiral_stairs_camera_focusHeight, 1, 200, Scratch.update_spiral_stairs_camera_focusHeight, F32(0.9), 200)
	focus[1] = camera.sMarioCamState.pos[1]
	const focY = F32(F32(camera.sMarioCamState.pos[2] + 125) + Scratch.update_spiral_stairs_camera_focusHeight[1])
	focus[3] = camera.sMarioCamState.pos[3]

	SrcEngineMathUtil.vec3f_copy(Scratch.update_spiral_stairs_camera_cPos, pos)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sFixedModeBasePosition, focus, Scratch.update_spiral_stairs_camera_dist, Scratch.update_spiral_stairs_camera_focPitch, Scratch.update_spiral_stairs_camera_focYaw)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sFixedModeBasePosition, Scratch.update_spiral_stairs_camera_cPos, Scratch.update_spiral_stairs_camera_dist, Scratch.update_spiral_stairs_camera_posPitch, Scratch.update_spiral_stairs_camera_posYaw)

	camera.sSpiralStairsYawOffset = S16(Scratch.update_spiral_stairs_camera_posYaw[1] - Scratch.update_spiral_stairs_camera_focYaw[1])
	-- posYaw will change if Mario is more than 90 degrees around the stairs, relative to the camera
	if camera.sSpiralStairsYawOffset < GroupsTypesHPlus3.DEGREES(-90) then
		camera.sSpiralStairsYawOffset = S16(GroupsTypesHPlus3.DEGREES(-90))
	end
	if camera.sSpiralStairsYawOffset > GroupsTypesHPlus3.DEGREES(90) then
		camera.sSpiralStairsYawOffset = S16(GroupsTypesHPlus3.DEGREES(90))
	end
	Scratch.update_spiral_stairs_camera_focYaw[1] = S16(Scratch.update_spiral_stairs_camera_focYaw[1] + camera.sSpiralStairsYawOffset)
	Scratch.update_spiral_stairs_camera_posYaw[1] = Scratch.update_spiral_stairs_camera_focYaw[1]
	-- ! @bug unnecessary
	camera.camera_approach_s16_symmetric_bool(Scratch.update_spiral_stairs_camera_posYaw, Scratch.update_spiral_stairs_camera_focYaw[1], 0x1000)

	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sFixedModeBasePosition, Scratch.update_spiral_stairs_camera_cPos, 300, 0, Scratch.update_spiral_stairs_camera_posYaw[1])

	-- Move the camera's y coord up/down the staircase
	Scratch.update_spiral_stairs_camera_checkPos[1] = F32(focus[1] + F32(F32(Scratch.update_spiral_stairs_camera_cPos[1] - focus[1]) * F32(0.7)))
	Scratch.update_spiral_stairs_camera_checkPos[2] = F32(F32(focus[2] + F32(F32(Scratch.update_spiral_stairs_camera_cPos[2] - focus[2]) * F32(0.7))) + 300)
	Scratch.update_spiral_stairs_camera_checkPos[3] = F32(focus[3] + F32(F32(Scratch.update_spiral_stairs_camera_cPos[3] - focus[3]) * F32(0.7)))
	local floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(Scratch.update_spiral_stairs_camera_checkPos[1], F32(Scratch.update_spiral_stairs_camera_checkPos[2] + 50), Scratch.update_spiral_stairs_camera_checkPos[3], Scratch.update_spiral_stairs_camera_floor)

	if floorHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		if floorHeight < camera.sMarioGeometry.currFloorHeight then
			floorHeight = camera.sMarioGeometry.currFloorHeight
		end
		floorHeight = F32(floorHeight + 125)
		pos[2] = SrcEngineMathUtil.approach_f32(pos[2], floorHeight, 30, 30)
	end

	Scratch.update_spiral_stairs_camera_focusY[1] = focus[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.update_spiral_stairs_camera_focusY, focY, 30)
	focus[2] = Scratch.update_spiral_stairs_camera_focusY[1]
	pos[1] = Scratch.update_spiral_stairs_camera_cPos[1]
	pos[3] = Scratch.update_spiral_stairs_camera_cPos[3]
	const camYaw = camera.calculate_yaw(focus, pos)

	return camYaw
end

-- from src/game/camera.c:mode_spiral_stairs_camera L2485-2487
function camera.mode_spiral_stairs_camera(c: GroupsTypesHPlus3.Camera)
	c.nextYaw = S16(camera.update_spiral_stairs_camera(c, c.focus, c.pos))
end

-- from src/game/camera.c:update_slide_or_0f_camera L2489-2494
function camera.update_slide_or_0f_camera(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const yaw = S16(camera.sMarioCamState.faceAngle[2] + camera.sModeOffsetYaw + GroupsTypesHPlus3.DEGREES(180))

	camera.focus_on_mario(focus, pos, 125, 125, 800, 5461, yaw)
	return camera.sMarioCamState.faceAngle[2]
end

-- from src/game/camera.c:unused_mode_0f_camera L2496-2501
function camera.unused_mode_0f_camera(c: GroupsTypesHPlus3.Camera)
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.U_CBUTTONS) then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))
	end
	c.nextYaw = S16(camera.update_slide_camera(c))
end

-- from src/game/camera.c:mode_slide_camera L2507-2517
function camera.mode_slide_camera(c: GroupsTypesHPlus3.Camera)
	if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CLOSE_CAMERA or camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_SLIPPERY then
		camera.mode_lakitu_camera(c)
	else
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.U_CBUTTONS) then
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))
		end
		c.nextYaw = S16(camera.update_slide_camera(c))
	end
end

-- from src/game/camera.c:store_lakitu_cam_info_for_c_up L2519-2524
function camera.store_lakitu_cam_info_for_c_up(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCUp.pos, c.pos)
	camera.vec3f_sub(camera.sCameraStoreCUp.pos, camera.sMarioCamState.pos)
	-- Only store the y value, and as an offset from Mario, for some reason
	SrcEngineMathUtil.vec3f_set(camera.sCameraStoreCUp.focus, 0, F32(c.focus[2] - camera.sMarioCamState.pos[2]), 0)
end

-- from src/game/camera.c:set_mode_c_up L2531-2539
function camera.set_mode_c_up(c: GroupsTypesHPlus3.Camera): number
	if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE) then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))
		camera.store_lakitu_cam_info_for_c_up(c)
		camera.sCameraSoundFlags = S16(bit32.band(camera.sCameraSoundFlags, bit32.bnot(GroupsTypesHPlus3.CAM_SOUND_C_UP_PLAYED)))
		return 1
	end
	return 0
end

-- from src/game/camera.c:exit_c_up L2545-2645
function camera.exit_c_up(c: GroupsTypesHPlus3.Camera): number
	-- Variables for searching for an open direction
	local searching = 0
	local checkYaw = 0

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE) and not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_STARTED_EXITING_C_UP) then
		SrcEngineMathUtil.vec3f_copy(Scratch.exit_c_up_checkFoc, c.focus)
		Scratch.exit_c_up_checkFoc[1] = camera.sMarioCamState.pos[1]
		Scratch.exit_c_up_checkFoc[3] = camera.sMarioCamState.pos[3]
		SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.exit_c_up_checkFoc, c.pos, Scratch.exit_c_up_curDist, Scratch.exit_c_up_curPitch, Scratch.exit_c_up_curYaw)
		SrcEngineMathUtil.vec3f_copy(Scratch.exit_c_up_curPos, c.pos)
		Scratch.exit_c_up_curDist[1] = 80

		-- Search for an open direction to zoom out in, if the camera is changing to close, free roam,
		-- or spiral-stairs mode
		if camera.sModeInfo.lastMode == GroupsTypesHPlus3.CAMERA_MODE_SPIRAL_STAIRS or camera.sModeInfo.lastMode == GroupsTypesHPlus3.CAMERA_MODE_CLOSE or camera.sModeInfo.lastMode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
			searching = 1
			-- Check the whole circle around Mario for an open direction to zoom out to
			local sector = 0
			while sector < 16 and searching == 1 do
				SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.exit_c_up_checkFoc, Scratch.exit_c_up_curPos, Scratch.exit_c_up_curDist[1], 0, S16(Scratch.exit_c_up_curYaw[1] + checkYaw))

				-- If there are no walls this way,
				Scratch.exit_c_up_curPosX[1] = Scratch.exit_c_up_curPos[1]
				Scratch.exit_c_up_curPosY[1] = Scratch.exit_c_up_curPos[2]
				Scratch.exit_c_up_curPosZ[1] = Scratch.exit_c_up_curPos[3]
				const wallCount: number = Registry.Members.src__engine__surface_collision.f32_find_wall_collision(Scratch.exit_c_up_curPosX, Scratch.exit_c_up_curPosY, Scratch.exit_c_up_curPosZ, 20, 50)
				Scratch.exit_c_up_curPos[1] = Scratch.exit_c_up_curPosX[1]
				Scratch.exit_c_up_curPos[2] = Scratch.exit_c_up_curPosY[1]
				Scratch.exit_c_up_curPos[3] = Scratch.exit_c_up_curPosZ[1]
				if wallCount == 0 then
					-- Start close to Mario, check for walls, floors, and ceilings all the way to the
					-- zoomed out distance
					local d = Scratch.exit_c_up_curDist[1]
					while d < camera.gCameraZoomDist do
						SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.exit_c_up_checkFoc, Scratch.exit_c_up_curPos, d, 0, S16(Scratch.exit_c_up_curYaw[1] + checkYaw))

						-- Check if we're zooming out into a floor or ceiling
						const ceilResult: number = Registry.Members.src__engine__surface_collision.find_ceil(Scratch.exit_c_up_curPos[1], F32(Scratch.exit_c_up_curPos[2] - 150), Scratch.exit_c_up_curPos[3], Scratch.exit_c_up_surface)
						const ceilHeight = F32(ceilResult + -10)
						if Scratch.exit_c_up_surface[1] ~= nil and ceilHeight < Scratch.exit_c_up_curPos[2] then
							break
						end
						const floorResult: number = Registry.Members.src__engine__surface_collision.find_floor(Scratch.exit_c_up_curPos[1], F32(Scratch.exit_c_up_curPos[2] + 150), Scratch.exit_c_up_curPos[3], Scratch.exit_c_up_surface)
						const floorHeight = F32(floorResult + 10)
						if Scratch.exit_c_up_surface[1] ~= nil and floorHeight > Scratch.exit_c_up_curPos[2] then
							break
						end

						-- Stop checking this direction if there is a wall blocking the way
						Scratch.exit_c_up_curPosX[1] = Scratch.exit_c_up_curPos[1]
						Scratch.exit_c_up_curPosY[1] = Scratch.exit_c_up_curPos[2]
						Scratch.exit_c_up_curPosZ[1] = Scratch.exit_c_up_curPos[3]
						const innerWallCount: number = Registry.Members.src__engine__surface_collision.f32_find_wall_collision(Scratch.exit_c_up_curPosX, Scratch.exit_c_up_curPosY, Scratch.exit_c_up_curPosZ, 20, 50)
						Scratch.exit_c_up_curPos[1] = Scratch.exit_c_up_curPosX[1]
						Scratch.exit_c_up_curPos[2] = Scratch.exit_c_up_curPosY[1]
						Scratch.exit_c_up_curPos[3] = Scratch.exit_c_up_curPosZ[1]
						if innerWallCount == 1 then
							break
						end

						d = F32(d + 20)
					end

					-- If there was no collision found all the way to the max distance, it's an opening
					if d >= camera.gCameraZoomDist then
						searching = 0
					end
				end

				-- Alternate left and right, checking each 1/16th (22.5 degrees) of the circle
				if searching == 1 then
					checkYaw = S16(-checkYaw)
					if checkYaw < 0 then
						checkYaw = S16(checkYaw - 0x1000)
					else
						checkYaw = S16(checkYaw + 0x1000)
					end
				end
				sector += 1
			end

			-- Update the stored focus and pos to the direction found in the search
			if searching == 0 then
				SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.exit_c_up_checkFoc, camera.sCameraStoreCUp.pos, camera.gCameraZoomDist, 0, S16(Scratch.exit_c_up_curYaw[1] + checkYaw))
				SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCUp.focus, Scratch.exit_c_up_checkFoc)
				camera.vec3f_sub(camera.sCameraStoreCUp.pos, camera.sMarioCamState.pos)
				camera.vec3f_sub(camera.sCameraStoreCUp.focus, camera.sMarioCamState.pos)
			end

			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_STARTED_EXITING_C_UP))
			camera.transition_next_state(c, 15)
		else
			-- Let the next camera mode handle it
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_STARTED_EXITING_C_UP, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))))
			SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.exit_c_up_checkFoc, c.pos, Scratch.exit_c_up_curDist[1], Scratch.exit_c_up_curPitch[1], S16(Scratch.exit_c_up_curYaw[1] + checkYaw))
		end
		camera.play_sound_cbutton_down()
	end
	return 0
end

-- from src/game/camera.c:update_c_up L2650-2656
function camera.update_c_up(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	const pitch = camera.sCUpCameraPitch
	const yaw = S16(camera.sMarioCamState.faceAngle[2] + camera.sModeOffsetYaw + GroupsTypesHPlus3.DEGREES(180))

	camera.focus_on_mario(focus, pos, 125, 125, 250, pitch, yaw)
	return camera.sMarioCamState.faceAngle[2]
end

-- from src/game/camera.c:move_mario_head_c_up L2661-2688
function camera.move_mario_head_c_up(c: GroupsTypesHPlus3.Camera)
	camera.sCUpCameraPitch = S16(camera.sCUpCameraPitch + S16(TruncS32(F32(GameInit.gPlayer1Controller.stickY * 10))))
	camera.sModeOffsetYaw = S16(camera.sModeOffsetYaw - S16(TruncS32(F32(GameInit.gPlayer1Controller.stickX * 10))))

	-- Bound looking up to nearly 80 degrees.
	if camera.sCUpCameraPitch > 0x38E3 then
		camera.sCUpCameraPitch = 0x38E3
	end
	-- Bound looking down to -45 degrees
	if camera.sCUpCameraPitch < -0x2000 then
		camera.sCUpCameraPitch = -0x2000
	end

	-- Bound the camera yaw to +-120 degrees
	if camera.sModeOffsetYaw > 0x5555 then
		camera.sModeOffsetYaw = 0x5555
	end
	if camera.sModeOffsetYaw < -0x5555 then
		camera.sModeOffsetYaw = -0x5555
	end

	-- Give Mario's neck natural-looking constraints
	camera.sMarioCamState.headRotation[1] = S16(TruncS32(camera.sCUpCameraPitch * 3 / 4))
	camera.sMarioCamState.headRotation[2] = S16(TruncS32(camera.sModeOffsetYaw * 3 / 4))
end

-- from src/game/camera.c:move_into_c_up L2693-2721
function camera.move_into_c_up(c: GroupsTypesHPlus3.Camera)
	const start = camera.sModeInfo.transitionStart
	const end_ = camera.sModeInfo.transitionEnd

	local dist = F32(end_.dist - start.dist)
	local pitch = S16(end_.pitch - start.pitch)
	local yaw = S16(end_.yaw - start.yaw)

	-- Linearly interpolate from start to end position's polar coordinates
	dist = F32(start.dist + F32(F32(dist * camera.sModeInfo.frame) / camera.sModeInfo.max))
	pitch = S16(start.pitch + TruncS32(pitch * camera.sModeInfo.frame / camera.sModeInfo.max))
	yaw = S16(start.yaw + TruncS32(yaw * camera.sModeInfo.frame / camera.sModeInfo.max))

	-- Linearly interpolate the focus from start to end
	c.focus[1] = F32(start.focus[1] + F32(F32(F32(end_.focus[1] - start.focus[1]) * camera.sModeInfo.frame) / camera.sModeInfo.max))
	c.focus[2] = F32(start.focus[2] + F32(F32(F32(end_.focus[2] - start.focus[2]) * camera.sModeInfo.frame) / camera.sModeInfo.max))
	c.focus[3] = F32(start.focus[3] + F32(F32(F32(end_.focus[3] - start.focus[3]) * camera.sModeInfo.frame) / camera.sModeInfo.max))

	SrcEngineMathUtil.vec3f_add(c.focus, camera.sMarioCamState.pos)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, dist, pitch, yaw)

	camera.sMarioCamState.headRotation[1] = 0
	camera.sMarioCamState.headRotation[2] = 0

	-- Finished zooming in
	camera.sModeInfo.frame = S16(camera.sModeInfo.frame + 1)
	if camera.sModeInfo.frame == camera.sModeInfo.max then
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVING_INTO_MODE)))
	end
end

-- from src/game/camera.c:mode_c_up_camera L2726-2769
function camera.mode_c_up_camera(c: GroupsTypesHPlus3.Camera): number
	-- Play a sound when entering C-Up mode
	if not bit32.btest(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_C_UP_PLAYED) then
		camera.play_sound_cbutton_up()
		camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_C_UP_PLAYED))
	end

	-- Zoom in first
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVING_INTO_MODE) then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))
		camera.move_into_c_up(c)
		return 1
	end

	if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_STARTED_EXITING_C_UP) then
		-- Normal update
		camera.move_mario_head_c_up(c)
		camera.update_c_up(c, c.focus, c.pos)
	else
		-- Exiting C-Up
		if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_TRANSITION_OUT_OF_C_UP) then
			-- Retrieve the previous position and focus
			SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCameraStoreCUp.pos)
			SrcEngineMathUtil.vec3f_add(c.pos, camera.sMarioCamState.pos)
			SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCameraStoreCUp.focus)
			SrcEngineMathUtil.vec3f_add(c.focus, camera.sMarioCamState.pos)
			-- Make Mario look forward
			Scratch.mode_c_up_camera_ref[1] = camera.sMarioCamState.headRotation[1]
			camera.camera_approach_s16_symmetric_bool(Scratch.mode_c_up_camera_ref, 0, 1024)
			camera.sMarioCamState.headRotation[1] = Scratch.mode_c_up_camera_ref[1]
			Scratch.mode_c_up_camera_ref[1] = camera.sMarioCamState.headRotation[2]
			camera.camera_approach_s16_symmetric_bool(Scratch.mode_c_up_camera_ref, 0, 1024)
			camera.sMarioCamState.headRotation[2] = Scratch.mode_c_up_camera_ref[1]
		else
			-- Finished exiting C-Up
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_STARTED_EXITING_C_UP, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE))))
		end
	end
	camera.sPanDistance = 0

	-- Exit C-Up mode
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, bit32.bor(IncludePROsH.A_BUTTON, IncludePROsH.B_BUTTON, IncludePROsH.D_CBUTTONS, IncludePROsH.L_CBUTTONS, IncludePROsH.R_CBUTTONS)) then
		camera.exit_c_up(c)
	end
	return 0
end

-- from src/game/camera.c:update_in_cannon L2774-2778
function camera.update_in_cannon(c: GroupsTypesHPlus3.Camera, focus: { number }, pos: { number }): number
	camera.focus_on_mario(pos, focus, F32(125 + camera.sCannonYOffset), 125, 800, camera.sMarioCamState.faceAngle[1], camera.sMarioCamState.faceAngle[2])
	return camera.sMarioCamState.faceAngle[2]
end

-- from src/game/camera.c:mode_cannon_camera L2784-2798
function camera.mode_cannon_camera(c: GroupsTypesHPlus3.Camera)
	camera.sLakituPitch = 0
	camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVING_INTO_MODE)))
	c.nextYaw = S16(camera.update_in_cannon(c, c.focus, c.pos))
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.A_BUTTON) then
		camera.set_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO, 1)
		camera.sPanDistance = 0
		camera.sCannonYOffset = 0
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT)))
	else
		camera.sCannonYOffset = SrcEngineMathUtil.approach_f32(camera.sCannonYOffset, 0, 100, 100)
	end
end

-- from src/game/camera.c:transition_next_state L2809-2814
function camera.transition_next_state(c: GroupsTypesHPlus3.Camera, frames: number)
	frames = S16(TruncS32(frames))
	if not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_FRAME_AFTER_CAM_INIT) then
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, bit32.bor(GroupsTypesHPlus3.CAM_FLAG_START_TRANSITION, GroupsTypesHPlus3.CAM_FLAG_TRANSITION_OUT_OF_C_UP)))
		camera.sModeTransition.framesLeft = frames
	end
end

-- from src/game/camera.c:transition_to_camera_mode L2822-2841
function camera.transition_to_camera_mode(c: GroupsTypesHPlus3.Camera, newMode: number, numFrames: number)
	newMode = S16(TruncS32(newMode))
	numFrames = S16(TruncS32(numFrames))
	if c.mode ~= newMode then
		camera.sModeInfo.newMode = if newMode ~= -1 then newMode else camera.sModeInfo.lastMode
		camera.sModeInfo.lastMode = c.mode
		c.mode = U8(camera.sModeInfo.newMode)

		-- Clear movement flags that would affect the transition
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, U16(bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_RESTRICT, GroupsTypesHPlus3.CAM_MOVE_ROTATE)))))
		if not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_FRAME_AFTER_CAM_INIT) then
			camera.transition_next_state(c, numFrames)
			camera.sCUpCameraPitch = 0
			camera.sModeOffsetYaw = 0
			camera.sLakituDist = 0
			camera.sLakituPitch = 0
			camera.sAreaYawChange = 0
			camera.sPanDistance = 0
			camera.sCannonYOffset = 0
		end
	end
end

-- from src/game/camera.c:set_camera_mode L2854-2901
function camera.set_camera_mode(c: GroupsTypesHPlus3.Camera, mode: number, frames: number)
	mode = S16(TruncS32(mode))
	frames = S16(TruncS32(frames))
	const start = camera.sModeInfo.transitionStart
	const endPoint = camera.sModeInfo.transitionEnd

	if mode == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE and camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTM_OUTSIDE then
		-- Empty in the C source.
	else
		-- Clear movement flags that would affect the transition
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.band(bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_MOVE_RESTRICT, GroupsTypesHPlus3.CAM_MOVE_ROTATE)), 0xFFFF)))
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVING_INTO_MODE))
		if mode == GroupsTypesHPlus3.CAMERA_MODE_NONE then
			mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
		end
		camera.sCUpCameraPitch = 0
		camera.sModeOffsetYaw = 0
		camera.sLakituDist = 0
		camera.sLakituPitch = 0
		camera.sAreaYawChange = 0

		camera.sModeInfo.newMode = if mode ~= -1 then mode else camera.sModeInfo.lastMode
		camera.sModeInfo.lastMode = c.mode
		camera.sModeInfo.max = frames
		camera.sModeInfo.frame = 1

		c.mode = U8(camera.sModeInfo.newMode)
		camera.gLakituState.mode = c.mode

		SrcEngineMathUtil.vec3f_copy(endPoint.focus, c.focus)
		camera.vec3f_sub(endPoint.focus, camera.sMarioCamState.pos)

		SrcEngineMathUtil.vec3f_copy(endPoint.pos, c.pos)
		camera.vec3f_sub(endPoint.pos, camera.sMarioCamState.pos)

		const modeTransition = camera.sModeTransitions[camera.sModeInfo.newMode + 1] :: (GroupsTypesHPlus3.Camera, { number }, { number }) -> number
		camera.sAreaYaw = S16(modeTransition(c, endPoint.focus, endPoint.pos))

		-- End was updated by sModeTransitions
		camera.vec3f_sub(endPoint.focus, camera.sMarioCamState.pos)
		camera.vec3f_sub(endPoint.pos, camera.sMarioCamState.pos)

		SrcEngineMathUtil.vec3f_copy(start.focus, camera.gLakituState.curFocus)
		camera.vec3f_sub(start.focus, camera.sMarioCamState.pos)

		SrcEngineMathUtil.vec3f_copy(start.pos, camera.gLakituState.curPos)
		camera.vec3f_sub(start.pos, camera.sMarioCamState.pos)

		Scratch.set_camera_mode_dist[1] = start.dist
		Scratch.set_camera_mode_pitch[1] = start.pitch
		Scratch.set_camera_mode_yaw[1] = start.yaw
		SrcEngineMathUtil.vec3f_get_dist_and_angle(start.focus, start.pos, Scratch.set_camera_mode_dist, Scratch.set_camera_mode_pitch, Scratch.set_camera_mode_yaw)
		start.dist = Scratch.set_camera_mode_dist[1]
		start.pitch = Scratch.set_camera_mode_pitch[1]
		start.yaw = Scratch.set_camera_mode_yaw[1]

		Scratch.set_camera_mode_dist[1] = endPoint.dist
		Scratch.set_camera_mode_pitch[1] = endPoint.pitch
		Scratch.set_camera_mode_yaw[1] = endPoint.yaw
		SrcEngineMathUtil.vec3f_get_dist_and_angle(endPoint.focus, endPoint.pos, Scratch.set_camera_mode_dist, Scratch.set_camera_mode_pitch, Scratch.set_camera_mode_yaw)
		endPoint.dist = Scratch.set_camera_mode_dist[1]
		endPoint.pitch = Scratch.set_camera_mode_pitch[1]
		endPoint.yaw = Scratch.set_camera_mode_yaw[1]
	end
end

-- from src/game/camera.c:update_lakitu L2906-3004
function camera.update_lakitu(c: GroupsTypesHPlus3.Camera)
	local distToFloor: number

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN) then
		-- Empty in the C source.
	else
		if c.cutscene ~= 0 then
			-- Empty in the C source.
		end
		if IncludePRUltratypesH.TRUE ~= 0 then
			const newYaw = S16(camera.next_lakitu_state(Scratch.update_lakitu_newPos, Scratch.update_lakitu_newFoc, c.pos, c.focus, camera.sOldPosition, camera.sOldFocus, c.nextYaw))
			Scratch.update_lakitu_yaw[1] = c.yaw
			camera.set_or_approach_s16_symmetric(Scratch.update_lakitu_yaw, newYaw, camera.sYawSpeed)
			c.yaw = Scratch.update_lakitu_yaw[1]
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE)))
		else
			-- dead code, moved to next_lakitu_state()
			SrcEngineMathUtil.vec3f_copy(Scratch.update_lakitu_newPos, c.pos)
			SrcEngineMathUtil.vec3f_copy(Scratch.update_lakitu_newFoc, c.focus)
		end

		-- Update old state
		SrcEngineMathUtil.vec3f_copy(camera.sOldPosition, Scratch.update_lakitu_newPos)
		SrcEngineMathUtil.vec3f_copy(camera.sOldFocus, Scratch.update_lakitu_newFoc)

		camera.gLakituState.yaw = c.yaw
		camera.gLakituState.nextYaw = c.nextYaw
		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalPos, c.pos)
		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalFocus, c.focus)

		-- Simulate Lakitu flying to the new position and turning towards the new focus
		camera.set_or_approach_vec3f_asymptotic(camera.gLakituState.curPos, Scratch.update_lakitu_newPos, camera.gLakituState.posHSpeed, camera.gLakituState.posVSpeed, camera.gLakituState.posHSpeed)
		camera.set_or_approach_vec3f_asymptotic(camera.gLakituState.curFocus, Scratch.update_lakitu_newFoc, camera.gLakituState.focHSpeed, camera.gLakituState.focVSpeed, camera.gLakituState.focHSpeed)
		-- Adjust Lakitu's speed back to normal
		Scratch.update_lakitu_speed[1] = camera.gLakituState.focHSpeed
		camera.set_or_approach_f32_asymptotic(Scratch.update_lakitu_speed, F32(0.8), F32(0.05))
		camera.gLakituState.focHSpeed = Scratch.update_lakitu_speed[1]
		Scratch.update_lakitu_speed[1] = camera.gLakituState.focVSpeed
		camera.set_or_approach_f32_asymptotic(Scratch.update_lakitu_speed, F32(0.3), F32(0.05))
		camera.gLakituState.focVSpeed = Scratch.update_lakitu_speed[1]
		Scratch.update_lakitu_speed[1] = camera.gLakituState.posHSpeed
		camera.set_or_approach_f32_asymptotic(Scratch.update_lakitu_speed, F32(0.3), F32(0.05))
		camera.gLakituState.posHSpeed = Scratch.update_lakitu_speed[1]
		Scratch.update_lakitu_speed[1] = camera.gLakituState.posVSpeed
		camera.set_or_approach_f32_asymptotic(Scratch.update_lakitu_speed, F32(0.3), F32(0.05))
		camera.gLakituState.posVSpeed = Scratch.update_lakitu_speed[1]

		-- Turn on smooth movement when it hasn't been blocked for 2 frames
		if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT) then
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT)))
		else
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
		end

		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.pos, camera.gLakituState.curPos)
		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.focus, camera.gLakituState.curFocus)

		if c.cutscene ~= 0 then
			SrcEngineMathUtil.vec3f_add(camera.gLakituState.focus, camera.sPlayer2FocusOffset)
			SrcEngineMathUtil.vec3f_set(camera.sPlayer2FocusOffset, 0, 0, 0)
		end

		Scratch.update_lakitu_dist[1] = camera.gLakituState.focusDistance
		Scratch.update_lakitu_pitch[1] = camera.gLakituState.oldPitch
		Scratch.update_lakitu_oldYaw[1] = camera.gLakituState.oldYaw
		SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.gLakituState.pos, camera.gLakituState.focus, Scratch.update_lakitu_dist, Scratch.update_lakitu_pitch, Scratch.update_lakitu_oldYaw)
		camera.gLakituState.focusDistance = Scratch.update_lakitu_dist[1]
		camera.gLakituState.oldPitch = Scratch.update_lakitu_pitch[1]
		camera.gLakituState.oldYaw = Scratch.update_lakitu_oldYaw[1]

		camera.gLakituState.roll = 0

		-- Apply camera shakes
		camera.shake_camera_pitch(camera.gLakituState.pos, camera.gLakituState.focus)
		camera.shake_camera_yaw(camera.gLakituState.pos, camera.gLakituState.focus)
		Scratch.update_lakitu_roll[1] = camera.gLakituState.roll
		camera.shake_camera_roll(Scratch.update_lakitu_roll)
		camera.gLakituState.roll = Scratch.update_lakitu_roll[1]
		camera.shake_camera_handheld(camera.gLakituState.pos, camera.gLakituState.focus)

		if camera.sMarioCamState.action == IncludeSm64H.ACT_DIVE and camera.gLakituState.lastFrameAction ~= IncludeSm64H.ACT_DIVE then
			camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_HIT_FROM_BELOW)
		end

		camera.gLakituState.roll = S16(camera.gLakituState.roll + camera.sHandheldShakeRoll)
		camera.gLakituState.roll = S16(camera.gLakituState.roll + camera.gLakituState.keyDanceRoll)

		if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_C_UP and c.cutscene == 0 then
			ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.TRUE
			distToFloor = Registry.Members.src__engine__surface_collision.find_floor(camera.gLakituState.pos[1], F32(camera.gLakituState.pos[2] + 20), camera.gLakituState.pos[3], Scratch.update_lakitu_floor)
			if distToFloor ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
				distToFloor = F32(distToFloor + 100)
				if camera.gLakituState.pos[2] < distToFloor then
					camera.gLakituState.pos[2] = distToFloor
				else
					ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.FALSE
				end
			end
		end

		SrcEngineMathUtil.vec3f_copy(camera.sModeTransition.marioPos, camera.sMarioCamState.pos)
	end
	camera.clamp_pitch(camera.gLakituState.pos, camera.gLakituState.focus, 0x3E00, -0x3E00)
	camera.gLakituState.mode = c.mode
	camera.gLakituState.defMode = c.defMode
end

-- from src/game/camera.c:update_camera L3011-3202
function camera.update_camera(c: GroupsTypesHPlus3.Camera)
	camera.gCamera = c
	camera.update_camera_hud_status(c)
	if c.cutscene == 0 then
		-- Only process R_TRIG if 'fixed' is not selected in the menu
		if camera.cam_select_alt_mode(0) == GroupsTypesHPlus3.CAM_SELECTION_MARIO then
			if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_TRIG) then
				if camera.set_cam_angle(0) == GroupsTypesHPlus3.CAM_ANGLE_LAKITU then
					camera.set_cam_angle(GroupsTypesHPlus3.CAM_ANGLE_MARIO)
				else
					camera.set_cam_angle(GroupsTypesHPlus3.CAM_ANGLE_LAKITU)
				end
			end
		end
		camera.play_sound_if_cam_switched_to_lakitu_or_mario()
	end

	-- Initialize the camera
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_FRAME_AFTER_CAM_INIT)))
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_INIT_CAMERA) then
		camera.init_camera(c)
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_INIT_CAMERA)))
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_FRAME_AFTER_CAM_INIT))
	end

	-- Store previous geometry information
	camera.sMarioGeometry.prevFloorHeight = camera.sMarioGeometry.currFloorHeight
	camera.sMarioGeometry.prevCeilHeight = camera.sMarioGeometry.currCeilHeight
	camera.sMarioGeometry.prevFloor = camera.sMarioGeometry.currFloor
	camera.sMarioGeometry.prevCeil = camera.sMarioGeometry.currCeil
	camera.sMarioGeometry.prevFloorType = camera.sMarioGeometry.currFloorType
	camera.sMarioGeometry.prevCeilType = camera.sMarioGeometry.currCeilType

	camera.find_mario_floor_and_ceil(camera.sMarioGeometry)
	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.TRUE
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.gLakituState.goalPos)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.gLakituState.goalFocus)

	c.yaw = camera.gLakituState.yaw
	c.nextYaw = camera.gLakituState.nextYaw
	c.mode = camera.gLakituState.mode
	c.defMode = camera.gLakituState.defMode

	camera.camera_course_processing(c)
	camera.stub_camera_3(c)
	camera.sCButtonsPressed = U16(camera.find_c_buttons_pressed(camera.sCButtonsPressed, GameInit.gPlayer1Controller.buttonPressed, GameInit.gPlayer1Controller.buttonDown))

	if c.cutscene ~= 0 then
		camera.sYawSpeed = 0
		camera.play_cutscene(c)
		camera.sFramesSinceCutsceneEnded = 0
	else
		-- Clear the recent cutscene after 8 frames
		if camera.gRecentCutscene ~= 0 and camera.sFramesSinceCutsceneEnded < 8 then
			camera.sFramesSinceCutsceneEnded = U8(camera.sFramesSinceCutsceneEnded + 1)
			if camera.sFramesSinceCutsceneEnded >= 8 then
				camera.gRecentCutscene = 0
				camera.sFramesSinceCutsceneEnded = 0
			end
		end
	end
	-- If not in a cutscene, do mode processing
	if c.cutscene == 0 then
		camera.sYawSpeed = 0x400

		if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
			if c.mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
				camera.mode_behind_mario_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_C_UP then
				camera.mode_c_up_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
				camera.mode_water_surface_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON then
				camera.mode_cannon_camera(c)
			else
				camera.mode_mario_camera(c)
			end
		else
			if c.mode == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
				camera.mode_behind_mario_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_C_UP then
				camera.mode_c_up_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
				camera.mode_water_surface_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON then
				camera.mode_cannon_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS then
				camera.mode_8_directions_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
				camera.mode_radial_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL then
				camera.mode_outward_radial_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
				camera.mode_lakitu_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
				camera.mode_lakitu_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_BOSS_FIGHT then
				camera.mode_boss_fight_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_PARALLEL_TRACKING then
				camera.mode_parallel_tracking_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_SLIDE_HOOT then
				camera.mode_slide_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED then
				camera.mode_fixed_camera(c)
			elseif c.mode == GroupsTypesHPlus3.CAMERA_MODE_SPIRAL_STAIRS then
				camera.mode_spiral_stairs_camera(c)
			end
		end
	end
	-- Start any Mario-related cutscenes
	camera.start_cutscene(c, camera.get_cutscene_from_mario_status(c))
	camera.stub_camera_2(c)
	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.FALSE
	if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_CASTLE then
		-- If fixed camera is selected as the alternate mode, then fix the camera as long as the right
		-- trigger is held
		if (c.cutscene == 0 and bit32.btest(GameInit.gPlayer1Controller.buttonDown, IncludePROsH.R_TRIG) and camera.cam_select_alt_mode(0) == GroupsTypesHPlus3.CAM_SELECTION_FIXED) or bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_FIX_IN_PLACE) or camera.sMarioCamState.action == IncludeSm64H.ACT_GETTING_BLOWN then

			-- If this is the first frame that R_TRIG is held, play the "click" sound
			if c.cutscene == 0 and bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_TRIG) and camera.cam_select_alt_mode(0) == GroupsTypesHPlus3.CAM_SELECTION_FIXED then
				camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_FIXED_ACTIVE))
				camera.play_sound_rbutton_changed()
			end

			-- Fixed mode only prevents Lakitu from moving. The camera pos still updates, so
			-- Lakitu will fly to his next position as normal whenever R_TRIG is released.
			camera.gLakituState.posHSpeed = 0
			camera.gLakituState.posVSpeed = 0

			c.nextYaw = camera.calculate_yaw(camera.gLakituState.focus, camera.gLakituState.pos)
			c.yaw = c.nextYaw
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_FIX_IN_PLACE)))
		else
			-- Play the "click" sound when fixed mode is released
			if bit32.btest(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_FIXED_ACTIVE) then
				camera.play_sound_rbutton_changed()
				camera.sCameraSoundFlags = S16(bit32.band(camera.sCameraSoundFlags, bit32.bnot(GroupsTypesHPlus3.CAM_SOUND_FIXED_ACTIVE)))
			end
		end
	else
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_TRIG) and camera.cam_select_alt_mode(0) == GroupsTypesHPlus3.CAM_SELECTION_FIXED then
			camera.play_sound_button_change_blocked()
		end
	end

	camera.update_lakitu(c)

	camera.gLakituState.lastFrameAction = camera.sMarioCamState.action
end

-- from src/game/camera.c:reset_camera L3207-3278
function camera.reset_camera(c: GroupsTypesHPlus3.Camera)
	camera.gCamera = c
	camera.gCameraMovementFlags = 0
	camera.s2ndRotateFlags = 0
	camera.sStatusFlags = 0
	camera.gCutsceneTimer = 0
	camera.sCutsceneShot = 0
	camera.gCutsceneObjSpawn = 0
	camera.gObjCutsceneDone = IncludePRUltratypesH.FALSE
	camera.gCutsceneFocus = nil
	camera.unused8032CFC8 = 0
	camera.unused8032CFCC = 0
	camera.gSecondCameraFocus = nil
	camera.sCButtonsPressed = 0
	SrcEngineMathUtil.vec3f_copy(camera.sModeTransition.marioPos, camera.sMarioCamState.pos)
	camera.sModeTransition.framesLeft = 0
	camera.unused8032CFCC = -1
	camera.unused8032CFC8 = -1
	camera.gCameraMovementFlags = 0
	camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_INIT_CAMERA))
	camera.unused8033B316 = 0
	camera.sStatusFlags = 0
	camera.unused8033B31A = 0
	camera.sCameraSoundFlags = 0
	camera.sCUpCameraPitch = 0
	camera.sModeOffsetYaw = 0
	camera.sSpiralStairsYawOffset = 0
	camera.sLakituDist = 0
	camera.sLakituPitch = 0
	camera.sAreaYaw = 0
	camera.sAreaYawChange = 0
	camera.sPanDistance = 0
	camera.sCannonYOffset = 0
	camera.sZoomAmount = 0
	camera.sZeroZoomDist = 0
	camera.sBehindMarioSoundTimer = 0
	camera.sCSideButtonYaw = 0
	camera.s8DirModeBaseYaw = 0
	camera.s8DirModeYawOffset = 0
	c.doorStatus = GroupsTypesHPlus3.DOOR_DEFAULT
	camera.sMarioCamState.headRotation[1] = 0
	camera.sMarioCamState.headRotation[2] = 0
	camera.sLuigiCamState.headRotation[1] = 0
	camera.sLuigiCamState.headRotation[2] = 0
	camera.sMarioCamState.cameraEvent = 0
	camera.sMarioCamState.usedObj = nil
	camera.gLakituState.shakeMagnitude[1] = 0
	camera.gLakituState.shakeMagnitude[2] = 0
	camera.gLakituState.shakeMagnitude[3] = 0
	camera.gLakituState.unusedVec2[1] = 0
	camera.gLakituState.unusedVec2[2] = 0
	camera.gLakituState.unusedVec2[3] = 0
	camera.gLakituState.unusedVec1[1] = 0
	camera.gLakituState.unusedVec1[2] = 0
	camera.gLakituState.unusedVec1[3] = 0
	camera.gLakituState.lastFrameAction = 0
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	camera.sFOVState.fov = 45
	camera.sFOVState.fovOffset = 0
	camera.sFOVState.unusedIsSleeping = 0
	camera.sFOVState.shakeAmplitude = 0
	camera.sFOVState.shakePhase = 0
	camera.sObjectCutscene = 0
	camera.gRecentCutscene = 0
	camera.unused8033B30C = 0
	camera.unused8033B310 = 0
end

-- from src/game/camera.c:init_camera L3280-3437
function camera.init_camera(c: GroupsTypesHPlus3.Camera)
	camera.sCreditsPlayer2Pitch = 0
	camera.sCreditsPlayer2Yaw = 0
	camera.gPrevLevel = U32(TruncS32(camera.gCurrLevelArea / 16))
	camera.gCurrLevelArea = Area.gCurrLevelNum * 16 + (Area.gCurrentArea :: GroupsTypesHPlus3.Area).index
	camera.sSelectionFlags = S16(bit32.band(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED))
	camera.sFramesPaused = 0
	camera.gLakituState.mode = c.mode
	camera.gLakituState.defMode = c.defMode
	camera.gLakituState.posHSpeed = F32(0.3)
	camera.gLakituState.posVSpeed = F32(0.3)
	camera.gLakituState.focHSpeed = F32(0.8)
	camera.gLakituState.focHSpeed = F32(0.3) -- @bug set focHSpeed back-to-back
	camera.gLakituState.roll = 0
	camera.gLakituState.keyDanceRoll = 0
	camera.gLakituState.unused = 0
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	SrcEngineMathUtil.vec3f_set(camera.sCastleEntranceOffset, 0, 0, 0)
	SrcEngineMathUtil.vec3f_set(camera.sPlayer2FocusOffset, 0, 0, 0)
	camera.find_mario_floor_and_ceil(camera.sMarioGeometry)
	camera.sMarioGeometry.prevFloorHeight = camera.sMarioGeometry.currFloorHeight
	camera.sMarioGeometry.prevCeilHeight = camera.sMarioGeometry.currCeilHeight
	camera.sMarioGeometry.prevFloor = camera.sMarioGeometry.currFloor
	camera.sMarioGeometry.prevCeil = camera.sMarioGeometry.currCeil
	camera.sMarioGeometry.prevFloorType = camera.sMarioGeometry.currFloorType
	camera.sMarioGeometry.prevCeilType = camera.sMarioGeometry.currCeilType
	for i = 0, 31 do
		camera.sCurCreditsSplinePos[i + 1].index = -1
		camera.sCurCreditsSplineFocus[i + 1].index = -1
	end
	camera.sCutsceneSplineSegment = 0
	camera.sCutsceneSplineSegmentProgress = 0
	camera.unused8033B6E8 = 0
	camera.sHandheldShakeInc = 0
	camera.sHandheldShakeTimer = 0
	camera.sHandheldShakeMag = 0
	for i = 0, 3 do
		camera.sHandheldShakeSpline[i + 1].index = -1
	end
	camera.sHandheldShakePitch = 0
	camera.sHandheldShakeYaw = 0
	camera.sHandheldShakeRoll = 0
	c.cutscene = 0
	Scratch.init_camera_marioOffset[1] = 0
	Scratch.init_camera_marioOffset[2] = 125
	Scratch.init_camera_marioOffset[3] = 400

	-- Set the camera's starting position or start a cutscene for certain levels
	-- Calls the initial cutscene when you enter Bowser battle levels
	-- Note: This replaced an "old" way to call these cutscenes using
	-- a camEvent value: CAM_EVENT_BOWSER_INIT
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_1 then
		-- Since Bowser 1 has a demo entry, check for it
		-- If it is, then set CamAct to the end to directly activate Bowser
		-- If it isn't, then start cutscene
		if GameInit.gCurrDemoInput == nil then
			camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_ENTER_BOWSER_ARENA)
		elseif camera.gSecondCameraFocus ~= nil then
			buffer.writei32((camera.gSecondCameraFocus :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBowserCamAct, IncludeObjectConstantsH.BOWSER_CAM_ACT_END)
		end
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
		camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_ENTER_BOWSER_ARENA)
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_3 then
		camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_ENTER_BOWSER_ARENA)
	-- ! Hardcoded position checks determine which cutscene to play when Mario enters castle grounds.
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE_GROUNDS then
		if camera.is_within_100_units_of_mario(-1328, 260, 4664) ~= 1 then
			Scratch.init_camera_marioOffset[1] = -400
			Scratch.init_camera_marioOffset[3] = -800
		end
		if camera.is_within_100_units_of_mario(-6901, 2376, -6509) == 1 then
			camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_EXIT_WATERFALL)
		end
		if camera.is_within_100_units_of_mario(5408, 4500, 3637) == 1 then
			camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_EXIT_FALL_WMOTR)
		end
		camera.gLakituState.mode = GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SA then
		Scratch.init_camera_marioOffset[3] = 200
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE_COURTYARD then
		Scratch.init_camera_marioOffset[3] = -300
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_LLL then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE then
		Scratch.init_camera_marioOffset[3] = 150
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_RR then
		SrcEngineMathUtil.vec3f_set(camera.sFixedModeBasePosition, -2985, 478, -5568)
	end
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
	end
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_EYEROK then
		SrcEngineMathUtil.vec3f_set(Scratch.init_camera_marioOffset, 0, 500, -100)
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CCM_SLIDE then
		Scratch.init_camera_marioOffset[3] = -300
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_WIGGLER then
		Scratch.init_camera_marioOffset[3] = -300
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SL_IGLOO then
		Scratch.init_camera_marioOffset[3] = -300
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SL_OUTSIDE then
		if camera.is_within_100_units_of_mario(257, 2150, 1399) == 1 then
			Scratch.init_camera_marioOffset[3] = -300
		end
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CCM_OUTSIDE then
		camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTM_OUTSIDE then
		camera.gLakituState.mode = GroupsTypesHPlus3.CAMERA_MODE_RADIAL
	end

	-- Set the camera pos to marioOffset (relative to Mario), added to Mario's position
	camera.offset_rotated(c.pos, camera.sMarioCamState.pos, Scratch.init_camera_marioOffset, camera.sMarioCamState.faceAngle)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO then
		const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 100), camera.sMarioCamState.pos[3], Scratch.init_camera_floor)
		c.pos[2] = F32(floorHeight + 125)
	end
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.curPos, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.curFocus, c.focus)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalPos, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalFocus, c.focus)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.pos, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.gLakituState.focus, c.focus)
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.set_fixed_cam_axis_sa_lobby(c.mode)
	end
	camera.store_lakitu_cam_info_for_c_up(c)
	camera.gLakituState.yaw = camera.calculate_yaw(c.focus, c.pos)
	camera.gLakituState.nextYaw = camera.gLakituState.yaw
	c.yaw = camera.gLakituState.yaw
	c.nextYaw = camera.gLakituState.yaw
end

-- from src/game/camera.c:zoom_out_if_paused_and_outside L3453-3485
function camera.zoom_out_if_paused_and_outside(cameraNode: GroupsTypesHPlus3.GraphNodeCamera)
	local areaMaskIndex = TruncS32(camera.gCurrLevelArea / 32)
	local areaBit = S32(bit32.lshift(1, bit32.band(camera.gCurrLevelArea, 0x10) // 4 + bit32.band(bit32.band(camera.gCurrLevelArea, 0xF) - 1, 3)))

	if areaMaskIndex >= IncludeLevelTableH.LEVEL_MAX // 2 then
		areaMaskIndex = 0
		areaBit = 0
	end
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_PAUSE_SCREEN) then
		if camera.sFramesPaused >= 2 then
			if bit32.btest(camera.sZoomOutAreaMasks[areaMaskIndex + 1], areaBit) then
				cameraNode.focus[1] = (camera.gCamera :: GroupsTypesHPlus3.Camera).areaCenX
				cameraNode.focus[2] = F32(F32(camera.sMarioCamState.pos[2] + (camera.gCamera :: GroupsTypesHPlus3.Camera).areaCenY) / 2)
				cameraNode.focus[3] = (camera.gCamera :: GroupsTypesHPlus3.Camera).areaCenZ
				SrcEngineMathUtil.vec3f_get_dist_and_angle(cameraNode.focus, camera.sMarioCamState.pos, Scratch.zoom_out_if_paused_and_outside_dist, Scratch.zoom_out_if_paused_and_outside_pitch, Scratch.zoom_out_if_paused_and_outside_yaw)
				SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, cameraNode.pos, 6000, 0x1000, Scratch.zoom_out_if_paused_and_outside_yaw[1])
				if Area.gCurrLevelNum ~= IncludeLevelTableH.LEVEL_THI then
					camera.find_in_bounds_yaw_wdw_bob_thi(cameraNode.pos, cameraNode.focus, 0)
				end
			end
		else
			camera.sFramesPaused = U8(camera.sFramesPaused + 1)
		end
	else
		camera.sFramesPaused = 0
	end
end

-- from src/game/camera.c:select_mario_cam_mode L3487-3489
function camera.select_mario_cam_mode()
	camera.sSelectionFlags = GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED
end

-- from src/game/camera.c:create_camera L3494-3509
function camera.create_camera(gc: GroupsTypesHPlus3.GraphNodeCamera, pool: MemoryH.AllocOnlyPool)
	const mode = S16(gc.config.mode)
	const c = GroupsTypesHPlus3.new_Camera()

	gc.config.camera = c
	c.mode = U8(mode)
	c.defMode = U8(mode)
	c.cutscene = 0
	c.doorStatus = GroupsTypesHPlus3.DOOR_DEFAULT
	c.areaCenX = gc.focus[1]
	c.areaCenY = gc.focus[2]
	c.areaCenZ = gc.focus[3]
	c.yaw = 0
	SrcEngineMathUtil.vec3f_copy(c.pos, gc.pos)
	SrcEngineMathUtil.vec3f_copy(c.focus, gc.focus)
end

-- from src/game/camera.c:update_graph_node_camera L3514-3522
function camera.update_graph_node_camera(gc: GroupsTypesHPlus3.GraphNodeCamera)
	gc.rollScreen = camera.gLakituState.roll
	SrcEngineMathUtil.vec3f_copy(gc.pos, camera.gLakituState.pos)
	SrcEngineMathUtil.vec3f_copy(gc.focus, camera.gLakituState.focus)
	camera.zoom_out_if_paused_and_outside(gc)
end

-- from src/game/camera.c:geo_camera_main L3524-3537
function camera.geo_camera_main(callContext: number, g: GroupsTypesHPlus3.GraphNode, context: unknown): { unknown }?
	const gc = g :: GroupsTypesHPlus3.GraphNodeCamera

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_CREATE then
		camera.create_camera(gc, context :: MemoryH.AllocOnlyPool)
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		camera.update_graph_node_camera(gc)
	end
	return nil
end

-- from src/game/camera.c:stub_camera_2 L3539-3540
function camera.stub_camera_2(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:stub_camera_3 L3542-3543
function camera.stub_camera_3(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:vec3f_sub L3545-3549
function camera.vec3f_sub(dst: { number }, src: { number })
	dst[1] = F32(dst[1] - src[1])
	dst[2] = F32(dst[2] - src[2])
	dst[3] = F32(dst[3] - src[3])
end

-- from src/game/camera.c:object_pos_to_vec3f L3551-3555
function camera.object_pos_to_vec3f(dst: { number }, o: GroupsTypesHPlus3.Object)
	dst[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	dst[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	dst[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
end

-- from src/game/camera.c:vec3f_to_object_pos L3557-3561
function camera.vec3f_to_object_pos(o: GroupsTypesHPlus3.Object, src: { number })
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, src[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, src[2])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, src[3])
end

-- from src/game/camera.c:unused_object_angle_to_vec3s L3563-3567
function camera.unused_object_angle_to_vec3s(dst: { number }, o: GroupsTypesHPlus3.Object)
	dst[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	dst[2] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	dst[3] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll))
end

-- from src/game/camera.c:evaluate_cubic_spline L3576-3608
function camera.evaluate_cubic_spline(u: number, Q: { number }, a0: { number }, a1: { number }, a2: { number }, a3: { number })
	u = F32(u)
	local B0: number
	local B1: number
	local B2: number
	local B3: number

	if u > 1 then
		u = 1
	end

	B0 = F32(F32(F32(F32(1 - u) * F32(1 - u)) * F32(1 - u)) / 6)
	B1 = F32(F32(F32(F32(F32(u * u) * u) / 2) - F32(u * u)) + F32(0.6666667))
	B2 = F32(F32(F32(F32(F32(F32(-u * u) * u) / 2) + F32(F32(u * u) / 2)) + F32(u / 2)) + F32(0.16666667))
	B3 = F32(F32(F32(u * u) * u) / 6)

	Q[1] = F32(F32(F32(F32(B0 * a0[1]) + F32(B1 * a1[1])) + F32(B2 * a2[1])) + F32(B3 * a3[1]))
	Q[2] = F32(F32(F32(F32(B0 * a0[2]) + F32(B1 * a1[2])) + F32(B2 * a2[2])) + F32(B3 * a3[2]))
	Q[3] = F32(F32(F32(F32(B0 * a0[3]) + F32(B1 * a1[3])) + F32(B2 * a2[3])) + F32(B3 * a3[3]))

	-- Unused code
	B0 = F32(F32(F32(F32(-0.5 * u) * u) + u) - F32(0.33333333))
	B1 = F32(F32(F32(F32(1.5 * u) * u) - F32(2 * u)) - 0.5)
	B2 = F32(F32(F32(F32(-1.5 * u) * u) + u) + 1)
	B3 = F32(F32(F32(F32(0.5 * u) * u)) - F32(0.16666667))

	const x = F32(F32(F32(F32(B0 * a0[1]) + F32(B1 * a1[1])) + F32(B2 * a2[1])) + F32(B3 * a3[1]))
	const y = F32(F32(F32(F32(B0 * a0[2]) + F32(B1 * a1[2])) + F32(B2 * a2[2])) + F32(B3 * a3[2]))
	const z = F32(F32(F32(F32(B0 * a0[3]) + F32(B1 * a1[3])) + F32(B2 * a2[3])) + F32(B3 * a3[3]))

	camera.unusedSplinePitch = SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(x * x) + F32(z * z)))), y)
	camera.unusedSplineYaw = SrcEngineMathUtil.atan2s(z, x)
end

-- from src/game/camera.c:move_point_along_spline L3631-3685
function camera.move_point_along_spline(p: { number }, spline: { GroupsTypesHPlus3.CutsceneSplinePoint }, splineSegment: { number }, progress: { number }): number
	local finished = 0
	local u = progress[1]
	local firstSpeed = 0
	local secondSpeed = 0
	local segment = splineSegment[1]

	if splineSegment[1] < 0 then
		segment = 0
		u = 0
	end
	if spline[segment + 1].index == -1 or spline[segment + 2].index == -1 or spline[segment + 3].index == -1 then
		return 1
	end

	for i = 0, 3 do
		Scratch.move_point_along_spline_controlPoints[i + 1][1] = spline[segment + i + 1].point[1]
		Scratch.move_point_along_spline_controlPoints[i + 1][2] = spline[segment + i + 1].point[2]
		Scratch.move_point_along_spline_controlPoints[i + 1][3] = spline[segment + i + 1].point[3]
	end
	camera.evaluate_cubic_spline(u, p, Scratch.move_point_along_spline_controlPoints[1], Scratch.move_point_along_spline_controlPoints[2], Scratch.move_point_along_spline_controlPoints[3], Scratch.move_point_along_spline_controlPoints[4])

	if spline[splineSegment[1] + 2].speed ~= 0 then
		firstSpeed = F32(1 / spline[splineSegment[1] + 2].speed)
	end
	if spline[splineSegment[1] + 3].speed ~= 0 then
		secondSpeed = F32(1 / spline[splineSegment[1] + 3].speed)
	end
	const progressChange = F32(F32(F32(secondSpeed - firstSpeed) * progress[1]) + firstSpeed)

	progress[1] = F32(progress[1] + progressChange)
	if 1 <= progress[1] then
		splineSegment[1] = S16(splineSegment[1] + 1)
		if spline[splineSegment[1] + 4].index == -1 then
			splineSegment[1] = 0
			finished = 1
		end
		progress[1] = F32(progress[1] - 1)
	end
	return finished
end

-- from src/game/camera.c:cam_select_alt_mode L3694-3716
function camera.cam_select_alt_mode(selection: number): number
	local mode = GroupsTypesHPlus3.CAM_SELECTION_FIXED

	if selection == GroupsTypesHPlus3.CAM_SELECTION_MARIO then
		if not bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED) then
			camera.sSelectionFlags = S16(bit32.bor(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED))
		end
		camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_UNUSED_SELECT_MARIO))
	end

	-- The alternate mode is up-close, but the player just selected fixed in the pause menu
	if selection == GroupsTypesHPlus3.CAM_SELECTION_FIXED and bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED) then
		-- So change to normal mode in case the user paused in up-close mode
		camera.set_cam_angle(GroupsTypesHPlus3.CAM_ANGLE_LAKITU)
		camera.sSelectionFlags = S16(bit32.band(camera.sSelectionFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED)))
		camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_UNUSED_SELECT_FIXED))
	end

	if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_SELECTED) then
		mode = GroupsTypesHPlus3.CAM_SELECTION_MARIO
	end
	return mode
end

-- from src/game/camera.c:set_cam_angle L3725-3753
function camera.set_cam_angle(mode: number): number
	local curMode = GroupsTypesHPlus3.CAM_ANGLE_LAKITU

	-- Switch to Mario mode
	if mode == GroupsTypesHPlus3.CAM_ANGLE_MARIO and not bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		camera.sSelectionFlags = S16(bit32.bor(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE))
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
			camera.sSelectionFlags = S16(bit32.bor(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_LAKITU_WAS_ZOOMED_OUT))
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT)))
		end
		camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_MARIO_ACTIVE))
	end

	-- Switch back to normal mode
	if mode == GroupsTypesHPlus3.CAM_ANGLE_LAKITU and bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		camera.sSelectionFlags = S16(bit32.band(camera.sSelectionFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE)))
		if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_LAKITU_WAS_ZOOMED_OUT) then
			camera.sSelectionFlags = S16(bit32.band(camera.sSelectionFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MODE_LAKITU_WAS_ZOOMED_OUT)))
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
		else
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT)))
		end
		camera.sCameraSoundFlags = S16(bit32.bor(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_NORMAL_ACTIVE))
	end
	if bit32.btest(camera.sSelectionFlags, GroupsTypesHPlus3.CAM_MODE_MARIO_ACTIVE) then
		curMode = GroupsTypesHPlus3.CAM_ANGLE_MARIO
	end
	return curMode
end

-- from src/game/camera.c:set_handheld_shake L3760-3791
function camera.set_handheld_shake(mode: number)
	mode = U8(TruncS32(mode))
	-- They're not in numerical order because that would be too simple...
	if mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE then -- Lowest increment
		camera.sHandheldShakeMag = 0x600
		camera.sHandheldShakeInc = F32(0.04)
	elseif mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_LOW then -- Lowest magnitude
		camera.sHandheldShakeMag = 0x300
		camera.sHandheldShakeInc = F32(0.06)
	elseif mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_HIGH then -- Highest mag and inc
		camera.sHandheldShakeMag = 0x1000
		camera.sHandheldShakeInc = F32(0.1)
	elseif mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_UNUSED then -- Never used
		camera.sHandheldShakeMag = 0x600
		camera.sHandheldShakeInc = F32(0.07)
	elseif mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_HANG_OWL then -- exactly the same as UNUSED...
		camera.sHandheldShakeMag = 0x600
		camera.sHandheldShakeInc = F32(0.07)
	elseif mode == GroupsTypesHPlus3.HAND_CAM_SHAKE_STAR_DANCE then -- Slightly steadier than HANG_OWL and UNUSED
		camera.sHandheldShakeMag = 0x400
		camera.sHandheldShakeInc = F32(0.07)
	else
		camera.sHandheldShakeMag = 0x0
		camera.sHandheldShakeInc = 0
	end
end

-- from src/game/camera.c:shake_camera_handheld L3800-3850
function camera.shake_camera_handheld(pos: { number }, focus: { number })
	if camera.sHandheldShakeMag == 0 then
		SrcEngineMathUtil.vec3f_set(Scratch.shake_camera_handheld_shakeOffset, 0, 0, 0)
	else
		for i = 0, 3 do
			Scratch.shake_camera_handheld_shakeSpline[i + 1][1] = camera.sHandheldShakeSpline[i + 1].point[1]
			Scratch.shake_camera_handheld_shakeSpline[i + 1][2] = camera.sHandheldShakeSpline[i + 1].point[2]
			Scratch.shake_camera_handheld_shakeSpline[i + 1][3] = camera.sHandheldShakeSpline[i + 1].point[3]
		end
		camera.evaluate_cubic_spline(camera.sHandheldShakeTimer, Scratch.shake_camera_handheld_shakeOffset, Scratch.shake_camera_handheld_shakeSpline[1], Scratch.shake_camera_handheld_shakeSpline[2], Scratch.shake_camera_handheld_shakeSpline[3], Scratch.shake_camera_handheld_shakeSpline[4])
		camera.sHandheldShakeTimer = F32(camera.sHandheldShakeTimer + camera.sHandheldShakeInc)
		if 1 <= camera.sHandheldShakeTimer then
			-- The first 3 control points are always (0,0,0), so the random spline is always just a
			-- straight line
			for i = 0, 2 do
				SrcEngineMathUtil.vec3s_copy(camera.sHandheldShakeSpline[i + 1].point, camera.sHandheldShakeSpline[i + 2].point)
			end
			camera.random_vec3s(camera.sHandheldShakeSpline[4].point, camera.sHandheldShakeMag, camera.sHandheldShakeMag, S16(math.modf(camera.sHandheldShakeMag / 2)))
			camera.sHandheldShakeTimer = F32(camera.sHandheldShakeTimer - 1)

			-- Code dead, this is set to be 0 before it is used.
			camera.sHandheldShakeInc = F32(SrcEngineBehaviorScript.random_float() * 0.5)
			if camera.sHandheldShakeInc < F32(0.02) then
				camera.sHandheldShakeInc = F32(0.02)
			end
		end
	end

	Scratch.shake_camera_handheld_ref[1] = camera.sHandheldShakePitch
	camera.approach_s16_asymptotic_bool(Scratch.shake_camera_handheld_ref, S16(TruncS32(Scratch.shake_camera_handheld_shakeOffset[1])), 0x08)
	camera.sHandheldShakePitch = Scratch.shake_camera_handheld_ref[1]
	Scratch.shake_camera_handheld_ref[1] = camera.sHandheldShakeYaw
	camera.approach_s16_asymptotic_bool(Scratch.shake_camera_handheld_ref, S16(TruncS32(Scratch.shake_camera_handheld_shakeOffset[2])), 0x08)
	camera.sHandheldShakeYaw = Scratch.shake_camera_handheld_ref[1]
	Scratch.shake_camera_handheld_ref[1] = camera.sHandheldShakeRoll
	camera.approach_s16_asymptotic_bool(Scratch.shake_camera_handheld_ref, S16(TruncS32(Scratch.shake_camera_handheld_shakeOffset[3])), 0x08)
	camera.sHandheldShakeRoll = Scratch.shake_camera_handheld_ref[1]

	if bit32.bor(camera.sHandheldShakePitch, camera.sHandheldShakeYaw) ~= 0 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(pos, focus, Scratch.shake_camera_handheld_dist, Scratch.shake_camera_handheld_pitch, Scratch.shake_camera_handheld_yaw)
		Scratch.shake_camera_handheld_pitch[1] = S16(Scratch.shake_camera_handheld_pitch[1] + camera.sHandheldShakePitch)
		Scratch.shake_camera_handheld_yaw[1] = S16(Scratch.shake_camera_handheld_yaw[1] + camera.sHandheldShakeYaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(pos, focus, Scratch.shake_camera_handheld_dist[1], Scratch.shake_camera_handheld_pitch[1], Scratch.shake_camera_handheld_yaw[1])
	end

	-- Unless called every frame, the effect will stop after the first time.
	camera.sHandheldShakeMag = 0
	camera.sHandheldShakeInc = 0
end

-- from src/game/camera.c:find_c_buttons_pressed L3855-3892
function camera.find_c_buttons_pressed(currentState: number, buttonsPressed: number, buttonsDown: number): number
	currentState = U16(TruncS32(currentState))
	buttonsPressed = U16(TruncS32(buttonsPressed))
	buttonsDown = U16(TruncS32(buttonsDown))
	buttonsPressed = U16(bit32.band(buttonsPressed, camera.CBUTTON_MASK))
	buttonsDown = U16(bit32.band(buttonsDown, camera.CBUTTON_MASK))

	if bit32.btest(buttonsPressed, IncludePROsH.L_CBUTTONS) then
		currentState = U16(bit32.bor(currentState, IncludePROsH.L_CBUTTONS))
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.R_CBUTTONS)))
	end
	if not bit32.btest(buttonsDown, IncludePROsH.L_CBUTTONS) then
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.L_CBUTTONS)))
	end

	if bit32.btest(buttonsPressed, IncludePROsH.R_CBUTTONS) then
		currentState = U16(bit32.bor(currentState, IncludePROsH.R_CBUTTONS))
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.L_CBUTTONS)))
	end
	if not bit32.btest(buttonsDown, IncludePROsH.R_CBUTTONS) then
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.R_CBUTTONS)))
	end

	if bit32.btest(buttonsPressed, IncludePROsH.U_CBUTTONS) then
		currentState = U16(bit32.bor(currentState, IncludePROsH.U_CBUTTONS))
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.D_CBUTTONS)))
	end
	if not bit32.btest(buttonsDown, IncludePROsH.U_CBUTTONS) then
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.U_CBUTTONS)))
	end

	if bit32.btest(buttonsPressed, IncludePROsH.D_CBUTTONS) then
		currentState = U16(bit32.bor(currentState, IncludePROsH.D_CBUTTONS))
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.U_CBUTTONS)))
	end
	if not bit32.btest(buttonsDown, IncludePROsH.D_CBUTTONS) then
		currentState = U16(bit32.band(currentState, bit32.bnot(IncludePROsH.D_CBUTTONS)))
	end

	return currentState
end

-- from src/game/camera.c:update_camera_hud_status L3897-3916
function camera.update_camera_hud_status(c: GroupsTypesHPlus3.Camera): number
	local status = GroupsTypesHPlus3.CAM_STATUS_NONE

	if c.cutscene ~= 0 or (bit32.btest(GameInit.gPlayer1Controller.buttonDown, IncludePROsH.R_TRIG) and camera.cam_select_alt_mode(0) == GroupsTypesHPlus3.CAM_SELECTION_FIXED) then
		status = S16(bit32.bor(status, GroupsTypesHPlus3.CAM_STATUS_FIXED))
	elseif camera.set_cam_angle(0) == GroupsTypesHPlus3.CAM_ANGLE_MARIO then
		status = S16(bit32.bor(status, GroupsTypesHPlus3.CAM_STATUS_MARIO))
	else
		status = S16(bit32.bor(status, GroupsTypesHPlus3.CAM_STATUS_LAKITU))
	end
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
		status = S16(bit32.bor(status, GroupsTypesHPlus3.CAM_STATUS_C_DOWN))
	end
	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE) then
		status = S16(bit32.bor(status, GroupsTypesHPlus3.CAM_STATUS_C_UP))
	end
	Registry.Members.src__game__hud.set_hud_camera_status(status)
	return status
end

-- from src/game/camera.c:collide_with_walls L3923-3960
function camera.collide_with_walls(pos: { number }, offsetY: number, radius: number): number
	offsetY = F32(offsetY)
	radius = F32(radius)
	Scratch.collide_with_walls_collisionData.x = pos[1]
	Scratch.collide_with_walls_collisionData.y = pos[2]
	Scratch.collide_with_walls_collisionData.z = pos[3]
	Scratch.collide_with_walls_collisionData.radius = radius
	Scratch.collide_with_walls_collisionData.offsetY = offsetY
	const numCollisions: number = Registry.Members.src__engine__surface_collision.find_wall_collisions(Scratch.collide_with_walls_collisionData)
	if numCollisions ~= 0 then
		for i = 0, Scratch.collide_with_walls_collisionData.numWalls - 1 do
			const wall = Scratch.collide_with_walls_collisionData.walls[Scratch.collide_with_walls_collisionData.numWalls] :: GroupsTypesHPlus3.Surface
			SrcEngineMathUtil.vec3f_copy(Scratch.collide_with_walls_newPos[i + 1], pos)
			const normX = wall.normal.x
			const normY = wall.normal.y
			const normZ = wall.normal.z
			const originOffset = wall.originOffset
			const offset = F32(F32(F32(F32(normX * Scratch.collide_with_walls_newPos[i + 1][1]) + F32(normY * Scratch.collide_with_walls_newPos[i + 1][2])) + F32(normZ * Scratch.collide_with_walls_newPos[i + 1][3])) + originOffset)
			const offsetAbsolute = GroupsTypesHPlus3.ABS2(offset)
			if offsetAbsolute < radius then
				Scratch.collide_with_walls_newPos[i + 1][1] = F32(Scratch.collide_with_walls_newPos[i + 1][1] + F32(normX * F32(radius - offset)))
				Scratch.collide_with_walls_newPos[i + 1][3] = F32(Scratch.collide_with_walls_newPos[i + 1][3] + F32(normZ * F32(radius - offset)))
				SrcEngineMathUtil.vec3f_copy(pos, Scratch.collide_with_walls_newPos[i + 1])
			end
		end
	end
	return numCollisions
end

-- from src/game/camera.c:vec3f_compare L3965-3972
function camera.vec3f_compare(pos: { number }, posX: number, posY: number, posZ: number): number
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	local equal = IncludePRUltratypesH.FALSE

	if pos[1] == posX and pos[2] == posY and pos[3] == posZ then
		equal = IncludePRUltratypesH.TRUE
	end
	return equal
end

-- from src/game/camera.c:clamp_pitch L3974-3991
function camera.clamp_pitch(from: { number }, to: { number }, maxPitch: number, minPitch: number): number
	maxPitch = S16(TruncS32(maxPitch))
	minPitch = S16(TruncS32(minPitch))
	local outOfRange = 0

	SrcEngineMathUtil.vec3f_get_dist_and_angle(from, to, Scratch.clamp_pitch_dist, Scratch.clamp_pitch_pitch, Scratch.clamp_pitch_yaw)
	if Scratch.clamp_pitch_pitch[1] > maxPitch then
		Scratch.clamp_pitch_pitch[1] = maxPitch
		outOfRange += 1
	end
	if Scratch.clamp_pitch_pitch[1] < minPitch then
		Scratch.clamp_pitch_pitch[1] = minPitch
		outOfRange += 1
	end
	SrcEngineMathUtil.vec3f_set_dist_and_angle(from, to, Scratch.clamp_pitch_dist[1], Scratch.clamp_pitch_pitch[1], Scratch.clamp_pitch_yaw[1])
	return outOfRange
end

-- from src/game/camera.c:is_within_100_units_of_mario L3993-4002
function camera.is_within_100_units_of_mario(posX: number, posY: number, posZ: number): number
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	local isCloseToMario = 0

	SrcEngineMathUtil.vec3f_set(Scratch.is_within_100_units_of_mario_pos, posX, posY, posZ)
	if camera.calc_abs_dist(camera.sMarioCamState.pos, Scratch.is_within_100_units_of_mario_pos) < 100 then
		isCloseToMario = 1
	end
	return isCloseToMario
end

-- from src/game/camera.c:set_or_approach_f32_asymptotic L4004-4015
function camera.set_or_approach_f32_asymptotic(dst: { number }, goal: number, scale: number): number
	goal = F32(goal)
	scale = F32(scale)
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT) then
		camera.approach_f32_asymptotic_bool(dst, goal, scale)
	else
		dst[1] = goal
	end
	if dst[1] == goal then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:approach_f32_asymptotic_bool L4022-4032
function camera.approach_f32_asymptotic_bool(current: { number }, target: number, multiplier: number): number
	target = F32(target)
	multiplier = F32(multiplier)
	if multiplier > 1 then
		multiplier = 1
	end
	current[1] = F32(current[1] + F32(F32(target - current[1]) * multiplier))
	if current[1] == target then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:approach_f32_asymptotic L4037-4040
function camera.approach_f32_asymptotic(current: number, target: number, multiplier: number): number
	current = F32(current)
	target = F32(target)
	multiplier = F32(multiplier)
	current = F32(current + F32(F32(target - current) * multiplier))
	return current
end

-- from src/game/camera.c:approach_s16_asymptotic_bool L4047-4063
function camera.approach_s16_asymptotic_bool(current: { number }, target: number, divisor: number): number
	target = S16(TruncS32(target))
	divisor = S16(TruncS32(divisor))
	local temp = current[1]

	if divisor == 0 then
		current[1] = target
	else
		temp = S16(temp - target)
		temp = S16(temp - (math.modf(temp / divisor)))
		temp = S16(temp + target)
		current[1] = temp
	end
	if current[1] == target then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:approach_s16_asymptotic L4069-4081
function camera.approach_s16_asymptotic(current: number, target: number, divisor: number): number
	current = S16(TruncS32(current))
	target = S16(TruncS32(target))
	divisor = S16(TruncS32(divisor))
	local temp = current

	if divisor == 0 then
		current = target
	else
		temp = S16(temp - target)
		temp = S16(temp - (math.modf(temp / divisor)))
		temp = S16(temp + target)
		current = temp
	end
	return current
end

-- from src/game/camera.c:approach_vec3f_asymptotic L4087-4091
function camera.approach_vec3f_asymptotic(current: { number }, target: { number }, xMul: number, yMul: number, zMul: number)
	xMul = F32(xMul)
	yMul = F32(yMul)
	zMul = F32(zMul)
	Scratch.approach_vec3f_asymptotic_current[1] = current[1]
	camera.approach_f32_asymptotic_bool(Scratch.approach_vec3f_asymptotic_current, target[1], xMul)
	current[1] = Scratch.approach_vec3f_asymptotic_current[1]

	Scratch.approach_vec3f_asymptotic_current[1] = current[2]
	camera.approach_f32_asymptotic_bool(Scratch.approach_vec3f_asymptotic_current, target[2], yMul)
	current[2] = Scratch.approach_vec3f_asymptotic_current[1]

	Scratch.approach_vec3f_asymptotic_current[1] = current[3]
	camera.approach_f32_asymptotic_bool(Scratch.approach_vec3f_asymptotic_current, target[3], zMul)
	current[3] = Scratch.approach_vec3f_asymptotic_current[1]
end

-- from src/game/camera.c:set_or_approach_vec3f_asymptotic L4097-4101
function camera.set_or_approach_vec3f_asymptotic(dst: { number }, goal: { number }, xMul: number, yMul: number, zMul: number)
	xMul = F32(xMul)
	yMul = F32(yMul)
	zMul = F32(zMul)
	Scratch.set_or_approach_vec3f_asymptotic_ref[1] = dst[1]
	camera.set_or_approach_f32_asymptotic(Scratch.set_or_approach_vec3f_asymptotic_ref, goal[1], xMul)
	dst[1] = Scratch.set_or_approach_vec3f_asymptotic_ref[1]
	Scratch.set_or_approach_vec3f_asymptotic_ref[1] = dst[2]
	camera.set_or_approach_f32_asymptotic(Scratch.set_or_approach_vec3f_asymptotic_ref, goal[2], yMul)
	dst[2] = Scratch.set_or_approach_vec3f_asymptotic_ref[1]
	Scratch.set_or_approach_vec3f_asymptotic_ref[1] = dst[3]
	camera.set_or_approach_f32_asymptotic(Scratch.set_or_approach_vec3f_asymptotic_ref, goal[3], zMul)
	dst[3] = Scratch.set_or_approach_vec3f_asymptotic_ref[1]
end

-- from src/game/camera.c:approach_vec3s_asymptotic L4107-4111
function camera.approach_vec3s_asymptotic(current: { number }, target: { number }, xMul: number, yMul: number, zMul: number)
	xMul = S16(TruncS32(xMul))
	yMul = S16(TruncS32(yMul))
	zMul = S16(TruncS32(zMul))
	Scratch.approach_vec3s_asymptotic_current[1] = current[1]
	camera.approach_s16_asymptotic_bool(Scratch.approach_vec3s_asymptotic_current, target[1], xMul)
	current[1] = Scratch.approach_vec3s_asymptotic_current[1]

	Scratch.approach_vec3s_asymptotic_current[1] = current[2]
	camera.approach_s16_asymptotic_bool(Scratch.approach_vec3s_asymptotic_current, target[2], yMul)
	current[2] = Scratch.approach_vec3s_asymptotic_current[1]

	Scratch.approach_vec3s_asymptotic_current[1] = current[3]
	camera.approach_s16_asymptotic_bool(Scratch.approach_vec3s_asymptotic_current, target[3], zMul)
	current[3] = Scratch.approach_vec3s_asymptotic_current[1]
end

-- from src/game/camera.c:camera_approach_s16_symmetric_bool L4113-4139
function camera.camera_approach_s16_symmetric_bool(current: { number }, target: number, increment: number): number
	target = S16(TruncS32(target))
	increment = S16(TruncS32(increment))
	local dist = S16(target - current[1])

	if increment < 0 then
		increment = S16(-1 * increment)
	end
	if dist > 0 then
		dist = S16(dist - increment)
		if dist >= 0 then
			current[1] = S16(target - dist)
		else
			current[1] = target
		end
	else
		dist = S16(dist + increment)
		if dist <= 0 then
			current[1] = S16(target - dist)
		else
			current[1] = target
		end
	end
	if current[1] == target then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:camera_approach_s16_symmetric L4141-4163
function camera.camera_approach_s16_symmetric(current: number, target: number, increment: number): number
	current = S16(TruncS32(current))
	target = S16(TruncS32(target))
	increment = S16(TruncS32(increment))
	local dist = S16(target - current)

	if increment < 0 then
		increment = S16(-1 * increment)
	end
	if dist > 0 then
		dist = S16(dist - increment)
		if dist >= 0 then
			current = S16(target - dist)
		else
			current = target
		end
	else
		dist = S16(dist + increment)
		if dist <= 0 then
			current = S16(target - dist)
		else
			current = target
		end
	end
	return current
end

-- from src/game/camera.c:set_or_approach_s16_symmetric L4165-4176
function camera.set_or_approach_s16_symmetric(current: { number }, target: number, increment: number): number
	target = S16(TruncS32(target))
	increment = S16(TruncS32(increment))
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT) then
		camera.camera_approach_s16_symmetric_bool(current, target, increment)
	else
		current[1] = target
	end
	if current[1] == target then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:camera_approach_f32_symmetric_bool L4183-4209
function camera.camera_approach_f32_symmetric_bool(current: { number }, target: number, increment: number): number
	target = F32(target)
	increment = F32(increment)
	local dist = F32(target - current[1])

	if increment < 0 then
		increment = F32(-1 * increment)
	end
	if dist > 0 then
		dist = F32(dist - increment)
		if dist > 0 then
			current[1] = F32(target - dist)
		else
			current[1] = target
		end
	else
		dist = F32(dist + increment)
		if dist < 0 then
			current[1] = F32(target - dist)
		else
			current[1] = target
		end
	end
	if current[1] == target then
		return IncludePRUltratypesH.FALSE
	else
		return IncludePRUltratypesH.TRUE
	end
end

-- from src/game/camera.c:camera_approach_f32_symmetric L4214-4236
function camera.camera_approach_f32_symmetric(current: number, target: number, increment: number): number
	current = F32(current)
	target = F32(target)
	increment = F32(increment)
	local dist = F32(target - current)

	if increment < 0 then
		increment = F32(-1 * increment)
	end
	if dist > 0 then
		dist = F32(dist - increment)
		if dist > 0 then
			current = F32(target - dist)
		else
			current = target
		end
	else
		dist = F32(dist + increment)
		if dist < 0 then
			current = F32(target - dist)
		else
			current = target
		end
	end
	return current
end

-- from src/game/camera.c:random_vec3s L4242-4260
function camera.random_vec3s(dst: { number }, xRange: number, yRange: number, zRange: number)
	xRange = S16(TruncS32(xRange))
	yRange = S16(TruncS32(yRange))
	zRange = S16(TruncS32(zRange))
	local randomFloat = SrcEngineBehaviorScript.random_float()
	const tempXRange = xRange
	local tempYRange: number
	local tempZRange: number

	dst[1] = S16(TruncS32(F32(F32(randomFloat * tempXRange) - F32(tempXRange / 2))))

	randomFloat = SrcEngineBehaviorScript.random_float()
	tempYRange = yRange
	dst[2] = S16(TruncS32(F32(F32(randomFloat * tempYRange) - F32(tempYRange / 2))))

	randomFloat = SrcEngineBehaviorScript.random_float()
	tempZRange = zRange
	dst[3] = S16(TruncS32(F32(F32(randomFloat * tempZRange) - F32(tempZRange / 2))))
end

-- from src/game/camera.c:reduce_by_dist_from_camera L4268-4307
function camera.reduce_by_dist_from_camera(value: number, maxDist: number, posX: number, posY: number, posZ: number): number
	value = S16(TruncS32(value))
	maxDist = F32(maxDist)
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	local result = 0
	-- Direction from pos to (Lakitu's) goalPos
	const goalDX = F32(camera.gLakituState.goalPos[1] - posX)
	const goalDY = F32(camera.gLakituState.goalPos[2] - posY)
	const goalDZ = F32(camera.gLakituState.goalPos[3] - posZ)

	Scratch.reduce_by_dist_from_camera_dist[1] = F32(math.sqrt(F32(F32(F32(goalDX * goalDX) + F32(goalDY * goalDY)) + F32(goalDZ * goalDZ))))
	if maxDist > Scratch.reduce_by_dist_from_camera_dist[1] then
		Scratch.reduce_by_dist_from_camera_pos[1] = posX
		Scratch.reduce_by_dist_from_camera_pos[2] = posY
		Scratch.reduce_by_dist_from_camera_pos[3] = posZ
		SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.gLakituState.goalPos, Scratch.reduce_by_dist_from_camera_pos, Scratch.reduce_by_dist_from_camera_dist, Scratch.reduce_by_dist_from_camera_pitch, Scratch.reduce_by_dist_from_camera_yaw)
		if Scratch.reduce_by_dist_from_camera_dist[1] < maxDist then
			camera.calculate_angles(camera.gLakituState.goalPos, camera.gLakituState.goalFocus, Scratch.reduce_by_dist_from_camera_goalPitch, Scratch.reduce_by_dist_from_camera_goalYaw)
			-- ! Must be same line to match on -O2
			Scratch.reduce_by_dist_from_camera_pitch[1] = S16(Scratch.reduce_by_dist_from_camera_pitch[1] - Scratch.reduce_by_dist_from_camera_goalPitch[1])
			Scratch.reduce_by_dist_from_camera_yaw[1] = S16(Scratch.reduce_by_dist_from_camera_yaw[1] - Scratch.reduce_by_dist_from_camera_goalYaw[1])
			Scratch.reduce_by_dist_from_camera_dist[1] = F32(Scratch.reduce_by_dist_from_camera_dist[1] - 2000)
			if Scratch.reduce_by_dist_from_camera_dist[1] < 0 then
				Scratch.reduce_by_dist_from_camera_dist[1] = 0
			end
			maxDist = F32(maxDist - 2000)
			if maxDist < 2000 then
				maxDist = 2000
			end
			result = S16(TruncS32(F32(value * F32(1 - F32(Scratch.reduce_by_dist_from_camera_dist[1] / maxDist)))))
			if Scratch.reduce_by_dist_from_camera_pitch[1] < -0x1800 or Scratch.reduce_by_dist_from_camera_pitch[1] > 0x400 or Scratch.reduce_by_dist_from_camera_yaw[1] < -0x1800 or Scratch.reduce_by_dist_from_camera_yaw[1] > 0x1800 then
				result = S16(TruncS32(result / 2))
			end
		end
	end
	return result
end

-- from src/game/camera.c:clamp_positions_and_find_yaw L4309-4326
function camera.clamp_positions_and_find_yaw(pos: { number }, origin: { number }, xMax: number, xMin: number, zMax: number, zMin: number): number
	xMax = F32(xMax)
	xMin = F32(xMin)
	zMax = F32(zMax)
	zMin = F32(zMin)
	local yaw = (camera.gCamera :: GroupsTypesHPlus3.Camera).nextYaw

	if pos[1] >= xMax then
		pos[1] = xMax
	end
	if pos[1] <= xMin then
		pos[1] = xMin
	end
	if pos[3] >= zMax then
		pos[3] = zMax
	end
	if pos[3] <= zMin then
		pos[3] = zMin
	end
	yaw = camera.calculate_yaw(origin, pos)
	return yaw
end

-- from src/game/camera.c:calc_avoid_yaw L4338-4355
function camera.calc_avoid_yaw(yawFromMario: number, wallYaw: number): number
	yawFromMario = S16(TruncS32(yawFromMario))
	wallYaw = S16(TruncS32(wallYaw))
	const yawDiff = S16(wallYaw - yawFromMario + GroupsTypesHPlus3.DEGREES(90))

	if yawDiff < 0 then
		-- Deflect to the right
		yawFromMario = wallYaw
	else
		-- Note: this favors the left side if the wall is exactly perpendicular to the camera.
		-- Deflect to the left
		yawFromMario = S16(wallYaw + GroupsTypesHPlus3.DEGREES(180))
	end
	return yawFromMario
end

-- from src/game/camera.c:is_surf_within_bounding_box L4365-4423
function camera.is_surf_within_bounding_box(surf: GroupsTypesHPlus3.Surface, xMax: number, yMax: number, zMax: number): number
	xMax = F32(xMax)
	yMax = F32(yMax)
	zMax = F32(zMax)
	-- Max delta between x, y, and z
	local dxMax = 0
	local dyMax = 0
	local dzMax = 0
	-- result
	local smaller = IncludePRUltratypesH.FALSE

	Scratch.is_surf_within_bounding_box_sx[1] = surf.vertex1[1]
	Scratch.is_surf_within_bounding_box_sx[2] = surf.vertex2[1]
	Scratch.is_surf_within_bounding_box_sx[3] = surf.vertex3[1]
	Scratch.is_surf_within_bounding_box_sy[1] = surf.vertex1[2]
	Scratch.is_surf_within_bounding_box_sy[2] = surf.vertex2[2]
	Scratch.is_surf_within_bounding_box_sy[3] = surf.vertex3[2]
	Scratch.is_surf_within_bounding_box_sz[1] = surf.vertex1[3]
	Scratch.is_surf_within_bounding_box_sz[2] = surf.vertex2[3]
	Scratch.is_surf_within_bounding_box_sz[3] = surf.vertex3[3]

	for i = 0, 2 do
		local j = i + 1
		if j >= 3 then
			j = 0
		end
		const dx = GroupsTypesHPlus3.ABS(Scratch.is_surf_within_bounding_box_sx[i + 1] - Scratch.is_surf_within_bounding_box_sx[j + 1])
		if dx > dxMax then
			dxMax = S16(TruncS32(dx))
		end
		const dy = GroupsTypesHPlus3.ABS(Scratch.is_surf_within_bounding_box_sy[i + 1] - Scratch.is_surf_within_bounding_box_sy[j + 1])
		if dy > dyMax then
			dyMax = S16(TruncS32(dy))
		end
		const dz = GroupsTypesHPlus3.ABS(Scratch.is_surf_within_bounding_box_sz[i + 1] - Scratch.is_surf_within_bounding_box_sz[j + 1])
		if dz > dzMax then
			dzMax = S16(TruncS32(dz))
		end
	end
	if yMax ~= -1 then
		if dyMax < yMax then
			smaller = IncludePRUltratypesH.TRUE
		end
	end
	if xMax ~= -1 and zMax ~= -1 then
		if dxMax < xMax and dzMax < zMax then
			smaller = IncludePRUltratypesH.TRUE
		end
	end
	return smaller
end

-- from src/game/camera.c:is_behind_surface L4430-4447
function camera.is_behind_surface(pos: { number }, surf: GroupsTypesHPlus3.Surface): number
	local behindSurface = 0
	-- Surface normal
	const normX = F32((surf.vertex2[2] - surf.vertex1[2]) * (surf.vertex3[3] - surf.vertex2[3]) - (surf.vertex3[2] - surf.vertex2[2]) * (surf.vertex2[3] - surf.vertex1[3]))
	const normY = F32((surf.vertex2[3] - surf.vertex1[3]) * (surf.vertex3[1] - surf.vertex2[1]) - (surf.vertex3[3] - surf.vertex2[3]) * (surf.vertex2[1] - surf.vertex1[1]))
	const normZ = F32((surf.vertex2[1] - surf.vertex1[1]) * (surf.vertex3[2] - surf.vertex2[2]) - (surf.vertex3[1] - surf.vertex2[1]) * (surf.vertex2[2] - surf.vertex1[2]))
	const dirX = F32(surf.vertex1[1] - pos[1])
	const dirY = F32(surf.vertex1[2] - pos[2])
	const dirZ = F32(surf.vertex1[3] - pos[3])

	if F32(F32(F32(dirX * normX) + F32(dirY * normY)) + F32(dirZ * normZ)) < 0 then
		behindSurface = 1
	end
	return behindSurface
end

-- from src/game/camera.c:is_range_behind_surface L4452-4477
function camera.is_range_behind_surface(from: { number }, to: { number }, surf: GroupsTypesHPlus3.Surface?, range: number, surfType: number): number
	range = S16(TruncS32(range))
	surfType = S16(TruncS32(surfType))
	local behindSurface = IncludePRUltratypesH.TRUE
	local leftBehind = 0
	local rightBehind = 0

	if surf ~= nil then
		if surfType == -1 or surf.type_ ~= surfType then
			if range == 0 then
				behindSurface = camera.is_behind_surface(to, surf)
			else
				SrcEngineMathUtil.vec3f_get_dist_and_angle(from, to, Scratch.is_range_behind_surface_checkDist, Scratch.is_range_behind_surface_checkPitch, Scratch.is_range_behind_surface_checkYaw)
				SrcEngineMathUtil.vec3f_set_dist_and_angle(from, Scratch.is_range_behind_surface_checkPos, Scratch.is_range_behind_surface_checkDist[1], Scratch.is_range_behind_surface_checkPitch[1], S16(Scratch.is_range_behind_surface_checkYaw[1] + range))
				leftBehind = camera.is_behind_surface(Scratch.is_range_behind_surface_checkPos, surf)
				SrcEngineMathUtil.vec3f_set_dist_and_angle(from, Scratch.is_range_behind_surface_checkPos, Scratch.is_range_behind_surface_checkDist[1], Scratch.is_range_behind_surface_checkPitch[1], S16(Scratch.is_range_behind_surface_checkYaw[1] - range))
				rightBehind = camera.is_behind_surface(Scratch.is_range_behind_surface_checkPos, surf)
				behindSurface = leftBehind * rightBehind
			end
		end
	end
	return behindSurface
end

-- from src/game/camera.c:is_mario_behind_surface L4479-4483
function camera.is_mario_behind_surface(c: GroupsTypesHPlus3.Camera, surf: GroupsTypesHPlus3.Surface): number
	const behindSurface = camera.is_behind_surface(camera.sMarioCamState.pos, surf)

	return behindSurface
end

-- from src/game/camera.c:scale_along_line L4489-4496
function camera.scale_along_line(dst: { number }, from: { number }, to: { number }, scale: number)
	scale = F32(scale)
	Scratch.scale_along_line_tempVec[1] = F32(F32(F32(to[1] - from[1]) * scale) + from[1])
	Scratch.scale_along_line_tempVec[2] = F32(F32(F32(to[2] - from[2]) * scale) + from[2])
	Scratch.scale_along_line_tempVec[3] = F32(F32(F32(to[3] - from[3]) * scale) + from[3])
	SrcEngineMathUtil.vec3f_copy(dst, Scratch.scale_along_line_tempVec)
end

-- from src/game/camera.c:is_pos_in_bounds L4501-4517
function camera.is_pos_in_bounds(pos: { number }, center: { number }, bounds: { number }, boundsYaw: number): number
	boundsYaw = S16(TruncS32(boundsYaw))
	local inBound = IncludePRUltratypesH.FALSE

	Scratch.is_pos_in_bounds_rel[1] = F32(center[1] - pos[1])
	Scratch.is_pos_in_bounds_rel[2] = F32(center[2] - pos[2])
	Scratch.is_pos_in_bounds_rel[3] = F32(center[3] - pos[3])

	camera.rotate_in_xz(Scratch.is_pos_in_bounds_rel, Scratch.is_pos_in_bounds_rel, boundsYaw)

	if -bounds[1] < Scratch.is_pos_in_bounds_rel[1] and Scratch.is_pos_in_bounds_rel[1] < bounds[1] and -bounds[2] < Scratch.is_pos_in_bounds_rel[2] and Scratch.is_pos_in_bounds_rel[2] < bounds[2] and -bounds[3] < Scratch.is_pos_in_bounds_rel[3] and Scratch.is_pos_in_bounds_rel[3] < bounds[3] then
		inBound = IncludePRUltratypesH.TRUE
	end
	return inBound
end

-- from src/game/camera.c:calculate_pitch L4519-4526
function camera.calculate_pitch(from: { number }, to: { number }): number
	const dx = F32(to[1] - from[1])
	const dy = F32(to[2] - from[2])
	const dz = F32(to[3] - from[3])
	const pitch = SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz)))), dy)

	return pitch
end

-- from src/game/camera.c:calculate_yaw L4528-4535
function camera.calculate_yaw(from: { number }, to: { number }): number
	const dx = F32(to[1] - from[1])
	const dz = F32(to[3] - from[3])
	const yaw = SrcEngineMathUtil.atan2s(dz, dx)

	return yaw
end

-- from src/game/camera.c:calculate_angles L4540-4547
function camera.calculate_angles(from: { number }, to: { number }, pitch: { number }, yaw: { number })
	const dx = F32(to[1] - from[1])
	const dy = F32(to[2] - from[2])
	const dz = F32(to[3] - from[3])

	pitch[1] = SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz)))), dy)
	yaw[1] = SrcEngineMathUtil.atan2s(dz, dx)
end

-- from src/game/camera.c:calc_abs_dist L4552-4559
function camera.calc_abs_dist(a: { number }, b: { number }): number
	const distX = F32(b[1] - a[1])
	const distY = F32(b[2] - a[2])
	const distZ = F32(b[3] - a[3])
	const distAbs = F32(math.sqrt(F32(F32(F32(distX * distX) + F32(distY * distY)) + F32(distZ * distZ))))

	return distAbs
end

-- from src/game/camera.c:calc_hor_dist L4564-4570
function camera.calc_hor_dist(a: { number }, b: { number }): number
	const distX = F32(b[1] - a[1])
	const distZ = F32(b[3] - a[3])
	const distHor = F32(math.sqrt(F32(F32(distX * distX) + F32(distZ * distZ))))

	return distHor
end

-- from src/game/camera.c:rotate_in_xz L4575-4582
function camera.rotate_in_xz(dst: { number }, src: { number }, yaw: number)
	yaw = S16(TruncS32(yaw))
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(yaw)
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(yaw)

	SrcEngineMathUtil.vec3f_copy(Scratch.rotate_in_xz_tempVec, src)
	dst[1] = F32(F32(Scratch.rotate_in_xz_tempVec[3] * Sin) + F32(Scratch.rotate_in_xz_tempVec[1] * Cos))
	dst[2] = Scratch.rotate_in_xz_tempVec[2]
	dst[3] = F32(F32(Scratch.rotate_in_xz_tempVec[3] * Cos) - F32(Scratch.rotate_in_xz_tempVec[1] * Sin))
end

-- from src/game/camera.c:rotate_in_yz L4590-4597
function camera.rotate_in_yz(dst: { number }, src: { number }, pitch: number)
	pitch = S16(TruncS32(pitch))
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(pitch)
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(pitch)

	SrcEngineMathUtil.vec3f_copy(Scratch.rotate_in_yz_tempVec, src)
	dst[3] = -F32(F32(Scratch.rotate_in_yz_tempVec[3] * Cos) - F32(Scratch.rotate_in_yz_tempVec[2] * Sin))
	dst[2] = F32(F32(Scratch.rotate_in_yz_tempVec[3] * Sin) + F32(Scratch.rotate_in_yz_tempVec[2] * Cos))
	dst[1] = Scratch.rotate_in_yz_tempVec[1]
end

-- from src/game/camera.c:set_camera_pitch_shake L4602-4608
function camera.set_camera_pitch_shake(mag: number, decay: number, inc: number)
	mag = S16(TruncS32(mag))
	decay = S16(TruncS32(decay))
	inc = S16(TruncS32(inc))
	if camera.gLakituState.shakeMagnitude[1] < mag then
		camera.gLakituState.shakeMagnitude[1] = mag
		camera.gLakituState.shakePitchDecay = decay
		camera.gLakituState.shakePitchVel = inc
	end
end

-- from src/game/camera.c:set_camera_yaw_shake L4613-4619
function camera.set_camera_yaw_shake(mag: number, decay: number, inc: number)
	mag = S16(TruncS32(mag))
	decay = S16(TruncS32(decay))
	inc = S16(TruncS32(inc))
	if (if mag > 0 then mag else -mag) > (if camera.gLakituState.shakeMagnitude[2] > 0 then camera.gLakituState.shakeMagnitude[2] else -camera.gLakituState.shakeMagnitude[2]) then
		camera.gLakituState.shakeMagnitude[2] = mag
		camera.gLakituState.shakeYawDecay = decay
		camera.gLakituState.shakeYawVel = inc
	end
end

-- from src/game/camera.c:set_camera_roll_shake L4624-4630
function camera.set_camera_roll_shake(mag: number, decay: number, inc: number)
	mag = S16(TruncS32(mag))
	decay = S16(TruncS32(decay))
	inc = S16(TruncS32(inc))
	if camera.gLakituState.shakeMagnitude[3] < mag then
		camera.gLakituState.shakeMagnitude[3] = mag
		camera.gLakituState.shakeRollDecay = decay
		camera.gLakituState.shakeRollVel = inc
	end
end

-- from src/game/camera.c:set_pitch_shake_from_point L4635-4649
function camera.set_pitch_shake_from_point(mag: number, decay: number, inc: number, maxDist: number, posX: number, posY: number, posZ: number)
	mag = S16(TruncS32(mag))
	decay = S16(TruncS32(decay))
	inc = S16(TruncS32(inc))
	maxDist = F32(maxDist)
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	Scratch.set_pitch_shake_from_point_pos[1] = posX
	Scratch.set_pitch_shake_from_point_pos[2] = posY
	Scratch.set_pitch_shake_from_point_pos[3] = posZ
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.gLakituState.goalPos, Scratch.set_pitch_shake_from_point_pos, Scratch.set_pitch_shake_from_point_dist, Scratch.set_pitch_shake_from_point_dummyPitch, Scratch.set_pitch_shake_from_point_dummyYaw)
	mag = camera.reduce_by_dist_from_camera(mag, maxDist, posX, posY, posZ)
	if mag ~= 0 then
		camera.set_camera_pitch_shake(mag, decay, inc)
	end
end

-- from src/game/camera.c:set_yaw_shake_from_point L4654-4668
function camera.set_yaw_shake_from_point(mag: number, decay: number, inc: number, maxDist: number, posX: number, posY: number, posZ: number)
	mag = S16(TruncS32(mag))
	decay = S16(TruncS32(decay))
	inc = S16(TruncS32(inc))
	maxDist = F32(maxDist)
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	Scratch.set_yaw_shake_from_point_pos[1] = posX
	Scratch.set_yaw_shake_from_point_pos[2] = posY
	Scratch.set_yaw_shake_from_point_pos[3] = posZ
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.gLakituState.goalPos, Scratch.set_yaw_shake_from_point_pos, Scratch.set_yaw_shake_from_point_dist, Scratch.set_yaw_shake_from_point_dummyPitch, Scratch.set_yaw_shake_from_point_dummyYaw)
	mag = camera.reduce_by_dist_from_camera(mag, maxDist, posX, posY, posZ)
	if mag ~= 0 then
		camera.set_camera_yaw_shake(mag, decay, inc)
	end
end

-- from src/game/camera.c:increment_shake_offset L4673-4679
function camera.increment_shake_offset(offset: { number }, increment: number)
	increment = S16(TruncS32(increment))
	if increment == -0x8000 then
		offset[1] = S16(bit32.band(offset[1], 0x8000) + 0xC000)
	else
		offset[1] = S16(offset[1] + increment)
	end
end

-- from src/game/camera.c:shake_camera_pitch L4684-4699
function camera.shake_camera_pitch(pos: { number }, focus: { number })
	if bit32.bor(camera.gLakituState.shakeMagnitude[1], camera.gLakituState.shakeMagnitude[2]) ~= 0 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(pos, focus, Scratch.shake_camera_pitch_dist, Scratch.shake_camera_pitch_pitch, Scratch.shake_camera_pitch_yaw)
		const Sin: number = Registry.Members.src__engine__math_util_h.sins(camera.gLakituState.shakePitchPhase)
		Scratch.shake_camera_pitch_pitch[1] = S16(TruncS32(F32(Scratch.shake_camera_pitch_pitch[1] + F32(camera.gLakituState.shakeMagnitude[1] * Sin))))
		SrcEngineMathUtil.vec3f_set_dist_and_angle(pos, focus, Scratch.shake_camera_pitch_dist[1], Scratch.shake_camera_pitch_pitch[1], Scratch.shake_camera_pitch_yaw[1])
		Scratch.shake_camera_pitch_ref[1] = camera.gLakituState.shakePitchPhase
		camera.increment_shake_offset(Scratch.shake_camera_pitch_ref, camera.gLakituState.shakePitchVel)
		camera.gLakituState.shakePitchPhase = Scratch.shake_camera_pitch_ref[1]
		Scratch.shake_camera_pitch_ref[1] = camera.gLakituState.shakeMagnitude[1]
		const Approached = camera.camera_approach_s16_symmetric_bool(Scratch.shake_camera_pitch_ref, 0, camera.gLakituState.shakePitchDecay)
		camera.gLakituState.shakeMagnitude[1] = Scratch.shake_camera_pitch_ref[1]
		if Approached == 0 then
			camera.gLakituState.shakePitchPhase = 0
		end
	end
end

-- from src/game/camera.c:shake_camera_yaw L4704-4719
function camera.shake_camera_yaw(pos: { number }, focus: { number })
	if camera.gLakituState.shakeMagnitude[2] ~= 0 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(pos, focus, Scratch.shake_camera_yaw_dist, Scratch.shake_camera_yaw_pitch, Scratch.shake_camera_yaw_yaw)
		const Sin: number = Registry.Members.src__engine__math_util_h.sins(camera.gLakituState.shakeYawPhase)
		Scratch.shake_camera_yaw_yaw[1] = S16(TruncS32(F32(Scratch.shake_camera_yaw_yaw[1] + F32(camera.gLakituState.shakeMagnitude[2] * Sin))))
		SrcEngineMathUtil.vec3f_set_dist_and_angle(pos, focus, Scratch.shake_camera_yaw_dist[1], Scratch.shake_camera_yaw_pitch[1], Scratch.shake_camera_yaw_yaw[1])
		Scratch.shake_camera_yaw_ref[1] = camera.gLakituState.shakeYawPhase
		camera.increment_shake_offset(Scratch.shake_camera_yaw_ref, camera.gLakituState.shakeYawVel)
		camera.gLakituState.shakeYawPhase = Scratch.shake_camera_yaw_ref[1]
		Scratch.shake_camera_yaw_ref[1] = camera.gLakituState.shakeMagnitude[2]
		const Approached = camera.camera_approach_s16_symmetric_bool(Scratch.shake_camera_yaw_ref, 0, camera.gLakituState.shakeYawDecay)
		camera.gLakituState.shakeMagnitude[2] = Scratch.shake_camera_yaw_ref[1]
		if Approached == 0 then
			camera.gLakituState.shakeYawPhase = 0
		end
	end
end

-- from src/game/camera.c:shake_camera_roll L4724-4735
function camera.shake_camera_roll(roll: { number })
	if camera.gLakituState.shakeMagnitude[3] ~= 0 then
		Scratch.shake_camera_roll_ref[1] = camera.gLakituState.shakeRollPhase
		camera.increment_shake_offset(Scratch.shake_camera_roll_ref, camera.gLakituState.shakeRollVel)
		camera.gLakituState.shakeRollPhase = Scratch.shake_camera_roll_ref[1]
		const Sin: number = Registry.Members.src__engine__math_util_h.sins(camera.gLakituState.shakeRollPhase)
		roll[1] = S16(TruncS32(F32(roll[1] + F32(camera.gLakituState.shakeMagnitude[3] * Sin))))
		Scratch.shake_camera_roll_ref[1] = camera.gLakituState.shakeMagnitude[3]
		const Approached = camera.camera_approach_s16_symmetric_bool(Scratch.shake_camera_roll_ref, 0, camera.gLakituState.shakeRollDecay)
		camera.gLakituState.shakeMagnitude[3] = Scratch.shake_camera_roll_ref[1]
		if Approached == 0 then
			camera.gLakituState.shakeRollPhase = 0
		end
	end
end

-- from src/game/camera.c:offset_yaw_outward_radial L4741-4790
function camera.offset_yaw_outward_radial(c: GroupsTypesHPlus3.Camera, areaYaw: number): number
	areaYaw = S16(TruncS32(areaYaw))
	local yawGoal = S16(GroupsTypesHPlus3.DEGREES(60))
	Scratch.offset_yaw_outward_radial_yaw[1] = camera.sModeOffsetYaw

	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTC then
		Scratch.offset_yaw_outward_radial_areaCenter[1] = c.areaCenX
		Scratch.offset_yaw_outward_radial_areaCenter[2] = camera.sMarioCamState.pos[2]
		Scratch.offset_yaw_outward_radial_areaCenter[3] = c.areaCenZ
		const distFromAreaCenter = camera.calc_abs_dist(Scratch.offset_yaw_outward_radial_areaCenter, camera.sMarioCamState.pos)
		if 800 > distFromAreaCenter then
			yawGoal = 0x3800
		end
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_PYRAMID then
		-- This mask splits the 360 degrees of yaw into 4 corners. It adds 45 degrees so that the yaw
		-- offset at the corner will be 0, but the yaw offset near the center will face more towards
		-- the direction Mario is running in.
		yawGoal = S16(bit32.band(areaYaw, 0xC000) - areaYaw + GroupsTypesHPlus3.DEGREES(45))
		if yawGoal < 0 then
			yawGoal = S16(-yawGoal)
		end
		yawGoal = S16(TruncS32(yawGoal / 32) * 48)
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_LLL_OUTSIDE then
		yawGoal = 0
	end
	const dYaw = S16(TruncS32(F32(F32(LevelUpdate.gMarioStates[1].forwardVel / 32) * 128)))

	if camera.sAreaYawChange < 0 then
		camera.camera_approach_s16_symmetric_bool(Scratch.offset_yaw_outward_radial_yaw, S16(-yawGoal), dYaw)
	end
	if camera.sAreaYawChange > 0 then
		camera.camera_approach_s16_symmetric_bool(Scratch.offset_yaw_outward_radial_yaw, yawGoal, dYaw)
	end
	-- When the final yaw is out of [-60,60] degrees, approach yawGoal faster than dYaw will ever be,
	-- making the camera lock in one direction until yawGoal drops below 60 (or Mario presses a C button)
	if Scratch.offset_yaw_outward_radial_yaw[1] < -GroupsTypesHPlus3.DEGREES(60) then
		-- ! Maybe they meant to reverse yawGoal's sign?
		camera.camera_approach_s16_symmetric_bool(Scratch.offset_yaw_outward_radial_yaw, S16(-yawGoal), 0x200)
	end
	if Scratch.offset_yaw_outward_radial_yaw[1] > GroupsTypesHPlus3.DEGREES(60) then
		-- ! Maybe they meant to reverse yawGoal's sign?
		camera.camera_approach_s16_symmetric_bool(Scratch.offset_yaw_outward_radial_yaw, yawGoal, 0x200)
	end
	return Scratch.offset_yaw_outward_radial_yaw[1]
end

-- from src/game/camera.c:cutscene_intro_peach_play_message_music L4795-4797
function camera.cutscene_intro_peach_play_message_music()
	-- SEQ_PLAYER_LEVEL is 0, SEQUENCE_ARGS(priority, seqId) is (priority << 8) | seqId
	Audio.play_music(0, bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_PEACH_MESSAGE), 0)
end

-- from src/game/camera.c:cutscene_intro_peach_play_lakitu_flying_music L4802-4804
function camera.cutscene_intro_peach_play_lakitu_flying_music()
	Audio.play_music(0, bit32.bor(bit32.lshift(15, 8), IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_INTRO), 0)
end

-- from src/game/camera.c:play_camera_buzz_if_cdown L4806-4810
function camera.play_camera_buzz_if_cdown()
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.D_CBUTTONS) then
		camera.play_sound_button_change_blocked()
	end
end

-- from src/game/camera.c:play_camera_buzz_if_cbutton L4812-4816
function camera.play_camera_buzz_if_cbutton()
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, camera.CBUTTON_MASK) then
		camera.play_sound_button_change_blocked()
	end
end

-- from src/game/camera.c:play_camera_buzz_if_c_sideways L4818-4823
function camera.play_camera_buzz_if_c_sideways()
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_CBUTTONS) or bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_CBUTTONS) then
		camera.play_sound_button_change_blocked()
	end
end

-- from src/game/camera.c:play_sound_cbutton_up L4825-4827
function camera.play_sound_cbutton_up()
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:play_sound_cbutton_down L4829-4831
function camera.play_sound_cbutton_down()
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:play_sound_cbutton_side L4833-4835
function camera.play_sound_cbutton_side()
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_TURN, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:play_sound_button_change_blocked L4837-4839
function camera.play_sound_button_change_blocked()
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:play_sound_rbutton_changed L4841-4843
function camera.play_sound_rbutton_changed()
	Audio.play_sound(IncludeSoundsH.SOUND_MENU_CLICK_CHANGE_VIEW, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:play_sound_if_cam_switched_to_lakitu_or_mario L4845-4853
function camera.play_sound_if_cam_switched_to_lakitu_or_mario()
	if bit32.btest(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_MARIO_ACTIVE) then
		camera.play_sound_rbutton_changed()
	end
	if bit32.btest(camera.sCameraSoundFlags, GroupsTypesHPlus3.CAM_SOUND_NORMAL_ACTIVE) then
		camera.play_sound_rbutton_changed()
	end
	camera.sCameraSoundFlags = S16(bit32.band(camera.sCameraSoundFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_SOUND_MARIO_ACTIVE, GroupsTypesHPlus3.CAM_SOUND_NORMAL_ACTIVE))))
end

-- from src/game/camera.c:radial_camera_input L4858-4962
function camera.radial_camera_input(c: GroupsTypesHPlus3.Camera, unused: number): number
	unused = F32(unused)
	const dummy = 0

	if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE) or not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE) then
		-- If C-L or C-R are pressed, the camera is rotating
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, bit32.bor(IncludePROsH.L_CBUTTONS, IncludePROsH.R_CBUTTONS)) then
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ENTERED_ROTATE_SURFACE)))
			--  @bug this does not clear the rotation flags set by the surface. It's possible to set
			--       both ROTATE_LEFT and ROTATE_RIGHT, locking the camera.
			--       Ex: If a surface set CAM_MOVE_ROTATE_RIGHT and the user presses C-R, it locks the
			--       camera until a different mode is activated
		end

		-- Rotate Right and left
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_CBUTTONS) then
			if camera.sModeOffsetYaw > -0x800 then
				-- The camera is now rotating right
				if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) then
					camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT))
				end

				if c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
					-- if > ~48 degrees, we're rotating for the second time.
					if camera.sModeOffsetYaw > 0x22AA then
						camera.s2ndRotateFlags = S16(bit32.bor(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT))
					end

					if camera.sModeOffsetYaw == GroupsTypesHPlus3.DEGREES(105) then
						camera.play_sound_button_change_blocked()
					else
						camera.play_sound_cbutton_side()
					end
				else
					if camera.sModeOffsetYaw == GroupsTypesHPlus3.DEGREES(60) then
						camera.play_sound_button_change_blocked()
					else
						camera.play_sound_cbutton_side()
					end
				end
			else
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_RETURN_TO_MIDDLE))
				camera.play_sound_cbutton_up()
			end
		end
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_CBUTTONS) then
			if camera.sModeOffsetYaw < 0x800 then
				if not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) then
					camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT))
				end

				if c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
					-- if < ~48 degrees, we're rotating for the second time.
					if camera.sModeOffsetYaw < -0x22AA then
						camera.s2ndRotateFlags = S16(bit32.bor(camera.s2ndRotateFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT))
					end

					if camera.sModeOffsetYaw == GroupsTypesHPlus3.DEGREES(-105) then
						camera.play_sound_button_change_blocked()
					else
						camera.play_sound_cbutton_side()
					end
				else
					if camera.sModeOffsetYaw == GroupsTypesHPlus3.DEGREES(-60) then
						camera.play_sound_button_change_blocked()
					else
						camera.play_sound_cbutton_side()
					end
				end
			else
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_RETURN_TO_MIDDLE))
				camera.play_sound_cbutton_up()
			end
		end
	end

	-- Zoom in / enter C-Up
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.U_CBUTTONS) then
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT)))
			camera.play_sound_cbutton_up()
		else
			camera.set_mode_c_up(c)
		end
	end

	-- Zoom out
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.D_CBUTTONS) then
		if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ALREADY_ZOOMED_OUT))

			camera.play_camera_buzz_if_cdown()
		else
			camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
			camera.play_sound_cbutton_down()
		end
	end

	-- ! returning uninitialized variable
	return dummy
end

-- from src/game/camera.c:trigger_cutscene_dialog L4967-4977
function camera.trigger_cutscene_dialog(trigger: number): number
	const result = 0

	if trigger == 1 then
		camera.start_object_cutscene_without_focus(GroupsTypesHPlus3.CUTSCENE_READ_MESSAGE)
	end
	if trigger == 2 then
		-- Empty in the C source.
	end
	return result
end

-- from src/game/camera.c:handle_c_button_movement L4982-5040
function camera.handle_c_button_movement(c: GroupsTypesHPlus3.Camera)
	-- Zoom in
	if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.U_CBUTTONS) then
		if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED and bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
			camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT)))
			camera.play_sound_cbutton_up()
		else
			camera.set_mode_c_up(c)
			if camera.sZeroZoomDist > camera.gCameraZoomDist then
				camera.sZoomAmount = -camera.gCameraZoomDist
			else
				camera.sZoomAmount = camera.gCameraZoomDist
			end
		end
	end
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		-- Zoom out
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.D_CBUTTONS) then
			if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT) then
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ALREADY_ZOOMED_OUT))
				camera.sZoomAmount = F32(camera.gCameraZoomDist + 400)

				camera.play_camera_buzz_if_cdown()
			else
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ZOOMED_OUT))
				camera.sZoomAmount = F32(camera.gCameraZoomDist + 400)
				camera.play_sound_cbutton_down()
			end
		end

		-- Rotate left or right
		const cSideYaw = 0x1000
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.R_CBUTTONS) then
			if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT) then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT)))
			else
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT))
				if camera.sCSideButtonYaw == 0 then
					camera.play_sound_cbutton_side()
				end
				camera.sCSideButtonYaw = S16(-cSideYaw)
			end
		end
		if bit32.btest(GameInit.gPlayer1Controller.buttonPressed, IncludePROsH.L_CBUTTONS) then
			if bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT) then
				camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_ROTATE_RIGHT)))
			else
				camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_ROTATE_LEFT))
				if camera.sCSideButtonYaw == 0 then
					camera.play_sound_cbutton_side()
				end
				camera.sCSideButtonYaw = cSideYaw
			end
		end
	end
end

-- from src/game/camera.c:clear_cutscene_vars L5045-5055
function camera.clear_cutscene_vars(c: GroupsTypesHPlus3.Camera)
	for i = 0, 9 do
		camera.sCutsceneVars[i + 1].unused1 = 0
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[i + 1].point, 0, 0, 0)
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[i + 1].unusedPoint, 0, 0, 0)
		SrcEngineMathUtil.vec3s_set(camera.sCutsceneVars[i + 1].angle, 0, 0, 0)
		camera.sCutsceneVars[i + 1].unused2 = 0
	end
end

-- from src/game/camera.c:start_cutscene L5060-5065
function camera.start_cutscene(c: GroupsTypesHPlus3.Camera, cutscene: number)
	cutscene = U8(TruncS32(cutscene))
	if c.cutscene ~= cutscene then
		c.cutscene = cutscene
		camera.clear_cutscene_vars(c)
	end
end

-- from src/game/camera.c:determine_dance_cutscene L5076-5099
function camera.determine_dance_cutscene(c: GroupsTypesHPlus3.Camera): number
	local starIndex = U8(TruncS32((SaveFile.gLastCompletedStarNum - 1) / 2))
	local cutsceneIndex = 0
	local courseNum = U8(Area.gCurrCourseNum)

	if starIndex > 3 then
		starIndex = 0
	end
	if courseNum > IncludeCourseTableH.COURSE_MAX then
		courseNum = IncludeCourseTableH.COURSE_NONE
	end
	cutsceneIndex = camera.sDanceCutsceneIndexTable[courseNum + 1][starIndex + 1]

	if bit32.btest(SaveFile.gLastCompletedStarNum, 1) then
		-- Odd stars take the lower four bytes
		cutsceneIndex = U8(bit32.band(cutsceneIndex, 0xF))
	else
		-- Even stars use the upper four bytes
		cutsceneIndex = U8(bit32.rshift(cutsceneIndex, 4))
	end
	const cutscene = camera.sDanceCutsceneTable[cutsceneIndex + 1]
	return cutscene
end

-- from src/game/camera.c:open_door_cutscene L5104-5114
function camera.open_door_cutscene(pullResult: number, pushResult: number): number
	pullResult = U8(TruncS32(pullResult))
	pushResult = U8(TruncS32(pushResult))
	local result = 0

	if camera.sMarioCamState.action == IncludeSm64H.ACT_PULLING_DOOR then
		result = pullResult
	end
	if camera.sMarioCamState.action == IncludeSm64H.ACT_PUSHING_DOOR then
		result = pushResult
	end
	return U8(result)
end

-- from src/game/camera.c:get_cutscene_from_mario_status L5122-5252
function camera.get_cutscene_from_mario_status(c: GroupsTypesHPlus3.Camera): number
	local cutscene = c.cutscene

	if cutscene == 0 then
		-- A cutscene started by an object, if any, will start if nothing else happened
		cutscene = camera.sObjectCutscene
		camera.sObjectCutscene = 0
		if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_DOOR then
			if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CASTLE_LOBBY then
				-- doorStatus is never DOOR_ENTER_LOBBY when cameraEvent == 6, because
				-- doorStatus is only used for the star door in the lobby, which uses
				-- ACT_ENTERING_STAR_DOOR
				if c.mode == GroupsTypesHPlus3.CAMERA_MODE_SPIRAL_STAIRS or c.mode == GroupsTypesHPlus3.CAMERA_MODE_CLOSE or c.doorStatus == GroupsTypesHPlus3.DOOR_ENTER_LOBBY then
					cutscene = camera.open_door_cutscene(GroupsTypesHPlus3.CUTSCENE_DOOR_PULL_MODE, GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH_MODE)
				else
					cutscene = camera.open_door_cutscene(GroupsTypesHPlus3.CUTSCENE_DOOR_PULL, GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH)
				end
			elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BBH then
				-- Castle Lobby uses 0 to mean 'no special modes', but BBH uses 1...
				if c.doorStatus == GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL then
					cutscene = camera.open_door_cutscene(GroupsTypesHPlus3.CUTSCENE_DOOR_PULL, GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH)
				else
					cutscene = camera.open_door_cutscene(GroupsTypesHPlus3.CUTSCENE_DOOR_PULL_MODE, GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH_MODE)
				end
			else
				cutscene = camera.open_door_cutscene(GroupsTypesHPlus3.CUTSCENE_DOOR_PULL, GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH)
			end
		end
		if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_DOOR_WARP then
			cutscene = GroupsTypesHPlus3.CUTSCENE_DOOR_WARP
		end
		if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_CANNON then
			cutscene = GroupsTypesHPlus3.CUTSCENE_ENTER_CANNON
		end
		if IncludeSurfaceTerrainsH.SURFACE_IS_PAINTING_WARP(camera.sMarioGeometry.currFloorType) ~= 0 then
			cutscene = GroupsTypesHPlus3.CUTSCENE_ENTER_PAINTING
		end
		if camera.sMarioCamState.action == IncludeSm64H.ACT_DEATH_EXIT then
			cutscene = GroupsTypesHPlus3.CUTSCENE_DEATH_EXIT
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_EXIT_AIRBORNE then
			cutscene = GroupsTypesHPlus3.CUTSCENE_EXIT_PAINTING_SUCC
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_SPECIAL_EXIT_AIRBORNE then
			if camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_1 or camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_2 or camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_3 then
				cutscene = GroupsTypesHPlus3.CUTSCENE_EXIT_BOWSER_SUCC
			else
				cutscene = GroupsTypesHPlus3.CUTSCENE_EXIT_SPECIAL_SUCC
			end
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_SPECIAL_DEATH_EXIT then
			if camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_1 or camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_2 or camera.gPrevLevel == IncludeLevelTableH.LEVEL_BOWSER_3 then
				cutscene = GroupsTypesHPlus3.CUTSCENE_EXIT_BOWSER_DEATH
			else
				cutscene = GroupsTypesHPlus3.CUTSCENE_NONPAINTING_DEATH
			end
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_ENTERING_STAR_DOOR then
			if c.doorStatus == GroupsTypesHPlus3.DOOR_DEFAULT then
				cutscene = GroupsTypesHPlus3.CUTSCENE_SLIDING_DOORS_OPEN
			else
				cutscene = GroupsTypesHPlus3.CUTSCENE_DOOR_PULL_MODE
			end
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_UNLOCKING_KEY_DOOR then
			cutscene = GroupsTypesHPlus3.CUTSCENE_UNLOCK_KEY_DOOR
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_WATER_DEATH then
			cutscene = GroupsTypesHPlus3.CUTSCENE_WATER_DEATH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_DEATH_ON_BACK then
			cutscene = GroupsTypesHPlus3.CUTSCENE_DEATH_ON_BACK
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_DEATH_ON_STOMACH then
			cutscene = GroupsTypesHPlus3.CUTSCENE_DEATH_ON_STOMACH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_STANDING_DEATH then
			cutscene = GroupsTypesHPlus3.CUTSCENE_STANDING_DEATH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_SUFFOCATION then
			cutscene = GroupsTypesHPlus3.CUTSCENE_SUFFOCATION_DEATH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_QUICKSAND_DEATH then
			cutscene = GroupsTypesHPlus3.CUTSCENE_QUICKSAND_DEATH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_ELECTROCUTION then
			cutscene = GroupsTypesHPlus3.CUTSCENE_STANDING_DEATH
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_STAR_DANCE_EXIT then
			cutscene = U8(camera.determine_dance_cutscene(c))
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_STAR_DANCE_WATER then
			cutscene = U8(camera.determine_dance_cutscene(c))
		elseif camera.sMarioCamState.action == IncludeSm64H.ACT_STAR_DANCE_NO_EXIT then
			cutscene = GroupsTypesHPlus3.CUTSCENE_DANCE_DEFAULT
		end
		if camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_INTRO then
			cutscene = GroupsTypesHPlus3.CUTSCENE_INTRO_PEACH
		elseif camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_GRAND_STAR then
			cutscene = GroupsTypesHPlus3.CUTSCENE_GRAND_STAR
		elseif camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_ENDING then
			cutscene = GroupsTypesHPlus3.CUTSCENE_ENDING
		elseif camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_END_WAVING then
			cutscene = GroupsTypesHPlus3.CUTSCENE_END_WAVING
		elseif camera.sMarioCamState.cameraEvent == GroupsTypesHPlus3.CAM_EVENT_START_CREDITS then
			cutscene = GroupsTypesHPlus3.CUTSCENE_CREDITS
		end
	end
	-- doorStatus is reset every frame. CameraTriggers need to constantly set doorStatus
	c.doorStatus = GroupsTypesHPlus3.DOOR_DEFAULT

	return cutscene
end

-- from src/game/camera.c:warp_camera L5257-5277
function camera.warp_camera(displacementX: number, displacementY: number, displacementZ: number)
	displacementX = F32(displacementX)
	displacementY = F32(displacementY)
	displacementZ = F32(displacementZ)
	const marioStates = LevelUpdate.gMarioStates[1]
	const start = camera.sModeInfo.transitionStart
	const end_ = camera.sModeInfo.transitionEnd

	camera.gCurrLevelArea = Area.gCurrLevelNum * 16 + (Area.gCurrentArea :: GroupsTypesHPlus3.Area).index
	Scratch.warp_camera_displacement[1] = displacementX
	Scratch.warp_camera_displacement[2] = displacementY
	Scratch.warp_camera_displacement[3] = displacementZ
	SrcEngineMathUtil.vec3f_add(camera.gLakituState.curPos, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(camera.gLakituState.curFocus, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(camera.gLakituState.goalPos, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(camera.gLakituState.goalFocus, Scratch.warp_camera_displacement)
	marioStates.waterLevel = S16(TruncS32(F32(marioStates.waterLevel + displacementY)))

	SrcEngineMathUtil.vec3f_add(start.focus, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(start.pos, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(end_.focus, Scratch.warp_camera_displacement)
	SrcEngineMathUtil.vec3f_add(end_.pos, Scratch.warp_camera_displacement)
end

-- from src/game/camera.c:approach_camera_height L5283-5297
function camera.approach_camera_height(c: GroupsTypesHPlus3.Camera, goal: number, inc: number)
	goal = F32(goal)
	inc = F32(inc)
	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT) then
		if c.pos[2] < goal then
			c.pos[2] = F32(c.pos[2] + inc)
			if c.pos[2] > goal then
				c.pos[2] = goal
			end
		else
			c.pos[2] = F32(c.pos[2] - inc)
			if c.pos[2] < goal then
				c.pos[2] = goal
			end
		end
	else
		c.pos[2] = goal
	end
end

-- from src/game/camera.c:stub_camera_4 L5299-5300
function camera.stub_camera_4(a: number, b: number, c: number, d: number)
	-- Empty in the C source.
end

-- from src/game/camera.c:set_focus_rel_mario L5310-5320
function camera.set_focus_rel_mario(c: GroupsTypesHPlus3.Camera, leftRight: number, yOff: number, forwBack: number, yawOff: number)
	leftRight = F32(leftRight)
	yOff = F32(yOff)
	forwBack = F32(forwBack)
	yawOff = S16(TruncS32(yawOff))
	camera.calc_y_to_curr_floor(Scratch.set_focus_rel_mario_focFloorYOff, 1, 200, Scratch.set_focus_rel_mario_focFloorYOff, F32(0.9), 200)
	const yaw = S16(camera.sMarioCamState.faceAngle[2] + yawOff)
	c.focus[3] = F32(F32(camera.sMarioCamState.pos[3] + F32(forwBack * Registry.Members.src__engine__math_util_h.coss(yaw))) - F32(leftRight * Registry.Members.src__engine__math_util_h.sins(yaw)))
	c.focus[1] = F32(F32(camera.sMarioCamState.pos[1] + F32(forwBack * Registry.Members.src__engine__math_util_h.sins(yaw))) + F32(leftRight * Registry.Members.src__engine__math_util_h.coss(yaw)))
	c.focus[2] = F32(F32(camera.sMarioCamState.pos[2] + yOff) + Scratch.set_focus_rel_mario_focFloorYOff[1])
end

-- from src/game/camera.c:unused_set_pos_rel_mario L5330-5336
function camera.unused_set_pos_rel_mario(c: GroupsTypesHPlus3.Camera, leftRight: number, yOff: number, forwBack: number, yawOff: number)
	leftRight = F32(leftRight)
	yOff = F32(yOff)
	forwBack = F32(forwBack)
	yawOff = S16(TruncS32(yawOff))
	const yaw = U16(camera.sMarioCamState.faceAngle[2] + yawOff)

	c.pos[1] = F32(F32(camera.sMarioCamState.pos[1] + F32(forwBack * Registry.Members.src__engine__math_util_h.sins(yaw))) + F32(leftRight * Registry.Members.src__engine__math_util_h.coss(yaw)))
	c.pos[2] = F32(camera.sMarioCamState.pos[2] + yOff)
	c.pos[3] = F32(F32(camera.sMarioCamState.pos[3] + F32(forwBack * Registry.Members.src__engine__math_util_h.coss(yaw))) - F32(leftRight * Registry.Members.src__engine__math_util_h.sins(yaw)))
end

-- from src/game/camera.c:offset_rotated L5344-5360
function camera.offset_rotated(dst: { number }, from: { number }, to: { number }, rotation: { number })
	const sinPitch = Registry.Members.src__engine__math_util_h.sins(rotation[1])
	const cosPitch = Registry.Members.src__engine__math_util_h.coss(rotation[1])

	-- First rotate the direction by rotation's pitch
	--! The Z axis is flipped here.
	const pitchRotated2 = F32(-F32(F32(to[3] * cosPitch) - F32(to[2] * sinPitch)))
	const pitchRotated1 = F32(F32(to[3] * sinPitch) + F32(to[2] * cosPitch))
	const pitchRotated0 = to[1]

	-- Rotate again by rotation's yaw
	dst[1] = F32(F32(from[1] + F32(pitchRotated2 * Registry.Members.src__engine__math_util_h.sins(rotation[2]))) + F32(pitchRotated0 * Registry.Members.src__engine__math_util_h.coss(rotation[2])))
	dst[2] = F32(from[2] + pitchRotated1)
	dst[3] = F32(F32(from[3] + F32(pitchRotated2 * Registry.Members.src__engine__math_util_h.coss(rotation[2]))) - F32(pitchRotated0 * Registry.Members.src__engine__math_util_h.sins(rotation[2])))
end

-- from src/game/camera.c:offset_rotated_coords L5368-5373
function camera.offset_rotated_coords(dst: { number }, from: { number }, rotation: { number }, xTo: number, yTo: number, zTo: number)
	xTo = F32(xTo)
	yTo = F32(yTo)
	zTo = F32(zTo)
	SrcEngineMathUtil.vec3f_set(Scratch.offset_rotated_coords_to, xTo, yTo, zTo)
	camera.offset_rotated(dst, from, Scratch.offset_rotated_coords_to, rotation)
end

-- from src/game/camera.c:determine_pushing_or_pulling_door L5375-5381
function camera.determine_pushing_or_pulling_door(rotation: { number })
	if camera.sMarioCamState.action == IncludeSm64H.ACT_PULLING_DOOR then
		rotation[1] = 0
	else
		rotation[1] = S16(GroupsTypesHPlus3.DEGREES(-180))
	end
end

-- from src/game/camera.c:next_lakitu_state L5398-5487
function camera.next_lakitu_state(newPos: { number }, newFoc: { number }, curPos: { number }, curFoc: { number }, oldPos: { number }, oldFoc: { number }, yaw: number): number
	yaw = S16(TruncS32(yaw))
	local distVelocity: number
	local pitchVelocity: number
	local yawVelocity: number
	const distTimer = camera.sModeTransition.framesLeft
	const angleTimer = S16(camera.sModeTransition.framesLeft)

	-- If not transitioning, just use gCamera's current pos and foc
	SrcEngineMathUtil.vec3f_copy(newPos, curPos)
	SrcEngineMathUtil.vec3f_copy(newFoc, curFoc)

	if bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_START_TRANSITION) then
		for i = 0, 2 do
			-- Add Mario's displacement from this frame to the last frame's pos and focus
			-- Makes the transition start from where the camera would have moved
			Scratch.next_lakitu_state_startPos[i + 1] = F32(F32(oldPos[i + 1] + camera.sMarioCamState.pos[i + 1]) - camera.sModeTransition.marioPos[i + 1])
			Scratch.next_lakitu_state_startFoc[i + 1] = F32(F32(oldFoc[i + 1] + camera.sMarioCamState.pos[i + 1]) - camera.sModeTransition.marioPos[i + 1])
		end

		Scratch.next_lakitu_state_refDist[1] = camera.sModeTransition.focDist
		Scratch.next_lakitu_state_refPitch[1] = camera.sModeTransition.focPitch
		Scratch.next_lakitu_state_refYaw[1] = camera.sModeTransition.focYaw
		SrcEngineMathUtil.vec3f_get_dist_and_angle(curFoc, Scratch.next_lakitu_state_startFoc, Scratch.next_lakitu_state_refDist, Scratch.next_lakitu_state_refPitch, Scratch.next_lakitu_state_refYaw)
		camera.sModeTransition.focDist = Scratch.next_lakitu_state_refDist[1]
		camera.sModeTransition.focPitch = Scratch.next_lakitu_state_refPitch[1]
		camera.sModeTransition.focYaw = Scratch.next_lakitu_state_refYaw[1]
		Scratch.next_lakitu_state_refDist[1] = camera.sModeTransition.posDist
		Scratch.next_lakitu_state_refPitch[1] = camera.sModeTransition.posPitch
		Scratch.next_lakitu_state_refYaw[1] = camera.sModeTransition.posYaw
		SrcEngineMathUtil.vec3f_get_dist_and_angle(curFoc, Scratch.next_lakitu_state_startPos, Scratch.next_lakitu_state_refDist, Scratch.next_lakitu_state_refPitch, Scratch.next_lakitu_state_refYaw)
		camera.sModeTransition.posDist = Scratch.next_lakitu_state_refDist[1]
		camera.sModeTransition.posPitch = Scratch.next_lakitu_state_refPitch[1]
		camera.sModeTransition.posYaw = Scratch.next_lakitu_state_refYaw[1]
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_START_TRANSITION)))
	end

	-- Transition from the last mode to the current one
	if camera.sModeTransition.framesLeft > 0 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(curFoc, curPos, Scratch.next_lakitu_state_goalDist, Scratch.next_lakitu_state_goalPitch, Scratch.next_lakitu_state_goalYaw)
		const DistDiff = F32(Scratch.next_lakitu_state_goalDist[1] - camera.sModeTransition.posDist)
		distVelocity = F32((if DistDiff > 0 then DistDiff else -DistDiff) / distTimer)
		const PitchDiff = Scratch.next_lakitu_state_goalPitch[1] - camera.sModeTransition.posPitch
		pitchVelocity = S16(math.modf((if PitchDiff > 0 then PitchDiff else -PitchDiff) / angleTimer))
		const YawDiff = Scratch.next_lakitu_state_goalYaw[1] - camera.sModeTransition.posYaw
		yawVelocity = S16(math.modf((if YawDiff > 0 then YawDiff else -YawDiff) / angleTimer))

		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.posDist
		camera.camera_approach_f32_symmetric_bool(Scratch.next_lakitu_state_ref, Scratch.next_lakitu_state_goalDist[1], distVelocity)
		camera.sModeTransition.posDist = Scratch.next_lakitu_state_ref[1]
		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.posYaw
		camera.camera_approach_s16_symmetric_bool(Scratch.next_lakitu_state_ref, Scratch.next_lakitu_state_goalYaw[1], yawVelocity)
		camera.sModeTransition.posYaw = Scratch.next_lakitu_state_ref[1]
		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.posPitch
		camera.camera_approach_s16_symmetric_bool(Scratch.next_lakitu_state_ref, Scratch.next_lakitu_state_goalPitch[1], pitchVelocity)
		camera.sModeTransition.posPitch = Scratch.next_lakitu_state_ref[1]
		SrcEngineMathUtil.vec3f_set_dist_and_angle(curFoc, Scratch.next_lakitu_state_nextPos, camera.sModeTransition.posDist, camera.sModeTransition.posPitch, camera.sModeTransition.posYaw)

		SrcEngineMathUtil.vec3f_get_dist_and_angle(curPos, curFoc, Scratch.next_lakitu_state_goalDist, Scratch.next_lakitu_state_goalPitch, Scratch.next_lakitu_state_goalYaw)
		pitchVelocity = S16(math.modf(camera.sModeTransition.focPitch / S16(camera.sModeTransition.framesLeft)))
		yawVelocity = S16(math.modf(camera.sModeTransition.focYaw / camera.sModeTransition.framesLeft))
		distVelocity = F32(camera.sModeTransition.focDist / camera.sModeTransition.framesLeft)

		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.focPitch
		camera.camera_approach_s16_symmetric_bool(Scratch.next_lakitu_state_ref, Scratch.next_lakitu_state_goalPitch[1], pitchVelocity)
		camera.sModeTransition.focPitch = Scratch.next_lakitu_state_ref[1]
		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.focYaw
		camera.camera_approach_s16_symmetric_bool(Scratch.next_lakitu_state_ref, Scratch.next_lakitu_state_goalYaw[1], yawVelocity)
		camera.sModeTransition.focYaw = Scratch.next_lakitu_state_ref[1]
		Scratch.next_lakitu_state_ref[1] = camera.sModeTransition.focDist
		camera.camera_approach_f32_symmetric_bool(Scratch.next_lakitu_state_ref, 0, distVelocity)
		camera.sModeTransition.focDist = Scratch.next_lakitu_state_ref[1]
		SrcEngineMathUtil.vec3f_set_dist_and_angle(curFoc, Scratch.next_lakitu_state_nextFoc, camera.sModeTransition.focDist, camera.sModeTransition.focPitch, camera.sModeTransition.focYaw)

		SrcEngineMathUtil.vec3f_copy(newFoc, Scratch.next_lakitu_state_nextFoc)
		SrcEngineMathUtil.vec3f_copy(newPos, Scratch.next_lakitu_state_nextPos)

		if (camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene ~= 0 or not bit32.btest(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE) then
			local floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(newPos[1], newPos[2], newPos[3], Scratch.next_lakitu_state_floor)
			if floorHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
				floorHeight = F32(floorHeight + 125)
				if floorHeight > newPos[2] then
					newPos[2] = floorHeight
				end
			end
			Scratch.next_lakitu_state_x[1] = newPos[1]
			Scratch.next_lakitu_state_y[1] = newPos[2]
			Scratch.next_lakitu_state_z[1] = newPos[3]
			Registry.Members.src__engine__surface_collision.f32_find_wall_collision(Scratch.next_lakitu_state_x, Scratch.next_lakitu_state_y, Scratch.next_lakitu_state_z, 0, 100)
			newPos[1] = Scratch.next_lakitu_state_x[1]
			newPos[2] = Scratch.next_lakitu_state_y[1]
			newPos[3] = Scratch.next_lakitu_state_z[1]
		end
		camera.sModeTransition.framesLeft = S16(camera.sModeTransition.framesLeft - 1)
		yaw = camera.calculate_yaw(newFoc, newPos)
	else
		camera.sModeTransition.posDist = 0
		camera.sModeTransition.posPitch = 0
		camera.sModeTransition.posYaw = 0
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_TRANSITION_OUT_OF_C_UP)))
	end
	SrcEngineMathUtil.vec3f_copy(camera.sModeTransition.marioPos, camera.sMarioCamState.pos)
	return yaw
end

-- from src/game/camera.c:stop_transitional_movement L5489-5492
function camera.stop_transitional_movement()
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(bit32.bor(GroupsTypesHPlus3.CAM_FLAG_START_TRANSITION, GroupsTypesHPlus3.CAM_FLAG_TRANSITION_OUT_OF_C_UP))))
	camera.sModeTransition.framesLeft = 0
end

-- from src/game/camera.c:set_camera_mode_fixed L5499-5518
function camera.set_camera_mode_fixed(c: GroupsTypesHPlus3.Camera, x: number, y: number, z: number): number
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	local basePosSet = IncludePRUltratypesH.FALSE
	const posX = x
	const posY = y
	const posZ = z

	if camera.sFixedModeBasePosition[1] ~= posX or camera.sFixedModeBasePosition[2] ~= posY or camera.sFixedModeBasePosition[3] ~= posZ then
		basePosSet = IncludePRUltratypesH.TRUE
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	end
	SrcEngineMathUtil.vec3f_set(camera.sFixedModeBasePosition, posX, posY, posZ)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_FIXED
		SrcEngineMathUtil.vec3f_set(c.pos, camera.sFixedModeBasePosition[1], camera.sMarioCamState.pos[2], camera.sFixedModeBasePosition[3])
	end
	return basePosSet
end

-- from src/game/camera.c:set_camera_mode_8_directions L5520-5527
function camera.set_camera_mode_8_directions(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS then
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		camera.s8DirModeBaseYaw = 0
		camera.s8DirModeYawOffset = 0
	end
end

-- from src/game/camera.c:set_camera_mode_boss_fight L5533-5538
function camera.set_camera_mode_boss_fight(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BOSS_FIGHT then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_BOSS_FIGHT, 15)
		camera.sModeOffsetYaw = S16(c.nextYaw - GroupsTypesHPlus3.DEGREES(45))
	end
end

-- from src/game/camera.c:set_camera_mode_close_cam L5540-5545
function camera.set_camera_mode_close_cam(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
	end
end

-- from src/game/camera.c:set_camera_mode_radial L5552-5569
function camera.set_camera_mode_radial(c: GroupsTypesHPlus3.Camera, transitionTime: number)
	transitionTime = S16(TruncS32(transitionTime))
	Scratch.set_camera_mode_radial_focus[1] = c.areaCenX
	Scratch.set_camera_mode_radial_focus[2] = camera.sMarioCamState.pos[2]
	Scratch.set_camera_mode_radial_focus[3] = c.areaCenZ
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
		const yaw = S16(camera.calculate_yaw(Scratch.set_camera_mode_radial_focus, camera.sMarioCamState.pos) - camera.calculate_yaw(c.focus, c.pos) + GroupsTypesHPlus3.DEGREES(90))
		if yaw > 0 then
			camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_RADIAL, transitionTime)
		else
			c.mode = GroupsTypesHPlus3.CAMERA_MODE_RADIAL
			camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		end
		camera.sModeOffsetYaw = 0
	end
end

-- from src/game/camera.c:parallel_tracking_init L5574-5588
function camera.parallel_tracking_init(c: GroupsTypesHPlus3.Camera, path: { GroupsTypesHPlus3.ParallelTrackingPoint })
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_PARALLEL_TRACKING then
		camera.sParTrackPath = path
		camera.sParTrackIndex = 0
		camera.sParTrackTransOff.pos[1] = 0
		camera.sParTrackTransOff.pos[2] = 0
		camera.sParTrackTransOff.pos[3] = 0
		-- Place the camera in the middle of the path
		c.pos[1] = F32(F32(path[1].pos[1] + path[2].pos[1]) / 2)
		c.pos[2] = F32(F32(path[1].pos[2] + path[2].pos[2]) / 2)
		c.pos[3] = F32(F32(path[1].pos[3] + path[2].pos[3]) / 2)
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_PARALLEL_TRACKING
	end
end

-- from src/game/camera.c:set_fixed_cam_axis_sa_lobby L5593-5603
function camera.set_fixed_cam_axis_sa_lobby(preset: number)
	preset = S16(TruncS32(preset))
	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SA then
		SrcEngineMathUtil.vec3f_set(camera.sFixedModeBasePosition, 646, 143, -1513)
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CASTLE_LOBBY then
		SrcEngineMathUtil.vec3f_set(camera.sFixedModeBasePosition, -577, 143, 1443)
	end
end

-- from src/game/camera.c:check_blocking_area_processing L5614-5629
function camera.check_blocking_area_processing(mode: buffer)
	if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_METAL_WATER) or buffer.readu8(mode, 0) == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO or buffer.readu8(mode, 0) == GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	end

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_DDD or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_WDW or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_COTMC then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING)))
	end

	if (buffer.readu8(mode, 0) == GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO and not bit32.btest(camera.sMarioCamState.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER))) or buffer.readu8(mode, 0) == GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON then
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	end
end

-- from src/game/camera.c:cam_rr_exit_building_side L5631-5634
function camera.cam_rr_exit_building_side(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_8_directions(c)
	camera.s8DirModeBaseYaw = S16(GroupsTypesHPlus3.DEGREES(90))
end

-- from src/game/camera.c:cam_rr_exit_building_top L5636-5644
function camera.cam_rr_exit_building_top(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_8_directions(c)
	if c.pos[2] < 6343 then
		c.pos[2] = 7543
		camera.gLakituState.goalPos[2] = c.pos[2]
		camera.gLakituState.curPos[2] = c.pos[2]
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	end
end

-- from src/game/camera.c:cam_rr_enter_building_window L5646-5650
function camera.cam_rr_enter_building_window(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.set_camera_mode_fixed(c, -2974, 478, -3975)
	end
end

-- from src/game/camera.c:cam_rr_enter_building L5652-5660
function camera.cam_rr_enter_building(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.set_camera_mode_fixed(c, -2953, 798, -3943)
	end
	-- Prevent the camera from being above the roof
	if c.pos[2] > 6043 then
		c.pos[2] = 6043
	end
end

-- from src/game/camera.c:cam_rr_enter_building_side L5662-5667
function camera.cam_rr_enter_building_side(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_FIXED
	end
end

-- from src/game/camera.c:cam_cotmc_exit_waterfall L5672-5674
function camera.cam_cotmc_exit_waterfall(c: GroupsTypesHPlus3.Camera)
	camera.gCameraMovementFlags = S16(bit32.bor(camera.gCameraMovementFlags, GroupsTypesHPlus3.CAM_MOVE_FIX_IN_PLACE))
end

-- from src/game/camera.c:cam_sl_snowman_head_8dir L5680-5684
function camera.cam_sl_snowman_head_8dir(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS, 60)
	camera.s8DirModeBaseYaw = 0x1D27
end

-- from src/game/camera.c:cam_sl_free_roam L5690-5692
function camera.cam_sl_free_roam(c: GroupsTypesHPlus3.Camera)
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 60)
end

-- from src/game/camera.c:move_camera_through_floor_while_descending L5697-5706
function camera.move_camera_through_floor_while_descending(c: GroupsTypesHPlus3.Camera, height: number)
	height = F32(height)
	if camera.sMarioGeometry.currFloorHeight < F32(height - 100) and camera.sMarioGeometry.prevFloorHeight > camera.sMarioGeometry.currFloorHeight then
		c.pos[2] = F32(height - 400)
		camera.gLakituState.curPos[2] = F32(height - 400)
		camera.gLakituState.goalPos[2] = F32(height - 400)
	end
end

-- from src/game/camera.c:cam_hmc_enter_maze L5708-5722
function camera.cam_hmc_enter_maze(c: GroupsTypesHPlus3.Camera)
	if c.pos[2] > -102 then
		SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, camera.gLakituState.goalPos, Scratch.cam_hmc_enter_maze_dist, Scratch.cam_hmc_enter_maze_pitch, Scratch.cam_hmc_enter_maze_yaw)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, camera.gLakituState.goalPos, 300, Scratch.cam_hmc_enter_maze_pitch[1], Scratch.cam_hmc_enter_maze_yaw[1])
		camera.gLakituState.goalPos[2] = -800

		c.pos[2] = camera.gLakituState.goalPos[2]
		camera.gLakituState.curPos[2] = camera.gLakituState.goalPos[2]

		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	end
end

-- from src/game/camera.c:cam_hmc_elevator_black_hole L5724-5726
function camera.cam_hmc_elevator_black_hole(c: GroupsTypesHPlus3.Camera)
	camera.move_camera_through_floor_while_descending(c, 1536)
end

-- from src/game/camera.c:cam_hmc_elevator_maze_emergency_exit L5728-5730
function camera.cam_hmc_elevator_maze_emergency_exit(c: GroupsTypesHPlus3.Camera)
	camera.move_camera_through_floor_while_descending(c, 2355)
end

-- from src/game/camera.c:cam_hmc_elevator_lake L5732-5734
function camera.cam_hmc_elevator_lake(c: GroupsTypesHPlus3.Camera)
	camera.move_camera_through_floor_while_descending(c, 1843)
end

-- from src/game/camera.c:cam_hmc_elevator_maze L5736-5738
function camera.cam_hmc_elevator_maze(c: GroupsTypesHPlus3.Camera)
	camera.move_camera_through_floor_while_descending(c, 1843)
end

-- from src/game/camera.c:cam_ssl_enter_pyramid_top L5743-5745
function camera.cam_ssl_enter_pyramid_top(c: GroupsTypesHPlus3.Camera)
	camera.start_object_cutscene_without_focus(GroupsTypesHPlus3.CUTSCENE_ENTER_PYRAMID_TOP)
end

-- from src/game/camera.c:cam_ssl_pyramid_center L5751-5754
function camera.cam_ssl_pyramid_center(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 90)
end

-- from src/game/camera.c:cam_ssl_boss_room L5759-5762
function camera.cam_ssl_boss_room(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL, 90)
end

-- from src/game/camera.c:cam_thi_move_cam_through_tunnel L5767-5771
function camera.cam_thi_move_cam_through_tunnel(c: GroupsTypesHPlus3.Camera)
	if camera.sModeOffsetYaw < GroupsTypesHPlus3.DEGREES(60) then
		camera.sModeOffsetYaw = S16(GroupsTypesHPlus3.DEGREES(60))
	end
end

-- from src/game/camera.c:cam_thi_look_through_tunnel L5776-5781
function camera.cam_thi_look_through_tunnel(c: GroupsTypesHPlus3.Camera)
	-- ~82.5 degrees
	if camera.sModeOffsetYaw > 0x3AAA then
		camera.sModeOffsetYaw = 0x3AAA
	end
end

-- from src/game/camera.c:cam_bob_tower L5788-5791
function camera.cam_bob_tower(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING))
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_RADIAL, 90)
end

-- from src/game/camera.c:cam_bob_default_free_roam L5801-5803
function camera.cam_bob_default_free_roam(c: GroupsTypesHPlus3.Camera)
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 90)
end

-- from src/game/camera.c:cam_castle_hmc_start_pool_cutscene L5809-5814
function camera.cam_castle_hmc_start_pool_cutscene(c: GroupsTypesHPlus3.Camera)
	if camera.sMarioCamState.action ~= IncludeSm64H.ACT_SPECIAL_DEATH_EXIT and camera.sMarioCamState.action ~= IncludeSm64H.ACT_SPECIAL_EXIT_AIRBORNE then
		camera.start_cutscene(c, GroupsTypesHPlus3.CUTSCENE_ENTER_POOL)
	end
end

-- from src/game/camera.c:cam_castle_lobby_entrance L5820-5823
function camera.cam_castle_lobby_entrance(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCastleEntranceOffset, F32(-813 - camera.sFixedModeBasePosition[1]), F32(378 - camera.sFixedModeBasePosition[2]), F32(1103 - camera.sFixedModeBasePosition[3]))
end

-- from src/game/camera.c:cam_castle_look_upstairs L5828-5837
function camera.cam_castle_look_upstairs(c: GroupsTypesHPlus3.Camera)
	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], c.pos[2], c.pos[3], Scratch.cam_castle_look_upstairs_floor)

	-- If Mario is on the first few steps, fix the camera pos, making it look up
	if camera.sMarioGeometry.currFloorHeight > 1229 and floorHeight < 1229 and camera.sCSideButtonYaw == 0 then
		SrcEngineMathUtil.vec3f_set(c.pos, -227, 1425, 1533)
	end
end

-- from src/game/camera.c:cam_castle_basement_look_downstairs L5842-5850
function camera.cam_castle_basement_look_downstairs(c: GroupsTypesHPlus3.Camera)
	const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], c.pos[2], c.pos[3], Scratch.cam_castle_basement_look_downstairs_floor)

	-- Fix the camera pos, making it look downwards. Only active on the top few steps
	if floorHeight > -110 and camera.sCSideButtonYaw == 0 then
		SrcEngineMathUtil.vec3f_set(c.pos, -980, 249, -1398)
	end
end

-- from src/game/camera.c:cam_castle_enter_lobby L5856-5862
function camera.cam_castle_enter_lobby(c: GroupsTypesHPlus3.Camera)
	if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
		camera.set_fixed_cam_axis_sa_lobby(c.mode)
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_FIXED
	end
end

-- from src/game/camera.c:cam_castle_enter_spiral_stairs L5867-5869
function camera.cam_castle_enter_spiral_stairs(c: GroupsTypesHPlus3.Camera)
	camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_SPIRAL_STAIRS, 20)
end

-- from src/game/camera.c:cam_castle_leave_spiral_stairs L5875-5881
function camera.cam_castle_leave_spiral_stairs(c: GroupsTypesHPlus3.Camera)
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_SPIRAL_STAIRS then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 30)
	else
		camera.set_camera_mode_close_cam(c)
	end
end

-- from src/game/camera.c:cam_castle_close_mode L5887-5889
function camera.cam_castle_close_mode(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_close_cam(c)
end

-- from src/game/camera.c:cam_castle_leave_lobby_sliding_door L5895-5898
function camera.cam_castle_leave_lobby_sliding_door(c: GroupsTypesHPlus3.Camera)
	camera.cam_castle_close_mode(c)
	c.doorStatus = GroupsTypesHPlus3.DOOR_ENTER_LOBBY
end

-- from src/game/camera.c:cam_castle_enter_lobby_sliding_door L5903-5905
function camera.cam_castle_enter_lobby_sliding_door(c: GroupsTypesHPlus3.Camera)
	camera.cam_castle_enter_lobby(c)
end

-- from src/game/camera.c:cam_bbh_room_6 L5907-5909
function camera.cam_bbh_room_6(c: GroupsTypesHPlus3.Camera)
	camera.parallel_tracking_init(c, camera.sBBHLibraryParTrackPath)
end

-- from src/game/camera.c:cam_bbh_fall_off_roof L5911-5913
function camera.cam_bbh_fall_off_roof(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_close_cam(c)
end

-- from src/game/camera.c:cam_bbh_fall_into_pool L5915-5923
function camera.cam_bbh_fall_into_pool(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_close_cam(c)
	SrcEngineMathUtil.vec3f_set(Scratch.cam_bbh_fall_into_pool_dir, 0, 0, 300)
	camera.offset_rotated(camera.gLakituState.goalPos, camera.sMarioCamState.pos, Scratch.cam_bbh_fall_into_pool_dir, camera.sMarioCamState.faceAngle)
	camera.gLakituState.goalPos[2] = -2300
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.gLakituState.goalPos)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
end

-- from src/game/camera.c:cam_bbh_room_1 L5925-5927
function camera.cam_bbh_room_1(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 956, 440, 1994)
end

-- from src/game/camera.c:cam_bbh_leave_front_door L5929-5932
function camera.cam_bbh_leave_front_door(c: GroupsTypesHPlus3.Camera)
	c.doorStatus = GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL
	camera.cam_bbh_room_1(c)
end

-- from src/game/camera.c:cam_bbh_room_2_lower L5934-5936
function camera.cam_bbh_room_2_lower(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 2591, 400, 1284)
end

-- from src/game/camera.c:cam_bbh_room_4 L5938-5940
function camera.cam_bbh_room_4(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 3529, 340, -1384)
end

-- from src/game/camera.c:cam_bbh_room_8 L5942-5944
function camera.cam_bbh_room_8(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, -500, 740, -1306)
end

-- from src/game/camera.c:cam_bbh_room_5_library L5950-5952
function camera.cam_bbh_room_5_library(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, -2172, 200, 675)
end

-- from src/game/camera.c:cam_bbh_room_5_library_to_hidden_transition L5959-5963
function camera.cam_bbh_room_5_library_to_hidden_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, -2172, 200, 675) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_5_hidden_to_library_transition L5965-5969
function camera.cam_bbh_room_5_hidden_to_library_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, -1542, 320, -307) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_5_hidden L5971-5974
function camera.cam_bbh_room_5_hidden(c: GroupsTypesHPlus3.Camera)
	c.doorStatus = GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL
	camera.set_camera_mode_fixed(c, -1542, 320, -307)
end

-- from src/game/camera.c:cam_bbh_room_3 L5976-5978
function camera.cam_bbh_room_3(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, -1893, 320, 2327)
end

-- from src/game/camera.c:cam_bbh_room_7_mr_i L5980-5982
function camera.cam_bbh_room_7_mr_i(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 1371, 360, -1302)
end

-- from src/game/camera.c:cam_bbh_room_7_mr_i_to_coffins_transition L5984-5988
function camera.cam_bbh_room_7_mr_i_to_coffins_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, 1371, 360, -1302) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_7_coffins_to_mr_i_transition L5990-5994
function camera.cam_bbh_room_7_coffins_to_mr_i_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, 2115, 260, -772) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_elevator_room_lower L5996-5999
function camera.cam_bbh_elevator_room_lower(c: GroupsTypesHPlus3.Camera)
	c.doorStatus = GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL
	camera.set_camera_mode_close_cam(c)
end

-- from src/game/camera.c:cam_bbh_room_0_back_entrance L6001-6003
function camera.cam_bbh_room_0_back_entrance(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_close_cam(c)
end

-- from src/game/camera.c:cam_bbh_elevator L6005-6011
function camera.cam_bbh_elevator(c: GroupsTypesHPlus3.Camera)
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		camera.set_camera_mode_close_cam(c)
		c.pos[2] = -405
		camera.gLakituState.goalPos[2] = -405
	end
end

-- from src/game/camera.c:cam_bbh_room_12_upper L6013-6016
function camera.cam_bbh_room_12_upper(c: GroupsTypesHPlus3.Camera)
	c.doorStatus = GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL
	camera.set_camera_mode_fixed(c, -2932, 296, 4429)
end

-- from src/game/camera.c:cam_bbh_enter_front_door L6018-6020
function camera.cam_bbh_enter_front_door(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_close_cam(c)
end

-- from src/game/camera.c:cam_bbh_room_2_library L6022-6024
function camera.cam_bbh_room_2_library(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 3493, 440, 617)
end

-- from src/game/camera.c:cam_bbh_room_2_library_to_trapdoor_transition L6026-6030
function camera.cam_bbh_room_2_library_to_trapdoor_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, 3493, 440, 617) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_2_trapdoor L6032-6034
function camera.cam_bbh_room_2_trapdoor(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 3502, 440, 1217)
end

-- from src/game/camera.c:cam_bbh_room_2_trapdoor_transition L6036-6040
function camera.cam_bbh_room_2_trapdoor_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, 3502, 440, 1217) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_9_attic L6042-6044
function camera.cam_bbh_room_9_attic(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, -670, 460, 372)
end

-- from src/game/camera.c:cam_bbh_room_9_attic_transition L6046-6050
function camera.cam_bbh_room_9_attic_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, -670, 460, 372) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_9_mr_i_transition L6052-6056
function camera.cam_bbh_room_9_mr_i_transition(c: GroupsTypesHPlus3.Camera)
	if camera.set_camera_mode_fixed(c, 131, 380, -263) == 1 then
		camera.transition_next_state(c, 20)
	end
end

-- from src/game/camera.c:cam_bbh_room_13_balcony L6058-6060
function camera.cam_bbh_room_13_balcony(c: GroupsTypesHPlus3.Camera)
	camera.set_camera_mode_fixed(c, 210, 420, 3109)
end

-- from src/game/camera.c:cam_bbh_room_0 L6062-6065
function camera.cam_bbh_room_0(c: GroupsTypesHPlus3.Camera)
	c.doorStatus = GroupsTypesHPlus3.DOOR_LEAVING_SPECIAL
	camera.set_camera_mode_fixed(c, -204, 807, 204)
end

-- from src/game/camera.c:cam_ccm_enter_slide_shortcut L6067-6069
function camera.cam_ccm_enter_slide_shortcut(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CCM_SLIDE_SHORTCUT))
end

-- from src/game/camera.c:cam_ccm_leave_slide_shortcut L6071-6073
function camera.cam_ccm_leave_slide_shortcut(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_CCM_SLIDE_SHORTCUT)))
end

-- from src/game/camera.c:surface_type_modes L6078-6098
function camera.surface_type_modes(c: GroupsTypesHPlus3.Camera): number
	local modeChanged = 0

	if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CLOSE_CAMERA then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 90)
		modeChanged = U32(modeChanged + 1)
	elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_FREE_ROAM then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 90)
		modeChanged = U32(modeChanged + 1)
	elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_SLIPPERY then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 90)
		modeChanged = U32(modeChanged + 1)
	end
	return modeChanged
end

-- from src/game/camera.c:set_mode_if_not_set_by_surface L6103-6112
function camera.set_mode_if_not_set_by_surface(c: GroupsTypesHPlus3.Camera, mode: number): number
	mode = U8(TruncS32(mode))
	const modeChanged = camera.surface_type_modes(c)

	if modeChanged == 0 and mode ~= 0 then
		camera.transition_to_camera_mode(c, mode, 90)
	end

	return modeChanged
end

-- from src/game/camera.c:surface_type_modes_thi L6117-6144
function camera.surface_type_modes_thi(c: GroupsTypesHPlus3.Camera)
	if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CLOSE_CAMERA then
		if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
			camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 90)
		end
	elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_FREE_ROAM then
		if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
			camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 90)
		end
	elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_NO_CAM_COL_SLIPPERY then
		if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
			camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 90)
		end
	elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_8_DIR then
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS, 90)
	else
		camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_RADIAL, 90)
	end
end


-- from src/game/camera.c:camera_course_processing L6505-6682
function camera.camera_course_processing(c: GroupsTypesHPlus3.Camera): number
	local level = Area.gCurrLevelNum
	local mode = 0
	const area = S8((Area.gCurrentArea :: GroupsTypesHPlus3.Area).index)
	-- Bounds iterator
	local b = 0
	local insideBounds = IncludePRUltratypesH.FALSE
	const oldMode = U8(c.mode)

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_C_UP then
		c.mode = U8(camera.sModeInfo.lastMode)
	end
	buffer.writeu8(Scratch.camera_course_processing_mode, 0, c.mode)
	camera.check_blocking_area_processing(Scratch.camera_course_processing_mode)
	if level > IncludeLevelTableH.LEVEL_COUNT + 1 then
		level = IncludeLevelTableH.LEVEL_COUNT + 1
	end

	const triggers = camera.sCameraTriggers[level + 1]
	if triggers ~= nil then
		b = 0

		-- Process positional triggers.
		-- All triggered events are called, not just the first one.
		while triggers[b + 1].event ~= nil do
			const event = triggers[b + 1].event :: (GroupsTypesHPlus3.Camera) -> ()

			-- Check only the current area's triggers
			if triggers[b + 1].area == area then
				-- Copy the bounding box into center and bounds
				SrcEngineMathUtil.vec3f_set(Scratch.camera_course_processing_center, triggers[b + 1].centerX, triggers[b + 1].centerY, triggers[b + 1].centerZ)
				SrcEngineMathUtil.vec3f_set(Scratch.camera_course_processing_bounds, triggers[b + 1].boundsX, triggers[b + 1].boundsY, triggers[b + 1].boundsZ)

				-- Check if Mario is inside the bounds
				if camera.is_pos_in_bounds(camera.sMarioCamState.pos, Scratch.camera_course_processing_center, Scratch.camera_course_processing_bounds, triggers[b + 1].boundsYaw) == IncludePRUltratypesH.TRUE then
					-- ! This should be checked before calling is_pos_in_bounds. (It does not belong
					-- ! outside the while loop because some events disable area processing)
					if not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING) then
						event(c)
						insideBounds = IncludePRUltratypesH.TRUE
					end
				end
			end

			if triggers[b + 1].area == -1 then
				-- Default triggers are only active if Mario is not already inside another trigger
				if insideBounds == 0 then
					if not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING) then
						event(c)
					end
				end
			end

			b = U32(b + 1)
		end
	end

	-- Area-specific camera processing
	if not bit32.btest(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING) then
		if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WF then
			if camera.sMarioCamState.action == IncludeSm64H.ACT_RIDING_HOOT then
				camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_SLIDE_HOOT, 60)
			else
				if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_CAMERA_8_DIR then
					camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS, 90)
					camera.s8DirModeBaseYaw = S16(GroupsTypesHPlus3.DEGREES(90))
				elseif camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_BOSS_FIGHT_CAMERA then
					if Area.gCurrActNum == 1 then
						camera.set_camera_mode_boss_fight(c)
					else
						camera.set_camera_mode_radial(c, 60)
					end
				else
					camera.set_camera_mode_radial(c, 60)
				end
			end
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BBH then
			-- if camera is fixed at bbh_room_13_balcony_camera (but as floats)
			if camera.vec3f_compare(camera.sFixedModeBasePosition, 210, 420, 3109) == IncludePRUltratypesH.TRUE then
				if camera.sMarioCamState.pos[2] < 1800 then
					camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_CLOSE, 30)
				end
			end
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_PYRAMID then
			camera.set_mode_if_not_set_by_surface(c, GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL)
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_OUTSIDE then
			camera.set_mode_if_not_set_by_surface(c, GroupsTypesHPlus3.CAMERA_MODE_RADIAL)
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_HUGE then
			-- no area-specific processing
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_TINY then
			camera.surface_type_modes_thi(c)
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTC then
			camera.set_mode_if_not_set_by_surface(c, GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL)
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BOB then
			if camera.set_mode_if_not_set_by_surface(c, GroupsTypesHPlus3.CAMERA_MODE_NONE) == 0 then
				if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_BOSS_FIGHT_CAMERA then
					camera.set_camera_mode_boss_fight(c)
				else
					if c.mode == GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
						camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_RADIAL, 60)
					else
						camera.set_camera_mode_radial(c, 60)
					end
				end
			end
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_MAIN then
			if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_WARP_1B then
				c.defMode = GroupsTypesHPlus3.CAMERA_MODE_RADIAL
			end
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_TOWN then
			if camera.sMarioGeometry.currFloorType == IncludeSurfaceTerrainsH.SURFACE_INSTANT_WARP_1C then
				c.defMode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
			end
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_DDD_WHIRLPOOL then
			-- ! @bug this does nothing
			camera.gLakituState.defMode = GroupsTypesHPlus3.CAMERA_MODE_OUTWARD_RADIAL
		elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_DDD_SUB then
			if c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_BEHIND_MARIO and c.mode ~= GroupsTypesHPlus3.CAMERA_MODE_WATER_SURFACE then
				if bit32.btest(camera.sMarioCamState.action, IncludeSm64H.ACT_FLAG_ON_POLE) or camera.sMarioGeometry.currFloorHeight > 800 then
					camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_8_DIRECTIONS, 60)
				else
					if camera.sMarioCamState.pos[2] < 800 then
						camera.transition_to_camera_mode(c, GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM, 60)
					end
				end
			end
			-- ! @bug this does nothing
			camera.gLakituState.defMode = GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM
		end
	end

	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_AREA_PROCESSING)))
	if oldMode == GroupsTypesHPlus3.CAMERA_MODE_C_UP then
		camera.sModeInfo.lastMode = c.mode
		c.mode = oldMode
	end
	mode = c.mode
	return mode
end

-- from src/game/camera.c:resolve_geometry_collisions L6688-6722
function camera.resolve_geometry_collisions(pos: { number }, lastGood: { number })
	local ceilY: number
	local floorY: number

	Scratch.resolve_geometry_collisions_x[1] = pos[1]
	Scratch.resolve_geometry_collisions_y[1] = pos[2]
	Scratch.resolve_geometry_collisions_z[1] = pos[3]
	Registry.Members.src__engine__surface_collision.f32_find_wall_collision(Scratch.resolve_geometry_collisions_x, Scratch.resolve_geometry_collisions_y, Scratch.resolve_geometry_collisions_z, 0, 100)
	pos[1] = Scratch.resolve_geometry_collisions_x[1]
	pos[2] = Scratch.resolve_geometry_collisions_y[1]
	pos[3] = Scratch.resolve_geometry_collisions_z[1]
	floorY = Registry.Members.src__engine__surface_collision.find_floor(pos[1], F32(pos[2] + 50), pos[3], Scratch.resolve_geometry_collisions_surf)
	ceilY = Registry.Members.src__engine__surface_collision.find_ceil(pos[1], F32(pos[2] - 50), pos[3], Scratch.resolve_geometry_collisions_surf)

	if SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT ~= floorY and SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT == ceilY then
		floorY = F32(floorY + 125)
		if pos[2] < floorY then
			pos[2] = floorY
		end
	end

	if SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT == floorY and SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT ~= ceilY then
		ceilY = F32(ceilY - 125)
		if pos[2] > ceilY then
			pos[2] = ceilY
		end
	end

	if SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT ~= floorY and SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT ~= ceilY then
		floorY = F32(floorY + 125)
		ceilY = F32(ceilY - 125)

		if pos[2] <= floorY and pos[2] < ceilY then
			pos[2] = floorY
		end
		if pos[2] > floorY and pos[2] >= ceilY then
			pos[2] = ceilY
		end
		if pos[2] <= floorY and pos[2] >= ceilY then
			pos[2] = F32(F32(floorY + ceilY) * 0.5)
		end
	end
end

-- from src/game/camera.c:rotate_camera_around_walls L6735-6822
function camera.rotate_camera_around_walls(c: GroupsTypesHPlus3.Camera, cPos: { number }, avoidYaw: { number }, yawRange: number): number
	yawRange = S16(TruncS32(yawRange))
	local status = 0
	-- The current iteration. The algorithm takes 8 equal steps from Mario back to the camera.
	local step = 0

	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, cPos, Scratch.rotate_camera_around_walls_dummyDist, Scratch.rotate_camera_around_walls_dummyPitch, Scratch.rotate_camera_around_walls_yawFromMario)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_CAM_NEAR_WALL)))
	Scratch.rotate_camera_around_walls_colData.offsetY = 100
	-- The distance from Mario to Lakitu
	local checkDist = 0
	-- The radius used to find potential walls to avoid.
	-- @bug Increases to 250.f, but the max collision radius is 200.f
	Scratch.rotate_camera_around_walls_coarseRadius[1] = 150
	-- This only increases when there is a wall collision found in the coarse pass
	Scratch.rotate_camera_around_walls_fineRadius[1] = 100

	while step < 8 do
		-- Start at Mario, move backwards to Lakitu's position
		Scratch.rotate_camera_around_walls_colData.x = F32(camera.sMarioCamState.pos[1] + F32(F32(cPos[1] - camera.sMarioCamState.pos[1]) * checkDist))
		Scratch.rotate_camera_around_walls_colData.y = F32(camera.sMarioCamState.pos[2] + F32(F32(cPos[2] - camera.sMarioCamState.pos[2]) * checkDist))
		Scratch.rotate_camera_around_walls_colData.z = F32(camera.sMarioCamState.pos[3] + F32(F32(cPos[3] - camera.sMarioCamState.pos[3]) * checkDist))
		Scratch.rotate_camera_around_walls_colData.radius = Scratch.rotate_camera_around_walls_coarseRadius[1]
		-- Increase the coarse check radius
		camera.camera_approach_f32_symmetric_bool(Scratch.rotate_camera_around_walls_coarseRadius, 250, 30)

		const coarseCount: number = Registry.Members.src__engine__surface_collision.find_wall_collisions(Scratch.rotate_camera_around_walls_colData)
		if coarseCount ~= 0 then
			local wall = Scratch.rotate_camera_around_walls_colData.walls[Scratch.rotate_camera_around_walls_colData.numWalls] :: GroupsTypesHPlus3.Surface

			-- If we're over halfway from Mario to Lakitu, then there's a wall near the camera, but
			-- not necessarily obstructing Mario
			if step >= 5 then
				camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_CAM_NEAR_WALL))
				if status <= 0 then
					status = 1
					wall = Scratch.rotate_camera_around_walls_colData.walls[Scratch.rotate_camera_around_walls_colData.numWalls] :: GroupsTypesHPlus3.Surface
					-- wallYaw is parallel to the wall, not perpendicular
					const wallYaw = S16(SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x) + GroupsTypesHPlus3.DEGREES(90))
					-- Calculate the avoid direction. The function returns the opposite direction so add 180
					-- degrees.
					avoidYaw[1] = S16(camera.calc_avoid_yaw(Scratch.rotate_camera_around_walls_yawFromMario[1], wallYaw) + GroupsTypesHPlus3.DEGREES(180))
				end
			end

			Scratch.rotate_camera_around_walls_colData.x = F32(camera.sMarioCamState.pos[1] + F32(F32(cPos[1] - camera.sMarioCamState.pos[1]) * checkDist))
			Scratch.rotate_camera_around_walls_colData.y = F32(camera.sMarioCamState.pos[2] + F32(F32(cPos[2] - camera.sMarioCamState.pos[2]) * checkDist))
			Scratch.rotate_camera_around_walls_colData.z = F32(camera.sMarioCamState.pos[3] + F32(F32(cPos[3] - camera.sMarioCamState.pos[3]) * checkDist))
			Scratch.rotate_camera_around_walls_colData.radius = Scratch.rotate_camera_around_walls_fineRadius[1]
			-- Increase the fine check radius
			camera.camera_approach_f32_symmetric_bool(Scratch.rotate_camera_around_walls_fineRadius, 200, 20)

			const fineCount: number = Registry.Members.src__engine__surface_collision.find_wall_collisions(Scratch.rotate_camera_around_walls_colData)
			if fineCount ~= 0 then
				wall = Scratch.rotate_camera_around_walls_colData.walls[Scratch.rotate_camera_around_walls_colData.numWalls] :: GroupsTypesHPlus3.Surface
				const horWallNorm = SrcEngineMathUtil.atan2s(wall.normal.z, wall.normal.x)
				const wallYaw = S16(horWallNorm + GroupsTypesHPlus3.DEGREES(90))
				-- If Mario would be blocked by the surface, then avoid it
				if camera.is_range_behind_surface(camera.sMarioCamState.pos, cPos, wall, yawRange, IncludeSurfaceTerrainsH.SURFACE_WALL_MISC) == 0 and camera.is_mario_behind_surface(c, wall) == IncludePRUltratypesH.TRUE and camera.is_surf_within_bounding_box(wall, -1, 150, -1) == IncludePRUltratypesH.FALSE then -- Also check if the wall is tall enough to cover Mario
					-- Calculate the avoid direction. The function returns the opposite direction so add 180
					-- degrees.
					avoidYaw[1] = S16(camera.calc_avoid_yaw(Scratch.rotate_camera_around_walls_yawFromMario[1], wallYaw) + GroupsTypesHPlus3.DEGREES(180))
					camera.camera_approach_s16_symmetric_bool(avoidYaw, horWallNorm, yawRange)
					status = 3
					step = 8
				end
			end
		end
		checkDist = F32(checkDist + 0.125)
		step += 1
	end

	return status
end

-- from src/game/camera.c:find_mario_floor_and_ceil L6829-6857
function camera.find_mario_floor_and_ceil(pg: GroupsTypesHPlus3.PlayerGeometry)
	const tempCheckingSurfaceCollisionsForCamera = ObjectListProcessor.gCheckingSurfaceCollisionsForCamera
	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.TRUE

	const floorResult: number = Registry.Members.src__engine__surface_collision.find_floor(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 10), camera.sMarioCamState.pos[3], Scratch.find_mario_floor_and_ceil_surf)
	if floorResult ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		pg.currFloorType = (Scratch.find_mario_floor_and_ceil_surf[1] :: GroupsTypesHPlus3.Surface).type_
	else
		pg.currFloorType = 0
	end

	const ceilResult: number = Registry.Members.src__engine__surface_collision.find_ceil(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] - 10), camera.sMarioCamState.pos[3], Scratch.find_mario_floor_and_ceil_surf)
	if ceilResult ~= SrcEngineSurfaceCollisionH.CELL_HEIGHT_LIMIT then
		pg.currCeilType = (Scratch.find_mario_floor_and_ceil_surf[1] :: GroupsTypesHPlus3.Surface).type_
	else
		pg.currCeilType = 0
	end

	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = IncludePRUltratypesH.FALSE
	const currFloorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 10), camera.sMarioCamState.pos[3], Scratch.find_mario_floor_and_ceil_surf)
	pg.currFloor = Scratch.find_mario_floor_and_ceil_surf[1]
	pg.currFloorHeight = currFloorHeight
	const currCeilHeight: number = Registry.Members.src__engine__surface_collision.find_ceil(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] - 10), camera.sMarioCamState.pos[3], Scratch.find_mario_floor_and_ceil_surf)
	pg.currCeil = Scratch.find_mario_floor_and_ceil_surf[1]
	pg.currCeilHeight = currCeilHeight
	pg.waterHeight = Registry.Members.src__engine__surface_collision.find_water_level(camera.sMarioCamState.pos[1], camera.sMarioCamState.pos[3])
	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = tempCheckingSurfaceCollisionsForCamera
end

-- from src/game/camera.c:start_object_cutscene L6863-6868
function camera.start_object_cutscene(cutscene: number, o: GroupsTypesHPlus3.Object)
	cutscene = U8(TruncS32(cutscene))
	camera.sObjectCutscene = cutscene
	camera.gRecentCutscene = 0
	camera.gCutsceneFocus = o
	camera.gObjCutsceneDone = IncludePRUltratypesH.FALSE
end

-- from src/game/camera.c:start_object_cutscene_without_focus L6874-6878
function camera.start_object_cutscene_without_focus(cutscene: number): number
	cutscene = U8(TruncS32(cutscene))
	camera.sObjectCutscene = cutscene
	camera.sCutsceneDialogResponse = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE
	return 0
end

-- from src/game/camera.c:unused_dialog_cutscene_response L6880-6892
function camera.unused_dialog_cutscene_response(cutscene: number): number
	cutscene = U8(TruncS32(cutscene))
	-- if not in a cutscene, start this one
	if (camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene == 0 and camera.sObjectCutscene == 0 then
		camera.sObjectCutscene = cutscene
	end

	-- if playing this cutscene and Mario responded, return the response
	if (camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene == cutscene and camera.sCutsceneDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
		return camera.sCutsceneDialogResponse
	else
		return 0
	end
end

-- from src/game/camera.c:cutscene_object_with_dialog L6894-6912
function camera.cutscene_object_with_dialog(cutscene: number, o: GroupsTypesHPlus3.Object, dialogID: number): number
	cutscene = U8(TruncS32(cutscene))
	dialogID = S16(TruncS32(dialogID))
	local response = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE

	if (camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene == 0 and camera.sObjectCutscene == 0 then
		if camera.gRecentCutscene ~= cutscene then
			camera.start_object_cutscene(cutscene, o)
			if dialogID ~= IncludeDialogIdsH.DIALOG_NONE then
				camera.sCutsceneDialogID = dialogID
			else
				camera.sCutsceneDialogID = IncludeDialogIdsH.DIALOG_001
			end
		else
			response = camera.sCutsceneDialogResponse
		end

		camera.gRecentCutscene = 0
	end
	return response
end

-- from src/game/camera.c:cutscene_object_without_dialog L6914-6917
function camera.cutscene_object_without_dialog(cutscene: number, o: GroupsTypesHPlus3.Object): number
	cutscene = U8(TruncS32(cutscene))
	const response = camera.cutscene_object_with_dialog(cutscene, o, IncludeDialogIdsH.DIALOG_NONE)

	return response
end

-- from src/game/camera.c:cutscene_object L6922-6934
function camera.cutscene_object(cutscene: number, o: GroupsTypesHPlus3.Object): number
	cutscene = U8(TruncS32(cutscene))
	local status = 0

	if (camera.gCamera :: GroupsTypesHPlus3.Camera).cutscene == 0 and camera.sObjectCutscene == 0 then
		if camera.gRecentCutscene ~= cutscene then
			camera.start_object_cutscene(cutscene, o)
			status = 1
		else
			status = -1
		end
	end
	return status
end

-- from src/game/camera.c:update_camera_yaw L6939-6942
function camera.update_camera_yaw(c: GroupsTypesHPlus3.Camera)
	c.nextYaw = camera.calculate_yaw(c.focus, c.pos)
	c.yaw = c.nextYaw
end

-- from src/game/camera.c:cutscene_reset_spline L6944-6947
function camera.cutscene_reset_spline()
	camera.sCutsceneSplineSegment = 0
	camera.sCutsceneSplineSegmentProgress = 0
end

-- from src/game/camera.c:stop_cutscene_and_retrieve_stored_info L6949-6954
function camera.stop_cutscene_and_retrieve_stored_info(c: GroupsTypesHPlus3.Camera)
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	c.cutscene = 0
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCameraStoreCutscene.focus)
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCameraStoreCutscene.pos)
end

-- from src/game/camera.c:cap_switch_save L6956-6959
function camera.cap_switch_save(dummy: number)
	dummy = S16(TruncS32(dummy))
	SaveFile.save_file_do_save(Area.gCurrSaveFileNum - 1)
end

-- from src/game/camera.c:init_spline_point L6961-6965
function camera.init_spline_point(splinePoint: GroupsTypesHPlus3.CutsceneSplinePoint, index: number, speed: number, point: { number })
	index = S8(TruncS32(index))
	speed = U8(TruncS32(speed))
	splinePoint.index = index
	splinePoint.speed = speed
	SrcEngineMathUtil.vec3s_copy(splinePoint.point, point)
end

-- from src/game/camera.c:copy_spline_segment L6968-6988
function camera.copy_spline_segment(dst: { GroupsTypesHPlus3.CutsceneSplinePoint }, src: { GroupsTypesHPlus3.CutsceneSplinePoint })
	local j = 0
	local i = 0

	camera.init_spline_point(dst[i + 1], src[j + 1].index, src[j + 1].speed, src[j + 1].point)
	i += 1
	repeat
		repeat
			camera.init_spline_point(dst[i + 1], src[j + 1].index, src[j + 1].speed, src[j + 1].point)
			i += 1
			j += 1
		until not (src[j + 1].index ~= -1) -- ! the C performs this comparison twice
	until not (j > 16)

	-- Create the end of the spline by duplicating the last point
	camera.init_spline_point(dst[i + 1], 0, src[j + 1].speed, src[j + 1].point)
	camera.init_spline_point(dst[i + 2], 0, 0, src[j + 1].point)
	camera.init_spline_point(dst[i + 3], 0, 0, src[j + 1].point)
	camera.init_spline_point(dst[i + 4], -1, 0, src[j + 1].point)
end

-- from src/game/camera.c:cutscene_common_set_dialog_state L6997-7004
function camera.cutscene_common_set_dialog_state(state: number): number
	local timer = camera.gCutsceneTimer
	-- If the dialog ended, return CUTSCENE_LOOP, which would end the cutscene shot
	if MarioActionsCutscene.set_mario_npc_dialog(state) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
		timer = GroupsTypesHPlus3.CUTSCENE_LOOP
	end
	return timer
end

-- from src/game/camera.c:unused_cutscene_mario_dialog_looking_down L7007-7009
function camera.unused_cutscene_mario_dialog_looking_down(c: GroupsTypesHPlus3.Camera)
	camera.gCutsceneTimer = camera.cutscene_common_set_dialog_state(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_DOWN)
end

-- from src/game/camera.c:cutscene_mario_dialog L7014-7016
function camera.cutscene_mario_dialog(c: GroupsTypesHPlus3.Camera)
	camera.gCutsceneTimer = camera.cutscene_common_set_dialog_state(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT)
end

-- from src/game/camera.c:unused_cutscene_mario_dialog_looking_up L7019-7021
function camera.unused_cutscene_mario_dialog_looking_up(c: GroupsTypesHPlus3.Camera)
	camera.gCutsceneTimer = camera.cutscene_common_set_dialog_state(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP)
end

-- from src/game/camera.c:cutscene_intro_peach_start_letter_music L7026-7031
function camera.cutscene_intro_peach_start_letter_music(c: GroupsTypesHPlus3.Camera)
	Audio.seq_player_lower_volume(0, 60, 40)
	camera.cutscene_intro_peach_play_message_music()
end

-- from src/game/camera.c:cutscene_intro_peach_start_flying_music L7036-7041
function camera.cutscene_intro_peach_start_flying_music(c: GroupsTypesHPlus3.Camera)
	Audio.seq_player_unlower_volume(0, 60)
	camera.cutscene_intro_peach_play_lakitu_flying_music()
end

-- from src/game/camera.c:reset_pan_distance L7053-7055
function camera.reset_pan_distance(c: GroupsTypesHPlus3.Camera)
	camera.sPanDistance = 0
end

-- from src/game/camera.c:player2_rotate_cam L7060-7102
function camera.player2_rotate_cam(c: GroupsTypesHPlus3.Camera, minPitch: number, maxPitch: number, minYaw: number, maxYaw: number)
	minPitch = S16(TruncS32(minPitch))
	maxPitch = S16(TruncS32(maxPitch))
	minYaw = S16(TruncS32(minYaw))
	maxYaw = S16(TruncS32(maxYaw))
	-- Change the camera rotation to match the 2nd player's stick
	Scratch.player2_rotate_cam_sCreditsPlayer2Yaw[1] = camera.sCreditsPlayer2Yaw
	camera.approach_s16_asymptotic_bool(Scratch.player2_rotate_cam_sCreditsPlayer2Yaw, S16(-S16(TruncS32(F32(GameInit.gPlayer2Controller.stickX * 250)))), 4)
	camera.sCreditsPlayer2Yaw = Scratch.player2_rotate_cam_sCreditsPlayer2Yaw[1]
	Scratch.player2_rotate_cam_sCreditsPlayer2Pitch[1] = camera.sCreditsPlayer2Pitch
	camera.approach_s16_asymptotic_bool(Scratch.player2_rotate_cam_sCreditsPlayer2Pitch, S16(-S16(TruncS32(F32(GameInit.gPlayer2Controller.stickY * 265)))), 4)
	camera.sCreditsPlayer2Pitch = Scratch.player2_rotate_cam_sCreditsPlayer2Pitch[1]
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, c.focus, Scratch.player2_rotate_cam_distCamToFocus, Scratch.player2_rotate_cam_pitch, Scratch.player2_rotate_cam_yaw)

	local pitchCap = S16(0x3800 - Scratch.player2_rotate_cam_pitch[1])
	if pitchCap < 0 then
		pitchCap = 0
	end
	if maxPitch > pitchCap then
		maxPitch = pitchCap
	end

	pitchCap = S16(-0x3800 - Scratch.player2_rotate_cam_pitch[1])
	if pitchCap > 0 then
		pitchCap = 0
	end
	if minPitch < pitchCap then
		minPitch = pitchCap
	end

	if camera.sCreditsPlayer2Pitch > maxPitch then
		camera.sCreditsPlayer2Pitch = maxPitch
	end
	if camera.sCreditsPlayer2Pitch < minPitch then
		camera.sCreditsPlayer2Pitch = minPitch
	end

	if camera.sCreditsPlayer2Yaw > maxYaw then
		camera.sCreditsPlayer2Yaw = maxYaw
	end
	if camera.sCreditsPlayer2Yaw < minYaw then
		camera.sCreditsPlayer2Yaw = minYaw
	end

	Scratch.player2_rotate_cam_pitch[1] = S16(Scratch.player2_rotate_cam_pitch[1] + camera.sCreditsPlayer2Pitch)
	Scratch.player2_rotate_cam_yaw[1] = S16(Scratch.player2_rotate_cam_yaw[1] + camera.sCreditsPlayer2Yaw)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, camera.sPlayer2FocusOffset, Scratch.player2_rotate_cam_distCamToFocus[1], Scratch.player2_rotate_cam_pitch[1], Scratch.player2_rotate_cam_yaw[1])
	camera.vec3f_sub(camera.sPlayer2FocusOffset, c.focus)
end

-- from src/game/camera.c:store_info_cannon L7107-7112
function camera.store_info_cannon(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCutscene.pos, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCutscene.focus, c.focus)
	camera.sCameraStoreCutscene.panDist = camera.sPanDistance
	camera.sCameraStoreCutscene.cannonYOffset = camera.sCannonYOffset
end

-- from src/game/camera.c:retrieve_info_cannon L7117-7122
function camera.retrieve_info_cannon(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCameraStoreCutscene.pos)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCameraStoreCutscene.focus)
	camera.sPanDistance = camera.sCameraStoreCutscene.panDist
	camera.sCannonYOffset = camera.sCameraStoreCutscene.cannonYOffset
end

-- from src/game/camera.c:store_info_star L7127-7133
function camera.store_info_star(c: GroupsTypesHPlus3.Camera)
	camera.reset_pan_distance(c)
	SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCutscene.pos, c.pos)
	camera.sCameraStoreCutscene.focus[1] = camera.sMarioCamState.pos[1]
	camera.sCameraStoreCutscene.focus[2] = c.focus[2]
	camera.sCameraStoreCutscene.focus[3] = camera.sMarioCamState.pos[3]
end

-- from src/game/camera.c:retrieve_info_star L7138-7141
function camera.retrieve_info_star(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCameraStoreCutscene.pos)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCameraStoreCutscene.focus)
end

-- from src/game/camera.c:unused_vec3s_to_vec3f L7143-7147
function camera.unused_vec3s_to_vec3f(dst: { number }, src: { number })
	dst[1] = src[1]
	dst[2] = src[2]
	dst[3] = src[3]
end

-- from src/game/camera.c:unused_vec3f_to_vec3s L7149-7155
function camera.unused_vec3f_to_vec3s(dst: { number }, src: { number })
	-- note: unlike vec3f_to_vec3s(), this function doesn't round the numbers and instead simply
	-- truncates them
	dst[1] = S16(TruncS32(src[1]))
	dst[2] = S16(TruncS32(src[2]))
	dst[3] = S16(TruncS32(src[3]))
end

-- from src/game/camera.c:pan_camera L7160-7168
function camera.pan_camera(c: GroupsTypesHPlus3.Camera, incPitch: number, incYaw: number)
	incPitch = S16(TruncS32(incPitch))
	incYaw = S16(TruncS32(incYaw))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, c.focus, Scratch.pan_camera_distCamToFocus, Scratch.pan_camera_pitch, Scratch.pan_camera_yaw)
	Scratch.pan_camera_pitch[1] = S16(Scratch.pan_camera_pitch[1] + incPitch)
	Scratch.pan_camera_yaw[1] = S16(Scratch.pan_camera_yaw[1] + incYaw)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, c.focus, Scratch.pan_camera_distCamToFocus[1], Scratch.pan_camera_pitch[1], Scratch.pan_camera_yaw[1])
end

-- from src/game/camera.c:cutscene_shake_explosion L7170-7173
function camera.cutscene_shake_explosion(c: GroupsTypesHPlus3.Camera)
	camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_EXPLOSION)
	camera.cutscene_set_fov_shake_preset(1)
end

-- from src/game/camera.c:unused_start_bowser_bounce_shake L7175-7177
function camera.unused_start_bowser_bounce_shake(c: GroupsTypesHPlus3.Camera)
	camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_BOWSER_THROW_BOUNCE)
end

-- from src/game/camera.c:rotate_and_move_vec3f L7185-7194
function camera.rotate_and_move_vec3f(to: { number }, from: { number }, incDist: number, incPitch: number, incYaw: number)
	incDist = F32(incDist)
	incPitch = S16(TruncS32(incPitch))
	incYaw = S16(TruncS32(incYaw))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(from, to, Scratch.rotate_and_move_vec3f_dist, Scratch.rotate_and_move_vec3f_pitch, Scratch.rotate_and_move_vec3f_yaw)
	Scratch.rotate_and_move_vec3f_pitch[1] = S16(Scratch.rotate_and_move_vec3f_pitch[1] + incPitch)
	Scratch.rotate_and_move_vec3f_yaw[1] = S16(Scratch.rotate_and_move_vec3f_yaw[1] + incYaw)
	Scratch.rotate_and_move_vec3f_dist[1] = F32(Scratch.rotate_and_move_vec3f_dist[1] + incDist)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(from, to, Scratch.rotate_and_move_vec3f_dist[1], Scratch.rotate_and_move_vec3f_pitch[1], Scratch.rotate_and_move_vec3f_yaw[1])
end

-- from src/game/camera.c:set_flag_post_door L7196-7199
function camera.set_flag_post_door(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BEHIND_MARIO_POST_DOOR))
	camera.sCameraYawAfterDoorCutscene = camera.calculate_yaw(c.focus, c.pos)
end

-- from src/game/camera.c:cutscene_soften_music L7201-7203
function camera.cutscene_soften_music(c: GroupsTypesHPlus3.Camera)
	Audio.seq_player_lower_volume(0, 60, 40)
end

-- from src/game/camera.c:cutscene_unsoften_music L7205-7207
function camera.cutscene_unsoften_music(c: GroupsTypesHPlus3.Camera)
	Audio.seq_player_unlower_volume(0, 60)
end

-- from src/game/camera.c:stub_camera_5 L7209-7210
function camera.stub_camera_5(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_unused_start L7212-7213
function camera.cutscene_unused_start(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_unused_loop L7215-7216
function camera.cutscene_unused_loop(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_ending_mario_fall_start L7221-7224
function camera.cutscene_ending_mario_fall_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(c.focus, -26, 0, -137)
	SrcEngineMathUtil.vec3f_set(c.pos, 165, 4725, 324)
end

-- from src/game/camera.c:cutscene_ending_mario_fall_focus_mario L7229-7239
function camera.cutscene_ending_mario_fall_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_ending_mario_fall_focus_mario_offset, 0, 80, 0)

	Scratch.cutscene_ending_mario_fall_focus_mario_offset[3] = F32(GroupsTypesHPlus3.ABS(F32(camera.sMarioCamState.pos[2] - c.pos[2])) * F32(-0.1))
	if Scratch.cutscene_ending_mario_fall_focus_mario_offset[3] > -100 then
		Scratch.cutscene_ending_mario_fall_focus_mario_offset[3] = -100
	end

	camera.offset_rotated(c.focus, camera.sMarioCamState.pos, Scratch.cutscene_ending_mario_fall_focus_mario_offset, camera.sMarioCamState.faceAngle)
end

-- from src/game/camera.c:cutscene_ending_mario_fall L7244-7248
function camera.cutscene_ending_mario_fall(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_mario_fall_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_mario_fall_focus_mario, c, 0, -1)
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_mario_land_closeup L7253-7257
function camera.cutscene_ending_mario_land_closeup(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(c.focus, 85, 826, 250)
	SrcEngineMathUtil.vec3f_set(c.pos, -51, 988, -202)
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_reset_spline L7262-7265
function camera.cutscene_ending_reset_spline(c: GroupsTypesHPlus3.Camera)
	camera.sCutsceneVars[10].point[1] = 0
	camera.cutscene_reset_spline()
end

-- from src/game/camera.c:cutscene_ending_fly_up_to_window L7270-7273
function camera.cutscene_ending_fly_up_to_window(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.sEndingFlyToWindowPos, Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment, Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress[1]
	Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sEndingFlyToWindowFocus, Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment, Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_fly_up_to_window_sCutsceneSplineSegmentProgress[1]
end

-- from src/game/camera.c:cutscene_ending_stars_free_peach L7278-7282
function camera.cutscene_ending_stars_free_peach(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_reset_spline, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_fly_up_to_window, c, 0, -1)
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_mario_land L7287-7291
function camera.cutscene_ending_mario_land(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(c.focus, camera.sEndingFlyToWindowFocus[1].point[1], F32(camera.sEndingFlyToWindowFocus[1].point[2] + 80), camera.sEndingFlyToWindowFocus[1].point[3])
	SrcEngineMathUtil.vec3f_set(c.pos, camera.sEndingFlyToWindowPos[1].point[1], camera.sEndingFlyToWindowPos[1].point[2], F32(camera.sEndingFlyToWindowPos[1].point[3] + 150))
	camera.player2_rotate_cam(c, -0x800, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_peach_appear_closeup L7296-7300
function camera.cutscene_ending_peach_appear_closeup(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	SrcEngineMathUtil.vec3f_set(c.pos, 179, 2463, -1216)
	c.pos[2] = F32(buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY) + 35)
	SrcEngineMathUtil.vec3f_set(c.focus, buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosX), F32(buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY) + 125), buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/camera.c:cutscene_ending_peach_appears L7305-7310
function camera.cutscene_ending_peach_appears(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	camera.cutscene_event(camera.cutscene_ending_peach_appear_closeup, c, 0, 0)
	Scratch.cutscene_ending_peach_appears_pos[1] = c.pos[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_ending_peach_appears_pos, F32(buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY) + 35), F32(0.02))
	c.pos[2] = Scratch.cutscene_ending_peach_appears_pos[1]
	Scratch.cutscene_ending_peach_appears_focus[1] = c.focus[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_ending_peach_appears_focus, F32(buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY) + 125), F32(0.15))
	c.focus[2] = Scratch.cutscene_ending_peach_appears_focus[1]
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_peach_descends_start L7315-7318
function camera.cutscene_ending_peach_descends_start(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_reset_spline()
	camera.sCutsceneVars[3].point[2] = 150
end

-- from src/game/camera.c:cutscene_ending_follow_peach_descent L7323-7326
function camera.cutscene_ending_follow_peach_descent(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	Scratch.cutscene_ending_follow_peach_descent_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_follow_peach_descent_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.sEndingPeachDescentCamPos, Scratch.cutscene_ending_follow_peach_descent_segment, Scratch.cutscene_ending_follow_peach_descent_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_follow_peach_descent_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_follow_peach_descent_progress[1]
	c.pos[2] = F32(c.pos[2] + F32(buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY) + camera.sCutsceneVars[4].point[2]))
end

-- from src/game/camera.c:cutscene_ending_peach_descent_lower_focus L7331-7333
function camera.cutscene_ending_peach_descent_lower_focus(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_ending_peach_descent_lower_focus_point[1] = camera.sCutsceneVars[3].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_ending_peach_descent_lower_focus_point, 90, F32(0.5))
	camera.sCutsceneVars[3].point[2] = Scratch.cutscene_ending_peach_descent_lower_focus_point[1]
end

-- from src/game/camera.c:cutscene_ending_peach_descent_back_to_mario L7338-7345
function camera.cutscene_ending_peach_descent_back_to_mario(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	Scratch.cutscene_ending_peach_descent_back_to_mario_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_peach_descent_back_to_mario_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(Scratch.cutscene_ending_peach_descent_back_to_mario_pos, camera.sEndingPeachDescentCamPos, Scratch.cutscene_ending_peach_descent_back_to_mario_segment, Scratch.cutscene_ending_peach_descent_back_to_mario_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_peach_descent_back_to_mario_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_peach_descent_back_to_mario_progress[1]
	c.pos[1] = Scratch.cutscene_ending_peach_descent_back_to_mario_pos[1]
	c.pos[3] = Scratch.cutscene_ending_peach_descent_back_to_mario_pos[3]
	Scratch.cutscene_ending_peach_descent_back_to_mario_pos[2] = F32(Scratch.cutscene_ending_peach_descent_back_to_mario_pos[2] + buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY))
	Scratch.cutscene_ending_peach_descent_back_to_mario_posY[1] = c.pos[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_ending_peach_descent_back_to_mario_posY, Scratch.cutscene_ending_peach_descent_back_to_mario_pos[2], F32(0.07))
	c.pos[2] = Scratch.cutscene_ending_peach_descent_back_to_mario_posY[1]
end

-- from src/game/camera.c:cutscene_ending_peach_descends L7351-7359
function camera.cutscene_ending_peach_descends(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	camera.cutscene_event(camera.cutscene_ending_peach_descends_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_follow_peach_descent, c, 0, 299)
	camera.cutscene_event(camera.cutscene_ending_peach_descent_back_to_mario, c, 300, -1)
	camera.cutscene_event(camera.cutscene_ending_peach_descent_lower_focus, c, 300, -1)
	SrcEngineMathUtil.vec3f_set(c.focus, buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosX), F32(camera.sCutsceneVars[3].point[2] + buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosY)), buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosZ))
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_mario_to_peach L7365-7370
function camera.cutscene_ending_mario_to_peach(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_reset_spline, c, 0, 0)
	Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.sEndingMarioToPeachPos, Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment, Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress[1]
	Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sEndingMarioToPeachFocus, Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment, Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_mario_to_peach_sCutsceneSplineSegmentProgress[1]
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_look_up_at_castle L7375-7377
function camera.cutscene_ending_look_up_at_castle(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sEndingLookUpAtCastle, Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegment, Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_look_up_at_castle_sCutsceneSplineSegmentProgress[1]
end

-- from src/game/camera.c:cutscene_ending_peach_wakeup L7382-7396
function camera.cutscene_ending_peach_wakeup(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_reset_spline, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_look_up_at_castle, c, 0, 0)

	camera.cutscene_event(camera.cutscene_ending_look_up_at_castle, c, 250, -1)
	camera.cutscene_spawn_obj(7, 300)
	camera.cutscene_spawn_obj(9, 340)

	SrcEngineMathUtil.vec3f_set(c.pos, -163, 978, -1082)
	camera.player2_rotate_cam(c, -0x800, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_dialog L7401-7405
function camera.cutscene_ending_dialog(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(c.focus, 11, 983, -1273)
	SrcEngineMathUtil.vec3f_set(c.pos, -473, 970, -1152)
	camera.player2_rotate_cam(c, -0x800, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_kiss_closeup L7410-7414
function camera.cutscene_ending_kiss_closeup(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_SET_29)
	SrcEngineMathUtil.vec3f_set(c.focus, 350, 1034, -1216)
	SrcEngineMathUtil.vec3f_set(c.pos, -149, 1021, -1216)
end

-- from src/game/camera.c:cutscene_ending_kiss_here_we_go L7419-7428
function camera.cutscene_ending_kiss_here_we_go(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_ending_kiss_here_we_go_foc, 233, 1068, -1298)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_ending_kiss_here_we_go_pos, -250, 966, -1111)
	-- another double typo
	camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_ending_kiss_here_we_go_pos, F32(0.2), F32(0.1), F32(0.2))
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_ending_kiss_here_we_go_foc, F32(0.2), F32(0.1), F32(0.2))
end

-- from src/game/camera.c:cutscene_ending_kiss L7433-7441
function camera.cutscene_ending_kiss(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_kiss_closeup, c, 0, 0)

	camera.cutscene_event(camera.cutscene_ending_kiss_here_we_go, c, 155, -1)

	camera.player2_rotate_cam(c, -0x800, 0x2000, -0x2000, 0x2000)
end

-- from src/game/camera.c:cutscene_ending_look_at_sky L7446-7449
function camera.cutscene_ending_look_at_sky(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sEndingLookAtSkyFocus, Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegment, Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_ending_look_at_sky_sCutsceneSplineSegmentProgress[1]
	SrcEngineMathUtil.vec3f_set(c.pos, 699, 1680, -703)
end

-- from src/game/camera.c:cutscene_ending_zoom_fov L7455-7457
function camera.cutscene_ending_zoom_fov(c: GroupsTypesHPlus3.Camera)
	camera.sFOVState.fov = 37
end

-- from src/game/camera.c:cutscene_ending_cake_for_mario L7462-7471
function camera.cutscene_ending_cake_for_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_ending_reset_spline, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_look_at_sky, c, 0, 0)
	camera.cutscene_event(camera.cutscene_ending_zoom_fov, c, 0, 499)
	camera.cutscene_event(camera.cutscene_ending_look_at_sky, c, 500, -1)
	camera.cutscene_spawn_obj(8, 600)
	camera.cutscene_spawn_obj(8, 608)
	camera.cutscene_spawn_obj(8, 624)
	camera.cutscene_spawn_obj(8, 710)
end

-- from src/game/camera.c:cutscene_ending_stop L7476-7480
function camera.cutscene_ending_stop(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_SET_45)
	c.cutscene = 0
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
end

-- from src/game/camera.c:cutscene_grand_star_start L7487-7491
function camera.cutscene_grand_star_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[1].point, 0, 150, -600)
	camera.offset_rotated(camera.sCutsceneVars[2].point, camera.sMarioCamState.pos, camera.sCutsceneVars[1].point, camera.sMarioCamState.faceAngle)
	camera.sCutsceneVars[2].point[2] = 457
end

-- from src/game/camera.c:cutscene_grand_star_front_of_mario L7496-7508
function camera.cutscene_grand_star_front_of_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, camera.sCutsceneVars[2].point, Scratch.cutscene_grand_star_front_of_mario_goalDist, Scratch.cutscene_grand_star_front_of_mario_goalPitch, Scratch.cutscene_grand_star_front_of_mario_goalYaw)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_grand_star_front_of_mario_dist, Scratch.cutscene_grand_star_front_of_mario_pitch, Scratch.cutscene_grand_star_front_of_mario_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_grand_star_front_of_mario_dist, Scratch.cutscene_grand_star_front_of_mario_goalDist[1], F32(0.1))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_grand_star_front_of_mario_pitch, Scratch.cutscene_grand_star_front_of_mario_goalPitch[1], 32)
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_grand_star_front_of_mario_yaw, S16(Scratch.cutscene_grand_star_front_of_mario_goalYaw[1] + 0x1200), 20)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_grand_star_front_of_mario_dist[1], Scratch.cutscene_grand_star_front_of_mario_pitch[1], Scratch.cutscene_grand_star_front_of_mario_yaw[1])
end

-- from src/game/camera.c:cutscene_grand_star_mario_jump L7513-7516
function camera.cutscene_grand_star_mario_jump(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3s_set(camera.sCutsceneVars[1].angle, 0, camera.sMarioCamState.faceAngle[2], 0)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[3].point, 0, 0, 0)
end

-- from src/game/camera.c:cutscene_grand_star_accel_cvar2 L7521-7524
function camera.cutscene_grand_star_accel_cvar2(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_grand_star_accel_cvar2_value[1] = camera.sCutsceneVars[3].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_accel_cvar2_value, -40, 2)
	camera.sCutsceneVars[3].point[3] = Scratch.cutscene_grand_star_accel_cvar2_value[1]
	camera.sCutsceneVars[3].point[1] = 5
end

-- from src/game/camera.c:cutscene_grand_star_approach_mario L7529-7534
function camera.cutscene_grand_star_approach_mario(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_grand_star_approach_mario_value[1] = camera.sCutsceneVars[3].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_approach_mario_value, 0, 2)
	camera.sCutsceneVars[3].point[3] = Scratch.cutscene_grand_star_approach_mario_value[1]
	camera.sCutsceneVars[3].point[1] = 0
	Scratch.cutscene_grand_star_approach_mario_value[1] = c.pos[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_grand_star_approach_mario_value, camera.sMarioCamState.pos[1], F32(0.01))
	c.pos[1] = Scratch.cutscene_grand_star_approach_mario_value[1]
	Scratch.cutscene_grand_star_approach_mario_value[1] = c.pos[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_grand_star_approach_mario_value, camera.sMarioCamState.pos[3], F32(0.01))
	c.pos[3] = Scratch.cutscene_grand_star_approach_mario_value[1]
end

-- from src/game/camera.c:cutscene_grand_star_move_cvar2 L7540-7542
function camera.cutscene_grand_star_move_cvar2(c: GroupsTypesHPlus3.Camera)
	camera.offset_rotated(c.pos, c.pos, camera.sCutsceneVars[3].point, camera.sCutsceneVars[1].angle)
end

-- from src/game/camera.c:cutscene_grand_star_focus_mario L7544-7549
function camera.cutscene_grand_star_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_grand_star_focus_mario_foc, camera.sMarioCamState.pos[1], F32(F32(F32(camera.sMarioCamState.pos[2] - 307) * 0.5) + 407), camera.sMarioCamState.pos[3])
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_grand_star_focus_mario_foc, 0.5, F32(0.8), 0.5)
end

-- from src/game/camera.c:cutscene_grand_star L7554-7563
function camera.cutscene_grand_star(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.cutscene_event(camera.cutscene_grand_star_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_grand_star_front_of_mario, c, 0, 109)
	camera.cutscene_event(camera.cutscene_grand_star_focus_mario, c, 0, -1)
	camera.cutscene_event(camera.cutscene_grand_star_mario_jump, c, 110, 110)
	camera.cutscene_event(camera.cutscene_grand_star_accel_cvar2, c, 110, 159)
	camera.cutscene_event(camera.cutscene_grand_star_approach_mario, c, 160, -1)
	camera.cutscene_event(camera.cutscene_grand_star_move_cvar2, c, 110, -1)
end

-- from src/game/camera.c:cutscene_grand_star_fly_start L7568-7577
function camera.cutscene_grand_star_fly_start(c: GroupsTypesHPlus3.Camera)
	-- ! cvar7 is unused in grand star
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[8].point, 0.5, 0.5, 0.5)
	-- ! cvar6 is unused in grand star
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[7].point, F32(0.01), F32(0.01), F32(0.01))
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[5].point, 0, 0, 0)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 0, F32(c.focus[2] - camera.sMarioCamState.pos[2]), 0)
	camera.sCutsceneVars[9].point[3] = 0
	camera.sCutsceneVars[9].point[1] = 0
end

-- from src/game/camera.c:cutscene_grand_star_fly_move_to_mario L7582-7589
function camera.cutscene_grand_star_fly_move_to_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_grand_star_fly_move_to_mario_posOff, -600, 0, -400)
	camera.approach_vec3f_asymptotic(camera.sCutsceneVars[5].point, Scratch.cutscene_grand_star_fly_move_to_mario_posOff, F32(0.05), F32(0.05), F32(0.05))
	Scratch.cutscene_grand_star_fly_move_to_mario_value[1] = camera.sCutsceneVars[6].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_move_to_mario_value, 0, 2)
	camera.sCutsceneVars[6].point[2] = Scratch.cutscene_grand_star_fly_move_to_mario_value[1]
	Scratch.cutscene_grand_star_fly_move_to_mario_value[1] = camera.sCutsceneVars[6].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_move_to_mario_value, -200, 6)
	camera.sCutsceneVars[6].point[3] = Scratch.cutscene_grand_star_fly_move_to_mario_value[1]
end

-- from src/game/camera.c:cutscene_grand_star_fly_mario_offscreen L7598-7608
function camera.cutscene_grand_star_fly_mario_offscreen(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[9].point[1]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 15, F32(0.1))
	camera.sCutsceneVars[9].point[1] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]

	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[5].point[1]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, -2000, camera.sCutsceneVars[9].point[1])
	camera.sCutsceneVars[5].point[1] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]
	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[5].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 1200, F32(camera.sCutsceneVars[9].point[1] / 10))
	camera.sCutsceneVars[5].point[2] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]
	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[5].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 1000, F32(camera.sCutsceneVars[9].point[1] / 10))
	camera.sCutsceneVars[5].point[3] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]

	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[6].point[1]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 0, camera.sCutsceneVars[9].point[1])
	camera.sCutsceneVars[6].point[1] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]
	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[6].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 1200, F32(camera.sCutsceneVars[9].point[1] / 2))
	camera.sCutsceneVars[6].point[2] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]
	Scratch.cutscene_grand_star_fly_mario_offscreen_point[1] = camera.sCutsceneVars[6].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_mario_offscreen_point, 1000, F32(camera.sCutsceneVars[9].point[1] / F32(1.5)))
	camera.sCutsceneVars[6].point[3] = Scratch.cutscene_grand_star_fly_mario_offscreen_point[1]
end

-- from src/game/camera.c:cutscene_grand_star_fly_app_cvars L7615-7631
function camera.cutscene_grand_star_fly_app_cvars(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_grand_star_fly_app_cvars_point[1] = camera.sCutsceneVars[9].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_app_cvars_point, 90, 2.5)
	camera.sCutsceneVars[9].point[3] = Scratch.cutscene_grand_star_fly_app_cvars_point[1]
	camera.offset_rotated(Scratch.cutscene_grand_star_fly_app_cvars_goalPos, camera.sMarioCamState.pos, camera.sCutsceneVars[5].point, camera.sMarioCamState.faceAngle)
	camera.offset_rotated(Scratch.cutscene_grand_star_fly_app_cvars_goalFoc, camera.sMarioCamState.pos, camera.sCutsceneVars[6].point, camera.sMarioCamState.faceAngle)

	-- Move towards goalPos by cvar8's Z speed
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.cutscene_grand_star_fly_app_cvars_goalPos, c.pos, Scratch.cutscene_grand_star_fly_app_cvars_dist, Scratch.cutscene_grand_star_fly_app_cvars_pitch, Scratch.cutscene_grand_star_fly_app_cvars_yaw)
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_grand_star_fly_app_cvars_dist, 0, camera.sCutsceneVars[9].point[3])
	SrcEngineMathUtil.vec3f_set_dist_and_angle(Scratch.cutscene_grand_star_fly_app_cvars_goalPos, c.pos, Scratch.cutscene_grand_star_fly_app_cvars_dist[1], Scratch.cutscene_grand_star_fly_app_cvars_pitch[1], Scratch.cutscene_grand_star_fly_app_cvars_yaw[1])

	camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_grand_star_fly_app_cvars_goalPos, F32(0.01), F32(0.01), F32(0.01))
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_grand_star_fly_app_cvars_goalFoc, 0.5, F32(0.8), 0.5)
end

-- from src/game/camera.c:cutscene_grand_star_fly L7642-7648
function camera.cutscene_grand_star_fly(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.cutscene_event(camera.cutscene_grand_star_fly_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_grand_star_fly_move_to_mario, c, 0, 140)
	camera.cutscene_event(camera.cutscene_grand_star_fly_mario_offscreen, c, 141, -1)
	camera.cutscene_event(camera.cutscene_grand_star_fly_app_cvars, c, 0, -1)
end

-- from src/game/camera.c:focus_in_front_of_mario L7655-7664
function camera.focus_in_front_of_mario(c: GroupsTypesHPlus3.Camera, dist: number, speed: number)
	dist = F32(dist)
	speed = F32(speed)
	Scratch.focus_in_front_of_mario_offset[1] = 0
	Scratch.focus_in_front_of_mario_offset[3] = dist
	Scratch.focus_in_front_of_mario_offset[2] = 100

	camera.offset_rotated(Scratch.focus_in_front_of_mario_goalFocus, camera.sMarioCamState.pos, Scratch.focus_in_front_of_mario_offset, camera.sMarioCamState.faceAngle)
	camera.approach_vec3f_asymptotic(c.focus, Scratch.focus_in_front_of_mario_goalFocus, speed, speed, speed)
end

-- from src/game/camera.c:cutscene_dance_move_to_mario L7670-7678
function camera.cutscene_dance_move_to_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_move_to_mario_dist, Scratch.cutscene_dance_move_to_mario_pitch, Scratch.cutscene_dance_move_to_mario_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dance_move_to_mario_dist, 600, F32(0.3))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_move_to_mario_pitch, 0x1000, 0x10)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_move_to_mario_dist[1], Scratch.cutscene_dance_move_to_mario_pitch[1], Scratch.cutscene_dance_move_to_mario_yaw[1])
end

-- from src/game/camera.c:cutscene_dance_rotate L7680-7682
function camera.cutscene_dance_rotate(c: GroupsTypesHPlus3.Camera)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, 0, 0, 0x200)
end

-- from src/game/camera.c:cutscene_dance_rotate_move_back L7684-7686
function camera.cutscene_dance_rotate_move_back(c: GroupsTypesHPlus3.Camera)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, -15, 0, 0)
end

-- from src/game/camera.c:cutscene_dance_rotate_move_towards_mario L7688-7690
function camera.cutscene_dance_rotate_move_towards_mario(c: GroupsTypesHPlus3.Camera)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, 20, 0, 0)
end

-- from src/game/camera.c:cutscene_dance_unused L7695-7696
function camera.cutscene_dance_unused(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_dance_default_focus_mario L7701-7703
function camera.cutscene_dance_default_focus_mario(c: GroupsTypesHPlus3.Camera)
	camera.focus_in_front_of_mario(c, -100, F32(0.2))
end

-- from src/game/camera.c:cutscene_dance_rotate_focus_mario L7708-7710
function camera.cutscene_dance_rotate_focus_mario(c: GroupsTypesHPlus3.Camera)
	camera.focus_in_front_of_mario(c, -200, F32(0.03))
end

-- from src/game/camera.c:cutscene_dance_shake_fov L7712-7714
function camera.cutscene_dance_shake_fov(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_shake(0x200, 0x28, S16(0x8000))
end

-- from src/game/camera.c:cutscene_dance_default_rotate L7721-7747
function camera.cutscene_dance_default_rotate(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sYawSpeed = 0
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	camera.cutscene_event(camera.cutscene_dance_default_focus_mario, c, 0, 20)
	camera.cutscene_event(camera.cutscene_dance_move_to_mario, c, 0, 39)
	-- Shake the camera on the 4th beat of the music, when Mario gives the peace sign.
	camera.cutscene_event(camera.cutscene_dance_shake_fov, c, 40, 40)

	if c.cutscene ~= GroupsTypesHPlus3.CUTSCENE_DANCE_DEFAULT then -- CUTSCENE_DANCE_ROTATE
		camera.cutscene_event(camera.cutscene_dance_rotate_focus_mario, c, 75, 102)
		camera.cutscene_event(camera.cutscene_dance_rotate, c, 50, -1)
		-- These two functions move the camera away and then towards Mario.
		camera.cutscene_event(camera.cutscene_dance_rotate_move_back, c, 50, 80)
		camera.cutscene_event(camera.cutscene_dance_rotate_move_towards_mario, c, 70, 90)
	else
		-- secret star, 100 coin star, or bowser red coin star.
		if camera.sMarioCamState.action ~= IncludeSm64H.ACT_STAR_DANCE_NO_EXIT and camera.sMarioCamState.action ~= IncludeSm64H.ACT_STAR_DANCE_WATER and camera.sMarioCamState.action ~= IncludeSm64H.ACT_STAR_DANCE_EXIT then
			camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
			c.cutscene = 0
			camera.transition_next_state(c, 20)
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
		end
	end
end

-- from src/game/camera.c:star_dance_bound_yaw L7752-7769
function camera.star_dance_bound_yaw(c: GroupsTypesHPlus3.Camera, absYaw: number, yawMax: number)
	absYaw = S16(TruncS32(absYaw))
	yawMax = S16(TruncS32(yawMax))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.star_dance_bound_yaw_distCamToMario, Scratch.star_dance_bound_yaw_dummyPitch, Scratch.star_dance_bound_yaw_yaw)
	local yawFromAbs = S16(Scratch.star_dance_bound_yaw_yaw[1] - absYaw)

	-- Because angles are s16, this checks if yaw is negative
	if bit32.btest(yawFromAbs, 0x8000) then
		yawFromAbs = S16(-yawFromAbs)
	end
	if yawFromAbs > yawMax then
		Scratch.star_dance_bound_yaw_yaw[1] = absYaw
		c.nextYaw = Scratch.star_dance_bound_yaw_yaw[1]
		c.yaw = Scratch.star_dance_bound_yaw_yaw[1]
	end
end

-- from src/game/camera.c:cutscene_dance_closeup_start L7775-7791
function camera.cutscene_dance_closeup_start(c: GroupsTypesHPlus3.Camera)
	if SaveFile.gLastCompletedStarNum == 4 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_JRB then
		camera.star_dance_bound_yaw(c, 0x0, 0x4000)
	end
	if SaveFile.gLastCompletedStarNum == 1 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_DDD then
		camera.star_dance_bound_yaw(c, S16(0x8000), 0x5000)
	end
	if SaveFile.gLastCompletedStarNum == 5 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_WDW then
		camera.star_dance_bound_yaw(c, S16(0x8000), 0x800)
	end

	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[10].point, c.focus)
	-- ! cvar8 is unused in the closeup cutscene
	camera.sCutsceneVars[9].angle[1] = 0x2000
end

-- from src/game/camera.c:cutscene_dance_closeup_focus_mario L7796-7802
function camera.cutscene_dance_closeup_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_dance_closeup_focus_mario_marioPos, camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 125), camera.sMarioCamState.pos[3])
	camera.approach_vec3f_asymptotic(camera.sCutsceneVars[10].point, Scratch.cutscene_dance_closeup_focus_mario_marioPos, F32(0.2), F32(0.2), F32(0.2))
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[10].point)
end

-- from src/game/camera.c:cutscene_dance_closeup_fly_above L7807-7822
function camera.cutscene_dance_closeup_fly_above(c: GroupsTypesHPlus3.Camera)
	local goalPitch = 0x1800

	if (SaveFile.gLastCompletedStarNum == 6 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_SL) or (SaveFile.gLastCompletedStarNum == 4 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_TTC) then
		goalPitch = 0x800
	end

	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_closeup_fly_above_dist, Scratch.cutscene_dance_closeup_fly_above_pitch, Scratch.cutscene_dance_closeup_fly_above_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_above_dist, 800, F32(0.05))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_above_pitch, goalPitch, 16)
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_above_yaw, c.yaw, 8)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_closeup_fly_above_dist[1], Scratch.cutscene_dance_closeup_fly_above_pitch[1], Scratch.cutscene_dance_closeup_fly_above_yaw[1])
end

-- from src/game/camera.c:cutscene_dance_closeup_fly_closer L7827-7836
function camera.cutscene_dance_closeup_fly_closer(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_closeup_fly_closer_dist, Scratch.cutscene_dance_closeup_fly_closer_pitch, Scratch.cutscene_dance_closeup_fly_closer_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_closer_dist, 240, F32(0.4))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_closer_yaw, c.yaw, 8)
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_closeup_fly_closer_pitch, 0x1000, 5)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_closeup_fly_closer_dist[1], Scratch.cutscene_dance_closeup_fly_closer_pitch[1], Scratch.cutscene_dance_closeup_fly_closer_yaw[1])
end

-- from src/game/camera.c:cutscene_dance_closeup_zoom L7841-7843
function camera.cutscene_dance_closeup_zoom(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_APP_80)
end

-- from src/game/camera.c:cutscene_dance_closeup_shake_fov L7848-7850
function camera.cutscene_dance_closeup_shake_fov(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_shake(0x300, 0x30, S16(0x8000))
end

-- from src/game/camera.c:cutscene_dance_closeup L7855-7875
function camera.cutscene_dance_closeup(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))

	if camera.sMarioCamState.action == IncludeSm64H.ACT_STAR_DANCE_WATER then
		camera.cutscene_event(camera.cutscene_dance_closeup_start, c, 0, 0)
		camera.cutscene_event(camera.cutscene_dance_closeup_focus_mario, c, 0, -1)
		camera.cutscene_event(camera.cutscene_dance_closeup_fly_above, c, 0, 62)
		camera.cutscene_event(camera.cutscene_dance_closeup_fly_closer, c, 63, -1)
		camera.cutscene_event(camera.cutscene_dance_closeup_zoom, c, 63, 63)
		camera.cutscene_event(camera.cutscene_dance_closeup_shake_fov, c, 70, 70)
	else
		camera.cutscene_event(camera.cutscene_dance_closeup_start, c, 0, 0)
		camera.cutscene_event(camera.cutscene_dance_closeup_focus_mario, c, 0, -1)
		-- Almost twice as fast as under water
		camera.cutscene_event(camera.cutscene_dance_closeup_fly_above, c, 0, 32)
		camera.cutscene_event(camera.cutscene_dance_closeup_fly_closer, c, 33, -1)
		camera.cutscene_event(camera.cutscene_dance_closeup_zoom, c, 33, 33)
		camera.cutscene_event(camera.cutscene_dance_closeup_shake_fov, c, 40, 40)
	end
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cutscene_dance_fly_away_start L7880-7905
function camera.cutscene_dance_fly_away_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[10].point, c.focus)
	camera.sCutsceneVars[9].point[3] = 65

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_RADIAL then
		SrcEngineMathUtil.vec3f_set(Scratch.cutscene_dance_fly_away_start_areaCenter, c.areaCenX, c.areaCenY, c.areaCenZ)
		c.yaw = camera.calculate_yaw(Scratch.cutscene_dance_fly_away_start_areaCenter, c.pos)
		c.nextYaw = c.yaw
	end

	-- Restrict the camera yaw in tight spaces
	if SaveFile.gLastCompletedStarNum == 6 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_CCM then
		camera.star_dance_bound_yaw(c, 0x5600, 0x800)
	end
	if SaveFile.gLastCompletedStarNum == 2 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_TTM then
		camera.star_dance_bound_yaw(c, 0x0, 0x800)
	end
	if SaveFile.gLastCompletedStarNum == 1 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_SL then
		camera.star_dance_bound_yaw(c, 0x2000, 0x800)
	end
	if SaveFile.gLastCompletedStarNum == 3 and Area.gCurrCourseNum == IncludeCourseTableH.COURSE_RR then
		camera.star_dance_bound_yaw(c, 0x0, 0x800)
	end
end

-- from src/game/camera.c:cutscene_dance_fly_away_approach_mario L7907-7916
function camera.cutscene_dance_fly_away_approach_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_fly_away_approach_mario_dist, Scratch.cutscene_dance_fly_away_approach_mario_pitch, Scratch.cutscene_dance_fly_away_approach_mario_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dance_fly_away_approach_mario_dist, 600, F32(0.3))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_fly_away_approach_mario_pitch, 0x1000, 16)
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dance_fly_away_approach_mario_yaw, c.yaw, 8)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_dance_fly_away_approach_mario_dist[1], Scratch.cutscene_dance_fly_away_approach_mario_pitch[1], Scratch.cutscene_dance_fly_away_approach_mario_yaw[1])
end

-- from src/game/camera.c:cutscene_dance_fly_away_focus_mario L7918-7924
function camera.cutscene_dance_fly_away_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_dance_fly_away_focus_mario_marioPos, camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 125), camera.sMarioCamState.pos[3])
	camera.approach_vec3f_asymptotic(camera.sCutsceneVars[10].point, Scratch.cutscene_dance_fly_away_focus_mario_marioPos, F32(0.2), F32(0.2), F32(0.2))
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[10].point)
end

-- from src/game/camera.c:cutscene_pan_cvar9 L7929-7934
function camera.cutscene_pan_cvar9(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[10].point)
	camera.sCutsceneVars[10].angle[1] = S16(camera.sCutsceneVars[10].angle[1] - 29)
	camera.sCutsceneVars[10].angle[2] = S16(camera.sCutsceneVars[10].angle[2] + 29)
	camera.pan_camera(c, camera.sCutsceneVars[10].angle[1], camera.sCutsceneVars[10].angle[2])
end

-- from src/game/camera.c:cutscene_dance_fly_rotate_around_mario L7939-7942
function camera.cutscene_dance_fly_rotate_around_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_pan_cvar9(c)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, camera.sCutsceneVars[9].point[3], 0, 0)
end

-- from src/game/camera.c:cutscene_dance_fly_away_rotate_while_flying L7947-7949
function camera.cutscene_dance_fly_away_rotate_while_flying(c: GroupsTypesHPlus3.Camera)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, 0, 0, 0x80)
end

-- from src/game/camera.c:cutscene_dance_fly_away_shake_fov L7951-7953
function camera.cutscene_dance_fly_away_shake_fov(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_shake(0x400, 0x30, S16(0x8000))
end

-- from src/game/camera.c:cutscene_dance_fly_away L7958-7968
function camera.cutscene_dance_fly_away(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.cutscene_event(camera.cutscene_dance_fly_away_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_dance_fly_away_focus_mario, c, 0, 30)
	camera.cutscene_event(camera.cutscene_dance_fly_away_approach_mario, c, 0, 30)
	camera.cutscene_event(camera.cutscene_dance_fly_rotate_around_mario, c, 55, 124)
	camera.cutscene_event(camera.cutscene_dance_fly_away_rotate_while_flying, c, 55, 124)
	camera.cutscene_event(camera.cutscene_dance_fly_away_shake_fov, c, 40, 40)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_STAR_DANCE)
end

-- from src/game/camera.c:cutscene_key_dance_jump_cvar L7974-7977
function camera.cutscene_key_dance_jump_cvar(c: GroupsTypesHPlus3.Camera)
	camera.offset_rotated(c.pos, camera.sMarioCamState.pos, camera.sCutsceneVars[9].point, camera.sMarioCamState.faceAngle)
	camera.offset_rotated(c.focus, camera.sMarioCamState.pos, camera.sCutsceneVars[8].point, camera.sMarioCamState.faceAngle)
end

-- from src/game/camera.c:cutscene_key_dance_jump_closeup L7982-7985
function camera.cutscene_key_dance_jump_closeup(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[9].point, 38, 171, -248)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[8].point, -57, 51, 187)
end

-- from src/game/camera.c:cutscene_key_dance_jump_lower_left L7990-7993
function camera.cutscene_key_dance_jump_lower_left(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[9].point, -178, 62, -132)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[8].point, 299, 91, 58)
end

-- from src/game/camera.c:cutscene_key_dance_jump_above L7998-8002
function camera.cutscene_key_dance_jump_above(c: GroupsTypesHPlus3.Camera)
	camera.gLakituState.keyDanceRoll = 0x2800
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[9].point, 89, 373, -304)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[8].point, 0, 127, 0)
end

-- from src/game/camera.c:cutscene_key_dance_jump_last L8007-8011
function camera.cutscene_key_dance_jump_last(c: GroupsTypesHPlus3.Camera)
	camera.gLakituState.keyDanceRoll = 0
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[9].point, 135, 158, -673)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[8].point, -20, 135, -198)
end

-- from src/game/camera.c:cutscene_key_dance_shake_fov L8013-8015
function camera.cutscene_key_dance_shake_fov(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_shake(0x180, 0x30, S16(0x8000))
end

-- from src/game/camera.c:cutscene_key_dance_handheld_shake L8017-8019
function camera.cutscene_key_dance_handheld_shake(c: GroupsTypesHPlus3.Camera)
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cutscene_key_dance_focus_mario L8021-8023
function camera.cutscene_key_dance_focus_mario(c: GroupsTypesHPlus3.Camera)
	camera.focus_in_front_of_mario(c, 0, F32(0.2))
end

-- from src/game/camera.c:cutscene_key_dance L8029-8039
function camera.cutscene_key_dance(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_dance_move_to_mario, c, 0, 10)
	camera.cutscene_event(camera.cutscene_key_dance_focus_mario, c, 0, 10)
	camera.cutscene_event(camera.cutscene_key_dance_jump_closeup, c, 0, 0)
	camera.cutscene_event(camera.cutscene_key_dance_jump_lower_left, c, 20, 20)
	camera.cutscene_event(camera.cutscene_key_dance_jump_above, c, 35, 35)
	camera.cutscene_event(camera.cutscene_key_dance_jump_last, c, 52, 52)
	camera.cutscene_event(camera.cutscene_key_dance_jump_cvar, c, 11, -1)
	camera.cutscene_event(camera.cutscene_key_dance_shake_fov, c, 54, 54)
	camera.cutscene_event(camera.cutscene_key_dance_handheld_shake, c, 52, -1)
end

-- from src/game/camera.c:cutscene_bowser_area_shake_fov L8041-8043
function camera.cutscene_bowser_area_shake_fov(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_set_fov_shake_preset(2)
end

-- from src/game/camera.c:cutscene_bowser_area_start_bowser_walking L8048-8050
function camera.cutscene_bowser_area_start_bowser_walking(c: GroupsTypesHPlus3.Camera)
	const secondCameraFocus = camera.gSecondCameraFocus :: GroupsTypesHPlus3.Object

	buffer.writei32(secondCameraFocus.rawData, IncludeObjectFieldsH.oBowserCamAct, IncludeObjectConstantsH.BOWSER_CAM_ACT_WALK)
end

-- from src/game/camera.c:cutscene_bowser_arena_set_pos L8057-8062
function camera.cutscene_bowser_arena_set_pos(c: GroupsTypesHPlus3.Camera)
	const secondCameraFocus = camera.gSecondCameraFocus :: GroupsTypesHPlus3.Object

	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[3].point, c.pos, camera.sCutsceneVars[4].point[3], camera.sCutsceneVars[4].angle[1], camera.sCutsceneVars[4].angle[2])
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[3].point, buffer.readf32(secondCameraFocus.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(secondCameraFocus.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(secondCameraFocus.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/camera.c:cutscene_bowser_arena_focus_sine L8068-8076
function camera.cutscene_bowser_arena_focus_sine(c: GroupsTypesHPlus3.Camera)
	-- unused initialization
	local yOff = 150

	-- cvar4 was zeroed when the cutscene started.
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(camera.sCutsceneVars[5].angle[2])
	yOff = F32(F32(Sin * 120) + 120)
	camera.sCutsceneVars[5].angle[2] = S16(camera.sCutsceneVars[5].angle[2] - 0x200)
	Scratch.cutscene_bowser_arena_focus_sine_point[1] = camera.sCutsceneVars[1].point[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_bowser_arena_focus_sine_point, yOff, 0.5)
	camera.sCutsceneVars[1].point[2] = Scratch.cutscene_bowser_arena_focus_sine_point[1]
end

-- from src/game/camera.c:cutscene_bowser_arena_set_focus L8081-8083
function camera.cutscene_bowser_arena_set_focus(c: GroupsTypesHPlus3.Camera)
	camera.offset_rotated(c.focus, camera.sCutsceneVars[3].point, camera.sCutsceneVars[1].point, camera.sCutsceneVars[3].angle)
end

-- from src/game/camera.c:cutscene_bowser_arena_adjust_offsets L8089-8093
function camera.cutscene_bowser_arena_adjust_offsets(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_bowser_arena_adjust_offsets_angle[1] = camera.sCutsceneVars[4].angle[1]
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_bowser_arena_adjust_offsets_angle, 0x6C8, 30)
	camera.sCutsceneVars[4].angle[1] = Scratch.cutscene_bowser_arena_adjust_offsets_angle[1]
	Scratch.cutscene_bowser_arena_adjust_offsets_point[1] = camera.sCutsceneVars[1].point[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_bowser_arena_adjust_offsets_point, -200, F32(0.02))
	camera.sCutsceneVars[1].point[3] = Scratch.cutscene_bowser_arena_adjust_offsets_point[1]
	Scratch.cutscene_bowser_arena_adjust_offsets_point[1] = camera.sCutsceneVars[4].point[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_bowser_arena_adjust_offsets_point, 550, F32(0.02))
	camera.sCutsceneVars[4].point[3] = Scratch.cutscene_bowser_arena_adjust_offsets_point[1]
end

-- from src/game/camera.c:cutscene_bowser_arena_pan_left L8098-8100
function camera.cutscene_bowser_arena_pan_left(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_bowser_arena_pan_left_point[1] = camera.sCutsceneVars[1].point[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_bowser_arena_pan_left_point, 0, F32(0.05))
	camera.sCutsceneVars[1].point[3] = Scratch.cutscene_bowser_arena_pan_left_point[1]
end

-- from src/game/camera.c:cutscene_bowser_arena_mario_dialog L8105-8107
function camera.cutscene_bowser_arena_mario_dialog(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_common_set_dialog_state(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_FRONT)
end

-- from src/game/camera.c:cutscene_stop_dialog L8109-8111
function camera.cutscene_stop_dialog(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_common_set_dialog_state(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
end

-- from src/game/camera.c:cutscene_bowser_arena_start L8120-8136
function camera.cutscene_bowser_arena_start(c: GroupsTypesHPlus3.Camera)
	const secondCameraFocus = camera.gSecondCameraFocus :: GroupsTypesHPlus3.Object

	camera.sCutsceneVars[4].point[3] = 430
	camera.sCutsceneVars[4].angle[2] = S16(buffer.readi32(secondCameraFocus.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - GroupsTypesHPlus3.DEGREES(45))
	camera.sCutsceneVars[4].angle[1] = 0xD90

	-- ! Tricky math: Bowser starts at (0, 307, -1000), with a moveAngle of (0,0,0). A sane person would
	-- ! expect this offset to move the focus to (0, 427, -1800).
	-- ! BUT because offset_rotated() flips the Z direction (to match sm64's coordinate system), this
	-- ! offset actually moves the focus to (0, 427, -200)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[1].point, 0, 120, -800)
	SrcEngineMathUtil.vec3s_set(camera.sCutsceneVars[3].angle, S16(buffer.readi32(secondCameraFocus.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), S16(buffer.readi32(secondCameraFocus.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(secondCameraFocus.rawData, IncludeObjectFieldsH.oMoveAngleRoll)))

	-- Set the camera's position and focus.
	camera.cutscene_bowser_arena_set_pos(c)
	camera.cutscene_bowser_arena_set_focus(c)
end

-- from src/game/camera.c:bowser_fight_intro_dialog L8141-8156
function camera.bowser_fight_intro_dialog(c: GroupsTypesHPlus3.Camera)
	local dialog = 0

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_1 then
		dialog = IncludeDialogIdsH.DIALOG_067
	elseif Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_BOWSER_2 then
		dialog = IncludeDialogIdsH.DIALOG_092
	else -- LEVEL_BOWSER_3
		dialog = IncludeDialogIdsH.DIALOG_093
	end

	GroupsIngameMenuPlus1.create_dialog_box(dialog)
end

-- from src/game/camera.c:cutscene_bowser_arena_dialog L8161-8167
function camera.cutscene_bowser_arena_dialog(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.bowser_fight_intro_dialog, c, 0, 0)

	if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
		camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
	end
end

-- from src/game/camera.c:cutscene_bowser_arena_end L8172-8179
function camera.cutscene_bowser_arena_end(c: GroupsTypesHPlus3.Camera)
	const secondCameraFocus = camera.gSecondCameraFocus :: GroupsTypesHPlus3.Object

	camera.cutscene_stop_dialog(c)
	c.cutscene = 0
	camera.transition_next_state(c, 20)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
	camera.sModeOffsetYaw = S16(camera.sMarioCamState.faceAngle[2] + GroupsTypesHPlus3.DEGREES(90))
	buffer.writei32(secondCameraFocus.rawData, IncludeObjectFieldsH.oBowserCamAct, IncludeObjectConstantsH.BOWSER_CAM_ACT_END)
end

-- from src/game/camera.c:cutscene_bowser_arena L8184-8203
function camera.cutscene_bowser_arena(c: GroupsTypesHPlus3.Camera)
	-- This does nothing, but may have been used in development
	camera.cutscene_spawn_obj(2, 0)

	if camera.gSecondCameraFocus ~= nil then
		camera.cutscene_event(camera.cutscene_bowser_arena_mario_dialog, c, 0, -1)
		camera.cutscene_event(camera.cutscene_bowser_arena_start, c, 0, 5)
		camera.cutscene_event(camera.cutscene_bowser_area_start_bowser_walking, c, 40, 40)
		camera.cutscene_event(camera.cutscene_bowser_area_shake_fov, c, 145, 145)
		camera.cutscene_event(camera.cutscene_bowser_arena_set_pos, c, 40, -1)
		camera.cutscene_event(camera.cutscene_bowser_arena_pan_left, c, 40, 99)
		camera.cutscene_event(camera.cutscene_bowser_arena_adjust_offsets, c, 100, -1)
		camera.cutscene_event(camera.cutscene_bowser_arena_focus_sine, c, 40, 140)
		camera.cutscene_event(camera.cutscene_bowser_arena_set_focus, c, 40, -1)
		camera.cutscene_event(camera.cutscene_shake_explosion, c, 60, 60)
		camera.cutscene_event(camera.cutscene_shake_explosion, c, 82, 82)
		camera.cutscene_event(camera.cutscene_shake_explosion, c, 109, 109)
		camera.cutscene_event(camera.cutscene_shake_explosion, c, 127, 127)
	end
end

-- from src/game/camera.c:cutscene_star_spawn_store_info L8205-8207
function camera.cutscene_star_spawn_store_info(c: GroupsTypesHPlus3.Camera)
	camera.store_info_star(c)
end

-- from src/game/camera.c:cutscene_star_spawn_focus_star L8212-8222
function camera.cutscene_star_spawn_focus_star(c: GroupsTypesHPlus3.Camera)
	if camera.gCutsceneFocus ~= nil then
		const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object
		camera.object_pos_to_vec3f(Scratch.cutscene_star_spawn_focus_star_starPos, cutsceneFocus)
		Scratch.cutscene_star_spawn_focus_star_starPos[2] = F32(Scratch.cutscene_star_spawn_focus_star_starPos[2] + cutsceneFocus.hitboxHeight)
		camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_star_spawn_focus_star_starPos, F32(0.1), F32(0.1), F32(0.1))
	end
end

-- from src/game/camera.c:cutscene_star_spawn_update_boss_fight L8227-8233
function camera.cutscene_star_spawn_update_boss_fight(c: GroupsTypesHPlus3.Camera)
	camera.update_boss_fight_camera(c, Scratch.cutscene_star_spawn_update_boss_fight_focus, Scratch.cutscene_star_spawn_update_boss_fight_pos)
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_star_spawn_update_boss_fight_focus, F32(0.2), F32(0.2), F32(0.2))
	camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_star_spawn_update_boss_fight_pos, F32(0.2), F32(0.2), F32(0.2))
end

-- from src/game/camera.c:cutscene_star_spawn_fly_back L8238-8241
function camera.cutscene_star_spawn_fly_back(c: GroupsTypesHPlus3.Camera)
	camera.retrieve_info_star(c)
	camera.transition_next_state(c, 15)
end

-- from src/game/camera.c:cutscene_star_spawn L8246-8255
function camera.cutscene_star_spawn(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_star_spawn_store_info, c, 0, 0)
	camera.cutscene_event(camera.cutscene_star_spawn_focus_star, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))

	if camera.gObjCutsceneDone ~= 0 then
		-- Set the timer to CUTSCENE_LOOP, which start the next shot.
		camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
	end
end

-- from src/game/camera.c:cutscene_star_spawn_back L8260-8269
function camera.cutscene_star_spawn_back(c: GroupsTypesHPlus3.Camera)
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_BOSS_FIGHT and camera.set_cam_angle(0) == GroupsTypesHPlus3.CAM_ANGLE_LAKITU then
		camera.cutscene_event(camera.cutscene_star_spawn_update_boss_fight, c, 0, -1)
	else
		camera.cutscene_event(camera.cutscene_star_spawn_fly_back, c, 0, 0)
	end

	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_star_spawn_end L8271-8275
function camera.cutscene_star_spawn_end(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	c.cutscene = 0
end

-- from src/game/camera.c:cutscene_exit_waterfall_warp L8277-8280
function camera.cutscene_exit_waterfall_warp(c: GroupsTypesHPlus3.Camera)
	-- ! hardcoded position
	SrcEngineMathUtil.vec3f_set(c.pos, -3899, 39, -5671)
end

-- from src/game/camera.c:cutscene_exit_to_castle_grounds_focus_mario L8285-8289
function camera.cutscene_exit_to_castle_grounds_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	c.focus[2] = F32(c.pos[2] + F32(F32(F32(camera.sMarioCamState.pos[2] + 125) - c.pos[2]) * 0.5))
	camera.approach_vec3f_asymptotic(c.focus, camera.sMarioCamState.pos, F32(0.05), F32(0.4), F32(0.05))
end

-- from src/game/camera.c:cutscene_exit_waterfall L8294-8298
function camera.cutscene_exit_waterfall(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_exit_waterfall_warp, c, 0, 0)
	camera.cutscene_event(camera.cutscene_exit_to_castle_grounds_focus_mario, c, 0, -1)
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_exit_to_castle_grounds_end L8303-8308
function camera.cutscene_exit_to_castle_grounds_end(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	c.cutscene = 0
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_exit_fall_to_castle_grounds_warp L8310-8313
function camera.cutscene_exit_fall_to_castle_grounds_warp(c: GroupsTypesHPlus3.Camera)
	-- ! hardcoded position
	SrcEngineMathUtil.vec3f_set(c.pos, 5830, 32, 3985)
end

-- from src/game/camera.c:cutscene_exit_fall_to_castle_grounds L8318-8322
function camera.cutscene_exit_fall_to_castle_grounds(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_exit_fall_to_castle_grounds_warp, c, 0, 0)
	camera.cutscene_event(camera.cutscene_exit_to_castle_grounds_focus_mario, c, 0, -1)
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_red_coin_star_start L8327-8332
function camera.cutscene_red_coin_star_start(c: GroupsTypesHPlus3.Camera)
	camera.object_pos_to_vec3f(camera.sCutsceneVars[2].point, camera.gCutsceneFocus :: GroupsTypesHPlus3.Object)
	camera.store_info_star(c)
	-- Store the default fov for after the cutscene
	camera.sCutsceneVars[3].point[3] = camera.sFOVState.fov
end

-- from src/game/camera.c:cutscene_red_coin_star_focus_xz L8337-8340
function camera.cutscene_red_coin_star_focus_xz(c: GroupsTypesHPlus3.Camera)
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	Scratch.cutscene_red_coin_star_focus_xz_value[1] = c.focus[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_red_coin_star_focus_xz_value, buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosX), F32(0.15))
	c.focus[1] = Scratch.cutscene_red_coin_star_focus_xz_value[1]
	Scratch.cutscene_red_coin_star_focus_xz_value[1] = c.focus[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_red_coin_star_focus_xz_value, buffer.readf32(cutsceneFocus.rawData, IncludeObjectFieldsH.oPosZ), F32(0.15))
	c.focus[3] = Scratch.cutscene_red_coin_star_focus_xz_value[1]
end

-- from src/game/camera.c:cutscene_red_coin_star_focus_y L8345-8347
function camera.cutscene_red_coin_star_focus_y(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_red_coin_star_focus_y_value[1] = c.focus[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_red_coin_star_focus_y_value, buffer.readf32((camera.gCutsceneFocus :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY), F32(0.1))
	c.focus[2] = Scratch.cutscene_red_coin_star_focus_y_value[1]
end

-- from src/game/camera.c:cutscene_red_coin_star_look_up_at_star L8352-8354
function camera.cutscene_red_coin_star_look_up_at_star(c: GroupsTypesHPlus3.Camera)
	c.focus[2] = F32(camera.sCutsceneVars[2].point[2] + F32(F32(buffer.readf32((camera.gCutsceneFocus :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) - camera.sCutsceneVars[2].point[2]) * F32(0.8)))
end

-- from src/game/camera.c:cutscene_red_coin_star_warp L8359-8377
function camera.cutscene_red_coin_star_warp(c: GroupsTypesHPlus3.Camera)
	const o = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object

	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[2].point, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[2].point, c.pos, Scratch.cutscene_red_coin_star_warp_dist, Scratch.cutscene_red_coin_star_warp_pitch, Scratch.cutscene_red_coin_star_warp_yaw)
	const posYaw = camera.calculate_yaw(camera.sCutsceneVars[2].point, c.pos)
	Scratch.cutscene_red_coin_star_warp_yaw[1] = camera.calculate_yaw(camera.sCutsceneVars[2].point, camera.sMarioCamState.pos)

	if GroupsTypesHPlus3.ABS(Scratch.cutscene_red_coin_star_warp_yaw[1] - posYaw + GroupsTypesHPlus3.DEGREES(90)) < GroupsTypesHPlus3.ABS(Scratch.cutscene_red_coin_star_warp_yaw[1] - posYaw - GroupsTypesHPlus3.DEGREES(90)) then
		Scratch.cutscene_red_coin_star_warp_yaw[1] = S16(Scratch.cutscene_red_coin_star_warp_yaw[1] + GroupsTypesHPlus3.DEGREES(90))
	else
		Scratch.cutscene_red_coin_star_warp_yaw[1] = S16(Scratch.cutscene_red_coin_star_warp_yaw[1] - GroupsTypesHPlus3.DEGREES(90))
	end

	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[2].point, c.pos, 400, 0x1000, Scratch.cutscene_red_coin_star_warp_yaw[1])
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
end

-- from src/game/camera.c:cutscene_red_coin_star_set_fov L8382-8384
function camera.cutscene_red_coin_star_set_fov(c: GroupsTypesHPlus3.Camera)
	camera.sFOVState.fov = 60
end

-- from src/game/camera.c:cutscene_red_coin_star L8386-8399
function camera.cutscene_red_coin_star(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.cutscene_event(camera.cutscene_red_coin_star_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_red_coin_star_warp, c, 30, 30)
	camera.cutscene_event(camera.cutscene_red_coin_star_focus_xz, c, 0, -1)
	camera.cutscene_event(camera.cutscene_red_coin_star_focus_y, c, 0, 29)
	camera.cutscene_event(camera.cutscene_red_coin_star_look_up_at_star, c, 30, -1)
	camera.cutscene_event(camera.cutscene_red_coin_star_set_fov, c, 30, -1)

	if camera.gObjCutsceneDone ~= 0 then
		-- Set the timer to CUTSCENE_LOOP, which start the next shot.
		camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
	end
end

-- from src/game/camera.c:cutscene_red_coin_star_end L8404-8410
function camera.cutscene_red_coin_star_end(c: GroupsTypesHPlus3.Camera)
	camera.retrieve_info_star(c)
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	c.cutscene = 0
	-- Restore the default fov
	camera.sFOVState.fov = camera.sCutsceneVars[3].point[3]
end

-- from src/game/camera.c:cutscene_goto_cvar_pos L8421-8477
function camera.cutscene_goto_cvar_pos(c: GroupsTypesHPlus3.Camera, goalDist: number, goalPitch: number, rotPitch: number, rotYaw: number)
	goalDist = F32(goalDist)
	goalPitch = S16(TruncS32(goalPitch))
	rotPitch = S16(TruncS32(rotPitch))
	rotYaw = S16(TruncS32(rotYaw))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[4].point, c.pos, Scratch.cutscene_goto_cvar_pos_nextDist, Scratch.cutscene_goto_cvar_pos_nextPitch, Scratch.cutscene_goto_cvar_pos_nextYaw)

	-- If over 8000 units away from the cannon, just teleport there
	if Scratch.cutscene_goto_cvar_pos_nextDist[1] > 8000 and c.cutscene == GroupsTypesHPlus3.CUTSCENE_PREPARE_CANNON then
		Scratch.cutscene_goto_cvar_pos_nextDist[1] = F32(goalDist * 4)
		Scratch.cutscene_goto_cvar_pos_nextPitch[1] = goalPitch
		SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, camera.sCutsceneVars[4].point)
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))

		if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_TTM then
			Scratch.cutscene_goto_cvar_pos_nextYaw[1] = SrcEngineMathUtil.atan2s(F32(camera.sCutsceneVars[4].point[3] - c.areaCenZ), F32(camera.sCutsceneVars[4].point[1] - c.areaCenX))
		end
	else
		if c.cutscene == GroupsTypesHPlus3.CUTSCENE_PREPARE_CANNON then
			SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, camera.sCutsceneVars[1].point, Scratch.cutscene_goto_cvar_pos_curDist, Scratch.cutscene_goto_cvar_pos_curPitch, Scratch.cutscene_goto_cvar_pos_curYaw)
			SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, camera.sCutsceneVars[4].point, Scratch.cutscene_goto_cvar_pos_cannonDist, Scratch.cutscene_goto_cvar_pos_cannonPitch, Scratch.cutscene_goto_cvar_pos_cannonYaw)
			camera.approach_f32_asymptotic_bool(Scratch.cutscene_goto_cvar_pos_curDist, Scratch.cutscene_goto_cvar_pos_cannonDist[1], F32(0.1))
			camera.approach_s16_asymptotic_bool(Scratch.cutscene_goto_cvar_pos_curPitch, Scratch.cutscene_goto_cvar_pos_cannonPitch[1], 15)
			camera.approach_s16_asymptotic_bool(Scratch.cutscene_goto_cvar_pos_curYaw, Scratch.cutscene_goto_cvar_pos_cannonYaw[1], 15)
			-- Move the current focus, sCutsceneVars[0].point, in the direction towards the cannon
			SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, camera.sCutsceneVars[1].point, Scratch.cutscene_goto_cvar_pos_curDist[1], Scratch.cutscene_goto_cvar_pos_curPitch[1], Scratch.cutscene_goto_cvar_pos_curYaw[1])
		else
			camera.approach_vec3f_asymptotic(camera.sCutsceneVars[1].point, camera.sCutsceneVars[4].point, F32(0.1), F32(0.1), F32(0.1))
		end
	end

	camera.approach_f32_asymptotic_bool(Scratch.cutscene_goto_cvar_pos_nextDist, goalDist, F32(0.05))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_goto_cvar_pos_nextPitch, goalPitch, 0x20)

	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[4].point, c.pos, Scratch.cutscene_goto_cvar_pos_nextDist[1], Scratch.cutscene_goto_cvar_pos_nextPitch[1], Scratch.cutscene_goto_cvar_pos_nextYaw[1])
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[1].point)

	-- Apply the constant rotation given
	camera.pan_camera(c, rotPitch, rotYaw)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, c.focus, Scratch.cutscene_goto_cvar_pos_nextDist, Scratch.cutscene_goto_cvar_pos_nextPitch, Scratch.cutscene_goto_cvar_pos_nextYaw)

	if Scratch.cutscene_goto_cvar_pos_nextPitch[1] < -0x3000 then
		Scratch.cutscene_goto_cvar_pos_nextPitch[1] = -0x3000
	end
	if Scratch.cutscene_goto_cvar_pos_nextPitch[1] > 0x3000 then
		Scratch.cutscene_goto_cvar_pos_nextPitch[1] = 0x3000
	end

	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, c.focus, Scratch.cutscene_goto_cvar_pos_nextDist[1], Scratch.cutscene_goto_cvar_pos_nextPitch[1], Scratch.cutscene_goto_cvar_pos_nextYaw[1])
end

-- from src/game/camera.c:cutscene_prepare_cannon_start L8482-8489
function camera.cutscene_prepare_cannon_start(c: GroupsTypesHPlus3.Camera)
	camera.store_info_cannon(c)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
	camera.sCutsceneVars[3].point[1] = 30
	-- Store the cannon door position in sCutsceneVars[3] point
	camera.object_pos_to_vec3f(camera.sCutsceneVars[4].point, camera.gCutsceneFocus :: GroupsTypesHPlus3.Object)
	SrcEngineMathUtil.vec3s_set(camera.sCutsceneVars[6].angle, 0, 0, 0)
end

-- from src/game/camera.c:cutscene_prepare_cannon_fly_to_cannon L8494-8498
function camera.cutscene_prepare_cannon_fly_to_cannon(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 300, 0x2000, 0, camera.sCutsceneVars[6].angle[2])
	Scratch.cutscene_prepare_cannon_fly_to_cannon_angle[1] = camera.sCutsceneVars[6].angle[2]
	camera.camera_approach_s16_symmetric_bool(Scratch.cutscene_prepare_cannon_fly_to_cannon_angle, 0x400, 17)
	camera.sCutsceneVars[6].angle[2] = Scratch.cutscene_prepare_cannon_fly_to_cannon_angle[1]
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cannon_approach_prev L8503-8506
function camera.cannon_approach_prev(value: { number }, target: number)
	target = F32(target)
	const inc = F32(GroupsTypesHPlus3.ABS(F32(target - value[1])) / camera.sCutsceneVars[3].point[1])
	camera.camera_approach_f32_symmetric_bool(value, target, inc)
end

-- from src/game/camera.c:cutscene_prepare_cannon_fly_back L8511-8530
function camera.cutscene_prepare_cannon_fly_back(c: GroupsTypesHPlus3.Camera)
	const distToPrevPos = camera.calc_abs_dist(c.pos, camera.sCameraStoreCutscene.pos)

	if distToPrevPos < 8000 then
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.pos[1]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.pos[1])
		c.pos[1] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.pos[2]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.pos[2])
		c.pos[2] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.pos[3]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.pos[3])
		c.pos[3] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.focus[1]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.focus[1])
		c.focus[1] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.focus[2]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.focus[2])
		c.focus[2] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
		Scratch.cutscene_prepare_cannon_fly_back_value[1] = c.focus[3]
		camera.cannon_approach_prev(Scratch.cutscene_prepare_cannon_fly_back_value, camera.sCameraStoreCutscene.focus[3])
		c.focus[3] = Scratch.cutscene_prepare_cannon_fly_back_value[1]
	else
		-- If too far away, just warp back
		SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCameraStoreCutscene.focus)
		SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCameraStoreCutscene.pos)
		camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	end
	if camera.sCutsceneVars[3].point[1] > 1 then
		camera.sCutsceneVars[3].point[1] = F32(camera.sCutsceneVars[3].point[1] - 1)
	end
end

-- from src/game/camera.c:cutscene_prepare_cannon L8535-8540
function camera.cutscene_prepare_cannon(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.cutscene_event(camera.cutscene_prepare_cannon_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_prepare_cannon_fly_to_cannon, c, 0, 140)
	camera.cutscene_event(camera.cutscene_prepare_cannon_fly_back, c, 141, -1)
end

-- from src/game/camera.c:cutscene_prepare_cannon_end L8545-8550
function camera.cutscene_prepare_cannon_end(c: GroupsTypesHPlus3.Camera)
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	c.cutscene = 0
	camera.retrieve_info_cannon(c)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
end

-- from src/game/camera.c:water_death_move_to_mario_side L8557-8564
function camera.water_death_move_to_mario_side(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.water_death_move_to_mario_side_dist, Scratch.water_death_move_to_mario_side_pitch, Scratch.water_death_move_to_mario_side_yaw)
	camera.approach_s16_asymptotic_bool(Scratch.water_death_move_to_mario_side_yaw, S16(camera.sMarioCamState.faceAngle[2] - 0x3000), 8)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.water_death_move_to_mario_side_dist[1], Scratch.water_death_move_to_mario_side_pitch[1], Scratch.water_death_move_to_mario_side_yaw[1])
end

-- from src/game/camera.c:death_goto_mario L8569-8571
function camera.death_goto_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 400, 0x1000, 0x300, 0)
end

-- from src/game/camera.c:cutscene_death_standing_start L8573-8577
function camera.cutscene_death_standing_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos)
	camera.sCutsceneVars[4].point[2] = F32(camera.sCutsceneVars[4].point[2] + 70)
end

-- from src/game/camera.c:cutscene_death_standing_goto_mario L8582-8585
function camera.cutscene_death_standing_goto_mario(c: GroupsTypesHPlus3.Camera)
	camera.death_goto_mario(c)
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_HIGH)
end

-- from src/game/camera.c:cutscene_death_standing L8590-8594
function camera.cutscene_death_standing(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_death_standing_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_death_standing_goto_mario, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
end

-- from src/game/camera.c:cutscene_death_stomach_start L8596-8601
function camera.cutscene_death_stomach_start(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_death_stomach_start_offset[1] = 0
	Scratch.cutscene_death_stomach_start_offset[2] = 40
	Scratch.cutscene_death_stomach_start_offset[3] = -60

	camera.offset_rotated(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos, Scratch.cutscene_death_stomach_start_offset, camera.sMarioCamState.faceAngle)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
end

-- from src/game/camera.c:cutscene_death_stomach_goto_mario L8603-8605
function camera.cutscene_death_stomach_goto_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 400, 0x1800, 0, -0x400)
end

-- from src/game/camera.c:unused_water_death_move_to_side_of_mario L8610-8612
function camera.unused_water_death_move_to_side_of_mario(c: GroupsTypesHPlus3.Camera)
	camera.water_death_move_to_mario_side(c)
end

-- from src/game/camera.c:cutscene_death_stomach L8617-8622
function camera.cutscene_death_stomach(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_death_stomach_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_death_stomach_goto_mario, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cutscene_bbh_death_start L8624-8629
function camera.cutscene_bbh_death_start(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_bbh_death_start_dir[1] = 0
	Scratch.cutscene_bbh_death_start_dir[2] = 40
	Scratch.cutscene_bbh_death_start_dir[3] = 60

	camera.offset_rotated(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos, Scratch.cutscene_bbh_death_start_dir, camera.sMarioCamState.faceAngle)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
end

-- from src/game/camera.c:cutscene_bbh_death_goto_mario L8631-8633
function camera.cutscene_bbh_death_goto_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 400, 0x1800, 0, 0x400)
end

-- from src/game/camera.c:cutscene_bbh_death L8638-8643
function camera.cutscene_bbh_death(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_bbh_death_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_bbh_death_goto_mario, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cutscene_quicksand_death_start L8648-8650
function camera.cutscene_quicksand_death_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
end

-- from src/game/camera.c:cutscene_quicksand_death_goto_mario L8655-8661
function camera.cutscene_quicksand_death_goto_mario(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 400, 0x2800, 0x200, 0)

	if c.cutscene == GroupsTypesHPlus3.CUTSCENE_WATER_DEATH then
		camera.water_death_move_to_mario_side(c)
	end
end

-- from src/game/camera.c:cutscene_quicksand_death L8666-8675
function camera.cutscene_quicksand_death(c: GroupsTypesHPlus3.Camera)
	camera.sCutsceneVars[4].point[1] = camera.sMarioCamState.pos[1]
	camera.sCutsceneVars[4].point[2] = F32(camera.sMarioCamState.pos[2] + 20)
	camera.sCutsceneVars[4].point[3] = camera.sMarioCamState.pos[3]

	camera.cutscene_event(camera.cutscene_quicksand_death_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_quicksand_death_goto_mario, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_HIGH)
end

-- from src/game/camera.c:cutscene_suffocation_fly_away L8680-8686
function camera.cutscene_suffocation_fly_away(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_suffocation_fly_away_offset[1] = 0
	Scratch.cutscene_suffocation_fly_away_offset[2] = 20
	Scratch.cutscene_suffocation_fly_away_offset[3] = 120

	camera.offset_rotated(Scratch.cutscene_suffocation_fly_away_target, camera.sMarioCamState.pos, Scratch.cutscene_suffocation_fly_away_offset, camera.sMarioCamState.faceAngle)
	camera.approach_vec3f_asymptotic(camera.sCutsceneVars[4].point, Scratch.cutscene_suffocation_fly_away_target, F32(0.1), F32(0.1), F32(0.1))
end

-- from src/game/camera.c:cutscene_suffocation_stay_above_gas L8691-8704
function camera.cutscene_suffocation_stay_above_gas(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 400, 0x2800, 0x200, 0)
	local gasLevel: number = Registry.Members.src__engine__surface_collision.find_poison_gas_level(camera.sMarioCamState.pos[1], camera.sMarioCamState.pos[3])

	if gasLevel ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		gasLevel = F32(gasLevel + 130)
		if gasLevel > c.pos[2] then
			c.pos[2] = gasLevel
		end
	end
end

-- from src/game/camera.c:cutscene_suffocation_rotate L8709-8716
function camera.cutscene_suffocation_rotate(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_suffocation_rotate_dist, Scratch.cutscene_suffocation_rotate_pitch, Scratch.cutscene_suffocation_rotate_yaw)
	Scratch.cutscene_suffocation_rotate_yaw[1] = S16(Scratch.cutscene_suffocation_rotate_yaw[1] + 0x100)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_suffocation_rotate_dist[1], Scratch.cutscene_suffocation_rotate_pitch[1], Scratch.cutscene_suffocation_rotate_yaw[1])
end

-- from src/game/camera.c:cutscene_suffocation L8721-8728
function camera.cutscene_suffocation(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_death_stomach_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_suffocation_rotate, c, 0, -1)
	camera.cutscene_event(camera.cutscene_suffocation_stay_above_gas, c, 0, -1)
	camera.cutscene_event(camera.cutscene_suffocation_fly_away, c, 50, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_HIGH)
end

-- from src/game/camera.c:cutscene_enter_pool_start L8730-8741
function camera.cutscene_enter_pool_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos)

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE then -- entering HMC
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[4].point, 2485, -1589, -2659)
	end
	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_HMC then -- entering CotMC
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[4].point, 3350, -4589, 4800)
	end

	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
end

-- from src/game/camera.c:cutscene_enter_pool_loop L8743-8747
function camera.cutscene_enter_pool_loop(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_goto_cvar_pos(c, 1200, 0x2000, 0x200, 0)
end

-- from src/game/camera.c:cutscene_enter_pool L8749-8753
function camera.cutscene_enter_pool(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_enter_pool_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_enter_pool_loop, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_start L8759-8765
function camera.cutscene_pyramid_top_explode_start(c: GroupsTypesHPlus3.Camera)
	camera.reset_pan_distance(c)
	camera.store_info_cannon(c)

	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[2].point, c.focus)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[4].point, c.areaCenX, 1280, c.areaCenZ)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_zoom_in L8770-8772
function camera.cutscene_pyramid_top_explode_zoom_in(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_APP_30)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_focus L8777-8780
function camera.cutscene_pyramid_top_explode_focus(c: GroupsTypesHPlus3.Camera)
	camera.approach_vec3f_asymptotic(c.focus, camera.sCutsceneVars[4].point, F32(0.02), F32(0.02), F32(0.02))
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_warp L8785-8799
function camera.cutscene_pyramid_top_explode_warp(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
	camera.sFOVState.fov = 45

	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[5].point, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[6].point, c.focus)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[4].point)

	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos, Scratch.cutscene_pyramid_top_explode_warp_dist, Scratch.cutscene_pyramid_top_explode_warp_pitch, Scratch.cutscene_pyramid_top_explode_warp_yaw)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[4].point, c.pos, 2000, 0, Scratch.cutscene_pyramid_top_explode_warp_yaw[1])
	c.pos[2] = F32(c.pos[2] + 500)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_closeup L8804-8816
function camera.cutscene_pyramid_top_explode_closeup(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[4].point, c.pos, Scratch.cutscene_pyramid_top_explode_closeup_dist, Scratch.cutscene_pyramid_top_explode_closeup_pitch, Scratch.cutscene_pyramid_top_explode_closeup_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_pyramid_top_explode_closeup_dist, 2000, F32(0.1))
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[4].point, c.pos, Scratch.cutscene_pyramid_top_explode_closeup_dist[1], Scratch.cutscene_pyramid_top_explode_closeup_pitch[1], Scratch.cutscene_pyramid_top_explode_closeup_yaw[1])

	c.focus[2] = F32(c.focus[2] + 4)
	c.pos[2] = F32(c.pos[2] - 5)
	camera.sFOVState.fov = 45
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_cam_shake L8821-8823
function camera.cutscene_pyramid_top_explode_cam_shake(c: GroupsTypesHPlus3.Camera)
	camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_PYRAMID_EXPLODE)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_warp_back L8828-8834
function camera.cutscene_pyramid_top_explode_warp_back(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCutsceneVars[5].point)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[6].point)
	camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_BOWSER_JUMP)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode L8839-8847
function camera.cutscene_pyramid_top_explode(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_focus, c, 0, 30)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_warp, c, 31, 31)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_closeup, c, 31, 139)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_zoom_in, c, 23, 23)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_warp_back, c, 140, 140)
	camera.cutscene_event(camera.cutscene_pyramid_top_explode_cam_shake, c, 31, 139)
end

-- from src/game/camera.c:cutscene_pyramid_top_explode_end L8852-8857
function camera.cutscene_pyramid_top_explode_end(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_stop_dialog(c)
	camera.stop_cutscene_and_retrieve_stored_info(c)
	-- Move the camera back to Mario
	camera.transition_next_state(c, 30)
end

-- from src/game/camera.c:cutscene_enter_pyramid_top_start L8862-8865
function camera.cutscene_enter_pyramid_top_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.focus)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[4].point, c.areaCenX, 1280, c.areaCenZ)
end

-- from src/game/camera.c:cutscene_enter_pyramid_top L8870-8882
function camera.cutscene_enter_pyramid_top(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_enter_pyramid_top_start, c, 0, 0)
	-- Move to cvar3
	camera.cutscene_goto_cvar_pos(c, 200, 0x3000, 0, 0)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_CUTSCENE)

	if camera.sMarioCamState.pos[2] > 1250 then
		-- End the cutscene early if Mario ledge-grabbed.
		-- This only works because of the janky way that ledge-grabbing is implemented.
		camera.cutscene_exit_to_castle_grounds_end(c)
	end
end

-- from src/game/camera.c:unused_cutscene_goto_cvar L8884-8890
function camera.unused_cutscene_goto_cvar(c: GroupsTypesHPlus3.Camera)
	local dist = camera.calc_abs_dist(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos)
	dist = F32(camera.calc_abs_dist(camera.sCutsceneVars[10].point, camera.sMarioCamState.pos) + 200)
	camera.cutscene_goto_cvar_pos(c, dist, 0x1000, 0x300, 0)
end

-- from src/game/camera.c:cutscene_dialog_start L8898-8933
function camera.cutscene_dialog_start(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_soften_music(c)
	ObjectHelpers.set_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_DIALOG))

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_BOSS_FIGHT then
		SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCutscene.focus, c.focus)
		SrcEngineMathUtil.vec3f_copy(camera.sCameraStoreCutscene.pos, c.pos)
	else
		camera.store_info_star(c)
	end

	-- Store Mario's position and faceAngle
	camera.sCutsceneVars[9].angle[1] = 0
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[9].point, camera.sMarioCamState.pos)
	camera.sCutsceneVars[9].point[2] = F32(camera.sCutsceneVars[9].point[2] + 125)

	-- Store gCutsceneFocus's position and yaw
	const cutsceneFocus = camera.gCutsceneFocus :: GroupsTypesHPlus3.Object
	camera.object_pos_to_vec3f(camera.sCutsceneVars[10].point, cutsceneFocus)
	camera.sCutsceneVars[10].point[2] = F32(camera.sCutsceneVars[10].point[2] + F32(cutsceneFocus.hitboxHeight + 200))
	camera.sCutsceneVars[10].angle[2] = camera.calculate_yaw(camera.sCutsceneVars[9].point, camera.sCutsceneVars[10].point)

	const yaw = camera.calculate_yaw(camera.sMarioCamState.pos, camera.gLakituState.curPos)
	if bit32.btest(yaw - camera.sCutsceneVars[10].angle[2], 0x8000) then
		camera.sCutsceneVars[10].angle[2] = S16(camera.sCutsceneVars[10].angle[2] - 0x6000)
	else
		camera.sCutsceneVars[10].angle[2] = S16(camera.sCutsceneVars[10].angle[2] + 0x6000)
	end
end

-- from src/game/camera.c:cutscene_dialog_move_mario_shoulder L8939-8968
function camera.cutscene_dialog_move_mario_shoulder(c: GroupsTypesHPlus3.Camera)
	camera.scale_along_line(Scratch.cutscene_dialog_move_mario_shoulder_focus, camera.sCutsceneVars[10].point, camera.sMarioCamState.pos, F32(0.7))
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.pos, Scratch.cutscene_dialog_move_mario_shoulder_focus, Scratch.cutscene_dialog_move_mario_shoulder_dist, Scratch.cutscene_dialog_move_mario_shoulder_pitch, Scratch.cutscene_dialog_move_mario_shoulder_yaw)
	Scratch.cutscene_dialog_move_mario_shoulder_pitch[1] = camera.calculate_pitch(c.pos, camera.sCutsceneVars[10].point)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.pos, Scratch.cutscene_dialog_move_mario_shoulder_pos, Scratch.cutscene_dialog_move_mario_shoulder_dist[1], Scratch.cutscene_dialog_move_mario_shoulder_pitch[1], Scratch.cutscene_dialog_move_mario_shoulder_yaw[1])

	Scratch.cutscene_dialog_move_mario_shoulder_focus[2] = F32(Scratch.cutscene_dialog_move_mario_shoulder_focus[2] + F32(F32(camera.sCutsceneVars[10].point[2] - Scratch.cutscene_dialog_move_mario_shoulder_focus[2]) * F32(0.1)))
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_dialog_move_mario_shoulder_focus, F32(0.2), F32(0.2), F32(0.2))

	SrcEngineMathUtil.vec3f_copy(Scratch.cutscene_dialog_move_mario_shoulder_pos, c.pos)

	-- Set y pos to cvar8's y (top of focus object)
	Scratch.cutscene_dialog_move_mario_shoulder_pos[2] = camera.sCutsceneVars[9].point[2]
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[9].point, Scratch.cutscene_dialog_move_mario_shoulder_pos, Scratch.cutscene_dialog_move_mario_shoulder_dist, Scratch.cutscene_dialog_move_mario_shoulder_pitch, Scratch.cutscene_dialog_move_mario_shoulder_yaw)
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_dialog_move_mario_shoulder_yaw, camera.sCutsceneVars[10].angle[2], 0x10)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dialog_move_mario_shoulder_dist, 180, F32(0.05))
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[9].point, Scratch.cutscene_dialog_move_mario_shoulder_pos, Scratch.cutscene_dialog_move_mario_shoulder_dist[1], Scratch.cutscene_dialog_move_mario_shoulder_pitch[1], Scratch.cutscene_dialog_move_mario_shoulder_yaw[1])

	-- Move up if Mario is below the focus object, down is Mario is above
	Scratch.cutscene_dialog_move_mario_shoulder_pos[2] = F32(camera.sCutsceneVars[9].point[2] + F32(Registry.Members.src__engine__math_util_h.sins(camera.calculate_pitch(camera.sCutsceneVars[10].point, camera.sCutsceneVars[9].point)) * 100))

	Scratch.cutscene_dialog_move_mario_shoulder_posY[1] = c.pos[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_dialog_move_mario_shoulder_posY, Scratch.cutscene_dialog_move_mario_shoulder_pos[2], F32(0.05))
	c.pos[2] = Scratch.cutscene_dialog_move_mario_shoulder_posY[1]
	c.pos[1] = Scratch.cutscene_dialog_move_mario_shoulder_pos[1]
	c.pos[3] = Scratch.cutscene_dialog_move_mario_shoulder_pos[3]
end

-- from src/game/camera.c:cutscene_dialog_create_dialog_box L8973-8982
function camera.cutscene_dialog_create_dialog_box(c: GroupsTypesHPlus3.Camera)
	if c.cutscene == GroupsTypesHPlus3.CUTSCENE_RACE_DIALOG then
		GroupsIngameMenuPlus1.create_dialog_box_with_response(camera.sCutsceneDialogID)
	else
		GroupsIngameMenuPlus1.create_dialog_box(camera.sCutsceneDialogID)
	end

	-- ! Unused. This may have been used before sCutsceneDialogResponse was implemented.
	camera.sCutsceneVars[9].angle[1] = GroupsIngameMenuPlus1.DIALOG_RESPONSE_NOT_DEFINED
end

-- from src/game/camera.c:cutscene_dialog L8987-9008
function camera.cutscene_dialog(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_dialog_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_dialog_move_mario_shoulder, c, 0, -1)
	camera.cutscene_event(camera.cutscene_dialog_create_dialog_box, c, 10, 10)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))

	if GroupsIngameMenuPlus1.gDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
		camera.sCutsceneDialogResponse = U8(GroupsIngameMenuPlus1.gDialogResponse)
	end

	if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE and camera.sCutsceneVars[9].angle[1] ~= 0 then
		if c.cutscene ~= GroupsTypesHPlus3.CUTSCENE_RACE_DIALOG then
			camera.sCutsceneDialogResponse = U8(GroupsIngameMenuPlus1.DIALOG_RESPONSE_NOT_DEFINED)
		end

		camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
		camera.retrieve_info_star(c)
		camera.transition_next_state(c, 15)
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
		camera.cutscene_unsoften_music(c)
	end
end

-- from src/game/camera.c:cutscene_dialog_set_flag L9013-9015
function camera.cutscene_dialog_set_flag(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_dialog_end L9020-9024
function camera.cutscene_dialog_end(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
	c.cutscene = 0
	ObjectHelpers.clear_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_DIALOG))
end

-- from src/game/camera.c:cutscene_read_message_start L9031-9042
function camera.cutscene_read_message_start(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_soften_music(c)
	camera.transition_next_state(c, 30)
	camera.reset_pan_distance(c)
	camera.store_info_star(c)

	camera.sCutsceneVars[2].angle[1] = camera.sCUpCameraPitch
	camera.sCutsceneVars[2].angle[2] = camera.sModeOffsetYaw
	camera.sCUpCameraPitch = -0x830
	camera.sModeOffsetYaw = 0
	camera.sCutsceneVars[1].angle[1] = 0
end

-- from src/game/camera.c:unused_cam_to_mario L9044-9050
function camera.unused_cam_to_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3s_set(Scratch.unused_cam_to_mario_dir, 0, camera.sMarioCamState.faceAngle[2], 0)
	camera.offset_rotated_coords(c.pos, camera.sMarioCamState.pos, Scratch.unused_cam_to_mario_dir, 0, 100, 190)
	camera.offset_rotated_coords(c.focus, camera.sMarioCamState.pos, Scratch.unused_cam_to_mario_dir, 0, 70, -20)
end

-- from src/game/camera.c:cutscene_read_message L9055-9089
function camera.cutscene_read_message(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_read_message_start, c, 0, 0)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))

	if camera.sCutsceneVars[1].angle[1] == 0 then
		-- Do nothing until message is gone.
		if GroupsIngameMenuPlus1.get_dialog_id() ~= IncludeDialogIdsH.DIALOG_NONE then
			camera.sCutsceneVars[1].angle[1] = S16(camera.sCutsceneVars[1].angle[1] + 1)
			ObjectHelpers.set_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_DIALOG))
		end
	elseif camera.sCutsceneVars[1].angle[1] == 1 then
		-- Leave the dialog.
		camera.move_mario_head_c_up(c)
		camera.update_c_up(c, c.focus, c.pos)

		-- This could cause softlocks. If a message starts one frame after another one closes, the
		-- cutscene will never end.
		if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
			camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
			camera.retrieve_info_star(c)
			camera.transition_next_state(c, 15)
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
			ObjectHelpers.clear_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_DIALOG))
			-- Retrieve previous state
			camera.sCUpCameraPitch = camera.sCutsceneVars[2].angle[1]
			camera.sModeOffsetYaw = camera.sCutsceneVars[2].angle[2]
			camera.cutscene_unsoften_music(c)
		end
	end
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_read_message_set_flag L9094-9096
function camera.cutscene_read_message_set_flag(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_read_message_end L9101-9104
function camera.cutscene_read_message_end(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
	c.cutscene = 0
end

-- from src/game/camera.c:cutscene_exit_succ_start L9112-9117
function camera.cutscene_exit_succ_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[8].point, camera.sMarioCamState.pos)
	SrcEngineMathUtil.vec3s_copy(camera.sCutsceneVars[8].angle, camera.sMarioCamState.faceAngle)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[7].point, 6, 363, 543)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 137, 226, 995)
end

-- from src/game/camera.c:cutscene_non_painting_set_cam_pos L9122-9149
function camera.cutscene_non_painting_set_cam_pos(c: GroupsTypesHPlus3.Camera)
	if camera.gPrevLevel == IncludeLevelTableH.LEVEL_HMC then
		SrcEngineMathUtil.vec3f_set(c.pos, 3465, -1008, -2961)
	elseif camera.gPrevLevel == IncludeLevelTableH.LEVEL_COTMC then
		SrcEngineMathUtil.vec3f_set(c.pos, 3465, -1008, -2961)
	elseif camera.gPrevLevel == IncludeLevelTableH.LEVEL_RR then
		SrcEngineMathUtil.vec3f_set(c.pos, -3741, 3151, 6065)
	elseif camera.gPrevLevel == IncludeLevelTableH.LEVEL_WMOTR then
		SrcEngineMathUtil.vec3f_set(c.pos, 1972, 3230, 5891)
	else
		camera.offset_rotated(c.pos, camera.sCutsceneVars[8].point, camera.sCutsceneVars[6].point, camera.sCutsceneVars[8].angle)
		const floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], F32(c.pos[2] + 1000), c.pos[3], Scratch.cutscene_non_painting_set_cam_pos_floor)
		c.pos[2] = F32(floorHeight + 125)
	end
end

-- from src/game/camera.c:cutscene_non_painting_set_cam_focus L9154-9165
function camera.cutscene_non_painting_set_cam_focus(c: GroupsTypesHPlus3.Camera)
	camera.offset_rotated(c.focus, camera.sCutsceneVars[8].point, camera.sCutsceneVars[7].point, camera.sCutsceneVars[8].angle)

	if camera.gPrevLevel == IncludeLevelTableH.LEVEL_COTMC or camera.gPrevLevel == IncludeLevelTableH.LEVEL_HMC or camera.gPrevLevel == IncludeLevelTableH.LEVEL_RR or camera.gPrevLevel == IncludeLevelTableH.LEVEL_WMOTR then
		c.focus[1] = F32(c.pos[1] + F32(F32(camera.sMarioCamState.pos[1] - c.pos[1]) * F32(0.7)))
		c.focus[2] = F32(c.pos[2] + F32(F32(camera.sMarioCamState.pos[2] - c.pos[2]) * F32(0.4)))
		c.focus[3] = F32(c.pos[3] + F32(F32(camera.sMarioCamState.pos[3] - c.pos[3]) * F32(0.7)))
	else
		c.focus[2] = F32(c.pos[2] + F32(F32(camera.sMarioCamState.pos[2] - c.pos[2]) * F32(0.2)))
	end
end

-- from src/game/camera.c:cutscene_exit_bowser_succ_focus_left L9170-9172
function camera.cutscene_exit_bowser_succ_focus_left(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_exit_bowser_succ_focus_left_value[1] = camera.sCutsceneVars[7].point[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_exit_bowser_succ_focus_left_value, -24, F32(0.05))
	camera.sCutsceneVars[7].point[1] = Scratch.cutscene_exit_bowser_succ_focus_left_value[1]
end

-- from src/game/camera.c:cutscene_exit_bowser_key_toss_shake L9178-9183
function camera.cutscene_exit_bowser_key_toss_shake(c: GroupsTypesHPlus3.Camera)
	-- ! Unnecessary check.
	if c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_BOWSER_SUCC then
		camera.set_camera_pitch_shake(0x800, 0x40, 0x800)
	end
end

-- from src/game/camera.c:cutscene_exit_succ_shake_landing L9188-9190
function camera.cutscene_exit_succ_shake_landing(c: GroupsTypesHPlus3.Camera)
	camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_EXPLOSION)
end

-- from src/game/camera.c:cutscene_exit_bowser_succ L9195-9202
function camera.cutscene_exit_bowser_succ(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_exit_succ_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_pos, c, 0, -1)
	camera.cutscene_event(camera.cutscene_exit_bowser_succ_focus_left, c, 18, -1)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_focus, c, 0, -1)
	camera.cutscene_event(camera.cutscene_exit_bowser_key_toss_shake, c, 125, 125)
	camera.cutscene_event(camera.cutscene_exit_succ_shake_landing, c, 41, 41)
end

-- from src/game/camera.c:cutscene_non_painting_end L9207-9220
function camera.cutscene_non_painting_end(c: GroupsTypesHPlus3.Camera)
	c.cutscene = 0

	if c.defMode == GroupsTypesHPlus3.CAMERA_MODE_CLOSE then
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
	else
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM
	end

	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.transition_next_state(c, 60)
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_exit_non_painting_succ_override_cvar L9225-9227
function camera.cutscene_exit_non_painting_succ_override_cvar(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 137, 246, 1115)
end

-- from src/game/camera.c:cutscene_exit_non_painting_succ L9232-9240
function camera.cutscene_exit_non_painting_succ(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_exit_succ_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_exit_non_painting_succ_override_cvar, c, 0, 0)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_pos, c, 0, -1)
	camera.cutscene_event(camera.cutscene_exit_bowser_succ_focus_left, c, 18, -1)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_focus, c, 0, -1)
	camera.cutscene_event(camera.cutscene_exit_succ_shake_landing, c, 41, 41)
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_non_painting_death_start L9247-9253
function camera.cutscene_non_painting_death_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[8].point, camera.sMarioCamState.pos)
	SrcEngineMathUtil.vec3s_copy(camera.sCutsceneVars[8].angle, camera.sMarioCamState.faceAngle)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[7].point, -42, 350, 727)
	-- This is always overwritten, except in the unused cutscene_exit_bowser_death()
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 107, 226, 1187)
end

-- from src/game/camera.c:cutscene_exit_bowser_death L9263-9267
function camera.cutscene_exit_bowser_death(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_non_painting_death_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_pos, c, 0, -1)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_focus, c, 0, -1)
end

-- from src/game/camera.c:cutscene_non_painting_death_override_offset L9273-9285
function camera.cutscene_non_painting_death_override_offset(c: GroupsTypesHPlus3.Camera)
	if camera.gPrevLevel == IncludeLevelTableH.LEVEL_HMC then
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 187, 369, -197)
	elseif camera.gPrevLevel == IncludeLevelTableH.LEVEL_COTMC then
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 187, 369, -197)
	else
		SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[6].point, 107, 246, 1307)
	end
end

-- from src/game/camera.c:cutscene_non_painting_death L9290-9296
function camera.cutscene_non_painting_death(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_non_painting_death_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_non_painting_death_override_offset, c, 0, 0)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_pos, c, 0, -1)
	camera.cutscene_event(camera.cutscene_non_painting_set_cam_focus, c, 0, -1)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_cap_switch_press_start L9306-9316
function camera.cutscene_cap_switch_press_start(c: GroupsTypesHPlus3.Camera)
	camera.store_info_star(c)
	const yaw = camera.calculate_yaw(camera.sMarioCamState.pos, c.pos)
	camera.sCutsceneVars[4].angle[2] = 0x1200
	-- Basically the amount of rotation to get from behind Mario to in front of Mario
	camera.sCutsceneVars[2].angle[2] = S16(bit32.band(yaw - (camera.sMarioCamState.faceAngle[2] + camera.sCutsceneVars[4].angle[2]), 0xFF00))
end

-- from src/game/camera.c:cutscene_cap_switch_press_rotate_around_mario L9322-9343
function camera.cutscene_cap_switch_press_rotate_around_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_cap_switch_press_rotate_around_mario_dist, Scratch.cutscene_cap_switch_press_rotate_around_mario_pitch, Scratch.cutscene_cap_switch_press_rotate_around_mario_yaw)

	-- cvar3 wraps around until it reaches 0x1000
	if camera.sCutsceneVars[4].angle[2] ~= 0x1000 then
		camera.sCutsceneVars[4].angle[2] = S16(camera.sCutsceneVars[4].angle[2] + 0x100)
	end

	-- cvar1 wraps until 0
	if camera.sCutsceneVars[2].angle[2] ~= 0 then
		camera.sCutsceneVars[2].angle[2] = S16(camera.sCutsceneVars[2].angle[2] + 0x100)
	end

	Scratch.cutscene_cap_switch_press_rotate_around_mario_yaw[1] = S16(camera.sMarioCamState.faceAngle[2] + camera.sCutsceneVars[4].angle[2] + camera.sCutsceneVars[2].angle[2])
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_cap_switch_press_rotate_around_mario_dist[1], Scratch.cutscene_cap_switch_press_rotate_around_mario_pitch[1], Scratch.cutscene_cap_switch_press_rotate_around_mario_yaw[1])
end

-- from src/game/camera.c:cutscene_cap_switch_press_lower_cam L9348-9350
function camera.cutscene_cap_switch_press_lower_cam(c: GroupsTypesHPlus3.Camera)
	camera.rotate_and_move_vec3f(c.pos, camera.sMarioCamState.pos, 0, -0x20, 0)
end

-- from src/game/camera.c:cutscene_cap_switch_press_approach_mario L9355-9367
function camera.cutscene_cap_switch_press_approach_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_cap_switch_press_approach_mario_dist, Scratch.cutscene_cap_switch_press_approach_mario_pitch, Scratch.cutscene_cap_switch_press_approach_mario_yaw)
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_cap_switch_press_approach_mario_dist, 195, F32(0.2))
	camera.approach_s16_asymptotic_bool(Scratch.cutscene_cap_switch_press_approach_mario_pitch, 0, 0x10)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_cap_switch_press_approach_mario_dist[1], Scratch.cutscene_cap_switch_press_approach_mario_pitch[1], Scratch.cutscene_cap_switch_press_approach_mario_yaw[1])

	Scratch.cutscene_cap_switch_press_approach_mario_focus[1] = c.focus[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_cap_switch_press_approach_mario_focus, camera.sMarioCamState.pos[1], F32(0.1))
	c.focus[1] = Scratch.cutscene_cap_switch_press_approach_mario_focus[1]
	Scratch.cutscene_cap_switch_press_approach_mario_focus[1] = c.focus[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_cap_switch_press_approach_mario_focus, F32(camera.sMarioCamState.pos[2] + 110), F32(0.1))
	c.focus[2] = Scratch.cutscene_cap_switch_press_approach_mario_focus[1]
	Scratch.cutscene_cap_switch_press_approach_mario_focus[1] = c.focus[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_cap_switch_press_approach_mario_focus, camera.sMarioCamState.pos[3], F32(0.1))
	c.focus[3] = Scratch.cutscene_cap_switch_press_approach_mario_focus[1]
end

-- from src/game/camera.c:cutscene_cap_switch_press_pan_left L9372-9377
function camera.cutscene_cap_switch_press_pan_left(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sMarioCamState.pos)
	c.focus[2] = F32(c.focus[2] + 110)
	Scratch.cutscene_cap_switch_press_pan_left_angle[1] = camera.sCutsceneVars[1].angle[2]
	camera.camera_approach_s16_symmetric_bool(Scratch.cutscene_cap_switch_press_pan_left_angle, 0x800, 0x20)
	camera.sCutsceneVars[1].angle[2] = Scratch.cutscene_cap_switch_press_pan_left_angle[1]
	camera.pan_camera(c, camera.sCutsceneVars[1].angle[1], camera.sCutsceneVars[1].angle[2])
end

-- from src/game/camera.c:cutscene_cap_switch_press_create_dialog L9382-9384
function camera.cutscene_cap_switch_press_create_dialog(c: GroupsTypesHPlus3.Camera)
	GroupsIngameMenuPlus1.create_dialog_box_with_response(buffer.readi32((camera.gCutsceneFocus :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + IncludeDialogIdsH.DIALOG_010)
end

-- from src/game/camera.c:unused_cap_switch_retrieve_info L9386-9389
function camera.unused_cap_switch_retrieve_info(c: GroupsTypesHPlus3.Camera)
	camera.retrieve_info_star(c)
	camera.transition_next_state(c, 30)
end

-- from src/game/camera.c:cutscene_cap_switch_press L9394-9421
function camera.cutscene_cap_switch_press(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))

	camera.cutscene_event(camera.cutscene_cap_switch_press_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_cap_switch_press_approach_mario, c, 0, 30)
	camera.cutscene_event(camera.cutscene_cap_switch_press_pan_left, c, 0, -1)
	camera.cutscene_event(camera.cutscene_cap_switch_press_rotate_around_mario, c, 30, -1)
	camera.cutscene_event(camera.cutscene_cap_switch_press_lower_cam, c, 10, 70)
	camera.cutscene_event(camera.cutscene_cap_switch_press_create_dialog, c, 10, 10)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_cap_switch_press_dist, Scratch.cutscene_cap_switch_press_pitch, Scratch.cutscene_cap_switch_press_yaw)

	if GroupsIngameMenuPlus1.gDialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
		camera.sCutsceneVars[5].angle[1] = S16(GroupsIngameMenuPlus1.gDialogResponse)
	end

	if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE and camera.sCutsceneVars[5].angle[1] ~= 0 then
		camera.sCutsceneDialogResponse = U8(camera.sCutsceneVars[5].angle[1])
		if camera.sCutsceneVars[5].angle[1] == 1 then
			camera.cap_switch_save(S16(buffer.readi32((camera.gCutsceneFocus :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))
		end
		camera.stop_cutscene_and_retrieve_stored_info(c)
		camera.transition_next_state(c, 30)
	end
end

-- from src/game/camera.c:cutscene_unlock_key_door_start L9430-9439
function camera.cutscene_unlock_key_door_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[2].point, c.focus)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_unlock_key_door_start_posOff, -206, 108, 234)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_unlock_key_door_start_focusOff, 48, 104, -193)
	camera.offset_rotated(camera.sCutsceneVars[3].point, camera.sMarioCamState.pos, Scratch.cutscene_unlock_key_door_start_posOff, camera.sMarioCamState.faceAngle)
	camera.offset_rotated(camera.sCutsceneVars[4].point, camera.sMarioCamState.pos, Scratch.cutscene_unlock_key_door_start_focusOff, camera.sMarioCamState.faceAngle)
end

-- from src/game/camera.c:cutscene_unlock_key_door_approach_mario L9445-9448
function camera.cutscene_unlock_key_door_approach_mario(c: GroupsTypesHPlus3.Camera)
	camera.approach_vec3f_asymptotic(c.pos, camera.sCutsceneVars[3].point, F32(0.1), F32(0.1), F32(0.1))
	camera.approach_vec3f_asymptotic(c.focus, camera.sCutsceneVars[4].point, F32(0.1), F32(0.1), F32(0.1))
end

-- from src/game/camera.c:cutscene_unlock_key_door_focus_lock L9453-9455
function camera.cutscene_unlock_key_door_focus_lock(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_unlock_key_door_focus_lock_point[1] = camera.sCutsceneVars[4].point[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_unlock_key_door_focus_lock_point, F32(camera.sMarioCamState.pos[2] + 140), F32(0.07))
	camera.sCutsceneVars[4].point[2] = Scratch.cutscene_unlock_key_door_focus_lock_point[1]
end

-- from src/game/camera.c:cutscene_unlock_key_door_stub L9457-9458
function camera.cutscene_unlock_key_door_stub(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_unlock_key_door_fly_back L9463-9466
function camera.cutscene_unlock_key_door_fly_back(c: GroupsTypesHPlus3.Camera)
	camera.approach_vec3f_asymptotic(c.pos, camera.sCutsceneVars[1].point, F32(0.1), F32(0.1), F32(0.1))
	camera.approach_vec3f_asymptotic(c.focus, camera.sCutsceneVars[2].point, F32(0.1), F32(0.1), F32(0.1))
end

-- from src/game/camera.c:cutscene_unlock_key_door_fov_shake L9471-9473
function camera.cutscene_unlock_key_door_fov_shake(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_set_fov_shake_preset(1)
end

-- from src/game/camera.c:cutscene_unlock_key_door L9478-9485
function camera.cutscene_unlock_key_door(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_unlock_key_door_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_unlock_key_door_approach_mario, c, 0, 123)
	camera.cutscene_event(camera.cutscene_unlock_key_door_fly_back, c, 124, -1)
	camera.cutscene_event(camera.cutscene_unlock_key_door_fov_shake, c, 79, 79)
	camera.cutscene_event(camera.cutscene_unlock_key_door_focus_lock, c, 70, 110)
	camera.cutscene_event(camera.cutscene_unlock_key_door_stub, c, 112, 112)
end

-- from src/game/camera.c:intro_peach_move_camera_start_to_pipe L9491-9516
function camera.intro_peach_move_camera_start_to_pipe(c: GroupsTypesHPlus3.Camera, positionSpline: { GroupsTypesHPlus3.CutsceneSplinePoint }, focusSpline: { GroupsTypesHPlus3.CutsceneSplinePoint }): number
	local posReturn = 0
	local focusReturn = 0

	-- The position spline's speed parameters are all 0, so sCutsceneSplineSegmentProgress doesn't get
	-- updated. Otherwise position would move two frames ahead, and c->focus would always be one frame
	-- further along the spline than c->pos.
	Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	posReturn = camera.move_point_along_spline(c.pos, positionSpline, Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment, Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress[1]
	Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	focusReturn = camera.move_point_along_spline(c.focus, focusSpline, Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment, Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.intro_peach_move_camera_start_to_pipe_sCutsceneSplineSegmentProgress[1]

	-- The two splines used by this function are reflected in the horizontal plane for some reason,
	-- so they are rotated every frame. Why do this, Nintendo?
	camera.rotate_in_xz(c.focus, c.focus, S16(GroupsTypesHPlus3.DEGREES(-180)))
	camera.rotate_in_xz(c.pos, c.pos, S16(GroupsTypesHPlus3.DEGREES(-180)))

	SrcEngineMathUtil.vec3f_set(Scratch.intro_peach_move_camera_start_to_pipe_offset, -1328, 260, 4664)
	SrcEngineMathUtil.vec3f_add(c.focus, Scratch.intro_peach_move_camera_start_to_pipe_offset)
	SrcEngineMathUtil.vec3f_add(c.pos, Scratch.intro_peach_move_camera_start_to_pipe_offset)

	posReturn += focusReturn -- Unused
	return focusReturn
end

-- from src/game/camera.c:peach_letter_text L9521-9523
function camera.peach_letter_text(c: GroupsTypesHPlus3.Camera)
	GroupsIngameMenuPlus1.create_dialog_box(IncludeDialogIdsH.DIALOG_020)
end

-- from src/game/camera.c:play_sound_peach_reading_letter L9526-9528
function camera.play_sound_peach_reading_letter(c: GroupsTypesHPlus3.Camera)
	Audio.play_sound(IncludeSoundsH.SOUND_PEACH_DEAR_MARIO, Audio.gGlobalSoundSource)
end

-- from src/game/camera.c:cutscene_intro_peach_start_to_pipe_spline L9535-9540
function camera.cutscene_intro_peach_start_to_pipe_spline(c: GroupsTypesHPlus3.Camera)
	if camera.intro_peach_move_camera_start_to_pipe(c, camera.sIntroStartToPipePosition, camera.sIntroStartToPipeFocus) ~= 0 then
		camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVE_C_UP_MODE)))
		camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_LOOP)
	end
end

-- from src/game/camera.c:cutscene_intro_peach_dialog L9545-9553
function camera.cutscene_intro_peach_dialog(c: GroupsTypesHPlus3.Camera)
	if GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalPos, c.pos)
		SrcEngineMathUtil.vec3f_copy(camera.gLakituState.goalFocus, c.focus)
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, bit32.bor(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE)))
		camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
		c.cutscene = 0
	end
end

-- from src/game/camera.c:cutscene_intro_peach_follow_pipe_spline L9555-9558
function camera.cutscene_intro_peach_follow_pipe_spline(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_intro_peach_follow_pipe_spline_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_intro_peach_follow_pipe_spline_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.sIntroPipeToDialogPosition, Scratch.cutscene_intro_peach_follow_pipe_spline_segment, Scratch.cutscene_intro_peach_follow_pipe_spline_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_intro_peach_follow_pipe_spline_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_intro_peach_follow_pipe_spline_progress[1]
	Scratch.cutscene_intro_peach_follow_pipe_spline_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_intro_peach_follow_pipe_spline_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sIntroPipeToDialogFocus, Scratch.cutscene_intro_peach_follow_pipe_spline_segment, Scratch.cutscene_intro_peach_follow_pipe_spline_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_intro_peach_follow_pipe_spline_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_intro_peach_follow_pipe_spline_progress[1]
end

-- from src/game/camera.c:cutscene_intro_peach_clear_cutscene_status L9560-9562
function camera.cutscene_intro_peach_clear_cutscene_status(c: GroupsTypesHPlus3.Camera)
	camera.sMarioCamState.cameraEvent = 0
end

-- from src/game/camera.c:cutscene_intro_peach_zoom_fov L9567-9570
function camera.cutscene_intro_peach_zoom_fov(c: GroupsTypesHPlus3.Camera)
	camera.sFOVState.fov = 8
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_ZOOM_30)
end

-- from src/game/camera.c:cutscene_intro_peach_reset_spline L9575-9581
function camera.cutscene_intro_peach_reset_spline(c: GroupsTypesHPlus3.Camera)
	camera.sCutsceneSplineSegment = 0
	camera.sCutsceneSplineSegmentProgress = F32(0.1)
	-- ! @bug since this event is only called for one frame, this handheld shake is turned off on the
	-- ! next frame.
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_HIGH)
end

-- from src/game/camera.c:cutscene_intro_peach_handheld_shake_off L9587-9589
function camera.cutscene_intro_peach_handheld_shake_off(c: GroupsTypesHPlus3.Camera)
	camera.set_handheld_shake(GroupsTypesHPlus3.HAND_CAM_SHAKE_OFF)
end

-- from src/game/camera.c:intro_pipe_exit_text L9591-9593
function camera.intro_pipe_exit_text(c: GroupsTypesHPlus3.Camera)
	GroupsIngameMenuPlus1.create_dialog_box(IncludeDialogIdsH.DIALOG_033)
end

-- from src/game/camera.c:play_sound_intro_turn_on_hud L9596-9598
function camera.play_sound_intro_turn_on_hud(c: GroupsTypesHPlus3.Camera)
	camera.play_sound_rbutton_changed()
end

-- from src/game/camera.c:cutscene_intro_peach_fly_to_pipe L9604-9620
function camera.cutscene_intro_peach_fly_to_pipe(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.play_sound_intro_turn_on_hud, c, 818, 818)

	camera.cutscene_spawn_obj(6, 1)
	camera.cutscene_event(camera.cutscene_intro_peach_start_flying_music, c, 0, 0)
	camera.cutscene_event(camera.cutscene_intro_peach_start_to_pipe_spline, c, 0, -1)

	camera.cutscene_event(camera.cutscene_intro_peach_clear_cutscene_status, c, 717, 717)

	camera.clamp_pitch(c.pos, c.focus, 0x3B00, -0x3B00)
	camera.sCutsceneVars[2].point[2] = 400
end

-- from src/game/camera.c:cutscene_intro_peach_mario_appears L9625-9643
function camera.cutscene_intro_peach_mario_appears(c: GroupsTypesHPlus3.Camera)
	camera.sMarioCamState.cameraEvent = 0
	camera.cutscene_event(camera.cutscene_intro_peach_reset_spline, c, 0, 0)
	camera.cutscene_event(camera.cutscene_intro_peach_follow_pipe_spline, c, 0, -1)
	camera.cutscene_event(camera.cutscene_intro_peach_handheld_shake_off, c, 70, 70)
	camera.cutscene_event(camera.intro_pipe_exit_text, c, 250, 250)

	Scratch.cutscene_intro_peach_mario_appears_value[1] = camera.sCutsceneVars[2].point[2]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_intro_peach_mario_appears_value, F32(F32(80 + camera.sMarioGeometry.currFloorHeight) + F32(F32(camera.sMarioCamState.pos[2] - camera.sMarioGeometry.currFloorHeight) * F32(1.1))), F32(0.4))
	camera.sCutsceneVars[2].point[2] = Scratch.cutscene_intro_peach_mario_appears_value[1]

	-- Make the camera look up as Mario jumps out of the pipe
	if c.focus[2] < camera.sCutsceneVars[2].point[2] then
		c.focus[2] = camera.sCutsceneVars[2].point[2]
	end

	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_UNUSED_CUTSCENE_ACTIVE))
end

-- from src/game/camera.c:cutscene_intro_peach_reset_fov L9648-9650
function camera.cutscene_intro_peach_reset_fov(c: GroupsTypesHPlus3.Camera)
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_DEFAULT)
end

-- from src/game/camera.c:cutscene_intro_peach_letter L9655-9674
function camera.cutscene_intro_peach_letter(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_spawn_obj(5, 0)
	camera.cutscene_event(camera.cutscene_intro_peach_zoom_fov, c, 0, 0)
	camera.cutscene_event(camera.cutscene_intro_peach_start_letter_music, c, 65, 65)

	camera.cutscene_event(camera.cutscene_intro_peach_start_to_pipe_spline, c, 0, 0)
	camera.cutscene_event(camera.peach_letter_text, c, 65, 65)

	camera.cutscene_event(camera.play_sound_peach_reading_letter, c, 83, 83)

	if camera.gCutsceneTimer > 120 and GroupsIngameMenuPlus1.get_dialog_id() == IncludeDialogIdsH.DIALOG_NONE then
		-- Start the next scene
		camera.gCutsceneTimer = GroupsTypesHPlus3.CUTSCENE_LOOP
	end

	camera.clamp_pitch(c.pos, c.focus, 0x3B00, -0x3B00)
end

-- from src/game/camera.c:cutscene_end_waving_start L9679-9681
function camera.cutscene_end_waving_start(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_reset_spline()
end

-- from src/game/camera.c:cutscene_end_waving L9726-9731
function camera.cutscene_end_waving(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_end_waving_start, c, 0, 0)
	Scratch.cutscene_end_waving_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.gEndWavingPos, Scratch.cutscene_end_waving_sCutsceneSplineSegment, Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_end_waving_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress[1]
	Scratch.cutscene_end_waving_sCutsceneSplineSegment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.gEndWavingFocus, Scratch.cutscene_end_waving_sCutsceneSplineSegment, Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_end_waving_sCutsceneSplineSegment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_end_waving_sCutsceneSplineSegmentProgress[1]
	camera.cutscene_spawn_obj(6, 120)
end

-- from src/game/camera.c:cutscene_credits_reset_spline L9736-9738
function camera.cutscene_credits_reset_spline(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_reset_spline()
end

-- from src/game/camera.c:cutscene_credits L9784-9888
function camera.cutscene_credits(c: GroupsTypesHPlus3.Camera)
	local focus: { GroupsTypesHPlus3.CutsceneSplinePoint }
	local pos: { GroupsTypesHPlus3.CutsceneSplinePoint }

	camera.cutscene_event(camera.cutscene_credits_reset_spline, c, 0, 0)

	if camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BOB then
		pos = camera.sBoBCreditsSplinePositions
		focus = camera.sBoBCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WF then
		pos = camera.sWFCreditsSplinePositions
		focus = camera.sWFCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_JRB_MAIN then
		pos = camera.sJRBCreditsSplinePositions
		focus = camera.sJRBCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CCM_SLIDE then
		pos = camera.sCCMSlideCreditsSplinePositions
		focus = camera.sCCMSlideCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_BBH then
		pos = camera.sBBHCreditsSplinePositions
		focus = camera.sBBHCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_HMC then
		pos = camera.sHMCCreditsSplinePositions
		focus = camera.sHMCCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_WIGGLER then
		pos = camera.sTHIWigglerCreditsSplinePositions
		focus = camera.sTHIWigglerCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_LLL_VOLCANO then
		pos = camera.sVolcanoCreditsSplinePositions
		focus = camera.sVolcanoCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SSL_OUTSIDE then
		pos = camera.sSSLCreditsSplinePositions
		focus = camera.sSSLCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_DDD_WHIRLPOOL then
		pos = camera.sDDDCreditsSplinePositions
		focus = camera.sDDDCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SL_OUTSIDE then
		pos = camera.sSLCreditsSplinePositions
		focus = camera.sSLCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_WDW_MAIN then
		pos = camera.sWDWCreditsSplinePositions
		focus = camera.sWDWCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTM_OUTSIDE then
		pos = camera.sTTMCreditsSplinePositions
		focus = camera.sTTMCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_THI_HUGE then
		pos = camera.sTHIHugeCreditsSplinePositions
		focus = camera.sTHIHugeCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_TTC then
		pos = camera.sTTCCreditsSplinePositions
		focus = camera.sTTCCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_RR then
		pos = camera.sRRCreditsSplinePositions
		focus = camera.sRRCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_SA then
		pos = camera.sSACreditsSplinePositions
		focus = camera.sSACreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_COTMC then
		pos = camera.sCotMCCreditsSplinePositions
		focus = camera.sCotMCCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_DDD_SUB then
		pos = camera.sDDDSubCreditsSplinePositions
		focus = camera.sDDDSubCreditsSplineFocus
	elseif camera.gCurrLevelArea == GroupsTypesHPlus3.AREA_CCM_OUTSIDE then
		-- ! Checks if the "Snowman's Lost His Head" star was collected. The credits likely would
		-- ! have avoided the snowman if the player didn't collect that star, but in the end the
		-- ! developers decided against it.
		if bit32.btest(SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(Area.gCurrCourseNum)), bit32.lshift(1, 4)) then
			pos = camera.sCCMOutsideCreditsSplinePositions
			focus = camera.sCCMOutsideCreditsSplineFocus
		else
			pos = camera.sCCMOutsideCreditsSplinePositions
			focus = camera.sCCMOutsideCreditsSplineFocus
		end
	else
		pos = camera.sCCMOutsideCreditsSplinePositions
		focus = camera.sCCMOutsideCreditsSplineFocus
	end

	camera.copy_spline_segment(camera.sCurCreditsSplinePos, pos)
	camera.copy_spline_segment(camera.sCurCreditsSplineFocus, focus)
	Scratch.cutscene_credits_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_credits_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.pos, camera.sCurCreditsSplinePos, Scratch.cutscene_credits_segment, Scratch.cutscene_credits_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_credits_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_credits_progress[1]
	Scratch.cutscene_credits_segment[1] = camera.sCutsceneSplineSegment
	Scratch.cutscene_credits_progress[1] = camera.sCutsceneSplineSegmentProgress
	camera.move_point_along_spline(c.focus, camera.sCurCreditsSplineFocus, Scratch.cutscene_credits_segment, Scratch.cutscene_credits_progress)
	camera.sCutsceneSplineSegment = Scratch.cutscene_credits_segment[1]
	camera.sCutsceneSplineSegmentProgress = Scratch.cutscene_credits_progress[1]
	camera.player2_rotate_cam(c, -0x2000, 0x2000, -0x4000, 0x4000)
end

-- from src/game/camera.c:cutscene_sliding_doors_open_start L9893-9907
function camera.cutscene_sliding_doors_open_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_sliding_doors_open_start_dist, Scratch.cutscene_sliding_doors_open_start_pitch, Scratch.cutscene_sliding_doors_open_start_yaw)

	-- If the camera is too close, warp it backwards set it to a better angle.
	if Scratch.cutscene_sliding_doors_open_start_dist[1] < 500 then
		Scratch.cutscene_sliding_doors_open_start_dist[1] = 500
		Scratch.cutscene_sliding_doors_open_start_yaw[1] = S16(camera.sMarioCamState.faceAngle[2] + 0x8800)
		Scratch.cutscene_sliding_doors_open_start_pitch[1] = 0x800
	end

	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sMarioCamState.pos, c.pos, Scratch.cutscene_sliding_doors_open_start_dist[1], Scratch.cutscene_sliding_doors_open_start_pitch[1], Scratch.cutscene_sliding_doors_open_start_yaw[1])
end

-- from src/game/camera.c:cutscene_sliding_doors_open_set_cvars L9914-9918
function camera.cutscene_sliding_doors_open_set_cvars(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[2].point, camera.sMarioCamState.pos)
	SrcEngineMathUtil.vec3s_copy(camera.sCutsceneVars[1].angle, camera.sMarioCamState.faceAngle)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[1].point, 80, 325, 200)
end

-- from src/game/camera.c:cutscene_sliding_doors_go_under_doorway L9924-9926
function camera.cutscene_sliding_doors_go_under_doorway(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_sliding_doors_go_under_doorway_point[1] = camera.sCutsceneVars[1].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_sliding_doors_go_under_doorway_point, 75, 10)
	camera.sCutsceneVars[1].point[2] = Scratch.cutscene_sliding_doors_go_under_doorway_point[1]
end

-- from src/game/camera.c:cutscene_sliding_doors_fly_back_up L9931-9933
function camera.cutscene_sliding_doors_fly_back_up(c: GroupsTypesHPlus3.Camera)
	Scratch.cutscene_sliding_doors_fly_back_up_point[1] = camera.sCutsceneVars[1].point[2]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_sliding_doors_fly_back_up_point, 125, 10)
	camera.sCutsceneVars[1].point[2] = Scratch.cutscene_sliding_doors_fly_back_up_point[1]
end

-- from src/game/camera.c:cutscene_sliding_doors_follow_mario L9938-9959
function camera.cutscene_sliding_doors_follow_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(Scratch.cutscene_sliding_doors_follow_mario_pos, c.pos)
	-- Update cvar1 with Mario's position (the y value doesn't change)
	camera.sCutsceneVars[2].point[1] = camera.sMarioCamState.pos[1]
	camera.sCutsceneVars[2].point[3] = camera.sMarioCamState.pos[3]

	-- Decrease cvar0's offsets, moving the camera behind Mario at his eye height.
	Scratch.cutscene_sliding_doors_follow_mario_point[1] = camera.sCutsceneVars[1].point[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_sliding_doors_follow_mario_point, 0, F32(0.1))
	camera.sCutsceneVars[1].point[1] = Scratch.cutscene_sliding_doors_follow_mario_point[1]
	Scratch.cutscene_sliding_doors_follow_mario_point[1] = camera.sCutsceneVars[1].point[3]
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_sliding_doors_follow_mario_point, 125, 50)
	camera.sCutsceneVars[1].point[3] = Scratch.cutscene_sliding_doors_follow_mario_point[1]
	-- Update cvar0's angle
	camera.approach_vec3s_asymptotic(camera.sCutsceneVars[1].angle, camera.sMarioCamState.faceAngle, 16, 16, 16)

	-- Apply the offset to the camera's position
	camera.offset_rotated(Scratch.cutscene_sliding_doors_follow_mario_pos, camera.sCutsceneVars[2].point, camera.sCutsceneVars[1].point, camera.sCutsceneVars[1].angle)
	camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_sliding_doors_follow_mario_pos, F32(0.15), F32(0.05), F32(0.15))

	-- Focus on Mario's eye height
	camera.set_focus_rel_mario(c, 0, 125, 0, 0)
end

-- from src/game/camera.c:cutscene_sliding_doors_open L9965-9974
function camera.cutscene_sliding_doors_open(c: GroupsTypesHPlus3.Camera)
	camera.reset_pan_distance(c)
	camera.cutscene_event(camera.cutscene_sliding_doors_open_start, c, 0, 8)
	camera.cutscene_event(camera.cutscene_sliding_doors_open_set_cvars, c, 8, 8)
	camera.cutscene_event(camera.cutscene_sliding_doors_go_under_doorway, c, 8, 28)
	camera.cutscene_event(camera.cutscene_sliding_doors_fly_back_up, c, 29, -1)
	camera.cutscene_event(camera.cutscene_sliding_doors_follow_mario, c, 8, -1)
end

-- from src/game/camera.c:cutscene_double_doors_end L9979-9983
function camera.cutscene_double_doors_end(c: GroupsTypesHPlus3.Camera)
	camera.set_flag_post_door(c)
	c.cutscene = 0
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
end

-- from src/game/camera.c:cutscene_enter_painting_stub L9985-9986
function camera.cutscene_enter_painting_stub(c: GroupsTypesHPlus3.Camera)
	-- Empty in the C source.
end

-- from src/game/camera.c:cutscene_enter_painting L9992-10041
function camera.cutscene_enter_painting(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_enter_painting_stub, c, 0, 0)
	-- Zoom in
	camera.set_fov_function(GroupsTypesHPlus3.CAM_FOV_APP_20)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))

	const gRipplingPainting: PaintingsH.Painting? = Registry.Members.src__game__paintings.gRipplingPainting
	if gRipplingPainting ~= nil then
		Scratch.cutscene_enter_painting_paintingAngle[1] = 0
		Scratch.cutscene_enter_painting_paintingAngle[2] = S16(TruncS32(F32(F32(gRipplingPainting.yaw / 360) * 65536))) -- convert degrees to IAU
		Scratch.cutscene_enter_painting_paintingAngle[3] = 0

		Scratch.cutscene_enter_painting_focusOffset[1] = F32(gRipplingPainting.size / 2)
		Scratch.cutscene_enter_painting_focusOffset[2] = Scratch.cutscene_enter_painting_focusOffset[1]
		Scratch.cutscene_enter_painting_focusOffset[3] = 0

		Scratch.cutscene_enter_painting_paintingPos[1] = gRipplingPainting.posX
		Scratch.cutscene_enter_painting_paintingPos[2] = gRipplingPainting.posY
		Scratch.cutscene_enter_painting_paintingPos[3] = gRipplingPainting.posZ

		camera.offset_rotated(Scratch.cutscene_enter_painting_focus, Scratch.cutscene_enter_painting_paintingPos, Scratch.cutscene_enter_painting_focusOffset, Scratch.cutscene_enter_painting_paintingAngle)
		camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_enter_painting_focus, F32(0.1), F32(0.1), F32(0.1))
		Scratch.cutscene_enter_painting_focusOffset[3] = -F32(F32(F32(gRipplingPainting.size * 1000) / 2) / 307)
		camera.offset_rotated(Scratch.cutscene_enter_painting_focus, Scratch.cutscene_enter_painting_paintingPos, Scratch.cutscene_enter_painting_focusOffset, Scratch.cutscene_enter_painting_paintingAngle)
		const highFloorResult: number = Registry.Members.src__engine__surface_collision.find_floor(Scratch.cutscene_enter_painting_focus[1], F32(Scratch.cutscene_enter_painting_focus[2] + 500), Scratch.cutscene_enter_painting_focus[3], Scratch.cutscene_enter_painting_highFloor)
		const floorHeight = F32(highFloorResult + 125)

		if Scratch.cutscene_enter_painting_focus[2] < floorHeight then
			Scratch.cutscene_enter_painting_focus[2] = floorHeight
		end

		if c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_PAINTING then
			camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_enter_painting_focus, F32(0.2), F32(0.1), F32(0.2))
		else
			camera.approach_vec3f_asymptotic(c.pos, Scratch.cutscene_enter_painting_focus, F32(0.9), F32(0.9), F32(0.9))
		end

		Registry.Members.src__engine__surface_collision.find_floor(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 50), camera.sMarioCamState.pos[3], Scratch.cutscene_enter_painting_floor)

		const floorType = (Scratch.cutscene_enter_painting_floor[1] :: GroupsTypesHPlus3.Surface).type_
		if floorType < IncludeSurfaceTerrainsH.SURFACE_PAINTING_WOBBLE_A6 or floorType > IncludeSurfaceTerrainsH.SURFACE_PAINTING_WARP_F9 then
			c.cutscene = 0
			camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
			camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
		end
	end
	c.mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
end

-- from src/game/camera.c:cutscene_exit_painting_start L10052-10076
function camera.cutscene_exit_painting_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[3].point, 258, -352, 1189)
	SrcEngineMathUtil.vec3f_set(camera.sCutsceneVars[2].point, 65, -155, 444)

	if camera.gPrevLevel == IncludeLevelTableH.LEVEL_TTM then
		camera.sCutsceneVars[2].point[2] = 0
		camera.sCutsceneVars[2].point[3] = 0
	end
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, camera.sMarioCamState.pos)
	camera.sCutsceneVars[1].angle[1] = 0
	camera.sCutsceneVars[1].angle[2] = camera.sMarioCamState.faceAngle[2]
	camera.sCutsceneVars[1].angle[3] = 0
	camera.offset_rotated(c.focus, camera.sCutsceneVars[1].point, camera.sCutsceneVars[2].point, camera.sCutsceneVars[1].angle)
	camera.offset_rotated(c.pos, camera.sCutsceneVars[1].point, camera.sCutsceneVars[3].point, camera.sCutsceneVars[1].angle)
	local floorHeight: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], F32(c.pos[2] + 10), c.pos[3], Scratch.cutscene_exit_painting_start_floor)

	if floorHeight ~= SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		floorHeight = F32(floorHeight + 60)
		if c.pos[2] < floorHeight then
			c.pos[2] = floorHeight
		end
	end
end

-- from src/game/camera.c:cutscene_exit_painting_move_to_mario L10081-10095
function camera.cutscene_exit_painting_move_to_mario(c: GroupsTypesHPlus3.Camera)
	-- ! Tricky math: Since offset_rotated() flips Z offsets, you'd expect a positive Z offset to move
	-- ! the camera into the wall. However, Mario's faceAngle always points into the painting, so a
	-- ! positive Z offset moves the camera "behind" Mario, away from the painting.
	-- !
	-- ! In the success cutscene, when Mario jumps out face-first, only his gfx angle is updated. His
	-- ! actual face angle isn't updated until after the cutscene.
	Scratch.cutscene_exit_painting_move_to_mario_value[1] = camera.sCutsceneVars[3].point[1]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_exit_painting_move_to_mario_value, 178, F32(0.05))
	camera.sCutsceneVars[3].point[1] = Scratch.cutscene_exit_painting_move_to_mario_value[1]
	Scratch.cutscene_exit_painting_move_to_mario_value[1] = camera.sCutsceneVars[3].point[3]
	camera.approach_f32_asymptotic_bool(Scratch.cutscene_exit_painting_move_to_mario_value, 889, F32(0.05))
	camera.sCutsceneVars[3].point[3] = Scratch.cutscene_exit_painting_move_to_mario_value[1]
	camera.offset_rotated(Scratch.cutscene_exit_painting_move_to_mario_pos, camera.sCutsceneVars[1].point, camera.sCutsceneVars[3].point, camera.sCutsceneVars[1].angle)
	c.pos[1] = Scratch.cutscene_exit_painting_move_to_mario_pos[1]
	c.pos[3] = Scratch.cutscene_exit_painting_move_to_mario_pos[3]
end

-- from src/game/camera.c:cutscene_exit_painting_move_to_floor L10100-10115
function camera.cutscene_exit_painting_move_to_floor(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(Scratch.cutscene_exit_painting_move_to_floor_floorHeight, camera.sMarioCamState.pos)
	Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2] = Registry.Members.src__engine__surface_collision.find_floor(camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 10), camera.sMarioCamState.pos[3], Scratch.cutscene_exit_painting_move_to_floor_floor)

	if Scratch.cutscene_exit_painting_move_to_floor_floor[1] ~= nil then
		Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2] = F32(F32(Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2] + F32(F32(camera.sMarioCamState.pos[2] - Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2]) * F32(0.7))) + 125)
		camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_exit_painting_move_to_floor_floorHeight, F32(0.2), F32(0.2), F32(0.2))

		if Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2] < c.pos[2] then
			Scratch.cutscene_exit_painting_move_to_floor_value[1] = c.pos[2]
			camera.approach_f32_asymptotic_bool(Scratch.cutscene_exit_painting_move_to_floor_value, Scratch.cutscene_exit_painting_move_to_floor_floorHeight[2], F32(0.05))
			c.pos[2] = Scratch.cutscene_exit_painting_move_to_floor_value[1]
		end
	end
end

-- from src/game/camera.c:cutscene_exit_painting L10120-10131
function camera.cutscene_exit_painting(c: GroupsTypesHPlus3.Camera)
	camera.cutscene_event(camera.cutscene_exit_painting_start, c, 0, 0)
	camera.cutscene_event(camera.cutscene_exit_painting_move_to_mario, c, 5, -1)
	camera.cutscene_event(camera.cutscene_exit_painting_move_to_floor, c, 5, -1)

	-- ! Hardcoded position. TTM's painting is close to an opposite wall, so just fix the pos.
	if camera.gPrevLevel == IncludeLevelTableH.LEVEL_TTM then
		SrcEngineMathUtil.vec3f_set(c.pos, -296, 1261, 3521)
	end

	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_unused_exit_start L10136-10145
function camera.cutscene_unused_exit_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_unused_exit_start_offset, 200, 300, 200)
	SrcEngineMathUtil.vec3s_set(Scratch.cutscene_unused_exit_start_marioAngle, 0, camera.sMarioCamState.faceAngle[2], 0)
	camera.offset_rotated(c.pos, camera.sMarioCamState.pos, Scratch.cutscene_unused_exit_start_offset, Scratch.cutscene_unused_exit_start_marioAngle)
	camera.set_focus_rel_mario(c, 0, 125, 0, 0)
end

-- from src/game/camera.c:cutscene_unused_exit_focus_mario L10150-10157
function camera.cutscene_unused_exit_focus_mario(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_unused_exit_focus_mario_focus, camera.sMarioCamState.pos[1], F32(camera.sMarioCamState.pos[2] + 125), camera.sMarioCamState.pos[3])
	camera.set_focus_rel_mario(c, 0, 125, 0, 0)
	camera.approach_vec3f_asymptotic(c.focus, Scratch.cutscene_unused_exit_focus_mario_focus, F32(0.02), F32(0.001), F32(0.02))
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_exit_painting_end L10162-10169
function camera.cutscene_exit_painting_end(c: GroupsTypesHPlus3.Camera)
	c.mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
	c.cutscene = 0
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT)))
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_enter_cannon_end L10174-10180
function camera.cutscene_enter_cannon_end(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT))
	c.mode = GroupsTypesHPlus3.CAMERA_MODE_INSIDE_CANNON
	c.cutscene = 0
	camera.sCannonYOffset = 800
end

-- from src/game/camera.c:cutscene_enter_cannon_raise L10185-10225
function camera.cutscene_enter_cannon_raise(c: GroupsTypesHPlus3.Camera)
	-- Shake the camera when the cannon is fully raised
	camera.cutscene_event(camera.cutscene_shake_explosion, c, 70, 70)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	Scratch.cutscene_enter_cannon_raise_angle[1] = camera.sCutsceneVars[2].angle[1]
	camera.camera_approach_s16_symmetric_bool(Scratch.cutscene_enter_cannon_raise_angle, 0, 0x80)
	camera.sCutsceneVars[2].angle[1] = Scratch.cutscene_enter_cannon_raise_angle[1]
	Scratch.cutscene_enter_cannon_raise_angle[1] = camera.sCutsceneVars[3].angle[1]
	camera.camera_approach_s16_symmetric_bool(Scratch.cutscene_enter_cannon_raise_angle, 0, 0x80)
	camera.sCutsceneVars[3].angle[1] = Scratch.cutscene_enter_cannon_raise_angle[1]
	-- Move the camera around the cannon, gradually rotating and moving closer
	SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.sCutsceneVars[1].point, c.pos, camera.sCutsceneVars[2].point[3], camera.sCutsceneVars[2].angle[1], camera.sCutsceneVars[2].angle[2])
	camera.sCutsceneVars[2].point[3] = SrcEngineMathUtil.approach_f32(camera.sCutsceneVars[2].point[3], 400, 5, 5)
	camera.sCutsceneVars[2].angle[2] = S16(camera.sCutsceneVars[2].angle[2] + 0x40)
	camera.sCutsceneVars[4].point[2] = F32(camera.sCutsceneVars[4].point[2] + 2)
	c.pos[2] = F32(c.pos[2] + camera.sCutsceneVars[4].point[2])

	const o = camera.sMarioCamState.usedObj
	if o ~= nil then
		camera.sCutsceneVars[1].point[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Scratch.cutscene_enter_cannon_raise_cannonAngle[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
		Scratch.cutscene_enter_cannon_raise_cannonAngle[2] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		Scratch.cutscene_enter_cannon_raise_cannonAngle[3] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll))
		c.focus[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		c.focus[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		c.focus[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		Scratch.cutscene_enter_cannon_raise_cannonFocus[1] = 0
		Scratch.cutscene_enter_cannon_raise_cannonFocus[2] = 100
		Scratch.cutscene_enter_cannon_raise_cannonFocus[3] = 0
		camera.offset_rotated(c.focus, c.focus, Scratch.cutscene_enter_cannon_raise_cannonFocus, Scratch.cutscene_enter_cannon_raise_cannonAngle)
	end

	const FloorY: number = Registry.Members.src__engine__surface_collision.find_floor(c.pos[1], F32(c.pos[2] + 500), c.pos[3], Scratch.cutscene_enter_cannon_raise_floor)
	const floorHeight = F32(FloorY + 100)

	if c.pos[2] < floorHeight then
		c.pos[2] = floorHeight
	end
end

-- from src/game/camera.c:cutscene_enter_cannon_start L10230-10253
function camera.cutscene_enter_cannon_start(c: GroupsTypesHPlus3.Camera)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sMarioCamState.cameraEvent = 0

	-- Store the cannon's position and angle in cvar0
	const o = camera.sMarioCamState.usedObj
	if o ~= nil then
		camera.sCutsceneVars[1].point[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		camera.sCutsceneVars[1].point[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		camera.sCutsceneVars[1].point[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		camera.sCutsceneVars[1].angle[1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
		camera.sCutsceneVars[1].angle[2] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		camera.sCutsceneVars[1].angle[3] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleRoll))
	end

	-- Store the camera's polar offset from the cannon in cvar1
	Scratch.cutscene_enter_cannon_start_dist[1] = camera.sCutsceneVars[2].point[3]
	Scratch.cutscene_enter_cannon_start_pitch[1] = camera.sCutsceneVars[2].angle[1]
	Scratch.cutscene_enter_cannon_start_yaw[1] = camera.sCutsceneVars[2].angle[2]
	SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.sCutsceneVars[1].point, c.pos, Scratch.cutscene_enter_cannon_start_dist, Scratch.cutscene_enter_cannon_start_pitch, Scratch.cutscene_enter_cannon_start_yaw)
	camera.sCutsceneVars[2].point[3] = Scratch.cutscene_enter_cannon_start_dist[1]
	camera.sCutsceneVars[2].angle[1] = Scratch.cutscene_enter_cannon_start_pitch[1]
	camera.sCutsceneVars[2].angle[2] = Scratch.cutscene_enter_cannon_start_yaw[1]
	camera.sCutsceneVars[4].point[2] = 0
	-- cvar4 is unused in this cutscene
	camera.sCutsceneVars[5].point[2] = 0
end

-- from src/game/camera.c:cutscene_door_start L10258-10261
function camera.cutscene_door_start(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[1].point, c.pos)
	SrcEngineMathUtil.vec3f_copy(camera.sCutsceneVars[2].point, c.focus)
end

-- from src/game/camera.c:cutscene_door_fix_cam L10266-10269
function camera.cutscene_door_fix_cam(c: GroupsTypesHPlus3.Camera)
	SrcEngineMathUtil.vec3f_copy(c.pos, camera.sCutsceneVars[1].point)
	SrcEngineMathUtil.vec3f_copy(c.focus, camera.sCutsceneVars[2].point)
end

-- from src/game/camera.c:cutscene_door_loop L10274-10280
function camera.cutscene_door_loop(c: GroupsTypesHPlus3.Camera)
	-- bitwise AND instead of boolean
	if camera.sMarioCamState.action ~= IncludeSm64H.ACT_PULLING_DOOR and camera.sMarioCamState.action ~= IncludeSm64H.ACT_PUSHING_DOOR then
		camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
		c.cutscene = 0
	end
end

-- from src/game/camera.c:cutscene_door_move_behind_mario L10285-10302
function camera.cutscene_door_move_behind_mario(c: GroupsTypesHPlus3.Camera)
	camera.reset_pan_distance(c)
	camera.determine_pushing_or_pulling_door(Scratch.cutscene_door_move_behind_mario_doorRotation)
	camera.set_focus_rel_mario(c, 0, 125, 0, 0)
	SrcEngineMathUtil.vec3s_set(camera.sCutsceneVars[1].angle, 0, S16(camera.sMarioCamState.faceAngle[2] + Scratch.cutscene_door_move_behind_mario_doorRotation[1]), 0)
	SrcEngineMathUtil.vec3f_set(Scratch.cutscene_door_move_behind_mario_camOffset, 0, 125, 250)

	if Scratch.cutscene_door_move_behind_mario_doorRotation[1] == 0 then -- useless code
		Scratch.cutscene_door_move_behind_mario_camOffset[1] = 0
	else
		Scratch.cutscene_door_move_behind_mario_camOffset[1] = 0
	end

	camera.offset_rotated(c.pos, camera.sMarioCamState.pos, Scratch.cutscene_door_move_behind_mario_camOffset, camera.sCutsceneVars[1].angle)
end

-- from src/game/camera.c:cutscene_door_follow_mario L10307-10316
function camera.cutscene_door_follow_mario(c: GroupsTypesHPlus3.Camera)
	camera.set_focus_rel_mario(c, 0, 125, 0, 0)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(c.focus, c.pos, Scratch.cutscene_door_follow_mario_dist, Scratch.cutscene_door_follow_mario_pitch, Scratch.cutscene_door_follow_mario_yaw)
	camera.camera_approach_f32_symmetric_bool(Scratch.cutscene_door_follow_mario_dist, 150, 7)
	SrcEngineMathUtil.vec3f_set_dist_and_angle(c.focus, c.pos, Scratch.cutscene_door_follow_mario_dist[1], Scratch.cutscene_door_follow_mario_pitch[1], Scratch.cutscene_door_follow_mario_yaw[1])
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_door_end L10321-10334
function camera.cutscene_door_end(c: GroupsTypesHPlus3.Camera)
	if c.defMode == GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM then
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_FREE_ROAM
	else
		c.mode = GroupsTypesHPlus3.CAMERA_MODE_CLOSE
	end

	c.cutscene = 0
	camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
	camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT))
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_BLOCK_SMOOTH_MOVEMENT)))
	camera.set_flag_post_door(c)
	camera.update_camera_yaw(c)
end

-- from src/game/camera.c:cutscene_door_mode L10339-10361
function camera.cutscene_door_mode(c: GroupsTypesHPlus3.Camera)
	camera.reset_pan_distance(c)
	camera.camera_course_processing(c)

	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED then
		c.nextYaw = S16(camera.update_fixed_camera(c, c.focus, c.pos))
	end
	if c.mode == GroupsTypesHPlus3.CAMERA_MODE_PARALLEL_TRACKING then
		c.nextYaw = S16(camera.update_parallel_tracking_camera(c, c.focus, c.pos))
	end

	c.yaw = c.nextYaw

	-- Loop until Mario is no longer using the door
	if camera.sMarioCamState.action ~= IncludeSm64H.ACT_ENTERING_STAR_DOOR and camera.sMarioCamState.action ~= IncludeSm64H.ACT_PULLING_DOOR and camera.sMarioCamState.action ~= IncludeSm64H.ACT_PUSHING_DOOR then
		camera.gCutsceneTimer = S16(GroupsTypesHPlus3.CUTSCENE_STOP)
		c.cutscene = 0
	end
end

-- from src/game/camera.c:play_cutscene L11163-11254
function camera.play_cutscene(c: GroupsTypesHPlus3.Camera)
	local cutsceneDuration = 0
	const oldCutscene = c.cutscene

	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SMOOTH_MOVEMENT)))
	camera.gCameraMovementFlags = S16(bit32.band(camera.gCameraMovementFlags, bit32.bnot(GroupsTypesHPlus3.CAM_MOVING_INTO_MODE)))

	if c.cutscene == GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN then
		const Shot = camera.sCutsceneStarSpawn[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_RED_COIN_STAR_SPAWN then
		const Shot = camera.sCutsceneRedCoinStarSpawn[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENDING then
		const Shot = camera.sCutsceneEnding[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_GRAND_STAR then
		const Shot = camera.sCutsceneGrandStar[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DOOR_WARP then
		const Shot = camera.sCutsceneDoorWarp[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DOOR_PULL then
		const Shot = camera.sCutsceneDoorPull[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH then
		const Shot = camera.sCutsceneDoorPush[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DOOR_PULL_MODE then
		const Shot = camera.sCutsceneDoorPullMode[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DOOR_PUSH_MODE then
		const Shot = camera.sCutsceneDoorPushMode[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_CANNON then
		const Shot = camera.sCutsceneEnterCannon[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_PAINTING then
		const Shot = camera.sCutsceneEnterPainting[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DEATH_EXIT then
		const Shot = camera.sCutsceneDeathExit[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_PAINTING_SUCC then
		const Shot = camera.sCutsceneExitPaintingSuccess[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_UNUSED_EXIT then
		const Shot = camera.sCutsceneUnusedExit[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_INTRO_PEACH then
		const Shot = camera.sCutsceneIntroPeach[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_BOWSER_ARENA then
		const Shot = camera.sCutsceneEnterBowserArena[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DANCE_ROTATE then
		const Shot = camera.sCutsceneDanceDefaultRotate[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DANCE_DEFAULT then
		const Shot = camera.sCutsceneDanceDefaultRotate[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DANCE_FLY_AWAY then
		const Shot = camera.sCutsceneDanceFlyAway[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DANCE_CLOSEUP then
		const Shot = camera.sCutsceneDanceCloseup[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_KEY_DANCE then
		const Shot = camera.sCutsceneKeyDance[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_0F_UNUSED then
		const Shot = camera.sCutsceneUnused[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_END_WAVING then
		const Shot = camera.sCutsceneEndWaving[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_CREDITS then
		const Shot = camera.sCutsceneCredits[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_CAP_SWITCH_PRESS then
		const Shot = camera.sCutsceneCapSwitchPress[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_SLIDING_DOORS_OPEN then
		const Shot = camera.sCutsceneSlidingDoorsOpen[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_PREPARE_CANNON then
		const Shot = camera.sCutscenePrepareCannon[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_UNLOCK_KEY_DOOR then
		const Shot = camera.sCutsceneUnlockKeyDoor[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_STANDING_DEATH then
		const Shot = camera.sCutsceneStandingDeath[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_POOL then
		const Shot = camera.sCutsceneEnterPool[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DEATH_ON_STOMACH then
		const Shot = camera.sCutsceneDeathStomach[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DEATH_ON_BACK then
		const Shot = camera.sCutsceneDeathOnBack[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_QUICKSAND_DEATH then
		const Shot = camera.sCutsceneQuicksandDeath[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_SUFFOCATION_DEATH then
		const Shot = camera.sCutsceneSuffocation[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_BOWSER_SUCC then
		const Shot = camera.sCutsceneExitBowserSuccess[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_BOWSER_DEATH then
		const Shot = camera.sCutsceneExitBowserDeath[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_SPECIAL_SUCC then
		const Shot = camera.sCutsceneExitSpecialSuccess[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_WATERFALL then
		const Shot = camera.sCutsceneExitWaterfall[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_EXIT_FALL_WMOTR then
		const Shot = camera.sCutsceneFallToCastleGrounds[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_NONPAINTING_DEATH then
		const Shot = camera.sCutsceneNonPaintingDeath[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_DIALOG then
		const Shot = camera.sCutsceneDialog[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_READ_MESSAGE then
		const Shot = camera.sCutsceneReadMessage[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_RACE_DIALOG then
		const Shot = camera.sCutsceneDialog[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_ENTER_PYRAMID_TOP then
		const Shot = camera.sCutsceneEnterPyramidTop[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	elseif c.cutscene == GroupsTypesHPlus3.CUTSCENE_SSL_PYRAMID_EXPLODE then
		const Shot = camera.sCutscenePyramidTopExplode[camera.sCutsceneShot + 1]
		const ShotFunction = Shot.shot :: (GroupsTypesHPlus3.Camera) -> ()
		cutsceneDuration = Shot.duration
		ShotFunction(c)
	end

	if cutsceneDuration ~= 0 and not bit32.btest(camera.gCutsceneTimer, GroupsTypesHPlus3.CUTSCENE_STOP) then
		-- @bug This should check for 0x7FFF (CUTSCENE_LOOP)
		-- instead, cutscenes that last longer than 0x3FFF frames will never end on their own
		if camera.gCutsceneTimer < 0x3FFF then
			camera.gCutsceneTimer = S16(camera.gCutsceneTimer + 1)
		end
		-- Because gCutsceneTimer is often set to 0x7FFF (CUTSCENE_LOOP), this conditional can only
		-- check for == due to overflow
		if camera.gCutsceneTimer == cutsceneDuration then
			camera.sCutsceneShot = S16(camera.sCutsceneShot + 1)
			camera.gCutsceneTimer = 0
		end
	else
		camera.sMarioCamState.cameraEvent = 0
		camera.sCutsceneShot = 0
		camera.gCutsceneTimer = 0
	end

	camera.sAreaYawChange = 0

	-- The cutscene just ended
	if c.cutscene == 0 and oldCutscene ~= 0 then
		camera.gRecentCutscene = oldCutscene
	end
end

-- from src/game/camera.c:cutscene_event L11260-11267
function camera.cutscene_event(event: (GroupsTypesHPlus3.Camera) -> (), c: GroupsTypesHPlus3.Camera, start: number, end_: number): number
	start = S16(TruncS32(start))
	end_ = S16(TruncS32(end_))
	if start <= camera.gCutsceneTimer then
		if end_ == -1 or end_ >= camera.gCutsceneTimer then
			event(c)
		end
	end
	return 0
end

-- from src/game/camera.c:cutscene_spawn_obj L11274-11279
function camera.cutscene_spawn_obj(obj: number, frame: number): number
	frame = S16(TruncS32(frame))
	if frame == camera.gCutsceneTimer then
		camera.gCutsceneObjSpawn = obj
	end
	return 0
end

-- from src/game/camera.c:set_fov_shake L11287-11293
function camera.set_fov_shake(amplitude: number, decay: number, shakeSpeed: number)
	amplitude = S16(TruncS32(amplitude))
	decay = S16(TruncS32(decay))
	shakeSpeed = S16(TruncS32(shakeSpeed))
	if amplitude > camera.sFOVState.shakeAmplitude then
		camera.sFOVState.shakeAmplitude = amplitude
		camera.sFOVState.decay = decay
		camera.sFOVState.shakeSpeed = shakeSpeed
	end
end

-- from src/game/camera.c:set_fov_shake_from_point L11298-11308
function camera.set_fov_shake_from_point(amplitude: number, decay: number, shakeSpeed: number, maxDist: number, posX: number, posY: number, posZ: number)
	amplitude = S16(TruncS32(amplitude))
	decay = S16(TruncS32(decay))
	shakeSpeed = S16(TruncS32(shakeSpeed))
	maxDist = F32(maxDist)
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	amplitude = camera.reduce_by_dist_from_camera(amplitude, maxDist, posX, posY, posZ)

	if amplitude ~= 0 then
		if amplitude > camera.sFOVState.shakeAmplitude then -- literally use the function above you silly nintendo, smh
			camera.sFOVState.shakeAmplitude = amplitude
			camera.sFOVState.decay = decay
			camera.sFOVState.shakeSpeed = shakeSpeed
		end
	end
end

-- from src/game/camera.c:shake_camera_fov L11313-11322
function camera.shake_camera_fov(perspective: GroupsTypesHPlus3.GraphNodePerspective)
	if camera.sFOVState.shakeAmplitude ~= 0 then
		camera.sFOVState.fovOffset = F32(F32(Registry.Members.src__engine__math_util_h.coss(camera.sFOVState.shakePhase) * camera.sFOVState.shakeAmplitude) / 0x100)
		camera.sFOVState.shakePhase = S16(camera.sFOVState.shakePhase + camera.sFOVState.shakeSpeed)
		Scratch.shake_camera_fov_shakeAmplitude[1] = camera.sFOVState.shakeAmplitude
		camera.camera_approach_f32_symmetric_bool(Scratch.shake_camera_fov_shakeAmplitude, 0, camera.sFOVState.decay)
		camera.sFOVState.shakeAmplitude = Scratch.shake_camera_fov_shakeAmplitude[1]
		perspective.fov = F32(perspective.fov + camera.sFOVState.fovOffset)
	else
		camera.sFOVState.shakePhase = 0
	end
end

-- from src/game/camera.c:unused_deactivate_sleeping_camera L11324-11326
function camera.unused_deactivate_sleeping_camera(m: GroupsTypesHPlus3.MarioState)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SLEEPING)))
end

-- from src/game/camera.c:set_fov_30 L11328-11330
function camera.set_fov_30(m: GroupsTypesHPlus3.MarioState)
	camera.sFOVState.fov = 30
end

-- from src/game/camera.c:approach_fov_20 L11332-11334
function camera.approach_fov_20(m: GroupsTypesHPlus3.MarioState)
	Scratch.approach_fov_20_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.approach_fov_20_fov, 20, F32(0.3))
	camera.sFOVState.fov = Scratch.approach_fov_20_fov[1]
end

-- from src/game/camera.c:set_fov_45 L11336-11338
function camera.set_fov_45(m: GroupsTypesHPlus3.MarioState)
	camera.sFOVState.fov = 45
end

-- from src/game/camera.c:set_fov_29 L11340-11342
function camera.set_fov_29(m: GroupsTypesHPlus3.MarioState)
	camera.sFOVState.fov = 29
end

-- from src/game/camera.c:zoom_fov_30 L11344-11348
function camera.zoom_fov_30(m: GroupsTypesHPlus3.MarioState)
	-- Pretty sure approach_f32_asymptotic_bool would do a much nicer job here, but you do you,
	-- Nintendo.
	Scratch.zoom_fov_30_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.zoom_fov_30_fov, 30, F32(F32(30 - camera.sFOVState.fov) / 60))
	camera.sFOVState.fov = Scratch.zoom_fov_30_fov[1]
end

-- from src/game/camera.c:fov_default L11354-11367
function camera.fov_default(m: GroupsTypesHPlus3.MarioState)
	camera.sStatusFlags = S16(bit32.band(camera.sStatusFlags, bit32.bnot(GroupsTypesHPlus3.CAM_FLAG_SLEEPING)))

	if m.action == IncludeSm64H.ACT_SLEEPING or m.action == IncludeSm64H.ACT_START_SLEEPING then
		Scratch.fov_default_fov[1] = camera.sFOVState.fov
		camera.camera_approach_f32_symmetric_bool(Scratch.fov_default_fov, 30, F32(F32(30 - camera.sFOVState.fov) / 30))
		camera.sFOVState.fov = Scratch.fov_default_fov[1]
		camera.sStatusFlags = S16(bit32.bor(camera.sStatusFlags, GroupsTypesHPlus3.CAM_FLAG_SLEEPING))
	else
		Scratch.fov_default_fov[1] = camera.sFOVState.fov
		camera.camera_approach_f32_symmetric_bool(Scratch.fov_default_fov, 45, F32(F32(45 - camera.sFOVState.fov) / 30))
		camera.sFOVState.fov = Scratch.fov_default_fov[1]
		camera.sFOVState.unusedIsSleeping = 0
	end
	if ((m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera).cutscene == GroupsTypesHPlus3.CUTSCENE_0F_UNUSED then
		camera.sFOVState.fov = 45
	end
end

-- from src/game/camera.c:unused_approach_fov_30 L11370-11372
function camera.unused_approach_fov_30(m: GroupsTypesHPlus3.MarioState)
	Scratch.unused_approach_fov_30_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.unused_approach_fov_30_fov, 30, 1)
	camera.sFOVState.fov = Scratch.unused_approach_fov_30_fov[1]
end

-- from src/game/camera.c:approach_fov_30 L11374-11376
function camera.approach_fov_30(m: GroupsTypesHPlus3.MarioState)
	Scratch.approach_fov_30_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.approach_fov_30_fov, 30, 1)
	camera.sFOVState.fov = Scratch.approach_fov_30_fov[1]
end

-- from src/game/camera.c:approach_fov_60 L11378-11380
function camera.approach_fov_60(m: GroupsTypesHPlus3.MarioState)
	Scratch.approach_fov_60_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.approach_fov_60_fov, 60, 1)
	camera.sFOVState.fov = Scratch.approach_fov_60_fov[1]
end

-- from src/game/camera.c:approach_fov_45 L11382-11392
function camera.approach_fov_45(m: GroupsTypesHPlus3.MarioState)
	local targetFoV = camera.sFOVState.fov
	const marioCamera = ((m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera)

	if marioCamera.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED and marioCamera.cutscene == 0 then
		targetFoV = 45
	else
		targetFoV = 45
	end

	camera.sFOVState.fov = SrcEngineMathUtil.approach_f32(camera.sFOVState.fov, targetFoV, 2, 2)
end

-- from src/game/camera.c:approach_fov_80 L11394-11396
function camera.approach_fov_80(m: GroupsTypesHPlus3.MarioState)
	Scratch.approach_fov_80_fov[1] = camera.sFOVState.fov
	camera.camera_approach_f32_symmetric_bool(Scratch.approach_fov_80_fov, 80, 3.5)
	camera.sFOVState.fov = Scratch.approach_fov_80_fov[1]
end

-- from src/game/camera.c:set_fov_bbh L11402-11412
function camera.set_fov_bbh(m: GroupsTypesHPlus3.MarioState)
	local targetFoV = camera.sFOVState.fov
	const marioCamera = ((m.area :: GroupsTypesHPlus3.Area).camera :: GroupsTypesHPlus3.Camera)

	if marioCamera.mode == GroupsTypesHPlus3.CAMERA_MODE_FIXED and marioCamera.cutscene == 0 then
		targetFoV = 60
	else
		targetFoV = 45
	end

	camera.sFOVState.fov = SrcEngineMathUtil.approach_f32(camera.sFOVState.fov, targetFoV, 2, 2)
end

-- from src/game/camera.c:geo_camera_fov L11417-11464
function camera.geo_camera_fov(callContext: number, g: GroupsTypesHPlus3.GraphNode, context: unknown): { unknown }?
	const perspective = g :: GroupsTypesHPlus3.GraphNodePerspective
	const marioState = LevelUpdate.gMarioStates[1]
	const fovFunc = camera.sFOVState.fovFunc

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		if fovFunc == GroupsTypesHPlus3.CAM_FOV_SET_45 then
			camera.set_fov_45(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_SET_29 then
			camera.set_fov_29(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_ZOOM_30 then
			camera.zoom_fov_30(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_DEFAULT then
			camera.fov_default(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_BBH then
			camera.set_fov_bbh(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_APP_45 then
			camera.approach_fov_45(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_SET_30 then
			camera.set_fov_30(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_APP_20 then
			camera.approach_fov_20(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_APP_80 then
			camera.approach_fov_80(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_APP_30 then
			camera.approach_fov_30(marioState)
		elseif fovFunc == GroupsTypesHPlus3.CAM_FOV_APP_60 then
			camera.approach_fov_60(marioState)
		end
	end

	perspective.fov = camera.sFOVState.fov
	camera.shake_camera_fov(perspective)
	return nil
end

-- from src/game/camera.c:set_fov_function L11471-11473
function camera.set_fov_function(func: number)
	func = U8(TruncS32(func))
	camera.sFOVState.fovFunc = func
end

-- from src/game/camera.c:cutscene_set_fov_shake_preset L11478-11487
function camera.cutscene_set_fov_shake_preset(preset: number)
	preset = U8(TruncS32(preset))
	if preset == 1 then
		camera.set_fov_shake(0x100, 0x30, S16(0x8000))
	elseif preset == 2 then
		camera.set_fov_shake(0x400, 0x20, 0x4000)
	end
end

-- from src/game/camera.c:set_fov_shake_from_point_preset L11495-11510
function camera.set_fov_shake_from_point_preset(preset: number, posX: number, posY: number, posZ: number)
	preset = U8(TruncS32(preset))
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	if preset == GroupsTypesHPlus3.SHAKE_FOV_SMALL then
		camera.set_fov_shake_from_point(0x100, 0x30, S16(0x8000), 3000, posX, posY, posZ)
	elseif preset == GroupsTypesHPlus3.SHAKE_FOV_MEDIUM then
		camera.set_fov_shake_from_point(0x200, 0x30, S16(0x8000), 4000, posX, posY, posZ)
	elseif preset == GroupsTypesHPlus3.SHAKE_FOV_LARGE then
		camera.set_fov_shake_from_point(0x300, 0x30, S16(0x8000), 6000, posX, posY, posZ)
	elseif preset == GroupsTypesHPlus3.SHAKE_FOV_UNUSED then
		camera.set_fov_shake_from_point(0x800, 0x20, 0x4000, 3000, posX, posY, posZ)
	end
end

-- from src/game/camera.c:unused_displace_obj_randomly L11515-11521
function camera.unused_displace_obj_randomly(o: GroupsTypesHPlus3.Object, xRange: number, yRange: number, zRange: number)
	xRange = F32(xRange)
	yRange = F32(yRange)
	zRange = F32(zRange)
	const rnd = SrcEngineBehaviorScript.random_float()

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(rnd * xRange) - F32(xRange / 2)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(F32(rnd * yRange) - F32(yRange / 2)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(rnd * zRange) - F32(zRange / 2)))
end

-- from src/game/camera.c:unused_rotate_obj_randomly L11526-11531
function camera.unused_rotate_obj_randomly(o: GroupsTypesHPlus3.Object, pitchRange: number, yawRange: number)
	pitchRange = F32(pitchRange)
	yawRange = F32(yawRange)
	const rnd = SrcEngineBehaviorScript.random_float()

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + S16(TruncS32(F32(F32(rnd * pitchRange) - F32(pitchRange / 2))))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + S16(TruncS32(F32(F32(rnd * yawRange) - F32(yawRange / 2))))))
end

-- from src/game/camera.c:obj_rotate_towards_point L11536-11545
function camera.obj_rotate_towards_point(o: GroupsTypesHPlus3.Object, point: { number }, pitchOff: number, yawOff: number, pitchDiv: number, yawDiv: number)
	pitchOff = S16(TruncS32(pitchOff))
	yawOff = S16(TruncS32(yawOff))
	pitchDiv = S16(TruncS32(pitchDiv))
	yawDiv = S16(TruncS32(yawDiv))
	camera.object_pos_to_vec3f(Scratch.obj_rotate_towards_point_oPos, o)
	SrcEngineMathUtil.vec3f_get_dist_and_angle(Scratch.obj_rotate_towards_point_oPos, point, Scratch.obj_rotate_towards_point_dist, Scratch.obj_rotate_towards_point_pitch, Scratch.obj_rotate_towards_point_yaw)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, camera.approach_s16_asymptotic(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), S16(pitchOff - Scratch.obj_rotate_towards_point_pitch[1]), pitchDiv))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, camera.approach_s16_asymptotic(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(Scratch.obj_rotate_towards_point_yaw[1] + yawOff), yawDiv))
end

-- from src/game/camera.c:sMarioCamState L439-439
camera.sMarioCamState = camera.gPlayerCameraState[1]

-- from src/game/camera.c:sLuigiCamState L440-440
camera.sLuigiCamState = camera.gPlayerCameraState[2]

-- from src/game/camera.c:sModeTransitions L465-484
camera.sModeTransitions = {
	nil,
	camera.update_radial_camera,
	camera.update_outward_radial_camera,
	camera.update_behind_mario_camera,
	camera.update_mario_camera,
	camera.unused_update_mode_5_camera,
	camera.update_c_up,
	camera.update_mario_camera,
	camera.nop_update_water_camera,
	camera.update_slide_or_0f_camera,
	camera.update_in_cannon,
	camera.update_boss_fight_camera,
	camera.update_parallel_tracking_camera,
	camera.update_fixed_camera,
	camera.update_8_directions_camera,
	camera.update_slide_or_0f_camera,
	camera.update_mario_camera,
	camera.update_spiral_stairs_camera,
}

-- from src/game/camera.c:sCamSL L6160-6165
camera.sCamSL = {
	{
		area = 1,
		event = camera.cam_sl_snowman_head_8dir,
		centerX = 1119,
		centerY = 3584,
		centerZ = 1125,
		boundsX = 1177,
		boundsY = 358,
		boundsZ = 358,
		boundsYaw = -0x1D27,
	},
	{
		area = 1,
		event = camera.cam_sl_free_roam,
		centerX = 1119,
		centerY = 3584,
		centerZ = 1125,
		boundsX = 4096,
		boundsY = 4096,
		boundsZ = 4096,
		boundsYaw = -0x1D27,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamTHI L6172-6176
camera.sCamTHI = {
	{
		area = 1,
		event = camera.cam_thi_move_cam_through_tunnel,
		centerX = -4609,
		centerY = -2969,
		centerZ = 6448,
		boundsX = 100,
		boundsY = 300,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_thi_look_through_tunnel,
		centerX = -4809,
		centerY = -2969,
		centerZ = 6448,
		boundsX = 100,
		boundsY = 300,
		boundsZ = 300,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamHMC L6182-6190
camera.sCamHMC = {
	{
		area = 1,
		event = camera.cam_hmc_enter_maze,
		centerX = 1996,
		centerY = 102,
		centerZ = 0,
		boundsX = 205,
		boundsY = 100,
		boundsZ = 205,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_hmc_start_pool_cutscene,
		centerX = 3350,
		centerY = -4689,
		centerZ = 4800,
		boundsX = 600,
		boundsY = 50,
		boundsZ = 600,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_hmc_elevator_black_hole,
		centerX = -3278,
		centerY = 1236,
		centerZ = 1379,
		boundsX = 358,
		boundsY = 200,
		boundsZ = 358,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_hmc_elevator_maze_emergency_exit,
		centerX = -2816,
		centerY = 2055,
		centerZ = -2560,
		boundsX = 358,
		boundsY = 200,
		boundsZ = 358,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_hmc_elevator_lake,
		centerX = -3532,
		centerY = 1543,
		centerZ = -7040,
		boundsX = 358,
		boundsY = 200,
		boundsZ = 358,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_hmc_elevator_maze,
		centerX = -972,
		centerY = 1543,
		centerZ = -7347,
		boundsX = 358,
		boundsY = 200,
		boundsZ = 358,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamSSL L6197-6203
camera.sCamSSL = {
	{
		area = 1,
		event = camera.cam_ssl_enter_pyramid_top,
		centerX = -2048,
		centerY = 1080,
		centerZ = -1024,
		boundsX = 150,
		boundsY = 150,
		boundsZ = 150,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_ssl_pyramid_center,
		centerX = 0,
		centerY = -104,
		centerZ = -104,
		boundsX = 1248,
		boundsY = 1536,
		boundsZ = 2950,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_ssl_pyramid_center,
		centerX = 0,
		centerY = 2500,
		centerZ = 256,
		boundsX = 515,
		boundsY = 5000,
		boundsZ = 515,
		boundsYaw = 0,
	},
	{
		area = 3,
		event = camera.cam_ssl_boss_room,
		centerX = 0,
		centerY = -1534,
		centerZ = -2040,
		boundsX = 1000,
		boundsY = 800,
		boundsZ = 1000,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamRR L6209-6217
camera.sCamRR = {
	{
		area = 1,
		event = camera.cam_rr_exit_building_side,
		centerX = -4197,
		centerY = 3819,
		centerZ = -3087,
		boundsX = 1769,
		boundsY = 1490,
		boundsZ = 342,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_rr_enter_building_side,
		centerX = -4197,
		centerY = 3819,
		centerZ = -3771,
		boundsX = 769,
		boundsY = 490,
		boundsZ = 342,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_rr_enter_building_window,
		centerX = -5603,
		centerY = 4834,
		centerZ = -5209,
		boundsX = 300,
		boundsY = 600,
		boundsZ = 591,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_rr_enter_building,
		centerX = -2609,
		centerY = 3730,
		centerZ = -5463,
		boundsX = 300,
		boundsY = 650,
		boundsZ = 577,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_rr_exit_building_top,
		centerX = -4196,
		centerY = 7343,
		centerZ = -5155,
		boundsX = 4500,
		boundsY = 1000,
		boundsZ = 4500,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_rr_enter_building,
		centerX = -4196,
		centerY = 6043,
		centerZ = -5155,
		boundsX = 500,
		boundsY = 300,
		boundsZ = 500,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamBOB L6226-6230
camera.sCamBOB = {
	{
		area = 1,
		event = camera.cam_bob_tower,
		centerX = 2468,
		centerY = 2720,
		centerZ = -4608,
		boundsX = 3263,
		boundsY = 1696,
		boundsZ = 3072,
		boundsYaw = 0,
	},
	{
		area = -1,
		event = camera.cam_bob_default_free_roam,
		centerX = 0,
		centerY = 0,
		centerZ = 0,
		boundsX = 0,
		boundsY = 0,
		boundsZ = 0,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamCotMC L6235-6238
camera.sCamCotMC = {
	{
		area = 1,
		event = camera.cam_cotmc_exit_waterfall,
		centerX = 0,
		centerY = 1500,
		centerZ = 3500,
		boundsX = 550,
		boundsY = 10000,
		boundsZ = 1500,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamCCM L6243-6247
camera.sCamCCM = {
	{
		area = 2,
		event = camera.cam_ccm_enter_slide_shortcut,
		centerX = -4846,
		centerY = 2061,
		centerZ = 27,
		boundsX = 1229,
		boundsY = 1342,
		boundsZ = 396,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_ccm_leave_slide_shortcut,
		centerX = -6412,
		centerY = -3917,
		centerZ = -6246,
		boundsX = 307,
		boundsY = 185,
		boundsZ = 132,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamCastle L6256-6294
camera.sCamCastle = {
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -1100,
		centerY = 657,
		centerZ = -1346,
		boundsX = 300,
		boundsY = 150,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = -1099,
		centerY = 657,
		centerZ = -803,
		boundsX = 300,
		boundsY = 150,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -2304,
		centerY = -264,
		centerZ = -4072,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -2304,
		centerY = 145,
		centerZ = -1344,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = -2304,
		centerY = 145,
		centerZ = -802,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = 2816,
		centerY = 1200,
		centerZ = -256,
		boundsX = 100,
		boundsY = 100,
		boundsZ = 100,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = 256,
		centerY = -161,
		centerZ = -4226,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = 256,
		centerY = 145,
		centerZ = -1344,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = 256,
		centerY = 145,
		centerZ = -802,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -1023,
		centerY = 44,
		centerZ = -4870,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -459,
		centerY = 145,
		centerZ = -1020,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0x6000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = -85,
		centerY = 145,
		centerZ = -627,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -1589,
		centerY = 145,
		centerZ = -1020,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = -0x6000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = -1963,
		centerY = 145,
		centerZ = -627,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_leave_lobby_sliding_door,
		centerX = -2838,
		centerY = 657,
		centerZ = -1659,
		boundsX = 200,
		boundsY = 150,
		boundsZ = 150,
		boundsYaw = 0x2000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby_sliding_door,
		centerX = -2319,
		centerY = 512,
		centerZ = -1266,
		boundsX = 300,
		boundsY = 150,
		boundsZ = 300,
		boundsYaw = 0x2000,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = 844,
		centerY = 759,
		centerZ = -1657,
		boundsX = 40,
		boundsY = 150,
		boundsZ = 40,
		boundsYaw = -0x2000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = 442,
		centerY = 759,
		centerZ = -1292,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = -0x2000,
	},
	{
		area = 2,
		event = camera.cam_castle_enter_spiral_stairs,
		centerX = -1000,
		centerY = 657,
		centerZ = 1740,
		boundsX = 200,
		boundsY = 300,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_castle_enter_spiral_stairs,
		centerX = -996,
		centerY = 1348,
		centerZ = 1814,
		boundsX = 200,
		boundsY = 300,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_castle_close_mode,
		centerX = -946,
		centerY = 657,
		centerZ = 2721,
		boundsX = 50,
		boundsY = 150,
		boundsZ = 50,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_castle_close_mode,
		centerX = -996,
		centerY = 1348,
		centerZ = 907,
		boundsX = 50,
		boundsY = 150,
		boundsZ = 50,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_castle_close_mode,
		centerX = -997,
		centerY = 1348,
		centerZ = 1450,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -4942,
		centerY = 452,
		centerZ = -461,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -3393,
		centerY = 350,
		centerZ = -793,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = -2851,
		centerY = 350,
		centerZ = -792,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = 803,
		centerY = 350,
		centerZ = -228,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = -0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_enter_lobby,
		centerX = 803,
		centerY = 350,
		centerZ = -228,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = -0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = 1345,
		centerY = 350,
		centerZ = -229,
		boundsX = 140,
		boundsY = 150,
		boundsZ = 140,
		boundsYaw = 0x4000,
	},
	{
		area = 1,
		event = camera.cam_castle_close_mode,
		centerX = -946,
		centerY = -929,
		centerZ = 622,
		boundsX = 300,
		boundsY = 150,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 2,
		event = camera.cam_castle_look_upstairs,
		centerX = -205,
		centerY = 1456,
		centerZ = 2508,
		boundsX = 210,
		boundsY = 928,
		boundsZ = 718,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_basement_look_downstairs,
		centerX = -1027,
		centerY = -587,
		centerZ = -718,
		boundsX = 318,
		boundsY = 486,
		boundsZ = 577,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_castle_lobby_entrance,
		centerX = -1023,
		centerY = 376,
		centerZ = 1830,
		boundsX = 300,
		boundsY = 400,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 3,
		event = camera.cam_castle_hmc_start_pool_cutscene,
		centerX = 2485,
		centerY = -1689,
		centerZ = -2659,
		boundsX = 600,
		boundsY = 50,
		boundsZ = 600,
		boundsYaw = 0,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCamBBH L6302-6364
camera.sCamBBH = {
	{
		area = 1,
		event = camera.cam_bbh_enter_front_door,
		centerX = 742,
		centerY = 0,
		centerZ = 2369,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_leave_front_door,
		centerX = 741,
		centerY = 0,
		centerZ = 1827,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 222,
		centerY = 0,
		centerZ = 1458,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 222,
		centerY = 0,
		centerZ = 639,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 435,
		centerY = 0,
		centerZ = 222,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1613,
		centerY = 0,
		centerZ = 222,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1827,
		centerY = 0,
		centerZ = 1459,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = -495,
		centerY = 819,
		centerZ = 1407,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = -495,
		centerY = 819,
		centerZ = 640,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 179,
		centerY = 819,
		centerZ = 222,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1613,
		centerY = 819,
		centerZ = 222,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1827,
		centerY = 819,
		centerZ = 486,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1827,
		centerY = 819,
		centerZ = 1818,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_lower,
		centerX = 2369,
		centerY = 0,
		centerZ = 1459,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_lower,
		centerX = 3354,
		centerY = 0,
		centerZ = 1347,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_lower,
		centerX = 2867,
		centerY = 514,
		centerZ = 1843,
		boundsX = 512,
		boundsY = 102,
		boundsZ = 409,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_4,
		centerX = 3354,
		centerY = 0,
		centerZ = 804,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_4,
		centerX = 1613,
		centerY = 0,
		centerZ = -320,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_8,
		centerX = 435,
		centerY = 0,
		centerZ = -320,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_5_library,
		centerX = -2021,
		centerY = 0,
		centerZ = 803,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_5_library,
		centerX = -320,
		centerY = 0,
		centerZ = 640,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_5_library_to_hidden_transition,
		centerX = -1536,
		centerY = 358,
		centerZ = -254,
		boundsX = 716,
		boundsY = 363,
		boundsZ = 102,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_5_hidden_to_library_transition,
		centerX = -1536,
		centerY = 358,
		centerZ = -459,
		boundsX = 716,
		boundsY = 363,
		boundsZ = 102,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_5_hidden,
		centerX = -1560,
		centerY = 0,
		centerZ = -1314,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_3,
		centerX = -320,
		centerY = 0,
		centerZ = 1459,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_3,
		centerX = -2021,
		centerY = 0,
		centerZ = 1345,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_library,
		centerX = 2369,
		centerY = 819,
		centerZ = 486,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_library,
		centerX = 2369,
		centerY = 1741,
		centerZ = 486,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_library_to_trapdoor_transition,
		centerX = 2867,
		centerY = 1228,
		centerZ = 1174,
		boundsX = 716,
		boundsY = 414,
		boundsZ = 102,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_trapdoor_transition,
		centerX = 2867,
		centerY = 1228,
		centerZ = 1378,
		boundsX = 716,
		boundsY = 414,
		boundsZ = 102,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_2_trapdoor,
		centerX = 2369,
		centerY = 819,
		centerZ = 1818,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_9_attic,
		centerX = 1829,
		centerY = 1741,
		centerZ = 486,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_9_attic,
		centerX = 741,
		centerY = 1741,
		centerZ = 1587,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_9_attic_transition,
		centerX = 102,
		centerY = 2048,
		centerZ = -191,
		boundsX = 100,
		boundsY = 310,
		boundsZ = 307,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_9_mr_i_transition,
		centerX = 409,
		centerY = 2048,
		centerZ = -191,
		boundsX = 100,
		boundsY = 310,
		boundsZ = 307,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_13_balcony,
		centerX = 742,
		centerY = 1922,
		centerZ = 2164,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_fall_off_roof,
		centerX = 587,
		centerY = 1322,
		centerZ = 2677,
		boundsX = 1000,
		boundsY = 400,
		boundsZ = 600,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_3,
		centerX = -1037,
		centerY = 819,
		centerZ = 1408,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_3,
		centerX = -1970,
		centerY = 1024,
		centerZ = 1345,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_8,
		centerX = 179,
		centerY = 819,
		centerZ = -320,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_7_mr_i,
		centerX = 1613,
		centerY = 819,
		centerZ = -320,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_7_mr_i_to_coffins_transition,
		centerX = 2099,
		centerY = 1228,
		centerZ = -819,
		boundsX = 102,
		boundsY = 414,
		boundsZ = 716,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_7_coffins_to_mr_i_transition,
		centerX = 2304,
		centerY = 1228,
		centerZ = -819,
		boundsX = 102,
		boundsY = 414,
		boundsZ = 716,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_6,
		centerX = -1037,
		centerY = 819,
		centerZ = 640,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_6,
		centerX = -1970,
		centerY = 1024,
		centerZ = 803,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_1,
		centerX = 1827,
		centerY = 819,
		centerZ = 1818,
		boundsX = 200,
		boundsY = 200,
		boundsZ = 200,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_fall_into_pool,
		centerX = 2355,
		centerY = -1112,
		centerZ = -193,
		boundsX = 1228,
		boundsY = 500,
		boundsZ = 1343,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_fall_into_pool,
		centerX = 2355,
		centerY = -1727,
		centerZ = 1410,
		boundsX = 1228,
		boundsY = 500,
		boundsZ = 705,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_elevator_room_lower,
		centerX = 0,
		centerY = -2457,
		centerZ = 1827,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_elevator_room_lower,
		centerX = 0,
		centerY = -2457,
		centerZ = 2369,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_elevator_room_lower,
		centerX = 0,
		centerY = -2457,
		centerZ = 4929,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_elevator_room_lower,
		centerX = 0,
		centerY = -2457,
		centerZ = 4387,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_0_back_entrance,
		centerX = 1887,
		centerY = -2457,
		centerZ = 204,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_0,
		centerX = 1272,
		centerY = -2457,
		centerZ = 204,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_0,
		centerX = -1681,
		centerY = -2457,
		centerZ = 204,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_0_back_entrance,
		centerX = -2296,
		centerY = -2457,
		centerZ = 204,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_elevator,
		centerX = -2939,
		centerY = -605,
		centerZ = 5367,
		boundsX = 800,
		boundsY = 100,
		boundsZ = 800,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_12_upper,
		centerX = -2939,
		centerY = -205,
		centerZ = 5367,
		boundsX = 300,
		boundsY = 100,
		boundsZ = 300,
		boundsYaw = 0,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_12_upper,
		centerX = -2332,
		centerY = -204,
		centerZ = 4714,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0x6000,
	},
	{
		area = 1,
		event = camera.cam_bbh_room_0_back_entrance,
		centerX = -1939,
		centerY = -204,
		centerZ = 4340,
		boundsX = 250,
		boundsY = 200,
		boundsZ = 250,
		boundsYaw = 0x6000,
	},
	camera.NULL_TRIGGER,
}

-- from src/game/camera.c:sCameraTriggers L6378-6381
camera.sCameraTriggers = {
	nil, -- LEVEL_NONE
	nil, -- LEVEL_UNKNOWN_1
	nil, -- LEVEL_UNKNOWN_2
	nil, -- LEVEL_UNKNOWN_3
	camera.sCamBBH, -- LEVEL_BBH
	camera.sCamCCM, -- LEVEL_CCM
	camera.sCamCastle, -- LEVEL_CASTLE
	camera.sCamHMC, -- LEVEL_HMC
	camera.sCamSSL, -- LEVEL_SSL
	nil, -- LEVEL_BOB
	camera.sCamSL, -- LEVEL_SL
	nil, -- LEVEL_WDW
	nil, -- LEVEL_JRB
	camera.sCamTHI, -- LEVEL_THI
	nil, -- LEVEL_TTC
	camera.sCamRR, -- LEVEL_RR
	nil, -- LEVEL_CASTLE_GROUNDS
	nil, -- LEVEL_BITDW
	nil, -- LEVEL_VCUTM
	nil, -- LEVEL_BITFS
	nil, -- LEVEL_SA
	nil, -- LEVEL_BITS
	nil, -- LEVEL_LLL
	nil, -- LEVEL_DDD
	nil, -- LEVEL_WF
	nil, -- LEVEL_ENDING
	nil, -- LEVEL_CASTLE_COURTYARD
	nil, -- LEVEL_PSS
	camera.sCamCotMC, -- LEVEL_COTMC
	nil, -- LEVEL_TOTWC
	nil, -- LEVEL_BOWSER_1
	nil, -- LEVEL_WMOTR
	nil, -- LEVEL_UNKNOWN_32
	nil, -- LEVEL_BOWSER_2
	nil, -- LEVEL_BOWSER_3
	nil, -- LEVEL_UNKNOWN_35
	nil, -- LEVEL_TTM
	nil, -- LEVEL_UNKNOWN_37
	nil, -- LEVEL_UNKNOWN_38
	nil, -- LEVEL_COUNT
} :: { { GroupsTypesHPlus3.CameraTrigger }? }

-- from src/game/camera.c:sCutsceneEnding L10370-10403
camera.sCutsceneEnding = {
	{ shot = camera.cutscene_ending_mario_fall, duration = 170 },
	{ shot = camera.cutscene_ending_mario_land, duration = 70 },
	{ shot = camera.cutscene_ending_mario_land_closeup, duration = 75 },
	{ shot = camera.cutscene_ending_stars_free_peach, duration = 386 },
	{ shot = camera.cutscene_ending_peach_appears, duration = 139 },
	{ shot = camera.cutscene_ending_peach_descends, duration = 590 },
	{ shot = camera.cutscene_ending_mario_to_peach, duration = 95 },
	{ shot = camera.cutscene_ending_peach_wakeup, duration = 425 },
	{ shot = camera.cutscene_ending_dialog, duration = 236 },
	{ shot = camera.cutscene_ending_kiss, duration = 245 },
	{ shot = camera.cutscene_ending_cake_for_mario, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_ending_stop, duration = 0 },
}

-- from src/game/camera.c:sCutsceneGrandStar L10408-10411
camera.sCutsceneGrandStar = {
	{ shot = camera.cutscene_grand_star, duration = 360 },
	{ shot = camera.cutscene_grand_star_fly, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutsceneUnused L10413-10416
camera.sCutsceneUnused = {
	{ shot = camera.cutscene_unused_start, duration = 1 },
	{ shot = camera.cutscene_unused_loop, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutsceneDoorWarp L10421-10424
camera.sCutsceneDoorWarp = {
	{ shot = camera.cutscene_door_start, duration = 1 },
	{ shot = camera.cutscene_door_loop, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutsceneEndWaving L10429-10431
camera.sCutsceneEndWaving = { { shot = camera.cutscene_end_waving, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneCredits L10436-10438
camera.sCutsceneCredits = { { shot = camera.cutscene_credits, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneDoorPull L10443-10449
camera.sCutsceneDoorPull = {
	{ shot = camera.cutscene_door_start, duration = 1 },
	{ shot = camera.cutscene_door_fix_cam, duration = 30 },
	{ shot = camera.cutscene_door_move_behind_mario, duration = 1 },
	{ shot = camera.cutscene_door_follow_mario, duration = 50 },
	{ shot = camera.cutscene_door_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneDoorPush L10454-10460
camera.sCutsceneDoorPush = {
	{ shot = camera.cutscene_door_start, duration = 1 },
	{ shot = camera.cutscene_door_fix_cam, duration = 20 },
	{ shot = camera.cutscene_door_move_behind_mario, duration = 1 },
	{ shot = camera.cutscene_door_follow_mario, duration = 50 },
	{ shot = camera.cutscene_door_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneDoorPullMode L10466-10470
camera.sCutsceneDoorPullMode = {
	{ shot = camera.cutscene_door_start, duration = 1 },
	{ shot = camera.cutscene_door_fix_cam, duration = 30 },
	{ shot = camera.cutscene_door_mode, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutsceneDoorPushMode L10476-10480
camera.sCutsceneDoorPushMode = {
	{ shot = camera.cutscene_door_start, duration = 1 },
	{ shot = camera.cutscene_door_fix_cam, duration = 20 },
	{ shot = camera.cutscene_door_mode, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutsceneEnterCannon L10485-10489
camera.sCutsceneEnterCannon = {
	{ shot = camera.cutscene_enter_cannon_start, duration = 1 },
	{ shot = camera.cutscene_enter_cannon_raise, duration = 121 },
	{ shot = camera.cutscene_enter_cannon_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneStarSpawn L10494-10498
camera.sCutsceneStarSpawn = {
	{ shot = camera.cutscene_star_spawn, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_star_spawn_back, duration = 15 },
	{ shot = camera.cutscene_star_spawn_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneRedCoinStarSpawn L10504-10507
camera.sCutsceneRedCoinStarSpawn = {
	{ shot = camera.cutscene_red_coin_star, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_red_coin_star_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneEnterPainting L10512-10514
camera.sCutsceneEnterPainting = { { shot = camera.cutscene_enter_painting, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneDeathExit L10519-10522
camera.sCutsceneDeathExit = {
	{ shot = camera.cutscene_exit_painting, duration = 118 },
	{ shot = camera.cutscene_exit_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneExitPaintingSuccess L10527-10530
camera.sCutsceneExitPaintingSuccess = {
	{ shot = camera.cutscene_exit_painting, duration = 180 },
	{ shot = camera.cutscene_exit_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneUnusedExit L10532-10536
camera.sCutsceneUnusedExit = {
	{ shot = camera.cutscene_unused_exit_start, duration = 1 },
	{ shot = camera.cutscene_unused_exit_focus_mario, duration = 60 },
	{ shot = camera.cutscene_exit_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneIntroPeach L10541-10551
camera.sCutsceneIntroPeach = {
	{ shot = camera.cutscene_intro_peach_letter, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_intro_peach_reset_fov, duration = 35 },
	{ shot = camera.cutscene_intro_peach_fly_to_pipe, duration = 820 },
	{ shot = camera.cutscene_intro_peach_mario_appears, duration = 270 },
	{ shot = camera.cutscene_intro_peach_dialog, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
}

-- from src/game/camera.c:sCutscenePrepareCannon L10556-10559
camera.sCutscenePrepareCannon = {
	{ shot = camera.cutscene_prepare_cannon, duration = 170 },
	{ shot = camera.cutscene_prepare_cannon_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneExitWaterfall L10564-10567
camera.sCutsceneExitWaterfall = {
	{ shot = camera.cutscene_exit_waterfall, duration = 52 },
	{ shot = camera.cutscene_exit_to_castle_grounds_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneFallToCastleGrounds L10572-10575
camera.sCutsceneFallToCastleGrounds = {
	{ shot = camera.cutscene_exit_fall_to_castle_grounds, duration = 73 },
	{ shot = camera.cutscene_exit_to_castle_grounds_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneEnterPyramidTop L10580-10583
camera.sCutsceneEnterPyramidTop = {
	{ shot = camera.cutscene_enter_pyramid_top, duration = 90 },
	{ shot = camera.cutscene_exit_to_castle_grounds_end, duration = 0 },
}

-- from src/game/camera.c:sCutscenePyramidTopExplode L10588-10592
camera.sCutscenePyramidTopExplode = {
	{ shot = camera.cutscene_mario_dialog, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_pyramid_top_explode, duration = 150 },
	{ shot = camera.cutscene_pyramid_top_explode_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneStandingDeath L10597-10599
camera.sCutsceneStandingDeath = { { shot = camera.cutscene_death_standing, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneEnterPool L10604-10607
camera.sCutsceneEnterPool = {
	{ shot = camera.cutscene_enter_pool, duration = 100 },
	{ shot = camera.cutscene_exit_to_castle_grounds_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneDeathStomach L10612-10614
camera.sCutsceneDeathStomach = { { shot = camera.cutscene_death_stomach, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneDeathOnBack L10619-10621
camera.sCutsceneDeathOnBack = { { shot = camera.cutscene_bbh_death, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneQuicksandDeath L10626-10628
camera.sCutsceneQuicksandDeath = { { shot = camera.cutscene_quicksand_death, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneWaterDeath L10633-10635
camera.sCutsceneWaterDeath = { { shot = camera.cutscene_quicksand_death, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneSuffocation L10640-10642
camera.sCutsceneSuffocation = { { shot = camera.cutscene_suffocation, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneEnterBowserArena L10647-10651
camera.sCutsceneEnterBowserArena = {
	{ shot = camera.cutscene_bowser_arena, duration = 180 },
	{ shot = camera.cutscene_bowser_arena_dialog, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_bowser_arena_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneDanceDefaultRotate L10660-10662
camera.sCutsceneDanceDefaultRotate = { { shot = camera.cutscene_dance_default_rotate, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneDanceFlyAway L10668-10670
camera.sCutsceneDanceFlyAway = { { shot = camera.cutscene_dance_fly_away, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneDanceCloseup L10676-10678
camera.sCutsceneDanceCloseup = { { shot = camera.cutscene_dance_closeup, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneKeyDance L10684-10686
camera.sCutsceneKeyDance = { { shot = camera.cutscene_key_dance, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneCapSwitchPress L10691-10693
camera.sCutsceneCapSwitchPress = { { shot = camera.cutscene_cap_switch_press, duration = GroupsTypesHPlus3.CUTSCENE_LOOP } }

-- from src/game/camera.c:sCutsceneSlidingDoorsOpen L10698-10701
camera.sCutsceneSlidingDoorsOpen = {
	{ shot = camera.cutscene_sliding_doors_open, duration = 50 },
	{ shot = camera.cutscene_double_doors_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneUnlockKeyDoor L10706-10709
camera.sCutsceneUnlockKeyDoor = {
	{ shot = camera.cutscene_unlock_key_door, duration = 200 },
	{ shot = camera.cutscene_double_doors_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneExitBowserSuccess L10714-10717
camera.sCutsceneExitBowserSuccess = {
	{ shot = camera.cutscene_exit_bowser_succ, duration = 190 },
	{ shot = camera.cutscene_non_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneExitBowserDeath L10722-10725
camera.sCutsceneExitBowserDeath = {
	{ shot = camera.cutscene_exit_bowser_death, duration = 120 },
	{ shot = camera.cutscene_non_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneExitSpecialSuccess L10730-10733
camera.sCutsceneExitSpecialSuccess = {
	{ shot = camera.cutscene_exit_non_painting_succ, duration = 163 },
	{ shot = camera.cutscene_non_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneNonPaintingDeath L10738-10741
camera.sCutsceneNonPaintingDeath = {
	{ shot = camera.cutscene_non_painting_death, duration = 120 },
	{ shot = camera.cutscene_non_painting_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneDialog L10746-10750
camera.sCutsceneDialog = {
	{ shot = camera.cutscene_dialog, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_dialog_set_flag, duration = 12 },
	{ shot = camera.cutscene_dialog_end, duration = 0 },
}

-- from src/game/camera.c:sCutsceneReadMessage L10755-10759
camera.sCutsceneReadMessage = {
	{ shot = camera.cutscene_read_message, duration = GroupsTypesHPlus3.CUTSCENE_LOOP },
	{ shot = camera.cutscene_read_message_set_flag, duration = 15 },
	{ shot = camera.cutscene_read_message_end, duration = 0 },
}

return camera
