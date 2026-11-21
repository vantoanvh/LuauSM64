--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/thi_top.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BreakParticlesInc = require("./break_particles_inc")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSm64H = require("../../../include/sm64_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const LevelUpdate = require("../level_update")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const Rom = require("../../rom/rom")
const SpawnSound = require("../spawn_sound")
const SrcEngineSurfaceLoad = require("../../engine/surface_load")
const Audio = require("../../rom/audio_recorder")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/behaviors/thi_top.inc.c:data
const thi_top_inc = {
	-- from src/game/behaviors/thi_top.inc.c:sTHITopPuffs L3-16
	sTHITopPuffs = {
		bhvParam = 0,
		count = 30,
		model = IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL,
		offsetY = 0,
		forwardVelBase = 40,
		forwardVelRange = 0,
		velYBase = 20,
		velYRange = 40,
		gravity = -4,
		dragStrength = 30,
		sizeBase = 20.0,
		sizeRange = 0.0,
	},
}

Registry.Register("src__game__behaviors__thi_top_inc", thi_top_inc)

-- from src/game/behaviors/thi_top.inc.c:bhv_thi_huge_island_top_loop L18-27
function thi_top_inc.bhv_thi_huge_island_top_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.btest(ObjectListProcessor.gTHIWaterDrained, 1) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Rom.WriteS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 18, 3000)
		end

		ObjectHelpers.cur_obj_hide()
	else
		SrcEngineSurfaceLoad.load_object_collision_model()
	end
end

-- from src/game/behaviors/thi_top.inc.c:bhv_thi_tiny_island_top_loop L29-57
function thi_top_inc.bhv_thi_tiny_island_top_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if not bit32.btest(ObjectListProcessor.gTHIWaterDrained, 1) then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) == 0 then
			if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 500.0 then
				if LevelUpdate.gMarioStates[1].action == IncludeSm64H.ACT_GROUND_POUND_LAND then
					buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
					ObjectHelpers.cur_obj_spawn_particles(thi_top_inc.sTHITopPuffs)
					BreakParticlesInc.spawn_triangle_break_particles(20, IncludeModelIdsH.MODEL_DIRT_ANIMATION, F32(0.3), 3)
					SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_GENERAL_ACTIVATE_CAP_SWITCH)
					ObjectHelpers.cur_obj_hide()
				end
			end
		else
			if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 50 then
				Rom.WriteS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 18, S16(Rom.ReadS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 18) - 1))
				SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER_DRAIN)
			else
				ObjectListProcessor.gTHIWaterDrained = S16(bit32.bor(ObjectListProcessor.gTHIWaterDrained, 1))
				Audio.play_puzzle_jingle()
				buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
			end
		end
	else
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			Rom.WriteS16((ObjectListProcessor.gEnvironmentRegions :: number) + 2 * 18, 700)
		end

		ObjectHelpers.cur_obj_hide()
	end
end

return thi_top_inc
