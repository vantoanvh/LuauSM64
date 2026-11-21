--!nonstrict
--!optimize 2

--[[
	Loads real level collision data through the Luau port of src/engine/surface_load (from the ROM) and through the native vanilla
	loaders (native/build/verify/load_driver.exe, from the compiled C arrays of reference/levels), and diffs what they build: the
	surface pool, the partition lists, the environment regions, the allocation counters and where the spawners were called.

	Run from the repository root after native/verify/build.sh: lute run native/verify/verify_load.luau

	Where the data is in the ROM
		The collision, macro object and room lists of a level are in the level's segment 7 (a MIO0 block, loaded by LOAD_MIO0 in the
		level script); the segmented addresses are the "// 0x07xxxxxx" comments of the reference/levels sources. The MIO0 blocks
		were found by decompressing every MIO0 block of the ROM and searching for the bytes of the collision array at that
		segment offset (one block per level), and agree with the `18 0C 00 07 <start> <end>` LOAD_MIO0 commands of the level scripts.

	Commands (the case file of the native driver)
		area <name> <index>        load_area_terrain, then dump the pool and the static partition
		dynclear                   clear_dynamic_surfaces
		timestop <flags>           gTimeStopState
		object <model> <16 f32> <distance to Mario f32> <collision distance f32> <drawing distance f32> <activeFlags> <ddd 0|1>
		                           load_object_collision_model on a real object (native: struct Object, Luau: a pool Object with
		                           its rawData buffer) with that transformation and fields, then dump the dynamic surfaces and
		                           partition and the render flag and drawing distance the load left in the object
	The macro/special object spawners and the object helpers are stubs on both sides. The native special object spawner is the
	real one; the stub of the port moves the list pointer by the distance it logged.
]]

const Fs = require("@std/fs")
const Process = require("@std/process")

const Common = require("./common")
const GroupsIngameMenuPlus1 = require("../../port/groups/ingame_menu_plus1")
const IncludeObjectFieldsH = require("../../port/include/object_fields_h")
const MacroSpecialObjects = require("../../port/src/game/macro_special_objects")
const ObjectHelpers = require("../../port/src/game/object_helpers")
const ObjectListProcessor = require("../../port/src/game/object_list_processor")
const BehaviorIds = require("../../port/src/rom/behavior_ids")
const Rom = require("../../port/src/rom/rom")
const SurfaceLoad = require("../../port/src/engine/surface_load")

const RomPath = "rom/baserom.us.z64"
const ReportLimit = 12
const TimeStopActive = 64

-- RomStart: the MIO0 block of segment 7; the others are segmented addresses
const Areas = {
	{ Name = "bob_1", RomStart = 0x3FC2B0, Terrain = 0x0700E958, Macro = 0x0701104C },
	{ Name = "jrb_1", RomStart = 0x41A760, Terrain = 0x0700B058, Macro = 0x0700C4E8 },
	{ Name = "ccm_1", RomStart = 0x383950, Terrain = 0x070138E8, Macro = 0x07016284 },
	{ Name = "castle_inside_1", RomStart = 0x396340, Terrain = 0x07068B88, Rooms = 0x0707782C, Macro = 0x07077764 },
	{ Name = "bbh_1", RomStart = 0x371C40, Terrain = 0x070207A0, Rooms = 0x0702605C, Macro = 0x070268C4 },
	{ Name = "hmc_1", RomStart = 0x3D0DC0, Terrain = 0x07025594, Rooms = 0x0702ADC4, Macro = 0x0702AA78 },
	{ Name = "ddd_1", RomStart = 0x48D930, Terrain = 0x0700D310, Macro = 0x0700EEF4 },
	{ Name = "ttm_1", RomStart = 0x4D1910, Terrain = 0x07013814, Macro = 0x07016F18 },
}

const Models = {
	{ Name = "bob_chain_chomp_gate", RomStart = 0x3FC2B0, Address = 0x070113C0 },
	{ Name = "bob_bridge", RomStart = 0x3FC2B0, Address = 0x070113F0 },
	{ Name = "bob_gate", RomStart = 0x3FC2B0, Address = 0x07011474 },
	{ Name = "ddd_submarine", RomStart = 0x48D930, Address = 0x0700F17C },
}

