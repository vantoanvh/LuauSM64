// Trace file: one "<buttons> <stickX> <stickY>" line per frame (docs/state-hash.md, Trace). `#` comments, blank lines.
// `boot` and `do` lines are for the game harness and are rejected here.
#ifndef GODDARD_ORACLE_TRACE_H
#define GODDARD_ORACLE_TRACE_H

#include <PR/ultratypes.h>

struct TraceFrame {
    u16 buttons;
    s8 stickX;
    s8 stickY;
};

// Returns a malloc'ed array of *count frames; exits with a message on a malformed file.
struct TraceFrame *trace_read(const char *path, int *count);

#endif
