#include "kwad.h"

#include <KinematicCollision.hpp>
#include <Label.hpp>
#include <PhysicsDirectBodyState.hpp>
#include <Spatial.hpp>
#include <String.hpp>
#include <TileMap.hpp>

#include <algorithm>
#include <csetjmp>
#include <cstring>

extern "C" {
#include "common/maths.h"
#include "drivers/accgyro/accgyro_fake.h"
#include "drivers/pwm_output.h"
#include "fc/init.h"
#include "fc/runtime_config.h"
#include "fc/tasks.h"
#include "flight/imu.h"
#include "scheduler/scheduler.h"
#include "sensors/sensors.h"

#include "rx/msp.h"

#include "io/gps.h"

#include "drivers/display.h"
}

using namespace godot;

const static auto GYRO_SCALE = 16.4f;
const static auto RAD2DEG = (180.0f / float(M_PI));
const static auto ACC_SCALE = (256 / 9.80665f);

const auto PIDSUM_LIMIT = 500.0f;
const auto PIDSUM_LIMIT_YAW = 400.0f;
const auto PID_MIXER_SCALING = 1000.0f;

const auto AIR_RHO = 1.225f;

// 20kHz scheduler, is enough to run PID at 8khz
const auto FREQUENCY = 20000.0f;

static int16_t motorsPwm[MAX_SUPPORTED_MOTORS];

const auto CHARS_PER_LINE = 30;
const auto VIDEO_LINES = 16;
static uint8_t osdScreen[16][30];

static int64_t sleep_timer = 0;

static uint64_t micros_passed = 0;

static float clamp(float x, float min, float max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
}

void Kwad::_register_methods() {
    register_method("_process", &Kwad::_process);
    // register_method("_physics_process", &Kwad::_physics_process);

    register_method("_integrate_forces", &Kwad::integrate_forces);

    register_method("_ready", &Kwad::_ready);
    register_method("new_rc_input", &Kwad::new_rc_input);

    register_method("set_motor_params", &Kwad::set_motor_params);
    register_method("set_prop_params", &Kwad::set_prop_params);
    register_method("set_frame_params", &Kwad::set_frame_params);
    register_method("set_quad_params", &Kwad::set_quad_params);
}

Kwad::Kwad() : dragArea(0.0024f, 0.018f, 0.0024f), dragC(1.8f) {
    motorKv = 2600.0f;
    motorR = 0.08f;
    motorI0 = 1.6f;
    motorKq = 60 / (motorKv * 2.0f * float(M_PI));

    propF = 12.99f;
    propA = 2e-8f;
    propRpm = 25000;
    propTorqueFac = 0.0195f;
    propInertia = 0.00000413f;

    batV = 16.0f;

    for (int i = 0; i < 8; i++) {
        rcData[i] = 1500;
    }

    init();
}

Kwad::~Kwad() {
}

void Kwad::_init() {
}

void Kwad::_ready() {
    get_node("/root/Globals")->connect("rc_input", this, "new_rc_input");

    // init motor pos, if not done already:
    set_frame_params(dragArea, dragC);
}

void Kwad::_process(float /*delta*/) {
    auto *osdTile = Object::cast_to<TileMap>(get_node("/root/Root/TileOSD"));

    for (int y = 0; y < VIDEO_LINES; y++) {
        for (int x = 0; x < CHARS_PER_LINE; x++) {
            int o = osdScreen[y][x];

            int tx = o % 36;
            int ty = o / 36;

            osdTile->set_cell(x, y, 0, false, false, false, Vector2(tx, ty));
        }
    }
}

void Kwad::new_rc_input(Array data) {
    for (int i = 0; i < 8; i++) {
        if (i < data.size())
            rcData[i] = uint16_t(1500 + float(data[i]) * 500);
        else
            rcData[i] = 1500;
    }

    rxMspFrameReceive(&rcData[0], 8);
}

