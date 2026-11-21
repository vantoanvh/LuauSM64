--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/mr_i.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SpawnStarInc = require("./spawn_star_inc")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
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

-- from src/game/behaviors/mr_i.inc.c:data
const mr_i_inc = {
	-- from src/game/behaviors/mr_i.inc.c:sMrIHitbox L295-305
	sMrIHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 2,
		numLootCoins = 5,
		radius = 80,
		height = 150,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__mr_i_inc", mr_i_inc)

-- from src/game/behaviors/mr_i.inc.c:bhv_piranha_particle_loop L5-12
function mr_i_inc.bhv_piranha_particle_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0 + F32(20.0 * SrcEngineBehaviorScript.random_float()))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0 + F32(20.0 * SrcEngineBehaviorScript.random_float()))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_piranha_particle_act_0 L14-26
function mr_i_inc.mr_i_piranha_particle_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_scale(3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 20.0)
	ObjectHelpers.cur_obj_update_floor_and_walls()

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) or bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_mist_particles()
	end
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_piranha_particle_act_1 L28-34
function mr_i_inc.mr_i_piranha_particle_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_mark_for_deletion(o)
	for Index = 1, 10 do
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PURPLE_MARBLE, BehaviorIds.bhvPurpleParticle)
	end
end

-- from src/game/behaviors/mr_i.inc.c:bhv_mr_i_particle_loop L41-43
function mr_i_inc.bhv_mr_i_particle_loop()
	ObjectHelpers.cur_obj_call_action_function(mr_i_inc.sMrIParticleActions)
end

-- from src/game/behaviors/mr_i.inc.c:spawn_mr_i_particle L45-55
function mr_i_inc.spawn_mr_i_particle()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp18 = o.header.gfx.scale[2]

	const particle = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PURPLE_MARBLE, BehaviorIds.bhvMrIParticle)
	buffer.writef32(particle.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(particle.rawData, IncludeObjectFieldsH.oPosY) + F32(50.0 * sp18))
	buffer.writef32(particle.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(particle.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 90.0) * sp18))
	buffer.writef32(particle.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(particle.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 90.0) * sp18))

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MRI_SHOOT)
end

-- from src/game/behaviors/mr_i.inc.c:bhv_mr_i_body_loop L57-81
function mr_i_inc.bhv_mr_i_body_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_copy_pos_and_angle(o, parentObj)

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		ObjectHelpers.obj_copy_scale(o, parentObj)
		ObjectHelpers.obj_set_parent_relative_pos(o, 0, 0, S16(TruncS32(F32(o.header.gfx.scale[2] * 100.0))))
		ObjectHelpers.obj_build_transform_from_pos_and_angle(o, 44, 15)
		ObjectHelpers.obj_translate_local(o, 6, 44)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, F32(o.header.gfx.scale[2] * 100.0))
	end

	if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oMrIUnk110) ~= 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, -1)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) == 15 then
			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oMrIUnk110, 0)
		end
	end

	if parentObj.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_act_3 L83-154
function mr_i_inc.mr_i_act_3()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp1C = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then 2.0 else 1.0
	const sp34 = if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk100) < 0 then 0x1000 else -0x1000
	const sp2C = F32((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 1) / 96.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 64 then
		const sp36 = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + F32(sp34 * SrcEngineMathUtilH.coss(F32(0x4000 * sp2C))))))

		if sp36 < 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) >= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_MRI_SPINNING)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, TruncS32((1.0 - SrcEngineMathUtilH.coss(F32(0x4000 * sp2C))) * -0x4000))
		ObjectHelpers.cur_obj_shake_y(4.0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 96 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 64 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_MRI_DEATH)
		end

		const sp30 = F32((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - 63) / 32.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + F32(sp34 * SrcEngineMathUtilH.coss(F32(0x4000 * sp2C))))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, TruncS32((1.0 - SrcEngineMathUtilH.coss(F32(0x4000 * sp2C))) * -0x4000))

		ObjectHelpers.cur_obj_shake_y(TruncS32(F32(F32(1.0 - sp30) * 4.0)))
		const sp20 = F32(SrcEngineMathUtilH.coss(F32(0x4000 * sp30)) * 0.4 + 0.6)
		ObjectHelpers.cur_obj_scale(F32(sp20 * sp1C))
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 104 then
		-- do nothing
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 168 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 104 then
			ObjectHelpers.cur_obj_become_intangible()
			ObjectHelpers.spawn_mist_particles()
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrIScale, sp1C * 0.6)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 100.0)
				SpawnStarInc.spawn_default_star(1370, 2000.0, -320.0)
				ObjectHelpers.obj_mark_for_deletion(o)
			else
				ObjectHelpers.cur_obj_spawn_loot_blue_coin()
			end
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrIScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrIScale) - 0.2 * sp1C)
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrIScale) < 0.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oMrIScale, 0.0)
		end

		ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oMrIScale))
	else
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_act_2 L156-228
function mr_i_inc.mr_i_act_2()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const sp1E = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4, 200)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4, 120)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk100, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 0)
	end

	ObjectHelpers.obj_turn_toward_object(o, gMario, 0x10, 0x800)
	ObjectHelpers.obj_turn_toward_object(o, gMario, 0x0F, 0x400)

	const sp1C = S16(sp1E - S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

	if sp1C == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk100, 0)
	elseif sp1C > 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk100) > 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC) + sp1C)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, 0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk100, 1)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk100) < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC) - sp1C)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, 0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk100, -1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4, 120)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC) > 65536 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4) - 1)
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkF4, 120)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnkFC) < 5000 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk108) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk110, 1)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk108) + 20 then
			mr_i_inc.spawn_mr_i_particle()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk108, TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 50.0) + 50.0)))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) + 1)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk108, TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 50.0) + 50.0)))
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 800.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_act_1 L230-267
function mr_i_inc.mr_i_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const gMario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const sp1E = S16(ObjectHelpers.obj_angle_to_object(o, gMario))
	const sp1C = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), sp1E))
	const sp1A = S16(ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(buffer.readi32(gMario.rawData, IncludeObjectFieldsH.oFaceAngleYaw))))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_become_tangible()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 30)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk108, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 20.0)))
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk108), 1) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, -256)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 256)
		end
	end

	if sp1C < 1024 and sp1A > 0x4000 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 700.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) + 1)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 30)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk108) + 60 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk110, 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk104) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oMrIUnk108) + 80 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk104, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMrIUnk108, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)))
		mr_i_inc.spawn_mr_i_particle()
	end
end

-- from src/game/behaviors/mr_i.inc.c:mr_i_act_0 L269-286
function mr_i_inc.mr_i_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_angle(o, 0, 0, 0)
	ObjectHelpers.cur_obj_scale(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_set_pos_to_home()
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/mr_i.inc.c:bhv_mr_i_loop L307-318
function mr_i_inc.bhv_mr_i_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, mr_i_inc.sMrIHitbox)
	ObjectHelpers.cur_obj_call_action_function(mr_i_inc.sMrIActions)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= 3 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 3000.0 or bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/mr_i.inc.c:sMrIParticleActions L36-39
mr_i_inc.sMrIParticleActions = { mr_i_inc.mr_i_piranha_particle_act_0, mr_i_inc.mr_i_piranha_particle_act_1 }

-- from src/game/behaviors/mr_i.inc.c:sMrIActions L288-293
mr_i_inc.sMrIActions = { mr_i_inc.mr_i_act_0, mr_i_inc.mr_i_act_1, mr_i_inc.mr_i_act_2, mr_i_inc.mr_i_act_3 }

return mr_i_inc
