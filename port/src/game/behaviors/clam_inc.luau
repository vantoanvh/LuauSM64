--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/clam.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroundParticlesInc = require("./ground_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

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

-- from src/game/behaviors/clam.inc.c:data
const clam_inc = {
	-- from src/game/behaviors/clam.inc.c:sClamShellHitbox L3-13
	sClamShellHitbox = {
		interactType = InteractionH.INTERACT_CLAM_OR_BUBBA,
		downOffset = 0,
		damageOrCoinValue = 2,
		health = 99,
		numLootCoins = 0,
		radius = 150,
		height = 80,
		hurtboxRadius = 150,
		hurtboxHeight = 80,
	},
}

Registry.Register("src__game__behaviors__clam_inc", clam_inc)

-- from src/game/behaviors/clam.inc.c:clam_act_0 L15-30
function clam_inc.clam_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if ObjBehaviors2.cur_obj_init_anim_check_frame(0, 25) ~= 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CLAM_SHELL3)
		GroundParticlesInc.spawn_mist_from_global()
		ObjectHelpers.cur_obj_become_tangible()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oClamUnkF4, 10)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_CLAM_SHELL2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oClamUnkF4) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oClamUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oClamUnkF4) - 1))
		ObjectHelpers.cur_obj_shake_y(3.0)
	end
end

-- from src/game/behaviors/clam.inc.c:clam_act_1 L32-47
function clam_inc.clam_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	elseif ObjBehaviors2.obj_is_rendering_enabled() ~= 0 and ObjBehaviors2.cur_obj_init_anim_check_frame(1, 8) ~= 0 then
		local val06 = -0x2000

		while val06 < 0x2000 do
			const Val04 = S16(TruncS32(F32(100.0 * SrcEngineMathUtilH.sins(val06))))
			const Val02 = S16(TruncS32(F32(100.0 * SrcEngineMathUtilH.coss(val06))))

			ObjectHelpers.spawn_object_relative(0, Val04, 30, Val02, o, IncludeModelIdsH.MODEL_BUBBLE, BehaviorIds.bhvBubbleMaybe)
			val06 = S16(val06 + 0x555)
		end
	elseif ObjectHelpers.cur_obj_check_anim_frame(30) ~= 0 then
		ObjectHelpers.cur_obj_become_intangible()
	end
end

-- from src/game/behaviors/clam.inc.c:bhv_clam_loop L49-62
function clam_inc.bhv_clam_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	o.header.gfx.scale[2] = 1.5

	if action == 0 then
		clam_inc.clam_act_0()
	elseif action == 1 then
		clam_inc.clam_act_1()
	end

	ObjBehaviors2.obj_check_attacks(clam_inc.sClamShellHitbox, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction))
end

return clam_inc
