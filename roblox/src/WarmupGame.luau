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
		harness uses (a hash run verified the game through it), its star select answered with A, and Mario kept at full health. Every level
		is entered, and the areas of the levels that have several (the harness's warp traces say which); the credits are run by the warps the
		game makes between its scenes (the harness's credits trace), so that none of these builds meshes while the player plays.
]]

const Area = require("../../port/src/game/area")
const Driver = require("./Driver")
const LevelTable = require("../../port/include/level_table_h")
const LevelUpdate = require("../../port/src/game/level_update")
const LevelUpdateH = require("../../port/src/game/level_update_h")
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
-- A level with no star select to answer is run for less: its first frames build what it shows
const ShortLevelFrames = 120
const AnswerFrames = { [40] = true, [41] = true, [80] = true, [81] = true, [120] = true, [121] = true }
const WarpNode = 0x0A
-- The frames the credits take to start (the end cutscene in the castle grounds), and each credits scene is run (the game goes on to the next
-- one by a warp here, as the scenes take 220 frames each): the scenes are 21, the last is the castle grounds again
const CreditsGroundsFrames = 120
const CreditsStartFrames = 90
const CreditsSceneFrames = 60
const MaximumCreditsScenes = 30
const FullHealth = 0x880
const Start = 0x1000
const Confirm = 0x8000

