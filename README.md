# KwadSim
The open source racing/freestyle drone simulator

[Demo](https://gfycat.com/OptimalKaleidoscopicAtlanticridleyturtle)

## Building

Install Godot 3.1

clone the repo:
```
    git clone --recurse-submodules git@github.com:timower/KwadSim.git
```
build the native betaflight plugin:
```
    cd Script/native
    cd godot-cpp
    scons bits=64 platform=linux generate_bindings=yes
    cd ..
    scons platform=linux
```

If you're not on linux replace platform=linux with platform=windows or platform=osx.
I've only tested on linux.

## Running

Open the project in godot and click run or execute `godot` from the root of the project.
