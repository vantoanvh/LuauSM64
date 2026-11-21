--!nonstrict
--!optimize 2

--[[
	Builds a fixed-seed surface scene, runs queries through the Luau port of src/engine/surface_collision and through the native
	vanilla functions (native/build/verify/surface_driver.exe), and diffs the results.

	Run from the repository root after native/verify/build.sh: lute run native/verify/verify_surface.luau

	Scene: 16x16 partition cells, a few of them holding static and dynamic lists of random triangles (floors, ceilings, walls),
	environment regions, and the globals the lookups read (camera mode, intangible flag, current object, Mario flags).
]]

const process = require("@std/process")

const Common = require("./common")
const Registry = require("../../port/groups/registry")
const Rom = require("../../port/src/rom/rom")
const SurfaceCollision = require("../../port/src/engine/surface_collision")
const SurfaceLoad = require("../../port/src/engine/surface_load")
const ObjectListProcessor = require("../../port/src/game/object_list_processor")
const LevelUpdate = require("../../port/src/game/level_update")

const SPATIAL_PARTITION_FLOORS = 0
const SPATIAL_PARTITION_CEILS = 1
const SPATIAL_PARTITION_WALLS = 2
const ACTIVE_FLAG_MOVE_THROUGH_GRATE = 64
const MARIO_VANISH_CAP = 2
const CellSize = 1024
const LevelBoundaryMax = 0x2000
const QueriesPerKind = 400
const ReportLimit = 12

const Cells = { { 8, 8 }, { 8, 9 }, { 7, 8 }, { 9, 9 }, { 0, 0 }, { 15, 15 }, { 3, 12 } }
const FloorTypes = { 0, 0, 0, 0x12, 0x12, 0x72, 0x0A }
const WallTypes = { 0, 0, 0, 0x72, 0x7B, 0x7B }

const Surfaces = {}
const IdOf = {}
const Walls = {}
const Commands = {}
const Labels = {}

LevelUpdate.gMarioState = { flags = 0 }
ObjectListProcessor.gMarioObject = { activeFlags = 0 }

const OtherObject = { activeFlags = 0 }

function Emit(Text: string, Run: (() -> { string })?)
	table.insert(Commands, { Text = Text, Run = Run })
end

function Tokens(...: string): string
	return table.concat({ ... }, " ")
end

function SurfaceId(Surface: unknown): string
	return if Surface == nil then "-1" else Common.FormatInt(IdOf[Surface])
end

function F(Value: number): string
	return Common.FormatF32(Value)
end

function I(Value: number): string
	return Common.FormatInt(Value)
end

function Normalize(Cross: { number }): { number }
	const Length = math.sqrt(Cross[1] * Cross[1] + Cross[2] * Cross[2] + Cross[3] * Cross[3])

	if Length == 0 then
		return { 0, 0, 0 }
	end

	return { Cross[1] / Length, Cross[2] / Length, Cross[3] / Length }
end

-- Surface of vertices A, B, C with the plane equation of the loader; facing is the sign wanted for ny (0: keep the winding)
function MakeSurface(Type: number, Flags: number, Vertices: { { number } }, Facing: number): { [string]: unknown }
	const A, B, C = Vertices[1], Vertices[2], Vertices[3]
	const AB = { B[1] - A[1], B[2] - A[2], B[3] - A[3] }
	const AC = { C[1] - A[1], C[2] - A[2], C[3] - A[3] }
	local Normal = Normalize({ AB[2] * AC[3] - AB[3] * AC[2], AB[3] * AC[1] - AB[1] * AC[3], AB[1] * AC[2] - AB[2] * AC[1] })
	local Second, Third = B, C

	if Facing ~= 0 and Normal[2] * Facing < 0 then
		Second, Third = C, B
		Normal = { -Normal[1], -Normal[2], -Normal[3] }
	end

	const Offset = -(Normal[1] * A[1] + Normal[2] * A[2] + Normal[3] * A[3])

	return {
		type_ = Type,
		force = Common.Range(0, 100),
		flags = Flags,
		room = Common.Range(-1, 10),
		lowerY = math.min(A[2], B[2], C[2]) - Common.Range(0, 8),
		upperY = math.max(A[2], B[2], C[2]) + Common.Range(0, 8),
		vertex1 = { A[1], A[2], A[3] },
		vertex2 = { Second[1], Second[2], Second[3] },
		vertex3 = { Third[1], Third[2], Third[3] },
		normal = { x = Common.F32(Normal[1]), y = Common.F32(Normal[2]), z = Common.F32(Normal[3]) },
		originOffset = Common.F32(Offset),
	}
