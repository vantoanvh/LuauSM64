// Compiles the unmodified src/goddard/debug_utils.c and adds an accessor for its random seeds.
#include "goddard/debug_utils.c"

#include "oracle.h"
#include "sink.h"

void oracle_hash_statics_debug_utils(void) {
    sink_u32("debug_utils.sPrimarySeed", sPrimarySeed);
    sink_u32("debug_utils.sSecondarySeed", sSecondarySeed);
}
