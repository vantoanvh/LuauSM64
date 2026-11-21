--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tumbling_bridge.inc.c.
]]

const SegmentSymbols = require("../../rom/segment_symbols")
const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")

-- from src/game/behaviors/tumbling_bridge.inc.c:TumblingBridgeData
export type TumblingBridgeData = {
	numBridgeSections: number,
	bridgeRelativeStartingXorZ: number,
	platformWidth: number,
	model: number,
	collision: number?,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/tumbling_bridge.inc.c:data
const tumbling_bridge_inc = {
	-- from src/game/behaviors/tumbling_bridge.inc.c:sTumblingBridgeData L16-21
	sTumblingBridgeData = {
		{
			numBridgeSections = 9,
			bridgeRelativeStartingXorZ = -512,
			platformWidth = 128,
			model = IncludeModelIdsH.MODEL_WF_TUMBLING_BRIDGE_PART,
			collision = SegmentSymbols.wf_seg7_collision_tumbling_bridge,
		},
		{
			numBridgeSections = 9,
			bridgeRelativeStartingXorZ = -412,
			platformWidth = 103,
			model = IncludeModelIdsH.MODEL_BBH_TUMBLING_PLATFORM_PART,
			collision = 0x07026B1C --[[ bbh_seg7_collision_07026B1C ]],
		},
		{
			numBridgeSections = 9,
			bridgeRelativeStartingXorZ = -512,
			platformWidth = 128,
			model = IncludeModelIdsH.MODEL_LLL_FALLING_PLATFORM,
			collision = 0x0701D18C --[[ lll_seg7_collision_0701D21C (ROM layout) ]],
		},
		{
			numBridgeSections = 9,
			bridgeRelativeStartingXorZ = -512,
			platformWidth = 128,
			model = IncludeModelIdsH.MODEL_BITFS_TUMBLING_PLATFORM_PART,
			collision = 0x07015288 --[[ bitfs_seg7_collision_07015288 ]],
		},
	},
}

Registry.Register("src__game__behaviors__tumbling_bridge_inc", tumbling_bridge_inc)

-- from src/game/behaviors/tumbling_bridge.inc.c:TumblingBridgeData (zero-filled constructor)
function tumbling_bridge_inc.new_TumblingBridgeData(): TumblingBridgeData
	return {
		numBridgeSections = 0,
		bridgeRelativeStartingXorZ = 0,
		platformWidth = 0,
		model = 0,
		collision = nil,
	} :: TumblingBridgeData
end

-- from src/game/behaviors/tumbling_bridge.inc.c:bhv_tumbling_bridge_platform_loop L23-62
function tumbling_bridge_inc.bhv_tumbling_bridge_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTumblingBridgeUnkF4, SrcEngineBehaviorScript.random_sign() * 0x80)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		ObjectHelpers.cur_obj_update_floor_height()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 5 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_PLATFORM)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) < 0x400 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch) + 0x80)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) > -0x400 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) < 0x400 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oTumblingBridgeUnkF4)) -- acceleration?
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -3.0)
		ObjectHelpers.cur_obj_rotate_face_angle_using_vel()
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) - 300.0) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		-- The bridge piece has fallen: nothing more to do.
	end

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/tumbling_bridge.inc.c:tumbling_bridge_act_1 L64-100
function tumbling_bridge_inc.tumbling_bridge_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bridgeID: number = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)
	local relativePlatformY = 0
	local relativeInitialPlatformY = 0

	for i = 0, tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].numBridgeSections - 1 do
		local relativePlatformX = 0
		local relativePlatformZ = 0

		if bridgeID == IncludeObjectConstantsH.TUMBLING_BRIDGE_BP_BITFS then
			relativePlatformX = tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].bridgeRelativeStartingXorZ + tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].platformWidth * i
		else
			relativePlatformZ = tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].bridgeRelativeStartingXorZ + tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].platformWidth * i
		end

		if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvLLLTumblingBridge) ~= 0 then
			if math.fmod(i, 3) == 0 then
				relativePlatformY -= 150
			end

			relativeInitialPlatformY = 450
		end

		const platformObj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_relative(0, S16(relativePlatformX), S16(relativePlatformY + relativeInitialPlatformY), S16(relativePlatformZ), o, tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].model, BehaviorIds.bhvTumblingBridgePlatform)

		ObjectHelpers.obj_set_collision_data(platformObj, tumbling_bridge_inc.sTumblingBridgeData[bridgeID + 1].collision)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
end

-- from src/game/behaviors/tumbling_bridge.inc.c:tumbling_bridge_act_2 L102-110
function tumbling_bridge_inc.tumbling_bridge_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_hide()

	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvLLLTumblingBridge) ~= 0 then
		ObjectHelpers.cur_obj_unhide()
	elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1200.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		ObjectHelpers.cur_obj_unhide()
	end
end

-- from src/game/behaviors/tumbling_bridge.inc.c:tumbling_bridge_act_3 L112-115
function tumbling_bridge_inc.tumbling_bridge_act_3()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_unhide()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
end

-- from src/game/behaviors/tumbling_bridge.inc.c:tumbling_bridge_act_0 L117-121
function tumbling_bridge_inc.tumbling_bridge_act_0()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjectHelpers.cur_obj_has_behavior(BehaviorIds.bhvLLLTumblingBridge) ~= 0 or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end
end

-- from src/game/behaviors/tumbling_bridge.inc.c:bhv_tumbling_bridge_loop L130-132
function tumbling_bridge_inc.bhv_tumbling_bridge_loop()
	ObjectHelpers.cur_obj_call_action_function(tumbling_bridge_inc.sTumblingBridgeActions)
end

-- from src/game/behaviors/tumbling_bridge.inc.c:sTumblingBridgeActions L123-128
tumbling_bridge_inc.sTumblingBridgeActions = {
	tumbling_bridge_inc.tumbling_bridge_act_0,
	tumbling_bridge_inc.tumbling_bridge_act_1,
	tumbling_bridge_inc.tumbling_bridge_act_2,
	tumbling_bridge_inc.tumbling_bridge_act_3,
}

return tumbling_bridge_inc
