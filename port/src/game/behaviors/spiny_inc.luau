--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/spiny.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const ObjBehaviors2H = require("../obj_behaviors_2_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/spiny.inc.c:data
const spiny_inc = {
	-- from src/game/behaviors/spiny.inc.c:sSpinyHitbox L12-22
	sSpinyHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 0,
		radius = 80,
		height = 50,
		hurtboxRadius = 40,
		hurtboxHeight = 40,
	},
	-- from src/game/behaviors/spiny.inc.c:sSpinyWalkAttackHandlers L27-34
	sSpinyWalkAttackHandlers = {
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_NOP,
		ObjBehaviors2H.ATTACK_HANDLER_NOP,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
	},
}

Registry.Register("src__game__behaviors__spiny_inc", spiny_inc)

-- from src/game/behaviors/spiny.inc.c:spiny_check_active L39-56
function spiny_inc.spiny_check_active(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if o.parentObj ~= o then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500.0 then
			-- It's possible for the lakitu to despawn while the spiny still
			-- references it. This line allows us to decrement the 0x1B field
			-- in an object that loads into the lakitu's former slot.
			-- This can be used in practice to corrupt a huge goomba to
			-- behave similar to a regular goomba.
			-- It can also be used on a bob-omb respawner to change its model
			-- to a butterfly or fish.
			const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

			buffer.writei32(ParentObj.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies, buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies) - 1)
			ObjectHelpers.obj_mark_for_deletion(o)
			return IncludePRUltratypesH.FALSE
		end
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/behaviors/spiny.inc.c:spiny_act_walk L61-119
function spiny_inc.spiny_act_walk()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if spiny_inc.spiny_check_active() ~= 0 then
		ObjectHelpers.cur_obj_update_floor_and_walls()

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, -17.0)
		ObjectHelpers.cur_obj_init_animation_with_sound(0)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
			-- After touching the ground for the first time, stop. From now on,
			-- ensure that face angle and move angle agree
			if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW) then
				if ObjBehaviors2.obj_forward_vel_approach(0.0, 1.0) ~= 0 then
					buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
				end
			else
				ObjBehaviors2.obj_forward_vel_approach(1.0, 0.2)
			end

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinyTurningAwayFromWall) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinyTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinyTargetYaw)), 0x80))
			else
				const TurningAwayFromWall = ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oSpinyTargetYaw)

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinyTurningAwayFromWall, TurningAwayFromWall)

				if TurningAwayFromWall == 0 then
					-- Walk and occasionally randomly change direction
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinyTimeUntilTurn) ~= 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinyTimeUntilTurn, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinyTimeUntilTurn) - 1)
					else
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinyTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + S16(SrcEngineBehaviorScript.random_sign()) * 0x2000)
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinyTimeUntilTurn, ObjBehaviors2.random_linear_offset(100, 100))
					end
				end

				ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinyTargetYaw)), 0x80)
			end
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			-- Bounce off walls while falling
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
		end

		ObjectHelpers.cur_obj_move_standard(-78)

		if ObjBehaviors2.obj_handle_attacks(spiny_inc.sSpinyHitbox, IncludeObjectConstantsH.SPINY_ACT_ATTACKED_MARIO, spiny_inc.sSpinyWalkAttackHandlers) ~= 0 then
			-- When attacked by mario, lessen the knockback
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SPINY_ACT_WALK)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.1))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) * F32(0.7))

			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0) -- weird flex but okay

			-- Don't allow mario to punch the spiny two frames in a row?
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_MR_BLIZZARD)
		else
			buffer.writeu32(o.rawData, IncludeObjectFieldsH.oInteractType, InteractionH.INTERACT_UNKNOWN_08)
		end
	end
end

-- from src/game/behaviors/spiny.inc.c:spiny_act_held_by_lakitu L125-144
function spiny_inc.spiny_act_held_by_lakitu()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 15.0)
	ObjectHelpers.cur_obj_init_animation_with_sound(0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, -50.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, 35.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, -100.0)

	if ParentObj.prevObj == nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SPINY_ACT_THROWN_BY_LAKITU)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

		-- Move more quickly if the lakitu is moving forward
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(buffer.readf32(ParentObj.rawData, IncludeObjectFieldsH.oForwardVel) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) + 10.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)

		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oMoveFlags, 0) -- you do you, spiny
	end
end

-- from src/game/behaviors/spiny.inc.c:spiny_act_thrown_by_lakitu L149-176
function spiny_inc.spiny_act_thrown_by_lakitu()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if spiny_inc.spiny_check_active() ~= 0 then
		ObjectHelpers.cur_obj_update_floor_and_walls()

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 15.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x2000)

		ObjectHelpers.cur_obj_init_animation_with_sound(0)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SPINY_UNK59)
			ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_SPINY)
			ObjectHelpers.obj_init_animation_with_sound(o, Memory.segmented_to_virtual(0x05016EAC), 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, -17.0)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SPINY_ACT_WALK)
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
		end

		ObjectHelpers.cur_obj_move_standard(-78)

		if ObjBehaviors2.obj_check_attacks(spiny_inc.sSpinyHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)) ~= 0 and o.parentObj ~= o then
			const ParentObj = o.parentObj :: GroupsTypesHPlus3.Object

			buffer.writei32(ParentObj.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies, buffer.readi32(ParentObj.rawData, IncludeObjectFieldsH.oEnemyLakituNumSpinies) - 1)
		end
	end
end

-- from src/game/behaviors/spiny.inc.c:bhv_spiny_update L181-198
function spiny_inc.bhv_spiny_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SPINY_ACT_WALK then
		spiny_inc.spiny_act_walk()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SPINY_ACT_HELD_BY_LAKITU then
		spiny_inc.spiny_act_held_by_lakitu()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SPINY_ACT_THROWN_BY_LAKITU then
		spiny_inc.spiny_act_thrown_by_lakitu()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SPINY_ACT_ATTACKED_MARIO then
		ObjBehaviors2.obj_move_for_one_second(IncludeObjectConstantsH.SPINY_ACT_WALK)
	end
end

return spiny_inc
