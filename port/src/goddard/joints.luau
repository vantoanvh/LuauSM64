--!strict
--!optimize 2

--[[
	Port of src/goddard/joints.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const DrawObjectsH = require("./draw_objects_h")
const GdMath = require("./gd_math")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Skin = require("./skin")
const DrawObjects = require("./draw_objects")
const DynlistProc = require("./dynlist_proc")
const GdMain = require("./gd_main")
const Objects = require("./objects")
const Sfx = require("./sfx")
const SfxH = require("./sfx_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

-- from src/goddard/joints.luau:scratch
const EyeJointScreenPosition = GdTypesH.new_GdVec3f()
-- from src/goddard/joints.luau:scratch
const EyeJointOffset = GdTypesH.new_GdVec3f()
-- from src/goddard/joints.luau:scratch
const GrabbableJointOffset = GdTypesH.new_GdVec3f()

-- from src/goddard/joints.c:data
const joints = {
	-- from src/goddard/joints.c:D_801A82D0 L23-23
	D_801A82D0 = 0,
	-- from src/goddard/joints.c:gGdTempBone L24-24
	gGdTempBone = nil :: GdTypesH.ObjBone?,
	-- from src/goddard/joints.c:sResetWeightVtxNum L27-27
	sResetWeightVtxNum = 0,
	-- from src/goddard/joints.c:D_801BA964 L29-29
	D_801BA964 = nil :: { { { number } } }?,
	-- from src/goddard/joints.c:D_801BA968 L30-30
	D_801BA968 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/joints.c:sJointCount L31-31
	sJointCount = 0,
	-- from src/goddard/joints.c:sJointNotF1Count L32-32
	sJointNotF1Count = 0,
	-- from src/goddard/joints.c:sBoneCount L33-33
	sBoneCount = 0,
	-- from src/goddard/joints.c:sJointArrLen L34-34
	sJointArrLen = 0,
	-- from src/goddard/joints.c:sJointArr L35-35
	sJointArr = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil } :: { GdTypesH.ObjJoint? },
	-- from src/goddard/joints.c:sJointArrVecs L36-36
	sJointArrVecs = {
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
	},
	-- from src/goddard/joints.c:sJointArr2Len L37-37
	sJointArr2Len = 0,
	-- from src/goddard/joints.c:sJointArr2 L38-38
	sJointArr2 = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil } :: { GdTypesH.ObjJoint? },
	-- from src/goddard/joints.c:sJointArr2Vecs L39-39
	sJointArr2Vecs = {
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 0 },
	},
	-- from src/goddard/joints.c:D_801BAAD0 L40-40
	D_801BAAD0 = { x = 0, y = 0, z = 0 },
	-- from src/goddard/joints.c:D_801BAAE0 L41-41
	D_801BAAE0 = { x = 0, y = 0, z = 0 },
}

Registry.Register("src__goddard__joints", joints)

