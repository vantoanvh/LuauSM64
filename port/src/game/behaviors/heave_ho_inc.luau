--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/heave_ho.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

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

-- from src/game/behaviors/heave_ho.inc.c:data
const heave_ho_inc = {
	-- from src/game/behaviors/heave_ho.inc.c:D_8032F460 L3-6
	D_8032F460 = {
		{ 30, 0 },
		{ 42, 1 },
		{ 52, 0 },
		{ 64, 1 },
		{ 74, 0 },
		{ 86, 1 },
		{ 96, 0 },
		{ 108, 1 },
		{ 118, 0 },
		{ -1, 0 },
	},
}

Registry.Register("src__game__behaviors__heave_ho_inc", heave_ho_inc)

-- from src/game/behaviors/heave_ho.inc.c:bhv_heave_ho_throw_mario_loop L8-28
function heave_ho_inc.bhv_heave_ho_throw_mario_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, 200.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, -50.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, 0.0)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	const heaveHoUnk88 = buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oHeaveHoUnk88)

	if heaveHoUnk88 == 0 then
		-- Nothing to do.
	elseif heaveHoUnk88 == 1 then
		-- Nothing to do.
	elseif heaveHoUnk88 == 2 then
		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_HEAVEHO_TOSSED)
		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK2)))
		LevelUpdate.gMarioStates[1].forwardVel = -45.0
		LevelUpdate.gMarioStates[1].vel[2] = 95.0
		buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oHeaveHoUnk88, 0)
	end
end

-- from src/game/behaviors/heave_ho.inc.c:heave_ho_act_1 L30-49
function heave_ho_inc.heave_ho_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local sp1C = 0

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	ObjectHelpers.cur_obj_reverse_animation()

	while true do
		if heave_ho_inc.D_8032F460[sp1C + 1][1] == -1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			break
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < heave_ho_inc.D_8032F460[sp1C + 1][1] then
			ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(2, heave_ho_inc.D_8032F460[sp1C + 1][2])
			break
		end

		sp1C += 1
	end
end

-- from src/game/behaviors/heave_ho.inc.c:heave_ho_act_2 L51-74
function heave_ho_inc.heave_ho_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 1000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4, (302 - buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)) / 152.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4) < 0.1 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4, 0.1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4, 1.0)
	end

	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4) * 10.0)

	const angleVel = S16(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnkF4) * 0x400)))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), angleVel))
end

-- from src/game/behaviors/heave_ho.inc.c:heave_ho_act_3 L76-91
function heave_ho_inc.heave_ho_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnk88, 2)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 1 then
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(1, 1.0)
		o.numCollidedObjs = 20
	end

	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/heave_ho.inc.c:heave_ho_act_0 L93-104
function heave_ho_inc.heave_ho_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_set_pos_to_home()

	if SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 4000.0 then
		ObjectHelpers.cur_obj_become_tangible()
		ObjectHelpers.cur_obj_unhide()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	else
		ObjectHelpers.cur_obj_become_intangible()
		ObjectHelpers.cur_obj_hide()
	end
end

-- from src/game/behaviors/heave_ho.inc.c:heave_ho_move L113-137
function heave_ho_inc.heave_ho_move()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_call_action_function(heave_ho_inc.sHeaveHoActions)
	ObjectHelpers.cur_obj_move_standard(-78)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, -15.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 0.0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 3.0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_HEAVEHO_MOVE)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= 0 and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_GRABBED_MARIO) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHeaveHoUnk88, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end
end

-- from src/game/behaviors/heave_ho.inc.c:bhv_heave_ho_loop L139-158
function heave_ho_inc.bhv_heave_ho_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	ObjectHelpers.cur_obj_scale(2.0)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		heave_ho_inc.heave_ho_move()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(0, 0)
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		ObjectHelpers.cur_obj_get_dropped()
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_dropped()
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/heave_ho.inc.c:sHeaveHoActions L106-111
heave_ho_inc.sHeaveHoActions = {
	heave_ho_inc.heave_ho_act_0,
	heave_ho_inc.heave_ho_act_1,
	heave_ho_inc.heave_ho_act_2,
	heave_ho_inc.heave_ho_act_3,
}

return heave_ho_inc
