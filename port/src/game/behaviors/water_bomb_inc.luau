--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_bomb.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const Camera = require("../camera")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/water_bomb.inc.c:data
const water_bomb_inc = {
	-- from src/game/behaviors/water_bomb.inc.c:sWaterBombHitbox L15-25
	sWaterBombHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 25,
		damageOrCoinValue = 1,
		health = 99,
		numLootCoins = 0,
		radius = 80,
		height = 50,
		hurtboxRadius = 60,
		hurtboxHeight = 50,
	},
	-- from src/game/behaviors/water_bomb.inc.c:waterBombExplodeParticles L70-83
	waterBombExplodeParticles = {
		bhvParam = 0,
		count = 5,
		model = IncludeModelIdsH.MODEL_BUBBLE,
		offsetY = 20,
		forwardVelBase = 20,
		forwardVelRange = 60,
		velYBase = 10,
		velYRange = 10,
		gravity = -2,
		dragStrength = 0,
		sizeBase = 35.0,
		sizeRange = 10.0,
	},
	-- from src/game/behaviors/water_bomb.inc.c:waterBombCannonParticle L178-191
	waterBombCannonParticle = {
		bhvParam = 0,
		count = 1,
		model = IncludeModelIdsH.MODEL_BUBBLE,
		offsetY = -20,
		forwardVelBase = 20,
		forwardVelRange = 5,
		velYBase = 0,
		velYRange = 0,
		gravity = -2,
		dragStrength = 0,
		sizeBase = 20.0,
		sizeRange = 5.0,
	},
}

Registry.Register("src__game__behaviors__water_bomb_inc", water_bomb_inc)

-- from src/game/behaviors/water_bomb.inc.c:bhv_water_bomb_spawner_update L31-64
function water_bomb_inc.bhv_water_bomb_spawner_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const SpawnerRadius = F32(50 * U16(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 16)) + 200)
	const LatDistToMario = ObjectHelpers.lateral_dist_between_objects(o, MarioObject)

	-- When mario is in range and a water bomb isn't already active
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerBombActive) == 0 and LatDistToMario < SpawnerRadius and F32(buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) < 1000 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerTimeToSpawn) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerTimeToSpawn, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerTimeToSpawn) - 1))
		else
			const WaterBomb = ObjectHelpers.spawn_object_relative(0, 0, 2000, 0, o, IncludeModelIdsH.MODEL_WATER_BOMB, BehaviorIds.bhvWaterBomb)

			if WaterBomb ~= nil then
				-- Drop farther ahead of mario when he is moving faster
				const WaterBombDistToMario = F32(F32(28 * LevelUpdate.gMarioStates[1].forwardVel) + 100)

				buffer.writei32(WaterBomb.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_BOMB_ACT_INIT)
				buffer.writef32(WaterBomb.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX) + F32(WaterBombDistToMario * SrcEngineMathUtilH.sins(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))
				buffer.writef32(WaterBomb.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ) + F32(WaterBombDistToMario * SrcEngineMathUtilH.coss(buffer.readi32(MarioObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))

				ObjectHelpers.spawn_object(WaterBomb, IncludeModelIdsH.MODEL_WATER_BOMB_SHADOW, BehaviorIds.bhvWaterBombShadow)

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerBombActive, IncludePRUltratypesH.TRUE)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterBombSpawnerTimeToSpawn, ObjBehaviors2.random_linear_offset(0, 50))
			end
		end
	end
end

-- from src/game/behaviors/water_bomb.inc.c:water_bomb_spawn_explode_particles L69-90
function water_bomb_inc.water_bomb_spawn_explode_particles(offsetY: number, forwardVelRange: number, velYBase: number)
	offsetY = S8(TruncS32(offsetY))
	forwardVelRange = S8(TruncS32(forwardVelRange))
	velYBase = S8(TruncS32(velYBase))
	water_bomb_inc.waterBombExplodeParticles.offsetY = offsetY
	water_bomb_inc.waterBombExplodeParticles.forwardVelRange = forwardVelRange
	water_bomb_inc.waterBombExplodeParticles.velYBase = velYBase

	ObjectHelpers.cur_obj_spawn_particles(water_bomb_inc.waterBombExplodeParticles)
end

-- from src/game/behaviors/water_bomb.inc.c:water_bomb_act_init L95-101
function water_bomb_inc.water_bomb_act_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SOMETHING_LANDING)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_BOMB_ACT_DROP)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -40)
end

