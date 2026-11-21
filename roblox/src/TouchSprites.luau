--!strict
--!optimize 2

--[[
	The pixel art of the touch controls (roblox/src/TouchControls), in the style of Super Mario 64: round buttons in the N64 pad's colors
	(A blue, B green, Z gray, Start red) with a thin black line, a lit crescent at the top left and a shaded one at the bottom right,
	each with a thin white icon (a jump arrow, an impact for the punch, a ground pound, a camera, a check mark, a triangle, the
	menu lines, the word START), and for the stick the N64's octagonal gate and the gray cap of its stick.

	Paradigm
		The art is small and coarse, like the game's own: a button is a few dozen pixels across and the screen shows each of them as a
		square of several screen pixels (ResampleMode Pixelated, a whole number of screen pixels for each art pixel). The sizes are given
		in art pixels (Sizes) and every picture is painted once, for them.

	Owned State
		The EditableImages of the pictures (they must live as long as the Content that shows them).
]]

const PixelCanvas = require("./PixelCanvas")

-- A button's pictures
export type Pair = { Normal: Content, Pressed: Content }

-- What the game is doing, which says what a button does and which buttons do anything: playing, reading a dialog, on the title screen (or the
-- game over screen), in a select (the files, the acts) or in the pause menu
export type Mode = "Play" | "Dialog" | "Title" | "Select" | "Pause"

-- A button's pictures by mode; a mode that has none hides the button
export type Modes = { [string]: Pair }

export type Sprites = {
	Jump: Modes,
	Attack: Modes,
	Crouch: Modes,
	Camera: Modes,
	Start: Modes,
	Gate: Content,
	Stick: Content,
	-- The pictures, kept alive for as long as they are shown
	Pictures: { PixelCanvas.Picture },
}

-- The colors of a button: the body, the lit rim and the shaded rim
type Palette = { Body: Color3, Light: Color3, Dark: Color3 }

-- The sizes of the pictures, in art pixels: the buttons (the jump and start buttons, which a thumb must find, are a little bigger), the gate of
-- the stick and its cap
const Sizes = { Button = 24, Primary = 27, Gate = 44, Cap = 24 }

-- The parts of a button, in art pixels: the black line and the lit and shaded rims
const LineWidth = 1
const RimWidth = 2

const Outline = Color3.fromRGB(14, 14, 24)
const White = Color3.new(1, 1, 1)
const Black = Color3.fromRGB(20, 20, 30)

-- The N64 controller's colors: A blue, B green, Z gray, Start red
const BluePalette = { Body = Color3.fromRGB(44, 96, 224), Light = Color3.fromRGB(110, 158, 250), Dark = Color3.fromRGB(26, 62, 168) } :: Palette
const GreenPalette = { Body = Color3.fromRGB(44, 172, 76), Light = Color3.fromRGB(112, 224, 134), Dark = Color3.fromRGB(26, 116, 50) } :: Palette
const GrayPalette = { Body = Color3.fromRGB(134, 134, 146), Light = Color3.fromRGB(198, 198, 210), Dark = Color3.fromRGB(86, 86, 98) } :: Palette
const RedPalette = { Body = Color3.fromRGB(214, 44, 44), Light = Color3.fromRGB(250, 116, 116), Dark = Color3.fromRGB(144, 26, 26) } :: Palette
-- the C buttons' yellow, for the camera
const YellowPalette = { Body = Color3.fromRGB(222, 164, 24), Light = Color3.fromRGB(250, 214, 96), Dark = Color3.fromRGB(158, 108, 10) } :: Palette
-- the cap of the stick: the N64's gray
const StickPalette = { Body = Color3.fromRGB(150, 150, 160), Light = Color3.fromRGB(214, 214, 224), Dark = Color3.fromRGB(86, 86, 98) } :: Palette