const Cases: { { [string]: unknown } } = {}
const Lines: { string } = {}
const SpecialEnds: { number } = {}
const IdOf: { [unknown]: number } = {}

local AreaBase = 0
local EnvironmentBase = 0

const function F(Value: number): string
	return Common.FormatF32(Value)
end

const function I(Value: number): string
	return Common.FormatInt(Value)
end

const function Emit(Line: string)
	table.insert(Lines, Line)
end

const function FindByName(List: { { [string]: unknown } }, Name: string): { [string]: unknown }
	for _, Entry in List do
		if Entry.Name == Name then
			return Entry
		end
	end

	error(`unknown {Name}`)
end

function GroupsIngameMenuPlus1.reset_red_coins_collected()
	return
end

-- Real spawners walk the preset tables; here they log the call and move the special list by what the native ones did
function MacroSpecialObjects.spawn_special_objects(AreaIndex: number, SpecialObjList: { number })
	const Start = SpecialObjList[1]
	const End = table.remove(SpecialEnds, 1)

	SpecialObjList[1] = AreaBase + 2 * End
	Emit(`special {AreaIndex} {(Start - AreaBase) // 2} {End}`)
end

function MacroSpecialObjects.spawn_macro_objects(AreaIndex: number, MacroObjList: number)
	Emit(`macro {AreaIndex} {Rom.ReadS16(MacroObjList)}`)
end

function MacroSpecialObjects.spawn_macro_objects_hardcoded(AreaIndex: number, MacroObjList: number)
	Emit(`hardcoded {AreaIndex} {Rom.ReadS16(MacroObjList)}`)
end

-- The distance to Mario of the first frame, which load_object_collision_model replaces by dist_between_objects
function ObjectHelpers.dist_between_objects(obj1: unknown, obj2: unknown): number
	return 0
end

-- Scale 1: the transformation is used as it is
function ObjectHelpers.obj_apply_scale_to_matrix(obj: unknown, dst: { { number } }, src: { { number } })
	for Row = 1, 4 do
		for Column = 1, 4 do
			dst[Row][Column] = src[Row][Column]
		end
	end
end

const function DumpPartition(Label: string, Partition: { { { unknown } } })
	for Z = 1, 16 do
		for X = 1, 16 do
			for List = 1, 3 do
				local Node = Partition[Z][X][List].next
				local Count = 0

				if Node == nil then
					continue
				end

				const Ids: { string } = {}

				while Node ~= nil do
					Count += 1
					table.insert(Ids, I(IdOf[Node.surface]))
					Node = Node.next
				end

				Emit(`cell {Label} {Z - 1} {X - 1} {List - 1} {Count} {table.concat(Ids, " ")}`)
			end
		end
	end
end

const function DumpState(Label: string, First: number, Dynamic: boolean)
	const Regions = ObjectListProcessor.gEnvironmentRegions
	const Env = if Regions == nil then -1 else (Regions - EnvironmentBase) // 2
	const Levels: { string } = {}

	Emit(`state {Label} nodes {I(ObjectListProcessor.gSurfaceNodesAllocated)} surfaces {I(ObjectListProcessor.gSurfacesAllocated)} staticnodes {I(ObjectListProcessor.gNumStaticSurfaceNodes)} staticsurfaces {I(ObjectListProcessor.gNumStaticSurfaces)} env {I(Env)} unused {I(SurfaceLoad.unused8038BE90)}`)

	for Index = 1, 20 do
		Levels[Index] = I(ObjectListProcessor.gEnvironmentLevels[Index])
	end

	Emit(`levels {table.concat(Levels, " ")}`)

	for Index = First, ObjectListProcessor.gSurfacesAllocated - 1 do
		const S = SurfaceLoad.sSurfacePool[Index + 1]
		const Tokens = {
			"surf", I(Index), I(S.type_), I(S.force), I(S.flags), I(S.room), I(S.lowerY), I(S.upperY),
			I(S.vertex1[1]), I(S.vertex1[2]), I(S.vertex1[3]), I(S.vertex2[1]), I(S.vertex2[2]), I(S.vertex2[3]),
			I(S.vertex3[1]), I(S.vertex3[2]), I(S.vertex3[3]),
			F(S.normal.x), F(S.normal.y), F(S.normal.z), F(S.originOffset), if S.object ~= nil then "1" else "0",
		}

		Emit(table.concat(Tokens, " "))
	end

	DumpPartition(if Dynamic then "dynamic" else "static", if Dynamic then SurfaceLoad.gDynamicSurfacePartition else SurfaceLoad.gStaticSurfacePartition)
