// Headless deterministic driver: runs the game boot and main loop of thread5_game_loop
// (src/game/game_init.c) once per trace line and writes one state hash per frame.
//
// Usage: sm64_native <trace> <hash-out> [<dump-out> [<dump-from-frame>]]
// Trace: see docs/state-hash.md (boot options and `do` directives).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

#include "sm64.h"
#include "behavior_data.h"
#include "model_ids.h"
#include "engine/level_script.h"
#include "game/game_init.h"
#include "game/level_update.h"
#include "game/main.h"
#include "game/memory.h"
#include "game/object_helpers.h"
#include "game/object_list_processor.h"
#include "game/save_file.h"
#include "game/sound_init.h"
#include "audio/external.h"

#include "harness.h"
#include "behavior_offset.h"
#include "state_hash.h"

#define POOL_BYTES 0x1000000

extern OSMesgQueue gGameVblankQueue;
extern struct VblankHandler gGameVblankHandler;
extern struct MemoryPool *gEffectsMemoryPool;
extern struct Object *gCurrentObject;
extern s16 gCurrActNum;
extern s16 gSavedCourseNum;
extern void spawn_default_star(f32 homeX, f32 homeY, f32 homeZ);
extern void spawn_no_exit_star(f32 homeX, f32 homeY, f32 homeZ);
extern void mario_blow_off_cap(struct MarioState *m, f32 capSpeed);

static u8 sPool[POOL_BYTES] __attribute__((aligned(16)));

#define MAX_DIRECTIVES 4

enum DirectiveKind {
    DIRECTIVE_WARP,
    DIRECTIVE_ACT,
    DIRECTIVE_STAR,
    DIRECTIVE_STAR_NO_EXIT,
    DIRECTIVE_GRAND_STAR,
    DIRECTIVE_CAP,
    DIRECTIVE_LIVES,
    DIRECTIVE_TRIGGER,
    DIRECTIVE_POS,
    DIRECTIVE_STARS,
    DIRECTIVE_KEY,
    DIRECTIVE_OBJECT_ACTION,
    DIRECTIVE_BLOW_CAP,
};

// A stimulus the trace applies between two frames (docs/state-hash.md, `do`)
struct Directive {
    int kind;
    int args[3];
};

struct FrameInput {
    u16 buttons;
    s8 stickX;
    s8 stickY;
    int directiveCount;
    struct Directive directives[MAX_DIRECTIVES];
};

static void fail(const char *message, const char *detail, int line) {
    fprintf(stderr, "%s%s%s (trace line %d)\n", message, detail != NULL ? ": " : "", detail != NULL ? detail : "", line);
    exit(1);
}

static void apply_boot_option(const char *key, const char *value, int line) {
    if (strcmp(key, "debug_level_select") == 0) {
        gDebugLevelSelect = (s8) atoi(value);
    } else {
        fail("unknown boot option", key, line);
    }
}

static struct Directive parse_directive(const char *text, int line) {
    struct Directive directive = { 0, { 0, 0, 0 } };
    char name[16];
    int count = sscanf(text, "do %15s %d %d %d", name, &directive.args[0], &directive.args[1], &directive.args[2]) - 1;

    if (strcmp(name, "warp") == 0 && count == 3) {
        directive.kind = DIRECTIVE_WARP;
    } else if (strcmp(name, "act") == 0 && count == 1) {
        directive.kind = DIRECTIVE_ACT;
    } else if (strcmp(name, "star") == 0 && count == 3) {
        directive.kind = DIRECTIVE_STAR;
    } else if (strcmp(name, "starnoexit") == 0 && count == 3) {
        directive.kind = DIRECTIVE_STAR_NO_EXIT;
    } else if (strcmp(name, "grandstar") == 0 && count == 0) {
        directive.kind = DIRECTIVE_GRAND_STAR;
    } else if (strcmp(name, "cap") == 0 && count == 2) {
        directive.kind = DIRECTIVE_CAP;
    } else if (strcmp(name, "lives") == 0 && count == 1) {
        directive.kind = DIRECTIVE_LIVES;
    } else if (strcmp(name, "trigger") == 0 && count == 1) {
        directive.kind = DIRECTIVE_TRIGGER;
    } else if (strcmp(name, "pos") == 0 && count == 3) {
        directive.kind = DIRECTIVE_POS;
    } else if (strcmp(name, "stars") == 0 && count == 1) {
        directive.kind = DIRECTIVE_STARS;
    } else if (strcmp(name, "key") == 0 && count == 1) {
        directive.kind = DIRECTIVE_KEY;
    } else if (strcmp(name, "objact") == 0 && count == 2) {
        directive.kind = DIRECTIVE_OBJECT_ACTION;
    } else if (strcmp(name, "blowcap") == 0 && count == 1) {
        directive.kind = DIRECTIVE_BLOW_CAP;
    } else {
        fail("bad directive", text, line);
    }
    return directive;
}

