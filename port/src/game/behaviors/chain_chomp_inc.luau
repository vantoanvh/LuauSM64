--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/chain_chomp.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const SrcEngineMathUtil = require("../../engine/math_util")
const BehaviorActions = require("../behavior_actions")
const BreakParticlesInc = require("./break_particles_inc")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const Audio = require("../../rom/audio_recorder")

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

-- from src/game/behaviors/chain_chomp.inc.c:data
const chain_chomp_inc = {
	-- from src/game/behaviors/chain_chomp.inc.c:sChainChompHitbox L15-25
	sChainChompHitbox = {
		interactType = InteractionH.INTERACT_MR_BLIZZARD,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 1,
		numLootCoins = 0,
		radius = 80,
		height = 160,
		hurtboxRadius = 80,
		hurtboxHeight = 160,
	},
}

Registry.Register("src__game__behaviors__chain_chomp_inc", chain_chomp_inc)

-- from src/game/behaviors/chain_chomp.inc.c:bhv_chain_chomp_chain_part_update L30-44
function chain_chomp_inc.bhv_chain_chomp_chain_part_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNLOAD_CHAIN then
		ObjectHelpers.obj_mark_for_deletion(o)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.CHAIN_CHOMP_CHAIN_PART_BP_PIVOT then
		const Segment = (parent.ptrData[IncludeObjectFieldsH.oChainChompSegments + 1] :: { ObjectHelpersH.ChainSegment })[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]
		const Anchor = parent.parentObj :: GroupsTypesHPlus3.Object

		-- Set position relative to the pivot
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(Anchor.rawData, IncludeObjectFieldsH.oPosX) + Segment.posX)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(Anchor.rawData, IncludeObjectFieldsH.oPosY) + Segment.posY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(Anchor.rawData, IncludeObjectFieldsH.oPosZ) + Segment.posZ)
	elseif buffer.readi32(parent.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus) ~= IncludeObjectConstantsH.CHAIN_CHOMP_NOT_RELEASED then
		ObjectHelpers.cur_obj_update_floor_and_walls()
		ObjectHelpers.cur_obj_move_standard(78)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_act_uninitialized L49-82
function chain_chomp_inc.chain_chomp_act_uninitialized()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 3000.0 then
		const Segments = {ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment() }

		o.ptrData[IncludeObjectFieldsH.oChainChompSegments + 1] = Segments

		for i = 0, 4 do
			ObjectHelpers.chain_segment_init(Segments[i + 1])
		end

		ObjectHelpers.cur_obj_set_pos_to_home()

		-- Spawn the pivot and set to parent
		const Pivot: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object(o, IncludeObjectConstantsH.CHAIN_CHOMP_CHAIN_PART_BP_PIVOT, BehaviorIds.bhvChainChompChainPart)
		o.parentObj = Pivot

		if Pivot ~= nil then
			-- Spawn the non-pivot chain parts, starting from the chain chomp and moving toward the pivot
			for i = 1, 4 do
				ObjectHelpers.spawn_object_relative(i, 0, 0, 0, o, IncludeModelIdsH.MODEL_METALLIC_BALL, BehaviorIds.bhvChainChompChainPart)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CHAIN_CHOMP_ACT_MOVE)
			ObjectHelpers.cur_obj_unhide()
		end
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_update_chain_segments L88-153
function chain_chomp_inc.chain_chomp_update_chain_segments()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Segments = o.ptrData[IncludeObjectFieldsH.oChainChompSegments + 1] :: { ObjectHelpersH.ChainSegment }
	local SegmentVelY = -20.0

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.0 then
		SegmentVelY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)
	end

	-- Segment 0 connects the pivot to the chain chomp itself, and segment i>0 connects the pivot to chain part i.
	for i = 1, 4 do
		const PrevSegment = Segments[i]
		const Segment = Segments[i + 1]

		-- Apply gravity
		Segment.posY = F32(Segment.posY + SegmentVelY)

		if Segment.posY < 0.0 then
			Segment.posY = 0.0
		end

		-- Cap distance to previous chain part (so that the tail follows the chomp)
		local OffsetX = F32(Segment.posX - PrevSegment.posX)
		local OffsetY = F32(Segment.posY - PrevSegment.posY)
		local OffsetZ = F32(Segment.posZ - PrevSegment.posZ)
		local Offset = F32(math.sqrt(F32(F32(F32(OffsetX * OffsetX) + F32(OffsetY * OffsetY)) + F32(OffsetZ * OffsetZ))))

		if Offset > buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts) then
			Offset = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts) / Offset)
			OffsetX = F32(OffsetX * Offset)
			OffsetY = F32(OffsetY * Offset)
			OffsetZ = F32(OffsetZ * Offset)
		end

		-- Cap distance to pivot (so that it stretches when the chomp moves far from the wooden post)
		OffsetX = F32(OffsetX + PrevSegment.posX)
		OffsetY = F32(OffsetY + PrevSegment.posY)
		OffsetZ = F32(OffsetZ + PrevSegment.posZ)
		Offset = F32(math.sqrt(F32(F32(F32(OffsetX * OffsetX) + F32(OffsetY * OffsetY)) + F32(OffsetZ * OffsetZ))))

		const MaxTotalOffset = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart) * (5 - i))

		if Offset > MaxTotalOffset then
			Offset = F32(MaxTotalOffset / Offset)
			OffsetX = F32(OffsetX * Offset)
			OffsetY = F32(OffsetY * Offset)
			OffsetZ = F32(OffsetZ * Offset)
		end

		Segment.posX = OffsetX
		Segment.posY = OffsetY
		Segment.posZ = OffsetZ
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_restore_normal_chain_lengths L159-162
function chain_chomp_inc.chain_chomp_restore_normal_chain_lengths()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart, F32(750.0 / 5), 4.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts, buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart))
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_sub_act_turn L167-207
function chain_chomp_inc.chain_chomp_sub_act_turn()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)

	chain_chomp_inc.chain_chomp_restore_normal_chain_lengths()
	ObjBehaviors2.obj_move_pitch_approach(0, 0x100)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 0x400)

		if ObjectHelpers.abs_angle_diff(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) < 0x800 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
				if ObjectHelpers.cur_obj_check_anim_frame(0) ~= 0 then
					ObjectHelpers.cur_obj_reverse_animation()

					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 40 then
						-- Increase the maximum distance from the pivot and enter the lunging sub-action.
						SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CHAIN_CHOMP2)

						buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.CHAIN_CHOMP_SUB_ACT_LUNGE)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart, 900.0 / 5)

						buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 140.0)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
						buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompTargetPitch, ObjBehaviors2.obj_get_pitch_from_vel())
					end
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) - 1))
				end
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			end
		else
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CHAIN_CHOMP1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
		end
	else
		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 400)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_sub_act_lunge L209-248