-- The icons, square, thin: # is the color of the icon
-- Jump: an arrow up (13 x 13)
const JumpIcon = {
	"......#......",
	".....###.....",
	"....#####....",
	"...#######...",
	"..#########..",
	".....###.....",
	".....###.....",
	".....###.....",
	".....###.....",
	".....###.....",
	".............",
	".............",
	".............",
}

-- The punch: an impact of lines around a hit (13 x 13)
const PunchIcon = {
	"#.....#.....#",
	".#....#....#.",
	"..#...#...#..",
	"...#..#..#...",
	"....#.#.#....",
	".....###.....",
	"#############",
	".....###.....",
	"....#.#.#....",
	"...#..#..#...",
	"..#...#...#..",
	".#....#....#.",
	"#.....#.....#",
}

-- The ground pound: an arrow down (13 x 13)
const PoundIcon = {
	".....###.....",
	".....###.....",
	".....###.....",
	".....###.....",
	".....###.....",
	"..#########..",
	"...#######...",
	"....#####....",
	".....###.....",
	"......#......",
	".............",
	".............",
	".............",
}

-- Choose: a check mark (13 x 13)
const CheckIcon = {
	".............",
	".............",
	"..........##.",
	".........##..",
	"........##...",
	".##....##....",
	"..##..##.....",
	"...####......",
	"....##.......",
	".............",
	".............",
	".............",
	".............",
}

-- Go on, start, resume: a triangle pointing right, with straight edges (13 x 13)
const PlayIcon = {
	".............",
	".##..........",
	".####........",
	".######......",
	".########....",
	".##########..",
	".########....",
	".######......",
	".####........",
	".##..........",
	".............",
	".............",
	".............",
}

-- The menu: three lines (13 wide)
const MenuIcon = {
	"..#########..",
	"..#########..",
	".............",
	".............",
	"..#########..",
	"..#########..",
	".............",
	".............",
	"..#########..",
	"..#########..",
}

-- The camera, which the R button switches between Mario's and Lakitu's (13 wide)
const CameraIcon = {
	".....###.....",
	"#############",
	"#...........#",
	"#....###....#",
	"#...#...#...#",
	"#...#...#...#",
	"#....###....#",
	"#...........#",
	"#############",
}

-- The letters of the word START, 3 pixels wide and 5 high
const Glyphs = {
	S = { "###", "#..", "###", "..#", "###" },
	T = { "###", ".#.", ".#.", ".#.", ".#." },
	A = { ".#.", "#.#", "###", "#.#", "#.#" },
	R = { "##.", "#.#", "##.", "#.#", "#.#" },
} :: { [string]: { string } }

-- The rows of a word, a pixel between its letters
const function Word(Letters: string): { string }
	const Rows: { string } = {}

	for Row = 1, 5 do
		const Parts: { string } = {}

		for Index = 1, #Letters do
			table.insert(Parts, Glyphs[string.sub(Letters, Index, Index)][Row])
		end

		table.insert(Rows, table.concat(Parts, "."))
	end

	return Rows
end

-- Start: the word, as on the N64's red button
const StartIcon = Word("START")

-- What an icon has at (X, Y) (zero based): "#" or "." for nothing
const function IconAt(Icon: { string }, X: number, Y: number): string
	if X < 0 or Y < 0 or Y >= #Icon or X >= #Icon[1] then
		return "."
	end

	return string.sub(Icon[Y + 1], X + 1, X + 1)
end

-- The columns and rows an icon really uses (the first and last of each), so that it is centered by what it draws and not by its grid
const function IconBounds(Icon: { string }): (number, number, number, number)
	local MinX, MaxX, MinY, MaxY = #Icon[1], -1, #Icon, -1

	for Row, Line in Icon do
		for Column = 1, #Line do
			if string.sub(Line, Column, Column) == "#" then
				MinX = math.min(MinX, Column - 1)
				MaxX = math.max(MaxX, Column - 1)
				MinY = math.min(MinY, Row - 1)
				MaxY = math.max(MaxY, Row - 1)
			end
		end
	end

	return MinX, MaxX, MinY, MaxY
