--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/mr_blizzard.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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


const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/mr_blizzard.inc.c:data
const mr_blizzard_inc = {
	-- from src/game/behaviors/mr_blizzard.inc.c:sMrBlizzardHitbox L4-14
	sMrBlizzardHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 24,
		damageOrCoinValue = 2,
		health = 99,
		numLootCoins = 3,
		radius = 65,
		height = 170,
		hurtboxRadius = 65,
		hurtboxHeight = 170,
	},
	-- from src/game/behaviors/mr_blizzard.inc.c:D_80331A00 L19-32
	D_80331A00 = {
		bhvParam = 0,
		count = 6,
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE,
		offsetY = 0,
		forwardVelBase = 5,
		forwardVelRange = 5,
		velYBase = 10,
		velYRange = 10,
		gravity = -3,
		dragStrength = 0,
		sizeBase = 3.0,
		sizeRange = 5.0,
	},
	-- from src/game/behaviors/mr_blizzard.inc.c:sMrBlizzardSnowballHitbox L418-428
	sMrBlizzardSnowballHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 12,
		damageOrCoinValue = 1,
		health = 99,
		numLootCoins = 0,
		radius = 30,
		height = 30,
		hurtboxRadius = 25,
		hurtboxHeight = 25,
	},
}

Registry.Register("src__game__behaviors__mr_blizzard_inc", mr_blizzard_inc)

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_spawn_white_particles L17-41
function mr_blizzard_inc.mr_blizzard_spawn_white_particles(count: number, offsetY: number, forwardVelBase: number, velYBase: number, sizeBase: number)
	count = S8(TruncS32(count))
	offsetY = S8(TruncS32(offsetY))
	forwardVelBase = S8(TruncS32(forwardVelBase))
	velYBase = S8(TruncS32(velYBase))
	sizeBase = S8(TruncS32(sizeBase))
	mr_blizzard_inc.D_80331A00.count = count
	mr_blizzard_inc.D_80331A00.offsetY = offsetY
	mr_blizzard_inc.D_80331A00.forwardVelBase = forwardVelBase
	mr_blizzard_inc.D_80331A00.velYBase = velYBase
	mr_blizzard_inc.D_80331A00.sizeBase = sizeBase

	ObjectHelpers.cur_obj_spawn_particles(mr_blizzard_inc.D_80331A00)
end

