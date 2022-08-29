#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes use_thinlto=yes"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

source /root/emsdk/emsdk_env.sh

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Web..."

  $SCONS platform=web ${OPTIONS} target=release_debug tools=no
  $SCONS platform=web ${OPTIONS} target=release tools=no

  $SCONS platform=web ${OPTIONS} target=release_debug tools=no gdnative_enabled=yes
  $SCONS platform=web ${OPTIONS} target=release tools=no gdnative_enabled=yes

  mkdir -p /root/out/templates
  cp -rvp bin/*.zip /root/out/templates
  rm -f bin/*.zip

  $SCONS platform=web ${OPTIONS} target=release_debug tools=yes use_closure_compiler=yes

  mkdir -p /root/out/tools
  cp -rvp bin/*.zip /root/out/tools
  rm -f bin/*.zip
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Web..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  $SCONS platform=web ${OPTIONS} ${OPTIONS_MONO} target=release_debug tools=no
  $SCONS platform=web ${OPTIONS} ${OPTIONS_MONO} target=release tools=no

  mkdir -p /root/out/templates-mono
  cp -rvp bin/*.zip /root/out/templates-mono
  rm -f bin/*.zip
fi

echo "Web build successful"
