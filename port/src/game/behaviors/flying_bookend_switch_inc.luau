--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/flying_bookend_switch.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const LevelUpdate = require("../level_update")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

-- from src/game/behaviors/flying_bookend_switch.inc.c:Struct80331B30
export type Struct80331B30 = {
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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/flying_bookend_switch_inc.luau:scratch
const Scratch = {
	flying_bookend_act_1_scale = buffer.create(4),
}

-- from src/game/behaviors/flying_bookend_switch.inc.c:data
const flying_bookend_switch_inc = {
	-- from src/game/behaviors/flying_bookend_switch.inc.c:sFlyingBookendHitbox L8-18
	sFlyingBookendHitbox = {
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = -1,
		radius = 60,
		height = 30,
		hurtboxRadius = 40,
		hurtboxHeight = 30,
	},
	-- from src/game/behaviors/flying_bookend_switch.inc.c:D_80331B30 L20-24
	D_80331B30 = { { unk00 = 52, unk02 = 150 }, { unk00 = 135, unk02 = 3 }, { unk00 = -75, unk02 = 78 } },
	-- from src/game/behaviors/flying_bookend_switch.inc.c:sBookSwitchHitbox L26-36
	sBookSwitchHitbox = {
		interactType = InteractionH.INTERACT_BREAKABLE,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 99,
		numLootCoins = 0,
		radius = 20,
		height = 30,
		hurtboxRadius = 20,
		hurtboxHeight = 30,
	},
}

Registry.Register("src__game__behaviors__flying_bookend_switch_inc", flying_bookend_switch_inc)

-- from src/game/behaviors/flying_bookend_switch.inc.c:Struct80331B30 (zero-filled constructor)
function flying_bookend_switch_inc.new_Struct80331B30(): Struct80331B30
	return { unk00 = 0, unk02 = 0 } :: Struct80331B30
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:flying_bookend_act_0 L38-49
function flying_bookend_switch_inc.flying_bookend_act_0()
	const o = ObjectListProcessor.gCurrentObject

	if ObjBehaviors2.obj_is_near_to_and_facing_mario(400, 0x3000) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DEFAULT_DEATH)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookendUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x7FFF)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookendUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - 0x7FFF)

		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BOOKEND_PART)
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:flying_bookend_act_1 L51-72
function flying_bookend_switch_inc.flying_bookend_act_1()
	const o = ObjectListProcessor.gCurrentObject

	if ObjBehaviors2.obj_forward_vel_approach(3, 1) ~= 0 then
		if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(2) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
				ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookendUnkF4)), 2000)
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 10 then
					ObjBehaviors2.obj_face_roll_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookendUnkF8)), 2000)
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 20 then
						buffer.writef32(Scratch.flying_bookend_act_1_scale, 0, o.header.gfx.scale[1])
						ObjBehaviors2.approach_f32_ptr(Scratch.flying_bookend_act_1_scale, 0, 3, F32(0.2))
						o.header.gfx.scale[1] = buffer.readf32(Scratch.flying_bookend_act_1_scale, 0)
					end
				end
			end
		end
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:flying_bookend_act_2 L74-89
function flying_bookend_switch_inc.flying_bookend_act_2()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation_with_sound(1)
	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) == 0 then
		ObjBehaviors2.obj_turn_pitch_toward_mario(120, 1000)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + 0x7FFF)
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 1000)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			ObjBehaviors2.obj_compute_vel_from_move_pitch(50)
		end
	end

	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:flying_bookend_act_3 L91-102
function flying_bookend_switch_inc.flying_bookend_act_3()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue, 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 50)
	end

	ObjBehaviors2.obj_forward_vel_approach(50, 2)
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bhv_flying_bookend_loop L104-133
function flying_bookend_switch_inc.bhv_flying_bookend_loop()
	const o = ObjectListProcessor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_POUNDING1)
		ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
			flying_bookend_switch_inc.flying_bookend_act_0()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
			flying_bookend_switch_inc.flying_bookend_act_1()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
			flying_bookend_switch_inc.flying_bookend_act_2()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
			flying_bookend_switch_inc.flying_bookend_act_3()
		end

		ObjBehaviors2.obj_check_attacks(flying_bookend_switch_inc.sFlyingBookendHitbox, -1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == -1 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL)) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
			ObjBehaviors2.obj_die_if_health_non_positive()
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 30 * o.header.gfx.scale[1])
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bhv_bookend_spawn_loop L135-148
function flying_bookend_switch_inc.bhv_bookend_spawn_loop()
	const o = ObjectListProcessor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 40 and ObjBehaviors2.obj_is_near_to_and_facing_mario(600, 0x2000) ~= 0 then
			const sp1C: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOOKEND, BehaviorIds.bhvFlyingBookend)

			if sp1C ~= nil then
				buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oAction, 3)
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DEFAULT_DEATH)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bookshelf_manager_act_0 L150-161
function flying_bookend_switch_inc.bookshelf_manager_act_0()
	const o = ObjectListProcessor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		for i = 0, 2 do
			ObjectHelpers.spawn_object_relative(S16(i), flying_bookend_switch_inc.D_80331B30[i + 1].unk00, flying_bookend_switch_inc.D_80331B30[i + 1].unk02, 0, o, IncludeModelIdsH.MODEL_BOOKEND, BehaviorIds.bhvBookSwitch)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bookshelf_manager_act_1 L163-172
