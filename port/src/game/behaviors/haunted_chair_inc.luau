--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/haunted_chair.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const GameInit = require("../game_init")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

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

-- from src/game/behaviors/haunted_chair_inc.luau:scratch
const Scratch = {
	bhv_haunted_chair_init_val00 = { 0 },
}

-- from src/game/behaviors/haunted_chair.inc.c:data
const haunted_chair_inc = {
	-- from src/game/behaviors/haunted_chair.inc.c:sHauntedChairHitbox L3-13
	sHauntedChairHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 0,
		radius = 50,
		height = 50,
		hurtboxRadius = 50,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__haunted_chair_inc", haunted_chair_inc)

-- from src/game/behaviors/haunted_chair.inc.c:bhv_haunted_chair_init L15-26
function haunted_chair_inc.bhv_haunted_chair_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const val04 = ObjectHelpers.cur_obj_find_nearest_object_with_behavior(BehaviorIds.bhvMadPiano, Scratch.bhv_haunted_chair_init_val00)

	if val04 ~= nil and Scratch.bhv_haunted_chair_init_val00[1] < 300.0 then
		o.parentObj = val04
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4, 1)
	end
end

-- from src/game/behaviors/haunted_chair.inc.c:haunted_chair_act_0 L28-97
function haunted_chair_inc.haunted_chair_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if o.parentObj ~= o then
		const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104) == 0 then
			if ObjectHelpers.lateral_dist_between_objects(o, parentObj) < 250.0 then
				const val0E = S16(ObjectHelpers.obj_angle_to_object(o, parentObj) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x2000)

				if bit32.btest(val0E, 0x4000) then
					-- The pointer to an own field is the field's byte offset (object-callee-signatures-applied)
					o.ptrData[IncludeObjectFieldsH.oHauntedChairUnk100 + 1] = IncludeObjectFieldsH.oFaceAngleRoll

					if val0E > 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104, 0x4000)
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104, -0x4000)
					end
				else
					o.ptrData[IncludeObjectFieldsH.oHauntedChairUnk100 + 1] = IncludeObjectFieldsH.oFaceAnglePitch

					if val0E < 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104, 0x5000)
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104, -0x4000)
					end
				end

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104) < 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF8, -1500.0)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF8, 1500.0)
				end
			end
		else
			const valueOffset = o.ptrData[IncludeObjectFieldsH.oHauntedChairUnk100 + 1] :: number

			ObjBehaviors2.oscillate_toward(o.rawData, valueOffset, o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF8, buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnk104), 4000.0, 20.0, 2.0)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) ~= 0 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) - 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	else
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 0x8) then
			local val08: number

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_HAUNTED_CHAIR_MOVE)
				val08 = 4.0
			else
				val08 = -4.0
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - val08)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - val08)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(F32(50.0 * val08)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF8, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkFC, 200.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4, 40)
		end
	end

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(80.0, 120.0)
end

-- from src/game/behaviors/haunted_chair.inc.c:haunted_chair_act_1 L99-136
function haunted_chair_inc.haunted_chair_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 70 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 50 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 6.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)

		ObjBehaviors2.oscillate_toward(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF8, -4000, 200.0, 20.0, 2.0)
		ObjBehaviors2.oscillate_toward(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, o.rawData, IncludeObjectFieldsH.oHauntedChairUnkFC, 0, 0.0, 20.0, 1.0)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) - 1))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_HAUNTED_CHAIR)

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjBehaviors2.obj_turn_pitch_toward_mario(120.0, 0))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))

				ObjBehaviors2.obj_compute_vel_from_move_pitch(50.0)
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedChairUnkF4) > 20 then
				if GameInit.gGlobalTimer % 4 == 0 then
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_AIR_2)
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 10000))
			end
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL)) then
			ObjBehaviors2.obj_die_if_health_non_positive()
		end
	end

	ObjBehaviors2.obj_check_attacks(haunted_chair_inc.sHauntedChairHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/haunted_chair.inc.c:bhv_haunted_chair_loop L138-151
function haunted_chair_inc.bhv_haunted_chair_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if action == 0 then
			haunted_chair_inc.haunted_chair_act_0()
		elseif action == 1 then
			haunted_chair_inc.haunted_chair_act_1()
		end

		ObjBehaviors2.cur_obj_spin_all_dimensions(30.0, 30.0)
	end
end

return haunted_chair_inc
