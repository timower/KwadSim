#!/bin/bash

set -e

if [ "$TRAVIS_OS_NAME" = "osx" ]; then
  wget https://downloads.tuxfamily.org/godotengine/3.1.2/Godot_v3.1.2-stable_osx.64.zip
  unzip -d godot Godot_v3.1.2-stable_osx.64.zip
  GODOT=godot/Godot.app/Contents/MacOS/Godot
elif [ "$TRAVIS_OS_NAME" = "windows" ]; then
  curl -o godot.zip https://downloads.tuxfamily.org/godotengine/3.1.2/Godot_v3.1.2-stable_win64.exe.zip
  unzip -d godot godot.zip
  GODOT=godot/Godot_v3.1.2-stable_win64.exe
  ${GODOT} --editor --quit || echo "Done"
else
  wget https://downloads.tuxfamily.org/godotengine/3.1.2/Godot_v3.1.2-stable_linux_headless.64.zip
  unzip -d godot Godot_v3.1.2-stable_linux_headless.64.zip
  GODOT=godot/Godot_v3.1.2-stable_linux_headless.64
  ${GODOT} --export x11 Temp.x11 || echo "Done"
fi

# TODO: find way to import assets cleanly:
${GODOT} -s addons/gut/gut_cmdln.gd --path $PWD -gdir=res://Script/Test -gexit
