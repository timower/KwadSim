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
    Vector3 drag_area;
    float drag_c;

    Vector3 acceleration;

    uint16_t rcData[8];

    std::array<Vector3, 4> motors;

    std::array<float, 4> motorRpm;
    std::array<float, 4> motorF;
    float resultant_prop_torque = 0;

    float total_delta = 0;

    Vector3 point_vel(Vector3 point);

   public:
    static void _register_methods();

    Kwad();
    ~Kwad();

    void new_rc_input(Array data);

    void get_gyro(const PhysicsDirectBodyState& state);

    void run_FC();

    void calc_motors(float delta);

    void _init();
    void _ready();

    void _process(float);

    // void _physics_process(float delta);

    void integrate_forces(PhysicsDirectBodyState* state);
};

}  // namespace godot
