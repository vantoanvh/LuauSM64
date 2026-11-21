// Per-frame state hash. The field order and encoding here is the specification in docs/state-hash.md.
#include <stdio.h>
#include <string.h>

#include <ultra64.h>

#include "sm64.h"
#include "game/area.h"
#include "game/camera.h"
#include "game/game_init.h"
#include "game/level_update.h"
#include "game/object_list_processor.h"

#include "behavior_offset.h"
#include "state_hash.h"

#define FNV_OFFSET_BASIS 0xcbf29ce484222325ULL
#define FNV_PRIME 0x100000001b3ULL

extern u16 gRandomSeed16;

static u64 sHash;
static FILE *sDump;

static void hash_byte(u8 value) {
    sHash ^= value;
    sHash *= FNV_PRIME;
}

static void hash_bytes_le(u32 value, int count) {
    int i;

    for (i = 0; i < count; i++) {
        hash_byte((u8) (value >> (8 * i)));
    }
}

static void field_s(const char *name, s32 value, int bytes) {
    hash_bytes_le((u32) value, bytes);
    if (sDump != NULL) {
        fprintf(sDump, "%s=%d\n", name, value);
    }
}

static void field_u(const char *name, u32 value, int bytes) {
    hash_bytes_le(value, bytes);
    if (sDump != NULL) {
        fprintf(sDump, "%s=%u\n", name, value);
    }
}

static void field_f32(const char *name, f32 value) {
    u32 bits;

    memcpy(&bits, &value, sizeof(bits));
    hash_bytes_le(bits, 4);
    if (sDump != NULL) {
        fprintf(sDump, "%s=0x%08x (%.9g)\n", name, bits, (double) value);
    }
}

#define S8(name, value) field_s(name, (s8) (value), 1)
#define S16(name, value) field_s(name, (s16) (value), 2)
#define S32(name, value) field_s(name, (s32) (value), 4)
#define U8(name, value) field_u(name, (u8) (value), 1)
#define U16(name, value) field_u(name, (u16) (value), 2)
#define U32(name, value) field_u(name, (u32) (value), 4)
#define F32(name, value) field_f32(name, (value))

static void field_vec3f(const char *name, const f32 *value) {
    char label[64];
    int i;

    for (i = 0; i < 3; i++) {
        snprintf(label, sizeof(label), "%s[%d]", name, i);
        field_f32(label, value[i]);
    }
}

static void field_vec3s(const char *name, const s16 *value) {
    char label[64];
    int i;

    for (i = 0; i < 3; i++) {
        snprintf(label, sizeof(label), "%s[%d]", name, i);
        field_s(label, value[i], 2);
    }
}

// Object identity: index in gObjectPool, -1 for none, -2 for an object outside the pool.
static s32 object_slot(const struct Object *obj) {
    if (obj == NULL) {
        return -1;
    }
    if (obj < gObjectPool || obj >= gObjectPool + OBJECT_POOL_CAPACITY) {
        return -2;
    }
    return (s32) (obj - gObjectPool);
}

static void hash_surface(const char *name, const struct Surface *surface) {
    char label[64];

    snprintf(label, sizeof(label), "%s.present", name);
    U8(label, surface != NULL);
    if (surface == NULL) {
        return;
    }
    snprintf(label, sizeof(label), "%s.type", name);
    S16(label, surface->type);
    snprintf(label, sizeof(label), "%s.force", name);
    S16(label, surface->force);
    snprintf(label, sizeof(label), "%s.flags", name);
    S8(label, surface->flags);
    snprintf(label, sizeof(label), "%s.room", name);
    S8(label, surface->room);
    snprintf(label, sizeof(label), "%s.lowerY", name);
    S16(label, surface->lowerY);
    snprintf(label, sizeof(label), "%s.upperY", name);
    S16(label, surface->upperY);
    snprintf(label, sizeof(label), "%s.vertex1", name);
    field_vec3s(label, surface->vertex1);
    snprintf(label, sizeof(label), "%s.vertex2", name);
    field_vec3s(label, surface->vertex2);
    snprintf(label, sizeof(label), "%s.vertex3", name);
    field_vec3s(label, surface->vertex3);
    snprintf(label, sizeof(label), "%s.normalX", name);
    F32(label, surface->normal.x);
    snprintf(label, sizeof(label), "%s.normalY", name);
    F32(label, surface->normal.y);
    snprintf(label, sizeof(label), "%s.normalZ", name);
    F32(label, surface->normal.z);
    snprintf(label, sizeof(label), "%s.originOffset", name);
    F32(label, surface->originOffset);
    snprintf(label, sizeof(label), "%s.object", name);
    S32(label, object_slot(surface->object));
}

static void hash_frame_globals(void) {
    U32("frame.globalTimer", gGlobalTimer);
    S16("frame.levelNum", gCurrLevelNum);
    S16("frame.courseNum", gCurrCourseNum);
    S16("frame.actNum", gCurrActNum);
    S16("frame.areaIndex", gCurrAreaIndex);
    U16("frame.randomSeed", gRandomSeed16);
}

