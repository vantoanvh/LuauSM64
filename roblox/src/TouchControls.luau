--!strict
--!optimize 2

--[[
	The N64 controller on a touch screen, with the layout of Roblox's own mobile controls (the jump button at the bottom right, the
	thumbstick at the bottom left) and the pixel art of the game (roblox/src/TouchSprites).

	Paradigm
		Touch devices only (UserInputService.PreferredInput is Touch when the game starts). The pad it keeps is read by roblox/src/Controls every
		game frame: Buttons has the bits of the buttons held, StickX and StickY are the stick from -1 to 1 (zero when no finger is on it).
		The screen is the controller, not a drawing of one:
			a fixed stick with the N64's octagonal gate at the bottom left, the jump button (A) at the bottom right as in every Roblox
			game, the attack button (B) and the crouch button (Z) in an arc beside it, a pause button (Start) at the top;
			the camera (the C buttons) is the right of the screen: a drag turns it (C left and C right), a pinch zooms it (C up and C down),
			a twist of two fingers turns it too.
		The default Roblox touch controls are turned off (GuiService.TouchControlsEnabled) so that they do not fight with these.

	Owned State
		The ScreenGui, the touch that holds the stick, the camera gestures and the pad.

	Design Notes
		A camera step is one press of a C button for PulseSeconds (the game reads the pad every 30th of a second), made each time a drag,
		a pinch or a twist has gone far enough for one more step.
]]

const GuiService = game:GetService("GuiService")
const Players = game:GetService("Players")
const UserInputService = game:GetService("UserInputService")

const TouchSprites = require("./TouchSprites")

-- The pad: bits of the held buttons and the stick as a fraction of its range; SetMode tells what the game is doing, which changes the icon of a
-- button (or hides it) so that it says what it does now
export type Touch = {
	Buttons: number,
	StickX: number,
	StickY: number,
	SetMode: (TouchSprites.Mode) -> (),
	-- Shows or hides the controls (they are hidden while the game loads)
	SetVisible: (boolean) -> (),
	-- The finger on the picture of the game, outside the buttons and the stick, when the game is not played (the menus): whether it is down and
	-- where, in the pixels of the N64's 320 x 240 picture, y down. The game turns it into a click of its own cursor
	PointerDown: boolean,
	PointerX: number,
	PointerY: number,
}

-- A button on the screen: its picture by mode, the bit it sets and whether a finger holds it
type Button = { Image: ImageLabel, Pictures: TouchSprites.Modes, Bit: number, Held: boolean }

-- The N64 controller bits (Controls)
const ButtonA = 0x8000
const ButtonB = 0x4000
const ButtonZ = 0x2000
const ButtonStart = 0x1000
const CUp = 0x0008
const CDown = 0x0004
const CLeft = 0x0002
const CRight = 0x0001

-- A button (all of them are the same size) is a share of the screen's height, within what a finger and the screen allow (in screen
-- pixels); every art pixel is a whole number of screen pixels, the closest to what makes a button that size
const ButtonShare = 0.11
const MinimumButton = 40
const MaximumButton = 72
-- The N64's picture, in pixels
const PictureWidth = 320
const PictureHeight = 240

-- The distance of the buttons to the edges of the screen, in art pixels
const EdgeMargin = 5
-- The gap between the jump button and the attack button, in art pixels
const ButtonGap = 2

-- The stick: the area that takes a finger (in sizes of the gate) and how far the cap travels (in sizes of the gate)
const GrabScale = 1.6
const CapTravel = 0.34

const IdleTransparency = 0.12
const HeldTransparency = 0

-- The camera: a drag of DragStep pixels makes a step, a pinch that changes the distance by PinchStep (a ratio) and a twist of TwistStep
-- degrees too; a step is the press of a C button for PulseSeconds
const DragStep = 60
const PinchStep = 0.15
const TwistStep = 20
const PulseSeconds = 0.1

