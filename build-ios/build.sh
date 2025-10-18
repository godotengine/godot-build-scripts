#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no redirect_build_objects=no"
# Keep LTO disabled for iOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow.
export OPTIONS="production=yes use_lto=no SWIFT_FRONTEND=/root/.local/share/swiftly/toolchains/6.2.0/usr/bin/swift-frontend"
export OPTIONS_MONO="module_mono_enabled=yes"
export TERM=xterm

export IOS_SDK="26.0"
export IOS_DEVICE="IOS_SDK_PATH=/root/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${IOS_SDK}.sdk"
export IOS_SIMULATOR="IOS_SDK_PATH=/root/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IOS_SDK}.sdk simulator=yes"
export APPLE_TARGET_ARM64="APPLE_TOOLCHAIN_PATH=/root/ioscross/arm64 apple_target_triple=arm-apple-darwin11-"
export APPLE_TARGET_X86_64="APPLE_TOOLCHAIN_PATH=/root/ioscross/x86_64 apple_target_triple=x86_64-apple-darwin11-"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for iOS..."

  # arm64 device
  $SCONS platform=ios $OPTIONS arch=arm64 target=template_debug $IOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=ios $OPTIONS arch=arm64 target=template_release $IOS_DEVICE $APPLE_TARGET_ARM64

  # arm64 simulator
  # Disabled for now as it doesn't work with cctools-port and current LLVM.
  # See https://github.com/godotengine/build-containers/pull/85.
  #$SCONS platform=ios $OPTIONS arch=arm64 target=template_debug $IOS_SIMULATOR $APPLE_TARGET_ARM64
  #$SCONS platform=ios $OPTIONS arch=arm64 target=template_release $IOS_SIMULATOR $APPLE_TARGET_ARM64

  # x86_64 simulator
  $SCONS platform=ios $OPTIONS arch=x86_64 target=template_debug $IOS_SIMULATOR $APPLE_TARGET_X86_64
  $SCONS platform=ios $OPTIONS arch=x86_64 target=template_release $IOS_SIMULATOR $APPLE_TARGET_X86_64

  mkdir -p /root/out/templates
  cp bin/libgodot.ios.template_release.arm64.a /root/out/templates/libgodot.ios.a
  cp bin/libgodot.ios.template_debug.arm64.a /root/out/templates/libgodot.ios.debug.a
  cp bin/libgodot.ios.template_release.x86_64.simulator.a /root/out/templates/libgodot.ios.simulator.a
  cp bin/libgodot.ios.template_debug.x86_64.simulator.a /root/out/templates/libgodot.ios.debug.simulator.a
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for iOS..."

  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/

  # arm64 device
  $SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug $IOS_DEVICE $APPLE_TARGET_ARM64
  $SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release $IOS_DEVICE $APPLE_TARGET_ARM64

  # arm64 simulator
  # Disabled for now as it doesn't work with cctools-port and current LLVM.
  # See https://github.com/godotengine/build-containers/pull/85.
  #$SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=arm64 target=template_debug $IOS_SIMULATOR $APPLE_TARGET_ARM64
  #$SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=arm64 target=template_release $IOS_SIMULATOR $APPLE_TARGET_ARM64

  # x86_64 simulator
  $SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_debug $IOS_SIMULATOR $APPLE_TARGET_X86_64
  $SCONS platform=ios $OPTIONS $OPTIONS_MONO arch=x86_64 target=template_release $IOS_SIMULATOR $APPLE_TARGET_X86_64

  mkdir -p /root/out/templates-mono
  cp bin/libgodot.ios.template_release.arm64.a /root/out/templates-mono/libgodot.ios.a
  cp bin/libgodot.ios.template_debug.arm64.a /root/out/templates-mono/libgodot.ios.debug.a
  cp bin/libgodot.ios.template_release.x86_64.simulator.a /root/out/templates-mono/libgodot.ios.simulator.a
  cp bin/libgodot.ios.template_debug.x86_64.simulator.a /root/out/templates-mono/libgodot.ios.debug.simulator.a
fi

echo "iOS build successful"