-- from src/game/behaviors/mr_blizzard.inc.c:bhv_mr_blizzard_init L46-63
function mr_blizzard_inc.bhv_mr_blizzard_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.MR_BLIZZARD_STYPE_JUMPING then
		-- Jumping Mr. Blizzard.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_JUMP)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, 24.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTargetMoveYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	else
		-- Cap wearing Mr. Blizzard from SL.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.MR_BLIZZARD_STYPE_GENERIC and bit32.btest(SaveFile.save_file_get_flags(), SaveFileH.SAVE_FLAG_CAP_ON_MR_BLIZZARD) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
		end

		-- Mr. Blizzard starts under the floor holding nothing.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, -200.0)
		o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] = nil
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_spawn_snowball L68-86
function mr_blizzard_inc.mr_blizzard_act_spawn_snowball()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] == nil and ObjBehaviors2.cur_obj_init_anim_check_frame(0, 5) ~= 0 then
		o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] = ObjectHelpers.spawn_object_relative(0, -70, S16(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) + 153.0))), 0, o, IncludeModelIdsH.MODEL_WHITE_PARTICLE, BehaviorIds.bhvMrBlizzardSnowball)
	elseif ObjectHelpers.cur_obj_check_anim_frame(10) ~= 0 then
		o.prevObj = o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] :: GroupsTypesHPlus3.Object?
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		-- If Mr. Blizzard's graphical position is below the ground, move to hide and unhide action.
		-- Otherwise, move to rotate action.
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) < 0.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_HIDE_UNHIDE)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_ROTATE)
		end
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_hide_unhide L91-107
function mr_blizzard_inc.mr_blizzard_act_hide_unhide()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
		-- If Mario is in range, move to rising action, make Mr. Blizzard visible,
		-- make Mr. Blizzard tangible, and initialize GraphYVel.
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNOW_SAND2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_RISE_FROM_GROUND)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel, 42.0)
		mr_blizzard_inc.mr_blizzard_spawn_white_particles(8, -10, 15, 20, 10)
		ObjectHelpers.cur_obj_unhide()
		ObjectHelpers.cur_obj_become_tangible()
	else
		-- If Mario is not in range, make Mr. Blizzard invisible.
		ObjectHelpers.cur_obj_hide()
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_rise_from_ground L112-135
function mr_blizzard_inc.mr_blizzard_act_rise_from_ground()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- If the timer is not 0, decrement by 1 until it reaches 0.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer) - 1)
	else
		-- Increments GraphYOffset by GraphYVel until it is greater than 24.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) > 24.0 then
			-- Mr. Blizzard's Y-position is increased by the value of GraphYOffset minus 24,
			-- GraphYOffset is set to 24, VelY is set to GraphYVel and action is moved to rotate.
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) - 24.0))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, 24.0)
			mr_blizzard_inc.mr_blizzard_spawn_white_particles(8, -20, 20, 15, 10)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_ROTATE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel) - 10.0)

			-- When GraphYVel is less than 0, set it to 47 and set timer to 5.
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel) < 0.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYVel, 47.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer, 5)
			end
		end
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_rotate L140-195
function mr_blizzard_inc.mr_blizzard_act_rotate()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- While Mr. Blizzard is on the ground, rotate toward Mario at 8.4375 degrees/frame.
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x600)

		-- Modify the ChangeInDizziness based on Mario's angle to Mr. Blizzard.
		const angleDiff = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		if angleDiff ~= 0 then
			if angleDiff < 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) - 8.0)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) + 8.0)
			end

			-- Incremement Dizziness by value of ChangeInDizziness
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness))
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) ~= 0.0 then
			const prevDizziness = buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness)

			-- Slowly move Dizziness back to 0 by making ChangeInDizziness positive if Dizziness
			-- is negative, and making ChangeInDizziness negative if Dizziness is positive.
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) < 0.0 then
				ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, 1000.0, 80.0)
			else
				ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, -1000.0, 80.0)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness))

			-- If prevDizziness has a different sign than Dizziness,
			-- set Dizziness and ChangeInDizziness to 0.
			if F32(prevDizziness * buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness)) < 0.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, 0.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, 0.0)
			end
		end

		-- If Dizziness is not 0 and Mr. Blizzard's FaceRollAngle has a magnitude greater than
		-- 67.5 degrees move to death action, delete the snowball, and make Mr. Blizzard intangible.
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) ~= 0.0 then
			if ObjectHelpers.absi(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll)) > 0x3000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_DEATH)
				o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] = nil
				o.prevObj = nil
				ObjectHelpers.cur_obj_become_intangible()
			end
		-- If Mario gets too far away, move to burrow action and delete the snowball.
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1500.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_BURROW)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, 300.0)
			o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] = nil
			o.prevObj = nil
		-- After 60 frames, if Mario is within 11.25 degrees of Mr. Blizzard, throw snowball action.
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 and ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x800 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_THROW_SNOWBALL)
		end
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_death L200-259
function mr_blizzard_inc.mr_blizzard_act_death()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	const dizzinessClamped = ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, -0x4000, 0x4000)

	if dizzinessClamped ~= 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) ~= 0.0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNOW_SAND1)

			-- If Mr. Blizzard is wearing Mario's cap, clear
			-- the save flag and spawn Mario's cap.
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) ~= 0 then
				SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_CAP_ON_MR_BLIZZARD)
				const cap = ObjectHelpers.spawn_object_relative(0, 5, 105, 0, o, IncludeModelIdsH.MODEL_MARIOS_CAP, BehaviorIds.bhvNormalCap)
				if cap ~= nil then
					buffer.writei32(cap.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + (if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) < 0 then 0x4000 else -0x4000))
					buffer.writef32(cap.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
				end

				-- Mr. Blizzard no longer spawns with Mario's cap on.
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, 0.0)
		end
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) < 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) - 40.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) + 40.0)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness))
	end

	-- After 30 frames, play the defeat sound once and scale Mr. Blizzard down to 0
	-- at .03 units per frame. Spawn coins and set the coins to not respawn.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 30 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 30 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_ENEMY_DEFEAT_SHRINK)
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale) ~= 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale) - F32(0.03))

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale) <= 0.0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale, 0.0)

				if not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 0x0000FF00) then
					ObjectHelpers.obj_spawn_loot_yellow_coins(o, buffer.readi32(o.rawData, IncludeObjectFieldsH.oNumLootCoins), 20.0)
					ObjectListProcessor.set_object_respawn_info_bits(o, 1)
				end
			end
		-- Reset Mr. Blizzard if Mario leaves its radius.
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1000.0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_SPAWN_SNOWBALL)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale, 1.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, -200.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, 0.0)
		end
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_throw_snowball L264-272
function mr_blizzard_inc.mr_blizzard_act_throw_snowball()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Play a sound and set HeldObj to NULL. Then set action to 0.
	if ObjBehaviors2.cur_obj_init_anim_check_frame(1, 7) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_SCUTTLEBUG_ALERT)
		o.prevObj = nil
		o.ptrData[IncludeObjectFieldsH.oMrBlizzardHeldObj + 1] = nil
	elseif ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_SPAWN_SNOWBALL)
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_burrow L277-293
function mr_blizzard_inc.mr_blizzard_act_burrow()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Reset Dizziness by increasing ChangeInDizziness if
	-- dizziness is negative and decreasing it if Dizziness
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness) < 0.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) + 150.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardChangeInDizziness) - 150.0)
	end

	-- Put Mr. Blizzard's graphical position back below ground
	-- then move to action 0.
	const approached = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset, -200.0, 4.0)

	if approached ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MR_BLIZZARD_ACT_SPAWN_SNOWBALL)
		ObjectHelpers.cur_obj_init_animation_with_sound(1)
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_act_jump L298-335
function mr_blizzard_inc.mr_blizzard_act_jump()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer) ~= 0 then
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTargetMoveYaw)), 3400)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer) - 1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MR_BLIZZARD_ALERT)

			-- If Mr. Blizzard is more than 700 units from its home, change its target yaw
			-- by 180 degrees, jump in the air, set distance from home to 0.
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDistFromHome) > 700 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTargetMoveYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTargetMoveYaw) + 0x8000)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 25.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer, 30)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDistFromHome, 0)
			else
				-- Jump forward.
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
			end
		end
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		-- When Mr. Blizzard lands, play the landing sound, stop Mr. Blizzard, and set its timer to 15.
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNOW_SAND1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDistFromHome) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDistFromHome, TruncS32(ObjectHelpers.cur_obj_lateral_dist_to_home()))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDistFromHome, 700)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrBlizzardTimer, 15)
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:bhv_mr_blizzard_update L340-381
function mr_blizzard_inc.bhv_mr_blizzard_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	-- Behavior loop
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_SPAWN_SNOWBALL then
		mr_blizzard_inc.mr_blizzard_act_spawn_snowball()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_HIDE_UNHIDE then
		mr_blizzard_inc.mr_blizzard_act_hide_unhide()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_RISE_FROM_GROUND then
		mr_blizzard_inc.mr_blizzard_act_rise_from_ground()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_ROTATE then
		mr_blizzard_inc.mr_blizzard_act_rotate()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_THROW_SNOWBALL then
		mr_blizzard_inc.mr_blizzard_act_throw_snowball()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_BURROW then
		mr_blizzard_inc.mr_blizzard_act_burrow()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_DEATH then
		mr_blizzard_inc.mr_blizzard_act_death()
	elseif action == IncludeObjectConstantsH.MR_BLIZZARD_ACT_JUMP then
		mr_blizzard_inc.mr_blizzard_act_jump()
	end

	-- Set roll angle equal to dizziness, making Mr. Blizzard slowly fall over.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardDizziness)))

	-- Mr. Blizzard's graphical position changes by changing the Y offset.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardGraphYOffset) + ObjectHelpers.absf(F32(20.0 * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))))) - F32(40.0 * F32(1.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale)))))

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrBlizzardScale))
	ObjectHelpers.cur_obj_move_standard(78)
	ObjBehaviors2.obj_check_attacks(mr_blizzard_inc.sMrBlizzardHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_snowball_act_0 L386-393
function mr_blizzard_inc.mr_blizzard_snowball_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	if parentObj.prevObj == o then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, 190.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, -38.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, -38.0)
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_snowball_act_1 L398-415
function mr_blizzard_inc.mr_blizzard_snowball_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if parentObj.prevObj == nil then
		if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.MR_BLIZZARD_ACT_THROW_SNOWBALL then
			local marioDist = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario)
			if marioDist > 800.0 then
				marioDist = 800.0
			end

			-- Launch the snowball relative to Mario's distance from the snowball.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32((buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 4000) - F32(marioDist * 4.0))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -20.0 + F32(marioDist * F32(0.075)))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
	end
end

-- from src/game/behaviors/mr_blizzard.inc.c:mr_blizzard_snowball_act_2 L433-446
function mr_blizzard_inc.mr_blizzard_snowball_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Set snowball to interact with walls, floors, and Mario.
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjBehaviors2.obj_check_attacks(mr_blizzard_inc.sMrBlizzardSnowballHitbox, -1)

	-- If snowball collides with the ground, delete snowball.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == -1 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER)) then
		mr_blizzard_inc.mr_blizzard_spawn_white_particles(6, 0, 5, 10, 3)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_MOVING_IN_SAND)
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/mr_blizzard.inc.c:bhv_mr_blizzard_snowball L451-463
function mr_blizzard_inc.bhv_mr_blizzard_snowball()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		mr_blizzard_inc.mr_blizzard_snowball_act_0()
	elseif action == 1 then
		mr_blizzard_inc.mr_blizzard_snowball_act_1()
	elseif action == 2 then
		mr_blizzard_inc.mr_blizzard_snowball_act_2()
	end
end

return mr_blizzard_inc
