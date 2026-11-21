--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/controllable_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/controllable_platform_inc.luau:scratch
const Scratch = {
	bhv_controllable_platform_loop_sp54 = { 0, 0, 0 },
	bhv_controllable_platform_loop_sp48 = { 0, 0, 0 },
	bhv_controllable_platform_loop_sp3C = { 0, 0, 0 },
	bhv_controllable_platform_loop_sp30 = { 0, 0, 0 },
}

-- from src/game/behaviors/controllable_platform.inc.c:data
const controllable_platform_inc = {
	-- from src/game/behaviors/controllable_platform.inc.c:D_80331694 L3-3
	D_80331694 = 0,
}

Registry.Register("src__game__behaviors__controllable_platform_inc", controllable_platform_inc)

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_act_1 L5-11
function controllable_platform_inc.controllable_platform_act_1()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY) - 4)
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY) < 41 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, 41)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_act_2 L13-23
function controllable_platform_inc.controllable_platform_act_2()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == controllable_platform_inc.D_80331694 then
		return
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY) + 4)
	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY) > 51 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, 51)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:bhv_controllable_platform_sub_loop L25-57
function controllable_platform_inc.bhv_controllable_platform_sub_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 30 then
			if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
				controllable_platform_inc.D_80331694 = S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))

				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_MOVING_PLATFORM_SWITCH)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		controllable_platform_inc.controllable_platform_act_1()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		controllable_platform_inc.controllable_platform_act_2()
	end

	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oVelZ))

	if parent.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:bhv_controllable_platform_init L59-78
function controllable_platform_inc.bhv_controllable_platform_init()
	const o = ObjectListProcessor.gCurrentObject

	local sp34 = ObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_HMC_METAL_ARROW_PLATFORM, BehaviorIds.bhvControllablePlatformSub, 0, 51, 204, 0, 0, 0)
	buffer.writei32(sp34.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 1)
	sp34 = ObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_HMC_METAL_ARROW_PLATFORM, BehaviorIds.bhvControllablePlatformSub, 0, 51, -204, 0, -0x8000, 0)
	buffer.writei32(sp34.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 2)
	sp34 = ObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_HMC_METAL_ARROW_PLATFORM, BehaviorIds.bhvControllablePlatformSub, 204, 51, 0, 0, 0x4000, 0)
	buffer.writei32(sp34.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 3)
	sp34 = ObjectHelpers.spawn_object_rel_with_rot(o, IncludeModelIdsH.MODEL_HMC_METAL_ARROW_PLATFORM, BehaviorIds.bhvControllablePlatformSub, -204, 51, 0, 0, -0x4000, 0)
	buffer.writei32(sp34.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, 4)

	controllable_platform_inc.D_80331694 = 0

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkFC, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
end

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_hit_wall L80-89
function controllable_platform_inc.controllable_platform_hit_wall(sp1B: number)
	sp1B = S8(TruncS32(sp1B))
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkF8, sp1B)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	controllable_platform_inc.D_80331694 = 5

	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_POUND1)
end

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_check_walls L91-121
function controllable_platform_inc.controllable_platform_check_walls(sp1B: number, sp1C: { number }, sp20: { number }, sp24: { number }, sp28: { number })
	sp1B = S8(TruncS32(sp1B))
	const o = ObjectListProcessor.gCurrentObject

	if sp1C[2] == 1 or (sp1C[1] == 1 and sp1C[3] == 1) then
		controllable_platform_inc.controllable_platform_hit_wall(sp1B)
	else
		if sp1C[1] == 1 then
			if ((sp1B == 1 or sp1B == 2) and TruncS32(sp20[3]) ~= 0)
				or ((sp1B == 3 or sp1B == 4) and TruncS32(sp20[1]) ~= 0) then
				controllable_platform_inc.controllable_platform_hit_wall(sp1B)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + sp20[1])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + sp20[3])
			end
		end

		if sp1C[3] == 1 then
			if ((sp1B == 1 or sp1B == 2) and TruncS32(sp28[3]) ~= 0)
				or ((sp1B == 3 or sp1B == 4) and TruncS32(sp28[1]) ~= 0) then
				controllable_platform_inc.controllable_platform_hit_wall(sp1B)
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + sp28[1])
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + sp28[3])
			end
		end
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 400) == 0 then
		controllable_platform_inc.D_80331694 = 6
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnk100, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_shake_on_wall_hit L123-138
function controllable_platform_inc.controllable_platform_shake_on_wall_hit()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkF8) == 1 or buffer.readi32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkF8) == 2 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 182.04444 * 10))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkFC) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x2000) * 20))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x1000) * 182.04444 * 10))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkFC) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) * 0x2000) * 20))
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 32 then
		controllable_platform_inc.D_80331694 = S8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkF8))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnkFC))
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:controllable_platform_tilt_from_mario L140-155
function controllable_platform_inc.controllable_platform_tilt_from_mario()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	-- from src/game/behaviors/controllable_platform.inc.c:sp1E
	const sp1E = S16(TruncS32(F32(mario.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))))
	-- from src/game/behaviors/controllable_platform.inc.c:sp1C
	const sp1C = S16(TruncS32(F32(mario.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))))

	if mario.platform == o or mario.platform == ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvControllablePlatformSub) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, sp1C * 4)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -sp1E * 4)
		if controllable_platform_inc.D_80331694 == 6 then
			controllable_platform_inc.D_80331694 = 0
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	else
		-- Empty in the C source.
	end
