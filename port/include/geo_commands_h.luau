--!strict
--!optimize 2

--[[
	Port of include/geo_commands.h.
]]

-- from include/geo_commands.h:data
const geo_commands_h = {
	BACKGROUND_OCEAN_SKY = 0,
	BACKGROUND_FLAMING_SKY = 1,
	BACKGROUND_UNDERWATER_CITY = 2,
	BACKGROUND_BELOW_CLOUDS = 3,
	BACKGROUND_SNOW_MOUNTAINS = 4,
	BACKGROUND_DESERT = 5,
	BACKGROUND_HAUNTED = 6,
	BACKGROUND_GREEN_SKY = 7,
	BACKGROUND_ABOVE_CLOUDS = 8,
	BACKGROUND_PURPLE_SKY = 9,
}

-- from include/geo_commands.h:GEO_BRANCH_AND_LINK L31-33
function geo_commands_h.GEO_BRANCH_AND_LINK(scriptTarget: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_END L39-40
function geo_commands_h.GEO_END(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BRANCH L48-50
function geo_commands_h.GEO_BRANCH(type_: number, scriptTarget: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_RETURN L56-57
function geo_commands_h.GEO_RETURN(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_OPEN_NODE L63-64
function geo_commands_h.GEO_OPEN_NODE(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_CLOSE_NODE L70-71
function geo_commands_h.GEO_CLOSE_NODE(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ASSIGN_AS_VIEW L78-79
function geo_commands_h.GEO_ASSIGN_AS_VIEW(index: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_UPDATE_NODE_FLAGS L86-87
function geo_commands_h.GEO_UPDATE_NODE_FLAGS(operation: number, flagBits: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NODE_SCREEN_AREA L98-101
function geo_commands_h.GEO_NODE_SCREEN_AREA(numEntries: number, x: number, y: number, width: number, height: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NODE_ORTHO L107-108
function geo_commands_h.GEO_NODE_ORTHO(scale: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_CAMERA_FRUSTUM L118-120
function geo_commands_h.GEO_CAMERA_FRUSTUM(fov: number, near: number, far: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_CAMERA_FRUSTUM_WITH_FUNC L121-124
function geo_commands_h.GEO_CAMERA_FRUSTUM_WITH_FUNC(fov: number, near: number, far: number, func: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NODE_START L130-131
function geo_commands_h.GEO_NODE_START(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ZBUFFER L138-139
function geo_commands_h.GEO_ZBUFFER(enable: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_RENDER_RANGE L147-149
function geo_commands_h.GEO_RENDER_RANGE(minDistance: number, maxDistance: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_SWITCH_CASE L157-159
function geo_commands_h.GEO_SWITCH_CASE(count: number, function_: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_CAMERA L173-176
function geo_commands_h.GEO_CAMERA(type_: number, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, function_: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE_ROTATE L195-197
function geo_commands_h.GEO_TRANSLATE_ROTATE(layer: number, tx: number, ty: number, tz: number, rx: number, ry: number, rz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE_ROTATE_WITH_DL L198-201
function geo_commands_h.GEO_TRANSLATE_ROTATE_WITH_DL(layer: number, tx: number, ty: number, tz: number, rx: number, ry: number, rz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE L210-212
function geo_commands_h.GEO_TRANSLATE(layer: number, tx: number, ty: number, tz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE_WITH_DL L213-216
function geo_commands_h.GEO_TRANSLATE_WITH_DL(layer: number, tx: number, ty: number, tz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATE L225-227
function geo_commands_h.GEO_ROTATE(layer: number, rx: number, ry: number, rz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATE_WITH_DL L228-231
function geo_commands_h.GEO_ROTATE_WITH_DL(layer: number, rx: number, ry: number, rz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATE_Y L238-239
function geo_commands_h.GEO_ROTATE_Y(layer: number, ry: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATE_Y_WITH_DL L240-242
function geo_commands_h.GEO_ROTATE_Y_WITH_DL(layer: number, ry: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE_NODE L254-256
function geo_commands_h.GEO_TRANSLATE_NODE(layer: number, ux: number, uy: number, uz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_TRANSLATE_NODE_WITH_DL L257-260
function geo_commands_h.GEO_TRANSLATE_NODE_WITH_DL(layer: number, ux: number, uy: number, uz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATION_NODE L272-274
function geo_commands_h.GEO_ROTATION_NODE(layer: number, ux: number, uy: number, uz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ROTATION_NODE_WITH_DL L275-278
function geo_commands_h.GEO_ROTATION_NODE_WITH_DL(layer: number, ux: number, uy: number, uz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ANIMATED_PART L288-291
function geo_commands_h.GEO_ANIMATED_PART(layer: number, x: number, y: number, z: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BILLBOARD_WITH_PARAMS L303-305
function geo_commands_h.GEO_BILLBOARD_WITH_PARAMS(layer: number, tx: number, ty: number, tz: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BILLBOARD_WITH_PARAMS_AND_DL L306-309
function geo_commands_h.GEO_BILLBOARD_WITH_PARAMS_AND_DL(layer: number, tx: number, ty: number, tz: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BILLBOARD L310-311
function geo_commands_h.GEO_BILLBOARD(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_DISPLAY_LIST L319-321
function geo_commands_h.GEO_DISPLAY_LIST(layer: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_SHADOW L330-332
function geo_commands_h.GEO_SHADOW(type_: number, solidity: number, scale: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_RENDER_OBJ L338-339
function geo_commands_h.GEO_RENDER_OBJ(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_ASM L347-349
function geo_commands_h.GEO_ASM(param: number, function_: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BACKGROUND L356-358
function geo_commands_h.GEO_BACKGROUND(background: number, function_: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_BACKGROUND_COLOR L359-360
function geo_commands_h.GEO_BACKGROUND_COLOR(background: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NOP_1A L365-367
function geo_commands_h.GEO_NOP_1A(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_COPY_VIEW L374-375
function geo_commands_h.GEO_COPY_VIEW(index: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_HELD_OBJECT L385-388
function geo_commands_h.GEO_HELD_OBJECT(param: number, ux: number, uy: number, uz: number, nodeFunc: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_SCALE L399-401
function geo_commands_h.GEO_SCALE(layer: number, scale: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_SCALE_WITH_DL L402-405
function geo_commands_h.GEO_SCALE_WITH_DL(layer: number, scale: number, displayList: number): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NOP_1E L410-412
function geo_commands_h.GEO_NOP_1E(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_NOP_1F L417-421
function geo_commands_h.GEO_NOP_1F(): number
	error("stale")
end

-- from include/geo_commands.h:GEO_CULLING_RADIUS L429-430
function geo_commands_h.GEO_CULLING_RADIUS(cullingRadius: number): number
	error("stale")
end

return geo_commands_h
