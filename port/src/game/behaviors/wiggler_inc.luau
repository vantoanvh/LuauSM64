--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/wiggler.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSeqIdsH = require("../../../include/seq_ids_h")

const InteractionH = require("../interaction_h")
const ObjBehaviors2H = require("../obj_behaviors_2_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const Memory = require("../memory")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectHelpersH = require("../object_helpers_h")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SpawnStarInc = require("./spawn_star_inc")

const SeqPlayerLevel = 0

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

-- from src/game/behaviors/wiggler_inc.luau:scratch
const Scratch = {
	wiggler_update_segments_dyaw = { 0 },
	wiggler_update_segments_dpitch = { 0 },
	wiggler_act_jumped_on_attackText = { IncludeDialogIdsH.DIALOG_152, IncludeDialogIdsH.DIALOG_168, IncludeDialogIdsH.DIALOG_151 },
	wiggler_act_jumped_on_scale = buffer.create(4),
	wiggler_act_shrink_scale = buffer.create(4),
}

-- from src/game/behaviors/wiggler.inc.c:data
const wiggler_inc = {
	-- from src/game/behaviors/wiggler.inc.c:sWigglerBodyPartHitbox L13-23
	sWigglerBodyPartHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 99,
		numLootCoins = 0,
		radius = 20,
		height = 20,
		hurtboxRadius = 20,
		hurtboxHeight = 10,
	},
	-- from src/game/behaviors/wiggler.inc.c:sWigglerHitbox L28-38
	sWigglerHitbox = {
		interactType = InteractionH.INTERACT_BOUNCE_TOP,
		downOffset = 0,
		damageOrCoinValue = 3,
		health = 4,
		numLootCoins = 0,
		radius = 60,
		height = 50,
		hurtboxRadius = 30,
		hurtboxHeight = 40,
	},
	-- from src/game/behaviors/wiggler.inc.c:sWigglerAttackHandlers L43-50
	sWigglerAttackHandlers = {
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_WIGGLER_JUMPED_ON,
		ObjBehaviors2H.ATTACK_HANDLER_SPECIAL_WIGGLER_JUMPED_ON,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
		ObjBehaviors2H.ATTACK_HANDLER_KNOCKBACK,
	},
	-- from src/game/behaviors/wiggler.inc.c:sWigglerSpeeds L55-55
	sWigglerSpeeds = { 2.0, 40.0, 30.0, 16.0 },
}

Registry.Register("src__game__behaviors__wiggler_inc", wiggler_inc)

