#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="debug_symbols=no use_static_cpp=yes use_lto=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm
export CC="gcc-8"
export CXX="g++-8"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Server..."

  $SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  #$SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=no target=release_debug
  $SCONS platform=server CC=$CC CXX=$CXX $OPTIONS tools=no target=release
  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Server..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  # Workaround for MSBuild segfault on Ubuntu containers, we build the CIL on Fedora and copy here.
  mkdir -p bin
  cp -r /root/mono-glue/cil/GodotSharp bin/

  $SCONS platform=server CC=$CC CXX=$CXX $OPTIONS $OPTIONS_MONO tools=yes target=release_debug copy_mono_root=yes build_cil=no
  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  #$SCONS platform=server CC=$CC CXX=$CXX $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=server CC=$CC CXX=$CXX $OPTIONS $OPTIONS_MONO tools=no target=release
  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

echo "Server build successful"