-- from src/game/behaviors/water_bomb.inc.c:water_bomb_act_drop L107-162
function water_bomb_inc.water_bomb_act_drop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, water_bomb_inc.sWaterBombHitbox)

	-- Explode if touched or if hit water
	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ENTERED_WATER) then
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_DIVING_IN_WATER)
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_BOMB_ACT_EXPLODE)
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		-- On impact with the ground, begin getting squished
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterBombOnGround) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterBombOnGround, IncludePRUltratypesH.TRUE)

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterBombNumBounces, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombNumBounces) + 1.0)

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombNumBounces) < 3.0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_WATER_BOMB_BOUNCING)
			else
				SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_OBJ_DIVING_IN_WATER)
			end

			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

			-- Move toward mario
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterBombStretchSpeed, -40.0)
		end

		-- Make less of an attempt to unsquish on each bounce
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterBombStretchSpeed, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombStretchSpeed) + F32(15.0 - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombNumBounces) * F32(2.8))))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombStretchSpeed) * F32(0.01)))

		-- After being too squished, explode
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch) < F32(-0.8) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WATER_BOMB_ACT_EXPLODE)
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch) > F32(0.1) then
			-- Begin bounce trajectory
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(1.8) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombStretchSpeed))
		end
	else
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch, 0.0, F32(0.008))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterBombOnGround, IncludePRUltratypesH.FALSE)
	end

	o.header.gfx.scale[2] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch) + 1.0)

	local stretch: number = buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombVerticalStretch)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWaterBombNumBounces) == 3.0 then
		stretch = F32(stretch * 4.0)
	end

	o.header.gfx.scale[3] = F32(1.0 - stretch)
	o.header.gfx.scale[1] = o.header.gfx.scale[3]

	ObjectHelpers.cur_obj_move_standard(78)
end

-- from src/game/behaviors/water_bomb.inc.c:water_bomb_act_explode L168-172
function water_bomb_inc.water_bomb_act_explode()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Parent = o.parentObj :: GroupsTypesHPlus3.Object

	water_bomb_inc.water_bomb_spawn_explode_particles(25, 60, 10)

	buffer.writei32(Parent.rawData, IncludeObjectFieldsH.oWaterBombSpawnerBombActive, IncludePRUltratypesH.FALSE)
	ObjectHelpers.obj_mark_for_deletion(o)
end

-- from src/game/behaviors/water_bomb.inc.c:water_bomb_act_shot_from_cannon L177-210
function water_bomb_inc.water_bomb_act_shot_from_cannon()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	if Timer > 100 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		if Timer < 7 then
			if Timer == 1 then
				water_bomb_inc.water_bomb_spawn_explode_particles(-20, 10, 30)
			end

			ObjectHelpers.cur_obj_spawn_particles(water_bomb_inc.waterBombCannonParticle)
		end

		if o.header.gfx.scale[2] > F32(1.2) then
			o.header.gfx.scale[2] = F32(o.header.gfx.scale[2] - F32(0.1))
		end

		const Scale = F32(2 - o.header.gfx.scale[2])

		o.header.gfx.scale[1] = Scale
		o.header.gfx.scale[3] = Scale
		ObjectHelpers.cur_obj_set_pos_via_transform()
	end
end

-- from src/game/behaviors/water_bomb.inc.c:bhv_water_bomb_update L215-234
function water_bomb_inc.bhv_water_bomb_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WATER_BOMB_ACT_SHOT_FROM_CANNON then
		water_bomb_inc.water_bomb_act_shot_from_cannon()
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, F32(40 * o.header.gfx.scale[2]))
		ObjectHelpers.cur_obj_update_floor_and_walls()

		const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

		if Action == IncludeObjectConstantsH.WATER_BOMB_ACT_INIT then
			water_bomb_inc.water_bomb_act_init()
		elseif Action == IncludeObjectConstantsH.WATER_BOMB_ACT_DROP then
			water_bomb_inc.water_bomb_act_drop()
		elseif Action == IncludeObjectConstantsH.WATER_BOMB_ACT_EXPLODE then
			water_bomb_inc.water_bomb_act_explode()
		end
	end
end

-- from src/game/behaviors/water_bomb.inc.c:bhv_water_bomb_shadow_update L240-254
function water_bomb_inc.bhv_water_bomb_shadow_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WATER_BOMB_ACT_EXPLODE then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		local BombHeight = F32(buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oFloorHeight))

		if BombHeight > 500 then
			BombHeight = 500
		end

		ObjectHelpers.obj_copy_pos(o, Parent)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oFloorHeight) + BombHeight)
		ObjectHelpers.obj_copy_scale(o, Parent)
	end
end

return water_bomb_inc
