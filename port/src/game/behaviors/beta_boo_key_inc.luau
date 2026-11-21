--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_boo_key.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const beta_boo_key_inc = {}

Registry.Register("src__game__behaviors__beta_boo_key_inc", beta_boo_key_inc)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/beta_boo_key.inc.c:bhv_alpha_boo_key_loop L24-45
function beta_boo_key_inc.bhv_alpha_boo_key_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Rotate the key
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x200)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x200)

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
		-- This line makes the object inside the key's parent boo drop.
		-- Was this intended to make the boo die when the key is collected?
		-- Boos don't read from oBooDeathStatus, they only set it to let the
		-- objects inside them know when to drop.
		-- Due to this line, the key will cause the game to crash if collected
		-- when its parent object is NULL.
		-- Another theory is that the boo key was intended to be spawned by a
		-- spawner that used object field 0x00 for something else. This
		-- is elaborated on more in beta_boo_key_dropped_loop.
		buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBooDeathStatus, IncludeObjectConstantsH.BOO_DEATH_STATUS_DYING)

		-- Delete the object and spawn sparkles
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
	end
end

-- from src/game/behaviors/beta_boo_key.inc.c:beta_boo_key_dropped_loop L53-105
function beta_boo_key_inc.beta_boo_key_dropped_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Apply standard physics to the key
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)

	-- Slowly increase the Y offset to make the model aligned correctly.
	-- This is spread out over 13 frames so that it's not noticable.
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) < 26.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) + 2.0)
	end

	-- Transition from rotating in both the yaw and the roll axes
	-- to just in the yaw axis. This is done by truncating the key's roll
	-- to the nearest multiple of 0x800, then continuously adding 0x800
	-- until it reaches a multiple of 0x10000, at which point &-ing with
	-- 0xFFFF returns 0 and the key stops rotating in the roll direction.
	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll), 0xFFFF) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll), 0xF800)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x800)
	end

	-- Once the key stops bouncing, stop its horizontal movement on the ground.
	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0.0)
	end

	-- Rotate the key
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800)

	-- If the key hits the floor or 90 frames have elapsed since it was dropped,
	-- become tangible and handle collision.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 90 or bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
		ObjectHelpers.cur_obj_become_tangible()

		if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
			-- This interaction status is 0x01, the first interaction status flag.
			-- It was only used for Hoot in the final game, but it seems it could've
			-- treated as a TRUE/FALSE statement or held some special meaning in beta.
			-- Earlier, in beta_boo_key_drop (called when the parent boo is killed),
			-- o->parentObj is set to the parent boo's parentObj. This means that
			-- here, the parentObj is actually the parent of the old parent boo.
			-- One theory about this code is that there was a boo spawner, which
			-- spawned "false" boos and one "true" boo with the key, and the player
			-- was intended to find the one with the key to progress.
			buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oInteractStatus, IncludePRUltratypesH.TRUE)

			-- Delete the object and spawn sparkles
			ObjectHelpers.obj_mark_for_deletion(o)
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SPARKLES, BehaviorIds.bhvGoldenCoinSparkles)
		end
	end
end

-- from src/game/behaviors/beta_boo_key.inc.c:beta_boo_key_drop L111-143
function beta_boo_key_inc.beta_boo_key_drop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- Update the key to be inside the boo
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	ObjectHelpers.obj_copy_pos(o, parent)

	-- This if statement to only run this code on the first frame
	-- is redundant, since it instantly sets the action to BETA_BOO_KEY_ACT_DROPPED
	-- which stops this function from running again.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		-- Separate from the parent boo
		o.parentObj = parent.parentObj

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BETA_BOO_KEY_ACT_DROPPED)

		-- Make the key move laterally away from Mario at 3 units/frame
		-- (as if he transferred kinetic energy to it)
		const velocityDirection = S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		const velocityMagnitude = 3.0

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, SrcEngineMathUtilH.sins(velocityDirection) * velocityMagnitude)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, SrcEngineMathUtilH.coss(velocityDirection) * velocityMagnitude)

		-- Give it an initial Y velocity of 40 units/frame
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 40.0)
	end

	-- Rotate the key
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x200)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x200)
end

-- from src/game/behaviors/beta_boo_key.inc.c:beta_boo_key_inside_boo_loop L148-165
function beta_boo_key_inc.beta_boo_key_inside_boo_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Update the key to be inside the boo at all times
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	ObjectHelpers.obj_copy_pos(o, parent)

	-- Use a Y offset of 40 to make the key model aligned correctly.
	-- (Why didn't they use oGraphYOffset?)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 40.0)

	-- If the boo is dying/dead, set the action to BETA_BOO_KEY_ACT_DROPPING.
	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBooDeathStatus) ~= IncludeObjectConstantsH.BOO_DEATH_STATUS_ALIVE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BETA_BOO_KEY_ACT_DROPPING)
	end

	-- Rotate the key
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + 0x200)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x200)
end

-- from src/game/behaviors/beta_boo_key.inc.c:bhv_beta_boo_key_loop L176-178
function beta_boo_key_inc.bhv_beta_boo_key_loop()
	ObjectHelpers.cur_obj_call_action_function(beta_boo_key_inc.sBetaBooKeyActions)
end

-- from src/game/behaviors/beta_boo_key.inc.c:sBetaBooKeyActions L167-171
beta_boo_key_inc.sBetaBooKeyActions = {
	beta_boo_key_inc.beta_boo_key_inside_boo_loop,
	beta_boo_key_inc.beta_boo_key_drop,
	beta_boo_key_inc.beta_boo_key_dropped_loop,
}

return beta_boo_key_inc
