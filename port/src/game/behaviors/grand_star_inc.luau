--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/grand_star.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorActions = require("../behavior_actions")
const Camera = require("../camera")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtil = require("../../engine/math_util")

const grand_star_inc = {}

Registry.Register("src__game__behaviors__grand_star_inc", grand_star_inc)

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

-- from src/game/behaviors/grand_star_inc.luau:scratch
const Scratch = {
	bhv_grand_star_loop_sp28 = { 0, 0, 0 },
	bhv_grand_star_loop_pos = { 0, 0, 0 },
}

-- from src/game/behaviors/grand_star.inc.c:arc_to_goal_pos L3-18
function grand_star_inc.arc_to_goal_pos(a0: { number }, a1: { number }, yVel: number, gravity: number): number
	yVel = F32(yVel)
	gravity = F32(gravity)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const dx = F32(a0[1] - a1[1])
	const dz = F32(a0[3] - a1[3])
	const planarDist = F32(math.sqrt(F32(F32(dx * dx) + F32(dz * dz))))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(dz, dx))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, yVel)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, gravity)

	const time = TruncS32(F32(F32(F32(-2.0 / buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity)) * yVel) - 1.0))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, planarDist / time)

	return time
end

-- from src/game/behaviors/grand_star.inc.c:grand_star_zero_velocity L20-24
function grand_star_inc.grand_star_zero_velocity()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
end

-- from src/game/behaviors/grand_star.inc.c:bhv_grand_star_loop L26-92
function grand_star_inc.bhv_grand_star_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	Scratch.bhv_grand_star_loop_sp28[1] = 0.0
	Scratch.bhv_grand_star_loop_sp28[2] = 0.0
	Scratch.bhv_grand_star_loop_sp28[3] = 0.0

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			ObjectHelpers.obj_set_angle(o, 0, 0, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x400)

			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL2_STAR_APPEARS)
		end

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 70 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end

		BehaviorActions.spawn_sparkle_particles(3, 200, 80, -60)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_GRAND_STAR)

			Camera.cutscene_object(GroupsTypesHPlus3.CUTSCENE_STAR_SPAWN, o)

			Scratch.bhv_grand_star_loop_pos[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
			Scratch.bhv_grand_star_loop_pos[2] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
			Scratch.bhv_grand_star_loop_pos[3] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oGrandStarUnk108, grand_star_inc.arc_to_goal_pos(Scratch.bhv_grand_star_loop_sp28, Scratch.bhv_grand_star_loop_pos, 80.0, -2.0))
		end

		ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) == 0 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 60.0)
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oSubAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oSubAction) + 1))

				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_GRAND_STAR_JUMP)
			end
		elseif buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.0 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 200.0) then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 200.0)
			grand_star_inc.grand_star_zero_velocity()
			Camera.gObjCutsceneDone = IncludePRUltratypesH.TRUE
			MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)

			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_GRAND_STAR_JUMP)
		end

		BehaviorActions.spawn_sparkle_particles(3, 200, 80, -60)
	else
		ObjectHelpers.cur_obj_become_tangible()

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
			ObjectHelpers.obj_mark_for_deletion(o)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) > 0x400 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) - 0x100))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw)))
	ObjectHelpers.cur_obj_scale(2.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 110.0)
end

return grand_star_inc
