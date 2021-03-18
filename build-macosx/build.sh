#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="osxcross_sdk=darwin20 production=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes mono_prefix=/root/dependencies/mono"
export TERM=xterm
export STRIP="x86_64-apple-${osxcross_sdk}-strip -u -r"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for macOS..."

  $SCONS platform=osx $OPTIONS arch=x86_64 tools=yes target=release_debug
  $SCONS platform=osx $OPTIONS arch=arm64 tools=yes target=release_debug
  lipo -create bin/godot.osx.opt.tools.x86_64 bin/godot.osx.opt.tools.arm64 -output bin/godot.osx.opt.tools.universal
  $STRIP bin/godot.osx.opt.tools.universal

  mkdir -p /root/out/tools
  cp -rvp bin/* /root/out/tools
  rm -rf bin

  $SCONS platform=osx $OPTIONS arch=x86_64 tools=no target=release_debug
  $SCONS platform=osx $OPTIONS arch=arm64 tools=no target=release_debug
  lipo -create bin/godot.osx.opt.debug.x86_64 bin/godot.osx.opt.debug.arm64 -output bin/godot.osx.opt.debug.universal
  $STRIP bin/godot.osx.opt.debug.universal
  $SCONS platform=osx $OPTIONS arch=x86_64 tools=no target=release
  $SCONS platform=osx $OPTIONS arch=arm64 tools=no target=release
  lipo -create bin/godot.osx.opt.x86_64 bin/godot.osx.opt.arm64 -output bin/godot.osx.opt.universal
  $STRIP bin/godot.osx.opt.universal

  mkdir -p /root/out/templates
  cp -rvp bin/* /root/out/templates
  rm -rf bin
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for macOS..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=x86_64 tools=yes target=release_debug copy_mono_root=yes
  $STRIP bin/godot.osx.opt.tools.x86_64.mono
  #$SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=arm64 tools=yes target=release_debug copy_mono_root=yes
  #lipo -create bin/godot.osx.opt.tools.x86_64.mono bin/godot.osx.opt.tools.arm64.mono -output bin/godot.osx.opt.tools.universal.mono
  #$STRIP bin/godot.osx.opt.tools.universal.mono

  mkdir -p /root/out/tools-mono
  cp -rvp bin/* /root/out/tools-mono
  rm -rf bin

  $SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=x86_64 tools=no target=release_debug
  $STRIP bin/godot.osx.opt.debug.x86_64.mono
  #$SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=arm64 tools=no target=release_debug
  #lipo -create bin/godot.osx.opt.debug.x86_64.mono bin/godot.osx.opt.debug.arm64.mono -output bin/godot.osx.opt.debug.universal.mono
  #$STRIP bin/godot.osx.opt.debug.universal.mono
  $SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=x86_64 tools=no target=release
  $STRIP bin/godot.osx.opt.x86_64.mono
  #$SCONS platform=osx $OPTIONS $OPTIONS_MONO arch=arm64 tools=no target=release
  #lipo -create bin/godot.osx.opt.x86_64.mono bin/godot.osx.opt.arm64.mono -output bin/godot.osx.opt.universal.mono
  #$STRIP bin/godot.osx.opt.universal.mono

  mkdir -p /root/out/templates-mono
  cp -rvp bin/* /root/out/templates-mono
  rm -rf bin
fi

echo "macOS build successful"
