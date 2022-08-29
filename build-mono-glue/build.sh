#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="debug_symbols=no use_static_cpp=no"
export TERM=xterm
export DISPLAY=:0

rm -rf godot
mkdir godot
cd godot
tar xf ../godot.tar.gz --strip-components=1

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Building and generating Mono glue..."

  dotnet --info
  export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/pkgconfig/

  ${SCONS} platform=linuxbsd ${OPTIONS} target=release_debug tools=yes module_mono_enabled=yes

  rm -rf /root/mono-glue/*
  bin/godot.linuxbsd.opt.tools.x86_64.mono --headless --generate-mono-glue /root/mono-glue
fi

echo "Mono glue generated successfully"
