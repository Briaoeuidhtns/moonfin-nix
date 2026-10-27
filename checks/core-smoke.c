#include "libretro_host.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

/* Original NROM program: set the universal background palette to blue, then
 * loop. No commercial ROM, BIOS, copyrighted game assets, or network needed. */
static int write_rom(const char *path) {
    uint8_t rom[16 + 16384 + 8192] = {0};
    memcpy(rom, "NES\x1a", 4);
    rom[4] = 1;
    rom[5] = 1;
    const uint8_t program[] = {
        0x78,                         /* SEI */
        0xd8,                         /* CLD */
        0xa2, 0xff, 0x9a,             /* LDX #$ff; TXS */
        0xa9, 0x00,
        0x8d, 0x00, 0x20,             /* disable PPU control */
        0x8d, 0x01, 0x20,             /* disable rendering */
        0x2c, 0x02, 0x20, 0x10, 0xfb, /* wait for vertical blank */
        0xa9, 0x3f, 0x8d, 0x06, 0x20, /* palette address $3f00 */
        0xa9, 0x00, 0x8d, 0x06, 0x20,
        0xa9, 0x21, 0x8d, 0x07, 0x20, /* write blue */
        0xa9, 0x08, 0x8d, 0x01, 0x20, /* enable background */
        0x4c, 0x26, 0x80,             /* JMP $8026 (self) */
    };
    memcpy(rom + 16, program, sizeof(program));
    for (int vector = 0x3ffa; vector < 0x4000; vector += 2) {
        rom[16 + vector] = 0x00;
        rom[16 + vector + 1] = 0x80;
    }
    FILE *file = fopen(path, "wb");
    if (!file) return 0;
    int ok = fwrite(rom, 1, sizeof(rom), file) == sizeof(rom);
    return fclose(file) == 0 && ok;
}

int main(int argc, char **argv) {
    if (argc != 2 || !write_rom("palette.nes")) return 1;
    lh_host *host = lh_create(LH_FORMAT_RGBA8888, (lh_callbacks){0});
    if (!host) return 1;
    lh_av_info info;
    int result = lh_load(host, argv[1], "palette.nes", ".", ".",
                         "palette", NULL, NULL, 0, &info);
    if (result != LH_OK || lh_start(host) != 0) {
        fprintf(stderr, "Could not start native FCEUmm: %d\n", result);
        lh_destroy(host);
        return 1;
    }

    int rendered = 0;
    const struct timespec delay = {.tv_sec = 0, .tv_nsec = 10000000};
    for (int attempt = 0; attempt < 300 && !rendered; ++attempt) {
        nanosleep(&delay, NULL);
        const void *frame;
        int width, height, stride;
        if (!lh_get_frame(host, &frame, &width, &height, &stride)) continue;
        const uint8_t *pixel = (const uint8_t *)frame +
                              (height / 2) * stride + (width / 2) * 4;
        /* The 6502 must execute the palette write: initial black/gray frames
         * do not satisfy this. Check the intended blue field, not frame count. */
        rendered = pixel[2] > pixel[0] + 40 &&
                   pixel[1] > pixel[0] + 20 && pixel[3] == 255;
        if (rendered) {
            printf("FCEUmm rendered original NES program: %dx%d RGBA=%u,%u,%u,%u\n",
                   width, height, pixel[0], pixel[1], pixel[2], pixel[3]);
        }
    }
    lh_stop(host);
    lh_destroy(host);
    if (!rendered) fprintf(stderr, "Expected blue NES frame was not rendered\n");
    return rendered ? 0 : 1;
}
