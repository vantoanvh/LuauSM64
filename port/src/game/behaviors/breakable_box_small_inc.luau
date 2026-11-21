--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/breakable_box_small.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const BehaviorIds = require("../../rom/behavior_ids")
const BreakParticlesInc = require("./break_particles_inc")
const CorkboxInc = require("./corkbox_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineBehaviorScript = require("../../engine/behavior_script")

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

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/game/behaviors/breakable_box_small.inc.c:data
const breakable_box_small_inc = {
	-- from src/game/behaviors/breakable_box_small.inc.c:sBreakableBoxSmallHitbox L3-13
	sBreakableBoxSmallHitbox = {
		interactType = InteractionH.INTERACT_GRABBABLE,
		downOffset = 20,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 150,
		height = 250,
		hurtboxRadius = 150,
		hurtboxHeight = 250,
	},
}

Registry.Register("src__game__behaviors__breakable_box_small_inc", breakable_box_small_inc)

-- from src/game/behaviors/breakable_box_small.inc.c:bhv_breakable_box_small_init L15-23
function breakable_box_small_inc.bhv_breakable_box_small_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2.5)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.99)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.4)
	ObjectHelpers.cur_obj_scale(F32(0.4))
	ObjectHelpers.obj_set_hitbox(o, breakable_box_small_inc.sBreakableBoxSmallHitbox)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAnimState, 1)
	o.activeFlags = S16(bit32.bor(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_UNK9))
end

-- from src/game/behaviors/breakable_box_small.inc.c:small_breakable_box_spawn_dust L25-29
function breakable_box_small_inc.small_breakable_box_spawn_dust()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const sp24 = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvSmoke)

	buffer.writef32(sp24.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(sp24.rawData, IncludeObjectFieldsH.oPosX) + (TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)) - 40))
	buffer.writef32(sp24.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(sp24.rawData, IncludeObjectFieldsH.oPosZ) + (TruncS32(F32(SrcEngineBehaviorScript.random_float() * 80.0)) - 40))
end

-- from src/game/behaviors/breakable_box_small.inc.c:small_breakable_box_act_move L31-56
function breakable_box_small_inc.small_breakable_box_act_move()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const collisionFlags = S16(ObjBehaviors.object_step())

	ObjectHelpers.obj_attack_collided_from_other_object(o)

	if collisionFlags == ObjBehaviors.OBJ_COL_FLAG_GROUNDED then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BOX_LANDING_2)
	end

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 20.0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_ENV_SLIDING)
			breakable_box_small_inc.small_breakable_box_spawn_dust()
		end
	end

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_HIT_WALL) then
		ObjectHelpers.spawn_mist_particles()
		BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, F32(0.7), 3)
		ObjBehaviors.obj_spawn_yellow_coins(o, 3)
		SpawnSound.create_sound_spawner(IncludeSoundsH.SOUND_GENERAL_BREAK_BOX)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end

	ObjBehaviors.obj_check_floor_death(collisionFlags, ObjBehaviors.sObjFloor)
end

-- from src/game/behaviors/breakable_box_small.inc.c:breakable_box_small_released_loop L58-75
function breakable_box_small_inc.breakable_box_small_released_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased) + 1))

	-- Begin flashing
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased) > 810 then
		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased), 1) then
			o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		else
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	end

	-- Despawn, and create a corkbox respawner
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased) > 900 then
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BREAKABLE_BOX_SMALL, BehaviorIds.bhvBreakableBoxSmall, 3000)
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	end
end

-- from src/game/behaviors/breakable_box_small.inc.c:breakable_box_small_idle_loop L77-96
function breakable_box_small_inc.breakable_box_small_idle_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		breakable_box_small_inc.small_breakable_box_act_move()
	elseif action == 100 then
		ObjBehaviors.obj_lava_death()
	elseif action == 101 then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		CorkboxInc.create_respawner(IncludeModelIdsH.MODEL_BREAKABLE_BOX_SMALL, BehaviorIds.bhvBreakableBoxSmall, 3000)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallReleased) == IncludePRUltratypesH.TRUE then
		breakable_box_small_inc.breakable_box_small_released_loop()
	end
end

-- from src/game/behaviors/breakable_box_small.inc.c:breakable_box_small_get_dropped L98-106
function breakable_box_small_inc.breakable_box_small_get_dropped()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_become_tangible()
	ObjectHelpers.cur_obj_enable_rendering()
	ObjectHelpers.cur_obj_get_dropped()
	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallReleased, IncludePRUltratypesH.TRUE)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased, 0)
end

-- from src/game/behaviors/breakable_box_small.inc.c:breakable_box_small_get_thrown L108-120
function breakable_box_small_inc.breakable_box_small_get_thrown()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_become_tangible()
	ObjectHelpers.cur_obj_enable_rendering_2()
	ObjectHelpers.cur_obj_enable_rendering()
	o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oHeldState, 0)
	buffer.writeu32(o.rawData, IncludeObjectFieldsH.oFlags, U32(bit32.band(buffer.readu32(o.rawData, IncludeObjectFieldsH.oFlags), bit32.bnot(IncludeObjectConstantsH.OBJ_FLAG_SET_FACE_YAW_TO_MOVE_YAW))))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 40.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 20.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallReleased, IncludePRUltratypesH.TRUE)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oBreakableBoxSmallFramesSinceReleased, 0)
	o.activeFlags = S16(bit32.band(o.activeFlags, bit32.bnot(IncludeObjectConstantsH.ACTIVE_FLAG_UNK9)))
end

-- from src/game/behaviors/breakable_box_small.inc.c:bhv_breakable_box_small_loop L122-143
function breakable_box_small_inc.bhv_breakable_box_small_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == 0 then
		breakable_box_small_inc.breakable_box_small_idle_loop()
	elseif heldState == 1 then
		ObjectHelpers.cur_obj_disable_rendering()
		ObjectHelpers.cur_obj_become_intangible()
	elseif heldState == 2 then
		breakable_box_small_inc.breakable_box_small_get_thrown()
	elseif heldState == 3 then
		breakable_box_small_inc.breakable_box_small_get_dropped()
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return breakable_box_small_inc
