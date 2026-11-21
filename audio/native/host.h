#ifndef AUDIO_NATIVE_HOST_H
#define AUDIO_NATIVE_HOST_H

#include <PR/ultratypes.h>

// Called by synthesis_hle.c around every process_sequences() call of synthesis_execute.
void audio_host_before_sequences(void);
void audio_host_after_sequences(s32 updateIndex);

#endif
