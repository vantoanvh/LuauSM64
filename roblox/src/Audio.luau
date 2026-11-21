--!strict
--!optimize 2

--[[
	Plays the sounds the game asked for in a frame (port/src/rom/audio_recorder) with the files rendered from the game's sound data
	(audio/): a sound effect by its bank and id, a sequence by its id.

	Paradigm
		The game never reads the audio back, so this module is a client of the recorded Events only. Present is called once per game frame
		with the Events of the frame and applies them to Roblox Sounds. The sound files are the temporary assets tools/ImportAudio.luau
		imported in this Studio session; ReplicatedStorage.SM64Audio holds their ids and the manifest of the renderer. Without that module
		there is no sound and no error: the game plays silently (New gives nil, Present does nothing for it).

	Owned State
		The Sound templates (one per clip), the sounds that play, the background music queue and the volume of the two sequence players
		(the level music and the environment jingles).

	Invariants
		A looping sound effect plays while the game requests it in consecutive frames and stops when it does not (the game requests a
		continuous sound every frame). A one-shot sound is not restarted while the game keeps requesting it, nor within DedupeFrames of
		its start. A file that has no id or no manifest entry is an error at New; a sound the game asks for with no file is warned once.

	Design Notes
		Sound effects use the game's distance volume and moving-bank speed. Roblox emits them at their camera-relative direction and
		applies a room effect to the sound bank. Music and menu sounds stay centered.
]]

const ContentProvider = game:GetService("ContentProvider")
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const SoundService = game:GetService("SoundService")

const AudioRecorder = require("../../port/src/rom/audio_recorder")
const IncludeSoundsH = require("../../port/include/sounds_h")

-- A music sequence and the part that repeats, in seconds.
type Clip = { Template: Sound, Loop: boolean, LoopStart: number, LoopEnd: number }

type AtlasEntry = { file: string, startMs: number, endMs: number, loopStartMs: number?, loopEndMs: number? }
type MusicEntry = { file: string, durationMs: number, loopStartMs: number?, loopEndMs: number? }
type Manifest = { gapMs: number, sfx: { [string]: AtlasEntry }, music: { [string]: MusicEntry } }

type Playing = { Sound: Sound, Started: number, Requested: number, Volume: number, Bits: number, Position: { number }? }

-- A sequence player of the game: the sound, the volume it fades to and how fast
type Player = { Sound: Sound?, Clip: Clip?, Base: number, Lowered: boolean, Scale: number, Target: number, Rate: number, Stopping: boolean }

type QueueItem = { SeqId: number, Priority: number }

export type Audio = {
	Folder: Folder,
	Origin: BasePart,
	Room: SoundGroup,
	Reverb: ReverbSoundEffect,
	Reach: number,
	Echo: number,
	MovingSpeed: number,
	Sfx: { [string]: Sound },
	Music: { [number]: Clip },
	Frame: number,
	Looping: { [string]: Playing },
	Last: { [string]: Playing },
	Queue: { QueueItem },
	Players: { Player },
	DisabledBanks: number,
	Muted: boolean,
	-- a sequence plays over the level music at a volume of its own (the merry-go-round), not as a jingle that lowers it
	Secondary: boolean,
	Missing: { [string]: boolean },
	Connection: RBXScriptConnection?,
}

