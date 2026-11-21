--!strict
--!optimize 2
--!native

--[[
	Shows the 2D picture of the game (the HUD, the text, the menus) around the 3D head viewport.

	Paradigm
		The game issues these in the geo traversal's foreground passes and in the Gfx pool after traversal (the recorder's Overlay).
		They are screen rectangles and flat triangles drawn by the RDP on top of the 3D picture, so the software rasterizer of render/ paints
		them into an RGBA image the size of the screen (the N64's 320 x 240 pixels) and a ScreenGui ImageLabel shows it
		with nearest neighbor sampling. The image is painted again only when the decoded draws change.

	Owned State
		The ScreenGui and two image layers, each with a framebuffer checkpoint before the changing batches.

	Design Notes
		The picture keeps the aspect of the N64 (4:3) in the middle of the window, and black panels (children of the frame that keeps the aspect, so no gap to the picture) cover the 3D view outside it: the game
		lays out its HUD, text, fades and the dimming of the pause menu for a 4:3 screen. The camera's vertical field of view is the
		game's, so the 3D view inside the bars is exactly what the N64 shows. A screen gui shows its colors as they are (not through
		the tone curve Roblox puts the 3D scene through), so the colors of the game go to the image unchanged.
]]

const AssetService = game:GetService("AssetService")
const Players = game:GetService("Players")
const TweenService = game:GetService("TweenService")

const DisplayList = require("../../render/display_list")
const HeadMesh = require("./HeadMesh")
const LoadingScreen = require("./LoadingScreen")
const Matrix = require("../../render/matrix")
const PresentationSpace = require("./PresentationSpace")
const Raster = require("../../render/raster")
const Recorder = require("../../port/src/rom/render_recorder")
const Scene = require("../../render/scene")

const ScreenViewport = { X = 160, Y = 120, HalfWidth = 160, HalfHeight = 120 }
-- Pixels of the image for each pixel of the N64's 320 x 240
const PixelScale = 1
const ImageWidth = 320 * PixelScale
const ImageHeight = 240 * PixelScale
const ImageStride = ImageWidth * 4
const ImageSize = Vector2.new(ImageWidth, ImageHeight)
const UnavailableNotice = "Saves unavailable this session"
const SaveNoticeBackground = 0.25
const SaveNoticeFade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 3)

type Canvas = {
	Label: ImageLabel,
	Image: EditableImage,
	Target: Raster.Framebuffer,
	Painted: { Scene.Batch }?,
	PaintStart: number,
	PaintCount: number,
	DepthWritten: boolean,
	Checkpoint: number,
	CheckpointPixels: buffer,
	SuffixBounds: Raster.Bounds,
	UploadPixels: buffer,
}

export type Overlay = {
	Frame: Frame,
	Foreground: Canvas,
	Background: Canvas?,
	Head: HeadMesh.HeadMesh,
	-- The black cover that hides the screen until the first picture is built
	Cover: Frame,
	-- The startup progress display, hidden with the cover on the first frame.
	Loading: LoadingScreen.Loading,
	SaveStatus: TextLabel,
	SaveFade: Tween?,
}

const function NewCanvas(Parent: Frame, Name: string, Layer: number): Canvas
	const Label = Instance.new("ImageLabel")
	const Image = AssetService:CreateEditableImage({ Size = ImageSize })

	Label.Name = Name
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.ResampleMode = Enum.ResamplerMode.Pixelated
	Label.ImageContent = Content.fromObject(Image)
	Label.Visible = false
	Label.ZIndex = Layer
	Label.Parent = Parent

	return {
		Label = Label,
		Image = Image,
		Target = Raster.NewSprite(ImageWidth, ImageHeight),
		Painted = nil,
		PaintStart = 1,
		PaintCount = 0,
		DepthWritten = false,
		Checkpoint = 0,
		CheckpointPixels = buffer.create(ImageStride * ImageHeight),
		SuffixBounds = { Left = ImageWidth, Top = ImageHeight, Right = 0, Bottom = 0 },
		UploadPixels = buffer.create(0),
	}
