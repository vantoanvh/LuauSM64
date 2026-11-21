--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/cloud.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const StrongWindParticleInc = require("./strong_wind_particle_inc")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/cloud_inc.luau:scratch
const Scratch = {
	cloud_fwoosh_update_scale = buffer.create(4),
}

-- from src/game/behaviors/cloud.inc.c:data
const cloud_inc = {
	-- from src/game/behaviors/cloud.inc.c:sCloudPartHeights L15-15
	sCloudPartHeights = { 11, 8, 12, 8, 9, 9 },
}

Registry.Register("src__game__behaviors__cloud_inc", cloud_inc)

-- from src/game/behaviors/cloud.inc.c:cloud_act_spawn_parts L20-44
function cloud_inc.cloud_act_spawn_parts()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- Spawn the pieces of the cloud itself
	for i = 0, 4 do
		const CloudPart: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative(i, 0, 0, 0, o, IncludeModelIdsH.MODEL_MIST, BehaviorIds.bhvCloudPart)

		if CloudPart ~= nil then
			ObjectHelpers.obj_set_billboard(CloudPart)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == IncludeObjectConstantsH.CLOUD_BP_FWOOSH then
		-- Spawn fwoosh's face
		ObjectHelpers.spawn_object_relative(5, 0, 0, 0, o, IncludeModelIdsH.MODEL_FWOOSH, BehaviorIds.bhvCloudPart)

		ObjectHelpers.cur_obj_scale(3.0)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_MAIN)
end

-- from src/game/behaviors/cloud.inc.c:cloud_act_fwoosh_hidden L49-54
function cloud_inc.cloud_act_fwoosh_hidden()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000.0 then
		ObjectHelpers.cur_obj_unhide()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_SPAWN_PARTS)
	end
end

-- from src/game/behaviors/cloud.inc.c:cloud_fwoosh_update L60-99
function cloud_inc.cloud_fwoosh_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_UNLOAD)
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCloudBlowing) ~= 0 then
			o.header.gfx.scale[2] = F32(o.header.gfx.scale[2] + buffer.readf32(o.rawData, IncludeObjectFieldsH.oCloudGrowSpeed))

			const NewGrowSpeed = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCloudGrowSpeed) - F32(0.005))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudGrowSpeed, NewGrowSpeed)

			if NewGrowSpeed < F32(-0.16) then
				-- Stop blowing once we are shrinking faster than -0.16
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oCloudBlowing, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			elseif NewGrowSpeed < F32(-0.1) then
				-- Start blowing once we start shrinking faster than -0.1
				SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_AIR_BLOW_WIND)
				StrongWindParticleInc.cur_obj_spawn_strong_wind_particles(12, 3.0, 0.0, -50.0, 120.0)
			else
				SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WIND1)
			end
		else
			-- Return to normal size
			buffer.writef32(Scratch.cloud_fwoosh_update_scale, 0, o.header.gfx.scale[2])
			ObjBehaviors2.approach_f32_ptr(Scratch.cloud_fwoosh_update_scale, 0, 3.0, F32(0.012))
			o.header.gfx.scale[2] = buffer.readf32(Scratch.cloud_fwoosh_update_scale, 0)

			buffer.writei16(o.rawData, IncludeObjectFieldsH.oCloudFwooshMovementRadius, S16(buffer.readi16(o.rawData, IncludeObjectFieldsH.oCloudFwooshMovementRadius) + 0xC8))

			-- If mario stays nearby for 100 frames, begin blowing
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 100 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oCloudBlowing, IncludePRUltratypesH.TRUE)
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudGrowSpeed, 0.14)
				end
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end

			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) + F32(100.0 * SrcEngineMathUtilH.coss(buffer.readi16(o.rawData, IncludeObjectFieldsH.oCloudFwooshMovementRadius))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) + F32(100.0 * SrcEngineMathUtilH.sins(buffer.readi16(o.rawData, IncludeObjectFieldsH.oCloudFwooshMovementRadius))))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		end

		ObjectHelpers.cur_obj_scale(o.header.gfx.scale[2])
	end
end

-- from src/game/behaviors/cloud.inc.c:cloud_act_main L105-134
function cloud_inc.cloud_act_main()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const LocalOffsetPhase = S16(0x800 * GameInit.gGlobalTimer)

	if o.parentObj ~= o then
		const parent = o.parentObj :: GroupsTypesHPlus3.Object

		-- Despawn if the parent lakitu does
		if parent.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_UNLOAD)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterX, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosX))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCloudCenterY, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosY))
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ))

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.CLOUD_BP_FWOOSH then
		-- This code should never run, since a lakitu cloud should always have a parent
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 1500.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_UNLOAD)
		end
	else
		cloud_inc.cloud_fwoosh_update()
	end

	const LocalOffset = F32(F32(2 * SrcEngineMathUtilH.coss(LocalOffsetPhase)) * o.header.gfx.scale[2])

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oCloudCenterX) + LocalOffset)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCloudCenterY) + LocalOffset) + F32(12.0 * o.header.gfx.scale[2]))
end

-- from src/game/behaviors/cloud.inc.c:cloud_act_unload L140-148
function cloud_inc.cloud_act_unload()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.CLOUD_BP_FWOOSH then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.CLOUD_ACT_FWOOSH_HIDDEN)
		ObjectHelpers.cur_obj_hide()
		ObjectHelpers.cur_obj_set_pos_to_home()
	end
end

-- from src/game/behaviors/cloud.inc.c:bhv_cloud_update L153-168
function cloud_inc.bhv_cloud_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.CLOUD_ACT_SPAWN_PARTS then
		cloud_inc.cloud_act_spawn_parts()
	elseif action == IncludeObjectConstantsH.CLOUD_ACT_MAIN then
		cloud_inc.cloud_act_main()
	elseif action == IncludeObjectConstantsH.CLOUD_ACT_UNLOAD then
		cloud_inc.cloud_act_unload()
	elseif action == IncludeObjectConstantsH.CLOUD_ACT_FWOOSH_HIDDEN then
		cloud_inc.cloud_act_fwoosh_hidden()
	end
end

-- from src/game/behaviors/cloud.inc.c:bhv_cloud_part_update L173-207
function cloud_inc.bhv_cloud_part_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object
	const Bhv = buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.CLOUD_ACT_UNLOAD then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		local Scale = F32(F32(2.0 / 3.0) * parent.header.gfx.scale[2])

		-- Takes 32 frames to cycle
		const AngleFromCenter = S16(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x10000 // 5 * Bhv)
		const LocalOffsetPhase = S16(0x800 * GameInit.gGlobalTimer + 0x4000 * Bhv)

		ObjectHelpers.cur_obj_scale(Scale)

		-- Cap fwoosh's face size
		if Bhv == 5 and Scale > 2.0 then
			Scale = 2.0
			o.header.gfx.scale[2] = 2.0
		end

		-- Move back and forth along (1, 1, 1)
		const LocalOffset = F32(F32(2 * SrcEngineMathUtilH.coss(LocalOffsetPhase)) * Scale)
		const CloudRadius = F32(25.0 * Scale)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oCloudCenterX) + F32(CloudRadius * SrcEngineMathUtilH.sins(AngleFromCenter))) + LocalOffset)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oCloudCenterY) + LocalOffset) + F32(Scale * cloud_inc.sCloudPartHeights[Bhv + 1]))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, F32(buffer.readf32(parent.rawData, IncludeObjectFieldsH.oPosZ) + F32(CloudRadius * SrcEngineMathUtilH.coss(AngleFromCenter))) + LocalOffset)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	end
end

return cloud_inc
