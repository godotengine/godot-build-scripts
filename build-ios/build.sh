#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
# Keep LTO disabled for iOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow.
export OPTIONS="production=yes use_lto=no"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm

export IOS_SDK="14.4"
export IOS_LIPO="/root/ioscross/arm64/bin/arm-apple-darwin11-lipo"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for iOS..."

  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release_debug \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release_debug \
    IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release \
    IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"

  mkdir -p /root/out/templates
  $IOS_LIPO -create bin/libgodot.iphone.opt.arm64.a bin/libgodot.iphone.opt.x86_64.a -output /root/out/templates/libgodot.iphone.opt.fat
  $IOS_LIPO -create bin/libgodot.iphone.opt.debug.arm64.a bin/libgodot.iphone.opt.debug.x86_64.a -output /root/out/templates/libgodot.iphone.opt.debug.fat
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for iOS..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 mono_prefix=/root/mono-installs/ios-arm64-release tools=no target=release_debug \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 mono_prefix=/root/mono-installs/ios-arm64-release tools=no target=release \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=x86_64 mono_prefix=/root/mono-installs/ios-x86_64-release tools=no target=release_debug \
    IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=x86_64 mono_prefix=/root/mono-installs/ios-x86_64-release tools=no target=release \
    IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"

  mkdir -p /root/out/templates-mono
  $IOS_LIPO -create bin/libgodot.iphone.opt.arm64.a bin/libgodot.iphone.opt.x86_64.a -output /root/out/templates-mono/libgodot.iphone.opt.fat
  $IOS_LIPO -create bin/libgodot.iphone.opt.debug.arm64.a bin/libgodot.iphone.opt.debug.x86_64.a -output /root/out/templates-mono/libgodot.iphone.opt.debug.fat

  mkdir -p /root/out/templates-mono/iphone-mono-libs
  $IOS_LIPO -create bin/libmonosgen-2.0.iphone.arm64.a bin/libmonosgen-2.0.iphone.x86_64.a -output /root/out/templates-mono/iphone-mono-libs/libmonosgen-2.0.iphone.fat.a
  $IOS_LIPO -create bin/libmono-native.iphone.arm64.a bin/libmono-native.iphone.x86_64.a -output /root/out/templates-mono/iphone-mono-libs/libmono-native.iphone.fat.a
  $IOS_LIPO -create bin/libmono-profiler-log.iphone.arm64.a bin/libmono-profiler-log.iphone.x86_64.a -output /root/out/templates-mono/iphone-mono-libs/libmono-profiler-log.iphone.fat.a

  # The Mono libraries for the interpreter are not available for simulator builds
  $IOS_LIPO -create bin/libmono-ee-interp.iphone.arm64.a -output /root/out/templates-mono/iphone-mono-libs/libmono-ee-interp.iphone.fat.a
  $IOS_LIPO -create bin/libmono-icall-table.iphone.arm64.a -output /root/out/templates-mono/iphone-mono-libs/libmono-icall-table.iphone.fat.a
  $IOS_LIPO -create bin/libmono-ilgen.iphone.arm64.a -output /root/out/templates-mono/iphone-mono-libs/libmono-ilgen.iphone.fat.a

  mkdir -p /root/out/templates-mono/bcl
  cp -r /root/mono-installs/ios-bcl/* /root/out/templates-mono/bcl
fi

echo "iOS build successful"
