--!strict
--!optimize 2

--[[
	Port of src/game/paintings.c.

	Design Notes
		The mesh and the triangle normals are blocks of the effects pool, as in the C (mem_pool_alloc, mem_pool_free every frame): a
		PaintingMeshVertex is 10 bytes (pos s16[3], norm s8[3], padded) and a Vec3f 12, in native (little endian) order since only this
		file reads them. The Vtx of render_painting and the matrices are written big endian into the Gfx pool, as the renderer reads them.
		The callbacks return the Memory address of the display list built in the pool (the lists redirect the writer as intro_geo.c does).
		The painting records hold the segmented addresses of the level data (display lists, texture maps, textures).
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const PaintingsH = require("./paintings_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const Memory = require("./memory")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSm64H = require("../../include/sm64_h")
const RenderingGraphNode = require("./rendering_graph_node")
const SrcEngineSurfaceCollision = require("../engine/surface_collision")
const Area = require("./area")
const IncludeCourseTableH = require("../../include/course_table_h")
const PaintingData = require("../rom/painting_data")
const SaveFile = require("./save_file")
const SaveFileH = require("./save_file_h")
const Gbi = require("../rom/gbi")
const GeoMisc = require("./geo_misc")
const GeoMiscH = require("./geo_misc_h")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")

-- sizeof(struct PaintingMeshVertex) (pos s16[3], norm s8[3]) and sizeof(Vec3f)
const MeshVertexSize = 10
const Vec3fSize = 12

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/paintings.luau:scratch
const PaintingFloor: { GroupsTypesHPlus3.Surface? } = {}
-- from src/game/paintings.luau:scratch
const painting_state_id = { 0 }

-- from src/game/paintings.c:data
const paintings = {
	RIPPLE_LEFT = 0x20,
	RIPPLE_MIDDLE = 0x10,
	RIPPLE_RIGHT = 0x8,
	ENTER_LEFT = 0x4,
	ENTER_MIDDLE = 0x2,
	ENTER_RIGHT = 0x1,
	NEAREST_4TH = 30,
	MARIO_X = 40,
	MIDDLE_X = 50,
	MARIO_Y = 60,
	MARIO_Z = 70,
	MIDDLE_Y = 80,
	DONT_RESET = -56,
	RESET_TIMER = 100,
	-- from src/game/paintings.c:gPaintingMarioFloorType L138-138
	gPaintingMarioFloorType = 0,
	-- from src/game/paintings.c:gPaintingMarioXPos L140-140
	gPaintingMarioXPos = 0,
	-- from src/game/paintings.c:gPaintingMarioYPos L141-141
	gPaintingMarioYPos = 0,
	-- from src/game/moving_texture.c:gPaintingMarioYEntry L118-118 (moving_texture.c is not in the port: the global lives here, painting_state and end_peach_cutscene_fade_out write it)
	gPaintingMarioYEntry = 0,
	-- from src/game/paintings.c:gPaintingMarioZPos L142-142
	gPaintingMarioZPos = 0,
	-- from src/game/paintings.c:gPaintingMesh L150-150 (the Memory address of the effects pool block of PaintingMeshVertex records)
	gPaintingMesh = nil :: number?,
	-- from src/game/paintings.c:gPaintingTriNorms L155-155 (the Memory address of the effects pool block of Vec3f)
	gPaintingTriNorms = nil :: number?,
	-- from src/game/paintings.c:gRipplingPainting L160-160
	gRipplingPainting = nil :: PaintingsH.Painting?,
	-- from src/game/paintings.c:gDDDPaintingStatus L165-165
	gDDDPaintingStatus = 0,
	-- from src/game/paintings.c:sHMCPaintings L167-170
	sHMCPaintings = { PaintingData.cotmc_painting, nil } :: { PaintingsH.Painting? },
	-- from src/game/paintings.c:sInsideCastlePaintings L172-176
	sInsideCastlePaintings = {
			PaintingData.bob_painting,
			PaintingData.ccm_painting,
			PaintingData.wf_painting,
			PaintingData.jrb_painting,
			PaintingData.lll_painting,
			PaintingData.ssl_painting,
			PaintingData.hmc_painting,
			PaintingData.ddd_painting,
			PaintingData.wdw_painting,
			PaintingData.thi_tiny_painting,
			PaintingData.ttm_painting,
			PaintingData.ttc_painting,
			PaintingData.sl_painting,
			PaintingData.thi_huge_painting,
			nil,
		} :: { PaintingsH.Painting? },
	-- from src/game/paintings.c:sTTMPaintings L178-181
	sTTMPaintings = { PaintingData.ttm_slide_painting, nil } :: { PaintingsH.Painting? },
	-- from src/game/paintings.c:gPaintingUpdateCounter L189-189
	gPaintingUpdateCounter = 1,
	-- from src/game/paintings.c:gLastPaintingUpdateCounter L190-190
	gLastPaintingUpdateCounter = 0,
}

Registry.Register("src__game__paintings", paintings)

-- from src/game/paintings.c:stop_other_paintings L195-209
function paintings.stop_other_paintings(idptr: { number }, paintingGroup: { PaintingsH.Painting? })
	const Id = idptr[1]
	local Index = 1

	while paintingGroup[Index] ~= nil do
		const Painting = paintingGroup[Index] :: PaintingsH.Painting

		if Painting.id ~= Id then
			Painting.state = S8(0)
		end

		Index += 1
	end
end

-- from src/game/paintings.c:painting_mario_y L214-225
function paintings.painting_mario_y(painting: PaintingsH.Painting): number
	local RelY = F32(F32(paintings.gPaintingMarioYPos - painting.posY) + 50.0)

	if RelY < 0.0 then
		RelY = 0.0
	elseif RelY > painting.size then
		RelY = painting.size
	end

	return RelY
end

-- from src/game/paintings.c:painting_mario_z L230-239
function paintings.painting_mario_z(painting: PaintingsH.Painting): number
	local RelZ = F32(painting.posZ - paintings.gPaintingMarioZPos)

	if RelZ < 0.0 then
		RelZ = 0.0
	elseif RelZ > painting.size then
		RelZ = painting.size
	end

	return RelZ
end

-- from src/game/paintings.c:painting_ripple_y L245-260
function paintings.painting_ripple_y(painting: PaintingsH.Painting, ySource: number): number
	ySource = S8(TruncS32(ySource))
	if ySource == paintings.MARIO_Y then
		return paintings.painting_mario_y(painting)
	elseif ySource == paintings.MARIO_Z then
		return paintings.painting_mario_z(painting)
	elseif ySource == paintings.MIDDLE_Y then
		return painting.size / 2.0
	end

	return 0.0
end

-- from src/game/paintings.c:painting_nearest_4th L265-288
function paintings.painting_nearest_4th(painting: PaintingsH.Painting): number
	const FirstQuarter = F32(painting.size / 4.0)
	const SecondQuarter = F32(painting.size / 2.0)
	const ThirdQuarter = F32(F32(painting.size * 3.0) / 4.0)

	if bit32.btest(painting.floorEntered, paintings.RIPPLE_LEFT) then
		return FirstQuarter
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_MIDDLE) then
		return SecondQuarter
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_RIGHT) then
		return ThirdQuarter
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_LEFT) then
		return FirstQuarter
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_MIDDLE) then
		return SecondQuarter
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_RIGHT) then
		return ThirdQuarter
	end

	return 0.0