end

-- from src/game/behaviors/controllable_platform.inc.c:bhv_controllable_platform_loop L157-229
function controllable_platform_inc.bhv_controllable_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 0)

	if controllable_platform_inc.D_80331694 == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) / 2))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) / 2))
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oControllablePlatformUnk100) == 1 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			controllable_platform_inc.D_80331694 = 6
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		end
	elseif controllable_platform_inc.D_80331694 == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, 10)
		Scratch.bhv_controllable_platform_loop_sp54[1] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp48, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 250), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 300), 50))
		Scratch.bhv_controllable_platform_loop_sp54[2] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp3C, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 300), 50))
		Scratch.bhv_controllable_platform_loop_sp54[3] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp30, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - 250), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 300), 50))
		controllable_platform_inc.controllable_platform_check_walls(2, Scratch.bhv_controllable_platform_loop_sp54, Scratch.bhv_controllable_platform_loop_sp48, Scratch.bhv_controllable_platform_loop_sp3C, Scratch.bhv_controllable_platform_loop_sp30)
	elseif controllable_platform_inc.D_80331694 == 2 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, -10)
		Scratch.bhv_controllable_platform_loop_sp54[1] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp48, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 250), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - 300), 50))
		Scratch.bhv_controllable_platform_loop_sp54[2] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp3C, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - 300), 50))
		Scratch.bhv_controllable_platform_loop_sp54[3] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp30, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - 250), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - 300), 50))
		controllable_platform_inc.controllable_platform_check_walls(1, Scratch.bhv_controllable_platform_loop_sp54, Scratch.bhv_controllable_platform_loop_sp48, Scratch.bhv_controllable_platform_loop_sp3C, Scratch.bhv_controllable_platform_loop_sp30)
	elseif controllable_platform_inc.D_80331694 == 3 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, 10)
		Scratch.bhv_controllable_platform_loop_sp54[1] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp48, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 250), 50))
		Scratch.bhv_controllable_platform_loop_sp54[2] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp3C, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 50))
		Scratch.bhv_controllable_platform_loop_sp54[3] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp30, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - 250), 50))
		controllable_platform_inc.controllable_platform_check_walls(4, Scratch.bhv_controllable_platform_loop_sp54, Scratch.bhv_controllable_platform_loop_sp48, Scratch.bhv_controllable_platform_loop_sp3C, Scratch.bhv_controllable_platform_loop_sp30)
	elseif controllable_platform_inc.D_80331694 == 4 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, -10)
		Scratch.bhv_controllable_platform_loop_sp54[1] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp48, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 250), 50))
		Scratch.bhv_controllable_platform_loop_sp54[2] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp3C, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 50))
		Scratch.bhv_controllable_platform_loop_sp54[3] = S8(ObjBehaviors.obj_find_wall_displacement(Scratch.bhv_controllable_platform_loop_sp30, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - 300), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - 250), 50))
		controllable_platform_inc.controllable_platform_check_walls(3, Scratch.bhv_controllable_platform_loop_sp54, Scratch.bhv_controllable_platform_loop_sp48, Scratch.bhv_controllable_platform_loop_sp3C, Scratch.bhv_controllable_platform_loop_sp30)
	elseif controllable_platform_inc.D_80331694 == 5 then
		controllable_platform_inc.controllable_platform_shake_on_wall_hit()
		return
	elseif controllable_platform_inc.D_80331694 == 6 then
		if ObjBehaviors.obj_flicker_and_disappear(o, 150) ~= 0 then
			ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_HMC_METAL_PLATFORM, BehaviorIds.bhvControllablePlatform, S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))), S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))), 0, 0, 0)
		end
	end

	controllable_platform_inc.controllable_platform_tilt_from_mario()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
	if controllable_platform_inc.D_80331694 ~= 0 and controllable_platform_inc.D_80331694 ~= 6 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR2)
	end
end

return controllable_platform_inc
