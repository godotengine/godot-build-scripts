#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Windows..."

  $SCONS platform=windows arch=x86_64 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x86_64/tools
  cp -rvp bin/* /root/out/x86_64/tools
  rm -rf bin

  $SCONS platform=windows arch=x86_64 $OPTIONS tools=no target=release_debug
  $SCONS platform=windows arch=x86_64 $OPTIONS tools=no target=release
  mkdir -p /root/out/x86_64/templates
  cp -rvp bin/* /root/out/x86_64/templates
  rm -rf bin

  $SCONS platform=windows arch=x86_32 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x86_32/tools
  cp -rvp bin/* /root/out/x86_32/tools
  rm -rf bin

  $SCONS platform=windows arch=x86_32 $OPTIONS tools=no target=release_debug
  $SCONS platform=windows arch=x86_32 $OPTIONS tools=no target=release
  mkdir -p /root/out/x86_32/templates
  cp -rvp bin/* /root/out/x86_32/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Windows..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  $SCONS platform=windows arch=x86_64 $OPTIONS $OPTIONS_MONO tools=yes target=release_debug
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=windows
  mkdir -p /root/out/x86_64/tools-mono
  cp -rvp bin/* /root/out/x86_64/tools-mono
  rm -rf bin

  $SCONS platform=windows arch=x86_64 $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=windows arch=x86_64 $OPTIONS $OPTIONS_MONO tools=no target=release
  mkdir -p /root/out/x86_64/templates-mono
  cp -rvp bin/* /root/out/x86_64/templates-mono
  rm -rf bin

  $SCONS platform=windows arch=x86_32 $OPTIONS $OPTIONS_MONO tools=yes target=release_debug
  ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=windows
  mkdir -p /root/out/x86_32/tools-mono
  cp -rvp bin/* /root/out/x86_32/tools-mono
  rm -rf bin

  $SCONS platform=windows arch=x86_32 $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=windows arch=x86_32 $OPTIONS $OPTIONS_MONO tools=no target=release
  mkdir -p /root/out/x86_32/templates-mono
  cp -rvp bin/* /root/out/x86_32/templates-mono
  rm -rf bin
fi

echo "Windows build successful"
