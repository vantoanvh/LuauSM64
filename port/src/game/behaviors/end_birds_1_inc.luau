--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/end_birds_1.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")

const end_birds_1_inc = {}

Registry.Register("src__game__behaviors__end_birds_1_inc", end_birds_1_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/end_birds_1_inc.luau:scratch
const Scratch = {
	bhv_end_birds_1_loop_sp34 = { 0, 0, 0 },
}

-- from src/game/behaviors/end_birds_1.inc.c:bhv_end_birds_1_loop L3-33
function end_birds_1_inc.bhv_end_birds_1_loop()
	const o = ObjectListProcessor.gCurrentObject

	SrcEngineBehaviorScript.random_float()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		ObjectHelpers.cur_obj_scale(F32(0.7))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk110, -554)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C, 3044)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108, -1314)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		SrcEngineMathUtil.vec3f_set(Scratch.bhv_end_birds_1_loop_sp34, buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk110), buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk10C), buffer.readf32(o.rawData, IncludeObjectFieldsH.oIntroLakituUnk108))

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 100 then
			Camera.obj_rotate_towards_point(o, Scratch.bhv_end_birds_1_loop_sp34, 0, 0, 0x20, 0x20)
		end
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oEndBirdUnk104) == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BIRDS_FLY_AWAY)
		end
		if Camera.gCutsceneTimer == 0 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end

	ObjectHelpers.cur_obj_set_pos_via_transform()
end

return end_birds_1_inc