-- Each visit: the level, its area and the warp node it is entered at (the destinations of the harness's warp traces), and whether it has a star
-- select to answer
const Levels = {
	{ Id = LevelTable.LEVEL_BBH, Area = 1, Node = WarpNode, Name = "Big Boo's Haunt", StarSelect = true },
	{ Id = LevelTable.LEVEL_CCM, Area = 1, Node = WarpNode, Name = "Cool, Cool Mountain", StarSelect = true },
	{ Id = LevelTable.LEVEL_CCM, Area = 2, Node = WarpNode, Name = "Cool, Cool Mountain, the slide", StarSelect = true },
	{ Id = LevelTable.LEVEL_HMC, Area = 1, Node = WarpNode, Name = "Hazy Maze Cave", StarSelect = true },
	{ Id = LevelTable.LEVEL_SSL, Area = 1, Node = WarpNode, Name = "Shifting Sand Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_SSL, Area = 2, Node = WarpNode, Name = "Shifting Sand Land, the pyramid", StarSelect = true },
	{ Id = LevelTable.LEVEL_BOB, Area = 1, Node = WarpNode, Name = "Bob-omb Battlefield", StarSelect = true },
	{ Id = LevelTable.LEVEL_SL, Area = 1, Node = WarpNode, Name = "Snowman's Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_SL, Area = 2, Node = WarpNode, Name = "Snowman's Land, the igloo", StarSelect = true },
	{ Id = LevelTable.LEVEL_WDW, Area = 1, Node = WarpNode, Name = "Wet-Dry World", StarSelect = true },
	{ Id = LevelTable.LEVEL_JRB, Area = 1, Node = WarpNode, Name = "Jolly Roger Bay", StarSelect = true },
	{ Id = LevelTable.LEVEL_JRB, Area = 2, Node = WarpNode, Name = "Jolly Roger Bay, the ship", StarSelect = true },
	{ Id = LevelTable.LEVEL_THI, Area = 1, Node = WarpNode, Name = "Tiny-Huge Island", StarSelect = true },
	{ Id = LevelTable.LEVEL_THI, Area = 2, Node = WarpNode, Name = "Tiny-Huge Island, small", StarSelect = true },
	{ Id = LevelTable.LEVEL_THI, Area = 3, Node = WarpNode, Name = "Tiny-Huge Island, the cave", StarSelect = true },
	{ Id = LevelTable.LEVEL_TTC, Area = 1, Node = WarpNode, Name = "Tick Tock Clock", StarSelect = true },
	{ Id = LevelTable.LEVEL_RR, Area = 1, Node = WarpNode, Name = "Rainbow Ride", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITDW, Area = 1, Node = WarpNode, Name = "Bowser in the Dark World", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITFS, Area = 1, Node = WarpNode, Name = "Bowser in the Fire Sea", StarSelect = true },
	{ Id = LevelTable.LEVEL_BITS, Area = 1, Node = WarpNode, Name = "Bowser in the Sky", StarSelect = true },
	{ Id = LevelTable.LEVEL_LLL, Area = 1, Node = WarpNode, Name = "Lethal Lava Land", StarSelect = true },
	{ Id = LevelTable.LEVEL_LLL, Area = 2, Node = WarpNode, Name = "Lethal Lava Land, the volcano", StarSelect = true },
	{ Id = LevelTable.LEVEL_DDD, Area = 1, Node = WarpNode, Name = "Dire, Dire Docks", StarSelect = true },
	{ Id = LevelTable.LEVEL_WF, Area = 1, Node = WarpNode, Name = "Whomp's Fortress", StarSelect = true },
	{ Id = LevelTable.LEVEL_TTM, Area = 1, Node = WarpNode, Name = "Tall, Tall Mountain", StarSelect = true },
	{ Id = LevelTable.LEVEL_TTM, Area = 2, Node = WarpNode, Name = "Tall, Tall Mountain, the slide", StarSelect = true },
	{ Id = LevelTable.LEVEL_CASTLE, Area = 1, Node = WarpNode, Name = "Peach's Castle", StarSelect = false },
	{ Id = LevelTable.LEVEL_CASTLE, Area = 2, Node = 0x01, Name = "Peach's Castle, upstairs", StarSelect = false },
	{ Id = LevelTable.LEVEL_CASTLE, Area = 3, Node = 0x01, Name = "Peach's Castle, the basement", StarSelect = false },
	{ Id = LevelTable.LEVEL_CASTLE_GROUNDS, Area = 1, Node = WarpNode, Name = "Castle Grounds", StarSelect = false },
	{ Id = LevelTable.LEVEL_CASTLE_COURTYARD, Area = 1, Node = 0x0B, Name = "Castle Courtyard", StarSelect = false },
	{ Id = LevelTable.LEVEL_VCUTM, Area = 1, Node = WarpNode, Name = "Vanish Cap Under the Moat", StarSelect = false },
	{ Id = LevelTable.LEVEL_SA, Area = 1, Node = WarpNode, Name = "Secret Aquarium", StarSelect = false },
	{ Id = LevelTable.LEVEL_PSS, Area = 1, Node = WarpNode, Name = "Princess's Secret Slide", StarSelect = false },
	{ Id = LevelTable.LEVEL_COTMC, Area = 1, Node = WarpNode, Name = "Cavern of the Metal Cap", StarSelect = false },
	{ Id = LevelTable.LEVEL_TOTWC, Area = 1, Node = WarpNode, Name = "Tower of the Wing Cap", StarSelect = false },
	{ Id = LevelTable.LEVEL_WMOTR, Area = 1, Node = WarpNode, Name = "Wing Mario Over the Rainbow", StarSelect = false },
	{ Id = LevelTable.LEVEL_BOWSER_1, Area = 1, Node = WarpNode, Name = "Bowser's first fight", StarSelect = false },
	{ Id = LevelTable.LEVEL_BOWSER_2, Area = 1, Node = WarpNode, Name = "Bowser's second fight", StarSelect = false },
	{ Id = LevelTable.LEVEL_BOWSER_3, Area = 1, Node = WarpNode, Name = "Bowser's third fight", StarSelect = false },
	{ Id = LevelTable.LEVEL_ENDING, Area = 1, Node = WarpNode, Name = "the ending", StarSelect = false },
}

const function Run(Image: buffer, Report: (number, string, string?) -> ()): (Presenter.Presenter, Sky.Backdrop)
	const Game = Driver.Load(Image, 0, nil)
	const View = Presenter.New()
	const Backdrop = Sky.New()
	const Pad = { Buttons = 0, StickX = 0, StickY = 0 }
	const DemoCount = Rom.ReadU32(Game.GameInit.gDemoInputsBuf.dmaTable :: number)
	const CreditsFrames = CreditsGroundsFrames + CreditsStartFrames + MaximumCreditsScenes * CreditsSceneFrames
	local LevelsTotal = 0

	for _, Level in Levels do
		LevelsTotal += if Level.StarSelect then LevelFrames else ShortLevelFrames
	end

	const Total = StartFrame + FileSelectFrames + IntroFrames + LevelsTotal + CreditsFrames + DemoCount * (DemoFrames + DemoReturnFrames)
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
		LevelUpdate.initiate_warp(Level.Id, Level.Area, Level.Node, 0)
		LevelUpdate.fade_into_special_warp(0, 0)
		Area.gSavedCourseNum = 0

		for Frame = 1, if Level.StarSelect then LevelFrames else ShortLevelFrames do
			Mario.health = FullHealth
			Advance(if Level.StarSelect and AnswerFrames[Frame] then Confirm else 0)
		end
	end

	-- the credits: the end cutscene in the castle grounds, then the scenes one after the other until the castle grounds come again
	Stage("Preparing the credits")

	const Mario = LevelUpdate.gMarioStates[1]

	Mario.health = FullHealth
	LevelUpdate.initiate_warp(LevelTable.LEVEL_CASTLE_GROUNDS, 1, WarpNode, 0)
	LevelUpdate.fade_into_special_warp(0, 0)
	Area.gSavedCourseNum = 0

	for _ = 1, CreditsGroundsFrames do
		Mario.health = FullHealth
		Advance(0)
	end

	LevelUpdate.level_trigger_warp(Mario, LevelUpdateH.WARP_OP_CREDITS_START)

	for _ = 1, CreditsStartFrames do
		Advance(0)
	end

	for _ = 1, MaximumCreditsScenes do
		LevelUpdate.level_trigger_warp(Mario, LevelUpdateH.WARP_OP_CREDITS_NEXT)

		for _ = 1, CreditsSceneFrames do
			Advance(0)
		end

		if Area.gCurrLevelNum == LevelTable.LEVEL_CASTLE_GROUNDS then
			break
		end
	end

	Presenter.EndWarm(View)
	Report(1, Status, nil)

	return View, Backdrop
end

return Run
