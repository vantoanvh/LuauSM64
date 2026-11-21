// State that persists between frames and drives the animation, hashed in a fixed order independent of addresses:
// pointers to objects become the `index` of the object (-1 for NULL), function pointers and buffers are skipped.
#include <string.h>

#include <ultra64.h>

#include "oracle.h"
#include "scene_hash.h"
#include "sink.h"

// gd_main.h defines printf as a macro: keep it after every header that declares it.
#include "goddard/gd_main.h"
#include "goddard/gd_types.h"
#include "goddard/objects.h"

static s32 ref(const void *object) {
    return object == NULL ? -1 : ((const struct GdObj *) object)->index;
}

static void vec(const char *name, const struct GdVec3f *v) {
    sink_f32(name, v->x);
    sink_f32(name, v->y);
    sink_f32(name, v->z);
}

static void mat(const char *name, const Mat4f m) {
    int row;
    int column;

    for (row = 0; row < 4; row++) {
        for (column = 0; column < 4; column++) {
            sink_f32(name, m[row][column]);
        }
    }
}

static void colour(const char *name, const struct GdColour *c) {
    sink_f32(name, c->r);
    sink_f32(name, c->g);
    sink_f32(name, c->b);
}

static void bbox(const char *name, const struct GdBoundingBox *b) {
    sink_f32(name, b->minX);
    sink_f32(name, b->minY);
    sink_f32(name, b->minZ);
    sink_f32(name, b->maxX);
    sink_f32(name, b->maxY);
    sink_f32(name, b->maxZ);
}

// NUL terminated string including the NUL; at most `limit` bytes of a fixed buffer.
static void text(const char *name, const char *string, u32 limit) {
    u32 length = 0;

    while (length < limit && string[length] != '\0') {
        length++;
    }
    sink_bytes(name, string, length < limit ? length + 1 : length);
}

static void hash_group(const struct ObjGroup *g) {
    const struct ListNode *node;
    s32 count = 0;

    sink_s32("group.prev", ref(g->prev));
    sink_s32("group.next", ref(g->next));
    sink_s32("group.memberTypes", g->memberTypes);
    sink_s32("group.memberCount", g->memberCount);
    sink_s32("group.debugPrint", g->debugPrint);
    sink_s32("group.linkType", g->linkType);
    text("group.name", g->name, sizeof(g->name));
    sink_s32("group.id", g->id);
    for (node = g->firstMember; node != NULL; node = node->next) {
        count++;
    }
    sink_s32("group.nodes", count);
    // linkType 1: the nodes point to compressed data, not to objects (objects.c, apply_to_obj_types_in_group).
    if ((g->linkType & 1) == 0) {
        for (node = g->firstMember; node != NULL; node = node->next) {
            sink_s32("group.member", ref(node->obj));
        }
    }
}

static void hash_bone(const struct ObjBone *b) {
    vec("bone.worldPos", &b->worldPos);
    sink_s32("bone.prev", ref(b->prev));
    sink_s32("bone.next", ref(b->next));
    vec("bone.unk28", &b->unk28);
    vec("bone.unk40", &b->unk40);
    vec("bone.unk58", &b->unk58);
    vec("bone.unk64", &b->unk64);
    mat("bone.mat70", b->mat70);
    mat("bone.matB0", b->matB0);
    sink_s32("bone.shapePtr", ref(b->shapePtr));
    sink_f32("bone.unkF4", b->unkF4);
    sink_f32("bone.unkF8", b->unkF8);
    sink_f32("bone.unkFC", b->unkFC);
    sink_s32("bone.colourNum", b->colourNum);
    sink_s32("bone.unk104", b->unk104);
    sink_s32("bone.id", b->id);
    sink_s32("bone.unk10C", ref(b->unk10C));
    sink_f32("bone.spring", b->spring);
    sink_f32("bone.unk114", b->unk114);
    sink_f32("bone.unk118", b->unk118);
}

