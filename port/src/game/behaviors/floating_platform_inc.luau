--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/floating_platform.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectListProcessor = require("../object_list_processor")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")

const floating_platform_inc = {}

Registry.Register("src__game__behaviors__floating_platform_inc", floating_platform_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

-- from src/game/behaviors/floating_platform_inc.luau:scratch
const Scratch = {
	floating_platform_find_home_y_floor = {} :: { GroupsTypesHPlus3.Surface? },
}

-- from src/game/behaviors/floating_platform.inc.c:floating_platform_find_home_y L3-15
function floating_platform_inc.floating_platform_find_home_y(): number
	const o = ObjectListProcessor.gCurrentObject

	const sp20 = SrcEngineSurfaceCollision.find_water_level(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const sp1C = SrcEngineSurfaceCollision.find_floor(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.floating_platform_find_home_y_floor)

	if sp20 > F32(sp1C + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkFC)) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF4, 0)
		return F32(sp20 + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkFC))
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF4, 1)
		return F32(sp1C + buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkFC))
	end
end

-- from src/game/behaviors/floating_platform.inc.c:floating_platform_act_0 L17-58
function floating_platform_inc.floating_platform_act_0()
	const o = ObjectListProcessor.gCurrentObject
	const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

	const sp6 = S16(TruncS32(F32(F32(F32(mario.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)) * SrcEngineMathUtilH.coss(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) + F32(F32(mario.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) * SrcEngineMathUtilH.sins(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))))
	const sp4 = S16(TruncS32(F32(F32(F32(mario.header.gfx.pos[3] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) * SrcEngineMathUtilH.coss(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) - F32(F32(mario.header.gfx.pos[1] - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)) * SrcEngineMathUtilH.sins(-1 * buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))))))

	if mario.platform == o then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, sp4 * 2)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, -sp6 * 2)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - 1)
		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		end

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8) > 90 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8, 90)
		end
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) / 2))
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) / 2))

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8, buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8) - 5)

		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 10)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8) < 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8, 0)
		end
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, F32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - 64) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF8)) + F32(SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnk100) * 0x800) * 10))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnk100, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnk100) + 1)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnk100) == 32 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnk100, 0)
	end
end

-- from src/game/behaviors/floating_platform.inc.c:bhv_floating_platform_loop L60-77
function floating_platform_inc.bhv_floating_platform_loop()
	const o = ObjectListProcessor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, floating_platform_inc.floating_platform_find_home_y())

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFloatingPlatformUnkF4) == 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 1)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
		floating_platform_inc.floating_platform_act_0()
	elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 1 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	end
end

return floating_platform_inc