-- from src/goddard/joints.c:grabbable_joint_update_func L49-128
function joints.grabbable_joint_update_func(self: GdTypesH.ObjJoint)
	const offset = GrabbableJointOffset
	const ctrl = GdMain.gGdCtrl

	-- The joint acts somewhat like a spring in that the further it is moved
	-- from its original position, the more resistance it has to moving further

	offset.x = F32(self.mat128[4][1] - self.initPos.x)
	offset.y = F32(self.mat128[4][2] - self.initPos.y)
	offset.z = F32(self.mat128[4][3] - self.initPos.z)

	if bit32.btest(self.header.drawFlags, GdTypesH.OBJ_PICKED) then
		self.velocity.x = F32(offset.x * -0.25)
		self.velocity.y = F32(offset.y * -0.25)
		self.velocity.z = F32(offset.z * -0.25)

		self.flags = S32(bit32.bor(self.flags, 0x2000))
	else
		if ctrl.trgR == IncludePRUltratypesH.FALSE then
			-- Set velocity so that the joint approaches its initial position
			self.velocity.x = F32(self.velocity.x - offset.x * 0.5)
			self.velocity.y = F32(self.velocity.y - offset.y * 0.5)
			self.velocity.z = F32(self.velocity.z - offset.z * 0.5)

			-- Decay the velocity
			self.velocity.x = F32(self.velocity.x * 0.8)
			self.velocity.y = F32(self.velocity.y * 0.8)
			self.velocity.z = F32(self.velocity.z * 0.8)

			-- If the joint's velocity has decayed enough and it is very close
			-- to its original position, stop its movement altogether
			if F32(F32(math.abs(self.velocity.x) + math.abs(self.velocity.y)) + math.abs(self.velocity.z)) < 1.0 then
				if F32(F32(math.abs(offset.x) + math.abs(offset.y)) + math.abs(offset.z)) < 1.0 then
					self.velocity.z = 0.0
					self.velocity.y = self.velocity.z
					self.velocity.x = self.velocity.y
					self.mat128[4][1] = F32(self.mat128[4][1] - offset.x)
					self.mat128[4][2] = F32(self.mat128[4][2] - offset.y)
					self.mat128[4][3] = F32(self.mat128[4][3] - offset.z)
				end
			end

			if bit32.btest(self.flags, 0x2000) then
				Sfx.gd_play_sfx(SfxH.GD_SFX_LET_GO_FACE)
			end

			self.flags = S32(bit32.band(self.flags, bit32.bnot(0x2000)))
		else
			-- freeze position of joint
			self.velocity.z = 0.0
			self.velocity.y = self.velocity.z
			self.velocity.x = self.velocity.y
		end
	end

	-- update position
	self.mat128[4][1] = F32(self.mat128[4][1] + self.velocity.x)
	self.mat128[4][2] = F32(self.mat128[4][2] + self.velocity.y)
	self.mat128[4][3] = F32(self.mat128[4][3] + self.velocity.z)

	if bit32.btest(self.header.drawFlags, GdTypesH.OBJ_PICKED) then
		ctrl.csrX = TruncS32(ctrl.csrX - S32(ctrl.csrX - ctrl.dragStartX) * 0.2)
		ctrl.csrY = TruncS32(ctrl.csrY - S32(ctrl.csrY - ctrl.dragStartY) * 0.2)
	end

	-- update position of attached objects
	offset.x = F32(self.mat128[4][1] - self.initPos.x)
	offset.y = F32(self.mat128[4][2] - self.initPos.y)
	offset.z = F32(self.mat128[4][3] - self.initPos.z)

	local att = (self.attachedObjsGrp :: GdTypesH.ObjGroup).firstMember

	while att ~= nil do
		const attobj = att.obj :: GdTypesH.GdObj

		DynlistProc.set_cur_dynobj(attobj)

		const attObjMtx: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_matrix_ptr()

		GdMath.gd_add_vec3f_to_mat4f_offset(attObjMtx, offset)
		att = att.next
	end
end

