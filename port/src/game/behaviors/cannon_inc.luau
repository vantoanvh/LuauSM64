--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/cannon.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const cannon_inc = {}

Registry.Register("src__game__behaviors__cannon_inc", cannon_inc)

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

-- from src/game/behaviors/cannon.inc.c:bhv_cannon_base_unused_loop L3-5
function cannon_inc.bhv_cannon_base_unused_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_0 L7-37
function cannon_inc.opened_cannon_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S16(bit32.lshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), 8)))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnk10C, IncludePRUltratypesH.FALSE)
		ObjectHelpers.cur_obj_enable_rendering()
		ObjectHelpers.cur_obj_become_tangible()
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
		ObjectHelpers.cur_obj_become_tangible()
		ObjectHelpers.cur_obj_enable_rendering()

		if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) and not bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_TOUCHED_BOB_OMB) then -- bob-omb explodes when it gets into a cannon
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 4)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnk10C, IncludePRUltratypesH.TRUE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF8, 1)
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		end
	else
		ObjectHelpers.cur_obj_become_intangible()
		ObjectHelpers.cur_obj_disable_rendering()
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnk10C, IncludePRUltratypesH.FALSE)
	end
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_4 L39-53
function cannon_inc.opened_cannon_act_4()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_CANNON1)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 5.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 2))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 2))

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 67 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 4))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 4))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 6)
	end
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_6 L55-77
function cannon_inc.opened_cannon_act_6()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_CANNON2)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 4 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 4.0))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + F32(F32(bit32.band(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) // 2, 1) - 0.5) * 4.0))
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 6 then
			-- Empty in the C source.
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 22 then
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, TruncS32(F32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4)) * 0x4000) + S16(bit32.lshift(buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte), 8)))))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4) + 0x400))
			elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 26 then
				-- Empty in the C source.
			else
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4, 0)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 5)
			end
		end
	end
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_5 L79-94
function cannon_inc.opened_cannon_act_5()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_CANNON3)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 4 then
		-- Empty in the C source.
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 20 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4) + 0x400))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, TruncS32(F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF4)) * 0x2000)))
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 25 then
			-- Empty in the C source.
		else
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
		end
	end
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_1 L96-104
function cannon_inc.opened_cannon_act_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_become_intangible()
	ObjectHelpers.cur_obj_disable_rendering()

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnk10C, IncludePRUltratypesH.FALSE)
	ObjectListProcessor.gMarioShotFromCannon = IncludePRUltratypesH.TRUE
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_2 L106-108
function cannon_inc.opened_cannon_act_2()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
end

-- from src/game/behaviors/cannon.inc.c:opened_cannon_act_3 L110-115
function cannon_inc.opened_cannon_act_3()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 3 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	end
end

-- from src/game/behaviors/cannon.inc.c:bhv_cannon_base_loop L127-135
function cannon_inc.bhv_cannon_base_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.cur_obj_call_action_function(cannon_inc.sOpenedCannonActions)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF8) ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCannonUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCannonUnkF8) + 1))
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

-- from src/game/behaviors/cannon.inc.c:bhv_cannon_barrel_loop L137-148
function cannon_inc.bhv_cannon_barrel_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const parent = o.parentObj :: GroupsTypesHPlus3.Object

	if bit32.btest(parent.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		ObjectHelpers.cur_obj_enable_rendering()
		ObjectHelpers.obj_copy_pos(o, parent)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(parent.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	else
		ObjectHelpers.cur_obj_disable_rendering()
	end
end

-- from src/game/behaviors/cannon.inc.c:sOpenedCannonActions L117-125
cannon_inc.sOpenedCannonActions = {
	cannon_inc.opened_cannon_act_0,
	cannon_inc.opened_cannon_act_1,
	cannon_inc.opened_cannon_act_2,
	cannon_inc.opened_cannon_act_3,
	cannon_inc.opened_cannon_act_4,
	cannon_inc.opened_cannon_act_5,
	cannon_inc.opened_cannon_act_6,
}

return cannon_inc
