--!strict
--!optimize 2

--[[
	Port of src/goddard/old_menu.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const Objects = require("./objects")

-- from src/goddard/old_menu.c:data
const old_menu = {
	-- from src/goddard/old_menu.c:sDefSettingsMenuStr L24-24
	sDefSettingsMenuStr = buffer.create(256),
	-- from src/goddard/old_menu.c:sStaticVec L25-25
	sStaticVec = { x = 0, y = 0, z = 0 },
	-- from src/goddard/old_menu.c:unusedVec L26-26
	unusedVec = { x = 0, y = 0, z = 0 },
	-- from src/goddard/old_menu.c:sCurGadgetPtr L27-27
	sCurGadgetPtr = nil :: GdTypesH.ObjGadget?,
}

Registry.Register("src__goddard__old_menu", old_menu)

-- from src/goddard/old_menu.c:get_objvalue L33-46
function old_menu.get_objvalue(dst: GdTypesH.ObjVarVal, type_: number, base: unknown, offset: number)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:Unknown8018B7A8 L49-59
function old_menu.Unknown8018B7A8(a0: unknown)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:menu_cb_default_settings L66-70
function old_menu.menu_cb_default_settings(itemId: number)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:add_item_to_default_settings_menu L75-83
function old_menu.add_item_to_default_settings_menu(group: GdTypesH.ObjGroup)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:create_gui_menu L88-114
function old_menu.create_gui_menu(grp: GdTypesH.ObjGroup): number
	error("stale")
end

-- from src/goddard/old_menu.c:make_label L117-129
function old_menu.make_label(ptr: GdTypesH.ObjValPtr?, str: string?, a2: number, x: number, y: number, z: number): GdTypesH.ObjLabel
	error("stale")
end

-- from src/goddard/old_menu.c:make_gadget L132-145
function old_menu.make_gadget(a0: number, a1: number): GdTypesH.ObjGadget
	error("stale")
end

-- from src/goddard/old_menu.c:set_objvalue L148-160
function old_menu.set_objvalue(src: GdTypesH.ObjVarVal, type_: number, base: unknown, offset: number)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:set_static_gdgt_value L163-172
function old_menu.set_static_gdgt_value(vp: GdTypesH.ObjValPtr)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:reset_gadget_default L175-180
function old_menu.reset_gadget_default(gdgt: GdTypesH.ObjGadget)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:adjust_gadget L183-219
function old_menu.adjust_gadget(gdgt: GdTypesH.ObjGadget, a1: number, a2: number)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:reset_gadget L222-249
function old_menu.reset_gadget(gdgt: GdTypesH.ObjGadget)
	error("stale")
	return
end

-- from src/goddard/old_menu.c:reset_gadgets_in_grp L252-254
function old_menu.reset_gadgets_in_grp(grp: GdTypesH.ObjGroup)
	Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_GADGETS, old_menu.reset_gadget, grp)
end

return old_menu
