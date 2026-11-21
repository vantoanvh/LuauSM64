// Headless deterministic driver for Goddard: calls it the way the game does (level_script.c level_cmd_load_mario_head,
// mario_misc.c geo_draw_mario_head_goddard, game_init.c display_and_vsync) once per trace line and writes one hash of the
// frame stream per frame (README, "Frame stream").
//
// Usage: goddard_oracle <id> <trace> <hash-out> [<dump-out> [<dump-from-frame> [<dump-to-frame> [<ppm-frame> <ppm-out>]]]]
//   id: 2 = regular Mario head (title screen), 3 = dizzy Mario head (game over screen)
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

#include "goddard/renderer.h"
#include "dl_walk.h"
#include "preview.h"
#include "scene_hash.h"
#include "sink.h"
#include "trace.h"

// level_script.c: main_pool_alloc(DOUBLE_SIZE_ON_64_BIT(0xE1000)); the size is doubled on 64 bit.
#define HEAD_POOL_BYTES (0xE1000 * 2)
// game_init.c: gZBuffer is 320 * 240 * 2 bytes, gFramebuffer0..2 are three buffers of the same size.
#define Z_BUFFER_BYTES 0x25800
#define FRAMEBUFFERS_BYTES (3 * 0x25800)

static u8 sHeadPool[HEAD_POOL_BYTES] __attribute__((aligned(16)));
static u8 sZBuffer[Z_BUFFER_BYTES] __attribute__((aligned(64)));
static u8 sFramebuffers[FRAMEBUFFERS_BYTES] __attribute__((aligned(64)));

static void fail(const char *message) {
    fprintf(stderr, "%s\n", message);
    exit(1);
}

static void report(const char *label, int frame, struct DlStats stats) {
    printf("%s frame %d: %u commands, %u vertices loaded, %u triangles\n", label, frame, stats.commands,
           stats.vertices, stats.triangles);
}

int main(int argc, char **argv) {
    struct TraceFrame *frames;
    FILE *hashFile;
    FILE *dumpFile = NULL;
    int frameCount;
    int dumpFrom = 0;
    int dumpTo = INT_MAX;
    int id;
    int frame;
    int ppmFrame = -1;
    const char *ppmPath = NULL;

    if (argc < 4) {
        fprintf(stderr, "usage: %s <id> <trace> <hash-out> [<dump-out|-> [<dump-from-frame> [<dump-to-frame> [<ppm-frame> <ppm-out>]]]]\n", argv[0]);
        return 2;
    }
    id = atoi(argv[1]);
    if (id != GD_SCENE_REGULAR_MARIO && id != GD_SCENE_DIZZY_MARIO) {
        fail("id must be 2 (regular Mario head) or 3 (dizzy Mario head)");
    }
    frames = trace_read(argv[2], &frameCount);
    hashFile = fopen(argv[3], "w");
    if (argc > 4 && strcmp(argv[4], "-") != 0) {
        dumpFile = fopen(argv[4], "w");
    }
    if (argc > 5) {
        dumpFrom = atoi(argv[5]);
    }
    if (argc > 6) {
        dumpTo = atoi(argv[6]);
    }
    if (argc > 8) {
        ppmFrame = atoi(argv[7]);
        ppmPath = argv[8];
    }
    if (hashFile == NULL || (argc > 4 && strcmp(argv[4], "-") != 0 && dumpFile == NULL)) {
        fail("cannot open output");
    }

    // level_cmd_load_mario_head
    gdm_init(sHeadPool, HEAD_POOL_BYTES);
    gd_add_to_heap(sZBuffer, sizeof(sZBuffer));
    gd_add_to_heap(sFramebuffers, sizeof(sFramebuffers));
    gdm_setup();
    gdm_maketestdl(id);

    for (frame = 0; frame < frameCount; frame++) {
        OSContPad pad;
        Gfx *dl;
        s32 sfx;
        struct DlStats stats;

        memset(&pad, 0, sizeof(pad));
        pad.button = frames[frame].buttons;
        pad.stick_x = frames[frame].stickX;
        pad.stick_y = frames[frame].stickY;

        // geo_draw_mario_head_goddard (GEO_CONTEXT_RENDER)
        gd_copy_p1_contpad(&pad);
        dl = gdm_gettestdl(id);
        sfx = gd_sfx_to_play();
        // display_and_vsync: the vblank callback runs before the RCP executes the display list.
        gd_vblank();

        sink_begin(dumpFile != NULL && frame >= dumpFrom && frame <= dumpTo ? dumpFile : NULL);
        sink_line("frame %d", frame);
        sink_s32("sfx", sfx);
        stats = dl_walk(dl);
        sink_u32("dl.commands", stats.commands);
        sink_u32("dl.vertices", stats.vertices);
        scene_hash();
        if (frame == ppmFrame && !preview_write(dl, ppmPath)) {
            fail("cannot write the preview");
        }
        fprintf(hashFile, "%d %016llx\n", frame, (unsigned long long) sink_end());

        if (frame == 0 || frame == 100 || frame == frameCount - 1) {
            report("dl", frame, stats);
        }
    }

    fclose(hashFile);
    if (dumpFile != NULL) {
        fclose(dumpFile);
    }
    free(frames);
    return 0;
}
