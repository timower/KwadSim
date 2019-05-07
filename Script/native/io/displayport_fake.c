#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#include "displayport_fake.h"
#include "drivers/display.h"
#include "common/utils.h"

uint8_t osdScreen[VIDEO_LINES][CHARS_PER_LINE];

// osd:
static uint8_t osdBackBuffer[VIDEO_LINES][CHARS_PER_LINE];
static displayPort_t fakeDisplayPort;

extern unsigned int resumeRefreshAt;
static int grab(displayPort_t *displayPort) {
    UNUSED(displayPort);

#ifdef USE_OSD
    resumeRefreshAt = 0;
#endif
    return 0;
}

static int release(displayPort_t *displayPort) {
    UNUSED(displayPort);
    return 0;
}

static int clearScreen(displayPort_t *displayPort) {
    UNUSED(displayPort);
    memset(osdBackBuffer, 0, 16 * 30);
    return 0;
}

static int drawScreen(displayPort_t *displayPort) {
    UNUSED(displayPort);
    memcpy(osdScreen, osdBackBuffer, 16 * 30);
    return 0;
}

static int screenSize(const displayPort_t *displayPort) {
    UNUSED(displayPort);
    return 480;
}

static int writeString(displayPort_t *displayPort, uint8_t x, uint8_t y,
                       const char *s) {
    UNUSED(displayPort);
    // printf("%d, %d: %s\n", x, y, s);
    if (y < VIDEO_LINES) {
        for (int i = 0; s[i] && x + i < CHARS_PER_LINE; i++) {
            osdBackBuffer[y][x + i] = s[i];
            // printf("%d, %d: %d\n", x, y, s[i]);
        }
    }
    return 0;
}

static int writeChar(displayPort_t *displayPort, uint8_t x, uint8_t y,
                     uint8_t c) {
    UNUSED(displayPort);
    if (x < CHARS_PER_LINE && y < VIDEO_LINES) {
        osdBackBuffer[y][x] = c;
    }
    return 0;
}

static bool isTransferInProgress(const displayPort_t *displayPort) {
    UNUSED(displayPort);
    return false;
}

static bool isSynced(const displayPort_t *displayPort) {
    UNUSED(displayPort);
    return true;
}

static void resync(displayPort_t *displayPort) {
    displayPort->rows = VIDEO_LINES;
    displayPort->cols = CHARS_PER_LINE;
}

static int heartbeat(displayPort_t *displayPort) {
    UNUSED(displayPort);
    return 0;
}

static uint32_t txBytesFree(const displayPort_t *displayPort) {
    UNUSED(displayPort);
    return UINT32_MAX;
}

static const displayPortVTable_t fakeDispVTable = {
    .grab = grab,
    .release = release,
    .clearScreen = clearScreen,
    .drawScreen = drawScreen,
    .screenSize = screenSize,
    .writeString = writeString,
    .writeChar = writeChar,
    .isTransferInProgress = isTransferInProgress,
    .heartbeat = heartbeat,
    .resync = resync,
    .isSynced = isSynced,
    .txBytesFree = txBytesFree,
};

struct vcdProfile_s;
displayPort_t *max7456DisplayPortInit(const struct vcdProfile_s *vcdProfile) {
    UNUSED(vcdProfile);

    printf("display init\n");
    displayInit(&fakeDisplayPort, &fakeDispVTable);

    resync(&fakeDisplayPort);

    return &fakeDisplayPort;
}
