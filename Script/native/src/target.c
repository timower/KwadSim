/*
 * This file is part of Cleanflight and Betaflight.
 *
 * Cleanflight and Betaflight are free software. You can redistribute
 * this software and/or modify this software under the terms of the
 * GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * Cleanflight and Betaflight are distributed in the hope that they
 * will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software.
 *
 * If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include <errno.h>
#include <time.h>

#include "common/maths.h"

#include "drivers/io.h"
#include "drivers/dma.h"
#include "drivers/serial.h"
#include "drivers/serial_tcp.h"
#include "drivers/system.h"
#include "drivers/pwm_output.h"
#include "drivers/light_led.h"

#include "drivers/timer.h"
#include "drivers/timer_def.h"
const timerHardware_t timerHardware[1]; // unused

#include "drivers/accgyro/accgyro_fake.h"
#include "flight/imu.h"

#include "fc/config.h"
#include "scheduler/scheduler.h"

#include "pg/rx.h"

#include "rx/rx.h"

#include "dyad.h"
#include "drivers/display.h"

#include "io/gps.h"
#include "fc/runtime_config.h"

uint32_t SystemCoreClock;

int timeval_sub(struct timespec *result, struct timespec *x, struct timespec *y);

int lockMainPID(void) {
    return 0;
}


char *strcasestr(const char *haystack, const char *needle)
{
    int nLen = strlen(needle);
    do {
        if (!strncasecmp(haystack, needle, nLen)) {
            return (char *)haystack;
        }
        haystack++;
    } while (*haystack);
    return NULL;
}


// system
//int __imp___acrt_iob_func() {}

void timerInit(void) {
    printf("[timer]Init...\n");
}

void timerStart(void) {
}

void failureMode(failureMode_e mode) {
    printf("[failureMode]!!! %d\n", mode);
    while (1);
}

void indicateFailure(failureMode_e mode, int repeatCount)
{
    UNUSED(repeatCount);
    printf("Failure LED flash for: [failureMode]!!! %d\n", mode);
}


// ADC part
uint16_t adcGetChannel(uint8_t channel) {
    UNUSED(channel);
    return 0;
}

// stack part
char _estack;
char _Min_Stack_Size;

// fake EEPROM
static FILE *eepromFd = NULL;
uint8_t eepromData[EEPROM_SIZE];

void FLASH_Unlock(void) {
    if (eepromFd != NULL) {
        fprintf(stderr, "[FLASH_Unlock] eepromFd != NULL\n");
        return;
    }

    // open or create
    eepromFd = fopen(EEPROM_FILENAME,"r+");
    if (eepromFd != NULL) {
        // obtain file size:
        fseek(eepromFd , 0 , SEEK_END);
        size_t lSize = ftell(eepromFd);
        rewind(eepromFd);

        size_t n = fread(eepromData, 1, sizeof(eepromData), eepromFd);
        if (n == lSize) {
            printf("[FLASH_Unlock] loaded '%s', size = %ld / %ld\n", EEPROM_FILENAME, lSize, sizeof(eepromData));
        } else {
            fprintf(stderr, "[FLASH_Unlock] failed to load '%s'\n", EEPROM_FILENAME);
            return;
        }
    } else {
        printf("[FLASH_Unlock] created '%s', size = %ld\n", EEPROM_FILENAME, sizeof(eepromData));
        if ((eepromFd = fopen(EEPROM_FILENAME, "w+")) == NULL) {
            fprintf(stderr, "[FLASH_Unlock] failed to create '%s'\n", EEPROM_FILENAME);
            return;
        }
        if (fwrite(eepromData, sizeof(eepromData), 1, eepromFd) != 1) {
            fprintf(stderr, "[FLASH_Unlock] write failed: %s\n", strerror(errno));
        }
    }
}

void FLASH_Lock(void) {
    // flush & close
    if (eepromFd != NULL) {
        fseek(eepromFd, 0, SEEK_SET);
        fwrite(eepromData, 1, sizeof(eepromData), eepromFd);
        fclose(eepromFd);
        eepromFd = NULL;
        printf("[FLASH_Lock] saved '%s'\n", EEPROM_FILENAME);
    } else {
        fprintf(stderr, "[FLASH_Lock] eeprom is not unlocked\n");
    }
}

FLASH_Status FLASH_ErasePage(uintptr_t Page_Address) {
    UNUSED(Page_Address);
//    printf("[FLASH_ErasePage]%x\n", Page_Address);
    return FLASH_COMPLETE;
}

FLASH_Status FLASH_ProgramWord(uintptr_t addr, uint32_t value) {
    if ((addr >= (uintptr_t)eepromData) && (addr < (uintptr_t)ARRAYEND(eepromData))) {
        *((uint32_t*)addr) = value;
        printf("[FLASH_ProgramWord]%p = %08x\n", (void*)addr, *((uint32_t*)addr));
    } else {
            printf("[FLASH_ProgramWord]%p out of range!\n", (void*)addr);
    }
    return FLASH_COMPLETE;
}

// serial stuff

void uartPinConfigure(const serialPinConfig_t *pSerialPinConfig)
{
    UNUSED(pSerialPinConfig);
    printf("uartPinConfigure\n");
}

PG_REGISTER_WITH_RESET_FN(serialPinConfig_t, serialPinConfig, PG_SERIAL_PIN_CONFIG, 0);

void pgResetFn_serialPinConfig(serialPinConfig_t *serialPinConfig)
{
    printf("Serial reset\n");
}

// RTC stuff?

uint32_t persistentObjectRead(int id) {
    UNUSED(id);
    printf("persistent read\n");
}

void persistentObjectWrite(int id, uint32_t value) {
    UNUSED(id);
    UNUSED(value);
}

// some badly ifdefed stuff
uint8_t mpuGyroReadRegister(const void *bus, uint8_t reg) {}

void IOConfigGPIO(IO_t io, ioConfig_t cfg) {}

void spektrumBind(rxConfig_t *rxConfig)
{
    UNUSED(rxConfig);
    printf("spektrumBind\n");
}

int spiDeviceByInstance(void *instance) {
    return 0;
}

void max7456WriteNvm(uint8_t char_address, const uint8_t *font_data) {}

PG_REGISTER_WITH_RESET_FN(displayPortProfile_t, displayPortProfileMax7456, PG_DISPLAY_PORT_MAX7456_CONFIG, 0);

void pgResetFn_displayPortProfileMax7456(displayPortProfile_t *displayPortProfile)
{
    displayPortProfile->colAdjust = 0;
    displayPortProfile->rowAdjust = 0;

    // Set defaults as per MAX7456 datasheet
    displayPortProfile->invert = false;
    displayPortProfile->blackBrightness = 0;
    displayPortProfile->whiteBrightness = 2;
}

#define GPS_DISTANCE_FLOWN_MIN_GROUND_SPEED_THRESHOLD_CM_S 15

uint32_t millis();

void GPS_calculateDistanceFlownVerticalSpeed_Fake(bool initialize) {
    static int32_t lastCoord[2] = { 0, 0 };
    static int16_t lastAlt;
    static int32_t lastMillis;

    int currentMillis = millis();

    if (initialize) {
        GPS_distanceFlownInCm = 0;
        GPS_verticalSpeedInCmS = 0;
    } else {
        if (STATE(GPS_FIX_HOME) && ARMING_FLAG(ARMED)) {
            // Only add up movement when speed is faster than minimum threshold
            if (gpsSol.groundSpeed > GPS_DISTANCE_FLOWN_MIN_GROUND_SPEED_THRESHOLD_CM_S) {
                uint32_t dist;
                int32_t dir;
                GPS_distance_cm_bearing(&gpsSol.llh.lat, &gpsSol.llh.lon, &lastCoord[LAT], &lastCoord[LON], &dist, &dir);
                GPS_distanceFlownInCm += dist;
            }
        }

        int32_t dt = currentMillis - lastMillis;
        GPS_verticalSpeedInCmS = dt == 0 ? 0 : (gpsSol.llh.altCm - lastAlt) * 1000 / dt;
        GPS_verticalSpeedInCmS = constrain(GPS_verticalSpeedInCmS, -1500.0f, 1500.0f);
    }
    lastCoord[LON] = gpsSol.llh.lon;
    lastCoord[LAT] = gpsSol.llh.lat;
    lastAlt = gpsSol.llh.altCm;
    lastMillis = currentMillis;
}
