// Compiles the unmodified src/goddard/sfx.c and adds an accessor for its sound bitsets.
#include "goddard/sfx.c"

#include "oracle.h"
#include "sink.h"

void oracle_hash_statics_sfx(void) {
    sink_u32("sfx.sCurrSfx", sCurrSfx);
    sink_u32("sfx.sPrevSfx", sPrevSfx);
}
