--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/intro_scene.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const intro_scene_inc = {}

Registry.Register("src__game__behaviors__intro_scene_inc", intro_scene_inc)

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

-- from src/game/behaviors/intro_scene.inc.c:spawn_child_obj_relative L3-25
function intro_scene_inc.spawn_child_obj_relative(parent: GroupsTypesHPlus3.Object, xOffset: number, yOffset: number, zOffset: number, pitchOffset: number, yawOffset: number, rollOffset: number, forwardVel: number, model: number, behavior: number)
	xOffset = S16(TruncS32(xOffset))
	yOffset = S16(TruncS32(yOffset))
	zOffset = S16(TruncS32(zOffset))
	pitchOffset = S16(TruncS32(pitchOffset))
	yawOffset = S16(TruncS32(yawOffset))
	rollOffset = S16(TruncS32(rollOffset))
	forwardVel = S16(TruncS32(forwardVel))
	const obj = ObjectHelpers.spawn_object(parent, model, behavior)

	obj.header.gfx.animInfo.animFrame = S16(TruncS32(F32(SrcEngineBehaviorScript.random_float() * 6.0)))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oEndBirdUnk104, Camera.sCutsceneVars[10].point[1])

	Camera.sCutsceneVars[10].point[1] = F32(Camera.sCutsceneVars[10].point[1] + 1.0)

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX) + xOffset)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + yOffset)

	if Camera.gCutsceneTimer > 700 then
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + -150.0)
	end

	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ) + zOffset)
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + pitchOffset))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + yawOffset))
	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleRoll, S32(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleRoll) + rollOffset))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oForwardVel, forwardVel)
end

-- from src/game/behaviors/intro_scene.inc.c:bhv_intro_scene_loop L27-87
function intro_scene_inc.bhv_intro_scene_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if Camera.gCutsceneObjSpawn ~= 0 then
		const gCamera = Camera.gCamera :: GroupsTypesHPlus3.Camera

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, gCamera.pos[1])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, gCamera.pos[2])
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, gCamera.pos[3])

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, 0)

		const spawnKind = Camera.gCutsceneObjSpawn

		if spawnKind == 6 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_LAKITU, BehaviorIds.bhvBeginningLakitu)
		elseif spawnKind == 5 then
			ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_PEACH, BehaviorIds.bhvBeginningPeach)
		elseif spawnKind == 7 then
			intro_scene_inc.spawn_child_obj_relative(o, 0, 205, 500, 0x1000, 0x6000, -0x1E00, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, 0, 205, 800, 0x1800, 0x6000, -0x1400, 35, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, -100, 300, 500, 0x800, 0x6000, 0, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, 100, -200, 800, 0, 0x4000, 0x1400, 45, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, -80, 300, 350, 0x1800, 0x5000, 0xA00, 35, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, -300, 300, 500, 0x800, 0x6000, 0x2800, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, -400, -200, 800, 0, 0x4000, -0x1400, 45, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
		elseif spawnKind == 9 then
			intro_scene_inc.spawn_child_obj_relative(o, 50, 205, 500, 0x1000, 0x6000, 0, 35, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
			intro_scene_inc.spawn_child_obj_relative(o, 0, 285, 800, 0x1800, 0x6000, 0, 35, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds1)
		elseif spawnKind == 8 then
			intro_scene_inc.spawn_child_obj_relative(o, -100, -100, -700, 0, 0, -0xF00, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds2)
			intro_scene_inc.spawn_child_obj_relative(o, -250, 255, -200, 0, 0, -0x1400, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds2)
			intro_scene_inc.spawn_child_obj_relative(o, -100, 155, -600, 0, 0, -0x500, 35, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds2)
			intro_scene_inc.spawn_child_obj_relative(o, 250, 200, -1200, 0, 0, -0x700, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds2)
			intro_scene_inc.spawn_child_obj_relative(o, -250, 255, -700, 0, 0, 0, 25, IncludeModelIdsH.MODEL_BIRDS, BehaviorIds.bhvEndBirds2)
		end

		Camera.gCutsceneObjSpawn = 0
	end
end

return intro_scene_inc