void Kwad::get_gyro(const PhysicsDirectBodyState &state) {
    Basis basis = get_transform().basis;

    Vector3 pos = get_transform().origin;
    Quat rotation(basis);
    Vector3 gyro = basis.xform_inv(state.get_angular_velocity());

    Vector3 accelerometer =
        basis.xform_inv(acceleration) * state.get_inverse_mass();

    int16_t x, y, z;
    if (sensors(SENSOR_ACC)) {
        x = int16_t(
            constrain(int(-accelerometer.z * ACC_SCALE), -32767, 32767));
        y = int16_t(constrain(int(accelerometer.x * ACC_SCALE), -32767, 32767));
        z = int16_t(
            constrain(int(-accelerometer.y * ACC_SCALE), -32767, 32767));
        fakeAccSet(fakeAccDev, x, y, z);
    }

    x = int16_t(constrain(int(-gyro.z * GYRO_SCALE * RAD2DEG), -32767, 32767));
    y = int16_t(constrain(int(-gyro.x * GYRO_SCALE * RAD2DEG), -32767, 32767));
    z = int16_t(constrain(int(gyro.y * GYRO_SCALE * RAD2DEG), -32767, 32767));
    fakeGyroSet(fakeGyroDev, x, y, z);

    imuSetAttitudeQuat(rotation.w, -rotation.z, rotation.x, -rotation.y);

    const auto
        DISTANCE_BETWEEN_TWO_LONGITUDE_POINTS_AT_EQUATOR_IN_HUNDREDS_OF_KILOMETERS =
            1.113195f;
    const auto cosLon0 = 0.63141842418f;

    // set gps:
    static int64_t last_millis = 0;
    int64_t millis = micros_passed / 1000;

    if (millis - last_millis > 100) {
        ENABLE_STATE(GPS_FIX);
        gpsSol.numSat = 10;
        gpsSol.llh.lat =
            int32_t(
                -pos.z * 100 /
                DISTANCE_BETWEEN_TWO_LONGITUDE_POINTS_AT_EQUATOR_IN_HUNDREDS_OF_KILOMETERS) +
            508445910;
        gpsSol.llh.lon =
            int32_t(
                pos.x * 100 /
                (cosLon0 *
                 DISTANCE_BETWEEN_TWO_LONGITUDE_POINTS_AT_EQUATOR_IN_HUNDREDS_OF_KILOMETERS)) +
            43551050;
        gpsSol.llh.altCm = int32_t(pos.y * 100);
        gpsSol.groundSpeed =
            uint16_t(state.get_linear_velocity().length() * 100);
        GPS_update |= GPS_MSP_UPDATE;

        last_millis = millis;
    }
}

static jmp_buf reset_buf;

void Kwad::run_FC() {
    if (!setjmp(reset_buf)) scheduler();
}

float Kwad::motor_torque(float volts, float rpm) {
    auto current = (volts - rpm / motorKv) / motorR;

    if (current > 0)
        current = std::max(0.0f, current - motorI0);
    else if (current < 0)
        current = std::min(0.0f, current + motorI0);
    return current * motorKq;
}

float Kwad::prop_thrust(float rpm) {
    const auto b = (propF - propA * propRpm * propRpm) / propRpm;
    return b * rpm + propA * rpm * rpm;
}

float Kwad::prop_torque(float rpm) {
    return prop_thrust(rpm) * propTorqueFac;
}

void Kwad::calc_motors(float delta) {
    const float motor_dir[4] = {1.0, -1.0, -1.0, 1.0};

    resPropTorque = 0;

    for (int i = 0; i < 4; i++) {
        auto rpm = motorRpm[i];

        auto volts = motorsPwm[i] / 1000.0f * batV;
        auto torque = motor_torque(volts, rpm);

        auto ptorque = prop_torque(rpm);
        auto net_torque = torque - ptorque;
        auto domega = net_torque / propInertia;
        auto drpm = (domega * delta) * 60.0f / (2.0f * float(M_PI));

        auto maxdrpm = fabsf(volts * motorKv - rpm);
        rpm += clamp(drpm, -maxdrpm, maxdrpm);

        motorF[i] = prop_thrust(rpm);
        motorRpm[i] = rpm;
        resPropTorque += motor_dir[i] * torque;
    }
}

