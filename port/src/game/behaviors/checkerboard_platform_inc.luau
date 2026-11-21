--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/checkerboard_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

-- from src/game/behaviors/checkerboard_platform.inc.c:Struct8032F754
export type Struct8032F754 = {
	unk0: number,
	unk1: { number },
	unk2: number,
}

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

-- from src/game/behaviors/checkerboard_platform.inc.c:data
const checkerboard_platform_inc = {
	-- from src/game/behaviors/checkerboard_platform.inc.c:D_8032F754 L9-12
	D_8032F754 = {
		{ unk0 = 145, unk1 = { F32(0.7), 1.5, F32(0.7) }, unk2 = 7.0 },
		{ unk0 = 235, unk1 = { F32(1.2), 2.0, F32(1.2) }, unk2 = F32(11.6) },
	},
}

Registry.Register("src__game__behaviors__checkerboard_platform_inc", checkerboard_platform_inc)

-- from src/game/behaviors/checkerboard_platform.inc.c:Struct8032F754 (zero-filled constructor)
function checkerboard_platform_inc.new_Struct8032F754(): Struct8032F754
	return { unk0 = 0, unk1 = table.create(3, 0), unk2 = 0 } :: Struct8032F754
end

-- from src/game/behaviors/checkerboard_platform.inc.c:bhv_checkerboard_elevator_group_init L14-40
function checkerboard_platform_inc.bhv_checkerboard_elevator_group_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 65)
	end

	const Sp3C = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) * 10
	const Sp34 = bit32.band(bit32.rshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24), 0xFF)

	for i = 0, 1 do
		local Sp38: number

		if i == 0 then
			Sp38 = -checkerboard_platform_inc.D_8032F754[Sp34 + 1].unk0
		else
			Sp38 = checkerboard_platform_inc.D_8032F754[Sp34 + 1].unk0
		end

		const Sp2C = ObjectHelpers.spawn_object_relative(S16(i), 0, S16(i * Sp3C), S16(Sp38), o, IncludeModelIdsH.MODEL_CHECKERBOARD_PLATFORM, BehaviorIds.bhvCheckerboardPlatformSub)

		buffer.writef32(Sp2C.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnk1AC, checkerboard_platform_inc.D_8032F754[Sp34 + 1].unk2)
		BehaviorActions.vec3f_copy_2(Sp2C.header.gfx.scale, checkerboard_platform_inc.D_8032F754[Sp34 + 1].unk1)
	end
end

-- from src/game/behaviors/checkerboard_platform.inc.c:checkerboard_plat_act_move_y L42-50
function checkerboard_platform_inc.checkerboard_plat_act_move_y(unused: number, vel: number, a2: number)
	vel = F32(vel)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, vel)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > a2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
	end
end

-- from src/game/behaviors/checkerboard_platform.inc.c:checkerboard_plat_act_rotate L52-59
function checkerboard_platform_inc.checkerboard_plat_act_rotate(a0: number, a1: number)
	a1 = S16(TruncS32(a1))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, a1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 1 == 0x8000 // ObjectHelpers.absi(a1) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, a0)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkF8, a0)
end

-- from src/game/behaviors/checkerboard_platform.inc.c:bhv_checkerboard_platform_init L61-63
function checkerboard_platform_inc.bhv_checkerboard_platform_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkFC, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
end

-- from src/game/behaviors/checkerboard_platform.inc.c:bhv_checkerboard_platform_loop L65-114
function checkerboard_platform_inc.bhv_checkerboard_platform_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp24 = buffer.readf32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnk1AC)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkF8, 0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR4)
	end

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	elseif action == 1 then
		checkerboard_platform_inc.checkerboard_plat_act_move_y(2, 10.0, buffer.readi32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkFC))
	elseif action == 2 then
		checkerboard_platform_inc.checkerboard_plat_act_rotate(3, 512)
	elseif action == 3 then
		checkerboard_platform_inc.checkerboard_plat_act_move_y(4, -10.0, buffer.readi32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkFC))
	elseif action == 4 then
		checkerboard_platform_inc.checkerboard_plat_act_rotate(1, -512)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + ObjectHelpers.absi(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + ObjectHelpers.absi(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(ObjectHelpers.signum_positive(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)) * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))) * Sp24)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, F32(ObjectHelpers.signum_positive(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)) * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))) * Sp24)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCheckerBoardPlatformUnkF8) == 1 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, S32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch), bit32.bnot(0x7FFF))))
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	else
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end

	SrcEngineSurfaceLoad.load_object_collision_model()
end

return checkerboard_platform_inc