-- from src/goddard/joints.c:eye_joint_update_func L133-178
function joints.eye_joint_update_func(self: GdTypesH.ObjJoint)
	const moveCamera = Objects.sCurrentMoveCamera

	if moveCamera == nil then
		return
	end

	if self.rootAnimator ~= nil then
		if self.rootAnimator.state ~= 7 then
			return
		end
	end

	DynlistProc.set_cur_dynobj(self.header)

	const sp5C: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()
	const sp44 = EyeJointScreenPosition
	const sp50 = EyeJointOffset

	sp44.x = sp5C[4][1]
	sp44.y = sp5C[4][2]
	sp44.z = sp5C[4][3]
	DrawObjects.world_pos_to_screen_coords(sp44, moveCamera, Objects.sCurrentMoveView :: GdTypesH.ObjView)

	sp50.x = F32(GdMain.gGdCtrl.csrX - sp44.x)
	sp50.y = -F32(GdMain.gGdCtrl.csrY - sp44.y)
	sp50.z = 0.0

	sp50.x = F32(sp50.x * 2.0)
	sp50.y = F32(sp50.y * 2.0)
	sp50.z = F32(sp50.z * 2.0)

	if GdMath.gd_vec3f_magnitude(sp50) > 30.0 then
		GdMath.gd_normalize_vec3f(sp50)
		sp50.x = F32(sp50.x * 30.0)
		sp50.y = F32(sp50.y * 30.0)
		sp50.z = F32(sp50.z * 30.0)
	end

	local att = (self.attachedObjsGrp :: GdTypesH.ObjGroup).firstMember

	while att ~= nil do
		const attobj = att.obj :: GdTypesH.GdObj

		DynlistProc.set_cur_dynobj(attobj)

		const attachedMatrix: { { number } } = Registry.Members.src__goddard__dynlist_proc.d_get_rot_mtx_ptr()

		GdMath.gd_add_vec3f_to_mat4f_offset(attachedMatrix, sp50)
		att = att.next
	end
end

-- from src/goddard/joints.c:func_8018EE5C L181-201
function joints.func_8018EE5C(j1: GdTypesH.ObjJoint, j2: GdTypesH.ObjJoint, j3: GdTypesH.ObjJoint?)
	error("stale")
	return
end

-- from src/goddard/joints.c:set_joint_vecs L204-224
function joints.set_joint_vecs(j: GdTypesH.ObjJoint, x: number, y: number, z: number)
	x = F32(x)
	y = F32(y)
	z = F32(z)

	j.worldPos.x = x
	j.worldPos.y = y
	j.worldPos.z = z

	j.unk30.x = x
	j.unk30.y = y
	j.unk30.z = z

	j.unk3C.x = x
	j.unk3C.y = y
	j.unk3C.z = z

	j.initPos.x = x
	j.initPos.y = y
	j.initPos.z = z

	j.mat128[4][1] = x
	j.mat128[4][2] = y
	j.mat128[4][3] = z
end

-- from src/goddard/joints.c:make_joint L227-269
function joints.make_joint(flags: number, x: number, y: number, z: number): GdTypesH.ObjJoint
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const j = Registry.Members.src__goddard__objects.make_object(GdTypesH.OBJ_TYPE_JOINTS) :: GdTypesH.ObjJoint

	joints.sJointCount += 1

	const oldhead: GdTypesH.ObjJoint? = Registry.Members.src__goddard__objects.gGdJointList

	Registry.Members.src__goddard__objects.gGdJointList = j

	if oldhead ~= nil then
		j.nextjoint = oldhead
		oldhead.prevjoint = j
	end

	GdMath.gd_set_identity_mat4(j.matE8)
	GdMath.gd_set_identity_mat4(j.mat128)
	joints.set_joint_vecs(j, x, y, z)
	j.ObjJoint_type = 0
	j.id = joints.sJointCount
	j.flags = flags

	if not bit32.btest(j.flags, 0x1) then
		joints.sJointNotF1Count += 1
	end

	if bit32.btest(j.flags, 0x1) then
		j.colourNum = DrawObjectsH.COLOUR_RED
	else
		j.colourNum = DrawObjectsH.COLOUR_PINK
	end

	j.unk1C4 = nil
	j.shapePtr = nil
	j.scale.x = 1.0
	j.scale.y = 1.0
	j.scale.z = 1.0
	j.friction.x = 0.0
	j.friction.y = 0.0
	j.friction.z = 0.0
	j.updateFunc = nil

	return j
end

