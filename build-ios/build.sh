#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
# Keep LTO disabled for iOS - it works but it makes linking apps on deploy very slow,
# which is seen as a regression in the current workflow.
export OPTIONS="production=yes lto=none"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm

export IOS_SDK="15.4"
export IOS_LIPO="/root/ioscross/arm64/bin/arm-apple-darwin11-lipo"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

# Classical

if [ "${CLASSICAL}" == "1" ]; then
  echo "Starting classical build for iOS..."

  # arm64 device
  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no ios_simulator=no target=release_debug \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=arm64 tools=no ios_simulator=no target=release \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

  # arm64 simulator
  # Disabled for now as it doesn't work with cctools-port and current LLVM.
  # See https://github.com/godotengine/build-containers/pull/85.
  #$SCONS platform=iphone $OPTIONS arch=arm64 tools=no ios_simulator=yes target=release_debug \
  #  IPHONESDK="/root/ioscross/arm64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64_sim/" ios_triple="arm-apple-darwin11-"
  #$SCONS platform=iphone $OPTIONS arch=arm64 tools=no ios_simulator=no target=release \
  #  IPHONESDK="/root/ioscross/arm64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64_sim/" ios_triple="arm-apple-darwin11-"

  # x86_64 simulator
  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no ios_simulator=yes target=release_debug \
    IPHONESDK="/root/ioscross/x86_64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64_sim/" ios_triple="x86_64-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS arch=x86_64 tools=no ios_simulator=yes target=release \
    IPHONESDK="/root/ioscross/x86_64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64_sim/" ios_triple="x86_64-apple-darwin11-"

  mkdir -p /root/out/templates
  cp bin/libgodot.iphone.opt.arm64.a /root/out/templates/libgodot.iphone.a
  cp bin/libgodot.iphone.opt.debug.arm64.a /root/out/templates/libgodot.iphone.debug.a
  #$IOS_LIPO -create bin/libgodot.iphone.opt.arm64.simulator.a bin/libgodot.iphone.opt.x86_64.simulator.a -output /root/out/templates/libgodot.iphone.simulator.a
  #$IOS_LIPO -create bin/libgodot.iphone.opt.debug.arm64.simulator.a bin/libgodot.iphone.opt.debug.x86_64.simulator.a -output /root/out/templates/libgodot.iphone.debug.simulator.a
  cp bin/libgodot.iphone.opt.x86_64.simulator.a /root/out/templates/libgodot.iphone.simulator.a
  cp bin/libgodot.iphone.opt.debug.x86_64.simulator.a /root/out/templates/libgodot.iphone.debug.simulator.a
fi

# Mono

