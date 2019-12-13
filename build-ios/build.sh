#!/bin/bash

set -e

# Config

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export IOS_SDK="12.4"
export OPTIONS="osxcross_sdk=darwin18 debug_symbols=no"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm
export OSXCROSS_IOS=not_nothing

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for iOS..."

  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release_debug IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release_debug IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"

  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot.iphone.opt.arm64.a bin/libgodot.iphone.opt.x86_64.a -output /root/out/libgodot.iphone.opt.fat
  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot.iphone.opt.debug.arm64.a bin/libgodot.iphone.opt.debug.x86_64.a -output /root/out/libgodot.iphone.opt.debug.fat

  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot_arkit_module.iphone.opt.arm64.a bin/libgodot_arkit_module.iphone.opt.x86_64.a -output /root/out/libgodot_arkit_module.iphone.opt.fat
  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot_arkit_module.iphone.opt.debug.arm64.a bin/libgodot_arkit_module.iphone.opt.debug.x86_64.a -output /root/out/libgodot_arkit_module.iphone.opt.debug.fat

  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot_camera_module.iphone.opt.arm64.a bin/libgodot_camera_module.iphone.opt.x86_64.a -output /root/out/libgodot_camera_module.iphone.opt.fat
  /root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot_camera_module.iphone.opt.debug.arm64.a bin/libgodot_camera_module.iphone.opt.debug.x86_64.a -output /root/out/libgodot_camera_module.iphone.opt.debug.fat
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "No Mono support for iOS yet."
  #cp /root/mono-glue/*.cpp modules/mono/glue/
  #cp -r /root/mono-glue/Managed/Generated modules/mono/glue/Managed/
fi

echo "iOS build successful"
