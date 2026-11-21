--!strict
--!optimize 2

--[[
	Port of src/game/paintings.h.
]]

const Registry = require("../../groups/registry")

-- from src/game/paintings.h:Painting
export type Painting = {
	id: number,
	imageCount: number,
	textureType: number,
	lastFloor: number,
	currFloor: number,
	floorEntered: number,
	state: number,
	pitch: number,
	yaw: number,
	posX: number,
	posY: number,
	posZ: number,
	currRippleMag: number,
	passiveRippleMag: number,
	entryRippleMag: number,
	rippleDecay: number,
	passiveRippleDecay: number,
	entryRippleDecay: number,
	currRippleRate: number,
	passiveRippleRate: number,
	entryRippleRate: number,
	dispersionFactor: number,
	passiveDispersionFactor: number,
	entryDispersionFactor: number,
	rippleTimer: number,
	rippleX: number,
	rippleY: number,
	normalDisplayList: number,
	textureMaps: number,
	textureArray: number,
	textureWidth: number,
	textureHeight: number,
	rippleDisplayList: number,
	rippleTrigger: number,
	alpha: number,
	marioWasUnder: number,
	marioIsUnder: number,
	marioWentUnder: number,
	size: number,
}

-- from src/game/paintings.h:PaintingMeshVertex
export type PaintingMeshVertex = {
	pos: { number }, -- [3]
	norm: buffer, -- [3]
}

-- from src/game/paintings.h:data
const paintings_h = {
	PAINTING_SIZE = 614.0,
	PAINTING_ID_DDD = 7,
	BOARD_BOWSERS_SUB = 1,
	BOWSERS_SUB_BEATEN = 0x2,
	DDD_BACK = 0x1,
	PAINTING_IDLE = 0,
	PAINTING_RIPPLE = 1,
	PAINTING_ENTERED = 2,
	RIPPLE_TRIGGER_PROXIMITY = 10,
	RIPPLE_TRIGGER_CONTINUOUS = 20,
	PAINTING_IMAGE = 0,
	PAINTING_ENV_MAP = 1,
}

Registry.Register("src__game__paintings_h", paintings_h)

-- from src/game/paintings.h:Painting (zero-filled constructor)
function paintings_h.new_Painting(): Painting
	return {
		id = 0,
		imageCount = 0,
		textureType = 0,
		lastFloor = 0,
		currFloor = 0,
		floorEntered = 0,
		state = 0,
		pitch = 0,
		yaw = 0,
		posX = 0,
		posY = 0,
		posZ = 0,
		currRippleMag = 0,
		passiveRippleMag = 0,
		entryRippleMag = 0,
		rippleDecay = 0,
		passiveRippleDecay = 0,
		entryRippleDecay = 0,
		currRippleRate = 0,
		passiveRippleRate = 0,
		entryRippleRate = 0,
		dispersionFactor = 0,
		passiveDispersionFactor = 0,
		entryDispersionFactor = 0,
		rippleTimer = 0,
		rippleX = 0,
		rippleY = 0,
		normalDisplayList = 0,
		textureMaps = 0,
		textureArray = 0,
		textureWidth = 0,
		textureHeight = 0,
		rippleDisplayList = 0,
		rippleTrigger = 0,
		alpha = 0,
		marioWasUnder = 0,
		marioIsUnder = 0,
		marioWentUnder = 0,
		size = 0,
	} :: Painting
end

-- from src/game/paintings.h:PaintingMeshVertex (zero-filled constructor)
function paintings_h.new_PaintingMeshVertex(): PaintingMeshVertex
	return { pos = table.create(3, 0), norm = buffer.create(3) } :: PaintingMeshVertex
end

-- from src/game/paintings.h:PAINTING_ID L11-11
function paintings_h.PAINTING_ID(id: number, grp: number): number
	return bit32.bor(id, bit32.lshift(grp, 8))
end

return paintings_h
