#pragma once

#include <Godot.hpp>
#include <Quat.hpp>
#include <RigidBody.hpp>
#include <Vector3.hpp>

#include <array>

namespace godot {

class Kwad : public RigidBody {
    GODOT_CLASS(Kwad, RigidBody)

   private:
    Vector3 dragArea;
    float dragC;

    Vector3 acceleration;

    std::array<uint16_t, 8> rcData;

    float batV;
    float propRpm, propA, propTorqueFac, propInertia;
    float motorKv, motorR, motorI0, motorKq;
    float propVela, propVelb, propVelc;
    std::array<Vector3, 4> motors;

    std::array<float, 4> motorRpm;
    std::array<float, 4> motorF;
    float resPropTorque = 0;

    float totalDelta = 0;

    void get_gyro(const PhysicsDirectBodyState& state);
    void run_FC();

    float motor_torque(float volts, float rpm);
    float prop_thrust(float rpm, float vel);
    float prop_torque(float rpm, float vel);
    void calc_motors(float delta, Vector3 linVel, Vector3 rotVel);

   public:
    bool crashed = false;

    static void _register_methods();

    Kwad();
    ~Kwad();

    void new_rc_input(Array data);

    void _init();
    void _ready();

    void _process(float);

    void integrate_forces(PhysicsDirectBodyState* state);

    void set_motor_params(float Kv, float R, float I0);
    void set_prop_params(float Rpm, float a, float torqueFactor, float inertia,
                         Array thrustVel);
    void set_frame_params(Vector3 dragArea, float dragC);
    void set_quad_params(float Vbat);
};

}  // namespace godot
