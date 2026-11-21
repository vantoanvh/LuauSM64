--!strict
--!optimize 2

--[[
	Port of src/goddard/particles.c.
]]

const Registry = require("../../groups/registry")

const GdTypesH = require("./gd_types_h")
const DebugUtils = require("./debug_utils")
const GdMath = require("./gd_math")
const Objects = require("./objects")
const Skin = require("./skin")
const DrawObjects = require("./draw_objects")
const DynlistProc = require("./dynlist_proc")

-- from src/goddard/particles.c:VtxPtc
-- union: the fields are views of the same storage in C; decide how they alias
export type VtxPtc = {
	vtx: { GdTypesH.ObjVertex }?,
	ptc: GdTypesH.ObjParticle?,
}

-- from src/goddard/particles.c:Connection
export type Connection = {
	header: GdTypesH.GdObj, -- first member: this table itself
	prev: GdTypesH.GdObj?,
	next: GdTypesH.GdObj?,
	objDrawFn: (() -> ())?,
	type_: number,
	index: number,
	drawFlags: number,
	filler: buffer, -- [8]
	node1: VtxPtc,
	node2: VtxPtc,
	unk24: number,
	unk28: number,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
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

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- from src/goddard/particles.luau:scratch
const MoveParticleSp40 = GdTypesH.new_GdVec3f()
-- from src/goddard/particles.luau:scratch
const MoveParticleSp34 = GdTypesH.new_GdVec3f()
-- from src/goddard/particles.luau:scratch
const MoveParticleSp64 = GdTypesH.new_GdVec3f()

-- from src/goddard/particles.c:data
const particles = {
	-- from src/goddard/particles.c:sUnused801A81D0 L30-30
	sUnused801A81D0 = nil,
	-- from src/goddard/particles.c:D_801A81D4 L31-35
	D_801A81D4 = { 9, 3, 12, -14, 25, 5, 16, -25, 42, 4, 15, -39, 55, -6, 20, -23, 70, -2, 20, -23, 135, 0, 16, 0, 0 },
	-- from src/goddard/particles.c:D_801A8238 L36-39
	D_801A8238 = { 15, 0, 22, 0, 0 },
	-- from src/goddard/particles.c:D_801B9EF0 L42-42
	D_801B9EF0 = nil :: GdTypesH.ObjFace?,
}

Registry.Register("src__goddard__particles", particles)

-- from src/goddard/particles.c:Connection (zero-filled constructor)
function particles.new_Connection(): Connection
	const Result = {
		prev = nil,
		next = nil,
		objDrawFn = nil,
		type_ = 0,
		index = 0,
		drawFlags = 0,
		filler = buffer.create(8),
		node1 = { vtx = nil },
		node2 = { vtx = nil },
		unk24 = 0,
		unk28 = 0,
		header = nil :: unknown,
	} :: Connection

	Result.header = Result

	return Result
end

-- from src/goddard/particles.c:connect_vertices L56-79
function particles.connect_vertices(vtx1: GdTypesH.ObjVertex, vtx2: GdTypesH.ObjVertex)
	error("stale")
	return
end

-- from src/goddard/particles.c:Unknown80181D14 L82-103
function particles.Unknown80181D14(face: GdTypesH.ObjFace)
	error("stale")
	return
end

-- from src/goddard/particles.c:func_80181EB0 L106-132
function particles.func_80181EB0(cxn: Connection)
	error("stale")
	return
end

-- from src/goddard/particles.c:func_80182088 L135-176
function particles.func_80182088(cxn: Connection)
	error("stale")
	return
end

-- from src/goddard/particles.c:func_801823A0 L179-206
function particles.func_801823A0(net: GdTypesH.ObjNet)
	error("stale")
	return
end

-- from src/goddard/particles.c:make_particle L209-224
function particles.make_particle(flags: number, colourNum: number, x: number, y: number, z: number): GdTypesH.ObjParticle
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const particle = Objects.make_object(GdTypesH.OBJ_TYPE_PARTICLES) :: GdTypesH.ObjParticle

	particle.pos.x = x
	particle.pos.y = y
	particle.pos.z = z
	particle.unk38.x = 0.0
	particle.unk38.y = 0.0
	particle.unk38.z = 0.0
	particle.colourNum = colourNum
	particle.flags = bit32.bor(flags, 8)
	particle.timeout = -1
	particle.id = Objects.D_801B9E40
	particle.shapePtr = nil
	particle.unkB0 = 1

	return particle
end

-- from src/goddard/particles.c:make_connection L227-255
function particles.make_connection(vtx1: GdTypesH.ObjVertex, vtx2: GdTypesH.ObjVertex): Connection?
	error("stale")
end

-- from src/goddard/particles.c:func_80182778 L258-284
function particles.func_80182778(ptc: GdTypesH.ObjParticle): number
	error("stale")
end

-- from src/goddard/particles.c:func_80182A08 L287-315
function particles.func_80182A08(ptc: GdTypesH.ObjParticle, b: GdTypesH.GdVec3f)
	if ptc.subParticlesGrp ~= nil then
		local link = ptc.subParticlesGrp.firstMember

		while link ~= nil do
			const child = link.obj :: GdTypesH.ObjParticle

			if child.timeout <= 0 then
				child.pos.x = ptc.pos.x
				child.pos.y = ptc.pos.y
				child.pos.z = ptc.pos.z
				child.timeout = TruncS32(F32(12.0 - F32(DebugUtils.gd_rand_float() * 5.0)))

				repeat
					child.unk38.x = F32(DebugUtils.gd_rand_float() * 50.0 - 25.0)
					child.unk38.y = F32(DebugUtils.gd_rand_float() * 50.0 - 25.0)
					child.unk38.z = F32(DebugUtils.gd_rand_float() * 50.0 - 25.0)
				until not (GdMath.gd_vec3f_magnitude(child.unk38) > 30.0)

				child.unk38.x = F32(child.unk38.x + b.x)
				child.unk38.y = F32(child.unk38.y + b.y)
				child.unk38.z = F32(child.unk38.z + b.z)
				child.header.drawFlags = U16(bit32.band(child.header.drawFlags, bit32.bnot(GdTypesH.OBJ_INVISIBLE)))
				child.flags = bit32.bor(child.flags, 8)
			end

			link = link.next
		end
	end
end

-- from src/goddard/particles.c:move_particle L318-456
function particles.move_particle(ptc: GdTypesH.ObjParticle)
	if bit32.btest(ptc.flags, 2) then
		return
	end

	if not bit32.btest(ptc.flags, 8) then
		return
	end

	const sp40 = MoveParticleSp40
	const sp34 = MoveParticleSp34
	const sp64 = MoveParticleSp64

	if ptc.unk60 == 3 then
		const viewCamera = DrawObjects.gViewUpdateCamera :: GdTypesH.ObjCamera

		sp40.x = F32(-viewCamera.unkE8[3][1] * 50.0)
		sp40.y = F32(-viewCamera.unkE8[3][2] * 50.0)
		sp40.z = F32(viewCamera.unkE8[3][3] * 50.0)
		sp34.x = F32(viewCamera.unkE8[3][1] * -20.0)
		sp34.y = F32(viewCamera.unkE8[3][2] * -20.0)
		sp34.z = F32(viewCamera.unkE8[3][3] * -20.0)
	end

	if ptc.attachedToObj ~= nil then
		DynlistProc.set_cur_dynobj(ptc.attachedToObj)

		if ptc.unk60 == 3 then
			if ptc.unk64 == 3 then
				const sp4C = (ptc.attachedToObj :: unknown) :: GdTypesH.ObjCamera
				-- Camera->unk18C = ObjView here
				const pickedObj = (sp4C.unk18C :: GdTypesH.ObjView).pickedObj

				if pickedObj ~= nil then
					DynlistProc.set_cur_dynobj(pickedObj)
					ptc.flags = bit32.bor(ptc.flags, 0x20)
				else
					ptc.flags = bit32.band(ptc.flags, bit32.bnot(0x10))
					ptc.flags = bit32.band(ptc.flags, bit32.bnot(0x20))
				end
			end
		end

		DynlistProc.d_get_world_pos(sp64)
		ptc.pos.x = sp64.x
		ptc.pos.y = sp64.y
		ptc.pos.z = sp64.z
	end

	const sp7C = F32(-0.4)

	ptc.pos.x = F32(ptc.pos.x + ptc.unk38.x)
	ptc.pos.y = F32(ptc.pos.y + ptc.unk38.y)
	ptc.pos.z = F32(ptc.pos.z + ptc.unk38.z)

	if bit32.btest(ptc.flags, 1) then
		ptc.unk38.y = F32(ptc.unk38.y + sp7C)
	end

	particles.func_801838D0(ptc)

	if ptc.unkB0 == 1 then
		ptc.unkB0 = 2

		if ptc.unk60 == 3 then
			if ptc.unk64 == 1 then
				const subParticles = Objects.make_group(0)

				ptc.subParticlesGrp = subParticles

				for i = 0, 50 - 1 do
					const sp60 = particles.make_particle(1, -1, ptc.pos.x, ptc.pos.y, ptc.pos.z)

					sp60.shapePtr = ptc.shapePtr
					Objects.addto_group(subParticles, sp60.header)
					sp60.flags = bit32.band(sp60.flags, bit32.bnot(8))
				end
			elseif ptc.unk64 == 2 or ptc.unk64 == 3 then
				const subParticles = Objects.make_group(0)

				ptc.subParticlesGrp = subParticles

				for i = 0, 30 - 1 do
					const sp60 = particles.make_particle(1, -1, ptc.pos.x, ptc.pos.y, ptc.pos.z)

					sp60.shapePtr = ptc.shapePtr
					Objects.addto_group(subParticles, sp60.header)
					sp60.flags = bit32.band(sp60.flags, bit32.bnot(8))
				end
			end
		end
	end

	ptc.unk38.x = F32(ptc.unk38.x * 0.9)
	ptc.unk38.y = F32(ptc.unk38.y * 0.9)
	ptc.unk38.z = F32(ptc.unk38.z * 0.9)

	if ptc.unk60 == 3 then
		if ptc.unk64 == 1 then
			if particles.func_80182778(ptc) ~= 0 and ptc.subParticlesGrp ~= nil then
				if ptc.unk80 ~= nil then
					ptc.unk80.unk3C = S32(bit32.bor(ptc.unk80.unk3C, 1))
					ptc.unk80.position.x = ptc.pos.x
					ptc.unk80.position.y = ptc.pos.y
					ptc.unk80.position.z = ptc.pos.z
				end

				local link = ptc.subParticlesGrp.firstMember

				while link ~= nil do
					const sp2C = (link.obj :: unknown) :: GdTypesH.ObjParticle

					sp2C.pos.x = ptc.pos.x
					sp2C.pos.y = ptc.pos.y
					sp2C.pos.z = ptc.pos.z
					sp2C.timeout = 20

					repeat
						sp2C.unk38.x = F32(DebugUtils.gd_rand_float() * 64.0 - 32.0)
						sp2C.unk38.y = F32(DebugUtils.gd_rand_float() * 64.0 - 32.0)
						sp2C.unk38.z = F32(DebugUtils.gd_rand_float() * 64.0 - 32.0)
					until not (GdMath.gd_vec3f_magnitude(sp2C.unk38) > 32.0)

					sp2C.unk30 = F32(DebugUtils.gd_rand_float() * 180.0)
					sp2C.header.drawFlags = U16(bit32.band(sp2C.header.drawFlags, bit32.bnot(GdTypesH.OBJ_INVISIBLE)))
					sp2C.flags = bit32.bor(sp2C.flags, 8)
					link = link.next
				end
			end
		elseif ptc.unk64 == 3 then
			if bit32.btest(ptc.flags, 0x20) and not bit32.btest(ptc.flags, 0x10) then
				particles.func_80182A08(ptc, sp40)
				ptc.flags = bit32.bor(ptc.flags, 0x10)
			end
		elseif ptc.unk64 == 2 then
			particles.func_80182A08(ptc, sp34)
		end

		Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_PARTICLES, particles.move_particle, ptc.subParticlesGrp)
	end

	if ptc.timeout >= 0 then
		const previousTimeout = ptc.timeout

		ptc.timeout -= 1

		if previousTimeout <= 0 then
			ptc.header.drawFlags = U16(bit32.bor(ptc.header.drawFlags, GdTypesH.OBJ_INVISIBLE))
			ptc.flags = bit32.band(ptc.flags, bit32.bnot(8))
		end
	end