-- from src/game/behaviors/wiggler.inc.c:bhv_wiggler_body_part_update L64-112
function wiggler_inc.bhv_wiggler_body_part_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Parent = o.parentObj :: GroupsTypesHPlus3.Object
	const Segments = Parent.ptrData[IncludeObjectFieldsH.oWigglerSegments + 1] :: { ObjectHelpersH.ChainSegment }
	const Segment = Segments[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]

	ObjectHelpers.cur_obj_scale(Parent.header.gfx.scale[1])

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, Segment.pitch)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, Segment.yaw)

	const PosOffset = F32(-37.5 * o.header.gfx.scale[1])
	const Dy = F32(F32(PosOffset * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))) - PosOffset)
	const Dxz = F32(PosOffset * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)))
	const Dx = F32(Dxz * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)))
	const Dz = F32(Dxz * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Segment.posX + Dx)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Segment.posY + Dy)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Segment.posZ + Dz)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oWigglerFallThroughFloorsHeight) then
		-- Since position is recomputed each frame, tilting the wiggler up
		-- while on the ground could cause the tail segments to clip through
		-- the floor
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 30)
		ObjectHelpers.cur_obj_update_floor_height()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight))
		end
	end

	Segment.posY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)

	-- Inherit walking animation speed from wiggler
	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed))

	if buffer.readf32(Parent.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed) == 0 then
		ObjectHelpers.cur_obj_reverse_animation()
	end

	if buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.WIGGLER_ACT_SHRINK then
		ObjectHelpers.cur_obj_become_intangible()
	else
		ObjBehaviors2.obj_check_attacks(wiggler_inc.sWigglerBodyPartHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
	end
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_init_segments L117-156
function wiggler_inc.wiggler_init_segments()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	-- mem_pool_alloc(gObjectMemoryPool, 4 * sizeof(struct ChainSegment)): a record array, no pool accounting (struct-allocation)
	const Segments = { ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment(), ObjectHelpersH.new_ChainSegment() }

	o.ptrData[IncludeObjectFieldsH.oWigglerSegments + 1] = Segments

	-- Each segment represents the global position and orientation of each
	-- object. Segment 0 represents the wiggler's head, and segment i>0
	-- represents body part i.
	for I = 1, 4 do
		ObjectHelpers.chain_segment_init(Segments[I])

		Segments[I].posX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		Segments[I].posY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Segments[I].posZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

		Segments[I].pitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		Segments[I].yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	end

	o.header.gfx.animInfo.animFrame = -1

	-- Spawn each body part
	for I = 1, 3 do
		const BodyPart = ObjectHelpers.spawn_object_relative(I, 0, 0, 0, o, IncludeModelIdsH.MODEL_WIGGLER_BODY, BehaviorIds.bhvWigglerBody)

		if BodyPart ~= nil then
			ObjectHelpers.obj_init_animation_with_sound(BodyPart, Memory.segmented_to_virtual(0x0500C874), 0)
			BodyPart.header.gfx.animInfo.animFrame = S16(math.fmod(23 * I, 26) - 1)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_WALK)
	ObjectHelpers.cur_obj_unhide()

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, 4)
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_update_segments L165-205
function wiggler_inc.wiggler_update_segments()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Segments = o.ptrData[IncludeObjectFieldsH.oWigglerSegments + 1] :: { ObjectHelpersH.ChainSegment }
	const SegmentLength = F32(35 * o.header.gfx.scale[1])

	for I = 1, 3 do
		const PrevBodyPart = Segments[I]
		const BodyPart = Segments[I + 1]

		const Dx = F32(BodyPart.posX - PrevBodyPart.posX)
		const Dy = F32(BodyPart.posY - PrevBodyPart.posY)
		const Dz = F32(BodyPart.posZ - PrevBodyPart.posZ)

		-- As the head turns, propagate this rotation backward if the difference
		-- is more than 45 degrees
		Scratch.wiggler_update_segments_dyaw[1] = S16(SrcEngineMathUtil.atan2s(-Dz, -Dx) - PrevBodyPart.yaw)
		ObjBehaviors2.clamp_s16(Scratch.wiggler_update_segments_dyaw, -0x2000, 0x2000)
		BodyPart.yaw = S16(PrevBodyPart.yaw + Scratch.wiggler_update_segments_dyaw[1])

		-- As the head tilts, propagate the tilt backward
		local Dxz = F32(math.sqrt(F32(F32(Dx * Dx) + F32(Dz * Dz))))

		Scratch.wiggler_update_segments_dpitch[1] = S16(SrcEngineMathUtil.atan2s(Dxz, Dy) - PrevBodyPart.pitch)
		ObjBehaviors2.clamp_s16(Scratch.wiggler_update_segments_dpitch, -0x2000, 0x2000)
		BodyPart.pitch = S16(PrevBodyPart.pitch + Scratch.wiggler_update_segments_dpitch[1])

		-- Set the body part's position relative to the previous body part's
		-- position, using the current body part's angles. This means that the
		-- head can rotate up to 45 degrees without the body moving
		BodyPart.posY = F32(F32(SegmentLength * SrcEngineMathUtilH.sins(BodyPart.pitch)) + PrevBodyPart.posY)
		Dxz = F32(SegmentLength * SrcEngineMathUtilH.coss(BodyPart.pitch))
		BodyPart.posX = F32(PrevBodyPart.posX - F32(Dxz * SrcEngineMathUtilH.sins(BodyPart.yaw)))
		BodyPart.posZ = F32(PrevBodyPart.posZ - F32(Dxz * SrcEngineMathUtilH.coss(BodyPart.yaw)))
	end
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_act_walk L212-282
function wiggler_inc.wiggler_act_walk()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed, F32(0.06) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

	-- Update text if necessary
	if buffer.readi16(o.rawData, IncludeObjectFieldsH.oWigglerTextStatus) < IncludeObjectConstantsH.WIGGLER_TEXT_STATUS_COMPLETED_DIALOG then
		if buffer.readi16(o.rawData, IncludeObjectFieldsH.oWigglerTextStatus) == IncludeObjectConstantsH.WIGGLER_TEXT_STATUS_AWAIT_DIALOG then
			Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oWigglerTextStatus, IncludeObjectConstantsH.WIGGLER_TEXT_STATUS_SHOWING_DIALOG)
		end

		-- If Mario is positioned below the wiggler, assume he entered through the
		-- lower cave entrance, so don't display text.
		if buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) or ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_NONE, GroupsTypesHPlus3.CUTSCENE_DIALOG, IncludeDialogIdsH.DIALOG_150) ~= 0 then
			buffer.writei16(o.rawData, IncludeObjectFieldsH.oWigglerTextStatus, IncludeObjectConstantsH.WIGGLER_TEXT_STATUS_COMPLETED_DIALOG)
		end
	else
		--! Every object's health is initially 2048, and wiggler's doesn't change
		--  to 4 until after this runs the first time. It indexes out of bounds
		--  and uses the value 113762.3 for one frame on US. This is fixed up
		--  in wiggler_init_segments if AVOID_UB is defined.
		ObjBehaviors2.obj_forward_vel_approach(wiggler_inc.sWigglerSpeeds[buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth)], 1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAwayFromWallTimer) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAwayFromWallTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAwayFromWallTimer) - 1))
		else
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) >= 25000 then
				-- If >1200 away from home, turn to home
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			end

			if ObjBehaviors2.obj_bounce_off_walls_edges_objects(o.rawData, IncludeObjectFieldsH.oWigglerTargetYaw) ~= 0 then
				--! If the wiggler could self-intersect, or intersect a different
				--  non-mario object, this could potentially be used to force
				--  the wiggler to walk straight - past his usual radius
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAwayFromWallTimer, ObjBehaviors2.random_linear_offset(30, 30))
			else
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) < 4 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerTargetYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
				elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oWigglerTimeUntilRandomTurn) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerTimeUntilRandomTurn, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWigglerTimeUntilRandomTurn) - 1))
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerTargetYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000 * S16(SrcEngineBehaviorScript.random_sign())))
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerTimeUntilRandomTurn, ObjBehaviors2.random_linear_offset(30, 50))
				end
			end
		end

		-- If moving at high speeds, could overflow. But can't reach such speeds
		-- in practice
		const YawTurnSpeed = S16(TruncS32(F32(30 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))))

		ObjectHelpers.cur_obj_rotate_yaw_toward(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWigglerTargetYaw)), YawTurnSpeed)
		ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), S16(2 * YawTurnSpeed))

		ObjBehaviors2.obj_face_pitch_approach(0, 0x320)

		-- For the first two seconds of walking, stay invulnerable
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 60 then
			ObjBehaviors2.obj_check_attacks(wiggler_inc.sWigglerHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
		elseif ObjBehaviors2.obj_handle_attacks(wiggler_inc.sWigglerHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction), wiggler_inc.sWigglerAttackHandlers) ~= 0 then
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) ~= IncludeObjectConstantsH.WIGGLER_ACT_JUMPED_ON then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_KNOCKBACK)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAwayFromWallTimer, 0)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed, 0)
		end
	end
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_act_jumped_on L287-327
function wiggler_inc.wiggler_act_jumped_on()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	-- Text to show on first, second, and third attack.
	const attackText: { number } = Scratch.wiggler_act_jumped_on_attackText

	-- Shrink until the squish speed becomes 0, then unisquish
	if ObjBehaviors2.approach_f32_ptr(o.rawData, IncludeObjectFieldsH.oWigglerSquishSpeed, 0.0, F32(0.05)) ~= 0 then
		-- Note that 4 is the default scale
		buffer.writef32(Scratch.wiggler_act_jumped_on_scale, 0, o.header.gfx.scale[2])
		ObjBehaviors2.approach_f32_ptr(Scratch.wiggler_act_jumped_on_scale, 0, 4.0, F32(0.2))
		o.header.gfx.scale[2] = buffer.readf32(Scratch.wiggler_act_jumped_on_scale, 0)
	else
		o.header.gfx.scale[2] = F32(o.header.gfx.scale[2] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oWigglerSquishSpeed))
	end

	-- Wait for a second after unsquishing, then show text and either shrink (if
	-- defeated) or go back to walking
	if o.header.gfx.scale[2] >= 4.0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			if ObjectHelpers.cur_obj_update_dialog_with_cutscene(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP, IncludeObjectConstantsH.DIALOG_FLAG_NONE, GroupsTypesHPlus3.CUTSCENE_DIALOG, attackText[buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 2 + 1]) ~= 0 then
				-- Because we don't want the wiggler to disappear after being
				-- defeated, we leave its health at 1
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oHealth, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) - 1))

				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 1 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_SHRINK)
					ObjectHelpers.cur_obj_become_intangible()
				else
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_WALK)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

					if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) == 2 then
						SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_WIGGLER_JUMP)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)
						buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 70.0)
					end
				end
			end
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	ObjBehaviors2.obj_check_attacks(wiggler_inc.sWigglerHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_act_knockback L332-345
function wiggler_inc.wiggler_act_knockback()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) * 30)))))
	else
		ObjBehaviors2.obj_face_pitch_approach(0, 0x190)
	end

	if ObjBehaviors2.obj_forward_vel_approach(0, 1) ~= 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_WALK)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	end

	ObjBehaviors2.obj_check_attacks(wiggler_inc.sWigglerHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_act_shrink L350-364
function wiggler_inc.wiggler_act_shrink()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 20 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_ENEMY_DEFEAT_SHRINK)
		end

		-- 4 is the default scale, so shrink to 1/4 of regular size
		buffer.writef32(Scratch.wiggler_act_shrink_scale, 0, o.header.gfx.scale[1])
		const reached: number = ObjBehaviors2.approach_f32_ptr(Scratch.wiggler_act_shrink_scale, 0, 1.0, F32(0.1))
		o.header.gfx.scale[1] = buffer.readf32(Scratch.wiggler_act_shrink_scale, 0)

		if reached ~= 0 then
			SpawnStarInc.spawn_default_star(0.0, 2048.0, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_FALL_THROUGH_FLOOR)
		end

		ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
	end
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_act_fall_through_floor L369-382
function wiggler_inc.wiggler_act_fall_through_floor()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
		Audio.stop_background_music(bit32.bor(bit32.lshift(4, 8), IncludeSeqIdsH.SEQ_EVENT_BOSS))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oWigglerFallThroughFloorsHeight, 1700)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oWigglerFallThroughFloorsHeight) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_WALK)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, ObjBehaviors2.obj_get_pitch_from_vel())
		end

		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end
