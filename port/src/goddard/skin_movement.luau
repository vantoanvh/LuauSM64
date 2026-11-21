--!strict
--!optimize 2

--[[
	Port of src/goddard/skin_movement.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const GdMath = require("./gd_math")
const Joints = require("./joints")
const Objects = require("./objects")
const Skin = require("./skin")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/goddard/skin_movement.luau:scratch
const WeightedPosition = { x = 0, y = 0, z = 0 }
-- from src/goddard/skin_movement.luau:scratch
const ResetPosition = { x = 0, y = 0, z = 0 }

-- from src/goddard/skin_movement.c:data
const skin_movement = {
	-- from src/goddard/skin_movement.c:sResetCurWeight L17-17
	sResetCurWeight = nil :: GdTypesH.ObjWeight?,
	-- from src/goddard/skin_movement.c:D_801B9EA8 L18-18
	D_801B9EA8 = { table.create(4, 0), table.create(4, 0), table.create(4, 0), table.create(4, 0) },
	-- from src/goddard/skin_movement.c:D_801B9EE8 L19-19
	D_801B9EE8 = nil :: GdTypesH.ObjJoint?,
}

Registry.Register("src__goddard__skin_movement", skin_movement)

-- from src/goddard/skin_movement.c:func_801815E0 L22-48
function skin_movement.func_801815E0(mtx: { { { number } } })
	error("stale")
	return
end

-- from src/goddard/skin_movement.c:scale_verts L53-69
function skin_movement.scale_verts(a0: GdTypesH.ObjGroup)
	local link = a0.firstMember

	while link ~= nil do
		const vtx = link.obj :: GdTypesH.ObjVertex
		const sp1C = vtx.scaleFactor

		if sp1C ~= 0.0 then
			vtx.pos.x = F32(vtx.initPos.x * sp1C)
			vtx.pos.y = F32(vtx.initPos.y * sp1C)
			vtx.pos.z = F32(vtx.initPos.z * sp1C)
		else
			vtx.pos.x = 0.0
			vtx.pos.y = 0.0
			vtx.pos.z = 0.0
		end

		link = link.next
	end
end

-- from src/goddard/skin_movement.c:move_skin L72-78
function skin_movement.move_skin(net: GdTypesH.ObjNet)
	const Shape = net.shapePtr

	if Shape ~= nil then
		skin_movement.scale_verts(Shape.scaledVtxGroup :: GdTypesH.ObjGroup)
	end
end

-- from src/goddard/skin_movement.c:func_80181894 L81-111
function skin_movement.func_80181894(joint: GdTypesH.ObjJoint)
	const weightGroup = joint.weightGrp

	if weightGroup ~= nil then
		local link = weightGroup.firstMember
		const stackVec = WeightedPosition

		while link ~= nil do
			const curWeight = link.obj :: GdTypesH.ObjWeight

			if curWeight.weightVal > 0.0 then
				stackVec.x = curWeight.vec20.x
				stackVec.y = curWeight.vec20.y
				stackVec.z = curWeight.vec20.z
				GdMath.gd_rotate_and_translate_vec3f(stackVec, joint.matE8)

				const connectedVtx = curWeight.vtx :: GdTypesH.ObjVertex
				const scaleFactor = curWeight.weightVal

				connectedVtx.pos.x = F32(connectedVtx.pos.x + F32(stackVec.x * scaleFactor))
				connectedVtx.pos.y = F32(connectedVtx.pos.y + F32(stackVec.y * scaleFactor))
				connectedVtx.pos.z = F32(connectedVtx.pos.z + F32(stackVec.z * scaleFactor))
			end

			link = link.next
		end
	end
end

-- from src/goddard/skin_movement.c:reset_weight_vtx L114-131
function skin_movement.reset_weight_vtx(vtx: GdTypesH.ObjVertex)
	const Weight = skin_movement.sResetCurWeight :: GdTypesH.ObjWeight
	const Index = Joints.sResetWeightVtxNum

	Joints.sResetWeightVtxNum = S32(Index + 1)

	if Index == Weight.vtxId then
		Weight.vtx = vtx

		const localVec = ResetPosition

		localVec.x = vtx.pos.x
		localVec.y = vtx.pos.y
		localVec.z = vtx.pos.z

		GdMath.gd_rotate_and_translate_vec3f(localVec, skin_movement.D_801B9EA8)

		Weight.vec20.x = localVec.x
		Weight.vec20.y = localVec.y
		Weight.vec20.z = localVec.z
		vtx.scaleFactor = F32(vtx.scaleFactor - Weight.weightVal)
	end
end

-- from src/goddard/skin_movement.c:reset_weight L133-151
function skin_movement.reset_weight(weight: GdTypesH.ObjWeight)
	skin_movement.sResetCurWeight = weight
	Joints.sResetWeightVtxNum = 0

	const Net = Skin.gGdSkinNet :: GdTypesH.ObjNet
	const skinGroup = Net.skinGrp

	if skinGroup ~= nil then
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_VERTICES, skin_movement.reset_weight_vtx, skinGroup)
	else
		error("reset_weight(): Skin net has no SkinGroup")
	end

	if weight.vtx == nil then
		error(string.format("reset_weight(): Skin vertex ID %d not found", weight.vtxId))
	end
end

-- from src/goddard/skin_movement.c:reset_joint_weights L153-161
function skin_movement.reset_joint_weights(joint: GdTypesH.ObjJoint)
	GdMath.gd_inverse_mat4f(joint.matE8, skin_movement.D_801B9EA8)

	skin_movement.D_801B9EE8 = joint

	const group = joint.weightGrp

	if group ~= nil then
		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_WEIGHTS, skin_movement.reset_weight, group)
	end
end

return skin_movement