// Trace lines: "boot <key> <value>" before the first frame, "do <name> <args>" before the frame it applies to, then
// "<buttons> <stickX> <stickY>" per frame.
static struct FrameInput *read_trace(const char *path, int *frameCount) {
    FILE *file = fopen(path, "r");
    char text[256];
    int line = 0;
    int capacity = 1024;
    struct FrameInput *frames = malloc(capacity * sizeof(*frames));
    struct Directive pending[MAX_DIRECTIVES];
    int pendingCount = 0;

    if (file == NULL) {
        fail("cannot open trace", path, 0);
    }
    *frameCount = 0;
    while (fgets(text, sizeof(text), file) != NULL) {
        char key[64];
        char value[64];
        unsigned buttons;
        int stickX;
        int stickY;

        line++;
        if (text[0] == '#' || text[0] == '\n' || text[0] == '\r') {
            continue;
        }
        if (sscanf(text, "boot %63s %63s", key, value) == 2) {
            if (*frameCount > 0) {
                fail("boot option after first frame", NULL, line);
            }
            apply_boot_option(key, value, line);
            continue;
        }
        if (strncmp(text, "do ", 3) == 0) {
            if (pendingCount == MAX_DIRECTIVES) {
                fail("too many directives before one frame", NULL, line);
            }
            pending[pendingCount++] = parse_directive(text, line);
            continue;
        }
        if (sscanf(text, "%i %d %d", &buttons, &stickX, &stickY) != 3) {
            fail("bad trace line", text, line);
        }
        if (*frameCount == capacity) {
            capacity *= 2;
            frames = realloc(frames, capacity * sizeof(*frames));
        }
        frames[*frameCount].buttons = (u16) buttons;
        frames[*frameCount].stickX = (s8) stickX;
        frames[*frameCount].stickY = (s8) stickY;
        frames[*frameCount].directiveCount = pendingCount;
        memcpy(frames[*frameCount].directives, pending, pendingCount * sizeof(*pending));
        pendingCount = 0;
        (*frameCount)++;
    }
    if (pendingCount > 0) {
        fail("directive after the last frame", NULL, line);
    }
    fclose(file);
    return frames;
}

