--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/fire_spitter.inc.c.
]]

const Registry = require("../../../groups/registry")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const fire_spitter_inc = {}

Registry.Register("src__game__behaviors__fire_spitter_inc", fire_spitter_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/fire_spitter_inc.luau:scratch
const Scratch = {
	fire_spitter_act_spit_fire_scaleVel = { 0 },
	fire_spitter_act_idle_scale = buffer.create(4),
}

-- from src/game/behaviors/fire_spitter.inc.c:fire_spitter_act_idle L3-10
function fire_spitter_inc.fire_spitter_act_idle()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(Scratch.fire_spitter_act_idle_scale, 0, o.header.gfx.scale[1])
	ObjBehaviors2.approach_f32_ptr(Scratch.fire_spitter_act_idle_scale, 0, F32(0.2), F32(0.002))
	o.header.gfx.scale[1] = buffer.readf32(Scratch.fire_spitter_act_idle_scale, 0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 800 and not bit32.btest(buffer.readu32(o.rawData, IncludeObjectFieldsH.oMoveFlags), IncludeObjectConstantsH.OBJ_MOVE_MASK_IN_WATER) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FIRE_SPITTER_ACT_SPIT_FIRE)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFireSpitterScaleVel, 0.05)
	end
end

-- from src/game/behaviors/fire_spitter.inc.c:fire_spitter_act_spit_fire L12-30
function fire_spitter_inc.fire_spitter_act_spit_fire()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario))

	-- Increase scale by 0.05, 0.04, ..., -0.03. Then wait ~8 frames, then
	-- starting moving scale by 0.05 each frame toward 0.1. The first time
	-- it becomes below 0.15 during this latter portion, shoot fire.
	Scratch.fire_spitter_act_spit_fire_scaleVel[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oFireSpitterScaleVel)
	const ScaleStatus: number = ObjBehaviors2.obj_grow_then_shrink(Scratch.fire_spitter_act_spit_fire_scaleVel, F32(0.15), F32(0.1))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFireSpitterScaleVel, Scratch.fire_spitter_act_spit_fire_scaleVel[1])

	if ScaleStatus ~= 0 then
		if ScaleStatus < 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.FIRE_SPITTER_ACT_IDLE)
		else
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_FLAME_BLOWN)
			ObjBehaviors2.obj_spit_fire(0, 0, 0, 5, IncludeModelIdsH.MODEL_RED_FLAME_SHADOW, 20, 15, 0x1000)
		end
	end
end

-- from src/game/behaviors/fire_spitter.inc.c:bhv_fire_spitter_update L32-47
function fire_spitter_inc.bhv_fire_spitter_update()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_scale(o.header.gfx.scale[1])
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 40)
	ObjectHelpers.cur_obj_update_floor_and_walls()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FIRE_SPITTER_ACT_IDLE then
		fire_spitter_inc.fire_spitter_act_idle()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.FIRE_SPITTER_ACT_SPIT_FIRE then
		fire_spitter_inc.fire_spitter_act_spit_fire()
	end

	ObjectHelpers.cur_obj_move_standard(78)
end

return fire_spitter_inc