static void hash_mario(void) {
    const struct MarioState *m = &gMarioStates[0];

    U16("mario.input", m->input);
    U32("mario.flags", m->flags);
    U32("mario.particleFlags", m->particleFlags);
    U32("mario.action", m->action);
    U32("mario.prevAction", m->prevAction);
    U16("mario.actionState", m->actionState);
    U16("mario.actionTimer", m->actionTimer);
    U32("mario.actionArg", m->actionArg);
    F32("mario.intendedMag", m->intendedMag);
    S16("mario.intendedYaw", m->intendedYaw);
    S16("mario.invincTimer", m->invincTimer);
    U8("mario.framesSinceA", m->framesSinceA);
    U8("mario.framesSinceB", m->framesSinceB);
    U8("mario.wallKickTimer", m->wallKickTimer);
    U8("mario.doubleJumpTimer", m->doubleJumpTimer);
    field_vec3s("mario.faceAngle", m->faceAngle);
    field_vec3s("mario.angleVel", m->angleVel);
    S16("mario.slideYaw", m->slideYaw);
    S16("mario.twirlYaw", m->twirlYaw);
    field_vec3f("mario.pos", m->pos);
    field_vec3f("mario.vel", m->vel);
    F32("mario.forwardVel", m->forwardVel);
    F32("mario.slideVelX", m->slideVelX);
    F32("mario.slideVelZ", m->slideVelZ);
    hash_surface("mario.wall", m->wall);
    hash_surface("mario.ceil", m->ceil);
    hash_surface("mario.floor", m->floor);
    F32("mario.ceilHeight", m->ceilHeight);
    F32("mario.floorHeight", m->floorHeight);
    S16("mario.floorAngle", m->floorAngle);
    S16("mario.waterLevel", m->waterLevel);
    S32("mario.interactObj", object_slot(m->interactObj));
    S32("mario.heldObj", object_slot(m->heldObj));
    S32("mario.usedObj", object_slot(m->usedObj));
    S32("mario.riddenObj", object_slot(m->riddenObj));
    S32("mario.marioObj", object_slot(m->marioObj));
    S16("mario.numCoins", m->numCoins);
    S16("mario.numStars", m->numStars);
    S8("mario.numKeys", m->numKeys);
    S8("mario.numLives", m->numLives);
    S16("mario.health", m->health);
    U8("mario.hurtCounter", m->hurtCounter);
    U8("mario.healCounter", m->healCounter);
    U8("mario.squishTimer", m->squishTimer);
    U16("mario.capTimer", m->capTimer);
    F32("mario.peakHeight", m->peakHeight);
    F32("mario.quicksandDepth", m->quicksandDepth);
    F32("mario.gettingBlownGravity", m->gettingBlownGravity);
}

static void hash_object(s32 slot, const struct Object *o) {
    U16("object.slot", slot);
    S16("object.activeFlags", o->activeFlags);
    U32("object.behavior", behavior_offset(o->behavior));
    F32("object.posX", o->oPosX);
    F32("object.posY", o->oPosY);
    F32("object.posZ", o->oPosZ);
    F32("object.velX", o->oVelX);
    F32("object.velY", o->oVelY);
    F32("object.velZ", o->oVelZ);
    F32("object.forwardVel", o->oForwardVel);
    S32("object.moveAnglePitch", o->oMoveAnglePitch);
    S32("object.moveAngleYaw", o->oMoveAngleYaw);
    S32("object.moveAngleRoll", o->oMoveAngleRoll);
    S32("object.faceAnglePitch", o->oFaceAnglePitch);
    S32("object.faceAngleYaw", o->oFaceAngleYaw);
    S32("object.faceAngleRoll", o->oFaceAngleRoll);
    S32("object.action", o->oAction);
    S32("object.subAction", o->oSubAction);
    S32("object.timer", o->oTimer);
    S32("object.bhvParams", o->oBhvParams);
    S16("object.animID", o->header.gfx.animInfo.animID);
    S16("object.animFrame", o->header.gfx.animInfo.animFrame);
}

static void hash_objects(void) {
    s32 slot;
    s32 count = 0;

    for (slot = 0; slot < OBJECT_POOL_CAPACITY; slot++) {
        const struct Object *o = &gObjectPool[slot];

        if (o->activeFlags != ACTIVE_FLAG_DEACTIVATED) {
            hash_object(slot, o);
            count++;
        }
    }
    S32("objects.count", count);
}

static void hash_camera(void) {
    field_vec3f("camera.pos", gLakituState.pos);
    field_vec3f("camera.focus", gLakituState.focus);
    field_vec3f("camera.curPos", gLakituState.curPos);
    field_vec3f("camera.curFocus", gLakituState.curFocus);
    U8("camera.mode", gLakituState.mode);
    U8("camera.defMode", gLakituState.defMode);
    S16("camera.roll", gLakituState.roll);
    S16("camera.yaw", gLakituState.yaw);
    S16("camera.nextYaw", gLakituState.nextYaw);
}

u64 state_hash_frame(FILE *dump) {
    sHash = FNV_OFFSET_BASIS;
    sDump = dump;

    hash_frame_globals();
    hash_mario();
    hash_objects();
    hash_camera();

    return sHash;
}
