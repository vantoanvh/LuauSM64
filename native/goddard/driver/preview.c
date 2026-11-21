// Sanity-check preview of a Goddard display list: a small Fast3D (F3D_OLD) emulation that transforms, lights and
// z-buffers the triangles (untextured: the texture is ignored) and writes a binary PPM. Sprite quads (stars, sparkles) and
// rectangles are skipped; triangles that touch the near plane are skipped (no clipping).
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ultra64.h>

#include "preview.h"

#define WIDTH 320
#define HEIGHT 240
#define SCALE 2
#define MAX_DEPTH 16
#define MAX_MATRICES 16
#define VERTEX_BUFFER 32

typedef float Matrix[4][4];

struct ClipVertex {
    float x;
    float y;
    float z;
    float w;
    float color[3];
};

struct State {
    Matrix modelview[MAX_MATRICES];
    int top;
    Matrix projection;
    Vp viewport;
    u32 geometryMode;
    int skipTriangles; // sprite quads (stars, sparkles): texture on with a texture scale of 0x8000 or more
    int lightCount;
    u8 lightColour[8][3];
    s8 lightDirection[8][3];
    struct ClipVertex vertices[VERTEX_BUFFER];
    float depth[WIDTH * HEIGHT];
    u8 pixels[WIDTH * HEIGHT * 3];
};

static struct State sState;

static void multiply(Matrix result, const Matrix a, const Matrix b) {
    Matrix temp;
    int i;
    int j;
    int k;

    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            temp[i][j] = 0.0f;
            for (k = 0; k < 4; k++) {
                temp[i][j] += a[i][k] * b[k][j];
            }
        }
    }
    memcpy(result, temp, sizeof(temp));
}

static void load_matrix(const Gfx *command) {
    u8 params = (u8) (command->words.w0 >> 16);
    Matrix loaded;
    Matrix *target = (params & G_MTX_PROJECTION) ? &sState.projection : &sState.modelview[sState.top];

    guMtxL2F(loaded, (Mtx *) command->words.w1);
    if (!(params & G_MTX_PROJECTION) && (params & G_MTX_PUSH) && sState.top + 1 < MAX_MATRICES) {
        memcpy(sState.modelview[sState.top + 1], sState.modelview[sState.top], sizeof(Matrix));
        sState.top++;
        target = &sState.modelview[sState.top];
    }
    if (params & G_MTX_LOAD) {
        memcpy(*target, loaded, sizeof(Matrix));
    } else {
        multiply(*target, loaded, *target);
    }
}

static void load_vertices(const Gfx *command) {
    u32 w0 = (u32) command->words.w0;
    int first = (w0 >> 16) & 0xf;
    int count = ((w0 >> 20) & 0xf) + 1;
    const Vtx_t *source = (const Vtx_t *) command->words.w1;
    Matrix combined;
    int i;

    multiply(combined, sState.modelview[sState.top], sState.projection);
    for (i = 0; i < count; i++) {
        struct ClipVertex *out = &sState.vertices[first + i];
        const Matrix *view = &sState.modelview[sState.top];
        float x = source[i].ob[0];
        float y = source[i].ob[1];
        float z = source[i].ob[2];
        int c;

        out->x = x * combined[0][0] + y * combined[1][0] + z * combined[2][0] + combined[3][0];
        out->y = x * combined[0][1] + y * combined[1][1] + z * combined[2][1] + combined[3][1];
        out->z = x * combined[0][2] + y * combined[1][2] + z * combined[2][2] + combined[3][2];
        out->w = x * combined[0][3] + y * combined[1][3] + z * combined[2][3] + combined[3][3];
        if (sState.geometryMode & G_LIGHTING) {
            float normal[3] = { (s8) source[i].cn[0] / 127.0f, (s8) source[i].cn[1] / 127.0f, (s8) source[i].cn[2] / 127.0f };
            float view_normal[3];
            float shade[3];
            int light;

            for (c = 0; c < 3; c++) {
                view_normal[c] = normal[0] * (*view)[0][c] + normal[1] * (*view)[1][c] + normal[2] * (*view)[2][c];
                shade[c] = sState.lightColour[sState.lightCount][c] / 255.0f; // ambient
            }
            for (light = 0; light < sState.lightCount; light++) {
                float dot = 0.0f;

                for (c = 0; c < 3; c++) {
                    dot += view_normal[c] * sState.lightDirection[light][c] / 127.0f;
                }
                if (dot > 0.0f) {
                    for (c = 0; c < 3; c++) {
                        shade[c] += dot * sState.lightColour[light][c] / 255.0f;
                    }
                }
            }
            for (c = 0; c < 3; c++) {
                out->color[c] = shade[c] > 1.0f ? 1.0f : shade[c];
            }
        } else {
            for (c = 0; c < 3; c++) {
                out->color[c] = source[i].cn[c] / 255.0f;
            }
        }
    }
}

