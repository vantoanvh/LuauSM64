--!strict
--!optimize 2

--[[
	Audio recorder: the sound requests the game makes in one frame, kept for the audio of a client.

	Paradigm
		The port has no audio engine (audio-os-externals): the C calls into src/audio/external.c are replaced here by functions of the
		same names that record the request. Begin turns recording on, End returns the Events of the frame and turns it off; while disabled
		a call costs one boolean test and never changes game state (the game reads nothing back from the audio: the native harness stubs
		these calls as no-ops, and get_current_background_music reports silence). A client plays each event with a file it rendered from
		the game's own sound data (audio/): a sound effect by its bank and id, a sequence by its id.

	Owned State
		Enabled, and the Events of the frame being recorded.

	Design Notes
		An Event is the name of the C function and its numeric arguments in the order of the C signature (soundBits, player, seqArgs,
		fade times, bank masks); Position is a copy of the sound source the call named (gGlobalSoundSource, the cameraToObject of an
		object: the position in the view space of the camera), nil when the call has none. Returns of the C functions are not modeled:
		the game never uses them.
]]

const IncludeSeqIdsH = require("../../include/seq_ids_h")
const IncludeSoundsH = require("../../include/sounds_h")

export type Event = { Name: string, Args: { number }, Position: { number }? }

-- The sequence players of src/audio/external.h
const SeqPlayerEnv = 1

-- Who speaks each dialog (src/audio/external.c sDialogSpeaker, 17 rows of 10; 255 is nobody) and the voice of each speaker
const NoSpeaker = 255
const SpeakerRows = {
	"255 6 6 6 6 3 3 3 255 3",
	"255 255 255 255 255 255 255 4 255 255",
	"255 2 2 2 2 2 2 2 2 2",
	"255 255 255 255 255 255 255 1 255 255",
	"255 3 255 255 255 255 255 6 255 255",
	"255 255 255 255 255 1 1 1 1 1",
	"255 255 255 255 255 255 255 7 255 255",
	"255 255 255 255 255 255 255 255 255 0",
	"0 255 255 255 255 5 255 255 255 255",
	"7 255 7 7 255 255 255 255 5 5",
	"0 0 255 255 255 6 6 5 5 255",
	"255 255 255 255 8 8 4 8 8 255",
	"255 255 255 255 255 255 255 255 4 255",
	"255 255 1 255 255 255 255 255 255 255",
	"255 255 255 255 255 255 255 255 255 255",
	"9 9 9 255 255 255 255 255 255 255",
	"255 10 255 255 255 255 255 255 9 255",
}
const KoopaMessageSpeaker = 2
const SpeakerVoices = {
	[0] = IncludeSoundsH.SOUND_OBJ_UKIKI_CHATTER_LONG,
	IncludeSoundsH.SOUND_OBJ_BIG_PENGUIN_YELL,
	IncludeSoundsH.SOUND_OBJ_BOWSER_INTRO_LAUGH,
	IncludeSoundsH.SOUND_OBJ_KOOPA_TALK,
	IncludeSoundsH.SOUND_OBJ_KING_BOBOMB_TALK,
	IncludeSoundsH.SOUND_OBJ_BOO_LAUGH_LONG,
	IncludeSoundsH.SOUND_OBJ_BOBOMB_BUDDY_TALK,
	IncludeSoundsH.SOUND_OBJ_BOWSER_LAUGH,
	IncludeSoundsH.SOUND_OBJ2_BOSS_DIALOG_GRUNT,
	IncludeSoundsH.SOUND_OBJ_WIGGLER_TALK,
	IncludeSoundsH.SOUND_GENERAL_YOSHI_TALK,
}
const DialogCount = 170
-- The dialogs of the cap switches: "You've stepped on the Wing, Metal, Vanish Cap Switch" (DIALOG_010 to DIALOG_012)
const FirstCapDialog = 10
const LastCapDialog = 12

const Speakers: { number } = {}

for _, Row in SpeakerRows do
	for Text in string.gmatch(Row, "%d+") do
		table.insert(Speakers, tonumber(Text) :: number)
	end
end

const Audio = {
	Enabled = false,
	Events = {} :: { Event },
	-- the source of the sounds that have none in the world (the menus, the HUD): the camera's own place
	gGlobalSoundSource = { 0, 0, 0 } :: { number },
}

-- The position of a sound source as three numbers, copied (the game rewrites its vectors)
const function Copy(Source: { number }?): { number }?
	if Source == nil then
		return nil
	end

	return { Source[1], Source[2], Source[3] }
end

const function Record(Name: string, Args: { number }, Source: { number }?)
	if Audio.Enabled then
		table.insert(Audio.Events, { Name = Name, Args = Args, Position = Copy(Source) })
	end
end

function Audio.Begin()
	Audio.Events = {}
	Audio.Enabled = true
end

