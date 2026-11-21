--!strict
--!optimize 2

--[[
	Port of src/game/platform_displacement.c.
]]

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const LevelUpdate = require("./level_update")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const ObjectListProcessorH = require("./object_list_processor_h")
const Registry = require("../../groups/registry")
const SrcEngineMathUtil = require("../engine/math_util")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/platform_displacement.c:data
const platform_displacement = {
	-- from src/game/platform_displacement.c:D_8032FEC0 L12-12
	D_8032FEC0 = 0,
	-- from src/game/platform_displacement.c:unused_8032FEC4 L14-14
	unused_8032FEC4 = { 0, 0, 0, 0 },
	-- from src/game/platform_displacement.c:gMarioPlatform L16-16
	gMarioPlatform = nil :: GroupsTypesHPlus3Types.Object?,
	-- scratch for the out parameters of find_floor, get_mario_pos and the matrix helpers (no re-entrancy)
	sFloor = { nil :: GroupsTypesHPlus3Types.Surface? },
	sMarioPosX = { 0 },
	sMarioPosY = { 0 },
	sMarioPosZ = { 0 },
	sCurrentObjectOffset = table.create(3, 0),
	sRelativeOffset = table.create(3, 0),
	sNewObjectOffset = table.create(3, 0),
	sRotation = table.create(3, 0),
	sDisplaceMatrix = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
}

-- from src/game/platform_displacement.c:update_mario_platform L22-67
function platform_displacement.update_mario_platform()
	if Registry.Members.src__game__object_list_processor.gMarioObject == nil then
		return
	end

	--! If Mario moves onto a rotating platform in a PU, the find_floor call
	--  will detect the platform and he will end up receiving a large amount
	--  of displacement since he is considered to be far from the platform's
	--  axis of rotation.
	const marioX = buffer.readf32(Registry.Members.src__game__object_list_processor.gMarioObject.rawData, IncludeObjectFieldsH.oPosX)
	const marioY = buffer.readf32(Registry.Members.src__game__object_list_processor.gMarioObject.rawData, IncludeObjectFieldsH.oPosY)
	const marioZ = buffer.readf32(Registry.Members.src__game__object_list_processor.gMarioObject.rawData, IncludeObjectFieldsH.oPosZ)
	const floorHeight = Registry.Members.src__engine__surface_collision.find_floor(marioX, marioY, marioZ, platform_displacement.sFloor)
	const floor = platform_displacement.sFloor[1]

	local awayFromFloor: number

	if Registry.Members.src__game__object_helpers.absf(F32(marioY - floorHeight)) < 4.0 then
		awayFromFloor = 0
	else
		awayFromFloor = 1
	end

	if awayFromFloor == 1 then
		platform_displacement.gMarioPlatform = nil
		Registry.Members.src__game__object_list_processor.gMarioObject.platform = nil
	elseif awayFromFloor == 0 then
		if floor ~= nil and floor.object ~= nil then
			platform_displacement.gMarioPlatform = floor.object
			Registry.Members.src__game__object_list_processor.gMarioObject.platform = floor.object
		else
			platform_displacement.gMarioPlatform = nil
			Registry.Members.src__game__object_list_processor.gMarioObject.platform = nil
		end
	end
end

-- from src/game/platform_displacement.c:get_mario_pos L72-76
function platform_displacement.get_mario_pos(x: { number }, y: { number }, z: { number })
	x[1] = LevelUpdate.gMarioStates[1].pos[1]
	y[1] = LevelUpdate.gMarioStates[1].pos[2]
	z[1] = LevelUpdate.gMarioStates[1].pos[3]
end

