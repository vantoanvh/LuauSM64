// Native reference for the surface_load port check: runs the vanilla loaders on the level collision data compiled from
// reference/levels and dumps the surface pool and the partitions. See verify_load.luau for the commands. An object model is
// loaded by the real load_object_collision_model on a real struct Object.
//
// Real: surface_load.c (all of it) and macro_special_objects.c (spawn_special_objects walks the object list with the real preset
// table; its spawn_object_abs_with_rot is a stub). Stubbed: the main pool, reset_red_coins_collected, the object helpers.
// The spawners are wrapped to log where they were called and how far the list pointer moved.
#include "game/macro_special_objects.c"

#include "surface_terrains.h"
#include "moving_texture_macros.h"
#include "level_misc_macros.h"
#include "dialog_ids.h"
#include "macro_presets.h"
#include "special_presets.h"

#include "levels/bob/areas/1/collision.inc.c"
#include "levels/bob/areas/1/macro.inc.c"
#include "levels/bob/chain_chomp_gate/collision.inc.c"
#include "levels/bob/seesaw_platform/collision.inc.c"
#include "levels/bob/grate_door/collision.inc.c"
#include "levels/jrb/areas/1/collision.inc.c"
#include "levels/jrb/areas/1/macro.inc.c"
#include "levels/ccm/areas/1/collision.inc.c"
#include "levels/ccm/areas/1/macro.inc.c"
#include "levels/castle_inside/areas/1/collision.inc.c"
#include "levels/castle_inside/areas/1/macro.inc.c"
#include "levels/castle_inside/areas/1/room.inc.c"
#include "levels/bbh/areas/1/collision.inc.c"
#include "levels/bbh/areas/1/macro.inc.c"
#include "levels/bbh/areas/1/room.inc.c"
#include "levels/hmc/areas/1/collision.inc.c"
#include "levels/hmc/areas/1/macro.inc.c"
#include "levels/hmc/areas/1/room.inc.c"
#include "levels/ddd/areas/1/collision.inc.c"
#include "levels/ddd/areas/1/macro.inc.c"
#include "levels/ddd/submarine/collision.inc.c"
#include "levels/ttm/areas/1/collision.inc.c"
#include "levels/ttm/areas/1/macro.inc.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

u32 gTimeStopState;
struct Object gMacroObjectDefaultParent;
struct Object *gMarioObject;
struct Object *gCurrentObject;
s32 gSurfaceNodesAllocated;
s32 gSurfacesAllocated;
s32 gNumStaticSurfaceNodes;
s32 gNumStaticSurfaces;
TerrainData *gEnvironmentRegions;
s32 gEnvironmentLevels[20];
s16 gCCMEnteredSlide;

const BehaviorScript bhvDDDWarp[1] = { 0 };

void *main_pool_alloc(u32 size, u32 side) {
    return calloc(1, size);
}

void reset_red_coins_collected(void) {
}

void *segmented_to_virtual(const void *addr) {
    return (void *) addr;
}

struct Object *spawn_object_abs_with_rot(struct Object *parent, s16 uselessArg, u32 model, const BehaviorScript *behavior,
                                         s16 x, s16 y, s16 z, s16 rx, s16 ry, s16 rz) {
    static struct Object spawned;

    return &spawned;
}

f32 dist_between_objects(struct Object *obj1, struct Object *obj2) {
    return 0.0f;
}

void obj_build_transform_from_pos_and_angle(struct Object *obj, s16 posIndex, s16 angleIndex) {
}

// Scale 1: the transformation is used as it is
void obj_apply_scale_to_matrix(struct Object *obj, Mat4 dst, Mat4 src) {
    memcpy(dst, src, sizeof(Mat4));
}

// Offsets are in terrain data words from the start of the area (or object model) being loaded; the environment offset is from the area's
static TerrainData *sAreaStart;
static TerrainData *sEnvironmentBase;

static void log_special_objects(s16 index, TerrainData **list) {
    TerrainData *start = *list;

    spawn_special_objects(index, list);
    printf("special %d %ld %ld\n", index, (long) (start - sAreaStart), (long) (*list - sAreaStart));
}

