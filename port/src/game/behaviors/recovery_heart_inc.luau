--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/recovery_heart.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- from src/game/behaviors/recovery_heart.inc.c:data
const recovery_heart_inc = {
	-- from src/game/behaviors/recovery_heart.inc.c:sRecoveryHeartHitbox L3-13
	sRecoveryHeartHitbox = {
		interactType = 0,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 50,
		height = 50,
		hurtboxRadius = 50,
		hurtboxHeight = 50,
	},
}

Registry.Register("src__game__behaviors__recovery_heart_inc", recovery_heart_inc)

-- from src/game/behaviors/recovery_heart.inc.c:bhv_recovery_heart_loop L15-39
function recovery_heart_inc.bhv_recovery_heart_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, recovery_heart_inc.sRecoveryHeartHitbox)
	if ObjectHelpers.obj_check_if_collided_with_object(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object) ~= 0 then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinningHeartPlayedSound) == 0 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_HEART_SPIN)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinningHeartPlayedSound, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinningHeartPlayedSound) + 1)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, TruncS32(F32(200.0 * LevelUpdate.gMarioStates[1].forwardVel)) + 1000)
	else
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinningHeartPlayedSound, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) - 50)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw) < 400 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw, 400)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin, 0)
		end
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin) >= 0x10000 then
		LevelUpdate.gMarioStates[1].healCounter = U8(LevelUpdate.gMarioStates[1].healCounter + 4)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin, buffer.readi32(o.rawData, IncludeObjectFieldsH.oSpinningHeartTotalSpin) - 0x10000)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelYaw))
end

return recovery_heart_inc
