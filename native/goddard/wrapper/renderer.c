// Compiles the unmodified src/goddard/renderer.c and adds the accessors for its file-static data.
// gd_exit (an endless loop in the game) is renamed here and defined in stub/os.c so that a goddard fatal error ends the
// oracle instead of hanging it.
#define gd_exit oracle_unused_gd_exit
#include "goddard/renderer.c"
#undef gd_exit

#include "oracle.h"
#include "sink.h"

#define TEXTURE(name) { #name, gd_texture_##name, sizeof(gd_texture_##name) }

const struct OracleTexture gOracleTextures[] = {
    TEXTURE(hand_open),
    TEXTURE(hand_closed),
    TEXTURE(red_star_0),
    TEXTURE(red_star_1),
    TEXTURE(red_star_2),
    TEXTURE(red_star_3),
    TEXTURE(red_star_4),
    TEXTURE(red_star_5),
    TEXTURE(red_star_6),
    TEXTURE(red_star_7),
    TEXTURE(white_star_0),
    TEXTURE(white_star_1),
    TEXTURE(white_star_2),
    TEXTURE(white_star_3),
    TEXTURE(white_star_4),
    TEXTURE(white_star_5),
    TEXTURE(white_star_6),
    TEXTURE(white_star_7),
    TEXTURE(sparkle_0),
    TEXTURE(sparkle_1),
    TEXTURE(sparkle_2),
    TEXTURE(sparkle_3),
    TEXTURE(sparkle_4),
    TEXTURE(sparkle_5),
    TEXTURE(mario_face_shine),
};
const int gOracleTextureCount = sizeof(gOracleTextures) / sizeof(gOracleTextures[0]);

void oracle_screen_buffers(void **zbuf, void **cbuf0, void **cbuf1) {
    *zbuf = sScreenView->zbuf;
    *cbuf0 = sScreenView->colourBufs[0];
    *cbuf1 = sScreenView->colourBufs[1];
}

static void hash_colour(const char *name, const struct GdColour *colour) {
    sink_f32(name, colour->r);
    sink_f32(name, colour->g);
    sink_f32(name, colour->b);
}

void oracle_hash_statics_renderer(void) {
    int i;

    sink_s32("renderer.gGdFrameBufNum", gGdFrameBufNum);
    sink_s16("renderer.sAlpha", sAlpha);
    sink_s32("renderer.sNumLights", sNumLights);
    sink_s32("renderer.sLightId", sLightId);
    sink_s32("renderer.sMtxParamType", sMtxParamType);
    sink_u32("renderer.sGdDlCount", sGdDlCount);
    sink_f32("renderer.sTimeScaleFactor", sTimeScaleFactor);
    sink_s32("renderer.sUpdateYoshiScene", sUpdateYoshiScene);
    sink_s32("renderer.sUpdateMarioScene", sUpdateMarioScene);
    sink_s32("renderer.sUpdateCarScene", sUpdateCarScene);
    hash_colour("renderer.sAmbScaleColour", &sAmbScaleColour);
    for (i = 0; i < 2; i++) {
        hash_colour("renderer.sLightScaleColours", &sLightScaleColours[i]);
        sink_s32("renderer.sLightDirections.x", sLightDirections[i].x);
        sink_s32("renderer.sLightDirections.y", sLightDirections[i].y);
        sink_s32("renderer.sLightDirections.z", sLightDirections[i].z);
    }
    sink_u16("renderer.sGdContPads[0].button", sGdContPads[0].button);
    sink_u8("renderer.sGdContPads[0].stick_x", sGdContPads[0].stick_x);
    sink_u8("renderer.sGdContPads[0].stick_y", sGdContPads[0].stick_y);
    sink_u16("renderer.sPrevFrameCont[0].button", sPrevFrameCont[0].button);
    sink_u8("renderer.sPrevFrameCont[0].stick_x", sPrevFrameCont[0].stick_x);
    sink_u8("renderer.sPrevFrameCont[0].stick_y", sPrevFrameCont[0].stick_y);
}
