--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/red_coin.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const MovingCoinInc = require("./moving_coin_inc")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- from src/game/behaviors/red_coin_inc.luau:scratch
const Scratch = {
	bhv_red_coin_init_dummyFloor = { nil :: GroupsTypesHPlus3.Surface? },
}

-- from src/game/behaviors/red_coin.inc.c:data
const red_coin_inc = {
	-- from src/game/behaviors/red_coin.inc.c:sRedCoinHitbox L11-21
	sRedCoinHitbox = {
		interactType = InteractionH.INTERACT_COIN,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 0,
		numLootCoins = 0,
		radius = 100,
		height = 64,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__red_coin_inc", red_coin_inc)

-- from src/game/behaviors/red_coin.inc.c:bhv_red_coin_init L26-45
function red_coin_inc.bhv_red_coin_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- The floor is unused; the call is kept for its C side effects.
	SrcEngineSurfaceCollision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_red_coin_init_dummyFloor)

	-- Set the red coins to have a parent of the closest red coin star.
	local hiddenRedCoinStar: GroupsTypesHPlus3.Object? = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvHiddenRedCoinStar)

	if hiddenRedCoinStar ~= nil then
		o.parentObj = hiddenRedCoinStar
	else
		hiddenRedCoinStar = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvBowserCourseRedCoinStar)
		if hiddenRedCoinStar ~= nil then
			o.parentObj = hiddenRedCoinStar
		else
			o.parentObj = nil
		end
	end

	ObjectHelpers.obj_set_hitbox(o, red_coin_inc.sRedCoinHitbox)
end

-- from src/game/behaviors/red_coin.inc.c:bhv_red_coin_loop L51-80
function red_coin_inc.bhv_red_coin_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- If Mario interacted with the object...
	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		-- ...and there is a red coin star in the level...
		if o.parentObj ~= nil then
			const parentObj = o.parentObj :: GroupsTypesHPlus3.Object
			buffer.writei32(parentObj.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter, buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) + 1)

			-- Spawn the orange number counter, as long as it isn't the last coin.
			if buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter) ~= 8 then
				ObjBehaviors.spawn_orange_number(S8(buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter)), 0, 0, 0)
			end

			Audio.play_sound(IncludeSoundsH.SOUND_MENU_COLLECT_RED_COIN + bit32.lshift(bit32.band(buffer.readi32(parentObj.rawData, IncludeObjectFieldsH.oHiddenStarTriggerCounter), 0xFF) - 1, 16), Audio.gGlobalSoundSource)
		end

		MovingCoinInc.coin_collected()
		-- Despawn the coin.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
	end
end

return red_coin_inc
