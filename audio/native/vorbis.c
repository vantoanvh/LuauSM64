// Ogg Vorbis encoder for the browser, built to WebAssembly with Emscripten's libogg and libvorbis ports (audio/build.mjs).
// The caller (rom-tool/sound/vorbis.js) copies the PCM into the buffer of vorbis_input, calls vorbis_encode and reads the file
// from vorbis_output.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <ogg/ogg.h>
#include <vorbis/vorbisenc.h>

// Frames fed to the analysis at a time
#define CHUNK_FRAMES 1024

static int16_t *sInput;
static unsigned char *sOutput;
static size_t sOutputSize;
static size_t sOutputCapacity;

// A buffer for `frames` frames of `channels` interleaved s16 samples, to be filled by the caller
int16_t *vorbis_input(int frames, int channels) {
    free(sInput);
    sInput = malloc((size_t) frames * channels * sizeof(int16_t));

    return sInput;
}

static void append(const unsigned char *data, size_t size) {
    if (sOutputSize + size > sOutputCapacity) {
        sOutputCapacity = (sOutputSize + size) * 2;
        sOutput = realloc(sOutput, sOutputCapacity);
    }

    memcpy(sOutput + sOutputSize, data, size);
    sOutputSize += size;
}

static void append_page(const ogg_page *page) {
    append(page->header, (size_t) page->header_len);
    append(page->body, (size_t) page->body_len);
}

// The pages the stream has ready (all of them with flush set)
static void write_pages(ogg_stream_state *stream, int flush) {
    ogg_page page;

    while ((flush ? ogg_stream_flush(stream, &page) : ogg_stream_pageout(stream, &page)) > 0) {
        append_page(&page);
    }
}

// The packets the analysis has ready
static void write_packets(ogg_stream_state *stream, vorbis_dsp_state *dsp, vorbis_block *block) {
    ogg_packet packet;

    while (vorbis_analysis_blockout(dsp, block) == 1) {
        vorbis_analysis(block, NULL);
        vorbis_bitrate_addblock(block);

        while (vorbis_bitrate_flushpacket(dsp, &packet)) {
            ogg_stream_packetin(stream, &packet);
            write_pages(stream, 0);
        }
    }
}

// Encodes the frames in the input buffer at a quality from 0 to 1 (the -q:a of ffmpeg's libvorbis divided by 10); returns the size of the
// file, or 0 when the encoder cannot start
size_t vorbis_encode(int frames, int channels, int rate, float quality) {
    vorbis_info info;
    vorbis_comment comment;
    vorbis_dsp_state dsp;
    vorbis_block block;
    ogg_stream_state stream;
    ogg_packet header, headerComment, headerCode;
    int done = 0;

    sOutputSize = 0;
    vorbis_info_init(&info);

    if (vorbis_encode_init_vbr(&info, channels, rate, quality) != 0) {
        vorbis_info_clear(&info);

        return 0;
    }

    vorbis_comment_init(&comment);
    vorbis_analysis_init(&dsp, &info);
    vorbis_block_init(&dsp, &block);
    ogg_stream_init(&stream, 1);
    vorbis_analysis_headerout(&dsp, &comment, &header, &headerComment, &headerCode);
    ogg_stream_packetin(&stream, &header);
    ogg_stream_packetin(&stream, &headerComment);
    ogg_stream_packetin(&stream, &headerCode);
    write_pages(&stream, 1);

    while (done < frames) {
        int count = frames - done < CHUNK_FRAMES ? frames - done : CHUNK_FRAMES;
        float **buffer = vorbis_analysis_buffer(&dsp, count);
        int i, c;

        for (i = 0; i < count; i++) {
            for (c = 0; c < channels; c++) {
                buffer[c][i] = sInput[(size_t) (done + i) * channels + c] / 32768.0f;
            }
        }

        vorbis_analysis_wrote(&dsp, count);
        write_packets(&stream, &dsp, &block);
        done += count;
    }

    vorbis_analysis_wrote(&dsp, 0);
    write_packets(&stream, &dsp, &block);
    write_pages(&stream, 1);

    ogg_stream_clear(&stream);
    vorbis_block_clear(&block);
    vorbis_dsp_clear(&dsp);
    vorbis_comment_clear(&comment);
    vorbis_info_clear(&info);

    return sOutputSize;
}

// The file vorbis_encode made
unsigned char *vorbis_output(void) {
    return sOutput;
}
