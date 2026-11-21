#!/bin/sh
# Writes preview/*.ppm (and .png when ffmpeg is on PATH): software renders of single frames (driver/preview.c).
cd "$(dirname "$0")" || exit 1
mkdir -p preview
render() { # <name> <id> <trace> <frame>
    build/goddard_oracle.exe "$2" "traces/$3.trace" /dev/null - 0 0 "$4" "preview/$1.ppm" > /dev/null || exit 1
    if command -v ffmpeg > /dev/null; then ffmpeg -y -loglevel error -i "preview/$1.ppm" "preview/$1.png" && rm "preview/$1.ppm"; fi
}
render idle_frame0 2 idle 0
render idle_frame590 2 idle 590
render grab_drag_frame170 2 grab_drag 170
render gameover_frame100 3 gameover 100
