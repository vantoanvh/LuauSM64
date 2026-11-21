--!strict
--!optimize 2

--[[
	Stores one EEPROM image per Roblox player. The game owns the four slots and their checksums.
	A renewable DataStore lease keeps an outgoing session and a rejoining session from overwriting each other.
]]

const DataStoreService = game:GetService("DataStoreService")
const EncodingService = game:GetService("EncodingService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const SaveFileH = require("../../port/src/game/save_file_h")

const LeaseSeconds = 120
const RenewalSeconds = 60
const WriteInterval = 6
const OpenAttempts = 6
const CloseAttempts = 3
const ShutdownSeconds = 25
const StatusAttribute = "SM64SaveStatus"
const Unavailable = "Saves unavailable this session"
const Retry = "Save pending. Retrying…"

type Record = { Image: string, Owner: string, Expires: number }

type Session = {
	Key: string,
	Owner: string,
	Image: string,
	Saved: string,
	Ready: boolean,
	Closing: boolean,
}

const Store = if game.GameId == 0 then nil else DataStoreService:GetDataStore(if RunService:IsStudio() then "SM64SaveSlotsStudio" else "SM64SaveSlots")
const Sessions: { [Player]: Session } = {}
const Open = Instance.new("RemoteFunction")
const Commit = Instance.new("RemoteEvent")
local ShuttingDown = false

const function Write(Player: Player, Session: Session, Data: DataStore)
	local WrittenAt = os.clock()
	local CloseFailures = 0

	while true do
		const Closing = Session.Closing
		const Image = Session.Image
		const Elapsed = os.clock() - WrittenAt

		if Closing or Elapsed >= RenewalSeconds or (Image ~= Session.Saved and Elapsed >= WriteInterval) then
			const Owner = if Closing then "" else Session.Owner
			const Ok, Result = pcall(function()
				return Data:UpdateAsync(Session.Key, function(Stored: Record?): Record?
					if Stored == nil or Stored.Owner ~= Session.Owner then
						return nil
					end

					return { Image = Image, Owner = Owner, Expires = if Closing then 0 else os.time() + LeaseSeconds }
				end)
			end)

			if Ok then
				if type(Result) ~= "table" or (Result :: Record).Owner ~= Owner or (Result :: Record).Image ~= Image then
					Player:SetAttribute(StatusAttribute, Unavailable)

					break
				end

				Session.Saved = Image
				WrittenAt = os.clock()

				if Closing then
					break
				end

				if Session.Image == Image then
					Player:SetAttribute(StatusAttribute, "")
				end
			else
				Player:SetAttribute(StatusAttribute, Retry)
				warn(`SM64 save write failed for {Player.UserId}: {Result}`)

				if Closing then
					CloseFailures += 1

					if CloseFailures >= CloseAttempts then
						break
					end
				end

				task.wait(2)
			end
		else
			task.wait(1)
		end
	end

	Sessions[Player] = nil
end

const function Load(Player: Player): buffer?
	if ShuttingDown or Sessions[Player] ~= nil then
		return nil
	end

	const Data = Store

	if Data == nil then
		Player:SetAttribute(StatusAttribute, Unavailable)

		return nil
	end

	const Session = { Key = `slot:{Player.UserId}`, Owner = HttpService:GenerateGUID(false), Image = "", Saved = "", Ready = false, Closing = false }

	Sessions[Player] = Session

	for Attempt = 1, OpenAttempts do
		const Ok, Value = pcall(function()
			return Data:UpdateAsync(Session.Key, function(Stored: unknown): Record?
				if type(Stored) == "table" then
					const Existing = Stored :: Record

					if type(Existing.Image) ~= "string" or type(Existing.Owner) ~= "string" or type(Existing.Expires) ~= "number" then
						return nil
					end

					if Existing.Owner ~= "" and Existing.Owner ~= Session.Owner and Existing.Expires > os.time() then
						return nil
					end

					return { Image = Existing.Image, Owner = Session.Owner, Expires = os.time() + LeaseSeconds }
				elseif Stored == nil then
					return { Image = "", Owner = Session.Owner, Expires = os.time() + LeaseSeconds }
				end

				return nil
			end)
		end)

		if Ok and type(Value) == "table" and (Value :: Record).Owner == Session.Owner then
			const Record = Value :: Record
			const Image = Record.Image
			const Valid, Bytes = pcall(function()
				return if Image == "" then buffer.create(SaveFileH.EEPROM_SIZE) else EncodingService:Base64Decode(buffer.fromstring(Image))
			end)

			Session.Image = Image
			Session.Saved = Image

			if not Valid or buffer.len(Bytes) ~= SaveFileH.EEPROM_SIZE then
				Session.Closing = true
				Player:SetAttribute(StatusAttribute, Unavailable)
				task.spawn(Write, Player, Session, Data)

				return nil
			end

			Session.Ready = not Session.Closing
			task.spawn(Write, Player, Session, Data)

			return if Session.Ready then Bytes else nil
		end

		if Session.Closing or Attempt == OpenAttempts then
			if not Ok then
				warn(`SM64 save load failed for {Player.UserId}: {Value}`)
			end

			break
		end

		task.wait(2)
	end

	Sessions[Player] = nil
	Player:SetAttribute(StatusAttribute, Unavailable)

	return nil
end

const function Receive(Player: Player, Bytes: unknown)
	const Session = Sessions[Player]

	if Session == nil or not Session.Ready or Session.Closing or typeof(Bytes) ~= "buffer" or buffer.len(Bytes) ~= SaveFileH.EEPROM_SIZE then
		return
	end

	const Image = buffer.tostring(EncodingService:Base64Encode(Bytes))

	if Image ~= Session.Image then
		Session.Image = Image
		Player:SetAttribute(StatusAttribute, "Saving…")
	end
end

const function Close(Player: Player)
	const Session = Sessions[Player]

	if Session ~= nil then
		Session.Closing = true
	end
end

const function Shutdown()
	ShuttingDown = true

	for _, Session in Sessions do
		Session.Closing = true
	end

	const Deadline = os.clock() + ShutdownSeconds

	while next(Sessions) ~= nil and os.clock() < Deadline do
		task.wait()
	end
end

Open.Name = "SM64SaveSlots"
Open.OnServerInvoke = Load
Commit.Name = "Commit"
Commit.OnServerEvent:Connect(Receive)
Commit.Parent = Open
Open.Parent = ReplicatedStorage
Players.PlayerRemoving:Connect(Close)
game:BindToClose(Shutdown)
