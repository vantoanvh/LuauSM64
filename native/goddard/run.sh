#!/bin/sh
# Runs the oracle on every trace of traces/manifest.txt: traces/<name>.goddard.hash (one hash per frame).
# Usage: run.sh [<exe>]   (default build/goddard_oracle.exe)
cd "$(dirname "$0")" || exit 1
exe="${1:-build/goddard_oracle.exe}"
grep -v '^#' traces/manifest.txt | while read -r name id; do
    [ -n "$name" ] || continue
    "$exe" "$id" "traces/$name.trace" "traces/$name.goddard.hash" > /dev/null || exit 1
    echo "$name: $(wc -l < "traces/$name.goddard.hash") frames"
done