void Kwad::integrate_forces(PhysicsDirectBodyState *state) {
    Basis basis = get_transform().basis;

    totalDelta += state->get_step();

    // update rc at 100Hz, otherwise rx loss gets reported:
    rxMspFrameReceive(&rcData[0], 8);

    // high frequency:
    const auto dt = 1 / FREQUENCY;
    while (totalDelta - dt > 0) {
        const auto dmicros = uint64_t(dt * 1e6f);
        micros_passed += dmicros;

        // get gyro, accel
        get_gyro(*state);

        // run FC or sleep if FC requests it
        if (sleep_timer > 0) {
            sleep_timer -= dmicros;
            sleep_timer = std::max(int64_t(0), sleep_timer);
        } else {
            run_FC();
        }

        // run motors
        calc_motors(dt);

        // run Physics
        auto gravityF = Vector3(0, -9.81f * get_mass(), 0);

        // force sum:
        Vector3 total_force = gravityF;

        // drag:
        float vel2 = state->get_linear_velocity().length_squared();
        auto dir = state->get_linear_velocity().normalized();
        auto local_dir = get_global_transform().basis.xform_inv(dir);
        float area = dragArea.dot(local_dir.abs());
        total_force -= dir * 0.5 * AIR_RHO * vel2 * dragC * area;

        // motors:
        for (auto i = 0u; i < 4; i++) {
            total_force += basis.xform(Vector3(0, motorF[i], 0));
        }

        acceleration = total_force * state->get_inverse_mass();
        state->set_linear_velocity(state->get_linear_velocity() +
                                   acceleration * dt);

        // moment sum around origin:
        Vector3 total_moment = get_global_transform().basis.y * resPropTorque;

        for (auto i = 0u; i < 4; i++) {
            auto force = basis.xform(Vector3(0, motorF[i], 0));
            auto rad = basis.xform(motors[i]);
            total_moment += rad.cross(force);
        }

        Vector3 angularAcc = state->get_inverse_inertia() * total_moment;

        auto total_angular = state->get_angular_velocity() + angularAcc * dt;
        state->set_angular_velocity(total_angular);

        totalDelta -= dt;
    }
}

void Kwad::set_motor_params(float Kv, float R, float I0) {
    motorKv = Kv;
    motorR = R;
    motorI0 = I0;
    motorKq = 60 / (motorKv * 2.0f * float(M_PI));
    // printf("motor: %f, %f, %f, %f\n", motorKv, motorR, motorI0, motorKq);
}

void Kwad::set_prop_params(float T, float Rpm, float a, float torqueFactor,
                           float inertia) {
    propF = T;
    propRpm = Rpm;
    propA = a;
    propTorqueFac = torqueFactor;
    propInertia = inertia;
    // printf("prop: %f, %f, %f, %f, %f\n", propF, propRpm, propA * 1e8,
    //       propTorqueFac, propInertia);
}

void Kwad::set_frame_params(Vector3 dragArea, float dragC) {
    this->dragArea = dragArea;
    this->dragC = dragC;
    // printf("frame: %f %f %f, %f\n", dragArea.x, dragArea.y, dragArea.z,
    // dragC);

    motors[0] = Object::cast_to<Spatial>(get_node("motor1"))->get_translation();
    motors[1] = Object::cast_to<Spatial>(get_node("motor2"))->get_translation();
    motors[2] = Object::cast_to<Spatial>(get_node("motor3"))->get_translation();
    motors[3] = Object::cast_to<Spatial>(get_node("motor4"))->get_translation();
}