end

-- How far a black panel reaches past the frame, in sizes of the frame
const BarReach = 10

-- The black panels around the frame of the 4:3 picture: left, right, top and bottom, each placed by an edge of the frame itself, so they
-- cover the rest of the window with no gap to the picture whatever the window is (a panel the size of the window is not needed: they
-- reach BarReach frames past the edge)
const BarSides = {
	{ Anchor = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(BarReach, BarReach) },
	{ Anchor = Vector2.new(0, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(BarReach, BarReach) },
	{ Anchor = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, BarReach) },
	{ Anchor = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, BarReach) },
}

const function MakeBars(Frame: Frame)
	for Index, Side in BarSides do
		const Bar = Instance.new("Frame")

		Bar.Name = `Bar${Index}`
		Bar.AnchorPoint = Side.Anchor
		Bar.Position = Side.Position
		Bar.Size = Side.Size
		Bar.BackgroundColor3 = Color3.new(0, 0, 0)
		Bar.BorderSizePixel = 0
		Bar.ZIndex = 4
		Bar.Parent = Frame
	end
end

const function New(): Overlay
	const Gui = Instance.new("ScreenGui")
	const Frame = Instance.new("Frame")
	const Ratio = Instance.new("UIAspectRatioConstraint")

	Gui.Name = "SM64Overlay"
	Gui.IgnoreGuiInset = true
	Gui.ResetOnSpawn = false
	-- the picture is fitted to the whole screen, notches and rounded corners included, as the touch controls are
	Gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	Gui.ClipToDeviceSafeArea = false
	Gui.ScreenInsets = Enum.ScreenInsets.None
	Gui.DisplayOrder = 10
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Position = UDim2.fromScale(0.5, 0.5)
	Frame.Size = UDim2.fromScale(1, 1)
	Frame.BackgroundTransparency = 1
	Ratio.AspectRatio = 4 / 3
	Ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	Ratio.Parent = Frame
	Frame.Parent = Gui
	MakeBars(Frame)
	Gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	const Cover = Instance.new("Frame")

	Cover.Size = UDim2.fromScale(1, 1)
	Cover.BackgroundColor3 = Color3.new(0, 0, 0)
	Cover.BorderSizePixel = 0
	Cover.ZIndex = 20
	Cover.Parent = Gui

	const Loading = LoadingScreen.New(Cover)

	const SaveStatus = Instance.new("TextLabel")

	SaveStatus.Name = "SaveStatus"
	SaveStatus.AnchorPoint = Vector2.xAxis
	SaveStatus.Position = UDim2.new(1, -12, 0, 12)
	SaveStatus.Size = UDim2.fromOffset(230, 30)
	SaveStatus.BackgroundColor3 = Color3.new(0, 0, 0)
	SaveStatus.BackgroundTransparency = SaveNoticeBackground
	SaveStatus.BorderSizePixel = 0
	SaveStatus.Font = Enum.Font.GothamMedium
	SaveStatus.TextColor3 = Color3.new(1, 1, 1)
	SaveStatus.Text = ""
	SaveStatus.TextSize = 14
	SaveStatus.ZIndex = 21
	SaveStatus.Visible = false
	SaveStatus.Parent = Gui

	return {
		Frame = Frame,
		Foreground = NewCanvas(Frame, "Foreground", 3),
		Background = nil,
		Head = HeadMesh.New(Frame),
		Cover = Cover,
		Loading = Loading,
		SaveStatus = SaveStatus,
		SaveFade = nil,
	}
end

