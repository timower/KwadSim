#!/bin/bash

if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    cd Script/native
    cd godot-cpp
    scons bits=64 platform=osx generate_bindings=yes || exit $?
    cd ..
    scons platform=osx use_llvm=yes || exit $?
else
    cd Script/native
    cd godot-cpp
    scons bits=64 platform=linux generate_bindings=yes || exit $?
    scons bits=64 platform=windows || exit $?
    cd ..
    scons platform=linux || exit $?
    scons platform=windows || exit $?
fi