end

-- from src/game/paintings.c:painting_mario_x L293-302
function paintings.painting_mario_x(painting: PaintingsH.Painting): number
	local RelX = F32(paintings.gPaintingMarioXPos - painting.posX)

	if RelX < 0.0 then
		RelX = 0.0
	elseif RelX > painting.size then
		RelX = painting.size
	end

	return RelX
end

-- from src/game/paintings.c:painting_ripple_x L307-322
function paintings.painting_ripple_x(painting: PaintingsH.Painting, xSource: number): number
	xSource = S8(TruncS32(xSource))
	if xSource == paintings.NEAREST_4TH then
		return paintings.painting_nearest_4th(painting)
	elseif xSource == paintings.MARIO_X then
		return paintings.painting_mario_x(painting)
	elseif xSource == paintings.MIDDLE_X then
		return painting.size / 2.0
	end

	return 0.0
end

-- from src/game/paintings.c:painting_state L332-363
function paintings.painting_state(state: number, painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? }, xSource: number, ySource: number, resetTimer: number)
	state = S8(TruncS32(state))
	xSource = S8(TruncS32(xSource))
	ySource = S8(TruncS32(ySource))
	resetTimer = S8(TruncS32(resetTimer))
	-- make sure no other paintings are rippling
	painting_state_id[1] = painting.id
	paintings.stop_other_paintings(painting_state_id, paintingGroup)

	-- use a different set of variables depending on the state
	if state == PaintingsH.PAINTING_RIPPLE then
		painting.currRippleMag = painting.passiveRippleMag
		painting.rippleDecay = painting.passiveRippleDecay
		painting.currRippleRate = painting.passiveRippleRate
		painting.dispersionFactor = painting.passiveDispersionFactor
	elseif state == PaintingsH.PAINTING_ENTERED then
		painting.currRippleMag = painting.entryRippleMag
		painting.rippleDecay = painting.entryRippleDecay
		painting.currRippleRate = painting.entryRippleRate
		painting.dispersionFactor = painting.entryDispersionFactor
	end
	painting.state = S8(state)
	painting.rippleX = paintings.painting_ripple_x(painting, xSource)
	painting.rippleY = paintings.painting_ripple_y(painting, ySource)
	paintings.gPaintingMarioYEntry = paintings.gPaintingMarioYPos

	-- Because true or false would be too simple...
	if resetTimer == paintings.RESET_TIMER then
		painting.rippleTimer = 0
	end
	paintings.gRipplingPainting = painting
end

-- from src/game/paintings.c:wall_painting_proximity_idle L368-385
function paintings.wall_painting_proximity_idle(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.RIPPLE_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	end
end

-- from src/game/paintings.c:wall_painting_proximity_rippling L390-398
function paintings.wall_painting_proximity_rippling(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.ENTER_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	end
end

-- from src/game/paintings.c:wall_painting_continuous_idle L403-420
function paintings.wall_painting_continuous_idle(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.RIPPLE_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.RESET_TIMER))
	end
end

-- from src/game/paintings.c:wall_painting_continuous_rippling L425-433
function paintings.wall_painting_continuous_rippling(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.ENTER_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.DONT_RESET))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.DONT_RESET))
	elseif bit32.btest(painting.floorEntered, paintings.ENTER_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.NEAREST_4TH), S8(paintings.MARIO_Y), S8(paintings.DONT_RESET))
	end
