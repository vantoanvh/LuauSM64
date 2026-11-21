--!strict
--!optimize 2

--[[
	Port of src/game/interaction.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeSm64H = require("../../include/sm64_h")

const InteractionH = require("./interaction_h")
const MarioStepH = require("./mario_step_h")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSeqIdsH = require("../../include/seq_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")
const Memory = require("./memory")
const ObjectHelpers = require("./object_helpers")
const SrcEngineMathUtil = require("../engine/math_util")
const SaveFileH = require("./save_file_h")
const GameInit = require("./game_init")
const LevelUpdate = require("./level_update")
const SaveFile = require("./save_file")
const SoundInit = require("./sound_init")
const LevelUpdateH = require("./level_update_h")
const Area = require("./area")
const Camera = require("./camera")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludeDialogIdsH = require("../../include/dialog_ids_h")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const BehaviorsSpawnStarInc = require("./behaviors/spawn_star_inc")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")

-- from src/game/interaction.c:InteractionHandler
export type InteractionHandler = {
	interactType: number,
	handler: ((GroupsTypesHPlus3.MarioState, number, GroupsTypesHPlus3.Object) -> number)?,
}

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

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/interaction.c:data
const interaction = {
	INT_GROUND_POUND_OR_TWIRL = 1,
	INT_PUNCH = 2,
	INT_KICK = 4,
	INT_TRIP = 8,
	INT_SLIDE_KICK = 16,
	INT_FAST_ATTACK_OR_SHELL = 32,
	INT_HIT_FROM_ABOVE = 64,
	INT_HIT_FROM_BELOW = 128,
	INT_ATTACK_NOT_FROM_BELOW = 127, -- (INT_GROUND_POUND_OR_TWIRL | INT_PUNCH | INT_KICK | INT_TRIP | INT_SLIDE_KICK | INT_FAST_ATTACK_OR_SHELL | INT_HIT_FROM_ABOVE)
	INT_ANY_ATTACK = 255, -- (INT_GROUND_POUND_OR_TWIRL | INT_PUNCH | INT_KICK | INT_TRIP | INT_SLIDE_KICK | INT_FAST_ATTACK_OR_SHELL | INT_HIT_FROM_ABOVE | INT_HIT_FROM_BELOW)
	INT_ATTACK_NOT_WEAK_FROM_ABOVE = 143, -- (INT_GROUND_POUND_OR_TWIRL | INT_PUNCH | INT_KICK | INT_TRIP | INT_HIT_FROM_BELOW)
	-- from src/game/interaction.c:sDelayInvincTimer L47-47
	sDelayInvincTimer = 0,
	-- from src/game/interaction.c:sInvulnerable L48-48
	sInvulnerable = 0,
	-- from src/game/interaction.c:sForwardKnockbackActions L118-122
	sForwardKnockbackActions = {
		{
			IncludeSm64H.ACT_SOFT_FORWARD_GROUND_KB,
			IncludeSm64H.ACT_FORWARD_GROUND_KB,
			IncludeSm64H.ACT_HARD_FORWARD_GROUND_KB,
		},
		{
			IncludeSm64H.ACT_FORWARD_AIR_KB,
			IncludeSm64H.ACT_FORWARD_AIR_KB,
			IncludeSm64H.ACT_HARD_FORWARD_AIR_KB,
		},
		{
			IncludeSm64H.ACT_FORWARD_WATER_KB,
			IncludeSm64H.ACT_FORWARD_WATER_KB,
			IncludeSm64H.ACT_FORWARD_WATER_KB,
		},
	},
	-- from src/game/interaction.c:sBackwardKnockbackActions L124-128
	sBackwardKnockbackActions = {
		{
			IncludeSm64H.ACT_SOFT_BACKWARD_GROUND_KB,
			IncludeSm64H.ACT_BACKWARD_GROUND_KB,
			IncludeSm64H.ACT_HARD_BACKWARD_GROUND_KB,
		},
		{
			IncludeSm64H.ACT_BACKWARD_AIR_KB,
			IncludeSm64H.ACT_BACKWARD_AIR_KB,
			IncludeSm64H.ACT_HARD_BACKWARD_AIR_KB,
		},
		{
			IncludeSm64H.ACT_BACKWARD_WATER_KB,
			IncludeSm64H.ACT_BACKWARD_WATER_KB,
			IncludeSm64H.ACT_BACKWARD_WATER_KB,
		},
	},
	-- from src/game/interaction.c:sDisplayingDoorText L130-130
	sDisplayingDoorText = 0,
	-- from src/game/interaction.c:sJustTeleported L131-131
	sJustTeleported = 0,
	-- from src/game/interaction.c:sPSSSlideStarted L132-132
	sPSSSlideStarted = 0,
	READ_MASK = 8194, -- (INPUT_B_PRESSED | INPUT_A_PRESSED)
	SIGN_RANGE = 0x4000,
}

Registry.Register("src__game__interaction", interaction)

-- C stack structs passed by address (BullyCollisionData marioData, bullyData) are module level scratch
-- from src/game/interaction.c:bully_knock_back_mario:marioData L331-394
const BullyCollisionMario = { conversionRatio = 0, radius = 0, posX = 0, posZ = 0, velX = 0, velZ = 0 } :: MarioStepH.BullyCollisionData
-- from src/game/interaction.c:bully_knock_back_mario:bullyData L331-394
const BullyCollisionBully = { conversionRatio = 0, radius = 0, posX = 0, posZ = 0, velX = 0, velZ = 0 } :: MarioStepH.BullyCollisionData

-- from src/game/interaction.c:check_kick_or_punch_wall:detector L1755-1778
const WallDetector = { 0, 0, 0 }

-- C stack out pointers (f32 locals, &m->pos[1], Surface floor) are module level scratch: one element tables
const NewMarioX = { 0 }
const NewMarioZ = { 0 }
const MarioPosY = { 0 }
const FloorSurface: { GroupsTypesHPlus3.Surface? } = {}

-- from src/game/interaction.c:InteractionHandler (zero-filled constructor)
function interaction.new_InteractionHandler(): InteractionHandler
	return { interactType = 0, handler = nil } :: InteractionHandler
end

-- from src/game/interaction.c:get_mario_cap_flag L137-151
function interaction.get_mario_cap_flag(capObject: GroupsTypesHPlus3.Object): number
	const script = Memory.virtual_to_segmented(0x13, capObject.behavior :: number)

	if script == BehaviorIds.bhvNormalCap then
		return IncludeSm64H.MARIO_NORMAL_CAP
	elseif script == BehaviorIds.bhvMetalCap then
		return IncludeSm64H.MARIO_METAL_CAP
	elseif script == BehaviorIds.bhvWingCap then
		return IncludeSm64H.MARIO_WING_CAP
	elseif script == BehaviorIds.bhvVanishCap then
		return IncludeSm64H.MARIO_VANISH_CAP
	end

	return 0
end

-- from src/game/interaction.c:object_facing_mario L157-169
function interaction.object_facing_mario(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object, angleRange: number): number
	angleRange = S16(TruncS32(angleRange))
	const dx = F32(m.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const dz = F32(m.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	const angleToMario = SrcEngineMathUtil.atan2s(dz, dx)
	const dAngle = S16(angleToMario - buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if -angleRange <= dAngle and dAngle <= angleRange then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:mario_obj_angle_to_object L171-176
function interaction.mario_obj_angle_to_object(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - m.pos[1])
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - m.pos[3])

	return SrcEngineMathUtil.atan2s(dz, dx)
end

-- from src/game/interaction.c:determine_interaction L182-245
function interaction.determine_interaction(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	local interactType = 0
	const action = m.action

	if bit32.btest(action, IncludeSm64H.ACT_FLAG_ATTACKING) then
		if action == IncludeSm64H.ACT_PUNCHING or action == IncludeSm64H.ACT_MOVE_PUNCHING or action == IncludeSm64H.ACT_JUMP_KICK then
			const dYawToObject = S16(interaction.mario_obj_angle_to_object(m, o) - m.faceAngle[2])

			if bit32.btest(m.flags, IncludeSm64H.MARIO_PUNCHING) then
				-- 120 degrees total, or 60 each way
				if -0x2AAA <= dYawToObject and dYawToObject <= 0x2AAA then
					interactType = interaction.INT_PUNCH
				end
			end
			if bit32.btest(m.flags, IncludeSm64H.MARIO_KICKING) then
				-- 120 degrees total, or 60 each way
				if -0x2AAA <= dYawToObject and dYawToObject <= 0x2AAA then
					interactType = interaction.INT_KICK
				end
			end
			if bit32.btest(m.flags, IncludeSm64H.MARIO_TRIPPING) then
				-- 180 degrees total, or 90 each way
				if -0x4000 <= dYawToObject and dYawToObject <= 0x4000 then
					interactType = interaction.INT_TRIP
				end
			end
		elseif action == IncludeSm64H.ACT_GROUND_POUND or action == IncludeSm64H.ACT_TWIRLING then
			if m.vel[2] < 0 then
				interactType = interaction.INT_GROUND_POUND_OR_TWIRL
			end
		elseif action == IncludeSm64H.ACT_GROUND_POUND_LAND or action == IncludeSm64H.ACT_TWIRL_LAND then
			-- Neither ground pounding nor twirling change Mario's vertical speed on landing,
			-- so the speed check is nearly always true (perhaps not if you land while going upwards?)
			-- Additionally, actionState it set on each first thing in their action, so this is
			-- only true prior to the very first frame (i.e. active 1 frame prior to it run).
			if m.vel[2] < 0 and m.actionState == 0 then
				interactType = interaction.INT_GROUND_POUND_OR_TWIRL
			end
		elseif action == IncludeSm64H.ACT_SLIDE_KICK or action == IncludeSm64H.ACT_SLIDE_KICK_SLIDE then
			interactType = interaction.INT_SLIDE_KICK
		elseif bit32.btest(action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) then
			interactType = interaction.INT_FAST_ATTACK_OR_SHELL
		elseif m.forwardVel <= -26 or 26 <= m.forwardVel then
			interactType = interaction.INT_FAST_ATTACK_OR_SHELL
		end
	end

	-- Prior to this, the interaction type could be overwritten. This requires, however,
	-- that the interaction not be set prior. This specifically overrides turning a ground
	-- pound into just a bounce.
	if interactType == 0 and bit32.btest(action, IncludeSm64H.ACT_FLAG_AIR) then
		if m.vel[2] < 0 then
			if m.pos[2] > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
				interactType = interaction.INT_HIT_FROM_ABOVE
			end
		else
			if m.pos[2] < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
				interactType = interaction.INT_HIT_FROM_BELOW
			end
		end
	end

	return interactType
end

-- from src/game/interaction.c:attack_object L250-278
function interaction.attack_object(o: GroupsTypesHPlus3.Object, interactType: number): number
	local attackType = 0

	if interactType == interaction.INT_GROUND_POUND_OR_TWIRL then
		attackType = InteractionH.ATTACK_GROUND_POUND_OR_TWIRL
	elseif interactType == interaction.INT_PUNCH then
		attackType = InteractionH.ATTACK_PUNCH
	elseif interactType == interaction.INT_KICK or interactType == interaction.INT_TRIP then
		attackType = InteractionH.ATTACK_KICK_OR_TRIP
	elseif interactType == interaction.INT_SLIDE_KICK or interactType == interaction.INT_FAST_ATTACK_OR_SHELL then
		attackType = InteractionH.ATTACK_FAST_ATTACK
	elseif interactType == interaction.INT_HIT_FROM_ABOVE then
		attackType = InteractionH.ATTACK_FROM_ABOVE
	elseif interactType == interaction.INT_HIT_FROM_BELOW then
		attackType = InteractionH.ATTACK_FROM_BELOW
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, attackType + bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_WAS_ATTACKED))
	return attackType
end

-- from src/game/interaction.c:mario_stop_riding_object L280-286
function interaction.mario_stop_riding_object(m: GroupsTypesHPlus3.MarioState)
	if m.riddenObj ~= nil then
		const riddenObj = m.riddenObj :: GroupsTypesHPlus3.Object
		buffer.writei32(riddenObj.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_STOP_RIDING)
		SoundInit.stop_shell_music()
		m.riddenObj = nil
	end
end

-- from src/game/interaction.c:mario_grab_used_object L288-293
function interaction.mario_grab_used_object(m: GroupsTypesHPlus3.MarioState)
	if m.heldObj == nil then
		m.heldObj = m.usedObj
		ObjectHelpers.obj_set_held_state(m.usedObj :: GroupsTypesHPlus3.Object, BehaviorIds.bhvCarrySomething3)
	end
end

-- from src/game/interaction.c:mario_drop_held_object L295-314
function interaction.mario_drop_held_object(m: GroupsTypesHPlus3.MarioState)
	if m.heldObj ~= nil then
		const heldObj = m.heldObj :: GroupsTypesHPlus3.Object
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		if heldObj.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvKoopaShellUnderwater) then
			SoundInit.stop_shell_music()
		end

		ObjectHelpers.obj_set_held_state(heldObj, BehaviorIds.bhvCarrySomething4)

		-- ! When dropping an object instead of throwing it, it will be put at Mario's
		-- y-positon instead of the HOLP's y-position. This fact is often exploited when
		-- cloning objects.
		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosX, marioBodyState.heldObjLastPosition[1])
		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosY, m.pos[2])
		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosZ, marioBodyState.heldObjLastPosition[3])

		buffer.writei32(heldObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, m.faceAngle[2])

		m.heldObj = nil
	end