function flying_bookend_switch_inc.bookshelf_manager_act_1()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8) == 0 then
		if ObjBehaviors2.obj_is_near_to_and_facing_mario(500, 0x3000) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8, 0)
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bookshelf_manager_act_2 L174-199
function flying_bookend_switch_inc.bookshelf_manager_act_2()
	const o = ObjectListProcessor.gCurrentObject

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) < 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4, 0)
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8, 1)
			end
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) >= 3 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
					const bookshelf = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHauntedBookshelf) :: GroupsTypesHPlus3.Object
					o.parentObj = bookshelf
					buffer.writei32(bookshelf.rawData, IncludeObjectFieldsH.oAction, 1)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(bookshelf.rawData, IncludeObjectFieldsH.oPosX))
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
				elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 30 then
					Audio.play_puzzle_jingle()
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bookshelf_manager_act_3 L201-208
function flying_bookend_switch_inc.bookshelf_manager_act_3()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 85 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	else
		const parent = o.parentObj :: GroupsTypesHPlus3.Object
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX))
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bookshelf_manager_act_4 L210-216
function flying_bookend_switch_inc.bookshelf_manager_act_4()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) >= 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bhv_haunted_bookshelf_manager_loop L218-236
function flying_bookend_switch_inc.bhv_haunted_bookshelf_manager_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		flying_bookend_switch_inc.bookshelf_manager_act_0()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		flying_bookend_switch_inc.bookshelf_manager_act_2()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		flying_bookend_switch_inc.bookshelf_manager_act_1()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		flying_bookend_switch_inc.bookshelf_manager_act_3()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		flying_bookend_switch_inc.bookshelf_manager_act_4()
	end
end

-- from src/game/behaviors/flying_bookend_switch.inc.c:bhv_book_switch_loop L238-306
function flying_bookend_switch_inc.bhv_book_switch_loop()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	o.header.gfx.scale[1] = 2
	o.header.gfx.scale[2] = F32(0.9)

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == 4 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		const attackType = ObjBehaviors2.obj_check_attacks(flying_bookend_switch_inc.sBookSwitchHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))

		if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF8) ~= 0 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 100 then
				ObjectHelpers.cur_obj_become_tangible()
			else
				ObjectHelpers.cur_obj_become_intangible()
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oBookSwitchUnkF4) == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DEFAULT_DEATH)
			end

			if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oBookSwitchUnkF4, 50, 20) ~= 0 then
				if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) >= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 and (attackType == InteractionH.ATTACK_PUNCH or attackType == InteractionH.ATTACK_KICK_OR_TRIP or attackType == InteractionH.ATTACK_FROM_BELOW) then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		else
			ObjectHelpers.cur_obj_become_intangible()

			if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oBookSwitchUnkF4, 0, 20) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= 0 then
				if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
					Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_RIGHT_ANSWER, Audio.gGlobalSoundSource)
					buffer.writei32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4) + 1)
				else
					const sp36 = S16(bit32.band(SrcEngineBehaviorScript.random_u16(), 1))
					local sp34 = S16(TruncS32(F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ) + F32(1.5 * LevelUpdate.gMarioStates[1].vel[3]))))

					Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)

					if sp34 > 0 then
						sp34 = 0
					end

					const sp38: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_BOOKEND, BehaviorIds.bhvFlyingBookend, S16(0x1FC * sp36 - 0x8CA), 890, sp34, 0, S16(0x8000 * sp36 + 0x4000), 0)

					if sp38 ~= nil then
						buffer.writei32(sp38.rawData, IncludeObjectFieldsH.oAction, 3)
					end

					buffer.writei32(parent.rawData, IncludeObjectFieldsH.oBookSwitchManagerUnkF4, -1)
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
			end
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(parent.rawData, IncludeObjectFieldsH.oForwardVel))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oBookSwitchUnkF4))
		ObjectHelpers.cur_obj_push_mario_away_from_cylinder(70, 70)
	end
end

return flying_bookend_switch_inc
