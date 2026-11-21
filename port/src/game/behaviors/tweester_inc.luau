--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tweester.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/tweester.inc.c:data
const tweester_inc = {
	-- from src/game/behaviors/tweester.inc.c:sTweesterHitbox L9-19
	sTweesterHitbox = {
		interactType = InteractionH.INTERACT_TORNADO,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 1500,
		height = 4000,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__tweester_inc", tweester_inc)

-- from src/game/behaviors/tweester.inc.c:tweester_scale_and_move L25-39
function tweester_inc.tweester_scale_and_move(preScale: number)
	preScale = F32(preScale)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Scale = F32(preScale * 0.4)
	const CosTimer: number = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTweesterScaleTimer))

	o.header.gfx.scale[1] = F32(((CosTimer + 1.0) * 0.5 * 0.3 + 1.0) * Scale)
	o.header.gfx.scale[2] = F32(((-CosTimer + 1.0) * 0.5 * 0.5 + 0.5) * Scale)
	o.header.gfx.scale[3] = F32(((CosTimer + 1.0) * 0.5 * 0.3 + 1.0) * Scale)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTweesterScaleTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTweesterScaleTimer) + 0x200)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 14.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x2C00)
end

-- from src/game/behaviors/tweester.inc.c:tweester_act_idle L46-68
function tweester_inc.tweester_act_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.TWEESTER_SUB_ACT_WAIT then
		ObjectHelpers.cur_obj_become_tangible()
		ObjectHelpers.cur_obj_set_pos_to_home()
		ObjectHelpers.cur_obj_scale(0.0)

		-- Hard to have any idea of this purpose, only set here.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTweesterUnused, 0)

		-- If Mario is within range, change to the growth sub-action.
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	else
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WIND1)
		tweester_inc.tweester_scale_and_move(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 60.0))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TWEESTER_ACT_CHASE)
		end
	end
end

-- from src/game/behaviors/tweester.inc.c:tweester_act_chase L74-111
function tweester_inc.tweester_act_chase()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ActivationRadius = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 100

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToHome, ObjectHelpers.cur_obj_angle_to_home())
	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WIND1)

	if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() < ActivationRadius and buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == IncludeObjectConstantsH.TWEESTER_SUB_ACT_CHASE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x200)
		-- print_debug_top_down_objectinfo("off ", 0): no call (debug-print-externals)

		if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_TWIRLING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToHome)), 0x200)

		if ObjectHelpers.cur_obj_lateral_dist_to_home() < 200.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TWEESTER_ACT_HIDE)
		end
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 3000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TWEESTER_ACT_HIDE)
	end

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oWallAngle))
	end

	ObjectHelpers.cur_obj_move_standard(60)
	tweester_inc.tweester_scale_and_move(1.0)
	ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SAND_DUST, BehaviorIds.bhvTweesterSandParticle)
end

-- from src/game/behaviors/tweester.inc.c:tweester_act_hide L117-131
function tweester_inc.tweester_act_hide()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ShrinkTimer = F32(60.0 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer))

	if ShrinkTimer >= 0.0 then
		tweester_inc.tweester_scale_and_move(F32(ShrinkTimer / 60.0))
	else
		ObjectHelpers.cur_obj_become_intangible()

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 2500.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TWEESTER_ACT_IDLE)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 360 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.TWEESTER_ACT_IDLE)
		end
	end
end

-- from src/game/behaviors/tweester.inc.c:bhv_tweester_loop L144-148
function tweester_inc.bhv_tweester_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, tweester_inc.sTweesterHitbox)
	ObjectHelpers.cur_obj_call_action_function(tweester_inc.sTweesterActions)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/tweester.inc.c:bhv_tweester_sand_particle_loop L154-170
function tweester_inc.bhv_tweester_sand_particle_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x3700)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) + 15.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 22.0)
	ObjectHelpers.cur_obj_scale(F32(SrcEngineBehaviorScript.random_float() + 1.0))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.obj_translate_xz_random(o, 100.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, SrcEngineBehaviorScript.random_u16())
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, SrcEngineBehaviorScript.random_u16())
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/tweester.inc.c:sTweesterActions L134-138
tweester_inc.sTweesterActions = { tweester_inc.tweester_act_idle, tweester_inc.tweester_act_chase, tweester_inc.tweester_act_hide }

return tweester_inc
