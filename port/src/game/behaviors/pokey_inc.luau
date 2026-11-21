--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/pokey.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const ObjBehaviors2H = require("../obj_behaviors_2_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
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

-- from src/game/behaviors/pokey.inc.c:data
const pokey_inc = {
	-- from src/game/behaviors/pokey.inc.c:sPokeyBodyPartHitbox L13-23
	sPokeyBodyPartHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 10,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 0,
		radius = 40,
		height = 20,
		hurtboxRadius = 20,
		hurtboxHeight = 20,
	},
	-- from src/game/behaviors/pokey.inc.c:sPokeyBodyPartAttackHandlers L28-35
	sPokeyBodyPartAttackHandlers = {
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
		ObjBehaviors2H.ATTACK_HANDLER_SQUISHED,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
	},
}

Registry.Register("src__game__behaviors__pokey_inc", pokey_inc)

-- from src/game/behaviors/pokey.inc.c:bhv_pokey_body_part_update L42-143
function pokey_inc.bhv_pokey_body_part_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const parentObj = o.parentObj :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.obj_update_standard_actions(3.0) ~= 0 then
		if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.POKEY_ACT_UNLOAD_PARTS then
			ObjectHelpers.obj_mark_for_deletion(o)
		else
			ObjectHelpers.cur_obj_update_floor_and_walls()
			ObjBehaviors2.obj_update_blinking(o.rawData, IncludeObjectFieldsH.oPokeyBodyPartBlinkTimer, 30, 60, 4)

			-- If the body part above us is dead, then decrease body part index
			-- by one, since new parts are spawned from the bottom.
			-- Set the bottom body part size, and gradually increase it.
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) > 1 and not bit32.btest(buffer.readu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags), bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) - 1)) then
				buffer.writeu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags, bit32.bor(buffer.readu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags), bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) - 1)))
				buffer.writeu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags, bit32.band(buffer.readu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags), bit32.bnot(bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) - 1)
			elseif buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize) < 1.0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1 == buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) then
				ObjBehaviors2.approach_f32_ptr(parentObj.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize, 1.0, F32(0.1))
				ObjectHelpers.cur_obj_scale(F32(buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize) * 3.0))
			end

			const offsetAngle = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 0x4000 + GameInit.gGlobalTimer * 0x800)

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.coss(offsetAngle) * 6.0))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.sins(offsetAngle) * 6.0))

			-- This is the height of the tower beneath the body part
			const baseHeight = F32(F32(buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPosY) + (120 * (buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)) - 240)) + F32(120.0 * buffer.readf32(parentObj.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize)))

			-- We treat the base height as a minimum height, allowing the body
			-- part to briefly stay in the air after a part below it dies
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < baseHeight then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, baseHeight)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
			end

			-- Only the head has loot coins
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 1)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, 0)
			end

			-- If the body part was attacked, then die. If the head was killed,
			-- then die after a delay.
			if ObjBehaviors2.obj_handle_attacks(pokey_inc.sPokeyBodyPartHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction), pokey_inc.sPokeyBodyPartAttackHandlers) ~= 0 then
				buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) - 1)

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
					buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oPokeyHeadWasKilled, IncludePRUltratypesH.TRUE)
					-- Last minute change to blue coins, not sure why they did not
					-- just set it to -1 above
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oNumLootCoins, -1)
				end

				buffer.writeu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags, bit32.band(buffer.readu32(parentObj.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags), bit32.bnot(bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))))
			elseif buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPokeyHeadWasKilled) ~= 0 then
				ObjectHelpers.cur_obj_become_intangible()

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyBodyPartDeathDelayAfterHeadKilled, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyBodyPartDeathDelayAfterHeadKilled) - 1)

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyBodyPartDeathDelayAfterHeadKilled) < 0 then
					buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) - 1)
					ObjBehaviors2.obj_die_if_health_non_positive()
				end
			else
				-- Die in order from top to bottom
				-- If a new body part spawns after the head has been killed, its
				-- death delay will be 0
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyBodyPartDeathDelayAfterHeadKilled, bit32.lshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), 2) + 20)
			end

			ObjectHelpers.cur_obj_move_standard(-78)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, F32(o.header.gfx.scale[2] * 22.0))
end

