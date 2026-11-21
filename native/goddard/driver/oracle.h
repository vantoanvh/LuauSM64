// Interface between the oracle driver and the statics of the unmodified goddard sources that only a wrapper
// translation unit can see (wrapper/*.c include the real .c file and add accessors).
#ifndef GODDARD_ORACLE_H
#define GODDARD_ORACLE_H

#include <ultra64.h>

struct OracleTexture {
    const char *name;
    const u8 *data;
    u32 size;
};

// Static texture arrays of renderer.c in table order (the order is part of the frame stream: index = position).
extern const struct OracleTexture gOracleTextures[];
extern const int gOracleTextureCount;

// Buffers of the screen view (roles of SetColorImage / SetDepthImage pointers).
void oracle_screen_buffers(void **zbuf, void **cbuf0, void **cbuf1);



// Hash the file-static state of renderer.c, debug_utils.c and sfx.c (README, "Scene state").
void oracle_hash_statics_renderer(void);
void oracle_hash_statics_debug_utils(void);
void oracle_hash_statics_sfx(void);

#endif
