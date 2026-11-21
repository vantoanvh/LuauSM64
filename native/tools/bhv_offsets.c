// Build-time tool: prints "OFFSET(<name>, <rom offset>)" for every behavior script array of
// data/behavior_data.c. The ROM stores the arrays back to back in source order with 4-byte words
// (native words are 8 bytes wide); the two `u64` filler objects are 8-byte aligned.
// bhv_layout.inc lists the objects in source order.
#include <stdio.h>

#include "data/behavior_data.c"

#define ROM_SIZE(name) (sizeof(name) / sizeof(BehaviorScript) * 4)

int main(void) {
    unsigned offset = 0;

#define BHV(name) \
    printf("OFFSET(%s, 0x%x)\n", #name, offset); \
    offset += ROM_SIZE(name);
#define STATIC_BHV(name) offset += ROM_SIZE(name);
#define FILLER_U64() offset = ((offset + 7) & ~7u) + 8;
#include "bhv_layout.inc"
#undef BHV
#undef STATIC_BHV
#undef FILLER_U64
    return 0;
}
