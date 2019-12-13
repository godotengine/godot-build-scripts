#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="osxcross_sdk=darwin18 debug_symbols=no"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes mono_prefix=/root/dependencies/mono"
export TERM=xterm

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=osx $OPTIONS tools=yes target=release_debug

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  $SCONS platform=osx $OPTIONS tools=no target=release_debug
  $SCONS platform=osx $OPTIONS tools=no target=release

  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for macOS..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO tools=yes target=release_debug copy_mono_root=yes

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO tools=no target=release_debug
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO tools=no target=release

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin

  find /root/out -name config -exec cp /root/dependencies/mono/etc/config {} \;
fi

echo "macOS build successful"
