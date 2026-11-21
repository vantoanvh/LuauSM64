--!strict
--!optimize 2

--[[
	Port of src/game/macro_special_objects.c.
]]

const BehaviorIds = require("../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSpecialPresetsH = require("../../include/special_presets_h")
const IncludeSpecialPresetsInc = require("../../include/special_presets_inc")
const ObjectHelpers = require("./object_helpers")
const Registry = require("../../groups/registry")
const Rom = require("../rom/rom")
const IncludeMacroPresetsInc = require("../../include/macro_presets_inc")
const IncludeObjectConstantsH = require("../../include/object_constants_h")

-- from src/game/macro_special_objects.c:LoadedPreset
export type LoadedPreset = {
	behavior: number?,
	param: number,
	model: number,
}

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
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

-- from src/game/macro_special_objects.luau:scratch
const Scratch = {
	spawn_macro_objects_macroObject = table.create(5, 0),
}

-- from src/game/macro_special_objects.c:data
const macro_special_objects = {
	MACRO_OBJ_Y_ROT = 0,
	MACRO_OBJ_X = 1,
	MACRO_OBJ_Y = 2,
	MACRO_OBJ_Z = 3,
	MACRO_OBJ_PARAMS = 4,
}

-- from src/game/macro_special_objects.c:LoadedPreset (zero-filled constructor)
function macro_special_objects.new_LoadedPreset(): LoadedPreset
	return { behavior = nil, param = 0, model = 0 } :: LoadedPreset
end

-- from src/game/macro_special_objects.c:convert_rotation L16-37
function macro_special_objects.convert_rotation(inRotation: number): number
	inRotation = S16(TruncS32(inRotation))
	local rotation = U16(bit32.band(inRotation, 0xFF))

	rotation = U16(bit32.lshift(rotation, 8))

	if rotation == 0x3F00 then
		rotation = 0x4000
	end

	if rotation == 0x7F00 then
		rotation = 0x8000
	end

	if rotation == 0xBF00 then
		rotation = 0xC000
	end

	if rotation == 0xFF00 then
		rotation = 0x0000
	end

	return S16(rotation)
end

-- from src/game/macro_special_objects.c:spawn_macro_abs_yrot_2params L44-50
function macro_special_objects.spawn_macro_abs_yrot_2params(model: number, behavior: number?, x: number, y: number, z: number, ry: number, params: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	ry = S16(TruncS32(ry))
	params = S16(TruncS32(params))
	if behavior ~= nil then
		const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent
		const newObj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_abs_with_rot(defaultParent, 0, model, behavior, x, y, z, 0, macro_special_objects.convert_rotation(ry), 0)

		buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.lshift(params, 16)))
	end
end

-- from src/game/macro_special_objects.c:spawn_macro_abs_yrot_param1 L57-63
function macro_special_objects.spawn_macro_abs_yrot_param1(model: number, behavior: number?, x: number, y: number, z: number, ry: number, param: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	ry = S16(TruncS32(ry))
	param = S16(TruncS32(param))
	if behavior ~= nil then
		const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent
		const newObj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_abs_with_rot(defaultParent, 0, model, behavior, x, y, z, 0, macro_special_objects.convert_rotation(ry), 0)

		buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oBhvParams, S32(bit32.lshift(param, 24)))
	end
end

-- from src/game/macro_special_objects.c:spawn_macro_abs_special L69-78
function macro_special_objects.spawn_macro_abs_special(model: number, behavior: number, x: number, y: number, z: number, unkA: number, unkB: number, unkC: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	unkA = S16(TruncS32(unkA))
	unkB = S16(TruncS32(unkB))
	unkC = S16(TruncS32(unkC))
	const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent
	const newObj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_abs_with_rot(defaultParent, 0, model, behavior, x, y, z, 0, 0, 0)

	-- Are all three of these values unused?
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oMacroUnk108, unkA)
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oMacroUnk10C, unkB)
	buffer.writef32(newObj.rawData, IncludeObjectFieldsH.oMacroUnk110, unkC)
end

