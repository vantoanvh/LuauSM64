--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/boulder.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SnowmanInc = require("./snowman_inc")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const boulder_inc = {}

Registry.Register("src__game__behaviors__boulder_inc", boulder_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/boulder.inc.c:bhv_big_boulder_init L3-11
function boulder_inc.bhv_big_boulder_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 8.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, F32(0.999))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 2.0)
end

-- from src/game/behaviors/boulder.inc.c:boulder_act_1 L13-28
function boulder_inc.boulder_act_1()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const collisionFlags = S16(ObjBehaviors.object_step_without_floor_orient())

	if bit32.band(collisionFlags, ObjBehaviors.OBJ_COL_FLAGS_LANDED) == ObjBehaviors.OBJ_COL_FLAG_GROUNDED and buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 10.0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_GRINDEL_ROLL)
		ObjectHelpers.spawn_mist_particles()
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 70.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 70.0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < -1000.0 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/boulder.inc.c:bhv_big_boulder_loop L30-49
function boulder_inc.bhv_big_boulder_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_scale(1.5)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 270.0)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	elseif action == 1 then
		boulder_inc.boulder_act_1()
		SnowmanInc.adjust_rolling_face_pitch(1.5)
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_UNKNOWN2)
	end

	SnowmanInc.set_rolling_sphere_hitbox()
end

-- from src/game/behaviors/boulder.inc.c:bhv_big_boulder_generator_loop L51-74
function boulder_inc.bhv_big_boulder_generator_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 256 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	if ObjBehaviors.current_mario_room_check(4) == IncludePRUltratypesH.FALSE or ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 1500) ~= IncludePRUltratypesH.FALSE then
		return
	end

	if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 6000) ~= IncludePRUltratypesH.FALSE then
		if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 0x3F) == 0 then
			const sp1C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_HMC_ROLLING_ROCK, BehaviorIds.bhvBigBoulder)
			buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4096.0)))
		end
	else
		if bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 0x7F) == 0 then
			const sp1C = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_HMC_ROLLING_ROCK, BehaviorIds.bhvBigBoulder)
			buffer.writei32(sp1C.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(SrcEngineBehaviorScript.random_float() * 4096.0)))
		end
	end
end

return boulder_inc