const FrameSeconds = 1 / 30
const AtlasPrerollMs = 32
const SfxGain = 0.8
const MusicGain = 0.5
const DedupeFrames = 3
const MaximumQueue = 6
-- src/audio/external.c
const AudioMaxDistance = 22000
const EmitterDistance = 8
const NoRoomEcho = 0
-- Acoustic reach and the three area echo levels from the level table.
const Acoustics = {
	[4] = { 28000, 40, 40, 40 }, [5] = { 17000, 16, 56, 56 }, [6] = { 20000, 32, 32, 48 },
	[7] = { 16000, 40, 40, 40 }, [8] = { 15000, 8, 48, 48 }, [9] = { 15000, 8, 8, 8 },
	[10] = { 14000, 16, 40, 40 }, [11] = { 17000, 16, 24, 24 }, [12] = { 20000, 16, 24, 24 },
	[13] = { 20000, 12, 12, 32 }, [14] = { 18000, 24, 24, 24 }, [15] = { 20000, 32, 32, 32 },
	[16] = { 25000, 8, 8, 8 }, [17] = { 16000, 40, 40, 40 }, [18] = { 30000, 40, 40, 40 },
	[19] = { 16000, 40, 40, 40 }, [20] = { 20000, 16, 16, 16 }, [21] = { 16000, 40, 40, 40 },
	[22] = { 22000, 8, 48, 48 }, [23] = { 17000, 16, 32, 32 }, [24] = { 13000, 8, 8, 8 },
	[26] = { 20000, 8, 8, 8 }, [27] = { 20000, 40, 40, 40 }, [28] = { 18000, 40, 40, 40 },
	[29] = { 20000, 32, 32, 32 }, [30] = { 20000, 64, 64, 64 }, [31] = { 20000, 40, 40, 40 },
	[33] = { 20000, 64, 64, 64 }, [34] = { 20000, 64, 64, 64 }, [36] = { 15000, 8, 8, 8 },
}
const DefaultAcoustics = { 20000, 0, 0, 0 }
const SoundIdMask = 0x00FF0000
-- the volume the level music is lowered to while the game talks (sLowerBackgroundMusicVolume) and while a jingle plays
const LoweredScale = 0.3
const JingleScale = 0.16
-- the sequence that holds the sound effects of the audio engine: played as music it is silent
const SoundPlayerSequence = 0
const SequencePlayers = 3
const LevelPlayer = 1
const EnvironmentPlayer = 2

-- Reads the files the import tool made: the id of each file and the manifest of the renderer
const function ReadFiles(Module: ModuleScript): ({ [string]: string }, Manifest)
	const Imported = require(Module) :: { Ids: { [string]: string }, Manifest: string }

	return Imported.Ids, HttpService:JSONDecode(Imported.Manifest) :: Manifest
end

const function MakeTemplate(Filename: string, Ids: { [string]: string }, Templates: { Sound }): Sound
	const Id = Ids[Filename]

	assert(Id ~= nil, `{Filename} was not imported: run roblox/tools/ImportAudio.luau and select all files in audio/out/atlases`)

	const Template = Instance.new("Sound")

	Template.Name = Filename
	Template.SoundId = Id
	table.insert(Templates, Template)

	return Template
end

