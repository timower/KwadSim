#pragma once

#include <Godot.hpp>
#include <Reference.hpp>

namespace godot {

class SerialTcpThread : public Reference {
    GODOT_CLASS(SerialTcpThread, Reference)

   public:
    static void _register_methods();

    SerialTcpThread();

    void _init() {
    }

    void start_tcp();
    void stop_tcp();
};

}  // namespace godot