// warp: the pause menu's exit of a course (play_mode_paused); act: the act the level loads with; star, starnoexit:
// spawn_default_star or spawn_no_exit_star at Mario plus the offset, as an object of Mario's would; grandstar: the grand
// star at Mario; cap: the cap flags and the cap timer of Mario; lives: his lives; trigger: level_trigger_warp with a
// WARP_OP (the death, the credits...); pos: Mario's position; stars: the saved file has this many stars (seven in each
// course in turn, the lowest bits of the star flags); key: save flags to set (the keys, the unlocked doors); objact: the
// action of every active object whose behavior is at that offset in segment 0x13 (a boss in the state of its next
// action); blowcap: mario_blow_off_cap with that speed
static void apply_directive(const struct Directive *directive) {
    int course;
    int slot;

    switch (directive->kind) {
        case DIRECTIVE_WARP:
            initiate_warp(directive->args[0], directive->args[1], directive->args[2], 0);
            fade_into_special_warp(0, 0);
            gSavedCourseNum = COURSE_NONE;
            break;
        case DIRECTIVE_ACT:
            gCurrActNum = directive->args[0];
            break;
        case DIRECTIVE_STAR:
        case DIRECTIVE_STAR_NO_EXIT:
            gCurrentObject = gMarioState->marioObj;
            (directive->kind == DIRECTIVE_STAR ? spawn_default_star : spawn_no_exit_star)(
                gMarioState->pos[0] + directive->args[0], gMarioState->pos[1] + directive->args[1],
                gMarioState->pos[2] + directive->args[2]);
            break;
        case DIRECTIVE_GRAND_STAR:
            spawn_object(gMarioState->marioObj, MODEL_STAR, bhvGrandStar);
            break;
        case DIRECTIVE_CAP:
            gMarioState->flags |= directive->args[0];
            gMarioState->capTimer = directive->args[1];
            break;
        case DIRECTIVE_LIVES:
            gMarioState->numLives = directive->args[0];
            break;
        case DIRECTIVE_TRIGGER:
            level_trigger_warp(gMarioState, directive->args[0]);
            break;
        case DIRECTIVE_POS:
            gMarioState->pos[0] = directive->args[0];
            gMarioState->pos[1] = directive->args[1];
            gMarioState->pos[2] = directive->args[2];
            break;
        case DIRECTIVE_STARS:
            for (course = 0; course < 15; course++) {
                int stars = directive->args[0] - 7 * course;

                stars = stars < 0 ? 0 : stars > 7 ? 7 : stars;
                if (stars > 0) {
                    save_file_set_star_flags(gCurrSaveFileNum - 1, course, (1 << stars) - 1);
                }
            }
            break;
        case DIRECTIVE_KEY:
            save_file_set_flags(directive->args[0]);
            break;
        case DIRECTIVE_OBJECT_ACTION:
            for (slot = 0; slot < OBJECT_POOL_CAPACITY; slot++) {
                struct Object *object = &gObjectPool[slot];

                if (object->activeFlags != ACTIVE_FLAG_DEACTIVATED && behavior_offset(object->behavior) == (u32) directive->args[0]) {
                    object->oAction = directive->args[1];
                }
            }
            break;
        case DIRECTIVE_BLOW_CAP:
            mario_blow_off_cap(gMarioState, directive->args[0]);
            break;
    }
}

// Boot sequence of thread3_main and thread5_game_loop, minus threads, audio and rumble.
static struct LevelCommand *boot_game(void) {
    main_pool_init(sPool, sPool + POOL_BYTES);
    gEffectsMemoryPool = mem_pool_init(0x4000, MEMORY_POOL_LEFT);

    setup_game_memory();
    init_controllers();
    save_file_load_all();
    set_vblank_handler(2, &gGameVblankHandler, &gGameVblankQueue, (OSMesg) 1);
    set_sound_mode(save_file_get_sound_mode());
    render_init();

    return segmented_to_virtual(level_script_entry);
}

int main(int argc, char **argv) {
    struct FrameInput *frames;
    struct LevelCommand *addr;
    FILE *hashFile;
    FILE *dumpFile = NULL;
    int frameCount;
    int dumpFrom = 0;
    int frame;

    if (argc < 3) {
        fprintf(stderr, "usage: %s <trace> <hash-out> [<dump-out> [<dump-from-frame>]]\n", argv[0]);
        return 2;
    }
    frames = read_trace(argv[1], &frameCount);
    hashFile = fopen(argv[2], "w");
    if (argc > 4) {
        dumpFrom = atoi(argv[4]);
    }
    if (argc > 3) {
        dumpFile = fopen(argv[3], "w");
    }
    if (hashFile == NULL || (argc > 3 && dumpFile == NULL)) {
        fprintf(stderr, "cannot open output\n");
        return 1;
    }

    addr = boot_game();
    for (frame = 0; frame < frameCount; frame++) {
        int directive;

        for (directive = 0; directive < frames[frame].directiveCount; directive++) {
            apply_directive(&frames[frame].directives[directive]);
        }
        native_set_pad(frames[frame].buttons, frames[frame].stickX, frames[frame].stickY);
        audio_game_loop_tick();
        select_gfx_pool();
        read_controller_inputs();
        addr = level_script_execute(addr);
        display_and_vsync();

        if (dumpFile != NULL && frame >= dumpFrom) {
            fprintf(dumpFile, "frame %d\n", frame);
        }
        fprintf(hashFile, "%d %016llx\n", frame, (unsigned long long) state_hash_frame(frame >= dumpFrom ? dumpFile : NULL));
    }

    fclose(hashFile);
    if (dumpFile != NULL) {
        fclose(dumpFile);
    }
    free(frames);
    return 0;
}
