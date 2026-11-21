// Native reference for the surface_collision port check: builds a scene from a case file and runs the queries through the vanilla functions.
// Same token conventions as math_driver.c. See verify_surface.luau for the command layouts.
#include "engine/surface_collision.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define MAX_SURFACES 1024
#define MAX_NODES 4096

SpatialPartitionCell gStaticSurfacePartition[NUM_CELLS][NUM_CELLS];
SpatialPartitionCell gDynamicSurfacePartition[NUM_CELLS][NUM_CELLS];
s16 gCheckingSurfaceCollisionsForCamera;
s16 gFindFloorIncludeSurfaceIntangible;
struct NumTimesCalled gNumCalls;
s32 gNumFindFloorMisses;
TerrainData *gEnvironmentRegions;
s32 gSurfaceNodesAllocated;
s32 gNumStaticSurfaces;
s32 gSurfacesAllocated;
struct MarioState gMarioStates[1];
struct MarioState *gMarioState = &gMarioStates[0];
struct Object gMarioObjectStorage;
struct Object gOtherObject;
struct Object *gMarioObject = &gMarioObjectStorage;
struct Object *gCurrentObject;

void print_debug_top_down_mapinfo(const char *str, s32 number) {
}

void set_text_array_x_y(s32 x, s32 y) {
}

static struct Surface sSurfaces[MAX_SURFACES];
static struct SurfaceNode sNodes[MAX_NODES];
static int sNodeCount;
static TerrainData sEnvironment[512];

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

static void output_int(long value) {
    printf(" %ld", value);
}

static void output_surface(struct Surface *surface) {
    output_int(surface == NULL ? -1 : (long) (surface - sSurfaces));
}

static struct SurfaceNode *cell_head(int dynamic, int cellZ, int cellX, int list) {
    return dynamic ? &gDynamicSurfacePartition[cellZ][cellX][list] : &gStaticSurfacePartition[cellZ][cellX][list];
}

