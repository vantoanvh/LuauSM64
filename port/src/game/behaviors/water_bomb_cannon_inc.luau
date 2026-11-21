--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/water_bomb_cannon.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

const water_bomb_cannon_inc = {}

Registry.Register("src__game__behaviors__water_bomb_cannon_inc", water_bomb_cannon_inc)

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

-- from src/game/behaviors/water_bomb_cannon.inc.c:bhv_bubble_cannon_barrel_loop L3-38
function water_bomb_cannon_inc.bhv_bubble_cannon_barrel_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oAction) == 2 then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oMoveAnglePitch) + 0x4000))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oMoveAnglePitch))

		const CannonBarrelBubblesUnkF4 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oCannonBarrelBubblesUnkF4) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oCannonBarrelBubblesUnkF4, CannonBarrelBubblesUnkF4)

		if CannonBarrelBubblesUnkF4 > 0 then
			ObjectHelpers.cur_obj_set_pos_via_transform()
			ObjBehaviors2.obj_forward_vel_approach(-5, 18)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oCannonBarrelBubblesUnkF4, 0)
			ObjectHelpers.obj_copy_pos(o, Parent)

			-- check this
			if buffer.readi32(Parent.rawData, IncludeObjectFieldsH.oWaterCannonUnkF4) ~= 0 then
				if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) == 0 then
					buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 35)

					const WaterBomb = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WATER_BOMB, BehaviorIds.bhvWaterBomb)

					if WaterBomb ~= nil then
						buffer.writef32(WaterBomb.rawData, IncludeObjectFieldsH.oForwardVel, -100)
						WaterBomb.header.gfx.scale[2] = F32(1.7)
					end

					Camera.set_camera_shake_from_point(GroupsTypesHPlus3.SHAKE_POS_MEDIUM, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
				end
			else
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0)
			end
		end
	end
end

-- from src/game/behaviors/water_bomb_cannon.inc.c:water_bomb_cannon_act_0 L40-48
function water_bomb_cannon_inc.water_bomb_cannon_act_0()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 2000 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_CANNON_BARREL, BehaviorIds.bhvCannonBarrelBubbles)
		ObjectHelpers.cur_obj_unhide()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x1C00)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkFC, 0x1C00)
	end
end

-- from src/game/behaviors/water_bomb_cannon.inc.c:water_bomb_cannon_act_1 L50-73
function water_bomb_cannon_inc.water_bomb_cannon_act_1()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 2500 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF4) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF4) - 1))
		else
			ObjBehaviors2.obj_move_pitch_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkFC)), 0x80)
			ObjBehaviors2.obj_face_yaw_approach(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnk100)), 0x100)

			if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) == S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnk100)) then
				if buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF8) ~= 0 then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF8) - 1))
				else
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_CANNON4)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF4, 70)
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkFC, S32(0x1000 + 0x400 * bit32.band(SrcEngineBehaviorScript.random_u16(), 0x03)))
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnk100, S32(-0x2000 + buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x1000 * (SrcEngineBehaviorScript.random_u16() % 5)))
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oWaterCannonUnkF8, 60)
				end
			end
		end
	end
end

-- from src/game/behaviors/water_bomb_cannon.inc.c:water_bomb_cannon_act_2 L75-78
function water_bomb_cannon_inc.water_bomb_cannon_act_2()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_hide()
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
end

-- from src/game/behaviors/water_bomb_cannon.inc.c:bhv_water_bomb_cannon_loop L80-94
function water_bomb_cannon_inc.bhv_water_bomb_cannon_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_push_mario_away_from_cylinder(220, 300)

	const Action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if Action == 0 then
		water_bomb_cannon_inc.water_bomb_cannon_act_0()
	elseif Action == 1 then
		water_bomb_cannon_inc.water_bomb_cannon_act_1()
	elseif Action == 2 then
		water_bomb_cannon_inc.water_bomb_cannon_act_2()
	end
end

return water_bomb_cannon_inc
