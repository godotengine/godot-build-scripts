#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="debug_symbols=no use_lto=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm
export MONO32_PREFIX=/root/dependencies/mono-32
export MONO64_PREFIX=/root/dependencies/mono-64

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for Windows..."

  $SCONS platform=windows bits=64 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x64/tools
  cp -rvp bin/* /root/out/x64/tools
  rm -rf bin

  $SCONS platform=windows bits=64 $OPTIONS tools=no target=release_debug
  $SCONS platform=windows bits=64 $OPTIONS tools=no target=release
  mkdir -p /root/out/x64/templates
  cp -rvp bin/* /root/out/x64/templates
  rm -rf bin

  $SCONS platform=windows bits=32 $OPTIONS tools=yes target=release_debug
  mkdir -p /root/out/x86/tools
  cp -rvp bin/* /root/out/x86/tools
  rm -rf bin

  $SCONS platform=windows bits=32 $OPTIONS tools=no target=release_debug
  $SCONS platform=windows bits=32 $OPTIONS tools=no target=release
  mkdir -p /root/out/x86/templates
  cp -rvp bin/* /root/out/x86/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for Windows..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/

  $SCONS platform=windows bits=64 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO64_PREFIX tools=yes target=release_debug copy_mono_root=yes
  mkdir -p /root/out/x64/tools-mono
  cp -rvp bin/* /root/out/x64/tools-mono
  rm -rf bin

  $SCONS platform=windows bits=64 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO64_PREFIX tools=no target=release_debug
  $SCONS platform=windows bits=64 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO64_PREFIX tools=no target=release
  mkdir -p /root/out/x64/templates-mono
  cp -rvp bin/* /root/out/x64/templates-mono
  rm -rf bin

  $SCONS platform=windows bits=32 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO32_PREFIX tools=yes target=release_debug copy_mono_root=yes
  mkdir -p /root/out/x86/tools-mono
  cp -rvp bin/* /root/out/x86/tools-mono
  rm -rf bin

  $SCONS platform=windows bits=32 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO32_PREFIX tools=no target=release_debug
  $SCONS platform=windows bits=32 $OPTIONS $OPTIONS_MONO mono_prefix=$MONO32_PREFIX tools=no target=release
  mkdir -p /root/out/x86/templates-mono
  cp -rvp bin/* /root/out/x86/templates-mono
  rm -rf bin
fi

echo "Windows build successful"