int main(int argc, char **argv) {
    char line[8192];
    FILE *in;

    if (argc != 2 || (in = fopen(argv[1], "r")) == NULL) {
        fprintf(stderr, "usage: surface_driver <cases>\n");
        return 2;
    }

    gMarioObject = &gMarioObjectStorage;

    while (fgets(line, sizeof(line), in) != NULL) {
        char *name = strtok(line, " \t\r\n");
        int i;

        if (name == NULL) {
            continue;
        }

        if (strcmp(name, "surf") == 0) {
            struct Surface *s = &sSurfaces[input_int()];

            s->type = input_int();
            s->force = input_int();
            s->flags = input_int();
            s->room = input_int();
            s->lowerY = input_int();
            s->upperY = input_int();
            for (i = 0; i < 3; i++) s->vertex1[i] = input_int();
            for (i = 0; i < 3; i++) s->vertex2[i] = input_int();
            for (i = 0; i < 3; i++) s->vertex3[i] = input_int();
            s->normal.x = input_f32();
            s->normal.y = input_f32();
            s->normal.z = input_f32();
            s->originOffset = input_f32();
            s->object = NULL;
        } else if (strcmp(name, "cell") == 0) {
            int dynamic = (int) input_int();
            int cellZ = (int) input_int();
            int cellX = (int) input_int();
            int list = (int) input_int();
            int count = (int) input_int();
            struct SurfaceNode *tail = cell_head(dynamic, cellZ, cellX, list);

            for (i = 0; i < count; i++) {
                struct SurfaceNode *node = &sNodes[sNodeCount++];

                node->surface = &sSurfaces[input_int()];
                node->next = NULL;
                tail->next = node;
                tail = node;
            }
        } else if (strcmp(name, "env") == 0) {
            int count = (int) input_int();

            for (i = 0; i < count; i++) {
                sEnvironment[i] = (TerrainData) input_int();
            }
            gEnvironmentRegions = sEnvironment;
        } else if (strcmp(name, "noenv") == 0) {
            gEnvironmentRegions = NULL;
        } else if (strcmp(name, "camera") == 0) {
            gCheckingSurfaceCollisionsForCamera = (s16) input_int();
        } else if (strcmp(name, "intangible") == 0) {
            gFindFloorIncludeSurfaceIntangible = (s16) input_int();
        } else if (strcmp(name, "marioflags") == 0) {
            gMarioState->flags = (u32) strtoul(input_token(), NULL, 16);
        } else if (strcmp(name, "current") == 0) {
            switch (input_int()) {
                case 0: gCurrentObject = NULL; break;
                case 1: gCurrentObject = gMarioObject; break;
                case 2: gCurrentObject = &gOtherObject; gOtherObject.activeFlags = ACTIVE_FLAG_MOVE_THROUGH_GRATE; break;
                default: gCurrentObject = &gOtherObject; gOtherObject.activeFlags = 0; break;
            }
        } else if (strcmp(name, "wall") == 0) {
            struct WallCollisionData data;
            s32 count;

            memset(&data, 0, sizeof(data));
            data.x = input_f32(); data.y = input_f32(); data.z = input_f32();
            data.offsetY = input_f32(); data.radius = input_f32();
            count = find_wall_collisions(&data);
            printf("wall");
            output_int(count);
            output_int(data.numWalls);
            output_f32(data.x);
            output_f32(data.z);
            for (i = 0; i < data.numWalls; i++) {
                output_surface(data.walls[i]);
            }
            printf("\n");
        } else if (strcmp(name, "wall32") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            f32 offsetY = input_f32(), radius = input_f32();
            s32 count = f32_find_wall_collision(&x, &y, &z, offsetY, radius);

            printf("wall32");
            output_int(count);
            output_f32(x); output_f32(y); output_f32(z);
            printf("\n");
        } else if (strcmp(name, "ceil") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            struct Surface *ceil;
            f32 height = find_ceil(x, y, z, &ceil);

            printf("ceil");
            output_f32(height);
            output_surface(ceil);
            printf("\n");
        } else if (strcmp(name, "floor") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            struct Surface *floor;
            f32 height = find_floor(x, y, z, &floor);

            printf("floor");
            output_f32(height);
            output_surface(floor);
            output_int(gFindFloorIncludeSurfaceIntangible);
            printf("\n");
        } else if (strcmp(name, "floordata") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            struct FloorGeometry *geo;
            f32 height = find_floor_height_and_data(x, y, z, &geo);

            printf("floordata");
            output_f32(height);
            output_int(geo != NULL);
            if (geo != NULL) {
                output_f32(geo->normalX); output_f32(geo->normalY); output_f32(geo->normalZ); output_f32(geo->originOffset);
            }
            printf("\n");
        } else if (strcmp(name, "floorh") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();

            printf("floorh");
            output_f32(find_floor_height(x, y, z));
            printf("\n");
        } else if (strcmp(name, "dynfloor") == 0) {
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            struct Surface *floor;
            f32 height = unused_find_dynamic_floor(x, y, z, &floor);

            printf("dynfloor");
            output_f32(height);
            output_surface(floor);
            printf("\n");
        } else if (strcmp(name, "ceillist") == 0 || strcmp(name, "floorlist") == 0) {
            int is_ceil = name[0] == 'c';
            int dynamic = (int) input_int();
            int cellZ = (int) input_int();
            int cellX = (int) input_int();
            int list = is_ceil ? SPATIAL_PARTITION_CEILS : SPATIAL_PARTITION_FLOORS;
            s32 x = (s32) input_int(), y = (s32) input_int(), z = (s32) input_int();
            f32 height = input_f32();
            struct SurfaceNode *head = cell_head(dynamic, cellZ, cellX, list)->next;
            struct Surface *surface = is_ceil ? find_ceil_from_list(head, x, y, z, &height) : find_floor_from_list(head, x, y, z, &height);

            printf("%s", name);
            output_surface(surface);
            output_f32(height);
            printf("\n");
        } else if (strcmp(name, "water") == 0) {
            f32 x = input_f32(), z = input_f32();

            printf("water");
            output_f32(find_water_level(x, z));
            printf("\n");
        } else if (strcmp(name, "gas") == 0) {
            f32 x = input_f32(), z = input_f32();

            printf("gas");
            output_f32(find_poison_gas_level(x, z));
            printf("\n");
        } else if (strcmp(name, "listlen") == 0) {
            int dynamic = (int) input_int();
            int cellZ = (int) input_int();
            int cellX = (int) input_int();
            int list = (int) input_int();

            printf("listlen");
            output_int(surface_list_length(cell_head(dynamic, cellZ, cellX, list)->next));
            printf("\n");
        } else if (strcmp(name, "resolve") == 0) {
            s32 checkCeil = (s32) input_int();
            f32 x = input_f32(), y = input_f32(), z = input_f32();
            f32 radius = input_f32();
            struct Surface *surface;
            f32 height;
            s32 ret = unused_resolve_floor_or_ceil_collisions(checkCeil, &x, &y, &z, radius, &surface, &height);

            printf("resolve");
            output_int(ret);
            output_f32(x); output_f32(y); output_f32(z);
            output_f32(height);
            output_surface(surface);
            printf("\n");
        } else if (strcmp(name, "counters") == 0) {
            printf("counters");
            output_int(gNumCalls.floor);
            output_int(gNumCalls.ceil);
            output_int(gNumCalls.wall);
            output_int(gNumFindFloorMisses);
            output_int(gFindFloorIncludeSurfaceIntangible);
            printf("\n");
        } else {
            fprintf(stderr, "unknown command %s\n", name);
            return 1;
        }
    }
    return 0;
}