end

-- from src/game/interaction.c:mario_throw_held_object L316-332
function interaction.mario_throw_held_object(m: GroupsTypesHPlus3.MarioState)
	if m.heldObj ~= nil then
		const heldObj = m.heldObj :: GroupsTypesHPlus3.Object
		const marioBodyState = m.marioBodyState :: GroupsTypesHPlus3.MarioBodyState

		if heldObj.behavior == Memory.segmented_to_virtual(BehaviorIds.bhvKoopaShellUnderwater) then
			SoundInit.stop_shell_music()
		end

		ObjectHelpers.obj_set_held_state(heldObj, BehaviorIds.bhvCarrySomething5)

		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosX, F32(marioBodyState.heldObjLastPosition[1] + 32 * Registry.Members.src__engine__math_util_h.sins(m.faceAngle[2])))
		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosY, marioBodyState.heldObjLastPosition[2])
		buffer.writef32(heldObj.rawData, IncludeObjectFieldsH.oPosZ, F32(marioBodyState.heldObjLastPosition[3] + 32 * Registry.Members.src__engine__math_util_h.coss(m.faceAngle[2])))

		buffer.writei32(heldObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, m.faceAngle[2])

		m.heldObj = nil
	end
end

-- from src/game/interaction.c:mario_stop_riding_and_holding L334-342
function interaction.mario_stop_riding_and_holding(m: GroupsTypesHPlus3.MarioState)
	interaction.mario_drop_held_object(m)
	interaction.mario_stop_riding_object(m)

	if m.action == IncludeSm64H.ACT_RIDING_HOOT then
		const usedObj = m.usedObj :: GroupsTypesHPlus3.Object
		buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oInteractStatus, IncludePRUltratypesH.FALSE)
		buffer.writei32(usedObj.rawData, IncludeObjectFieldsH.oHootMarioReleaseTime, GameInit.gGlobalTimer)
	end
end

-- from src/game/interaction.c:does_mario_have_normal_cap_on_head L344-346
function interaction.does_mario_have_normal_cap_on_head(m: GroupsTypesHPlus3.MarioState): number
	return if bit32.band(m.flags, bit32.bor(IncludeSm64H.MARIO_CAPS, IncludeSm64H.MARIO_CAP_ON_HEAD)) == bit32.bor(IncludeSm64H.MARIO_NORMAL_CAP, IncludeSm64H.MARIO_CAP_ON_HEAD) then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:mario_blow_off_cap L348-366
