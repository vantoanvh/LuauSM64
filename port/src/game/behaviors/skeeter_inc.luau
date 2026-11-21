--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/skeeter.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

-- from src/game/behaviors/skeeter.inc.c:Struct80331C38
export type Struct80331C38 = {
	unk00: number,
	unk02: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/skeeter_inc.luau:scratch
const Scratch = {
	bhv_skeeter_wave_update_scale = buffer.create(4),
	skeeter_act_idle_angleVel = { 0 },
	skeeter_act_idle_angle = { 0 },
}

-- from src/game/behaviors/skeeter.inc.c:data
const skeeter_inc = {
	-- from src/game/behaviors/skeeter.inc.c:sSkeeterHitbox L8-18
	sSkeeterHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 20,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 3,
		radius = 180,
		height = 100,
		hurtboxRadius = 150,
		hurtboxHeight = 90,
	},
	-- from src/game/behaviors/skeeter.inc.c:D_80331C38 L20-25
	D_80331C38 = {
		{ unk00 = -130, unk02 = -190 },
		{ unk00 = 0x0082, unk02 = -190 },
		{ unk00 = -180, unk02 = 0x0082 },
		{ unk00 = 0x00B4, unk02 = 0x0082 },
	},
}

Registry.Register("src__game__behaviors__skeeter_inc", skeeter_inc)

-- from src/game/behaviors/skeeter.inc.c:Struct80331C38 (zero-filled constructor)
function skeeter_inc.new_Struct80331C38(): Struct80331C38
	return { unk00 = 0, unk02 = 0 } :: Struct80331C38
end

-- from src/game/behaviors/skeeter.inc.c:skeeter_spawn_waves L27-34
function skeeter_inc.skeeter_spawn_waves()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	for Index = 1, 4 do
		ObjectHelpers.spawn_object_relative_with_scale(0, skeeter_inc.D_80331C38[Index].unk00, 0, skeeter_inc.D_80331C38[Index].unk02, F32(0.8), o, IncludeModelIdsH.MODEL_IDLE_WATER_WAVE, BehaviorIds.bhvSkeeterWave)
	end
end

-- from src/game/behaviors/skeeter.inc.c:skeeter_act_idle L36-63
function skeeter_inc.skeeter_act_idle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		ObjectHelpers.cur_obj_init_animation_with_sound(3)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime) and ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_WALK)
		end
	else
		ObjectHelpers.cur_obj_init_animation_with_sound(1)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE) then
			skeeter_inc.skeeter_spawn_waves()

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
				Scratch.skeeter_act_idle_angleVel[1] = buffer.readi16(o.rawData, IncludeObjectFieldsH.oSkeeterUnk1AC)
				Scratch.skeeter_act_idle_angle[1] = buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)
				const turned = ObjBehaviors2.obj_smooth_turn(Scratch.skeeter_act_idle_angleVel, Scratch.skeeter_act_idle_angle, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle)), F32(0.02), 5, 50, 200)
				buffer.writei16(o.rawData, IncludeObjectFieldsH.oSkeeterUnk1AC, Scratch.skeeter_act_idle_angleVel[1])
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Scratch.skeeter_act_idle_angle[1])

				if turned ~= 0 then
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime) ~= 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime) - 1)
					elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
						SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_WALKING_WATER)
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_LUNGE)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 80.0)
						buffer.writei16(o.rawData, IncludeObjectFieldsH.oSkeeterUnk1AC, 0)
					end
				end
			end
		end
	end
end

-- from src/game/behaviors/skeeter.inc.c:skeeter_act_lunge L65-92
function skeeter_inc.skeeter_act_lunge()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_AT_WATER_SURFACE) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_IDLE)
	else
		skeeter_inc.skeeter_spawn_waves()
		ObjectHelpers.cur_obj_init_animation_with_sound(0)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.3))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		end

		if ObjBehaviors2.obj_forward_vel_approach(0.0, F32(0.8)) ~= 0 and ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle, ObjBehaviors2.obj_random_fixed_turn(SrcEngineBehaviorScript.random_u16() % 0x2000))
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_IDLE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, ObjBehaviors2.random_linear_offset(0, 30))
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))
		end
	end
end

-- from src/game/behaviors/skeeter.inc.c:skeeter_act_walk L94-137
function skeeter_inc.skeeter_act_walk()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_IDLE)
	else
		ObjBehaviors2.obj_forward_vel_approach(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSkeeterUnkFC), F32(0.4))
		const sp24 = F32(F32(0.12) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(2, sp24)
		ObjBehaviors2.cur_obj_play_sound_at_anim_range(3, 13, IncludeSoundsH.SOUND_OBJ_SKEETER_WALK)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterTurningAwayFromWall) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle)), 0x400))
		else
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, ObjBehaviors2.random_linear_offset(20, 30))
			end

			const bounced = ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTurningAwayFromWall, bounced)

			if bounced == 0 then
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oSkeeterUnkFC, 20.0)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oSkeeterUnkFC, 10.0)
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime) ~= 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime) - 1)
					elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
						if bit32.btest(SrcEngineBehaviorScript.random_u16(), 0x0003) then
							buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle, ObjBehaviors2.obj_random_fixed_turn(0x2000))
							buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, ObjBehaviors2.random_linear_offset(100, 100))
						else
							buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SKEETER_ACT_IDLE)
							buffer.writei32(o.rawData, IncludeObjectFieldsH.oSkeeterWaitTime, ObjBehaviors2.random_linear_offset(100, 100))
						end
					end
				end
			end
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSkeeterTargetAngle)), 0x400)
	end
end

-- from src/game/behaviors/skeeter.inc.c:bhv_skeeter_update L139-159
function skeeter_inc.bhv_skeeter_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_SNUFIT_SKEETER_DEATH)
	ObjBehaviors2.treat_far_home_as_mario(1000.0)
	ObjectHelpers.cur_obj_update_floor_and_walls()

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.SKEETER_ACT_IDLE then
		skeeter_inc.skeeter_act_idle()
	elseif action == IncludeObjectConstantsH.SKEETER_ACT_LUNGE then
		skeeter_inc.skeeter_act_lunge()
	elseif action == IncludeObjectConstantsH.SKEETER_ACT_WALK then
		skeeter_inc.skeeter_act_walk()
	end

	ObjBehaviors2.obj_check_attacks(skeeter_inc.sSkeeterHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	ObjectHelpers.cur_obj_move_standard(-78)
end

-- from src/game/behaviors/skeeter.inc.c:bhv_skeeter_wave_update L161-168
function skeeter_inc.bhv_skeeter_wave_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(Scratch.bhv_skeeter_wave_update_scale, 0, o.header.gfx.scale[1])
	if ObjBehaviors2.approach_f32_ptr(Scratch.bhv_skeeter_wave_update_scale, 0, 0.0, F32(0.3)) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
	o.header.gfx.scale[1] = buffer.readf32(Scratch.bhv_skeeter_wave_update_scale, 0)

	ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, GameInit.gGlobalTimer // 6)
end

return skeeter_inc