void Kwad::set_quad_params(float Vbat) {
    batV = Vbat;
    // printf("vbat: %f\n", batV);
}

/*********************
 * Betaflight Stuff: *
 *********************/

extern "C" void systemInit(void) {
    int ret;

    printf("[system]Init...\n");

    SystemCoreClock = 500 * 1000000;  // fake 500MHz
    FLASH_Unlock();

    // serial can't been slow down
    rescheduleTask(TASK_SERIAL, 1);
}

extern "C" void systemReset(void) {
    printf("[system]Reset!\n");

    micros_passed = 0;
    init();

    longjmp(reset_buf, 1);
}

extern "C" void systemResetToBootloader(void) {
    printf("[system]ResetToBootloader!\n");

    micros_passed = 0;
    init();

    longjmp(reset_buf, 1);
}

extern "C" uint32_t micros(void) {
    return micros_passed & 0xFFFFFFFF;
}

extern "C" uint32_t millis(void) {
    static uint32_t last_mil = 0;
    uint32_t mil = (micros_passed / 1000) & 0xFFFFFFFF;
    // fix for gps double stuff:
    if (mil == last_mil) mil += 1;
    last_mil = mil;
    return mil;
}

void microsleep(uint32_t usec) {
    sleep_timer = usec;
}

extern "C" void delayMicroseconds(uint32_t usec) {
    microsleep(usec);
}

extern "C" void delay(uint32_t ms) {
    microsleep(ms * 1000);
}

extern "C" {

// PWM part
static bool pwmMotorsEnabled = false;
static pwmOutputPort_t motors[MAX_SUPPORTED_MOTORS];
static pwmOutputPort_t servos[MAX_SUPPORTED_SERVOS];

// real value to send
static int16_t servosPwm[MAX_SUPPORTED_SERVOS];
static int16_t idlePulse;

void motorDevInit(const motorDevConfig_t *motorConfig, uint16_t _idlePulse,
                  uint8_t motorCount) {
    UNUSED(motorConfig);
    UNUSED(motorCount);

    idlePulse = _idlePulse;
    if (motorConfig->motorPwmProtocol == PWM_TYPE_BRUSHED) {
        idlePulse = 1000.0;
    }

    for (int motorIndex = 0;
         motorIndex < MAX_SUPPORTED_MOTORS && motorIndex < motorCount;
         motorIndex++) {
        motors[motorIndex].enabled = true;
    }
    pwmMotorsEnabled = true;
}

void servoDevInit(const servoDevConfig_t *servoConfig) {
    UNUSED(servoConfig);
    for (uint8_t servoIndex = 0; servoIndex < MAX_SUPPORTED_SERVOS;
         servoIndex++) {
        servos[servoIndex].enabled = true;
    }
}

pwmOutputPort_t *pwmGetMotors(void) {
    return motors;
}

void pwmEnableMotors(void) {
    pwmMotorsEnabled = true;
}

bool pwmAreMotorsEnabled(void) {
    return pwmMotorsEnabled;
}

bool isMotorProtocolDshot(void) {
    return false;
}

void pwmWriteMotor(uint8_t index, float value) {
    motorsPwm[index] = int16_t(value - idlePulse);
}

void pwmShutdownPulsesForAllMotors(uint8_t motorCount) {
    UNUSED(motorCount);
    pwmMotorsEnabled = false;
}

void pwmWriteServo(uint8_t index, float value) {
    servosPwm[index] = int16_t(value);
}

void pwmCompleteMotorUpdate(uint8_t motorCount) {
    UNUSED(motorCount);
}

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
    std::memset(osdBackBuffer, 0, 16 * 30);
    return 0;
}

static int drawScreen(displayPort_t *displayPort) {
    UNUSED(displayPort);
    std::memcpy(osdScreen, osdBackBuffer, 16 * 30);
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
}
