#!/bin/sh
# Builds the native check drivers (build/verify/*.exe) with the flags of native/Makefile.
# Needs the native build (native/build.sh) to have produced build/us for the generated headers and guMtxF2L.o.
export PATH="/c/Program Files/LLVM/bin:/c/Tools/WinLibs/mingw64/bin:$PATH"
cd "$(dirname "$0")/.." || exit 1

REF=../reference
OUT=build/us
CFLAGS="-std=gnu90 -O1 -g -fsigned-char -fno-strict-aliasing -fwrapv -ffp-contract=off -fcommon -w \
  -DVERSION_US=1 -DF3D_OLD=1 -DNON_MATCHING=1 -DAVOID_UB=1 -D_FINALROM=1 -D_LANGUAGE_C -DNO_SEGMENTED_MEMORY \
  -I$REF/include -I$OUT -I$OUT/include -I$REF/src -I$REF -Istub -I."

mkdir -p build/verify
gcc $CFLAGS -o build/verify/math_driver.exe verify/math_driver.c $OUT/obj/lib/src/guMtxF2L.o -lm || exit 1
gcc $CFLAGS -o build/verify/surface_driver.exe verify/surface_driver.c -lm || exit 1

# load_driver includes macro_special_objects.c, whose preset tables name every behavior: link stub symbols for the undefined ones
gcc $CFLAGS -c -o build/verify/load_driver.o verify/load_driver.c || exit 1
nm -u build/verify/load_driver.o | sed -n 's/^ *U \(bhv[A-Za-z0-9_]*\)$/const unsigned char \1[8] = { 0 };/p' > build/verify/bhv_stubs.c
gcc $CFLAGS -o build/verify/load_driver.exe build/verify/load_driver.o build/verify/bhv_stubs.c -lm || exit 1
