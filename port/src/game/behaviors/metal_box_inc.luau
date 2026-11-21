--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/metal_box.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/metal_box_inc.luau:scratch
const Scratch = {
	check_if_moving_over_floor_pfloor = {},
}

-- from src/game/behaviors/metal_box.inc.c:data
const metal_box_inc = {
	-- from src/game/behaviors/metal_box.inc.c:sMetalBoxHitbox L3-13
	sMetalBoxHitbox = {
		interactType = 0,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 220,
		height = 300,
		hurtboxRadius = 220,
		hurtboxHeight = 300,
	},
}

Registry.Register("src__game__behaviors__metal_box_inc", metal_box_inc)

-- from src/game/behaviors/metal_box.inc.c:check_if_moving_over_floor L15-28
function metal_box_inc.check_if_moving_over_floor(a0: number, a1: number): number
	a0 = F32(a0)
	a1 = F32(a1)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp20 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * a1))
	const sp18 = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)) * a1))
	const floorHeight = SrcEngineSurfaceCollision.find_floor(sp20, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), sp18, Scratch.check_if_moving_over_floor_pfloor)

	if ObjectHelpers.absf(F32(floorHeight - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))) < a0 then
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/behaviors/metal_box.inc.c:bhv_pushable_loop L30-49
function metal_box_inc.bhv_pushable_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, metal_box_inc.sMetalBoxHitbox)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if ObjectHelpers.obj_check_if_collided_with_object(o, marioObj) ~= 0 and bit32.btest(LevelUpdate.gMarioStates[1].flags, IncludeSm64H.MARIO_UNKNOWN_31) then
		const sp1C = S16(ObjectHelpers.obj_angle_to_object(o, marioObj))

		if ObjectHelpers.abs_angle_diff(sp1C, S16(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) > 0x4000 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S16(bit32.band(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 0x2000, 0xC000)))

			if metal_box_inc.check_if_moving_over_floor(8.0, 150.0) ~= 0 then
				buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 4.0)
				Registry.Members.src__game__spawn_sound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_METAL_BOX_PUSH)
			end
		end
	end

	ObjectHelpers.cur_obj_move_using_fvel_and_gravity()
end

return metal_box_inc