static void draw_triangle(const Gfx *command) {
    u32 w1 = (u32) command->words.w1;
    const struct ClipVertex *v[3] = { &sState.vertices[((w1 >> 16) & 0xff) / 10], &sState.vertices[((w1 >> 8) & 0xff) / 10],
                                      &sState.vertices[(w1 & 0xff) / 10] };
    float sx[3];
    float sy[3];
    float sz[3];
    float area;
    int i;
    int minX = WIDTH;
    int maxX = -1;
    int minY = HEIGHT;
    int maxY = -1;
    int x;
    int y;

    if (sState.skipTriangles) {
        return;
    }
    for (i = 0; i < 3; i++) {
        if (v[i]->w <= 0.0f) {
            return;
        }
        sx[i] = v[i]->x / v[i]->w * sState.viewport.vp.vscale[0] / 4.0f + sState.viewport.vp.vtrans[0] / 4.0f;
        // The RSP negates y: screen y grows downward while the projected y grows upward.
        sy[i] = -v[i]->y / v[i]->w * sState.viewport.vp.vscale[1] / 4.0f + sState.viewport.vp.vtrans[1] / 4.0f;
        sz[i] = v[i]->z / v[i]->w;
        minX = sx[i] < minX ? (int) floorf(sx[i]) : minX;
        maxX = sx[i] > maxX ? (int) ceilf(sx[i]) : maxX;
        minY = sy[i] < minY ? (int) floorf(sy[i]) : minY;
        maxY = sy[i] > maxY ? (int) ceilf(sy[i]) : maxY;
    }
    area = (sx[1] - sx[0]) * (sy[2] - sy[0]) - (sx[2] - sx[0]) * (sy[1] - sy[0]);
    if (area == 0.0f) {
        return;
    }
    // Screen y points down and front faces are counter clockwise in the projected plane.
    if ((area < 0.0f && (sState.geometryMode & G_CULL_FRONT)) || (area > 0.0f && (sState.geometryMode & G_CULL_BACK))) {
        return;
    }
    minX = minX < 0 ? 0 : minX;
    minY = minY < 0 ? 0 : minY;
    maxX = maxX >= WIDTH ? WIDTH - 1 : maxX;
    maxY = maxY >= HEIGHT ? HEIGHT - 1 : maxY;
    for (y = minY; y <= maxY; y++) {
        for (x = minX; x <= maxX; x++) {
            float px = x + 0.5f;
            float py = y + 0.5f;
            float b0 = ((sx[1] - px) * (sy[2] - py) - (sx[2] - px) * (sy[1] - py)) / area;
            float b1 = ((sx[2] - px) * (sy[0] - py) - (sx[0] - px) * (sy[2] - py)) / area;
            float b2 = 1.0f - b0 - b1;
            float z;
            int c;

            if (b0 < 0.0f || b1 < 0.0f || b2 < 0.0f) {
                continue;
            }
            z = b0 * sz[0] + b1 * sz[1] + b2 * sz[2];
            if (z >= sState.depth[y * WIDTH + x]) {
                continue;
            }
            sState.depth[y * WIDTH + x] = z;
            for (c = 0; c < 3; c++) {
                float value = b0 * v[0]->color[c] + b1 * v[1]->color[c] + b2 * v[2]->color[c];

                sState.pixels[(y * WIDTH + x) * 3 + c] = (u8) (value * 255.0f);
            }
        }
    }
}

static void load_light(const Gfx *command) {
    u32 w0 = (u32) command->words.w0;
    int index = (w0 >> 16) & 0xff;
    const u8 *data = (const u8 *) command->words.w1;
    int slot = (index - G_MV_L0) / 2;

    if (index == G_MV_VIEWPORT) {
        memcpy(&sState.viewport, data, sizeof(Vp));
    } else if (slot >= 0 && slot < 8) {
        memcpy(sState.lightColour[slot], data, 3);
        memcpy(sState.lightDirection[slot], data + 8, 3);
    }
}

static void walk(const Gfx *dl, int depth) {
    if (depth > MAX_DEPTH) {
        return;
    }
    for (;; dl++) {
        u32 w0 = (u32) dl->words.w0;
        u8 op = (u8) (w0 >> 24);

        switch (op) {
            case G_DL:
                walk((const Gfx *) dl->words.w1, depth + 1);
                if (((w0 >> 16) & 0xff) == G_DL_NOPUSH) {
                    return;
                }
                break;
            case (u8) G_ENDDL:
                return;
            case G_MTX:
                load_matrix(dl);
                break;
            case (u8) G_POPMTX:
                if (sState.top > 0) {
                    sState.top--;
                }
                break;
            case G_MOVEMEM:
                load_light(dl);
                break;
            case (u8) G_MOVEWORD:
                if ((w0 & 0xff) == G_MW_NUMLIGHT) {
                    sState.lightCount = (int) (((u32) dl->words.w1 - 0x80000000u) / 32) - 1;
                }
                break;
            case (u8) G_SETGEOMETRYMODE:
                sState.geometryMode |= (u32) dl->words.w1;
                break;
            case (u8) G_CLEARGEOMETRYMODE:
                sState.geometryMode &= ~(u32) dl->words.w1;
                break;
            case (u8) G_TEXTURE:
                sState.skipTriangles = (w0 & 0xff) != 0 && (dl->words.w1 >> 16) >= 0x8000;
                break;
            case G_VTX:
                load_vertices(dl);
                break;
            case (u8) G_TRI1:
                draw_triangle(dl);
                break;
            default:
                break;
        }
    }
}

int preview_write(const Gfx *dl, const char *path) {
    FILE *file;
    int i;
    int x;
    int y;

    memset(&sState, 0, sizeof(sState));
    for (i = 0; i < WIDTH * HEIGHT; i++) {
        sState.depth[i] = 1e30f;
    }
    walk(dl, 0);
    file = fopen(path, "wb");
    if (file == NULL) {
        return 0;
    }
    fprintf(file, "P6\n%d %d\n255\n", WIDTH * SCALE, HEIGHT * SCALE);
    for (y = 0; y < HEIGHT * SCALE; y++) {
        for (x = 0; x < WIDTH * SCALE; x++) {
            fwrite(&sState.pixels[((y / SCALE) * WIDTH + x / SCALE) * 3], 1, 3, file);
        }
    }
    fclose(file);
    return 1;
}