end

-- from src/game/paintings.c:floor_painting_proximity_idle L440-459
function paintings.floor_painting_proximity_idle(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.RIPPLE_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	elseif painting.marioWentUnder ~= 0 then
		if bit32.btest(painting.currFloor, paintings.ENTER_LEFT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_MIDDLE) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_RIGHT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		end
	end
end

-- from src/game/paintings.c:floor_painting_proximity_rippling L466-476
function paintings.floor_painting_proximity_rippling(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if painting.marioWentUnder ~= 0 then
		if bit32.btest(painting.currFloor, paintings.ENTER_LEFT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_MIDDLE) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_RIGHT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
		end
	end
end

-- from src/game/paintings.c:floor_painting_continuous_idle L485-502
function paintings.floor_painting_continuous_idle(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if bit32.btest(painting.floorEntered, paintings.RIPPLE_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.floorEntered, paintings.RIPPLE_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_RIPPLE), painting, paintingGroup, S8(paintings.MIDDLE_X), S8(paintings.MIDDLE_Y), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.currFloor, paintings.ENTER_LEFT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.currFloor, paintings.ENTER_MIDDLE) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	elseif bit32.btest(painting.currFloor, paintings.ENTER_RIGHT) then
		paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.RESET_TIMER))
	end
end

-- from src/game/paintings.c:floor_painting_continuous_rippling L507-517
function paintings.floor_painting_continuous_rippling(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if painting.marioWentUnder ~= 0 then
		if bit32.btest(painting.currFloor, paintings.ENTER_LEFT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.DONT_RESET))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_MIDDLE) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.DONT_RESET))
		elseif bit32.btest(painting.currFloor, paintings.ENTER_RIGHT) then
			paintings.painting_state(S8(PaintingsH.PAINTING_ENTERED), painting, paintingGroup, S8(paintings.MARIO_X), S8(paintings.MARIO_Z), S8(paintings.DONT_RESET))
		end
	end
end

-- from src/game/paintings.c:painting_update_floors L522-574
function paintings.painting_update_floors(painting: PaintingsH.Painting)
	const PaintingId = painting.id
	local RippleLeft = S8(0)
	local RippleMiddle = S8(0)
	local RippleRight = S8(0)
	local EnterLeft = S8(0)
	local EnterMiddle = S8(0)
	local EnterRight = S8(0)

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WOBBLE_A6 then
		RippleLeft = S8(paintings.RIPPLE_LEFT)
	end

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WOBBLE_A7 then
		RippleMiddle = S8(paintings.RIPPLE_MIDDLE)
	end

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WOBBLE_A8 then
		RippleRight = S8(paintings.RIPPLE_RIGHT)
	end

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WARP_D3 then
		EnterLeft = S8(paintings.ENTER_LEFT)
	end

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WARP_D4 then
		EnterMiddle = S8(paintings.ENTER_MIDDLE)
	end

	if paintings.gPaintingMarioFloorType == PaintingId * 3 + IncludeSurfaceTerrainsH.SURFACE_PAINTING_WARP_D5 then
		EnterRight = S8(paintings.ENTER_RIGHT)
	end

	painting.lastFloor = painting.currFloor
	painting.currFloor = S8(RippleLeft + RippleMiddle + RippleRight + EnterLeft + EnterMiddle + EnterRight)
	painting.floorEntered = S8(bit32.band(bit32.bxor(painting.lastFloor, painting.currFloor), painting.currFloor))

	painting.marioWasUnder = painting.marioIsUnder

	if paintings.gPaintingMarioYPos < painting.posY then
		painting.marioIsUnder = S8(IncludePRUltratypesH.TRUE)
	else
		painting.marioIsUnder = S8(IncludePRUltratypesH.FALSE)
	end

	painting.marioWentUnder = S8(bit32.band(bit32.bxor(painting.marioWasUnder, painting.marioIsUnder), painting.marioIsUnder))
end

-- from src/game/paintings.c:painting_update_ripple_state L582-612
function paintings.painting_update_ripple_state(painting: PaintingsH.Painting)
	if paintings.gPaintingUpdateCounter ~= paintings.gLastPaintingUpdateCounter then
		painting.currRippleMag = F32(painting.currRippleMag * painting.rippleDecay)
		painting.rippleTimer = F32(painting.rippleTimer + 1.0)
	end

	if painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_PROXIMITY then
		if painting.currRippleMag <= 1.0 then
			painting.state = S8(PaintingsH.PAINTING_IDLE)
			paintings.gRipplingPainting = nil
		end
	elseif painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_CONTINUOUS then
		if painting.state == PaintingsH.PAINTING_ENTERED and painting.currRippleMag <= painting.passiveRippleMag then
			painting.state = S8(PaintingsH.PAINTING_RIPPLE)
			painting.currRippleMag = painting.passiveRippleMag
			painting.rippleDecay = painting.passiveRippleDecay
			painting.currRippleRate = painting.passiveRippleRate
			painting.dispersionFactor = painting.passiveDispersionFactor
		end
	end
end

