// Replacement for src/game/main.c, profiler.c and rumble_init.c: the globals the game reads,
// without the OS thread scheduler, RCP task queue or profiler.
#include <ultra64.h>

#include "sm64.h"
#include "game/main.h"
#include "game/profiler.h"

OSIoMesg gDmaIoMesg;
OSMesg gMainReceivedMesg;
OSMesgQueue gDmaMesgQueue;
OSMesgQueue gSIEventMesgQueue;

struct VblankHandler *gVblankHandler1 = NULL;
struct VblankHandler *gVblankHandler2 = NULL;

s8 gResetTimer = 0;
s8 gNmiResetBarsTimer = 0;
s8 gDebugLevelSelect = FALSE;
s8 gShowProfiler = FALSE;
s8 gShowDebugText = FALSE;

void set_vblank_handler(s32 index, struct VblankHandler *handler, OSMesgQueue *queue, OSMesg *msg) {
    handler->queue = queue;
    handler->msg = msg;

    switch (index) {
        case 1:
            gVblankHandler1 = handler;
            break;
        case 2:
            gVblankHandler2 = handler;
            break;
    }
}

void exec_display_list(struct SPTask *spTask) {
}

void profiler_log_thread5_time(enum ProfilerGameEvent eventID) {
}

void profiler_log_thread4_time(void) {
}

void draw_profiler(void) {
}

void dispatch_audio_sptask(struct SPTask *spTask) {
}
