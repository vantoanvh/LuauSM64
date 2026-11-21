--!strict
--!optimize 2

--[[
	Port of src/game/sound_init.c.
]]

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const Audio = require("../rom/audio_recorder")
const IncludePROsMessageH = require("../../include/PR/os_message_h")
const IncludeSoundsH = require("../../include/sounds_h")
const IncludeLevelTableH = require("../../include/level_table_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const Registry = require("../../groups/registry")
const IncludeSeqIdsH = require("../../include/seq_ids_h")

-- SEQ_PLAYER_LEVEL and SEQ_PLAYER_SFX of src/audio/external.h
const SeqPlayerLevel = 0
const SeqPlayerSfx = 2

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/sound_init.c:data
const sound_init = {
	MUSIC_NONE = 0xFFFF,
	-- from src/game/sound_init.c:unused80339DC0 L21-21
	unused80339DC0 = table.create(3, 0),
	-- from src/game/sound_init.c:sSoundMesgQueue L22-22
	sSoundMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/sound_init.c:sSoundMesgBuf L23-23
	sSoundMesgBuf = { nil },
	-- from src/game/sound_init.c:sSoundVblankHandler L24-24
	sSoundVblankHandler = { queue = nil, msg = nil } :: GroupsTypesHPlus3.VblankHandler,
	-- from src/game/sound_init.c:sMusicVolume L27-27
	sMusicVolume = 0,
	-- from src/game/sound_init.c:sBgMusicDisabled L29-29
	sBgMusicDisabled = 0,
	-- from src/game/sound_init.c:sPlayingInfiniteStairs L33-33
	sPlayingInfiniteStairs = 0,
	-- from src/game/sound_init.c:unused8032C6D8 L34-34
	unused8032C6D8 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
	-- from src/game/sound_init.c:sSoundMenuModeToSoundMode L35-35
	sSoundMenuModeToSoundMode = { nil --[[ ? SOUND_MODE_STEREO ]], nil --[[ ? SOUND_MODE_MONO ]], nil --[[ ? SOUND_MODE_HEADSET ]] },
	-- from src/game/sound_init.c:sMenuSoundsExtra L37-74
	sMenuSoundsExtra = {
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 0,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 65536,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 131072,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 196608,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 262144,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 327680,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_SLIDE + 393216,
		IncludeSoundsH.SOUND_MOVING_LAVA_BURN,
		IncludeSoundsH.SOUND_MOVING_SLIDE_DOWN_TREE,
		IncludeSoundsH.SOUND_MOVING_SLIDE_DOWN_POLE,
		IncludeSoundsH.SOUND_MOVING_QUICKSAND_DEATH,
		IncludeSoundsH.SOUND_MOVING_TERRAIN_RIDING_SHELL,
		IncludeSoundsH.NO_SOUND,
		IncludeSoundsH.SOUND_ENV_BOAT_ROCKING1,
		IncludeSoundsH.SOUND_ENV_ELEVATOR3,
		IncludeSoundsH.SOUND_ENV_UNKNOWN2,
		IncludeSoundsH.SOUND_ENV_WATERFALL1,
		IncludeSoundsH.SOUND_ENV_WATERFALL2,
		IncludeSoundsH.SOUND_ENV_ELEVATOR1,
		IncludeSoundsH.SOUND_ENV_DRONING1,
		IncludeSoundsH.SOUND_ENV_DRONING2,
		IncludeSoundsH.SOUND_ENV_ELEVATOR2,
		IncludeSoundsH.SOUND_ENV_WIND1,
		IncludeSoundsH.SOUND_ENV_WATER,
		IncludeSoundsH.SOUND_AIR_BOWSER_SPIT_FIRE,
		IncludeSoundsH.SOUND_MOVING_AIM_CANNON,
		IncludeSoundsH.SOUND_AIR_LAKITU_FLY,
		IncludeSoundsH.SOUND_AIR_AMP_BUZZ,
		IncludeSoundsH.SOUND_AIR_CASTLE_OUTDOORS_AMBIENT,
		IncludeSoundsH.SOUND_OBJ2_BIRD_CHIRP1,
		IncludeSoundsH.SOUND_GENERAL2_BIRD_CHIRP2,
		IncludeSoundsH.SOUND_OBJ_BIRD_CHIRP3,
		IncludeSoundsH.SOUND_ENV_ELEVATOR2,
		IncludeSoundsH.SOUND_AIR_BLOW_WIND,
		IncludeSoundsH.SOUND_AIR_BLOW_FIRE,
		IncludeSoundsH.SOUND_ENV_ELEVATOR4,
	},
	-- from src/game/sound_init.c:sPaintingEjectSoundPlayed L75-75
	sPaintingEjectSoundPlayed = 0,
}

-- from src/game/sound_init.c:reset_volume L82-84
function sound_init.reset_volume()
	sound_init.sMusicVolume = U8(0)
end

-- from src/game/sound_init.c:lower_background_noise L89-99
function sound_init.lower_background_noise(a: number)
	if a == 1 then
		Audio.set_audio_muted(IncludePRUltratypesH.TRUE)
	elseif a == 2 then
		Audio.seq_player_lower_volume(SeqPlayerLevel, 60, 40)
	end

	sound_init.sMusicVolume = U8(bit32.bor(sound_init.sMusicVolume, a))
end

-- from src/game/sound_init.c:raise_background_noise L104-114
function sound_init.raise_background_noise(a: number)
	if a == 1 then
		Audio.set_audio_muted(IncludePRUltratypesH.FALSE)
	elseif a == 2 then
		Audio.seq_player_unlower_volume(SeqPlayerLevel, 60)
	end

	sound_init.sMusicVolume = U8(bit32.band(sound_init.sMusicVolume, bit32.bnot(a)))
end

-- from src/game/sound_init.c:disable_background_sound L119-124
function sound_init.disable_background_sound()
	if sound_init.sBgMusicDisabled == IncludePRUltratypesH.FALSE then
		sound_init.sBgMusicDisabled = U8(IncludePRUltratypesH.TRUE)
		Audio.sound_banks_disable(SeqPlayerSfx, IncludeSoundsH.SOUND_BANKS_BACKGROUND)
	end
end

-- from src/game/sound_init.c:enable_background_sound L129-134
function sound_init.enable_background_sound()
	if sound_init.sBgMusicDisabled == IncludePRUltratypesH.TRUE then
		sound_init.sBgMusicDisabled = U8(IncludePRUltratypesH.FALSE)
		Audio.sound_banks_enable(SeqPlayerSfx, IncludeSoundsH.SOUND_BANKS_BACKGROUND)
	end
end

-- from src/game/sound_init.c:set_sound_mode L141-145
function sound_init.set_sound_mode(soundMode: number)
	soundMode = U16(TruncS32(soundMode))
	if soundMode < 3 then
		-- audio_set_sound_mode(sSoundMenuModeToSoundMode[soundMode]): the output mode (stereo, mono, headset) has no effect on the sounds a client plays
	end
end

-- from src/game/sound_init.c:play_menu_sounds L152-179
function sound_init.play_menu_sounds(soundMenuFlags: number)
	soundMenuFlags = S16(TruncS32(soundMenuFlags))
	if bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_HANDAPPEAR) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_HAND_APPEAR, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_HANDISAPPEAR) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_HAND_DISAPPEAR, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_UNKNOWN1) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_UNK0C, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_PINCHMARIOFACE) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_PINCH_MARIO_FACE, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_PINCHMARIOFACE2) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_PINCH_MARIO_FACE, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_LETGOMARIOFACE) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_LET_GO_MARIO_FACE, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_CAMERAZOOMIN) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_IN, Audio.gGlobalSoundSource)
	elseif bit32.btest(soundMenuFlags, Registry.Members.src__game__sound_init_h.SOUND_MENU_FLAG_CAMERAZOOMOUT) then
		Audio.play_sound(IncludeSoundsH.SOUND_MENU_CAMERA_ZOOM_OUT, Audio.gGlobalSoundSource)
	end

	if bit32.btest(soundMenuFlags, 0x100) then
		sound_init.play_menu_sounds_extra(20, nil)
	end
