--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bullet_bill.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const bullet_bill_inc = {}

Registry.Register("src__game__behaviors__bullet_bill_inc", bullet_bill_inc)

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

-- from src/game/behaviors/bullet_bill.inc.c:bhv_white_puff_smoke_init L3-5
function bullet_bill_inc.bhv_white_puff_smoke_init()
	ObjectHelpers.cur_obj_scale(F32(F32(SrcEngineBehaviorScript.random_float() * 2) + 2.0))
end

-- from src/game/behaviors/bullet_bill.inc.c:bhv_bullet_bill_init L7-9
function bullet_bill_inc.bhv_bullet_bill_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBulletBillInitialMoveYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
end

-- from src/game/behaviors/bullet_bill.inc.c:bullet_bill_act_0 L11-20
function bullet_bill_inc.bullet_bill_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_become_tangible()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBulletBillInitialMoveYaw))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
	ObjectHelpers.cur_obj_set_pos_to_home()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
end

-- from src/game/behaviors/bullet_bill.inc.c:bullet_bill_act_1 L22-27
function bullet_bill_inc.bullet_bill_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp1E = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

	if Sp1E < 0x2000 and 400.0 < buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/bullet_bill.inc.c:bullet_bill_act_2 L29-60
function bullet_bill_inc.bullet_bill_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 40 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 50 then
		if math.fmod(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 2) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 3.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -3.0)
		end
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 70 then
			ObjectHelpers.cur_obj_update_floor_and_walls()
		end

		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvWhitePuffSmoke)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 300.0 then
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x100)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 50 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_POUNDING_CANNON)
			ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
			ObjectHelpers.spawn_mist_particles()
		end
	end
end

-- from src/game/behaviors/bullet_bill.inc.c:bullet_bill_act_3 L62-64
function bullet_bill_inc.bullet_bill_act_3()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
end

-- from src/game/behaviors/bullet_bill.inc.c:bullet_bill_act_4 L66-79
function bullet_bill_inc.bullet_bill_act_4()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -30.0)
		ObjectHelpers.cur_obj_become_intangible()
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x1000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x1000))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 20.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/bullet_bill.inc.c:bhv_bullet_bill_loop L89-94
function bullet_bill_inc.bhv_bullet_bill_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_call_action_function(bullet_bill_inc.sBulletBillActions)

	if ObjectHelpers.cur_obj_check_interacted() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	end
end

-- from src/game/behaviors/bullet_bill.inc.c:sBulletBillActions L81-87
bullet_bill_inc.sBulletBillActions = {
	bullet_bill_inc.bullet_bill_act_0,
	bullet_bill_inc.bullet_bill_act_1,
	bullet_bill_inc.bullet_bill_act_2,
	bullet_bill_inc.bullet_bill_act_3,
	bullet_bill_inc.bullet_bill_act_4,
}

return bullet_bill_inc
