// Native reference for the math_util port check: runs the cases of a file through the vanilla functions.
// Case line: <function> <args...>; f32 values are 8 hex digits of the bit pattern, integers are decimal.
// Result line: <function> <results...>; a NaN prints as "nan". See verify_math.luau for the argument layouts.
#include "engine/math_util.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

Vec3f gVec3fZero = { 0.0f, 0.0f, 0.0f };

// Deterministic stand-in for the surface lookup, mirrored by verify_math.luau.
f32 find_floor(f32 x, f32 y, f32 z, struct Surface **pfloor) {
    *pfloor = NULL;
    return (f32) ((((s32) x * 3 + (s32) z * 7) % 211)) - 100.0f + (y - 150.0f);
}

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

static void input_vec3f(Vec3f v) {
    int i;

    for (i = 0; i < 3; i++) {
        v[i] = input_f32();
    }
}

static void input_vec3s(Vec3s v) {
    int i;

    for (i = 0; i < 3; i++) {
        v[i] = (s16) input_int();
    }
}

static void input_mat4(Mat4 m) {
    int i, j;

    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            m[i][j] = input_f32();
        }
    }
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

static void output_vec3f(Vec3f v) {
    int i;

    for (i = 0; i < 3; i++) {
        output_f32(v[i]);
    }
}

static void output_vec3s(Vec3s v) {
    int i;

    for (i = 0; i < 3; i++) {
        output_int(v[i]);
    }
}

static void output_mat4(Mat4 m) {
    int i, j;

    for (i = 0; i < 4; i++) {
        for (j = 0; j < 4; j++) {
            output_f32(m[i][j]);
        }
    }
}