function chain_chomp_inc.chain_chomp_sub_act_lunge()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjBehaviors2.obj_face_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompTargetPitch)), 0x400)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0.0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompRestrictedByChain) == IncludePRUltratypesH.TRUE then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompUnk104, 30.0)
		end

		-- Purpose unclear in the C source: kept as written.
		local Val04 = F32(900.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompDistToPivot))

		if Val04 > 220.0 then
			Val04 = 220.0
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts, F32(Val04 / 220.0) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	else
		-- Turn toward pivot
		const Segments = o.ptrData[IncludeObjectFieldsH.oChainChompSegments + 1] :: { ObjectHelpersH.ChainSegment }

		ObjectHelpers.cur_obj_rotate_yaw_toward(SrcEngineMathUtil.atan2s(Segments[1].posZ, Segments[1].posX), 0x1000)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompUnk104) ~= 0.0 then
			ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oChainChompUnk104, 0.0, F32(0.8))
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.CHAIN_CHOMP_SUB_ACT_TURN)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts, buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompUnk104))

		if math.fmod(GameInit.gGlobalTimer, 2) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistBetweenChainParts, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompUnk104))
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 30 then
		ObjectHelpers.cur_obj_reverse_animation()
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_released_trigger_cutscene L253-264
function chain_chomp_inc.chain_chomp_released_trigger_cutscene()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)

	if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) and Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o) == 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus, IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_LUNGE_AROUND)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_released_lunge_around L270-302
