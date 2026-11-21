--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_falling_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

-- from src/game/behaviors/bowser_falling_platform.inc.c:BowserFallingPlatformData
export type BowserFallingPlatformData = {
	collision: number?,
	posX: number,
	posZ: number,
	angle: number,
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

-- from src/game/behaviors/bowser_falling_platform_inc.luau:scratch
const Scratch = {
	falling_bowser_plat_act_fall_pos = table.create(3, 0),
	falling_bowser_plat_act_fall_objPos = table.create(3, 0),
}

-- from src/game/behaviors/bowser_falling_platform.inc.c:data
const bowser_falling_platform_inc = {
	-- from src/game/behaviors/bowser_falling_platform.inc.c:sBowserFallingPlatform L10-22
	sBowserFallingPlatform = {
		{ collision = nil, posX = 0, posZ = 0, angle = 0 },
		{
			collision = 0x07004B94 --[[ bowser_3_seg7_collision_07004B94 ]],
			posX = -800,
			posZ = -1000,
			angle = -20992,
		},
		{
			collision = 0x07004C18 --[[ bowser_3_seg7_collision_07004C18 ]],
			posX = -1158,
			posZ = 390,
			angle = -18432,
		},
		{
			collision = 0x07004C9C --[[ bowser_3_seg7_collision_07004C9C ]],
			posX = -1158,
			posZ = 390,
			angle = -7680,
		},
		{ collision = 0x07004D20 --[[ bowser_3_seg7_collision_07004D20 ]], posX = 0, posZ = 1240, angle = -6144 },
		{ collision = 0x07004DA4 --[[ bowser_3_seg7_collision_07004DA4 ]], posX = 0, posZ = 1240, angle = 6144 },
		{ collision = 0x07004E28 --[[ bowser_3_seg7_collision_07004E28 ]], posX = 1158, posZ = 390, angle = 7680 },
		{
			collision = 0x07004EAC --[[ bowser_3_seg7_collision_07004EAC ]],
			posX = 1158,
			posZ = 390,
			angle = 18432,
		},
		{
			collision = 0x07004F30 --[[ bowser_3_seg7_collision_07004F30 ]],
			posX = 800,
			posZ = -1000,
			angle = 20992,
		},
		{
			collision = 0x07004FB4 --[[ bowser_3_seg7_collision_07004FB4 ]],
			posX = 800,
			posZ = -1000,
			angle = -31744,
		},
		{
			collision = 0x07005038 --[[ bowser_3_seg7_collision_07005038 ]],
			posX = -800,
			posZ = -1000,
			angle = 31744,
		},
	},
}

Registry.Register("src__game__behaviors__bowser_falling_platform_inc", bowser_falling_platform_inc)

-- from src/game/behaviors/bowser_falling_platform.inc.c:BowserFallingPlatformData (zero-filled constructor)
function bowser_falling_platform_inc.new_BowserFallingPlatformData(): BowserFallingPlatformData
	return { collision = nil, posX = 0, posZ = 0, angle = 0 } :: BowserFallingPlatformData
end

-- from src/game/behaviors/bowser_falling_platform.inc.c:falling_bowser_plat_act_start L24-30
function bowser_falling_platform_inc.falling_bowser_plat_act_start()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	o.ptrData[IncludeObjectFieldsH.oBitSPlatformBowser + 1] = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvBowser)
	ObjectHelpers.obj_set_collision_data(o, bowser_falling_platform_inc.sBowserFallingPlatform[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1].collision :: number)

	if o.ptrData[IncludeObjectFieldsH.oBitSPlatformBowser + 1] ~= nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_BITS_PLAT_ACT_CHECK)
	end
end

-- from src/game/behaviors/bowser_falling_platform.inc.c:falling_bowser_plat_act_check L32-57
function bowser_falling_platform_inc.falling_bowser_plat_act_check()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const bowser = o.ptrData[IncludeObjectFieldsH.oBitSPlatformBowser + 1] :: GroupsTypesHPlus3.Object

	if bowser.platform == o then
		if buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_BIG_JUMP and bit32.btest(buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oBowserStatus), IncludeObjectConstantsH.BOWSER_STATUS_BIG_JUMP) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_BITS_PLAT_ACT_FALL)
		end
	end

	if buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oHealth) == 1 and (buffer.readi32(bowser.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.BOWSER_ACT_DANCE or buffer.readu32(bowser.rawData, IncludeObjectFieldsH.oHeldState) ~= IncludeObjectConstantsH.HELD_FREE) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBitSPlatformTimer, 0)
	else
		if (ObjectListProcessor.gDebugInfo[5][7] + 20) * (buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) - 1) < buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitSPlatformTimer) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.BOWSER_BITS_PLAT_ACT_FALL)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBitSPlatformTimer, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBitSPlatformTimer) + 1)
	end
end

-- from src/game/behaviors/bowser_falling_platform.inc.c:falling_bowser_plat_act_fall L59-97
function bowser_falling_platform_inc.falling_bowser_plat_act_fall()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const timer = buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer)

	if timer == 0 or timer == 22 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOWSER_PLATFORM_2)
	end

	if timer < 22 then
		Camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_FALLING_BITS_PLAT)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 8.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -4.0)
	end

	if bit32.band(timer, 1) == 0 and timer < 14 then
		const platform = bowser_falling_platform_inc.sBowserFallingPlatform[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]
		const angle = S16(platform.angle + S32(bit32.lshift(ObjectListProcessor.gDebugInfo[5][2], 8)))
		const val = -(timer // 2) * 290 + 1740

		Scratch.falling_bowser_plat_act_fall_objPos[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
		Scratch.falling_bowser_plat_act_fall_objPos[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
		Scratch.falling_bowser_plat_act_fall_objPos[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
		BehaviorActions.vec3f_copy_2(Scratch.falling_bowser_plat_act_fall_pos, Scratch.falling_bowser_plat_act_fall_objPos)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, platform.posX + F32(SrcEngineMathUtilH.sins(angle + 0x14B0) * val))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, platform.posZ + F32(SrcEngineMathUtilH.coss(angle + 0x14B0) * val))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 307.0)
		BehaviorActions.spawn_mist_particles_variable(4, 0, 100.0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, platform.posX + F32(SrcEngineMathUtilH.sins(angle - 0x14B0) * val))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, platform.posZ + F32(SrcEngineMathUtilH.coss(angle - 0x14B0) * val))
		BehaviorActions.spawn_mist_particles_variable(4, 0, 100.0)

		BehaviorActions.vec3f_copy_2(Scratch.falling_bowser_plat_act_fall_objPos, Scratch.falling_bowser_plat_act_fall_pos)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, Scratch.falling_bowser_plat_act_fall_objPos[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, Scratch.falling_bowser_plat_act_fall_objPos[2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, Scratch.falling_bowser_plat_act_fall_objPos[3])
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if timer > 300 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/bowser_falling_platform.inc.c:bhv_falling_bowser_platform_loop L105-107
function bowser_falling_platform_inc.bhv_falling_bowser_platform_loop()
	ObjectHelpers.cur_obj_call_action_function(bowser_falling_platform_inc.sFallingBowserPlatformActions)
end

-- from src/game/behaviors/bowser_falling_platform.inc.c:sFallingBowserPlatformActions L99-103
bowser_falling_platform_inc.sFallingBowserPlatformActions = {
	bowser_falling_platform_inc.falling_bowser_plat_act_start,
	bowser_falling_platform_inc.falling_bowser_plat_act_check,
	bowser_falling_platform_inc.falling_bowser_plat_act_fall,
}

return bowser_falling_platform_inc