-- from src/game/platform_displacement.c:set_mario_pos L81-85
function platform_displacement.set_mario_pos(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	LevelUpdate.gMarioStates[1].pos[1] = x
	LevelUpdate.gMarioStates[1].pos[2] = y
	LevelUpdate.gMarioStates[1].pos[3] = z
end

-- from src/game/platform_displacement.c:apply_platform_displacement L91-166
function platform_displacement.apply_platform_displacement(isMario: number, platform: GroupsTypesHPlus3Types.Object)
	-- rotation is Vec3s: the s16 stores wrap
	platform_displacement.sRotation[1] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelPitch))
	platform_displacement.sRotation[2] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelYaw))
	platform_displacement.sRotation[3] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelRoll))

	local x: number
	local y: number
	local z: number

	if isMario ~= 0 then
		platform_displacement.D_8032FEC0 = 0
		platform_displacement.get_mario_pos(platform_displacement.sMarioPosX, platform_displacement.sMarioPosY, platform_displacement.sMarioPosZ)
		x = platform_displacement.sMarioPosX[1]
		y = platform_displacement.sMarioPosY[1]
		z = platform_displacement.sMarioPosZ[1]
	else
		x = buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosX)
		y = buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosY)
		z = buffer.readf32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosZ)
	end

	x = F32(x + buffer.readf32(platform.rawData, IncludeObjectFieldsH.oVelX))
	z = F32(z + buffer.readf32(platform.rawData, IncludeObjectFieldsH.oVelZ))

	if platform_displacement.sRotation[1] ~= 0 or platform_displacement.sRotation[2] ~= 0 or platform_displacement.sRotation[3] ~= 0 then
		if isMario ~= 0 then
			LevelUpdate.gMarioStates[1].faceAngle[2] = S16(LevelUpdate.gMarioStates[1].faceAngle[2] + platform_displacement.sRotation[2])
		end

		const platformPosX = buffer.readf32(platform.rawData, IncludeObjectFieldsH.oPosX)
		const platformPosY = buffer.readf32(platform.rawData, IncludeObjectFieldsH.oPosY)
		const platformPosZ = buffer.readf32(platform.rawData, IncludeObjectFieldsH.oPosZ)

		platform_displacement.sCurrentObjectOffset[1] = F32(x - platformPosX)
		platform_displacement.sCurrentObjectOffset[2] = F32(y - platformPosY)
		platform_displacement.sCurrentObjectOffset[3] = F32(z - platformPosZ)

		platform_displacement.sRotation[1] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAnglePitch) - buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelPitch))
		platform_displacement.sRotation[2] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelYaw))
		platform_displacement.sRotation[3] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAngleRoll) - buffer.readi32(platform.rawData, IncludeObjectFieldsH.oAngleVelRoll))

		SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(platform_displacement.sDisplaceMatrix, platform_displacement.sCurrentObjectOffset, platform_displacement.sRotation)
		Registry.Members.src__game__object_helpers.linear_mtxf_transpose_mul_vec3f(platform_displacement.sDisplaceMatrix, platform_displacement.sRelativeOffset, platform_displacement.sCurrentObjectOffset)

		platform_displacement.sRotation[1] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
		platform_displacement.sRotation[2] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
		platform_displacement.sRotation[3] = S16(buffer.readi32(platform.rawData, IncludeObjectFieldsH.oFaceAngleRoll))

		SrcEngineMathUtil.mtxf_rotate_zxy_and_translate(platform_displacement.sDisplaceMatrix, platform_displacement.sCurrentObjectOffset, platform_displacement.sRotation)
		Registry.Members.src__game__object_helpers.linear_mtxf_mul_vec3f(platform_displacement.sDisplaceMatrix, platform_displacement.sNewObjectOffset, platform_displacement.sRelativeOffset)

		x = F32(platformPosX + platform_displacement.sNewObjectOffset[1])
		y = F32(platformPosY + platform_displacement.sNewObjectOffset[2])
		z = F32(platformPosZ + platform_displacement.sNewObjectOffset[3])
	end

	if isMario ~= 0 then
		platform_displacement.set_mario_pos(x, y, z)
	else
		buffer.writef32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosX, x)
		buffer.writef32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosY, y)
		buffer.writef32(Registry.Members.src__game__object_list_processor.gCurrentObject.rawData, IncludeObjectFieldsH.oPosZ, z)
	end
end

-- from src/game/platform_displacement.c:apply_mario_platform_displacement L171-177
function platform_displacement.apply_mario_platform_displacement()
	const platform = platform_displacement.gMarioPlatform

	if not bit32.btest(Registry.Members.src__game__object_list_processor.gTimeStopState, ObjectListProcessorH.TIME_STOP_ACTIVE) and Registry.Members.src__game__object_list_processor.gMarioObject ~= nil and platform ~= nil then
		platform_displacement.apply_platform_displacement(IncludePRUltratypesH.TRUE, platform)
	end
end

-- from src/game/platform_displacement.c:clear_mario_platform L183-185
function platform_displacement.clear_mario_platform()
	platform_displacement.gMarioPlatform = nil
end

return platform_displacement
