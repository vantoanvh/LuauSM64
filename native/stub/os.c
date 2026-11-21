// libultra replacement: no threads, no interrupts, no DMA latency.
// The only live data paths are the controller pad (set by the harness) and PI DMA (memcpy).
#include <string.h>

#include <ultra64.h>

#include "stub/harness.h"

u64 rspF3DBootStart[1];
u64 rspF3DBootEnd[1];
u64 rspF3DStart[1];
u64 rspF3DEnd[1];
u64 rspF3DDataStart[1];
u64 rspF3DDataEnd[1];

// Only read by unused profiling code.
u64 osClockRate = 62500000;

static OSContPad sNativePad;

void native_set_pad(u16 buttons, s8 stickX, s8 stickY) {
    sNativePad.button = buttons;
    sNativePad.stick_x = stickX;
    sNativePad.stick_y = stickY;
    sNativePad.errnum = 0;
}

void osCreateMesgQueue(OSMesgQueue *mq, OSMesg *msg, s32 count) {
    memset(mq, 0, sizeof(*mq));
}

s32 osRecvMesg(OSMesgQueue *mq, OSMesg *msg, s32 flags) {
    return 0;
}

s32 osPiStartDma(OSIoMesg *mb, s32 priority, s32 direction, uintptr_t devAddr, void *vAddr,
                 size_t nbytes, OSMesgQueue *mq) {
    memcpy(vAddr, (void *) devAddr, nbytes);
    return 0;
}

void osInvalDCache(void *addr, size_t size) {
}

void osWritebackDCacheAll(void) {
}

void osViSwapBuffer(void *vaddr) {
}

void osViBlack(u8 active) {
}

void osViSetSpecialFeatures(u32 func) {
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

void osContGetReadData(OSContPad *pad) {
    pad[0] = sNativePad;
}

// No save device: the game starts with an empty save and never writes it.
s32 osEepromProbe(OSMesgQueue *mq) {
    return 0;
}

s32 osEepromLongRead(OSMesgQueue *mq, u8 address, u8 *buffer, int length) {
    return -1;
}

s32 osEepromLongWrite(OSMesgQueue *mq, u8 address, u8 *buffer, int length) {
    return -1;
}
