--!strict
--!optimize 2

--[[
	Port of src/goddard/skin.c.
]]

const GdTypesH = require("./gd_types_h")
const GdMath = require("./gd_math")
const Registry = require("../../groups/registry")
const Rom = require("../rom/rom")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/goddard/skin.luau:scratch
const VtxLayout = { v = { ob = 0 } }

-- from src/goddard/skin.c:data
const skin = {
	-- from src/goddard/skin.c:gGdSkinNet L20-20
	gGdSkinNet = nil :: GdTypesH.ObjNet?,
	-- from src/goddard/skin.c:D_801BAAF4 L22-22
	D_801BAAF4 = 0,
	-- from src/goddard/skin.c:sNetCount L23-23
	sNetCount = 0,
}

-- from src/goddard/skin.c:compute_net_bounding_box L26-47
function skin.compute_net_bounding_box(net: GdTypesH.ObjNet)
	Registry.Members.src__goddard__objects.reset_bounding_box()

	const VertexGroup = net.unk1D0
	const NodeGroup = net.unk1C8

	if VertexGroup ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, Registry.Members.src__goddard__objects.add_obj_pos_to_bounding_box, VertexGroup)
	end

	if NodeGroup ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_ALL, Registry.Members.src__goddard__objects.add_obj_pos_to_bounding_box, NodeGroup)
	end

	const Box: GdTypesH.GdBoundingBox = Registry.Members.src__goddard__objects.gSomeBoundingBox

	Box.minX = F32(Box.minX * net.scale.x)
	Box.maxX = F32(Box.maxX * net.scale.x)
	Box.minY = F32(Box.minY * net.scale.y)
	Box.maxY = F32(Box.maxY * net.scale.y)
	Box.minZ = F32(Box.minZ * net.scale.z)
	Box.maxZ = F32(Box.maxZ * net.scale.z)
	net.boundingBox.minX = Box.minX
	net.boundingBox.minY = Box.minY
	net.boundingBox.minZ = Box.minZ
	net.boundingBox.maxX = Box.maxX
	net.boundingBox.maxY = Box.maxY
	net.boundingBox.maxZ = Box.maxZ
end

-- from src/goddard/skin.c:reset_net L50-79
function skin.reset_net(net: GdTypesH.ObjNet)
	net.worldPos.x = net.initPos.x
	net.worldPos.y = net.initPos.y
	net.worldPos.z = net.initPos.z
	net.velocity.x = 0.0
	net.velocity.y = 0.0
	net.velocity.z = 0.0
	net.torque.x = 0.0
	net.torque.y = 0.0
	net.torque.z = 0.0

	skin.compute_net_bounding_box(net)
	GdMath.gd_print_vec("net scale: ", net.scale)
	GdMath.gd_print_bounding_box("net box: ", net.boundingBox)

	skin.gGdSkinNet = net
	skin.D_801BAAF4 = 0

	GdMath.gd_set_identity_mat4(net.mat168)
	GdMath.gd_set_identity_mat4(net.matE8)
	GdMath.gd_rot_mat_about_vec(net.matE8, net.unk68)
	GdMath.gd_add_vec3f_to_mat4f_offset(net.matE8, net.worldPos)
	GdMath.gd_copy_mat4f(net.matE8, net.mat128)

	const grp = net.unk1C8

	if grp ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_JOINTS, Registry.Members.src__goddard__joints.reset_joint, grp)
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_JOINTS, Registry.Members.src__goddard__joints.func_80191220, grp)
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_BONES, Registry.Members.src__goddard__joints.func_8018FB58, grp)
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_BONES, Registry.Members.src__goddard__joints.func_8018FA68, grp)
	end
end

-- from src/goddard/skin.c:func_80192294 L82-90
function skin.func_80192294(net: GdTypesH.ObjNet)
	if net.attachedToObj == nil then
		Registry.Members.src__goddard__objects.transform_child_objects_recursive(net.header, nil)
	end
end

-- from src/goddard/skin.c:func_801922FC L93-108
function skin.func_801922FC(net: GdTypesH.ObjNet)
	skin.gGdSkinNet = net

	if net.netType == 4 then
		const Shape = net.shapePtr

		if Shape ~= nil then
			Registry.Members.src__goddard__objects.D_801B9E38 = { net.mat128 }
			Registry.Members.src__goddard__skin_movement.scale_verts(Shape.vtxGroup :: GdTypesH.ObjGroup)
		end

		const group = net.unk1C8

		if group ~= nil then
			Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_JOINTS, Registry.Members.src__goddard__skin_movement.reset_joint_weights, group)
		end
	end
end

-- from src/goddard/skin.c:make_net L111-133
function skin.make_net(a0: number, shapedata: GdTypesH.ObjShape?, a2: GdTypesH.ObjGroup?, a3: GdTypesH.ObjGroup?, a4: GdTypesH.ObjGroup?): GdTypesH.ObjNet
	const net: GdTypesH.ObjNet = Registry.Members.src__goddard__objects.make_object(GdTypesH.OBJ_TYPE_NETS)

	GdMath.gd_set_identity_mat4(net.mat128)

	net.initPos.x = 0.0
	net.initPos.y = 0.0
	net.initPos.z = 0.0
	skin.sNetCount = S32(skin.sNetCount + 1)
	net.id = skin.sNetCount
	net.scale.x = 1.0
	net.scale.y = 1.0
	net.scale.z = 1.0
	net.shapePtr = shapedata
	net.unk1C8 = a2
	net.unk1CC = a3
	net.unk1D0 = a4
	net.netType = 0
	net.ctrlType = 0
	net.unk21C = nil
	net.unk3C = 1
	net.colourNum = 0
	net.skinGrp = nil

	skin.reset_net(net)

	return net