end

function RandomVertex(CellX: number, CellZ: number, BaseY: number): { number }
	return {
		-LevelBoundaryMax + CellX * CellSize + Common.Range(-100, CellSize + 100),
		BaseY + Common.Range(-60, 60),
		-LevelBoundaryMax + CellZ * CellSize + Common.Range(-100, CellSize + 100),
	}
end

function AddSurface(Surface: { [string]: unknown }): number
	const Id = #Surfaces
	const Normal = Surface.normal
	const Vertex1, Vertex2, Vertex3 = Surface.vertex1, Surface.vertex2, Surface.vertex3

	Surfaces[Id + 1] = Surface
	IdOf[Surface] = Id

	Emit(
		Tokens(
			"surf", I(Id), I(Surface.type_), I(Surface.force), I(Surface.flags), I(Surface.room), I(Surface.lowerY), I(Surface.upperY),
			I(Vertex1[1]), I(Vertex1[2]), I(Vertex1[3]), I(Vertex2[1]), I(Vertex2[2]), I(Vertex2[3]), I(Vertex3[1]), I(Vertex3[2]), I(Vertex3[3]),
			F(Normal.x), F(Normal.y), F(Normal.z), F(Surface.originOffset)
		),
		nil
	)

	return Id
end

function AddCell(Dynamic: number, CellZ: number, CellX: number, List: number, Ids: { number })
	const Partition = if Dynamic == 1 then SurfaceLoad.gDynamicSurfacePartition else SurfaceLoad.gStaticSurfacePartition
	local Tail = Partition[CellZ + 1][CellX + 1][List + 1]
	const Words = { "cell", I(Dynamic), I(CellZ), I(CellX), I(List), I(#Ids) }

	for _, Id in Ids do
		const Node = { surface = Surfaces[Id + 1], next = nil }

		Tail.next = Node
		Tail = Node
		table.insert(Words, I(Id))
	end

	Emit(table.concat(Words, " "), nil)
end

function BuildScene()
	for _, Cell in Cells do
		const CellZ, CellX = Cell[1], Cell[2]

		for Dynamic = 0, 1 do
			for List = SPATIAL_PARTITION_FLOORS, SPATIAL_PARTITION_WALLS do
				const Ids = {}

				-- Floors and ceilings: usually two triangles that tile the cell, so lookups hit, then random ones that can win or lose against them
				if List ~= SPATIAL_PARTITION_WALLS and Common.Range(0, 9) < 7 then
					const BaseY = Common.Range(-400, 400)
					const X0 = -LevelBoundaryMax + CellX * CellSize - Common.Range(0, 40)
					const Z0 = -LevelBoundaryMax + CellZ * CellSize - Common.Range(0, 40)
					const X1 = X0 + CellSize + 80
					const Z1 = Z0 + CellSize + 80
					const Facing = if List == SPATIAL_PARTITION_FLOORS then 1 else -1
					const Type = FloorTypes[Common.Range(1, #FloorTypes)]

					table.insert(Ids, AddSurface(MakeSurface(Type, 0, { { X0, BaseY, Z0 }, { X1, BaseY + Common.Range(-60, 60), Z0 }, { X0, BaseY + Common.Range(-60, 60), Z1 } }, Facing)))
					table.insert(Ids, AddSurface(MakeSurface(Type, 0, { { X1, BaseY + Common.Range(-60, 60), Z1 }, { X0, BaseY + Common.Range(-60, 60), Z1 }, { X1, BaseY, Z0 } }, Facing)))
				end

				for _ = 1, Common.Range(0, 5) do
					local Surface

					if List == SPATIAL_PARTITION_WALLS then
						const Start = RandomVertex(CellX, CellZ, 0)
						const Stop = RandomVertex(CellX, CellZ, 0)
						const Low = Common.Range(-400, 200)
						const High = Low + Common.Range(30, 400)
						const Flags = Common.Range(0, 1) * 2

						Surface = MakeSurface(WallTypes[Common.Range(1, #WallTypes)], Flags, { { Start[1], Low, Start[3] }, { Stop[1], Low, Stop[3] }, { Start[1], High, Start[3] } }, 0)

						if math.abs(Surface.normal.x) > math.abs(Surface.normal.z) then
							Surface.flags += 8
						end

						table.insert(Walls, { Surface = Surface, Start = Start, Stop = Stop, Low = Low, High = High })
					else
						const BaseY = Common.Range(-400, 400)
						const Flags = Common.Range(0, 1) * 2

						Surface = MakeSurface(FloorTypes[Common.Range(1, #FloorTypes)], Flags, { RandomVertex(CellX, CellZ, BaseY), RandomVertex(CellX, CellZ, BaseY), RandomVertex(CellX, CellZ, BaseY) }, if List == SPATIAL_PARTITION_FLOORS then 1 else -1)
					end

					table.insert(Ids, AddSurface(Surface))
				end

				AddCell(Dynamic, CellZ, CellX, List, Ids)
			end
		end
	end
end

function RandomPosition(): (number, number, number)
	const Pick = Common.Range(0, 99)

	if Pick < 4 then
		const Extremes = { 8192, -8192, 8191.5, -8191.5, 40000, -40000, 1e10, -1e10, 0, -0.0 }

		return Common.F32(Extremes[Common.Range(1, #Extremes)]), Common.F32(Common.Range(-600, 600)), Common.F32(Extremes[Common.Range(1, #Extremes)])
	end

	const Cell = if Pick < 12 then { Common.Range(0, 15), Common.Range(0, 15) } else Cells[Common.Range(1, #Cells)]
	const Fraction = if Common.Range(0, 1) == 0 then 0 else Common.Range(0, 99) / 100

	return Common.F32(-LevelBoundaryMax + Cell[2] * CellSize + Common.Range(-50, CellSize + 50) + Fraction),
		Common.F32(Common.Range(-600, 600) + Fraction),
		Common.F32(-LevelBoundaryMax + Cell[1] * CellSize + Common.Range(-50, CellSize + 50) + Fraction)
end

-- A point near a wall: inside the lower half of its triangle seen from the side, up to 150 off the plane
function WallPosition(): (number, number, number)
	const Wall = Walls[Common.Range(1, #Walls)]
	const Along = Common.Range(5, 40) / 100
	const Away = Common.Range(-150, 150)
	const Normal = Wall.Surface.normal

	return Common.F32(Wall.Start[1] + (Wall.Stop[1] - Wall.Start[1]) * Along + Normal.x * Away),
		Common.F32(Wall.Low + Common.Range(0, (Wall.High - Wall.Low) // 3)),
		Common.F32(Wall.Start[3] + (Wall.Stop[3] - Wall.Start[3]) * Along + Normal.z * Away)
end

function Query(Kind: string, Args: { number }, Run: () -> { string })
	const Words = { Kind }

	for _, Value in Args do
		table.insert(Words, F(Value))
	end

	Emit(table.concat(Words, " "), Run)
end

function Globals()
	const Pick = Common.Range(0, 3)

	if Pick == 0 then
		const Value = Common.Range(0, 1)

		Emit(`camera {Value}`, function()
			ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = Value

			return nil
		end)
	elseif Pick == 1 then
		const Value = if Common.Range(0, 3) == 0 then 1 else 0

		Emit(`intangible {Value}`, function()
			ObjectListProcessor.gFindFloorIncludeSurfaceIntangible = Value

			return nil
		end)
	elseif Pick == 2 then
		const Mode = Common.Range(0, 3)

		Emit(`current {Mode}`, function()
			ObjectListProcessor.gCurrentObject = if Mode == 0 then nil elseif Mode == 1 then ObjectListProcessor.gMarioObject else OtherObject
			OtherObject.activeFlags = if Mode == 2 then ACTIVE_FLAG_MOVE_THROUGH_GRATE else 0

			return nil
		end)
	else
		const Flags = if Common.Range(0, 1) == 0 then MARIO_VANISH_CAP else 0

		Emit(`marioflags {string.format("%x", Flags)}`, function()
			LevelUpdate.gMarioState.flags = Flags

			return nil
		end)
	end
end

function BuildQueries()
	for Count = 1, QueriesPerKind do
		if Count % 3 == 0 then
			Globals()
		end

		local X, Y, Z = RandomPosition()

		if Common.Range(0, 99) < 45 then
			X, Y, Z = WallPosition()
		end

		const Radius = Common.F32(Common.Range(0, 250))
		const OffsetY = Common.F32(Common.Range(0, 160))

		Query("wall", { X, Y, Z, OffsetY, Radius }, function()
			const Data = { x = X, y = Y, z = Z, offsetY = OffsetY, radius = Radius, filler = buffer.create(2), numWalls = 0, walls = {} }
			const Count = SurfaceCollision.find_wall_collisions(Data)
			const Result = { "wall", I(Count), I(Data.numWalls), F(Data.x), F(Data.z) }

			for Index = 1, Data.numWalls do
				table.insert(Result, SurfaceId(Data.walls[Index]))
			end

			return Result
		end)

		Query("wall32", { X, Y, Z, OffsetY, Radius }, function()
			const XPtr, YPtr, ZPtr = { X }, { Y }, { Z }
			const Count = SurfaceCollision.f32_find_wall_collision(XPtr, YPtr, ZPtr, OffsetY, Radius)

			return { "wall32", I(Count), F(XPtr[1]), F(YPtr[1]), F(ZPtr[1]) }
		end)

		Query("ceil", { X, Y, Z }, function()
			const Out = {}
			const Height = SurfaceCollision.find_ceil(X, Y, Z, Out)

			return { "ceil", F(Height), SurfaceId(Out[1]) }
		end)

		Query("floor", { X, Y, Z }, function()
			const Out = {}
			const Height = SurfaceCollision.find_floor(X, Y, Z, Out)

			return { "floor", F(Height), SurfaceId(Out[1]), I(ObjectListProcessor.gFindFloorIncludeSurfaceIntangible) }
		end)

		Query("floordata", { X, Y, Z }, function()
			const Out = {}
			const Height = SurfaceCollision.find_floor_height_and_data(X, Y, Z, Out)
			const Result = { "floordata", F(Height), I(if Out[1] ~= nil then 1 else 0) }

			if Out[1] ~= nil then
				table.insert(Result, F(Out[1].normalX))
				table.insert(Result, F(Out[1].normalY))
				table.insert(Result, F(Out[1].normalZ))
				table.insert(Result, F(Out[1].originOffset))
			end

			return Result
		end)

		Query("floorh", { X, Y, Z }, function()
			return { "floorh", F(SurfaceCollision.find_floor_height(X, Y, Z)) }
		end)

		Query("dynfloor", { X, Y, Z }, function()
			const Out = {}
			const Height = SurfaceCollision.unused_find_dynamic_floor(X, Y, Z, Out)

			return { "dynfloor", F(Height), SurfaceId(Out[1]) }
		end)

		const CheckCeil = Common.Range(0, 1)

		Emit(`resolve {CheckCeil} {F(X)} {F(Y)} {F(Z)} {F(Radius)}`, function()
			const PX, PY, PZ = { X }, { Y }, { Z }
			const Out = {}
			const Height = { 0 }
			const Result = SurfaceCollision.unused_resolve_floor_or_ceil_collisions(CheckCeil, PX, PY, PZ, Radius, Out, Height)

			return { "resolve", I(Result), F(PX[1]), F(PY[1]), F(PZ[1]), F(Height[1]), SurfaceId(Out[1]) }
		end)

		if Count % 50 == 0 then
			Emit("counters", function()
				const Calls = ObjectListProcessor.gNumCalls

				return { "counters", I(Calls.floor), I(Calls.ceil), I(Calls.wall), I(ObjectListProcessor.gNumFindFloorMisses), I(ObjectListProcessor.gFindFloorIncludeSurfaceIntangible) }
			end)
		end
	end
end

-- The static lookups of a list: ints as the callers pass them (s16 values), and a wider range for the products that wrap in an s32
function BuildListQueries()
	for _, Cell in Cells do
		for Dynamic = 0, 1 do
			for List = SPATIAL_PARTITION_FLOORS, SPATIAL_PARTITION_WALLS do
				const CellZ, CellX = Cell[1], Cell[2]
				const Partition = if Dynamic == 1 then SurfaceLoad.gDynamicSurfacePartition else SurfaceLoad.gStaticSurfacePartition

				Emit(`listlen {Dynamic} {CellZ} {CellX} {List}`, function()
					return { "listlen", I(SurfaceCollision.surface_list_length(Partition[CellZ + 1][CellX + 1][List + 1].next)) }
				end)

				if List ~= SPATIAL_PARTITION_WALLS then
					for _ = 1, 25 do
						const Name = if List == SPATIAL_PARTITION_CEILS then "ceillist" else "floorlist"
						const Wide = Common.Range(0, 4) == 0
						const X = if Wide then Common.Range(-100000, 100000) else -LevelBoundaryMax + CellX * CellSize + Common.Range(-50, CellSize + 50)
						const Y = if Wide then Common.Range(-100000, 100000) else Common.Range(-600, 600)
						const Z = if Wide then Common.Range(-100000, 100000) else -LevelBoundaryMax + CellZ * CellSize + Common.Range(-50, CellSize + 50)
						const Height = Common.F32(if List == SPATIAL_PARTITION_CEILS then 20000 else -11000)

						Emit(`{Name} {Dynamic} {CellZ} {CellX} {X} {Y} {Z} {F(Height)}`, function()
							const PHeight = { Height }
							const Head = Partition[CellZ + 1][CellX + 1][List + 1].next
							const Surface = if List == SPATIAL_PARTITION_CEILS then SurfaceCollision.find_ceil_from_list(Head, X, Y, Z, PHeight) else SurfaceCollision.find_floor_from_list(Head, X, Y, Z, PHeight)

							return { Name, SurfaceId(Surface), F(PHeight[1]) }
						end)
					end
				end
			end
		end
	end
end

-- Regions of 6 words: value, loX, loZ, hiX, hiZ, height; water below 50, gas from 50 where the value is a multiple of 10
function BuildEnvironment()
	const Words = { 4 }

	for _ = 1, 4 do
		const Values = { 0, 10, 30, 50, 60, 55, 70 }
		const LoX = Common.Range(-3000, 1000)
		const LoZ = Common.Range(-3000, 1000)

		table.insert(Words, Values[Common.Range(1, #Values)])
		table.insert(Words, LoX)
		table.insert(Words, LoZ)
		table.insert(Words, LoX + Common.Range(100, 3000))
		table.insert(Words, LoZ + Common.Range(100, 3000))
		table.insert(Words, Common.Range(-500, 500))
	end

	for Phase = 1, 2 do
		if Phase == 1 then
			const Texts = {}

			for _, Word in Words do
				table.insert(Texts, I(Word))
			end

			Emit(`env {#Words} {table.concat(Texts, " ")}`, function()
				const Address = Rom.Allocate(2 * #Words)

				for Index, Word in Words do
					Rom.WriteS16(Address + 2 * (Index - 1), Word)
				end

				ObjectListProcessor.gEnvironmentRegions = Address

				return nil
			end)
		else
			Emit("noenv", function()
				ObjectListProcessor.gEnvironmentRegions = nil

				return nil
			end)
		end

		for _ = 1, 120 do
			-- mostly inside one of the boxes
			const Region = Common.Range(0, 3) * 6 + 2
			const Inside = Common.Range(0, 9) < 8
			const X = Common.F32((if Inside then Common.Range(Words[Region + 1] - 20, Words[Region + 3] + 20) else Common.Range(-3500, 4500)) + Common.Range(0, 99) / 100)
			const Z = Common.F32((if Inside then Common.Range(Words[Region + 2] - 20, Words[Region + 4] + 20) else Common.Range(-3500, 4500)) + Common.Range(0, 99) / 100)

			Query("water", { X, Z }, function()
				return { "water", F(SurfaceCollision.find_water_level(X, Z)) }
			end)

			Query("gas", { X, Z }, function()
				return { "gas", F(SurfaceCollision.find_poison_gas_level(X, Z)) }
			end)
		end
	end
end

Common.Seed(64)
BuildScene()
BuildEnvironment()
BuildListQueries()
Emit("camera 0", function()
	ObjectListProcessor.gCheckingSurfaceCollisionsForCamera = 0

	return nil
end)
Emit("intangible 0", function()
	ObjectListProcessor.gFindFloorIncludeSurfaceIntangible = 0

	return nil
end)
Emit("current 0", function()
	ObjectListProcessor.gCurrentObject = nil

	return nil
end)
Emit("marioflags 0", function()
	LevelUpdate.gMarioState.flags = 0

	return nil
end)
BuildQueries()
Emit("counters", function()
	const Calls = ObjectListProcessor.gNumCalls

	return { "counters", I(Calls.floor), I(Calls.ceil), I(Calls.wall), I(ObjectListProcessor.gNumFindFloorMisses), I(ObjectListProcessor.gFindFloorIncludeSurfaceIntangible) }
end)

const CaseLines = {}
const PortLines = {}

for _, Command in Commands do
	table.insert(CaseLines, Command.Text)

	if Command.Run ~= nil then
		const Result = Command.Run()

		if Result ~= nil then
			table.insert(PortLines, table.concat(Result, " "))
			table.insert(Labels, Command.Text)
		end
	end
end

const NativeLines = Common.RunNative(`{process.cwd()}/native/build/verify/surface_driver.exe`, CaseLines)
const Mismatches, Totals = Common.Diff(Labels, PortLines, NativeLines, ReportLimit)

local TotalMismatches = 0

for Name, Total in Totals do
	const Count = Mismatches[Name] or 0

	TotalMismatches += Count
	print(`{Name}: {Count} / {Total} mismatches`)
end

print(`total mismatches: {TotalMismatches} / {#PortLines}`)
