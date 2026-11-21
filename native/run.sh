#!/bin/sh
# Runs the native reference on a trace: run.sh <trace> <hash-out> [<dump-out>]
cd "$(dirname "$0")" || exit 1
exec ./build/us/sm64_native.exe "$@"
