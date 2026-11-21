--!strict
--!optimize 2

--[[
	Port of src/game/spawn_sound.c.
]]

const Registry = require("../../groups/registry")

const SpawnSoundH = require("./spawn_sound_h")
const BehaviorIds = require("../rom/behavior_ids")
const Audio = require("../rom/audio_recorder")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const ObjectHelpers = require("./object_helpers")

const spawn_sound = {}

Registry.Register("src__game__spawn_sound", spawn_sound)

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

-- from src/game/spawn_sound.c:exec_anim_sound_state L18-45
function spawn_sound.exec_anim_sound_state(soundStates: { SpawnSoundH.SoundState })
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const stateIdx: number = buffer.readi32(o.rawData, IncludeObjectFieldsH.oSoundStateID)

	if soundStates[stateIdx + 1].playSound == IncludePRUltratypesH.TRUE then
		local animFrame = soundStates[stateIdx + 1].animFrame1

		if animFrame >= 0 then
			if ObjectHelpers.cur_obj_check_anim_frame(animFrame) ~= 0 then
				spawn_sound.cur_obj_play_sound_2(soundStates[stateIdx + 1].soundMagic)
			end
		end

		animFrame = soundStates[stateIdx + 1].animFrame2

		if animFrame >= 0 then
			if ObjectHelpers.cur_obj_check_anim_frame(animFrame) ~= 0 then
				spawn_sound.cur_obj_play_sound_2(soundStates[stateIdx + 1].soundMagic)
			end
		end
	end
end

-- from src/game/spawn_sound.c:create_sound_spawner L51-55
function spawn_sound.create_sound_spawner(soundMagic: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const obj: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object(o, 0, BehaviorIds.bhvSoundSpawner)

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oSoundEffectUnkF4, soundMagic)
end

-- from src/game/spawn_sound.c:cur_obj_play_sound_1 L62-66
function spawn_sound.cur_obj_play_sound_1(soundMagic: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		Audio.play_sound(soundMagic, o.header.gfx.cameraToObject)
	end
end

-- from src/game/spawn_sound.c:cur_obj_play_sound_2 L68-83
function spawn_sound.cur_obj_play_sound_2(soundMagic: number)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_ACTIVE) then
		Audio.play_sound(soundMagic, o.header.gfx.cameraToObject)
	end
end

-- from src/game/spawn_sound.c:calc_dist_to_volume_range_1 L96-108
function spawn_sound.calc_dist_to_volume_range_1(distance: number): number
	distance = F32(distance)
	local volume = 0

	if distance < 500 then
		volume = 127
	elseif 1500 < distance then
		volume = 0
	else
		volume = TruncS32(F32(F32(F32(F32(distance - 500) / 1000) * 64) + 60))
	end

	return volume
end

-- from src/game/spawn_sound.c:calc_dist_to_volume_range_2 L110-122
function spawn_sound.calc_dist_to_volume_range_2(distance: number): number
	distance = F32(distance)
	local volume = 0

	if distance < 1300 then
		volume = 127
	elseif 2300 < distance then
		volume = 0
	else
		volume = TruncS32(F32(F32(F32(F32(distance - 1000) / 1000) * 64) + 60))
	end

	return volume
end

return spawn_sound
