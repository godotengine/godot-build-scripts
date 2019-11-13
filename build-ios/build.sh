#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export IOS_SDK="12.4"
export OPTIONS="osxcross_sdk=darwin17 builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no use_static_cpp=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm
export OSXCROSS_IOS=not_nothing

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

$SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release_debug IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"
$SCONS platform=iphone $OPTIONS arch=arm64 tools=no target=release IPHONESDK="/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/arm64/" ios_triple="arm-apple-darwin11-"

$SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release_debug IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"
$SCONS platform=iphone $OPTIONS arch=x86_64 tools=no target=release IPHONESDK="/root/ioscross/x86_64/SDK/iPhoneOS${IOS_SDK}.sdk" IPHONEPATH="/root/ioscross/x86_64/" ios_triple="x86_64-apple-darwin11-"

/root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot.iphone.opt.arm64.a bin/libgodot.iphone.opt.x86_64.a -output /root/out/libgodot.iphone.opt.fat
/root/ioscross/arm64/bin/arm-apple-darwin11-lipo -create bin/libgodot.iphone.opt.debug.arm64.a bin/libgodot.iphone.opt.debug.x86_64.a -output /root/out/libgodot.iphone.opt.debug.fat

echo "iOS build successful"
