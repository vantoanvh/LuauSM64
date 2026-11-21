// Offline host of the game's audio engine, built to WebAssembly (audio/build.mjs): replaces the game and
// libultra parts the engine talks to (DMA, audio interface, game state) and drives it frame by frame the
// way thread4_sound and the game loop do, collecting the PCM the audio interface would play.
//
// The caller (rom-tool/sound/engine.js) fills the four data buffers with the sound data of the ROM (32-bit
// little endian layout, rom-tool/sound/rom-data.js), calls audio_start, then audio_render_sfx or
// audio_render_music once; it reads the interleaved stereo s16 PCM at 32 kHz from audio_pcm and the
// description of the render from audio_info. A render needs a fresh instance: the engine's state is not
// reset.
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

#include "sm64.h"
#include "audio/data.h"
#include "audio/external.h"
#include "audio/heap.h"
#include "audio/internal.h"
#include "audio/load.h"
#include "audio/seqplayer.h"
#include "audio/synthesis.h"

#include "host.h"

// Game state read by external.c. Position (0, 0, 0) of gGlobalSoundSource is the listener, so a
// sound plays at full volume, centered. Level 0 has no reverb preset.
s16 gCurrLevelNum;
s16 gCurrAreaIndex = 1;
s16 gMarioCurrentRoom;
struct MarioState gMarioStates[1];

// Audio data, filled by the caller (sizes exceed the real data).
u8 gSoundDataADSR[0x40000];
u8 gSoundDataRaw[0x300000];
u8 gMusicData[0x40000];
u8 gBankSetsData[0x400];
ALIGNED16 u8 gAudioHeap[DOUBLE_SIZE_ON_64_BIT(0x31200)];

// Microcode symbols that only fill the (unused) task description.
u64 rspF3DBootStart[1], rspF3DBootEnd[1];
u64 rspAspMainStart[1], rspAspMainDataStart[1], rspAspMainDataEnd[1];

// ---- libultra replacement -------------------------------------------------------------------

#define AI_FREQUENCY 32000
// The game tunes tempo for a 16.713 ms audio frame (gTempoInternalToExternal).
#define SAMPLES_PER_FRAME (AI_FREQUENCY * 0.016713)

static double sAiQueuedBytes;

s32 osAiSetFrequency(u32 frequency) {
    return frequency;
}

s32 osAiSetNextBuffer(void *buffer, u32 size) {
    sAiQueuedBytes += size;
    return 0;
}

u32 osAiGetLength(void) {
    return (u32) sAiQueuedBytes;
}

void osCreateMesgQueue(OSMesgQueue *mq, OSMesg *msg, s32 count) {
    memset(mq, 0, sizeof(*mq));
}

s32 osRecvMesg(OSMesgQueue *mq, OSMesg *msg, s32 flags) {
    return 0;
}

s32 osPiStartDma(OSIoMesg *mb, s32 priority, s32 direction, uintptr_t devAddr, void *vAddr, size_t nbytes,
                 OSMesgQueue *mq) {
    memcpy(vAddr, (void *) devAddr, nbytes);
    return 0;
}

void osInvalDCache(void *addr, size_t size) {
}

void osWritebackDCache(void *addr, size_t size) {
}

void osWritebackDCacheAll(void) {
}

// ---- sequence loop detection ----------------------------------------------------------------

// The state of every script of a sequence player right after a tick of its tempo clock. When a
// state repeats, the sequence has looped: scripts, delays and channel settings are all equal, so
// everything after it repeats too.
#define FNV_OFFSET 0xcbf29ce484222325ull
#define FNV_PRIME 0x100000001b3ull

static uint64_t hash_u64(uint64_t h, uint64_t v) {
    int i;
    for (i = 0; i < 8; i++) {
        h = (h ^ ((v >> (i * 8)) & 0xff)) * FNV_PRIME;
    }
    return h;
}

static uint64_t hash_f32(uint64_t h, f32 v) {
    uint32_t bits;
    memcpy(&bits, &v, sizeof(bits));
    return hash_u64(h, bits);
}

static uint64_t hash_script(uint64_t h, const struct M64ScriptState *s, const u8 *seqData) {
    int i;
    h = hash_u64(h, (uint64_t) (s->pc - seqData));
    h = hash_u64(h, s->depth);
    for (i = 0; i < s->depth && i < 4; i++) {
        h = hash_u64(h, (uint64_t) (s->stack[i] - seqData));
        h = hash_u64(h, s->remLoopIters[i]);
    }
    return h;
}