end

-- from src/goddard/particles.c:move_particles_in_grp L459-464
function particles.move_particles_in_grp(group: GdTypesH.ObjGroup)
	Skin.gGdSkinNet = nil
	Objects.apply_to_obj_types_in_group(GdTypesH.OBJ_TYPE_PARTICLES, particles.move_particle, group)
end

-- from src/goddard/particles.c:ABS L466-466
function particles.ABS(x: number): number
	return if x < 0.0 then -x else x
end

-- from src/goddard/particles.c:Unknown801835C8 L468-494
function particles.Unknown801835C8(ptc: GdTypesH.ObjParticle)
	error("stale")
	return
end

-- from src/goddard/particles.c:stub_particles_1 L499-500
function particles.stub_particles_1(a: number)
	error("stale")
	return
end

-- from src/goddard/particles.c:stub_particles_2 L505-506
function particles.stub_particles_2(a: number)
	error("stale")
	return
end

-- from src/goddard/particles.c:stub_particles_3 L511-512
function particles.stub_particles_3(a: number, b: number, c: number)
	error("stale")
	return
end

-- from src/goddard/particles.c:stub_particles_4 L517-518
function particles.stub_particles_4(a: number, b: number, c: number)
	error("stale")
	return
end

-- from src/goddard/particles.c:func_801838D0 L521-525
function particles.func_801838D0(ptc: GdTypesH.ObjParticle)
	Objects.D_801B9E3C = ptc

	if ptc.pos.y < -15.0 then
		-- Empty in the C source.
	end
end

return particles
