// libultra replacement for the Goddard oracle: no threads, no interrupts, no clock.
// Goddard only creates message queues and starts the controller read; the oracle driver feeds the pad itself
// (gd_copy_p1_contpad) and the real parse_p1_controller reads sGdContPads.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

void osCreateMesgQueue(OSMesgQueue *mq, OSMesg *msg, s32 count) {
    memset(mq, 0, sizeof(*mq));
}

s32 osRecvMesg(OSMesgQueue *mq, OSMesg *msg, s32 flags) {
    return 0;
}

void osSetEventMesg(OSEvent event, OSMesgQueue *mq, OSMesg msg) {
}

s32 osContInit(OSMesgQueue *mq, u8 *bitpattern, OSContStatus *status) {
    *bitpattern = 1;
    status[0].type = CONT_TYPE_NORMAL;
    status[0].status = 0;
    status[0].errnum = 0;
    return 0;
}

s32 osContStartReadData(OSMesgQueue *mq) {
    return 0;
}

void osViSetSpecialFeatures(u32 func) {
}

void osViSwapBuffer(void *vaddr) {
}

// NO_SEGMENTED_MEMORY: virtual and physical addresses are the same (macros.h VIRTUAL_TO_PHYSICAL).
uintptr_t osVirtualToPhysical(void *addr) {
    return (uintptr_t) addr;
}

// Goddard's only clock use: timers (debug display only) and the seed switch of gd_rand_float. A constant keeps the
// oracle deterministic; a port reproduces the same random sequence by treating the time as 0.
u64 osGetTime(void) {
    return 0;
}

// Replaces the endless loop of renderer.c gd_exit (wrapper/renderer.c): every goddard fatal error (fatal_printf) ends here.
void gd_exit(s32 code) {
    fprintf(stderr, "goddard fatal error (gd_exit %d); break here to see the caller\n", code);
    exit(3);
}
