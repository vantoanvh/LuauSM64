--!strict
--!optimize 2

--[[
	Connects the game's EEPROM image to the server's save slots.
	Sends a snapshot after a game tick commits changes to the device.
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const SaveFileH = require("../../port/src/game/save_file_h")

export type Device = { Bytes: buffer, Dirty: boolean }

const function Open(): (Device?, RemoteEvent?)
	const Load = ReplicatedStorage:WaitForChild("SM64SaveSlots", 10) :: RemoteFunction?

	if Load == nil then
		warn("SM64 saves are unavailable because the server save script is missing")

		return nil, nil
	end

	const Commit = Load:WaitForChild("Commit") :: RemoteEvent
	const Success, Result = pcall(function(): unknown
		return Load:InvokeServer()
	end)

	if not Success or typeof(Result) ~= "buffer" or buffer.len(Result) ~= SaveFileH.EEPROM_SIZE then
		warn("SM64 saves are unavailable for this session")

		return nil, nil
	end

	return { Bytes = Result, Dirty = false }, Commit
end

const function Send(Device: Device?, Commit: RemoteEvent?)
	if Device ~= nil and Commit ~= nil and Device.Dirty then
		Commit:FireServer(Device.Bytes)
		Device.Dirty = false
	end
end

const function Observe(Report: (string?) -> ())
	const Player = Players.LocalPlayer

	const function Changed()
		const Value = Player:GetAttribute("SM64SaveStatus")

		Report(if type(Value) == "string" and Value ~= "" then Value else nil)
	end

	Player:GetAttributeChangedSignal("SM64SaveStatus"):Connect(Changed)
	Changed()
end

return { Open = Open, Send = Send, Observe = Observe }
