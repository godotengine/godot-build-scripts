#!/bin/bash

set -e

# Config

export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export IOS_SDK="18.5"
export IOS_OPTIONS_ARM64="SDKVERSION=${IOS_SDK} ios_triple=arm-apple-darwin11- IPHONEPATH=/root/ioscross/arm64/ IPHONESDK=/root/ioscross/arm64/SDK/iPhoneOS${IOS_SDK}.sdk/"

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for iOS..."

# arm64 device
$SCONS platform=iphone $IOS_OPTIONS_ARM64 arch=arm64 tools=no target=release_debug
$SCONS platform=iphone $IOS_OPTIONS_ARM64 arch=arm64 tools=no target=release

mkdir -p /root/out/templates
cp bin/godot.iphone.*.arm64 /root/out/templates/

echo "iOS build successful"
