--!strict
--!optimize 2

--[[
	Port of src/game/behavior_actions.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludeModelIdsH = require("../../include/model_ids_h")

const ObjectListProcessor = require("./object_list_processor")
const SaveFileH = require("./save_file_h")
const BehaviorIds = require("../rom/behavior_ids")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const RenderingGraphNode = require("./rendering_graph_node")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

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

-- from src/game/behavior_actions.luau:scratch
local D_8035FF10 = 0
-- from src/game/behavior_actions.luau:scratch
const MarioPartMatrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) }

-- from src/game/behavior_actions.c:data
const behavior_actions = {
	o = ObjectListProcessor.gCurrentObject,
	-- from src/game/behavior_actions.c:sCapSaveFlags L50-54
	sCapSaveFlags = {
		SaveFileH.SAVE_FLAG_HAVE_WING_CAP,
		SaveFileH.SAVE_FLAG_HAVE_METAL_CAP,
		SaveFileH.SAVE_FLAG_HAVE_VANISH_CAP,
	},
	-- from src/game/behavior_actions.c:sBooHitRotations L57-61
	sBooHitRotations = {
		6047,
		5664,
		5292,
		4934,
		4587,
		4254,
		3933,
		3624,
		3329,
		3046,
		2775,
		2517,
		2271,
		2039,
		1818,
		1611,
		1416,
		1233,
		1063,
		906,
		761,
		629,
		509,
		402,
		308,
		226,
		157,
		100,
		56,
		25,
		4,
		0,
	},
	-- from src/game/behavior_actions.c:sMistParticles L82-95
	sMistParticles = {
		bhvParam = 2,
		count = 20,
		model = IncludeModelIdsH.MODEL_MIST,
		offsetY = 0,
		forwardVelBase = 40,
		forwardVelRange = 5,
		velYBase = 30,
		velYRange = 20,
		gravity = -4,
		dragStrength = 30,
		sizeBase = 330.0,
		sizeRange = 10.0,
	},
}

Registry.Register("src__game__behavior_actions", behavior_actions)

-- from src/game/behavior_actions.c:spawn_mist_particles_variable L98-112
function behavior_actions.spawn_mist_particles_variable(count: number, offsetY: number, size: number)
	size = F32(size)
	behavior_actions.sMistParticles.sizeBase = size
	behavior_actions.sMistParticles.sizeRange = F32(size / 20.0)
	behavior_actions.sMistParticles.offsetY = S8(offsetY)

	if count == 0 then
		behavior_actions.sMistParticles.count = S8(20)
	elseif count > 20 then
		behavior_actions.sMistParticles.count = S8(count)
	else
		behavior_actions.sMistParticles.count = S8(4)
	end

	Registry.Members.src__game__object_helpers.cur_obj_spawn_particles(behavior_actions.sMistParticles)
end

-- from src/game/behavior_actions.c:geo_move_mario_part_from_parent L146-158
function behavior_actions.geo_move_mario_part_from_parent(run: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if run == IncludePRUltratypesH.TRUE then
		const Obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const MarioObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

		if Obj == MarioObject and Obj.prevObj ~= nil then
			Registry.Members.src__game__object_helpers.create_transformation_from_matrices(MarioPartMatrix, mtx, ((RenderingGraphNode.gCurGraphNodeCamera :: GroupsTypesHPlus3.GraphNodeCamera).matrixPtr :: { { { number } } })[1])
			Registry.Members.src__game__object_helpers.obj_update_pos_from_parent_transformation(MarioPartMatrix, Obj.prevObj)
			Registry.Members.src__game__object_helpers.obj_set_gfx_pos_from_pos(Obj.prevObj)
		end
	end

	return nil
end

-- from src/game/behavior_actions.c:spawn_sparkle_particles L169-180
function behavior_actions.spawn_sparkle_particles(n: number, a1: number, a2: number, r: number)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Separation = S16(TruncS32(65536 / n))

	for Index = 0, n - 1 do
		const SinValue: number = Registry.Members.src__engine__math_util_h.sins(S16(D_8035FF10 + Index * Separation))
		const CosValue: number = Registry.Members.src__engine__math_util_h.coss(S16(D_8035FF10 + Index * Separation))

		Registry.Members.src__game__object_helpers.spawn_object_relative(S16(0), S16(TruncS32(F32(SinValue * a1))), S16((Index + 1) * a2), S16(TruncS32(F32(CosValue * a1))), o, IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvSparkleSpawn)
	end

	D_8035FF10 = S16(D_8035FF10 + r * 256)
end

-- from src/game/behavior_actions.c:vec3f_copy_2 L193-197
function behavior_actions.vec3f_copy_2(dest: { number }, src: { number })
	dest[1] = src[1]
	dest[2] = src[2]
	dest[3] = src[3]
end

-- from src/game/behavior_actions.c:set_obj_anim_with_accel_and_sound L220-233
function behavior_actions.set_obj_anim_with_accel_and_sound(a0: number, a1: number, a2: number): number
	a0 = S16(TruncS32(a0))
	a1 = S16(TruncS32(a1))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	local Sp1C = F32(o.header.gfx.animInfo.animAccel / 65536.0)

	if Sp1C == 0 then
		Sp1C = 1.0
	end

	local InRange: number = Registry.Members.src__game__object_helpers.cur_obj_check_anim_frame_in_range(a0, TruncS32(Sp1C))

	if InRange == 0 then
		InRange = Registry.Members.src__game__object_helpers.cur_obj_check_anim_frame_in_range(a1, TruncS32(Sp1C))
	end

	if InRange ~= 0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(a2)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

return behavior_actions
