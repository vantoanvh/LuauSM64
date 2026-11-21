--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/butterfly.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const butterfly_inc = {}

Registry.Register("src__game__behaviors__butterfly_inc", butterfly_inc)

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

-- from src/game/behaviors/butterfly_inc.luau:scratch
const Scratch = {
	butterfly_step_floorGeo = {},
}

-- from src/game/behaviors/butterfly.inc.c:bhv_butterfly_init L3-11
function butterfly_inc.bhv_butterfly_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_init_animation(1)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 100.0)))
	o.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 7.0)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/behaviors/butterfly.inc.c:butterfly_step L13-43
function butterfly_inc.butterfly_step(speed: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const Pitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	const YPhase = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, SrcEngineMathUtilH.sins(Yaw) * speed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.sins(Pitch) * speed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, SrcEngineMathUtilH.coss(Yaw) * speed)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BUTTERFLY_ACT_FOLLOW_MARIO then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + F32(F32(SrcEngineMathUtilH.coss(TruncS32(YPhase * 655.36)) * 20.0) / 4)))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	end

	const FloorY = SrcEngineSurfaceCollision.find_floor_height_and_data(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.butterfly_step_floorGeo)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(FloorY + 2.0) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, FloorY + 2.0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) + 1))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) > 100 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase, 0)
	end
end

-- from src/game/behaviors/butterfly.inc.c:butterfly_calculate_angle L45-55
function butterfly_inc.butterfly_calculate_angle()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX) + 5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) // 4)
	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ) + 5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) // 4)
	ObjectHelpers.obj_turn_toward_object(o, MarioObject, 16, 0x300)
	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX) - 5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) // 4)
	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ) - 5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) // 4)

	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY) + (5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) + 0x100) // 4)
	ObjectHelpers.obj_turn_toward_object(o, MarioObject, 15, 0x500)
	buffer.writef32(MarioObject.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY) - (5 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oButterflyYPhase) + 0x100) // 4)
end

-- from src/game/behaviors/butterfly.inc.c:butterfly_act_rest L57-64
function butterfly_inc.butterfly_act_rest()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1000) ~= 0 then
		ObjectHelpers.cur_obj_init_animation(0)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BUTTERFLY_ACT_FOLLOW_MARIO)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).header.gfx.angle[2])
	end
end

-- from src/game/behaviors/butterfly.inc.c:butterfly_act_follow_mario L66-74
function butterfly_inc.butterfly_act_follow_mario()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	butterfly_inc.butterfly_calculate_angle()
	butterfly_inc.butterfly_step(7)

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ), 1200) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BUTTERFLY_ACT_RETURN_HOME)
	end
end

-- from src/game/behaviors/butterfly.inc.c:butterfly_act_return_home L76-96
function butterfly_inc.butterfly_act_return_home()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const HomeDistX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const HomeDistY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	const HomeDistZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const HAngleToHome = S16(SrcEngineMathUtil.atan2s(HomeDistZ, HomeDistX))
	const VAngleToHome = S16(SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(HomeDistX * HomeDistX) + F32(HomeDistZ * HomeDistZ)))), -HomeDistY))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), HAngleToHome, 0x800))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), VAngleToHome, 0x50))

	butterfly_inc.butterfly_step(7)

	if F32(F32(F32(HomeDistX * HomeDistX) + F32(HomeDistY * HomeDistY)) + F32(HomeDistZ * HomeDistZ)) < 144.0 then
		ObjectHelpers.cur_obj_init_animation(1)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BUTTERFLY_ACT_RESTING)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
	end
end

-- from src/game/behaviors/butterfly.inc.c:bhv_butterfly_loop L98-114
function butterfly_inc.bhv_butterfly_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BUTTERFLY_ACT_RESTING then
		butterfly_inc.butterfly_act_rest()
	elseif action == IncludeObjectConstantsH.BUTTERFLY_ACT_FOLLOW_MARIO then
		butterfly_inc.butterfly_act_follow_mario()
	elseif action == IncludeObjectConstantsH.BUTTERFLY_ACT_RETURN_HOME then
		butterfly_inc.butterfly_act_return_home()
	end

	ObjBehaviors.set_object_visibility(o, 3000)
end

return butterfly_inc