-- from src/game/paintings.c:calculate_ripple_at_point L618-650
function paintings.calculate_ripple_at_point(painting: PaintingsH.Painting, posX: number, posY: number): number
	posX = F32(posX)
	posY = F32(posY)

	const RippleMag = painting.currRippleMag
	const RippleRate = painting.currRippleRate
	const DispersionFactor = painting.dispersionFactor
	const RippleTimer = painting.rippleTimer
	const RippleX = painting.rippleX
	const RippleY = painting.rippleY
	const SizeRatio = painting.size / PaintingsH.PAINTING_SIZE

	posX = F32(posX * SizeRatio)
	posY = F32(posY * SizeRatio)

	const DeltaX = F32(posX - RippleX)
	const DeltaY = F32(posY - RippleY)
	const DistanceToOrigin = F32(math.sqrt(F32(F32(DeltaX * DeltaX) + F32(DeltaY * DeltaY))))
	-- A larger dispersionFactor makes the ripple spread slower
	const RippleDistance = F32(DistanceToOrigin / DispersionFactor)

	if RippleTimer < RippleDistance then
		-- if the ripple hasn't reached the point yet, make the point magnitude 0
		return 0
	end

	-- use a cosine wave to make the ripple go up and down, scaled by the painting's ripple magnitude (cosf: the double cosine of the float argument, rounded to float)
	const RippleZ = F32(RippleMag * F32(math.cos(F32(RippleRate * (2 * math.pi) * F32(RippleTimer - RippleDistance)))))

	return GeoMisc.round_float(RippleZ)
end

-- from src/game/paintings.c:ripple_if_movable L656-663
function paintings.ripple_if_movable(painting: PaintingsH.Painting, movable: number, posX: number, posY: number): number
	movable = S16(TruncS32(movable))
	posX = S16(TruncS32(posX))
	posY = S16(TruncS32(posY))
	local RippleZ = S16(0)

	if movable ~= 0 then
		RippleZ = paintings.calculate_ripple_at_point(painting, posX, posY)
	end

	return RippleZ
end

-- from src/game/paintings.c:painting_generate_mesh L684-699 (mesh is the Memory address of the segment 2 table)
function paintings.painting_generate_mesh(painting: PaintingsH.Painting, mesh: number, numTris: number)
	numTris = S16(TruncS32(numTris))
	const Block = Memory.mem_pool_alloc(Memory.gEffectsMemoryPool :: number, numTris * MeshVertexSize) :: number

	paintings.gPaintingMesh = Block

	-- accesses are off by 1 since the first entry is the number of vertices
	for Index = 0, numTris - 1 do
		const Vertex = Block + Index * MeshVertexSize
		const PosX = Rom.ReadS16(mesh + 2 * (Index * 3 + 1))
		const PosY = Rom.ReadS16(mesh + 2 * (Index * 3 + 2))
		-- The "z coordinate" of each vertex in the mesh is either 1 or 0. Instead of being an actual coordinate, it just determines whether the vertex moves
		const PosZ = paintings.ripple_if_movable(painting, Rom.ReadS16(mesh + 2 * (Index * 3 + 3)), PosX, PosY)

		buffer.writei16(Rom.Memory, Vertex, PosX)
		buffer.writei16(Rom.Memory, Vertex + 2, PosY)
		buffer.writei16(Rom.Memory, Vertex + 4, PosZ)
	end
end

-- from src/game/paintings.c:painting_calculate_triangle_normals L716-745
function paintings.painting_calculate_triangle_normals(mesh: number, numVtx: number, numTris: number)
	numVtx = S16(TruncS32(numVtx))
	numTris = S16(TruncS32(numTris))
	const Mesh = paintings.gPaintingMesh :: number
	const TriNorms = Memory.mem_pool_alloc(Memory.gEffectsMemoryPool :: number, numTris * Vec3fSize) :: number

	paintings.gPaintingTriNorms = TriNorms

	for Index = 0, numTris - 1 do
		-- Add 2 because of the 2 length entries preceding the list
		const Tri = S16(numVtx * 3 + Index * 3 + 2)
		const Vertex0 = Mesh + Rom.ReadS16(mesh + 2 * Tri) * MeshVertexSize
		const Vertex1 = Mesh + Rom.ReadS16(mesh + 2 * (Tri + 1)) * MeshVertexSize
		const Vertex2 = Mesh + Rom.ReadS16(mesh + 2 * (Tri + 2)) * MeshVertexSize

		const X0 = buffer.readi16(Rom.Memory, Vertex0)
		const Y0 = buffer.readi16(Rom.Memory, Vertex0 + 2)
		const Z0 = buffer.readi16(Rom.Memory, Vertex0 + 4)
		const X1 = buffer.readi16(Rom.Memory, Vertex1)
		const Y1 = buffer.readi16(Rom.Memory, Vertex1 + 2)
		const Z1 = buffer.readi16(Rom.Memory, Vertex1 + 4)
		const X2 = buffer.readi16(Rom.Memory, Vertex2)
		const Y2 = buffer.readi16(Rom.Memory, Vertex2 + 2)
		const Z2 = buffer.readi16(Rom.Memory, Vertex2 + 4)

		const Dx10 = F32(X1 - X0)
		const Dy10 = F32(Y1 - Y0)
		const Dz10 = F32(Z1 - Z0)
		const Dx21 = F32(X2 - X1)
		const Dy21 = F32(Y2 - Y1)
		const Dz21 = F32(Z2 - Z1)
		const Normal = TriNorms + Index * Vec3fSize

		-- Cross product to find each triangle's normal vector
		buffer.writef32(Rom.Memory, Normal, F32(F32(Dy10 * Dz21) - F32(Dz10 * Dy21)))
		buffer.writef32(Rom.Memory, Normal + 4, F32(F32(Dz10 * Dx21) - F32(Dx10 * Dz21)))
		buffer.writef32(Rom.Memory, Normal + 8, F32(F32(Dx10 * Dy21) - F32(Dy10 * Dx21)))
	end
