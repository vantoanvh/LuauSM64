--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/swoop.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/swoop_inc.luau:scratch
const Scratch = {
	swoop_act_idle_scale = buffer.create(4),
}

-- from src/game/behaviors/swoop.inc.c:data
const swoop_inc = {
	-- from src/game/behaviors/swoop.inc.c:sSwoopHitbox L10-20
	sSwoopHitbox = {
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 1,
		radius = 100,
		height = 80,
		hurtboxRadius = 70,
		hurtboxHeight = 70,
	},
}

Registry.Register("src__game__behaviors__swoop_inc", swoop_inc)

-- from src/game/behaviors/swoop.inc.c:swoop_act_idle L26-38
function swoop_inc.swoop_act_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	buffer.writef32(Scratch.swoop_act_idle_scale, 0, o.header.gfx.scale[1])
	const ScaleReached: number = ObjBehaviors2.approach_f32_ptr(Scratch.swoop_act_idle_scale, 0, 1.0, F32(0.05))
	o.header.gfx.scale[1] = buffer.readf32(Scratch.swoop_act_idle_scale, 0)

	if ScaleReached ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
		if ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 800) ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_SWOOP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SWOOP_ACT_MOVE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -12.0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0x8000)
end

-- from src/game/behaviors/swoop.inc.c:swoop_act_move L44-95
function swoop_inc.swoop_act_move()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, 2.0)

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_UNKNOWN6)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) == 0.0 then
		-- If we haven't started moving yet, begin swooping
		if ObjBehaviors2.obj_face_roll_approach(0, 2500) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -10.0)
		end
	elseif ObjectHelpers.cur_obj_mario_far_away() ~= 0 then
		-- If mario far away, reset
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SWOOP_ACT_IDLE)
		ObjectHelpers.cur_obj_set_pos_to_home()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		o.header.gfx.scale[1] = 0.0
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopBonkCountdown) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopBonkCountdown, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopBonkCountdown) - 1)
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) ~= 0.0 then
			-- If we're not done swooping, turn toward mario. When between
			-- 0 and 200 units above mario, increase speed and stop swooping
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32((ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oPosY) + 200.0) then
				if ObjBehaviors2.obj_y_vel_approach(0.0, 0.5) ~= 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 2.0)
				end
			else
				ObjBehaviors2.obj_y_vel_approach(-10.0, 0.5)
			end
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			-- Bounce off a wall and don't bounce again for 30 frames.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopTargetYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopBonkCountdown, 30)
		end

		-- Tilt upward when approaching mario
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopTargetPitch, ObjBehaviors2.obj_get_pitch_from_vel())

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopTargetPitch) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSwoopTargetPitch, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopTargetPitch) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 500)))))
		end

		ObjBehaviors2.obj_move_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopTargetPitch)), 140)

		-- Jitter yaw a bit
		const CosTimer: number = Registry.Members.src__engine__math_util_h.coss(S16(4000 * GameInit.gGlobalTimer))
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopTargetYaw) + TruncS32(F32(3000 * CosTimer))), 1200)
		ObjBehaviors2.obj_roll_to_match_yaw_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSwoopTargetYaw)), 0x3000, 500)

		-- Jitter roll a bit
		const CosRollTimer: number = Registry.Members.src__engine__math_util_h.coss(S16(20000 * GameInit.gGlobalTimer))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + TruncS32(F32(1000 * CosRollTimer))))
	end
end

-- from src/game/behaviors/swoop.inc.c:bhv_swoop_update L100-122
function swoop_inc.bhv_swoop_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_SWOOP_DEATH)

		ObjectHelpers.cur_obj_update_floor_and_walls()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SWOOP_ACT_IDLE then
			swoop_inc.swoop_act_idle()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SWOOP_ACT_MOVE then
			swoop_inc.swoop_act_move()
		end

		ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
		ObjectHelpers.cur_obj_move_standard(78)

		ObjBehaviors2.obj_check_attacks(swoop_inc.sSwoopHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	end
end

return swoop_inc
