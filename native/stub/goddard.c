// Goddard (Mario head / intro 3D) replacement: the head is only drawn, never read by game logic.
#include <ultra64.h>

#include "goddard/renderer.h"

void gd_add_to_heap(void *addr, u32 size) {
}

void gdm_init(void *blockpool, u32 size) {
}

void gdm_setup(void) {
}

void gdm_maketestdl(s32 id) {
}

void gd_vblank(void) {
}

void gd_copy_p1_contpad(OSContPad *p1cont) {
}

s32 gd_sfx_to_play(void) {
    return 0;
}

Gfx *gdm_gettestdl(s32 id) {
    return NULL;
}
