--!strict
--!optimize 2

--[[
	Port of src/engine/surface_collision.c.

	Design Notes
		The C stack temporaries passed by address (f32 and Surface out pointers, WallCollisionData) are module level scratch tables: no allocation per call.
		An out pointer is a one element table, [1] is *p.
]]

const Registry = require("../../groups/registry")

const Rom = require("../rom/rom")

const GroupsTypesHPlus3Types = require("../../groups/types_h_plus3_types")

const SurfaceCollisionH = require("./surface_collision_h")
const SurfaceLoadH = require("./surface_load_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSm64H = require("../../include/sm64_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")

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

-- C float to s32 conversion; like the native x86-64 reference build, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

const Height = { 0 }
const DynamicHeight = { 0 }
const Floor: { GroupsTypesHPlus3Types.Surface? } = {}

-- from src/engine/surface_collision.c:f32_find_wall_collision:collision L160-160
const Collision = {
	x = 0,
	y = 0,
	z = 0,
	offsetY = 0,
	radius = 0,
	filler = buffer.create(2),
	numWalls = 0,
	walls = {},
} :: SurfaceCollisionH.WallCollisionData

-- from src/engine/surface_collision.c:data
const surface_collision = {
	-- from src/engine/surface_collision.c:sFloorGeo L372-372
	sFloorGeo = { filler = buffer.create(16), normalX = 0, normalY = 0, normalZ = 0, originOffset = 0 },
	-- from src/engine/surface_collision.c:unused8038BE50 L374-374
	unused8038BE50 = buffer.create(64),
}

Registry.Register("src__engine__surface_collision", surface_collision)

-- from src/engine/surface_collision.c:find_wall_collisions_from_list L19-154
function surface_collision.find_wall_collisions_from_list(surfaceNode: SurfaceLoadH.SurfaceNode?, data: SurfaceCollisionH.WallCollisionData): number
	local radius = data.radius
	const x = data.x
	const y = F32(data.y + data.offsetY)
	const z = data.z
	local numCols = 0

	-- Max collision radius = 200
	if radius > 200.0 then
		radius = 200.0
	end

	-- Stay in this loop until out of walls.
	while surfaceNode ~= nil do
		const surf = surfaceNode.surface :: GroupsTypesHPlus3Types.Surface

		surfaceNode = surfaceNode.next

		-- Exclude a large number of walls immediately to optimize.
		if y < surf.lowerY or y > surf.upperY then
			continue
		end

		const offset = F32(F32(F32(F32(surf.normal.x * x) + F32(surf.normal.y * y)) + F32(surf.normal.z * z)) + surf.originOffset)

		if offset < -radius or offset > radius then
			continue
		end

		const px = x
		const pz = z

		--! (Quantum Tunneling) Due to issues with the vertices walls choose and
		--  the fact they are floating point, certain floating point positions
		--  along the seam of two walls may collide with neither wall or both walls.
		if bit32.btest(surf.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_X_PROJECTION) then
			const w1 = -surf.vertex1[3]
			const w2 = -surf.vertex2[3]
			const w3 = -surf.vertex3[3]
			const y1 = surf.vertex1[2]
			const y2 = surf.vertex2[2]
			const y3 = surf.vertex3[2]

			if surf.normal.x > 0.0 then
				if F32(F32(F32(y1 - y) * F32(w2 - w1)) - F32(F32(w1 - -pz) * F32(y2 - y1))) > 0.0 then
					continue
				end

				if F32(F32(F32(y2 - y) * F32(w3 - w2)) - F32(F32(w2 - -pz) * F32(y3 - y2))) > 0.0 then
					continue
				end

				if F32(F32(F32(y3 - y) * F32(w1 - w3)) - F32(F32(w3 - -pz) * F32(y1 - y3))) > 0.0 then
					continue
				end
			else
				if F32(F32(F32(y1 - y) * F32(w2 - w1)) - F32(F32(w1 - -pz) * F32(y2 - y1))) < 0.0 then
					continue
				end

				if F32(F32(F32(y2 - y) * F32(w3 - w2)) - F32(F32(w2 - -pz) * F32(y3 - y2))) < 0.0 then
					continue
				end

				if F32(F32(F32(y3 - y) * F32(w1 - w3)) - F32(F32(w3 - -pz) * F32(y1 - y3))) < 0.0 then
					continue
				end
			end
		else
			const w1 = surf.vertex1[1]
			const w2 = surf.vertex2[1]
			const w3 = surf.vertex3[1]
			const y1 = surf.vertex1[2]
			const y2 = surf.vertex2[2]
			const y3 = surf.vertex3[2]

			if surf.normal.z > 0.0 then
				if F32(F32(F32(y1 - y) * F32(w2 - w1)) - F32(F32(w1 - px) * F32(y2 - y1))) > 0.0 then
					continue
				end

				if F32(F32(F32(y2 - y) * F32(w3 - w2)) - F32(F32(w2 - px) * F32(y3 - y2))) > 0.0 then
					continue
				end

				if F32(F32(F32(y3 - y) * F32(w1 - w3)) - F32(F32(w3 - px) * F32(y1 - y3))) > 0.0 then
					continue
				end
			else
				if F32(F32(F32(y1 - y) * F32(w2 - w1)) - F32(F32(w1 - px) * F32(y2 - y1))) < 0.0 then
					continue
				end

				if F32(F32(F32(y2 - y) * F32(w3 - w2)) - F32(F32(w2 - px) * F32(y3 - y2))) < 0.0 then
					continue
				end

				if F32(F32(F32(y3 - y) * F32(w1 - w3)) - F32(F32(w3 - px) * F32(y1 - y3))) < 0.0 then
					continue
				end
			end
		end

		-- Determine if checking for the camera or not.
		if Registry.Members.src__game__object_list_processor.gCheckingSurfaceCollisionsForCamera ~= 0 then
			if bit32.btest(surf.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_NO_CAM_COLLISION) then
				continue
			end
		else
			-- Ignore camera only surfaces.
			if surf.type_ == IncludeSurfaceTerrainsH.SURFACE_CAMERA_BOUNDARY then
				continue
			end

			-- If an object can pass through a vanish cap wall, pass through.
			if surf.type_ == IncludeSurfaceTerrainsH.SURFACE_VANISH_CAP_WALLS then
				-- If an object can pass through a vanish cap wall, pass through.
				if Registry.Members.src__game__object_list_processor.gCurrentObject ~= nil and bit32.btest(Registry.Members.src__game__object_list_processor.gCurrentObject.activeFlags, IncludeObjectConstantsH.ACTIVE_FLAG_MOVE_THROUGH_GRATE) then
					continue
				end

				-- If Mario has a vanish cap, pass through the vanish cap wall.
				if Registry.Members.src__game__object_list_processor.gCurrentObject ~= nil and Registry.Members.src__game__object_list_processor.gCurrentObject == Registry.Members.src__game__object_list_processor.gMarioObject and bit32.btest(Registry.Members.src__game__level_update.gMarioState.flags, IncludeSm64H.MARIO_VANISH_CAP) then
					continue
				end
			end
		end

		--! (Wall Overlaps) Because this doesn't update the x and z local variables,
		--  multiple walls can push mario more than is required.
		data.x = F32(data.x + F32(surf.normal.x * F32(radius - offset)))
		data.z = F32(data.z + F32(surf.normal.z * F32(radius - offset)))

		--! (Unreferenced Walls) Since this only returns the first four walls,
		--  this can lead to wall interaction being missed. Typically unreferenced walls
		--  come from only using one wall, however.
		if data.numWalls < 4 then
			data.walls[data.numWalls + 1] = surf
			data.numWalls = S16(data.numWalls + 1)
		end

		numCols += 1
	end

	return numCols
end

-- from src/engine/surface_collision.c:f32_find_wall_collision L159-179
function surface_collision.f32_find_wall_collision(xPtr: { number }, yPtr: { number }, zPtr: { number }, offsetY: number, radius: number): number
	offsetY = F32(offsetY)
	radius = F32(radius)
	Collision.offsetY = offsetY
	Collision.radius = radius

	Collision.x = xPtr[1]
	Collision.y = yPtr[1]
	Collision.z = zPtr[1]

	Collision.numWalls = 0

	const numCollisions = surface_collision.find_wall_collisions(Collision)

	xPtr[1] = Collision.x
	yPtr[1] = Collision.y
	zPtr[1] = Collision.z

	return numCollisions
end

-- from src/engine/surface_collision.c:find_wall_collisions L184-217
function surface_collision.find_wall_collisions(colData: SurfaceCollisionH.WallCollisionData): number
	local numCollisions = 0
	const x = S16(TruncS32(colData.x))
	const z = S16(TruncS32(colData.z))

	colData.numWalls = 0

	if x <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or x >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return numCollisions
	end

	if z <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or z >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return numCollisions
	end

	-- World (level) consists of a 16x16 grid. Find where the collision is on
	-- the grid (round toward -inf)
	const cellX = S16(bit32.band((x + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))
	const cellZ = S16(bit32.band((z + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))

	-- Check for surfaces belonging to objects.
	local node = Registry.Members.src__engine__surface_load.gDynamicSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_WALLS + 1].next

	numCollisions += surface_collision.find_wall_collisions_from_list(node, colData)

	-- Check for surfaces that are a part of level geometry.
	node = Registry.Members.src__engine__surface_load.gStaticSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_WALLS + 1].next
	numCollisions += surface_collision.find_wall_collisions_from_list(node, colData)

	-- Increment the debug tracker.
	Registry.Members.src__game__object_list_processor.gNumCalls.wall = S16(Registry.Members.src__game__object_list_processor.gNumCalls.wall + 1)

	return numCollisions
end

-- from src/engine/surface_collision.c:find_ceil_from_list L226-301
function surface_collision.find_ceil_from_list(surfaceNode: SurfaceLoadH.SurfaceNode?, x: number, y: number, z: number, pheight: { number }): GroupsTypesHPlus3Types.Surface?
	local ceil: GroupsTypesHPlus3Types.Surface? = nil

	ceil = nil

	-- Stay in this loop until out of ceilings.
	while surfaceNode ~= nil do
		const surf = surfaceNode.surface :: GroupsTypesHPlus3Types.Surface

		surfaceNode = surfaceNode.next

		const x1 = surf.vertex1[1]
		const z1 = surf.vertex1[3]
		const z2 = surf.vertex2[3]
		const x2 = surf.vertex2[1]

		-- Checking if point is in bounds of the triangle laterally.
		if S32(S32((z1 - z) * (x2 - x1)) - S32((x1 - x) * (z2 - z1))) > 0 then
			continue
		end

		-- Slight optimization by checking these later.
		const x3 = surf.vertex3[1]
		const z3 = surf.vertex3[3]

		if S32(S32((z2 - z) * (x3 - x2)) - S32((x2 - x) * (z3 - z2))) > 0 then
			continue
		end

		if S32(S32((z3 - z) * (x1 - x3)) - S32((x3 - x) * (z1 - z3))) > 0 then
			continue
		end

		-- Determine if checking for the camera or not.
		if Registry.Members.src__game__object_list_processor.gCheckingSurfaceCollisionsForCamera ~= 0 then
			if bit32.btest(surf.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_NO_CAM_COLLISION) then
				continue
			end
		-- Ignore camera only surfaces.
		elseif surf.type_ == IncludeSurfaceTerrainsH.SURFACE_CAMERA_BOUNDARY then
			continue
		end

		do
			const nx = surf.normal.x
			const ny = surf.normal.y
			const nz = surf.normal.z
			const oo = surf.originOffset

			-- If a wall, ignore it. Likely a remnant, should never occur.
			if ny == 0.0 then
				continue
			end

			-- Find the ceil height at the specific point.
			const height = F32(-F32(F32(F32(x * nx) + F32(nz * z)) + oo) / ny)

			-- Checks for ceiling interaction with a 78 unit buffer.
			--! (Exposed Ceilings) Because any point above a ceiling counts
			--  as interacting with a ceiling, ceilings far below can cause
			-- "invisible walls" that are really just exposed ceilings.
			if F32(y - F32(height - -78.0)) > 0.0 then
				continue
			end

			pheight[1] = height
			ceil = surf

			break
		end
	end

	--! (Surface Cucking) Since only the first ceil is returned and not the lowest,
	--  lower ceilings can be "cucked" by higher ceilings.
	return ceil
end

-- from src/engine/surface_collision.c:find_ceil L306-354
function surface_collision.find_ceil(posX: number, posY: number, posZ: number, pceil: { GroupsTypesHPlus3Types.Surface? }): number
	posX = F32(posX)
	posY = F32(posY)
	posZ = F32(posZ)
	Height[1] = SurfaceCollisionH.CELL_HEIGHT_LIMIT
	DynamicHeight[1] = SurfaceCollisionH.CELL_HEIGHT_LIMIT

	--! (Parallel Universes) Because position is casted to an s16, reaching higher
	--  float locations can return ceilings despite them not existing there.
	--  (Dynamic ceilings will unload due to the range.)
	const x = S16(TruncS32(posX))
	const y = S16(TruncS32(posY))
	const z = S16(TruncS32(posZ))

	pceil[1] = nil

	if x <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or x >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return Height[1]
	end

	if z <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or z >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return Height[1]
	end

	-- Each level is split into cells to limit load, find the appropriate cell.
	const cellX = S16(bit32.band((x + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))
	const cellZ = S16(bit32.band((z + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))

	-- Check for surfaces belonging to objects.
	local surfaceList = Registry.Members.src__engine__surface_load.gDynamicSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_CEILS + 1].next
	const dynamicCeil = surface_collision.find_ceil_from_list(surfaceList, x, y, z, DynamicHeight)

	-- Check for surfaces that are a part of level geometry.
	surfaceList = Registry.Members.src__engine__surface_load.gStaticSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_CEILS + 1].next

	local ceil = surface_collision.find_ceil_from_list(surfaceList, x, y, z, Height)

	if DynamicHeight[1] < Height[1] then
		ceil = dynamicCeil
		Height[1] = DynamicHeight[1]
	end

	pceil[1] = ceil

	-- Increment the debug tracker.
	Registry.Members.src__game__object_list_processor.gNumCalls.ceil = S16(Registry.Members.src__game__object_list_processor.gNumCalls.ceil + 1)

	return Height[1]
end

-- from src/engine/surface_collision.c:unused_obj_find_floor_height L363-367
function surface_collision.unused_obj_find_floor_height(obj: GroupsTypesHPlus3Types.Object): number
	error("stale")
end

-- from src/engine/surface_collision.c:find_floor_height_and_data L381-396
function surface_collision.find_floor_height_and_data(xPos: number, yPos: number, zPos: number, floorGeo: { SurfaceCollisionH.FloorGeometry? }): number
	xPos = F32(xPos)
	yPos = F32(yPos)
	zPos = F32(zPos)
	const floorHeight = surface_collision.find_floor(xPos, yPos, zPos, Floor)

	floorGeo[1] = nil

	const floor = Floor[1]

	if floor ~= nil then
		surface_collision.sFloorGeo.normalX = floor.normal.x
		surface_collision.sFloorGeo.normalY = floor.normal.y
		surface_collision.sFloorGeo.normalZ = floor.normal.z
		surface_collision.sFloorGeo.originOffset = floor.originOffset

		floorGeo[1] = surface_collision.sFloorGeo
	end

	return floorHeight
end

-- from src/engine/surface_collision.c:find_floor_from_list L401-471
function surface_collision.find_floor_from_list(surfaceNode: SurfaceLoadH.SurfaceNode?, x: number, y: number, z: number, pheight: { number }): GroupsTypesHPlus3Types.Surface?
	local floor: GroupsTypesHPlus3Types.Surface? = nil

	-- Iterate through the list of floors until there are no more floors.
	while surfaceNode ~= nil do
		const surf = surfaceNode.surface :: GroupsTypesHPlus3Types.Surface

		surfaceNode = surfaceNode.next

		const x1 = surf.vertex1[1]
		const z1 = surf.vertex1[3]
		const x2 = surf.vertex2[1]
		const z2 = surf.vertex2[3]

		-- Check that the point is within the triangle bounds.
		if S32(S32((z1 - z) * (x2 - x1)) - S32((x1 - x) * (z2 - z1))) < 0 then
			continue
		end

		-- To slightly save on computation time, set this later.
		const x3 = surf.vertex3[1]
		const z3 = surf.vertex3[3]

		if S32(S32((z2 - z) * (x3 - x2)) - S32((x2 - x) * (z3 - z2))) < 0 then
			continue
		end

		if S32(S32((z3 - z) * (x1 - x3)) - S32((x3 - x) * (z1 - z3))) < 0 then
			continue
		end

		-- Determine if we are checking for the camera or not.
		if Registry.Members.src__game__object_list_processor.gCheckingSurfaceCollisionsForCamera ~= 0 then
			if bit32.btest(surf.flags, IncludeSurfaceTerrainsH.SURFACE_FLAG_NO_CAM_COLLISION) then
				continue
			end
		-- If we are not checking for the camera, ignore camera only floors.
		elseif surf.type_ == IncludeSurfaceTerrainsH.SURFACE_CAMERA_BOUNDARY then
			continue
		end

		const nx = surf.normal.x
		const ny = surf.normal.y
		const nz = surf.normal.z
		const oo = surf.originOffset

		-- If a wall, ignore it. Likely a remnant, should never occur.
		if ny == 0.0 then
			continue
		end

		-- Find the height of the floor at a given location.
		const height = F32(-F32(F32(F32(x * nx) + F32(nz * z)) + oo) / ny)

		-- Checks for floor interaction with a 78 unit buffer.
		if F32(y - F32(height + -78.0)) < 0.0 then
			continue
		end

		pheight[1] = height
		floor = surf

		break
	end

	--! (Surface Cucking) Since only the first floor is returned and not the highest,
	--  higher floors can be "cucked" by lower floors.
	return floor
end

-- from src/engine/surface_collision.c:find_floor_height L476-482
function surface_collision.find_floor_height(x: number, y: number, z: number): number
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const floorHeight = surface_collision.find_floor(x, y, z, Floor)

	return floorHeight
end

-- from src/engine/surface_collision.c:unused_find_dynamic_floor L488-508
function surface_collision.unused_find_dynamic_floor(xPos: number, yPos: number, zPos: number, pfloor: { GroupsTypesHPlus3Types.Surface? }): number
	xPos = F32(xPos)
	yPos = F32(yPos)
	zPos = F32(zPos)
	Height[1] = SurfaceCollisionH.FLOOR_LOWER_LIMIT

	-- Would normally cause PUs, but dynamic floors unload at that range.
	const x = S16(TruncS32(xPos))
	const y = S16(TruncS32(yPos))
	const z = S16(TruncS32(zPos))

	-- Each level is split into cells to limit load, find the appropriate cell.
	const cellX = S16(bit32.band(math.modf((x + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) / SurfaceCollisionH.CELL_SIZE), SurfaceLoadH.NUM_CELLS_INDEX))
	const cellZ = S16(bit32.band(math.modf((z + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) / SurfaceCollisionH.CELL_SIZE), SurfaceLoadH.NUM_CELLS_INDEX))

	const surfaceList = Registry.Members.src__engine__surface_load.gDynamicSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_FLOORS + 1].next
	const floor = surface_collision.find_floor_from_list(surfaceList, x, y, z, Height)

	pfloor[1] = floor

	return Height[1]
