--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_key.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnObject = require("../spawn_object")
const SpawnSound = require("../spawn_sound")

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/bowser_key.inc.c:data
const bowser_key_inc = {
	-- from src/game/behaviors/bowser_key.inc.c:sBowserKeyHitbox L3-13
	sBowserKeyHitbox = {
		interactType = InteractionH.INTERACT_STAR_OR_KEY,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 160,
		height = 100,
		hurtboxRadius = 160,
		hurtboxHeight = 100,
	},
}

Registry.Register("src__game__behaviors__bowser_key_inc", bowser_key_inc)

-- from src/game/behaviors/bowser_key.inc.c:bhv_bowser_key_loop L15-49
function bowser_key_inc.bhv_bowser_key_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_scale(0.5)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) > 0x400 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) - 0x100))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -0x4000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 165.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 70.0)
		end

		BehaviorActions.spawn_sparkle_particles(3, 200, 80, -60)
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
		ObjectHelpers.cur_obj_update_floor_and_walls()
		ObjectHelpers.cur_obj_move_standard(78)

		if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_LANDED) then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNKNOWN3)
		end
	else
		ObjectHelpers.obj_set_hitbox(o, bowser_key_inc.sBowserKeyHitbox)

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			SpawnObject.mark_obj_for_deletion(o)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		end
	end
end

return bowser_key_inc
