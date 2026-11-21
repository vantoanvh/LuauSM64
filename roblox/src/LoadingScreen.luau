--!strict
--!optimize 2

--[[
	The loading screen, in the style of Super Mario 64: a row of Power Stars that light up as the game gets ready, a segmented bar under
	them, the percentage, what is being made and the asset, in the pixel font with the black outline of the game's HUD. It lives on the
	black cover that hides the screen until the first picture is built (roblox/src/Overlay).

	Paradigm
		Everything is laid out in art pixels, and an art pixel is a pixel of the HUD on the screen (roblox/src/HudScale, but at least
		MinimumStep, or a phone would show it too small), a whole number of screen pixels: the stars, the bar and the text have the resolution of the game's own picture. The screen is built again when the
		window changes size.

	Owned State
		The labels, the stars and the cells of the bar, and how much has been done (it never goes back).
]]

const HudScale = require("./HudScale")
const PixelCanvas = require("./PixelCanvas")

export type Loading = {
	Root: Frame,
	Stars: { ImageLabel },
	-- Each cell of the bar: its body and its lit top line
	Cells: { { Body: Frame, Top: Frame } },
	Lit: Content,
	Dim: Content,
	-- The pictures of the stars (kept alive while the screen shows them)
	Pictures: { PixelCanvas.Picture },
	Percentage: TextLabel,
	Status: TextLabel,
	Asset: TextLabel,
	-- What the two lines say now (they are made again with the screen)
	StatusText: string,
	AssetText: string,
	Completed: number,
	Step: number,
}

const StarCount = 8
const CellCount = 16
-- The size of the art: a star's canvas, a cell of the bar (its gap included), and the screen's width and height
const StarCanvas = 17
const CellWidth = 8
const ScreenWidth = StarCount * StarCanvas
const HeadingY = 0
const HeadingHeight = 12
const StarsY = 16
const BarY = 38
const BarHeight = 9
const StatusY = 52
const AssetY = 64
const ScreenHeight = 72

const StarShape = {
	"......###......",
	"......###......",
	".....#####.....",
	".....#####.....",
	"###############",
	".#############.",
	"..####k#k####..",
	"...###k#k###...",
	"...#########...",
	"..###########..",
	"..####...####..",
	".####.....####.",
	".###.......###.",
	"###.........###",
	"##...........##",
}

const Outline = Color3.fromRGB(10, 10, 16)
const StarBody = Color3.fromRGB(255, 214, 40)
const StarLight = Color3.fromRGB(255, 244, 140)
const DimBody = Color3.fromRGB(50, 50, 62)
const DimLight = Color3.fromRGB(64, 64, 78)
const Yellow = Color3.fromRGB(255, 224, 64)
const White = Color3.new(1, 1, 1)
const Gray = Color3.fromRGB(176, 180, 196)
const BarBackground = Color3.fromRGB(26, 26, 36)
const Font = Enum.Font.Arcade
-- The screen is never drawn with an art pixel smaller than this many screen pixels (on a phone the HUD's own pixel is a pixel or two, too
-- small to read)
const MinimumStep = 3

-- The art pixel for a window of this size
const function StepOf(Window: Vector2): number
	return math.max(HudScale(Window), MinimumStep)
end

-- What the star has at (X, Y) of the canvas, one pixel in from its edge
const function ShapeAt(X: number, Y: number): string
	if X < 1 or Y < 1 or X > #StarShape[1] or Y > #StarShape then
		return "."
	end

	return string.sub(StarShape[Y], X, X)
end

-- The Power Star, lit or dark: its body, a lit top left, the eyes, and a black line around it
const function PaintStar(Lit: boolean): PixelCanvas.Picture
	const Canvas = PixelCanvas.New(StarCanvas)

	for Y = 0, StarCanvas - 1 do
		for X = 0, StarCanvas - 1 do
			const Here = ShapeAt(X, Y)

			if Here == "#" then
				PixelCanvas.Put(Canvas, X, Y, if X + Y < 9 then (if Lit then StarLight else DimLight) else (if Lit then StarBody else DimBody), 255)
			elseif Here == "k" then
				PixelCanvas.Put(Canvas, X, Y, Outline, 255)
			elseif ShapeAt(X - 1, Y) ~= "." or ShapeAt(X + 1, Y) ~= "." or ShapeAt(X, Y - 1) ~= "." or ShapeAt(X, Y + 1) ~= "." then
				PixelCanvas.Put(Canvas, X, Y, Outline, 255)
			end
		end
	end

	return PixelCanvas.Finish(Canvas)
end

-- A rectangle in art pixels
const function MakeBox(Parent: Instance, Step: number, X: number, Y: number, Width: number, Height: number, Color: Color3): Frame
	const Box = Instance.new("Frame")

	Box.Position = UDim2.fromOffset(X * Step, Y * Step)
	Box.Size = UDim2.fromOffset(Width * Step, Height * Step)
	Box.BackgroundColor3 = Color
	Box.BorderSizePixel = 0
	Box.ZIndex = 22
	Box.Parent = Parent

	return Box
end