static void hash_joint(const struct ObjJoint *j) {
    vec("joint.worldPos", &j->worldPos);
    sink_s32("joint.shapePtr", ref(j->shapePtr));
    sink_s32("joint.prevjoint", ref(j->prevjoint));
    sink_s32("joint.nextjoint", ref(j->nextjoint));
    vec("joint.unk30", &j->unk30);
    vec("joint.unk3C", &j->unk3C);
    vec("joint.unk48", &j->unk48);
    vec("joint.initPos", &j->initPos);
    vec("joint.unk6C", &j->unk6C);
    vec("joint.velocity", &j->velocity);
    vec("joint.unk84", &j->unk84);
    vec("joint.unk90", &j->unk90);
    vec("joint.scale", &j->scale);
    vec("joint.unkA8", &j->unkA8);
    vec("joint.unkB4", &j->unkB4);
    vec("joint.shapeOffset", &j->shapeOffset);
    vec("joint.unkCC", &j->unkCC);
    vec("joint.friction", &j->friction);
    mat("joint.matE8", j->matE8);
    mat("joint.mat128", j->mat128);
    mat("joint.mat168", j->mat168);
    vec("joint.unk1A8", &j->unk1A8);
    sink_s32("joint.id", j->id);
    sink_s32("joint.flags", j->flags);
    sink_s32("joint.unk1C0", j->unk1C0);
    sink_s32("joint.unk1C4", ref(j->unk1C4));
    sink_s32("joint.colourNum", j->colourNum);
    sink_s32("joint.type", j->type);
    sink_s32("joint.rootAnimator", ref(j->rootAnimator));
    sink_s32("joint.weightGrp", ref(j->weightGrp));
    sink_s32("joint.attachedObjsGrp", ref(j->attachedObjsGrp));
    sink_s32("joint.attachFlags", j->attachFlags);
    vec("joint.attachOffset", &j->attachOffset);
    sink_s32("joint.attachedToObj", ref(j->attachedToObj));
    sink_f32("joint.unk228", j->unk228);
}

static void hash_particle(const struct ObjParticle *p) {
    sink_s32("particle.shapePtr", ref(p->shapePtr));
    vec("particle.pos", &p->pos);
    sink_f32("particle.unk30", p->unk30);
    vec("particle.unk38", &p->unk38);
    sink_f32("particle.unk44", p->unk44);
    sink_f32("particle.unk48", p->unk48);
    sink_s32("particle.id", p->id);
    sink_u32("particle.flags", p->flags);
    sink_s32("particle.colourNum", p->colourNum);
    sink_s32("particle.timeout", p->timeout);
    sink_s32("particle.unk60", p->unk60);
    sink_s32("particle.unk64", p->unk64);
    sink_s32("particle.subParticlesGrp", ref(p->subParticlesGrp));
    sink_s32("particle.unk74", p->unk74);
    sink_bytes("particle.unk78", p->unk78, sizeof(p->unk78));
    sink_s32("particle.unk7C", ref(p->unk7C));
    sink_s32("particle.unk80", ref(p->unk80));
    sink_s32("particle.unkB0", p->unkB0);
    sink_s32("particle.attachedObjsGrp", ref(p->attachedObjsGrp));
    sink_s32("particle.attachFlags", p->attachFlags);
    sink_s32("particle.attachedToObj", ref(p->attachedToObj));
}

static void hash_shape(const struct ObjShape *s) {
    sink_s32("shape.prevShape", ref(s->prevShape));
    sink_s32("shape.nextShape", ref(s->nextShape));
    sink_s32("shape.faceGroup", ref(s->faceGroup));
    sink_s32("shape.vtxGroup", ref(s->vtxGroup));
    sink_s32("shape.scaledVtxGroup", ref(s->scaledVtxGroup));
    sink_s32("shape.mtlGroup", ref(s->mtlGroup));
    sink_s32("shape.unk30", s->unk30);
    sink_s32("shape.faceCount", s->faceCount);
    sink_s32("shape.vtxCount", s->vtxCount);
    sink_s32("shape.unk3C", s->unk3C);
    sink_u32("shape.id", s->id);
    sink_s32("shape.flag", s->flag);
    sink_s32("shape.dlNums[0]", s->dlNums[0]);
    sink_s32("shape.dlNums[1]", s->dlNums[1]);
    sink_s32("shape.unk50", s->unk50);
    sink_f32("shape.alpha", s->alpha);
    text("shape.name", s->name, sizeof(s->name));
}

