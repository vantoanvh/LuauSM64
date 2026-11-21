--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/amp.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/amp.inc.c:data
const amp_inc = {
	-- from src/game/behaviors/amp.inc.c:sAmpHitbox L9-19
	sAmpHitbox = {
		interactType = InteractionH.INTERACT_SHOCK,
		downOffset = 40,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 40,
		height = 50,
		hurtboxRadius = 50,
		hurtboxHeight = 60,
	},
}

Registry.Register("src__game__behaviors__amp_inc", amp_inc)

-- from src/game/behaviors/amp.inc.c:bhv_homing_amp_init L24-39
function amp_inc.bhv_homing_amp_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))

	-- Homing amps start at 1/10th their normal size.
	-- They grow when they "appear" to Mario.
	ObjectHelpers.cur_obj_scale(F32(0.1))

	-- Hide the amp (until Mario gets near).
	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
end

-- from src/game/behaviors/amp.inc.c:check_amp_attack L44-65
function amp_inc.check_amp_attack()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Strange placement for this call. The hitbox is never cleared.
	-- For perspective, this code is run every frame of bhv_circling_amp_loop
	-- and every frame of a homing amp's HOMING_AMP_ACT_CHASE action.
	ObjectHelpers.obj_set_hitbox(o, amp_inc.sAmpHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		-- Unnecessary if statement, maybe caused by a macro for
		--     if (o->oInteractStatus & INT_STATUS_INTERACTED) {
		--         o->oAction = X;
		--     }
		-- ?
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			-- This function is used for both normal amps and homing amps,
			-- AMP_ACT_ATTACK_COOLDOWN == HOMING_AMP_ACT_ATTACK_COOLDOWN
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.AMP_ACT_ATTACK_COOLDOWN)
		end

		-- Clear interact status
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

-- from src/game/behaviors/amp.inc.c:homing_amp_appear_loop L70-98
function amp_inc.homing_amp_appear_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- gLakituState.goalPos is the position lakitu is moving towards.
	-- In Lakitu and Mario cam, it is usually very close to the current camera position.
	-- In Fixed cam, it is the point behind Mario the camera will go to when transitioning
	-- to Lakitu cam. Homing amps will point themselves towards this point when appearing.
	const relativeTargetX = F32(Camera.gLakituState.goalPos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const relativeTargetZ = F32(Camera.gLakituState.goalPos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const targetYaw = S16(SrcEngineMathUtil.atan2s(relativeTargetZ, relativeTargetX))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), targetYaw, 0x1000))

	-- For 30 frames, make the amp "appear" by increasing its size by 0.03 each frame,
	-- except for the first frame (when oTimer == 0) because the expression in cur_obj_scale
	-- evaluates to 0.1, which is the same as it was before. After 30 frames, it ends at
	-- a scale factor of 0.97. The amp remains at 97% of its real height for 60 more frames.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 30 then
		ObjectHelpers.cur_obj_scale(F32(0.1 + 0.9 * F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) / 30)))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	end

	-- Once the timer becomes greater than 90, i.e. 91 frames have passed,
	-- reset the amp's size and start chasing Mario.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
		ObjectHelpers.cur_obj_scale(1.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOMING_AMP_ACT_CHASE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAmpYPhase, 0)
	end
end

-- from src/game/behaviors/amp.inc.c:homing_amp_chase_loop L103-154
function amp_inc.homing_amp_chase_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- Lock on to Mario if he ever goes within 11.25 degrees of the amp's line of sight
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) - 0x400 < buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) and buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) < buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario) + 0x400 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oHomingAmpLockedOn, IncludePRUltratypesH.TRUE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	-- If the amp is locked on to Mario, start "chasing" him by moving
	-- in a straight line at 15 units/second for 32 frames.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHomingAmpLockedOn) == IncludePRUltratypesH.TRUE then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)

		-- Move the amp's average Y (the Y value it oscillates around) to align with
		-- Mario's head. Mario's graphics' Y + 150 is around the top of his head.
		-- Note that the average Y will slowly go down to approach his head if the amp
		-- is above his head, but if the amp is below it will instantly snap up.
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY) > F32(marioObj.header.gfx.pos[2] + 150.0) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY) - 10.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY, marioObj.header.gfx.pos[2] + 150.0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHomingAmpLockedOn, IncludePRUltratypesH.FALSE)
		end
	else
		-- If the amp is not locked on to Mario, move forward at 10 units/second
		-- while curving towards him.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 10.0)

		ObjectHelpers.obj_turn_toward_object(o, marioObj, 16, 0x400)

		-- The amp's average Y will approach Mario's graphical Y position + 250
		-- at a rate of 10 units per frame. Interestingly, this is different from
		-- the + 150 used while chasing him. Could this be a typo?
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY) < F32(marioObj.header.gfx.pos[2] + 250.0) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY) + 10.0)
		end
	end

	-- The amp's position will sinusoidally oscillate 40 units around its average Y.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) * 0x400) * 20.0))

	-- Handle attacks
	amp_inc.check_amp_attack()

	-- Give up if Mario goes further than 1500 units from the amp's original position
	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 1500) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOMING_AMP_ACT_GIVE_UP)
	end
end

-- from src/game/behaviors/amp.inc.c:homing_amp_give_up_loop L159-176
function amp_inc.homing_amp_give_up_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Move forward for 152 frames
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 15.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		-- Hide the amp and reset it back to its inactive state
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOMING_AMP_ACT_INACTIVE)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomingAmpAvgY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	end
end

