--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_bomb.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const bowser_bomb_inc = {}

Registry.Register("src__game__behaviors__bowser_bomb_inc", bowser_bomb_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/game/behaviors/bowser_bomb.inc.c:bhv_bowser_bomb_loop L3-18
function bowser_bomb_inc.bhv_bowser_bomb_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), bit32.bnot(InteractionH.INT_STATUS_INTERACTED))))
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_EXPLOSION, BehaviorIds.bhvExplosion)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_HIT_MINE) then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWSER_FLAMES, BehaviorIds.bhvBowserBombExplosion)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BOWSER_BOMB_EXPLOSION)
		Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_LARGE, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	ObjBehaviors.set_object_visibility(o, 7000)
end

-- from src/game/behaviors/bowser_bomb.inc.c:bhv_bowser_bomb_explosion_loop L20-37
function bowser_bomb_inc.bhv_bowser_bomb_explosion_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	ObjectHelpers.cur_obj_scale(F32(F32(timer / 14.0) * 9.0 + 1.0))

	if timer % 4 == 0 and timer < 20 then
		const mineSmoke = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BOWSER_SMOKE, BehaviorIds.bhvBowserBombSmoke)
		buffer.writef32(mineSmoke.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(mineSmoke.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SrcEngineBehaviorScript.random_float() * 600.0) - 400.0))
		buffer.writef32(mineSmoke.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(mineSmoke.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(SrcEngineBehaviorScript.random_float() * 600.0) - 400.0))
		buffer.writef32(mineSmoke.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(mineSmoke.rawData, IncludeObjectFieldsH.oVelY) + F32(SrcEngineBehaviorScript.random_float() * 10.0))
	end

	if timer % 2 == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
	end

	if timer == 28 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/bowser_bomb.inc.c:bhv_bowser_bomb_smoke_loop L39-57
function bowser_bomb_inc.bhv_bowser_bomb_smoke_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	ObjectHelpers.cur_obj_scale(F32(F32(timer / 14.0) * 9.0 + 1.0))

	if timer % 2 == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState) + 1)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) - 10)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oOpacity) < 10 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	if timer == 28 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

return bowser_bomb_inc
