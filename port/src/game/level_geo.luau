--!strict
--!optimize 2

--[[
	Port of src/game/level_geo.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const Camera = require("./camera")
const EnvfxSnow = require("./envfx_snow")
const EnvfxSnowH = require("./envfx_snow_h")
const Memory = require("./memory")
const SrcEngineGraphNode = require("../engine/graph_node")
const SrcEngineMathUtil = require("../engine/math_util")

const level_geo = {}

Registry.Register("src__game__level_geo", level_geo)

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- from src/game/level_geo.luau:scratch
const Scratch = {
	geo_envfx_main_marioPos = { 0, 0, 0 },
	geo_envfx_main_camFrom = { 0, 0, 0 },
	geo_envfx_main_camTo = { 0, 0, 0 },
}

-- from src/game/level_geo.c:geo_envfx_main L16-56
function level_geo.geo_envfx_main(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtxf: { { number } }): { unknown }?
	const marioPos = Scratch.geo_envfx_main_marioPos
	const camFrom = Scratch.geo_envfx_main_camFrom
	const camTo = Scratch.geo_envfx_main_camTo
	const camera: GroupsTypesHPlus3.GraphNodeCamera? = Registry.Members.src__game__rendering_graph_node.gCurGraphNodeCamera
	local gfx: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER and camera ~= nil then
		const execNode = node :: GroupsTypesHPlus3.GraphNodeGenerated
		const areaUpdateCounter: number = Registry.Members.src__game__rendering_graph_node.gAreaUpdateCounter

		-- params = &execNode->parameter: the s32 field read as u32
		if bit32.rshift(execNode.parameter, 16) ~= areaUpdateCounter then
			-- UNUSED sp2C = gCurGraphNodeCamera->config.camera is not read
			const snowMode = bit32.band(execNode.parameter, 0xFFFF)

			SrcEngineMathUtil.vec3f_to_vec3s(camTo, camera.focus)
			SrcEngineMathUtil.vec3f_to_vec3s(camFrom, camera.pos)
			SrcEngineMathUtil.vec3f_to_vec3s(marioPos, Camera.gPlayerCameraState[1].pos)

			const particleList = EnvfxSnow.envfx_update_particles(snowMode, marioPos, camTo, camFrom)

			if particleList ~= nil then
				const mtx = Memory.alloc_display_list(64) :: { unknown }

				gfx = Memory.alloc_display_list(16) :: { unknown }
				SrcEngineMathUtil.mtxf_to_mtx(mtx, mtxf)
				-- gSPMatrix and gSPBranchList are dropped (gfx-display-lists-noop)
				execNode.fnNode.node.flags = S16(bit32.bor(bit32.band(execNode.fnNode.node.flags, 0xFF), 0x400))
			end

			execNode.parameter = S32(bit32.bor(bit32.band(execNode.parameter, 0xFFFF), bit32.lshift(areaUpdateCounter, 16)))
		end
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_AREA_INIT then
		-- Give these arguments some dummy values. Not used in ENVFX_MODE_NONE
		SrcEngineMathUtil.vec3s_copy(camTo, SrcEngineGraphNode.gVec3sZero)
		SrcEngineMathUtil.vec3s_copy(camFrom, SrcEngineGraphNode.gVec3sZero)
		SrcEngineMathUtil.vec3s_copy(marioPos, SrcEngineGraphNode.gVec3sZero)
		EnvfxSnow.envfx_update_particles(EnvfxSnowH.ENVFX_MODE_NONE, marioPos, camTo, camFrom)
	end

	return gfx
end

-- from src/game/level_geo.c:geo_skybox_main L62-79
function level_geo.geo_skybox_main(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { { number } } }): { unknown }?
	const backgroundNode: GroupsTypesHPlus3.GraphNodeBackground = node :: GroupsTypesHPlus3.GraphNodeBackground

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_AREA_LOAD then
		backgroundNode.unused = 0
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		-- create_skybox_facing_camera is replaced (display list only): gfx stays NULL
	end

	return nil
end

return level_geo
