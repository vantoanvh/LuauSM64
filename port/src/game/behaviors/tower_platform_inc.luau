--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tower_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const tower_platform_inc = {}

Registry.Register("src__game__behaviors__tower_platform_inc", tower_platform_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
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

-- from src/game/behaviors/tower_platform.inc.c:bhv_wf_solid_tower_platform_loop L3-7
function tower_platform_inc.bhv_wf_solid_tower_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/tower_platform.inc.c:bhv_wf_elevator_tower_platform_loop L9-45
function tower_platform_inc.bhv_wf_elevator_tower_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 140 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5.0)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 140 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 5.0)
		end
	end

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/tower_platform.inc.c:bhv_wf_sliding_tower_platform_loop L47-74
function tower_platform_inc.bhv_wf_sliding_tower_platform_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp24 = S32(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformUnk110) / buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformUnk10C))))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > Sp24 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformUnk10C))
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > Sp24 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformUnk10C))
	end

	ObjectHelpers.cur_obj_compute_vel_xz()

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 3 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/tower_platform.inc.c:spawn_and_init_wf_platforms L76-90
function tower_platform_inc.spawn_and_init_wf_platforms(a: number, bhv: number)
	a = S16(TruncS32(a))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Platform = ObjectHelpers.spawn_object(o, a, bhv)
	const Yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF4) * buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkFC) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF8))

	buffer.writei32(Platform.rawData, IncludeObjectFieldsH.oMoveAngleYaw, Yaw)
	buffer.writef32(Platform.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(Platform.rawData, IncludeObjectFieldsH.oPosX) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk100) * SrcEngineMathUtilH.sins(Yaw)))
	buffer.writef32(Platform.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(Platform.rawData, IncludeObjectFieldsH.oPosY) + 100 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF4))
	buffer.writef32(Platform.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(Platform.rawData, IncludeObjectFieldsH.oPosZ) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk100) * SrcEngineMathUtilH.coss(Yaw)))
	buffer.writef32(Platform.rawData, IncludeObjectFieldsH.oPlatformUnk110, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk104))
	buffer.writef32(Platform.rawData, IncludeObjectFieldsH.oPlatformUnk10C, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk108))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF4) + 1)
end

-- from src/game/behaviors/tower_platform.inc.c:spawn_wf_platform_group L92-110
function tower_platform_inc.spawn_wf_platform_group()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF4, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkF8, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnkFC, 0x2000)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk100, 704.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk104, 380.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPlatformSpawnerUnk108, 3.0)

	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSolidTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSlidingTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSolidTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSlidingTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSolidTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSlidingTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM, BehaviorIds.bhvWFSolidTowerPlatform)
	tower_platform_inc.spawn_and_init_wf_platforms(IncludeModelIdsH.MODEL_WF_TOWER_SQUARE_PLATORM_ELEVATOR, BehaviorIds.bhvWFElevatorTowerPlatform)
end

-- from src/game/behaviors/tower_platform.inc.c:bhv_tower_platform_group_loop L112-139
function tower_platform_inc.bhv_tower_platform_group_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const MarioY = buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, ObjectHelpers.dist_between_objects(o, MarioObject))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if MarioY > F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 1000.0) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		tower_platform_inc.spawn_wf_platform_group()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if MarioY < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 1000.0) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

return tower_platform_inc