function interaction.mario_blow_off_cap(m: GroupsTypesHPlus3.MarioState, capSpeed: number)
	capSpeed = F32(capSpeed)
	if interaction.does_mario_have_normal_cap_on_head(m) ~= 0 then
		SaveFile.save_file_set_cap_pos(m.pos[1], m.pos[2], m.pos[3])

		m.flags = bit32.band(m.flags, bit32.bnot(bit32.bor(IncludeSm64H.MARIO_NORMAL_CAP, IncludeSm64H.MARIO_CAP_ON_HEAD)))

		const capObject = ObjectHelpers.spawn_object(m.marioObj :: GroupsTypesHPlus3.Object, IncludeModelIdsH.MODEL_MARIOS_CAP, BehaviorIds.bhvNormalCap)

		buffer.writef32(capObject.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(capObject.rawData, IncludeObjectFieldsH.oPosY) + (if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SHORT_HITBOX) then 120 else 180)))
		buffer.writef32(capObject.rawData, IncludeObjectFieldsH.oForwardVel, capSpeed)
		buffer.writei32(capObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S16(m.faceAngle[2] + 0x400))

		if m.forwardVel < 0 then
			buffer.writei32(capObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S16(buffer.readi32(capObject.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000))
		end
	end
end

-- from src/game/interaction.c:mario_lose_cap_to_enemy L368-378
function interaction.mario_lose_cap_to_enemy(arg: number): number
	local wasWearingCap = IncludePRUltratypesH.FALSE

	if interaction.does_mario_have_normal_cap_on_head(LevelUpdate.gMarioState) ~= 0 then
		SaveFile.save_file_set_flags(if arg == 1 then SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO else SaveFileH.SAVE_FLAG_CAP_ON_UKIKI)
		LevelUpdate.gMarioState.flags = bit32.band(LevelUpdate.gMarioState.flags, bit32.bnot(bit32.bor(IncludeSm64H.MARIO_NORMAL_CAP, IncludeSm64H.MARIO_CAP_ON_HEAD)))
		wasWearingCap = IncludePRUltratypesH.TRUE
	end

	return wasWearingCap
end

-- from src/game/interaction.c:mario_retrieve_cap L380-385
function interaction.mario_retrieve_cap()
	interaction.mario_drop_held_object(LevelUpdate.gMarioState)
	SaveFile.save_file_clear_flags(bit32.bor(SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO, SaveFileH.SAVE_FLAG_CAP_ON_UKIKI))
	LevelUpdate.gMarioState.flags = bit32.band(LevelUpdate.gMarioState.flags, bit32.bnot(IncludeSm64H.MARIO_CAP_ON_HEAD))
	LevelUpdate.gMarioState.flags = bit32.bor(LevelUpdate.gMarioState.flags, bit32.bor(IncludeSm64H.MARIO_NORMAL_CAP, IncludeSm64H.MARIO_CAP_IN_HAND))
end

-- from src/game/interaction.c:able_to_grab_object L387-401
function interaction.able_to_grab_object(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	const action = m.action

	if action == IncludeSm64H.ACT_DIVE_SLIDE or action == IncludeSm64H.ACT_DIVE then
		if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO) then
			return IncludePRUltratypesH.TRUE
		end
	elseif action == IncludeSm64H.ACT_PUNCHING or action == IncludeSm64H.ACT_MOVE_PUNCHING then
		if m.actionArg < 2 then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:mario_get_collided_object L403-416
function interaction.mario_get_collided_object(m: GroupsTypesHPlus3.MarioState, interactType: number): GroupsTypesHPlus3.Object?
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	for i = 0, marioObj.numCollidedObjs - 1 do
		const object = marioObj.collidedObjs[i + 1] :: GroupsTypesHPlus3.Object

		if buffer.readu32(object.rawData, IncludeObjectFieldsH.oInteractType) == interactType then
			return object
		end
	end

	return nil
end

-- from src/game/interaction.c:mario_check_object_grab L418-448
function interaction.mario_check_object_grab(m: GroupsTypesHPlus3.MarioState): number
	local result = IncludePRUltratypesH.FALSE

	if bit32.btest(m.input, IncludeSm64H.INPUT_INTERACT_OBJ_GRABBABLE) then
		const interactObj = m.interactObj :: GroupsTypesHPlus3.Object
		const script = Memory.virtual_to_segmented(0x13, interactObj.behavior :: number)

		if script == BehaviorIds.bhvBowser then
			const facingDYaw = S16(m.faceAngle[2] - buffer.readi32(interactObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
			if facingDYaw >= -0x5555 and facingDYaw <= 0x5555 then
				m.faceAngle[2] = S16(buffer.readi32(interactObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
				m.usedObj = m.interactObj
				result = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_PICKING_UP_BOWSER, 0)
			end
		else
			const facingDYaw = S16(interaction.mario_obj_angle_to_object(m, interactObj) - m.faceAngle[2])
			if facingDYaw >= -0x2AAA and facingDYaw <= 0x2AAA then
				m.usedObj = m.interactObj

				if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
					Registry.Members.src__game__mario.set_mario_action(m, if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_DIVING) then IncludeSm64H.ACT_DIVE_PICKING_UP else IncludeSm64H.ACT_PICKING_UP, 0)
				end

				result = IncludePRUltratypesH.TRUE
			end
		end
	end

	return result
end

-- from src/game/interaction.c:bully_knock_back_mario L450-513
function interaction.bully_knock_back_mario(mario: GroupsTypesHPlus3.MarioState): number
	const bully = mario.interactObj :: GroupsTypesHPlus3.Object
	const bullyToMarioRatio = F32(F32(bully.hitboxRadius * 3) / 53)
	const marioToBullyRatio = F32(53 / bully.hitboxRadius)

	Registry.Members.src__game__mario_step.init_bully_collision_data(BullyCollisionMario, mario.pos[1], mario.pos[3], mario.forwardVel, mario.faceAngle[2], bullyToMarioRatio, 52)
	Registry.Members.src__game__mario_step.init_bully_collision_data(BullyCollisionBully, buffer.readf32(bully.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(bully.rawData, IncludeObjectFieldsH.oPosZ), buffer.readf32(bully.rawData, IncludeObjectFieldsH.oForwardVel), S16(buffer.readi32(bully.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), marioToBullyRatio, F32(bully.hitboxRadius + 2))

	if mario.forwardVel ~= 0 then
		Registry.Members.src__game__mario_step.transfer_bully_speed(BullyCollisionMario, BullyCollisionBully)
	else
		Registry.Members.src__game__mario_step.transfer_bully_speed(BullyCollisionBully, BullyCollisionMario)
	end

	const newMarioYaw = SrcEngineMathUtil.atan2s(BullyCollisionMario.velZ, BullyCollisionMario.velX)
	const newBullyYaw = SrcEngineMathUtil.atan2s(BullyCollisionBully.velZ, BullyCollisionBully.velX)

	const marioDYaw = S16(newMarioYaw - mario.faceAngle[2])
	local bonkAction = 0

	mario.faceAngle[2] = newMarioYaw
	mario.forwardVel = F32(math.sqrt(F32(F32(BullyCollisionMario.velX * BullyCollisionMario.velX) + F32(BullyCollisionMario.velZ * BullyCollisionMario.velZ))))
	mario.pos[1] = BullyCollisionMario.posX
	mario.pos[3] = BullyCollisionMario.posZ

	buffer.writei32(bully.rawData, IncludeObjectFieldsH.oMoveAngleYaw, newBullyYaw)
	buffer.writef32(bully.rawData, IncludeObjectFieldsH.oForwardVel, F32(math.sqrt(F32(F32(BullyCollisionBully.velX * BullyCollisionBully.velX) + F32(BullyCollisionBully.velZ * BullyCollisionBully.velZ)))))
	buffer.writef32(bully.rawData, IncludeObjectFieldsH.oPosX, BullyCollisionBully.posX)
	buffer.writef32(bully.rawData, IncludeObjectFieldsH.oPosZ, BullyCollisionBully.posZ)

	if marioDYaw < -0x4000 or marioDYaw > 0x4000 then
		mario.faceAngle[2] = S16(mario.faceAngle[2] + 0x8000)
		mario.forwardVel *= -1

		if bit32.btest(mario.action, IncludeSm64H.ACT_FLAG_AIR) then
			bonkAction = IncludeSm64H.ACT_BACKWARD_AIR_KB
		else
			bonkAction = IncludeSm64H.ACT_SOFT_BACKWARD_GROUND_KB
		end
	else
		if bit32.btest(mario.action, IncludeSm64H.ACT_FLAG_AIR) then
			bonkAction = IncludeSm64H.ACT_FORWARD_AIR_KB
		else
			bonkAction = IncludeSm64H.ACT_SOFT_FORWARD_GROUND_KB
		end
	end

	return bonkAction
end

-- from src/game/interaction.c:bounce_off_object L515-522
function interaction.bounce_off_object(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object, velY: number)
	velY = F32(velY)
	m.pos[2] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + o.hitboxHeight)
	m.vel[2] = velY

	m.flags = bit32.band(m.flags, bit32.bnot(IncludeSm64H.MARIO_UNKNOWN_08))

	Audio.play_sound(IncludeSoundsH.SOUND_ACTION_BOUNCE_OFF_OBJECT, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
end

-- from src/game/interaction.c:hit_object_from_below L524-527
function interaction.hit_object_from_below(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object)
	m.vel[2] = 0
	Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_HIT_FROM_BELOW)
end

-- from src/game/interaction.c:unused_determine_knockback_action L529-557
function interaction.unused_determine_knockback_action(m: GroupsTypesHPlus3.MarioState): number
	const angleToObject = interaction.mario_obj_angle_to_object(m, m.interactObj :: GroupsTypesHPlus3.Object)
	const facingDYaw = S16(angleToObject - m.faceAngle[2])

	if m.forwardVel < 16 then
		m.forwardVel = 16
	end

	m.faceAngle[2] = angleToObject

	local bonkAction = 0
	if facingDYaw >= -0x4000 and facingDYaw <= 0x4000 then
		m.forwardVel *= -1
		if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_AIR, IncludeSm64H.ACT_FLAG_ON_POLE, IncludeSm64H.ACT_FLAG_HANGING)) then
			bonkAction = IncludeSm64H.ACT_BACKWARD_AIR_KB
		else
			bonkAction = IncludeSm64H.ACT_SOFT_BACKWARD_GROUND_KB
		end
	else
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_AIR, IncludeSm64H.ACT_FLAG_ON_POLE, IncludeSm64H.ACT_FLAG_HANGING)) then
			bonkAction = IncludeSm64H.ACT_FORWARD_AIR_KB
		else
			bonkAction = IncludeSm64H.ACT_SOFT_FORWARD_GROUND_KB
		end
	end

	return bonkAction
end

