--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/jumping_box.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/jumping_box.inc.c:data
const jumping_box_inc = {
	-- from src/game/behaviors/jumping_box.inc.c:sJumpingBoxHitbox L3-13
	sJumpingBoxHitbox = {
		interactType = InteractionH.INTERACT_GRABBABLE,
		downOffset = 20,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 5,
		radius = 150,
		height = 250,
		hurtboxRadius = 150,
		hurtboxHeight = 250,
	},
}

Registry.Register("src__game__behaviors__jumping_box_inc", jumping_box_inc)

-- from src/game/behaviors/jumping_box.inc.c:jumping_box_act_0 L15-29
function jumping_box_inc.jumping_box_act_0()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		const countdown = buffer.readi32(o.rawData, IncludeObjectFieldsH.oJumpingBoxUnkF8)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oJumpingBoxUnkF8, S32(countdown - 1))

		if countdown < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > buffer.readi32(o.rawData, IncludeObjectFieldsH.oJumpingBoxUnkF4) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 5.0) + 15.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))
		end
	elseif bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_ON_GROUND) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oJumpingBoxUnkF8, TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 60.0) + 30.0)))
	end
end

-- from src/game/behaviors/jumping_box.inc.c:jumping_box_act_1 L31-36
function jumping_box_inc.jumping_box_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), bit32.bor(IncludeObjectConstantsH.OBJ_MOVE_HIT_WALL, IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER, IncludeObjectConstantsH.OBJ_MOVE_LANDED)) then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_mist_particles()
	end
end

-- from src/game/behaviors/jumping_box.inc.c:jumping_box_free_update L43-50
function jumping_box_inc.jumping_box_free_update()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BREAKABLE_BOX)
	ObjectHelpers.cur_obj_scale(0.5)
	ObjectHelpers.obj_set_hitbox(o, jumping_box_inc.sJumpingBoxHitbox)
	ObjectHelpers.cur_obj_update_floor_and_walls()
	ObjectHelpers.cur_obj_move_standard(78)
	ObjectHelpers.cur_obj_call_action_function(jumping_box_inc.sJumpingBoxActions)
end

-- from src/game/behaviors/jumping_box.inc.c:bhv_jumping_box_loop L52-80
function jumping_box_inc.bhv_jumping_box_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		jumping_box_inc.jumping_box_free_update()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.obj_copy_pos(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object)
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_BREAKABLE_BOX_SMALL)
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(-1, 0)
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN then
		ObjectHelpers.cur_obj_get_thrown_or_placed(40.0, 20.0, 1)
	elseif heldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.cur_obj_get_dropped()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_STOP_RIDING) then
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BREAK_BOX)
		ObjectHelpers.obj_explode_and_spawn_coins(46.0, 1)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/jumping_box.inc.c:sJumpingBoxActions L38-41
jumping_box_inc.sJumpingBoxActions = { jumping_box_inc.jumping_box_act_0, jumping_box_inc.jumping_box_act_1 }

return jumping_box_inc
