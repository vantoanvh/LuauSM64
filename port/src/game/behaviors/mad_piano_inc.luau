--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/mad_piano.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

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

-- from src/game/behaviors/mad_piano.inc.c:data
const mad_piano_inc = {
	-- from src/game/behaviors/mad_piano.inc.c:sMadPianoHitbox L3-13
	sMadPianoHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 99,
		numLootCoins = 0,
		radius = 200,
		height = 150,
		hurtboxRadius = 200,
		hurtboxHeight = 150,
	},
}

Registry.Register("src__game__behaviors__mad_piano_inc", mad_piano_inc)

-- from src/game/behaviors/mad_piano.inc.c:mad_piano_act_wait L15-28
function mad_piano_inc.mad_piano_act_wait()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation_with_sound(0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 and LevelUpdate.gMarioStates[1].forwardVel > 10.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MAD_PIANO_ACT_ATTACK)
			ObjectHelpers.cur_obj_become_tangible()
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(280.0, 150.0)
end

-- from src/game/behaviors/mad_piano.inc.c:mad_piano_act_attack L30-60
function mad_piano_inc.mad_piano_act_attack()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_init_animation_with_sound(1)
	ObjBehaviors2.cur_obj_play_sound_at_anim_range(0, 0, IncludeSoundsH.SOUND_OBJ_MAD_PIANO_CHOMPING)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 80 and ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.MAD_PIANO_ACT_WAIT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		ObjectHelpers.cur_obj_become_intangible()
	else
		const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
		local distToHome = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

		if distToHome > 400.0 then
			distToHome = F32(400.0 / distToHome)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(dx * distToHome))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(dz * distToHome))
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 400)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)
	end

	ObjBehaviors2.obj_check_attacks(mad_piano_inc.sMadPianoHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/mad_piano.inc.c:bhv_mad_piano_update L62-75
function mad_piano_inc.bhv_mad_piano_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 0x4000))

		const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if action == IncludeObjectConstantsH.MAD_PIANO_ACT_WAIT then
			mad_piano_inc.mad_piano_act_wait()
		elseif action == IncludeObjectConstantsH.MAD_PIANO_ACT_ATTACK then
			mad_piano_inc.mad_piano_act_attack()
		end
	end
end

return mad_piano_inc
