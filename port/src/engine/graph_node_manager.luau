--!strict
--!optimize 2

--[[
	Port of src/engine/graph_node_manager.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")
const Rom = require("../rom/rom")
const GeoLayout = require("./geo_layout")
const GraphNode = require("./graph_node")
const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const graph_node_manager = {}

Registry.Register("src__engine__graph_node_manager", graph_node_manager)

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/engine/graph_node_manager.c:next_s16_in_geo_script L8-18
function graph_node_manager.next_s16_in_geo_script(src: { number }): number
	const ret = Rom.ReadS16(src[1])

	src[1] += 2

	return ret
end

-- from src/engine/graph_node_manager.c:read_vec3s_to_vec3f L27-32
function graph_node_manager.read_vec3s_to_vec3f(dst: { number }, src: { number }): { number }
	dst[1] = graph_node_manager.next_s16_in_geo_script(src)
	dst[2] = graph_node_manager.next_s16_in_geo_script(src)
	dst[3] = graph_node_manager.next_s16_in_geo_script(src)

	return src
end

-- from src/engine/graph_node_manager.c:read_vec3s L39-44
function graph_node_manager.read_vec3s(dst: { number }, src: { number }): { number }
	dst[1] = graph_node_manager.next_s16_in_geo_script(src)
	dst[2] = graph_node_manager.next_s16_in_geo_script(src)
	dst[3] = graph_node_manager.next_s16_in_geo_script(src)

	return src
end

-- from src/engine/graph_node_manager.c:read_vec3s_angle L51-56
function graph_node_manager.read_vec3s_angle(dst: { number }, src: { number }): { number }
	dst[1] = S16((math.modf(S32(bit32.lshift(graph_node_manager.next_s16_in_geo_script(src), 15)) / 180)))
	dst[2] = S16((math.modf(S32(bit32.lshift(graph_node_manager.next_s16_in_geo_script(src), 15)) / 180)))
	dst[3] = S16((math.modf(S32(bit32.lshift(graph_node_manager.next_s16_in_geo_script(src), 15)) / 180)))

	return src
end

-- from src/engine/graph_node_manager.c:register_scene_graph_node L63-80
function graph_node_manager.register_scene_graph_node(graphNode: GroupsTypesHPlus3Types.GraphNode?)
	if graphNode ~= nil then
		GeoLayout.gCurGraphNodeList[GeoLayout.gCurGraphNodeIndex + 1] = graphNode

		if GeoLayout.gCurGraphNodeIndex == 0 then
			if GeoLayout.gCurRootGraphNode == nil then
				GeoLayout.gCurRootGraphNode = graphNode
			end
		else
			const parentNode = GeoLayout.gCurGraphNodeList[GeoLayout.gCurGraphNodeIndex] :: GroupsTypesHPlus3Types.GraphNode

			if parentNode.type_ == GroupsTypesHPlus3.GRAPH_NODE_TYPE_OBJECT_PARENT then
				(parentNode :: GroupsTypesHPlus3Types.GraphNodeObjectParent).sharedChild = graphNode
			else
				GraphNode.geo_add_child(parentNode, graphNode)
			end
		end
	end
end

return graph_node_manager
