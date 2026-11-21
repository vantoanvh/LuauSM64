--!strict
--!optimize 2

--[[
	Boots the port and steps its game loop with a live controller (the Roblox side of harness/loop.luau, harness/port.luau and
	harness/controller.luau, which drive the same functions from a trace).

	Design Notes
		Roblox has no path requires, so the modules are required by name here; they run when Load requires them, after Rom.Load
		(they read the ROM image and the segment table as they run). The boot and the frame are the steps of harness/loop.luau
		without the trace directives; a change there is a change here (a hash run of the harness is what verifies them).
]]

export type Pad = { Buttons: number, StickX: number, StickY: number }

export type Game = {
	Address: number,
	GameInit: typeof(require("../../port/src/game/game_init")),
	LevelScript: typeof(require("../../port/src/engine/level_script")),
	SoundInit: typeof(require("../../port/src/game/sound_init")),
}

const PoolStart = 0x100
const EffectsPoolSize = 0x4000
const LevelScriptEntry = 0x10000000

-- Makes Image the ROM, loads every module and boots the game; returns the Game
const function Load(Image: buffer, DebugLevelSelect: number, Eeprom: { Bytes: buffer, Dirty: boolean }?): Game
	const Rom = require("../../port/src/rom/rom")

	Rom.Load(Image)
	require("../../port/groups/loader")

	const GameInit = require("../../port/src/game/game_init")
	const LevelScript = require("../../port/src/engine/level_script")
	const Main = require("../../port/src/game/main")
	const Memory = require("../../port/src/game/memory")
	const MemoryH = require("../../port/src/game/memory_h")
	const OsCont = require("../../port/include/PR/os_cont_h")
	const SaveFile = require("../../port/src/game/save_file")
	const SoundInit = require("../../port/src/game/sound_init")
	const Symbols = require("../../port/src/rom/symbols")

	Main.gDebugLevelSelect = DebugLevelSelect
	Memory.main_pool_init(PoolStart, Symbols.GoddardZBuffer)
	Memory.gEffectsMemoryPool = Memory.mem_pool_init(EffectsPoolSize, MemoryH.MEMORY_POOL_LEFT)
	GameInit.setup_game_memory()

	-- init_controllers with one standard controller on port 0
	GameInit.gControllers[1].statusData = GameInit.gControllerStatuses[1]
	GameInit.gControllers[1].controllerData = GameInit.gControllerPads[1]
	GameInit.gControllerBits = 1
	GameInit.gControllerStatuses[1].type_ = OsCont.CONT_TYPE_NORMAL
	GameInit.gControllerStatuses[1].status = 0
	GameInit.gControllerStatuses[1].errnum = 0

	SaveFile.AttachEeprom(Eeprom)
	SaveFile.save_file_load_all()
	SoundInit.set_sound_mode(SaveFile.save_file_get_sound_mode())
	GameInit.render_init()

	return {
		Address = Memory.segmented_to_virtual(LevelScriptEntry),
		GameInit = GameInit,
		LevelScript = LevelScript,
		SoundInit = SoundInit,
	}
end

-- One frame of thread5_game_loop with Input as controller 1
const function Step(Game: Game, Input: Pad)
	const GameInit = Game.GameInit

	Game.SoundInit.audio_game_loop_tick()
	GameInit.select_gfx_pool()

	const Pad = GameInit.gControllerPads[1]

	Pad.button = Input.Buttons
	Pad.stick_x = Input.StickX
	Pad.stick_y = Input.StickY
	Pad.errnum = 0

	GameInit.run_demo_inputs()

	for Index = 1, 2 do
		const Player = GameInit.gControllers[Index]
		const Data = Player.controllerData

		if Data ~= nil then
			Player.rawStickX = Data.stick_x
			Player.rawStickY = Data.stick_y
			Player.buttonPressed = bit32.band(Data.button, bit32.bxor(Data.button, Player.buttonDown))
			Player.buttonDown = Data.button
			GameInit.adjust_analog_stick(Player)
		else
			Player.rawStickX = 0
			Player.rawStickY = 0
			Player.buttonPressed = 0
			Player.buttonDown = 0
			Player.stickX = 0
			Player.stickY = 0
			Player.stickMag = 0
		end
	end

	-- Player 1's inputs are copied to player 3's port
	const Player1 = GameInit.gPlayer1Controller
	const Player3 = GameInit.gPlayer3Controller

	Player3.rawStickX = Player1.rawStickX
	Player3.rawStickY = Player1.rawStickY
	Player3.stickX = Player1.stickX
	Player3.stickY = Player1.stickY
	Player3.stickMag = Player1.stickMag
	Player3.buttonPressed = Player1.buttonPressed
	Player3.buttonDown = Player1.buttonDown

	Game.Address = Game.LevelScript.level_script_execute(Game.Address)
	GameInit.display_and_vsync()
end

return { Load = Load, Step = Step }