static void hash_net(const struct ObjNet *n) {
    vec("net.worldPos", &n->worldPos);
    vec("net.initPos", &n->initPos);
    sink_s32("net.flags", n->flags);
    sink_u32("net.id", n->id);
    sink_s32("net.unk3C", n->unk3C);
    sink_s32("net.colourNum", n->colourNum);
    vec("net.unusedForce", &n->unusedForce);
    vec("net.velocity", &n->velocity);
    vec("net.rotation", &n->rotation);
    vec("net.unk68", &n->unk68);
    vec("net.collDisp", &n->collDisp);
    vec("net.collTorque", &n->collTorque);
    vec("net.unusedCollTorqueL", &n->unusedCollTorqueL);
    vec("net.unusedCollTorqueD", &n->unusedCollTorqueD);
    vec("net.torque", &n->torque);
    vec("net.centerOfGravity", &n->centerOfGravity);
    bbox("net.boundingBox", &n->boundingBox);
    vec("net.unusedCollDispOff", &n->unusedCollDispOff);
    sink_f32("net.unusedCollMaxD", n->unusedCollMaxD);
    sink_f32("net.maxRadius", n->maxRadius);
    mat("net.matE8", n->matE8);
    mat("net.mat128", n->mat128);
    mat("net.mat168", n->mat168);
    sink_s32("net.shapePtr", ref(n->shapePtr));
    vec("net.scale", &n->scale);
    sink_f32("net.unusedMass", n->unusedMass);
    sink_s32("net.numModes", n->numModes);
    sink_s32("net.unk1C0", ref(n->unk1C0));
    sink_s32("net.skinGrp", ref(n->skinGrp));
    sink_s32("net.unk1C8", ref(n->unk1C8));
    sink_s32("net.unk1CC", ref(n->unk1CC));
    sink_s32("net.unk1D0", ref(n->unk1D0));
    sink_s32("net.attachedObjsGrp", ref(n->attachedObjsGrp));
    vec("net.attachOffset", &n->attachOffset);
    sink_s32("net.attachFlags", n->attachFlags);
    sink_s32("net.attachedToObj", ref(n->attachedToObj));
    sink_s32("net.netType", n->netType);
    sink_s32("net.unk1F0", ref(n->unk1F0));
    vec("net.unk1F4", &n->unk1F4);
    vec("net.unk200", &n->unk200);
    sink_s32("net.unk20C", ref(n->unk20C));
    sink_s32("net.ctrlType", n->ctrlType);
    sink_s32("net.unk21C", ref(n->unk21C));
}

static void hash_plane(const struct ObjPlane *p) {
    sink_u32("plane.id", p->id);
    sink_s32("plane.unk18", p->unk18);
    sink_f32("plane.unk1C", p->unk1C);
    sink_s32("plane.unk20", p->unk20);
    sink_s32("plane.unk24", p->unk24);
    bbox("plane.boundingBox", &p->boundingBox);
    sink_s32("plane.unk40", ref(p->unk40));
}

static void hash_vertex(const struct ObjVertex *v) {
    vec("vertex.initPos", &v->initPos);
    vec("vertex.pos", &v->pos);
    vec("vertex.normal", &v->normal);
    sink_s16("vertex.id", v->id);
    sink_f32("vertex.scaleFactor", v->scaleFactor);
    sink_f32("vertex.alpha", v->alpha);
}