static void log_macro_objects(s16 index, s16 *list) {
    printf("macro %d %d\n", index, list[0]);
    spawn_macro_objects(index, list);
}

static void log_macro_objects_hardcoded(s16 index, s16 *list) {
    printf("hardcoded %d %d\n", index, list[0]);
    spawn_macro_objects_hardcoded(index, list);
}

#define spawn_special_objects(index, list) log_special_objects(index, list)
#define spawn_macro_objects(index, list) log_macro_objects(index, list)
#define spawn_macro_objects_hardcoded(index, list) log_macro_objects_hardcoded(index, list)
#include "engine/surface_load.c"
#undef spawn_special_objects
#undef spawn_macro_objects
#undef spawn_macro_objects_hardcoded

struct TestArea {
    const char *name;
    TerrainData *terrain;
    RoomData *rooms;
    s16 *macro;
};

static struct TestArea sAreas[] = {
    { "bob_1", (TerrainData *) bob_seg7_collision_level, NULL, (s16 *) bob_seg7_macro_objs },
    { "jrb_1", (TerrainData *) jrb_seg7_area_1_collision, NULL, (s16 *) jrb_seg7_area_1_macro_objs },
    { "ccm_1", (TerrainData *) ccm_seg7_area_1_collision, NULL, (s16 *) ccm_seg7_area_1_macro_objs },
    { "castle_inside_1", (TerrainData *) inside_castle_seg7_area_1_collision, (RoomData *) inside_castle_seg7_area_1_rooms,
      (s16 *) inside_castle_seg7_area_1_macro_objs },
    { "bbh_1", (TerrainData *) bbh_seg7_collision_level, (RoomData *) bbh_seg7_rooms, (s16 *) bbh_seg7_macro_objs },
    { "hmc_1", (TerrainData *) hmc_seg7_collision_level, (RoomData *) hmc_seg7_rooms, (s16 *) hmc_seg7_macro_objs },
    { "ddd_1", (TerrainData *) ddd_seg7_area_1_collision, NULL, (s16 *) ddd_seg7_area_1_macro_objs },
    { "ttm_1", (TerrainData *) ttm_seg7_area_1_collision, NULL, (s16 *) ttm_seg7_area_1_macro_objs },
};

struct Model {
    const char *name;
    TerrainData *collision;
};

static struct Model sModels[] = {
    { "bob_chain_chomp_gate", (TerrainData *) bob_seg7_collision_chain_chomp_gate },
    { "bob_bridge", (TerrainData *) bob_seg7_collision_bridge },
    { "bob_gate", (TerrainData *) bob_seg7_collision_gate },
    { "ddd_submarine", (TerrainData *) ddd_seg7_collision_submarine },
};

static char *input_token(void) {
    return strtok(NULL, " \t\r\n");
}

static f32 input_f32(void) {
    uint32_t bits = (uint32_t) strtoul(input_token(), NULL, 16);
    f32 value;

    memcpy(&value, &bits, 4);
    return value;
}

static long input_int(void) {
    return strtol(input_token(), NULL, 10);
}

static void output_f32(f32 value) {
    uint32_t bits;

    if (isnan(value)) {
        printf(" nan");
        return;
    }
    memcpy(&bits, &value, 4);
    printf(" %08x", bits);
}

static long surface_index(struct Surface *surface) {
    return surface == NULL ? -1 : (long) (surface - sSurfacePool);
}

static void dump_partition(const char *label, SpatialPartitionCell (*partition)[NUM_CELLS]) {
    int z, x, list;

    for (z = 0; z < NUM_CELLS; z++) {
        for (x = 0; x < NUM_CELLS; x++) {
            for (list = 0; list < 3; list++) {
                struct SurfaceNode *node = partition[z][x][list].next;
                int count = 0;

                if (node == NULL) {
                    continue;
                }
                for (; node != NULL; node = node->next) {
                    count++;
                }
                printf("cell %s %d %d %d %d", label, z, x, list, count);
                for (node = partition[z][x][list].next; node != NULL; node = node->next) {
                    printf(" %ld", surface_index(node->surface));
                }
                printf("\n");
            }
        }
    }
}

