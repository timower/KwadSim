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
    float propF, propRpm, propA, propTorqueFac, propInertia;
    float motorKv, motorR, motorI0, motorKq;
    std::array<Vector3, 4> motors;

    std::array<float, 4> motorRpm;
    std::array<float, 4> motorF;
    float resPropTorque = 0;

    float totalDelta = 0;

    void get_gyro(const PhysicsDirectBodyState& state);
    void run_FC();

    float motor_torque(float volts, float rpm);
    float prop_thrust(float rpm);
    float prop_torque(float rpm);
    void calc_motors(float delta);

   public:
    static void _register_methods();

    Kwad();
    ~Kwad();

    void new_rc_input(Array data);

    void _init();
    void _ready();

    void _process(float);

    void integrate_forces(PhysicsDirectBodyState* state);

    void set_motor_params(float Kv, float R, float I0);
    void set_prop_params(float T, float Rpm, float a, float torqueFactor,
                         float inertia);
    void set_frame_params(Vector3 dragArea, float dragC);
    void set_quad_params(float Vbat);
};

}  // namespace godot
