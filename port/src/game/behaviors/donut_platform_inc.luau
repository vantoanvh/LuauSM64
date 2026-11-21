--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/donut_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeMacrosH = require("../../../include/macros_h")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

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

-- from src/game/behaviors/donut_platform.inc.c:data
const donut_platform_inc = {
	-- from src/game/behaviors/donut_platform.inc.c:sDonutPlatformPositions L3-15
	sDonutPlatformPositions = {
		{ 0x0B4C, -2089, 0x19A4 },
		{ -2156, 0x08A3, -87 },
		{ 0x069C, 0x09D8, -32 },
		{ 0x05CF, 0x09D8, -32 },
		{ 0x0502, 0x09D8, -32 },
		{ 0x054C, -2089, 0x19A4 },
		{ 0x0A7F, -2089, 0x19A4 },
		{ 0x09B2, -2089, 0x19A4 },
		{ 0x06E6, -2089, 0x19A4 },
		{ 0x0619, -2089, 0x19A4 },
		{ -4171, -2089, 0x19A4 },
		{ 0x00E6, -2089, 0x19A4 },
		{ 0x0019, -2089, 0x19A4 },
		{ -179, -2089, 0x19A4 },
		{ -3967, -2089, 0x19A4 },
		{ -7345, -2447, 0x197A },
		{ -4376, -2089, 0x19A4 },
		{ -6321, -2089, 0x197A },
		{ -6525, -2089, 0x197A },
		{ -6730, -2089, 0x197A },
		{ -4477, -2908, 0x19A4 },
		{ -7140, -2447, 0x197A },
		{ -6935, -2447, 0x197A },
		{ -4887, -2908, 0x19A4 },
		{ -4682, -2908, 0x19A4 },
		{ -961, 0x0A66, -187 },
		{ 0x00EF, 0x04CD, -173 },
		{ 0x0022, 0x04CD, -173 },
		{ -169, 0x04CD, -173 },
		{ -1165, 0x0A66, -187 },
		{ -756, 0x0A66, -187 },
	},
}

Registry.Register("src__game__behaviors__donut_platform_inc", donut_platform_inc)

-- from src/game/behaviors/donut_platform.inc.c:bhv_donut_platform_spawner_update L17-38
function donut_platform_inc.bhv_donut_platform_spawner_update()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	for i = 0, IncludeMacrosH.ARRAY_COUNT(donut_platform_inc.sDonutPlatformPositions) - 1 do
		const platformFlag = bit32.lshift(1, i)

		if not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDonutPlatformSpawnerSpawnedPlatforms), platformFlag) then
			const dx = F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosX) - donut_platform_inc.sDonutPlatformPositions[i + 1][1])
			const dy = F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) - donut_platform_inc.sDonutPlatformPositions[i + 1][2])
			const dz = F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ) - donut_platform_inc.sDonutPlatformPositions[i + 1][3])
			const marioSqDist = F32(F32(F32(dx * dx) + F32(dy * dy)) + F32(dz * dz))

			-- dist > 1000 and dist < 2000
			if marioSqDist > 1000000 and marioSqDist < 4000000 then
				if ObjectHelpers.spawn_object_relative(S16(i), donut_platform_inc.sDonutPlatformPositions[i + 1][1], donut_platform_inc.sDonutPlatformPositions[i + 1][2], donut_platform_inc.sDonutPlatformPositions[i + 1][3], o, IncludeModelIdsH.MODEL_RR_DONUT_PLATFORM, BehaviorIds.bhvDonutPlatform) ~= nil then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oDonutPlatformSpawnerSpawnedPlatforms, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oDonutPlatformSpawnerSpawnedPlatforms), platformFlag)))
				end
			end
		end
	end
end

-- from src/game/behaviors/donut_platform.inc.c:bhv_donut_platform_update L40-70
function donut_platform_inc.bhv_donut_platform_update()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) ~= 0 and (bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_ON_GROUND) or buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500) then
		const parent = o.parentObj :: GroupsTypesHPlus3.Object

		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oDonutPlatformSpawnerSpawnedPlatforms, S32(bit32.band(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oDonutPlatformSpawnerSpawnedPlatforms), bit32.bxor(bit32.lshift(1, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)), 0xFFFFFFFF))))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500 then
			ObjectHelpers.obj_mark_for_deletion(o)
		else
			ObjectHelpers.obj_explode_and_spawn_coins(150, 1)
			SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_DONUT_PLATFORM_EXPLOSION)
		end
	else
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity) == 0 then
			if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
				ObjectHelpers.cur_obj_shake_y(4)
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 15 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -0.1)
				end
			else
				ObjectHelpers.cur_obj_set_pos_to_home()
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
			end
		else
			ObjectHelpers.cur_obj_update_floor_and_walls()
			ObjectHelpers.cur_obj_move_standard(78)
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

return donut_platform_inc