-- A pixel picture: its pixels stay square at any size
const function MakeSprite(Parent: Instance, Name: string, Picture: Content): ImageLabel
	const Image = Instance.new("ImageLabel")
	const Ratio = Instance.new("UIAspectRatioConstraint")

	Image.Name = Name
	Image.AnchorPoint = Vector2.new(0.5, 0.5)
	Image.BackgroundTransparency = 1
	Image.ImageContent = Picture
	Image.ResampleMode = Enum.ResamplerMode.Pixelated
	Ratio.Parent = Image
	Image.Parent = Parent

	return Image
end

-- A button that sets Bit while a finger holds it, with the picture of the mode: normal, or sunk while it is held
const function MakeButton(Parent: Instance, Name: string, Pictures: TouchSprites.Modes, Bit: number, Pad: Touch): Button
	const Image = MakeSprite(Parent, Name, Content.none)
	const Self = { Image = Image, Pictures = Pictures, Bit = Bit, Held = false } :: Button

	Image.ImageTransparency = IdleTransparency
	-- a finger that lands on it is not for the camera or the stick
	Image.Active = true

	Image.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			Self.Held = true
			Pad.Buttons = bit32.bor(Pad.Buttons, Bit)
			Image.ImageTransparency = HeldTransparency
			-- the sunk picture of the mode it has now
			for _, Pair in Self.Pictures do
				if Image.ImageContent == Pair.Normal then
					Image.ImageContent = Pair.Pressed
				end
			end
		end
	end)

	Image.InputEnded:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			Self.Held = false
			Pad.Buttons = bit32.band(Pad.Buttons, bit32.bnot(Bit))
			Image.ImageTransparency = IdleTransparency

			for _, Pair in Self.Pictures do
				if Image.ImageContent == Pair.Pressed then
					Image.ImageContent = Pair.Normal
				end
			end
		end
	end)

	return Self
end

-- Shows the button as the mode has it: its picture, or nothing when the mode has none (and a button that is held then lets go)
const function ShowButton(Self: Button, Pad: Touch, Mode: TouchSprites.Mode)
	const Pair = Self.Pictures[Mode] :: TouchSprites.Pair?

	Self.Image.Visible = Pair ~= nil

	if Pair == nil then
		Self.Held = false
		Pad.Buttons = bit32.band(Pad.Buttons, bit32.bnot(Self.Bit))
	else
		Self.Image.ImageContent = if Self.Held then Pair.Pressed else Pair.Normal
	end
end

-- A press of a C button, for PulseSeconds (one step of the camera)
const function Pulse(Pad: Touch, Bit: number)
	Pad.Buttons = bit32.bor(Pad.Buttons, Bit)

	task.delay(PulseSeconds, function()
		Pad.Buttons = bit32.band(Pad.Buttons, bit32.bnot(Bit))
	end)
end

-- The mode before the buttons exist
const function IgnoreMode(_Mode: TouchSprites.Mode) end
const function IgnoreVisible(_Visible: boolean) end