end

const function Mix(Color: Color3, Factor: number): Color3
	return Color3.new(Color.R * Factor, Color.G * Factor, Color.B * Factor)
end

-- A round button of Size art pixels: lit from the top left, or sunk and darker when pressed (its icon a pixel down and right)
const function Disc(Size: number, Colors: Palette, Icon: { string }, Nudge: number, Pressed: boolean): PixelCanvas.Picture
	const Canvas = PixelCanvas.New(Size)
	const Middle = Size / 2
	const Body = if Pressed then Mix(Colors.Body, 0.8) else Colors.Body
	const Shift = if Pressed then 1 else 0
	-- the icon, centered by the pixels it draws
	const MinX, MaxX, MinY, MaxY = IconBounds(Icon)
	const OriginX = (Size - (MaxX - MinX + 1)) // 2 - MinX + Nudge
	const OriginY = (Size - (MaxY - MinY + 1)) // 2 - MinY

	for Y = 0, Size - 1 do
		for X = 0, Size - 1 do
			const Dx = X + 0.5 - Middle
			const Dy = Y + 0.5 - Middle
			const Distance = math.sqrt(Dx * Dx + Dy * Dy)
			const Rim = (Dx + Dy) / Middle
			local Color = Body
			local Alpha = 255

			if Distance > Middle - 0.3 then
				Alpha = 0
			elseif Distance > Middle - 0.3 - LineWidth then
				Color = Outline
			elseif Distance > Middle - 0.3 - LineWidth - RimWidth then
				-- the rims: lit at the top left and shaded at the bottom right; a pressed button is only shaded at the top left
				if Rim < -0.35 then
					Color = if Pressed then Mix(Colors.Dark, 0.85) else Colors.Light
				elseif Rim > 0.35 and not Pressed then
					Color = Colors.Dark
				end
			end

			if Alpha > 0 then
				const IconX = X - OriginX - Shift
				const IconY = Y - OriginY - Shift

				if IconAt(Icon, IconX, IconY) == "#" then
					Color = White
				elseif IconAt(Icon, IconX - 1, IconY - 1) == "#" then
					-- a pixel of shadow down and right of the icon
					Color = Black
				end
			end

			PixelCanvas.Put(Canvas, X, Y, Color, Alpha)
		end
	end

	return PixelCanvas.Finish(Canvas)
end

-- The gate of the stick, an octagon as on the N64 controller: a pale band between two dark lines, translucent inside, a notch at each of
-- the eight directions
const function Gate(): PixelCanvas.Picture
	const Size = Sizes.Gate
	const Canvas = PixelCanvas.New(Size)
	const Middle = Size / 2

	for Y = 0, Size - 1 do
		for X = 0, Size - 1 do
			const Dx = math.abs(X + 0.5 - Middle)
			const Dy = math.abs(Y + 0.5 - Middle)
			-- how far inside the octagon: 0 on its edge, larger inward
			const Depth = math.min(Middle - math.max(Dx, Dy), (Middle * 1.5 - Dx - Dy) / 1.2)
			local Color = White
			local Alpha = 0

			if Depth < 0 then
				Alpha = 0
			elseif Depth < 1.5 then
				Color = Outline
				Alpha = 230
			elseif Depth < 4 then
				Color = Color3.fromRGB(226, 226, 238)
				Alpha = 225
			elseif Depth < 5.5 then
				Color = Outline
				Alpha = 230
			else
				Color = Color3.fromRGB(30, 30, 46)
				Alpha = 92
			end

			-- the notches: dark pixels in the band at the four sides and the four corners
			if Depth >= 1.5 and Depth < 4 and (Dx < 1.2 or Dy < 1.2 or math.abs(Dx - Dy) < 1.2) then
				Color = Outline
				Alpha = 230
			end

			PixelCanvas.Put(Canvas, X, Y, Color, Alpha)
		end
	end

	return PixelCanvas.Finish(Canvas)
