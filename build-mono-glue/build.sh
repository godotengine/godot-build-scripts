#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="debug_symbols=no"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf ../godot.tar.gz --strip-components=1

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Building and generating Mono glue..."

  mono --version
  export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig/

  ${SCONS} platform=x11 bits=64 ${OPTIONS} target=release_debug tools=yes module_mono_enabled=yes mono_glue=no

  rm -rf /root/mono-glue/*
  xvfb-run bin/godot.x11.opt.tools.64.mono --generate-mono-glue /root/mono-glue || /bin/true

  # Build and copy CIL that we'll need for Ubuntu 14.04 Linux builds
  # to workaround Mono MSBuild segfault in our containers.
  xvfb-run bin/godot.x11.opt.tools.64.mono --generate-mono-glue modules/mono/glue || /bin/true
  ${SCONS} platform=x11 bits=64 ${OPTIONS} target=release_debug tools=yes module_mono_enabled=yes mono_glue=yes build_cil=yes

  mkdir /root/mono-glue/cil
  cp -r bin/GodotSharp /root/mono-glue/cil/
fi

echo "Mono glue generated successfully"