end

-- Rotation about y and translation, scaled; rows are the basis vectors then the translation
const function RandomMatrix(Scale: number, Translation: number): { number }
	const Angle = Common.Range(0, 65535) * math.pi * 2 / 65536
	const Cos, Sin = Common.F32(math.cos(Angle) * Scale), Common.F32(math.sin(Angle) * Scale)

	return {
		Cos, 0, -Sin, 0,
		0, Common.F32(Scale), 0, 0,
		Sin, 0, Cos, 0,
		Common.Range(-Translation, Translation), Common.Range(-Translation, Translation), Common.Range(-Translation, Translation), 1,
	}
end

const function AddCase(Kind: string, Text: string, Args: { unknown }?)
	table.insert(Cases, { Kind = Kind, Text = Text, Args = Args })
end

-- Fields of the object besides its transformation: the defaults load the model, in range and in the current room
const Loaded = { MarioDist = 0, CollisionDist = 1000, DrawingDist = 4000, ActiveFlags = 0, Ddd = 0 }

const function AddObject(Model: string, Matrix: { number }, Overrides: { [string]: number }?)
	const Options: { [string]: number } = {}
	const Tokens: { string } = {}

	for Key, Default in Loaded do
		Options[Key] = if Overrides ~= nil and Overrides[Key] ~= nil then Overrides[Key] else Default
	end

	for Index, Value in Matrix do
		Tokens[Index] = F(Value)
	end

	table.insert(Tokens, F(Options.MarioDist))
	table.insert(Tokens, F(Options.CollisionDist))
	table.insert(Tokens, F(Options.DrawingDist))
	table.insert(Tokens, I(Options.ActiveFlags))
	table.insert(Tokens, I(Options.Ddd))

	AddCase("dynclear", "dynclear")
	AddCase("object", `object {Model} {table.concat(Tokens, " ")}`, { Model, Matrix, Options })
end

const function BuildCases()
	Common.Seed(7)

	for _, Area in Areas do
		AddCase("dynclear", "dynclear")
		AddCase("area", `area {Area.Name} 1`, { Area.Name })

		for _, Model in Models do
			if string.sub(Model.Name, 1, 3) ~= string.sub(Area.Name, 1, 3) then
				continue
			end

			AddObject(Model.Name, { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 })

			for _ = 1, 3 do
				AddObject(Model.Name, RandomMatrix(1, 3000))
			end

			AddObject(Model.Name, RandomMatrix(0.5, 3000))
			-- Far outside the s16 range: the float to s16 conversion
			AddObject(Model.Name, RandomMatrix(4, 40000))
			AddObject(Model.Name, { 1e5, 0, 0, 0, 0, 1e5, 0, 0, 0, 0, 1e5, 0, 4e9, -4e9, 3e9, 1 })

			-- The gates of load_object_collision_model: out of range, another room, the first frame distance, a collision
			-- distance that extends the drawing distance, the DDD warp room
			AddObject(Model.Name, RandomMatrix(1, 3000), { MarioDist = 1500 })
			AddObject(Model.Name, RandomMatrix(1, 3000), { MarioDist = 999, ActiveFlags = 8 })
			AddObject(Model.Name, RandomMatrix(1, 3000), { MarioDist = 19000, CollisionDist = 30000, DrawingDist = 5000 })
			AddObject(Model.Name, RandomMatrix(1, 3000), { CollisionDist = 6000, DrawingDist = 4000, MarioDist = 4500 })
			AddObject(Model.Name, RandomMatrix(1, 3000), { MarioDist = 4000, CollisionDist = 4000.5, DrawingDist = 100 })
			AddObject(Model.Name, RandomMatrix(1, 3000), { Ddd = 1 })

			if Model.Name == "bob_gate" then
				-- Time stop: the dynamic surfaces stay
				AddCase("timestop", "timestop 64", { TimeStopActive })
				AddObject(Model.Name, RandomMatrix(1, 3000))
				AddObject(Model.Name, RandomMatrix(1, 3000))
				AddCase("timestop", "timestop 0", { 0 })
			end
		end
	end
