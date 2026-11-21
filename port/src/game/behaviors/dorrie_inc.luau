--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/dorrie.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const PlatformDisplacement = require("../platform_displacement")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const dorrie_inc = {}

Registry.Register("src__game__behaviors__dorrie_inc", dorrie_inc)

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


-- from src/game/behaviors/dorrie.inc.c:dorrie_raise_head L3-15
function dorrie_inc.dorrie_raise_head()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	const startAngle = buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle)

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle) - S16(TruncS32(ObjectHelpers.absf(F32(370 * SrcEngineMathUtilH.sins(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieHeadRaiseSpeed))))))))

	const xzDisp = F32(440 * F32(SrcEngineMathUtilH.coss(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle)) - SrcEngineMathUtilH.coss(startAngle)))
	const yDisp = F32(440 * F32(SrcEngineMathUtilH.sins(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle)) - SrcEngineMathUtilH.sins(startAngle)))

	PlatformDisplacement.set_mario_pos(F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosX) + F32(xzDisp * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))), F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) - yDisp), F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ) + F32(xzDisp * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))))
end

-- from src/game/behaviors/dorrie.inc.c:dorrie_act_move L17-52
function dorrie_inc.dorrie_act_move()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	const startYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	local targetYaw = 0
	local targetSpeed = 0

	buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle, -0x26F4)
	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieForwardDistToMario) < 320 and buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieGroundPounded) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DORRIE)
		o.collisionData = Memory.segmented_to_virtual(0x0600FBB8)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.DORRIE_ACT_LOWER_HEAD)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDorrieYawVel, 0)
	else
		if mario.platform == o then
			targetYaw = S16(buffer.readi32(mario.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
			targetSpeed = 10
		else
			local circularTurn = S16(0x4000 - SrcEngineMathUtil.atan2s(2000, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieDistToHome) - 2000)))
			if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome)) < 0 then
				circularTurn = S16(-circularTurn)
			end

			targetYaw = S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome) + circularTurn)
			targetSpeed = 5
		end

		ObjBehaviors2.obj_forward_vel_approach(targetSpeed, 0.5)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDorrieYawVel, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDorrieYawVel)), S16(TruncS32(S16(targetYaw - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) / 50)), 5))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oDorrieYawVel))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - startYaw)
end

-- from src/game/behaviors/dorrie.inc.c:dorrie_begin_head_raise L54-58
function dorrie_inc.dorrie_begin_head_raise(liftingMario: number)
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDorrieLiftingMario, liftingMario)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.DORRIE_ACT_RAISE_HEAD)
	buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieHeadRaiseSpeed, 0)
end

-- from src/game/behaviors/dorrie.inc.c:dorrie_act_lower_head L60-91
function dorrie_inc.dorrie_act_lower_head()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	if ObjBehaviors2.cur_obj_init_anim_check_frame(2, 35) ~= 0 then
		ObjectHelpers.cur_obj_reverse_animation()

		if mario.platform == o then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY) == -17 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieForwardDistToMario) > 780 and MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_START then
				dorrie_inc.dorrie_begin_head_raise(IncludePRUltratypesH.TRUE)
			elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieForwardDistToMario) > 320 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
			dorrie_inc.dorrie_begin_head_raise(IncludePRUltratypesH.FALSE)
		end
	else
		buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle) + 0x115))
	end
end

-- from src/game/behaviors/dorrie.inc.c:dorrie_act_raise_head L93-108
function dorrie_inc.dorrie_act_raise_head()
	const o = ObjectListProcessor.gCurrentObject

	o.collisionData = Memory.segmented_to_virtual(0x0600F644)
	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.DORRIE_ACT_MOVE)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oDorrieLiftingMario) ~= 0 and o.header.gfx.animInfo.animFrame < 74 then
		if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieHeadRaiseSpeed, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieHeadRaiseSpeed) + 0x1CC))
			if ObjectHelpers.cur_obj_check_anim_frame(73) ~= 0 then
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
			end
			dorrie_inc.dorrie_raise_head()
		else
			ObjectHelpers.cur_obj_reverse_animation()
		end
	end
end

-- from src/game/behaviors/dorrie.inc.c:bhv_dorrie_update L110-170
function dorrie_inc.bhv_dorrie_update()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	local maxOffsetY = 0

	if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieForwardDistToMario, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

		ObjBehaviors2.obj_perform_position_op(0)
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome, ObjectHelpers.cur_obj_angle_to_home())
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieDistToHome, ObjectHelpers.cur_obj_lateral_dist_to_home())

		-- Shift dorrie's bounds to account for her neck
		const boundsShift = F32(F32(440 * SrcEngineMathUtilH.coss(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieNeckAngle))) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome)))

		const DistClamped: number = ObjBehaviors2.clamp_f32(o.rawData, IncludeObjectFieldsH.oDorrieDistToHome, F32(1650 + boundsShift), F32(2300 + boundsShift))

		if DistClamped ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieDistToHome) * SrcEngineMathUtilH.sins(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieDistToHome) * SrcEngineMathUtilH.coss(buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieAngleToHome))))
		end

		buffer.writei16(o.rawData, IncludeObjectFieldsH.oDorrieGroundPounded, ObjectHelpers.cur_obj_is_mario_ground_pounding_platform())

		if mario.platform == o then
			maxOffsetY = -17
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY) >= 0 then
				if buffer.readi16(o.rawData, IncludeObjectFieldsH.oDorrieGroundPounded) ~= 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieVelY, -15)
				else
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieVelY, -6)
				end
			end
		else
			maxOffsetY = 0
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieVelY))
		ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oDorrieVelY, 3, 1)
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieVelY) > 0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY) > maxOffsetY then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY, maxOffsetY)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oDorrieOffsetY))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.DORRIE_ACT_MOVE then
			dorrie_inc.dorrie_act_move()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.DORRIE_ACT_LOWER_HEAD then
			dorrie_inc.dorrie_act_lower_head()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.DORRIE_ACT_RAISE_HEAD then
			dorrie_inc.dorrie_act_raise_head()
		end

		ObjBehaviors2.obj_perform_position_op(1)
	end
end

return dorrie_inc
