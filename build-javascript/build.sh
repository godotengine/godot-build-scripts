#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="debug_symbols=no"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes mono_prefix=/root/mono-installs/wasm-runtime-release"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for JavaScript..."

  $SCONS platform=javascript ${OPTIONS} target=release_debug tools=no
  $SCONS platform=javascript ${OPTIONS} target=release tools=no

  mkdir -p /root/out/templates
  cp -rvp bin/*.zip /root/out/templates
  rm -f bin/*.zip
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for JavaScript..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/

  $SCONS platform=javascript ${OPTIONS} ${OPTIONS_MONO} target=release_debug tools=no
  $SCONS platform=javascript ${OPTIONS} ${OPTIONS_MONO} target=release tools=no

  mkdir -p /root/out/templates-mono
  cp -rvp bin/*.zip /root/out/templates-mono
  rm -f bin/*.zip

  mkdir -p /root/out/templates-mono/bcl
  cp -r /root/mono-installs/wasm-bcl/wasm /root/out/templates-mono/bcl/
fi

echo "JavaScript build successful"
