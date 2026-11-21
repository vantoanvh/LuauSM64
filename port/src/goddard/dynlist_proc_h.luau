--!strict
--!optimize 2

--[[
	Port of src/goddard/dynlist_proc.h.
]]

-- from src/goddard/dynlist_proc.h:data
const dynlist_proc_h = {
	PARM_PTR_OBJ_VTX = 1,
	PARM_PTR_CHAR = 5,
	PARM_F_ALPHA = 1,
	PARM_F_RANGE_MIN = 2,
	PARM_F_RANGE_MAX = 3,
	PARM_F_VARVAL = 6,
	D_CAR_DYNAMICS = 0,
	D_NET = 1,
	D_JOINT = 2,
	D_ANOTHER_JOINT = 3,
	D_CAMERA = 4,
	D_VERTEX = 5,
	D_FACE = 6,
	D_PLANE = 7,
	D_BONE = 8,
	D_MATERIAL = 9,
	D_SHAPE = 10,
	D_GADGET = 11,
	D_LABEL = 12,
	D_VIEW = 13,
	D_ANIMATOR = 14,
	D_DATA_GRP = 15,
	D_PARTICLE = 16,
	D_LIGHT = 17,
	D_GROUP = 18,
}

-- from src/goddard/dynlist_proc.h:DynNameAsStr L16-16
function dynlist_proc_h.DynNameAsStr(name: unknown): string?
	if type(name) == "string" then
		return name
	end

	return nil
end

-- from src/goddard/dynlist_proc.h:DynNameAsInt L17-17
function dynlist_proc_h.DynNameAsInt(name: unknown): number
	if type(name) == "number" then
		return bit32.band(name, 0xFFFFFFFF)
	end

	return 0
end

-- from src/goddard/dynlist_proc.h:AsDynName L18-18
function dynlist_proc_h.AsDynName(unk: unknown): unknown
	return unk
end

return dynlist_proc_h
