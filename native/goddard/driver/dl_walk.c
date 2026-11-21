// F3D_OLD (Fast3D) display list expansion without 64-bit pointers: every command is emitted as its opcode, its 32-bit
// first word and either its 32-bit second word or the bytes / stable identity the second word points to.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

#include "dl_walk.h"
#include "oracle.h"
#include "sink.h"

#define MAX_DEPTH 16
#define MAX_COMMANDS 1000000
#define IMAGE_BYTES (320 * 240 * 2)

// Image ids: 0 .. gOracleTextureCount - 1 are the textures of gOracleTextures, then the screen view buffers.
enum ScreenImage { IMAGE_ZBUFFER, IMAGE_COLOUR_BUFFER_0, IMAGE_COLOUR_BUFFER_1, IMAGE_COUNT };
static const char *const sScreenImageNames[IMAGE_COUNT] = { "zbuffer", "colour_buffer_0", "colour_buffer_1" };

static struct DlStats sStats;

static void fail(const char *message, u32 value) {
    fprintf(stderr, "dl_walk: %s (0x%x)\n", message, value);
    exit(1);
}

// Opcode names for the dump (F3D_OLD values of gbi.h).
static const char *opcode_name(u8 op) {
    switch (op) {
        case G_SPNOOP: return "SPNOOP";
        case G_MTX: return "MTX";
        case G_MOVEMEM: return "MOVEMEM";
        case G_VTX: return "VTX";
        case G_DL: return "DL";
        case (u8) G_TRI1: return "TRI1";
        case (u8) G_CULLDL: return "CULLDL";
        case (u8) G_POPMTX: return "POPMTX";
        case (u8) G_MOVEWORD: return "MOVEWORD";
        case (u8) G_TEXTURE: return "TEXTURE";
        case (u8) G_SETOTHERMODE_H: return "SETOTHERMODE_H";
        case (u8) G_SETOTHERMODE_L: return "SETOTHERMODE_L";
        case (u8) G_ENDDL: return "ENDDL";
        case (u8) G_SETGEOMETRYMODE: return "SETGEOMETRYMODE";
        case (u8) G_CLEARGEOMETRYMODE: return "CLEARGEOMETRYMODE";
        case (u8) G_LINE3D: return "LINE3D";
        case (u8) G_RDPHALF_1: return "RDPHALF_1";
        case (u8) G_RDPHALF_2: return "RDPHALF_2";
        case (u8) G_RDPHALF_CONT: return "RDPHALF_CONT";
        case G_NOOP: return "NOOP";
        case G_SETCIMG: return "SETCIMG";
        case G_SETZIMG: return "SETZIMG";
        case G_SETTIMG: return "SETTIMG";
        case G_SETCOMBINE: return "SETCOMBINE";
        case G_SETENVCOLOR: return "SETENVCOLOR";
        case G_SETPRIMCOLOR: return "SETPRIMCOLOR";
        case G_SETBLENDCOLOR: return "SETBLENDCOLOR";
        case G_SETFOGCOLOR: return "SETFOGCOLOR";
        case G_SETFILLCOLOR: return "SETFILLCOLOR";
        case G_FILLRECT: return "FILLRECT";
        case G_SETTILE: return "SETTILE";
        case G_LOADTILE: return "LOADTILE";
        case G_LOADBLOCK: return "LOADBLOCK";
        case G_SETTILESIZE: return "SETTILESIZE";
        case G_LOADTLUT: return "LOADTLUT";
        case G_RDPSETOTHERMODE: return "RDPSETOTHERMODE";
        case G_SETPRIMDEPTH: return "SETPRIMDEPTH";
        case G_SETSCISSOR: return "SETSCISSOR";
        case G_SETCONVERT: return "SETCONVERT";
        case G_SETKEYR: return "SETKEYR";
        case G_SETKEYGB: return "SETKEYGB";
        case G_RDPFULLSYNC: return "RDPFULLSYNC";
        case G_RDPTILESYNC: return "RDPTILESYNC";
        case G_RDPPIPESYNC: return "RDPPIPESYNC";
        case G_RDPLOADSYNC: return "RDPLOADSYNC";
        case G_TEXRECTFLIP: return "TEXRECTFLIP";
        case G_TEXRECT: return "TEXRECT";
        default: return "UNKNOWN";
    }
}

