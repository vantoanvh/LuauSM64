#!/bin/sh
# Determinism check: runs every trace twice (plus the -O0 gcov build when present) into scratch files and compares the
# hash files with each other and with the committed traces/*.goddard.hash. Prints "check passed" on success.
cd "$(dirname "$0")" || exit 1
scratch="$(mktemp -d)"
status=0
grep -v '^#' traces/manifest.txt | while read -r name id; do
    [ -n "$name" ] || continue
    build/goddard_oracle.exe "$id" "traces/$name.trace" "$scratch/$name.1" > /dev/null || exit 1
    build/goddard_oracle.exe "$id" "traces/$name.trace" "$scratch/$name.2" > /dev/null || exit 1
    cmp -s "$scratch/$name.1" "$scratch/$name.2" || { echo "$name: two runs differ"; exit 1; }
    cmp -s "$scratch/$name.1" "traces/$name.goddard.hash" || { echo "$name: differs from traces/$name.goddard.hash"; exit 1; }
    if [ -x build/cov/goddard_oracle.exe ]; then
        build/cov/goddard_oracle.exe "$id" "traces/$name.trace" "$scratch/$name.cov" > /dev/null || exit 1
        cmp -s "$scratch/$name.1" "$scratch/$name.cov" || { echo "$name: -O0 gcov build differs"; exit 1; }
    fi
    echo "$name: identical"
done || status=1
rm -rf "$scratch"
[ "$status" -eq 0 ] && echo "check passed"
exit "$status"