-- from src/game/behaviors/pokey.inc.c:pokey_act_uninitialized L149-174
function pokey_inc.pokey_act_uninitialized()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 then
		local partModel = IncludeModelIdsH.MODEL_POKEY_HEAD

		for i = 0, 4 do
			-- Spawn body parts at y offsets 480, 360, 240, 120, 0
			-- behavior param 0 = head, 4 = lowest body part
			const bodyPart = ObjectHelpers.spawn_object_relative(i, 0, -i * 120 + 480, 0, o, partModel, BehaviorIds.bhvPokeyBodyPart)

			if bodyPart ~= nil then
				ObjectHelpers.obj_scale(bodyPart, 3.0)
			end

			partModel = IncludeModelIdsH.MODEL_POKEY_BODY_PART
		end

		buffer.writeu32(o.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags, 0x1F)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts, 5)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize, 1.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.POKEY_ACT_WANDER)
	end
end

-- from src/game/behaviors/pokey.inc.c:pokey_act_wander L182-275
function pokey_inc.pokey_act_wander()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) == 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.POKEY_ACT_UNLOAD_PARTS)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	else
		ObjBehaviors2.treat_far_home_as_mario(1000.0)
		ObjectHelpers.cur_obj_update_floor_and_walls()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyHeadWasKilled) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 5.0)

			-- If a body part is missing, replenish it after 100 frames
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) < 5 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
					-- Because the body parts shift index whenever a body part
					-- is killed, the index of the new part is equal to the number
					-- of living body parts
					const bodyPart = ObjectHelpers.spawn_object_relative(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts), 0, 0, 0, o, IncludeModelIdsH.MODEL_POKEY_BODY_PART, BehaviorIds.bhvPokeyBodyPart)

					if bodyPart ~= nil then
						buffer.writeu32(o.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags, bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oPokeyAliveBodyPartFlags), bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts))))
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyNumAliveBodyParts) + 1)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oPokeyBottomBodyPartSize, 0.0)

						ObjectHelpers.obj_scale(bodyPart, 0.0)
					end

					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyTurningAwayFromWall) ~= 0 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyTurningAwayFromWall, ObjBehaviors2.obj_resolve_collisions_and_turn(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw)), 0x200))
			else
				-- If far from home, turn back toward home
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000.0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
				end

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyTurningAwayFromWall, ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw))

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyTurningAwayFromWall) == 0 then
					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyChangeTargetTimer) ~= 0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyChangeTargetTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyChangeTargetTimer) - 1)
					elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2000.0 then
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw, ObjBehaviors2.obj_random_fixed_turn(0x2000))
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyChangeTargetTimer, ObjBehaviors2.random_linear_offset(30, 50))
					else
						-- The goal of this computation is to make pokey approach
						-- mario directly if he is far away, but to shy away from
						-- him when he is nearby

						-- targetAngleOffset is 0 when distance to mario is >= 1838.4
						-- and 0x4000 when distance to mario is <= 200
						local targetAngleOffset = TruncS32(F32(0x4000 - F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) - 200.0) * 10.0)))

						if targetAngleOffset < 0 then
							targetAngleOffset = 0
						elseif targetAngleOffset > 0x4000 then
							targetAngleOffset = 0x4000
						end

						-- If we need to rotate CCW to get to mario, then negate
						-- the target angle offset
						if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) > 0 then
							targetAngleOffset = -targetAngleOffset
						end

						-- When mario is far, targetAngleOffset is 0, so he moves
						-- toward him directly. When mario is close,
						-- targetAngleOffset is 0x4000, so he turns 90 degrees
						-- away from mario
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + targetAngleOffset)
					end
				end

				ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPokeyTargetYaw)), 0x200)
			end
		end

		ObjectHelpers.cur_obj_move_standard(-78)
	end
end

-- from src/game/behaviors/pokey.inc.c:pokey_act_unload_parts L282-285
function pokey_inc.pokey_act_unload_parts()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.POKEY_ACT_UNINITIALIZED)
	ObjectHelpers.cur_obj_set_pos_to_home()
end

-- from src/game/behaviors/pokey.inc.c:bhv_pokey_update L290-306
function pokey_inc.bhv_pokey_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_POKEY_DEATH)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.POKEY_ACT_UNINITIALIZED then
		pokey_inc.pokey_act_uninitialized()
	elseif action == IncludeObjectConstantsH.POKEY_ACT_WANDER then
		pokey_inc.pokey_act_wander()
	elseif action == IncludeObjectConstantsH.POKEY_ACT_UNLOAD_PARTS then
		pokey_inc.pokey_act_unload_parts()
	end
end

return pokey_inc
