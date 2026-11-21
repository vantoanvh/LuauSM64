--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/hoot.inc.c.
]]

const Registry = require("../../../groups/registry")

const SrcEngineSurfaceCollisionH = require("../../engine/surface_collision_h")
const Camera = require("../camera")
const GameInit = require("../game_init")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeDialogIdsH = require("../../../include/dialog_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const InteractionH = require("../interaction_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const ObjectListProcessorH = require("../object_list_processor_h")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtil = require("../../engine/math_util")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceCollision = require("../../engine/surface_collision")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const MarioActionsCutscene = require("../mario_actions_cutscene")
const MarioActionsCutsceneH = require("../mario_actions_cutscene_h")

const hoot_inc = {}

Registry.Register("src__game__behaviors__hoot_inc", hoot_inc)

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

-- from src/game/behaviors/hoot_inc.luau:scratch
const Scratch = {
	hoot_floor_bounce_floorGeo = {},
	hoot_free_step_floorGeo = {},
	hoot_surface_collision_floorGeo = {},
	hoot_surface_collision_hitbox = SrcEngineSurfaceCollisionH.new_WallCollisionData(),
}

-- from src/game/behaviors/hoot.inc.c:bhv_hoot_init L3-12
function hoot_inc.bhv_hoot_init()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.cur_obj_init_animation(0)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 800.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 150.0)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oHomeZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + 300.0)
	o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))

	ObjectHelpers.cur_obj_become_intangible()
end

-- from src/game/behaviors/hoot.inc.c:hoot_find_next_floor L14-21
function hoot_inc.hoot_find_next_floor(floorGeo: { SrcEngineSurfaceCollisionH.FloorGeometry? }, arg1: number): number
	arg1 = F32(arg1)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const sp24 = F32(F32(arg1 * SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const sp1c = F32(F32(arg1 * SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const floorY = SrcEngineSurfaceCollision.find_floor_height_and_data(sp24, 10000.0, sp1c, floorGeo)

	return floorY
end

-- from src/game/behaviors/hoot.inc.c:hoot_floor_bounce L23-45
function hoot_inc.hoot_floor_bounce()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local floorY = hoot_inc.hoot_find_next_floor(Scratch.hoot_floor_bounce_floorGeo, 375.0)

	if F32(floorY + 75.0) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) - 3640.8888)))
	end

	floorY = hoot_inc.hoot_find_next_floor(Scratch.hoot_floor_bounce_floorGeo, 200.0)

	if F32(floorY + 125.0) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, S32(TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) - 7281.7776)))
	end

	floorY = hoot_inc.hoot_find_next_floor(Scratch.hoot_floor_bounce_floorGeo, 0.0)

	if F32(floorY + 125.0) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, floorY + 125.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch) < -21845.3328 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, -21845)
	end
end

-- from src/game/behaviors/hoot.inc.c:hoot_free_step L47-78
function hoot_inc.hoot_free_step(fastOscY: number, speed: number)
	fastOscY = S16(TruncS32(fastOscY))
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const pitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	const animFrame = S16(o.header.gfx.animInfo.animFrame)
	const xPrev = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	const zPrev = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.sins(pitch) * speed)
	const hSpeed = F32(SrcEngineMathUtilH.coss(pitch) * speed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, SrcEngineMathUtilH.sins(yaw) * hSpeed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, SrcEngineMathUtilH.coss(yaw) * hSpeed)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))

	if fastOscY == 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + F32(F32(SrcEngineMathUtilH.coss(TruncS32(animFrame * 3276.8)) * 50.0) / 4)))
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + F32(F32(SrcEngineMathUtilH.coss(TruncS32(animFrame * 6553.6)) * 50.0) / 4)))
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	SrcEngineSurfaceCollision.find_floor_height_and_data(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.hoot_free_step_floorGeo)

	if Scratch.hoot_free_step_floorGeo[1] == nil then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, xPrev)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, zPrev)
	end

	if animFrame == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
	end
end

-- from src/game/behaviors/hoot.inc.c:hoot_player_set_yaw L80-94
function hoot_inc.hoot_player_set_yaw()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	local stickX = GameInit.gPlayer3Controller.rawStickX
	local stickY = GameInit.gPlayer3Controller.rawStickY

	if stickX < 10 and stickX >= -9 then
		stickX = 0
	end

	if stickY < 10 and stickY >= -9 then
		stickY = 0
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) - 5 * stickX))
end

-- from src/game/behaviors/hoot.inc.c:hoot_carry_step L96-114
function hoot_inc.hoot_carry_step(speed: number, xPrev: number, zPrev: number)
	xPrev = F32(xPrev)
	zPrev = F32(zPrev)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const yaw = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw))
	const pitch = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch))
	const animFrame = S16(o.header.gfx.animInfo.animFrame)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, SrcEngineMathUtilH.sins(pitch) * speed)
	const hSpeed = F32(SrcEngineMathUtilH.coss(pitch) * speed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, SrcEngineMathUtilH.sins(yaw) * hSpeed)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, SrcEngineMathUtilH.coss(yaw) * hSpeed)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) + F32(F32(SrcEngineMathUtilH.coss(TruncS32(animFrame * 6553.6)) * 50.0) / 4)))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))

	if animFrame == 0 then
		SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_SWISH_WATER)
	end
end

