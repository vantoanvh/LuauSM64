// Build-time tool: prints "<name> <entry count>" for every behavior script array in data/behavior_data.c.
// Compiled with the game flags; BHV_NAMES is a generated list of BHV(name) lines.
#include <stdio.h>

#include "data/behavior_data.c"

int main(void) {
#define BHV(name) printf("%s %u\n", #name, (unsigned) (sizeof(name) / sizeof(BehaviorScript)));
#include "bhv_names.inc"
#undef BHV
    return 0;
}