static void hash_face(const struct ObjFace *f) {
    int i;

    colour("face.colour", &f->colour);
    sink_s32("face.colourNum", f->colourNum);
    vec("face.normal", &f->normal);
    sink_s32("face.vtxCount", f->vtxCount);
    for (i = 0; i < 4; i++) {
        sink_s32("face.vertices", ref(f->vertices[i]));
    }
    sink_s32("face.mtlId", f->mtlId);
    sink_s32("face.mtl", ref(f->mtl));
}

static void hash_camera(const struct ObjCamera *c) {
    int i;

    vec("camera.worldPos", &c->worldPos);
    sink_s32("camera.prev", ref(c->prev));
    sink_s32("camera.next", ref(c->next));
    sink_s32("camera.id", c->id);
    sink_s32("camera.flags", c->flags);
    sink_s32("camera.unk30", ref(c->unk30));
    vec("camera.lookAt", &c->lookAt);
    vec("camera.unk40", &c->unk40);
    vec("camera.unk4C", &c->unk4C);
    sink_f32("camera.unk58", c->unk58);
    sink_f32("camera.unk60", c->unk60);
    mat("camera.unk64", c->unk64);
    sink_f32("camera.unkA4", c->unkA4);
    mat("camera.unkA8", c->unkA8);
    mat("camera.unkE8", c->unkE8);
    vec("camera.unk128", &c->unk128);
    vec("camera.unk134", &c->unk134);
    for (i = 0; i < 4; i++) {
        vec("camera.zoomPositions", &c->zoomPositions[i]);
    }
    sink_s32("camera.maxZoomLevel", c->maxZoomLevel);
    sink_s32("camera.zoomLevel", c->zoomLevel);
    sink_f32("camera.unk178", c->unk178);
    sink_f32("camera.unk17C", c->unk17C);
    vec("camera.unk180", &c->unk180);
    sink_s32("camera.unk18C", ref(c->unk18C));
}

static void hash_material(const struct ObjMaterial *m) {
    sink_s32("material.id", m->id);
    text("material.name", m->name, sizeof(m->name));
    sink_s32("material.type", m->type);
    colour("material.Ka", &m->Ka);
    colour("material.Kd", &m->Kd);
    sink_s32("material.gddlNumber", m->gddlNumber);
}

static void hash_weight(const struct ObjWeight *w) {
    sink_s32("weight.vtxId", w->vtxId);
    vec("weight.vec20", &w->vec20);
    sink_f32("weight.weightVal", w->weightVal);
    sink_s32("weight.vtx", ref(w->vtx));
}

static void hash_gadget(const struct ObjGadget *g) {
    vec("gadget.worldPos", &g->worldPos);
    sink_s32("gadget.unk20", g->unk20);
    sink_s32("gadget.type", g->type);
    sink_f32("gadget.sliderPos", g->sliderPos);
    sink_u32("gadget.varval.low", (u32) g->varval.l);
    sink_u32("gadget.varval.high", (u32) (g->varval.l >> 32));
    sink_f32("gadget.rangeMin", g->rangeMin);
    sink_f32("gadget.rangeMax", g->rangeMax);
    vec("gadget.size", &g->size);
    sink_s32("gadget.valueGrp", ref(g->valueGrp));
    sink_s32("gadget.shapePtr", ref(g->shapePtr));
    sink_s32("gadget.unk54", ref(g->unk54));
    sink_s32("gadget.colourNum", g->colourNum);
}

static void hash_view(const struct ObjView *v) {
    sink_s32("view.unk1C", v->unk1C);
    sink_s32("view.id", v->id);
    sink_s32("view.activeCam", ref(v->activeCam));
    sink_s32("view.components", ref(v->components));
    sink_s32("view.lights", ref(v->lights));
    sink_s32("view.pickedObj", ref(v->pickedObj));
    sink_s32("view.flags", v->flags);
    sink_s32("view.projectionType", v->projectionType);
    vec("view.upperLeft", &v->upperLeft);
    sink_f32("view.unk48", v->unk48);
    sink_f32("view.unk4C", v->unk4C);
    vec("view.lowerRight", &v->lowerRight);
    vec("view.clipping", &v->clipping);
    if (v->namePtr != NULL) {
        text("view.name", v->namePtr, 64);
    } else {
        sink_u8("view.name", 0);
    }
    sink_s32("view.gdDlNum", v->gdDlNum);
    sink_s32("view.unk74", v->unk74);
    sink_s32("view.unk78", v->unk78);
    colour("view.colour", &v->colour);
    sink_s32("view.parent", ref(v->parent));
    sink_s32("view.unk9C", v->unk9C);
}