int main(int argc, char **argv) {
    char line[8192];
    FILE *in;

    if (argc != 2 || (in = fopen(argv[1], "r")) == NULL) {
        fprintf(stderr, "usage: math_driver <cases>\n");
        return 2;
    }

    while (fgets(line, sizeof(line), in) != NULL) {
        char *name = strtok(line, " \t\r\n");
        Vec3f v1, v2, v3, v4;
        Vec3s s1, s2, s3;
        Mat4 m1, m2, m3;
        f32 f1, f2, f3, f4;
        long i1, i2, i3, i4;

        if (name == NULL) {
            continue;
        }
        printf("%s", name);

        if (strcmp(name, "vec3f_copy") == 0) {
            input_vec3f(v1); input_vec3f(v2);
            vec3f_copy(v1, v2);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_set") == 0) {
            input_vec3f(v1); f1 = input_f32(); f2 = input_f32(); f3 = input_f32();
            vec3f_set(v1, f1, f2, f3);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_add") == 0) {
            input_vec3f(v1); input_vec3f(v2);
            vec3f_add(v1, v2);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_sum") == 0) {
            input_vec3f(v1); input_vec3f(v2); input_vec3f(v3);
            vec3f_sum(v1, v2, v3);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3s_copy") == 0) {
            input_vec3s(s1); input_vec3s(s2);
            vec3s_copy(s1, s2);
            output_vec3s(s1);
        } else if (strcmp(name, "vec3s_set") == 0) {
            input_vec3s(s1); i1 = input_int(); i2 = input_int(); i3 = input_int();
            vec3s_set(s1, i1, i2, i3);
            output_vec3s(s1);
        } else if (strcmp(name, "vec3s_add") == 0) {
            input_vec3s(s1); input_vec3s(s2);
            vec3s_add(s1, s2);
            output_vec3s(s1);
        } else if (strcmp(name, "vec3s_sum") == 0) {
            input_vec3s(s1); input_vec3s(s2); input_vec3s(s3);
            vec3s_sum(s1, s2, s3);
            output_vec3s(s1);
        } else if (strcmp(name, "vec3s_sub") == 0) {
            input_vec3s(s1); input_vec3s(s2);
            vec3s_sub(s1, s2);
            output_vec3s(s1);
        } else if (strcmp(name, "vec3s_to_vec3f") == 0) {
            input_vec3f(v1); input_vec3s(s1);
            vec3s_to_vec3f(v1, s1);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_to_vec3s") == 0) {
            input_vec3s(s1); input_vec3f(v1);
            vec3f_to_vec3s(s1, v1);
            output_vec3s(s1);
        } else if (strcmp(name, "find_vector_perpendicular_to_plane") == 0) {
            input_vec3f(v1); input_vec3f(v2); input_vec3f(v3); input_vec3f(v4);
            find_vector_perpendicular_to_plane(v1, v2, v3, v4);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_cross") == 0) {
            input_vec3f(v1); input_vec3f(v2); input_vec3f(v3);
            vec3f_cross(v1, v2, v3);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_normalize") == 0) {
            input_vec3f(v1);
            vec3f_normalize(v1);
            output_vec3f(v1);
        } else if (strcmp(name, "mtxf_copy") == 0) {
            input_mat4(m1); input_mat4(m2);
            mtxf_copy(m1, m2);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_identity") == 0) {
            input_mat4(m1);
            mtxf_identity(m1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_translate") == 0) {
            input_mat4(m1); input_vec3f(v1);
            mtxf_translate(m1, v1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_lookat") == 0) {
            input_mat4(m1); input_vec3f(v1); input_vec3f(v2); i1 = input_int();
            mtxf_lookat(m1, v1, v2, i1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_rotate_zxy_and_translate") == 0) {
            input_mat4(m1); input_vec3f(v1); input_vec3s(s1);
            mtxf_rotate_zxy_and_translate(m1, v1, s1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_rotate_xyz_and_translate") == 0) {
            input_mat4(m1); input_vec3f(v1); input_vec3s(s1);
            mtxf_rotate_xyz_and_translate(m1, v1, s1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_billboard") == 0) {
            input_mat4(m1); input_mat4(m2); input_vec3f(v1); i1 = input_int();
            mtxf_billboard(m1, m2, v1, i1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_align_terrain_normal") == 0) {
            input_mat4(m1); input_vec3f(v1); input_vec3f(v2); i1 = input_int();
            mtxf_align_terrain_normal(m1, v1, v2, i1);
            output_mat4(m1);
            output_vec3f(v1);
        } else if (strcmp(name, "mtxf_align_terrain_triangle") == 0) {
            input_mat4(m1); input_vec3f(v1); i1 = input_int(); f1 = input_f32();
            mtxf_align_terrain_triangle(m1, v1, i1, f1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_mul") == 0) {
            input_mat4(m1); input_mat4(m2); input_mat4(m3);
            mtxf_mul(m1, m2, m3);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_scale_vec3f") == 0) {
            input_mat4(m1); input_mat4(m2); input_vec3f(v1);
            mtxf_scale_vec3f(m1, m2, v1);
            output_mat4(m1);
        } else if (strcmp(name, "mtxf_mul_vec3s") == 0) {
            input_mat4(m1); input_vec3s(s1);
            mtxf_mul_vec3s(m1, s1);
            output_vec3s(s1);
        } else if (strcmp(name, "mtxf_to_mtx") == 0) {
            Mtx out;
            s32 *words = (s32 *) &out;
            int i;

            memset(&out, 0, sizeof(out));
            input_mat4(m1);
            mtxf_to_mtx(&out, m1);
            for (i = 0; i < 16; i++) {
                output_int(words[i]);
            }
        } else if (strcmp(name, "mtxf_rotate_xy") == 0) {
            Mtx out;
            s32 *words = (s32 *) &out;
            int i;

            memset(&out, 0, sizeof(out));
            i1 = input_int();
            mtxf_rotate_xy(&out, i1);
            for (i = 0; i < 16; i++) {
                output_int(words[i]);
            }
        } else if (strcmp(name, "get_pos_from_transform_mtx") == 0) {
            input_vec3f(v1); input_mat4(m1); input_mat4(m2);
            get_pos_from_transform_mtx(v1, m1, m2);
            output_vec3f(v1);
        } else if (strcmp(name, "vec3f_get_dist_and_angle") == 0) {
            f32 dist;
            s16 pitch, yaw;

            input_vec3f(v1); input_vec3f(v2);
            vec3f_get_dist_and_angle(v1, v2, &dist, &pitch, &yaw);
            output_f32(dist);
            output_int(pitch);
            output_int(yaw);
        } else if (strcmp(name, "vec3f_set_dist_and_angle") == 0) {
            input_vec3f(v1); input_vec3f(v2); f1 = input_f32(); i1 = input_int(); i2 = input_int();
            vec3f_set_dist_and_angle(v1, v2, f1, i1, i2);
            output_vec3f(v2);
        } else if (strcmp(name, "approach_s32") == 0) {
            i1 = input_int(); i2 = input_int(); i3 = input_int(); i4 = input_int();
            output_int(approach_s32(i1, i2, i3, i4));
        } else if (strcmp(name, "approach_f32") == 0) {
            f1 = input_f32(); f2 = input_f32(); f3 = input_f32(); f4 = input_f32();
            output_f32(approach_f32(f1, f2, f3, f4));
        } else if (strcmp(name, "atan2_lookup") == 0) {
            f1 = input_f32(); f2 = input_f32();
            output_int(atan2_lookup(f1, f2));
        } else if (strcmp(name, "atan2s") == 0) {
            f1 = input_f32(); f2 = input_f32();
            output_int(atan2s(f1, f2));
        } else if (strcmp(name, "atan2f") == 0) {
            f1 = input_f32(); f2 = input_f32();
            output_f32(atan2f(f1, f2));
        } else if (strcmp(name, "sins") == 0) {
            i1 = input_int();
            output_f32(sins(i1));
        } else if (strcmp(name, "coss") == 0) {
            i1 = input_int();
            output_f32(coss(i1));
        } else if (strcmp(name, "spline_get_weights") == 0) {
            Vec4f weights;
            int i;

            gSplineState = (int) input_int(); f1 = input_f32();
            spline_get_weights(weights, f1, 0);
            for (i = 0; i < 4; i++) {
                output_f32(weights[i]);
            }
        } else if (strcmp(name, "spline") == 0) {
            // keyframe count, then (speed x y z) per keyframe; zero padding follows like the real animations
            Vec4s keyframes[64];
            Vec3f result;
            int count = (int) input_int();
            int i;
            int polls;

            memset(keyframes, 0, sizeof(keyframes));
            for (i = 0; i < count; i++) {
                keyframes[i][0] = (s16) input_int();
                keyframes[i][1] = (s16) input_int();
                keyframes[i][2] = (s16) input_int();
                keyframes[i][3] = (s16) input_int();
            }
            anim_spline_init(keyframes);
            for (polls = 0; polls < 300; polls++) {
                s32 ended = anim_spline_poll(result);

                output_vec3f(result);
                output_int(ended);
                if (ended) {
                    break;
                }
            }
        } else {
            fprintf(stderr, "unknown case %s\n", name);
            return 1;
        }
        printf("\n");
    }
    return 0;
}