end

-- from src/game/paintings.c:normalize_component L751-762
function paintings.normalize_component(comp: number): number
	comp = F32(comp)
	local Rounded: number

	if comp > 0.0 then
		Rounded = S8(TruncS32(comp * 127.0 + 0.5))
	elseif comp < 0.0 then
		Rounded = S8(TruncS32(comp * 128.0 - 0.5))
	else
		Rounded = S8(0)
	end

	return Rounded
end

-- from src/game/paintings.c:painting_average_vertex_normals L779-820 (neighborTris is the Memory address of the segment 2 table)
function paintings.painting_average_vertex_normals(neighborTris: number, numVtx: number)
	numVtx = S16(TruncS32(numVtx))
	const Mesh = paintings.gPaintingMesh :: number
	const TriNorms = paintings.gPaintingTriNorms :: number
	local Entry = 0

	for Index = 0, numVtx - 1 do
		local Nx = 0.0
		local Ny = 0.0
		local Nz = 0.0
		-- The first number of each entry is the number of adjacent tris
		const Neighbors = Rom.ReadS16(neighborTris + 2 * Entry)

		for J = 0, Neighbors - 1 do
			const Normal = TriNorms + Rom.ReadS16(neighborTris + 2 * (Entry + J + 1)) * Vec3fSize

			Nx = F32(Nx + buffer.readf32(Rom.Memory, Normal))
			Ny = F32(Ny + buffer.readf32(Rom.Memory, Normal + 4))
			Nz = F32(Nz + buffer.readf32(Rom.Memory, Normal + 8))
		end

		-- Move to the next vertex's entry
		Entry = S16(Entry + Neighbors + 1)

		-- average the surface normals from each neighboring tri
		Nx = F32(Nx / Neighbors)
		Ny = F32(Ny / Neighbors)
		Nz = F32(Nz / Neighbors)

		const Nlen = F32(math.sqrt(F32(F32(F32(Nx * Nx) + F32(Ny * Ny)) + F32(Nz * Nz))))
		const Vertex = Mesh + Index * MeshVertexSize

		if Nlen == 0.0 then
			buffer.writei8(Rom.Memory, Vertex + 6, 0)
			buffer.writei8(Rom.Memory, Vertex + 7, 0)
			buffer.writei8(Rom.Memory, Vertex + 8, 0)
		else
			buffer.writei8(Rom.Memory, Vertex + 6, paintings.normalize_component(F32(Nx / Nlen)))
			buffer.writei8(Rom.Memory, Vertex + 7, paintings.normalize_component(F32(Ny / Nlen)))
			buffer.writei8(Rom.Memory, Vertex + 8, paintings.normalize_component(F32(Nz / Nlen)))
		end
	end
end

-- from src/game/paintings.c:render_painting L829-904 (img is a segmented texture address, textureMap the Memory address of the map)
function paintings.render_painting(img: number, tWidth: number, tHeight: number, textureMap: number, mapVerts: number, mapTris: number, alpha: number): number?
	tWidth = S16(TruncS32(tWidth))
	tHeight = S16(TruncS32(tHeight))
	mapVerts = S16(TruncS32(mapVerts))
	mapTris = S16(TruncS32(mapTris))
	alpha = bit32.band(alpha, 0xFF)

	-- We can fit 15 (16 / 3) vertices in the RSP's vertex buffer. Group triangles by 5, with one remainder group.
	const TriGroups = S16(mapTris // 5)
	const RemGroupTris = S16(math.fmod(mapTris, 5))
	const NumVtx = S16(mapTris * 3)
	const Commands = S16(TriGroups * 2 + RemGroupTris + 7)
	const Verts = Gbi.alloc_display_list(NumVtx * 16) :: number
	const Dlist = Gbi.alloc_display_list(Commands * 8)

	if Dlist == nil then
		return nil
	end

	const Mesh = paintings.gPaintingMesh :: number
	const Outer = Gbi.Redirect(Dlist)

	GeoMiscH.gLoadBlockTexture(tWidth, tHeight, Gbi.G_IM_FMT_RGBA, img)

	-- Draw the groups of 5 first
	for Group = 0, TriGroups - 1 do
		-- The triangle groups are the second part of the texture map. Each group is a list of 15 mappings
		const TriGroup = S16(mapVerts * 3 + Group * 15 + 2)

		for Map = 0, 14 do
			-- The mapping is just an index into the earlier part of the textureMap. Some mappings are repeated, for example, when multiple triangles share a vertex
			const Mapping = Rom.ReadS16(textureMap + 2 * (TriGroup + Map))
			-- The first entry is the ID of the vertex in the mesh
			const MeshVertex = Mesh + Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 1)) * MeshVertexSize
			-- The next two are the texture coordinates for that vertex
			const Tx = Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 2))
			const Ty = Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 3))

			-- Map the texture and place it in the verts array
			GeoMisc.make_vertex(Verts, Group * 15 + Map, buffer.readi16(Rom.Memory, MeshVertex), buffer.readi16(Rom.Memory, MeshVertex + 2), buffer.readi16(Rom.Memory, MeshVertex + 4), Tx, Ty, buffer.readi8(Rom.Memory, MeshVertex + 6), buffer.readi8(Rom.Memory, MeshVertex + 7), buffer.readi8(Rom.Memory, MeshVertex + 8), alpha)
		end

		-- Load the vertices and draw the 5 triangles
		Gbi.gSPVertex(Verts + Group * 15 * 16, 15, 0)
		Gbi.gSPDisplayList(Segment2Symbols.dl_paintings_draw_ripples)
	end

	-- One group left with < 5 triangles
	const TriGroup = S16(mapVerts * 3 + TriGroups * 15 + 2)

	-- Map the texture to the triangles
	for Map = 0, RemGroupTris * 3 - 1 do
		const Mapping = Rom.ReadS16(textureMap + 2 * (TriGroup + Map))
		const MeshVertex = Mesh + Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 1)) * MeshVertexSize
		const Tx = Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 2))
		const Ty = Rom.ReadS16(textureMap + 2 * (Mapping * 3 + 3))

		GeoMisc.make_vertex(Verts, TriGroups * 15 + Map, buffer.readi16(Rom.Memory, MeshVertex), buffer.readi16(Rom.Memory, MeshVertex + 2), buffer.readi16(Rom.Memory, MeshVertex + 4), Tx, Ty, buffer.readi8(Rom.Memory, MeshVertex + 6), buffer.readi8(Rom.Memory, MeshVertex + 7), buffer.readi8(Rom.Memory, MeshVertex + 8), alpha)
	end

	-- Draw the triangles individually
	Gbi.gSPVertex(Verts + TriGroups * 15 * 16, RemGroupTris * 3, 0)

	for Group = 0, RemGroupTris - 1 do
		Gbi.gSP1Triangle(Group * 3, Group * 3 + 1, Group * 3 + 2, 0)
	end

	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Outer)

	return Dlist
