--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_objs.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const water_objs_inc = {}

Registry.Register("src__game__behaviors__water_objs_inc", water_objs_inc)

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

-- from src/game/behaviors/water_objs.inc.c:bhv_water_air_bubble_init L4-6
function water_objs_inc.bhv_water_air_bubble_init()
	ObjectHelpers.cur_obj_scale(4)
end

-- from src/game/behaviors/water_objs.inc.c:bhv_water_air_bubble_loop L10-43
function water_objs_inc.bhv_water_air_bubble_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4)) * 0.5 + 4)
	o.header.gfx.scale[2] = F32(-SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4)) * 0.5 + 4)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4) + 0x400))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 30 then
		ObjectHelpers.cur_obj_become_intangible()
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 3)
	else
		ObjectHelpers.cur_obj_become_tangible()
		ObjectHelpers.cur_obj_forward_vel_approach_upward(2, 10)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.obj_angle_to_object(o, MarioObject))
		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SrcEngineBehaviorScript.random_float() * 4) - 2))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(SrcEngineBehaviorScript.random_float() * 4) - 2))

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) or buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 200 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_BUBBLE)
		ObjectHelpers.obj_mark_for_deletion(o)

		for I = 1, 30 do
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_BUBBLE, BehaviorIds.bhvBubbleMaybe)
		end
	end

	if SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/water_objs.inc.c:bhv_bubble_wave_init L45-49
function water_objs_inc.bhv_bubble_wave_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkFC, S32(0x800 + TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnk100, S32(0x800 + TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048))))
	SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_QUIET_BUBBLE)
end

-- from src/game/behaviors/water_objs.inc.c:scale_bubble_random L51-53
function water_objs_inc.scale_bubble_random()
	ObjectHelpers.cur_obj_scale(F32(SrcEngineBehaviorScript.random_float() + 1))
end

-- from src/game/behaviors/water_objs.inc.c:bhv_bubble_maybe_loop L55-64
function water_objs_inc.bhv_bubble_maybe_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + F32(F32(SrcEngineBehaviorScript.random_float() * 3) + 6))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(SrcEngineBehaviorScript.random_float() * 10) - 5))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(SrcEngineBehaviorScript.random_float() * 10) - 5))

	o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4)) * 0.2 + 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkFC)))
	o.header.gfx.scale[2] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8)) * 0.2 + 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnk100)))
end

-- from src/game/behaviors/water_objs.inc.c:bhv_small_water_wave_loop L66-85
function water_objs_inc.bhv_small_water_wave_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp1C = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4)) * 0.2 + 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkFC)))
	o.header.gfx.scale[2] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8)) * 0.2 + 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnk100)))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > Sp1C then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5)

		if ObjectListProcessor.gFreeObjectList.ObjectNode_next ~= nil then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMALL_WATER_SPLASH, BehaviorIds.bhvObjectWaterSplash)
		end
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/water_objs.inc.c:scale_bubble_sin L87-92
function water_objs_inc.scale_bubble_sin()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	o.header.gfx.scale[1] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4)) * 0.5 + 2)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF4) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkFC)))
	o.header.gfx.scale[2] = F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8)) * 0.5 + 2)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkF8) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterObjUnk100)))
end

-- from src/game/behaviors/water_objs.inc.c:bhv_particle_init L94-99
function water_objs_inc.bhv_particle_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_scale_xyz(o, 2, 2, 1)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnkFC, S32(0x800 + TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterObjUnk100, S32(0x800 + TruncS32(F32(SrcEngineBehaviorScript.random_float() * 2048))))
	ObjectHelpers.obj_translate_xyz_random(o, 100)
end

-- from src/game/behaviors/water_objs.inc.c:bhv_particle_loop L101-110
function water_objs_inc.bhv_particle_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sp24 = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5)
	ObjectHelpers.obj_translate_xz_random(o, 4)
	water_objs_inc.scale_bubble_sin()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > Sp24 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) ~= 0 then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.try_to_spawn_object(5, 0, o, IncludeModelIdsH.MODEL_SMALL_WATER_SPLASH, BehaviorIds.bhvObjectWaterSplash)
	end
end

-- from src/game/behaviors/water_objs.inc.c:bhv_small_bubbles_loop L112-116
function water_objs_inc.bhv_small_bubbles_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5)
	ObjectHelpers.obj_translate_xz_random(o, 4)
	water_objs_inc.scale_bubble_sin()
end

-- from src/game/behaviors/water_objs.inc.c:bhv_fish_group_loop L118-122
function water_objs_inc.bhv_fish_group_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if (ObjectListProcessor.gMarioCurrentRoom == 15 or ObjectListProcessor.gMarioCurrentRoom == 7) and bit32.btest(GameInit.gGlobalTimer, 1) then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvSmallParticleBubbles)
	end
end

-- from src/game/behaviors/water_objs.inc.c:bhv_water_waves_init L124-129
function water_objs_inc.bhv_water_waves_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	for I = 1, 3 do
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvSmallParticle)
	end
end

return water_objs_inc
