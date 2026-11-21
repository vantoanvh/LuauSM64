--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/spindrift.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const ChuckyaInc = require("./chuckya_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/spindrift_inc.luau:scratch
const Scratch = {
	bhv_spindrift_loop_oForwardVel = { 0 },
}

-- from src/game/behaviors/spindrift.inc.c:data
const spindrift_inc = {
	-- from src/game/behaviors/spindrift.inc.c:sSpindriftHitbox L3-13
	sSpindriftHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 1,
		numLootCoins = 3,
		radius = 90,
		height = 80,
		hurtboxRadius = 80,
		hurtboxHeight = 70,
	},
}

Registry.Register("src__game__behaviors__spindrift_inc", spindrift_inc)

-- from src/game/behaviors/spindrift.inc.c:bhv_spindrift_loop L15-46
function spindrift_inc.bhv_spindrift_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK10))

	if ObjectHelpers.cur_obj_set_hitbox_and_die_if_attacked(spindrift_inc.sSpindriftHitbox, IncludeSoundsH.SOUND_OBJ_DYING_ENEMY1, 0) ~= 0 then
		ObjectHelpers.cur_obj_change_action(1)
	end

	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		Scratch.bhv_spindrift_loop_oForwardVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
		ChuckyaInc.approach_forward_vel(Scratch.bhv_spindrift_loop_oForwardVel, 4.0, 1.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, Scratch.bhv_spindrift_loop_oForwardVel[1])

		if ObjectHelpers.cur_obj_lateral_dist_from_mario_to_home() > 1000.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.cur_obj_angle_to_home())
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 300.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleToMario, ObjectHelpers.obj_angle_to_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object))
		end

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -10.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))
		end
	end

	ObjectHelpers.cur_obj_move_standard(-60)
end

return spindrift_inc
