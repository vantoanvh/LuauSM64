--!strict
--!optimize 2

--[[
	Port of src/goddard/dynlists/dynlist_macros.h.
]]

const GdTypesH = require("../gd_types_h")

const dynlist_macros_h = {}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/goddard/dynlists/dynlist_macros_h.luau:scratch
const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/goddard/dynlists/dynlist_macros_h.luau:scratch
const function DynUnionOf(Value: unknown): GdTypesH.DynUnion
	if type(Value) == "number" then
		return { ptr = Value, str = nil, word = S32(Value) }
	end

	if type(Value) == "string" then
		return { ptr = Value, str = Value, word = 0 }
	end

	return { ptr = Value, str = nil, word = 0 }
end

-- from src/goddard/dynlists/dynlist_macros.h:BeginList L9-10
function dynlist_macros_h.BeginList(): GdTypesH.DynList
	return { cmd = 53716, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:EndList L15-16
function dynlist_macros_h.EndList(): GdTypesH.DynList
	return { cmd = 58, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:UseIntegerNames L22-23
function dynlist_macros_h.UseIntegerNames(enable: boolean): GdTypesH.DynList
	return { cmd = 0, w1 = DynUnionOf(nil), w2 = DynUnionOf(if enable then 1 else 0), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetInitialPosition L29-30
function dynlist_macros_h.SetInitialPosition(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 1, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetRelativePosition L36-37
function dynlist_macros_h.SetRelativePosition(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 2, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetWorldPosition L43-44
function dynlist_macros_h.SetWorldPosition(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 3, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetNormal L50-51
function dynlist_macros_h.SetNormal(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 4, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetScale L57-58
function dynlist_macros_h.SetScale(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 5, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetRotation L64-65
function dynlist_macros_h.SetRotation(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 6, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetDrawFlag L71-72
function dynlist_macros_h.SetDrawFlag(flags: number): GdTypesH.DynList
	return { cmd = 7, w1 = DynUnionOf(nil), w2 = DynUnionOf(flags), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetFlag L78-79
function dynlist_macros_h.SetFlag(flags: number): GdTypesH.DynList
	return { cmd = 8, w1 = DynUnionOf(nil), w2 = DynUnionOf(flags), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:ClearFlag L85-86
function dynlist_macros_h.ClearFlag(flags: number): GdTypesH.DynList
	return { cmd = 9, w1 = DynUnionOf(nil), w2 = DynUnionOf(flags), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetFriction L92-93
function dynlist_macros_h.SetFriction(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 10, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetSpring L99-100
function dynlist_macros_h.SetSpring(spring: number): GdTypesH.DynList
	return { cmd = 11, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(spring), y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:CallList L106-107
function dynlist_macros_h.CallList(list: unknown): GdTypesH.DynList
	return { cmd = 12, w1 = DynUnionOf(list), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetColourNum L114-115
function dynlist_macros_h.SetColourNum(colourNum: number): GdTypesH.DynList
	return { cmd = 13, w1 = DynUnionOf(nil), w2 = DynUnionOf(colourNum), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeDynObj L121-122
function dynlist_macros_h.MakeDynObj(type_: number, name: unknown): GdTypesH.DynList
	return { cmd = 15, w1 = DynUnionOf(name), w2 = DynUnionOf(type_), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:StartGroup L128-129
function dynlist_macros_h.StartGroup(grpName: unknown): GdTypesH.DynList
	return { cmd = 16, w1 = DynUnionOf(grpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:EndGroup L135-136
function dynlist_macros_h.EndGroup(grpName: unknown): GdTypesH.DynList
	return { cmd = 17, w1 = DynUnionOf(grpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:AddToGroup L142-143
function dynlist_macros_h.AddToGroup(grpName: unknown): GdTypesH.DynList
	return { cmd = 18, w1 = DynUnionOf(grpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetType L149-150
function dynlist_macros_h.SetType(type_: number): GdTypesH.DynList
	return { cmd = 19, w1 = DynUnionOf(nil), w2 = DynUnionOf(type_), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetMaterialGroup L156-157
function dynlist_macros_h.SetMaterialGroup(mtlGrpName: unknown): GdTypesH.DynList
	return { cmd = 20, w1 = DynUnionOf(mtlGrpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetNodeGroup L166-167
function dynlist_macros_h.SetNodeGroup(grpName: unknown): GdTypesH.DynList
	return { cmd = 21, w1 = DynUnionOf(grpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetSkinShape L174-175
function dynlist_macros_h.SetSkinShape(shapeName: unknown): GdTypesH.DynList
	return { cmd = 22, w1 = DynUnionOf(shapeName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetPlaneGroup L181-182
function dynlist_macros_h.SetPlaneGroup(planeGrpName: unknown): GdTypesH.DynList
	return { cmd = 23, w1 = DynUnionOf(planeGrpName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetShapePtrPtr L189-190
function dynlist_macros_h.SetShapePtrPtr(shapePtr: unknown): GdTypesH.DynList
	return { cmd = 24, w1 = DynUnionOf(shapePtr), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetShapePtr L197-198
function dynlist_macros_h.SetShapePtr(shapeName: unknown): GdTypesH.DynList
	return { cmd = 25, w1 = DynUnionOf(shapeName), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetShapeOffset L204-205
function dynlist_macros_h.SetShapeOffset(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 26, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetCenterOfGravity L211-212
function dynlist_macros_h.SetCenterOfGravity(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 27, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:LinkWith L218-219
function dynlist_macros_h.LinkWith(w1: unknown): GdTypesH.DynList
	return { cmd = 28, w1 = DynUnionOf(w1), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:LinkWithPtr L223-224
function dynlist_macros_h.LinkWithPtr(w1: unknown): GdTypesH.DynList
	return { cmd = 29, w1 = DynUnionOf(w1), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:UseObj L230-231
function dynlist_macros_h.UseObj(name: unknown): GdTypesH.DynList
	return { cmd = 30, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetControlType L238-239
function dynlist_macros_h.SetControlType(w2: number): GdTypesH.DynList
	return { cmd = 31, w1 = DynUnionOf(nil), w2 = DynUnionOf(w2), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetSkinWeight L246-247
function dynlist_macros_h.SetSkinWeight(vtxNum: number, weight: number): GdTypesH.DynList
	return { cmd = 32, w1 = DynUnionOf(nil), w2 = DynUnionOf(vtxNum), vec = { x = F32(weight), y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetAmbient L253-254
function dynlist_macros_h.SetAmbient(r: number, g: number, b: number): GdTypesH.DynList
	return { cmd = 33, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(r), y = F32(g), z = F32(b) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetDiffuse L260-261
function dynlist_macros_h.SetDiffuse(r: number, g: number, b: number): GdTypesH.DynList
	return { cmd = 34, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(r), y = F32(g), z = F32(b) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetId L267-268
function dynlist_macros_h.SetId(id: number): GdTypesH.DynList
	return { cmd = 35, w1 = DynUnionOf(nil), w2 = DynUnionOf(id), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetMaterial L274-275
function dynlist_macros_h.SetMaterial(id: number): GdTypesH.DynList
	return { cmd = 36, w1 = DynUnionOf(nil), w2 = DynUnionOf(id), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MapMaterials L282-283
function dynlist_macros_h.MapMaterials(name: unknown): GdTypesH.DynList
	return { cmd = 37, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MapVertices L291-292
function dynlist_macros_h.MapVertices(name: unknown): GdTypesH.DynList
	return { cmd = 38, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:Attach L298-299
function dynlist_macros_h.Attach(name: unknown): GdTypesH.DynList
	return { cmd = 39, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:AttachTo L305-306
function dynlist_macros_h.AttachTo(flags: number, name: unknown): GdTypesH.DynList
	return { cmd = 40, w1 = DynUnionOf(name), w2 = DynUnionOf(flags), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetAttachOffset L312-313
function dynlist_macros_h.SetAttachOffset(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 41, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetNameSuffix L319-320
function dynlist_macros_h.SetNameSuffix(suffix: unknown): GdTypesH.DynList
	return { cmd = 43, w1 = DynUnionOf(suffix), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetParamF L334-335
function dynlist_macros_h.SetParamF(param: number, value: number): GdTypesH.DynList
	return { cmd = 44, w1 = DynUnionOf(nil), w2 = DynUnionOf(param), vec = { x = F32(value), y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetParamPtr L346-347
function dynlist_macros_h.SetParamPtr(param: number, value: unknown): GdTypesH.DynList
	return { cmd = 45, w1 = DynUnionOf(value), w2 = DynUnionOf(param), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeNetWithSubGroup L352-353
function dynlist_macros_h.MakeNetWithSubGroup(name: unknown): GdTypesH.DynList
	return { cmd = 46, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeAttachedJoint L358-359
function dynlist_macros_h.MakeAttachedJoint(name: unknown): GdTypesH.DynList
	return { cmd = 47, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:EndNetWithSubGroup L364-365
function dynlist_macros_h.EndNetWithSubGroup(name: unknown): GdTypesH.DynList
	return { cmd = 48, w1 = DynUnionOf(name), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeVertex L370-371
function dynlist_macros_h.MakeVertex(x: number, y: number, z: number): GdTypesH.DynList
	return { cmd = 49, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(x), y = F32(y), z = F32(z) } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeValPtr L376-377
function dynlist_macros_h.MakeValPtr(id: unknown, flags: number, type_: number, offset: number): GdTypesH.DynList
	return { cmd = 50, w1 = DynUnionOf(id), w2 = DynUnionOf(type_), vec = { x = F32(offset), y = F32(flags), z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:UseTexture L384-385
function dynlist_macros_h.UseTexture(texture: unknown): GdTypesH.DynList
	return { cmd = 52, w1 = DynUnionOf(nil), w2 = DynUnionOf(texture), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:SetTextureST L391-392
function dynlist_macros_h.SetTextureST(s: number, t: number): GdTypesH.DynList
	return { cmd = 53, w1 = DynUnionOf(nil), w2 = DynUnionOf(nil), vec = { x = F32(s), y = F32(t), z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeNetFromShape L395-396
function dynlist_macros_h.MakeNetFromShape(shape: unknown): GdTypesH.DynList
	return { cmd = 54, w1 = DynUnionOf(shape), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

-- from src/goddard/dynlists/dynlist_macros.h:MakeNetFromShapePtrPtr L399-400
function dynlist_macros_h.MakeNetFromShapePtrPtr(w1: unknown): GdTypesH.DynList
	return { cmd = 55, w1 = DynUnionOf(w1), w2 = DynUnionOf(nil), vec = { x = 0, y = 0, z = 0 } }
end

return dynlist_macros_h
