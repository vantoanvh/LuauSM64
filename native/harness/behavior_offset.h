#ifndef BEHAVIOR_OFFSET_H
#define BEHAVIOR_OFFSET_H

#include "sm64.h"
#include "types.h"

#define BEHAVIOR_UNKNOWN 0xFFFFFFFFu

// Byte offset of a behavior script inside segment 0x13 (its position in the ROM),
// or BEHAVIOR_UNKNOWN when the pointer is not the start of a behavior script.
u32 behavior_offset(const BehaviorScript *behavior);

#endif
