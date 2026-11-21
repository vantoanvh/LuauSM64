#include <stdarg.h>
#include <string.h>

#include "sink.h"

#define FNV_OFFSET_BASIS 0xcbf29ce484222325ULL
#define FNV_PRIME 0x100000001b3ULL

static u64 sHash;
static FILE *sDump;
static int sQuiet;

static void hash_byte(u8 value) {
    sHash ^= value;
    sHash *= FNV_PRIME;
}

static void hash_le(u32 value, int count) {
    int i;

    for (i = 0; i < count; i++) {
        hash_byte((u8) (value >> (8 * i)));
    }
}

void sink_begin(FILE *dump) {
    sHash = FNV_OFFSET_BASIS;
    sDump = dump;
    sQuiet = 0;
}

u64 sink_end(void) {
    sDump = NULL;
    return sHash;
}

int sink_dumping(void) {
    return sDump != NULL;
}

void sink_line(const char *format, ...) {
    va_list args;

    if (sDump == NULL) {
        return;
    }
    va_start(args, format);
    vfprintf(sDump, format, args);
    va_end(args);
    fputc('\n', sDump);
}

void sink_u8(const char *name, u32 value) {
    hash_le(value, 1);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=%u\n", name, value & 0xff);
    }
}

void sink_s16(const char *name, s32 value) {
    hash_le((u32) value, 2);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=%d\n", name, (s16) value);
    }
}

void sink_u16(const char *name, u32 value) {
    hash_le(value, 2);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=%u\n", name, value & 0xffff);
    }
}

void sink_s32(const char *name, s32 value) {
    hash_le((u32) value, 4);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=%d\n", name, value);
    }
}

void sink_u32(const char *name, u32 value) {
    hash_le(value, 4);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=%u\n", name, value);
    }
}

void sink_f32(const char *name, f32 value) {
    u32 bits;

    memcpy(&bits, &value, sizeof(bits));
    hash_le(bits, 4);
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=0x%08x (%.9g)\n", name, bits, (double) value);
    }
}

void sink_bytes(const char *name, const void *data, u32 count) {
    const u8 *bytes = (const u8 *) data;
    u32 i;

    for (i = 0; i < count; i++) {
        hash_byte(bytes[i]);
    }
    if (sDump != NULL && !sQuiet) {
        fprintf(sDump, "%s=", name);
        for (i = 0; i < count; i++) {
            fprintf(sDump, "%02x", bytes[i]);
        }
        fputc('\n', sDump);
    }
}

void sink_quiet(int quiet) {
    sQuiet = quiet;
}