-- from src/game/macro_special_objects.c:spawn_macro_coin_unknown L86-95
function macro_special_objects.spawn_macro_coin_unknown(behavior: number, objInfo: { number })
	const model = if behavior == BehaviorIds.bhvYellowCoin then IncludeModelIdsH.MODEL_YELLOW_COIN else IncludeModelIdsH.MODEL_NONE
	const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent
	const coin: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_abs_with_rot(defaultParent, 0, model, behavior, objInfo[macro_special_objects.MACRO_OBJ_X + 1], objInfo[macro_special_objects.MACRO_OBJ_Y + 1], objInfo[macro_special_objects.MACRO_OBJ_Z + 1], 0, macro_special_objects.convert_rotation(objInfo[macro_special_objects.MACRO_OBJ_Y_ROT + 1]), 0)

	buffer.writeu32(coin.rawData, IncludeObjectFieldsH.oUnusedBhvParams, U32(objInfo[macro_special_objects.MACRO_OBJ_PARAMS + 1]))
	buffer.writei32(coin.rawData, IncludeObjectFieldsH.oBhvParams, bit32.rshift(bit32.band(objInfo[macro_special_objects.MACRO_OBJ_PARAMS + 1], 0xFF), 16))
end

-- from src/game/macro_special_objects.c:spawn_macro_objects L103-168
function macro_special_objects.spawn_macro_objects(areaIndex: number, macroObjList: number)
	areaIndex = S16(TruncS32(areaIndex))
	const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent
	const macroObject: { number } = Scratch.spawn_macro_objects_macroObject

	defaultParent.header.gfx.areaIndex = S8(areaIndex)
	defaultParent.header.gfx.activeAreaIndex = S8(areaIndex)

	while true do
		-- An encountered value of -1 means the list has ended.
		if Rom.ReadS16(macroObjList) == -1 then
			break
		end

		-- Preset identifier for sMacroObjectPresets array
		const presetID: number = bit32.band(Rom.ReadS16(macroObjList), 0x1FF) - 31

		if presetID < 0 then
			break
		end

		-- Set macro object properties from the list
		macroObject[macro_special_objects.MACRO_OBJ_Y_ROT + 1] = S16(bit32.lshift(bit32.band(Rom.ReadS16(macroObjList) // 512, 0x7F), 1))
		macroObjList += 2
		macroObject[macro_special_objects.MACRO_OBJ_X + 1] = Rom.ReadS16(macroObjList)
		macroObjList += 2
		macroObject[macro_special_objects.MACRO_OBJ_Y + 1] = Rom.ReadS16(macroObjList)
		macroObjList += 2
		macroObject[macro_special_objects.MACRO_OBJ_Z + 1] = Rom.ReadS16(macroObjList)
		macroObjList += 2
		macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1] = Rom.ReadS16(macroObjList)
		macroObjList += 2

		-- Get the preset values from the sMacroObjectPresets list.
		const preset = IncludeMacroPresetsInc.sMacroObjectPresets[presetID + 1]

		if preset.param ~= 0 then
			macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1] = S16(bit32.band(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1], 0xFF00) + bit32.band(preset.param, 0x00FF))
		end

		-- If object has been killed, prevent it from respawning
		if bit32.band(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1] // 256, IncludeObjectConstantsH.RESPAWN_INFO_DONT_RESPAWN) ~= IncludeObjectConstantsH.RESPAWN_INFO_DONT_RESPAWN then
			-- Spawn the new macro object.
			const newObj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object_abs_with_rot(defaultParent, 0, preset.model, preset.behavior :: number, macroObject[macro_special_objects.MACRO_OBJ_X + 1], macroObject[macro_special_objects.MACRO_OBJ_Y + 1], macroObject[macro_special_objects.MACRO_OBJ_Z + 1], 0, macro_special_objects.convert_rotation(macroObject[macro_special_objects.MACRO_OBJ_Y_ROT + 1]), 0)

			buffer.writeu32(newObj.rawData, IncludeObjectFieldsH.oUnusedBhvParams, U32(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1]))
			buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oBhvParams, bit32.lshift(bit32.band(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1], 0x00FF), 16) + bit32.band(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1], 0xFF00))
			buffer.writei32(newObj.rawData, IncludeObjectFieldsH.oBhvParams2ndByte, bit32.band(macroObject[macro_special_objects.MACRO_OBJ_PARAMS + 1], 0x00FF))
			newObj.respawnInfoType = IncludeObjectConstantsH.RESPAWN_INFO_TYPE_16
			newObj.respawnInfo = macroObjList - 2
			newObj.parentObj = newObj
		end
	end
end

