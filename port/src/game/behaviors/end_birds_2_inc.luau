--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/end_birds_2.inc.c.
]]

const Registry = require("../../../groups/registry")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")
const SrcEngineMathUtil = require("../../engine/math_util")

const end_birds_2_inc = {}

Registry.Register("src__game__behaviors__end_birds_2_inc", end_birds_2_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/end_birds_2_inc.luau:scratch
const Scratch = {
	bhv_end_birds_2_loop_sp34 = { 0 },
	bhv_end_birds_2_loop_sp32 = { 0 },
	bhv_end_birds_2_loop_sp30 = { 0 },
	bhv_end_birds_2_loop_sp3C = { 0, 0, 0 },
}

-- from src/game/behaviors/end_birds_2.inc.c:bhv_end_birds_2_loop L3-32
function end_birds_2_inc.bhv_end_birds_2_loop()
	const o = ObjectListProcessor.gCurrentObject

	SrcEngineBehaviorScript.random_float()
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(SrcEngineBehaviorScript.random_float() * 10) + 25)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		ObjectHelpers.cur_obj_scale(F32(0.7))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		const camera = Camera.gCamera :: GroupsTypesHPlus3.Camera

		SrcEngineMathUtil.vec3f_get_dist_and_angle(camera.pos, camera.focus, Scratch.bhv_end_birds_2_loop_sp34, Scratch.bhv_end_birds_2_loop_sp32, Scratch.bhv_end_birds_2_loop_sp30)
		Scratch.bhv_end_birds_2_loop_sp30[1] = S16(Scratch.bhv_end_birds_2_loop_sp30[1] + 0x1000)
		-- nice work, Nintendo
		Scratch.bhv_end_birds_2_loop_sp32[1] = S16(Scratch.bhv_end_birds_2_loop_sp32[1] + 0)
		SrcEngineMathUtil.vec3f_set_dist_and_angle(camera.pos, Scratch.bhv_end_birds_2_loop_sp3C, 14000, Scratch.bhv_end_birds_2_loop_sp32[1], Scratch.bhv_end_birds_2_loop_sp30[1])
		Camera.obj_rotate_towards_point(o, Scratch.bhv_end_birds_2_loop_sp3C, 0, 0, 8, 8)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oEndBirdUnk104) == 0 and buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BIRDS_FLY_AWAY)
		end
	end

	ObjectHelpers.cur_obj_set_pos_via_transform()
end

return end_birds_2_inc