-- The pad of a touch screen, or nil on a device without one
const function New(): Touch?
	if UserInputService.PreferredInput ~= Enum.PreferredInput.Touch then
		return nil
	end

	const Pad = { Buttons = 0, StickX = 0, StickY = 0, SetMode = IgnoreMode, SetVisible = IgnoreVisible, PointerDown = false, PointerX = 0, PointerY = 0 } :: Touch
	const Gui = Instance.new("ScreenGui")
	const Sprites = TouchSprites.Build()

	GuiService.TouchControlsEnabled = false
	Gui.Name = "SM64Touch"
	Gui.Enabled = false
	Gui.DisplayOrder = 20
	Gui.IgnoreGuiInset = true
	Gui.ResetOnSpawn = false
	-- the buttons are placed from the edges of the whole screen, as the default controls are
	Gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	Gui.ClipToDeviceSafeArea = false
	Gui.ScreenInsets = Enum.ScreenInsets.None

	-- the stick is fixed: a finger that lands in the area around the gate takes it, and the cap follows the finger from the center of the gate
	const Grab = Instance.new("Frame")

	Grab.Name = "StickArea"
	Grab.AnchorPoint = Vector2.new(0.5, 0.5)
	Grab.BackgroundTransparency = 1
	Grab.Active = true
	Grab.Parent = Gui

	const Gate = MakeSprite(Gui, "StickGate", Sprites.Gate)
	const Cap = MakeSprite(Gate, "StickCap", Sprites.Stick)

	Cap.Position = UDim2.fromScale(0.5, 0.5)
	Cap.Size = UDim2.fromScale(TouchSprites.Sizes.Cap / TouchSprites.Sizes.Gate, TouchSprites.Sizes.Cap / TouchSprites.Sizes.Gate)

	const Jump = MakeButton(Gui, "Jump", Sprites.Jump, ButtonA, Pad)
	const Attack = MakeButton(Gui, "Attack", Sprites.Attack, ButtonB, Pad)
	const Crouch = MakeButton(Gui, "Crouch", Sprites.Crouch, ButtonZ, Pad)
	const Pause = MakeButton(Gui, "Pause", Sprites.Pause, ButtonStart, Pad)
	const Faces = { Jump, Attack, Crouch, Pause }
	local Mode: TouchSprites.Mode = "Play"

	const function Show()
		for _, Face in Faces do
			ShowButton(Face, Pad, Mode)
		end
	end

	Show()

	const function SetMode(Next: TouchSprites.Mode)
		if Next ~= Mode then
			Mode = Next
			Show()
		end
	end

	const function SetVisible(Visible: boolean)
		Gui.Enabled = Visible
	end

	Pad.SetMode = SetMode
	Pad.SetVisible = SetVisible

	-- Places the buttons from the bottom right and the stick from the bottom left, each art pixel a whole number of screen pixels
	const function Layout()
		const Screen = Gui.AbsoluteSize

		-- the screen has no size until it shows
		if Screen.Y == 0 then
			return
		end

		const Sizes = TouchSprites.Sizes
		const Pixel = math.max(math.round(math.clamp(Screen.Y * ButtonShare, MinimumButton, MaximumButton) / Sizes.Button), 1)
		const Margin = EdgeMargin * Pixel
		const ButtonPixels = Sizes.Button * Pixel
		const GatePixels = Sizes.Gate * Pixel
		-- the center of the jump button, from the right and the bottom
		const RightA = Margin + ButtonPixels / 2
		const BottomA = Margin + ButtonPixels / 2

		for _, Face in Faces do
			Face.Image.Size = UDim2.fromOffset(ButtonPixels, ButtonPixels)
		end

		Jump.Image.Position = UDim2.new(1, -RightA, 1, -BottomA)
		Attack.Image.Position = UDim2.new(1, -(RightA + ButtonPixels + ButtonGap * Pixel), 1, -BottomA)
		Crouch.Image.Position = UDim2.new(1, -(RightA + ButtonPixels * 0.6), 1, -(BottomA + ButtonPixels * 1.05))
		Pause.Image.Position = UDim2.new(1, -RightA, 0, BottomA)

		-- the stick: at the left edge, as low as the buttons
		Gate.Size = UDim2.fromOffset(GatePixels, GatePixels)
		Gate.Position = UDim2.new(0, Margin + GatePixels / 2, 1, -(Margin + GatePixels / 2))
		Grab.Size = UDim2.fromOffset(GatePixels * GrabScale, GatePixels * GrabScale)
		Grab.Position = Gate.Position
	end

	Layout()
	Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout)

	local Holder: InputObject? = nil

	-- Moves the cap with the finger and sets the stick
	const function Drag(Position: Vector2)
		const Size = Gate.AbsoluteSize.X
		local Offset = (Position - (Gate.AbsolutePosition + Gate.AbsoluteSize / 2)) / (Size * CapTravel)

		if Offset.Magnitude > 1 then
			Offset = Offset.Unit
		end

		Pad.StickX = Offset.X
		Pad.StickY = -Offset.Y
		Cap.Position = UDim2.fromScale(0.5 + Offset.X * CapTravel, 0.5 + Offset.Y * CapTravel)
	end

	Grab.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch and Holder == nil then
			Holder = Input
			Drag(Vector2.new(Input.Position.X, Input.Position.Y))
		end
	end)

	-- Where a finger is on the picture of the game: the 4:3 picture is in the middle of the screen
	const function Place(Input: InputObject)
		const Screen = Gui.AbsoluteSize
		const Width = math.min(Screen.X, Screen.Y * 4 / 3)
		const Height = Width * 3 / 4
		const Inside = Vector2.new(Input.Position.X, Input.Position.Y) - Gui.AbsolutePosition

		Pad.PointerX = math.clamp((Inside.X - (Screen.X - Width) / 2) / Width * PictureWidth, 0, PictureWidth)
		Pad.PointerY = math.clamp((Inside.Y - (Screen.Y - Height) / 2) / Height * PictureHeight, 0, PictureHeight)
	end

	-- the camera: a finger that lands where nothing takes it drags (in the menus it points at the picture instead), two fingers pinch and twist
	local Pointer: InputObject? = nil
	local Dragger: InputObject? = nil
	local Dragged = 0
	local PinchFrom = 1
	local TwistFrom = 0

	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if Input.UserInputType ~= Enum.UserInputType.Touch or Processed then
			return
		end

		if Mode ~= "Play" then
			if Pointer == nil then
				Pointer = Input
				Pad.PointerDown = true
				Place(Input)
			end
		elseif Dragger == nil then
			Dragger = Input
			Dragged = 0
		end
	end)

	UserInputService.TouchMoved:Connect(function(Input: InputObject)
		if Input == Holder then
			Drag(Vector2.new(Input.Position.X, Input.Position.Y))
		elseif Input == Pointer then
			Place(Input)
		elseif Input == Dragger then
			-- the world follows the finger: a drag to the right turns the camera to the left
			Dragged += Input.Delta.X

			while Dragged >= DragStep do
				Dragged -= DragStep
				Pulse(Pad, CLeft)
			end

			while Dragged <= -DragStep do
				Dragged += DragStep
				Pulse(Pad, CRight)
			end
		end
	end)

	UserInputService.TouchEnded:Connect(function(Input: InputObject)
		if Input == Holder then
			Holder = nil
			Pad.StickX = 0
			Pad.StickY = 0
			Cap.Position = UDim2.fromScale(0.5, 0.5)
		elseif Input == Pointer then
			Pointer = nil
			Pad.PointerDown = false
		elseif Input == Dragger then
			Dragger = nil
		end
	end)

	UserInputService.TouchPinch:Connect(function(_Positions: { Vector2 }, Scale: number, _Velocity: number, State: Enum.UserInputState, Processed: boolean)
		if Processed then
			return
		end

		if State == Enum.UserInputState.Begin then
			PinchFrom = 1
			-- two fingers are not a drag
			Dragger = nil
		elseif State == Enum.UserInputState.Change then
			-- the fingers apart zoom in, together zoom out
			if Scale >= PinchFrom * (1 + PinchStep) then
				PinchFrom = Scale
				Pulse(Pad, CUp)
			elseif Scale <= PinchFrom * (1 - PinchStep) then
				PinchFrom = Scale
				Pulse(Pad, CDown)
			end
		end
	end)

	UserInputService.TouchRotate:Connect(function(_Positions: { Vector2 }, Rotation: number, _Velocity: number, State: Enum.UserInputState, Processed: boolean)
		if Processed then
			return
		end

		if State == Enum.UserInputState.Begin then
			TwistFrom = 0
		elseif State == Enum.UserInputState.Change then
			if Rotation >= TwistFrom + TwistStep then
				TwistFrom = Rotation
				Pulse(Pad, CRight)
			elseif Rotation <= TwistFrom - TwistStep then
				TwistFrom = Rotation
				Pulse(Pad, CLeft)
			end
		end
	end)

	Gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	return Pad
end

return New
