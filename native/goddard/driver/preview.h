// Software preview of a display list (sanity check that the oracle produces the head); see preview.c.
#ifndef GODDARD_ORACLE_PREVIEW_H
#define GODDARD_ORACLE_PREVIEW_H

#include <ultra64.h>

// Writes a PPM (640x480) of the shaded triangles of `dl` (no textures); returns 0 when the file cannot be written.
int preview_write(const Gfx *dl, const char *path);

#endif