-- from src/game/behaviors/amp.inc.c:amp_attack_cooldown_loop L181-197
function amp_inc.amp_attack_cooldown_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Turn intangible and wait for 90 frames before chasing Mario again after hitting him.
	o.header.gfx.animInfo.animFrame = S16(o.header.gfx.animInfo.animFrame + 2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	ObjectHelpers.cur_obj_become_intangible()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
		ObjectHelpers.cur_obj_become_tangible()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOMING_AMP_ACT_CHASE)
	end
end

-- from src/game/behaviors/amp.inc.c:bhv_homing_amp_loop L202-234
function amp_inc.bhv_homing_amp_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.HOMING_AMP_ACT_INACTIVE then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 800) == IncludePRUltratypesH.TRUE then
			-- Make the amp start to appear, and un-hide it.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOMING_AMP_ACT_APPEAR)
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	elseif action == IncludeObjectConstantsH.HOMING_AMP_ACT_APPEAR then
		amp_inc.homing_amp_appear_loop()
	elseif action == IncludeObjectConstantsH.HOMING_AMP_ACT_CHASE then
		amp_inc.homing_amp_chase_loop()
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_AMP_BUZZ)
	elseif action == IncludeObjectConstantsH.HOMING_AMP_ACT_GIVE_UP then
		amp_inc.homing_amp_give_up_loop()
	elseif action == IncludeObjectConstantsH.HOMING_AMP_ACT_ATTACK_COOLDOWN then
		amp_inc.amp_attack_cooldown_loop()
	end

	ObjBehaviors.object_step()

	-- Oscillate
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAmpYPhase, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) + 1)
end

-- from src/game/behaviors/amp.inc.c:bhv_circling_amp_init L239-268
function amp_inc.bhv_circling_amp_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)

	-- Determine the radius of the circling amp's circle
	const radiusParam = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if radiusParam == IncludeObjectConstantsH.AMP_BP_ROT_RADIUS_200 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oAmpRadiusOfRotation, 200.0)
	elseif radiusParam == IncludeObjectConstantsH.AMP_BP_ROT_RADIUS_300 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oAmpRadiusOfRotation, 300.0)
	elseif radiusParam == IncludeObjectConstantsH.AMP_BP_ROT_RADIUS_400 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oAmpRadiusOfRotation, 400.0)
	elseif radiusParam == IncludeObjectConstantsH.AMP_BP_ROT_RADIUS_0 then
		-- The fixed amp has no radius: nothing is stored.
	end

	-- Choose a random point along the amp's circle.
	-- The amp's move angle represents its angle along the circle.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.AMP_ACT_IDLE)
end

-- from src/game/behaviors/amp.inc.c:fixed_circling_amp_idle_loop L274-300
function amp_inc.fixed_circling_amp_idle_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- Turn towards Mario, in both yaw and pitch.
	const xToMario = F32(marioObj.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const yToMario = F32(F32(marioObj.header.gfx.pos[2] + 120.0) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	const zToMario = F32(marioObj.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const vAngleToMario = S16(SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(xToMario * xToMario) + F32(zToMario * zToMario)))), -yToMario))

	ObjectHelpers.obj_turn_toward_object(o, marioObj, 19, 0x1000)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)), vAngleToMario, 0x1000))

	-- Oscillate 40 units up and down.
	-- Interestingly, 0x458 (1112 in decimal) is a magic number with no apparent significance.
	-- It is slightly larger than the 0x400 figure used for homing amps, which makes
	-- fixed amps oscillate slightly quicker.
	-- Also, this uses the cosine, which starts at 1 instead of 0.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) * 0x458) * 20.0))

	-- Handle attacks
	amp_inc.check_amp_attack()

	-- Oscillate
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAmpYPhase, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) + 1)

	-- Where there is a cur_obj_play_sound_1 call in the main circling amp update function,
	-- there is nothing here. Fixed amps are the only amps that never play
	-- the "amp buzzing" sound.
end

-- from src/game/behaviors/amp.inc.c:circling_amp_idle_loop L305-324
function amp_inc.circling_amp_idle_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Move in a circle.
	-- The Y oscillation uses the magic number 0x8B0 (2224), which is
	-- twice that of the fixed amp. In other words, circling amps will
	-- oscillate twice as fast. Also, unlike all other amps, circling
	-- amps oscillate 60 units around their average Y instead of 40.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oAmpRadiusOfRotation)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * buffer.readf32(o.rawData, IncludeObjectFieldsH.oAmpRadiusOfRotation)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) * 0x8B0) * 30.0))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x400)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x4000)

	-- Handle attacks
	amp_inc.check_amp_attack()

	-- Oscillate
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAmpYPhase, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAmpYPhase) + 1)

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_AMP_BUZZ)
end

-- from src/game/behaviors/amp.inc.c:bhv_circling_amp_loop L331-345
function amp_inc.bhv_circling_amp_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.AMP_ACT_IDLE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.AMP_BP_ROT_RADIUS_0 then
			amp_inc.fixed_circling_amp_idle_loop()
		else
			amp_inc.circling_amp_idle_loop()
		end
	elseif action == IncludeObjectConstantsH.AMP_ACT_ATTACK_COOLDOWN then
		amp_inc.amp_attack_cooldown_loop()
	end
end

return amp_inc
