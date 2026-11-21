--!strict
--!optimize 2

--[[
	Runs the SM64 port on the client and shows it as MeshParts (roblox/src/Presenter): the game steps at 30 frames per second with the
	keyboard or gamepad as the N64 controller (roblox/src/Controls), Roblox renders and lights the meshes and plays the sounds the game
	asks for (roblox/src/Audio, with the files audio/ rendered). The game starts at the logo, as on
	the console, after the meshes of the menus and the courses are made (roblox/src/Warmup) behind a black screen.
]]

const RunService = game:GetService("RunService")

const Area = require("./port/src/game/area")
const AudioRecorder = require("./port/src/rom/audio_recorder")
const Audio = require("./roblox/src/Audio")
const Driver = require("./roblox/src/Driver")
const Overlay = require("./roblox/src/Overlay")
const Presenter = require("./roblox/src/Presenter")
const Controls = require("./roblox/src/Controls")
const Recorder = require("./port/src/rom/render_recorder")
const RomImage = require("./roblox/src/RomImage")
const SaveSlots = require("./roblox/src/SaveSlots")
const Sky = require("./roblox/src/Sky")
const Warmup = require("./roblox/src/Warmup")

const FrameTime = 1 / 30
const AudioReady = 0.15
const RomReady = 0.18
const SceneryReady = 0.96
const Starting = 0.99

-- the black cover is up before anything else is made
const Screen = Overlay.New()

-- the sound files are loaded behind it
const Sounds = Audio.New(function(Completed: number, Total: number, Asset: string)
	Overlay.SetProgress(Screen, AudioReady * Completed / math.max(Total, 1), `Loading audio ({Completed}/{Total} sounds)`, Asset)
end)

Overlay.SetProgress(Screen, AudioReady, "Reading game data", "Decoding the ROM image")

const Image = RomImage()

Overlay.SetProgress(Screen, RomReady, "Preparing title screen", "Creating the sprite quad mesh")

-- the menus and the courses are run in a game of their own (roblox/src/Warmup); the presenter and the sky it made stay
const View, Backdrop = Warmup(Image, function(Fraction: number, Status: string, Asset: string?)
	Overlay.SetProgress(Screen, math.lerp(RomReady, SceneryReady, Fraction), Status, Asset)
end)

Overlay.SetProgress(Screen, SceneryReady, "Reading save files", nil)

const Eeprom, Commit = SaveSlots.Open()

SaveSlots.Observe(function(Message: string?)
	Overlay.SetSaveStatus(Screen, Message or (if Eeprom == nil then "Saves unavailable this session" else nil))
end)

Overlay.SetProgress(Screen, Starting, "Starting game", "Waiting for the first frame")

const Game = Driver.Load(Image, 0, Eeprom)
const TitleScreen = require("./port/src/menu/title_screen")
const DemoPrepareAt = TitleScreen.PRESS_START_DEMO_TIMER - 120
local Accumulated = 0
local Frame = 0
local Pending: Recorder.Frame? = nil
local WorldReady = false
local SkyReady = false
local StepMs = 0
local WorldSeconds = 0
local SkySeconds = 0

-- One frame of the game and its meshes; the milliseconds of each part go to attributes of the folder for a look at the speed
const function Advance()
	const Held = Pending
	local Recorded: Recorder.Frame

	if Held == nil then
		Frame += 1

		const Started = os.clock()

		Recorder.Begin()
		AudioRecorder.Begin()
		Driver.Step(Game, Controls.Read())
		SaveSlots.Send(Eeprom, Commit)
		StepMs = (os.clock() - Started) * 1000
		Recorded = Recorder.End()
		Pending = Recorded

		Audio.Present(Sounds, AudioRecorder.End(), Area.gCurrLevelNum, Area.gCurrAreaIndex)

		if Game.GameInit.gCurrDemoInput == nil and TitleScreen.sDemoCountdown == DemoPrepareAt then
			Presenter.StageDemo(View, Game.GameInit.gDemoInputListID + 1)
		end

		const PrepareStarted = os.clock()

		Presenter.Capture(View, Recorded)
		WorldSeconds = os.clock() - PrepareStarted
		SkySeconds = 0
		WorldReady = false
		SkyReady = false
	else
		Recorded = Held
	end

	-- Both can start loading from this frame. Keep its Gfx pool intact until both are ready to show it.
	const SkyStarted = os.clock()

	if not SkyReady then
		SkyReady = Sky.Prepare(Backdrop, Recorded)
	end

	SkySeconds += os.clock() - SkyStarted

	const WorldStarted = os.clock()

	if not WorldReady then
		WorldReady = Presenter.Ready(View)
	end

	if not (WorldReady and SkyReady) then
		WorldSeconds += os.clock() - WorldStarted

		return
	end

	Presenter.Present(View, Recorded)

	WorldSeconds += os.clock() - WorldStarted

	const ShowSkyStarted = os.clock()

	Sky.Present(Backdrop, Recorded)

	const Backdropped = os.clock()

	Overlay.Present(Screen, Recorded)
	Overlay.SetCover(Screen, false)
	Controls.Show()
	Pending = nil
	View.Folder:SetAttribute("Frame", Frame)
	View.Folder:SetAttribute("StepMs", StepMs)
	View.Folder:SetAttribute("PresentMs", WorldSeconds * 1000)
	View.Folder:SetAttribute("SkyMs", (SkySeconds + Backdropped - ShowSkyStarted) * 1000)
	View.Folder:SetAttribute("OverlayMs", (os.clock() - Backdropped) * 1000)
end

const function OnPreRender(DeltaTime: number)
	-- The game ticks at 30 Hz. A pending picture is retried on the next render without running another tick.
	if Pending ~= nil then
		Advance()

		return
	end

	Accumulated = math.min(Accumulated + DeltaTime, FrameTime * 2)

	if Accumulated >= FrameTime then
		Accumulated -= FrameTime
		Advance()
	end
end

RunService.PostSimulation:Connect(OnPreRender)
