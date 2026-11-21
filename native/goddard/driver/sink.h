// Frame stream sink: FNV-1a hash of the frame stream, plus an optional human-readable dump of the same fields.
// Byte encoding of the fields is docs/state-hash.md (little endian, two's complement, f32 bit patterns).
#ifndef GODDARD_ORACLE_SINK_H
#define GODDARD_ORACLE_SINK_H

#include <stdio.h>

#include <PR/ultratypes.h>

// Starts a fresh frame hash. `dump` is NULL (hash only) or the file that receives `name=value` lines.
void sink_begin(FILE *dump);
u64 sink_end(void);
int sink_dumping(void);

// Dump-only text line (headings, decoded commands); never hashed.
void sink_line(const char *format, ...);
// While quiet, fields are hashed but not written to the dump (the caller writes one decoded line instead).
void sink_quiet(int quiet);

void sink_u8(const char *name, u32 value);
void sink_s16(const char *name, s32 value);
void sink_u16(const char *name, u32 value);
void sink_s32(const char *name, s32 value);
void sink_u32(const char *name, u32 value);
void sink_f32(const char *name, f32 value);
// Raw bytes in memory order (the host is little endian); the dump shows them as hex.
void sink_bytes(const char *name, const void *data, u32 count);

#endif
