#!/bin/sh
# Builds native/build/us/sm64_native.exe. Needs reference/ with extracted assets (python extract_assets.py us).
export PATH="/c/Program Files/LLVM/bin:/c/Tools/WinLibs/mingw64/bin:$PATH"
cd "$(dirname "$0")" || exit 1
exec mingw32-make -j"${JOBS:-8}" "$@"