-- from src/game/behaviors/hoot.inc.c:hoot_surface_collision L116-152
function hoot_inc.hoot_surface_collision(xPrev: number, yPrev: number, zPrev: number)
	xPrev = F32(xPrev)
	yPrev = F32(yPrev)
	zPrev = F32(zPrev)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const hitbox = Scratch.hoot_surface_collision_hitbox

	hitbox.x = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	hitbox.y = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	hitbox.z = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
	hitbox.offsetY = 10.0
	hitbox.radius = 50.0

	if SrcEngineSurfaceCollision.find_wall_collisions(hitbox) ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, hitbox.x)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, hitbox.y)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, hitbox.z)

		const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

		buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK7)))
	end

	const floorY = SrcEngineSurfaceCollision.find_floor_height_and_data(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), Scratch.hoot_surface_collision_floorGeo)

	if Scratch.hoot_surface_collision_floorGeo[1] == nil then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, xPrev)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, zPrev)

		return
	end

	if ObjBehaviors.absf_2(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)) > 8000.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, xPrev)
	end

	if ObjBehaviors.absf_2(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)) > 8000.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, zPrev)
	end

	if F32(floorY + 125.0) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, floorY + 125.0)
	end
end

-- from src/game/behaviors/hoot.inc.c:hoot_act_ascent L154-172
function hoot_inc.hoot_act_ascent(xPrev: number, zPrev: number)
	xPrev = F32(xPrev)
	zPrev = F32(zPrev)
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const negX = F32(0.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const negZ = F32(0.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const angleToOrigin = SrcEngineMathUtil.atan2s(negZ, negX)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), angleToOrigin, 0x500))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0xCE38)

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) >= 29 then
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WIND2)
		o.header.gfx.animInfo.animFrame = 1
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > 6500.0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOOT_ACT_CARRY)
	end

	hoot_inc.hoot_carry_step(60, xPrev, zPrev)
end

-- from src/game/behaviors/hoot.inc.c:hoot_action_loop L174-215
function hoot_inc.hoot_action_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const xPrev = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	const yPrev = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	const zPrev = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.HOOT_ACT_ASCENT then
		hoot_inc.hoot_act_ascent(xPrev, zPrev)
	elseif action == IncludeObjectConstantsH.HOOT_ACT_CARRY then
		hoot_inc.hoot_player_set_yaw()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0x71C)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < 2700.0 then
			ObjectHelpers.set_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))

			if Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, IncludeDialogIdsH.DIALOG_045) ~= 0 then
				ObjectHelpers.clear_time_stop_flags(bit32.bor(ObjectListProcessorH.TIME_STOP_ENABLED, ObjectListProcessorH.TIME_STOP_MARIO_AND_DOORS))
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.HOOT_ACT_TIRED)
			end
		end

		hoot_inc.hoot_carry_step(20, xPrev, zPrev)
	elseif action == IncludeObjectConstantsH.HOOT_ACT_TIRED then
		hoot_inc.hoot_player_set_yaw()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, 0)

		hoot_inc.hoot_carry_step(20, xPrev, zPrev)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			const marioObj = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object

			buffer.writei32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus, S32(bit32.bor(buffer.readi32(marioObj.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_MARIO_UNK7)))
		end
	end

	hoot_inc.hoot_surface_collision(xPrev, yPrev, zPrev)
end

-- from src/game/behaviors/hoot.inc.c:hoot_turn_to_home L217-226
function hoot_inc.hoot_turn_to_home()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const homeDistX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
	const homeDistY = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY))
	const homeDistZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))
	const hAngleToHome = SrcEngineMathUtil.atan2s(homeDistZ, homeDistX)
	const vAngleToHome = SrcEngineMathUtil.atan2s(F32(math.sqrt(F32(F32(homeDistX * homeDistX) + F32(homeDistZ * homeDistZ)))), -homeDistY)

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)), hAngleToHome, 0x140))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAnglePitch)), vAngleToHome, 0x140))
end

-- from src/game/behaviors/hoot.inc.c:hoot_awake_loop L228-244
function hoot_inc.hoot_awake_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus) == IncludePRUltratypesH.TRUE then
		hoot_inc.hoot_action_loop()
		ObjectHelpers.cur_obj_init_animation(1)
	else
		ObjectHelpers.cur_obj_init_animation(0)

		hoot_inc.hoot_turn_to_home()
		hoot_inc.hoot_floor_bounce()
		hoot_inc.hoot_free_step(0, 10)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 0)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
	end

	ObjBehaviors.set_object_visibility(o, 2000)
end

-- from src/game/behaviors/hoot.inc.c:bhv_hoot_loop L246-272
function hoot_inc.bhv_hoot_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const availability = buffer.readi32(o.rawData, IncludeObjectFieldsH.oHootAvailability)

	if availability == IncludeObjectConstantsH.HOOT_AVAIL_ASLEEP_IN_TREE then
		if ObjBehaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), 50) ~= 0 then
			o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHootAvailability, IncludeObjectConstantsH.HOOT_AVAIL_WANTS_TO_TALK)
		end
	elseif availability == IncludeObjectConstantsH.HOOT_AVAIL_WANTS_TO_TALK then
		hoot_inc.hoot_awake_loop()

		if MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_LOOK_UP) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK and Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, IncludeDialogIdsH.DIALOG_044) ~= 0 then
			MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)

			ObjectHelpers.cur_obj_become_tangible()

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oHootAvailability, IncludeObjectConstantsH.HOOT_AVAIL_READY_TO_FLY)
		end
	elseif availability == IncludeObjectConstantsH.HOOT_AVAIL_READY_TO_FLY then
		hoot_inc.hoot_awake_loop()
	end
end

return hoot_inc
