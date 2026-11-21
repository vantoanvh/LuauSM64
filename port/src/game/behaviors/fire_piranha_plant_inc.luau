--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/fire_piranha_plant.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnStarInc = require("./spawn_star_inc")

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end


-- from src/game/behaviors/fire_piranha_plant.inc.c:data
const fire_piranha_plant_inc = {
	-- from src/game/behaviors/fire_piranha_plant.inc.c:sFirePiranhaPlantHitbox L3-13
	sFirePiranhaPlantHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 1,
		radius = 80,
		height = 160,
		hurtboxRadius = 50,
		hurtboxHeight = 150,
	},
	-- from src/game/behaviors/fire_piranha_plant.inc.c:D_80331B5C L15-18
	D_80331B5C = { 0.5, 2.0 },
	-- from src/game/behaviors/fire_piranha_plant.inc.c:sPiranhaPlantFireHitbox L20-30
	sPiranhaPlantFireHitbox = {
		interactType = InteractionH.INTERACT_FLAME,
		downOffset = 10,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 10,
		height = 20,
		hurtboxRadius = 10,
		hurtboxHeight = 20,
	},
	-- from src/game/behaviors/fire_piranha_plant.inc.c:sNumActiveFirePiranhaPlants L32-32
	sNumActiveFirePiranhaPlants = 0,
	-- from src/game/behaviors/fire_piranha_plant.inc.c:sNumKilledFirePiranhaPlants L33-33
	sNumKilledFirePiranhaPlants = 0,
}

Registry.Register("src__game__behaviors__fire_piranha_plant_inc", fire_piranha_plant_inc)

-- from src/game/behaviors/fire_piranha_plant.inc.c:bhv_fire_piranha_plant_init L35-51
function fire_piranha_plant_inc.bhv_fire_piranha_plant_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantNeutralScale, fire_piranha_plant_inc.D_80331B5C[U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)) + 1])
	ObjectHelpers.obj_set_hitbox(o, fire_piranha_plant_inc.sFirePiranhaPlantHitbox)

	if U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)) ~= 0 then
		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_PERSISTENT_RESPAWN)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 1)

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 0x0000FF00) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 2)
		end
	end

	fire_piranha_plant_inc.sNumActiveFirePiranhaPlants = 0
	fire_piranha_plant_inc.sNumKilledFirePiranhaPlants = 0
end

-- from src/game/behaviors/fire_piranha_plant.inc.c:fire_piranha_plant_act_hide L53-94
function fire_piranha_plant_inc.fire_piranha_plant_act_hide()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinTimer) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinVel)))
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinVel, 0, 200)

		if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinTimer) - 1)
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinTimer) == 0 then
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_ENEMY_DEFEAT_SHRINK)
			end
		end
	else
		const Reached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantScale, 0, F32(F32(0.04) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantNeutralScale)))

		if Reached ~= 0 then
			ObjectHelpers.cur_obj_become_intangible()

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantActive) ~= 0 then
				fire_piranha_plant_inc.sNumActiveFirePiranhaPlants -= 1
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantActive, IncludePRUltratypesH.FALSE)

				if U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 0 then
					fire_piranha_plant_inc.sNumKilledFirePiranhaPlants += 1
					if fire_piranha_plant_inc.sNumKilledFirePiranhaPlants == 5 then
						SpawnStarInc.spawn_default_star(-6300, -1850, -6300)
					end

					ObjBehaviors2.obj_die_if_health_non_positive()
					ObjectListProcessor.set_object_respawn_info_bits(o, 1)
				end
			elseif fire_piranha_plant_inc.sNumActiveFirePiranhaPlants < 2 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 100 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 800 then
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_PIRANHA_PLANT_APPEAR)

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantActive, IncludePRUltratypesH.TRUE)
				fire_piranha_plant_inc.sNumActiveFirePiranhaPlants += 1

				ObjectHelpers.cur_obj_unhide()
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FIRE_PIRANHA_PLANT_ACT_GROW)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			else
				ObjectHelpers.cur_obj_hide()
			end
		end
	end

	ObjectHelpers.cur_obj_extend_animation_if_at_end()
end

-- from src/game/behaviors/fire_piranha_plant.inc.c:fire_piranha_plant_act_grow L96-117
function fire_piranha_plant_inc.fire_piranha_plant_act_grow()
	const o = ObjectListProcessor.gCurrentObject

	ObjBehaviors2.cur_obj_init_anim_extend(4)

	const neutralScale = buffer.readf32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantNeutralScale)
	const Reached: number = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantScale, neutralScale, F32(F32(0.04) * neutralScale))

	if Reached ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 80 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_PIRANHA_PLANT_SHRINK)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FIRE_PIRANHA_PLANT_ACT_HIDE)
			ObjectHelpers.cur_obj_init_animation_with_sound(0)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 50 then
			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)
		elseif ObjBehaviors2.obj_is_rendering_enabled() ~= 0 and ObjectHelpers.cur_obj_check_anim_frame(56) ~= 0 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_FLAME_BLOWN)
			ObjBehaviors2.obj_spit_fire(0, S16(TruncS32(F32(30 * neutralScale))), S16(TruncS32(F32(140 * neutralScale))), F32(F32(2.5) * neutralScale), IncludeModelIdsH.MODEL_RED_FLAME_SHADOW, 20, 15, 0x1000)
		end
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantScale) > F32(neutralScale / 2) then
		ObjectHelpers.cur_obj_become_tangible()
	end
end

-- from src/game/behaviors/fire_piranha_plant.inc.c:bhv_fire_piranha_plant_update L119-146
function fire_piranha_plant_inc.bhv_fire_piranha_plant_update()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantScale))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FIRE_PIRANHA_PLANT_ACT_HIDE then
		fire_piranha_plant_inc.fire_piranha_plant_act_hide()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FIRE_PIRANHA_PLANT_ACT_GROW then
		fire_piranha_plant_inc.fire_piranha_plant_act_grow()
	end

	if ObjBehaviors2.obj_check_attacks(fire_piranha_plant_inc.sFirePiranhaPlantHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) < 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantActive) ~= 0 then
				fire_piranha_plant_inc.sNumActiveFirePiranhaPlants -= 1
			end
		else
			ObjectHelpers.cur_obj_init_animation_with_sound(2)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FIRE_PIRANHA_PLANT_ACT_HIDE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinTimer, 10)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFirePiranhaPlantDeathSpinVel, 8000)

		ObjectHelpers.cur_obj_become_intangible()
	end
end

return fire_piranha_plant_inc
