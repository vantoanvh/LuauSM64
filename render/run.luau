--!nonstrict
--!optimize 2

--[[
	Runs the port headless on a trace and renders chosen frames of it.

	Usage (from the repository root)
		lute run render/run.luau <trace> <out-directory> <frame,frame,...> [<width>]

	The height is three quarters of the width (default 320, the N64 framebuffer).

	Design Notes
		The harness boots and steps the game (harness/loop.luau); the recorder is on during the frames to render only.
]]

const Fs = require("@std/fs")
const Process = require("@std/process")

const Build = require("./builder")
const Loop = require("../harness/loop")
const Load = require("../harness/port")
const EncodePng = require("./png")
const Raster = require("./raster")
const ReadTrace = require("../harness/trace")
const Recorder = require("../port/src/rom/render_recorder")

const RomPath = "rom/baserom.us.z64"

if #Process.args < 4 then
	error("usage: lute run render/run.luau <trace> <out-directory> <frame,frame,...> [<width>]")
end

const Width = tonumber(Process.args[5] or "320") :: number
const Height = Width * 3 // 4
const Trace = ReadTrace(Process.args[2])
const OutDirectory = Process.args[3]
const Wanted: { [number]: boolean } = {}

for _, Text in string.split(Process.args[4], ",") do
	Wanted[tonumber(Text) :: number] = true
end

if not Fs.exists(OutDirectory) then
	Fs.createDirectory(OutDirectory)
end

const Port = Load("../port", buffer.fromstring(Fs.readFileToString(RomPath)))
const Game = Loop.NewGame()

Loop.Boot(Port, Game, Trace.Boot)

for Frame = 0, #Trace.Frames - 1 do
	Game.Frame = Frame

	if Wanted[Frame] then
		Recorder.Begin()
	end

	Loop.Step(Port, Game, Trace.Frames[Frame + 1])

	if Wanted[Frame] then
		const Recorded = Recorder.End()
		const Started = os.clock()
		const Scene = Build(Recorded)
		local Draws = 0
		local Vertices = 0

		for _, Pass in Recorded.Passes do
			Draws += #Pass.Draws
		end

		for _, Batch in Scene.Batches do
			Vertices += Batch.VertexCount
		end

		print(`frame {Frame}: {#Recorded.Passes} passes, {Draws} draws, {#Scene.Batches} batches, {Scene.Stats.Triangles} triangles, {Vertices} vertices, {Scene.Stats.Generated} generated lists and {Scene.Stats.Skipped} shadows skipped, {Scene.Stats.Commands} commands, decoded in {string.format("%.2f", os.clock() - Started)} s`)

		for Op, Count in Scene.Stats.Unhandled do
			print(`  unhandled opcode 0x{string.format("%02X", Op)}: {Count}`)
		end

		const Target = Raster.New(Width, Height)
		const RasterStarted = os.clock()

		Raster.Clear(Target, Scene.ClearColor[1], Scene.ClearColor[2], Scene.ClearColor[3])
		Raster.DrawScene(Target, Scene)
		print(`  rasterized {Width}x{Height} in {string.format("%.2f", os.clock() - RasterStarted)} s`)
		Fs.writeStringToFile(`{OutDirectory}/frame{Frame}.png`, EncodePng(Width, Height, Target.Color))
	end
end
