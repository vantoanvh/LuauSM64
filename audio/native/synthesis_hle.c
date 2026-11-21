// The game's synthesis.c compiled for the host: the audio microcode commands execute immediately
// through mixer.c (mixer.h redirects the abi.h macros), and every sequence update is reported to
// the host so it can follow the sequence scripts (loop detection).
#include <ultra64.h>

#include "audio/synthesis.h"
#include "audio/heap.h"
#include "audio/data.h"
#include "audio/load.h"
#include "audio/seqplayer.h"
#include "audio/internal.h"
#include "audio/external.h"

#include "host.h"
#include "mixer.h"

static void process_sequences_observed(s32 updatesRemaining) {
    audio_host_before_sequences();
    process_sequences(updatesRemaining);
    audio_host_after_sequences(gAudioUpdatesPerFrame - 1 - updatesRemaining);
}

#define process_sequences process_sequences_observed

#include "audio/synthesis.c"
