--!strict
--!optimize 2

--[[
	Port of src/game/geo_misc.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const Gbi = require("../rom/gbi")
const GeoMiscH = require("./geo_misc_h")
const RenderingGraphNode = require("./rendering_graph_node")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const LevelUpdate = require("./level_update")
const Memory = require("./memory")
const ObjectListProcessor = require("./object_list_processor")
const Rom = require("../rom/rom")
const SaveFile = require("./save_file")
const SaveFileH = require("./save_file_h")
const SegmentSymbols = require("../rom/segment_symbols")
const SrcEngineMathUtilH = require("../engine/math_util_h")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/geo_misc.c:data
const geo_misc = {
	NUM_FLYING_CARPET_VERTICES = 21,
	-- from src/game/geo_misc.c:sCurAreaTimer L33-33
	sCurAreaTimer = 1,
	-- from src/game/geo_misc.c:sPrevAreaTimer L34-34
	sPrevAreaTimer = 0,
	-- from src/game/geo_misc.c:sFlyingCarpetRippleTimer L35-35
	sFlyingCarpetRippleTimer = 0,
	-- from src/game/geo_misc.c:gFlyingCarpetState L37-37
	gFlyingCarpetState = 0,
}

Registry.Register("src__game__geo_misc", geo_misc)

-- from src/game/geo_misc.c:make_vertex L46-64
function geo_misc.make_vertex(vtx: number, n: number, x: number, y: number, z: number, tx: number, ty: number, r: number, g: number, b: number, a: number)
	x = S16(TruncS32(x))
	y = S16(TruncS32(y))
	z = S16(TruncS32(z))
	tx = S16(TruncS32(tx))
	ty = S16(TruncS32(ty))
	r = U8(TruncS32(r))
	g = U8(TruncS32(g))
	b = U8(TruncS32(b))
	a = U8(TruncS32(a))

	const at = vtx + n * 16

	Rom.WriteS16(at, x)
	Rom.WriteS16(at + 2, y)
	Rom.WriteS16(at + 4, z)
	Rom.WriteS16(at + 6, 0)
	Rom.WriteS16(at + 8, tx)
	Rom.WriteS16(at + 10, ty)
	Rom.WriteU8(at + 12, r)
	Rom.WriteU8(at + 13, g)
	Rom.WriteU8(at + 14, b)
	Rom.WriteU8(at + 15, a)
end

-- from src/game/geo_misc.c:round_float L69-76
function geo_misc.round_float(num: number): number
	num = F32(num)
	if num >= 0.0 then
		return S16(TruncS32(num + 0.5))
	else
		return S16(TruncS32(num - 0.5))
	end
end

-- from src/game/geo_misc.c:geo_exec_inside_castle_light L82-108
function geo_misc.geo_exec_inside_castle_light(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	local displayList: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const flags: number = SaveFile.save_file_get_flags()

		if LevelUpdate.gHudDisplay.stars >= 10 and not bit32.btest(flags, SaveFileH.SAVE_FLAG_HAVE_WING_CAP) then
			displayList = Memory.alloc_display_list(2 * 8) :: { unknown }

			if displayList == nil then
				return nil
			end

			const generatedNode = node :: GroupsTypesHPlus3.GraphNodeGenerated

			generatedNode.fnNode.node.flags = S16(bit32.bor(bit32.band(generatedNode.fnNode.node.flags, 0xFF), 0x500))
			-- gSPDisplayList, gSPEndDisplayList: no call (gfx-display-lists-noop)
		end
	end

	return displayList
end

-- from src/game/geo_misc.c:geo_exec_flying_carpet_timer_update L113-129
function geo_misc.geo_exec_flying_carpet_timer_update(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if callContext ~= GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		geo_misc.sFlyingCarpetRippleTimer = S16(0)
		geo_misc.sPrevAreaTimer = S16(RenderingGraphNode.gAreaUpdateCounter - 1)
		geo_misc.sCurAreaTimer = S16(RenderingGraphNode.gAreaUpdateCounter)
		geo_misc.gFlyingCarpetState = S8(GeoMiscH.FLYING_CARPET_IDLE)
	else
		geo_misc.sPrevAreaTimer = geo_misc.sCurAreaTimer
		geo_misc.sCurAreaTimer = S16(RenderingGraphNode.gAreaUpdateCounter)

		if geo_misc.sPrevAreaTimer ~= geo_misc.sCurAreaTimer then
			geo_misc.sFlyingCarpetRippleTimer = S16(geo_misc.sFlyingCarpetRippleTimer + 0x400)
		end
	end

	return nil
end

-- from src/game/geo_misc.c:geo_exec_flying_carpet_create L134-192
function geo_misc.geo_exec_flying_carpet_create(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	const generatedNode = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const sp64: number = Memory.segmented_to_virtual(SegmentSymbols.flying_carpet_static_vertex_data)
	local displayList: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const verts = Gbi.alloc_display_list(geo_misc.NUM_FLYING_CARPET_VERTICES * 16)

		displayList = Memory.alloc_display_list(7 * 8) :: { unknown }

		if verts == nil or displayList == nil then
			return nil
		end

		generatedNode.fnNode.node.flags = S16(bit32.bor(bit32.band(generatedNode.fnNode.node.flags, 0xFF), 0x100))

		for n = 0, 20 do
			const row: number = S16(n // 3)
			const col: number = S16(math.fmod(n, 3))
			const x: number = Rom.ReadS16(sp64 + 2 * (n * 4 + 0))
			const y: number = geo_misc.round_float(F32(SrcEngineMathUtilH.sins(geo_misc.sFlyingCarpetRippleTimer + bit32.lshift(row, 12) + bit32.lshift(col, 14)) * 20.0))
			const z: number = Rom.ReadS16(sp64 + 2 * (n * 4 + 1))
			const tx: number = Rom.ReadS16(sp64 + 2 * (n * 4 + 2))
			const ty: number = Rom.ReadS16(sp64 + 2 * (n * 4 + 3))

			geo_misc.make_vertex(verts, n, x, y, z, tx, ty, 0, 127, 0, 255)
		end

		-- gSPDisplayList, gSPVertex, gSPEndDisplayList: no call (gfx-display-lists-noop)
		const curGraphNodeObject = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object

		if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == curGraphNodeObject then
			geo_misc.gFlyingCarpetState = S8(GeoMiscH.FLYING_CARPET_MOVING_WITH_MARIO)
		elseif buffer.readf32(curGraphNodeObject.rawData, IncludeObjectFieldsH.oForwardVel) ~= 0.0 then
			geo_misc.gFlyingCarpetState = S8(GeoMiscH.FLYING_CARPET_MOVING_WITHOUT_MARIO)
		else
			geo_misc.gFlyingCarpetState = S8(GeoMiscH.FLYING_CARPET_IDLE)
		end
	end

	return displayList
end

-- from src/game/geo_misc.c:geo_exec_cake_end_screen L197-231
function geo_misc.geo_exec_cake_end_screen(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	const generatedNode = node :: GroupsTypesHPlus3.GraphNodeGenerated
	local displayList: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		displayList = Memory.alloc_display_list(3 * 8) :: { unknown }
		generatedNode.fnNode.node.flags = S16(bit32.bor(bit32.band(generatedNode.fnNode.node.flags, 0xFF), 0x100))
		-- gSPDisplayList, gSPEndDisplayList: no call (gfx-display-lists-noop)
	end

	return displayList
end

return geo_misc
