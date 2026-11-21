#include <stdio.h>
#include <stdlib.h>

#include "trace.h"

struct TraceFrame *trace_read(const char *path, int *count) {
    FILE *file = fopen(path, "r");
    char text[256];
    int line = 0;
    int capacity = 1024;
    struct TraceFrame *frames = malloc(capacity * sizeof(*frames));

    if (file == NULL) {
        fprintf(stderr, "cannot open trace %s\n", path);
        exit(1);
    }
    *count = 0;
    while (fgets(text, sizeof(text), file) != NULL) {
        unsigned buttons;
        int stickX;
        int stickY;

        line++;
        if (text[0] == '#' || text[0] == '\n' || text[0] == '\r') {
            continue;
        }
        if (sscanf(text, "%i %d %d", &buttons, &stickX, &stickY) != 3) {
            fprintf(stderr, "bad trace line %d: %s", line, text);
            exit(1);
        }
        if (*count == capacity) {
            capacity *= 2;
            frames = realloc(frames, capacity * sizeof(*frames));
        }
        frames[*count].buttons = (u16) buttons;
        frames[*count].stickX = (s8) stickX;
        frames[*count].stickY = (s8) stickY;
        (*count)++;
    }
    fclose(file);
    return frames;
}
