--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/treasure_chest.inc.c.
]]

const Registry = require("../../../groups/registry")
const Audio = require("../../rom/audio_recorder")
const IncludeSoundsH = require("../../../include/sounds_h")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SpawnStarInc = require("./spawn_star_inc")

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

-- from src/game/behaviors/treasure_chest.inc.c:data
const treasure_chest_inc = {
	-- from src/game/behaviors/treasure_chest.inc.c:sTreasureChestBottomHitbox L6-16
	sTreasureChestBottomHitbox = {
		interactType = InteractionH.INTERACT_SHOCK,
		downOffset = 0,
		damageOrCoinValue = 1,
		health = 0,
		numLootCoins = 0,
		radius = 300,
		height = 300,
		hurtboxRadius = 310,
		hurtboxHeight = 310,
	},
}

Registry.Register("src__game__behaviors__treasure_chest_inc", treasure_chest_inc)

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_top_loop L18-61
function treasure_chest_inc.bhv_treasure_chest_top_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const GrandParent = (o.parentObj :: GroupsTypesHPlus3.Object).parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 1 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			if buffer.readi32(GrandParent.rawData, IncludeObjectFieldsH.oTreasureChestUnkFC) == 0 then
				ObjectHelpers.spawn_object_relative(0, 0, -80, 120, o, IncludeModelIdsH.MODEL_BUBBLE, BehaviorIds.bhvWaterAirBubble)
				Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_CLAM_SHELL1, o.header.gfx.cameraToObject)
			else
				Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_OPEN_CHEST, o.header.gfx.cameraToObject)
			end
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - 0x200)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) < -0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, -0x4000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)

			if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= 4 then
				ObjBehaviors.spawn_orange_number(S8(buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oBhvParams2ndByte)), 0, -40, 0)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + 0x800)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) > 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	end
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_bottom_init L63-66
function treasure_chest_inc.bhv_treasure_chest_bottom_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.spawn_object_relative(0, 0, 102, -77, o, IncludeModelIdsH.MODEL_TREASURE_CHEST_LID, BehaviorIds.bhvTreasureChestTop)
	ObjectHelpers.obj_set_hitbox(o, treasure_chest_inc.sTreasureChestBottomHitbox)
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_bottom_loop L68-104
function treasure_chest_inc.bhv_treasure_chest_bottom_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if ObjBehaviors.obj_check_if_facing_toward_angle(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw), (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).header.gfx.angle[2] + 0x8000, 0x3000) ~= 0
			and ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 150) ~= 0
			and buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF8) == 0 then
			if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF4) == buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) then
				Audio.play_sound(IncludeSoundsH.SOUND_GENERAL2_RIGHT_ANSWER, Audio.gGlobalSoundSource)
				buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF4, buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF4) + 1)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
			else
				buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF4, 1)
				buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF8, IncludePRUltratypesH.TRUE)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
				ObjectHelpers.cur_obj_become_tangible()
				Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_BUZZ, Audio.gGlobalSoundSource)
			end
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF8) == IncludePRUltratypesH.TRUE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		ObjectHelpers.cur_obj_become_intangible()

		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 500) == 0 then
			buffer.writei32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oTreasureChestUnkF8, IncludePRUltratypesH.FALSE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		end
	end

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(150.0, 150.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/treasure_chest.inc.c:spawn_treasure_chest L106-110
function treasure_chest_inc.spawn_treasure_chest(sp3B: number, x: number, y: number, z: number, yaw: number)
	sp3B = S8(TruncS32(sp3B))
	yaw = S16(TruncS32(yaw))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Chest = ObjectHelpers.spawn_object_abs_with_rot(o, 0, IncludeModelIdsH.MODEL_TREASURE_CHEST_BASE, BehaviorIds.bhvTreasureChestBottom, S16(x), S16(y), S16(z), 0, yaw, 0)

	buffer.writei32(Chest.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, sp3B)
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_ship_init L112-119
function treasure_chest_inc.bhv_treasure_chest_ship_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	treasure_chest_inc.spawn_treasure_chest(1, 400, -350, -2700, 0)
	treasure_chest_inc.spawn_treasure_chest(2, 650, -350, -940, -0x6001)
	treasure_chest_inc.spawn_treasure_chest(3, -550, -350, -770, 0x5FFF)
	treasure_chest_inc.spawn_treasure_chest(4, 100, -350, -1700, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4, 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkFC, 0)
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_ship_loop L121-146
function treasure_chest_inc.bhv_treasure_chest_ship_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4) == 5 then
			Audio.play_puzzle_jingle()
			Audio.fade_volume_scale(0, 127, 1000)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if ObjectListProcessor.gEnvironmentRegions ~= nil then
			Rom.WriteS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 6, S16(Rom.ReadS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 6) - 5))
			Audio.play_sound(IncludeSoundsH.SOUND_ENV_WATER_DRAIN, Audio.gGlobalSoundSource)
			Camera.set_environmental_camera_shake(GroupsTypesHPlus3.SHAKE_ENV_JRB_SHIP_DRAIN)

			if Rom.ReadS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 6) < -335 then
				Rom.WriteS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 6, -335)
				o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
			end
		end
	end
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_jrb_init L148-155
function treasure_chest_inc.bhv_treasure_chest_jrb_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	treasure_chest_inc.spawn_treasure_chest(1, -1700, -2812, -1150, 0x7FFF)
	treasure_chest_inc.spawn_treasure_chest(2, -1150, -2812, -1550, 0x7FFF)
	treasure_chest_inc.spawn_treasure_chest(3, -2400, -2812, -1800, 0x7FFF)
	treasure_chest_inc.spawn_treasure_chest(4, -1800, -2812, -2100, 0x7FFF)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4, 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkFC, 1)
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_jrb_loop L157-177
function treasure_chest_inc.bhv_treasure_chest_jrb_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4) == 5 then
			Audio.play_puzzle_jingle()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			ObjectHelpers.spawn_mist_particles()
			SpawnStarInc.spawn_default_star(-1800.0, -2500.0, -1700.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		-- Nothing to do: the chest waits.
	end
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_ddd_init L179-187
function treasure_chest_inc.bhv_treasure_chest_ddd_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	treasure_chest_inc.spawn_treasure_chest(1, -4500, -5119, 1300, -0x6001)
	treasure_chest_inc.spawn_treasure_chest(2, -1800, -5119, 1050, 0x1FFF)
	treasure_chest_inc.spawn_treasure_chest(3, -4500, -5119, -1100, 9102)
	treasure_chest_inc.spawn_treasure_chest(4, -2400, -4607, 125, 16019)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4, 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkFC, 0)
end

-- from src/game/behaviors/treasure_chest.inc.c:bhv_treasure_chest_ddd_loop L189-209
function treasure_chest_inc.bhv_treasure_chest_ddd_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTreasureChestUnkF4) == 5 then
			Audio.play_puzzle_jingle()
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 60 then
			ObjectHelpers.spawn_mist_particles()
			SpawnStarInc.spawn_default_star(-1900.0, -4000.0, -1400.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		end
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 2 then
		-- Nothing to do: the chest waits.
	end
end

return treasure_chest_inc
