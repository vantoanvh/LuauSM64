--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/koopa_shell.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

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

-- from src/game/behaviors/koopa_shell.inc.c:data
const koopa_shell_inc = {
	-- from src/game/behaviors/koopa_shell.inc.c:sKoopaShellHitbox L3-13
	sKoopaShellHitbox = {
		interactType = InteractionH.INTERACT_KOOPA_SHELL,
		downOffset = 0,
		damageOrCoinValue = 4,
		health = 1,
		numLootCoins = 1,
		radius = 50,
		height = 50,
		hurtboxRadius = 50,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__koopa_shell_inc", koopa_shell_inc)

-- from src/game/behaviors/koopa_shell.inc.c:koopa_shell_spawn_water_drop L15-26
function koopa_shell_inc.koopa_shell_spawn_water_drop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WAVE_TRAIL, BehaviorIds.bhvObjectWaveTrail)

	if LevelUpdate.gMarioStates[1].forwardVel > 10.0 then
		const drop = ObjectHelpers.spawn_object_with_scale(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvWaterDroplet, 1.5)

		buffer.writef32(drop.rawData, IncludeObjectFieldsH.oVelY, SrcEngineBehaviorScript.random_float() * 30.0)
		ObjectHelpers.obj_translate_xz_random(drop, 110.0)
	end
end

-- from src/game/behaviors/koopa_shell.inc.c:bhv_koopa_shell_flame_loop L28-47
function koopa_shell_inc.bhv_koopa_shell_flame_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineBehaviorScript.random_float() * 30.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 10.0)))
		ObjectHelpers.obj_translate_xz_random(o, 110.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaShellFlameScale, 4.0)
	end

	ObjectHelpers.cur_obj_update_floor_height()
	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oKoopaShellFlameScale, buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaShellFlameScale) + -0.3)
	ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oKoopaShellFlameScale))
end

-- from src/game/behaviors/koopa_shell.inc.c:bhv_koopa_shell_flame_spawn L49-54
function koopa_shell_inc.bhv_koopa_shell_flame_spawn()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	for i = 0, 1 do
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_RED_FLAME, BehaviorIds.bhvKoopaShellFlame)
	end
end

-- from src/game/behaviors/koopa_shell.inc.c:koopa_shell_spawn_sparkles L56-59
function koopa_shell_inc.koopa_shell_spawn_sparkles(a: number)
	a = F32(a)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp1C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)

	buffer.writef32(sp1C.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(sp1C.rawData, IncludeObjectFieldsH.oPosY) + a)
end

-- from src/game/behaviors/koopa_shell.inc.c:bhv_koopa_shell_loop L61-108
function koopa_shell_inc.bhv_koopa_shell_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, koopa_shell_inc.sKoopaShellHitbox)
	ObjectHelpers.cur_obj_scale(1.0)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		ObjectHelpers.cur_obj_update_floor_and_walls()
		ObjectHelpers.cur_obj_if_hit_wall_bounce_away()

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x1000))
		ObjectHelpers.cur_obj_move_standard(-20)
		koopa_shell_inc.koopa_shell_spawn_sparkles(10.0)
	elseif action == 1 then
		ObjectHelpers.obj_copy_pos(o, marioObj)
		const sp34: GroupsTypesHPlus3.Surface? = ObjectHelpers.cur_obj_update_floor_height_and_get_floor()

		if ObjectHelpers.absf(F32(SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))) < 10.0 then
			koopa_shell_inc.koopa_shell_spawn_water_drop()
		elseif ObjectHelpers.absf(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))) < 5.0 then
			if sp34 ~= nil and sp34.type_ == 1 then
				koopa_shell_inc.bhv_koopa_shell_flame_spawn()
			else
				koopa_shell_inc.koopa_shell_spawn_sparkles(10.0)
			end
		else
			koopa_shell_inc.koopa_shell_spawn_sparkles(10.0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_STOP_RIDING) then
			ObjectHelpers.obj_mark_for_deletion(o)
			ObjectHelpers.spawn_mist_particles()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return koopa_shell_inc
