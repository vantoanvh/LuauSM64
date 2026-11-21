--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/tox_box.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

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

-- from src/game/behaviors/tox_box.inc.c:data
const tox_box_inc = {
	FORWARD = 4, -- TOX_BOX_ACT_ROLL_FORWARD, followed by LAND
	BACKWARD = 5, -- TOX_BOX_ACT_ROLL_BACKWARD, followed by LAND
	RIGHT = 6, -- TOX_BOX_ACT_ROLL_RIGHT, followed by LAND
	LEFT = 7, -- TOX_BOX_ACT_ROLL_LEFT, followed by LAND
	LAND = 1, -- TOX_BOX_ACT_ROLL_LAND, the second item of FORWARD, BACKWARD, RIGHT and LEFT
	IDLE = 2, -- TOX_BOX_ACT_IDLE
	END = -1, -- TOX_BOX_ACT_TABLE_END
}

Registry.Register("src__game__behaviors__tox_box_inc", tox_box_inc)

-- from src/game/behaviors/tox_box.inc.c:tox_box_shake_screen L80-84
function tox_box_inc.tox_box_shake_screen()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 3000.0 then
		ObjectHelpers.cur_obj_shake_screen(GroupsTypesHPlus3.SHAKE_POS_SMALL)
	end
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_move L86-103
function tox_box_inc.tox_box_move(forwardVel: number, upVel: number, deltaPitch: number, deltaRoll: number)
	forwardVel = F32(forwardVel)
	upVel = F32(upVel)
	deltaPitch = S16(TruncS32(deltaPitch))
	deltaRoll = S16(TruncS32(deltaRoll))
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, 99.41124 * SrcEngineMathUtilH.sins(F32(F32((buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) + 1) / 8) * 32768)) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 3.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, forwardVel)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oUpVel, upVel)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) + deltaPitch)

	if S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch)) < 0 then
		deltaRoll = S16(-deltaRoll)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll) + deltaRoll)
	ObjectHelpers.cur_obj_set_pos_via_transform()

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 7 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, ObjectHelpers.cur_obj_progress_action_table())
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_UNK46)
	end
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_roll_forward L105-107
function tox_box_inc.tox_box_act_roll_forward()
	tox_box_inc.tox_box_move(64.0, 0.0, 0x800, 0)
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_roll_backward L109-111
function tox_box_inc.tox_box_act_roll_backward()
	tox_box_inc.tox_box_move(-64.0, 0.0, -0x800, 0)
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_roll_right L113-115
function tox_box_inc.tox_box_act_roll_right()
	tox_box_inc.tox_box_move(0.0, -64.0, 0, 0x800)
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_roll_left L117-119
function tox_box_inc.tox_box_act_roll_left()
	tox_box_inc.tox_box_move(0.0, 64.0, 0, -0x800)
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_roll_land L121-133
function tox_box_inc.tox_box_act_roll_land()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, 0.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
		tox_box_inc.tox_box_shake_screen()
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) + 3.0)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, ObjectHelpers.cur_obj_progress_action_table())
	end
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_idle L135-139
function tox_box_inc.tox_box_act_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, ObjectHelpers.cur_obj_progress_action_table())
	end
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_unused_idle L141-145
function tox_box_inc.tox_box_act_unused_idle()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, ObjectHelpers.cur_obj_progress_action_table())
	end
end

-- from src/game/behaviors/tox_box.inc.c:tox_box_act_init L147-150
function tox_box_inc.tox_box_act_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const actionTable = tox_box_inc.sToxBoxActionTables[buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) + 1]

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, ObjectHelpers.cur_obj_set_action_table(actionTable))
end

-- from src/game/behaviors/tox_box.inc.c:bhv_tox_box_loop L163-166
function tox_box_inc.bhv_tox_box_loop()
	ObjectHelpers.cur_obj_call_action_function(tox_box_inc.sToxBoxActions)
	SrcEngineSurfaceLoad.load_object_collision_model()
end

-- from src/game/behaviors/tox_box.inc.c:sToxBoxActionTable1 L10-18
tox_box_inc.sToxBoxActionTable1 = {
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.END,
}

-- from src/game/behaviors/tox_box.inc.c:sToxBoxActionTable2 L20-26
tox_box_inc.sToxBoxActionTable2 = {
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.END,
}

-- from src/game/behaviors/tox_box.inc.c:sToxBoxActionTable3 L28-36
tox_box_inc.sToxBoxActionTable3 = {
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.RIGHT,
	tox_box_inc.LAND,
	tox_box_inc.BACKWARD,
	tox_box_inc.LAND,
	tox_box_inc.IDLE,
	tox_box_inc.FORWARD,
	tox_box_inc.LAND,
	tox_box_inc.LEFT,
	tox_box_inc.LAND,
	tox_box_inc.END,
}

-- from src/game/behaviors/tox_box.inc.c:sToxBoxActionTables L74-78
tox_box_inc.sToxBoxActionTables = { tox_box_inc.sToxBoxActionTable1, tox_box_inc.sToxBoxActionTable2, tox_box_inc.sToxBoxActionTable3 }

-- from src/game/behaviors/tox_box.inc.c:sToxBoxActions L152-161
tox_box_inc.sToxBoxActions = {
	tox_box_inc.tox_box_act_init,
	tox_box_inc.tox_box_act_roll_land,
	tox_box_inc.tox_box_act_idle,
	tox_box_inc.tox_box_act_unused_idle,
	tox_box_inc.tox_box_act_roll_forward,
	tox_box_inc.tox_box_act_roll_backward,
	tox_box_inc.tox_box_act_roll_right,
	tox_box_inc.tox_box_act_roll_left,
}

return tox_box_inc