// Texture or screen buffer identity of an image pointer: id (u16) and byte offset (u32).
static void emit_image(const void *pointer) {
    const u8 *address = (const u8 *) pointer;
    void *buffers[IMAGE_COUNT];
    int i;

    for (i = 0; i < gOracleTextureCount; i++) {
        const struct OracleTexture *texture = &gOracleTextures[i];

        if (address >= texture->data && address < texture->data + texture->size) {
            sink_u16("image.id", i);
            sink_u32("image.offset", (u32) (address - texture->data));
            sink_line("    image=%s+%u", texture->name, (u32) (address - texture->data));
            return;
        }
    }
    oracle_screen_buffers(&buffers[IMAGE_ZBUFFER], &buffers[IMAGE_COLOUR_BUFFER_0], &buffers[IMAGE_COLOUR_BUFFER_1]);
    for (i = 0; i < IMAGE_COUNT; i++) {
        const u8 *base = (const u8 *) buffers[i];

        if (base != NULL && address >= base && address < base + IMAGE_BYTES) {
            sink_u16("image.id", gOracleTextureCount + i);
            sink_u32("image.offset", (u32) (address - base));
            sink_line("    image=%s+%u", sScreenImageNames[i], (u32) (address - base));
            return;
        }
    }
    fail("image pointer is neither a goddard texture nor a screen view buffer", (u32) (uintptr_t) address);
}


static void dump_vertices(const u8 *bytes, u32 count) {
    u32 i;

    for (i = 0; i < count; i++) {
        const Vtx_t *v = (const Vtx_t *) (bytes + i * sizeof(Vtx));

        sink_line("    vtx[%u] pos=(%d,%d,%d) flag=%u st=(%d,%d) cn=(%u,%u,%u,%u)", i, v->ob[0], v->ob[1], v->ob[2], v->flag,
                  v->tc[0], v->tc[1], v->cn[0], v->cn[1], v->cn[2], v->cn[3]);
    }
}

static void dump_words(const char *label, const u8 *bytes, u32 count) {
    u32 i;

    if (!sink_dumping()) {
        return;
    }
    sink_line("    %s", label);
    for (i = 0; i < count; i += 16) {
        char line[80];
        u32 j;
        int length = 0;

        for (j = i; j < i + 16 && j < count; j += 4) {
            u32 word;

            memcpy(&word, bytes + j, 4);
            length += sprintf(line + length, " %08x", word);
        }
        sink_line("     %s", line + 1);
    }
}

// Viewport: 16 bytes (Vp_t, eight s16). Lookat and light slots (a Light is 16 bytes of which only col, colc and dir are
// data; the pad bytes are never written by Goddard): col[3] at 0, colc[3] at 4, dir[3] at 8. A slot loaded from the
// address of a Lights struct (the ambient light, `a`) holds the ambient col / colc and then l[0].col in bytes 8 to 10.
static void emit_movemem(u8 index, const u8 *data, u32 length) {
    if (index == G_MV_VIEWPORT) {
        if (length != sizeof(Vp)) {
            fail("viewport length", length);
        }
        sink_bytes("viewport", data, sizeof(Vp));
        dump_words("viewport words", data, sizeof(Vp));
    } else if (index >= G_MV_LOOKATY && index <= G_MV_L7 && length == sizeof(Light)) {
        sink_bytes("light.col", data, 3);
        sink_bytes("light.colc", data + 4, 3);
        sink_bytes("light.dir", data + 8, 3);
        if (sink_dumping()) {
            sink_line("    slot=0x%02x col=(%u,%u,%u) colc=(%u,%u,%u) dir=(%d,%d,%d)", index, data[0], data[1], data[2], data[4],
                      data[5], data[6], (s8) data[8], (s8) data[9], (s8) data[10]);
        }
    } else {
        fail("unhandled MOVEMEM index", index);
    }
}

