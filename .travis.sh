#!/bin/bash

cd Script/native
cd godot-cpp
scons bits=64 platform=linux generate_bindings=yes || exit $?
scons bits=64 platform=windows || exit $?
cd ..
scons platform=linux || exit $?
scons platform=windows || exit $?
