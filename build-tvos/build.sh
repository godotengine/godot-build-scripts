#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
# Keep LTO disabled for tvOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow (mirrors the iOS build).
export OPTIONS="production=yes use_lto=no vulkan=no opengl3=no SWIFT_FRONTEND=/root/.local/share/swiftly/toolchains/6.3.0/usr/bin/swift-frontend"
export OPTIONS_MONO="module_mono_enabled=yes"
export OPTIONS_DOTNET=
export TERM=xterm

export TVOS_SDK="26.4"
export TVOS_DEVICE="TVOS_SDK_PATH=/root/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS${TVOS_SDK}.sdk"
export APPLE_TARGET_ARM64="APPLE_TOOLCHAIN_PATH=/root/ioscross/arm64 apple_target_triple=arm-apple-darwin11-"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for tvOS..."

  # arm64 device
  $SCONS platform=tvos $OPTIONS arch=arm64 target=template_debug $TVOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=tvos $OPTIONS arch=arm64 target=template_release $TVOS_DEVICE $APPLE_TARGET_ARM64

  # tvOS simulator builds are intentionally not produced.

  mkdir -p /root/out/templates
  cp bin/libgodot.tvos.template_release.arm64.a /root/out/templates/libgodot.tvos.a
  cp bin/libgodot.tvos.template_debug.arm64.a /root/out/templates/libgodot.tvos.debug.a
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for tvOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  # arm64 device
  $SCONS platform=tvos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug $TVOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=tvos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release $TVOS_DEVICE $APPLE_TARGET_ARM64

  # tvOS simulator builds are intentionally not produced.

  mkdir -p /root/out/templates-mono
  cp bin/libgodot.tvos.template_release.arm64.a /root/out/templates-mono/libgodot.tvos.a
  cp bin/libgodot.tvos.template_debug.arm64.a /root/out/templates-mono/libgodot.tvos.debug.a
fi

echo "tvOS build successful"