-- Batches hold decoded values and cached textures. Compare the values so framebuffer addresses are irrelevant
-- and changes to vertices or matrices behind an unchanged display list pointer still invalidate the image.
const function SameDraws(Left: unknown, Right: unknown): boolean
	if Left == Right then
		return true
	end

	if type(Left) ~= "table" or type(Right) ~= "table" then
		return false
	end

	const Before = Left :: { [unknown]: unknown }
	const After = Right :: { [unknown]: unknown }

	for Key, Value in Before do
		const Other = After[Key]

		if Value ~= Other and not SameDraws(Value, Other) then
			return false
		end
	end

	for Key in After do
		if Before[Key] == nil then
			return false
		end
	end

	return true
end

const function PresentPixels(Self: Canvas, Drawn: Scene.Scene, First: number, Last: number, Matching: number)
	local WritesDepth = false

	for Index = First, Last do
		if Drawn.Batches[Index].DepthUpdate then
			WritesDepth = true

			break
		end
	end

	-- The checkpoint stores color only. A scene that writes depth is redrawn in one pass.
	const Prefix = if WritesDepth then 0 else Matching
	const Reuse = Prefix > 0 and Prefix == Self.Checkpoint
	const Target = Self.Target
	const Bounds = Self.SuffixBounds
	const OldLeft, OldTop, OldRight, OldBottom = Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom

	if Reuse then
		if OldLeft < OldRight then
			const Count = (OldRight - OldLeft) * 4

			for Y = OldTop, OldBottom - 1 do
				const Offset = Y * ImageStride + OldLeft * 4

				buffer.copy(Target.Color, Offset, Self.CheckpointPixels, Offset, Count)
			end
		end
	else
		Raster.ClearSprite(Target, Self.DepthWritten)

		if Prefix > 0 then
			Raster.DrawScene(Target, Drawn, First, First + Prefix - 1)
			buffer.copy(Self.CheckpointPixels, 0, Target.Color)
		end
	end

	Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Bottom = ImageWidth, ImageHeight, 0, 0
	Raster.DrawScene(Target, Drawn, First + Prefix, Last, if Prefix > 0 then Bounds else nil)
	Self.Checkpoint = Prefix
	Self.DepthWritten = WritesDepth

	if not Reuse then
		Self.Image:WritePixelsBuffer(Vector2.zero, ImageSize, Target.Color)

		return
	end

	const Left = math.min(OldLeft, Bounds.Left)
	const Top = math.min(OldTop, Bounds.Top)
	const Right = math.max(OldRight, Bounds.Right)
	const Bottom = math.max(OldBottom, Bounds.Bottom)
	const Width = Right - Left
	const Height = Bottom - Top

	if Width <= 0 or Height <= 0 then
		return
	end

	if Width == ImageWidth and Height == ImageHeight then
		Self.Image:WritePixelsBuffer(Vector2.zero, ImageSize, Target.Color)

		return
	end

	const Stride = Width * 4
	const Size = Stride * Height
	local Pixels = Self.UploadPixels

	if buffer.len(Pixels) ~= Size then
		Pixels = buffer.create(Size)
		Self.UploadPixels = Pixels
	end

	for Row = 0, Height - 1 do
		buffer.copy(Pixels, Row * Stride, Target.Color, (Top + Row) * ImageStride + Left * 4, Stride)
	end

	Self.Image:WritePixelsBuffer(Vector2.new(Left, Top), Vector2.new(Width, Height), Pixels)
end

const function PresentCanvas(Self: Canvas, Drawn: Scene.Scene, First: number, Last: number)
	const Count = Last - First + 1

	if Count <= 0 then
		Self.Label.Visible = false

		return
	end

	const Painted = Self.Painted
	local Matching = 0

	if Painted ~= nil then
		for Offset = 0, math.min(Self.PaintCount, Count) - 1 do
			if not SameDraws(Painted[Self.PaintStart + Offset], Drawn.Batches[First + Offset]) then
				break
			end

			Matching = Offset + 1
		end
	end

	if Matching ~= Self.PaintCount or Matching ~= Count then
		PresentPixels(Self, Drawn, First, Last, Matching)
		Self.Painted = Drawn.Batches
		Self.PaintStart = First
		Self.PaintCount = Count
	end

	if not Self.Label.Visible then
		Self.Label.Visible = true
	end
