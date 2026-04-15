#!/bin/bash

set -e

# Config

# Swift toolchain path comes from the image (godot-apple sets SWIFT_VERSION);
# fall back to a sensible default if run against an older image.
SWIFT_VERSION="${SWIFT_VERSION:-6.3.0}"
SWIFT_FRONTEND="/root/.local/share/swiftly/toolchains/${SWIFT_VERSION}/usr/bin/swift-frontend"

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
# Keep LTO disabled for visionOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow.
# Disable Vulkan and MoltenVK for visionOS - visionOS doesn't support MoltenVK.
export OPTIONS="production=yes use_lto=no vulkan=no SWIFT_FRONTEND=${SWIFT_FRONTEND}"
export OPTIONS_MONO="module_mono_enabled=yes"
export OPTIONS_DOTNET="module_dotnet_enabled=yes"
export TERM=xterm

export VISIONOS_SDK="26.4"
export VISIONOS_DEVICE="VISIONOS_SDK_PATH=/root/Xcode.app/Contents/Developer/Platforms/XROS.platform/Developer/SDKs/XROS${VISIONOS_SDK}.sdk"
export VISIONOS_SIMULATOR="VISIONOS_SDK_PATH=/root/Xcode.app/Contents/Developer/Platforms/XRSimulator.platform/Developer/SDKs/XRSimulator${VISIONOS_SDK}.sdk"
export APPLE_TARGET_ARM64="APPLE_TOOLCHAIN_PATH=/root/ioscross/arm64 apple_target_triple=arm-apple-darwin11-"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for visionOS..."

  # arm64 device
  $SCONS platform=visionos $OPTIONS arch=arm64 target=template_debug $VISIONOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=visionos $OPTIONS arch=arm64 target=template_release $VISIONOS_DEVICE $APPLE_TARGET_ARM64

  # arm64 simulator (disabled for now, see build-ios)
  #$SCONS platform=visionos $OPTIONS arch=arm64 target=template_debug $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64
  #$SCONS platform=visionos $OPTIONS arch=arm64 target=template_release $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64

  mkdir -p /root/out/templates
  cp bin/libgodot.visionos.template_release.arm64.a /root/out/templates/libgodot.visionos.a
  cp bin/libgodot.visionos.template_debug.arm64.a /root/out/templates/libgodot.visionos.debug.a
  cp bin/libgodot_camera.visionos.template_release.arm64.a /root/out/templates/libgodot_camera.visionos.a
  cp bin/libgodot_camera.visionos.template_debug.arm64.a /root/out/templates/libgodot_camera.visionos.debug.a
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for visionOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  # arm64 device
  $SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug $VISIONOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release $VISIONOS_DEVICE $APPLE_TARGET_ARM64

  # arm64 simulator (disabled for now, see build-ios)
  #$SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64
  #$SCONS platform=visionos $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64

  mkdir -p /root/out/templates-mono
  cp bin/libgodot.visionos.template_release.arm64.a /root/out/templates-mono/libgodot.visionos.a
  cp bin/libgodot.visionos.template_debug.arm64.a /root/out/templates-mono/libgodot.visionos.debug.a
  cp bin/libgodot_camera.visionos.template_release.arm64.a /root/out/templates-mono/libgodot_camera.visionos.a
  cp bin/libgodot_camera.visionos.template_debug.arm64.a /root/out/templates-mono/libgodot_camera.visionos.debug.a
fi

# .NET

if [ "${DOTNET}" == "1" ]; then
  echo "Starting .NET build for visionOS..."

  # arm64 device
  $SCONS platform=visionos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_debug $VISIONOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=visionos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_release $VISIONOS_DEVICE $APPLE_TARGET_ARM64

  # arm64 simulator (disabled for now, see build-ios)
  #$SCONS platform=visionos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_debug $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64
  #$SCONS platform=visionos $OPTIONS $OPTIONS_DOTNET arch=arm64 target=template_release $VISIONOS_SIMULATOR $APPLE_TARGET_ARM64

  mkdir -p /root/out/templates-dotnet
  cp bin/libgodot.visionos.template_release.arm64.a /root/out/templates-dotnet/libgodot.visionos.a
  cp bin/libgodot.visionos.template_debug.arm64.a /root/out/templates-dotnet/libgodot.visionos.debug.a
  cp bin/libgodot_camera.visionos.template_release.arm64.a /root/out/templates-dotnet/libgodot_camera.visionos.a
  cp bin/libgodot_camera.visionos.template_debug.arm64.a /root/out/templates-dotnet/libgodot_camera.visionos.debug.a
fi

echo "visionOS build successful"
