--!strict
--!optimize 2

--[[
	Port of src/goddard/dynlist_proc.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const DynlistProcH = require("./dynlist_proc_h")
const DebugUtils = require("./debug_utils")
const GdMath = require("./gd_math")
const DrawObjects = require("./draw_objects")
const Objects = require("./objects")
const Skin = require("./skin")

-- from src/goddard/dynlist_proc.c:DynObjInfo
export type DynObjInfo = {
	name: buffer, -- [8]
	obj: GdTypesH.GdObj?,
	num: number,
	unk: number,
}

-- A pointer to a global shape variable (&gShapeSilverStar): the value is read when the command runs (goddard-dynlist-macros)
export type ShapePointer = {
	Base: { [string]: unknown },
	Key: string,
}

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function U32(Value: number): number
	return bit32.band(Value, 0xFFFFFFFF)
end

-- from src/goddard/dynlist_proc.luau:scratch
const function UnsupportedMessage(Function: string, Info: DynObjInfo?, ObjectType: number): string
	const Name = (Info :: DynObjInfo).name

	return string.format("%s: Object '%s'(%x) does not support this function.", Function, buffer.readstring(Name, 0, DebugUtils.gd_strlen(Name)), ObjectType)
end

-- from src/goddard/dynlist_proc.luau:scratch
const GetDynObjInfoBuffer = buffer.create(0x100)
-- from src/goddard/dynlist_proc.luau:scratch
const WorldDistObj1Pos = { x = 0, y = 0, z = 0 } :: GdTypesH.GdVec3f
-- from src/goddard/dynlist_proc.luau:scratch
const WorldDistObj2Pos = { x = 0, y = 0, z = 0 } :: GdTypesH.GdVec3f
-- from src/goddard/dynlist_proc.luau:scratch
const WorldDistPosDiff = { x = 0, y = 0, z = 0 } :: GdTypesH.GdVec3f
-- from src/goddard/dynlist_proc.luau:scratch
const AttachToCurrObjPos = { x = 0, y = 0, z = 0 } :: GdTypesH.GdVec3f
-- from src/goddard/dynlist_proc.luau:scratch
const AttachToObjPos = { x = 0, y = 0, z = 0 } :: GdTypesH.GdVec3f
-- from src/goddard/dynlist_proc.luau:scratch
const AllocAnimdataTriangle = GdTypesH.new_GdTriangleF()

-- from src/goddard/dynlist_proc.c:data
const dynlist_proc = {
	DYNOBJ_NAME_SIZE = 8,
	DYNOBJ_LIST_SIZE = 3000,
	VTX_BUF_SIZE = 3000,
	-- from src/goddard/dynlist_proc.c:sGdDynObjList L64-64
	sGdDynObjList = nil :: { DynObjInfo }?,
	-- from src/goddard/dynlist_proc.c:sDynListCurObj L65-65
	sDynListCurObj = nil :: GdTypesH.GdObj?,
	-- from src/goddard/dynlist_proc.c:sNullBoundingBox L66-69
	sNullBoundingBox = { minX = 0.0, minY = 0.0, minZ = 0.0, maxX = 0.0, maxY = 0.0, maxZ = 0.0 },
	-- from src/goddard/dynlist_proc.c:sUseIntegerNames L70-70
	sUseIntegerNames = 0,
	-- from src/goddard/dynlist_proc.c:sIntToStringBuf L73-73
	sIntToStringBuf = "",
	-- from src/goddard/dynlist_proc.c:sNullDynObjInfo L75-75
	sNullDynObjInfo = { name = buffer.create(8), obj = nil, num = 0, unk = 0 } :: DynObjInfo,
	-- from src/goddard/dynlist_proc.c:sDynNameSuffix L76-76
	sDynNameSuffix = buffer.create(8),
	-- from src/goddard/dynlist_proc.c:sUnnamedObjCount L77-78
	sUnnamedObjCount = 0,
	-- from src/goddard/dynlist_proc.c:sLoadedDynObjs L79-79
	sLoadedDynObjs = 0,
	-- from src/goddard/dynlist_proc.c:sDynListCurInfo L80-80
	sDynListCurInfo = nil :: DynObjInfo?,
	-- from src/goddard/dynlist_proc.c:sParentObjInfo L81-81
	sParentObjInfo = nil :: DynObjInfo?,
	-- from src/goddard/dynlist_proc.c:sStashedDynObjInfo L82-82
	sStashedDynObjInfo = nil :: DynObjInfo?,
	-- from src/goddard/dynlist_proc.c:sStashedDynObj L83-83
	sStashedDynObj = nil :: GdTypesH.GdObj?,
	-- from src/goddard/dynlist_proc.c:sDynNetCount L84-84
	sDynNetCount = 0,
	-- from src/goddard/dynlist_proc.c:sDynNetNameSuffix L85-85
	sDynNetNameSuffix = "",
	-- from src/goddard/dynlist_proc.c:sStashedDynNameSuffix L86-86
	sStashedDynNameSuffix = buffer.create(256),
}

Registry.Register("src__goddard__dynlist_proc", dynlist_proc)

-- from src/goddard/dynlist_proc.c:DynObjInfo (zero-filled constructor)
function dynlist_proc.new_DynObjInfo(): DynObjInfo
	return { name = buffer.create(8), obj = nil, num = 0, unk = 0 } :: DynObjInfo
end

-- from src/goddard/dynlist_proc.c:Dyn1AsInt L47-47
function dynlist_proc.Dyn1AsInt(dyn: unknown): number
	return (dyn :: GdTypesH.DynList).w1.word
end

-- from src/goddard/dynlist_proc.c:Dyn1AsPtr L48-48
function dynlist_proc.Dyn1AsPtr(dyn: unknown): unknown
	return (dyn :: GdTypesH.DynList).w1.ptr
end

-- from src/goddard/dynlist_proc.c:Dyn1AsStr L49-49
function dynlist_proc.Dyn1AsStr(dyn: unknown): string?
	return (dyn :: GdTypesH.DynList).w1.str
end

-- from src/goddard/dynlist_proc.c:Dyn1AsName L50-50
function dynlist_proc.Dyn1AsName(dyn: unknown): unknown
	return (dyn :: GdTypesH.DynList).w1.ptr
end

-- from src/goddard/dynlist_proc.c:Dyn2AsInt L52-52
function dynlist_proc.Dyn2AsInt(dyn: unknown): number
	return (dyn :: GdTypesH.DynList).w2.word
end

-- from src/goddard/dynlist_proc.c:Dyn2AsPtr L53-53
function dynlist_proc.Dyn2AsPtr(dyn: unknown): unknown
	return (dyn :: GdTypesH.DynList).w2.ptr
end

-- from src/goddard/dynlist_proc.c:Dyn2AsStr L54-54
function dynlist_proc.Dyn2AsStr(dyn: unknown): string?
	return (dyn :: GdTypesH.DynList).w2.str
end

-- from src/goddard/dynlist_proc.c:Dyn2AsName L55-55
function dynlist_proc.Dyn2AsName(dyn: unknown): unknown
	return (dyn :: GdTypesH.DynList).w2.ptr
end

-- from src/goddard/dynlist_proc.c:DynVec L57-57
function dynlist_proc.DynVec(dyn: unknown): GdTypesH.GdVec3f
	return (dyn :: GdTypesH.DynList).vec
end

-- from src/goddard/dynlist_proc.c:DynVecX L58-58
function dynlist_proc.DynVecX(dyn: unknown): number
	return (dyn :: GdTypesH.DynList).vec.x
end

-- from src/goddard/dynlist_proc.c:DynVecY L59-59
function dynlist_proc.DynVecY(dyn: unknown): number
	return (dyn :: GdTypesH.DynList).vec.y
end

-- from src/goddard/dynlist_proc.c:DynVecZ L60-60
function dynlist_proc.DynVecZ(dyn: unknown): number
	return (dyn :: GdTypesH.DynList).vec.z
end

-- from src/goddard/dynlist_proc.c:d_stash_dynobj L128-131
function dynlist_proc.d_stash_dynobj()
	dynlist_proc.sStashedDynObjInfo = dynlist_proc.sDynListCurInfo
	dynlist_proc.sStashedDynObj = dynlist_proc.sDynListCurObj
end

-- from src/goddard/dynlist_proc.c:d_unstash_dynobj L136-139
function dynlist_proc.d_unstash_dynobj()
	dynlist_proc.sDynListCurObj = dynlist_proc.sStashedDynObj
	dynlist_proc.sDynListCurInfo = dynlist_proc.sStashedDynObjInfo
end

-- from src/goddard/dynlist_proc.c:reset_dynlist L144-153
function dynlist_proc.reset_dynlist()
	dynlist_proc.sUnnamedObjCount = 0
	dynlist_proc.sLoadedDynObjs = 0
	buffer.writeu8(dynlist_proc.sDynNameSuffix, 0, 0)
	dynlist_proc.sGdDynObjList = nil
	dynlist_proc.sDynListCurObj = nil
	dynlist_proc.sDynNetCount = 0
	dynlist_proc.sUseIntegerNames = 0
	DebugUtils.gd_strcpy(dynlist_proc.sNullDynObjInfo.name, "NullObj")
end

-- from src/goddard/dynlist_proc.c:proc_dynlist L161-337
function dynlist_proc.proc_dynlist(dylist: { GdTypesH.DynList }): GdTypesH.GdObj
	local Index = 1

	if dylist[Index].cmd ~= 0xD1D4 then
		error("proc_dynlist() not a valid dyn list")
	end

	Index += 1

	while dylist[Index].cmd ~= 58 do
		const Entry = dylist[Index]
		const cmd = Entry.cmd

		if cmd == 43 then
			dynlist_proc.d_set_name_suffix(dynlist_proc.Dyn1AsStr(Entry))
		elseif cmd == 15 then
			dynlist_proc.d_makeobj(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 46 then
			dynlist_proc.d_add_net_with_subgroup(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 48 then
			dynlist_proc.d_end_net_with_subgroup(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 47 then
			dynlist_proc.d_attach_joint_to_net(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 16 then
			dynlist_proc.d_start_group(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 17 then
			dynlist_proc.d_end_group(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 18 then
			dynlist_proc.d_addto_group(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 30 then
			dynlist_proc.d_use_obj(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 28 then
			dynlist_proc.d_link_with(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 50 then
			dynlist_proc.d_add_valptr(dynlist_proc.Dyn1AsName(Entry), U32(TruncS32(dynlist_proc.DynVecY(Entry))), dynlist_proc.Dyn2AsInt(Entry), TruncS32(dynlist_proc.DynVecX(Entry)))
		elseif cmd == 29 then
			dynlist_proc.d_link_with_ptr(dynlist_proc.Dyn1AsPtr(Entry))
		elseif cmd == 12 then
			dynlist_proc.proc_dynlist(dynlist_proc.Dyn1AsPtr(Entry) :: { GdTypesH.DynList })
		elseif cmd == 0 then
			dynlist_proc.d_use_integer_names(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 1 then
			dynlist_proc.d_set_init_pos(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 2 then
			dynlist_proc.d_set_rel_pos(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 3 then
			dynlist_proc.d_set_world_pos(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 4 then
			dynlist_proc.d_set_normal(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 5 then
			dynlist_proc.d_set_scale(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 49 then
			dynlist_proc.d_make_vertex(dynlist_proc.DynVec(Entry))
		elseif cmd == 6 then
			dynlist_proc.d_set_rotation(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 27 then
			dynlist_proc.d_center_of_gravity(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 26 then
			dynlist_proc.d_set_shape_offset(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 44 then
			dynlist_proc.d_set_parm_f(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.DynVecX(Entry))
		elseif cmd == 45 then
			dynlist_proc.d_set_parm_ptr(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.Dyn1AsPtr(Entry))
		elseif cmd == 8 then
			dynlist_proc.d_set_flags(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 9 then
			dynlist_proc.d_clear_flags(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 7 then
			dynlist_proc.d_set_obj_draw_flag(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 39 then
			dynlist_proc.d_attach(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 40 then
			dynlist_proc.d_attachto_dynid(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 41 then
			dynlist_proc.d_set_att_offset(dynlist_proc.DynVec(Entry))
		elseif cmd == 21 then
			dynlist_proc.d_set_nodegroup(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 20 then
			dynlist_proc.d_set_matgroup(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 22 then
			dynlist_proc.d_set_skinshape(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 23 then
			dynlist_proc.d_set_planegroup(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 24 then
			dynlist_proc.d_set_shapeptrptr(dynlist_proc.Dyn1AsPtr(Entry) :: ShapePointer?)
		elseif cmd == 25 then
			dynlist_proc.d_set_shapeptr(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 19 then
			dynlist_proc.d_set_type(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 13 then
			dynlist_proc.d_set_colour_num(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 10 then
			dynlist_proc.d_friction(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 11 then
			dynlist_proc.d_set_spring(dynlist_proc.DynVecX(Entry))
		elseif cmd == 33 then
			dynlist_proc.d_set_ambient(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 34 then
			dynlist_proc.d_set_diffuse(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry), dynlist_proc.DynVecZ(Entry))
		elseif cmd == 31 then
			dynlist_proc.d_set_control_type(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 32 then
			dynlist_proc.d_set_skin_weight(dynlist_proc.Dyn2AsInt(Entry), dynlist_proc.DynVecX(Entry))
		elseif cmd == 35 then
			dynlist_proc.d_set_id(dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 36 then
			dynlist_proc.d_set_material(dynlist_proc.Dyn1AsPtr(Entry), dynlist_proc.Dyn2AsInt(Entry))
		elseif cmd == 37 then
			dynlist_proc.d_map_materials(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 38 then
			dynlist_proc.d_map_vertices(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 53 then
			dynlist_proc.d_set_texture_st(dynlist_proc.DynVecX(Entry), dynlist_proc.DynVecY(Entry))
		elseif cmd == 52 then
			dynlist_proc.d_use_texture(dynlist_proc.Dyn2AsPtr(Entry))
		elseif cmd == 54 then
			dynlist_proc.d_make_netfromshapeid(dynlist_proc.Dyn1AsName(Entry))
		elseif cmd == 55 then
			dynlist_proc.d_make_netfromshape_ptrptr(dynlist_proc.Dyn1AsPtr(Entry) :: ShapePointer)
		else
			error("proc_dynlist(): unkown command")
		end

		Index += 1
	end

	return dynlist_proc.sDynListCurObj :: GdTypesH.GdObj
end

-- from src/goddard/dynlist_proc.c:d_set_name_suffix L345-355
function dynlist_proc.d_set_name_suffix(str: string?)
	if str ~= nil then
		if str == "" then
			dynlist_proc.sUnnamedObjCount += 1
			DebugUtils.gd_strcpy(dynlist_proc.sDynNameSuffix, string.format("__%d", dynlist_proc.sUnnamedObjCount))
		else
			DebugUtils.gd_strcpy(dynlist_proc.sDynNameSuffix, str)
		end
	else
		buffer.writeu8(dynlist_proc.sDynNameSuffix, 0, 0)
	end
end

-- from src/goddard/dynlist_proc.c:d_append_to_name_suffix L365-379
function dynlist_proc.d_append_to_name_suffix(str: string?)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:stash_name_suffix L384-386
function dynlist_proc.stash_name_suffix()
	DebugUtils.gd_strcpy(dynlist_proc.sStashedDynNameSuffix, dynlist_proc.sDynNameSuffix)
end

-- from src/goddard/dynlist_proc.c:unstash_name_suffix L391-393
function dynlist_proc.unstash_name_suffix()
	DebugUtils.gd_strcpy(dynlist_proc.sDynNameSuffix, dynlist_proc.sStashedDynNameSuffix)
end

-- from src/goddard/dynlist_proc.c:get_dynobj_info L401-426
function dynlist_proc.get_dynobj_info(name: unknown): DynObjInfo?
	if dynlist_proc.sLoadedDynObjs == 0 then
		return nil
	end

	if dynlist_proc.sUseIntegerNames ~= 0 then
		DebugUtils.gd_strcpy(GetDynObjInfoBuffer, string.format("N%d", S32(DynlistProcH.DynNameAsInt(name))))
	else
		DebugUtils.gd_strcpy(GetDynObjInfoBuffer, DynlistProcH.DynNameAsStr(name) :: string)
	end

	DebugUtils.gd_strcat(GetDynObjInfoBuffer, dynlist_proc.sDynNameSuffix)

	local foundDynobj: DynObjInfo? = nil
	const dynObjList = dynlist_proc.sGdDynObjList :: { DynObjInfo }

	for i = 0, dynlist_proc.sLoadedDynObjs - 1 do
		if DebugUtils.gd_str_not_equal(dynObjList[i + 1].name, GetDynObjInfoBuffer) == 0 then
			foundDynobj = dynObjList[i + 1]
			break
		end
	end

	return foundDynobj
end

-- from src/goddard/dynlist_proc.c:reset_dynamic_objs L435-445
function dynlist_proc.reset_dynamic_objs()
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_add_net_with_subgroup L451-463
function dynlist_proc.d_add_net_with_subgroup(a0: number, name: unknown)
	dynlist_proc.d_makeobj(DynlistProcH.D_NET, name)
	dynlist_proc.d_set_obj_draw_flag(GdTypesH.OBJ_INVISIBLE)
	-- this creates a string to append to the names of the objs created after this
	dynlist_proc.sDynNetCount += 1
	dynlist_proc.sDynNetNameSuffix = string.format("c%d", dynlist_proc.sDynNetCount)
	dynlist_proc.d_set_type(4)
	dynlist_proc.stash_name_suffix()
	dynlist_proc.d_set_name_suffix(dynlist_proc.sDynNetNameSuffix)
	dynlist_proc.d_start_group(name)
	dynlist_proc.unstash_name_suffix()
	dynlist_proc.d_use_obj(name)
	dynlist_proc.sParentObjInfo = dynlist_proc.sDynListCurInfo
end

-- from src/goddard/dynlist_proc.c:d_end_net_with_subgroup L468-476
function dynlist_proc.d_end_net_with_subgroup(name: unknown)
	dynlist_proc.d_use_obj(name)
	dynlist_proc.stash_name_suffix()
	dynlist_proc.d_set_name_suffix(dynlist_proc.sDynNetNameSuffix)
	dynlist_proc.d_end_group(name)
	dynlist_proc.d_set_nodegroup(name)
	dynlist_proc.unstash_name_suffix()
	dynlist_proc.sParentObjInfo = nil
end

-- from src/goddard/dynlist_proc.c:d_attach_joint_to_net L486-495
function dynlist_proc.d_attach_joint_to_net(arg0: number, name: unknown)
	dynlist_proc.d_makeobj(DynlistProcH.D_JOINT, name)
	dynlist_proc.d_set_type(3)
	dynlist_proc.d_set_shapeptrptr(nil)
	dynlist_proc.d_attach_to(0xD, (dynlist_proc.sParentObjInfo :: DynObjInfo).obj :: GdTypesH.GdObj)
	dynlist_proc.sParentObjInfo = dynlist_proc.sDynListCurInfo
end

-- from src/goddard/dynlist_proc.c:d_make_netfromshapeid L501-511
function dynlist_proc.d_make_netfromshapeid(name: unknown)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_make_netfromshape_ptrptr L518-525
function dynlist_proc.d_make_netfromshape_ptrptr(shapePtr: ShapePointer)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:add_to_dynobj_list L532-580
function dynlist_proc.add_to_dynobj_list(newobj: GdTypesH.GdObj, name: unknown)
	if dynlist_proc.sGdDynObjList == nil then
		const NewList = {} :: { DynObjInfo }

		for Index = 1, dynlist_proc.DYNOBJ_LIST_SIZE do
			NewList[Index] = dynlist_proc.new_DynObjInfo()
		end

		dynlist_proc.sGdDynObjList = NewList
	end

	local idbuf: string

	if dynlist_proc.sUseIntegerNames ~= 0 then
		idbuf = string.format("N%d", S32(DynlistProcH.DynNameAsInt(name)))
		name = nil
	else
		idbuf = string.format("U%d", S32(dynlist_proc.sLoadedDynObjs + 1))
	end

	const dynObjList = dynlist_proc.sGdDynObjList :: { DynObjInfo }
	const Entry = dynObjList[dynlist_proc.sLoadedDynObjs + 1]

	if DynlistProcH.DynNameAsStr(name) ~= nil then
		if dynlist_proc.get_dynobj_info(name) ~= nil then
			error(string.format("dMakeObj(\"%s\"): Object with same name already exists", tostring(DynlistProcH.DynNameAsStr(name))))
		end

		DebugUtils.gd_strcpy(Entry.name, DynlistProcH.DynNameAsStr(name) :: string)
	else
		DebugUtils.gd_strcpy(Entry.name, idbuf)
	end

	DebugUtils.gd_strcat(Entry.name, dynlist_proc.sDynNameSuffix)

	if DebugUtils.gd_strlen(Entry.name) > dynlist_proc.DYNOBJ_NAME_SIZE - 1 then
		error(string.format("dyn list obj name too long '%s'", buffer.readstring(Entry.name, 0, DebugUtils.gd_strlen(Entry.name))))
	end

	Entry.num = dynlist_proc.sLoadedDynObjs
	dynlist_proc.sDynListCurInfo = Entry
	Entry.obj = newobj
	dynlist_proc.sLoadedDynObjs += 1

	if dynlist_proc.sLoadedDynObjs >= dynlist_proc.DYNOBJ_LIST_SIZE then
		error("dMakeObj(): Too many dynlist objects")
	end

	dynlist_proc.sDynListCurObj = newobj
end

-- from src/goddard/dynlist_proc.c:integer_name_to_string L589-596
function dynlist_proc.integer_name_to_string(name: unknown): string?
	if DynlistProcH.DynNameAsInt(name) ~= 0 and dynlist_proc.sUseIntegerNames ~= 0 then
		dynlist_proc.sIntToStringBuf = string.format("N%d", S32(DynlistProcH.DynNameAsInt(name)))
		return dynlist_proc.sIntToStringBuf
	end

	return nil
end

-- from src/goddard/dynlist_proc.c:d_makeobj L605-688
function dynlist_proc.d_makeobj(type_: number, name: unknown): GdTypesH.GdObj?
	local dobj: GdTypesH.GdObj

	if type_ == DynlistProcH.D_CAR_DYNAMICS then
		error("dmakeobj() Car dynamics are missing!")
	elseif type_ == DynlistProcH.D_JOINT then
		dobj = Registry.Members.src__goddard__joints.make_joint(0, 0.0, 0.0, 0.0).header
	elseif type_ == DynlistProcH.D_ANOTHER_JOINT then
		dobj = Registry.Members.src__goddard__joints.make_joint(0, 0.0, 0.0, 0.0).header
	elseif type_ == DynlistProcH.D_NET then
		dobj = Skin.make_net(0, nil, nil, nil, nil).header
	elseif type_ == DynlistProcH.D_GROUP then
		dobj = Objects.make_group(0).header
	elseif type_ == DynlistProcH.D_DATA_GRP then
		dynlist_proc.d_makeobj(DynlistProcH.D_GROUP, name)

		const Group = dynlist_proc.sDynListCurObj :: GdTypesH.ObjGroup

		Group.linkType = 1

		return nil
	elseif type_ == DynlistProcH.D_CAMERA then
		dobj = Objects.make_camera(0, nil).header
	elseif type_ == DynlistProcH.D_BONE then
		dobj = Registry.Members.src__goddard__joints.make_bone(0, nil, nil, 0).header
	elseif type_ == DynlistProcH.D_PARTICLE then
		dobj = Registry.Members.src__goddard__particles.make_particle(0, 0, 0.0, 0.0, 0.0).header
	elseif type_ == DynlistProcH.D_VERTEX then
		dobj = Registry.Members.src__goddard__shape_helper.gd_make_vertex(0.0, 0.0, 0.0).header
	elseif type_ == DynlistProcH.D_FACE then
		dobj = Registry.Members.src__goddard__shape_helper.make_face_with_colour(1.0, 1.0, 1.0).header
	elseif type_ == DynlistProcH.D_PLANE then
		dobj = Objects.make_plane(0, nil).header
	elseif type_ == DynlistProcH.D_MATERIAL then
		dobj = Objects.make_material(0, nil, 0).header
	elseif type_ == DynlistProcH.D_SHAPE then
		dobj = Registry.Members.src__goddard__shape_helper.make_shape(0, dynlist_proc.integer_name_to_string(name)).header
	elseif type_ == DynlistProcH.D_GADGET then
		dobj = Registry.Members.src__goddard__old_menu.make_gadget(0, 0).header
	elseif type_ == DynlistProcH.D_LABEL then
		dobj = Registry.Members.src__goddard__old_menu.make_label(nil, nil, 8, 0, 0, 0).header
	elseif type_ == DynlistProcH.D_VIEW then
		dobj = Objects.make_view(nil, bit32.bor(GdTypesH.VIEW_2_COL_BUF, GdTypesH.VIEW_ALLOC_ZBUF, GdTypesH.VIEW_UNK_2000, GdTypesH.VIEW_UNK_4000, GdTypesH.VIEW_1_CYCLE, GdTypesH.VIEW_MOVEMENT, GdTypesH.VIEW_DRAW), 2, 0, 0, 0, 0, nil).header
	elseif type_ == DynlistProcH.D_ANIMATOR then
		dobj = Objects.make_animator().header
	elseif type_ == DynlistProcH.D_LIGHT then
		dobj = Objects.make_light(0, nil, 0).header
		Objects.addto_group(DrawObjects.gGdLightGroup :: GdTypesH.ObjGroup, dobj)
	else
		error("dMakeObj(): Unkown object type")
	end

	dynlist_proc.add_to_dynobj_list(dobj, name)

	return dobj
end

-- from src/goddard/dynlist_proc.c:d_attach L695-714
function dynlist_proc.d_attach(name: unknown)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:copy_bytes L830-837
function dynlist_proc.copy_bytes(src: { unknown }, dst: { unknown }, num: number)
	if num == 0 then
		return
	end

	for Index = 1, num do
		const Element = src[Index]

		dst[Index] = if type(Element) == "table" then table.clone(Element) else Element
	end
end

-- from src/goddard/dynlist_proc.c:alloc_animdata L844-959
function dynlist_proc.alloc_animdata(animator: GdTypesH.ObjAnimator)
	const allocMtxScale = F32(0.1)

	const animgrp = animator.animdataGrp

	if animgrp == nil then
		error("no anim group")
	end

	const animSource = (((animgrp.firstMember :: GdTypesH.ListNode).obj :: unknown) :: { GdTypesH.AnimDataInfo }?)

	if animSource == nil then
		error("no animation data")
	end

	-- count number of array-ed animation data structs
	local animCnt = 0

	while animSource[animCnt + 1].count >= 0 do
		animCnt += 1
	end

	const animDst = {} :: { GdTypesH.AnimDataInfo }

	for i = 1, animCnt do
		animDst[i] = GdTypesH.new_AnimDataInfo()
	end

	for i = 0, animCnt - 1 do
		const curAnimSrc = animSource[i + 1]
		local allocSpace: { unknown }? = nil

		if curAnimSrc.type_ ~= 0 then
			if curAnimSrc.type_ == GdTypesH.GD_ANIM_CAMERA_EYE3S_LOOKAT3S or curAnimSrc.type_ == GdTypesH.GD_ANIM_ROT3S or curAnimSrc.type_ == GdTypesH.GD_ANIM_POS3S or curAnimSrc.type_ == GdTypesH.GD_ANIM_ROT3S_POS3S or curAnimSrc.type_ == GdTypesH.GD_ANIM_SCALE3F_ROT3F_POS3F or curAnimSrc.type_ == GdTypesH.GD_ANIM_SCALE3S_POS3S_ROT3S or curAnimSrc.type_ == GdTypesH.GD_ANIM_MTX4x4 then
				-- the size of one element is not modelled: the elements are tables
			else
				error("unknown anim type for allocation")
			end

			const newSpace = {} :: { unknown }

			allocSpace = newSpace

			if curAnimSrc.type_ == GdTypesH.GD_ANIM_SCALE3S_POS3S_ROT3S then
				for dataIdx = 0, curAnimSrc.count - 1 do
					const halfarr = (curAnimSrc.data :: { { number } })[dataIdx + 1]
					const curMtxVec = GdTypesH.new_AnimMtxVec()

					newSpace[dataIdx + 1] = curMtxVec
					AllocAnimdataTriangle.p0.x = F32(F32(halfarr[1]) * allocMtxScale)
					AllocAnimdataTriangle.p0.y = F32(F32(halfarr[2]) * allocMtxScale)
					AllocAnimdataTriangle.p0.z = F32(F32(halfarr[3]) * allocMtxScale)
					AllocAnimdataTriangle.p1.x = F32(F32(halfarr[4]) * allocMtxScale)
					AllocAnimdataTriangle.p1.y = F32(F32(halfarr[5]) * allocMtxScale)
					AllocAnimdataTriangle.p1.z = F32(F32(halfarr[6]) * allocMtxScale)
					AllocAnimdataTriangle.p2.x = F32(halfarr[7])
					AllocAnimdataTriangle.p2.y = F32(halfarr[8])
					AllocAnimdataTriangle.p2.z = F32(halfarr[9])
					GdMath.gd_set_identity_mat4(curMtxVec.matrix)
					GdMath.gd_rot_mat_about_vec(curMtxVec.matrix, AllocAnimdataTriangle.p1)
					GdMath.gd_add_vec3f_to_mat4f_offset(curMtxVec.matrix, AllocAnimdataTriangle.p2)
					curMtxVec.vec.x = AllocAnimdataTriangle.p0.x
					curMtxVec.vec.y = AllocAnimdataTriangle.p0.y
					curMtxVec.vec.z = AllocAnimdataTriangle.p0.z
				end

				curAnimSrc.type_ = GdTypesH.GD_ANIM_MTX4x4F_SCALE3F
			else
				dynlist_proc.copy_bytes(curAnimSrc.data :: { unknown }, newSpace, curAnimSrc.count)
			end
		end

		animDst[i + 1].type_ = curAnimSrc.type_
		animDst[i + 1].count = curAnimSrc.count
		animDst[i + 1].data = allocSpace
	end

	(animgrp.firstMember :: GdTypesH.ListNode).obj = (animDst :: unknown) :: GdTypesH.GdObj
end

-- from src/goddard/dynlist_proc.c:chk_shapegen L970-1071
function dynlist_proc.chk_shapegen(shape: GdTypesH.ObjShape)
	const shapeMtls = shape.mtlGroup
	const shapeFaces = shape.faceGroup
	const shapeVtx = shape.vtxGroup

	if shapeVtx ~= nil and shapeFaces ~= nil then
		if bit32.btest(shapeVtx.linkType, 1) and bit32.btest(shapeFaces.linkType, 1) then
			-- These ListNodes point to special, compressed data structures
			const vtxdata = ((shapeVtx.firstMember :: GdTypesH.ListNode).obj :: unknown) :: GdTypesH.GdVtxData
			const facedata = ((shapeFaces.firstMember :: GdTypesH.ListNode).obj :: unknown) :: GdTypesH.GdFaceData

			if facedata.type_ ~= 1 then
				error("unsupported poly type")
			end

			if vtxdata.type_ ~= 1 then
				error("unsupported vertex type")
			end

			if vtxdata.count >= dynlist_proc.VTX_BUF_SIZE then
				error("shapegen() too many vertices")
			end

			const vtxbuf = {} :: { GdTypesH.ObjVertex }
			local oldObjHead = Objects.gGdObjectList :: GdTypesH.GdObj

			for i = 0, vtxdata.count - 1 do
				const vertexData = vtxdata.data[i + 1]
				const vtx: GdTypesH.ObjVertex = Registry.Members.src__goddard__shape_helper.gd_make_vertex(vertexData[1], vertexData[2], vertexData[3])

				vtx.normal.z = 0.0
				vtx.normal.y = 0.0
				vtx.normal.x = 0.0
				vtxbuf[i + 1] = vtx
			end

			const madeVtx = Objects.make_group_of_type(GdTypesH.OBJ_TYPE_VERTICES, oldObjHead, nil)

			oldObjHead = Objects.gGdObjectList :: GdTypesH.GdObj

			for i = 0, facedata.count - 1 do
				const faceData = facedata.data[i + 1]
				const face: GdTypesH.ObjFace = Registry.Members.src__goddard__shape_helper.make_face_with_colour(1.0, 1.0, 1.0)

				face.mtlId = faceData[1]
				Registry.Members.src__goddard__shape_helper.add_3_vtx_to_face(face, vtxbuf[faceData[2] + 1], vtxbuf[faceData[3] + 1], vtxbuf[faceData[4] + 1])

				const vertex1 = vtxbuf[faceData[2] + 1]

				vertex1.normal.x = F32(vertex1.normal.x + face.normal.x)
				vertex1.normal.y = F32(vertex1.normal.y + face.normal.y)
				vertex1.normal.z = F32(vertex1.normal.z + face.normal.z)

				const vertex2 = vtxbuf[faceData[3] + 1]

				vertex2.normal.x = F32(vertex2.normal.x + face.normal.x)
				vertex2.normal.y = F32(vertex2.normal.y + face.normal.y)
				vertex2.normal.z = F32(vertex2.normal.z + face.normal.z)

				const vertex3 = vtxbuf[faceData[4] + 1]

				vertex3.normal.x = F32(vertex3.normal.x + face.normal.x)
				vertex3.normal.y = F32(vertex3.normal.y + face.normal.y)
				vertex3.normal.z = F32(vertex3.normal.z + face.normal.z)
			end

			if bit32.btest(shape.flag, 0x10) then
				for i = 0, vtxdata.count - 1 do
					const vertex = vtxbuf[i + 1]

					vertex.normal.x = vertex.pos.x
					vertex.normal.y = vertex.pos.y
					vertex.normal.z = vertex.pos.z
					GdMath.gd_normalize_vec3f(vertex.normal)
				end
			else
				for i = 0, vtxdata.count - 1 do
					GdMath.gd_normalize_vec3f(vtxbuf[i + 1].normal)
				end
			end

			const madeFaces = Objects.make_group_of_type(GdTypesH.OBJ_TYPE_FACES, oldObjHead, nil)

			shape.faceGroup = madeFaces
			shape.vtxGroup = madeVtx
		end
	end

	if shapeMtls ~= nil then
		if shape.faceGroup ~= nil then
			DrawObjects.map_face_materials(shape.faceGroup, shapeMtls)
		else
			error("chk_shapegen() please set face group before mats")
		end
	end
end

-- from src/goddard/dynlist_proc.c:d_set_nodegroup L1081-1114
function dynlist_proc.d_set_nodegroup(name: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dSetNodeGroup(\"%s\"): Undefined group", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.unk1C8 = info.obj :: GdTypesH.ObjGroup
		Net.unk1D0 = info.obj :: GdTypesH.ObjGroup
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_SHAPES then
		const Shape = dynobj :: GdTypesH.ObjShape

		Shape.vtxGroup = info.obj :: GdTypesH.ObjGroup
		dynlist_proc.chk_shapegen(Shape)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		const Gadget = dynobj :: GdTypesH.ObjGadget

		Gadget.unk54 = info.obj :: GdTypesH.ObjGroup
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_ANIMATORS then
		const Animator = dynobj :: GdTypesH.ObjAnimator

		Animator.animdataGrp = info.obj :: GdTypesH.ObjGroup
		dynlist_proc.alloc_animdata(Animator)
	else
		error(UnsupportedMessage("dSetNodeGroup()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_matgroup L1119-1140
function dynlist_proc.d_set_matgroup(name: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dSetMatGroup(\"%s\"): Undefined group", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_SHAPES then
		const Shape = dynobj :: GdTypesH.ObjShape

		Shape.mtlGroup = info.obj :: GdTypesH.ObjGroup
		dynlist_proc.chk_shapegen(Shape)
	else
		error(UnsupportedMessage("dSetMatGroup()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_texture_st L1148-1162
function dynlist_proc.d_set_texture_st(s: number, t: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_use_texture L1167-1180
function dynlist_proc.d_use_texture(texture: unknown)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_skinshape L1186-1206
function dynlist_proc.d_set_skinshape(name: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dSetSkinShape(\"%s\"): Undefined object", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		(dynobj :: GdTypesH.ObjNet).skinGrp = (info.obj :: GdTypesH.ObjShape).vtxGroup
	else
		error(UnsupportedMessage("dSetSkinShape()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_map_materials L1214-1227
function dynlist_proc.d_map_materials(name: unknown)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_map_vertices L1237-1250
function dynlist_proc.d_map_vertices(name: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dMapVertices(\"%s\"): Undefined group", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	DrawObjects.map_vertices(dynobj :: GdTypesH.ObjGroup, info.obj :: GdTypesH.ObjGroup)
end

-- from src/goddard/dynlist_proc.c:d_set_planegroup L1258-1283
function dynlist_proc.d_set_planegroup(name: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dSetPlaneGroup(\"%s\"): Undefined group", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.unk1CC = info.obj :: GdTypesH.ObjGroup
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_SHAPES then
		const Shape = dynobj :: GdTypesH.ObjShape

		Shape.faceGroup = info.obj :: GdTypesH.ObjGroup
		dynlist_proc.chk_shapegen(Shape)
	else
		error(UnsupportedMessage("dSetPlaneGroup()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_shapeptrptr L1289-1324
function dynlist_proc.d_set_shapeptrptr(shpPtrptr: ShapePointer?)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	local shape: GdTypesH.ObjShape? = nil

	if shpPtrptr ~= nil then
		shape = shpPtrptr.Base[shpPtrptr.Key] :: GdTypesH.ObjShape?
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.shapePtr = shape
		Joint.colourNum = 0
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		(dynobj :: GdTypesH.ObjNet).shapePtr = shape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_BONES then
		(dynobj :: GdTypesH.ObjBone).shapePtr = shape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		(dynobj :: GdTypesH.ObjGadget).shapePtr = shape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		(dynobj :: GdTypesH.ObjParticle).shapePtr = shape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		(dynobj :: GdTypesH.ObjLight).unk9C = shape
	else
		error(UnsupportedMessage("dSetShapePtrPtr()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_shapeptr L1330-1362
function dynlist_proc.d_set_shapeptr(name: unknown)
	if name == nil or name == 0 then
		return
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dSetShapePtr(\"%s\"): Undefined object", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	const dynobj = dynlist_proc.sDynListCurObj :: GdTypesH.GdObj

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.shapePtr = info.obj :: GdTypesH.ObjShape
		Joint.colourNum = 0
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		(dynobj :: GdTypesH.ObjNet).shapePtr = info.obj :: GdTypesH.ObjShape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_BONES then
		(dynobj :: GdTypesH.ObjBone).shapePtr = info.obj :: GdTypesH.ObjShape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		(dynobj :: GdTypesH.ObjGadget).shapePtr = info.obj :: GdTypesH.ObjShape
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		(dynobj :: GdTypesH.ObjParticle).shapePtr = info.obj :: GdTypesH.ObjShape
	else
		error(UnsupportedMessage("dSetShapePtr()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_use_obj L1367-1377
function dynlist_proc.d_use_obj(name: unknown): GdTypesH.GdObj
	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dUseObj(\"%s\"): Undefined object", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	dynlist_proc.sDynListCurObj = info.obj
	dynlist_proc.sDynListCurInfo = info

	return info.obj :: GdTypesH.GdObj
end

-- from src/goddard/dynlist_proc.c:set_cur_dynobj L1384-1387
function dynlist_proc.set_cur_dynobj(obj: GdTypesH.GdObj)
	dynlist_proc.sDynListCurObj = obj
	dynlist_proc.sDynListCurInfo = dynlist_proc.sNullDynObjInfo
end

-- from src/goddard/dynlist_proc.c:d_start_group L1392-1394
function dynlist_proc.d_start_group(name: unknown)
	dynlist_proc.d_makeobj(DynlistProcH.D_GROUP, name)
end

-- from src/goddard/dynlist_proc.c:d_end_group L1400-1416
function dynlist_proc.d_end_group(name: unknown)
	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dEndGroup(\"%s\"): Undefined group", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	const dynGrp = info.obj :: GdTypesH.ObjGroup
	const dynObjList = dynlist_proc.sGdDynObjList :: { DynObjInfo }

	for i = info.num + 1, dynlist_proc.sLoadedDynObjs - 1 do
		const dynObj = dynObjList[i + 1].obj :: GdTypesH.GdObj

		if dynObj.type_ ~= GdTypesH.OBJ_TYPE_GROUPS then
			Objects.addto_group(dynGrp, dynObj)
		end
	end
end

-- from src/goddard/dynlist_proc.c:d_addto_group L1421-1432
function dynlist_proc.d_addto_group(name: unknown)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_use_integer_names L1440-1442
function dynlist_proc.d_use_integer_names(isIntBool: number)
	dynlist_proc.sUseIntegerNames = isIntBool
end

-- from src/goddard/dynlist_proc.c:d_set_init_pos L1448-1501
function dynlist_proc.d_set_init_pos(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.worldPos.x = x
		Joint.worldPos.y = y
		Joint.worldPos.z = z
		Joint.unk3C.x = x
		Joint.unk3C.y = y
		Joint.unk3C.z = z
		Joint.initPos.x = x
		Joint.initPos.y = y
		Joint.initPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.worldPos.x = x
		Net.worldPos.y = y
		Net.worldPos.z = z
		Net.initPos.x = x
		Net.initPos.y = y
		Net.initPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = dynobj :: GdTypesH.ObjParticle

		Particle.pos.x = x
		Particle.pos.y = y
		Particle.pos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		const Camera = dynobj :: GdTypesH.ObjCamera

		Camera.worldPos.x = x
		Camera.worldPos.y = y
		Camera.worldPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		const Vertex = dynobj :: GdTypesH.ObjVertex

		dynlist_proc.d_set_rel_pos(x, y, z)
		Vertex.initPos.x = x
		Vertex.initPos.y = y
		Vertex.initPos.z = z
	else
		error(UnsupportedMessage("dSetInitPos()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_velocity L1507-1529
function dynlist_proc.d_set_velocity(vel: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_velocity L1536-1558
function dynlist_proc.d_get_velocity(dst: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_torque L1566-1583
function dynlist_proc.d_set_torque(src: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_init_pos L1589-1616
function dynlist_proc.d_get_init_pos(dst: GdTypesH.GdVec3f)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		dst.x = Joint.initPos.x
		dst.y = Joint.initPos.y
		dst.z = Joint.initPos.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		dst.x = Net.initPos.x
		dst.y = Net.initPos.y
		dst.z = Net.initPos.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		const Vertex = dynobj :: GdTypesH.ObjVertex

		dst.x = Vertex.initPos.x
		dst.y = Vertex.initPos.y
		dst.z = Vertex.initPos.z
	else
		error(UnsupportedMessage("dGetInitPos()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_get_init_rot L1622-1647
function dynlist_proc.d_get_init_rot(dst: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_rel_pos L1655-1713
function dynlist_proc.d_set_rel_pos(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.unk3C.x = x
		Joint.unk3C.y = y
		Joint.unk3C.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		const Camera = dynobj :: GdTypesH.ObjCamera

		Camera.unk40.x = x
		Camera.unk40.y = y
		Camera.unk40.z = z
		Camera.zoomPositions[1].x = x
		Camera.zoomPositions[1].y = y
		Camera.zoomPositions[1].z = z
		Camera.zoomPositions[2].x = F32(x * 1.5)
		Camera.zoomPositions[2].y = F32(y * 1.5)
		Camera.zoomPositions[2].z = F32(z * 1.5)
		Camera.zoomPositions[3].x = F32(x * 2.0)
		Camera.zoomPositions[3].y = F32(y * 2.0)
		Camera.zoomPositions[3].z = F32(z * 2.0)
		Camera.maxZoomLevel = 2
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		const Vertex = dynobj :: GdTypesH.ObjVertex

		Vertex.pos.x = x
		Vertex.pos.y = y
		Vertex.pos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LABELS then
		const Label = dynobj :: GdTypesH.ObjLabel

		Label.position.x = x
		Label.position.y = y
		Label.position.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = dynobj :: GdTypesH.ObjParticle

		Particle.pos.x = x
		Particle.pos.y = y
		Particle.pos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		-- No fields are set for a net.
	else
		error(UnsupportedMessage("dSetRelPos()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_addto_rel_pos L1718-1745
function dynlist_proc.d_addto_rel_pos(src: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_rel_pos L1750-1780
function dynlist_proc.d_get_rel_pos(dst: GdTypesH.GdVec3f)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		const Vertex = Object :: GdTypesH.ObjVertex

		dst.x = Vertex.pos.x
		dst.y = Vertex.pos.y
		dst.z = Vertex.pos.z
	elseif Object.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = Object :: GdTypesH.ObjJoint

		dst.x = Joint.unk3C.x
		dst.y = Joint.unk3C.y
		dst.z = Joint.unk3C.z
	elseif Object.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		const Camera = Object :: GdTypesH.ObjCamera

		dst.x = Camera.unk40.x
		dst.y = Camera.unk40.y
		dst.z = Camera.unk40.z
	elseif Object.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = Object :: GdTypesH.ObjParticle

		dst.x = Particle.pos.x
		dst.y = Particle.pos.y
		dst.z = Particle.pos.z
	else
		error(UnsupportedMessage("dGetRelPos()", dynlist_proc.sDynListCurInfo, Object.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_get_att_objgroup L1786-1803
function dynlist_proc.d_get_att_objgroup(): GdTypesH.ObjGroup?
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		return (Object :: GdTypesH.ObjJoint).attachedObjsGrp
	elseif Object.type_ == GdTypesH.OBJ_TYPE_NETS then
		return (Object :: GdTypesH.ObjNet).attachedObjsGrp
	end

	error(UnsupportedMessage("dGetAttObjGroup()", dynlist_proc.sDynListCurInfo, Object.type_))
end

-- from src/goddard/dynlist_proc.c:d_get_att_to_obj L1808-1825
function dynlist_proc.d_get_att_to_obj(): GdTypesH.GdObj?
	error("stale")
end

-- from src/goddard/dynlist_proc.c:d_get_scale L1830-1858
function dynlist_proc.d_get_scale(dst: GdTypesH.GdVec3f)
	if dynlist_proc.sDynListCurObj == nil then
		error("proc_dynlist(): No current object")
	end

	const dynobj = dynlist_proc.sDynListCurObj :: GdTypesH.GdObj

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		dst.x = Joint.scale.x
		dst.y = Joint.scale.y
		dst.z = Joint.scale.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		dst.x = Net.scale.x
		dst.y = Net.scale.y
		dst.z = Net.scale.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		dst.x = 1.0
		dst.y = 1.0
		dst.z = 1.0
	else
		error(UnsupportedMessage("dGetScale()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_att_offset L1863-1896
function dynlist_proc.d_set_att_offset(off: GdTypesH.GdVec3f)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.attachOffset.x = off.x
		Joint.attachOffset.y = off.y
		Joint.attachOffset.z = off.z
		Joint.initPos.x = off.x
		Joint.initPos.y = off.y
		Joint.initPos.z = off.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.attachOffset.x = off.x
		Net.attachOffset.y = off.y
		Net.attachOffset.z = off.z
		Net.initPos.x = off.x
		Net.initPos.y = off.y
		Net.initPos.z = off.z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		-- No fields are set for a particle.
	else
		error(UnsupportedMessage("dSetAttOffset()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_att_to_offset L1906-1937
function dynlist_proc.d_set_att_to_offset(a: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_att_offset L1944-1966
function dynlist_proc.d_get_att_offset(dst: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_att_flags L1971-1994
function dynlist_proc.d_get_att_flags(): number
	error("stale")
end

-- from src/goddard/dynlist_proc.c:d_set_world_pos L2001-2041
function dynlist_proc.d_set_world_pos(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		const Camera = dynobj :: GdTypesH.ObjCamera

		Camera.worldPos.x = x
		Camera.worldPos.y = y
		Camera.worldPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.worldPos.x = x
		Joint.worldPos.y = y
		Joint.worldPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.worldPos.x = x
		Net.worldPos.y = y
		Net.worldPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		const Gadget = dynobj :: GdTypesH.ObjGadget

		Gadget.worldPos.x = x
		Gadget.worldPos.y = y
		Gadget.worldPos.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VIEWS then
		const View = dynobj :: GdTypesH.ObjView

		View.upperLeft.x = x
		View.upperLeft.y = y
		View.upperLeft.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		const Vertex = dynobj :: GdTypesH.ObjVertex

		Vertex.pos.x = x
		Vertex.pos.y = y
		Vertex.pos.z = z
	else
		error(UnsupportedMessage("dSetWorldPos()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_normal L2047-2069
function dynlist_proc.d_set_normal(x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_world_pos_ptr L2077-2094
function dynlist_proc.d_get_world_pos_ptr(): GdTypesH.GdVec3f
	error("stale")
end

-- from src/goddard/dynlist_proc.c:d_get_world_pos L2099-2181
function dynlist_proc.d_get_world_pos(dst: GdTypesH.GdVec3f)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	const Type = Object.type_
	local Position: GdTypesH.GdVec3f

	if Type == GdTypesH.OBJ_TYPE_VERTICES then
		Position = (Object :: GdTypesH.ObjVertex).pos
	elseif Type == GdTypesH.OBJ_TYPE_JOINTS then
		Position = (Object :: GdTypesH.ObjJoint).worldPos
	elseif Type == GdTypesH.OBJ_TYPE_NETS then
		Position = (Object :: GdTypesH.ObjNet).worldPos
	elseif Type == GdTypesH.OBJ_TYPE_PARTICLES then
		Position = (Object :: GdTypesH.ObjParticle).pos
	elseif Type == GdTypesH.OBJ_TYPE_CAMERAS then
		Position = (Object :: GdTypesH.ObjCamera).worldPos
	elseif Type == GdTypesH.OBJ_TYPE_BONES then
		Position = (Object :: GdTypesH.ObjBone).worldPos
	elseif Type == GdTypesH.OBJ_TYPE_SHAPES or Type == GdTypesH.OBJ_TYPE_LABELS then
		dst.x = 0.0
		dst.y = 0.0
		dst.z = 0.0

		return
	elseif Type == GdTypesH.OBJ_TYPE_GADGETS then
		Position = (Object :: GdTypesH.ObjGadget).worldPos
	elseif Type == GdTypesH.OBJ_TYPE_PLANES or Type == GdTypesH.OBJ_TYPE_ZONES then
		const Box = if Type == GdTypesH.OBJ_TYPE_PLANES then (Object :: GdTypesH.ObjPlane).boundingBox else (Object :: GdTypesH.ObjZone).boundingBox

		dst.x = F32(F32(Box.minX + Box.maxX) * 0.5)
		dst.y = F32(F32(Box.minY + Box.maxY) * 0.5)
		dst.z = F32(F32(Box.minZ + Box.maxZ) * 0.5)

		return
	elseif Type == GdTypesH.OBJ_TYPE_LIGHTS then
		Position = (Object :: GdTypesH.ObjLight).position
	else
		const Info = dynlist_proc.sDynListCurInfo
		const Name = if Info == nil then "" else buffer.readstring(Info.name, 0, DebugUtils.gd_strlen(Info.name))

		error(string.format("dGetWorldPos(): Object '%s'(%x) does not support this function.", Name, Type))
	end

	dst.x = Position.x
	dst.y = Position.y
	dst.z = Position.z
end

-- from src/goddard/dynlist_proc.c:d_attach_to L720-803
function dynlist_proc.d_attach_to(flag: number, obj: GdTypesH.GdObj)
	dynlist_proc.d_stash_dynobj()

	if dynlist_proc.sDynListCurObj == nil then
		error("proc_dynlist(): No current object")
	end

	local attgrp: GdTypesH.ObjGroup?

	if obj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = obj :: GdTypesH.ObjJoint

		attgrp = Joint.attachedObjsGrp
		if attgrp == nil then
			attgrp = Objects.make_group(0)
			Joint.attachedObjsGrp = attgrp
		end
	elseif obj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = obj :: GdTypesH.ObjNet

		attgrp = Net.attachedObjsGrp
		if attgrp == nil then
			attgrp = Objects.make_group(0)
			Net.attachedObjsGrp = attgrp
		end
	elseif obj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = obj :: GdTypesH.ObjParticle

		attgrp = Particle.attachedObjsGrp
		if attgrp == nil then
			attgrp = Objects.make_group(0)
			Particle.attachedObjsGrp = attgrp
		end
	elseif obj.type_ == GdTypesH.OBJ_TYPE_ANIMATORS then
		const Animator = obj :: GdTypesH.ObjAnimator

		attgrp = Animator.attachedObjsGrp
		if attgrp == nil then
			attgrp = Objects.make_group(0)
			Animator.attachedObjsGrp = attgrp
		end
	else
		error(UnsupportedMessage("dAttachTo()", dynlist_proc.sDynListCurInfo, (dynlist_proc.sDynListCurObj :: GdTypesH.GdObj).type_))
	end

	if Objects.group_contains_obj(attgrp :: GdTypesH.ObjGroup, dynlist_proc.sDynListCurObj :: GdTypesH.GdObj) ~= 0 then
		return
	end

	Objects.addto_group(attgrp :: GdTypesH.ObjGroup, dynlist_proc.sDynListCurObj :: GdTypesH.GdObj)

	if bit32.btest(flag, 9) then
		dynlist_proc.d_get_world_pos(AttachToCurrObjPos)
		dynlist_proc.set_cur_dynobj(obj)
		dynlist_proc.d_get_world_pos(AttachToObjPos)
		AttachToCurrObjPos.x = F32(AttachToCurrObjPos.x - AttachToObjPos.x)
		AttachToCurrObjPos.y = F32(AttachToCurrObjPos.y - AttachToObjPos.y)
		AttachToCurrObjPos.z = F32(AttachToCurrObjPos.z - AttachToObjPos.z)
	end

	dynlist_proc.d_unstash_dynobj()

	const dynobj = dynlist_proc.sDynListCurObj :: GdTypesH.GdObj

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.attachFlags = flag
		Joint.attachedToObj = obj
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.attachFlags = flag
		Net.attachedToObj = obj
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = dynobj :: GdTypesH.ObjParticle

		Particle.attachFlags = flag
		Particle.attachedToObj = obj
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_ANIMATORS then
		const Animator = dynobj :: GdTypesH.ObjAnimator

		Animator.attachFlags = flag
		Animator.attachedToObj = obj
	else
		error(UnsupportedMessage("dAttachTo()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end

	if bit32.btest(flag, 9) then
		dynlist_proc.d_set_att_offset(AttachToCurrObjPos)
	end
end

-- from src/goddard/dynlist_proc.c:d_attachto_dynid L809-825
function dynlist_proc.d_attachto_dynid(flag: number, name: unknown)
	if name == nil or name == 0 then
		return
	end

	if dynlist_proc.sDynListCurObj == nil then
		error("proc_dynlist(): No current object")
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dAttachTo(\"%s\"): Undefined object", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	dynlist_proc.d_attach_to(flag, info.obj :: GdTypesH.GdObj)
end

-- from src/goddard/dynlist_proc.c:d_make_vertex L2188-2191
function dynlist_proc.d_make_vertex(pos: GdTypesH.GdVec3f)
	dynlist_proc.d_makeobj(DynlistProcH.D_VERTEX, DynlistProcH.AsDynName(nil))
	dynlist_proc.d_set_init_pos(pos.x, pos.y, pos.z)
end

-- from src/goddard/dynlist_proc.c:d_set_scale L2198-2240
function dynlist_proc.d_set_scale(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const initDynobj = dynlist_proc.sDynListCurObj

	if initDynobj == nil then
		error("proc_dynlist(): No current object")
	end

	dynlist_proc.d_stash_dynobj()

	if initDynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = initDynobj :: GdTypesH.ObjJoint

		Joint.scale.x = x
		Joint.scale.y = y
		Joint.scale.z = z
	elseif initDynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = initDynobj :: GdTypesH.ObjNet

		Net.scale.x = x
		Net.scale.y = y
		Net.scale.z = z
	elseif initDynobj.type_ == GdTypesH.OBJ_TYPE_VIEWS then
		const View = initDynobj :: GdTypesH.ObjView

		View.lowerRight.x = x
		View.lowerRight.y = y
		View.lowerRight.z = z
	elseif initDynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		-- No fields are set for a particle.
	elseif initDynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		const Gadget = initDynobj :: GdTypesH.ObjGadget

		if Gadget.shapePtr ~= nil then
			Registry.Members.src__goddard__shape_helper.scale_verts_in_shape(Gadget.shapePtr, x, y, z)
		end

		Gadget.size.x = x
		Gadget.size.y = y
		Gadget.size.z = z
	elseif initDynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		-- No fields are set for a light.
	else
		error(UnsupportedMessage("dSetScale()", dynlist_proc.sDynListCurInfo, initDynobj.type_))
	end

	dynlist_proc.d_unstash_dynobj()
end

-- from src/goddard/dynlist_proc.c:d_set_rotation L2245-2269
function dynlist_proc.d_set_rotation(x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.unk6C.x = x
		Joint.unk6C.y = y
		Joint.unk6C.z = z
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.unk68.x = x
		Net.unk68.y = y
		Net.unk68.z = z
	else
		error(UnsupportedMessage("dSetRotation()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_center_of_gravity L2274-2289
function dynlist_proc.d_center_of_gravity(x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_shape_offset L2294-2309
function dynlist_proc.d_set_shape_offset(x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_add_valptr L2317-2355
function dynlist_proc.d_add_valptr(name: unknown, vflags: number, type_: number, offset: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_add_valproc L2361-2377
function dynlist_proc.d_add_valproc(proc: (GdTypesH.ObjVarVal, GdTypesH.ObjVarVal) -> GdTypesH.ObjVarVal)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_link_with_ptr L2384-2445
function dynlist_proc.d_link_with_ptr(ptr: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		(dynobj :: GdTypesH.ObjCamera).unk30 = ptr :: GdTypesH.GdObj
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GROUPS then
		const Group = dynobj :: GdTypesH.ObjGroup

		Group.firstMember = Objects.make_link_to_obj(nil, ptr :: GdTypesH.GdObj)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_BONES then
		Registry.Members.src__goddard__joints.add_joint2bone(dynobj :: GdTypesH.ObjBone, ptr :: GdTypesH.ObjJoint)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VIEWS then
		const View = dynobj :: GdTypesH.ObjView

		View.components = ptr :: GdTypesH.ObjGroup

		const viewBuffers: number = Registry.Members.src__goddard__renderer.setup_view_buffers(View.namePtr :: string, View, TruncS32(View.upperLeft.x), TruncS32(View.upperLeft.y), TruncS32(View.lowerRight.x), TruncS32(View.lowerRight.y))

		View.unk1C = viewBuffers
		Objects.reset_nets_and_gadgets(View.components :: GdTypesH.ObjGroup)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_FACES then
		const Face = dynobj :: GdTypesH.ObjFace

		if Face.vtxCount >= 4 then
			error("too many points")
		end

		Face.vertices[Face.vtxCount + 1] = ptr :: GdTypesH.ObjVertex
		Face.vtxCount += 1

		if Face.vtxCount >= 3 then
			Registry.Members.src__goddard__shape_helper.calc_face_normal(Face)
		end
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_ANIMATORS then
		const Animator = dynobj :: GdTypesH.ObjAnimator

		if Animator.animatedPartsGrp == nil then
			Animator.animatedPartsGrp = Objects.make_group(0)
		end

		Objects.addto_group(Animator.animatedPartsGrp :: GdTypesH.ObjGroup, ptr :: GdTypesH.GdObj)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LABELS then
		const Label = dynobj :: GdTypesH.ObjLabel

		Label.valptr = Objects.make_valptr(ptr :: GdTypesH.GdObj, GdTypesH.OBJ_TYPE_ALL, 0, 0)
	else
		error(UnsupportedMessage("dLinkWithPtr()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_link_with L2451-2471
function dynlist_proc.d_link_with(name: unknown)
	const origInfo = dynlist_proc.sDynListCurInfo :: DynObjInfo

	if dynlist_proc.sDynListCurObj == nil then
		error("proc_dynlist(): No current object")
	end

	if name == nil or name == 0 then
		return
	end

	const info = dynlist_proc.get_dynobj_info(name)

	if info == nil then
		error(string.format("dLinkWith(\"%s\"): Undefined object", tostring(DynlistProcH.DynNameAsStr(name))))
	end

	dynlist_proc.d_link_with_ptr(info.obj)
	dynlist_proc.set_cur_dynobj(origInfo.obj :: GdTypesH.GdObj)
	dynlist_proc.sDynListCurInfo = origInfo
end

-- from src/goddard/dynlist_proc.c:d_set_flags L2476-2513
function dynlist_proc.d_set_flags(flags: number)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		const Joint = dynobj :: GdTypesH.ObjJoint

		Joint.flags = S32(bit32.bor(Joint.flags, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_BONES then
		const Bone = dynobj :: GdTypesH.ObjBone

		Bone.unk104 = S32(bit32.bor(Bone.unk104, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		const Net = dynobj :: GdTypesH.ObjNet

		Net.flags = S32(bit32.bor(Net.flags, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		const Camera = dynobj :: GdTypesH.ObjCamera

		Camera.flags = S32(bit32.bor(Camera.flags, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VIEWS then
		const View = dynobj :: GdTypesH.ObjView

		View.flags = S32(bit32.bor(View.flags, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_SHAPES then
		const Shape = dynobj :: GdTypesH.ObjShape

		Shape.flag = S32(bit32.bor(Shape.flag, flags))
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		const Particle = dynobj :: GdTypesH.ObjParticle

		Particle.flags = bit32.bor(Particle.flags, flags)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		const Light = dynobj :: GdTypesH.ObjLight

		Light.flags = S32(bit32.bor(Light.flags, flags))
	else
		error(UnsupportedMessage("dSetFlags()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_clear_flags L2518-2543
function dynlist_proc.d_clear_flags(flags: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_parm_f L2550-2599
function dynlist_proc.d_set_parm_f(param: number, val: number)
	val = F32(val)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_SHAPES then
		if param == DynlistProcH.PARM_F_ALPHA then
			(dynobj :: GdTypesH.ObjShape).alpha = val
		else
			error(UnsupportedMessage("dSetParmf() - unsupported parm.", dynlist_proc.sDynListCurInfo, dynobj.type_))
		end
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		const Gadget = dynobj :: GdTypesH.ObjGadget

		if param == DynlistProcH.PARM_F_RANGE_MIN then
			Gadget.rangeMin = val
		elseif param == DynlistProcH.PARM_F_RANGE_MAX then
			Gadget.rangeMax = val
		elseif param == DynlistProcH.PARM_F_VARVAL then
			Gadget.varval.f = val
		else
			error(UnsupportedMessage("dSetParmf() - unsupported parm.", dynlist_proc.sDynListCurInfo, dynobj.type_))
		end
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		if param == DynlistProcH.PARM_F_ALPHA then
			(dynobj :: GdTypesH.ObjVertex).alpha = val
		else
			error(UnsupportedMessage("dSetParmf() - unsupported parm.", dynlist_proc.sDynListCurInfo, dynobj.type_))
		end
	else
		error(UnsupportedMessage("dSetParmf()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_parm_ptr L2606-2649
function dynlist_proc.d_set_parm_ptr(param: number, ptr: unknown)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_LABELS then
		if param == DynlistProcH.PARM_PTR_CHAR then
			(dynobj :: GdTypesH.ObjLabel).fmtstr = ptr :: string
		else
			error("Bad parm")
		end
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VIEWS then
		if param == DynlistProcH.PARM_PTR_CHAR then
			(dynobj :: GdTypesH.ObjView).namePtr = ptr :: string
		else
			error("Bad parm")
		end
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_FACES then
		const Face = dynobj :: GdTypesH.ObjFace

		if param == DynlistProcH.PARM_PTR_OBJ_VTX then
			-- Don't allow more than 4 vertices in a face
			if Face.vtxCount >= 4 then
				error("dsetparmp() too many points")
			end

			-- `ptr` here is a vertex index, not an actual pointer.
			-- These vertex indices later get converted to `ObjVertex` pointers when `find_thisface_verts` is called.
			Face.vertices[Face.vtxCount + 1] = ptr :: GdTypesH.ObjVertex
			Face.vtxCount += 1
		else
			error("Bad parm")
		end
	else
		error(UnsupportedMessage("dSetParmp()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_obj_draw_flag L2654-2660
function dynlist_proc.d_set_obj_draw_flag(flag: number)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	Object.drawFlags = U16(bit32.bor(Object.drawFlags, flag))
end

-- from src/goddard/dynlist_proc.c:d_set_type L2665-2695
function dynlist_proc.d_set_type(type_: number)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		(dynobj :: GdTypesH.ObjNet).netType = type_
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GADGETS then
		(dynobj :: GdTypesH.ObjGadget).ObjGadget_type = type_
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_GROUPS then
		(dynobj :: GdTypesH.ObjGroup).debugPrint = type_
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		(dynobj :: GdTypesH.ObjJoint).ObjJoint_type = type_
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_PARTICLES then
		(dynobj :: GdTypesH.ObjParticle).unk60 = type_
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_MATERIALS then
		(dynobj :: GdTypesH.ObjMaterial).ObjMaterial_type = type_
	else
		error(UnsupportedMessage("dSetType()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_id L2700-2724
function dynlist_proc.d_set_id(id: number)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_MATERIALS then
		(dynobj :: GdTypesH.ObjMaterial).id = id
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		(dynobj :: GdTypesH.ObjJoint).id = id
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_VERTICES then
		(dynobj :: GdTypesH.ObjVertex).id = S16(id)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		(dynobj :: GdTypesH.ObjLight).id = id
	else
		error(UnsupportedMessage("dSetID()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_colour_num L2731-2766
function dynlist_proc.d_set_colour_num(colornum: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_material L2771-2784
function dynlist_proc.d_set_material(a0: unknown, mtlId: number)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_FACES then
		(Object :: GdTypesH.ObjFace).mtlId = mtlId
	else
		error(UnsupportedMessage("dSetMaterial()", dynlist_proc.sDynListCurInfo, Object.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_friction L2789-2804
function dynlist_proc.d_friction(x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_spring L2809-2822
function dynlist_proc.d_set_spring(spring: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_ambient L2827-2842
function dynlist_proc.d_set_ambient(r: number, g: number, b: number)
	r = F32(r)
	g = F32(g)
	b = F32(b)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_MATERIALS then
		const Material = Object :: GdTypesH.ObjMaterial

		Material.Ka.r = r
		Material.Ka.g = g
		Material.Ka.b = b
	else
		error(UnsupportedMessage("dSetAmbient()", dynlist_proc.sDynListCurInfo, Object.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_diffuse L2847-2867
function dynlist_proc.d_set_diffuse(r: number, g: number, b: number)
	r = F32(r)
	g = F32(g)
	b = F32(b)
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_MATERIALS then
		const Material = Object :: GdTypesH.ObjMaterial

		Material.Kd.r = r
		Material.Kd.g = g
		Material.Kd.b = b
	elseif Object.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		const Light = Object :: GdTypesH.ObjLight

		Light.diffuse.r = r
		Light.diffuse.g = g
		Light.diffuse.b = b
	else
		error(UnsupportedMessage("dSetDiffuse()", dynlist_proc.sDynListCurInfo, Object.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_set_control_type L2872-2885
function dynlist_proc.d_set_control_type(ctrltype: number)
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_bounding_box L2892-2910
function dynlist_proc.d_get_bounding_box(): GdTypesH.GdBoundingBox
	error("stale")
end

-- from src/goddard/dynlist_proc.c:d_get_matrix L2915-2944
function dynlist_proc.d_get_matrix(dst: { { number } })
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_matrix L2949-2971
function dynlist_proc.d_set_matrix(src: { { number } })
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_set_rot_mtx L2977-2993
function dynlist_proc.d_set_rot_mtx(src: { { number } })
	error("stale")
	return
end

-- from src/goddard/dynlist_proc.c:d_get_rot_mtx_ptr L2998-3013
function dynlist_proc.d_get_rot_mtx_ptr(): { { number } }
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		return (Object :: GdTypesH.ObjJoint).mat128
	elseif Object.type_ == GdTypesH.OBJ_TYPE_NETS then
		return (Object :: GdTypesH.ObjNet).mat168
	end

	error(UnsupportedMessage("dGetRMatrixPtr()", dynlist_proc.sDynListCurInfo, Object.type_))
end

-- from src/goddard/dynlist_proc.c:d_set_i_matrix L3019-3043
function dynlist_proc.d_set_i_matrix(src: { { number } })
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		GdMath.gd_copy_mat4f(src, (dynobj :: GdTypesH.ObjNet).matE8)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		GdMath.gd_copy_mat4f(src, (dynobj :: GdTypesH.ObjJoint).mat168)
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_LIGHTS then
		const Light = dynobj :: GdTypesH.ObjLight

		Light.position.x = src[4][1]
		Light.position.y = src[4][2]
		Light.position.z = src[4][3]
	else
		error(UnsupportedMessage("dSetIMatrix()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

-- from src/goddard/dynlist_proc.c:d_get_matrix_ptr L3048-3071
function dynlist_proc.d_get_matrix_ptr(): { { number } }
	const Object = dynlist_proc.sDynListCurObj

	if Object == nil then
		error("proc_dynlist(): No current object")
	end

	if Object.type_ == GdTypesH.OBJ_TYPE_NETS then
		return (Object :: GdTypesH.ObjNet).mat128
	elseif Object.type_ == GdTypesH.OBJ_TYPE_CAMERAS then
		return (Object :: GdTypesH.ObjCamera).unk64
	elseif Object.type_ == GdTypesH.OBJ_TYPE_BONES then
		return (Object :: GdTypesH.ObjBone).mat70
	elseif Object.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		return (Object :: GdTypesH.ObjJoint).matE8
	end

	error(UnsupportedMessage("dGetMatrixPtr()", dynlist_proc.sDynListCurInfo, Object.type_))
end

-- from src/goddard/dynlist_proc.c:d_get_i_mtx_ptr L3077-3097
function dynlist_proc.d_get_i_mtx_ptr(): { { number } }
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_NETS then
		return (dynobj :: GdTypesH.ObjNet).matE8
	elseif dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		return (dynobj :: GdTypesH.ObjJoint).mat168
	end

	error(UnsupportedMessage("dGetIMatrixPtr()", dynlist_proc.sDynListCurInfo, dynobj.type_))
end

-- from src/goddard/dynlist_proc.c:d_calc_world_dist_btwn L3103-3118
function dynlist_proc.d_calc_world_dist_btwn(obj1: GdTypesH.GdObj, obj2: GdTypesH.GdObj): number
	dynlist_proc.set_cur_dynobj(obj1)
	dynlist_proc.d_get_world_pos(WorldDistObj1Pos)
	dynlist_proc.set_cur_dynobj(obj2)
	dynlist_proc.d_get_world_pos(WorldDistObj2Pos)
	WorldDistPosDiff.x = F32(WorldDistObj2Pos.x - WorldDistObj1Pos.x)
	WorldDistPosDiff.y = F32(WorldDistObj2Pos.y - WorldDistObj1Pos.y)
	WorldDistPosDiff.z = F32(WorldDistObj2Pos.z - WorldDistObj1Pos.z)

	return GdMath.gd_vec3f_magnitude(WorldDistPosDiff)
end

-- from src/goddard/dynlist_proc.c:d_set_skin_weight L3124-3138
function dynlist_proc.d_set_skin_weight(vtxId: number, percentWeight: number)
	percentWeight = F32(percentWeight)
	const dynobj = dynlist_proc.sDynListCurObj

	if dynobj == nil then
		error("proc_dynlist(): No current object")
	end

	if dynobj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
		Registry.Members.src__goddard__joints.set_skin_weight(dynobj :: GdTypesH.ObjJoint, vtxId, nil, percentWeight / 100.0)
	else
		error(UnsupportedMessage("dSetSkinWeight()", dynlist_proc.sDynListCurInfo, dynobj.type_))
	end
end

return dynlist_proc