end

-- from src/game/behaviors/wiggler.inc.c:wiggler_jumped_on_attack_handler L388-393
function wiggler_inc.wiggler_jumped_on_attack_handler()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_WIGGLER_ATTACKED)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.WIGGLER_ACT_JUMPED_ON)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oWigglerSquishSpeed, F32(0.4))
end

-- from src/game/behaviors/wiggler.inc.c:bhv_wiggler_update L398-450
function wiggler_inc.bhv_wiggler_update()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == IncludeObjectConstantsH.WIGGLER_ACT_UNINITIALIZED then
		wiggler_inc.wiggler_init_segments()
	else
		if Action == IncludeObjectConstantsH.WIGGLER_ACT_FALL_THROUGH_FLOOR then
			wiggler_inc.wiggler_act_fall_through_floor()
		else
			ObjBehaviors2.treat_far_home_as_mario(1200)

			-- Walking animation and sound
			ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(0, buffer.readf32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed))

			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oWigglerWalkAnimSpeed) ~= 0 then
				ObjBehaviors2.cur_obj_play_sound_at_anim_range(0, 13, if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHealth) >= 4 then IncludeSoundsH.SOUND_OBJ_WIGGLER_LOW_PITCH else IncludeSoundsH.SOUND_OBJ_WIGGLER_HIGH_PITCH)
			else
				ObjectHelpers.cur_obj_reverse_animation()
			end

			ObjectHelpers.cur_obj_update_floor_and_walls()

			const ActionAfterFloor = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

			if ActionAfterFloor == IncludeObjectConstantsH.WIGGLER_ACT_WALK then
				wiggler_inc.wiggler_act_walk()
			elseif ActionAfterFloor == IncludeObjectConstantsH.WIGGLER_ACT_KNOCKBACK then
				wiggler_inc.wiggler_act_knockback()
			elseif ActionAfterFloor == IncludeObjectConstantsH.WIGGLER_ACT_JUMPED_ON then
				wiggler_inc.wiggler_act_jumped_on()
			elseif ActionAfterFloor == IncludeObjectConstantsH.WIGGLER_ACT_SHRINK then
				wiggler_inc.wiggler_act_shrink()
			elseif ActionAfterFloor == IncludeObjectConstantsH.WIGGLER_ACT_FALL_THROUGH_FLOOR then
				wiggler_inc.wiggler_act_fall_through_floor()
			end

			ObjectHelpers.cur_obj_move_standard(-78)
		end

		-- Update segment 0 with data from the wiggler object
		const Segments = o.ptrData[IncludeObjectFieldsH.oWigglerSegments + 1] :: { ObjectHelpersH.ChainSegment }

		Segments[1].posX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		Segments[1].posY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Segments[1].posZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		Segments[1].pitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		Segments[1].yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

		-- Update the rest of the segments to follow segment 0
		wiggler_inc.wiggler_update_segments()
	end
end

return wiggler_inc
