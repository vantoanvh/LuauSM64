--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/snufit.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const RenderingGraphNode = require("../rendering_graph_node")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/game/behaviors/snufit.inc.c:data
const snufit_inc = {
	-- from src/game/behaviors/snufit.inc.c:sSnufitHitbox L9-19
	sSnufitHitbox = {
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 2,
		radius = 100,
		height = 60,
		hurtboxRadius = 70,
		hurtboxHeight = 50,
	},
	-- from src/game/behaviors/snufit.inc.c:sSnufitBulletHitbox L21-31
	sSnufitBulletHitbox = {
		interactType = InteractionH.INTERACT_SNUFIT_BULLET,
		downOffset = 50,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 100,
		height = 50,
		hurtboxRadius = 100,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__snufit_inc", snufit_inc)

-- from src/game/behaviors/snufit.inc.c:geo_snufit_move_mask L37-49
function snufit_inc.geo_snufit_move_mask(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const transNode = node.next :: GroupsTypesHPlus3.GraphNodeTranslationRotation

		transNode.translation[1] = buffer.readi16(obj.rawData, IncludeObjectFieldsH.oSnufitXOffset)
		transNode.translation[2] = buffer.readi16(obj.rawData, IncludeObjectFieldsH.oSnufitYOffset)
		transNode.translation[3] = buffer.readi16(obj.rawData, IncludeObjectFieldsH.oSnufitZOffset)
	end

	return nil
end

-- from src/game/behaviors/snufit.inc.c:geo_snufit_scale_body L54-63
function snufit_inc.geo_snufit_scale_body(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { { number } } }): { unknown }?
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const scaleNode = node.next :: GroupsTypesHPlus3.GraphNodeScale

		scaleNode.scale = F32(buffer.readi16(obj.rawData, IncludeObjectFieldsH.oSnufitBodyScale) / 1000.0)
	end

	return nil
end

-- from src/game/behaviors/snufit.inc.c:snufit_act_idle L69-89
function snufit_inc.snufit_act_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const marioDist = S32(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) / 10.0)))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > marioDist and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 800.0 then
		-- Controls an alternating scaling factor in a cos.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod)), 0, 1500))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale)), 600, 15))

		if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod)) == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale) == 600 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SNUFIT_ACT_SHOOT)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBullets, 0)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitCircularPeriod, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitCircularPeriod) + 400)
	end
end

-- from src/game/behaviors/snufit.inc.c:snufit_act_shoot L94-109
function snufit_inc.snufit_act_shoot()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod)), -0x8000, 3000))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale)), 167, 20))

	if U16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod)) == 0x8000 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale) == 167 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SNUFIT_ACT_IDLE)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBullets) < 3 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitBullets, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBullets) + 1)
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_SNUFIT_SHOOT)
		ObjectHelpers.spawn_object_relative(0, 0, -20, 40, o, IncludeModelIdsH.MODEL_BOWLING_BALL, BehaviorIds.bhvSnufitBalls)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSnufitRecoil, -30)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/snufit.inc.c:bhv_snufit_loop L115-170
function snufit_inc.bhv_snufit_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Only update if Mario is in the current room.
	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, IncludeSoundsH.SOUND_OBJ_SNUFIT_SKEETER_DEATH)

		-- Face Mario if he is within range.
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 800.0 then
			ObjBehaviors2.obj_turn_pitch_toward_mario(120.0, 2000)

			if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) > 0x2000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x2000)
			elseif S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)) < -0x2000 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, -0x2000)
			end

			ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 2000)
		else
			ObjBehaviors2.obj_move_pitch_approach(0, 0x200)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 200)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SNUFIT_ACT_IDLE then
			snufit_inc.snufit_act_idle()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SNUFIT_ACT_SHOOT then
			snufit_inc.snufit_act_shoot()
		end

		-- Snufit orbits in a circular motion depending on an internal timer
		-- and vertically off the global timer. The vertical position can be
		-- manipulated using pauses since it uses the global timer.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(100.0 * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitCircularPeriod))))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(8.0 * SrcEngineMathUtilH.coss(4000 * GameInit.gGlobalTimer)))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(100.0 * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitCircularPeriod))))

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oSnufitYOffset, -0x20)
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oSnufitZOffset, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitRecoil) + 180))
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oSnufitBodyScale, S16(TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale) + 666) + F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyBaseScale) * SrcEngineMathUtilH.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSnufitBodyScalePeriod))))))))

		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oSnufitBodyScale) > 1000 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oSnufitScale, F32((buffer.readi16(o.rawData, IncludeObjectFieldsH.oSnufitBodyScale) - 1000) / 1000.0) + 1.0)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oSnufitBodyScale, 1000)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oSnufitScale, 1.0)
		end

		ObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oSnufitScale))
		ObjBehaviors2.obj_check_attacks(snufit_inc.sSnufitHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	end
end

-- from src/game/behaviors/snufit.inc.c:bhv_snufit_balls_loop L175-210
function snufit_inc.bhv_snufit_balls_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- If far from Mario or in a different room, despawn.
	if bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) or (buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) ~= 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1500.0) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	-- Gravity =/= 0 after it has hit Mario while metal.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity) == 0.0 then
		ObjectHelpers.cur_obj_update_floor_and_walls()

		ObjBehaviors2.obj_compute_vel_from_move_pitch(40.0)

		if ObjBehaviors2.obj_check_attacks(snufit_inc.sSnufitBulletHitbox, 1) ~= 0 then
			-- We hit Mario while he is metal!
			-- Bounce off, and fall until the first check is true.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.05))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)

			ObjectHelpers.cur_obj_become_intangible()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND, IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL)) then
			-- The Snufit shot Mario and has fulfilled its lonely existance.
			-- The above check could theoretically be avoided by finding a geometric
			-- situation that does not trigger those flags (Water?). If found,
			-- this would be a route to hang the game via too many snufit bullets.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oDeathSound, -1)
			ObjBehaviors2.obj_die_if_health_non_positive()
		end

		ObjectHelpers.cur_obj_move_standard(78)
	else
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end
end

return snufit_inc
