--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_main.h.
]]

-- from src/goddard/gd_main.h:GdControl
export type GdControl = {
	unk00: number,
	filler1: buffer, -- [4]
	dleft: number,
	dright: number,
	dup: number,
	ddown: number,
	cleft: number,
	cright: number,
	cup: number,
	cdown: number,
	unk28: unknown,
	unk2C: unknown,
	unk30: unknown,
	btnA: number,
	btnB: number,
	filler2: buffer, -- [8]
	trgL: number,
	trgR: number,
	unk4C: number,
	unk50: number,
	newStartPress: number,
	filler3: buffer, -- [36]
	stickXf: number,
	stickYf: number,
	filler4: buffer, -- [4]
	unk88: number,
	filler5: buffer, -- [20]
	unkA0: number,
	filler6: buffer, -- [8]
	unkAC: number,
	filler7: buffer, -- [8]
	dragStartX: number,
	dragStartY: number,
	stickDeltaX: number,
	stickDeltaY: number,
	stickX: number,
	stickY: number,
	csrX: number,
	csrY: number,
	dragging: number,
	unkD8b40: number,
	unkD8b20: number,
	startedDragging: number,
	unkD8b08: number,
	unkD8b04: number,
	AbtnPressWait: number,
	dragStartFrame: number,
	filler8: buffer, -- [8]
	currFrame: number,
	filler9: buffer, -- [4]
	prevFrame: GdControl?,
}

const gd_main_h = {}

-- from src/goddard/gd_main.h:GdControl (zero-filled constructor)
function gd_main_h.new_GdControl(): GdControl
	return {
		unk00 = 0,
		filler1 = buffer.create(4),
		dleft = 0,
		dright = 0,
		dup = 0,
		ddown = 0,
		cleft = 0,
		cright = 0,
		cup = 0,
		cdown = 0,
		unk28 = nil,
		unk2C = nil,
		unk30 = nil,
		btnA = 0,
		btnB = 0,
		filler2 = buffer.create(8),
		trgL = 0,
		trgR = 0,
		unk4C = 0,
		unk50 = 0,
		newStartPress = 0,
		filler3 = buffer.create(36),
		stickXf = 0,
		stickYf = 0,
		filler4 = buffer.create(4),
		unk88 = 0,
		filler5 = buffer.create(20),
		unkA0 = 0,
		filler6 = buffer.create(8),
		unkAC = 0,
		filler7 = buffer.create(8),
		dragStartX = 0,
		dragStartY = 0,
		stickDeltaX = 0,
		stickDeltaY = 0,
		stickX = 0,
		stickY = 0,
		csrX = 0,
		csrY = 0,
		dragging = 0,
		unkD8b40 = 0,
		unkD8b20 = 0,
		startedDragging = 0,
		unkD8b08 = 0,
		unkD8b04 = 0,
		AbtnPressWait = 0,
		dragStartFrame = 0,
		filler8 = buffer.create(8),
		currFrame = 0,
		filler9 = buffer.create(4),
		prevFrame = nil,
	} :: GdControl
end

return gd_main_h
