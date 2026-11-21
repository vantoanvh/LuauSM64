// sinf and cosf as the correctly rounded double precision result rounded to f32 (Makefile: -Dsinf=oracle_sinf
// -Dcosf=oracle_cosf for the goddard and gu sources). The oracle then does not depend on the single precision
// algorithm of the C library, and a port computing math.sin / math.cos in double precision and rounding to f32 matches.
#include <math.h>

float oracle_sinf(float x) {
    return (float) sin((double) x);
}

float oracle_cosf(float x) {
    return (float) cos((double) x);
}