if [ "${MONO}" == "1" ]; then
  echo "Starting Mono build for iOS..."

  cp /root/mono-glue/*.cpp modules/mono/glue/
  cp -r /root/mono-glue/GodotSharp/GodotSharp/Generated modules/mono/glue/GodotSharp/GodotSharp/
  cp -r /root/mono-glue/GodotSharp/GodotSharpEditor/Generated modules/mono/glue/GodotSharp/GodotSharpEditor/

  # arm64 device
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 ios_simulator=no mono_prefix=/root/mono-installs/ios-arm64-release tools=no target=release_debug \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 ios_simulator=no mono_prefix=/root/mono-installs/ios-arm64-release tools=no target=release \
    IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

  # arm64 simulator
  # Disabled for now as it doesn't work with cctools-port and current LLVM.
  # See https://github.com/godotengine/build-containers/pull/85.
  #$SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 ios_simulator=yes mono_prefix=/root/mono-installs/ios-arm64-sim-release tools=no target=release_debug \
  #  IPHONESDK="/root/ioscross/arm64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64_sim/" ios_triple="arm-apple-darwin11-"
  #$SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=arm64 ios_simulator=yes mono_prefix=/root/mono-installs/ios-arm64-sim-release tools=no target=release \
  #  IPHONESDK="/root/ioscross/arm64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64_sim/" ios_triple="arm-apple-darwin11-"

  # x86_64 simulator
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=x86_64 ios_simulator=yes mono_prefix=/root/mono-installs/ios-x86_64-release tools=no target=release_debug \
    IPHONESDK="/root/ioscross/x86_64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64_sim/" ios_triple="x86_64-apple-darwin11-"
  $SCONS platform=iphone $OPTIONS $OPTIONS_MONO arch=x86_64 ios_simulator=yes mono_prefix=/root/mono-installs/ios-x86_64-release tools=no target=release \
    IPHONESDK="/root/ioscross/x86_64_sim/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64_sim/" ios_triple="x86_64-apple-darwin11-"

  mkdir -p /root/out/templates-mono

  cp bin/libgodot.iphone.opt.arm64.a /root/out/templates-mono/libgodot.iphone.a
  cp bin/libgodot.iphone.opt.debug.arm64.a /root/out/templates-mono/libgodot.iphone.debug.a
  #$IOS_LIPO -create bin/libgodot.iphone.opt.arm64.simulator.a bin/libgodot.iphone.opt.x86_64.simulator.a -output /root/out/templates-mono/libgodot.iphone.simulator.a
  #$IOS_LIPO -create bin/libgodot.iphone.opt.debug.arm64.simulator.a bin/libgodot.iphone.opt.debug.x86_64.simulator.a -output /root/out/templates-mono/libgodot.iphone.debug.simulator.a
  cp bin/libgodot.iphone.opt.x86_64.simulator.a /root/out/templates-mono/libgodot.iphone.simulator.a
  cp bin/libgodot.iphone.opt.debug.x86_64.simulator.a /root/out/templates-mono/libgodot.iphone.debug.simulator.a

  cp -r misc/dist/iphone-mono-libs /root/out/templates-mono/iphone-mono-libs

  cp bin/libmonosgen-2.0.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmonosgen-2.0.xcframework/ios-arm64/libmonosgen.a
  cp bin/libmono-native.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmono-native.xcframework/ios-arm64/libmono-native.a
  cp bin/libmono-profiler-log.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmono-profiler-log.xcframework/ios-arm64/libmono-profiler-log.a

  #$IOS_LIPO -create bin/libmonosgen-2.0.iphone.arm64.simulator.a bin/libmonosgen-2.0.iphone.x86_64.simulator.a -output /root/out/templates-mono/iphone-mono-libs/libmonosgen-2.0.xcframework/ios-arm64_x86_64-simulator/libmonosgen.a
  #$IOS_LIPO -create bin/libmono-native.iphone.arm64.simulator.a bin/libmono-native.iphone.x86_64.simulator.a -output /root/out/templates-mono/iphone-mono-libs/libmono-native.xcframework/ios-arm64_x86_64-simulator/libmono-native.a
  #$IOS_LIPO -create bin/libmono-profiler-log.iphone.arm64.simulator.a bin/libmono-profiler-log.iphone.x86_64.simulator.a -output /root/out/templates-mono/iphone-mono-libs/libmono-profiler-log.xcframework/ios-arm64_x86_64-simulator/libmono-profiler-log.a
  cp bin/libmonosgen-2.0.iphone.x86_64.simulator.a /root/out/templates-mono/iphone-mono-libs/libmonosgen-2.0.xcframework/ios-arm64_x86_64-simulator/libmonosgen.a
  cp bin/libmono-native.iphone.x86_64.simulator.a /root/out/templates-mono/iphone-mono-libs/libmono-native.xcframework/ios-arm64_x86_64-simulator/libmono-native.a
  cp bin/libmono-profiler-log.iphone.x86_64.simulator.a /root/out/templates-mono/iphone-mono-libs/libmono-profiler-log.xcframework/ios-arm64_x86_64-simulator/libmono-profiler-log.a

  # The Mono libraries for the interpreter are not available for simulator builds
  cp bin/libmono-ee-interp.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmono-ee-interp.xcframework/ios-arm64/libmono-ee-interp.a
  cp bin/libmono-icall-table.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmono-icall-table.xcframework/ios-arm64/libmono-icall-table.a
  cp bin/libmono-ilgen.iphone.arm64.a /root/out/templates-mono/iphone-mono-libs/libmono-ilgen.xcframework/ios-arm64/libmono-ilgen.a

  mkdir -p /root/out/templates-mono/bcl
  cp -r /root/mono-installs/ios-bcl/* /root/out/templates-mono/bcl
fi

echo "iOS build successful"