static uint64_t hash_layer(uint64_t h, const struct SequenceChannelLayer *layer, const u8 *seqData) {
    h = hash_u64(h, layer->enabled);
    if (!layer->enabled) {
        return h;
    }
    h = hash_script(h, &layer->scriptState, seqData);
    h = hash_u64(h, (uint64_t) (uint16_t) layer->delay);
    h = hash_u64(h, (uint64_t) (uint16_t) layer->duration);
    h = hash_u64(h, (uint64_t) (uint16_t) layer->transposition);
    h = hash_u64(h, layer->status);
    h = hash_f32(h, layer->pan);
    return h;
}

static uint64_t hash_channel(uint64_t h, const struct SequenceChannel *channel, const u8 *seqData) {
    int i;
    h = hash_u64(h, channel->enabled);
    if (!channel->enabled) {
        return h;
    }
    h = hash_script(h, &channel->scriptState, seqData);
    h = hash_u64(h, channel->delay);
    h = hash_u64(h, (uint64_t) (uint16_t) channel->instOrWave);
    h = hash_u64(h, (uint64_t) (uint16_t) channel->transposition);
    h = hash_u64(h, channel->bankId);
    h = hash_u64(h, channel->reverbVol);
    h = hash_f32(h, channel->volume);
    h = hash_f32(h, channel->volumeScale);
    h = hash_f32(h, channel->pan);
    h = hash_f32(h, channel->freqScale);
    for (i = 0; i < LAYERS_MAX; i++) {
        h = hash_u64(h, channel->layers[i] != NULL);
        if (channel->layers[i] != NULL) {
            h = hash_layer(h, channel->layers[i], seqData);
        }
    }
    return h;
}

static uint64_t sequence_state_hash(const struct SequencePlayer *player) {
    uint64_t h = FNV_OFFSET;
    int i;
    h = hash_script(h, &player->scriptState, player->seqData);
    h = hash_u64(h, player->delay);
    h = hash_u64(h, player->tempo);
    h = hash_u64(h, (uint64_t) (uint16_t) player->transposition);
    for (i = 0; i < CHANNELS_MAX; i++) {
        if (player->channels[i] != &gSequenceChannelNone) {
            h = hash_u64(h, i + 1);
            h = hash_channel(h, player->channels[i], player->seqData);
        }
    }
    return h;
}

#define MAX_TICKS 400000
#define TICK_TABLE_SIZE (1 << 20)

struct Tick {
    uint64_t hash;
    uint32_t tick;
    uint32_t pendingOffset; // sample offset of the update inside its frame
    int64_t samplePos;
};

static struct {
    int watchedPlayer; // -1: no loop detection
    uint32_t tickCount;
    int64_t frameStartPos; // sample position of the frame being synthesized
    int tickedThisFrame;   // number of ticks recorded in the current frame
    struct Tick pending[8];
    int64_t *firstPos;     // by tick index
    uint64_t *hashes;      // by tick index
    uint32_t *table;       // hash -> tick index + 1
    uint16_t tempoAccBefore;
    uint16_t tempoBefore;
    int loopFound;         // number of detected repeats of the first loop (0, 1, 2)
    uint32_t loopStartTick;
    uint32_t periodTicks;
    int64_t loopStartPos;
    int64_t loopEndPos;
    int64_t loopEnd2Pos;
} sLoop;

void audio_host_before_sequences(void) {
    if (sLoop.watchedPlayer >= 0) {
        sLoop.tempoAccBefore = gSequencePlayers[sLoop.watchedPlayer].tempoAcc;
        sLoop.tempoBefore = gSequencePlayers[sLoop.watchedPlayer].tempo;
    }
}

// Called after process_sequences with the index of the update inside the frame.
void audio_host_after_sequences(s32 updateIndex) {
    const struct SequencePlayer *player;
    if (sLoop.watchedPlayer < 0) {
        return;
    }
    player = &gSequencePlayers[sLoop.watchedPlayer];
    if (!player->enabled || player->tempoAcc == sLoop.tempoAccBefore + sLoop.tempoBefore) {
        return;
    }
    // The tempo clock ticked: remember the state and the sample where this update starts.
    if (sLoop.tickedThisFrame < 8) {
        struct Tick *t = &sLoop.pending[sLoop.tickedThisFrame++];
        t->hash = sequence_state_hash(player);
        t->pendingOffset = updateIndex;
    }
}

// Sample offsets of the updates of a frame of `length` samples (replicates synthesis_execute).
static void update_offsets(int length, int *offsets) {
    int updates = gAudioUpdatesPerFrame;
    int i;
    int offset = 0;
    for (i = updates; i > 0; i--) {
        int chunk;
        offsets[updates - i] = offset;
        if (i == 1) {
            chunk = length;
        } else {
            int v0 = length / i;
            chunk = v0 - (v0 & 7);
            if ((v0 & 7) >= 4) {
                chunk += 8;
            }
        }
        length -= chunk;
        offset += chunk;
    }
}

