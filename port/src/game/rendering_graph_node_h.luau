--!strict
--!optimize 2

--[[
	Port of src/game/rendering_graph_node.h.
]]

-- from src/game/rendering_graph_node.h:data
const rendering_graph_node_h = {
	ANIM_TYPE_NONE = 0,
	ANIM_TYPE_TRANSLATION = 1,
	ANIM_TYPE_VERTICAL_TRANSLATION = 2,
	ANIM_TYPE_LATERAL_TRANSLATION = 3,
	ANIM_TYPE_NO_TRANSLATION = 4,
	ANIM_TYPE_ROTATION = 5,
}

return rendering_graph_node_h
