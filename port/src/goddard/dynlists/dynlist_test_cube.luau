--!strict
--!optimize 2

--[[
	Port of src/goddard/dynlists/dynlist_test_cube.c.
]]

const DynlistProcH = require("../dynlist_proc_h")
const DynlistMacrosH = require("./dynlist_macros_h")

-- from src/goddard/dynlists/dynlist_test_cube.c:data
const dynlist_test_cube = {
	-- from src/goddard/dynlists/dynlist_test_cube.c:dynlist_test_cube L9-82
	dynlist_test_cube = {
		DynlistMacrosH.BeginList(),
		DynlistMacrosH.StartGroup("ico1vg"),
		DynlistMacrosH.MakeVertex(-2.0, 0.0, -2.0),
		DynlistMacrosH.MakeVertex(-2.0, 0.0, 2.0),
		DynlistMacrosH.MakeVertex(2.0, 0.0, 2.0),
		DynlistMacrosH.MakeVertex(2.0, 0.0, -2.0),
		DynlistMacrosH.MakeVertex(0.0, 3.0, 0.0),
		DynlistMacrosH.MakeVertex(0.0, -3.0, 0.0),
		DynlistMacrosH.EndGroup("ico1vg"),
		DynlistMacrosH.StartGroup("ico1pg"),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 4),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 2),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 1),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_FACE, nil),
		DynlistMacrosH.SetMaterial(0),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 3),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 5),
		DynlistMacrosH.SetParamPtr(DynlistProcH.PARM_PTR_OBJ_VTX, 0),
		DynlistMacrosH.EndGroup("ico1pg"),
		DynlistMacrosH.UseObj("ico1pg"),
		DynlistMacrosH.MapVertices("ico1vg"),
		DynlistMacrosH.MakeDynObj(DynlistProcH.D_SHAPE, "ico1_sh"),
		DynlistMacrosH.SetNodeGroup("ico1vg"),
		DynlistMacrosH.SetPlaneGroup("ico1pg"),
		DynlistMacrosH.EndList(),
	},
}

return dynlist_test_cube
