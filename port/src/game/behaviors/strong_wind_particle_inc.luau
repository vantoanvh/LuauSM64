--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/strong_wind_particle.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")

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

-- from src/game/behaviors/strong_wind_particle.inc.c:data
const strong_wind_particle_inc = {
	-- from src/game/behaviors/strong_wind_particle.inc.c:sStrongWindParticleHitbox L3-13
	sStrongWindParticleHitbox = {
		interactType = InteractionH.INTERACT_STRONG_WIND,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 20,
		height = 70,
		hurtboxRadius = 20,
		hurtboxHeight = 70,
	},
}

Registry.Register("src__game__behaviors__strong_wind_particle_inc", strong_wind_particle_inc)

-- from src/game/behaviors/strong_wind_particle.inc.c:bhv_strong_wind_particle_loop L15-49
function strong_wind_particle_inc.bhv_strong_wind_particle_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, strong_wind_particle_inc.sStrongWindParticleHitbox)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		o.ptrData[IncludeObjectFieldsH.oStrongWindParticlePenguinObj + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvSLWalkingPenguin)
		ObjectHelpers.obj_translate_xyz_random(o, 100.0)

		const CosPitch: number = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
		const SinPitch: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(CosPitch * 100.0))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SinPitch * -100.0))

		const WindSpread: number = ObjectHelpers.random_f32_around_zero(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 500)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + WindSpread)))) -- Wind spread
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 100)
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then -- Deactivate after 15 frames
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	-- If collided with the SL walking penguin, deactivate.
	const PenguinObj = o.ptrData[IncludeObjectFieldsH.oStrongWindParticlePenguinObj + 1] :: GroupsTypesHPlus3.Object?

	if PenguinObj ~= nil then
		const PenguinXDist = F32(buffer.readf32(PenguinObj.rawData, IncludeObjectFieldsH.oSLWalkingPenguinWindCollisionXPos) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		const PenguinZDist = F32(buffer.readf32(PenguinObj.rawData, IncludeObjectFieldsH.oSLWalkingPenguinWindCollisionZPos) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		const DistanceFromPenguin = F32(math.sqrt(F32(F32(PenguinXDist * PenguinXDist) + F32(PenguinZDist * PenguinZDist))))

		if DistanceFromPenguin < 300.0 then
			ObjectHelpers.obj_mark_for_deletion(o)
			ObjectHelpers.cur_obj_become_intangible()
		end
	end
end

-- from src/game/behaviors/strong_wind_particle.inc.c:cur_obj_spawn_strong_wind_particles L53-67
function strong_wind_particle_inc.cur_obj_spawn_strong_wind_particles(windSpread: number, scale: number, relPosX: number, relPosY: number, relPosZ: number)
	scale = F32(scale)
	relPosX = F32(relPosX)
	relPosY = F32(relPosY)
	relPosZ = F32(relPosZ)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Alternate between tiny particles and regular particles each frame.
	if bit32.btest(GameInit.gGlobalTimer, 1) then
		-- Because the tiny particles are unimportant objects, invisible wind particles are spawned to provide collision.
		ObjectHelpers.spawn_object_relative_with_scale(S16(windSpread), S16(TruncS32(relPosX)), S16(TruncS32(relPosY)), S16(TruncS32(relPosZ)), 0.5, o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_DL, BehaviorIds.bhvTinyStrongWindParticle)
		ObjectHelpers.spawn_object_relative_with_scale(S16(windSpread), S16(TruncS32(relPosX)), S16(TruncS32(relPosY)), S16(TruncS32(relPosZ)), scale, o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvStrongWindParticle)
	else
		ObjectHelpers.spawn_object_relative_with_scale(S16(windSpread), S16(TruncS32(relPosX)), S16(TruncS32(relPosY)), S16(TruncS32(relPosZ)), scale, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvStrongWindParticle)
	end

	-- There is also no need to spawn additional invisible wind particles here.
	ObjectHelpers.spawn_object_relative_with_scale(S16(windSpread), S16(TruncS32(relPosX)), S16(TruncS32(relPosY)), S16(TruncS32(relPosZ)), scale, o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvStrongWindParticle)
end

return strong_wind_particle_inc
