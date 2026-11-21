--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/exclamation_box.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")

const InteractionH = require("../interaction_h")
const BehaviorActions = require("../behavior_actions")
const BreakParticlesInc = require("./break_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SaveFile = require("../save_file")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

-- from src/game/behaviors/exclamation_box.inc.c:ExclamationBoxContents
export type ExclamationBoxContents = {
	id: number,
	unused: number,
	bhvParams1stByte: number,
	model: number,
	behavior: number?,
}

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/exclamation_box.inc.c:data
const exclamation_box_inc = {
	-- from src/game/behaviors/exclamation_box.inc.c:sExclamationBoxHitbox L3-13
	sExclamationBoxHitbox = {
		interactType = InteractionH.INTERACT_BREAKABLE,
		downOffset = 5,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 40,
		height = 30,
		hurtboxRadius = 40,
		hurtboxHeight = 30,
	},
	-- from src/game/behaviors/exclamation_box.inc.c:sExclamationBoxContents L23-40
	sExclamationBoxContents = {
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_WING_CAP,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_MARIOS_WING_CAP,
			behavior = BehaviorIds.bhvWingCap,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_METAL_CAP,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_MARIOS_METAL_CAP,
			behavior = BehaviorIds.bhvMetalCap,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_VANISH_CAP,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_MARIOS_CAP,
			behavior = BehaviorIds.bhvVanishCap,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_KOOPA_SHELL,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_KOOPA_SHELL,
			behavior = BehaviorIds.bhvKoopaShell,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_ONE_COIN,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_YELLOW_COIN,
			behavior = BehaviorIds.bhvSingleCoinGetsSpawned,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_THREE_COINS,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_NONE,
			behavior = BehaviorIds.bhvThreeCoinsSpawn,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_TEN_COINS,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_NONE,
			behavior = BehaviorIds.bhvTenCoinsSpawn,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_1UP_WALKING,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_1UP,
			behavior = BehaviorIds.bhv1UpWalking,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_1,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_1,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_1UP_RUNNING_AWAY,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_1UP,
			behavior = BehaviorIds.bhv1UpRunningAway,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_2,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_2,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_3,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_3,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_4,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_4,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_5,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_5,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_STAR_ACT_6,
			unused = 0,
			bhvParams1stByte = IncludeObjectConstantsH.STAR_INDEX_ACT_6,
			model = IncludeModelIdsH.MODEL_STAR,
			behavior = BehaviorIds.bhvSpawnedStar,
		},
		{
			id = IncludeObjectConstantsH.EXCLAMATION_BOX_BP_END,
			unused = 0,
			bhvParams1stByte = 0,
			model = IncludeModelIdsH.MODEL_NONE,
			behavior = nil,
		},
	} :: { ExclamationBoxContents },
}

Registry.Register("src__game__behaviors__exclamation_box_inc", exclamation_box_inc)

-- from src/game/behaviors/exclamation_box.inc.c:ExclamationBoxContents (zero-filled constructor)
function exclamation_box_inc.new_ExclamationBoxContents(): ExclamationBoxContents
	return { id = 0, unused = 0, bhvParams1stByte = 0, model = 0, behavior = nil } :: ExclamationBoxContents
end

-- from src/game/behaviors/exclamation_box.inc.c:bhv_rotating_exclamation_box_loop L42-46
function exclamation_box_inc.bhv_rotating_exclamation_box_loop()
	const o = ObjectListProcessor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if buffer.readi32(parent.rawData, IncludeObjectFieldsH.oAction) ~= 1 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_0 L48-61
function exclamation_box_inc.exclamation_box_act_0()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) <= IncludeObjectConstantsH.EXCLAMATION_BOX_BP_SPECIAL_CAP_END then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte))
		if bit32.btest(SaveFile.save_file_get_flags(), BehaviorActions.sCapSaveFlags[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]) or bit32.btest(bit32.extract(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24, 8), 0xFF) then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, IncludeObjectConstantsH.EXCLAMATION_BOX_ANIM_STATE_DEFAULT)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_1 L63-76
