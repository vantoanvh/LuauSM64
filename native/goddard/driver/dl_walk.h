// Expands a Goddard display list into frame stream records (README, "Display list stream").
#ifndef GODDARD_ORACLE_DL_WALK_H
#define GODDARD_ORACLE_DL_WALK_H

#include <ultra64.h>

struct DlStats {
    u32 commands;  // records emitted
    u32 vertices;  // vertices loaded by G_VTX
    u32 triangles; // G_TRI1 commands
};

// Walks `dl` (and every list it calls or branches to) depth first; emits to the sink and returns the totals.
struct DlStats dl_walk(const Gfx *dl);

#endif