end

-- from src/game/sound_init.c:play_painting_eject_sound L186-197
function sound_init.play_painting_eject_sound()
	if Registry.Members.src__game__paintings.gRipplingPainting ~= nil and Registry.Members.src__game__paintings.gRipplingPainting.state == Registry.Members.src__game__paintings_h.PAINTING_ENTERED then
		if sound_init.sPaintingEjectSoundPlayed == IncludePRUltratypesH.FALSE then
			Audio.play_sound(IncludeSoundsH.SOUND_GENERAL_PAINTING_EJECT, (Registry.Members.src__game__level_update.gMarioStates[1].marioObj :: GroupsTypesHPlus3.Object).header.gfx.cameraToObject)
		end

		sound_init.sPaintingEjectSoundPlayed = S8(IncludePRUltratypesH.TRUE)
	else
		sound_init.sPaintingEjectSoundPlayed = S8(IncludePRUltratypesH.FALSE)
	end
end

-- from src/game/sound_init.c:play_infinite_stairs_music L202-222
function sound_init.play_infinite_stairs_music()
	local shouldPlay = IncludePRUltratypesH.FALSE

	-- Infinite stairs?
	if Registry.Members.src__game__area.gCurrLevelNum == IncludeLevelTableH.LEVEL_CASTLE and Registry.Members.src__game__area.gCurrAreaIndex == 2 and Registry.Members.src__game__level_update.gMarioState.numStars < 70 then
		const floor = Registry.Members.src__game__level_update.gMarioState.floor

		if floor ~= nil and floor.room == 6 then
			if Registry.Members.src__game__level_update.gMarioState.pos[3] < 2540 then
				shouldPlay = IncludePRUltratypesH.TRUE
			end
		end
	end

	if bit32.bxor(sound_init.sPlayingInfiniteStairs, shouldPlay) ~= 0 then
		sound_init.sPlayingInfiniteStairs = shouldPlay

		if shouldPlay ~= 0 then
			Audio.play_secondary_music(IncludeSeqIdsH.SEQ_EVENT_ENDLESS_STAIRS, 0, 255, 1000)
		else
			Audio.stop_secondary_music(500)
		end
	end