function Audio.End(): { Event }
	Audio.Enabled = false

	return Audio.Events
end

-- src/audio/external.c
function Audio.play_sound(SoundBits: number, Position: { number }?)
	Record("play_sound", { SoundBits }, Position)
end

function Audio.stop_sound(SoundBits: number, Position: { number }?)
	Record("stop_sound", { SoundBits }, Position)
end

function Audio.stop_sounds_from_source(Position: { number }?)
	Record("stop_sounds_from_source", {}, Position)
end

function Audio.stop_sounds_in_continuous_banks()
	Record("stop_sounds_in_continuous_banks", {}, nil)
end

function Audio.sound_banks_disable(Player: number, BankMask: number)
	Record("sound_banks_disable", { Player, BankMask }, nil)
end

function Audio.sound_banks_enable(Player: number, BankMask: number)
	Record("sound_banks_enable", { Player, BankMask }, nil)
end

function Audio.set_sound_moving_speed(Bank: number, Speed: number)
	Record("set_sound_moving_speed", { Bank, Speed }, nil)
end

-- src/audio/external.c play_dialog_sound: the voice of the speaker, the message music of Bowser, the jingle of the cap switches
function Audio.play_dialog_sound(DialogId: number)
	const Dialog = if DialogId >= DialogCount then 0 else DialogId
	const Speaker = Speakers[Dialog + 1]

	if Speaker ~= NoSpeaker then
		Audio.play_sound(SpeakerVoices[Speaker], Audio.gGlobalSoundSource)

		if Speaker == KoopaMessageSpeaker then
			Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_KOOPA_MESSAGE, 0)
		end
	end

	if Dialog >= FirstCapDialog and Dialog <= LastCapDialog then
		Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_SOLVE_PUZZLE, 0)
	end
end

function Audio.play_music(Player: number, SeqArgs: number, FadeTimer: number)
	Record("play_music", { Player, SeqArgs, FadeTimer }, nil)
end

-- src/audio/external.c: the fanfares play over the level music, which they fade down
function Audio.play_star_fanfare()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_HIGH_SCORE, 0)
end

function Audio.play_race_fanfare()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_RACE, 0)
end

function Audio.play_puzzle_jingle()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_SOLVE_PUZZLE, 0)
end

-- the argument (the level music is cut at once when it is FALSE) does not change the sequence
function Audio.play_power_star_jingle(_: number)
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_STAR_SPAWN, 0)
end

function Audio.play_course_clear()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_CUTSCENE_COLLECT_STAR, 0)
end

function Audio.play_peachs_jingle()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_PEACH_MESSAGE, 0)
end

function Audio.play_toads_jingle()
	Audio.play_music(SeqPlayerEnv, IncludeSeqIdsH.SEQ_EVENT_TOAD_MESSAGE, 0)
end

-- A second sequence over the level music (the merry-go-round, the piranha plants), the level music at BackgroundVolume
function Audio.play_secondary_music(SeqId: number, BackgroundVolume: number, Volume: number, FadeTimer: number)
	Record("play_secondary_music", { SeqId, BackgroundVolume, Volume, FadeTimer }, nil)
end

-- func_80321080 of src/audio/external.c: the secondary music fades out and the level music returns
function Audio.stop_secondary_music(FadeTimer: number)
	Record("stop_secondary_music", { FadeTimer }, nil)
end

-- src/audio/external.c sound_reset: every sequence and sound stops (the preset of the audio heap is not modeled)
function Audio.sound_reset(PresetId: number)
	Record("sound_reset", { PresetId }, nil)
end

-- func_803210D4: the music and the sounds but the menu's fade out
function Audio.fade_out_all(FadeDuration: number)
	Record("fade_out_all", { FadeDuration }, nil)
end

function Audio.drop_queued_background_music()
	Record("drop_queued_background_music", {}, nil)
end

function Audio.stop_background_music(SeqId: number)
	Record("stop_background_music", { SeqId }, nil)
end

function Audio.fadeout_background_music(SeqId: number, FadeOut: number)
	Record("fadeout_background_music", { SeqId, FadeOut }, nil)
end

function Audio.seq_player_fade_out(Player: number, FadeDuration: number)
	Record("seq_player_fade_out", { Player, FadeDuration }, nil)
end

function Audio.fade_volume_scale(Player: number, TargetScale: number, FadeDuration: number)
	Record("fade_volume_scale", { Player, TargetScale, FadeDuration }, nil)
end

function Audio.seq_player_lower_volume(Player: number, FadeDuration: number, Percentage: number)
	Record("seq_player_lower_volume", { Player, FadeDuration, Percentage }, nil)
end

function Audio.seq_player_unlower_volume(Player: number, FadeDuration: number)
	Record("seq_player_unlower_volume", { Player, FadeDuration }, nil)
end

function Audio.set_audio_muted(Muted: number)
	Record("set_audio_muted", { Muted }, nil)
end

return Audio
