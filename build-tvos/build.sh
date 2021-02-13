#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS="production=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm

export TVOS_SDK="14.2"
export TVOS_LIPO="/root/ioscross/arm64/bin/arm-apple-darwin11-lipo"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for tvOS..."

  # tvOS Device
  # use_lto is required for Linux-compiled binary to pass App Store checks

  $SCONS platform=tvos $OPTIONS arch=arm64 tools=no target=release_debug \
    TVOSSDK="/root/ioscross/arm64/SDK/AppleTVOS${TVOS_SDK}.sdk" TVOSPATH="/root/ioscross/arm64/" tvos_triple="arm-apple-darwin11-"
  $SCONS platform=tvos $OPTIONS arch=arm64 tools=no target=release \
    TVOSSDK="/root/ioscross/arm64/SDK/AppleTVOS${TVOS_SDK}.sdk" TVOSPATH="/root/ioscross/arm64/" tvos_triple="arm-apple-darwin11-"

  # tvOS Simulator
  # simulators do not requre `use_lto` to work, so it's diabled to decrease build times.

  $SCONS platform=tvos $OPTIONS arch=x86_64 simulator=yes tools=no use_lto=no target=release_debug \
    TVOSSDK="/root/ioscross/x86_64/SDK/AppleTVSimulator${TVOS_SDK}.sdk" TVOSPATH="/root/ioscross/x86_64/" tvos_triple="x86_64-apple-darwin11-"
  $SCONS platform=tvos $OPTIONS arch=x86_64 simulator=yes tools=no use_lto=no target=release \
    TVOSSDK="/root/ioscross/x86_64/SDK/AppleTVSimulator${TVOS_SDK}.sdk" TVOSPATH="/root/ioscross/x86_64/" tvos_triple="x86_64-apple-darwin11-"

  mkdir -p /root/out/templates
  $TVOS_LIPO -create bin/libgodot.tvos.opt.arm64.a bin/libgodot.tvos.opt.x86_64.simulator.a -output /root/out/templates/libgodot.tvos.opt.fat
  $TVOS_LIPO -create bin/libgodot.tvos.opt.debug.arm64.a bin/libgodot.tvos.opt.debug.x86_64.simulator.a -output /root/out/templates/libgodot.tvos.opt.debug.fat
fi

echo "tvOS build successful"