end

-- from src/game/sound_init.c:set_background_music L227-240
function sound_init.set_background_music(a: number, seqArgs: number, fadeTimer: number)
	a = U16(TruncS32(a))
	seqArgs = U16(TruncS32(seqArgs))
	fadeTimer = S16(TruncS32(fadeTimer))
	if Registry.Members.src__game__main.gResetTimer == 0 and seqArgs ~= sound_init.sCurrentMusic then
		if Registry.Members.src__game__area.gCurrCreditsEntry ~= nil then
			Audio.sound_reset(7)
		else
			Audio.sound_reset(a)
		end

		if Registry.Members.src__game__level_update.gNeverEnteredCastle == 0 or seqArgs ~= IncludeSeqIdsH.SEQ_LEVEL_INSIDE_CASTLE then
			Audio.play_music(SeqPlayerLevel, seqArgs, fadeTimer)
			sound_init.sCurrentMusic = seqArgs
		end
	end
end

-- from src/game/sound_init.c:fadeout_music L245-250
function sound_init.fadeout_music(fadeOutTime: number)
	fadeOutTime = S16(TruncS32(fadeOutTime))
	Audio.fade_out_all(fadeOutTime)
	sound_init.sCurrentMusic = U16(sound_init.MUSIC_NONE)
	sound_init.sCurrentShellMusic = U16(sound_init.MUSIC_NONE)
	sound_init.sCurrentCapMusic = U16(sound_init.MUSIC_NONE)
end