end

-- from src/game/paintings.c:painting_model_view_transform L909-933
function paintings.painting_model_view_transform(painting: PaintingsH.Painting): number
	const SizeRatio = F32(painting.size / PaintingsH.PAINTING_SIZE)
	const RotX = Gbi.alloc_display_list(64) :: number
	const RotY = Gbi.alloc_display_list(64) :: number
	const Translate = Gbi.alloc_display_list(64) :: number
	const Scale = Gbi.alloc_display_list(64) :: number
	const Dlist = Gbi.alloc_display_list(5 * 8) :: number

	Gbi.guTranslate(Translate, painting.posX, painting.posY, painting.posZ)
	Gbi.guRotate(RotX, painting.pitch, 1.0, 0.0, 0.0)
	Gbi.guRotate(RotY, painting.yaw, 0.0, 1.0, 0.0)
	Gbi.guScale(Scale, SizeRatio, SizeRatio, SizeRatio)

	const Outer = Gbi.Redirect(Dlist)

	Gbi.gSPMatrix(Translate, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_PUSH))
	Gbi.gSPMatrix(RotX, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	Gbi.gSPMatrix(RotY, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	Gbi.gSPMatrix(Scale, bit32.bor(Gbi.G_MTX_MODELVIEW, Gbi.G_MTX_MUL, Gbi.G_MTX_NOPUSH))
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Outer)

	return Dlist
end

-- from src/game/paintings.c:painting_ripple_image L938-974
function paintings.painting_ripple_image(painting: PaintingsH.Painting): number?
	const ImageCount = painting.imageCount
	const TWidth = painting.textureWidth
	const THeight = painting.textureHeight
	const TextureMaps = Memory.segmented_to_virtual(painting.textureMaps)
	const Textures = Memory.segmented_to_virtual(painting.textureArray)
	const Dlist = Gbi.alloc_display_list((ImageCount + 6) * 8)

	if Dlist == nil then
		return Dlist
	end

	const Outer = Gbi.Redirect(Dlist)

	Gbi.gSPDisplayList(paintings.painting_model_view_transform(painting))
	Gbi.gSPDisplayList(Segment2Symbols.dl_paintings_rippling_begin)
	Gbi.gSPDisplayList(painting.rippleDisplayList)

	-- Map each image to the mesh's vertices
	for Index = 0, ImageCount - 1 do
		const TextureMap = Memory.segmented_to_virtual(Rom.ReadU32(TextureMaps + 4 * Index))
		const MeshVerts = Rom.ReadS16(TextureMap)
		const MeshTris = Rom.ReadS16(TextureMap + 2 * (MeshVerts * 3 + 1))

		Gbi.gSPDisplayList(paintings.render_painting(Rom.ReadU32(Textures + 4 * Index), TWidth, THeight, TextureMap, MeshVerts, MeshTris, painting.alpha) :: number)
	end

	-- Update the ripple, may automatically reset the painting's state.
	paintings.painting_update_ripple_state(painting)

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPDisplayList(Segment2Symbols.dl_paintings_rippling_end)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Outer)

	return Dlist
end

