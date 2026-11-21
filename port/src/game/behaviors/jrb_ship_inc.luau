--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/jrb_ship.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

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

-- from src/game/behaviors/jrb_ship_inc.luau:scratch
const Scratch = {
	bhv_jrb_sliding_box_loop_sp60 = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
	bhv_jrb_sliding_box_loop_sp54 = { 0, 0, 0 },
	bhv_jrb_sliding_box_loop_sp48 = { 0, 0, 0 },
	bhv_jrb_sliding_box_loop_sp40 = { 0, 0, 0 },
	bhv_jrb_sliding_box_loop_sp38 = {},
}

-- from src/game/behaviors/jrb_ship.inc.c:data
const jrb_ship_inc = {
	-- from src/game/behaviors/jrb_ship.inc.c:sSkullSlidingBoxHitbox L3-13
	sSkullSlidingBoxHitbox = {
		interactType = InteractionH.INTERACT_DAMAGE,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 1,
		numLootCoins = 0,
		radius = 130,
		height = 100,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__jrb_ship_inc", jrb_ship_inc)

-- from src/game/behaviors/jrb_ship.inc.c:bhv_sunken_ship_part_loop L15-23
function jrb_ship_inc.bhv_sunken_ship_part_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const distToMario = buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario)

	if distToMario > 10000.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 140)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, TruncS32(F32(distToMario * 140.0) / 10000.0))
	end

	ObjectHelpers.cur_obj_disable_rendering()
end

-- from src/game/behaviors/jrb_ship.inc.c:bhv_ship_part_3_loop L25-41
function jrb_ship_inc.bhv_ship_part_3_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	const sp1E = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	const sp1C = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))

	ObjectHelpers.cur_obj_set_pos_to_home_with_debug()

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oShipPart3UnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oShipPart3UnkF4) + 0x100))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oShipPart3UnkF4)) * 0x400))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oShipPart3UnkF8)) * 0x400))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - sp1E))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - sp1C))

	if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) > 1000.0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_BOAT_ROCKING1)
	end
end

-- from src/game/behaviors/jrb_ship.inc.c:bhv_jrb_sliding_box_loop L43-117
function jrb_ship_inc.bhv_jrb_sliding_box_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
	local sp1E = 0

	if o.ptrData[IncludeObjectFieldsH.oJRBSlidingBoxUnkF4 + 1] == nil then
		const nearest = ObjectHelpers.cur_obj_nearest_object_with_behavior(BehaviorIds.bhvInSunkenShip3) :: GroupsTypesHPlus3.Object?

		if nearest ~= nil then
			o.ptrData[IncludeObjectFieldsH.oJRBSlidingBoxUnkF4 + 1] = nearest
		end

		const sp3C = nearest :: GroupsTypesHPlus3.Object

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosZ))
	else
		const sp3C = o.ptrData[IncludeObjectFieldsH.oJRBSlidingBoxUnkF4 + 1] :: GroupsTypesHPlus3.Object

		Scratch.bhv_jrb_sliding_box_loop_sp40[1] = S16(buffer.readi32(sp3C.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		Scratch.bhv_jrb_sliding_box_loop_sp40[2] = S16(buffer.readi32(sp3C.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		Scratch.bhv_jrb_sliding_box_loop_sp40[3] = S16(buffer.readi32(sp3C.rawData, IncludeObjectFieldsH.oFaceAngleRoll))

		Scratch.bhv_jrb_sliding_box_loop_sp54[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosX)
		Scratch.bhv_jrb_sliding_box_loop_sp54[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosY)
		Scratch.bhv_jrb_sliding_box_loop_sp54[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ)

		SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(Scratch.bhv_jrb_sliding_box_loop_sp60, Scratch.bhv_jrb_sliding_box_loop_sp54, Scratch.bhv_jrb_sliding_box_loop_sp40)
		ObjectHelpers.linear_mtxf_mul_vec3f(Scratch.bhv_jrb_sliding_box_loop_sp60, Scratch.bhv_jrb_sliding_box_loop_sp48, Scratch.bhv_jrb_sliding_box_loop_sp54)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosX) + Scratch.bhv_jrb_sliding_box_loop_sp48[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosY) + Scratch.bhv_jrb_sliding_box_loop_sp48[2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(sp3C.rawData, IncludeObjectFieldsH.oPosZ) + Scratch.bhv_jrb_sliding_box_loop_sp48[3])

		sp1E = S16(buffer.readi32(sp3C.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	end

	SrcEngineSurfaceCollision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.bhv_jrb_sliding_box_loop_sp38)

	if Scratch.bhv_jrb_sliding_box_loop_sp38[1] ~= nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, sp1E)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkFC, SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkF8)) * 20.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkF8) + 0x100))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oParentRelativePosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkFC))

	if buffer.readf32(marioObj.rawData, IncludeObjectFieldsH.oPosY) > 1000.0 and ObjectHelpers.absf(buffer.readf32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkFC)) > 3.0 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_ROUGH_SLIDE)
	end

	ObjectHelpers.obj_set_hitbox(o, jrb_ship_inc.sSkullSlidingBoxHitbox)

	if not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oJRBSlidingBoxUnkF8), 0x7FFF) then
		ObjectHelpers.cur_obj_become_tangible()
	end

	if ObjectHelpers.obj_check_if_collided_with_object(o, marioObj) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		ObjectHelpers.cur_obj_become_intangible()
	end
end

return jrb_ship_inc
