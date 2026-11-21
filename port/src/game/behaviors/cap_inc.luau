--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/cap.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const Area = require("../area")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeCourseTableH = require("../../../include/course_table_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../../include/surface_terrains_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SaveFile = require("../save_file")
const SaveFileH = require("../save_file_h")
const SrcEngineMathUtilH = require("../../engine/math_util_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/cap.inc.c:data
const cap_inc = {
	-- from src/game/behaviors/cap.inc.c:sCapHitbox L3-13
	sCapHitbox = {
		interactType = InteractionH.INTERACT_CAP,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 80,
		height = 80,
		hurtboxRadius = 90,
		hurtboxHeight = 90,
	},
}

Registry.Register("src__game__behaviors__cap_inc", cap_inc)

-- from src/game/behaviors/cap.inc.c:cap_set_hitbox L15-25
function cap_inc.cap_set_hitbox(): number
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, cap_inc.sCapHitbox)

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_INTERACTED) then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/behaviors/cap.inc.c:cap_despawn L27-31
function cap_inc.cap_despawn()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 300 then
		ObjBehaviors.obj_flicker_and_disappear(o, 300)
	end
end

-- from src/game/behaviors/cap.inc.c:cap_check_quicksand L33-69
function cap_inc.cap_check_quicksand()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Floor = ObjBehaviors.sObjFloor

	if Floor == nil then
		return
	end

	if Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
		o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
	elseif Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_QUICKSAND or Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_DEEP_QUICKSAND or Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_QUICKSAND then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 10)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	elseif Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_DEEP_MOVING_QUICKSAND or Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_SHALLOW_MOVING_QUICKSAND or Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_MOVING_QUICKSAND then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 11)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, bit32.lshift(bit32.band(Floor.force, 0xFF), 8))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 8 + 2 * (0 - bit32.rshift(bit32.band(Floor.force, 0xFF00), 8)))
	elseif Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_INSTANT_QUICKSAND then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 12)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)
	elseif Floor.type_ == IncludeSurfaceTerrainsH.SURFACE_INSTANT_MOVING_QUICKSAND then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 13)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, bit32.lshift(bit32.band(Floor.force, 0xFF), 8))
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 8 + 2 * (0 - bit32.rshift(bit32.band(Floor.force, 0xFF00), 8)))
	end
end

-- from src/game/behaviors/cap.inc.c:cap_sink_quicksand L71-104
function cap_inc.cap_sink_quicksand()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 10 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) + -1.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x2000)
		end
	elseif action == 11 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 10 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) + -3.0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x2000)
	elseif action == 12 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) + -1.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end
	elseif action == 13 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oGraphYOffset, buffer.readf32(o.rawData, IncludeObjectFieldsH.oGraphYOffset) + -6.0)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
			o.activeFlags = IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0x2000)
	end

	cap_inc.cap_check_quicksand()
end

-- from src/game/behaviors/cap.inc.c:bhv_wing_cap_init L106-111
function cap_inc.bhv_wing_cap_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 1.2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 0.9)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
end

-- from src/game/behaviors/cap.inc.c:cap_scale_vertically L113-120
function cap_inc.cap_scale_vertically()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oCapUnkF8, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCapUnkF8) + 0x2000))
	o.header.gfx.scale[2] = F32(SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oCapUnkF8)) * 0.3 + 0.7)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCapUnkF8) == 0x10000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCapUnkF8, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oCapUnkF4, 2)
	end
end

-- from src/game/behaviors/cap.inc.c:wing_vanish_cap_act_0 L122-139
function cap_inc.wing_vanish_cap_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 128.0))))
	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		cap_inc.cap_check_quicksand()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) ~= 0.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCapUnkF4, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCapUnkF4) == 1 then
		cap_inc.cap_scale_vertically()
	end
end

-- from src/game/behaviors/cap.inc.c:bhv_wing_vanish_cap_loop L141-159
function cap_inc.bhv_wing_vanish_cap_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		cap_inc.wing_vanish_cap_act_0()
	else
		ObjBehaviors.object_step()
		cap_inc.cap_sink_quicksand()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		ObjectHelpers.cur_obj_become_tangible()
	end

	cap_inc.cap_despawn()
	cap_inc.cap_set_hitbox()
end

-- from src/game/behaviors/cap.inc.c:bhv_metal_cap_init L161-166
function cap_inc.bhv_metal_cap_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 2.4)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 1.5)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)
end

-- from src/game/behaviors/cap.inc.c:metal_cap_act_0 L168-177
function cap_inc.metal_cap_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 128.0))))
	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		cap_inc.cap_check_quicksand()
	end
end

-- from src/game/behaviors/cap.inc.c:bhv_metal_cap_loop L179-197
function cap_inc.bhv_metal_cap_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		cap_inc.metal_cap_act_0()
	else
		ObjBehaviors.object_step()
		cap_inc.cap_sink_quicksand()
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 20 then
		ObjectHelpers.cur_obj_become_tangible()
	end

	cap_inc.cap_set_hitbox()
	cap_inc.cap_despawn()
end

-- from src/game/behaviors/cap.inc.c:bhv_normal_cap_init L199-206
function cap_inc.bhv_normal_cap_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 0.7)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.89)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 0.9)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 255)

	SaveFile.save_file_set_cap_pos(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
end

-- from src/game/behaviors/cap.inc.c:normal_cap_set_save_flags L208-228
function cap_inc.normal_cap_set_save_flags()
	SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_CAP_ON_GROUND)

	if Area.gCurrCourseNum == IncludeCourseTableH.COURSE_SSL then
		SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO)
	elseif Area.gCurrCourseNum == IncludeCourseTableH.COURSE_SL then
		SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_MR_BLIZZARD)
	elseif Area.gCurrCourseNum == IncludeCourseTableH.COURSE_TTM then
		SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_UKIKI)
	else
		SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_CAP_ON_KLEPTO)
	end
end

-- from src/game/behaviors/cap.inc.c:normal_cap_act_0 L230-250
function cap_inc.normal_cap_act_0()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw)) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 128.0))))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(F32(F32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) + F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * 80.0))))
	const collisionFlags = S16(ObjBehaviors.object_step())

	if bit32.btest(collisionFlags, ObjBehaviors.OBJ_COL_FLAG_GROUNDED) then
		cap_inc.cap_check_quicksand()

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) ~= 0.0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oCapUnkF4, 1)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0.0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
		end
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oCapUnkF4) == 1 then
		cap_inc.cap_scale_vertically()
	end
end

-- from src/game/behaviors/cap.inc.c:bhv_normal_cap_loop L252-275
function cap_inc.bhv_normal_cap_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == 0 then
		cap_inc.normal_cap_act_0()
	else
		ObjBehaviors.object_step()
		cap_inc.cap_sink_quicksand()
	end

	if TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)) ~= 0 then
		SaveFile.save_file_set_cap_pos(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	end

	if o.activeFlags == IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED then
		cap_inc.normal_cap_set_save_flags()
	end

	if cap_inc.cap_set_hitbox() == IncludePRUltratypesH.TRUE then
		SaveFile.save_file_clear_flags(SaveFileH.SAVE_FLAG_CAP_ON_GROUND)
	end
end

-- from src/game/behaviors/cap.inc.c:bhv_vanish_cap_init L277-282
function cap_inc.bhv_vanish_cap_init()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oGravity, 1.2)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oFriction, 0.999)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oBuoyancy, 0.9)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oOpacity, 150)
end

return cap_inc