static void hash_label(const struct ObjLabel *l) {
    vec("label.position", &l->position);
    sink_s32("label.unk24", l->unk24);
    sink_s32("label.valptr", ref(l->valptr));
    sink_s32("label.unk30", l->unk30);
}

static void hash_animator(const struct ObjAnimator *a) {
    sink_s32("animator.animatedPartsGrp", ref(a->animatedPartsGrp));
    sink_s32("animator.animdataGrp", ref(a->animdataGrp));
    sink_s32("animator.animSeqNum", a->animSeqNum);
    sink_f32("animator.unk24", a->unk24);
    sink_f32("animator.frame", a->frame);
    sink_s32("animator.attachedObjsGrp", ref(a->attachedObjsGrp));
    sink_s32("animator.attachFlags", a->attachFlags);
    sink_s32("animator.attachedToObj", ref(a->attachedToObj));
    sink_s32("animator.state", a->state);
    sink_s32("animator.nods", a->nods);
    sink_s32("animator.stillTimer", a->stillTimer);
}

static void hash_valptr(const struct ObjValPtr *v) {
    sink_s32("valptr.obj", ref(v->obj));
    sink_s32("valptr.datatype", v->datatype);
    sink_s32("valptr.flag", v->flag);
}

static void hash_light(const struct ObjLight *l) {
    sink_s32("light.id", l->id);
    text("light.name", l->name, sizeof(l->name));
    sink_s32("light.flags", l->flags);
    sink_f32("light.unk30", l->unk30);
    sink_f32("light.unk38", l->unk38);
    sink_s32("light.unk3C", l->unk3C);
    sink_s32("light.unk40", l->unk40);
    sink_s32("light.unk4C", l->unk4C);
    colour("light.diffuse", &l->diffuse);
    colour("light.colour", &l->colour);
    vec("light.unk68", &l->unk68);
    vec("light.position", &l->position);
    vec("light.unk80", &l->unk80);
    vec("light.unk8C", &l->unk8C);
    sink_s32("light.unk98", l->unk98);
    sink_s32("light.unk9C", ref(l->unk9C));
}

static void hash_zone(const struct ObjZone *z) {
    bbox("zone.boundingBox", &z->boundingBox);
    sink_s32("zone.unk2C", ref(z->unk2C));
    sink_s32("zone.unk30", ref(z->unk30));
}

static void hash_unk200000(const struct ObjUnk200000 *u) {
    sink_s32("unk200000.unk30", ref(u->unk30));
    sink_s32("unk200000.unk34", ref(u->unk34));
}

