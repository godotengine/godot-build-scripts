#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
# Keep LTO disabled for visionOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow.
# Disable Vulkan and MoltenVK for visionOS - visionOS doesn't support MoltenVK
export OPTIONS="production=yes use_lto=no vulkan=no"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

export VISIONOS_SDK="2.5"
export VISIONOS_LIPO="/root/ioscross/arm64/bin/arm-apple-darwin11-lipo"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for visionOS..."

  # arm64 device
  $SCONS platform=visionos $OPTIONS arch=arm64 visionos_simulator=no target=template_debug \
    VISIONOS_SDK_PATH="/root/SDKs/XROS${VISIONOS_SDK}.sdk" IOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" apple_target_triple="arm-apple-darwin11-"
  $SCONS platform=visionos $OPTIONS arch=arm64 visionos_simulator=no target=template_release \
    VISIONOS_SDK_PATH="/root/SDKs/XROS${VISIONOS_SDK}.sdk" IOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" apple_target_triple="arm-apple-darwin11-"

  # arm64 simulator (disabled for now)
  # $SCONS platform=visionos $OPTIONS arch=arm64 visionos_simulator=yes target=template_debug \
  #   VISIONOS_SDK_PATH="/root/SDKs/XROS${VISIONOS_SDK}.sdk" IOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" apple_target_triple="arm-apple-darwin11-"
  # $SCONS platform=visionos $OPTIONS arch=arm64 visionos_simulator=yes target=template_release \
  #   VISIONOS_SDK_PATH="/root/SDKs/XROS${VISIONOS_SDK}.sdk" IOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" apple_target_triple="arm-apple-darwin11-"

  mkdir -p /root/out/templates
  cp bin/libgodot.visionos.template_release.arm64.a /root/out/templates/libgodot.visionos.a
  cp bin/libgodot.visionos.template_debug.arm64.a /root/out/templates/libgodot.visionos.debug.a
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for visionOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  # arm64 device
  $SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 visionos_simulator=no target=template_debug \
    VISIONOS_SDK_PATH="/root/ioscross/arm64/SDK/XROS${VISIONOS_SDK}.sdk" VISIONOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" visionos_triple="arm-apple-darwin11-"
  $SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 visionos_simulator=no target=template_release \
    VISIONOS_SDK_PATH="/root/ioscross/arm64/SDK/XROS${VISIONOS_SDK}.sdk" VISIONOS_TOOLCHAIN_PATH="/root/ioscross/arm64/" visionos_triple="arm-apple-darwin11-"

  # Simulator builds disabled for now - visionOS simulator support not included
  # See corresponding iOS build.sh for reference if simulator support is added later

  mkdir -p /root/out/templates-mono

  cp bin/libgodot.visionos.template_release.arm64.a /root/out/templates-mono/libgodot.visionos.a
  cp bin/libgodot.visionos.template_debug.arm64.a /root/out/templates-mono/libgodot.visionos.debug.a
fi

echo "visionOS build successful"
