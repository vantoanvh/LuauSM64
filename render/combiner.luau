--!strict
--!optimize 2

--[[
	The RDP color combiner: (A - B) * C + D on colors and on alpha, one or two cycles, over the texel, shade, primitive,
	environment and combined inputs. All values are 0..1.

	Design Notes
		A G_SETCOMBINE word set is compiled once per Combine array into a Program: for each of its 16 slots (a b c d of the color,
		then of the alpha, for each cycle) a register number and, for color slots, whether the alpha of the register stands in
		for its three channels (the *_ALPHA inputs of C). The registers are module level arrays: SetConstants fills the ones
		that are the same for a batch, Run the per pixel inputs.
		ColorKind and AlphaKind name the combinations that most of the game uses (shade, texel * shade, texel) so the rasterizer
		can skip Run for them.
]]

const Gbi = require("./gbi")

export type Program = {
	Register: { number },
	UseAlpha: { boolean },
	-- Specialized operations for the first cycle, or General when the interpreter must run it.
	ColorKind: number,
	AlphaKind: number,
	-- False when the second cycle passes the first cycle's result through (the usual two cycle fog mode)
	SecondCycle: boolean,
}

-- Register numbers
const Zero = 1
const One = 2
const Texel0 = 3
const Texel1 = 4
const Primitive = 5
const Shade = 6
const Environment = 7
const Combined = 8
const LodFraction = 9
const PrimLodFraction = 10
const RegisterCount = 10

const Operation = {
	General = 0,
	Shade = 1,
	TexelShade = 2,
	Texel = 3,
	PassThrough = 4,
	TexelEnvironment = 5,
	Environment = 6,
}

const R = table.create(RegisterCount, 0)
const G = table.create(RegisterCount, 0)
const B = table.create(RegisterCount, 0)
const A = table.create(RegisterCount, 0)

R[One], G[One], B[One], A[One] = 1, 1, 1, 1

-- The program of each Combine table (the display list shares one table for each distinct G_SETCOMBINE, so there are few)
const Programs: { [{ number }]: Program } = {}

-- The register of a mux value 0..5 shared by all slots: combined, texel 0, texel 1, primitive, shade, environment
const function Common(Value: number): number
	return if Value == 0 then Combined else Value + 2
end

-- The register and alpha flag of an A, B or D color mux; C (Position 3) has the alpha inputs
const function ColorSlot(Position: number, Value: number): (number, boolean)
	if Value <= Gbi.CcEnvironment then
		return Common(Value), false
	elseif Position == 3 then
		if Value == Gbi.CcCombinedAlpha then
			return Combined, true
		elseif Value == Gbi.CcTexel0Alpha then
			return Texel0, true
		elseif Value == Gbi.CcTexel1Alpha then
			return Texel1, true
		elseif Value == Gbi.CcPrimitiveAlpha then
			return Primitive, true
		elseif Value == Gbi.CcShadeAlpha then
			return Shade, true
		elseif Value == Gbi.CcEnvAlpha then
			return Environment, true
		elseif Value == Gbi.CcLodFraction then
			return LodFraction, false
		elseif Value == Gbi.CcPrimLodFraction then
			return PrimLodFraction, false
		elseif Value == 15 then
			return One, false
		end
	elseif Value == Gbi.CcOne and Position ~= 2 then
		return One, false
	end

	return Zero, false
end

-- The register of an alpha mux value; C (Position 3) has the LOD fractions where the others have combined and one
const function AlphaSlot(Position: number, Value: number): number
	if Value >= 1 and Value <= 5 then
		return Common(Value)
	elseif Value == 0 then
		return if Position == 3 then LodFraction else Combined
	elseif Value == 6 then
		return if Position == 3 then PrimLodFraction else One
	end

	return Zero
end

-- The kind of the four registers a, b, c, d of the first cycle (color: UseAlpha is from the program, alpha: always false)
const function Kind(Program: Program, First: number): number
	const Registers = Program.Register
	const RegisterA, RegisterB, RegisterC, RegisterD = Registers[First], Registers[First + 1], Registers[First + 2], Registers[First + 3]

	if RegisterA == Zero and RegisterB == Zero and RegisterC == Zero and RegisterD == Shade then
		return Operation.Shade
	elseif RegisterA == Texel0 and RegisterB == Zero and RegisterC == Shade and RegisterD == Zero then
		return Operation.TexelShade
	elseif RegisterA == Zero and RegisterB == Zero and RegisterC == Zero and RegisterD == Texel0 then
		return Operation.Texel
	elseif RegisterA == Zero and RegisterB == Zero and RegisterC == Zero and RegisterD == Combined then
		return Operation.PassThrough
	elseif RegisterA == Texel0 and RegisterB == Zero and RegisterC == Environment and RegisterD == Zero then
		return Operation.TexelEnvironment
	elseif RegisterA == Zero and RegisterB == Zero and RegisterC == Zero and RegisterD == Environment then
		return Operation.Environment
	end

	return Operation.General
