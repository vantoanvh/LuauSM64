#ifndef STATE_HASH_H
#define STATE_HASH_H

#include <stdio.h>

#include <PR/ultratypes.h>

// Hashes the game state of one finished frame per docs/state-hash.md.
// When dump is not NULL, every hashed field is also written to it as text.
u64 state_hash_frame(FILE *dump);

#endif