// Surfaces from index first, and the partition of the static or dynamic surfaces
static void dump_state(const char *label, int first, int dynamic) {
    int i;

    printf("state %s nodes %d surfaces %d staticnodes %d staticsurfaces %d env %ld unused %d\n", label, gSurfaceNodesAllocated,
           gSurfacesAllocated, gNumStaticSurfaceNodes, gNumStaticSurfaces,
           gEnvironmentRegions == NULL ? -1L : (long) (gEnvironmentRegions - sEnvironmentBase), unused8038BE90);
    printf("levels");
    for (i = 0; i < 20; i++) {
        printf(" %d", gEnvironmentLevels[i]);
    }
    printf("\n");

    for (i = first; i < gSurfacesAllocated; i++) {
        struct Surface *s = &sSurfacePool[i];

        printf("surf %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d", i, s->type, s->force, s->flags, s->room, s->lowerY,
               s->upperY, s->vertex1[0], s->vertex1[1], s->vertex1[2], s->vertex2[0], s->vertex2[1], s->vertex2[2],
               s->vertex3[0], s->vertex3[1], s->vertex3[2]);
        output_f32(s->normal.x);
        output_f32(s->normal.y);
        output_f32(s->normal.z);
        output_f32(s->originOffset);
        printf(" %d\n", s->object != NULL);
    }

    if (dynamic) {
        dump_partition("dynamic", gDynamicSurfacePartition);
    } else {
        dump_partition("static", gStaticSurfacePartition);
    }
}

int main(int argc, char **argv) {
    char line[8192];
    FILE *in;
    static struct Object object;

    if (argc != 2 || (in = fopen(argv[1], "r")) == NULL) {
        fprintf(stderr, "usage: load_driver <cases>\n");
        return 2;
    }

    alloc_surface_pools();

    while (fgets(line, sizeof(line), in) != NULL) {
        char *name = strtok(line, " \t\r\n");
        int i, j;

        if (name == NULL) {
            continue;
        }

        if (strcmp(name, "area") == 0) {
            const char *which = input_token();
            s16 index = (s16) input_int();

            for (i = 0; i < (int) (sizeof(sAreas) / sizeof(sAreas[0])); i++) {
                if (strcmp(which, sAreas[i].name) == 0) {
                    sAreaStart = sAreas[i].terrain;
                    sEnvironmentBase = sAreas[i].terrain;
                    load_area_terrain(index, sAreas[i].terrain, sAreas[i].rooms, sAreas[i].macro);
                    dump_state(which, 0, 0);
                }
            }
        } else if (strcmp(name, "dynclear") == 0) {
            clear_dynamic_surfaces();
        } else if (strcmp(name, "timestop") == 0) {
            gTimeStopState = (u32) input_int();
        } else if (strcmp(name, "object") == 0) {
            const char *which = input_token();

            memset(&object, 0, sizeof(object));
            gCurrentObject = &object;
            for (i = 0; i < 4; i++) {
                for (j = 0; j < 4; j++) {
                    object.transform[i][j] = input_f32();
                }
            }
            object.header.gfx.throwMatrix = &object.transform;
            object.oDistanceToMario = input_f32();
            object.oCollisionDistance = input_f32();
            object.oDrawingDistance = input_f32();
            object.activeFlags = (s16) input_int();
            object.behavior = input_int() ? bhvDDDWarp : NULL;

            for (i = 0; i < (int) (sizeof(sModels) / sizeof(sModels[0])); i++) {
                if (strcmp(which, sModels[i].name) == 0) {
                    object.collisionData = sModels[i].collision;
                    sAreaStart = sModels[i].collision;
                    load_object_collision_model();
                    dump_state(which, gNumStaticSurfaces, 1);
                    printf("objstate %s %d", which, object.header.gfx.node.flags);
                    output_f32(object.oDrawingDistance);
                    printf("\n");
                }
            }
        }
    }
    return 0;
}
