// Audio replacement: sound requests are dropped. Game logic never reads audio state
// except get_current_background_music, which reports silence.
#include <ultra64.h>

#include "sm64.h"
#include "audio/external.h"

u32 gAudioRandom;
f32 gGlobalSoundSource[3] = { 0.0f, 0.0f, 0.0f };

void play_sound(s32 soundBits, f32 *pos) {
}

void seq_player_fade_out(u8 player, u16 fadeDuration) {
}

void fade_volume_scale(u8 player, u8 targetScale, u16 fadeDuration) {
}

void seq_player_lower_volume(u8 player, u16 fadeDuration, u8 percentage) {
}

void seq_player_unlower_volume(u8 player, u16 fadeDuration) {
}

void set_audio_muted(u8 muted) {
}

void sound_init(void) {
}

void stop_sound(u32 soundBits, f32 *pos) {
}

void stop_sounds_from_source(f32 *pos) {
}

void stop_sounds_in_continuous_banks(void) {
}

void sound_banks_disable(u8 player, u16 bankMask) {
}

void sound_banks_enable(u8 player, u16 bankMask) {
}

void set_sound_moving_speed(u8 bank, u8 speed) {
}

void play_dialog_sound(u8 dialogID) {
}

void play_music(u8 player, u16 seqArgs, u16 fadeTimer) {
}

void stop_background_music(u16 seqId) {
}

void fadeout_background_music(u16 arg0, u16 fadeOut) {
}

void drop_queued_background_music(void) {
}

u16 get_current_background_music(void) {
    return 0;
}

void play_secondary_music(u8 seqId, u8 bgMusicVolume, u8 volume, u16 fadeTimer) {
}

void func_80321080(u16 fadeTimer) {
}

void func_803210D4(u16 fadeOutTime) {
}

void play_course_clear(void) {
}

void play_peachs_jingle(void) {
}

void play_puzzle_jingle(void) {
}

void play_star_fanfare(void) {
}

void play_power_star_jingle(u8 arg0) {
}

void play_race_fanfare(void) {
}

void play_toads_jingle(void) {
}

void sound_reset(u8 presetId) {
}

void audio_set_sound_mode(u8 arg0) {
}

void audio_init(void) {
}

void audio_signal_game_loop_tick(void) {
}

struct SPTask *create_next_audio_frame_task(void) {
    return NULL;
}