-- from src/game/interaction.c:determine_knockback_action L559-614
function interaction.determine_knockback_action(m: GroupsTypesHPlus3.MarioState, arg: number): number
	const interactObj = m.interactObj :: GroupsTypesHPlus3.Object
	local terrainIndex = 0
	local strengthIndex = 0

	const angleToObject = interaction.mario_obj_angle_to_object(m, interactObj)
	const facingDYaw = S16(angleToObject - m.faceAngle[2])
	const remainingHealth = S16(m.health - 0x40 * m.hurtCounter)

	if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
		terrainIndex = 2
	elseif bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_AIR, IncludeSm64H.ACT_FLAG_ON_POLE, IncludeSm64H.ACT_FLAG_HANGING)) then
		terrainIndex = 1
	end

	if remainingHealth < 0x100 then
		strengthIndex = 2
	elseif buffer.readi32(interactObj.rawData, IncludeObjectFieldsH.oDamageOrCoinValue) >= 4 then
		strengthIndex = 2
	elseif buffer.readi32(interactObj.rawData, IncludeObjectFieldsH.oDamageOrCoinValue) >= 2 then
		strengthIndex = 1
	end

	m.faceAngle[2] = angleToObject

	if terrainIndex == 2 then
		if m.forwardVel < 28 then
			Registry.Members.src__game__mario.mario_set_forward_vel(m, 28)
		end

		if m.pos[2] >= buffer.readf32(interactObj.rawData, IncludeObjectFieldsH.oPosY) then
			if m.vel[2] < 20 then
				m.vel[2] = 20
			end
		else
			if m.vel[2] > 0 then
				m.vel[2] = 0
			end
		end
	else
		if m.forwardVel < 16 then
			Registry.Members.src__game__mario.mario_set_forward_vel(m, 16)
		end
	end

	local bonkAction = 0
	if -0x4000 <= facingDYaw and facingDYaw <= 0x4000 then
		m.forwardVel *= -1
		bonkAction = interaction.sBackwardKnockbackActions[terrainIndex + 1][strengthIndex + 1]
	else
		m.faceAngle[2] = S16(m.faceAngle[2] + 0x8000)
		bonkAction = interaction.sForwardKnockbackActions[terrainIndex + 1][strengthIndex + 1]
	end

	return bonkAction
end

-- from src/game/interaction.c:push_mario_out_of_object L616-648
function interaction.push_mario_out_of_object(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object, padding: number)
	padding = F32(padding)
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	const minDistance = F32(F32(o.hitboxRadius + marioObj.hitboxRadius) + padding)

	const offsetX = F32(m.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const offsetZ = F32(m.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const distance = F32(math.sqrt(F32(F32(offsetX * offsetX) + F32(offsetZ * offsetZ))))

	if distance < minDistance then
		local pushAngle = 0

		if distance == 0 then
			pushAngle = m.faceAngle[2]
		else
			pushAngle = SrcEngineMathUtil.atan2s(offsetZ, offsetX)
		end

		NewMarioX[1] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(minDistance * Registry.Members.src__engine__math_util_h.sins(pushAngle)))
		NewMarioZ[1] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(minDistance * Registry.Members.src__engine__math_util_h.coss(pushAngle)))
		MarioPosY[1] = m.pos[2]

		Registry.Members.src__engine__surface_collision.f32_find_wall_collision(NewMarioX, MarioPosY, NewMarioZ, 60, 50)
		m.pos[2] = MarioPosY[1]

		Registry.Members.src__engine__surface_collision.find_floor(NewMarioX[1], m.pos[2], NewMarioZ[1], FloorSurface)
		if FloorSurface[1] ~= nil then
			m.pos[1] = NewMarioX[1]
			m.pos[3] = NewMarioZ[1]
		end
	end
end

-- from src/game/interaction.c:bounce_back_from_attack L650-669
function interaction.bounce_back_from_attack(m: GroupsTypesHPlus3.MarioState, interactType: number)
	if bit32.btest(interactType, bit32.bor(interaction.INT_PUNCH, interaction.INT_KICK, interaction.INT_TRIP)) then
		if m.action == IncludeSm64H.ACT_PUNCHING then
			m.action = IncludeSm64H.ACT_MOVE_PUNCHING
		end

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
			Registry.Members.src__game__mario.mario_set_forward_vel(m, -16)
		else
			Registry.Members.src__game__mario.mario_set_forward_vel(m, -48)
		end

		Camera.set_camera_shake_from_hit(GroupsTypesHPlus3.SHAKE_ATTACK)
		m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_TRIANGLE)
	end

	if bit32.btest(interactType, bit32.bor(interaction.INT_PUNCH, interaction.INT_KICK, interaction.INT_TRIP, interaction.INT_FAST_ATTACK_OR_SHELL)) then
		Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HIT_2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
	end
end

-- from src/game/interaction.c:should_push_or_pull_door L671-678
function interaction.should_push_or_pull_door(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	const dx = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - m.pos[1])
	const dz = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - m.pos[3])

	const dYaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - SrcEngineMathUtil.atan2s(dz, dx))

	return if dYaw >= -0x4000 and dYaw <= 0x4000 then 0x00000001 else 0x00000002
end

-- from src/game/interaction.c:take_damage_from_interact_object L680-708
function interaction.take_damage_from_interact_object(m: GroupsTypesHPlus3.MarioState): number
	const interactObj = m.interactObj :: GroupsTypesHPlus3.Object
	local damage = buffer.readi32(interactObj.rawData, IncludeObjectFieldsH.oDamageOrCoinValue)
	local shake = GroupsTypesHPlus3.SHAKE_SMALL_DAMAGE

	if damage >= 4 then
		shake = GroupsTypesHPlus3.SHAKE_LARGE_DAMAGE
	elseif damage >= 2 then
		shake = GroupsTypesHPlus3.SHAKE_MED_DAMAGE
	end

	if not bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then
		damage += TruncS32((damage + 1) / 2)
	end

	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		damage = 0
	end

	m.hurtCounter = U8(m.hurtCounter + 4 * damage)

	Camera.set_camera_shake_from_hit(shake)
	return damage
end

-- from src/game/interaction.c:take_damage_and_knock_back L710-734
function interaction.take_damage_and_knock_back(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	if interaction.sInvulnerable == 0 and not bit32.btest(m.flags, IncludeSm64H.MARIO_VANISH_CAP) and not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_ATTACKED_MARIO))
		m.interactObj = o

		const damage = interaction.take_damage_from_interact_object(m)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_BIG_KNOCKBACK) then
			m.forwardVel = 40
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue) > 0 then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ATTACKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

		const knockbackAction = interaction.determine_knockback_action(m, buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))
		const cancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, knockbackAction, damage)
		return cancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:reset_mario_pitch L736-741
function interaction.reset_mario_pitch(m: GroupsTypesHPlus3.MarioState)
	if m.action == IncludeSm64H.ACT_WATER_JUMP or m.action == IncludeSm64H.ACT_SHOT_FROM_CANNON or m.action == IncludeSm64H.ACT_FLYING then
		const area = m.area :: GroupsTypesHPlus3.Area
		const camera = area.camera :: GroupsTypesHPlus3.Camera

		Camera.set_camera_mode(camera, camera.defMode, 1)
		m.faceAngle[1] = 0
	end
end

-- from src/game/interaction.c:interact_coin L743-761
function interaction.interact_coin(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	m.numCoins = S16(m.numCoins + buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))
	m.healCounter = U8(m.healCounter + 4 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)

	if IncludeCourseTableH.COURSE_IS_MAIN_COURSE(Area.gCurrCourseNum) ~= 0 and m.numCoins - buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue) < 100 and m.numCoins >= 100 then
		Registry.Members.src__game__behaviors__sparkle_spawn_star_inc.bhv_spawn_star_no_level_exit(IncludeObjectConstantsH.STAR_INDEX_100_COINS)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_water_ring L763-767
function interaction.interact_water_ring(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	m.healCounter = U8(m.healCounter + 4 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_star_or_key L769-835
function interaction.interact_star_or_key(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local starGrabAction = IncludeSm64H.ACT_STAR_DANCE_EXIT
	const noExit = if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NO_EXIT) then 1 else 0
	const grandStar = if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRAND_STAR) then 1 else 0

	if m.health >= 0x100 then
		interaction.mario_stop_riding_and_holding(m)

		if noExit == 0 then
			m.hurtCounter = 0
			m.healCounter = 0
			if m.capTimer > 1 then
				m.capTimer = 1
			end
		end

		if noExit ~= 0 then
			starGrabAction = IncludeSm64H.ACT_STAR_DANCE_NO_EXIT
		end

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SWIMMING) then
			starGrabAction = IncludeSm64H.ACT_STAR_DANCE_WATER
		end

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_METAL_WATER) then
			starGrabAction = IncludeSm64H.ACT_STAR_DANCE_WATER
		end

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
			starGrabAction = IncludeSm64H.ACT_FALL_AFTER_STAR_GRAB
		end

		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvStarKeyCollectionPuffSpawner)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		const starIndex = bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 24, 0x1F)
		SaveFile.save_file_collect_star_or_key(m.numCoins, starIndex)

		m.numStars = S16(SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1))

		if noExit == 0 then
			Audio.drop_queued_background_music()
			SoundInit.fadeout_level_music(126)
		end

		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

		if grandStar ~= 0 then
			const jumboCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_JUMBO_STAR_CUTSCENE, 0)
			return jumboCancel
		end

		const starCancel = Registry.Members.src__game__mario.set_mario_action(m, starGrabAction, noExit + 2 * grandStar)
		return starCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_bbh_entrance L837-853
function interaction.interact_bbh_entrance(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if m.action ~= IncludeSm64H.ACT_BBH_ENTER_SPIN and m.action ~= IncludeSm64H.ACT_BBH_ENTER_JUMP then
		interaction.mario_stop_riding_and_holding(m)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
			const spinCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_BBH_ENTER_SPIN, 0)
			return spinCancel
		end

		const jumpCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_BBH_ENTER_JUMP, 0)
		return jumpCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_warp L855-901
