--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tree_particles.inc.c.
]]

const Registry = require("../../../groups/registry")
const Area = require("../area")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeLevelTableH = require("../../../include/level_table_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const ObjectListProcessorH = require("../object_list_processor_h")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")

const tree_particles_inc = {}

Registry.Register("src__game__behaviors__tree_particles_inc", tree_particles_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/tree_particles.inc.c:bhv_tree_snow_or_leaf_loop L3-44
function tree_particles_inc.bhv_tree_snow_or_leaf_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_update_floor_height()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, S32(TruncS32((SrcEngineBehaviorScript.random_float() - 0.5) * 0x1000)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll, S32(TruncS32((SrcEngineBehaviorScript.random_float() - 0.5) * 0x1000)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF8, 4)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkFC, S32(TruncS32(F32(F32(SrcEngineBehaviorScript.random_float() * 0x400) + 0x600))))
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloorHeight) < SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	if ObjectListProcessor.gPrevFrameObjectCount > ObjectListProcessorH.OBJECT_POOL_CAPACITY - 28 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelRoll))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + -3.0)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -8.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -8.0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) - 0.3)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
	end

	const SinMoveAngleYaw: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const CosMoveAngleYaw: number = Registry.Members.src__engine__math_util_h.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const SinFloatYaw: number = Registry.Members.src__engine__math_util_h.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF4))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SinMoveAngleYaw * SinFloatYaw) * buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF8)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(CosMoveAngleYaw * SinFloatYaw) * buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF8)))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF4, buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkF4) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreeSnowOrLeafUnkFC))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

-- from src/game/behaviors/tree_particles.inc.c:bhv_snow_leaf_particle_spawn_init L46-83
function tree_particles_inc.bhv_snow_leaf_particle_spawn_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	buffer.writeu32(MarioObj.rawData, IncludeObjectFieldsH.oActiveParticleFlags, bit32.band(buffer.readu32(MarioObj.rawData, IncludeObjectFieldsH.oActiveParticleFlags), bit32.bnot(IncludeObjectConstantsH.ACTIVE_PARTICLE_LEAF)))

	local IsSnow: number

	if Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CCM or Area.gCurrLevelNum == IncludeLevelTableH.LEVEL_SL then
		IsSnow = IncludePRUltratypesH.TRUE
	else
		IsSnow = IncludePRUltratypesH.FALSE
	end

	if IsSnow ~= 0 then
		if SrcEngineBehaviorScript.random_float() < 0.5 then
			const SnowObj = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_DL, BehaviorIds.bhvTreeSnow)
			const SnowScale = SrcEngineBehaviorScript.random_float()

			ObjectHelpers.obj_scale_xyz(SnowObj, SnowScale, SnowScale, SnowScale)
			buffer.writei32(SnowObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
			buffer.writef32(SnowObj.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 5.0))
			buffer.writef32(SnowObj.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 15.0))
		end
	else
		if SrcEngineBehaviorScript.random_float() < 0.3 then
			const LeafObj = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_LEAVES, BehaviorIds.bhvTreeLeaf)
			const LeafScale = F32(SrcEngineBehaviorScript.random_float() * 3.0)

			ObjectHelpers.obj_scale_xyz(LeafObj, LeafScale, LeafScale, LeafScale)
			buffer.writei32(LeafObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())
			buffer.writef32(LeafObj.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 5.0) + 5.0)
			buffer.writef32(LeafObj.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 15.0))
			buffer.writei32(LeafObj.rawData, IncludeObjectFieldsH.oFaceAnglePitch, SrcEngineBehaviorScript.random_u16())
			buffer.writei32(LeafObj.rawData, IncludeObjectFieldsH.oFaceAngleRoll, SrcEngineBehaviorScript.random_u16())
			buffer.writei32(LeafObj.rawData, IncludeObjectFieldsH.oFaceAngleYaw, SrcEngineBehaviorScript.random_u16())
		end
	end
end

return tree_particles_inc