function exclamation_box_inc.exclamation_box_act_1()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_become_intangible()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_EXCLAMATION_POINT, BehaviorIds.bhvRotatingExclamationMark)
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_EXCLAMATION_BOX_OUTLINE)
	end

	if bit32.btest(SaveFile.save_file_get_flags(), BehaviorActions.sCapSaveFlags[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]) or bit32.btest(bit32.extract(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), 24, 8), 0xFF) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
		ObjectHelpers.cur_obj_set_model(IncludeModelIdsH.MODEL_EXCLAMATION_BOX)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_2 L78-102
function exclamation_box_inc.exclamation_box_act_2()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, exclamation_box_inc.sExclamationBoxHitbox)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		ObjectHelpers.cur_obj_unhide()
		ObjectHelpers.cur_obj_become_tangible()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, 0)
	end

	if ObjectHelpers.cur_obj_was_attacked_or_ground_pounded() ~= 0 then
		ObjectHelpers.cur_obj_become_intangible()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC, 0x4000)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 30)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, -8)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloorHeight, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
	end

	SrcEngineSurfaceLoad.load_object_collision_model()
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_3 L104-125
function exclamation_box_inc.exclamation_box_act_3()
	const o = ObjectListProcessor.gCurrentObject

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkF8, (SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC)) + 1) * 0.3 + 0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkF4, (-SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC)) + 1) * 0.5 + 1)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, (-SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC)) + 1) * 26)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC, buffer.readi32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkFC) + 0x1000)
	o.header.gfx.scale[1] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkF4) * 2)
	o.header.gfx.scale[2] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkF8) * 2)
	o.header.gfx.scale[3] = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oExclamationBoxUnkF4) * 2)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 7 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_spawn_contents L127-144
function exclamation_box_inc.exclamation_box_spawn_contents(contents: { ExclamationBoxContents }, targetContentsID: number)
	targetContentsID = U8(TruncS32(targetContentsID))
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	local index = 1
	while contents[index].id ~= IncludeObjectConstantsH.EXCLAMATION_BOX_BP_END do
		if targetContentsID == contents[index].id then
			const contentsObj = ObjectHelpers.spawn_object(o, contents[index].model, contents[index].behavior :: number)
			buffer.writef32(contentsObj.rawData, IncludeObjectFieldsH.oVelY, 20)
			buffer.writef32(contentsObj.rawData, IncludeObjectFieldsH.oForwardVel, 3)
			buffer.writei32(contentsObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(mario.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.bor(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams), bit32.lshift(contents[index].bhvParams1stByte, 24))))
			if contents[index].model == IncludeModelIdsH.MODEL_STAR then
				buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.bor(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), IncludeObjectConstantsH.OBJ_FLAG_PERSISTENT_RESPAWN)))
			end
			break
		end
		index += 1
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_4 L146-158
function exclamation_box_inc.exclamation_box_act_4()
	const o = ObjectListProcessor.gCurrentObject

	exclamation_box_inc.exclamation_box_spawn_contents(exclamation_box_inc.sExclamationBoxContents, U8(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte)))
	BehaviorActions.spawn_mist_particles_variable(0, 0, 46)
	BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_CARTOON_STAR, F32(0.3), S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAnimState)))
	SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BREAK_BOX)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) <= IncludeObjectConstantsH.EXCLAMATION_BOX_BP_SPECIAL_CAP_END then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
		ObjectHelpers.cur_obj_hide()
	else
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:exclamation_box_act_5 L160-164
function exclamation_box_inc.exclamation_box_act_5()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 300 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)
	end
end

-- from src/game/behaviors/exclamation_box.inc.c:bhv_exclamation_box_loop L175-178
function exclamation_box_inc.bhv_exclamation_box_loop()
	ObjectHelpers.cur_obj_scale(F32(2))
	ObjectHelpers.cur_obj_call_action_function(exclamation_box_inc.sExclamationBoxActions)
end

-- from src/game/behaviors/exclamation_box.inc.c:sExclamationBoxActions L166-173
exclamation_box_inc.sExclamationBoxActions = {
	exclamation_box_inc.exclamation_box_act_0,
	exclamation_box_inc.exclamation_box_act_1,
	exclamation_box_inc.exclamation_box_act_2,
	exclamation_box_inc.exclamation_box_act_3,
	exclamation_box_inc.exclamation_box_act_4,
	exclamation_box_inc.exclamation_box_act_5,
}

return exclamation_box_inc