function interaction.interact_warp(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_FADING_WARP) then
		const action = m.action

		if action == IncludeSm64H.ACT_TELEPORT_FADE_IN then
			interaction.sJustTeleported = IncludePRUltratypesH.TRUE
		elseif interaction.sJustTeleported == 0 then
			if action == IncludeSm64H.ACT_IDLE or action == IncludeSm64H.ACT_PANTING or action == IncludeSm64H.ACT_STANDING_AGAINST_WALL or action == IncludeSm64H.ACT_CROUCHING then
				m.interactObj = o
				m.usedObj = o

				interaction.sJustTeleported = IncludePRUltratypesH.TRUE
				const fadeOutCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_TELEPORT_FADE_OUT, 0)
				return fadeOutCancel
			end
		end
	else
		if m.action ~= IncludeSm64H.ACT_EMERGE_FROM_PIPE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
			m.interactObj = o
			m.usedObj = o

			Audio.play_sound(if o.collisionData == Memory.segmented_to_virtual(0x03009AC8) then IncludeSoundsH.SOUND_MENU_ENTER_PIPE else IncludeSoundsH.SOUND_MENU_ENTER_HOLE, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

			interaction.mario_stop_riding_object(m)
			const disappearCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_DISAPPEARED, bit32.lshift(LevelUpdateH.WARP_OP_WARP_OBJECT, 16) + 2)
			return disappearCancel
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_warp_door L903-957
function interaction.interact_warp_door(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local doorAction = 0
	const saveFlags = SaveFile.save_file_get_flags()
	const warpDoorId = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 24)
	local actionArg = 0

	if m.action == IncludeSm64H.ACT_WALKING or m.action == IncludeSm64H.ACT_DECELERATING then
		if warpDoorId == 1 and not bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR) then
			if not bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_HAVE_KEY_2) then
				if interaction.sDisplayingDoorText == 0 then
					Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_READING_AUTOMATIC_DIALOG, if bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_HAVE_KEY_1) then IncludeDialogIdsH.DIALOG_023 else IncludeDialogIdsH.DIALOG_022)
				end
				interaction.sDisplayingDoorText = IncludePRUltratypesH.TRUE

				return IncludePRUltratypesH.FALSE
			end

			doorAction = IncludeSm64H.ACT_UNLOCKING_KEY_DOOR
		end

		if warpDoorId == 2 and not bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_UNLOCKED_BASEMENT_DOOR) then
			if not bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_HAVE_KEY_1) then
				if interaction.sDisplayingDoorText == 0 then
					Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_READING_AUTOMATIC_DIALOG, if bit32.btest(saveFlags, SaveFileH.SAVE_FLAG_HAVE_KEY_2) then IncludeDialogIdsH.DIALOG_023 else IncludeDialogIdsH.DIALOG_022)
				end
				interaction.sDisplayingDoorText = IncludePRUltratypesH.TRUE

				return IncludePRUltratypesH.FALSE
			end

			doorAction = IncludeSm64H.ACT_UNLOCKING_KEY_DOOR
		end

		if m.action == IncludeSm64H.ACT_WALKING or m.action == IncludeSm64H.ACT_DECELERATING then
			actionArg = interaction.should_push_or_pull_door(m, o) + 0x00000004

			if doorAction == 0 then
				if bit32.btest(actionArg, 0x00000001) then
					doorAction = IncludeSm64H.ACT_PULLING_DOOR
				else
					doorAction = IncludeSm64H.ACT_PUSHING_DOOR
				end
			end

			m.interactObj = o
			m.usedObj = o
			const doorCancel = Registry.Members.src__game__mario.set_mario_action(m, doorAction, actionArg)
			return doorCancel
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:get_door_save_file_flag L959-997
function interaction.get_door_save_file_flag(door: GroupsTypesHPlus3.Object): number
	local saveFileFlag = 0
	const requiredNumStars = buffer.readi32(door.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 24

	const isCCMDoor = buffer.readf32(door.rawData, IncludeObjectFieldsH.oPosX) < 0
	const isPSSDoor = buffer.readf32(door.rawData, IncludeObjectFieldsH.oPosY) > 500

	if requiredNumStars == 1 then
		if isPSSDoor then
			saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_PSS_DOOR
		else
			saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_WF_DOOR
		end
	elseif requiredNumStars == 3 then
		if isCCMDoor then
			saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_CCM_DOOR
		else
			saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_JRB_DOOR
		end
	elseif requiredNumStars == 8 then
		saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_BITDW_DOOR
	elseif requiredNumStars == 30 then
		saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_BITFS_DOOR
	elseif requiredNumStars == 50 then
		saveFileFlag = SaveFileH.SAVE_FLAG_UNLOCKED_50_STAR_DOOR
	end

	return saveFileFlag
end

-- from src/game/interaction.c:interact_door L999-1064
function interaction.interact_door(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const requiredNumStars = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams) // 2 ^ 24)
	const numStars = S16(SaveFile.save_file_get_total_star_count(Area.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_MIN - 1, IncludeCourseTableH.COURSE_MAX - 1))

	if m.action == IncludeSm64H.ACT_WALKING or m.action == IncludeSm64H.ACT_DECELERATING then
		if numStars >= requiredNumStars then
			const actionArg = interaction.should_push_or_pull_door(m, o)
			local enterDoorAction = if bit32.btest(actionArg, 0x00000001) then IncludeSm64H.ACT_PULLING_DOOR else IncludeSm64H.ACT_PUSHING_DOOR
			const doorSaveFileFlag = interaction.get_door_save_file_flag(o)

			m.interactObj = o
			m.usedObj = o

			if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_STAR_DOOR) then
				enterDoorAction = IncludeSm64H.ACT_ENTERING_STAR_DOOR
			end

			if doorSaveFileFlag ~= 0 and not bit32.btest(SaveFile.save_file_get_flags(), doorSaveFileFlag) then
				enterDoorAction = IncludeSm64H.ACT_UNLOCKING_STAR_DOOR
			end

			const doorCancel = Registry.Members.src__game__mario.set_mario_action(m, enterDoorAction, actionArg)
			return doorCancel
		elseif interaction.sDisplayingDoorText == 0 then
			local text = bit32.lshift(IncludeDialogIdsH.DIALOG_022, 16)

			if requiredNumStars == 1 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_024, 16)
			elseif requiredNumStars == 3 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_025, 16)
			elseif requiredNumStars == 8 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_026, 16)
			elseif requiredNumStars == 30 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_027, 16)
			elseif requiredNumStars == 50 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_028, 16)
			elseif requiredNumStars == 70 then
				text = bit32.lshift(IncludeDialogIdsH.DIALOG_029, 16)
			end

			text += requiredNumStars - numStars

			interaction.sDisplayingDoorText = IncludePRUltratypesH.TRUE
			const textCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_READING_AUTOMATIC_DIALOG, text)
			return textCancel
		end
	elseif m.action == IncludeSm64H.ACT_IDLE and interaction.sDisplayingDoorText == IncludePRUltratypesH.TRUE and requiredNumStars == 70 then
		m.interactObj = o
		m.usedObj = o
		const starDoorCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_ENTERING_STAR_DOOR, interaction.should_push_or_pull_door(m, o))
		return starDoorCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_cannon_base L1066-1076
function interaction.interact_cannon_base(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if m.action ~= IncludeSm64H.ACT_IN_CANNON then
		interaction.mario_stop_riding_and_holding(m)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		const cannonCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_IN_CANNON, 0)
		return cannonCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_igloo_barrier L1078-1086
function interaction.interact_igloo_barrier(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	m.interactObj = o
	m.usedObj = o
	interaction.push_mario_out_of_object(m, o, 5)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_tornado L1088-1111
function interaction.interact_tornado(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.action ~= IncludeSm64H.ACT_TORNADO_TWIRLING and m.action ~= IncludeSm64H.ACT_SQUISHED then
		interaction.mario_stop_riding_and_holding(m)
		Registry.Members.src__game__mario.mario_set_forward_vel(m, 0)
		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoYawVel, 0x400)
		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioTornadoPosY, F32(m.pos[2] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))

		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, marioObj.header.gfx.cameraToObject)

		const tornadoCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_TORNADO_TWIRLING, if m.action == IncludeSm64H.ACT_TWIRLING then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE)
		return tornadoCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_whirlpool L1113-1134
function interaction.interact_whirlpool(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

	if m.action ~= IncludeSm64H.ACT_CAUGHT_IN_WHIRLPOOL then
		interaction.mario_stop_riding_and_holding(m)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		m.forwardVel = 0

		buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioWhirlpoolPosY, F32(m.pos[2] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))

		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, marioObj.header.gfx.cameraToObject)

		const whirlpoolCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_CAUGHT_IN_WHIRLPOOL, 0)
		return whirlpoolCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_strong_wind L1136-1156
function interaction.interact_strong_wind(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if m.action ~= IncludeSm64H.ACT_GETTING_BLOWN then
		interaction.mario_stop_riding_and_holding(m)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		m.usedObj = o

		m.faceAngle[2] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000)
		m.gettingBlownGravity = F32(0.4)
		m.forwardVel = -24
		m.vel[2] = 12

		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

		const windCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_GETTING_BLOWN, 0)
		return windCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_flame L1158-1186