-- from src/game/paintings.c:painting_ripple_env_mapped L979-1011
function paintings.painting_ripple_env_mapped(painting: PaintingsH.Painting): number?
	const TWidth = painting.textureWidth
	const THeight = painting.textureHeight
	const TextureMaps = Memory.segmented_to_virtual(painting.textureMaps)
	const TArray = Memory.segmented_to_virtual(painting.textureArray)
	const Dlist = Gbi.alloc_display_list(7 * 8)

	if Dlist == nil then
		return Dlist
	end

	const Outer = Gbi.Redirect(Dlist)

	Gbi.gSPDisplayList(paintings.painting_model_view_transform(painting))
	Gbi.gSPDisplayList(Segment2Symbols.dl_paintings_env_mapped_begin)
	Gbi.gSPDisplayList(painting.rippleDisplayList)

	-- Map the image to the mesh's vertices
	const TextureMap = Memory.segmented_to_virtual(Rom.ReadU32(TextureMaps))
	const MeshVerts = Rom.ReadS16(TextureMap)
	const MeshTris = Rom.ReadS16(TextureMap + 2 * (MeshVerts * 3 + 1))

	Gbi.gSPDisplayList(paintings.render_painting(Rom.ReadU32(TArray), TWidth, THeight, TextureMap, MeshVerts, MeshTris, painting.alpha) :: number)

	-- Update the ripple, may automatically reset the painting's state.
	paintings.painting_update_ripple_state(painting)

	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPDisplayList(Segment2Symbols.dl_paintings_env_mapped_end)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Outer)

	return Dlist
end

-- from src/game/paintings.c:display_painting_rippling L1017-1043
function paintings.display_painting_rippling(painting: PaintingsH.Painting): number?
	const mesh = Memory.segmented_to_virtual(Segment2Symbols.seg2_painting_triangle_mesh)
	const neighborTris = Memory.segmented_to_virtual(Segment2Symbols.seg2_painting_mesh_neighbor_tris)
	const numVtx = Rom.ReadS16(mesh)
	const numTris = Rom.ReadS16(mesh + 2 * (numVtx * 3 + 1))
	local dlist: number? = nil

	-- Generate the mesh and its lighting data
	paintings.painting_generate_mesh(painting, mesh, numVtx)
	paintings.painting_calculate_triangle_normals(mesh, numVtx, numTris)
	paintings.painting_average_vertex_normals(neighborTris, numVtx)

	-- Map the painting's texture depending on the painting's texture type.
	if painting.textureType == PaintingsH.PAINTING_IMAGE then
		dlist = paintings.painting_ripple_image(painting)
	elseif painting.textureType == PaintingsH.PAINTING_ENV_MAP then
		dlist = paintings.painting_ripple_env_mapped(painting)
	end

	-- The mesh data is freed every frame.
	Memory.mem_pool_free(Memory.gEffectsMemoryPool :: number, paintings.gPaintingMesh :: number)
	Memory.mem_pool_free(Memory.gEffectsMemoryPool :: number, paintings.gPaintingTriNorms :: number)

	return dlist
end

-- from src/game/paintings.c:display_painting_not_rippling L1048-1060
function paintings.display_painting_not_rippling(painting: PaintingsH.Painting): number?
	const Dlist = Gbi.alloc_display_list(4 * 8)

	if Dlist == nil then
		return Dlist
	end

	const Outer = Gbi.Redirect(Dlist)

	Gbi.gSPDisplayList(paintings.painting_model_view_transform(painting))
	Gbi.gSPDisplayList(painting.normalDisplayList)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPEndDisplayList()
	Gbi.Redirect(Outer)

	return Dlist
end

-- from src/game/paintings.c:reset_painting L1065-1093
function paintings.reset_painting(painting: PaintingsH.Painting)
	painting.lastFloor = S8(0)
	painting.currFloor = S8(0)
	painting.floorEntered = S8(0)
	painting.marioWasUnder = S8(0)
	painting.marioIsUnder = S8(0)
	painting.marioWentUnder = S8(0)

	paintings.gRipplingPainting = nil
end

-- from src/game/paintings.c:move_ddd_painting L1110-1139
function paintings.move_ddd_painting(painting: PaintingsH.Painting, frontPos: number, backPos: number, speed: number)
	frontPos = F32(frontPos)
	backPos = F32(backPos)
	speed = F32(speed)
	const DddFlags = SaveFile.save_file_get_star_flags(Area.gCurrSaveFileNum - 1, (IncludeCourseTableH.COURSE_NUM_TO_INDEX(IncludeCourseTableH.COURSE_DDD)))
	const SaveFileFlags = SaveFile.save_file_get_flags()
	const BowsersSubBeaten = bit32.band(DddFlags, PaintingsH.BOARD_BOWSERS_SUB)
	const DddBack = bit32.band(SaveFileFlags, SaveFileH.SAVE_FLAG_DDD_MOVED_BACK)

	if BowsersSubBeaten == 0 and DddBack == 0 then
		painting.posX = frontPos
		paintings.gDDDPaintingStatus = S8(0)
	elseif BowsersSubBeaten ~= 0 and DddBack == 0 then
		painting.posX = F32(painting.posX + speed)
		paintings.gDDDPaintingStatus = S8(PaintingsH.BOWSERS_SUB_BEATEN)

		if painting.posX >= backPos then
			painting.posX = backPos
			SaveFile.save_file_set_flags(SaveFileH.SAVE_FLAG_DDD_MOVED_BACK)
		end
	elseif BowsersSubBeaten ~= 0 and DddBack ~= 0 then
		painting.posX = backPos
		paintings.gDDDPaintingStatus = S8(bit32.bor(PaintingsH.BOWSERS_SUB_BEATEN, PaintingsH.DDD_BACK))
	end
end

