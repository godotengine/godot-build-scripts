#!/bin/bash

set -e

# Config

# Debug symbols are enabled for the Android builds so we can generate a separate debug symbols file.
# Gradle will strip them out of the final artifacts.
export SCONS="scons -j${NUM_CORES} verbose=yes warnings=no progress=no"
export OPTIONS=""

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

echo "Starting classical build for Android..."
$SCONS platform=android android_arch=armv7 $OPTIONS tools=no target=release_debug
$SCONS platform=android android_arch=armv7 $OPTIONS tools=no target=release
$SCONS platform=android android_arch=arm64v8 $OPTIONS tools=no target=release_debug
$SCONS platform=android android_arch=arm64v8 $OPTIONS tools=no target=release
$SCONS platform=android android_arch=x86 $OPTIONS tools=no target=release_debug
$SCONS platform=android android_arch=x86 $OPTIONS tools=no target=release
$SCONS platform=android android_arch=x86_64 $OPTIONS tools=no target=release_debug
$SCONS platform=android android_arch=x86_64 $OPTIONS tools=no target=release

pushd platform/android/java
./gradlew build
popd

mkdir -p /root/out/templates
cp bin/android_debug.apk /root/out/templates/
cp bin/android_release.apk /root/out/templates/

echo "Android build successful"