end

-- The cap of the stick: a gray disc with a ridged grip, as a thumb sees it
const function Stick(): PixelCanvas.Picture
	const Size = Sizes.Cap
	const Canvas = PixelCanvas.New(Size)
	const Middle = Size / 2

	for Y = 0, Size - 1 do
		for X = 0, Size - 1 do
			const Dx = X + 0.5 - Middle
			const Dy = Y + 0.5 - Middle
			const Distance = math.sqrt(Dx * Dx + Dy * Dy)
			const Rim = Dx + Dy
			local Color = StickPalette.Body
			local Alpha = 255

			if Distance > Middle - 0.3 then
				Alpha = 0
			elseif Distance > Middle - 1.5 then
				Color = Outline
			elseif Distance > Middle - 3.5 then
				Color = if Rim < -2.5 then StickPalette.Light elseif Rim > 2.5 then StickPalette.Dark else StickPalette.Body
			elseif Distance > 3.5 and Distance < 4.8 then
				-- the ridge of the grip: a ring in the dish of the cap
				Color = Mix(StickPalette.Body, 0.82)
			elseif Distance < 2.5 and Dx + Dy < 0 then
				-- the lit middle of the dish
				Color = Mix(StickPalette.Light, 0.95)
			end

			PixelCanvas.Put(Canvas, X, Y, Color, Alpha)
		end
	end

	return PixelCanvas.Finish(Canvas)
end

-- A button's pictures, the normal one and the sunk one
-- (Nudge moves the icon to the right by that many pixels: a triangle looks centered when its middle is, not its box)
const function Pair(Size: number, Colors: Palette, Icon: { string }, Nudge: number, Pictures: { PixelCanvas.Picture }): Pair
	const Normal = Disc(Size, Colors, Icon, Nudge, false)
	const Pressed = Disc(Size, Colors, Icon, Nudge, true)

	table.insert(Pictures, Normal)
	table.insert(Pictures, Pressed)

	return { Normal = Normal.Content, Pressed = Pressed.Content }
end

-- Paints the pictures
const function Build(): Sprites
	const Pictures: { PixelCanvas.Picture } = {}
	const GatePicture = Gate()
	const StickPicture = Stick()
	-- the pictures several modes share
	const Check = Pair(Sizes.Primary, BluePalette, CheckIcon, 0, Pictures)
	const Start = Pair(Sizes.Primary, RedPalette, StartIcon, 0, Pictures)

	table.insert(Pictures, GatePicture)
	table.insert(Pictures, StickPicture)

	return {
		-- the jump button (A) is a jump arrow while playing, a check mark to choose in a select or the pause menu, and a triangle to go on in a
		-- dialog; on the title screen A does nothing
		Jump = {
			Play = Pair(Sizes.Primary, BluePalette, JumpIcon, 0, Pictures),
			Select = Check,
			Pause = Check,
			Dialog = Pair(Sizes.Primary, BluePalette, PlayIcon, 1, Pictures),
		},
		-- the punch, the ground pound and the camera mode (R) are only for playing: in the menus B does what A does, and Z and R do nothing
		Attack = { Play = Pair(Sizes.Button, GreenPalette, PunchIcon, 0, Pictures) },
		Crouch = { Play = Pair(Sizes.Button, GrayPalette, PoundIcon, 0, Pictures) },
		Camera = { Play = Pair(Sizes.Button, YellowPalette, CameraIcon, 0, Pictures) },
		-- the menu while playing, START on the title screen and in the pause menu (a select starts with A, a dialog does not pause)
		Start = { Play = Pair(Sizes.Primary, RedPalette, MenuIcon, 0, Pictures), Title = Start, Pause = Start },
		Gate = GatePicture.Content,
		Stick = StickPicture.Content,
		Pictures = Pictures,
	}
end

return { Build = Build, Sizes = Sizes }
