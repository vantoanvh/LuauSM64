--!strict
--!optimize 2

--[[
	Converts recorded scene units to Roblox studs and identifies the graph passes drawn over the world.
]]

const Recorder = require("../../port/src/rom/render_recorder")
const Symbols = require("../../port/src/rom/symbols")

-- The lowest segmented address (segment 1); below it an address is a Memory offset
const SegmentedBase = 0x01000000
const TargetStudsPerUnit = 0.005
-- The closest near plane used by a world projection in the game (Big Boo's Haunt and the castle basement).
const MinimumGameNear = 50
const Camera = workspace.CurrentCamera :: Camera
const StudsPerUnit = math.max(TargetStudsPerUnit, -Camera.NearPlaneZ / MinimumGameNear)

-- The head scene builds its lists in the main pool; regular generated lists use the Gfx pool.
const function IsEngineList(Address: number): boolean
	return Address > 0 and Address < SegmentedBase and (Address < Symbols.GfxPool or Address >= Symbols.GfxPool + Symbols.GfxPoolSize)
end

const function DrawsEngineList(Pass: Recorder.Pass): boolean
	for _, Draw in Pass.Draws do
		const Address = Draw.DisplayList

		if type(Address) == "number" and IsEngineList(Address) then
			return true
		end
	end

	return false
end

-- A master list after the world can inherit the recorder's perspective while issuing its own fullscreen matrix.
const function ClassifyPass(Pass: Recorder.Pass): "background" | "world" | "foreground"
	if DrawsEngineList(Pass) then
		return "foreground"
	end

	if Pass.Projection ~= nil and not Pass.Projection.Perspective then
		return "background"
	end

	return if Pass.ZBuffer or Pass.View ~= nil then "world" else "foreground"
end

return { StudsPerUnit = StudsPerUnit, ClassifyPass = ClassifyPass, IsEngineList = IsEngineList }
