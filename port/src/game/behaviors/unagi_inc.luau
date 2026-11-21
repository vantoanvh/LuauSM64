--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/unagi.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const Memory = require("../memory")
const SegmentSymbols = require("../../rom/segment_symbols")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/unagi.inc.c:data
const unagi_inc = {
	-- from src/game/behaviors/unagi.inc.c:sUnagiHitbox L3-13
	sUnagiHitbox = {
		interactType = InteractionH.INTERACT_CLAM_OR_BUBBA,
		downOffset = 50,
		damageOrCoinValue = 3,
		health = 99,
		numLootCoins = 0,
		radius = 150,
		height = 150,
		hurtboxRadius = 150,
		hurtboxHeight = 150,
	},
}

Registry.Register("src__game__behaviors__unagi_inc", unagi_inc)

-- from src/game/behaviors/unagi.inc.c:bhv_unagi_init L15-32
function unagi_inc.bhv_unagi_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 1 then
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.jrb_seg7_trajectory_unagi_1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, -7600)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	else
		o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] = Memory.segmented_to_virtual(SegmentSymbols.jrb_seg7_trajectory_unagi_2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUnagiUnk1B0, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	end

	o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1]
end

-- from src/game/behaviors/unagi.inc.c:unagi_act_0 L34-43
function unagi_inc.unagi_act_0()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Waypoint = o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1] :: number
	-- from src/game/behaviors/unagi.inc.c:unagi_act_0
	const pos = Waypoint + 2

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 4500 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Rom.ReadS16(pos + 0))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Rom.ReadS16(pos + 2))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Rom.ReadS16(pos + 4))
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk1AC) < 700 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
	end
end

-- from src/game/behaviors/unagi.inc.c:unagi_act_1_4 L45-74
function unagi_inc.unagi_act_1_4(arg0: number)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID) == 3 then
		if ObjectHelpers.cur_obj_check_anim_frame(30) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40)
		end
	elseif ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= arg0 and bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags), 0xFF) >= 7 then
			ObjectHelpers.cur_obj_init_animation_with_sound(3)
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(2)
		end
	end

	if ObjectHelpers.cur_obj_check_anim_frame(6) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_MOVING_WATER)
	end

	if ObjectHelpers.cur_obj_follow_path(0) == ObjectHelpersH.PATH_REACHED_END then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, arg0)
	end

	const PitchTarget = ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetPitch)), 50)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, PitchTarget)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, PitchTarget)

	ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw)), 120)
	ObjBehaviors2.obj_roll_to_match_yaw_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPathedTargetYaw)), 0x2000, 100)

	ObjBehaviors2.obj_forward_vel_approach(10, F32(0.2))
	ObjectHelpers.cur_obj_set_pos_via_transform()
end

-- from src/game/behaviors/unagi.inc.c:unagi_act_2 L76-91
function unagi_inc.unagi_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.ptrData[IncludeObjectFieldsH.oPathedPrevWaypoint + 1] = o.ptrData[IncludeObjectFieldsH.oPathedStartWaypoint + 1]
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPathedPrevWaypointFlags, 0)

	ObjectHelpers.cur_obj_set_pos_to_home()

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)

	const UnkYaw = buffer.readi16(o.rawData, IncludeObjectFieldsH.oUnagiUnk1B0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, UnkYaw)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, UnkYaw)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8, 0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4, -800)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
end

-- from src/game/behaviors/unagi.inc.c:unagi_act_3 L93-138
function unagi_inc.unagi_act_3()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) < 0.0 then
		ObjectHelpers.cur_obj_init_animation_with_sound(6)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) + 10.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) > 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4, 0.0)
		end
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) == 0.0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(6)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk1AC) < 1000.0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_EEL_2)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110, 30.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110))
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110, 0.0)
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110) > 0.0 then
			if ObjBehaviors2.cur_obj_init_anim_and_check_if_end(5) ~= 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110, 0.0)
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110) == 0.0 then
			ObjectHelpers.cur_obj_init_animation_with_sound(0)

			if ObjectHelpers.cur_obj_check_if_at_animation_end() ~= 0 then
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk1AC) < 1000.0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8))
					ObjectHelpers.cur_obj_init_animation_with_sound(1)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110, -50.0)
					ObjectHelpers.cur_obj_init_animation_with_sound(4)
				end
			end
		end

		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnk110), 4.0)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) < 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4, buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF8))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oUnagiUnkF4) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
end

-- from src/game/behaviors/unagi.inc.c:bhv_unagi_loop L140-171
function unagi_inc.bhv_unagi_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oUnagiUnk1B2) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oUnagiUnk1AC, 99999)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 3000 then
			for I = -4, 3 do
				ObjectHelpers.spawn_object_relative(S16(I), 0, 0, 0, o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvUnagiSubobject)
			end

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oUnagiUnk1B2, 1)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 4000 then
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oUnagiUnk1B2, 0)
	end

	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == 0 then
		unagi_inc.unagi_act_0()
	elseif Action == 1 then
		unagi_inc.unagi_act_1_4(Action)
	elseif Action == 2 then
		unagi_inc.unagi_act_2()
		unagi_inc.unagi_act_3()
	elseif Action == 3 then
		unagi_inc.unagi_act_3()
	elseif Action == 4 then
		unagi_inc.unagi_act_1_4(2)
	end
end

-- from src/game/behaviors/unagi.inc.c:bhv_unagi_subobject_loop L173-199
function unagi_inc.bhv_unagi_subobject_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi16(Parent.rawData, IncludeObjectFieldsH.oUnagiUnk1B2) == 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		local val04 = F32(300 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY) - F32(F32(val04 * SrcEngineMathUtilH.sins(buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oFaceAnglePitch))) * F32(1.13)))

		val04 = F32(SrcEngineMathUtilH.coss(TruncS32(buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oFaceAnglePitch) / 2)) * val04)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosX) + F32(val04 * SrcEngineMathUtilH.sins(buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosZ) + F32(val04 * SrcEngineMathUtilH.coss(buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw))))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == -4 then
			if buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oAnimState) ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 150 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oBhvParams))
				SpawnStarInc.spawn_default_star(6833, -3654, 2230)
				buffer.writei32(Parent.rawData, IncludeObjectFieldsH.oAnimState, 0)
			end
		else
			ObjBehaviors2.obj_check_attacks(unagi_inc.sUnagiHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 3 then
				buffer.writef32(Parent.rawData, IncludeObjectFieldsH.oUnagiUnk1AC, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario))
			end
		end
	end
end

return unagi_inc
