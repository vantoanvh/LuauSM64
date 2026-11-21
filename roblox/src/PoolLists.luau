--!strict
--!optimize 2

--[[
	The draws of a frame as calls of lists in the ROM, each under its matrix.

	Paradigm
		A draw the geo traversal hands over is a list in the ROM (the same bytes every frame, so a presenter decodes it once and moves its
		meshes) or a list a callback node made in the Gfx pool (its bytes are the game's of this frame: the title logo, the backdrops). The
		lists of the pool the title and intro make hold only matrices and calls of lists in the ROM, so a pool list is walked: each call
		of a list in the ROM becomes a call of its own under the product of the matrices that led to it.

	Design Notes
		Commands of a pool list that are not matrix, call, return or end (vertices, triangles: the backdrops) are not shown by a presenter of
		meshes and are skipped here, as are the nested pool lists below MaximumDepth.
]]

const Gbi = require("../../render/gbi")
const Matrix = require("../../render/matrix")
const Recorder = require("../../port/src/rom/render_recorder")
const Rom = require("../../port/src/rom/rom")
const Symbols = require("../../port/src/rom/symbols")

-- A list drawn under a matrix, with the alpha of the environment color the lists of the pool before it set (a fade; 255 when none did).
-- A list in the ROM is the same every frame. A Dynamic call is a list of the pool that carries vertices of its own (water, lava, the ripple
-- of a painting: the game rewrites them every frame), taken whole.
export type Call = { Layer: number, Address: number, Mv: Matrix.Matrix, EnvAlpha: number, Dynamic: boolean }

-- The alpha of the environment color as the commands set it on the way
type Environment = { Alpha: number }

const MaximumDepth = 4
const MaximumCommands = 256
const Identity = Matrix.Identity()

const function IsPool(Address: number): boolean
	return Address >= Symbols.GfxPool and Address < Symbols.GfxPool + Symbols.GfxPoolSize
end

-- Whether a list of the pool, or a list of the pool it calls, loads vertices from the pool or sets the texture image: the walk below keeps
-- the calls of lists in the ROM only, so the texture a painting sets before it calls its list in the ROM would be lost (a black picture)
const function HasVertices(Address: number, Depth: number): boolean
	local Cursor = Address

	for _ = 1, MaximumCommands do
		const Word0 = Rom.ReadU32(Cursor)
		const Word1 = Rom.ReadU32(Cursor + 4)
		const Op = bit32.rshift(Word0, 24)

		Cursor += 8

		if Op == Gbi.Opcode.EndDl then
			return false
		elseif (Op == Gbi.Opcode.Vtx and IsPool(Word1)) or Op == Gbi.Opcode.SetTextureImage then
			return true
		elseif Op == Gbi.Opcode.Dl then
			if IsPool(Word1) and Depth < MaximumDepth and HasVertices(Word1, Depth + 1) then
				return true
			end

			if bit32.extract(Word0, 16, 8) ~= 0 then
				return false
			end
		end
	end

	return false
end

-- Nested display lists share the draw's modelview stack, so their pushes and pops survive the return.
const function Walk(Address: number, Stack: { Matrix.Matrix }, Layer: number, Depth: number, Calls: { Call }, Env: Environment, ReadTransforms: boolean)
	local Cursor = Address

	for _ = 1, MaximumCommands do
		const Word0 = Rom.ReadU32(Cursor)
		const Word1 = Rom.ReadU32(Cursor + 4)
		const Op = bit32.rshift(Word0, 24)

		Cursor += 8

		if Op == Gbi.Opcode.EndDl then
			return
		elseif Op == Gbi.Opcode.SetEnvColor then
			Env.Alpha = bit32.band(Word1, 0xFF)
		elseif Op == Gbi.Opcode.Mtx and ReadTransforms then
			const Flags = bit32.extract(Word0, 16, 8)

			if not bit32.btest(Flags, Gbi.MtxProjection) then
				const Words = table.create(16, 0)

				for Index = 1, 16 do
					Words[Index] = Rom.ReadS32(Word1 + (Index - 1) * 4)
				end

				const Loaded = Matrix.FromFixed(Words)

				if bit32.btest(Flags, Gbi.MtxPush) then
					table.insert(Stack, Stack[#Stack])
				end

				Stack[#Stack] = if bit32.btest(Flags, Gbi.MtxLoad) then Loaded else Matrix.Multiply(Loaded, Stack[#Stack])
			end
		elseif Op == Gbi.Opcode.PopMtx and ReadTransforms then
			if #Stack > 1 then
				table.remove(Stack)
			end
		elseif Op == Gbi.Opcode.Dl then
			if IsPool(Word1) then
				if Depth < MaximumDepth then
					Walk(Word1, Stack, Layer, Depth + 1, Calls, Env, ReadTransforms)
				end
			elseif Word1 ~= 0 then
				table.insert(Calls, { Layer = Layer, Address = Word1, Mv = Stack[#Stack], EnvAlpha = Env.Alpha, Dynamic = false })
			end

			-- a branch does not come back
			if bit32.extract(Word0, 16, 8) ~= 0 then
				return
			end
		end
	end
end

-- The calls of the draws of a pass in the order they run
const function Flatten(Draws: { Recorder.Draw }, ReadTransforms: boolean): { Call }
	const Calls: { Call } = {}
	const Env = { Alpha = 255 }

	for _, Draw in Draws do
		if type(Draw.DisplayList) ~= "number" or Draw.DisplayList == 0 then
			continue
		end

		const Address = Draw.DisplayList :: number
		const Mv = if ReadTransforms then Matrix.FromFixed(Draw.Matrix :: { number }) else Identity

		if IsPool(Address) and HasVertices(Address, 1) then
			table.insert(Calls, { Layer = Draw.Layer, Address = Address, Mv = Mv, EnvAlpha = Env.Alpha, Dynamic = true })
		elseif IsPool(Address) then
			Walk(Address, { Mv }, Draw.Layer, 1, Calls, Env, ReadTransforms)
		else
			table.insert(Calls, { Layer = Draw.Layer, Address = Address, Mv = Mv, EnvAlpha = Env.Alpha, Dynamic = false })
		end
	end

	return Calls
end

return Flatten
