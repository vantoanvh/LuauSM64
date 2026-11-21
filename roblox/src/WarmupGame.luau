--!strict
--!optimize 2

--[[
	Prepares meshes and skyboxes before the game starts, including the actual attract-mode entrances: the game that roblox/src/Warmup runs
	in a copy of the modules.

	Paradigm
		This runs from a copy of the modules (roblox/src/Warmup makes it): the copy has its own game, its own ROM memory and its own
		presenter, so the real game, from the modules of the original, starts from its beginning, as the console does. What is shared is
		the presenter: the one this returns (the decoded entries and their parts) is the one the real game shows.

	Design Notes
		The game waits after each frame until the builds of its lists are done: a list reads the memory the scene has loaded, which the next
		scene changes. The game runs at the speed the builds allow, as the player sees nothing yet. A level is entered by the warp the
		harness uses (a hash run verified the game through it), its star select answered with A, and Mario kept at full health; the
		levels after the castle courtyard (26 and up) are not run: the game shows its course complete screen on entering them this way.
]]

const Area = require("../../port/src/game/area")
const Driver = require("./Driver")
const LevelTable = require("../../port/include/level_table_h")
const LevelUpdate = require("../../port/src/game/level_update")
const Presenter = require("./Presenter")
const Recorder = require("../../port/src/rom/render_recorder")
const Rom = require("../../port/src/rom/rom")
const Sky = require("./Sky")
const TitleScreen = require("../../port/src/menu/title_screen")

