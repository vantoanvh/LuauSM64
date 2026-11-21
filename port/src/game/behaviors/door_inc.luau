--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/door.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeSoundsH = require("../../../include/sounds_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const Memory = require("../memory")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const ObjectListProcessorH = require("../object_list_processor_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/door_inc.luau:scratch
const Scratch = {
	bhv_door_init_floor = {} :: { GroupsTypesHPlus3.Surface? },
}

-- from src/game/behaviors/door.inc.c:data
const door_inc = {
	-- from src/game/behaviors/door.inc.c:sDoorActions L8-8
	sDoorActions = {
		{ flag = 0x40000, action = 3 },
		{ flag = 0x80000, action = 4 },
		{ flag = 0x10000, action = 1 },
		{ flag = 0x20000, action = 2 },
		{ flag = 0xFFFFFFFF, action = 0 },
	},
	-- from src/game/behaviors/door.inc.c:sDoorOpenSounds L10-10
	sDoorOpenSounds = { IncludeSoundsH.SOUND_GENERAL_OPEN_WOOD_DOOR, IncludeSoundsH.SOUND_GENERAL_OPEN_IRON_DOOR },
	-- from src/game/behaviors/door.inc.c:sDoorCloseSounds L12-12
	sDoorCloseSounds = { IncludeSoundsH.SOUND_GENERAL_CLOSE_WOOD_DOOR, IncludeSoundsH.SOUND_GENERAL_CLOSE_IRON_DOOR },
}

Registry.Register("src__game__behaviors__door_inc", door_inc)

-- from src/game/behaviors/door.inc.c:door_animation_and_reset L14-19
function door_inc.door_animation_and_reset(sp18: number)
	ObjectHelpers.cur_obj_init_animation_with_sound(sp18)

	const o = ObjectListProcessor.gCurrentObject
	if ObjectHelpers.cur_obj_check_if_near_animation_end() ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/door.inc.c:set_door_camera_event L21-28
function door_inc.set_door_camera_event()
	const o = ObjectListProcessor.gCurrentObject

	if Memory.segmented_to_virtual(BehaviorIds.bhvDoor) == o.behavior then
		Camera.gPlayerCameraState[1].cameraEvent = GroupsTypesHPlus3.CAM_EVENT_DOOR
	else
		Camera.gPlayerCameraState[1].cameraEvent = GroupsTypesHPlus3.CAM_EVENT_DOOR_WARP
	end
	Camera.gPlayerCameraState[1].usedObj = o
end

-- from src/game/behaviors/door.inc.c:play_door_open_noise L30-39
function door_inc.play_door_open_noise()
	const sp1C = ObjectHelpers.cur_obj_has_model(IncludeModelIdsH.MODEL_HMC_METAL_DOOR)
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(door_inc.sDoorOpenSounds[sp1C + 1])
		ObjectListProcessor.gTimeStopState = U32(bit32.bor(ObjectListProcessor.gTimeStopState, ObjectListProcessorH.TIME_STOP_MARIO_OPENED_DOOR))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 70 then
		SpawnSound.cur_obj_play_sound_2(door_inc.sDoorCloseSounds[sp1C + 1])
	end
end

-- from src/game/behaviors/door.inc.c:play_warp_door_open_noise L41-46
function door_inc.play_warp_door_open_noise()
	const sp1C = ObjectHelpers.cur_obj_has_model(IncludeModelIdsH.MODEL_HMC_METAL_DOOR)
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 30 then
		SpawnSound.cur_obj_play_sound_2(door_inc.sDoorCloseSounds[sp1C + 1])
	end
end

-- from src/game/behaviors/door.inc.c:bhv_door_loop L48-86
function door_inc.bhv_door_loop()
	const o = ObjectListProcessor.gCurrentObject

	local sp1C = 0

	while door_inc.sDoorActions[sp1C + 1].flag ~= 0xFFFFFFFF do
		if ObjectHelpers.cur_obj_clear_interact_status_flag(door_inc.sDoorActions[sp1C + 1].flag) ~= 0 then
			door_inc.set_door_camera_event()
			ObjectHelpers.cur_obj_change_action(door_inc.sDoorActions[sp1C + 1].action)
		end
		sp1C += 1
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		ObjectHelpers.cur_obj_init_animation_with_sound(0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		door_inc.door_animation_and_reset(1)
		door_inc.play_door_open_noise()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		door_inc.door_animation_and_reset(2)
		door_inc.play_door_open_noise()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		door_inc.door_animation_and_reset(3)
		door_inc.play_warp_door_open_noise()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 4 then
		door_inc.door_animation_and_reset(4)
		door_inc.play_warp_door_open_noise()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		SrcEngineSurfaceLoad.load_object_collision_model()
	end

	door_inc.bhv_star_door_loop_2()
end

-- from src/game/behaviors/door.inc.c:bhv_door_init L88-118
function door_inc.bhv_door_init()
	const o = ObjectListProcessor.gCurrentObject

	local x = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	local z = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
	SrcEngineSurfaceCollision.find_floor(x, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), z, Scratch.bhv_door_init_floor)
	const floor = Scratch.bhv_door_init_floor[1]
	if floor ~= nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8, floor.room)
	end

	x = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 200))
	z = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * 200))
	SrcEngineSurfaceCollision.find_floor(x, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), z, Scratch.bhv_door_init_floor)
	const floorForward = Scratch.bhv_door_init_floor[1]
	if floorForward ~= nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDoorUnkFC, floorForward.room)
	end

	x = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * -200))
	z = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * -200))
	SrcEngineSurfaceCollision.find_floor(x, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), z, Scratch.bhv_door_init_floor)
	const floorBackward = Scratch.bhv_door_init_floor[1]
	if floorBackward ~= nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oDoorUnk100, floorBackward.room)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8) > 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8) < 60 then
		buffer.writei8(ObjectListProcessor.gDoorAdjacentRooms[buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8) + 1], 0, S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkFC)))
		buffer.writei8(ObjectListProcessor.gDoorAdjacentRooms[buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8) + 1], 1, S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnk100)))
	end
end

-- from src/game/behaviors/door.inc.c:bhv_star_door_loop_2 L120-153
function door_inc.bhv_star_door_loop_2()
	const o = ObjectListProcessor.gCurrentObject

	local sp4 = IncludePRUltratypesH.FALSE

	if ObjectListProcessor.gMarioCurrentRoom ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkF8) == ObjectListProcessor.gMarioCurrentRoom then
			sp4 = IncludePRUltratypesH.TRUE
		elseif ObjectListProcessor.gMarioCurrentRoom == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkFC) then
			sp4 = IncludePRUltratypesH.TRUE
		elseif ObjectListProcessor.gMarioCurrentRoom == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnk100) then
			sp4 = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 0) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkFC) then
			sp4 = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 0) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnk100) then
			sp4 = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 1) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnkFC) then
			sp4 = IncludePRUltratypesH.TRUE
		elseif buffer.readi8(ObjectListProcessor.gDoorAdjacentRooms[ObjectListProcessor.gMarioCurrentRoom + 1], 1) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oDoorUnk100) then
			sp4 = IncludePRUltratypesH.TRUE
		end
	else
		sp4 = IncludePRUltratypesH.TRUE
	end

	if sp4 == IncludePRUltratypesH.TRUE then
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE))
		ObjectListProcessor.D_8035FEE4 = S16(ObjectListProcessor.D_8035FEE4 + 1)
	end

	if sp4 == IncludePRUltratypesH.FALSE then
		o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE)))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oDoorUnk88, sp4)
end

return door_inc
