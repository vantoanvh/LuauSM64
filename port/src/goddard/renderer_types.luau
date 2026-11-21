--!strict
--!optimize 2

--[[
	Types of src/goddard/renderer.
]]

const GdTypesH = require("./gd_types_h")

-- from src/goddard/renderer.c:GdDisplayList
export type GdDisplayList = {
	curVtxIdx: number,
	totalVtx: number,
	vtx: number?,
	curMtxIdx: number,
	totalMtx: number,
	mtx: number?,
	curLightIdx: number,
	totalLights: number,
	light: number?,
	curGfxIdx: number,
	totalGfx: number,
	gfx: number?,
	dlptr: { number }?,
	curVpIdx: number,
	totalVp: number,
	vp: number?,
	id: number,
	number: number,
	filler: buffer, -- [4]
	parent: GdDisplayList?,
}

-- from src/goddard/renderer.c:LightDirVec
export type LightDirVec = {
	x: number,
	y: number,
	z: number,
}

-- from src/goddard/renderer.c:DynListBankInfo
export type DynListBankInfo = {
	flag: number,
	list: GdTypesH.DynList?,
}

const renderer_types = {}

-- from src/goddard/renderer.c:GdDisplayList (zero-filled constructor)
function renderer_types.new_GdDisplayList(): GdDisplayList
	return {
		curVtxIdx = 0,
		totalVtx = 0,
		vtx = nil,
		curMtxIdx = 0,
		totalMtx = 0,
		mtx = nil,
		curLightIdx = 0,
		totalLights = 0,
		light = nil,
		curGfxIdx = 0,
		totalGfx = 0,
		gfx = nil,
		dlptr = nil,
		curVpIdx = 0,
		totalVp = 0,
		vp = nil,
		id = 0,
		number = 0,
		filler = buffer.create(4),
		parent = nil,
	} :: GdDisplayList
end

-- from src/goddard/renderer.c:LightDirVec (zero-filled constructor)
function renderer_types.new_LightDirVec(): LightDirVec
	return { x = 0, y = 0, z = 0 } :: LightDirVec
end

-- from src/goddard/renderer.c:DynListBankInfo (zero-filled constructor)
function renderer_types.new_DynListBankInfo(): DynListBankInfo
	return { flag = 0, list = nil } :: DynListBankInfo
end

return renderer_types
