--!strict
--!optimize 2

--[[
	Port of src/goddard/gd_main.c.
]]

const GdMainH = require("./gd_main_h")

-- from src/goddard/gd_main.c:data
const gd_main = {
	-- from src/goddard/gd_main.c:gGdMoveScene L16-16
	gGdMoveScene = 1,
	-- from src/goddard/gd_main.c:sUnref801A8054 L17-17
	sUnref801A8054 = 1,
	-- from src/goddard/gd_main.c:D_801A8058 L18-18
	D_801A8058 = -600.0,
	-- from src/goddard/gd_main.c:gGdUseVtxNormal L19-19
	gGdUseVtxNormal = 1,
	-- from src/goddard/gd_main.c:sUnrefScnWidth L20-20
	sUnrefScnWidth = 320,
	-- from src/goddard/gd_main.c:sUnrefScnHeight L21-21
	sUnrefScnHeight = 240,
	-- from src/goddard/gd_main.c:gGdCtrl L24-24
	gGdCtrl = {
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
	} :: GdMainH.GdControl,
	-- from src/goddard/gd_main.c:gGdCtrlPrev L25-25
	gGdCtrlPrev = {
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
	} :: GdMainH.GdControl,
}

-- from src/goddard/gd_main.c:__main__ L30-61
function gd_main.__main__(): number
	error("stale")
end

return gd_main
