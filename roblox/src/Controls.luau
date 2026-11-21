--!strict
--!optimize 2

--[[
	The N64 controller from the keyboard, a gamepad or the touch screen (roblox/src/TouchControls). Read gives the pad of the moment.

	Controls
		Stick: WASD or the left thumbstick. A: Space or gamepad A. B: E or X. Z: Q or the left trigger. Start: Return or Start.
		C buttons: the arrow keys or the right thumbstick. R (the camera mode): R or the right bumper. A touch device shows the buttons and a
		fixed stick on the screen.
]]

const UserInputService = game:GetService("UserInputService")

const Area = require("../../port/src/game/area")
const DialogIdsH = require("../../port/include/dialog_ids_h")
const Driver = require("./Driver")
const FileSelect = require("../../port/src/menu/file_select")
const GdMain = require("../../port/src/goddard/gd_main")
const IngameMenu = require("../../port/groups/ingame_menu_plus1")
const LevelTableH = require("../../port/include/level_table_h")
const LevelScript = require("../../port/src/engine/level_script")
const Rom = require("../../port/src/rom/rom")
const TouchControls = require("./TouchControls")
const TouchSprites = require("./TouchSprites")

-- The touch pad of a device with a touch screen (nil on others), kept by its own buttons
const Touch = TouchControls()

-- The ROM starts of the level scripts of the title screen (with the game over screen and the level select) and of the menu (the file select and
-- the act select): the game is in one of them while the level script that runs is
const IntroScript = 0x269EA0
const MenuScript = 0x2A6120

const StickRange = 80
const AButton = 0x8000
const ThumbstickDeadzone = 0.2
-- How far the right thumbstick must be pushed for a C button
const CButtonThreshold = 0.5
const CRight = 0x0001
const CLeft = 0x0002
const CDown = 0x0004
const CUp = 0x0008

const KeyBits = {
	[Enum.KeyCode.Space] = 0x8000,
	[Enum.KeyCode.E] = 0x4000,
	[Enum.KeyCode.Q] = 0x2000,
	[Enum.KeyCode.Return] = 0x1000,
	[Enum.KeyCode.R] = 0x0010,
	[Enum.KeyCode.Up] = 0x0008,
	[Enum.KeyCode.Down] = 0x0004,
	[Enum.KeyCode.Left] = 0x0002,
	[Enum.KeyCode.Right] = 0x0001,
}

const GamepadBits = {
	[Enum.KeyCode.ButtonA] = 0x8000,
	[Enum.KeyCode.ButtonX] = 0x4000,
	[Enum.KeyCode.ButtonL2] = 0x2000,
	[Enum.KeyCode.ButtonStart] = 0x1000,
	[Enum.KeyCode.ButtonR1] = 0x0010,
}

-- What the game is doing, for the touch buttons (which of them do anything, and their icons): a dialog is open, the pause menu is (also the
-- course complete and save screens: the menu mode), the title or game over screen runs, a file or an act select does (they are the two level
-- scripts of the ROM that the game runs for them), or the game is played
const function ModeOf(): TouchSprites.Mode
	if IngameMenu.gDialogID ~= DialogIdsH.DIALOG_NONE then
		return "Dialog"
	elseif IngameMenu.gMenuMode ~= IngameMenu.MENU_MODE_NONE then
		return "Pause"
	-- before the first frame the level script has not started
	elseif LevelScript.sCurrentCmd == 0 then
		return "Play"
	end

	const Script = Rom.BlockOf(LevelScript.sCurrentCmd)

	if Script == IntroScript then
		return "Title"
	elseif Script == MenuScript then
		return "Select"
	end

	return "Play"
end

-- Whether the screen is one of the menus that has a cursor (the title with Mario's head, the file select, the game over screen), which a
-- finger can point at: the levels up to the third, with no pause menu on them
const function Pointing(): boolean
	return IngameMenu.gMenuMode == IngameMenu.MENU_MODE_NONE and Area.gCurrLevelNum <= LevelTableH.LEVEL_UNKNOWN_3
end

-- Moves the cursors of the menus to the finger, as if the stick had taken them there, and presses A for as long as it is down: the file select
-- clicks what is under the cursor when A goes down, Goddard's hand takes hold of the head while A is held (the cursor of a menu is
-- not on the screen when the other one is)
const function Point(Touch: TouchControls.Touch): number
	-- the file select's cursor is in pixels from the middle of the picture, y up
	FileSelect.sCursorPos[1] = math.clamp(Touch.PointerX - 160, -132, 132)
	FileSelect.sCursorPos[2] = math.clamp(120 - Touch.PointerY, -90, 90)
	-- Goddard's hand is in pixels of the picture, y down
	GdMain.gGdCtrl.csrX = Touch.PointerX
	GdMain.gGdCtrl.csrY = Touch.PointerY

	return AButton
end

-- The pad now: what is held
const function ReadPad(): Driver.Pad
	local Buttons = 0
	local StickX = 0
	local StickY = 0

	for Key, Bit in KeyBits do
		if UserInputService:IsKeyDown(Key) then
			Buttons = bit32.bor(Buttons, Bit)
		end
	end

	for Key, Bit in GamepadBits do
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Key) then
			Buttons = bit32.bor(Buttons, Bit)
		end
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		StickX += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		StickX -= 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		StickY += 1
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		StickY -= 1
	end

	for _, State in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if State.KeyCode == Enum.KeyCode.Thumbstick1 then
			if math.abs(State.Position.X) > ThumbstickDeadzone then
				StickX = State.Position.X
			end

			if math.abs(State.Position.Y) > ThumbstickDeadzone then
				StickY = State.Position.Y
			end
		elseif State.KeyCode == Enum.KeyCode.Thumbstick2 then
			-- the right thumbstick is the C buttons
			if State.Position.X > CButtonThreshold then
				Buttons = bit32.bor(Buttons, CRight)
			elseif State.Position.X < -CButtonThreshold then
				Buttons = bit32.bor(Buttons, CLeft)
			end

			if State.Position.Y > CButtonThreshold then
				Buttons = bit32.bor(Buttons, CUp)
			elseif State.Position.Y < -CButtonThreshold then
				Buttons = bit32.bor(Buttons, CDown)
			end
		end
	end

	if Touch ~= nil then
		Touch.SetMode(ModeOf())
		Buttons = bit32.bor(Buttons, Touch.Buttons)

		if Touch.PointerDown and Pointing() then
			Buttons = bit32.bor(Buttons, Point(Touch))
		end

		if Touch.StickX ~= 0 or Touch.StickY ~= 0 then
			StickX = Touch.StickX
			StickY = Touch.StickY
		end
	end

	const Length = math.sqrt(StickX * StickX + StickY * StickY)

	if Length > 1 then
		StickX /= Length
		StickY /= Length
	end

	return { Buttons = Buttons, StickX = math.round(StickX * StickRange), StickY = math.round(StickY * StickRange) }
end

-- Shows the touch controls (they are hidden while the game loads); a device without a touch screen has none
const function Show()
	if Touch ~= nil then
		Touch.SetVisible(true)
	end
end

return { Read = ReadPad, Show = Show }