static void commit_ticks(int frameLength) {
    int offsets[8];
    int i;
    update_offsets(frameLength, offsets);
    for (i = 0; i < sLoop.tickedThisFrame; i++) {
        struct Tick *t = &sLoop.pending[i];
        int64_t pos = sLoop.frameStartPos + offsets[t->pendingOffset];
        uint32_t slot = (uint32_t) (t->hash >> 20) & (TICK_TABLE_SIZE - 1);
        uint32_t tick = sLoop.tickCount;
        if (tick >= MAX_TICKS) {
            break;
        }
        sLoop.hashes[tick] = t->hash;
        sLoop.firstPos[tick] = pos;
        sLoop.tickCount++;

        if (sLoop.loopFound == 0) {
            while (sLoop.table[slot] != 0 && sLoop.hashes[sLoop.table[slot] - 1] != t->hash) {
                slot = (slot + 1) & (TICK_TABLE_SIZE - 1);
            }
            if (sLoop.table[slot] == 0) {
                sLoop.table[slot] = tick + 1;
            } else {
                sLoop.loopStartTick = sLoop.table[slot] - 1;
                sLoop.periodTicks = tick - sLoop.loopStartTick;
                sLoop.loopStartPos = sLoop.firstPos[sLoop.loopStartTick];
                sLoop.loopEndPos = pos;
                sLoop.loopFound = 1;
            }
        } else if (sLoop.loopFound == 1 && tick == sLoop.loopStartTick + 2 * sLoop.periodTicks) {
            if (t->hash == sLoop.hashes[sLoop.loopStartTick]) {
                sLoop.loopEnd2Pos = pos;
                sLoop.loopFound = 2;
            } else {
                sLoop.loopFound = -1; // not a true loop
            }
        }
    }
    sLoop.tickedThisFrame = 0;
}

// ---- rendering ------------------------------------------------------------------------------

static int16_t *sPcm;
static int64_t sPcmFrames; // stereo sample frames written
static int64_t sPcmCapacity;
static double sAiFraction;

static void append_pcm(const s16 *samples, int frames) {
    if (sPcmFrames + frames > sPcmCapacity) {
        sPcmCapacity = (sPcmFrames + frames) * 2;
        sPcm = realloc(sPcm, sPcmCapacity * 2 * sizeof(int16_t));
    }
    memcpy(sPcm + sPcmFrames * 2, samples, (size_t) frames * 2 * sizeof(int16_t));
    sPcmFrames += frames;
}

// Runs one audio frame (one vblank of the real game) and returns the peak of its samples.
static int run_audio_frame(void) {
    int frames;
    int peak = 0;
    int i;
    s16 *buffer;
    // The audio interface plays what is queued.
    sAiFraction += SAMPLES_PER_FRAME;
    sAiQueuedBytes -= (int) sAiFraction * 4;
    sAiFraction -= (int) sAiFraction;
    if (sAiQueuedBytes < 0) {
        sAiQueuedBytes = 0;
    }

    sLoop.frameStartPos = sPcmFrames;
    create_next_audio_frame_task();
    frames = gAiBufferLengths[gCurrAiBufferIndex];
    buffer = gAiBuffers[gCurrAiBufferIndex];
    commit_ticks(frames);
    append_pcm(buffer, frames);
    for (i = 0; i < frames * 2; i++) {
        int v = abs(buffer[i]);
        if (v > peak) {
            peak = v;
        }
    }
    return peak;
}

// sound_reset waits for the audio thread to fade out the playing notes before it rebuilds the
// heap. Nothing plays yet, and the engine skips the wait while it is uninitialized, so do that.
static void sound_reset_idle(u8 preset) {
    gAudioLoadLock = AUDIO_LOCK_UNINITIALIZED;
    sound_reset(preset);
    gAudioLoadLock = AUDIO_LOCK_NOT_LOADING;
}

// One game frame: the game loop ticks the sound system, then two audio frames play.
static int run_game_frame(int *peak) {
    int p0, p1;
    audio_signal_game_loop_tick();
    p0 = run_audio_frame();
    p1 = run_audio_frame();
    *peak = p0 > p1 ? p0 : p1;
    return 2;
}

#define SILENCE_PEAK 4
#define SILENT_FRAMES_TO_STOP 90 // 1.5 s

// What a render reports, read by the caller through audio_info: how it ended and the loop of a sequence.
enum RenderEnd { END_CAP, END_SILENCE, END_NEVER_AUDIBLE, END_LOOP, END_ENDED };

static double sInfo[8];

enum InfoField { INFO_END, INFO_FRAMES, INFO_LOOP_FOUND, INFO_LOOP_START, INFO_LOOP_END, INFO_LOOP_END2, INFO_PERIOD_TICKS, INFO_TICKS };