-- from src/game/sound_init.c:fadeout_level_music L255-260
function sound_init.fadeout_level_music(fadeTimer: number)
	fadeTimer = S16(TruncS32(fadeTimer))
	Audio.seq_player_fade_out(SeqPlayerLevel, fadeTimer)
	sound_init.sCurrentMusic = U16(sound_init.MUSIC_NONE)
	sound_init.sCurrentShellMusic = U16(sound_init.MUSIC_NONE)
	sound_init.sCurrentCapMusic = U16(sound_init.MUSIC_NONE)
end

-- from src/game/sound_init.c:play_cutscene_music L265-268
function sound_init.play_cutscene_music(seqArgs: number)
	seqArgs = U16(TruncS32(seqArgs))
	Audio.play_music(SeqPlayerLevel, seqArgs, 0)
	sound_init.sCurrentMusic = seqArgs
end

-- from src/game/sound_init.c:play_shell_music L273-276
function sound_init.play_shell_music()
	const shellMusic = bit32.lshift(4, 8) + bit32.bor(IncludeSeqIdsH.SEQ_EVENT_POWERUP, IncludeSeqIdsH.SEQ_VARIATION)

	Audio.play_music(SeqPlayerLevel, shellMusic, 0)
	sound_init.sCurrentShellMusic = shellMusic
end

-- from src/game/sound_init.c:stop_shell_music L281-286
function sound_init.stop_shell_music()
	if sound_init.sCurrentShellMusic ~= sound_init.MUSIC_NONE then
		Audio.stop_background_music(sound_init.sCurrentShellMusic)
		sound_init.sCurrentShellMusic = U16(sound_init.MUSIC_NONE)
	end
end

-- from src/game/sound_init.c:play_cap_music L291-297
function sound_init.play_cap_music(seqArgs: number)
	seqArgs = U16(TruncS32(seqArgs))
	Audio.play_music(SeqPlayerLevel, seqArgs, 0)

	if sound_init.sCurrentCapMusic ~= sound_init.MUSIC_NONE and sound_init.sCurrentCapMusic ~= seqArgs then
		Audio.stop_background_music(sound_init.sCurrentCapMusic)
	end

	sound_init.sCurrentCapMusic = seqArgs
end

-- from src/game/sound_init.c:fadeout_cap_music L302-306
function sound_init.fadeout_cap_music()
	if sound_init.sCurrentCapMusic ~= sound_init.MUSIC_NONE then
		Audio.fadeout_background_music(sound_init.sCurrentCapMusic, 600)
	end
end

-- from src/game/sound_init.c:stop_cap_music L311-316
function sound_init.stop_cap_music()
	if sound_init.sCurrentCapMusic ~= sound_init.MUSIC_NONE then
		Audio.stop_background_music(sound_init.sCurrentCapMusic)
		sound_init.sCurrentCapMusic = U16(sound_init.MUSIC_NONE)
	end
end

-- from src/game/sound_init.c:play_menu_sounds_extra L321-323
function sound_init.play_menu_sounds_extra(a: number, b: { number }?)
	Audio.play_sound(sound_init.sMenuSoundsExtra[a + 1], b)
end

-- from src/game/sound_init.c:audio_game_loop_tick L328-330
function sound_init.audio_game_loop_tick()
	-- audio_signal_game_loop_tick(): wakes the audio thread, which the port does not have
end

-- from src/game/sound_init.c:thread4_sound L335-359
function sound_init.thread4_sound(arg: unknown)
	error("stale")
end

-- from src/game/sound_init.c:sCurrentMusic L30-30
sound_init.sCurrentMusic = sound_init.MUSIC_NONE

-- from src/game/sound_init.c:sCurrentShellMusic L31-31
sound_init.sCurrentShellMusic = sound_init.MUSIC_NONE

-- from src/game/sound_init.c:sCurrentCapMusic L32-32
sound_init.sCurrentCapMusic = sound_init.MUSIC_NONE

return sound_init