static void hash_object(const struct GdObj *o) {
    sink_s32("object.type", o->type);
    sink_s16("object.index", o->index);
    sink_u16("object.drawFlags", o->drawFlags);
    switch (o->type) {
        case OBJ_TYPE_GROUPS: hash_group((const struct ObjGroup *) o); break;
        case OBJ_TYPE_BONES: hash_bone((const struct ObjBone *) o); break;
        case OBJ_TYPE_JOINTS: hash_joint((const struct ObjJoint *) o); break;
        case OBJ_TYPE_PARTICLES: hash_particle((const struct ObjParticle *) o); break;
        case OBJ_TYPE_SHAPES: hash_shape((const struct ObjShape *) o); break;
        case OBJ_TYPE_NETS: hash_net((const struct ObjNet *) o); break;
        case OBJ_TYPE_PLANES: hash_plane((const struct ObjPlane *) o); break;
        case OBJ_TYPE_FACES: hash_face((const struct ObjFace *) o); break;
        case OBJ_TYPE_VERTICES: hash_vertex((const struct ObjVertex *) o); break;
        case OBJ_TYPE_CAMERAS: hash_camera((const struct ObjCamera *) o); break;
        case OBJ_TYPE_MATERIALS: hash_material((const struct ObjMaterial *) o); break;
        case OBJ_TYPE_WEIGHTS: hash_weight((const struct ObjWeight *) o); break;
        case OBJ_TYPE_GADGETS: hash_gadget((const struct ObjGadget *) o); break;
        case OBJ_TYPE_VIEWS: hash_view((const struct ObjView *) o); break;
        case OBJ_TYPE_LABELS: hash_label((const struct ObjLabel *) o); break;
        case OBJ_TYPE_ANIMATORS: hash_animator((const struct ObjAnimator *) o); break;
        case OBJ_TYPE_VALPTRS: hash_valptr((const struct ObjValPtr *) o); break;
        case OBJ_TYPE_LIGHTS: hash_light((const struct ObjLight *) o); break;
        case OBJ_TYPE_ZONES: hash_zone((const struct ObjZone *) o); break;
        case OBJ_TYPE_UNK200000: hash_unk200000((const struct ObjUnk200000 *) o); break;
        default: break;
    }
}

static void hash_control(const char *name, const struct GdControl *c) {
    sink_s32(name, c->unk00);
    sink_s32(name, c->dleft);
    sink_s32(name, c->dright);
    sink_s32(name, c->dup);
    sink_s32(name, c->ddown);
    sink_s32(name, c->cleft);
    sink_s32(name, c->cright);
    sink_s32(name, c->cup);
    sink_s32(name, c->cdown);
    sink_s32(name, c->btnA);
    sink_s32(name, c->btnB);
    sink_s32(name, c->trgL);
    sink_s32(name, c->trgR);
    sink_s32(name, c->unk4C);
    sink_s32(name, c->unk50);
    sink_s32(name, c->newStartPress);
    sink_f32(name, c->stickXf);
    sink_f32(name, c->stickYf);
    sink_f32(name, c->unk88);
    sink_f32(name, c->unkA0);
    sink_f32(name, c->unkAC);
    sink_s32(name, c->dragStartX);
    sink_s32(name, c->dragStartY);
    sink_s32(name, c->stickDeltaX);
    sink_s32(name, c->stickDeltaY);
    sink_s32(name, c->stickX);
    sink_s32(name, c->stickY);
    sink_s32(name, c->csrX);
    sink_s32(name, c->csrY);
    sink_u8(name, c->dragging);
    sink_u8(name, c->unkD8b40);
    sink_u8(name, c->unkD8b20);
    sink_u8(name, c->startedDragging);
    sink_u8(name, c->unkD8b08);
    sink_u8(name, c->unkD8b04);
    sink_u8(name, c->AbtnPressWait);
    sink_u32(name, c->dragStartFrame);
    sink_u32(name, c->currFrame);
}

void scene_hash(void) {
    const struct GdObj *object;
    s32 count = 0;

    sink_line("scene");
    sink_s32("gGdObjCount", gGdObjCount);
    sink_s32("gGdGroupCount", gGdGroupCount);
    sink_s32("gGdPlaneCount", gGdPlaneCount);
    sink_s32("gGdCameraCount", gGdCameraCount);
    sink_s32("gGdMoveScene", gGdMoveScene);
    sink_s32("gGdUseVtxNormal", gGdUseVtxNormal);
    sink_f32("D_801A8058", D_801A8058);
    hash_control("gGdCtrl", &gGdCtrl);
    hash_control("gGdCtrlPrev", &gGdCtrlPrev);
    oracle_hash_statics_renderer();
    oracle_hash_statics_debug_utils();
    oracle_hash_statics_sfx();
    for (object = gGdObjectList; object != NULL; object = object->next) {
        count++;
    }
    sink_s32("objects", count);
    for (object = gGdObjectList; object != NULL; object = object->next) {
        hash_object(object);
    }
}