// Hashes the pointed-to data of a command whose second word is an address; `w1` is never hashed itself.
static void emit_pointer_payload(u8 op, u32 w0, uintptr_t w1) {
    u32 length = w0 & 0xffff;

    switch (op) {
        case G_MTX:
            if (length != sizeof(Mtx)) {
                fail("matrix length", length);
            }
            sink_bytes("mtx", (const void *) w1, sizeof(Mtx));
            dump_words("mtx words (guMtxF2L layout)", (const u8 *) w1, sizeof(Mtx));
            break;
        case G_MOVEMEM:
            emit_movemem((u8) (w0 >> 16), (const u8 *) w1, length);
            break;
        case G_VTX:
            if (length % sizeof(Vtx) != 0 || length == 0) {
                fail("vertex length", length);
            }
            sink_bytes("vtx", (const void *) w1, length);
            if (sink_dumping()) {
                dump_vertices((const u8 *) w1, length / sizeof(Vtx));
            }
            sStats.vertices += length / sizeof(Vtx);
            break;
        default:
            emit_image((const void *) w1);
            break;
    }
}

static int has_pointer(u8 op) {
    return op == G_MTX || op == G_MOVEMEM || op == G_VTX || op == G_SETTIMG || op == G_SETZIMG || op == G_SETCIMG;
}

static void walk(const Gfx *dl, int depth) {
    if (depth > MAX_DEPTH) {
        fail("display list nesting too deep", depth);
    }
    for (;; dl++) {
        uintptr_t w0 = dl->words.w0;
        uintptr_t w1 = dl->words.w1;
        u8 op = (u8) (w0 >> 24);

        if (w0 >> 32 != 0) {
            fail("first word has bits above 32", (u32) (w0 >> 32));
        }
        if (++sStats.commands > MAX_COMMANDS) {
            fail("display list does not end", sStats.commands);
        }
        sink_quiet(1);
        sink_u8("op", op);
        sink_u32("w0", (u32) w0);

        if (op == G_DL) {
            // The target list is a nested sequence of records; a branch (no push) never returns.
            sink_line("cmd %u depth=%d DL w0=%08x %s", sStats.commands - 1, depth, (u32) w0,
                      ((w0 >> 16) & 0xff) == G_DL_NOPUSH ? "branch" : "call");
            sink_quiet(0);
            walk((const Gfx *) w1, depth + 1);
            if (((w0 >> 16) & 0xff) == G_DL_NOPUSH) {
                return;
            }
        } else if (has_pointer(op)) {
            sink_line("cmd %u depth=%d %s w0=%08x", sStats.commands - 1, depth, opcode_name(op), (u32) w0);
            emit_pointer_payload(op, (u32) w0, w1);
            sink_quiet(0);
        } else {
            if (w1 >> 32 != 0) {
                fail("unhandled command with a pointer in the second word", op);
            }
            sink_u32("w1", (u32) w1);
            sink_line("cmd %u depth=%d %s w0=%08x w1=%08x", sStats.commands - 1, depth, opcode_name(op), (u32) w0, (u32) w1);
            sink_quiet(0);
            if (op == (u8) G_TRI1) {
                sStats.triangles++;
            } else if (op == (u8) G_ENDDL) {
                return;
            }
        }
    }
}

struct DlStats dl_walk(const Gfx *dl) {
    sStats.commands = 0;
    sStats.vertices = 0;
    sStats.triangles = 0;
    walk(dl, 0);
    return sStats;
}