-- from src/goddard/joints.c:make_grabber_joint L276-290
function joints.make_grabber_joint(shape: GdTypesH.ObjShape, flags: number, x: number, y: number, z: number): GdTypesH.ObjJoint
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const j = joints.make_joint(0, x, y, z)

	j.shapePtr = shape
	j.ObjJoint_type = 5
	j.flags = S32(bit32.bor(j.flags, flags))
	j.colourNum = DrawObjectsH.COLOUR_PINK
	j.header.drawFlags = U16(bit32.bor(j.header.drawFlags, GdTypesH.OBJ_IS_GRABBABLE))
	j.header.drawFlags = U16(bit32.bor(j.header.drawFlags, GdTypesH.OBJ_INVISIBLE))
	j.updateFunc = joints.grabbable_joint_update_func
	j.rootAnimator = nil

	return j
end

-- from src/goddard/joints.c:func_8018F328 L293-316
function joints.func_8018F328(b: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018F4CC L319-325
function joints.func_8018F4CC(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018F520 L328-391
function joints.func_8018F520(b: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018F89C L394-421
function joints.func_8018F89C(b: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018FA68 L424-430
function joints.func_8018FA68(b: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:set_skin_weight L433-443
function joints.set_skin_weight(j: GdTypesH.ObjJoint, id: number, vtx: GdTypesH.ObjVertex?, weight: number): number
	weight = F32(weight)
	if j.weightGrp == nil then
		j.weightGrp = Registry.Members.src__goddard__objects.make_group(0)
	end

	const w: GdTypesH.ObjWeight = Registry.Members.src__goddard__objects.make_weight(0, id, vtx, weight)

	Registry.Members.src__goddard__objects.addto_group(j.weightGrp, w.header)

	return IncludePRUltratypesH.TRUE
end

-- from src/goddard/joints.c:func_8018FB58 L446-467
function joints.func_8018FB58(b: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:add_joint2bone L470-488
function joints.add_joint2bone(b: GdTypesH.ObjBone, j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:make_bone L491-522
function joints.make_bone(a0: number, j1: GdTypesH.ObjJoint?, j2: GdTypesH.ObjJoint?, a3: number): GdTypesH.ObjBone
	error("stale")
end

-- from src/goddard/joints.c:stub_joints_1 L525-526
function joints.stub_joints_1(a0: number)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018FF28 L529-535
function joints.func_8018FF28(a0: GdTypesH.ObjJoint, a1: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:print_some_spaces L541-547
function joints.print_some_spaces(size: number)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8018FFE8 L550-590
function joints.func_8018FFE8(a0: { GdTypesH.ObjBone? }, a1: { GdTypesH.ObjJoint? }, a2: GdTypesH.ObjJoint, a3: GdTypesH.ObjJoint): number
	error("stale")
end

-- from src/goddard/joints.c:func_80190168 L593-641
function joints.func_80190168(b: GdTypesH.ObjBone, a1: GdTypesH.ObjJoint, a2: GdTypesH.ObjJoint, a3: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_801903E8 L644-669
function joints.func_801903E8(j: GdTypesH.ObjJoint, a1: GdTypesH.GdVec3f, x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80190574 L672-770
function joints.func_80190574(a0: number, a1: GdTypesH.ObjJoint?, a2: GdTypesH.ObjJoint, x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_801909B4 L773-782
function joints.func_801909B4()
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80190A20 L785-808
function joints.func_80190A20()
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80190B54 L811-869
function joints.func_80190B54(a0: GdTypesH.ObjJoint, a1: GdTypesH.ObjJoint?, a2: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80190E68 L872-893
function joints.func_80190E68(obj: GdTypesH.GdObj, x: number, y: number, z: number)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80190F3C L896-932
function joints.func_80190F3C(a0: GdTypesH.ObjJoint, a1: number, a2: number, a3: number): number
	error("stale")
end

-- from src/goddard/joints.c:func_801911A8 L935-941
function joints.func_801911A8(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191220 L944-962
function joints.func_80191220(j: GdTypesH.ObjJoint)
	j.unk48.x = j.initPos.x
	j.unk48.y = j.initPos.y
	j.unk48.z = j.initPos.z

	const net = Skin.gGdSkinNet :: GdTypesH.ObjNet

	GdMath.gd_mat4f_mult_vec3f(j.unk48, net.mat128)
	j.unk3C.x = j.unk48.x
	j.unk3C.y = j.unk48.y
	j.unk3C.z = j.unk48.z
	j.worldPos.x = net.worldPos.x
	j.worldPos.y = net.worldPos.y
	j.worldPos.z = net.worldPos.z
	j.worldPos.x = F32(j.worldPos.x + j.unk3C.x)
	j.worldPos.y = F32(j.worldPos.y + j.unk3C.y)
	j.worldPos.z = F32(j.worldPos.z + j.unk3C.z)
	j.unk1A8.x = 0.0
	j.unk1A8.y = 0.0
	j.unk1A8.z = 0.0
	Registry.Members.src__goddard__objects.gGdCounter.ctr0 += 1
end

-- from src/goddard/joints.c:func_801913C0 L965-968
function joints.func_801913C0(j: GdTypesH.ObjJoint)
	Registry.Members.src__goddard__skin_movement.func_80181894(j)
end

-- from src/goddard/joints.c:func_801913F0 L971-986
function joints.func_801913F0(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:stub_joints_2 L989-990
function joints.stub_joints_2(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_8019150C L993-1004
function joints.func_8019150C(a0: { { { number } } }, a1: GdTypesH.GdVec3f)
	error("stale")
	return
end

-- from src/goddard/joints.c:reset_joint L1007-1033
function joints.reset_joint(j: GdTypesH.ObjJoint)
	j.worldPos.x = j.initPos.x
	j.worldPos.y = j.initPos.y
	j.worldPos.z = j.initPos.z
	j.unk30.x = j.initPos.x
	j.unk30.y = j.initPos.y
	j.unk30.z = j.initPos.z
	j.unk3C.x = j.initPos.x
	j.unk3C.y = j.initPos.y
	j.unk3C.z = j.initPos.z
	j.velocity.x = 0.0
	j.velocity.y = 0.0
	j.velocity.z = 0.0
	j.unk84.x = 0.0
	j.unk84.y = 0.0
	j.unk84.z = 0.0
	j.unk90.x = 0.0
	j.unk90.y = 0.0
	j.unk90.z = 0.0
	j.unk1A8.x = 0.0
	j.unk1A8.y = 0.0
	j.unk1A8.z = 0.0

	GdMath.gd_set_identity_mat4(j.mat168)
	GdMath.gd_scale_mat4f_by_vec3f(j.mat168, j.scale)
	GdMath.gd_rot_mat_about_vec(j.mat168, j.unk6C)
	GdMath.gd_add_vec3f_to_mat4f_offset(j.mat168, j.attachOffset)
	GdMath.gd_copy_mat4f(j.mat168, j.matE8)
	GdMath.gd_set_identity_mat4(j.mat128)
	GdMath.gd_add_vec3f_to_mat4f_offset(j.mat128, j.initPos)
end

-- from src/goddard/joints.c:func_80191824 L1036-1050
function joints.func_80191824(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_801918F4 L1053-1077
function joints.func_801918F4(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191A1C L1080-1113
function joints.func_80191A1C(a0: GdTypesH.ObjBone)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191BF8 L1116-1131
function joints.func_80191BF8(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191D60 L1134-1146
function joints.func_80191D60(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191E54 L1149-1153
function joints.func_80191E54(j: GdTypesH.ObjJoint)
	error("stale")
	return
end

-- from src/goddard/joints.c:func_80191E88 L1156-1160
function joints.func_80191E88(grp: GdTypesH.ObjGroup)
	error("stale")
	return
end

-- from src/goddard/joints.c:reset_joint_counts L1163-1167
function joints.reset_joint_counts()
	joints.sJointCount = 0
	joints.sJointNotF1Count = 0
	joints.sBoneCount = 0
end

return joints
