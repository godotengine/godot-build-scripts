#!/bin/bash

set -e

export BUILD_NAME=official
export SCONS="scons -j16 verbose=yes warnings=no progress=no"
export OPTIONS="builtin_libpng=yes builtin_openssl=yes builtin_zlib=yes debug_symbols=no use_static_cpp=yes use_lto=yes"
export OPTIONS_MONO="module_mono_enabled=yes mono_static=yes"
export TERM=xterm
export ANDROID_HOME=/root/
export ANDROID_NDK_ROOT=/root/ndk-bundle/

rm -rf godot
mkdir godot
cd godot
tar xf /root/godot.tar.gz --strip-components=1

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

cp bin/*.apk /root/out
