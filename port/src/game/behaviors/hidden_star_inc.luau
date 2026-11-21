--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/hidden_star.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsIngameMenuPlus1 = require("../../../groups/ingame_menu_plus1")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnStarInc = require("./spawn_star_inc")

const hidden_star_inc = {}

Registry.Register("src__game__behaviors__hidden_star_inc", hidden_star_inc)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/hidden_star.inc.c:bhv_hidden_star_init L3-14
function hidden_star_inc.bhv_hidden_star_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const count = S16(ObjectHelpers.count_objects_with_behavior(BehaviorIds.bhvHiddenStarTrigger))

	if count == 0 then
		const star = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvStar, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))), 0, 0, 0)

		buffer.writei32(star.rawData, IncludeObjectFieldsH.oBhvParams, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams))
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter, S32(5 - count))
end

-- from src/game/behaviors/hidden_star.inc.c:bhv_hidden_star_loop L16-32
function hidden_star_inc.bhv_hidden_star_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) == 5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 2 then
			SpawnStarInc.spawn_red_coin_cutscene_star(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			ObjectHelpers.spawn_mist_particles()
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

-- from src/game/behaviors/hidden_star.inc.c:bhv_hidden_star_trigger_loop L34-55
function hidden_star_inc.bhv_hidden_star_trigger_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) == IncludePRUltratypesH.TRUE then
		const hiddenStar: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHiddenStar)

		if hiddenStar ~= nil then
			buffer.writei32(hiddenStar.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter, S32(buffer.readi32(hiddenStar.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) + 1))

			if buffer.readi32(hiddenStar.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) ~= 5 then
				ObjBehaviors.spawn_orange_number(S8(buffer.readi32(hiddenStar.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter)), 0, 0, 0)
			end

			Audio.play_sound(IncludeSoundsH.SOUND_MENU_COLLECT_SECRET + bit32.lshift(bit32.band(buffer.readi32(hiddenStar.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter), 0xFF) - 1, 16), Audio.gGlobalSoundSource)
		end

		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/hidden_star.inc.c:bhv_bowser_course_red_coin_star_loop L57-75
function hidden_star_inc.bhv_bowser_course_red_coin_star_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	GroupsIngameMenuPlus1.gRedCoinsCollected = S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter))

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) == 8 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif action == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 2 then
			SpawnStarInc.spawn_no_exit_star(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
			ObjectHelpers.spawn_mist_particles()
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	end
end

return hidden_star_inc