-- The frame the title is up and START is pressed (the logo plays before it), the frames of the file select that follow, and the frames
-- the game takes to play its intro (Lakitu, Mario's drop) and let Mario walk in the castle grounds
const StartFrame = 200
const FileSelectFrames = 260
const IntroFrames = 700
const DemoFrames = 120
const DemoReturnFrames = 90
-- The frames each level is run (its star select takes the first), the frames A is pressed in them, the first warp node and a full health
const LevelFrames = 240
const AnswerFrames = { [40] = true, [41] = true, [80] = true, [81] = true, [120] = true, [121] = true }
const WarpNode = 0x0A
const FullHealth = 0x880
const Start = 0x1000
const Confirm = 0x8000

const Levels = {
	{ Id = LevelTable.LEVEL_BBH, Name = "Big Boo's Haunt", StarSelect = true },
	{ Id = LevelTable.LEVEL_CCM, Name = "Cool, Cool Mountain", StarSelect = true },
	{ Id = LevelTable.LEVEL_HMC, Name = "Hazy Maze Cave", StarSelect = true },
	{ Id = LevelTable.LEVEL_SSL, Name = "Shifting Sand Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_BOB, Name = "Bob-omb Battlefield", StarSelect = true },
	{ Id = LevelTable.LEVEL_SL, Name = "Snowman's Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_WDW, Name = "Wet-Dry World", StarSelect = true },
	{ Id = LevelTable.LEVEL_JRB, Name = "Jolly Roger Bay", StarSelect = true },
	{ Id = LevelTable.LEVEL_THI, Name = "Tiny-Huge Island", StarSelect = true },
	{ Id = LevelTable.LEVEL_TTC, Name = "Tick Tock Clock", StarSelect = true },
	{ Id = LevelTable.LEVEL_RR, Name = "Rainbow Ride", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITDW, Name = "Bowser in the Dark World", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITFS, Name = "Bowser in the Fire Sea", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITS, Name = "Bowser in the Sky", StarSelect = true },
	{ Id = LevelTable.LEVEL_LLL, Name = "Lethal Lava Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_DDD, Name = "Dire, Dire Docks", StarSelect = true },
	{ Id = LevelTable.LEVEL_WF, Name = "Whomp's Fortress", StarSelect = true },
	{ Id = LevelTable.LEVEL_CASTLE, Name = "Peach's Castle", StarSelect = false },
	{ Id = LevelTable.LEVEL_CASTLE_GROUNDS, Name = "Castle Grounds", StarSelect = false },
	{ Id = LevelTable.LEVEL_VCUTM, Name = "Vanish Cap Under the Moat", StarSelect = false },
	{ Id = LevelTable.LEVEL_SA, Name = "Secret Aquarium", StarSelect = false },
}

const function Run(Image: buffer, Report: (number, string, string?) -> ()): (Presenter.Presenter, Sky.Backdrop)
	const Game = Driver.Load(Image, 0, nil)
	const View = Presenter.New()
	const Backdrop = Sky.New()
	const Pad = { Buttons = 0, StickX = 0, StickY = 0 }
	const DemoCount = Rom.ReadU32(Game.GameInit.gDemoInputsBuf.dmaTable :: number)
	const Total = StartFrame + FileSelectFrames + IntroFrames + #Levels * LevelFrames + DemoCount * (DemoFrames + DemoReturnFrames)
	local Frames = 0
	local Status = "Preparing title screen"
	local LastYield = os.clock()
	local LastAsset: string? = nil

	const function Stage(Name: string)
		Status = Name
		LastAsset = nil
		Report(Frames / Total, Status, "Scanning display lists")
	end

	Stage(Status)

	-- one frame of the game, its lists made before the next
	const function Advance(Buttons: number, Demo: number?)
		Pad.Buttons = Buttons

		Recorder.Begin()
		Driver.Step(Game, Pad)
		const Recorded = Recorder.End()

		Presenter.Warm(View, Recorded, if Game.GameInit.gCurrDemoInput ~= nil then Demo else nil)
		local SkyReady = Sky.Prepare(Backdrop, Recorded)

		while not (Presenter.Idle(View) and SkyReady) do
			const Asset = Presenter.PreloadAsset(View) or (if not SkyReady then "Baking skybox" else nil)

			if Asset ~= LastAsset then
				LastAsset = Asset
				Report(Frames / Total, Status, Asset or "Scanning display lists")
			end

			task.wait()
			LastYield = os.clock()

			if not SkyReady then
				SkyReady = Sky.Prepare(Backdrop, Recorded)
			end
		end

		Frames += 1

		if Frames % 30 == 0 or LastAsset ~= nil then
			LastAsset = nil
			Report(Frames / Total, Status, "Scanning display lists")

			if os.clock() - LastYield >= 1 / 60 then
				task.wait()
				LastYield = os.clock()
			end
		end
	end

	for _ = 1, StartFrame do
		Advance(0)
	end

	-- Use the demo level scripts and inputs. A warp from gameplay allocates different segments
	-- and can enter through a different area with different meshes in view.
	for Demo = 1, DemoCount do
		Stage(`Preparing demo {Demo}/{DemoCount}`)
		TitleScreen.sDemoCountdown = TitleScreen.PRESS_START_DEMO_TIMER - 1

		for _ = 1, DemoFrames do
			Advance(0, Demo)
		end

		for Frame = 1, DemoReturnFrames do
			-- Release START before the title accepts input again.
			Advance(if Frame == 1 then Start else 0)
		end
	end

	Stage("Preparing file select")

	for Frame = 1, FileSelectFrames do
		Advance(if Frame == 1 then Start else 0)
	end

	Stage("Preparing intro cutscene")

	for Frame = 1, IntroFrames do
		Advance(if Frame <= 2 then Confirm else 0)
	end

	for Index, Level in Levels do
		Stage(`Preparing {Level.Name} ({Index}/{#Levels})`)

		const Mario = LevelUpdate.gMarioStates[1]

		Mario.health = FullHealth
		LevelUpdate.initiate_warp(Level.Id, 1, WarpNode, 0)
		LevelUpdate.fade_into_special_warp(0, 0)
		Area.gSavedCourseNum = 0

		for Frame = 1, LevelFrames do
			Mario.health = FullHealth
			Advance(if Level.StarSelect and AnswerFrames[Frame] then Confirm else 0)
		end
	end

	Presenter.EndWarm(View)
	Report(1, Status, nil)

	return View, Backdrop
end

return Run
