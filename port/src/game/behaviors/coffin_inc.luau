--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/coffin.inc.c.
]]

const Registry = require("../../../groups/registry")
const BehaviorIds = require("../../rom/behavior_ids")
const GameInit = require("../game_init")
const GroundParticlesInc = require("./ground_particles_inc")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeModelIdsH = require("../../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjBehaviors2 = require("../obj_behaviors_2")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")

-- from src/game/behaviors/coffin.inc.c:LateralPosition
export type LateralPosition = {
	x: number,
	z: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/coffin.inc.c:data
const coffin_inc = {
	-- from src/game/behaviors/coffin.inc.c:coffinRelativePos L20-23
	coffinRelativePos = {
		{ x = 412, z = -150 },
		{ x = 762, z = -150 },
		{ x = 1112, z = -150 },
		{ x = 412, z = 150 },
		{ x = 762, z = 150 },
		{ x = 1112, z = 150 },
	},
}

Registry.Register("src__game__behaviors__coffin_inc", coffin_inc)

-- from src/game/behaviors/coffin.inc.c:LateralPosition (zero-filled constructor)
function coffin_inc.new_LateralPosition(): LateralPosition
	return { x = 0, z = 0 } :: LateralPosition
end

-- from src/game/behaviors/coffin.inc.c:bhv_coffin_spawner_loop L29-58
function coffin_inc.bhv_coffin_spawner_loop()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COFFIN_SPAWNER_ACT_COFFINS_UNLOADED then
		if not bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
			for i = 0, 5 do
				const relativeZ = coffin_inc.coffinRelativePos[i + 1].z

				-- Behavior param of 0 for all even i, 1 for all odd
				const coffin: GroupsTypesHPlus3.Object? = ObjectHelpers.spawn_object_relative(S16(bit32.band(i, 1)), coffin_inc.coffinRelativePos[i + 1].x, 0, relativeZ, o, IncludeModelIdsH.MODEL_BBH_WOODEN_TOMB, BehaviorIds.bhvCoffin)

				-- Never true, game would enter a while(1) before it could.
				-- Possible a remnant of days this didn't happen.
				if coffin ~= nil then
					-- Rotate the coffin 180 degrees if its on the other side of the room.
					if relativeZ > 0 then
						buffer.writei32(coffin.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0x8000)
					end
				end
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif bit32.btest(o.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_IN_DIFFERENT_ROOM) then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.COFFIN_SPAWNER_ACT_COFFINS_UNLOADED)
	end
end

-- from src/game/behaviors/coffin.inc.c:coffin_act_idle L65-109
function coffin_inc.coffin_act_idle()
	const o = ObjectListProcessor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBhvParams2ndByte) ~= IncludeObjectConstantsH.COFFIN_BP_STATIC then
		-- Lay down if standing
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)), -2000, 200))

			-- If the coffin landed...
			if ObjBehaviors2.obj_face_pitch_approach(0, S16(-buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch))) ~= 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_ELEVATOR_MOVE_2)

				-- This bit changes the coffin's position,
				-- spawns dust there, then resets the position.
				ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_SAVE_POSITION)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) - 0x4000)
				ObjBehaviors2.obj_set_dist_from_home(200)
				GroundParticlesInc.spawn_mist_from_global()
				ObjBehaviors2.obj_perform_position_op(ObjBehaviors2.POS_OP_RESTORE_POSITION)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oTimer, 0)
		else
			-- Yaw never changes and is aligned, so yawCos = 1 or -1, yawSin = 0
			const yawCos = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
			const yawSin = SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw))

			const mario = ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object
			const dx = F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosX) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX))
			const dz = F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosZ) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ))

			const distForwards = F32(F32(dx * yawCos) + F32(dz * yawSin))
			const distSideways = F32(F32(dz * yawCos) - F32(dx * yawSin))

			-- This checks a box around the coffin and if it has been a bit since it stood up.
			-- It also checks in the case Mario is squished, so he doesn't get permanently squished.
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60
				and (buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) > 100 or LevelUpdate.gMarioState.action == IncludeSm64H.ACT_SQUISHED)
				and F32(buffer.readf32(mario.rawData, IncludeObjectFieldsH.oPosY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) < 200
				and ObjectHelpers.absf(distForwards) < 140
				and distSideways < 150
				and distSideways > -450 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_BUTTON_PRESS_2_LOWPRIO)
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.COFFIN_ACT_STAND_UP)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
		end
	end
end

-- from src/game/behaviors/coffin.inc.c:coffin_act_stand_up L114-134
function coffin_inc.coffin_act_stand_up()
	const o = ObjectListProcessor.gCurrentObject

	-- Stand up
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch) ~= 0x4000 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, ObjectHelpers.approach_s16_symmetric(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)), 1000, 200))
		ObjBehaviors2.obj_face_pitch_approach(0x4000, S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch)))
	else
		-- Stay standing
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 60 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.COFFIN_ACT_IDLE)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
			if GameInit.gGlobalTimer % 4 == 0 then
				SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_ELEVATOR_MOVE_2)
			end

			-- Shake the coffin while its standing
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 400 * (GameInit.gGlobalTimer % 2) - 200)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oAngleVelPitch, 0)
	end
end

-- from src/game/behaviors/coffin.inc.c:bhv_coffin_loop L140-159
function coffin_inc.bhv_coffin_loop()
	const o = ObjectListProcessor.gCurrentObject

	-- Gotta save those 6 object slots
	if buffer.readi32((o.parentObj :: GroupsTypesHPlus3.Object).rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COFFIN_SPAWNER_ACT_COFFINS_UNLOADED then
		ObjectHelpers.obj_mark_for_deletion(o)
	else
		-- Scale the coffin vertically? Must have thought it was too short?
		o.header.gfx.scale[2] = F32(1.1)

		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COFFIN_ACT_IDLE then
			coffin_inc.coffin_act_idle()
		elseif buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == IncludeObjectConstantsH.COFFIN_ACT_STAND_UP then
			coffin_inc.coffin_act_stand_up()
		end

		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

return coffin_inc
