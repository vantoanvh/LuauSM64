--!strict
--!optimize 2

--[[
	Port of src/goddard/dynlists/dynlist_unused.c.
]]

const DynlistProcH = require("../dynlist_proc_h")
const DynlistMacrosH = require("./dynlist_macros_h")

-- from src/goddard/dynlists/dynlist_unused.c:data
const dynlist_unused = {
	-- from src/goddard/dynlists/dynlist_unused.c:dynlist_spot_shape L7-75
	dynlist_spot_shape = {
		DynlistMacrosH.BeginList(),
		DynlistMacrosH.StartGroup("spotvg"),
		DynlistMacrosH.MakeVertex(0.0, 0.0, 0.0),
		DynlistMacrosH.MakeVertex(1.0, -1.0, 1.0),
		DynlistMacrosH.SetParamF(DynlistProcH.PARM_F_ALPHA, 0.0),
		DynlistMacrosH.MakeVertex(1.0, 1.0, 1.0),
		DynlistMacrosH.SetParamF(DynlistProcH.PARM_F_ALPHA, 0.0),
		DynlistMacrosH.MakeVertex(-1.0, 1.0, 1.0),
		DynlistMacrosH.SetParamF(DynlistProcH.PARM_F_ALPHA, 0.0),
		DynlistMacrosH.MakeVertex(-1.0, -1.0, 1.0),
		DynlistMacrosH.SetParamF(DynlistProcH.PARM_F_ALPHA, 0.0),
		DynlistMacrosH.MakeVertex(0.0, 0.0, 0.0),
		DynlistMacrosH.EndGroup("spotvg"),
		DynlistMacrosH.StartGroup("spotpg"),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.EndGroup("spotpg"),
		DynlistMacrosH.UseObj("spotpg"),
		DynlistMacrosH.MapVertices("spotvg"),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_SHAPE, "spot_sh"),
		DynlistMacrosH.SetNodeGroup("spotvg"),
		DynlistMacrosH.SetPlaneGroup("spotpg"),
		DynlistMacrosH.SetParamF(DynlistProcH.PARM_F_ALPHA, 0.1),
		DynlistMacrosH.EndList(),
	},
}

return dynlist_unused
