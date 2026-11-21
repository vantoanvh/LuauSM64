--!strict
--!optimize 2

--[[
	Prepares the meshes and skyboxes of the menus and the courses before the game starts: it runs a game (roblox/src/WarmupGame) in a copy of
	the modules and gives back the presenter and the sky that game made.

	Paradigm
		The modules keep the state of a game (the ROM memory, the game's globals, the presenter's tables), so the warm-up game and the game
		the player plays cannot be the same one: the real game, from the original modules, has to start from its beginning, as the console
		does. The warm-up game runs from a copy of the module folders (port, render, roblox) and the copy is dropped when it is done. Only the
		folders are copied, not the entry scripts beside them, so a copy cannot start a client of its own. What the player's game takes
		from the warm-up is the presenter and the sky, whose decoded entries and parts are the same in either game.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The game of the copy has the type of this one (it is the same module)
const WarmupGame = require("./WarmupGame")

-- Copies the module folders of the tree this module is in (its root is the folder SM64 of ReplicatedStorage)
const function CopyModules(): Folder
	const Root = script:FindFirstAncestor("SM64")

	assert(Root ~= nil, "Warmup is not inside the module tree SM64")

	const Copy = Instance.new("Folder")

	Copy.Name = "SM64Warmup"

	for _, Child in Root:GetChildren() do
		if Child:IsA("Folder") then
			Child:Clone().Parent = Copy
		end
	end

	return Copy
end

const function Warmup(Image: buffer, Report: (number, string, string?) -> ())
	const Copy = CopyModules()

	Copy.Parent = ReplicatedStorage

	const Module = Copy:FindFirstChild("WarmupGame", true)

	assert(Module ~= nil and Module:IsA("ModuleScript"), "the copy of the modules has no WarmupGame")

	const Run = require(Module) :: typeof(WarmupGame)
	const View, Backdrop = Run(Image, Report)

	Copy:Destroy()

	return View, Backdrop
end

return Warmup