-- from src/game/paintings.c:set_painting_layer L1144-1153
function paintings.set_painting_layer(gen: GroupsTypesHPlus3.GraphNodeGenerated, painting: PaintingsH.Painting)
	if painting.alpha == 0xFF then
		gen.fnNode.node.flags = S16(bit32.bor(bit32.band(gen.fnNode.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_OPAQUE, 8)))
	else
		gen.fnNode.node.flags = S16(bit32.bor(bit32.band(gen.fnNode.node.flags, 0xFF), bit32.lshift(IncludeSm64H.LAYER_TRANSPARENT, 8)))
	end
end

-- from src/game/paintings.c:display_painting L1158-1167
function paintings.display_painting(painting: PaintingsH.Painting): number?
	if painting.state == PaintingsH.PAINTING_IDLE then
		return paintings.display_painting_not_rippling(painting)
	end

	return paintings.display_painting_rippling(painting)
end

-- from src/game/paintings.c:wall_painting_update L1173-1193
function paintings.wall_painting_update(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_PROXIMITY then
		if painting.state == PaintingsH.PAINTING_IDLE then
			paintings.wall_painting_proximity_idle(painting, paintingGroup)
		elseif painting.state == PaintingsH.PAINTING_RIPPLE then
			paintings.wall_painting_proximity_rippling(painting, paintingGroup)
		end
	elseif painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_CONTINUOUS then
		if painting.state == PaintingsH.PAINTING_IDLE then
			paintings.wall_painting_continuous_idle(painting, paintingGroup)
		elseif painting.state == PaintingsH.PAINTING_RIPPLE then
			paintings.wall_painting_continuous_rippling(painting, paintingGroup)
		end
	end
end

-- from src/game/paintings.c:floor_painting_update L1201-1221
function paintings.floor_painting_update(painting: PaintingsH.Painting, paintingGroup: { PaintingsH.Painting? })
	if painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_PROXIMITY then
		if painting.state == PaintingsH.PAINTING_IDLE then
			paintings.floor_painting_proximity_idle(painting, paintingGroup)
		elseif painting.state == PaintingsH.PAINTING_RIPPLE then
			paintings.floor_painting_proximity_rippling(painting, paintingGroup)
		end
	elseif painting.rippleTrigger == PaintingsH.RIPPLE_TRIGGER_CONTINUOUS then
		if painting.state == PaintingsH.PAINTING_IDLE then
			paintings.floor_painting_continuous_idle(painting, paintingGroup)
		elseif painting.state == PaintingsH.PAINTING_RIPPLE then
			paintings.floor_painting_continuous_rippling(painting, paintingGroup)
		end
	end
end

-- from src/game/paintings.c:geo_painting_draw L1227-1263
function paintings.geo_painting_draw(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): number?
	const gen = node :: GroupsTypesHPlus3.GraphNodeGenerated
	const group = bit32.band(bit32.arshift(gen.parameter, 8), 0xFF)
	const id = bit32.band(gen.parameter, 0xFF)
	local paintingDlist: number? = nil
	const paintingGroup = paintings.sPaintingGroups[group + 1]
	-- segmented_to_virtual of a group element is the identity (painting-group-tables)
	const painting = paintingGroup[id + 1] :: PaintingsH.Painting

	if callContext ~= GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		paintings.reset_painting(painting)
	elseif callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		-- Update the ddd painting before drawing
		if group == 1 and id == PaintingsH.PAINTING_ID_DDD then
			paintings.move_ddd_painting(painting, 3456.0, F32(5529.6), 20.0)
		end

		-- Determine if the painting is transparent
		paintings.set_painting_layer(gen, painting)

		-- Draw before updating
		paintingDlist = paintings.display_painting(painting)

		-- Update the painting
		paintings.painting_update_floors(painting)

		-- only paintings with 0 pitch are treated as walls
		if S16(TruncS32(painting.pitch)) == 0 then
			paintings.wall_painting_update(painting, paintingGroup)
		else
			paintings.floor_painting_update(painting, paintingGroup)
		end
	end

	return paintingDlist
end

-- from src/game/paintings.c:geo_painting_update L1268-1287
function paintings.geo_painting_update(callContext: number, node: GroupsTypesHPlus3.GraphNode, c: { { number } }): number?
	if callContext ~= GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		paintings.gLastPaintingUpdateCounter = S16(RenderingGraphNode.gAreaUpdateCounter - 1)
		paintings.gPaintingUpdateCounter = S16(RenderingGraphNode.gAreaUpdateCounter)
	else
		paintings.gLastPaintingUpdateCounter = paintings.gPaintingUpdateCounter
		paintings.gPaintingUpdateCounter = S16(RenderingGraphNode.gAreaUpdateCounter)

		const MarioObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject
		const MarioX = buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosX)
		const MarioY = buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosY)
		const MarioZ = buffer.readf32(MarioObject.rawData, IncludeObjectFieldsH.oPosZ)

		SrcEngineSurfaceCollision.find_floor(MarioX, MarioY, MarioZ, PaintingFloor)

		paintings.gPaintingMarioFloorType = (PaintingFloor[1] :: GroupsTypesHPlus3.Surface).type_
		paintings.gPaintingMarioXPos = MarioX
		paintings.gPaintingMarioYPos = MarioY
		paintings.gPaintingMarioZPos = MarioZ
	end

	return nil
end

-- from src/game/paintings.c:sPaintingGroups L183-187
paintings.sPaintingGroups = { paintings.sHMCPaintings, paintings.sInsideCastlePaintings, paintings.sTTMPaintings }

return paintings