function chain_chomp_inc.chain_chomp_released_lunge_around()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	chain_chomp_inc.chain_chomp_restore_normal_chain_lengths()

	-- Finish bounce
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		-- Before first bounce, turn toward mario and wait 2 seconds
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompNumLunges) == 0 then
			if ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario)), 800) ~= 0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompNumLunges, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompNumLunges) + 1))
					-- enable wall collision
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oWallHitboxRadius, 200.0)
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		else
			const Lunges = S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompNumLunges) + 1)

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompNumLunges, Lunges)

			if Lunges <= 5 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CHAIN_CHOMP1)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + SrcEngineBehaviorScript.random_sign() * 0x2000))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus, IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_BREAK_GATE)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, 1450.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, 562.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_angle_to_home())
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, ObjectHelpers.cur_obj_lateral_dist_to_home() / 8)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 50.0)
			end
		end
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_released_break_gate L309-328
function chain_chomp_inc.chain_chomp_released_break_gate()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompHitGate) == 0 then
		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompHitGate, IncludePRUltratypesH.TRUE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_reflect_move_angle_off_wall())
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * F32(0.4))
		end
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus, IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_JUMP_AWAY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, 3288.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, -1770.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.cur_obj_angle_to_home())
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, ObjectHelpers.cur_obj_lateral_dist_to_home() / 50.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 120.0)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_released_jump_away L333-338
function chain_chomp_inc.chain_chomp_released_jump_away()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) then
		Camera.gObjCutsceneDone = IncludePRUltratypesH.TRUE
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus, IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_END_CUTSCENE)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_released_end_cutscene L343-348
function chain_chomp_inc.chain_chomp_released_end_cutscene()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o) == -1 then
		MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNLOAD_CHAIN)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_act_move L354-446