-- Reports the sound files as Roblox finishes fetching them.
const function Preload(Templates: { Sound }, Report: (number, number, string) -> ())
	const Assets: { Sound } = {}
	const Names: { [string]: string } = {}
	local Done = 0
	const Failed: { string } = {}

	for _, Template in Templates do
		const Id = Template.SoundId

		if Names[Id] == nil then
			Names[Id] = Template.Name
			table.insert(Assets, Template)
		end
	end

	Report(0, #Assets, "Fetching sound effects and music")

	ContentProvider:PreloadAsync(Assets, function(ContentId: string, Status: Enum.AssetFetchStatus)
		Done += 1

		if Status ~= Enum.AssetFetchStatus.Success then
			table.insert(Failed, `{ContentId}: {Status.Name}`)
		end

		const Name = Names[ContentId] or ContentId

		Report(math.min(Done, #Assets), #Assets, if Status == Enum.AssetFetchStatus.Success then `Loaded {Name}` else `Could not load {Name}`)
	end)

	assert(#Failed == 0, `{#Failed} sound files did not load, the first: {Failed[1]}`)
end

const function NewPlayer(): Player
	return { Sound = nil, Clip = nil, Base = 1, Lowered = false, Scale = 1, Target = 1, Rate = 1, Stopping = false }
end

-- The distance of a sound source to the camera as intensity and then volume (get_sound_volume of src/audio/external.c)
const function SourceVolume(Self: Audio, Bits: number, Position: { number }?): number
	if Position == nil or bit32.btest(Bits, IncludeSoundsH.SOUND_NO_VOLUME_LOSS) then
		return 1
	end

	const Distance = math.sqrt(Position[1] ^ 2 + Position[2] ^ 2 + Position[3] ^ 2)

	if Distance > AudioMaxDistance then
		return 0
	end

	const Bank = bit32.rshift(Bits, 28)
	const Reach = Self.Reach / (if Bank < 3 then 2 else 3)
	const Intensity = math.max(0, 1 - Distance / Reach)

	return Intensity * Intensity
end

const function WarnOnce(Self: Audio, Key: string, Message: string)
	if not Self.Missing[Key] then
		Self.Missing[Key] = true
		warn(Message)
	end
end

const function StopSound(Sound: Sound)
	const Emitter = Sound.Parent

	Sound:Stop()
	Sound:Destroy()

	if Emitter ~= nil and Emitter:IsA("Attachment") then
		Emitter:Destroy()
	end
end

const function PlaceSfx(Self: Audio, Playing: Playing)
	const Sound = Playing.Sound
	const Bits = Playing.Bits
	const Position = Playing.Position
	const Direction = if Position == nil then vector.zero else vector.create(Position[1], Position[2], Position[3])
	const Distance = vector.magnitude(Direction)
	const Parent = Sound.Parent
	const Camera = workspace.CurrentCamera
	local PlaybackSpeed = 1
	local Volume = Playing.Volume

	if Distance > 0.001 and Camera ~= nil then
		local Emitter: Attachment

		if Parent ~= nil and Parent:IsA("Attachment") then
			Emitter = Parent
		else
			Emitter = Instance.new("Attachment")
			Emitter.Parent = Self.Origin
			Sound.RollOffMinDistance = EmitterDistance * 4
			Sound.RollOffMaxDistance = EmitterDistance * 16
			Sound.Parent = Emitter
		end

		const Offset = Direction / Distance * EmitterDistance

		Emitter.Position = Camera.CFrame:PointToWorldSpace((Offset :: unknown) :: Vector3)
	elseif Parent ~= Self.Folder then
		Sound.Parent = Self.Folder

		if Parent ~= nil and Parent:IsA("Attachment") then
			Parent:Destroy()
		end
	end

	if not bit32.btest(Bits, IncludeSoundsH.SOUND_CONSTANT_FREQUENCY) then
		PlaybackSpeed += math.min(Distance, AudioMaxDistance) / AudioMaxDistance / 15

		if bit32.rshift(Bits, 28) == IncludeSoundsH.SOUND_BANK_MOVING then
			const Flying = bit32.band(Bits, SoundIdMask) == bit32.band(IncludeSoundsH.SOUND_MOVING_FLYING, SoundIdMask)

			PlaybackSpeed += Self.MovingSpeed / (if Flying then 80 else 400)
			Volume *= math.clamp((Self.MovingSpeed + 8) / 16, 0.5, 1)
		end
	end

	Sound.SoundGroup = if bit32.btest(Bits, IncludeSoundsH.SOUND_NO_ECHO) then nil else Self.Room
	Sound.PlaybackSpeed = PlaybackSpeed
	Sound.Volume = Volume
end

-- The volume of a sequence player's sound
const function PlayerVolume(Self: Audio, Player: Player): number
	return if Self.Muted then 0 else Player.Scale * MusicGain
end

-- Where the volume of a player is heading: its own scale, lowered while the game talks, and the level music under a jingle
const function RetargetPlayer(Self: Audio, Index: number)
	const Player = Self.Players[Index]
	local Target = Player.Base

	if Player.Lowered then
		Target = math.min(Target, LoweredScale)
	end

	if Index == LevelPlayer and Self.Players[EnvironmentPlayer].Sound ~= nil and not Self.Secondary then
		Target = math.min(Target, JingleScale)
	end

	Player.Target = Target
end

const function ClearPlayer(Self: Audio, Index: number)
	const Player = Self.Players[Index]

	if Player.Sound ~= nil then
		StopSound(Player.Sound)
	end

	Player.Sound = nil
	Player.Clip = nil
	Player.Stopping = false

	RetargetPlayer(Self, LevelPlayer)
end

-- A looping sound that reached the end of its file goes back to the start of its loop
const function RestartLoop(Sound: Sound, Clip: Clip)
	Sound.TimePosition = Clip.LoopStart
	Sound:Play()
end

-- seq_player_play_sequence: the sequence starts over, fading in over Fade frames
const function PlaySequence(Self: Audio, Index: number, SeqId: number, Fade: number)
	const Player = Self.Players[Index]

	ClearPlayer(Self, Index)

	if SeqId == SoundPlayerSequence then
		return
	end

	-- the variation bit of a sequence id (0x80) has a file only where it changes the music
	const Clip = Self.Music[SeqId] or Self.Music[bit32.band(SeqId, 0x7F)]

	if Clip == nil then
		WarnOnce(Self, `music{SeqId}`, `sequence {SeqId} has no file in the audio manifest`)

		return
	end

	const Sound = Clip.Template:Clone() :: Sound

	Sound.Looped = false
	Player.Sound = Sound
	Player.Clip = Clip
	Player.Base = 1
	Player.Scale = if Fade > 0 then 0 else Player.Base
	Player.Rate = if Fade > 0 then 1 / (Fade * FrameSeconds) else 1
	Sound.Volume = PlayerVolume(Self, Player)
	Sound.Parent = Self.Folder

	Sound.Ended:Connect(function()
		if Player.Sound ~= Sound then
			return
		end

		if Clip.Loop then
			RestartLoop(Sound, Clip)
		else
			ClearPlayer(Self, Index)
		end
	end)
	Sound:Play()
	RetargetPlayer(Self, Index)
	RetargetPlayer(Self, LevelPlayer)
end

-- seq_player_fade_out
const function FadePlayerOut(Self: Audio, Index: number, Duration: number)
	const Player = Self.Players[Index]

	if Player.Sound == nil then
		return
	end

	Player.Stopping = true
	Player.Target = 0
	Player.Rate = 1 / math.max(Duration * FrameSeconds, FrameSeconds)
end

const function RequestSfx(Self: Audio, Bits: number, Position: { number }?)
	const Bank = bit32.rshift(Bits, 28)

	if bit32.btest(Self.DisabledBanks, bit32.lshift(1, Bank)) then
		return
	end

	const Key = `{Bank}_{bit32.band(bit32.rshift(Bits, 16), 0xFF)}`
	const Template = Self.Sfx[Key]

	if Template == nil then
		WarnOnce(Self, `sfx{Key}`, `sound {Key} has no file in the audio manifest`)

		return
	end

	const Volume = SfxGain * SourceVolume(Self, Bits, Position)

	if Template.Looped then
		const Playing = Self.Looping[Key]

		if Playing == nil then
			const Sound = Template:Clone() :: Sound
			const Started = { Sound = Sound, Started = Self.Frame, Requested = Self.Frame, Volume = Volume, Bits = Bits, Position = Position } :: Playing

			PlaceSfx(Self, Started)
			Sound.TimePosition = Sound.PlaybackRegion.Min
			Sound:Play()
			Self.Looping[Key] = Started
		elseif Playing.Requested ~= Self.Frame or Volume > Playing.Volume then
			Playing.Requested = Self.Frame
			Playing.Volume = Volume
			Playing.Bits = Bits
			Playing.Position = Position
		end

		return
	end

	const Last = Self.Last[Key]

	if Last ~= nil and Last.Sound.Parent ~= nil then
		const Repeated = Self.Frame - Last.Started < DedupeFrames
		const Held = Last.Requested == Self.Frame - 1 and Last.Sound.IsPlaying

		Last.Requested = Self.Frame

		if Repeated or Held then
			return
		end
	end

	const Sound = Template:Clone() :: Sound
	const Started = { Sound = Sound, Started = Self.Frame, Requested = Self.Frame, Volume = Volume, Bits = Bits, Position = Position } :: Playing

	PlaceSfx(Self, Started)
	Sound.Ended:Once(function()
		StopSound(Sound)
	end)
	Sound.TimePosition = Sound.PlaybackRegion.Min
	Sound:Play()
	Self.Last[Key] = Started
end

const function StopLoops(Self: Audio, Key: string?)
	for Name, Playing in Self.Looping do
		if Key == nil or Key == Name then
			StopSound(Playing.Sound)
			Self.Looping[Name] = nil
		end
	end
end

const function StopSfx(Self: Audio, Bits: number)
	const Key = `{bit32.rshift(Bits, 28)}_{bit32.band(bit32.rshift(Bits, 16), 0xFF)}`

	StopLoops(Self, Key)

	const Last = Self.Last[Key]

	if Last ~= nil and Last.Sound.Parent ~= nil then
		StopSound(Last.Sound)
	end
end

-- play_music of src/audio/external.c: the level player has a queue by priority, the others play at once
const function OnPlayMusic(Self: Audio, Event: AudioRecorder.Event)
	const Player, SeqArgs, Fade = Event.Args[1], Event.Args[2], Event.Args[3]
	const SeqId = bit32.band(SeqArgs, 0xFF)
	const Priority = bit32.rshift(SeqArgs, 8)

	if Player ~= 0 then
		PlaySequence(Self, Player + 1, SeqId, Fade)

		return
	end

	const Queue = Self.Queue

	if #Queue == MaximumQueue then
		return
	end

	for Index, Item in Queue do
		if Item.SeqId == SeqId then
			if Index == 1 then
				PlaySequence(Self, LevelPlayer, SeqId, Fade)
			end

			return
		end
	end

	local Found = #Queue + 1

	for Index, Item in Queue do
		if Item.Priority <= Priority then
			Found = Index

			break
		end
	end

	table.insert(Queue, Found, { SeqId = SeqId, Priority = Priority })

	if Found == 1 then
		PlaySequence(Self, LevelPlayer, SeqId, Fade)
	elseif #Queue > MaximumQueue then
		table.remove(Queue)
	end
end

const function OnStopBackgroundMusic(Self: Audio, Event: AudioRecorder.Event)
	const SeqId = bit32.band(Event.Args[1], 0xFF)

	for Index, Item in Self.Queue do
		if Item.SeqId == SeqId then
			table.remove(Self.Queue, Index)

			if Index == 1 then
				if #Self.Queue > 0 then
					PlaySequence(Self, LevelPlayer, Self.Queue[1].SeqId, 0)
				else
					FadePlayerOut(Self, LevelPlayer, 20)
				end
			end

			return
		end
	end
end

const function OnFadeoutBackgroundMusic(Self: Audio, Event: AudioRecorder.Event)
	const Head = Self.Queue[1]

	if Head ~= nil and Head.SeqId == bit32.band(Event.Args[1], 0xFF) then
		FadePlayerOut(Self, LevelPlayer, Event.Args[2])
		table.remove(Self.Queue, 1)
	end
end

const function OnSeqPlayerFadeOut(Self: Audio, Event: AudioRecorder.Event)
	const Player = Event.Args[1]

	FadePlayerOut(Self, Player + 1, Event.Args[2])

	if Player == 0 then
		table.clear(Self.Queue)
	end
end

const function OnFadeVolumeScale(Self: Audio, Event: AudioRecorder.Event)
	const Index = Event.Args[1] + 1
	const Player = Self.Players[Index]

	Player.Base = Event.Args[2] / 127
	Player.Rate = 1 / math.max(Event.Args[3] * FrameSeconds, FrameSeconds)
	RetargetPlayer(Self, Index)
end

const function OnSeqPlayerLowerVolume(Self: Audio, Event: AudioRecorder.Event)
	const Index = Event.Args[1] + 1
	const Player = Self.Players[Index]

	Player.Lowered = true
	Player.Rate = 1 / math.max(Event.Args[2] * FrameSeconds, FrameSeconds)
	RetargetPlayer(Self, Index)
end

const function OnSeqPlayerUnlowerVolume(Self: Audio, Event: AudioRecorder.Event)
	const Index = Event.Args[1] + 1
	const Player = Self.Players[Index]

	Player.Lowered = false
	Player.Rate = 1 / math.max(Event.Args[2] * FrameSeconds, FrameSeconds)
	RetargetPlayer(Self, Index)
end

const function OnPlaySound(Self: Audio, Event: AudioRecorder.Event)
	RequestSfx(Self, Event.Args[1], Event.Position)
end

const function OnStopSound(Self: Audio, Event: AudioRecorder.Event)
	StopSfx(Self, Event.Args[1])
end

const function OnStopSoundsInContinuousBanks(Self: Audio)
	StopLoops(Self, nil)
end

const function OnSoundBanksDisable(Self: Audio, Event: AudioRecorder.Event)
	Self.DisabledBanks = bit32.bor(Self.DisabledBanks, Event.Args[2])

	for Key in Self.Looping do
		if bit32.btest(Self.DisabledBanks, bit32.lshift(1, tonumber(string.match(Key, "^(%d+)_")) :: number)) then
			StopLoops(Self, Key)
		end
	end
end

const function OnSoundBanksEnable(Self: Audio, Event: AudioRecorder.Event)
	Self.DisabledBanks = bit32.band(Self.DisabledBanks, bit32.bnot(Event.Args[2]))
end

const function OnPlaySecondaryMusic(Self: Audio, Event: AudioRecorder.Event)
	const SeqId, BackgroundVolume, Volume, Fade = Event.Args[1], Event.Args[2], Event.Args[3], Event.Args[4]

	if #Self.Queue == 0 or Self.Secondary then
		return
	end

	Self.Secondary = true

	const Level = Self.Players[LevelPlayer]

	Level.Base = BackgroundVolume / 127
	Level.Rate = 1 / math.max(Fade * FrameSeconds, FrameSeconds)
	PlaySequence(Self, EnvironmentPlayer, SeqId, bit32.rshift(Fade, 1))

	if Volume < 128 then
		Self.Players[EnvironmentPlayer].Base = Volume / 127
		RetargetPlayer(Self, EnvironmentPlayer)
	end

	RetargetPlayer(Self, LevelPlayer)
end

const function OnStopSecondaryMusic(Self: Audio, Event: AudioRecorder.Event)
	if not Self.Secondary then
		return
	end

	const Level = Self.Players[LevelPlayer]

	Self.Secondary = false
	Level.Base = 1
	Level.Rate = 1 / math.max(Event.Args[1] * FrameSeconds, FrameSeconds)
	FadePlayerOut(Self, EnvironmentPlayer, Event.Args[1])
	RetargetPlayer(Self, LevelPlayer)
end

const function OnSoundReset(Self: Audio)
	StopLoops(Self, nil)

	for Key, Last in Self.Last do
		if Last.Sound.Parent ~= nil then
			StopSound(Last.Sound)
		end

		Self.Last[Key] = nil
	end

	for Index, Player in Self.Players do
		ClearPlayer(Self, Index)

		Player.Base = 1
		Player.Lowered = false
		Player.Scale = 1
	end

	table.clear(Self.Queue)
	Self.Secondary = false
	Self.DisabledBanks = 0
	Self.MovingSpeed = 0
end

const function OnFadeOutAll(Self: Audio, Event: AudioRecorder.Event)
	FadePlayerOut(Self, LevelPlayer, Event.Args[1])
	FadePlayerOut(Self, EnvironmentPlayer, Event.Args[1])
	table.clear(Self.Queue)
	StopLoops(Self, nil)
end

const function OnDropQueuedBackgroundMusic(Self: Audio)
	for Index = #Self.Queue, 2, -1 do
		table.remove(Self.Queue, Index)
	end
end

const function OnSetAudioMuted(Self: Audio, Event: AudioRecorder.Event)
	Self.Muted = Event.Args[1] ~= 0
end

-- The sounds of sources stop when they stop being requested.
const function OnStopSoundsFromSource()
end

const function OnSetSoundMovingSpeed(Self: Audio, Event: AudioRecorder.Event)
	if Event.Args[1] == IncludeSoundsH.SOUND_BANK_MOVING then
		Self.MovingSpeed = bit32.band(Event.Args[2], 255)
	end
end
-- the dialog and the fanfares are expanded into the calls above by the recorder
const function OnPlayDialogSound()
end

-- The recorder's function names and how each is applied
const Handlers = {
	["stop_sounds_from_source"] = OnStopSoundsFromSource,
	["set_sound_moving_speed"] = OnSetSoundMovingSpeed,
	["play_dialog_sound"] = OnPlayDialogSound,
	["play_music"] = OnPlayMusic,
	["stop_background_music"] = OnStopBackgroundMusic,
	["fadeout_background_music"] = OnFadeoutBackgroundMusic,
	["seq_player_fade_out"] = OnSeqPlayerFadeOut,
	["fade_volume_scale"] = OnFadeVolumeScale,
	["seq_player_lower_volume"] = OnSeqPlayerLowerVolume,
	["seq_player_unlower_volume"] = OnSeqPlayerUnlowerVolume,
	["play_sound"] = OnPlaySound,
	["stop_sound"] = OnStopSound,
	["stop_sounds_in_continuous_banks"] = OnStopSoundsInContinuousBanks,
	["sound_banks_disable"] = OnSoundBanksDisable,
	["sound_banks_enable"] = OnSoundBanksEnable,
	["play_secondary_music"] = OnPlaySecondaryMusic,
	["stop_secondary_music"] = OnStopSecondaryMusic,
	["sound_reset"] = OnSoundReset,
	["fade_out_all"] = OnFadeOutAll,
	["drop_queued_background_music"] = OnDropQueuedBackgroundMusic,
	["set_audio_muted"] = OnSetAudioMuted,
} :: { [string]: (Audio, AudioRecorder.Event) -> () }

-- Repeats a looping sound at its loop point
const function Wrap(Sound: Sound, Clip: Clip)
	if Clip.Loop and Sound.TimePosition >= Clip.LoopEnd then
		Sound.TimePosition = Clip.LoopStart + (Sound.TimePosition - Clip.LoopEnd)
	end
end

const function WrapMusicLoops(Self: Audio)
	for _, Player in Self.Players do
		if Player.Sound ~= nil and Player.Clip ~= nil then
			Wrap(Player.Sound, Player.Clip)
		end
	end
end

-- Builds the clips and reports completed and total files while Roblox loads them. The sound is optional: with no
-- ReplicatedStorage.SM64Audio (the files rendered from the ROM and imported by roblox/tools/ImportAudio.luau) the game plays silently, and
-- there is no Audio (Present does nothing for it).
const function New(Report: (number, number, string) -> ()): Audio?
	const Module = ReplicatedStorage:FindFirstChild("SM64Audio")

	if Module == nil or not Module:IsA("ModuleScript") then
		warn("SM64 has no sound: render the sounds from your ROM (audio/README.md) and run roblox/tools/ImportAudio.luau to hear them")

		return nil
	end

	const Ids, Manifest = ReadFiles(Module)
	const PrerollMs = math.min(AtlasPrerollMs, Manifest.gapMs)
	const Templates: { Sound } = {}
	const Sfx: { [string]: Sound } = {}
	const Music: { [number]: Clip } = {}

	for Key, Entry in Manifest.sfx do
		const Template = MakeTemplate(Entry.file, Ids, Templates)
		const LoopStartMs = Entry.loopStartMs
		const LoopEndMs = Entry.loopEndMs
		-- Seek into the preceding silence so Roblox's Ogg seek does not clip the attack.
		const PlaybackStartMs = math.max(0, Entry.startMs - PrerollMs)

		Template.PlaybackRegionsEnabled = true
		Template.PlaybackRegion = NumberRange.new(PlaybackStartMs / 1000, (LoopEndMs or Entry.endMs) / 1000)

		if LoopStartMs ~= nil and LoopEndMs ~= nil then
			Template.Looped = true
			Template.LoopRegion = NumberRange.new(LoopStartMs / 1000, LoopEndMs / 1000)
		end

		Sfx[Key] = Template
	end

	for Key, Entry in Manifest.music do
		Music[tonumber(Key) :: number] = {
			Template = MakeTemplate(Entry.file, Ids, Templates),
			Loop = Entry.loopEndMs ~= nil,
			LoopStart = (Entry.loopStartMs or 0) / 1000,
			LoopEnd = (Entry.loopEndMs or Entry.durationMs) / 1000,
		}
	end

	Preload(Templates, Report)

	const Folder = Instance.new("Folder")

	Folder.Name = "SM64Sounds"
	Folder.Parent = SoundService

	const Origin = Instance.new("Part")
	const Room = Instance.new("SoundGroup")
	const Reverb = Instance.new("ReverbSoundEffect")

	Origin.Name = "SM64SoundSources"
	Origin.Anchored = true
	Origin.CanCollide = false
	Origin.CanQuery = false
	Origin.CanTouch = false
	Origin.CastShadow = false
	Origin.Transparency = 1
	Origin.CFrame = CFrame.identity
	Origin.Parent = workspace
	Room.Name = "SM64RoomSound"
	Room.Parent = SoundService
	Reverb.Enabled = false
	Reverb.DryLevel = 0
	Reverb.Parent = Room

	const Players: { Player } = {}

	for _ = 1, SequencePlayers do
		table.insert(Players, NewPlayer())
	end

	const Self = {
		Folder = Folder,
		Origin = Origin,
		Room = Room,
		Reverb = Reverb,
		Reach = DefaultAcoustics[1],
		Echo = NoRoomEcho,
		MovingSpeed = 0,
		Sfx = Sfx,
		Music = Music,
		Frame = 0,
		Looping = {},
		Last = {},
		Queue = {},
		Players = Players,
		DisabledBanks = 0,
		Muted = false,
		Secondary = false,
		Missing = {},
		Connection = nil,
	} :: Audio

	Self.Connection = RunService.PreRender:Connect(function()
		WrapMusicLoops(Self)
	end)

	return Self
end

-- Applies the Events of a game frame
const function Present(Self: Audio?, Events: { AudioRecorder.Event }, Level: number, Area: number)
	if Self == nil then
		return
	end

	Self.Frame += 1

	const LevelAcoustics: { number }? = Acoustics[Level]
	const Profile: { number } = if LevelAcoustics == nil then DefaultAcoustics else LevelAcoustics
	const Echo = Profile[math.clamp(Area, 1, 3) + 1]

	Self.Reach = Profile[1]

	if Echo ~= Self.Echo then
		Self.Echo = Echo
		Self.Reverb.Enabled = Echo > NoRoomEcho

		if Echo > NoRoomEcho then
			Self.Reverb.WetLevel = 20 * math.log10(Echo / 127) - 6
			Self.Reverb.DecayTime = math.lerp(0.35, 1.7, Echo / 127)
		end
	end

	for _, Event in Events do
		Handlers[Event.Name](Self, Event)
	end

	for Key, Playing in Self.Looping do
		if Playing.Requested < Self.Frame - 1 then
			StopSound(Playing.Sound)
			Self.Looping[Key] = nil
		else
			PlaceSfx(Self, Playing)
		end
	end

	for Index, Player in Self.Players do
		const Sound = Player.Sound

		if Sound == nil then
			continue
		end

		const Step = Player.Rate * FrameSeconds

		Player.Scale = if Player.Scale < Player.Target then math.min(Player.Scale + Step, Player.Target) else math.max(Player.Scale - Step, Player.Target)
		Sound.Volume = PlayerVolume(Self, Player)

		if Player.Stopping and Player.Scale <= 0 then
			ClearPlayer(Self, Index)
		end
	end
end

return { New = New, Present = Present }
