--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/falling_pillar.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")
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

-- from src/game/behaviors/falling_pillar.inc.c:data
const falling_pillar_inc = {
	-- from src/game/behaviors/falling_pillar.inc.c:sFallingPillarHitbox L9-19
	sFallingPillarHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 150,
		damageOrCoinValue = 3,
		health = 0,
		numLootCoins = 0,
		radius = 150,
		height = 300,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__falling_pillar_inc", falling_pillar_inc)

-- from src/game/behaviors/falling_pillar.inc.c:bhv_falling_pillar_init L24-28
function falling_pillar_inc.bhv_falling_pillar_init()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.91)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.3)
end

-- from src/game/behaviors/falling_pillar.inc.c:bhv_falling_pillar_spawn_hitboxes L33-39
function falling_pillar_inc.bhv_falling_pillar_spawn_hitboxes()
	const o = ObjectListProcessor.gCurrentObject

	for i = 0, 3 do
		ObjectHelpers.spawn_object_relative(S16(i), 0, S16(i * 400 + 300), 0, o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvFallingPillarHitbox)
	end
end

-- from src/game/behaviors/falling_pillar.inc.c:bhv_falling_pillar_calculate_angle_in_front_of_mario L45-53
function falling_pillar_inc.bhv_falling_pillar_calculate_angle_in_front_of_mario(): number
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- Calculate target to be 500 units in front of Mario in
	-- the direction he is facing (angle[1] is yaw).
	const targetX = F32(F32(SrcEngineMathUtilH.sins(mario.header.gfx.angle[2]) * 500) + mario.header.gfx.pos[1])
	const targetZ = F32(F32(SrcEngineMathUtilH.coss(mario.header.gfx.angle[2]) * 500) + mario.header.gfx.pos[3])

	-- Calculate the angle to the target from the pillar's current location.
	return SrcEngineMathUtil.atan2s(F32(targetZ - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)), F32(targetX - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)))
end

-- from src/game/behaviors/falling_pillar.inc.c:bhv_falling_pillar_loop L58-119
function falling_pillar_inc.bhv_falling_pillar_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FALLING_PILLAR_ACT_IDLE then
		-- When Mario is within 1300 units of distance...
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1300) ~= 0 then
			-- Begin slightly moving towards Mario.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 1)

			-- Spawn the invisible hitboxes.
			falling_pillar_inc.bhv_falling_pillar_spawn_hitboxes()

			-- Start turning towards Mario.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FALLING_PILLAR_ACT_TURNING)

			-- Play the detaching sound.
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_POUND_ROCK)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FALLING_PILLAR_ACT_TURNING then
		ObjBehaviors.object_step_without_floor_orient()

		-- Calculate angle in front of Mario and turn towards it.
		const angleInFrontOfMario = falling_pillar_inc.bhv_falling_pillar_calculate_angle_in_front_of_mario()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)), angleInFrontOfMario, 0x400))

		-- After 10 ticks, start falling.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 10 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FALLING_PILLAR_ACT_FALLING)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FALLING_PILLAR_ACT_FALLING then
		ObjBehaviors.object_step_without_floor_orient()

		-- Start falling slowly, with increasing acceleration each frame.
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFallingPillarPitchAcceleration, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFallingPillarPitchAcceleration) + 4)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, TruncS32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFallingPillarPitchAcceleration))))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))

		-- Once the pillar has turned nearly 90 degrees (after ~22 frames),
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0x3900 then
			-- Move 500 units in the direction of falling.
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) * 500))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) * 500))

			-- Make the camera shake and spawn dust clouds.
			Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_MEDIUM, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			BehaviorActions.spawn_mist_particles_variable(0, 0, 92)

			-- Go invisible.
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED

			-- Play the hitting the ground sound.
			SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BIG_POUND)
		end
	end
end

-- from src/game/behaviors/falling_pillar.inc.c:bhv_falling_pillar_hitbox_loop L124-145
function falling_pillar_inc.bhv_falling_pillar_hitbox_loop()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	-- Get the state of the pillar.
	const pitch = buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAnglePitch)
	const yaw = buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw)
	const x = buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX)
	const y = buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY)
	const z = buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ)
	const yOffset = F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 400 + 300)

	-- Update position of hitboxes so they fall with the pillar.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(F32(SrcEngineMathUtilH.sins(pitch) * SrcEngineMathUtilH.sins(yaw)) * yOffset) + x)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(SrcEngineMathUtilH.coss(pitch) * yOffset) + y)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(F32(SrcEngineMathUtilH.sins(pitch) * SrcEngineMathUtilH.coss(yaw)) * yOffset) + z)

	-- Give these a hitbox so they can collide with Mario.
	ObjectHelpers.obj_set_hitbox(o, falling_pillar_inc.sFallingPillarHitbox)

	-- When the pillar goes inactive, the hitboxes also go inactive.
	if parent.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return falling_pillar_inc