end

-- Decode once so the RSP state carries across the background, mesh, and foreground.
const function Present(Self: Overlay, Frame: Recorder.Frame)
	const Drawn = Scene.New(ScreenViewport)
	const State = DisplayList.New(Drawn)
	local HeadStart, HeadEnd = 0, 0

	for _, Pass in Frame.Passes do
		if PresentationSpace.ClassifyPass(Pass) ~= "foreground" then
			continue
		end

		for _, Draw in Pass.Draws do
			const Address = Draw.DisplayList

			if type(Address) ~= "number" or Address == 0 then
				continue
			end

			const First = #Drawn.Batches + 1

			DisplayList.Draw(State, Address, Matrix.FromFixed(Draw.Matrix :: { number }), Draw.Layer, Pass.ZBuffer, Pass.Projection)

			if HeadStart == 0 and PresentationSpace.IsEngineList(Address) then
				for Index = First, #Drawn.Batches do
					if HeadMesh.IsBody(Drawn.Batches[Index]) then
						HeadStart = if HeadStart == 0 then Index else HeadStart
						HeadEnd = Index
					elseif HeadStart > 0 then
						break
					end
				end
			end
		end
	end

	if Frame.Overlay ~= nil then
		DisplayList.Run(State, Frame.Overlay.Start, Frame.Overlay.End)
	end

	HeadMesh.Present(Self.Head, Drawn.Batches, HeadStart, HeadEnd)

	const Background = Self.Background

	if HeadStart > 0 then
		const Canvas = Background or NewCanvas(Self.Frame, "HeadBackground", 1)

		Self.Background = Canvas
		PresentCanvas(Canvas, Drawn, 1, HeadStart - 1)
	elseif Background ~= nil then
		Background.Label:Destroy()
		Background.Image:Destroy()
		Self.Background = nil
	end

	PresentCanvas(Self.Foreground, Drawn, HeadEnd + 1, #Drawn.Batches)
end

const function FadeUnavailableNotice(Self: Overlay)
	const Label = Self.SaveStatus

	if Self.Cover.Visible or Label.Text ~= UnavailableNotice or not Label.Visible or Self.SaveFade ~= nil then
		return
	end

	const Fade = TweenService:Create(Label, SaveNoticeFade, { TextTransparency = 1, BackgroundTransparency = 1 })

	Self.SaveFade = Fade
	Fade.Completed:Once(function(State: Enum.PlaybackState)
		if Self.SaveFade == Fade then
			Self.SaveFade = nil

			if State == Enum.PlaybackState.Completed then
				Label.Visible = false
			end
		end
	end)
	Fade:Play()
end

-- Shows or hides the cover
const function SetCover(Self: Overlay, Covered: boolean)
	if Self.Cover.Visible ~= Covered then
		Self.Cover.Visible = Covered
		FadeUnavailableNotice(Self)
	end
end

const function SetProgress(Self: Overlay, Fraction: number, Status: string, Asset: string?)
	LoadingScreen.Set(Self.Loading, Fraction, Status, Asset)
end

const function SetSaveStatus(Self: Overlay, Message: string?)
	const Label = Self.SaveStatus
	const Text = Message or ""

	if Label.Text == Text then
		return
	end

	const Fade = Self.SaveFade

	if Fade ~= nil then
		Self.SaveFade = nil
		Fade:Cancel()
		Fade:Destroy()
	end

	Label.Text = Text
	Label.Visible = Message ~= nil
	Label.TextTransparency = 0
	Label.BackgroundTransparency = SaveNoticeBackground
	FadeUnavailableNotice(Self)
end

return { New = New, Present = Present, SetCover = SetCover, SetProgress = SetProgress, SetSaveStatus = SetSaveStatus }
