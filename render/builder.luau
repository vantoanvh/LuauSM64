--!strict
--!optimize 2

--[[
	Builds the Scene of one recorded frame: runs the display list of every master list entry through the interpreter, in the order
	the RCP runs them (layer by layer).

	Design Notes
		Runtime generated lists (callback nodes, tables) are counted and skipped. The interpreter state lives across the draws of a
		frame, as the RDP and RSP state does. The shadows of a master list come after its draws.
]]

const DisplayList = require("./display_list")
const Matrix = require("./matrix")
const Recorder = require("../port/src/rom/render_recorder")
const Scene = require("./scene")
const AddShadow = require("./shadow")
const Skybox = require("./skybox")

const function Build(Frame: Recorder.Frame): Scene.Scene
	const Viewport = Frame.Viewport or { X = 160, Y = 120, HalfWidth = 160, HalfHeight = 120 }
	const Result = Scene.New(Viewport)
	const State = DisplayList.New(Result)

	for _, Background in Frame.Backgrounds do
		table.insert(Result.Backgrounds, Background)

		if Background.Skybox ~= nil then
			Skybox.Add(Result, Background.Position, Background.Focus)
		else
			-- The fill color is RGBA5551
			const Pixel = Background.Fill % 0x10000

			Result.ClearColor = { bit32.rshift(Pixel, 11) * 255 // 31, bit32.band(bit32.rshift(Pixel, 6), 31) * 255 // 31, bit32.band(bit32.rshift(Pixel, 1), 31) * 255 // 31 }
		end
	end

	for _, Pass in Frame.Passes do
		for _, Draw in Pass.Draws do
			if type(Draw.DisplayList) == "number" and Draw.DisplayList ~= 0 then
				DisplayList.Draw(State, Draw.DisplayList, Matrix.FromFixed(Draw.Matrix :: { number }), Draw.Layer, Pass.ZBuffer, Pass.Projection)
			else
				Result.Stats.Generated += 1
			end
		end

		for _, Shadow in Pass.Shadows do
			if not AddShadow(State, Shadow, Pass.ZBuffer, Pass.Projection, Shadow.ModelView) then
				Result.Stats.Skipped += 1
			end
		end
	end

	if Frame.Overlay ~= nil then
		DisplayList.Run(State, Frame.Overlay.Start, Frame.Overlay.End)
	end

	return Result
end

return Build