end

-- from src/engine/surface_collision.c:find_floor L513-582
function surface_collision.find_floor(xPos: number, yPos: number, zPos: number, pfloor: { GroupsTypesHPlus3Types.Surface? }): number
	xPos = F32(xPos)
	yPos = F32(yPos)
	zPos = F32(zPos)
	Height[1] = SurfaceCollisionH.FLOOR_LOWER_LIMIT
	DynamicHeight[1] = SurfaceCollisionH.FLOOR_LOWER_LIMIT

	--! (Parallel Universes) Because position is casted to an s16, reaching higher
	--  float locations can return floors despite them not existing there.
	--  (Dynamic floors will unload due to the range.)
	const x = S16(TruncS32(xPos))
	const y = S16(TruncS32(yPos))
	const z = S16(TruncS32(zPos))

	pfloor[1] = nil

	if x <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or x >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return Height[1]
	end

	if z <= -SurfaceCollisionH.LEVEL_BOUNDARY_MAX or z >= SurfaceCollisionH.LEVEL_BOUNDARY_MAX then
		return Height[1]
	end

	-- Each level is split into cells to limit load, find the appropriate cell.
	const cellX = S16(bit32.band((x + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))
	const cellZ = S16(bit32.band((z + SurfaceCollisionH.LEVEL_BOUNDARY_MAX) // SurfaceCollisionH.CELL_SIZE, SurfaceLoadH.NUM_CELLS_INDEX))

	-- Check for surfaces belonging to objects.
	local surfaceList = Registry.Members.src__engine__surface_load.gDynamicSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_FLOORS + 1].next
	const dynamicFloor = surface_collision.find_floor_from_list(surfaceList, x, y, z, DynamicHeight)

	-- Check for surfaces that are a part of level geometry.
	surfaceList = Registry.Members.src__engine__surface_load.gStaticSurfacePartition[cellZ + 1][cellX + 1][SurfaceLoadH.SPATIAL_PARTITION_FLOORS + 1].next

	local floor = surface_collision.find_floor_from_list(surfaceList, x, y, z, Height)

	-- To prevent the Merry-Go-Round room from loading when Mario passes above the hole that leads
	-- there, SURFACE_INTANGIBLE is used. This prevent the wrong room from loading, but can also allow
	-- Mario to pass through.
	if Registry.Members.src__game__object_list_processor.gFindFloorIncludeSurfaceIntangible == 0 then
		--! (BBH Crash) Most NULL checking is done by checking the height of the floor returned
		--  instead of checking directly for a NULL floor. If this check returns a NULL floor
		--  (happens when there is no floor under the SURFACE_INTANGIBLE floor) but returns the height
		--  of the SURFACE_INTANGIBLE floor instead of the typical -11000 returned for a NULL floor.
		if floor ~= nil and floor.type_ == IncludeSurfaceTerrainsH.SURFACE_INTANGIBLE then
			floor = surface_collision.find_floor_from_list(surfaceList, x, TruncS32(F32(Height[1] - 200.0)), z, Height)
		end
	else
		-- To prevent accidentally leaving the floor tangible, stop checking for it.
		Registry.Members.src__game__object_list_processor.gFindFloorIncludeSurfaceIntangible = IncludePRUltratypesH.FALSE
	end

	-- If a floor was missed, increment the debug counter.
	if floor == nil then
		Registry.Members.src__game__object_list_processor.gNumFindFloorMisses = S32(Registry.Members.src__game__object_list_processor.gNumFindFloorMisses + 1)
	end

	if DynamicHeight[1] > Height[1] then
		floor = dynamicFloor
		Height[1] = DynamicHeight[1]
	end

	pfloor[1] = floor

	-- Increment the debug tracker.
	Registry.Members.src__game__object_list_processor.gNumCalls.floor = S16(Registry.Members.src__game__object_list_processor.gNumCalls.floor + 1)

	return Height[1]
end

-- from src/engine/surface_collision.c:find_water_level L591-621
function surface_collision.find_water_level(x: number, z: number): number
	x = F32(x)
	z = F32(z)
	local numRegions: number
	local val: number
	local loX: number
	local loZ: number
	local hiX: number
	local hiZ: number
	local waterLevel = SurfaceCollisionH.FLOOR_LOWER_LIMIT
	local p = Registry.Members.src__game__object_list_processor.gEnvironmentRegions :: number?

	if p ~= nil then
		numRegions = Rom.ReadS16(p)
		p += 2

		for i = 0, numRegions - 1 do
			val = Rom.ReadS16(p)
			p += 2
			loX = Rom.ReadS16(p)
			p += 2
			loZ = Rom.ReadS16(p)
			p += 2
			hiX = Rom.ReadS16(p)
			p += 2
			hiZ = Rom.ReadS16(p)
			p += 2

			-- If the location is within a water box and it is a water box.
			-- Water is less than 50 val only, while above is gas and such.
			if loX < x and x < hiX and loZ < z and z < hiZ and val < 50 then
				-- Set the water height. Since this breaks, only return the first height.
				waterLevel = Rom.ReadS16(p)

				break
			end

			p += 2
		end
	end

	return waterLevel
end

-- from src/engine/surface_collision.c:find_poison_gas_level L626-661
function surface_collision.find_poison_gas_level(x: number, z: number): number
	x = F32(x)
	z = F32(z)
	local numRegions: number
	local val: number
	local loX: number
	local loZ: number
	local hiX: number
	local hiZ: number
	local gasLevel = SurfaceCollisionH.FLOOR_LOWER_LIMIT
	local p = Registry.Members.src__game__object_list_processor.gEnvironmentRegions :: number?

	if p ~= nil then
		numRegions = Rom.ReadS16(p)
		p += 2

		for i = 0, numRegions - 1 do
			val = Rom.ReadS16(p)

			if val >= 50 then
				loX = Rom.ReadS16(p + 2 * 1)
				loZ = Rom.ReadS16(p + 2 * 2)
				hiX = Rom.ReadS16(p + 2 * 3)
				hiZ = Rom.ReadS16(p + 2 * 4)

				-- If the location is within a gas's box and it is a gas box.
				-- Gas has a value of 50, 60, etc.
				if loX < x and x < hiX and loZ < z and z < hiZ and math.fmod(val, 10) == 0 then
					-- Set the gas height. Since this breaks, only return the first height.
					gasLevel = Rom.ReadS16(p + 2 * 5)

					break
				end
			end

			p += 2 * 6
		end
	end

	return gasLevel
end

-- from src/engine/surface_collision.c:surface_list_length L670-679
function surface_collision.surface_list_length(list: SurfaceLoadH.SurfaceNode?): number
	local count = 0

	while list ~= nil do
		list = list.next
		count += 1
	end

	return count
end

-- from src/engine/surface_collision.c:debug_surface_list_info L685-735
function surface_collision.debug_surface_list_info(xPos: number, zPos: number)
	-- The debug HUD text (print_debug_top_down_mapinfo, set_text_array_x_y) is not ported; only the counter reset remains
	Registry.Members.src__game__object_list_processor.gNumCalls.floor = 0
	Registry.Members.src__game__object_list_processor.gNumCalls.ceil = 0
	Registry.Members.src__game__object_list_processor.gNumCalls.wall = 0
end

-- from src/engine/surface_collision.c:unused_resolve_floor_or_ceil_collisions L741-779
function surface_collision.unused_resolve_floor_or_ceil_collisions(checkCeil: number, px: { number }, py: { number }, pz: { number }, radius: number, psurface: { GroupsTypesHPlus3Types.Surface? }, surfaceHeight: { number }): number
	radius = F32(radius)
	const x = px[1]
	const y = py[1]
	const z = pz[1]

	psurface[1] = nil

	if checkCeil ~= 0 then
		surfaceHeight[1] = surface_collision.find_ceil(x, y, z, psurface)
	else
		surfaceHeight[1] = surface_collision.find_floor(x, y, z, psurface)
	end

	const surface = psurface[1]

	if surface == nil then
		return -1
	end

	const nx = surface.normal.x
	const ny = surface.normal.y
	const nz = surface.normal.z
	const oo = surface.originOffset

	const offset = F32(F32(F32(F32(nx * x) + F32(ny * y)) + F32(nz * z)) + oo)
	const distance = if offset >= 0 then offset else -offset

	-- Interesting surface interaction that should be surf type independent.
	if distance < radius then
		px[1] = F32(px[1] + F32(nx * F32(radius - offset)))
		py[1] = F32(py[1] + F32(ny * F32(radius - offset)))
		pz[1] = F32(pz[1] + F32(nz * F32(radius - offset)))

		return 1
	end

	return 0
end

return surface_collision