function interaction.interact_flame(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local burningAction = IncludeSm64H.ACT_BURNING_JUMP

	if interaction.sInvulnerable == 0 and not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) and not bit32.btest(m.flags, IncludeSm64H.MARIO_VANISH_CAP) and not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o

		if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) or F32(m.waterLevel - m.pos[2]) > 50 then
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_FLAME_OUT, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		else
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioBurnTimer, 0)
			Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ON_FIRE, marioObj.header.gfx.cameraToObject)

			if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) and m.vel[2] <= 0 then
				burningAction = IncludeSm64H.ACT_BURNING_FALL
			end

			const cancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, burningAction, 1)
			return cancel
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_snufit_bullet L1188-1211
function interaction.interact_snufit_bullet(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if interaction.sInvulnerable == 0 and not bit32.btest(m.flags, IncludeSm64H.MARIO_VANISH_CAP) then
		if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_WAS_ATTACKED))
			Audio.play_sound(IncludeSoundsH.SOUND_ACTION_UNKNOWN458, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_ATTACKED_MARIO))
			m.interactObj = o
			interaction.take_damage_from_interact_object(m)

			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ATTACKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
			Registry.Members.src__game__mario.update_mario_sound_and_camera(m)

			const knockbackAction = interaction.determine_knockback_action(m, buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))
			const snufitCancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, knockbackAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oDamageOrCoinValue))
			return snufitCancel
		end
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_clam_or_bubba L1213-1227
function interaction.interact_clam_or_bubba(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_EATS_MARIO) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.interactObj = o
		const bubbaCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_EATEN_BY_BUBBA, 0)
		return bubbaCancel
	elseif interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/interaction.c:interact_bully L1229-1274
function interaction.interact_bully(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local interactFlags = 0
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		interactFlags = interaction.INT_FAST_ATTACK_OR_SHELL
	else
		interactFlags = interaction.determine_interaction(m, o)
	end

	m.interactObj = o

	if bit32.btest(interactFlags, interaction.INT_ATTACK_NOT_FROM_BELOW) then
		interaction.push_mario_out_of_object(m, o, 5)

		m.forwardVel = -16
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, m.faceAngle[2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(3392 / o.hitboxRadius))

		interaction.attack_object(o, interactFlags)
		interaction.bounce_back_from_attack(m, interactFlags)
		return IncludePRUltratypesH.TRUE
	elseif interaction.sInvulnerable == 0 and not bit32.btest(m.flags, IncludeSm64H.MARIO_VANISH_CAP) and not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)
		m.invincTimer = 2

		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_EEUH, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Audio.play_sound(IncludeSoundsH.SOUND_OBJ_BULLY_METAL, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		interaction.push_mario_out_of_object(m, o, 5)
		Registry.Members.src__game__mario.drop_and_set_mario_action(m, interaction.bully_knock_back_mario(m), 0)

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_shock L1276-1303
function interaction.interact_shock(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if interaction.sInvulnerable == 0 and not bit32.btest(m.flags, IncludeSm64H.MARIO_VANISH_CAP) and not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		const actionArg = if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_AIR, IncludeSm64H.ACT_FLAG_ON_POLE, IncludeSm64H.ACT_FLAG_HANGING)) then 0 else 1

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_ATTACKED_MARIO))
		m.interactObj = o

		interaction.take_damage_from_interact_object(m)
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_ATTACKED, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		if bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_SWIMMING, IncludeSm64H.ACT_FLAG_METAL_WATER)) then
			const waterShockCancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_WATER_SHOCKED, 0)
			return waterShockCancel
		else
			Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
			const shockCancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_SHOCKED, actionArg)
			return shockCancel
		end
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_stub L1305-1310
function interaction.interact_stub(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_mr_blizzard L1312-1322
function interaction.interact_mr_blizzard(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_hit_from_below L1324-1366
function interaction.interact_hit_from_below(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local interactFlags = 0
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		interactFlags = interaction.INT_FAST_ATTACK_OR_SHELL
	else
		interactFlags = interaction.determine_interaction(m, o)
	end

	if bit32.btest(interactFlags, interaction.INT_ANY_ATTACK) then
		interaction.attack_object(o, interactFlags)
		interaction.bounce_back_from_attack(m, interactFlags)

		if bit32.btest(interactFlags, interaction.INT_HIT_FROM_BELOW) then
			interaction.hit_object_from_below(m, o)
		end

		if bit32.btest(interactFlags, interaction.INT_HIT_FROM_ABOVE) then
			if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_TWIRL_BOUNCE) then
				interaction.bounce_off_object(m, o, 80)
				interaction.reset_mario_pitch(m)

				Audio.play_sound(IncludeSoundsH.SOUND_MARIO_TWIRL_BOUNCE, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

				const twirlCancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_TWIRLING, 0)
				return twirlCancel
			else
				interaction.bounce_off_object(m, o, 30)
			end
		end
	elseif interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_bounce_top L1368-1404
function interaction.interact_bounce_top(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local interactFlags = 0
	if bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
		interactFlags = interaction.INT_FAST_ATTACK_OR_SHELL
	else
		interactFlags = interaction.determine_interaction(m, o)
	end

	if bit32.btest(interactFlags, interaction.INT_ATTACK_NOT_FROM_BELOW) then
		interaction.attack_object(o, interactFlags)
		interaction.bounce_back_from_attack(m, interactFlags)

		if bit32.btest(interactFlags, interaction.INT_HIT_FROM_ABOVE) then
			if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_TWIRL_BOUNCE) then
				interaction.bounce_off_object(m, o, 80)
				interaction.reset_mario_pitch(m)

				Audio.play_sound(IncludeSoundsH.SOUND_MARIO_TWIRL_BOUNCE, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

				const bounceCancel = Registry.Members.src__game__mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_TWIRLING, 0)
				return bounceCancel
			else
				interaction.bounce_off_object(m, o, 30)
			end
		end
	elseif interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_unknown_08 L1406-1421
function interaction.interact_unknown_08(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const interactFlags = interaction.determine_interaction(m, o)

	if bit32.btest(interactFlags, interaction.INT_PUNCH) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_WAS_ATTACKED, InteractionH.ATTACK_PUNCH))
		interaction.bounce_back_from_attack(m, interactFlags)
	elseif interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_damage L1423-1433
function interaction.interact_damage(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if interaction.take_damage_and_knock_back(m, o) ~= 0 then
		return IncludePRUltratypesH.TRUE
	end

	if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_DELAY_INVINCIBILITY) then
		interaction.sDelayInvincTimer = IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_breakable L1435-1458
function interaction.interact_breakable(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const interactFlags = interaction.determine_interaction(m, o)

	if bit32.btest(interactFlags, interaction.INT_ATTACK_NOT_WEAK_FROM_ABOVE) then
		interaction.attack_object(o, interactFlags)
		interaction.bounce_back_from_attack(m, interactFlags)

		m.interactObj = o

		if interactFlags == interaction.INT_HIT_FROM_ABOVE then
			interaction.bounce_off_object(m, o, 30) --! Not in the 0x8F mask
		elseif interactFlags == interaction.INT_HIT_FROM_BELOW then
			interaction.hit_object_from_below(m, o)
		end

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_koopa_shell L1460-1484
function interaction.interact_koopa_shell(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) then
		const interactFlags = interaction.determine_interaction(m, o)

		if interactFlags == interaction.INT_HIT_FROM_ABOVE or m.action == IncludeSm64H.ACT_WALKING or m.action == IncludeSm64H.ACT_HOLD_WALKING then
			m.interactObj = o
			m.usedObj = o
			m.riddenObj = o

			interaction.attack_object(o, interactFlags)
			Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
			SoundInit.play_shell_music()
			interaction.mario_drop_held_object(m)

			-- ! Puts Mario in ground action even when in air, making it easy to
			-- escape air actions into crouch slide (shell cancel)
			const shellCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_RIDING_SHELL_GROUND, 0)
			return shellCancel
		end

		interaction.push_mario_out_of_object(m, o, 2)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:check_object_grab_mario L1486-1508
function interaction.check_object_grab_mario(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	if (not bit32.btest(m.action, bit32.bor(IncludeSm64H.ACT_FLAG_AIR, IncludeSm64H.ACT_FLAG_INVULNERABLE, IncludeSm64H.ACT_FLAG_ATTACKING)) or interaction.sInvulnerable == 0) and bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO) then
		if interaction.object_facing_mario(m, o, 0x2AAA) ~= 0 then
			interaction.mario_stop_riding_and_holding(m)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, bit32.bor(InteractionH.INT_STATUS_INTERACTED, InteractionH.INT_STATUS_GRABBED_MARIO))

			m.faceAngle[2] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
			m.interactObj = o
			m.usedObj = o

			Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_OOOF, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

			const grabbedCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_GRABBED, 0)
			return grabbedCancel
		end
	end

	interaction.push_mario_out_of_object(m, o, -5)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_pole L1510-1558