end

-- from src/goddard/skin.c:func_80192528 L136-160
function skin.func_80192528(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/skin.c:collision_something_801926A4 L163-199
function skin.collision_something_801926A4(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/skin.c:func_80192AD0 L202-229
function skin.func_80192AD0(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/skin.c:move_bonesnet L232-242
function skin.move_bonesnet(net: GdTypesH.ObjNet)
	const Matrix: { { number } } = Registry.Members.src__goddard__objects.D_801B9DC8

	GdMath.gd_set_identity_mat4(Matrix)

	const sp24 = net.unk1C8

	if sp24 ~= nil then
		Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_JOINTS, Registry.Members.src__goddard__joints.func_801913C0, sp24)
	end
end

-- from src/goddard/skin.c:func_80192CCC L245-298
function skin.func_80192CCC(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/skin.c:convert_gd_verts_to_Vn L301-346
function skin.convert_gd_verts_to_Vn(grp: GdTypesH.ObjGroup)
	error("stale")
	return
end

-- from src/goddard/skin.c:convert_gd_verts_to_Vtx L349-382
function skin.convert_gd_verts_to_Vtx(grp: GdTypesH.ObjGroup)
	local link = grp.firstMember

	while link ~= nil do
		const vtx = link.obj :: GdTypesH.ObjVertex
		const x = S16(TruncS32(vtx.pos.x))
		const y = S16(TruncS32(vtx.pos.y))
		const z = S16(TruncS32(vtx.pos.z))
		local vtxlink = vtx.gbiVerts

		while vtxlink ~= nil do
			-- vtxcoords = vtxlink->data->v.ob: the Vtx is a Memory block, ob[3] are its first three s16
			const vtxcoords = (vtxlink.data :: number) + VtxLayout.v.ob

			Rom.WriteS16(vtxcoords, x)
			Rom.WriteS16(vtxcoords + 2, y)
			Rom.WriteS16(vtxcoords + 4, z)

			vtxlink = vtxlink.prev
		end

		link = link.next
	end
end

-- from src/goddard/skin.c:convert_net_verts L385-399
function skin.convert_net_verts(net: GdTypesH.ObjNet)
	const Shape = net.shapePtr

	if Shape ~= nil then
		if Shape.unk30 ~= 0 then
			skin.convert_gd_verts_to_Vn(Shape.vtxGroup :: GdTypesH.ObjGroup)
		end
	end

	if net.netType == 2 then
		if Shape ~= nil then
			skin.convert_gd_verts_to_Vtx(Shape.scaledVtxGroup :: GdTypesH.ObjGroup)
		end
	end
end

-- from src/goddard/skin.c:move_joints_in_net L402-420
function skin.move_joints_in_net(net: GdTypesH.ObjNet)
	const grp = net.unk1C8

	if grp ~= nil then
		local link = grp.firstMember

		while link ~= nil do
			const obj = link.obj :: GdTypesH.GdObj

			if obj.type_ == GdTypesH.OBJ_TYPE_JOINTS then
				const Joint = obj :: GdTypesH.ObjJoint
				const Update = Joint.updateFunc

				if Update ~= nil then
					Update(Joint)
				end
			end

			link = link.next
		end
	end
end

-- from src/goddard/skin.c:move_net L423-453
function skin.move_net(net: GdTypesH.ObjNet)
	skin.gGdSkinNet = net

	const NetType = net.netType

	if NetType == 1 or NetType == 6 then
		return
	elseif NetType == 7 then
		skin.func_80192CCC(net)
	elseif NetType == 4 then
		skin.move_bonesnet(net)
	elseif NetType == 2 then
		Registry.Members.src__goddard__skin_movement.move_skin(net)
	elseif NetType == 3 then
		skin.move_joints_in_net(net)
	elseif NetType == 5 then
		Registry.Members.src__goddard__particles.func_801823A0(net)
	else
		error(string.format("move_net(%d(%d)): Undefined net type", net.id, NetType))
	end
end

-- from src/goddard/skin.c:move_nets L456-463
function skin.move_nets(group: GdTypesH.ObjGroup)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.func_80192294, group)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.move_net, group)
end

-- from src/goddard/skin.c:func_8019373C L466-483
function skin.func_8019373C(net: GdTypesH.ObjNet)
	if net.netType == 2 then
		const Shape = net.shapePtr

		if Shape ~= nil then
			const ScaledGroup: GdTypesH.ObjGroup = Registry.Members.src__goddard__objects.make_group(0)

			Shape.scaledVtxGroup = ScaledGroup

			const VertexGroup = Shape.vtxGroup :: GdTypesH.ObjGroup
			local link = VertexGroup.firstMember

			while link ~= nil do
				const vtx = link.obj :: GdTypesH.ObjVertex

				if vtx.scaleFactor ~= 1.0 then
					Registry.Members.src__goddard__objects.addto_group(ScaledGroup, vtx.header)
				end

				link = link.next
			end
		end
	end
end

-- from src/goddard/skin.c:func_80193848 L486-491
function skin.func_80193848(group: GdTypesH.ObjGroup)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.reset_net, group)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.func_80192294, group)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.func_801922FC, group)
	Registry.Members.src__goddard__objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_NETS, skin.func_8019373C, group)
end

-- from src/goddard/skin.c:gd_print_net L494-522
function skin.gd_print_net(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/skin.c:reset_net_count L525-527
function skin.reset_net_count()
	skin.sNetCount = 0
end

return skin
