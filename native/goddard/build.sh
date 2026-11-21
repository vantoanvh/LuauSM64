#!/bin/sh
# Builds native/goddard/build/goddard_oracle.exe. Needs native/build/us (generated textures; see ../Makefile `generated`).
export PATH="/c/Program Files/LLVM/bin:/c/Tools/WinLibs/mingw64/bin:$PATH"
cd "$(dirname "$0")" || exit 1
[ -d ../build/us/textures/intro_raw ] || { echo "missing native/build/us (run ../build.sh generated)" >&2; exit 1; }
exec mingw32-make -j"${JOBS:-8}" "$@"