function chain_chomp_inc.chain_chomp_act_move()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Unload chain if mario is far enough
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus) == IncludeObjectConstantsH.CHAIN_CHOMP_NOT_RELEASED and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 4000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNLOAD_CHAIN)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	else
		ObjectHelpers.cur_obj_update_floor_and_walls()

		const ReleaseStatus = buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus)

		if ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_NOT_RELEASED then
			const SubAction = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction)

			if SubAction == IncludeObjectConstantsH.CHAIN_CHOMP_SUB_ACT_TURN then
				chain_chomp_inc.chain_chomp_sub_act_turn()
			elseif SubAction == IncludeObjectConstantsH.CHAIN_CHOMP_SUB_ACT_LUNGE then
				chain_chomp_inc.chain_chomp_sub_act_lunge()
			end
		elseif ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_TRIGGER_CUTSCENE then
			chain_chomp_inc.chain_chomp_released_trigger_cutscene()
		elseif ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_LUNGE_AROUND then
			chain_chomp_inc.chain_chomp_released_lunge_around()
		elseif ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_BREAK_GATE then
			chain_chomp_inc.chain_chomp_released_break_gate()
		elseif ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_JUMP_AWAY then
			chain_chomp_inc.chain_chomp_released_jump_away()
		elseif ReleaseStatus == IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_END_CUTSCENE then
			chain_chomp_inc.chain_chomp_released_end_cutscene()
		end

		ObjectHelpers.cur_obj_move_standard(78)

		const Parent = o.parentObj :: GroupsTypesHPlus3.Object
		const Segments = o.ptrData[IncludeObjectFieldsH.oChainChompSegments + 1] :: { ObjectHelpersH.ChainSegment }

		-- Segment 0 connects the pivot to the chain chomp itself
		Segments[1].posX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosX))
		Segments[1].posY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY))
		Segments[1].posZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosZ))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompDistToPivot, F32(math.sqrt(F32(F32(F32(Segments[1].posX * Segments[1].posX) + F32(Segments[1].posY * Segments[1].posY)) + F32(Segments[1].posZ * Segments[1].posZ)))))

		-- If the chain is fully stretched
		const MaxDistToPivot = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart) * 5)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompDistToPivot) > MaxDistToPivot then
			const Ratio = F32(MaxDistToPivot / buffer.readf32(o.rawData, IncludeObjectFieldsH.oChainChompDistToPivot))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompDistToPivot, MaxDistToPivot)

			Segments[1].posX = F32(Segments[1].posX * Ratio)
			Segments[1].posY = F32(Segments[1].posY * Ratio)
			Segments[1].posZ = F32(Segments[1].posZ * Ratio)

			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus) == IncludeObjectConstantsH.CHAIN_CHOMP_NOT_RELEASED then
				-- Restrict chain chomp position
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosX) + Segments[1].posX)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY) + Segments[1].posY)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosZ) + Segments[1].posZ)

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompRestrictedByChain, IncludePRUltratypesH.TRUE)
			else
				-- Move pivot like the chain chomp is pulling it along
				const OldPivotY = buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY)

				buffer.writef32(Parent.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - Segments[1].posX)
				buffer.writef32(Parent.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - Segments[1].posY)
				buffer.writef32(Parent.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oPosY) - OldPivotY)
				buffer.writef32(Parent.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - Segments[1].posZ)
			end
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompRestrictedByChain, IncludePRUltratypesH.FALSE)
		end

		chain_chomp_inc.chain_chomp_update_chain_segments()

		-- Begin a lunge if mario tries to attack
		if ObjBehaviors2.obj_check_attacks(chain_chomp_inc.sChainChompHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, IncludeObjectConstantsH.CHAIN_CHOMP_SUB_ACT_LUNGE)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oChainChompMaxDistFromPivotPerChainPart, 900.0 / 5)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 300.0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oChainChompTargetPitch, -0x3000)
		end
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:chain_chomp_act_unload_chain L452-461
function chain_chomp_inc.chain_chomp_act_unload_chain()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_hide()
	-- mem_pool_free of the segments is dropped: the table is released by the collector (chain-chomp-segments-table).
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNINITIALIZED)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oChainChompReleaseStatus) ~= IncludeObjectConstantsH.CHAIN_CHOMP_NOT_RELEASED then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:bhv_chain_chomp_update L466-478
function chain_chomp_inc.bhv_chain_chomp_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNINITIALIZED then
		chain_chomp_inc.chain_chomp_act_uninitialized()
	elseif action == IncludeObjectConstantsH.CHAIN_CHOMP_ACT_MOVE then
		chain_chomp_inc.chain_chomp_act_move()
	elseif action == IncludeObjectConstantsH.CHAIN_CHOMP_ACT_UNLOAD_CHAIN then
		chain_chomp_inc.chain_chomp_act_unload_chain()
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:bhv_wooden_post_update L483-522
function chain_chomp_inc.bhv_wooden_post_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- When ground pounded by mario, drop by -45 + -20
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWoodenPostMarioPounding) == 0 then
		const Pounding = ObjectHelpers.cur_obj_is_mario_ground_pounding_platform()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWoodenPostMarioPounding, Pounding)

		if Pounding ~= 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_POUND_WOOD_POST)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oWoodenPostSpeedY, -70.0)
		end
	else
		const Stopped = ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oWoodenPostSpeedY, 0.0, 25.0)

		if Stopped ~= 0 then
			-- Stay still until mario is done ground pounding
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWoodenPostMarioPounding, ObjectHelpers.cur_obj_is_mario_ground_pounding_platform())
		else
			const OffsetY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oWoodenPostOffsetY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oWoodenPostSpeedY))

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oWoodenPostOffsetY, OffsetY)

			if OffsetY < -190.0 then
				-- Once pounded, if this is the chain chomp's post, release the chain chomp
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oWoodenPostOffsetY, -190.0)

				if o.parentObj ~= o then
					Audio.play_puzzle_jingle()
					buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oChainChompReleaseStatus, IncludeObjectConstantsH.CHAIN_CHOMP_RELEASED_TRIGGER_CUTSCENE)
					o.parentObj = o
				end
			end
		end
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWoodenPostOffsetY) ~= 0.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oWoodenPostOffsetY))
	elseif not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), IncludeObjectConstantsH.WOODEN_POST_BP_NO_COINS_MASK) then
		-- Reset the timer once mario is far enough
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 400.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWoodenPostTotalMarioAngle, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		else
			-- When mario runs around the post 3 times within 200 frames, spawn coins
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWoodenPostTotalMarioAngle, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWoodenPostTotalMarioAngle) + S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - buffer.readi32(o.rawData, IncludeObjectFieldsH.oWoodenPostPrevAngleToMario))))

			if ObjectHelpers.absi(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWoodenPostTotalMarioAngle)) > 0x30000 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 200 then
				ObjectHelpers.obj_spawn_loot_yellow_coins(o, 5, 20.0)
				ObjectListProcessor.set_object_respawn_info_bits(o, 1)
			end
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWoodenPostPrevAngleToMario, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
	end
end

-- from src/game/behaviors/chain_chomp.inc.c:bhv_chain_chomp_gate_init L527-529
function chain_chomp_inc.bhv_chain_chomp_gate_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.parentObj = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvChainChomp)
end

-- from src/game/behaviors/chain_chomp.inc.c:bhv_chain_chomp_gate_update L534-542
function chain_chomp_inc.bhv_chain_chomp_gate_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oChainChompHitGate) ~= 0 then
		ObjectHelpers.spawn_mist_particles_with_sound(IncludeSoundsH.SOUND_GENERAL_WALL_EXPLOSION)
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_SMALL, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		BehaviorActions.spawn_mist_particles_variable(0, 127, 200.0)
		BreakParticlesInc.spawn_triangle_break_particles(30, IncludeModelIdsH.MODEL_DIRT_ANIMATION, 3.0, 4)
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return chain_chomp_inc