// Plays a sound effect on its own. A continuous sound (hold) is requested every game frame, as the
// game does, for as long as the engine reports it playing; it is not requested again once it has
// ended by itself (that would restart it), so only a sound that never ends runs into the cap.
static void render_sfx(u32 soundBits, int hold, double maxSeconds) {
    int maxFrames = (int) (maxSeconds * 60);
    int silent = 0;
    int sawSound = 0;
    int frame = 0;
    int end = END_CAP;

    // Loading a level: sound_reset starts the sound player sequence. Let it run before the request.
    sound_reset_idle(0);
    for (; frame < 4; frame++) {
        int peak;
        run_game_frame(&peak);
    }
    sPcmFrames = 0;

    for (frame = 0; frame < maxFrames / 2; frame++) {
        int peak;
        u8 playing, inBank, playingId;
        get_currently_playing_sound(soundBits >> SOUNDARGS_SHIFT_BANK, &playing, &inBank, &playingId);
        if (frame == 0 || (hold && playing > 0)) {
            play_sound(soundBits, gGlobalSoundSource);
        }
        run_game_frame(&peak);
        if (peak > SILENCE_PEAK) {
            sawSound = 1;
            silent = 0;
        } else {
            silent += 2;
        }
        if (silent >= SILENT_FRAMES_TO_STOP) {
            end = sawSound ? END_SILENCE : END_NEVER_AUDIBLE;
            break;
        }
    }
    sInfo[INFO_END] = end;
    sInfo[INFO_FRAMES] = (double) sPcmFrames;
}

// Plays a sequence on its own until it has looped twice, ended and gone silent, or the cap.
static void render_music(int player, u16 seqArgs, int preset, double maxSeconds) {
    int maxFrames = (int) (maxSeconds * 60);
    int silent = 0;
    int frame;
    int end = END_CAP;

    sLoop.firstPos = malloc(MAX_TICKS * sizeof(int64_t));
    sLoop.hashes = malloc(MAX_TICKS * sizeof(uint64_t));
    sLoop.table = calloc(TICK_TABLE_SIZE, sizeof(uint32_t));

    // set_background_music: sound_reset(preset), then the sequence.
    sound_reset_idle(preset);
    sPcmFrames = 0;
    sLoop.watchedPlayer = player;
    play_music(player, seqArgs, 0);

    for (frame = 0; frame < maxFrames / 2; frame++) {
        int peak;
        run_game_frame(&peak);
        if (sLoop.loopFound == 2) {
            end = END_LOOP;
            break;
        }
        if (peak > SILENCE_PEAK) {
            silent = 0;
        } else {
            silent += 2;
        }
        if (!gSequencePlayers[player].enabled && silent >= SILENT_FRAMES_TO_STOP) {
            end = END_ENDED;
            break;
        }
    }
    sInfo[INFO_END] = end;
    sInfo[INFO_FRAMES] = (double) sPcmFrames;
    sInfo[INFO_LOOP_FOUND] = sLoop.loopFound;
    sInfo[INFO_LOOP_START] = (double) sLoop.loopStartPos;
    sInfo[INFO_LOOP_END] = (double) sLoop.loopEndPos;
    sInfo[INFO_LOOP_END2] = (double) sLoop.loopEnd2Pos;
    sInfo[INFO_PERIOD_TICKS] = sLoop.periodTicks;
    sInfo[INFO_TICKS] = sLoop.tickCount;
}

// ---- interface to the caller ----------------------------------------------------------------

// The buffers of the sound data: 0 the sound banks (ctl), 1 their samples (tbl), 2 the sequences, 3 the bank sets
u8 *audio_buffer(int which) {
    switch (which) {
        case 0: return gSoundDataADSR;
        case 1: return gSoundDataRaw;
        case 2: return gMusicData;
        default: return gBankSetsData;
    }
}

// Starts the engine on the data in the buffers: thread4_sound, then game_init.
void audio_start(void) {
    sLoop.watchedPlayer = -1;
    audio_init();
    sound_init();
}

// Plays the sound effect soundBits on its own (see render_sfx)
void audio_render_sfx(u32 soundBits, int hold, double maxSeconds) {
    render_sfx(soundBits, hold, maxSeconds);
}

// Plays a sequence on its own (see render_music)
void audio_render_music(int player, u16 seqArgs, int preset, double maxSeconds) {
    render_music(player, seqArgs, preset, maxSeconds);
}

// What the render made: interleaved stereo s16 frames (their number is INFO_FRAMES of audio_info)
int16_t *audio_pcm(void) {
    return sPcm;
}

// The description of the render, as doubles by InfoField (host.c enum, mirrored in rom-tool/sound/engine.js)
double *audio_info(void) {
    return sInfo;
}