function interaction.interact_pole(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const actionId = bit32.band(m.action, IncludeSm64H.ACT_ID_MASK)

	if actionId >= 0x080 and actionId < 0x0A0 then
		if not bit32.btest(m.prevAction, IncludeSm64H.ACT_FLAG_ON_POLE) or m.usedObj ~= o then
			const lowSpeed = m.forwardVel <= 10
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

			interaction.mario_stop_riding_and_holding(m)

			m.interactObj = o
			m.usedObj = o
			m.vel[2] = 0
			m.forwardVel = 0

			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleUnk108, 0)
			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, 0)
			buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioPolePos, F32(m.pos[2] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))

			if lowSpeed then
				const slowCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_GRAB_POLE_SLOW, 0)
				return slowCancel
			end

			-- ! @bug Using m->forwardVel here is assumed to be 0.0f due to the set from earlier.
			--       This is fixed in the Shindou version.

			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioPoleYawVel, TruncS32(F32(F32(m.forwardVel * 0x100) + 0x1000)))

			interaction.reset_mario_pitch(m)

			const fastCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_GRAB_POLE_FAST, 0)
			return fastCancel
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_hoot L1560-1581
function interaction.interact_hoot(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const actionId = bit32.band(m.action, IncludeSm64H.ACT_ID_MASK)

	-- Can pause to advance the global timer without falling too far, allowing
	-- you to regrab after letting go.
	if actionId >= 0x080 and actionId < 0x098 and U32(GameInit.gGlobalTimer - buffer.readi32((m.usedObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oHootMarioReleaseTime)) > 30 then
		interaction.mario_stop_riding_and_holding(m)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, IncludePRUltratypesH.TRUE)
		m.interactObj = o
		m.usedObj = o

		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
		const hootCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_RIDING_HOOT, 0)
		return hootCancel
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_cap L1583-1634
function interaction.interact_cap(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const capFlag = interaction.get_mario_cap_flag(o)
	local capMusic = 0
	local capTime = 0

	if m.action ~= IncludeSm64H.ACT_GETTING_BLOWN and capFlag ~= 0 then
		m.interactObj = o
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)

		m.flags = bit32.band(m.flags, bit32.bnot(bit32.bor(IncludeSm64H.MARIO_CAP_ON_HEAD, IncludeSm64H.MARIO_CAP_IN_HAND)))
		m.flags = bit32.bor(m.flags, capFlag)

		if capFlag == IncludeSm64H.MARIO_VANISH_CAP then
			capTime = 600
			capMusic = bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_EVENT_POWERUP
		elseif capFlag == IncludeSm64H.MARIO_METAL_CAP then
			capTime = 600
			capMusic = bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_EVENT_METAL_CAP
		elseif capFlag == IncludeSm64H.MARIO_WING_CAP then
			capTime = 1800
			capMusic = bit32.lshift(4, 8) + IncludeSeqIdsH.SEQ_EVENT_POWERUP
		end

		if capTime > m.capTimer then
			m.capTimer = capTime
		end

		if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_IDLE) or m.action == IncludeSm64H.ACT_WALKING then
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_CAP_IN_HAND)
			Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_PUTTING_ON_CAP, 0)
		else
			m.flags = bit32.bor(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD)
		end

		Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		Audio.play_sound(IncludeSoundsH.SOUND_MARIO_HERE_WE_GO, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)

		if capMusic ~= 0 then
			SoundInit.play_cap_music(capMusic)
		end

		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_grabbable L1636-1667
function interaction.interact_grabbable(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	const script = Memory.virtual_to_segmented(0x13, o.behavior :: number)

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_KICKABLE) then
		const interactFlags = interaction.determine_interaction(m, o)
		if bit32.btest(interactFlags, bit32.bor(interaction.INT_KICK, interaction.INT_TRIP)) then
			interaction.attack_object(o, interactFlags)
			interaction.bounce_back_from_attack(m, interactFlags)
			return IncludePRUltratypesH.FALSE
		end
	end

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_GRABS_MARIO) then
		if interaction.check_object_grab_mario(m, interactType, o) ~= 0 then
			return IncludePRUltratypesH.TRUE
		end
	end

	if interaction.able_to_grab_object(m, o) ~= 0 then
		if not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NOT_GRABBABLE) then
			m.interactObj = o
			m.input = U16(bit32.bor(m.input, IncludeSm64H.INPUT_INTERACT_OBJ_GRABBABLE))
			return IncludePRUltratypesH.TRUE
		end
	end

	if script ~= BehaviorIds.bhvBowser then
		interaction.push_mario_out_of_object(m, o, -5)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:mario_can_talk L1669-1689
function interaction.mario_can_talk(m: GroupsTypesHPlus3.MarioState, arg: number): number
	if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_IDLE) then
		return IncludePRUltratypesH.TRUE
	end

	if m.action == IncludeSm64H.ACT_WALKING then
		if arg ~= 0 then
			return IncludePRUltratypesH.TRUE
		end

		const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
		const val6 = marioObj.header.gfx.animInfo.animID

		if val6 == 0x0080 or val6 == 0x007F or val6 == 0x006C then
			return IncludePRUltratypesH.TRUE
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:check_read_sign L1703-1721
function interaction.check_read_sign(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	if bit32.btest(m.input, interaction.READ_MASK) and interaction.mario_can_talk(m, 0) ~= 0 and interaction.object_facing_mario(m, o, interaction.SIGN_RANGE) ~= 0 then
		const facingDYaw = S16(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x8000) - m.faceAngle[2])

		if facingDYaw >= -interaction.SIGN_RANGE and facingDYaw <= interaction.SIGN_RANGE then
			const targetX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(105 * Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))))
			const targetZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(105 * Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))))
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object

			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDYaw, facingDYaw)
			buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosX, F32(targetX - m.pos[1]))
			buffer.writef32(marioObj.rawData, IncludeObjectFieldsH.oMarioReadingSignDPosZ, F32(targetZ - m.pos[3]))

			m.interactObj = o
			m.usedObj = o
			const signCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_READING_SIGN, 0)
			return signCancel
		end
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:check_npc_talk L1723-1739
function interaction.check_npc_talk(m: GroupsTypesHPlus3.MarioState, o: GroupsTypesHPlus3.Object): number
	if bit32.btest(m.input, interaction.READ_MASK) and interaction.mario_can_talk(m, 1) ~= 0 then
		const facingDYaw = S16(interaction.mario_obj_angle_to_object(m, o) - m.faceAngle[2])

		if facingDYaw >= -0x4000 and facingDYaw <= 0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, InteractionH.INT_STATUS_INTERACTED)

			m.interactObj = o
			m.usedObj = o

			interaction.push_mario_out_of_object(m, o, -10)
			const talkCancel = Registry.Members.src__game__mario.set_mario_action(m, IncludeSm64H.ACT_WAITING_FOR_DIALOG, 0)
			return talkCancel
		end
	end

	interaction.push_mario_out_of_object(m, o, -10)
	return IncludePRUltratypesH.FALSE
end

-- from src/game/interaction.c:interact_text L1741-1753
function interaction.interact_text(m: GroupsTypesHPlus3.MarioState, interactType: number, o: GroupsTypesHPlus3.Object): number
	local interact = IncludePRUltratypesH.FALSE

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_SIGN) then
		interact = interaction.check_read_sign(m, o)
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oInteractionSubtype), InteractionH.INT_SUBTYPE_NPC) then
		interact = interaction.check_npc_talk(m, o)
	else
		interaction.push_mario_out_of_object(m, o, 2)
	end

	return interact
end

