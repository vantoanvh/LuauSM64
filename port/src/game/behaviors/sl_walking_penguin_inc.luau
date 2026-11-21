--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/sl_walking_penguin.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const TuxieInc = require("./tuxie_inc")

-- from src/game/behaviors/sl_walking_penguin.inc.c:SLWalkingPenguinStep
export type SLWalkingPenguinStep = {
	stepLength: number,
	anim: number,
	speed: number,
	animSpeed: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/sl_walking_penguin.inc.c:data
const sl_walking_penguin_inc = {
	-- from src/game/behaviors/sl_walking_penguin.inc.c:sSLWalkingPenguinErraticSteps L11-19
	sSLWalkingPenguinErraticSteps = {
		{ stepLength = 60, anim = IncludeObjectConstantsH.PENGUIN_ANIM_WALK, speed = 6.0, animSpeed = 1.0 },
		{ stepLength = 30, anim = IncludeObjectConstantsH.PENGUIN_ANIM_IDLE, speed = 0.0, animSpeed = 1.0 },
		{ stepLength = 30, anim = IncludeObjectConstantsH.PENGUIN_ANIM_WALK, speed = 12.0, animSpeed = 2.0 },
		{ stepLength = 30, anim = IncludeObjectConstantsH.PENGUIN_ANIM_IDLE, speed = 0.0, animSpeed = 1.0 },
		{ stepLength = 30, anim = IncludeObjectConstantsH.PENGUIN_ANIM_WALK, speed = -6.0, animSpeed = 1.0 },
		{ stepLength = 30, anim = IncludeObjectConstantsH.PENGUIN_ANIM_IDLE, speed = 0.0, animSpeed = 1.0 },
		{ stepLength = -1, anim = 0, speed = 0.0, animSpeed = 0.0 },
	},
}

Registry.Register("src__game__behaviors__sl_walking_penguin_inc", sl_walking_penguin_inc)

-- from src/game/behaviors/sl_walking_penguin.inc.c:SLWalkingPenguinStep (zero-filled constructor)
function sl_walking_penguin_inc.new_SLWalkingPenguinStep(): SLWalkingPenguinStep
	return { stepLength = 0, anim = 0, speed = 0, animSpeed = 0 } :: SLWalkingPenguinStep
end

-- from src/game/behaviors/sl_walking_penguin.inc.c:sl_walking_penguin_turn L21-35
function sl_walking_penguin_inc.sl_walking_penguin_turn(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Stay still and use walking animation for the turn.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(IncludeObjectConstantsH.PENGUIN_ANIM_WALK, 1.0)

	-- Turn around.
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x400)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 31 then
		return IncludePRUltratypesH.TRUE -- Finished turning
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/sl_walking_penguin.inc.c:bhv_sl_walking_penguin_loop L37-122
function sl_walking_penguin_inc.bhv_sl_walking_penguin_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const perpendicularOffset = 100.0

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0)
	ObjectHelpers.cur_obj_update_floor_and_walls()

	-- Walk erratically across the ice bridge using preset steps.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SL_WALKING_PENGUIN_ACT_MOVING_FORWARDS then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			-- Initiate variables
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStepTimer, 0)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStepTimer) < sl_walking_penguin_inc.sSLWalkingPenguinErraticSteps[buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1].stepLength then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStepTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStepTimer) + 1)
		else
			-- Move to next step
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStepTimer, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1)

			if sl_walking_penguin_inc.sSLWalkingPenguinErraticSteps[buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1].stepLength < 0 then
				-- Reached the end of the list, go back to the start
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep, 0)
			end
		end

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) < 300.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1) -- If reached the end of the bridge, turn around and head back.
		else
			-- Move and animate the penguin
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, sl_walking_penguin_inc.sSLWalkingPenguinErraticSteps[buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1].speed)

			ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(
				sl_walking_penguin_inc.sSLWalkingPenguinErraticSteps[buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1].anim,
				sl_walking_penguin_inc.sSLWalkingPenguinErraticSteps[buffer.readi32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinCurStep) + 1].animSpeed
			)
		end

	-- At the end, turn around and prepare to head back across the bridge.
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SL_WALKING_PENGUIN_ACT_TURNING_BACK then
		if sl_walking_penguin_inc.sl_walking_penguin_turn() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1) -- Finished turning
		end

	-- Walk back across the bridge at a constant speed.
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SL_WALKING_PENGUIN_ACT_RETURNING then
		-- Move and animate the penguin
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 12.0)
		ObjectHelpers.cur_obj_init_animation_with_accel_and_sound(IncludeObjectConstantsH.PENGUIN_ANIM_WALK, 2.0)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) > 1700.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1) -- If reached the start of the bridge, turn around.
		end

	-- At the start, turn around and prepare to walk erratically across the bridge.
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.SL_WALKING_PENGUIN_ACT_TURNING_FORWARDS then
		if sl_walking_penguin_inc.sl_walking_penguin_turn() ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.SL_WALKING_PENGUIN_ACT_MOVING_FORWARDS) -- Finished turning
		end
	end

	ObjectHelpers.cur_obj_move_standard(-78)
	if ObjectHelpers.cur_obj_hide_if_mario_far_away_y(1000.0) == 0 then
		TuxieInc.play_penguin_walking_sound(IncludeObjectConstantsH.PENGUIN_WALK_BIG)
	end

	-- Adjust the position to get a point better lined up with the visual model, for stopping the wind.
	-- The new point is 60 units behind the penguin and 100 units perpedicularly, away from the snowman.

	local adjustedXPos = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(0xDBB0) * 60.0)) -- 0xDBB0 = -51 degrees, the angle the penguin is facing
	local adjustedZPos = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(0xDBB0) * 60.0))
	adjustedXPos = F32(adjustedXPos + F32(perpendicularOffset * SrcEngineMathUtilH.sins(0x1BB0))) -- 0x1BB0 = 39 degrees, perpendicular to the penguin
	adjustedZPos = F32(adjustedZPos + F32(perpendicularOffset * SrcEngineMathUtilH.coss(0x1BB0)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinWindCollisionXPos, adjustedXPos)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oSLWalkingPenguinWindCollisionZPos, adjustedZPos)

	-- print_debug_bottom_up x2: no call (debug-print-externals)
end

return sl_walking_penguin_inc