end

const function Compile(Combine: { number }): Program
	const Cached = Programs[Combine]

	if Cached ~= nil then
		return Cached
	end

	const Program = { Register = table.create(16, 0), UseAlpha = table.create(16, false), ColorKind = Operation.General, AlphaKind = Operation.General, SecondCycle = true }

	for Cycle = 0, 1 do
		for Position = 1, 4 do
			const Base = Cycle * 8
			const Register, UseAlpha = ColorSlot(Position, Combine[Base + Position])

			Program.Register[Base + Position] = Register
			Program.UseAlpha[Base + Position] = UseAlpha
			Program.Register[Base + 4 + Position] = AlphaSlot(Position, Combine[Base + 4 + Position])
		end
	end

	if not Program.UseAlpha[3] then
		Program.ColorKind = Kind(Program, 1)
	end

	Program.AlphaKind = Kind(Program, 5)
	Program.SecondCycle = not (Kind(Program, 9) == Operation.PassThrough and Kind(Program, 13) == Operation.PassThrough)
	Programs[Combine] = Program

	return Program
end

-- Whether the alpha of a combine reads the alpha of the environment color (a fade: the game changes that color's alpha)
const function UsesEnvironmentAlpha(Combine: { number }): boolean
	const Program = Compile(Combine)

	for Slot = 5, 8 do
		if Program.Register[Slot] == Environment or (Program.SecondCycle and Program.Register[Slot + 8] == Environment) then
			return true
		end
	end

	return false
end

-- The inputs that are the same for every pixel of a batch (colors 0..255)
const function SetConstants(PrimitiveColor: { number }, EnvironmentColor: { number })
	R[Primitive], G[Primitive], B[Primitive], A[Primitive] = PrimitiveColor[1] / 255, PrimitiveColor[2] / 255, PrimitiveColor[3] / 255, PrimitiveColor[4] / 255
	R[Environment], G[Environment], B[Environment], A[Environment] = EnvironmentColor[1] / 255, EnvironmentColor[2] / 255, EnvironmentColor[3] / 255, EnvironmentColor[4] / 255
end

const function Fetch(Program: Program, Slot: number): (number, number, number)
	const Register = Program.Register[Slot]

	if Program.UseAlpha[Slot] then
		const Alpha = A[Register]

		return Alpha, Alpha, Alpha
	end

	return R[Register], G[Register], B[Register]
end

const function Clamp(Value: number): number
	return if Value < 0 then 0 elseif Value > 1 then 1 else Value
end

-- One cycle: the result goes to the combined register
const function RunCycle(Program: Program, Base: number)
	const Ar, Ag, Ab = Fetch(Program, Base + 1)
	const Br, Bg, Bb = Fetch(Program, Base + 2)
	const Cr, Cg, Cb = Fetch(Program, Base + 3)
	const Dr, Dg, Db = Fetch(Program, Base + 4)
	const Registers = Program.Register
	const AlphaA = A[Registers[Base + 5]]
	const AlphaB = A[Registers[Base + 6]]
	const AlphaC = A[Registers[Base + 7]]
	const AlphaD = A[Registers[Base + 8]]

	R[Combined] = Clamp((Ar - Br) * Cr + Dr)
	G[Combined] = Clamp((Ag - Bg) * Cg + Dg)
	B[Combined] = Clamp((Ab - Bb) * Cb + Db)
	A[Combined] = Clamp((AlphaA - AlphaB) * AlphaC + AlphaD)
end

-- Texel and shade are 0..1; the second texel is the first (single texture)
const function Run(
	Program: Program,
	TwoCycle: boolean,
	TexelR: number,
	TexelG: number,
	TexelB: number,
	TexelA: number,
	ShadeR: number,
	ShadeG: number,
	ShadeB: number,
	ShadeA: number
): (number, number, number, number)
	R[Texel0], G[Texel0], B[Texel0], A[Texel0] = TexelR, TexelG, TexelB, TexelA
	R[Texel1], G[Texel1], B[Texel1], A[Texel1] = TexelR, TexelG, TexelB, TexelA
	R[Shade], G[Shade], B[Shade], A[Shade] = ShadeR, ShadeG, ShadeB, ShadeA
	RunCycle(Program, 0)

	if TwoCycle then
		RunCycle(Program, 8)
	end

	return R[Combined], G[Combined], B[Combined], A[Combined]
end

return { Compile = Compile, SetConstants = SetConstants, Run = Run, UsesEnvironmentAlpha = UsesEnvironmentAlpha, Operation = Operation }
