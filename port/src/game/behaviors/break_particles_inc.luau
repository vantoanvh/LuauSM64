--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/break_particles.inc.c.
]]

const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const Registry = require("../../../groups/registry")

const break_particles_inc = {}

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

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/break_particles.inc.c:spawn_triangle_break_particles L3-27
function break_particles_inc.spawn_triangle_break_particles(numTris: number, triModel: number, triSize: number, triAnimState: number)
	numTris = S16(TruncS32(numTris))
	triModel = S16(TruncS32(triModel))
	triSize = F32(triSize)
	triAnimState = S16(TruncS32(triAnimState))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	for i = 0, numTris - 1 do
		const triangle: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_helpers.spawn_object(o, triModel, BehaviorIds.bhvBreakBoxTriangle)

		buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oAnimState, triAnimState)
		buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(triangle.rawData, IncludeObjectFieldsH.oPosY) + 100.0)

		const moveAngleYaw: number = Registry.Members.src__engine__behavior_script.random_u16()

		buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oMoveAngleYaw, moveAngleYaw)
		buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(triangle.rawData, IncludeObjectFieldsH.oMoveAngleYaw))

		const facePitch: number = Registry.Members.src__engine__behavior_script.random_u16()

		buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oFaceAnglePitch, facePitch)

		const velY: number = Registry.Members.src__game__object_helpers.random_f32_around_zero(50.0)

		buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oVelY, velY)

		if triModel == IncludeModelIdsH.MODEL_DIRT_ANIMATION or triModel == IncludeModelIdsH.MODEL_SL_CRACKED_ICE_CHUNK then
			buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0xF00)
			buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oAngleVelYaw, 0x500)
			buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
		else
			const randomFloat: number = Registry.Members.src__engine__behavior_script.random_float()

			buffer.writei32(triangle.rawData, IncludeObjectFieldsH.oAngleVelPitch, S32(0x80 * TruncS32(F32(randomFloat + 50.0))))
			buffer.writef32(triangle.rawData, IncludeObjectFieldsH.oForwardVel, 30.0)
		end

		Registry.Members.src__game__object_helpers.obj_scale(triangle, triSize)
	end
end

return break_particles_inc