end

const function RunCase(Case: { [string]: unknown })
	if Case.Kind == "dynclear" then
		SurfaceLoad.clear_dynamic_surfaces()
	elseif Case.Kind == "timestop" then
		ObjectListProcessor.gTimeStopState = Case.Args[1]
	elseif Case.Kind == "area" then
		const Area = FindByName(Areas, Case.Args[1])

		Rom.LoadMio0(7, Area.RomStart)
		AreaBase = Rom.SegmentedToVirtual(Area.Terrain)
		EnvironmentBase = AreaBase

		const Rooms = if Area.Rooms ~= nil then Rom.SegmentedToVirtual(Area.Rooms) else nil

		SurfaceLoad.load_area_terrain(1, AreaBase, Rooms, Rom.SegmentedToVirtual(Area.Macro))
		DumpState(Area.Name, 0, false)
	else
		const Model = FindByName(Models, Case.Args[1])
		const Matrix = Case.Args[2]
		const Options = Case.Args[3]
		const Object = ObjectListProcessor.gObjectPool[1]

		buffer.fill(Object.rawData, 0, 0)
		Object.activeFlags = Options.ActiveFlags
		Object.behavior = if Options.Ddd == 1 then Rom.SegmentedToVirtual(BehaviorIds.bhvDDDWarp) else nil
		Object.header.gfx.node.flags = 0
		Object.transform = {}

		for Row = 1, 4 do
			Object.transform[Row] = { Matrix[Row * 4 - 3], Matrix[Row * 4 - 2], Matrix[Row * 4 - 1], Matrix[Row * 4] }
		end

		Object.header.gfx.throwMatrix = { Object.transform }
		ObjectListProcessor.gCurrentObject = Object
		buffer.writef32(Object.rawData, IncludeObjectFieldsH.oDistanceToMario, Options.MarioDist)
		buffer.writef32(Object.rawData, IncludeObjectFieldsH.oCollisionDistance, Options.CollisionDist)
		buffer.writef32(Object.rawData, IncludeObjectFieldsH.oDrawingDistance, Options.DrawingDist)

		Rom.LoadMio0(7, Model.RomStart)
		AreaBase = Rom.SegmentedToVirtual(Model.Address)
		Object.collisionData = AreaBase

		SurfaceLoad.load_object_collision_model()

		DumpState(Model.Name, ObjectListProcessor.gNumStaticSurfaces, true)
		Emit(`objstate {Model.Name} {I(Object.header.gfx.node.flags)} {F(buffer.readf32(Object.rawData, IncludeObjectFieldsH.oDrawingDistance))}`)
	end
end

BuildCases()

const CaseLines: { string } = {}

for _, Case in Cases do
	table.insert(CaseLines, Case.Text)
end

const NativeLines = Common.RunNative(`{Process.cwd()}/native/build/verify/load_driver.exe`, CaseLines)

while NativeLines[#NativeLines] == "" do
	table.remove(NativeLines)
end

for _, Line in NativeLines do
	const End = string.match(Line, "^special %d+ %d+ (%d+)$")

	if End ~= nil then
		table.insert(SpecialEnds, tonumber(End))
	end
end

Rom.Load(buffer.fromstring(Fs.readFileToString(RomPath)))
SurfaceLoad.alloc_surface_pools()

for Index, Surface in SurfaceLoad.sSurfacePool do
	IdOf[Surface] = Index - 1
end

const Labels: { string } = {}

for _, Case in Cases do
	const Before = #Lines

	RunCase(Case)

	for _ = Before + 1, #Lines do
		table.insert(Labels, Case.Text)
	end
end

if #Lines ~= #NativeLines then
	print(`line count differs: port {#Lines}, native {#NativeLines}`)
end

const Mismatches, Totals = Common.Diff(Labels, Lines, NativeLines, ReportLimit)

local TotalMismatches = if #Lines ~= #NativeLines then math.abs(#Lines - #NativeLines) else 0

for Name, Total in Totals do
	const Count = Mismatches[Name] or 0

	TotalMismatches += Count
	print(`{Name}: {Count} / {Total} mismatches`)
end

print(`total mismatches: {TotalMismatches} / {#Lines}`)