-- from src/game/macro_special_objects.c:spawn_macro_objects_hardcoded L170-234
function macro_special_objects.spawn_macro_objects_hardcoded(areaIndex: number, macroObjList: number)
	areaIndex = S16(TruncS32(areaIndex))
	const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent

	defaultParent.header.gfx.areaIndex = S8(areaIndex)
	defaultParent.header.gfx.activeAreaIndex = S8(areaIndex)

	while true do
		const macroObjPreset: number = Rom.ReadS16(macroObjList)

		macroObjList += 2

		if macroObjPreset < 0 then
			break
		end

		const macroObjX: number = Rom.ReadS16(macroObjList)

		macroObjList += 2

		const macroObjY: number = Rom.ReadS16(macroObjList)

		macroObjList += 2

		const macroObjZ: number = Rom.ReadS16(macroObjList)

		macroObjList += 2

		const macroObjRY: number = Rom.ReadS16(macroObjList)

		macroObjList += 2

		if macroObjPreset == 0 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_NONE, BehaviorIds.bhvBooStaircase, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 1 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_BBH_TILTING_FLOOR_PLATFORM, BehaviorIds.bhvBBHTiltingTrapPlatform, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 2 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_BBH_TUMBLING_PLATFORM, BehaviorIds.bhvBBHTumblingBridge, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 3 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_BBH_MOVING_BOOKSHELF, BehaviorIds.bhvHauntedBookshelf, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 4 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_BBH_MESH_ELEVATOR, BehaviorIds.bhvMeshElevator, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 20 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvYellowCoin, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		elseif macroObjPreset == 21 then
			macro_special_objects.spawn_macro_abs_yrot_2params(IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvYellowCoin, macroObjX, macroObjY, macroObjZ, macroObjRY, 0)
		end
	end
end

-- from src/game/macro_special_objects.c:spawn_special_objects L236-321
function macro_special_objects.spawn_special_objects(areaIndex: number, specialObjList: { number })
	areaIndex = S16(TruncS32(areaIndex))
	const extraParams: { number } = table.create(4, 0)
	const numOfSpecialObjects: number = Rom.ReadS16(specialObjList[1])
	const defaultParent: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMacroObjectDefaultParent

	specialObjList[1] += 2
	defaultParent.header.gfx.areaIndex = S8(areaIndex)
	defaultParent.header.gfx.activeAreaIndex = S8(areaIndex)

	for i = 1, numOfSpecialObjects do
		const presetID: number = U8(Rom.ReadS16(specialObjList[1]))

		specialObjList[1] += 2

		const x: number = Rom.ReadS16(specialObjList[1])

		specialObjList[1] += 2

		const y: number = Rom.ReadS16(specialObjList[1])

		specialObjList[1] += 2

		const z: number = Rom.ReadS16(specialObjList[1])

		specialObjList[1] += 2

		local offset = 0

		while true do
			if IncludeSpecialPresetsInc.sSpecialObjectPresets[offset + 1].presetID == presetID then
				break
			end

			if IncludeSpecialPresetsInc.sSpecialObjectPresets[offset + 1].presetID == IncludeSpecialPresetsH.special_null_end then
				-- Empty in the C source.
			end

			offset += 1
		end

		const preset = IncludeSpecialPresetsInc.sSpecialObjectPresets[offset + 1]
		const model: number = U8(preset.model)
		const behavior: number? = preset.behavior
		const type_: number = U8(preset.type_)
		const defaultParam: number = U8(preset.defParam)

		if type_ == IncludeSpecialPresetsInc.SPTYPE_NO_YROT_OR_PARAMS then
			macro_special_objects.spawn_macro_abs_yrot_2params(model, behavior, x, y, z, 0, 0)
		elseif type_ == IncludeSpecialPresetsInc.SPTYPE_YROT_NO_PARAMS then
			extraParams[1] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			macro_special_objects.spawn_macro_abs_yrot_2params(model, behavior, x, y, z, extraParams[1], 0)
		elseif type_ == IncludeSpecialPresetsInc.SPTYPE_PARAMS_AND_YROT then
			extraParams[1] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			extraParams[2] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			macro_special_objects.spawn_macro_abs_yrot_2params(model, behavior, x, y, z, extraParams[1], extraParams[2])
		elseif type_ == IncludeSpecialPresetsInc.SPTYPE_UNKNOWN then
			extraParams[1] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			extraParams[2] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			extraParams[3] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			macro_special_objects.spawn_macro_abs_special(model, behavior :: number, x, y, z, extraParams[1], extraParams[2], extraParams[3])
		elseif type_ == IncludeSpecialPresetsInc.SPTYPE_DEF_PARAM_AND_YROT then
			extraParams[1] = Rom.ReadS16(specialObjList[1])
			specialObjList[1] += 2
			macro_special_objects.spawn_macro_abs_yrot_param1(model, behavior, x, y, z, extraParams[1], defaultParam)
		end
	end
end

return macro_special_objects
