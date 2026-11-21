--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/beta_chest.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const beta_chest_inc = {}

Registry.Register("src__game__behaviors__beta_chest_inc", beta_chest_inc)

-- from src/game/behaviors/beta_chest.inc.c:bhv_beta_chest_bottom_init L14-29
function beta_chest_inc.bhv_beta_chest_bottom_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- Set the object's model
	ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_TREASURE_CHEST_BASE)

	-- ??? Pointless code?
	-- Maybe chests were originally intended to have random yaws.
	-- Shoshinkai 1995 footage shows chests in DDD scattered around
	-- a point with different yaws. Maybe this feature was lazily
	-- cancelled by setting the yaw to 0, right before this beta
	-- object was discarded?
	-- The random value is drawn for its effect on the random state; the store is overwritten below.
	SrcEngineBehaviorScript.random_u16()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)

	-- Spawn the chest lid 97 units in the +Y direction and 77 units in the -Z direction.
	ObjectHelpers.spawn_object_relative(0, 0, 97, -77, o, IncludeModelIdsH.MODEL_TREASURE_CHEST_LID, BehaviorIds.bhvBetaChestLid)
end

-- from src/game/behaviors/beta_chest.inc.c:bhv_beta_chest_bottom_loop L36-38
function beta_chest_inc.bhv_beta_chest_bottom_loop()
	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(200.0, 200.0)
end

-- from src/game/behaviors/beta_chest.inc.c:bhv_beta_chest_lid_loop L45-72
function beta_chest_inc.bhv_beta_chest_lid_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BETA_CHEST_ACT_IDLE_CLOSED then
		if ObjectHelpers.dist_between_objects(o.parentObj :: GroupsTypesHPlus3.Object, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) < 300.0 then
			-- Set to BETA_CHEST_ACT_OPENING
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.BETA_CHEST_ACT_OPENING then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			-- Spawn the bubble 80 units in the -Y direction and 120 units in the +Z direction.
			ObjectHelpers.spawn_object_relative(0, 0, -80, 120, o, IncludeModelIdsH.MODEL_BUBBLE, BehaviorIds.bhvWaterAirBubble)
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_CLAM_SHELL1, o.header.gfx.cameraToObject)
		end

		-- Rotate the lid 0x400 (1024) angle units per frame backwards.
		-- When the lid becomes vertical, stop rotating.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x400)
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < -0x4000 then
			-- Set to BETA_CHEST_ACT_IDLE_OPEN
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		-- fallthrough
	elseif action == IncludeObjectConstantsH.BETA_CHEST_ACT_IDLE_OPEN then
		-- Nothing to do: the lid stays open.
	end
end

return beta_chest_inc