-- A line of text in the HUD's pixel font with its black outline, TextSize in art pixels of height
const function MakeText(Parent: Instance, Step: number, Y: number, Height: number, TextSize: number, Color: Color3): TextLabel
	const Label = Instance.new("TextLabel")
	const Stroke = Instance.new("UIStroke")

	Label.Position = UDim2.fromOffset(0, Y * Step)
	Label.Size = UDim2.fromOffset(ScreenWidth * Step, Height * Step)
	Label.BackgroundTransparency = 1
	Label.Font = Font
	Label.TextSize = TextSize * Step
	Label.TextColor3 = Color
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextTruncate = Enum.TextTruncate.AtEnd
	Label.ZIndex = 22
	Stroke.Color = Outline
	Stroke.Thickness = Step
	Stroke.Parent = Label
	Label.Parent = Parent

	return Label
end

-- Shows the stars and the cells that are lit
const function Refresh(Self: Loading)
	const LitStars = math.min(Self.Completed * StarCount // 1, StarCount)
	const LitCells = math.min(Self.Completed * CellCount // 1, CellCount)

	for Number, Star in Self.Stars do
		Star.ImageContent = if Number <= LitStars then Self.Lit else Self.Dim
	end

	for Number, Cell in Self.Cells do
		Cell.Body.BackgroundColor3 = if Number <= LitCells then StarBody else DimBody
		Cell.Top.BackgroundColor3 = if Number <= LitCells then StarLight else DimLight
	end
end

-- Builds the screen for a size of the art pixel, in place of the one before
const function Build(Self: Loading, Step: number)
	Self.Root:ClearAllChildren()
	Self.Step = Step
	Self.Root.Size = UDim2.fromOffset(ScreenWidth * Step, ScreenHeight * Step)

	const Heading = MakeText(Self.Root, Step, HeadingY, HeadingHeight, 8, White)

	Heading.Text = "LOADING"
	Self.Percentage = MakeText(Self.Root, Step, HeadingY, HeadingHeight, 8, Yellow)
	Self.Percentage.TextXAlignment = Enum.TextXAlignment.Right
	Self.Percentage.Text = `{Self.Completed * 100 // 1}%`

	-- the stars, one next to the other
	table.clear(Self.Stars)

	for Number = 1, StarCount do
		const Star = Instance.new("ImageLabel")

		Star.Position = UDim2.fromOffset((Number - 1) * StarCanvas * Step, StarsY * Step)
		Star.Size = UDim2.fromOffset(StarCanvas * Step, StarCanvas * Step)
		Star.BackgroundTransparency = 1
		Star.ImageContent = Self.Dim
		Star.ResampleMode = Enum.ResamplerMode.Pixelated
		Star.ZIndex = 22
		Star.Parent = Self.Root
		table.insert(Self.Stars, Star)
	end

	-- the bar: a black frame, a dark well and the cells, each 7 pixels wide with a pixel between them
	MakeBox(Self.Root, Step, 0, BarY, ScreenWidth, BarHeight, Outline)
	MakeBox(Self.Root, Step, 2, BarY + 2, ScreenWidth - 4, BarHeight - 4, BarBackground)
	table.clear(Self.Cells)

	for Number = 1, CellCount do
		const X = (ScreenWidth - CellCount * CellWidth) // 2 + (Number - 1) * CellWidth
		const Body = MakeBox(Self.Root, Step, X, BarY + 2, CellWidth - 1, BarHeight - 4, DimBody)
		const Top = MakeBox(Body, Step, 0, 0, CellWidth - 1, 1, DimLight)

		table.insert(Self.Cells, { Body = Body, Top = Top })
	end

	Self.Status = MakeText(Self.Root, Step, StatusY, 10, 6, White)
	Self.Status.Text = Self.StatusText
	Self.Asset = MakeText(Self.Root, Step, AssetY, 8, 5, Gray)
	Self.Asset.Text = Self.AssetText
	Refresh(Self)
end

-- The screen, inside the cover
const function New(Cover: Frame): Loading
	const Root = Instance.new("Frame")

	Root.Name = "Loading"
	Root.AnchorPoint = Vector2.one / 2
	Root.Position = UDim2.fromScale(0.5, 0.5)
	Root.BackgroundTransparency = 1
	Root.ZIndex = 21
	Root.Parent = Cover

	const LitStar = PaintStar(true)
	const DimStar = PaintStar(false)
	const Self = {
		Root = Root,
		Stars = {},
		Cells = {},
		Lit = LitStar.Content,
		Dim = DimStar.Content,
		Pictures = { LitStar, DimStar },
		-- the lines are made by Build
		Percentage = Instance.new("TextLabel"),
		Status = Instance.new("TextLabel"),
		Asset = Instance.new("TextLabel"),
		StatusText = "PREPARING AUDIO",
		AssetText = "",
		Completed = 0,
		Step = 0,
	} :: Loading

	Build(Self, StepOf(Cover.AbsoluteSize))

	-- the art pixel follows the window
	Cover:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		const Step = StepOf(Cover.AbsoluteSize)

		if Step ~= Self.Step then
			Build(Self, Step)
		end
	end)

	return Self
end

-- Shows how far the game is (a fraction from 0 to 1, never less than it was), what is being made and the asset
const function Set(Self: Loading, Fraction: number, Status: string, Asset: string?)
	Self.Completed = math.clamp(Fraction, Self.Completed, 1)
	Self.Percentage.Text = `{Self.Completed * 100 // 1}%`
	Self.StatusText = string.upper(Status)
	Self.AssetText = Asset or ""
	Self.Status.Text = Self.StatusText
	Self.Asset.Text = Self.AssetText
	Refresh(Self)
end

return { New = New, Set = Set }