-- from src/game/interaction.c:check_kick_or_punch_wall L1755-1778
function interaction.check_kick_or_punch_wall(m: GroupsTypesHPlus3.MarioState)
	if bit32.btest(m.flags, bit32.bor(IncludeSm64H.MARIO_PUNCHING, IncludeSm64H.MARIO_KICKING, IncludeSm64H.MARIO_TRIPPING)) then
		WallDetector[1] = F32(m.pos[1] + F32(50 * Registry.Members.src__engine__math_util_h.sins(m.faceAngle[2])))
		WallDetector[3] = F32(m.pos[3] + F32(50 * Registry.Members.src__engine__math_util_h.coss(m.faceAngle[2])))
		WallDetector[2] = m.pos[2]

		if Registry.Members.src__game__mario.resolve_and_return_wall_collisions(WallDetector, 80, 5) ~= nil then
			if m.action ~= IncludeSm64H.ACT_MOVE_PUNCHING or m.forwardVel >= 0 then
				if m.action == IncludeSm64H.ACT_PUNCHING then
					m.action = IncludeSm64H.ACT_MOVE_PUNCHING
				end

				Registry.Members.src__game__mario.mario_set_forward_vel(m, -48)
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HIT_2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
				m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_TRIANGLE)
			elseif bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) then
				Registry.Members.src__game__mario.mario_set_forward_vel(m, -16)
				Audio.play_sound(IncludeSoundsH.SOUND_ACTION_HIT_2, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
				m.particleFlags = bit32.bor(m.particleFlags, IncludeSm64H.PARTICLE_TRIANGLE)
			end
		end
	end
end

-- from src/game/interaction.c:mario_process_interactions L1780-1817
function interaction.mario_process_interactions(m: GroupsTypesHPlus3.MarioState)
	interaction.sDelayInvincTimer = IncludePRUltratypesH.FALSE
	interaction.sInvulnerable = if bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INVULNERABLE) or m.invincTimer ~= 0 then IncludePRUltratypesH.TRUE else IncludePRUltratypesH.FALSE

	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_INTANGIBLE) and m.collidedObjInteractTypes ~= 0 then
		for i = 0, #interaction.sInteractionHandlers - 1 do
			const interactType = interaction.sInteractionHandlers[i + 1].interactType

			if bit32.btest(m.collidedObjInteractTypes, interactType) then
				const object = interaction.mario_get_collided_object(m, interactType) :: GroupsTypesHPlus3.Object

				m.collidedObjInteractTypes = bit32.band(m.collidedObjInteractTypes, bit32.bnot(interactType))

				if not bit32.btest(buffer.readi32(object.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
					const handler = interaction.sInteractionHandlers[i + 1].handler :: (GroupsTypesHPlus3.MarioState, number, GroupsTypesHPlus3.Object) -> number

					if handler(m, interactType, object) ~= 0 then
						break
					end
				end
			end
		end
	end

	if m.invincTimer > 0 and interaction.sDelayInvincTimer == 0 then
		m.invincTimer = S16(m.invincTimer - 1)
	end

	-- ! If the kick/punch flags are set and an object collision changes Mario's
	-- action, he will get the kick/punch wall speed anyway.
	interaction.check_kick_or_punch_wall(m)
	m.flags = bit32.band(m.flags, bit32.bnot(bit32.bor(IncludeSm64H.MARIO_PUNCHING, IncludeSm64H.MARIO_KICKING, IncludeSm64H.MARIO_TRIPPING)))

	const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
	if not bit32.btest(marioObj.collidedObjInteractTypes, bit32.bor(InteractionH.INTERACT_WARP_DOOR, InteractionH.INTERACT_DOOR)) then
		interaction.sDisplayingDoorText = IncludePRUltratypesH.FALSE
	end
	if not bit32.btest(marioObj.collidedObjInteractTypes, InteractionH.INTERACT_WARP) then
		interaction.sJustTeleported = IncludePRUltratypesH.FALSE
	end
end

-- from src/game/interaction.c:check_death_barrier L1819-1825
function interaction.check_death_barrier(m: GroupsTypesHPlus3.MarioState)
	if m.pos[2] < F32(m.floorHeight + 2048) then
		if LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_WARP_FLOOR) == 20 and not bit32.btest(m.flags, IncludeSm64H.MARIO_UNKNOWN_18) then
			Audio.play_sound(IncludeSoundsH.SOUND_MARIO_WAAAOOOW, (m.marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end
	end
end

-- from src/game/interaction.c:check_lava_boost L1827-1836
function interaction.check_lava_boost(m: GroupsTypesHPlus3.MarioState)
	if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_RIDING_SHELL) and m.pos[2] < F32(m.floorHeight + 10) then
		if not bit32.btest(m.flags, IncludeSm64H.MARIO_METAL_CAP) then
			m.hurtCounter = U8(m.hurtCounter + (if bit32.btest(m.flags, IncludeSm64H.MARIO_CAP_ON_HEAD) then 12 else 18))
		end

		Registry.Members.src__game__mario.update_mario_sound_and_camera(m)
		Registry.Members.src__game__mario.drop_and_set_mario_action(m, IncludeSm64H.ACT_LAVA_BOOST, 0)
	end
end

-- from src/game/interaction.c:pss_begin_slide L1838-1844
function interaction.pss_begin_slide(m: GroupsTypesHPlus3.MarioState)
	if not bit32.btest(LevelUpdate.gHudDisplay.flags, LevelUpdateH.HUD_DISPLAY_FLAG_TIMER) then
		LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_SHOW)
		LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_START)
		interaction.sPSSSlideStarted = IncludePRUltratypesH.TRUE
	end
end

-- from src/game/interaction.c:pss_end_slide L1846-1856
function interaction.pss_end_slide(m: GroupsTypesHPlus3.MarioState)
	if interaction.sPSSSlideStarted ~= 0 then
		const slideTime = LevelUpdate.level_control_timer(LevelUpdateH.TIMER_CONTROL_STOP)

		if slideTime < 630 then
			const marioObj = m.marioObj :: GroupsTypesHPlus3.Object
			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oBhvParams, bit32.lshift(IncludeObjectConstantsH.STAR_INDEX_ACT_2, 24))
			BehaviorsSpawnStarInc.spawn_default_star(-6358, -4300, 4700)
		end

		interaction.sPSSSlideStarted = IncludePRUltratypesH.FALSE
	end
end

-- from src/game/interaction.c:mario_handle_special_floors L1858-1893
function interaction.mario_handle_special_floors(m: GroupsTypesHPlus3.MarioState)
	if bit32.band(m.action, IncludeSm64H.ACT_GROUP_MASK) == IncludeSm64H.ACT_GROUP_CUTSCENE then
		return
	end

	if m.floor ~= nil then
		const floorType = m.floor.type_

		if floorType == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE or floorType == IncludeSurfaceTerrainsH.SURFACE_VERTICAL_WIND then
			interaction.check_death_barrier(m)
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_WARP then
			LevelUpdate.level_trigger_warp(m, LevelUpdateH.WARP_OP_WARP_FLOOR)
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_TIMER_START then
			interaction.pss_begin_slide(m)
		elseif floorType == IncludeSurfaceTerrainsH.SURFACE_TIMER_END then
			interaction.pss_end_slide(m)
		end

		if not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_AIR) and not bit32.btest(m.action, IncludeSm64H.ACT_FLAG_SWIMMING) then
			if floorType == IncludeSurfaceTerrainsH.SURFACE_BURNING then
				interaction.check_lava_boost(m)
			end
		end
	end
end

-- from src/game/interaction.c:sInteractionHandlers L84-116
interaction.sInteractionHandlers = {
	{ interactType = InteractionH.INTERACT_COIN, handler = interaction.interact_coin },
	{ interactType = InteractionH.INTERACT_WATER_RING, handler = interaction.interact_water_ring },
	{ interactType = InteractionH.INTERACT_STAR_OR_KEY, handler = interaction.interact_star_or_key },
	{ interactType = InteractionH.INTERACT_BBH_ENTRANCE, handler = interaction.interact_bbh_entrance },
	{ interactType = InteractionH.INTERACT_WARP, handler = interaction.interact_warp },
	{ interactType = InteractionH.INTERACT_WARP_DOOR, handler = interaction.interact_warp_door },
	{ interactType = InteractionH.INTERACT_DOOR, handler = interaction.interact_door },
	{ interactType = InteractionH.INTERACT_CANNON_BASE, handler = interaction.interact_cannon_base },
	{ interactType = InteractionH.INTERACT_IGLOO_BARRIER, handler = interaction.interact_igloo_barrier },
	{ interactType = InteractionH.INTERACT_TORNADO, handler = interaction.interact_tornado },
	{ interactType = InteractionH.INTERACT_WHIRLPOOL, handler = interaction.interact_whirlpool },
	{ interactType = InteractionH.INTERACT_STRONG_WIND, handler = interaction.interact_strong_wind },
	{ interactType = InteractionH.INTERACT_FLAME, handler = interaction.interact_flame },
	{ interactType = InteractionH.INTERACT_SNUFIT_BULLET, handler = interaction.interact_snufit_bullet },
	{ interactType = InteractionH.INTERACT_CLAM_OR_BUBBA, handler = interaction.interact_clam_or_bubba },
	{ interactType = InteractionH.INTERACT_BULLY, handler = interaction.interact_bully },
	{ interactType = InteractionH.INTERACT_SHOCK, handler = interaction.interact_shock },
	{ interactType = InteractionH.INTERACT_BOUNCE_TOP2, handler = interaction.interact_bounce_top },
	{ interactType = InteractionH.INTERACT_MR_BLIZZARD, handler = interaction.interact_mr_blizzard },
	{
		interactType = InteractionH.INTERACT_HIT_FROM_BELOW,
		handler = interaction.interact_hit_from_below,
	},
	{ interactType = InteractionH.INTERACT_BOUNCE_TOP, handler = interaction.interact_bounce_top },
	{ interactType = InteractionH.INTERACT_DAMAGE, handler = interaction.interact_damage },
	{ interactType = InteractionH.INTERACT_POLE, handler = interaction.interact_pole },
	{ interactType = InteractionH.INTERACT_HOOT, handler = interaction.interact_hoot },
	{ interactType = InteractionH.INTERACT_BREAKABLE, handler = interaction.interact_breakable },
	{ interactType = InteractionH.INTERACT_KOOPA, handler = interaction.interact_bounce_top },
	{ interactType = InteractionH.INTERACT_KOOPA_SHELL, handler = interaction.interact_koopa_shell },
	{ interactType = InteractionH.INTERACT_UNKNOWN_08, handler = interaction.interact_unknown_08 },
	{ interactType = InteractionH.INTERACT_CAP, handler = interaction.interact_cap },
	{ interactType = InteractionH.INTERACT_GRABBABLE, handler = interaction.interact_grabbable },
	{ interactType = InteractionH.INTERACT_TEXT, handler = interaction.interact_text },
}

return interaction
