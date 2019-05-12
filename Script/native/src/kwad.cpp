#include "kwad.h"

#include <KinematicCollision.hpp>
#include <Label.hpp>
#include <OS.hpp>
#include <PhysicsDirectBodyState.hpp>
#include <Spatial.hpp>
#include <String.hpp>
#include <TileMap.hpp>

#include <algorithm>
#include <csetjmp>
#include <cstring>

#ifndef M_PI
#define M_PI 3.14159265358979
#endif

extern "C" {
#include "dyad.h"

#include "common/maths.h"

#include "fc/init.h"
#include "fc/runtime_config.h"
#include "fc/tasks.h"

#include "flight/imu.h"

#include "scheduler/scheduler.h"
#include "sensors/sensors.h"

#include "drivers/accgyro/accgyro_fake.h"
#include "drivers/pwm_output.h"
#include "drivers/pwm_output_fake.h"

#include "rx/msp.h"

#include "io/displayport_fake.h"
#include "io/gps.h"
}

using namespace godot;

const static auto GYRO_SCALE = 16.4f;
const static auto RAD2DEG = (180.0f / float(M_PI));
const static auto ACC_SCALE = (256 / 9.80665f);

const auto AIR_RHO = 1.225f;

// 20kHz scheduler, is enough to run PID at 8khz
const auto FREQUENCY = 20000.0f;

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

    register_property("crashed", &Kwad::crashed, false);
}

Kwad::Kwad() : dragArea(0.0024f, 0.018f, 0.0024f), dragC(1.8f) {
    motorKv = 2600.0f;
    motorR = 0.08f;
    motorI0 = 1.6f;
    motorKq = 60 / (motorKv * 2.0f * float(M_PI));

    propA = 2e-8f;
    propRpm = 25000;
    propTorqueFac = 0.0195f;
    propInertia = 0.00000413f;
    propVela = -2.40336140e-03f;
    propVelb = -1.11946546e-01f;
    propVelc = 1.09384441e+01f;

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
    auto *globals = get_node("/root/Globals");
    globals->connect("rc_input", this, "new_rc_input");

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

    // imuSetAttitudeQuat(rotation.w, -rotation.z, rotation.x, -rotation.y);

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

float Kwad::prop_thrust(float rpm, float vel) {
    const auto propF = propVela * vel * vel + propVelb * vel + propVelc;
    const auto b = (propF - propA * propRpm * propRpm) / propRpm;
    return b * rpm + propA * rpm * rpm;
}

float Kwad::prop_torque(float rpm, float vel) {
    return prop_thrust(rpm, vel) * propTorqueFac;
}

void Kwad::calc_motors(float delta, Vector3 linVel, Vector3 rotVel) {
    const float motor_dir[4] = {1.0, -1.0, -1.0, 1.0};

    resPropTorque = 0;

    const auto up = get_global_transform().basis.y;

    for (int i = 0; i < 4; i++) {
        const auto r = get_transform().basis.xform(motors[i]);
        const auto vel = std::max(0.0f, (linVel + rotVel.cross(r)).dot(up));

        auto rpm = motorRpm[i];

        auto volts = motorsPwm[i] / 1000.0f * batV;
        auto torque = motor_torque(volts, rpm);

        auto ptorque = prop_torque(rpm, vel);
        auto net_torque = torque - ptorque;
        auto domega = net_torque / propInertia;
        auto drpm = (domega * delta) * 60.0f / (2.0f * float(M_PI));

        auto maxdrpm = fabsf(volts * motorKv - rpm);
        rpm += clamp(drpm, -maxdrpm, maxdrpm);

        motorF[i] = prop_thrust(rpm, vel);
        motorRpm[i] = rpm;
        resPropTorque += motor_dir[i] * torque;
    }
}

void Kwad::integrate_forces(PhysicsDirectBodyState *state) {
    Basis basis = get_transform().basis;

    totalDelta += state->get_step();

#ifdef TIMING
    auto start = OS::get_singleton()->get_ticks_usec();
#endif
    // update tcp serial
    dyad_update();

#ifdef TIMING
    auto end = OS::get_singleton()->get_ticks_usec();
    Godot::print(String("dyad time: {0}").format(Array::make(end - start)));
#endif

    // update rc at 100Hz, otherwise rx loss gets reported:
    rxMspFrameReceive(&rcData[0], 8);

    // high frequency:
    const auto dt = 1 / FREQUENCY;
    while (totalDelta - dt > 0) {
        totalDelta -= dt;
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

        if (crashed) continue;

        // run motors
        calc_motors(dt, state->get_linear_velocity(),
                    state->get_angular_velocity());

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
    }

    // crash detection:
    auto ncontacts = state->get_contact_count();
    auto totalImulse = 0.0f;
    for (auto i = 0; i < ncontacts; i++) {
        totalImulse += fabsf(state->get_contact_impulse(i));
    }
    if (ncontacts != 0) {
        // if (totalImulse > 1.0f) crashed = true;
    }
#ifdef TIMING
    auto end2 = OS::get_singleton()->get_ticks_usec();
    Godot::print(String("loop time: {0}").format(Array::make(end2 - end)));
#endif
}

void Kwad::set_motor_params(float Kv, float R, float I0) {
    motorKv = Kv;
    motorR = R;
    motorI0 = I0;
    motorKq = 60 / (motorKv * 2.0f * float(M_PI));
    // printf("motor: %f, %f, %f, %f\n", motorKv, motorR, motorI0, motorKq);
}

void Kwad::set_prop_params(float Rpm, float a, float torqueFactor,
                           float inertia, Array thrustVel) {
    propRpm = Rpm;
    propA = a;
    propTorqueFac = torqueFactor;
    propInertia = inertia;

    propVela = thrustVel[0];
    propVelb = thrustVel[1];
    propVelc = thrustVel[2];
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
extern "C" {
void systemInit(void) {
    int ret;

    printf("[system]Init...\n");

    SystemCoreClock = 500 * 1000000;  // fake 500MHz
    FLASH_Unlock();

    // serial can't been slow down
    // rescheduleTask(TASK_SERIAL, 1);
}

void systemReset(void) {
    printf("[system]Reset!\n");

    micros_passed = 0;
    init();

    longjmp(reset_buf, 1);
}

void systemResetToBootloader(void) {
    printf("[system]ResetToBootloader!\n");

    micros_passed = 0;
    init();

    longjmp(reset_buf, 1);
}

uint32_t micros(void) {
    return micros_passed & 0xFFFFFFFF;
}

uint32_t millis(void) {
    // static uint32_t last_mil = 0;
    uint32_t mil = (micros_passed / 1000) & 0xFFFFFFFF;
    // fix for gps double stuff:
    // if (mil == last_mil) mil += 1;
    // last_mil = mil;
    return mil;
}

void microsleep(uint32_t usec) {
    sleep_timer = usec;
}

void delayMicroseconds(uint32_t usec) {
    microsleep(usec);
}

void delay(uint32_t ms) {
    microsleep(ms * 1000);
}
}
